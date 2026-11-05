// D-130 (phase D): which app is live. The queue remembers every app that polled; the QA fork's phase-D build sends
// its simulator UDID with each poll, and commands are targeted at the test simulator, so "live" means *that* app.
// An older build polls anonymously: it still gets every command (it cannot be told apart), and health says so.

/** `pollers` from the queue (`{device, bundle, pid, at}`), `testUdid` = the test simulator or null when unresolved. */
export function pollHealth(pollers, { testUdid = null, now = Date.now(), freshMs = 5_000 } = {}) {
	const fresh = pollers.filter((entry) => now - entry.at < freshMs);
	const own = testUdid ? fresh.find((entry) => entry.device === testUdid) : fresh.find((entry) => entry.device);
	const anonymous = fresh.find((entry) => !entry.device);
	const live = own ?? anonymous ?? null;
	const newest = [...pollers].sort((lhs, rhs) => rhs.at - lhs.at)[0];
	return {
		isAppPolling: Boolean(live),
		lastPollMsAgo: live ? now - live.at : newest ? now - newest.at : null,
		pollingDevice: live?.device ?? null,
		// false: the app polling is a build without device identity — commands reach whichever app polls first.
		isIdentified: Boolean(own),
		// With the test simulator's own app live, an anonymous older build elsewhere is just another app.
		otherDevices: fresh
			.filter((entry) => entry !== live && (entry.device || own))
			.map((entry) => ({ device: entry.device, bundle: entry.bundle, msAgo: now - entry.at })),
	};
}
