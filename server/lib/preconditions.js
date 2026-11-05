// Automatic preconditions (D-051). A macro states what it needs —
//   "requires": { "environment": "uatb", "session": "loggedIn", "networkLens": true, "startScreen": "home" }
// — and the replay brings the app there first, doing only what is missing: the environment is read
// from the app's settings (no UI), the session is probed on Home, and the switch / login / logout
// routines run only on a mismatch. People pick a test, never a setup macro.
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { deviceArg } from "./test-device.js";
import { DEFAULT_BUNDLE_ID, readAppDefault as readSimulatorAppDefault } from "./app-defaults.js";

const run = promisify(execFile);

/** `BM_AppEnvironmentStoredValue` codes (BlibliCoreNetwork `BM_EnvironmentType`; 0/absent = PROD). */
export const ENVIRONMENTS = {
	prod: { code: 1, label: "PROD", switchMacro: "mc_F649LJ7QKN", loginMacro: "mc_F5BUCDH5ET" },
	uatb: { code: 8, label: "UAT B", switchMacro: "mc_F649LIVYQ5", loginMacro: "mc_F5BUCDH5ET" },
	preprod: { code: 9, label: "PRE PROD", switchMacro: "mc_F649LJRNKK", loginMacro: "mc_F5BUCDH5ET" },
};
export const ROUTINES = { openHome: "mc_EAH97EMYH5", logout: "mc_FD3GLFFJWN" };

/**
 * The screen a case expects the app on before its first step (`requires.startScreen`). `anyScreen` is for a case
 * that opens its own page by deeplink: deeplinks open over whatever is showing (D-157), so it only needs the app up.
 */
export const START_SCREENS = {
	home: { label: "Home", routine: ROUTINES.openHome },
	anyScreen: { label: "any screen (the test opens its own page)" },
	freshLaunch: { label: "a fresh launch (the test relaunches the app itself)", isSelfStarting: true },
};
export const HOME_LOGIN_ELEMENT = "el_EDI127XJPR";
const SESSIONS = new Set(["loggedIn", "loggedOut"]);

export function environmentFromCode(code) {
	const value = Number(code) || ENVIRONMENTS.prod.code;
	return Object.entries(ENVIRONMENTS).find(([, environment]) => environment.code === value)?.[0] ?? `code-${value}`;
}

const labelOf = (key) => ENVIRONMENTS[key]?.label ?? key;

/**
 * Reads one of the app's settings on the test simulator; null when absent. Through the simulator's preferences service
 * and the app's own plist (D-127): the file on disk lags behind (D-058), and the bundle-id domain is not the app's.
 * Booleans come back as "1" / "0".
 */
export async function readAppDefault(key, bundleId = DEFAULT_BUNDLE_ID) {
	return readSimulatorAppDefault({ udid: deviceArg(), bundleId, key });
}

export async function readEnvironment() {
	return environmentFromCode(await readAppDefault("BM_AppEnvironmentStoredValue"));
}

/** True when a macro has `mock` steps, which only work with NetworkLens switched on in the app. */
export function usesMocks(macro) {
	return (macro.steps ?? []).some((step) => step.do === "mock");
}

/**
 * Brings the app to `requires`. Returns `{ ok, reason }`; each action is reported through `say`.
 * Deps are injected so the decision logic is testable without a simulator.
 */
export async function resolvePreconditions(requires, deps) {
	const { readEnvironment: readEnv, readDefault, setDefault, relaunch, runRoutine, probeLoggedOut, say, isAppRunning = async () => true, runsRoutineFirst = () => false } = deps;
	if (!requires) return { ok: true };
	let isLoggedOut = null;

	if (requires.environment) {
		const wanted = ENVIRONMENTS[requires.environment];
		if (!wanted) return { ok: false, reason: `unknown environment “${requires.environment}”` };
		const current = await readEnv();
		if (current === requires.environment) {
			say(`✓ precondition: environment is already ${wanted.label}`);
		} else {
			say(`⚙ precondition: environment ${labelOf(current)} → ${wanted.label}`);
			const switched = await runRoutine(wanted.switchMacro);
			if (!switched.ok) return { ok: false, reason: `couldn't switch to ${wanted.label}: ${switched.reason ?? switched.verdict}` };
			isLoggedOut = true;
		}
	}

	if (requires.networkLens) {
		// An environment switch wipes the app's settings, NetworkLensEnabled included; the lens reads
		// it at launch, hence the relaunch.
		if (!["true", "1"].includes(await readDefault("NetworkLensEnabled"))) {
			say("⚙ precondition: turning NetworkLens on and relaunching the app");
			await setDefault("NetworkLensEnabled", true);
			const relaunched = await relaunch();
			if (!relaunched.ok) return { ok: false, reason: `couldn't relaunch after turning NetworkLens on: ${relaunched.reason ?? relaunched.verdict}` };
		}
	}

	if (requires.session) {
		if (!SESSIONS.has(requires.session)) return { ok: false, reason: `unknown session “${requires.session}”` };
		if (isLoggedOut === null) isLoggedOut = await probeLoggedOut();
		const isLoggedIn = !isLoggedOut;
		if (requires.session === "loggedIn" && !isLoggedIn) {
			const environment = requires.environment ?? (await readEnv());
			const loginMacro = ENVIRONMENTS[environment]?.loginMacro ?? ENVIRONMENTS.uatb.loginMacro;
			say(`⚙ precondition: logging in (${labelOf(environment)})`);
			const loggedIn = await runRoutine(loginMacro);
			if (!loggedIn.ok) return { ok: false, reason: `couldn't log in: ${loggedIn.reason ?? loggedIn.verdict}` };
			// D-153: some Home sections (the Flash Sale revamp) load only for a logged-in user — reload Home after logging in.
			if (requires.reloadHome) {
				say("⚙ precondition: relaunching so Home loads for the logged-in user");
				const relaunched = await relaunch();
				if (!relaunched.ok) return { ok: false, reason: `couldn't relaunch after logging in: ${relaunched.reason ?? relaunched.verdict}` };
			}
		} else if (requires.session === "loggedOut" && isLoggedIn) {
			say("⚙ precondition: logging out");
			const loggedOut = await runRoutine(ROUTINES.logout);
			if (!loggedOut.ok) return { ok: false, reason: `couldn't log out: ${loggedOut.reason ?? loggedOut.verdict}` };
		} else {
			say(`✓ precondition: already ${isLoggedIn ? "logged in" : "logged out"}`);
		}
	}

	if (requires.startScreen) return reachStartScreen(requires.startScreen, { runRoutine, isAppRunning, runsRoutineFirst, say });
	return { ok: true };
}

/** Only what is straightforward: a known routine, or starting the app; any other screen is left to the test. */
async function reachStartScreen(key, { runRoutine, isAppRunning, runsRoutineFirst, say }) {
	const screen = START_SCREENS[key];
	if (!screen) {
		say(`⚠ precondition: no known way to reach the start screen “${key}” — starting where the app is`);
		return { ok: true };
	}
	if (screen.isSelfStarting) {
		say(`✓ precondition: the test starts from ${screen.label}`);
		return { ok: true };
	}
	if (screen.routine && runsRoutineFirst(screen.routine)) {
		say(`✓ precondition: the test opens ${screen.label} itself`);
		return { ok: true };
	}
	if (!screen.routine && (await isAppRunning())) {
		say(`✓ precondition: the app is running — the test starts on ${screen.label}`);
		return { ok: true };
	}
	const routine = screen.routine ?? START_SCREENS.home.routine;
	say(`⚙ precondition: ${screen.routine ? `opening ${screen.label}` : "starting the app"}`);
	const reached = await runRoutine(routine);
	return reached.ok ? { ok: true } : { ok: false, reason: `couldn't reach the start screen (${screen.label}): ${reached.reason ?? reached.verdict}` };
}
