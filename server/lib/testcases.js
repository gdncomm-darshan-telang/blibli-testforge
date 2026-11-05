// Dependency-free parser for the test-case markdown tables used across this project's QA reports
// (Scenario / Precondition / Steps / Expected Result / API columns, in whatever order a given doc
// uses). No markdown library needed for this one shape — a header row, a `---` separator, then data
// rows, all pipe-delimited.
import { readFile } from "node:fs/promises";
import { jiraLinksFrom } from "./jira-links.js";

const CANONICAL_FIELDS = {
	scenario: ["scenario", "test scenario", "test case", "test cases", "case", "title", "description"],
	precondition: ["precondition", "preconditions", "setup"],
	steps: ["steps", "step", "test steps", "step action", "step actions", "action"],
	expected: ["expected result", "expected", "expected outcome"],
	api: ["api", "endpoint", "apis"],
	evidence: ["screenshot", "evidence"],
	iosStatus: ["ios automation status", "ios status"],
	androidStatus: ["android automation status", "android status"],
	id: ["id", "case id", "test case id", "tc id", "tc", "test id", "no", "no.", "#"],
};

function canonicalize(header) {
	const needle = header.replace(/[*_`]/g, "").trim().toLowerCase();
	for (const [field, variants] of Object.entries(CANONICAL_FIELDS)) {
		if (variants.includes(needle)) return field;
	}
	return null;
}

/** Header fields; a blank first header over a row-number column (MICROSITE_TABBING's page) is the id. */
function headerFields(headers) {
	const fields = headers.map(canonicalize);
	if (!fields.includes("id") && headers[0]?.replace(/[*_`]/g, "").trim() === "") fields[0] = "id";
	return fields;
}

function splitRow(line) {
	// Strips a leading/trailing pipe, then splits on unescaped `|`; `<br>` inside a cell (Confluence
	// markdown export) becomes " / " like the HTML parser's line joins.
	return line
		.trim()
		.replace(/^\|/, "")
		.replace(/\|$/, "")
		.split(/(?<!\\)\|/)
		// `\_` / `\*` are markdown escapes from the Confluence export (MICROSITE\_TABBING), not part of the text.
		.map((cell) => cell.replace(/\\\|/g, "|").replace(/\\([_*[\]])/g, "$1").replace(/<br\s*\/?>/gi, " / ").trim());
}

const SEPARATOR_ROW = /^\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?$/;

/** Each run of consecutive pipe lines that has a `---` separator under its first line. */
function markdownTables(markdown) {
	const tables = [];
	let block = [];
	const flush = () => {
		if (block.length > 2 && SEPARATOR_ROW.test(block[1])) tables.push(block);
		block = [];
	};
	for (const line of markdown.split("\n")) {
		if (line.trim().startsWith("|")) block.push(line);
		else flush();
	}
	flush();
	return tables;
}

/** Same best-scoring-table rule as the HTML parser: a page also carries metadata tables (Jira links,
 *  revision history) whose rows must not become cases. */
export function parseTestCaseTable(markdown) {
	let best = null;
	for (const lines of markdownTables(markdown)) {
		const fields = headerFields(splitRow(lines[0]));
		const score = fields.filter((field) => field && field !== "id").length;
		if (!best || score > best.score) best = { lines, fields, score };
	}
	if (!best || best.score === 0) return [];

	const cases = [];
	let autoId = 1;
	for (const line of best.lines.slice(2)) {
		if (SEPARATOR_ROW.test(line)) continue;
		const cells = splitRow(line);
		if (cells.length < 2) continue;
		const row = {};
		cells.forEach((cell, index) => {
			const field = best.fields[index];
			if (field) row[field] = cell;
			else row[`col${index}`] = cell;
		});
		if (!row.id) row.id = String(autoId);
		autoId += 1;
		cases.push(row);
	}
	return cases;
}

const ENTITIES = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " " };

function htmlToText(html) {
	return html
		.replace(/<br\s*\/?>/gi, "\n")
		.replace(/<\/(p|li|div)>/gi, "\n")
		.replace(/<[^>]+>/g, "")
		.replace(/&(#\d+|#x[0-9a-f]+|\w+);/gi, (whole, code) => {
			if (code.startsWith("#x")) return String.fromCodePoint(parseInt(code.slice(2), 16));
			if (code.startsWith("#")) return String.fromCodePoint(Number(code.slice(1)));
			return ENTITIES[code.toLowerCase()] ?? whole;
		})
		.split("\n")
		.map((line) => line.trim())
		.filter(Boolean)
		.join(" / ");
}

/** Every table on a Confluence page, as arrays of cell text. Storage format is XHTML, so plain
 *  tag splitting is enough — no DOM library for this one shape. Nested tables are not expected. */
function htmlTables(html) {
	const tables = [];
	for (const tableMatch of html.matchAll(/<table[\s\S]*?<\/table>/gi)) {
		const rows = [];
		for (const rowMatch of tableMatch[0].matchAll(/<tr[\s\S]*?<\/tr>/gi)) {
			const cells = [...rowMatch[0].matchAll(/<t[hd][^>]*>([\s\S]*?)<\/t[hd]>/gi)].map((cell) => htmlToText(cell[1]));
			if (cells.length) rows.push(cells);
		}
		if (rows.length > 1) tables.push(rows);
	}
	return tables;
}

/** Picks the table whose header row maps the most canonical fields — a test-case page usually also
 *  carries a revision or metadata table that must not be mistaken for the cases. */
export function parseTestCaseHtml(html) {
	let best = null;
	for (const rows of htmlTables(html)) {
		const fields = headerFields(rows[0]);
		const score = fields.filter((field) => field && field !== "id").length;
		if (!best || score > best.score) best = { rows, fields, score };
	}
	if (!best || best.score === 0) return [];

	return best.rows.slice(1).map((cells, index) => {
		const row = {};
		cells.forEach((cell, cellIndex) => {
			const field = best.fields[cellIndex];
			row[field || `col${cellIndex}`] = cell;
		});
		if (!row.id) row.id = String(index + 1);
		return row;
	});
}

/** Cases from a Confluence page read: the Atlassian plugin's `getConfluenceContent` result
 *  (`{data: {title, body}}`, D-080) or the Rovo `getConfluencePage` one (`{content: {nodes: [page]}}`). */
export function parseConfluencePage(toolResultText) {
	const json = JSON.parse(toolResultText);
	const page = json?.data ?? json?.content?.nodes?.[0];
	const body = typeof page?.body === "string" ? page.body : page?.body?.value ?? page?.body?.markdown ?? page?.body?.storage?.value;
	if (!body) throw new Error("the page came back without a body");
	const cases = /<table/i.test(body) ? parseTestCaseHtml(body) : parseTestCaseTable(body);
	return { title: page.title, cases, jira: jiraLinksFrom(body, cases) };
}

/** @deprecated name kept for callers from before D-080. */
export const parseRovoPage = parseConfluencePage;

export function hasConfluenceCredentials() {
	return Boolean(process.env.CONFLUENCE_EMAIL && process.env.CONFLUENCE_TOKEN);
}

export function confluencePageId(url) {
	const match = url.match(/\/pages\/(\d+)/) || url.match(/[?&]pageId=(\d+)/);
	return match ? match[1] : null;
}

async function loadConfluencePage(url) {
	const pageId = confluencePageId(url);
	if (!pageId) throw new Error("not a Confluence page URL (expected …/pages/<id>/…)");
	const { CONFLUENCE_EMAIL: email, CONFLUENCE_TOKEN: token } = process.env;
	if (!email || !token) {
		throw new Error("Confluence credentials not set (CONFLUENCE_EMAIL / CONFLUENCE_TOKEN)");
	}
	const { origin } = new URL(url);
	const response = await fetch(`${origin}/wiki/api/v2/pages/${pageId}?body-format=storage`, {
		headers: {
			Authorization: `Basic ${Buffer.from(`${email}:${token}`).toString("base64")}`,
			Accept: "application/json",
		},
		signal: AbortSignal.timeout(15_000),
	});
	if (!response.ok) throw new Error(`Confluence answered HTTP ${response.status} for page ${pageId}`);
	const page = await response.json();
	const body = page.body?.storage?.value ?? "";
	const cases = parseTestCaseHtml(body);
	return { title: page.title, cases, jira: jiraLinksFrom(body, cases) };
}

export async function loadTestCases(source) {
	if (/^https?:\/\//i.test(source)) return loadConfluencePage(source);
	const text = await readFile(source, "utf8");
	const cases = /<table/i.test(text) ? parseTestCaseHtml(text) : parseTestCaseTable(text);
	return { title: source, cases, jira: jiraLinksFrom(text, cases) };
}
