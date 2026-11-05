// Which mock variant answered (D-163). The trace marks an exchange `isMockServed` but not which variant
// served it, so the served response is matched against each variant of the endpoint's rule: the same
// body bytes first; then, when a body was redacted or retimed on its way in, the same status and byte
// count; a served failure matches a variant whose step fails. Several equal candidates stay ambiguous
// rather than guessed.

const decode = (base64) => {
	try {
		return Buffer.from(String(base64 ?? ""), "base64");
	} catch {
		return Buffer.alloc(0);
	}
};

/** Every response a variant can serve, step by step (a scripted variant has several). */
function variantResponses(variant) {
	return (variant.steps ?? []).map((step) => {
		if (step.fail || step.failure) return { kind: "failure" };
		if (step.hang) return { kind: "hang" };
		const response = step.respond?._0;
		if (!response) return { kind: "other" };
		const body = decode(response.body);
		return { kind: "response", status: response.statusCode ?? 200, body, bytes: body.length, delay: Number(response.delay ?? 0) };
	});
}

/** The variant names that could have produced one served exchange, and how sure the match is. */
export function matchVariant(exchange, rule) {
	const response = exchange.response;
	const candidates = (rule?.variants ?? []).map((variant) => ({ name: variant.name, responses: variantResponses(variant) }));
	if (!response) {
		const failing = candidates.filter((entry) => entry.responses.some((item) => item.kind === "failure"));
		return { variants: failing.map((entry) => entry.name), match: failing.length ? "failure" : null };
	}
	const served = decode(response.body);
	const status = response.statusCode ?? 200;
	if (!response.bodyTruncated) {
		const exact = candidates.filter((entry) => entry.responses.some((item) => item.kind === "response" && item.status === status && item.body.equals(served)));
		if (exact.length) return byTiming(exact, exchange, "exact");
	}
	const bytes = response.originalBodyByteCount ?? served.length;
	const sized = candidates.filter((entry) => entry.responses.some((item) => item.kind === "response" && item.status === status && item.bytes === bytes));
	return sized.length ? byTiming(sized, exchange, "size") : { variants: [], match: null };
}

/**
 * Same body, different delay (`loaded` vs `slow`): the trace's total time picks the variant whose delay
 * is closest. Without a recorded time, or when delays tie, every candidate stays.
 */
function byTiming(candidates, exchange, match) {
	const total = exchange.timing?.total;
	const delays = candidates.map((entry) => Math.max(...entry.responses.filter((item) => item.kind === "response").map((item) => item.delay)));
	if (candidates.length < 2 || typeof total !== "number" || new Set(delays).size < 2) return { variants: candidates.map((entry) => entry.name), match };
	const distances = delays.map((delay) => Math.abs(delay - total));
	const closest = Math.min(...distances);
	return { variants: candidates.filter((_, index) => distances[index] === closest).map((entry) => entry.name), match: `${match}+timing` };
}

/**
 * Per endpoint, the variants served between two times: `[{endpoint, variant, match, count}]`, one row
 * per distinct variant (or `variant: null` when nothing matches). `rules` are NetworkLens rules.
 */
export function variantsServed(records, rules, { since = 0, until = Infinity } = {}) {
	// A device can hold several rules for one endpoint (an old one left switched off): match across all of them.
	const byEndpoint = new Map();
	for (const rule of rules) {
		const merged = byEndpoint.get(rule.endpointKey) ?? { endpointKey: rule.endpointKey, variants: [] };
		for (const variant of rule.variants ?? []) if (!merged.variants.some((entry) => entry.name === variant.name)) merged.variants.push(variant);
		byEndpoint.set(rule.endpointKey, merged);
	}
	const rows = new Map();
	for (const record of records) {
		const exchange = record?.exchange;
		if (!exchange?.isMockServed) continue;
		const at = new Date(record.recordedAt).getTime();
		if (at < since || at > until) continue;
		const endpoint = exchange.endpointKey ?? "(no endpoint key)";
		const { variants, match } = matchVariant(exchange, byEndpoint.get(endpoint));
		const variant = variants.length === 1 ? variants[0] : null;
		const key = `${endpoint}\u0000${variant ?? variants.join("|")}`;
		const row = rows.get(key) ?? { endpoint, variant, match: variants.length > 1 ? "ambiguous" : match, count: 0, ...(variants.length > 1 ? { candidates: variants } : {}) };
		row.count += 1;
		rows.set(key, row);
	}
	return [...rows.values()];
}

/** The variants a macro's own `mock` steps arm, in order — what a replay will serve. */
export function variantsArmedBy(steps) {
	const armed = [];
	for (const step of steps) {
		if (step.do !== "mock" || step.enabled === false || !step.variant) continue;
		if (!armed.some((entry) => entry.endpoint === step.endpoint && entry.variant === step.variant)) armed.push({ endpoint: step.endpoint, variant: step.variant, match: "macro" });
	}
	return armed;
}
