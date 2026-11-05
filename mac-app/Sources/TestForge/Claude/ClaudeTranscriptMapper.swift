import Foundation

/// Session stream events (`lib/claude-session.js` records) → transcript rows; mirrors the web Sessions tab.
enum ClaudeTranscriptMapper {
	static func message(eventName: String, payload: JSONValue) -> ClaudeStreamMessage? {
		if eventName == "summary" {
			return payload.decoded(as: ClaudeSessionSummary.self).map(ClaudeStreamMessage.summary)
		}
		guard case .object(let event) = payload,
			let seq = event["seq"]?.intValue
		else {
			return nil
		}
		let type = event["type"]?.stringValue ?? ""
		if type == "dashboard",
			let kind = event["kind"]?.stringValue,
			kind.hasSuffix("-resolved"),
			let requestId = event["requestId"]?.stringValue {
			return .resolved(seq: seq, requestId: requestId, outcome: outcome(event["decision"]))
		}
		let kinds = transcriptKinds(type: type, event: event)
		guard !kinds.isEmpty else {
			return nil
		}
		let items = kinds.enumerated().map { index, kind in
			ClaudeTranscriptItem(id: "\(seq)-\(index)", kind: kind)
		}
		return .items(seq: seq, items: items)
	}

	static func statusTitle(_ status: String) -> String {
		switch status {
			case "running":
				return String(localized: "Working…")
			case "waiting-approval":
				return String(localized: "Needs your approval")
			case "waiting-answer":
				return String(localized: "Asking you a question")
			case "waiting-device":
				return String(localized: "Waiting for the phone")
			case "closed":
				return String(localized: "Closed")
			case "error":
				return String(localized: "Stopped with an error")
			default:
				return String(localized: "Ready")
		}
	}

	static func shortToolName(_ name: String) -> String {
		guard name.hasPrefix("mcp__") else {
			return name
		}
		let parts = name.components(separatedBy: "__")
		guard parts.count >= 3,
			let server = parts[safe: 1],
			let tool = parts[safe: 2]
		else {
			return name
		}
		let trimmedServer = server
			.replacingOccurrences(of: #"^plugin_[^_]+_"#, with: "", options: .regularExpression)
			.replacingOccurrences(of: "claude_ai_", with: "")
		return "\(trimmedServer) · \(tool)"
	}

	private static func transcriptKinds(type: String, event: [String: JSONValue]) -> [ClaudeTranscriptKind] {
		switch type {
			case "dashboard":
				return dashboardKinds(event: event)
			case "system":
				guard event["subtype"]?.stringValue == "init" else {
					return []
				}
				return [.started(model: event["model"]?.stringValue ?? "Claude")]
			case "assistant":
				// A subagent's own steps stay out of the main conversation, as on the web.
				guard event["parent_tool_use_id"]?.stringValue == nil else {
					return []
				}
				return contentParts(event).compactMap(assistantKind)
			case "user":
				return contentParts(event).compactMap(toolResultKind)
			case "result":
				let isError = event["is_error"]?.boolValue ?? false
				return isError ? [.notice(String(localized: "The turn ended with an error"), isError: true)] : []
			default:
				return []
		}
	}

	private static func dashboardKinds(event: [String: JSONValue]) -> [ClaudeTranscriptKind] {
		let text = event["text"]?.stringValue ?? ""
		let requestId = event["requestId"]?.stringValue ?? ""
		let toolName = event["toolName"]?.stringValue ?? ""
		switch event["kind"]?.stringValue {
			case "user":
				return [.user(text)]
			case "approval":
				return [.approval(requestId: requestId, toolName: shortToolName(toolName), detail: approvalDetail(event["input"]))]
			case "question":
				return [.question(requestId: requestId, questions: questions(event["input"]))]
			case "hard-deny":
				return [.notice(String(localized: "Blocked \(shortToolName(toolName)): \(text)"), isError: true)]
			case "interrupted":
				return [.notice(String(localized: "Stopped"), isError: false)]
			case "reopened":
				return [.notice(String(localized: "Reopened — Claude continues from where this session left off"), isError: false)]
			case "error":
				return [.notice(text, isError: true)]
			default:
				return []
		}
	}

	private static func contentParts(_ event: [String: JSONValue]) -> [[String: JSONValue]] {
		guard case .object(let message) = event["message"],
			case .array(let parts) = message["content"]
		else {
			return []
		}
		return parts.compactMap { part in
			guard case .object(let object) = part else {
				return nil
			}
			return object
		}
	}

	private static func assistantKind(_ part: [String: JSONValue]) -> ClaudeTranscriptKind? {
		switch part["type"]?.stringValue {
			case "text":
				let text = (part["text"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
				guard !text.isEmpty else {
					return nil
				}
				let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
				let rendered = (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
				return .assistant(rendered)
			case "tool_use":
				let name = shortToolName(part["name"]?.stringValue ?? "")
				return .tool(name: name, argument: keyArgument(part["input"]), detail: prettyJSON(part["input"]))
			default:
				return nil
		}
	}

	private static func toolResultKind(_ part: [String: JSONValue]) -> ClaudeTranscriptKind? {
		guard part["type"]?.stringValue == "tool_result" else {
			return nil
		}
		let isError = part["is_error"]?.boolValue ?? false
		let text = resultText(part["content"])
		let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
		guard !firstLine.isEmpty else {
			return nil
		}
		let preview = String(firstLine.prefix(ClaudeConstants.Transcript.resultPreviewLength))
		return .toolResult(preview, isError: isError, full: text)
	}

	private static func resultText(_ content: JSONValue?) -> String {
		switch content {
			case .string(let text):
				return text
			case .array(let pieces):
				let texts: [String] = pieces.compactMap { piece in
					guard case .object(let object) = piece else {
						return nil
					}
					return object["text"]?.stringValue
				}
				return texts.joined(separator: "\n")
			default:
				return ""
		}
	}

	private static func keyArgument(_ input: JSONValue?) -> String {
		guard case .object(let object) = input else {
			return ""
		}
		let keys = ["command", "file_path", "path", "pattern", "url", "query", "identifier", "label", "skill", "description"]
		let value = keys.lazy.compactMap { object[$0]?.stringValue }.first ?? ""
		return String(value.prefix(ClaudeConstants.Transcript.argumentLength))
	}

	private static func approvalDetail(_ input: JSONValue?) -> String {
		guard case .object(let object) = input else {
			return ""
		}
		if let command = object["command"]?.stringValue {
			return command
		}
		if let filePath = object["file_path"]?.stringValue {
			let change = object["new_string"]?.stringValue ?? object["content"]?.stringValue ?? ""
			return "\(filePath)\n\(change.prefix(ClaudeConstants.Transcript.approvalDetailLength))"
		}
		return String(prettyJSON(input).prefix(ClaudeConstants.Transcript.approvalDetailLength))
	}

	private static func prettyJSON(_ value: JSONValue?) -> String {
		guard let value else {
			return ""
		}
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
		let data = (try? encoder.encode(value)) ?? Data()
		return String(data: data, encoding: .utf8) ?? ""
	}

	private static func questions(_ input: JSONValue?) -> [ClaudeQuestion] {
		guard case .object(let object) = input,
			case .array(let list) = object["questions"]
		else {
			return []
		}
		return list.compactMap { entry in
			guard case .object(let question) = entry,
				let text = question["question"]?.stringValue
			else {
				return nil
			}
			return ClaudeQuestion(
				question: text,
				header: question["header"]?.stringValue ?? "",
				options: options(question["options"]),
				isMultiSelect: question["multiSelect"]?.boolValue ?? false
			)
		}
	}

	private static func options(_ value: JSONValue?) -> [ClaudeQuestionOption] {
		guard case .array(let list) = value else {
			return []
		}
		return list.compactMap { entry in
			guard case .object(let option) = entry,
				let label = option["label"]?.stringValue
			else {
				return nil
			}
			let detail = option["description"]?.stringValue ?? ""
			return ClaudeQuestionOption(label: label, detail: detail == label ? "" : detail)
		}
	}

	private static func outcome(_ decision: JSONValue?) -> String {
		guard case .object(let object) = decision else {
			return String(localized: "Answered")
		}
		guard object["behavior"]?.stringValue == "allow" else {
			let message = object["message"]?.stringValue ?? ""
			return message.isEmpty ? String(localized: "Denied") : String(localized: "Denied — \(message)")
		}
		if case .object(let answers) = object["answers"] {
			let picked = answers.values.compactMap(\.stringValue).filter { !$0.isEmpty }
			if !picked.isEmpty {
				return String(localized: "Answered: \(picked.joined(separator: " · "))")
			}
		}
		let isAlways = object["alwaysAllow"]?.boolValue ?? false
		return isAlways ? String(localized: "Approved (always)") : String(localized: "Approved")
	}
}

private extension JSONValue {
	var stringValue: String? {
		guard case .string(let value) = self else {
			return nil
		}
		return value
	}

	var intValue: Int? {
		guard case .number(let value) = self else {
			return nil
		}
		return Int(value)
	}

	var boolValue: Bool? {
		guard case .bool(let value) = self else {
			return nil
		}
		return value
	}
}
