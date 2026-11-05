// A simulator app that crashes leaves an `.ips` report in the Mac's DiagnosticReports folder. P4
// (D-061) reads it after a case that didn't pass: a crash makes the verdict BLOCKED, not FAIL, and
// the report travels with the run.
import { readdir, readFile, stat } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

export const DIAGNOSTIC_REPORTS = join(homedir(), "Library", "Logs", "DiagnosticReports");

/** Header line + body JSON of an `.ips` file → `{bundleId, exception, frames[]}`; null if unreadable. */
export function summarizeIps(text) {
	const newline = text.indexOf("\n");
	if (newline < 0) return null;
	try {
		const header = JSON.parse(text.slice(0, newline));
		const body = JSON.parse(text.slice(newline + 1));
		const thread = (body.threads ?? []).find((entry) => entry.triggered) ?? body.threads?.[0];
		const images = body.usedImages ?? [];
		const frames = (thread?.frames ?? []).slice(0, 8).map((frame) => {
			const image = images[frame.imageIndex]?.name ?? "?";
			return frame.symbol ? `${image} ${frame.symbol}` : `${image} +${frame.imageOffset ?? "?"}`;
		});
		const exception = body.exception ? [body.exception.type, body.exception.signal, body.exception.subtype].filter(Boolean).join(" · ") : null;
		return { bundleId: header.bundleID ?? body.bundleInfo?.CFBundleIdentifier ?? null, appName: header.app_name ?? body.procName ?? null, exception, frames };
	} catch {
		return null;
	}
}

/** The newest crash report of `bundleId` written at or after `sinceMs`, summarized; null if none. */
export async function findCrash(sinceMs, { bundleId, directory = DIAGNOSTIC_REPORTS } = {}) {
	const names = (await readdir(directory).catch(() => [])).filter((name) => name.endsWith(".ips"));
	const recent = [];
	for (const name of names) {
		const path = join(directory, name);
		const info = await stat(path).catch(() => null);
		if (info && info.mtimeMs >= sinceMs) recent.push({ path, mtimeMs: info.mtimeMs });
	}
	recent.sort((a, b) => b.mtimeMs - a.mtimeMs);
	for (const { path } of recent) {
		const summary = summarizeIps(await readFile(path, "utf8").catch(() => ""));
		if (summary && (!bundleId || summary.bundleId === bundleId)) return { path, ...summary };
	}
	return null;
}
