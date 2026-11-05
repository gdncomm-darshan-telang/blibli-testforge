// F5 (D-195): what a case's recording feeds the app — the deeplinks it opens and the mocked responses it arms — so
// the Tests detail can show and download them without anyone reading the macro or the NetworkLens session.

/** `steps` are a macro's flattened steps (routines included). */
export function macroInputs(steps) {
	const deeplinks = [];
	const mocks = [];
	for (const step of steps) {
		if (["openDeeplink", "openUrl"].includes(step.do) && step.url && !deeplinks.includes(step.url)) deeplinks.push(step.url);
		if (step.do === "mock" && step.endpoint) {
			const key = `${step.endpoint}|${step.variant ?? ""}|${step.enabled !== false}`;
			if (!mocks.some((entry) => entry.key === key)) mocks.push({ key, endpoint: step.endpoint, variant: step.enabled === false ? null : step.variant ?? null, isOff: step.enabled === false, atLaunch: Boolean(step.atLaunch) });
		}
	}
	return { deeplinks, mocks: mocks.map(({ key, ...entry }) => entry) };
}

const matchesEndpoint = (rule, endpoint) => {
	const key = String(rule.endpointKey ?? "");
	return key === endpoint || key.endsWith(` ${endpoint}`) || key.includes(endpoint);
};

/** The armed variant's response from the NetworkLens session: status, content type and decoded body; null when absent. */
export function mockResponse(sessionRules, endpoint, variantName) {
	const rule = (sessionRules ?? []).find((entry) => matchesEndpoint(entry, endpoint));
	const variant = rule?.variants?.find((entry) => entry.name === variantName);
	const response = variant?.steps?.map((entry) => entry.respond?._0).find(Boolean);
	if (!response) return null;
	const body = typeof response.body === "string" ? Buffer.from(response.body, "base64").toString("utf8") : "";
	const contentType = Object.entries(response.headers ?? {}).find(([name]) => name.toLowerCase() === "content-type")?.[1] ?? "application/json";
	return { status: response.status ?? 200, contentType, body, endpointKey: rule.endpointKey };
}
