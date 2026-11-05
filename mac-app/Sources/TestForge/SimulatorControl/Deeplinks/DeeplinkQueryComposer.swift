import Foundation

struct DeeplinkQueryItem: Equatable, Identifiable {
	let id: UUID
	var name: String
	var value: String
}

/// Appends query parameters to a typed or built link as text, so custom `blibli://` links keep their exact shape.
enum DeeplinkQueryComposer {
	private static let allowed: CharacterSet = {
		var set = CharacterSet.urlQueryAllowed
		set.remove(charactersIn: "&=+#?")
		return set
	}()

	/// Rows without a name are skipped; an existing `?query` is extended and a `#fragment` stays last.
	static func link(_ base: String, adding items: [DeeplinkQueryItem]) -> String {
		let pairs = items.compactMap(pair)
		guard !base.isEmpty,
			!pairs.isEmpty
		else {
			return base
		}
		let parts = base.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
		let head = String(parts.first ?? "")
		let fragment = parts.count > 1 ? "#" + parts[1] : ""
		let separator: String
		if !head.contains("?") {
			separator = "?"
		} else if head.hasSuffix("?") || head.hasSuffix("&") {
			separator = ""
		} else {
			separator = "&"
		}
		return head + separator + pairs.joined(separator: "&") + fragment
	}

	private static func pair(_ item: DeeplinkQueryItem) -> String? {
		let name = item.name.trimmingCharacters(in: .whitespaces)
		guard !name.isEmpty else {
			return nil
		}
		return encode(name) + "=" + encode(item.value)
	}

	private static func encode(_ text: String) -> String {
		text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
	}
}
