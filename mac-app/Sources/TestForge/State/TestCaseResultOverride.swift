import Foundation

/// D-180: one change a person made to a case's result on the Tests page, with the reason they gave.
struct TestCaseResultOverride: Decodable, Equatable {
	let verdict: String
	let previousVerdict: String?
	let reason: String

	/// `strict` or `lenient`: how the next Claude run judges the case.
	let leniency: String

	let changedAt: Date?

	private enum CodingKeys: String, CodingKey {
		case verdict
		case previousVerdict
		case reason
		case leniency
		case changedAt = "at"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		verdict = (try? container.decodeIfPresent(String.self, forKey: .verdict)) ?? ""
		previousVerdict = try? container.decodeIfPresent(String.self, forKey: .previousVerdict)
		reason = (try? container.decodeIfPresent(String.self, forKey: .reason)) ?? ""
		leniency = (try? container.decodeIfPresent(String.self, forKey: .leniency)) ?? "strict"
		let changedText = try? container.decodeIfPresent(String.self, forKey: .changedAt)
		changedAt = changedText.flatMap { ServerDate.parse(text: $0) }
	}
}
