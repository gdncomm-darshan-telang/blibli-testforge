import { test } from "node:test";
import assert from "node:assert/strict";
import { parseDevicectl } from "../lib/physical-devices.js";

const device = (name, tunnelState, extra = {}) => ({
	identifier: `id-${name}`,
	deviceProperties: { name, osVersionNumber: "18.6.2", developerModeStatus: "enabled" },
	hardwareProperties: { marketingName: "iPhone 13 Pro", platform: "iOS", reality: "physical", udid: `udid-${name}` },
	connectionProperties: { pairingState: "paired", tunnelState, transportType: "wired" },
	...extra,
});

test("D-197: paired devices, connected first, each with what stops tests on it", () => {
	const list = parseDevicectl({ result: { devices: [device("B", "unavailable"), device("A", "connected"), { hardwareProperties: { reality: "virtual" } }] } });
	assert.deepEqual(list.map((entry) => [entry.name, entry.isConnected, entry.connection]), [["A", true, "cable"], ["B", false, null]]);
	assert.equal(list[0].osVersion, "iOS 18.6.2");
	assert.equal(list[0].canRunTests, false);
	assert.match(list[1].blockers[0], /not connected/);
	assert.equal(list[0].blockers.length, 1);
	assert.deepEqual(parseDevicectl({}), []);
});
