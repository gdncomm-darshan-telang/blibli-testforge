// Test session report (D-176): the session from `buildSession` as Markdown (in-app viewer, .md export, the export
// zip) and as Confluence-ready HTML (publish to the personal page, .html export). Pure functions only.
import { basename } from "node:path";

/** Proof images shown per case; the rest stay in session.json and the media folder. */
export const IMAGES_PER_CASE = 4;

const verdictKind = (verdict) => {
	const text = String(verdict ?? "");
	if (!text) return "notRun";
	if (/^PASS/.test(text)) return "passed";
	if (/^FAIL/.test(text)) return "failed";
	return "undecided";
};

const VERDICT_ICON = { passed: "✅", failed: "❌", undecided: "⚠️", notRun: "⚪️" };

export const verdictLabel = (verdict) => `${VERDICT_ICON[verdictKind(verdict)]} ${verdict ? String(verdict).split(/\s*[:—-]\s/)[0] : "Not run"}`;

const ranAsLabel = (mode) => ({ replay: "Replay", run: "Claude", claude: "Claude" })[mode] ?? (mode ?? "");

/** D-180: one Tests-page result change, oldest first in the report. */
function overrideLine(change) {
	return `- ${when(change.at)}: ${change.previousVerdict ? `${verdictLabel(change.previousVerdict)} → ` : ""}**${verdictLabel(change.verdict)}** (${change.leniency === "lenient" ? "lenient" : "strict"}) — ${mdCell(change.reason)}`;
}

function when(iso) {
	if (!iso) return "";
	const date = new Date(iso);
	return Number.isNaN(date.getTime()) ? String(iso) : date.toISOString().slice(0, 16).replace("T", " ");
}

function duration(ms) {
	if (!ms && ms !== 0) return "";
	const seconds = Math.round(ms / 1000);
	return seconds >= 60 ? `${Math.floor(seconds / 60)}m ${seconds % 60}s` : `${seconds}s`;
}

const cost = (usd) => (typeof usd === "number" ? `$${usd.toFixed(2)}` : "");

/** Cases that need a look come first in the report: failed, then undecided. */
function attentionCases(session) {
	return session.cases.filter((entry) => ["failed", "undecided"].includes(verdictKind(entry.latest?.verdict)))
		.sort((first, second) => (verdictKind(first.latest?.verdict) === "failed" ? 0 : 1) - (verdictKind(second.latest?.verdict) === "failed" ? 0 : 1));
}

function passRate(summary) {
	const decided = summary.cases - summary.notRun;
	return decided ? `${Math.round((summary.passed / decided) * 100)}%` : "—";
}

function stepText(step) {
	if (typeof step === "string") return step;
	return `${step.ok === false ? "✗" : "✓"} ${step.text}${step.reason && step.ok === false ? ` — ${step.reason}` : ""}`;
}

// --- Markdown -------------------------------------------------------------------------------------------------------

const mdCell = (text) => String(text ?? "").replace(/\|/g, "\\|").replace(/\s*\n\s*/g, " ").trim();

/** Indented, multi-line document text as a Markdown block; empty fields are left out. */
function mdField(title, text) {
	const value = String(text ?? "").trim();
	return value ? [`**${title}**`, "", value, ""] : [];
}

/**
 * `imagePath(file)` turns a media entry into the path the reader resolves (absolute on this Mac, relative inside the
 * zip); null leaves the image out.
 */
export function sessionMarkdown(session, { imagePath = (file) => file.path } = {}) {
	const { summary, document, code } = session;
	const lines = [
		`# ${document.title ?? "QA session"} — test session report`,
		"",
		`**Exported:** ${when(session.exportedAt)}${code?.branch ? ` · **Branch:** \`${code.branch}\`` : ""}${code?.codeId ? ` · **Code:** \`${code.codeId}\`` : ""}`,
		...(document.source ? ["", `**Test document:** ${document.source}`] : []),
		"",
		"## Summary",
		"",
		"| Cases | Passed | Failed | Undecided | Not run | Pass rate | Recorded | Edited locally |",
		"|---|---|---|---|---|---|---|---|",
		`| ${summary.cases} | ${summary.passed} | ${summary.failed} | ${summary.undecided ?? 0} | ${summary.notRun} | ${passRate(summary)} | ${summary.recorded} | ${summary.editedLocally} |`,
		"",
	];
	const attention = attentionCases(session);
	if (attention.length) {
		lines.push("## Needs attention", "");
		for (const entry of attention) lines.push(`- **${entry.id}** · ${mdCell(entry.scenario)} — ${verdictLabel(entry.latest?.verdict)}${entry.latest?.verdict && /[:—]/.test(entry.latest.verdict) ? `: ${mdCell(String(entry.latest.verdict).replace(/^[A-Z_]+\s*[:—-]\s*/, ""))}` : ""}`);
		lines.push("");
	}
	lines.push("## Results", "", "| Case | Scenario | Verdict | Ran as | When | Duration | Recording |", "|---|---|---|---|---|---|---|");
	for (const entry of session.cases) {
		const latest = entry.latest;
		lines.push(`| ${mdCell(entry.id)}${entry.localEdit ? " ✎" : ""} | ${mdCell(entry.scenario)} | ${verdictLabel(latest?.verdict)} | ${ranAsLabel(latest?.ranAs)} | ${when(latest?.at)} | ${duration(latest?.durationMs)} | ${entry.recording ? "●" : ""} |`);
	}
	lines.push("", "✎ edited locally (the edited text is what ran) · ● has a recording that replays without Claude", "", "## Cases", "");
	for (const entry of session.cases) lines.push(...mdCase(entry, imagePath));
	return lines.join("\n");
}

function mdCase(entry, imagePath) {
	const latest = entry.latest;
	const lines = [`### ${entry.id} · ${mdCell(entry.scenario)}`, "", `**Verdict:** ${verdictLabel(latest?.verdict)}${latest ? ` · ${ranAsLabel(latest.ranAs)} · ${when(latest.at)}${latest.durationMs ? ` · ${duration(latest.durationMs)}` : ""}${latest.model ? ` · ${latest.model}` : ""}${cost(latest.costUsd) ? ` · ${cost(latest.costUsd)}` : ""}` : ""}`, ""];
	if (latest?.verdict && /[:—]/.test(latest.verdict)) lines.push(`> ${mdCell(latest.verdict)}`, "");
	if (latest?.review?.action === "override") lines.push(`> Overridden to **${latest.review.verdict}**${latest.review.reason ? `: ${mdCell(latest.review.reason)}` : ""}`, "");
	if (entry.localEdit) lines.push("> ✎ Edited locally — runs used this text, not the document's.", "");
	if (entry.resultOverrides?.length) lines.push("**Result changes**", "", ...entry.resultOverrides.map(overrideLine), "");
	lines.push(...mdField("Precondition", entry.precondition), ...mdField("Steps", entry.steps), ...mdField("Expected result", entry.expected));
	if (entry.api) lines.push("**API**", "", "```", String(entry.api).trim(), "```", "");
	if (entry.recording) lines.push(`**Recording:** ${mdCell(entry.recording.name)}${entry.recording.hasExplanations ? " · has explanations" : ""}`, "");
	const steps = (latest?.steps ?? []).map(stepText).filter(Boolean);
	if (steps.length) lines.push("**Last run steps**", "", ...steps.map((step) => `- ${mdCell(step)}`), "");
	if (latest?.summary) lines.push("**Claude's summary**", "", String(latest.summary).trim(), "");
	if (entry.history.length > 1) {
		lines.push("**Run history**", "", "| When | Verdict | Ran as | Duration | Cost |", "|---|---|---|---|---|");
		for (const run of entry.history) lines.push(`| ${when(run.at)} | ${verdictLabel(run.verdict)} | ${ranAsLabel(run.ranAs)} | ${duration(run.durationMs)} | ${cost(run.costUsd)} |`);
		lines.push("");
	}
	const images = entry.media.screenshots.slice(-IMAGES_PER_CASE).map((file) => [file, imagePath(file)]).filter(([, path]) => path);
	if (images.length) {
		lines.push("**Proof**", "");
		for (const [file, path] of images) lines.push(`![${basename(file.path)}](${encodeURI(path)})`, "");
	}
	const videos = [...entry.media.videos, ...entry.media.demoVideos].map((file) => imagePath(file) ?? null).filter(Boolean);
	if (videos.length) lines.push(`**Videos:** ${videos.map((path) => `[${basename(path)}](${encodeURI(path)})`).join(" · ")}`, "");
	lines.push("---", "");
	return lines;
}

// --- Confluence -----------------------------------------------------------------------------------------------------

const escapeHtml = (text) => String(text ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

const htmlText = (text) => escapeHtml(String(text ?? "").trim()).replace(/\n/g, "<br/>");

const row = (cells, tag = "td") => `<tr>${cells.map((cell) => `<${tag}>${cell}</${tag}>`).join("")}</tr>`;

/**
 * The same report as plain HTML that Confluence's HTML import keeps intact: headings, tables, lists, emoji verdicts.
 * No macros, no images (the connector can't upload attachments); proof file names point at the export zip.
 */
export function sessionConfluenceHtml(session) {
	const { summary, document, code } = session;
	const parts = [
		`<p>Test session report exported ${escapeHtml(when(session.exportedAt))} from TestForge${code?.branch ? ` · branch <code>${escapeHtml(code.branch)}</code>` : ""}${code?.codeId ? ` · code <code>${escapeHtml(code.codeId)}</code>` : ""}.</p>`,
		...(document.source ? [`<p>Test document: ${escapeHtml(document.source)}</p>`] : []),
		"<h2>Summary</h2>",
		"<table><tbody>",
		row(["Cases", "Passed", "Failed", "Undecided", "Not run", "Pass rate", "Recorded", "Edited locally"], "th"),
		row([summary.cases, summary.passed, summary.failed, summary.undecided ?? 0, summary.notRun, passRate(summary), summary.recorded, summary.editedLocally].map(String)),
		"</tbody></table>",
	];
	const attention = attentionCases(session);
	if (attention.length) {
		parts.push("<h2>Needs attention</h2>", "<ul>");
		for (const entry of attention) parts.push(`<li><strong>${escapeHtml(entry.id)}</strong> · ${escapeHtml(entry.scenario)} — ${escapeHtml(entry.latest?.verdict ?? "")}</li>`);
		parts.push("</ul>");
	}
	parts.push("<h2>Results</h2>", "<table><tbody>", row(["Case", "Scenario", "Verdict", "Ran as", "When", "Duration"], "th"));
	for (const entry of session.cases) {
		const latest = entry.latest;
		parts.push(row([`${escapeHtml(entry.id)}${entry.localEdit ? " ✎" : ""}`, escapeHtml(entry.scenario), escapeHtml(verdictLabel(latest?.verdict)), escapeHtml(ranAsLabel(latest?.ranAs)), escapeHtml(when(latest?.at)), escapeHtml(duration(latest?.durationMs))]));
	}
	parts.push("</tbody></table>", "<p><em>✎ edited locally: the edited text is what ran.</em></p>", "<h2>Cases</h2>");
	for (const entry of session.cases) {
		const latest = entry.latest;
		parts.push(`<h3>${escapeHtml(entry.id)} · ${escapeHtml(entry.scenario)}</h3>`);
		parts.push(`<p><strong>Verdict:</strong> ${escapeHtml(latest?.verdict ? `${verdictLabel(latest.verdict)} — ${latest.verdict}` : verdictLabel(null))}${latest ? ` · ${escapeHtml(ranAsLabel(latest.ranAs))} · ${escapeHtml(when(latest.at))}` : ""}</p>`);
		if (latest?.review?.action === "override") parts.push(`<p><strong>Overridden to ${escapeHtml(latest.review.verdict)}</strong>${latest.review.reason ? `: ${escapeHtml(latest.review.reason)}` : ""}</p>`);
		if (entry.localEdit) parts.push("<p><em>✎ Edited locally — runs used this text, not the document's.</em></p>");
		if (entry.resultOverrides?.length) parts.push("<p><strong>Result changes</strong></p><ul>", ...entry.resultOverrides.map((change) => `<li>${escapeHtml(overrideLine(change).replace(/^- /, "").replace(/\*\*/g, ""))}</li>`), "</ul>");
		for (const [title, value] of [["Precondition", entry.precondition], ["Steps", entry.steps], ["Expected result", entry.expected]]) {
			if (String(value ?? "").trim()) parts.push(`<p><strong>${title}</strong><br/>${htmlText(value)}</p>`);
		}
		const failedSteps = (latest?.steps ?? []).filter((step) => typeof step === "object" && step.ok === false);
		if (failedSteps.length) parts.push("<p><strong>Failed steps</strong></p><ul>", ...failedSteps.map((step) => `<li>${escapeHtml(stepText(step))}</li>`), "</ul>");
		if (entry.history.length > 1) parts.push(`<p><strong>Runs:</strong> ${entry.history.map((run) => escapeHtml(`${verdictLabel(run.verdict)} ${when(run.at)}`)).join(" · ")}</p>`);
		const proof = entry.media.screenshots.slice(-IMAGES_PER_CASE).map((file) => basename(file.path));
		if (proof.length) parts.push(`<p><strong>Proof</strong> (in the session export): ${proof.map(escapeHtml).join(", ")}</p>`);
	}
	return parts.join("\n");
}

export const sessionReportTitle = (session) => `QA session — ${session.document.title ?? "test session"} — ${when(session.exportedAt).slice(0, 10)}`;
