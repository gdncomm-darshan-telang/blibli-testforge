// Local repositories: list, open interactive Claude in Terminal, reveal in Finder.
import { isKnownWorkspace, listProjects, openInTerminal, revealInFinder } from "../lib/projects.js";

export function registerProjectRoutes(app) {
	app.get("/api/projects", async (req, res) => {
		res.json({ projects: await listProjects({ refresh: req.query.refresh === "1" }) });
	});

	const guarded = (action) => async (req, res) => {
		const { dir } = req.body;
		if (!(await isKnownWorkspace(dir))) return res.status(400).json({ error: "not a known project folder" });
		try {
			await action(dir);
			res.json({ ok: true });
		} catch (error) {
			res.status(500).json({ error: error.message });
		}
	};
	app.post("/api/projects/open-terminal", guarded(openInTerminal));
	app.post("/api/projects/reveal", guarded(revealInFinder));
}
