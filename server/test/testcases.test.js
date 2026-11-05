import { test } from "node:test";
import assert from "node:assert/strict";
import { parseConfluencePage } from "../lib/testcases.js";

const table = [
	"| No | Scenario | Expected Result |",
	"| --- | --- | --- |",
	"| SF-001 | Open Flash Sale | Section shows |",
	"| SF-002 | Range empty | Section hidden |",
].join("\n");

test("parses the Atlassian plugin getConfluenceContent envelope (D-080)", () => {
	const text = JSON.stringify({ data: { id: "1", title: "Plugin page", body: { format: "markdown", value: table } } });
	const page = parseConfluencePage(text);
	assert.equal(page.title, "Plugin page");
	assert.deepEqual(page.cases.map((c) => c.id), ["SF-001", "SF-002"]);
});

test("still parses the Rovo getConfluencePage envelope", () => {
	const text = JSON.stringify({ content: { nodes: [{ title: "Rovo page", body: table }] } });
	const page = parseConfluencePage(text);
	assert.equal(page.title, "Rovo page");
	assert.equal(page.cases.length, 2);
});

test("a read without a body is an error", () => {
	assert.throws(() => parseConfluencePage(JSON.stringify({ data: { title: "x" } })), /without a body/);
	assert.throws(() => parseConfluencePage("{}"), /without a body/);
});

test("a blank first header over row numbers is the id; 'Test cases' is the scenario (MICROSITE_TABBING page)", () => {
	const body = [
		"| **Jira** | [SEA-59531](https://x) |",
		"| --- | --- |",
		"| **QA** | @someone |",
		"",
		"|  | **Test cases** | **STEP ACTION** | **EXPECTED RESULT** | **API** | **SCREENSHOT** |",
		"| --- | --- | --- | --- | --- | --- |",
		"| 1 | Tab hidden when image is null | Configure a tab without image. | That tab is not shown. | `{ \"image\": null }` |  |",
		"| 2 | Invert mode ON for MICROSITE\\_TABBING | Set `invertMode` = true. | Light text. |  |  |",
	].join("\n");
	const page = parseConfluencePage(JSON.stringify({ content: { nodes: [{ title: "MT", body }] } }));
	assert.deepEqual(page.cases.map((c) => [c.id, c.scenario]), [["1", "Tab hidden when image is null"], ["2", "Invert mode ON for MICROSITE_TABBING"]]);
	assert.equal(page.cases[0].steps, "Configure a tab without image.");
});
