// What NetworkLens was doing to the app's traffic when a replay failed. A mocked response reads
// exactly like a backend or app bug, so every failed replay reports it before anyone files one
// (D-043). Since D-059 the note names the mocks that actually answered a request during the run
// (the trace marks each exchange `isMockServed`), not every rule that happens to be armed: a Flash
// Sale mock left on says nothing about a failed login.
import { liveState } from "./control.js";
import { readSession, resolveSessionPath } from "./session.js";

async function readFromSessionFile() {
	const { path } = await resolveSessionPath();
	const session = await readSession(path);
	return { isMockingEnabled: session.isMockingEnabled, rules: session.mocks };
}

/** `{endpointKey → count}` of mock-served exchanges in trace records recorded at or after `since`. */
export function mockServedSince(records, since) {
	const counts = {};
	for (const record of records) {
		if (!record?.exchange?.isMockServed) continue;
		if (since && new Date(record.recordedAt).getTime() < since) continue;
		const key = record.exchange.endpointKey ?? "(no endpoint key)";
		counts[key] = (counts[key] ?? 0) + 1;
	}
	return counts;
}

/**
 * Asks the running app first (the truth while it is up), falls back to the session file.
 * `served` — `{endpointKey → count}` from the trace for this run; when given, only those mocks are
 * reported as possible causes. `touched` — endpoints the macro's own mock steps set, to say which
 * mocks the test set up itself. `live` / `fromFile` exist for tests.
 */
export async function checkInterceptor({ live = liveState, fromFile = readFromSessionFile, served = null, touched = [] } = {}) {
	let source = "running app";
	let state;
	const answer = await live().catch(() => ({ ok: false }));
	if (answer.ok) {
		state = { isMockingEnabled: Boolean(answer.outcome?.isMockingEnabled), rules: answer.outcome?.rules ?? [] };
	} else {
		source = "session file (app not answering on the control queue)";
		state = await fromFile().catch(() => null);
	}
	if (!state && !served) return { source, known: false, suspicious: false, lines: ["NetworkLens state unknown — neither the app nor the session file answered."] };
	state ??= { isMockingEnabled: false, rules: [] };

	const enabledRules = state.rules.filter((rule) => rule.isEnabled);
	const armed = state.isMockingEnabled ? enabledRules.map((rule) => rule.endpointKey ?? "(no endpoint key)") : [];
	const lines = [`NetworkLens (${source}): mocking ${state.isMockingEnabled ? "ON" : "OFF"}, ${state.rules.length} rule(s), ${enabledRules.length} enabled`];

	if (!served) {
		// No trace for the run: fall back to listing what is armed now.
		armed.forEach((key) => lines.push(`  armed: ${key}`));
		if (state.isMockingEnabled && armed.length === 0) lines.push("  mocking is ON with no enabled rule — turn it off unless this case needs it.");
		if (armed.length > 0) lines.push("  a mocked response may explain this failure — check before calling it an app bug.");
		return { source, known: true, isMockingEnabled: state.isMockingEnabled, armed, served: null, suspicious: state.isMockingEnabled, lines };
	}

	const isTouched = (key) => touched.some((endpoint) => key === endpoint || key.includes(endpoint));
	const servedKeys = Object.keys(served);
	for (const key of servedKeys) {
		const who = isTouched(key) ? "set up by this test" : "NOT set up by this test — left on from elsewhere";
		lines.push(`  answered ${served[key]} request(s) with a mock: ${key} (${who})`);
	}
	const idle = armed.filter((key) => !servedKeys.includes(key));
	if (idle.length) lines.push(`  armed but not called during this run (can't explain it): ${idle.join(", ")}`);
	if (servedKeys.length) lines.push("  a mocked response answered this run — check it before calling the failure an app bug.");
	else lines.push("  no mocked response during this run — NetworkLens didn't cause this failure.");
	return { source, known: true, isMockingEnabled: state.isMockingEnabled, armed, served, suspicious: servedKeys.length > 0, lines };
}
