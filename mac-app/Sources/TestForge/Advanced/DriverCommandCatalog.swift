import Foundation

enum DriverFieldKind: Equatable {
	case text
	case number
	case toggle
}

struct DriverCommandField: Equatable, Identifiable {
	let name: String
	let prompt: String
	let kind: DriverFieldKind
	let isRequired: Bool

	var id: String {
		name
	}
}

struct DriverCommandSpec: Equatable, Identifiable {
	let kind: String
	let title: String
	let fields: [DriverCommandField]

	/// Relaunching drops whatever screen a person had open, so it asks first.
	let needsConfirmation: Bool

	var id: String {
		kind
	}
}

/// One entry per kind in `contracts/commands.md`, matching the web Driver console's form list.
enum DriverCommandCatalog {
	static let all: [DriverCommandSpec] = [
		spec(kind: "deviceInfo", title: "Device info"),
		spec(kind: "dumpTree", title: "Dump tree", fields: [optional("identifier", "Scope identifier"), optional("elementType", "Element type")]),
		spec(kind: "screenshot", title: "Screenshot", fields: [
			required("label", "Label"),
			optional("mustBeVisible", "Identifier that must be visible")
		]),
		spec(kind: "tap", title: "Tap", fields: [
			required("identifier", "Identifier"),
			optional("elementType", "Element type"),
			toggle("force", "Force")
		]),
		spec(kind: "tapByLabel", title: "Tap by label", fields: [required("label", "Visible label"), toggle("force", "Force")]),
		spec(kind: "type", title: "Type text", fields: [
			required("identifier", "Identifier"),
			required("text", "Text"),
			toggle("keepKeyboard", "Keep keyboard up")
		]),
		spec(kind: "swipe", title: "Swipe", fields: [
			required("direction", "up / down / left / right"),
			optional("scrollViewIdentifier", "Scroll view identifier")
		]),
		spec(kind: "scrollUntilExists", title: "Scroll until exists", fields: [
			required("identifier", "Identifier"),
			optional("scrollViewIdentifier", "Scroll view identifier")
		]),
		spec(kind: "scrollToTop", title: "Scroll to top", fields: [
			optional("identifier", "Identifier"),
			optional("scrollViewIdentifier", "Scroll view identifier")
		]),
		spec(kind: "waitForExists", title: "Wait for exists", fields: [required("identifier", "Identifier"), number("timeout", "Timeout (seconds)")]),
		spec(kind: "waitForNotExists", title: "Wait for not-exists", fields: [
			required("identifier", "Identifier"),
			number("timeout", "Timeout (seconds)")
		]),
		spec(kind: "assertExists", title: "Assert exists", fields: [required("identifier", "Identifier")]),
		spec(kind: "getLabel", title: "Get label", fields: [required("identifier", "Identifier")]),
		spec(kind: "getLabels", title: "Get labels", fields: [
			optional("containerIdentifier", "Container identifier"),
			optional("elementType", "Element type")
		]),
		spec(kind: "getElementCount", title: "Get element count", fields: [required("containerIdentifier", "Container identifier")]),
		spec(kind: "getFrame", title: "Get frame", fields: [required("identifier", "Identifier")]),
		spec(kind: "alertTap", title: "Tap alert button", fields: [required("buttonTitle", "Button title")]),
		spec(kind: "dismissKeyboard", title: "Dismiss keyboard"),
		spec(kind: "openDeeplink", title: "Open deeplink", fields: [required("url", "blibli://…")]),
		DriverCommandSpec(kind: "relaunchApp", title: String(localized: "Relaunch app"), fields: [], needsConfirmation: true)
	]

	private static func spec(kind: String, title: String.LocalizationValue, fields: [DriverCommandField] = []) -> DriverCommandSpec {
		DriverCommandSpec(kind: kind, title: String(localized: title), fields: fields, needsConfirmation: false)
	}

	private static func required(_ name: String, _ prompt: String.LocalizationValue) -> DriverCommandField {
		DriverCommandField(name: name, prompt: String(localized: prompt), kind: .text, isRequired: true)
	}

	private static func optional(_ name: String, _ prompt: String.LocalizationValue) -> DriverCommandField {
		DriverCommandField(name: name, prompt: String(localized: prompt), kind: .text, isRequired: false)
	}

	private static func number(_ name: String, _ prompt: String.LocalizationValue) -> DriverCommandField {
		DriverCommandField(name: name, prompt: String(localized: prompt), kind: .number, isRequired: false)
	}

	private static func toggle(_ name: String, _ prompt: String.LocalizationValue) -> DriverCommandField {
		DriverCommandField(name: name, prompt: String(localized: prompt), kind: .toggle, isRequired: false)
	}
}
