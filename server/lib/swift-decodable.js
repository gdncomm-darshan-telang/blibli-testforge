// Parses a hand-written Swift `Decodable`/`Codable` type's `init(from decoder:)` into a field list
// (name, wire key, optionality, scalar/enum/opaque kind) — so a mock-variant generator can target a
// field without needing Swift's actual type system (D-155). Two decode-line shapes exist in this
// codebase and both are handled:
//   - the explicit form: `x = try values.decodeIfPresent(Type.self, forKey: .x)` — type and
//     presence are both right there on the line.
//   - the subscript form, via this codebase's own `KeyedDecodingContainer` subscript extension
//     (Common/BM_Extension/BM_KeyedDecodingContainerExtension.swift — always returns `T?`):
//     `x = values[.x]` / `self.x = container[.x]` — no type literal at all, so the type has to come
//     from `x`'s own `let`/`var` declaration elsewhere in the same type.

const SCALAR_TYPES = new Set(["String", "Int", "Int8", "Int16", "Int32", "Int64", "UInt", "Double", "Float", "Bool"]);

const EXPLICIT_DECODE_RE = /^(?:self\.)?(_)?(\w+)\s*=\s*try\s+\w+\.decode(IfPresent)?\(\s*(.+?)\.self\s*,\s*forKey:\s*\.(\w+)\s*\)\s*$/;
const SUBSCRIPT_DECODE_RE = /^(?:self\.)?(_)?(\w+)\s*=\s*\w+\[\.(\w+)\]\s*$/;
const CONTAINER_LET_RE = /^let\s+\w+\s*=\s*try\s+decoder\.container/;
const PROPERTY_DECL_RE = /^(?:@\w+(?:\([^)]*\))?\s+)*(?:public\s+|private\s+|fileprivate\s+|internal\s+|open\s+|static\s+)*(?:let|var)\s+(\w+)\s*:\s*([^={\n]+?)\s*(?:=.*)?$/;

/** The index of the `}` matching the `{` at `openIndex`, or -1 if unbalanced. */
function findMatchingBrace(text, openIndex) {
	let depth = 0;
	for (let i = openIndex; i < text.length; i++) {
		if (text[i] === "{") depth++;
		else if (text[i] === "}") {
			depth--;
			if (depth === 0) return i;
		}
	}
	return -1;
}

/** The body of the first `{...}` block whose header matches `headerPattern` inside `text`. */
function blockAfter(text, headerPattern) {
	const match = headerPattern.exec(text);
	if (!match) return null;
	const openIndex = text.indexOf("{", match.index);
	if (openIndex === -1) return null;
	const closeIndex = findMatchingBrace(text, openIndex);
	if (closeIndex === -1) return null;
	return text.slice(openIndex + 1, closeIndex);
}

/** The body of a `struct`/`class`/`enum <typeName>` declaration, wherever it appears in `source`. */
function extractTypeBody(source, typeName) {
	return blockAfter(source, new RegExp(`\\b(?:struct|class|enum)\\s+${typeName}\\b[^{]*\\{`));
}

/** The body of an `enum <typeName>: String` declaration specifically (a raw-String enum). */
function extractStringEnumBody(source, typeName) {
	return blockAfter(source, new RegExp(`\\benum\\s+${typeName}\\s*:\\s*String\\b[^{]*\\{`));
}

function stripComment(line) {
	return line.replace(/\/\/.*$/, "").trim();
}

/** `case a, b, c` / `case x = "y"` lines inside an enum body, one entry per case. */
function parseCaseEntries(body) {
	const entries = [];
	const caseLineRe = /case\s+([^\n]+)/g;
	let match;
	while ((match = caseLineRe.exec(body))) {
		for (const raw of match[1].split(",")) {
			const clean = stripComment(raw);
			const entryMatch = /^(\w+)(?:\s*=\s*"([^"]*)")?$/.exec(clean);
			if (entryMatch) entries.push({ name: entryMatch[1], raw: entryMatch[2] });
		}
	}
	return entries;
}

/** property name -> wire key, from this type's `CodingKeys` enum; `null` when there isn't one
 *  (Swift still compiles `forKey: .x` / `values[.x]` against a synthesized CodingKeys whose raw
 *  value is `x`). */
function parseCodingKeys(typeBody) {
	const block = blockAfter(typeBody, /enum\s+CodingKeys\b/);
	if (block === null) return null;
	const map = new Map();
	for (const entry of parseCaseEntries(block)) map.set(entry.name, entry.raw ?? entry.name);
	return map;
}

/** A same-file raw-String enum's real wire values, excluding a no-literal fallback case
 *  (`case unknown`) — that's the decoder's own sentinel, never a value the backend sends. */
function parseEnumCases(source, typeName) {
	const body = extractStringEnumBody(source, typeName);
	if (body === null) return null;
	return parseCaseEntries(body)
		.filter((entry) => entry.raw !== undefined)
		.map((entry) => ({ name: entry.name, raw: entry.raw }));
}

/** property name -> its declared type text (e.g. `"[AttachProductL4Info]?"`), read from every
 *  `let`/`var` line in the type body. Only consulted for the subscript decode form, which carries
 *  no type literal of its own. A computed property (`var x: Int { ... }`) never matches — its line
 *  ends in `{`, which the type-capture group excludes and nothing after it satisfies `$`. */
function parsePropertyDecls(typeBody) {
	const map = new Map();
	for (const rawLine of typeBody.split("\n")) {
		const match = PROPERTY_DECL_RE.exec(stripComment(rawLine));
		if (match) map.set(match[1], match[2].trim());
	}
	return map;
}

/** Classifies one bare type token (no trailing `?`, no `.self`) against the whole file. */
function classifyType(rawType, source) {
	const trimmed = rawType.trim();
	const arrayMatch = /^\[\s*([\s\S]+?)\s*\]$/.exec(trimmed);
	if (arrayMatch) {
		const inner = arrayMatch[1];
		if (inner.includes(":")) return { isArray: false, kind: "opaque", skipReason: `dictionary-valued field (${trimmed}) unsupported in v1` };
		return { isArray: true, ...classifyScalarOrEnum(inner, source) };
	}
	return { isArray: false, ...classifyScalarOrEnum(trimmed, source) };
}

function classifyScalarOrEnum(typeName, source) {
	if (typeName === "SafeURL") return { kind: "scalar" };
	if (SCALAR_TYPES.has(typeName)) return { kind: "scalar" };
	const enumCases = parseEnumCases(source, typeName);
	if (enumCases !== null) return { kind: "enum", enumCases };
	return { kind: "opaque", skipReason: `nested/cross-file type "${typeName}" not resolved in v1 — mutated as a whole field only` };
}

/** A declared-type string (`"[AttachProductL4Info]?"`, `"URL?"`, `"Int"`) -> `{isOptional, ...classifyType}`. */
function classifyDeclaredType(declaredType, source) {
	const trimmed = declaredType.trim();
	const isOptional = trimmed.endsWith("?");
	const bare = isOptional ? trimmed.slice(0, -1).trim() : trimmed;
	return { isOptional, ...classifyType(bare, source) };
}

/**
 * One field per decode line in `initBody` — either shape. A line neither shape matches, or a
 * subscript line whose property has no resolvable declaration, is kept as a `kind: "unparsed"`
 * entry (`jsonKey: null`) rather than aborting the whole struct — one bad field must not hide the
 * rest.
 */
function parseInitFields(initBody, codingKeys, propertyTypes, source) {
	const fields = [];
	const wireKeyFor = (codingKeyCase) => (codingKeys ? (codingKeys.get(codingKeyCase) ?? codingKeyCase) : codingKeyCase);

	for (const rawLine of initBody.split("\n")) {
		const line = stripComment(rawLine);
		if (!line || CONTAINER_LET_RE.test(line)) continue;

		const explicit = EXPLICIT_DECODE_RE.exec(line);
		if (explicit) {
			const [, underscore, propName, ifPresent, rawType, codingKeyCase] = explicit;
			const classified = classifyType(rawType, source);
			fields.push({
				name: propName,
				jsonKey: wireKeyFor(codingKeyCase),
				swiftType: rawType.trim(),
				isArray: Boolean(classified.isArray),
				isOptional: Boolean(ifPresent) || Boolean(underscore),
				kind: classified.kind,
				...(classified.enumCases ? { enumCases: classified.enumCases } : {}),
				...(classified.skipReason ? { skipReason: classified.skipReason } : {}),
			});
			continue;
		}

		const subscripted = SUBSCRIPT_DECODE_RE.exec(line);
		if (subscripted) {
			const [, , propName, codingKeyCase] = subscripted;
			const declaredType = propertyTypes.get(propName);
			if (declaredType === undefined) {
				fields.push({ name: propName, jsonKey: null, kind: "unparsed", isOptional: null, isArray: false, skipReason: `couldn't find a stored property declaration for "${propName}" to learn its type (subscript decode)` });
				continue;
			}
			const classified = classifyDeclaredType(declaredType, source);
			fields.push({
				name: propName,
				jsonKey: wireKeyFor(codingKeyCase),
				swiftType: declaredType,
				isArray: Boolean(classified.isArray),
				isOptional: classified.isOptional,
				kind: classified.kind,
				...(classified.enumCases ? { enumCases: classified.enumCases } : {}),
				...(classified.skipReason ? { skipReason: classified.skipReason } : {}),
			});
			continue;
		}

		fields.push({ name: line.slice(0, 40), jsonKey: null, kind: "unparsed", isOptional: null, isArray: false, skipReason: `unparsed decode line: "${line}"` });
	}
	return fields;
}

/**
 * Parses `typeName`'s hand-written `init(from decoder:)` out of `source`. Returns one entry per
 * decoded field: `{ name, jsonKey, swiftType, isArray, isOptional, kind, enumCases?, skipReason? }`.
 * `kind` is `"scalar"` | `"enum"` | `"opaque"` (nested struct, cross-file type, or a dictionary —
 * v1 never recurses into any of these, only mutates the whole field) | `"unparsed"` (the decode
 * line didn't match either known shape, or a subscript line's property type couldn't be found;
 * `jsonKey` is `null` and the field is never mutated).
 */
export function parseDecodableFields(source, typeName) {
	const typeBody = extractTypeBody(source, typeName);
	if (typeBody === null) throw new Error(`no struct/class/enum named "${typeName}" found`);
	const codingKeys = parseCodingKeys(typeBody);
	const propertyTypes = parsePropertyDecls(typeBody);
	const initBody = blockAfter(typeBody, /init\s*\(\s*from\s+decoder\s*:/);
	if (initBody === null) throw new Error(`"${typeName}" has no init(from decoder:) — only hand-written Decodable inits are supported in v1`);
	return parseInitFields(initBody, codingKeys, propertyTypes, source);
}
