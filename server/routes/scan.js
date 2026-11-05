// Scan mode endpoints (D-086). The scan holds the device lock for its whole life: a test run would
// navigate away under the person walking the app, and both would poll the same harness.
const LOCK_OWNER = "scan-mode";

export function registerScanRoutes(app, { scan, deviceLock, busyReason }) {
	scan.on("end", () => deviceLock.release(LOCK_OWNER));

	app.get("/api/scan", (_req, res) => res.json(scan.view()));

	app.post("/api/scan/start", (_req, res) => {
		if (scan.isActive) return res.status(409).json({ error: "A scan is already running." });
		const busy = busyReason();
		if (busy) return res.status(409).json({ error: busy });
		if (!deviceLock.tryAcquire(LOCK_OWNER, "Scan mode")) {
			return res.status(409).json({ error: `The simulator is in use by ${deviceLock.status().holder?.label ?? "another task"}.` });
		}
		try {
			res.json({ ok: true, scan: scan.start() });
		} catch (error) {
			deviceLock.release(LOCK_OWNER);
			res.status(500).json({ error: error.message });
		}
	});

	app.post("/api/scan/mark", (req, res) => {
		const name = String(req.body?.name ?? "").trim();
		if (!name) return res.status(400).json({ error: "Name the screen first, e.g. “Cart — empty”." });
		sendCommand(res, () => scan.command("mark", name));
	});
	app.post("/api/scan/skip", (_req, res) => sendCommand(res, () => scan.command("skip")));
	app.post("/api/scan/stop", (_req, res) => sendCommand(res, () => scan.command("stop")));

	function sendCommand(res, command) {
		try {
			command();
			res.json({ ok: true });
		} catch (error) {
			res.status(409).json({ error: error.message });
		}
	}
}
