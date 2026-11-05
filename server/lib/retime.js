// Mock bodies captured with absolute times go stale: a Flash Sale schedule captured on Monday has no
// "Tomorrow" slot by Wednesday. A `mock` step with `retime: true` moves every epoch-millisecond
// timestamp in the served body by one shared offset, so the earliest one lands an hour before now
// and the gaps between them — today's slot, tomorrow's slot — stay exactly as captured (D-058).
const MIN_EPOCH_MS = Date.UTC(2015, 0, 1);
const MAX_EPOCH_MS = Date.UTC(2045, 0, 1);
const LEAD_MS = 60 * 60 * 1000;

const isEpochMs = (value) => Number.isInteger(value) && value >= MIN_EPOCH_MS && value <= MAX_EPOCH_MS;

function collect(node, found) {
	if (Array.isArray(node)) node.forEach((item) => collect(item, found));
	else if (node && typeof node === "object") Object.values(node).forEach((item) => collect(item, found));
	else if (isEpochMs(node)) found.push(node);
	return found;
}

function shift(node, delta) {
	if (Array.isArray(node)) return node.map((item) => shift(item, delta));
	if (node && typeof node === "object") return Object.fromEntries(Object.entries(node).map(([key, item]) => [key, shift(item, delta)]));
	return isEpochMs(node) ? node + delta : node;
}

/** Returns `{ body, delta, count }`; a body that isn't JSON or has no timestamps comes back unchanged. */
export function retimeBody(buffer, now = Date.now()) {
	let parsed;
	try {
		parsed = JSON.parse(buffer.toString("utf8"));
	} catch {
		return { body: buffer, delta: 0, count: 0 };
	}
	const stamps = collect(parsed, []);
	if (stamps.length === 0) return { body: buffer, delta: 0, count: 0 };
	const delta = now - LEAD_MS - Math.min(...stamps);
	return { body: Buffer.from(JSON.stringify(shift(parsed, delta)), "utf8"), delta, count: stamps.length };
}
