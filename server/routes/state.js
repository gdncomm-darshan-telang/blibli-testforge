// The one live state stream (D-077): a page (or the Mac app) connects once, gets a snapshot of every
// slice, then a `patch` event whenever a slice changes. It replaces `/api/events` and every polling
// timer in the page.
import { sse } from "./sessions.js";

/** Slices re-read after a POST under these paths, so an action shows its effect at once. */
const POKES = [
	[/^\/api\/(mocks|mocking|lens)/, ["mocks", "status"]],
	[/^\/api\/harness/, ["harness", "readiness"]],
	[/^\/api\/(driver|simulator|device)/, ["device", "trace", "status"]],
	[/^\/api\/(code|build|qa-)/, ["code", "build", "readiness"]],
	[/^\/api\/(batch|setups)/, ["batch"]],
	[/^\/api\/(testcases|macros)/, ["readiness", "testcases"]],
];

export function registerStateRoutes(app, { hub }) {
	app.use((req, res, next) => {
		if (req.method !== "GET" && req.path.startsWith("/api/")) {
			res.on("finish", () => {
				for (const [pattern, names] of POKES) if (pattern.test(req.path)) names.forEach((name) => hub.poke(name));
			});
		}
		next();
	});

	app.get("/api/state", (_req, res) => res.json(hub.snapshot()));

	app.get("/api/state/stream", (req, res) => {
		const send = sse(res);
		send("snapshot", hub.snapshot());
		const unsubscribe = hub.subscribe((patch) => send("patch", patch));
		req.on("close", unsubscribe);
	});
}
