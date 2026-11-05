// F3 (D-191): a batch that runs hands-free. Before it starts, the person sees everything that would otherwise stop
// it halfway — environment switches, logins, steps a person must do, Claude runs that need approval or usage — and
// the cases are ordered so each environment and session is set up once, not once per case.

const ENV_LABELS = { prod: "PROD", uatb: "UAT B" };

/** Recorded cases replay in an order that needs the fewest environment and login changes; Claude runs go last. */
export function orderForFewerSwitches(items, requiresOf, currentEnvironment = null) {
	const envRank = (env) => (!env || env === currentEnvironment ? 0 : 1);
	const keyed = items.map((item, index) => {
		const requires = item.mode === "replay" ? requiresOf(item.macroId) ?? {} : {};
		return { item, index, env: requires.environment ?? null, session: requires.session ?? null, isClaude: item.mode !== "replay" };
	});
	keyed.sort((first, second) =>
		Number(first.isClaude) - Number(second.isClaude)
		|| envRank(first.env) - envRank(second.env)
		|| String(first.env ?? "").localeCompare(String(second.env ?? ""))
		|| String(first.session ?? "").localeCompare(String(second.session ?? ""))
		|| first.index - second.index);
	return keyed.map((entry) => entry.item);
}

/** Counts each change of environment or session the ordered replays need, starting from the device's state. */
function countChanges(ordered, requiresOf, currentEnvironment) {
	let environment = currentEnvironment;
	let session = null;
	const switches = [];
	let logins = 0;
	let logouts = 0;
	for (const item of ordered.filter((entry) => entry.mode === "replay")) {
		const requires = requiresOf(item.macroId) ?? {};
		if (requires.environment && requires.environment !== environment) {
			switches.push({ to: requires.environment, label: ENV_LABELS[requires.environment] ?? requires.environment, beforeCase: item.caseId });
			environment = requires.environment;
			session = null;
		}
		if (requires.session && requires.session !== session) {
			if (requires.session === "loggedIn") logins++;
			else logouts++;
			session = requires.session;
		}
	}
	return { switches, logins, logouts };
}

/**
 * What a batch of these cases will do and what could stop it. `macroOf(id)` gives a v2 macro (for `requires` and
 * `manual` steps), `currentEnvironment` the device's, `canRunUnattended` whether Claude runs may go without approval.
 */
export function planBatch({ items, macroOf, currentEnvironment = null, canRunUnattended = false, usage = null }) {
	const requiresOf = (macroId) => macroOf(macroId)?.requires ?? null;
	const ordered = orderForFewerSwitches(items, requiresOf, currentEnvironment);
	const { switches, logins, logouts } = countChanges(ordered, requiresOf, currentEnvironment);
	const replays = ordered.filter((item) => item.mode === "replay");
	const claudeRuns = ordered.filter((item) => item.mode !== "replay");
	const manualCases = replays.filter((item) => (macroOf(item.macroId)?.steps ?? []).some((step) => step.do === "manual")).map((item) => item.caseId);
	const stops = [];
	if (claudeRuns.length && !canRunUnattended) stops.push({ id: "approval", text: `${claudeRuns.length} Claude run(s) ask before each tool use — this Mac doesn't allow unattended Claude runs` });
	if (manualCases.length) stops.push({ id: "manual", text: `${manualCases.join(", ")} ha${manualCases.length === 1 ? "s" : "ve"} a step a person must do; the batch waits up to 10 min at each` });
	if (claudeRuns.length && usage?.isNearLimit) stops.push({ id: "usage", text: `Claude usage is at ${usage.percent}% — a limit pauses the batch until it resets` });
	return {
		caseIds: ordered.map((item) => item.caseId),
		items: ordered,
		replayCount: replays.length,
		claudeCount: claudeRuns.length,
		environmentSwitches: switches,
		logins,
		logouts,
		manualCases,
		stops,
		isHandsFree: stops.length === 0,
	};
}
