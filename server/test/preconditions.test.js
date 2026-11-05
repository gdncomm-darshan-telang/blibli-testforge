import { test } from "node:test";
import assert from "node:assert/strict";
import { ENVIRONMENTS, ROUTINES, environmentFromCode, resolvePreconditions, usesMocks } from "../lib/preconditions.js";

function fakeDeps({ environment = "uatb", lens = "true", isLoggedOut = false, failing = [] } = {}) {
	const calls = [];
	const deps = {
		readEnvironment: async () => environment,
		readDefault: async () => lens,
		setDefault: async (key, value) => calls.push(`set ${key}=${value}`),
		relaunch: async () => (calls.push("relaunch"), { ok: true }),
		runRoutine: async (id) => (calls.push(id), failing.includes(id) ? { ok: false, verdict: "FAIL", reason: "boom" } : { ok: true }),
		probeLoggedOut: async () => (calls.push("probe"), isLoggedOut),
		say: () => {},
	};
	return { deps, calls };
}

test("environment codes map to keys, absent means PROD", () => {
	assert.equal(environmentFromCode("8"), "uatb");
	assert.equal(environmentFromCode(null), "prod");
	assert.equal(environmentFromCode("6"), "code-6");
});

test("nothing runs when the app already matches", async () => {
	const { deps, calls } = fakeDeps();
	const result = await resolvePreconditions({ environment: "uatb", session: "loggedIn", networkLens: true }, deps);
	assert.equal(result.ok, true);
	assert.deepEqual(calls, ["probe"]);
});

test("wrong environment: switch, lens back on, then log in without probing", async () => {
	const { deps, calls } = fakeDeps({ environment: "prod", lens: null });
	const result = await resolvePreconditions({ environment: "uatb", session: "loggedIn", networkLens: true }, deps);
	assert.equal(result.ok, true);
	assert.deepEqual(calls, [ENVIRONMENTS.uatb.switchMacro, "set NetworkLensEnabled=true", "relaunch", ENVIRONMENTS.uatb.loginMacro]);
});

test("logged in but the case needs logged out: log out", async () => {
	const { deps, calls } = fakeDeps();
	await resolvePreconditions({ session: "loggedOut" }, deps);
	assert.deepEqual(calls, ["probe", ROUTINES.logout]);
});

test("a failing routine blocks with a reason", async () => {
	const { deps } = fakeDeps({ isLoggedOut: true, failing: [ENVIRONMENTS.uatb.loginMacro] });
	const result = await resolvePreconditions({ session: "loggedIn" }, deps);
	assert.equal(result.ok, false);
	assert.match(result.reason, /couldn't log in: boom/);
});

test("mock steps imply NetworkLens", () => {
	assert.equal(usesMocks({ steps: [{ do: "mock" }] }), true);
	assert.equal(usesMocks({ steps: [{ do: "tap" }] }), false);
});

test("reloadHome relaunches after logging in (D-153)", async () => {
	const { deps, calls } = fakeDeps({ environment: "prod", isLoggedOut: true });
	const result = await resolvePreconditions({ environment: "prod", session: "loggedIn", reloadHome: true }, deps);
	assert.equal(result.ok, true);
	assert.deepEqual(calls, ["probe", ENVIRONMENTS.prod.loginMacro, "relaunch"]);
});

test("reloadHome does nothing when already logged in (D-153)", async () => {
	const { deps, calls } = fakeDeps({ environment: "prod" });
	const result = await resolvePreconditions({ environment: "prod", session: "loggedIn", reloadHome: true }, deps);
	assert.equal(result.ok, true);
	assert.deepEqual(calls, ["probe"]);
});

test("start screen: Home opens Home unless the test does it first; any screen only needs the app running", async () => {
	const home = fakeDeps();
	assert.deepEqual(await resolvePreconditions({ startScreen: "home" }, home.deps), { ok: true });
	assert.deepEqual(home.calls, [ROUTINES.openHome]);

	const itself = fakeDeps();
	await resolvePreconditions({ startScreen: "home" }, { ...itself.deps, runsRoutineFirst: (id) => id === ROUTINES.openHome });
	assert.deepEqual(itself.calls, []);

	const running = fakeDeps();
	await resolvePreconditions({ startScreen: "anyScreen" }, { ...running.deps, isAppRunning: async () => true });
	assert.deepEqual(running.calls, []);

	const stopped = fakeDeps();
	await resolvePreconditions({ startScreen: "anyScreen" }, { ...stopped.deps, isAppRunning: async () => false });
	assert.deepEqual(stopped.calls, [ROUTINES.openHome]);

	const unknown = fakeDeps();
	assert.deepEqual(await resolvePreconditions({ startScreen: "Cart" }, unknown.deps), { ok: true });
	assert.deepEqual(unknown.calls, []);

	const failing = fakeDeps({ failing: [ROUTINES.openHome] });
	const result = await resolvePreconditions({ startScreen: "home" }, failing.deps);
	assert.equal(result.ok, false);
	assert.match(result.reason, /start screen \(Home\)/);
});
