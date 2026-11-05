// D-127: the app's settings go to the plist the app reads (its data container), never the bundle-id shared domain.
import { test } from "node:test";
import assert from "node:assert/strict";
import { deleteAppDefault, readAppDefault, writeAppDefault } from "../lib/app-defaults.js";

const CONTAINER = "/sim/data/Containers/Data/Application/APP";

function fakeExec(calls, { readOut = "1\n", failDelete } = {}) {
	return async (_command, args) => {
		calls.push(args);
		if (args[1] === "get_app_container") return { stdout: `${CONTAINER}\n` };
		if (args[4] === "delete" && failDelete) throw Object.assign(new Error("exit 1"), { stderr: failDelete });
		return { stdout: args[4] === "read" ? readOut : "" };
	};
}

test("read, write and delete address the container plist by path", async () => {
	const calls = [];
	const exec = fakeExec(calls);
	assert.equal(await readAppDefault({ udid: "U", bundleId: "com.app", key: "K", exec }), "1");
	await writeAppDefault({ udid: "U", bundleId: "com.app", key: "K", type: "bool", value: "YES", exec });
	await deleteAppDefault({ udid: "U", bundleId: "com.app", key: "K", exec });
	const domain = `${CONTAINER}/Library/Preferences/com.app`;
	const verbs = calls.filter((args) => args[3] === "defaults").map((args) => args.slice(4));
	assert.deepEqual(verbs, [["read", domain, "K"], ["write", domain, "K", "-bool", "YES"], ["delete", domain, "K"]]);
});

test("a missing key is null on read and fine on delete; other delete errors surface", async () => {
	const missing = async (_command, args) => {
		if (args[1] === "get_app_container") return { stdout: CONTAINER };
		throw new Error("does not exist");
	};
	assert.equal(await readAppDefault({ udid: "U", key: "K", exec: missing }), null);
	await deleteAppDefault({ udid: "U", key: "K", exec: fakeExec([], { failDelete: "The domain/default pair does not exist" }) });
	await assert.rejects(deleteAppDefault({ udid: "U", key: "K", exec: fakeExec([], { failDelete: "Permission denied" }) }));
});

test("unknown types are refused before anything runs", async () => {
	const calls = [];
	await assert.rejects(writeAppDefault({ udid: "U", key: "K", type: "data", value: "x", exec: fakeExec(calls) }));
	assert.equal(calls.length, 0);
});
