// Queue operations. Pages learn about task, session and device-lock changes from the live state
// stream (`/api/state/stream`, D-077), which replaced this file's old `/api/events` feed.

export function registerTaskRoutes(app, { tasks, deviceLock }) {
	app.get("/api/tasks", (_req, res) => res.json({ tasks: tasks.list(), device: deviceLock.status() }));

	app.post("/api/tasks", (req, res) => {
		const { kind = "claude", title, payload, links } = req.body;
		if (kind === "claude" && !payload?.prompt?.trim()) return res.status(400).json({ error: "prompt is required" });
		try {
			res.json({ task: tasks.enqueue({ kind, title: title || payload.prompt.slice(0, 80), payload, links }) });
		} catch (error) {
			res.status(400).json({ error: error.message });
		}
	});

	app.post("/api/tasks/clear-finished", (_req, res) => res.json({ cleared: tasks.clearFinished() }));

	app.post("/api/tasks/:id/cancel", (req, res) => {
		if (!tasks.cancel(req.params.id)) return res.status(409).json({ error: "task is not queued or running" });
		res.json({ ok: true });
	});

	app.post("/api/tasks/:id/move", (req, res) => {
		if (!tasks.move(req.params.id, req.body.direction === "up" ? -1 : 1)) return res.status(409).json({ error: "can't move that task" });
		res.json({ ok: true });
	});

	app.post("/api/tasks/:id/retry", (req, res) => {
		const task = tasks.retry(req.params.id);
		if (!task) return res.status(409).json({ error: "only finished tasks can be retried" });
		res.json({ task });
	});

	app.get("/api/device/lock", (_req, res) => res.json(deviceLock.status()));
}
