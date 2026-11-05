// Templates a URL path into an endpoint key, mirroring the app's own
// PathMatcher: a numeric, UUID, or >=16-char hex segment is volatile and
// becomes {id} so a rule written here matches the same request the app does.

const HEX16 = /^[0-9a-f]{16,}$/i;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const NUMERIC = /^[0-9]+$/;

function isVolatile(segment) {
	return NUMERIC.test(segment) || UUID.test(segment) || HEX16.test(segment);
}

export function templatePath(pathname) {
	return pathname
		.split("/")
		.map((segment) => (segment && isVolatile(segment) ? "{id}" : segment))
		.join("/");
}

/** Builds { endpointKey, query } from either a pasted full URL or a bare "METHOD /path". */
export function resolveEndpoint(method, input) {
	const trimmed = input.trim();
	try {
		const url = new URL(trimmed);
		const query = {};
		for (const [key, value] of url.searchParams.entries()) {
			query[key] = value;
		}
		return {
			endpointKey: `${method.toUpperCase()} ${templatePath(url.pathname)}`,
			query,
			host: url.host,
		};
	} catch {
		// Not a full URL — treat as a path, with an optional "METHOD /path" prefix.
		const match = trimmed.match(/^([A-Za-z]+)\s+(.+)$/);
		const path = match ? match[2] : trimmed;
		const verb = match ? match[1] : method;
		return { endpointKey: `${verb.toUpperCase()} ${templatePath(path)}`, query: {}, host: null };
	}
}
