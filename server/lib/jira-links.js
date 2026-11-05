// F4 (D-193): which Jira ticket a test case reports to, taken from the test case document itself — its metadata table
// ("| **Jira** | [SEA-59531](…) |") for the whole page, and any ticket a case's own row names. Then the comment a
// result posts there, built here so the person reads exactly what goes out before confirming.

const KEY = /\b([A-Z][A-Z0-9]{1,9}-\d{1,7})\b/g;
const LINKED_KEY = /\[([A-Z][A-Z0-9]{1,9}-\d{1,7})\]\(([^)\s]+)\)/g;
const BROWSE_URL = /(https?:\/\/[^\s)|"'<>]+\/browse\/([A-Z][A-Z0-9]{1,9}-\d{1,7}))/g;
const TICKET_LABEL = /\b(jira|ticket|story|epic|issue|bug)\b/i;

function linkedKeys(text) {
	const found = new Map();
	for (const [, key, url] of String(text).matchAll(LINKED_KEY)) found.set(key, url);
	for (const [, url, key] of String(text).matchAll(BROWSE_URL)) if (!found.has(key)) found.set(key, url);
	return found;
}

/** A row of a non-case table labelled Jira/Ticket/Story…: `| **Jira** | [SEA-1](url) |` or `<td>Jira</td><td>SEA-1</td>`. */
function labelledKeys(body) {
	const found = new Map();
	const isHtml = /<tr/i.test(String(body));
	const rows = isHtml ? String(body).split(/<\/tr>/i) : String(body).split("\n").filter((line) => line.trim().startsWith("|"));
	for (const row of rows) {
		const cells = isHtml ? row.split(/<\/t[dh]>/i) : row.split("|");
		const label = (cells.find((cell) => cell.replace(/<[^>]+>|\*/g, "").trim()) ?? "").replace(/<[^>]+>|\*/g, "").trim();
		if (!TICKET_LABEL.test(label) || label.length > 30) continue;
		const linked = linkedKeys(row);
		for (const [key, url] of linked) found.set(key, url);
		for (const [, key] of row.replace(/<[^>]+>/g, " ").matchAll(KEY)) if (!found.has(key)) found.set(key, null);
	}
	return found;
}

/**
 * `{document: [{key, url}], byCase: {caseId: [{key, url}]}}`. Bare keys in a case row count only when their project
 * is already a ticket project of this page (so "UTF-8" in a step never becomes a ticket).
 */
export function jiraLinksFrom(body, cases = []) {
	const documentKeys = new Map([...labelledKeys(body), ...linkedKeys(body)]);
	const projects = new Set([...documentKeys.keys()].map((key) => key.split("-")[0]));
	const byCase = {};
	for (const testCase of cases) {
		const text = Object.values(testCase).filter((value) => typeof value === "string").join("\n");
		const keys = linkedKeys(text);
		for (const [, key] of text.matchAll(KEY)) if (!keys.has(key) && projects.has(key.split("-")[0])) keys.set(key, documentKeys.get(key) ?? null);
		if (keys.size) byCase[testCase.id] = [...keys].map(([key, url]) => ({ key, url }));
	}
	// A key that only appears inside one case row is that case's, not the page's.
	const caseOnly = new Set(Object.values(byCase).flat().map((link) => link.key));
	const labelled = labelledKeys(body);
	const document = [...documentKeys].filter(([key]) => labelled.has(key) || !caseOnly.has(key)).map(([key, url]) => ({ key, url }));
	return { document, byCase };
}

/** The tickets a case's result goes to: its own, else the page's. */
export function ticketsFor(caseId, links) {
	return links?.byCase?.[caseId]?.length ? links.byCase[caseId] : links?.document ?? [];
}

/** Plain-text comment for a case result; no tool names, nothing the reader needs this Mac to understand. */
export function jiraComment({ testCase, run, build, batchName, proofNames = [], note = "" }) {
	const lines = [
		`Test result — case ${testCase.id}: ${testCase.scenario ?? ""}`.trim(),
		"",
		`Result: ${run?.verdict ?? "not run"}${run?.at ? ` (${new Date(run.at).toLocaleString("en-GB")})` : ""}`,
	];
	if (build) lines.push(`Build: ${build}`);
	if (batchName) lines.push(`Test batch: ${batchName}`);
	if (testCase.expected) lines.push("", `Expected: ${testCase.expected}`);
	const failed = (run?.steps ?? []).find((step) => step.ok === false && !step.skipped);
	if (failed) lines.push("", `Failed at: ${failed.text}${failed.reason ? ` — ${failed.reason}` : ""}`);
	if (proofNames.length) lines.push("", `Proof (${proofNames.length}): ${proofNames.slice(0, 10).join(", ")}${proofNames.length > 10 ? " …" : ""}`);
	if (note.trim()) lines.push("", note.trim());
	return lines.join("\n");
}
