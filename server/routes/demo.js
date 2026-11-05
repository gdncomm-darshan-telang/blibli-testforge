// Demo videos (D-164): write a case's plain-words notes once (Claude), record a demo replay, list recordings.
import { readdir, readFile, stat } from "node:fs/promises";
import { join } from "node:path";
import { LANGUAGES, demoNotesPrompt, mergeMockNotes, parseDemoNotes, saveMacroNotes } from "../lib/demo.js";

/**
 * `deps`: `findMacro(id)`, `describe(macro)` → `[{id, text, note}]` top-level steps in plain words,
 * `caseFor(macro)` → loaded test case or null, `mediaRoot()`, `guard(res)` → true when it already answered,
 * `enqueueDemo(macro)` → `{job}`, `runClaude`, `jobs {createJob, appendLine, finishJob}`.
 */
export function registerDemoRoutes(app, deps) {
	const { createJob, appendLine, finishJob } = deps.jobs;

	app.post("/api/demo/:macroId/notes", async (req, res) => {
		const macro = await deps.findMacro(req.params.macroId);
		if (!macro) return res.status(404).json({ error: "no such macro" });
		if (macro.demo && req.body?.overwrite !== true) return res.status(409).json({ error: "this macro already has demo notes — send overwrite: true to rewrite them", notes: macro.demo });
		const rows = await deps.describe(macro);
		const mocks = (macro.steps ?? []).filter((step) => step.do === "mock" && step.variant).map((step) => ({ endpoint: step.endpoint, variant: step.variant, note: step.note }));
		const prompt = demoNotesPrompt({ testCase: deps.caseFor(macro), macroName: macro.name, rows, mocks });
		const job = createJob({ kind: "demo-notes", macroId: macro.id });
		appendLine(job, `● writing demo notes for ${macro.name} (English + Bahasa)`);
		deps.runClaude(job, { prompt, args: ["--model", "sonnet", "--allowedTools", "Read", "--disallowedTools", "Bash", "Edit", "Write"] }).then(async ({ code, result }) => {
			try {
				const { notes, mocks: mockNotes } = parseDemoNotes(result?.text, rows.map((row) => row.id), mocks.map((mock) => mock.endpoint));
				await saveMacroNotes(macro.path, notes);
				const added = await mergeMockNotes(mockNotes);
				appendLine(job, `✓ ${Object.keys(notes.steps).length} step note(s) · ${added} new server-answer note(s)`);
				finishJob(job, { status: "done", verdict: "NOTES" });
			} catch (error) {
				appendLine(job, `! ${result ? error.message : `claude exited with code ${code}`}`);
				finishJob(job, { status: "error", verdict: "NO_NOTES" });
			}
		});
		res.status(202).json({ ok: true, jobId: job.id });
	});

	app.post("/api/demo/:macroId/record", async (req, res) => {
		const macro = await deps.findMacro(req.params.macroId);
		if (!macro) return res.status(404).json({ error: "no such macro" });
		if (await deps.guard(res)) return;
		const { job } = deps.enqueueDemo(macro);
		res.status(202).json({ ok: true, jobId: job.id, hasNotes: Boolean(macro.demo) });
	});

	/** Demo folders, newest first, with the files the renderer made. */
	app.get("/api/demo/recordings", async (_req, res) => {
		const root = deps.mediaRoot();
		if (!root) return res.json({ recordings: [] });
		const dir = join(root, "demos");
		const names = await readdir(dir).catch(() => []);
		const recordings = [];
		for (const name of names) {
			const folder = join(dir, name);
			const timeline = await readFile(join(folder, "timeline.json"), "utf8").then(JSON.parse).catch(() => null);
			if (!timeline) continue;
			const files = await readdir(folder).catch(() => []);
			const info = await stat(folder).catch(() => null);
			recordings.push({
				folder,
				caseId: timeline.caseId,
				macroName: timeline.macroName,
				verdict: timeline.verdict,
				recordedAt: timeline.recordedAt,
				hasNotes: Boolean(timeline.notes),
				videos: Object.fromEntries(LANGUAGES.map((lang) => [lang, files.includes(`demo-${lang}.mp4`) ? join(folder, `demo-${lang}.mp4`) : null])),
				subtitles: Object.fromEntries(LANGUAGES.map((lang) => [lang, files.includes(`demo-${lang}.vtt`) ? join(folder, `demo-${lang}.vtt`) : null])),
				modifiedMs: info?.mtimeMs ?? 0,
			});
		}
		res.json({ recordings: recordings.sort((left, right) => right.modifiedMs - left.modifiedMs) });
	});
}
