// Deeplinks (D-157): build a link from the app's own route list and open it in the app on the test simulator,
// with `simctl openurl` — the app stays running (no relaunch, no test runner) and the target screen is pushed
// over whatever is on screen, so Back returns there. The catalog is the app's DeeplinkList.txt; the live router
// config (remote) can differ, so a match is "which entry in DeeplinkList.txt would catch it", not a promise.
import { readFile, writeFile, mkdir, rename } from "node:fs/promises";
import { dirname, join } from "node:path";
import { randomUUID } from "node:crypto";

const HISTORY_LIMIT = 30;
const SAVED_LIMIT = 200;
const URL_LIMIT = 2048;
// blibli:// is what the app registers for routes (Info.plist CFBundleURLSchemes); com.blibli.mobile:// too.
const APP_SCHEMES = ["blibli", "com.blibli.mobile"];
// https links on these hosts are universal links: the app's associated domains take them, so `simctl openurl` opens
// the app, not Safari (verified on the QA clone, 2026-10-31).
const APP_LINK_HOSTS = /(^|\.)blibli\.com$/i;
// UAT-B pages aren't universal links for the QA build; the app opens the same path as blibli:// (user's workaround).
const LINK_REWRITES = [[/^https?:\/\/wwwuatb\.gdn-app\.com\//i, "blibli://"]];

/** The link as it will be opened: a UAT-B web link becomes the blibli:// link for the same path. */
export function normalizeLink(url) {
	const text = String(url ?? "").trim();
	const rewrite = LINK_REWRITES.find(([pattern]) => pattern.test(text));
	return rewrite ? text.replace(rewrite[0], rewrite[1]) : text;
}

/**
 * A fill-in template from one route regex, e.g. `(.*)/cari/(.*)` → `blibli://cari/{value}`. The leading `(.*)` is
 * the host part and becomes `blibli:/`; inner `(.*)` groups become `{value}`, `{value2}`…; a trailing one is optional
 * (`{rest}`). A regex with other syntax (classes, alternation) is `advanced`: the person types the link themselves.
 */
export function templateFor(regex) {
	let body = String(regex).replace(/^\(\?i\)/, "").replace(/^\^/, "").replace(/\\\//g, "/");
	// Optional slash / query tails the app accepts but a link doesn't need: `(/?)`, `($|\?.*)`, `((/?)$|\?(.*))`.
	body = body.replace(/\(\(\/\?\)\$\|\\\?\(\.\*\)\)$/, "").replace(/\(\$\|\\\?\.\*\)$/, "").replace(/\(\/\?\)/g, "").replace(/\$$/, "");
	body = body.replace(/^\(\.\*\)\??/, "").replace(/^\.\*/, "");
	// A numeric path segment (`[0-9]*`) is a slot of its own.
	body = body.replace(/\[0-9\][*+]/g, "{id}");
	const isAdvanced = /[[\]|+]|\\[dws]|\((?!\.\*\))/i.test(body);
	if (body.startsWith("com/")) body = `/www.blibli.${body}`;
	else if (!body.startsWith("/")) body = `/${body}`;
	body = body.replace(/\(\.\*\)\??$/, "{rest}");
	let valueCount = 0;
	body = body.replace(/\(\.\*\)\??/g, () => {
		valueCount += 1;
		return valueCount === 1 ? "{value}" : `{value${valueCount}}`;
	});
	body = body.replace(/\.\*/g, "").replace(/\\(.)/g, "$1");
	// Fields show in the order their slots appear in the link.
	const params = [...body.matchAll(/\{(\w+)\}/g)].map(([, name]) => ({ name, isOptional: name === "rest" }));
	return { template: `blibli:/${body}`, params, isAdvanced };
}

/** The template with its `{name}` slots filled; empty optional slots drop out. */
export function fillTemplate(template, values = {}) {
	return String(template).replace(/\{(\w+)\}/g, (_match, name) => (values[name] == null ? "" : String(values[name])));
}

export async function loadCatalog(file) {
	const raw = JSON.parse(await readFile(file, "utf8"));
	return raw.map((entry, index) => ({
		id: `r${index}`,
		description: entry.description ?? "",
		handlerClass: entry.handlerClass ?? "",
		regex: entry.deeplinkRegex ?? "",
		...templateFor(entry.deeplinkRegex ?? ""),
	}));
}

/** Every catalog entry whose regex matches `url`, in list order — the first is the one the app tries first. */
export function matchUrl(catalog, url) {
	return catalog.filter((entry) => {
		try {
			// `(?i)` is ICU (the app's NSRegularExpression) syntax; JS takes it as the `i` flag.
			const isCaseless = entry.regex.startsWith("(?i)");
			return new RegExp(isCaseless ? entry.regex.slice(4) : entry.regex, isCaseless ? "i" : "").test(url);
		} catch {
			return false;
		}
	}).map(({ id, description, handlerClass, regex }) => ({ id, description, handlerClass, regex }));
}

/** Why `url` can't be opened, or null: app schemes and https links on Blibli hosts (universal links) open the app. */
export function urlProblem(url) {
	const text = String(url ?? "").trim();
	if (!text) return "type or build a link first";
	if (text.length > URL_LIMIT) return `the link is longer than ${URL_LIMIT} characters`;
	const scheme = text.match(/^([a-z][\w.+-]*):/i)?.[1]?.toLowerCase();
	if (!scheme) return "a link starts with a scheme, e.g. blibli://cart";
	if (APP_SCHEMES.includes(scheme)) return null;
	if (scheme === "https" || scheme === "http") {
		let host = "";
		try {
			host = new URL(text).hostname;
		} catch {
			return "that isn't a valid link";
		}
		return APP_LINK_HOSTS.test(host) ? null : `${host} isn't a Blibli site — it would open Safari, not the app`;
	}
	return `${scheme}:// would open outside the app — use blibli:// or https://www.blibli.com/…`;
}

/** Saved links and recent opens, kept in `.data/deeplinks.json`. */
export class DeeplinkStore {
	constructor(file) {
		this.file = file;
		this.state = null;
	}

	async load() {
		if (this.state) return this.state;
		try {
			const parsed = JSON.parse(await readFile(this.file, "utf8"));
			this.state = { saved: parsed.saved ?? [], history: parsed.history ?? [] };
		} catch {
			this.state = { saved: [], history: [] };
		}
		return this.state;
	}

	async save({ name, url }) {
		const state = await this.load();
		const entry = { id: randomUUID(), name: String(name ?? "").trim().slice(0, 80) || url, url, savedAt: new Date().toISOString() };
		state.saved = [entry, ...state.saved.filter((saved) => saved.url !== url)].slice(0, SAVED_LIMIT);
		await this.#write();
		return entry;
	}

	async remove(id) {
		const state = await this.load();
		const before = state.saved.length;
		state.saved = state.saved.filter((saved) => saved.id !== id);
		if (state.saved.length !== before) await this.#write();
		return state.saved.length !== before;
	}

	async noteOpened({ url, ok, error, matched }) {
		const state = await this.load();
		state.history = [{ url, ok, ...(error && { error }), ...(matched && { matched }), at: new Date().toISOString() }, ...state.history].slice(0, HISTORY_LIMIT);
		await this.#write();
	}

	async #write() {
		await mkdir(dirname(this.file), { recursive: true });
		const temp = join(dirname(this.file), `.deeplinks-${process.pid}.tmp`);
		await writeFile(temp, JSON.stringify(this.state, null, "\t"));
		await rename(temp, this.file);
	}
}
