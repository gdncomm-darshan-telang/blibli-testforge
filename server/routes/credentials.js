// Logins (Keychain-backed, D-044) and the person-in-the-loop popups replays raise.
// Secrets only ever travel inbound: no route returns a password or OTP.
import { deleteCredential, listCredentials, saveCredential, STATIC_OTP_ENVIRONMENTS } from "../lib/credentials.js";
import { mailOtp } from "../lib/mail-otp.js";
import { sse } from "./sessions.js";

export function registerCredentialRoutes(app, { prompts }) {
	app.get("/api/credentials", async (_req, res) => {
		res.json({ logins: await listCredentials(), staticOtpEnvironments: [...STATIC_OTP_ENVIRONMENTS] });
	});

	app.post("/api/credentials", async (req, res) => {
		try {
			const { env, profile, email, password, otp } = req.body ?? {};
			res.json({ ok: true, login: await saveCredential({ env, profile, email, password, otp: otp || undefined }) });
		} catch (error) {
			res.status(400).json({ error: error.message });
		}
	});

	app.delete("/api/credentials/:env/:profile", async (req, res) => {
		try {
			await deleteCredential(req.params);
			res.json({ ok: true });
		} catch (error) {
			res.status(400).json({ error: error.message });
		}
	});

	// Outlook OTP reader (D-048): link starts a device-code sign-in; no route returns a token or code.
	app.get("/api/mail-otp", async (_req, res) => res.json(await mailOtp.status()));

	app.post("/api/mail-otp/link", async (_req, res) => {
		try {
			res.json(await mailOtp.startLink());
		} catch (error) {
			res.status(502).json({ error: error.message });
		}
	});

	app.delete("/api/mail-otp/link", async (_req, res) => {
		await mailOtp.unlink();
		res.json({ ok: true });
	});

	app.get("/api/prompts", (_req, res) => res.json({ prompts: prompts.list() }));

	app.get("/api/prompts/stream", (req, res) => {
		const send = sse(res);
		const push = () => send("prompts", { prompts: prompts.list() });
		push();
		prompts.on("change", push);
		req.on("close", () => prompts.off("change", push));
	});

	app.post("/api/prompts/:id", (req, res) => {
		const isAnswered = prompts.answer(req.params.id, req.body ?? {});
		if (!isAnswered) return res.status(404).json({ error: "that popup was already answered or has expired" });
		res.json({ ok: true });
	});
}
