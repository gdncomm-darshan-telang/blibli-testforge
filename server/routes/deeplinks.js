// Deeplinks (D-157): the app's route list as fill-in templates, saved links, recent opens, and "open in the app"
// on the test simulator. Opening never relaunches the app and needs no test runner: `simctl openurl` hands the link
// to the running app, which pushes the target screen over the current one.
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { loadCatalog, matchUrl, normalizeLink, urlProblem } from "../lib/deeplinks.js";

const run = promisify(execFile);

export function registerDeeplinkRoutes(app, { catalogFile, store, deviceArg, deviceLock, refuseWhileTesting, confirmOpen = async () => false, appVersion = async () => null }) {
	let catalog = null;
	const catalogNow = async () => {
		catalog ??= await loadCatalog(catalogFile);
		return catalog;
	};

	app.get("/api/deeplinks", async (_req, res) => {
		try {
			// The installed QA build's version seeds the min-version presets (D-205); null when nothing is built.
			const [routes, state, version] = await Promise.all([catalogNow(), store.load(), appVersion().catch(() => null)]);
			res.json({ routes, saved: state.saved, history: state.history, source: catalogFile, appVersion: version });
		} catch (error) {
			res.status(500).json({ error: `couldn't read the route list: ${error.message}` });
		}
	});

	/** Which routes in the list would catch `url` (first = the one the app tries first). */
	app.post("/api/deeplinks/match", async (req, res) => {
		const url = normalizeLink(req.body?.url);
		res.json({ url, problem: urlProblem(url), matches: matchUrl(await catalogNow(), url) });
	});

	app.post("/api/deeplinks/open", async (req, res) => {
		const url = normalizeLink(req.body?.url);
		const problem = urlProblem(url);
		if (problem) return res.status(400).json({ error: problem });
		// A test drives the phone; a link opened under it would break the run.
		if (refuseWhileTesting(res)) return;
		if (!deviceLock.tryAcquire("deeplink", "Open link")) return res.status(409).json({ error: `the phone is busy — ${deviceLock.holder.label} is driving it` });
		const matched = matchUrl(await catalogNow(), url)[0]?.description ?? null;
		try {
			await run("xcrun", ["simctl", "openurl", deviceArg(), url], { timeout: 20_000 });
			// iOS asks "Open in “Blibli”?" for a link opened from outside the app; the harness taps Open when it's up.
			const isConfirmed = await confirmOpen().catch(() => false);
			await store.noteOpened({ url, ok: true, matched });
			res.json({ ok: true, url, device: deviceArg(), matched, isConfirmed, ...(!isConfirmed && { note: "if iOS asks “Open in Blibli?”, tap Open on the simulator" }) });
		} catch (error) {
			const raw = String(error.stderr || error.message).trim();
			// simctl's own wording for a shut-down device ("Unable to lookup in current state: Shutdown") says nothing useful.
			const reason = /current state: Shutdown/i.test(raw) ? "the test simulator isn't booted — boot it on the Simulator screen (⌘7)" : raw.split("\n").pop();
			await store.noteOpened({ url, ok: false, error: reason, matched });
			res.status(502).json({ error: `the simulator didn't open it: ${reason}` });
		} finally {
			deviceLock.release("deeplink");
		}
	});

	app.post("/api/deeplinks/saved", async (req, res) => {
		const url = normalizeLink(req.body?.url);
		const problem = urlProblem(url);
		if (problem) return res.status(400).json({ error: problem });
		res.json({ saved: await store.save({ name: req.body?.name, url }) });
	});

	app.delete("/api/deeplinks/saved/:id", async (req, res) => {
		res.json({ ok: await store.remove(req.params.id) });
	});
}
