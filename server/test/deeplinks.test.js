import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { existsSync } from "node:fs";
import { DeeplinkStore, fillTemplate, loadCatalog, matchUrl, normalizeLink, templateFor, urlProblem } from "../lib/deeplinks.js";

const CATALOG = join(import.meta.dirname, "..", "..", "..", "BlibliMobile-iOS", "BlibliMobile-iOS", "Common", "Deeplink", "DeeplinkList.txt");

test("templateFor turns route regexes into blibli:// templates", () => {
	assert.deepEqual(templateFor("(.*)/cari/(.*)"), { template: "blibli://cari/{rest}", params: [{ name: "rest", isOptional: true }], isAdvanced: false });
	assert.equal(templateFor(".*/cart").template, "blibli://cart");
	assert.equal(templateFor("(.*)?virtualstore").template, "blibli://virtualstore");
	assert.equal(templateFor("(.*)com/jual/(.*)").template, "blibli://www.blibli.com/jual/{rest}");
	assert.equal(templateFor("(?i)(.*)/home(/?)($|\\?.*)").template, "blibli://home");
	assert.equal(templateFor("(.*)/c/[0-9]*/(.*)/(.*)/(.*)").template, "blibli://c/{id}/{value}/{value2}/{rest}");
	assert.equal(templateFor("(?i)(.*)wwwuat([a-b]).gdn-app.com(/?)$").isAdvanced, true);
});

test("fillTemplate drops empty optional slots", () => {
	assert.equal(fillTemplate("blibli://cari/{rest}", { rest: "sepatu" }), "blibli://cari/sepatu");
	assert.equal(fillTemplate("blibli://login{rest}", {}), "blibli://login");
});

test("every template in the app's list is caught by its own route", { skip: !existsSync(CATALOG) && "app repo not beside the server" }, async () => {
	const catalog = await loadCatalog(CATALOG);
	assert.ok(catalog.length > 100);
	const missed = catalog.filter((route) => !route.isAdvanced).filter((route) => {
		const url = fillTemplate(route.template, { value: "x", value2: "y", id: "1", rest: "" });
		return !matchUrl(catalog, url).some((hit) => hit.id === route.id);
	});
	assert.deepEqual(missed.map((route) => route.regex), []);
	assert.equal(matchUrl(catalog, "blibli://cart")[0].handlerClass, "CartHelper");
});

test("urlProblem lets app schemes and Blibli universal links through", () => {
	assert.equal(urlProblem("blibli://cart"), null);
	assert.equal(urlProblem("com.blibli.mobile://x"), null);
	assert.equal(urlProblem("https://www.blibli.com/promosi/android-testing-promo-by-pradeep"), null);
	assert.match(urlProblem("https://wwwuatb.gdn-app.com/promosi/x"), /isn't a Blibli site/);
	assert.match(urlProblem("https://example.com/promosi/x"), /isn't a Blibli site/);
	assert.match(urlProblem("https://evilblibli.com/x"), /isn't a Blibli site/);
	assert.match(urlProblem("tel://123"), /outside the app/);
	assert.match(urlProblem(""), /type or build/);
	assert.match(urlProblem("cart"), /scheme/);
});

test("DeeplinkStore keeps saved links unique and recent opens capped", async () => {
	const store = new DeeplinkStore(join(await mkdtemp(join(tmpdir(), "deeplinks-")), "deeplinks.json"));
	const first = await store.save({ name: "Cart", url: "blibli://cart" });
	await store.save({ name: "Cart again", url: "blibli://cart" });
	assert.equal((await store.load()).saved.length, 1);
	assert.equal(await store.remove(first.id), false);
	for (let index = 0; index < 35; index++) await store.noteOpened({ url: `blibli://cari/${index}`, ok: true });
	const reloaded = new DeeplinkStore(store.file);
	const state = await reloaded.load();
	assert.equal(state.history.length, 30);
	assert.equal(state.history[0].url, "blibli://cari/34");
});

test("a UAT-B web link opens as the blibli:// link for the same path", () => {
	assert.equal(normalizeLink(" https://wwwuatb.gdn-app.com/promosi/android-testing-promo-by-pradeep "), "blibli://promosi/android-testing-promo-by-pradeep");
	assert.equal(normalizeLink("http://wwwuatb.gdn-app.com/promosi/x?y=1"), "blibli://promosi/x?y=1");
	assert.equal(normalizeLink("https://www.blibli.com/promosi/x"), "https://www.blibli.com/promosi/x");
});
