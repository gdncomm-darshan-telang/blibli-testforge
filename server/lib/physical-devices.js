// F7 (D-197): iPhones and iPads paired with this Mac, from `xcrun devicectl list devices --json-output`, so the
// TestForge can show them beside the simulators. Running tests on one is not wired yet; `blockers` says what's missing.

const CONNECTED = new Set(["connected"]);

/** One devicectl device → what the TestForge shows; null for anything that isn't real hardware. */
export function physicalDeviceView(device) {
	const hardware = device?.hardwareProperties ?? {};
	const properties = device?.deviceProperties ?? {};
	const connection = device?.connectionProperties ?? {};
	if (hardware.reality && hardware.reality !== "physical") return null;
	const isConnected = CONNECTED.has(connection.tunnelState);
	const isPaired = connection.pairingState === "paired";
	const isDeveloperModeOn = properties.developerModeStatus === "enabled";
	const blockers = [];
	if (!isPaired) blockers.push("not paired with this Mac — connect it by cable and trust this Mac");
	else if (!isConnected) blockers.push("not connected — plug it in or join the same Wi-Fi, unlocked");
	if (!isDeveloperModeOn) blockers.push("Developer Mode is off (Settings › Privacy & Security)");
	blockers.push("tests need a device build of the app and the test runner, signed for this device — not set up yet");
	return {
		id: device.identifier,
		udid: hardware.udid ?? null,
		name: properties.name ?? hardware.marketingName ?? "iPhone",
		model: hardware.marketingName ?? hardware.productType ?? null,
		osVersion: properties.osVersionNumber ? `${hardware.platform ?? "iOS"} ${properties.osVersionNumber}` : null,
		connection: isConnected ? (connection.transportType === "wired" ? "cable" : "network") : null,
		isPaired,
		isConnected,
		isDeveloperModeOn,
		canRunTests: false,
		blockers,
	};
}

export function parseDevicectl(json) {
	const devices = json?.result?.devices ?? [];
	return devices.map(physicalDeviceView).filter(Boolean).sort((first, second) => Number(second.isConnected) - Number(first.isConnected) || first.name.localeCompare(second.name));
}
