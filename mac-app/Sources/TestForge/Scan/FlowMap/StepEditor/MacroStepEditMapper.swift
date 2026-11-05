import Foundation

/// Turns edited steps into the `PUT /api/macros/v2/:id/steps` body: the new order plus only the values that changed.
enum MacroStepEditMapper {
	static func body(original: [MacroStep], edited: [MacroStep]) -> [String: JSONValue] {
		let originalById = Dictionary(uniqueKeysWithValues: original.map { ($0.id, $0) })
		var changes: [String: JSONValue] = [:]
		for step in edited {
			guard let before = originalById[step.id] else {
				continue
			}
			let fieldChanges = changedFields(before: before, after: step)
			if !fieldChanges.isEmpty {
				changes[step.id] = .object(fieldChanges)
			}
		}
		return ["order": .array(edited.map { .string($0.id) }), "changes": .object(changes)]
	}

	private static func changedFields(before: MacroStep, after: MacroStep) -> [String: JSONValue] {
		var fields: [String: JSONValue] = [:]
		if after.canChangeTimeout,
			let timeout = after.timeout,
			timeout != before.timeout {
			fields[MacroStepField.timeout] = .number(timeout)
		}
		if after.canChangeOptional, after.isOptional != before.isOptional {
			fields[MacroStepField.optional] = .bool(after.isOptional)
		}
		if after.canChangeText,
			let text = after.typedText,
			text != before.typedText {
			fields[MacroStepField.text] = .string(text)
		}
		if after.canChangeSeconds,
			let seconds = after.seconds,
			seconds != before.seconds {
			fields[MacroStepField.seconds] = .number(seconds)
		}
		if after.canChangeName,
			let name = after.name,
			name != before.name {
			fields[MacroStepField.name] = .string(name)
		}
		return fields
	}
}
