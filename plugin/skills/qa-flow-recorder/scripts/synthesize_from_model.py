#!/usr/bin/env python3
"""Synthesizes a schema-conformant response body straight from a Swift `Codable` type.

The safety net under `capture_baseline.py`'s trust ladder: when an endpoint has never answered for
real and no pack variant seeds it either, this reads the endpoint's own response model and builds a
body from its declared shape, so a run is not blocked on a baseline that simply does not exist yet.

This is the **lowest-trust tier there is** — a blind schema fill, not a captured contract. It never
claims to be anything more: every value is a synthetic placeholder (a real value, never `null`, so
an optional-gated UI path still has something to render — the whole point of a *safety* generator),
and every field this script could not confidently synthesize is named in a `warnings` list rather
than guessed at silently. Running `check_baseline.py` against a synthesized body is a self-check —
it was built from the same key extraction `check_baseline.py` itself reads — and proves nothing
about what the real backend actually sends.

Reuses `check_baseline.py`'s `find_type_source()` (grep + brace-matching to a type's declaration and
body) and its two parsing regexes rather than re-deriving them. The one genuinely new piece is
reading a stored property's *type* annotation — `check_baseline.py`'s own `declared_keys()`
deliberately stops at `:`/`=` to get only the name.

Usage:
    synthesize_from_model.py --source-root <app source dir> --model "<SwiftType>[@<path>]"

`@<path>` is the same envelope-path grammar `check_baseline.py --model` reads (`data`, `data[*]`,
`data.products[*]`) — only a trailing `[*]` on the final segment is supported, matching how every
manifest entry in this codebase actually spells one.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent))
from check_baseline import CODING_KEY, find_type_source  # noqa: E402

STORED_PROPERTY_TYPED = re.compile(
    r"^\s*(?:@\w+\s+)*(?:private\s+|public\s+|internal\s+)?(?:let|var)\s+_?(\w+)\s*:\s*([^={\n]+)")
ENUM_STRING_DECLARATION = r"enum\s+{name}\b[^{{]*:\s*String\b"
MAX_DEPTH = 6

PRIMITIVE_STRING_TYPES = {"String", "Character"}
PRIMITIVE_INT_TYPES = {"Int", "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64"}
PRIMITIVE_FLOAT_TYPES = {"Double", "Float", "CGFloat"}
DYNAMIC_TYPES = {"Any", "AnyObject", "AnyCodable", "[String: Any]", "JSONValue"}


def declared_fields(body: str) -> tuple[list[tuple[str, str]], dict[str, str]]:
    """(name, raw type token) per depth-0 stored property, plus a property->wire-key rename map.

    Same depth-tracking loop as `check_baseline.py`'s `declared_keys()` — only depth-0 properties
    count, and a nested type's own stored properties are read at any depth to close the same
    CodingKeys-block scanning gap that function's docstring already names.
    """
    fields: list[tuple[str, str]] = []
    renames: dict[str, str] = {}
    depth = 0
    coding_keys_depth: int | None = None
    for line in body.splitlines():
        stripped = line.strip()
        opening = stripped.count("{") - stripped.count("}")

        if coding_keys_depth is not None:
            match = CODING_KEY.match(stripped)
            if match:
                names = [part.strip() for part in match.group(1).split(",") if part.strip()]
                if match.group(2) and len(names) == 1:
                    renames[names[0]] = match.group(2)
                else:
                    for name in names:
                        renames.setdefault(name, name)
            if depth + opening <= coding_keys_depth:
                coding_keys_depth = None
        elif re.match(r"(?:private\s+|public\s+)?enum\s+CodingKeys\b", stripped):
            for name in re.findall(r"case\s+([\w,\s]+)", stripped):
                for part in name.split(","):
                    part = part.strip()
                    if part:
                        renames.setdefault(part, part)
            if opening > 0:
                coding_keys_depth = depth
        elif depth == 0:
            match = STORED_PROPERTY_TYPED.match(line)
            if match:
                raw_type = match.group(2).split("//", 1)[0].strip().rstrip(",")
                fields.append((match.group(1), raw_type))

        depth += opening
    return fields, renames


def strip_optional(token: str) -> str:
    token = token.strip()
    while token.endswith("?") or token.endswith("!"):
        token = token[:-1].strip()
    return token


def synthesize_enum_value(source_root: Path, type_name: str, warnings: list[str]) -> str | None:
    """The first case's raw value of a `String`-backed enum — Swift auto-synthesizes a raw value
    equal to the case name when none is written, so a bare `case a` still yields `"a"`."""
    pattern = ENUM_STRING_DECLARATION.format(name=re.escape(type_name))
    try:
        listed = subprocess.run(
            ["grep", "-rlE", pattern, str(source_root), "--include=*.swift"],
            capture_output=True, text=True).stdout.split()
    except Exception:
        listed = []
    for path in listed:
        text = Path(path).read_text(errors="ignore")
        match = re.search(pattern, text)
        if not match:
            continue
        start = text.find("{", match.end())
        if start < 0:
            continue
        depth = 0
        for index in range(start, len(text)):
            if text[index] == "{":
                depth += 1
            elif text[index] == "}":
                depth -= 1
                if depth == 0:
                    case_match = re.search(r"case\s+(\w+)(?:\s*=\s*\"([^\"]+)\")?", text[start + 1:index])
                    return case_match.group(2) or case_match.group(1) if case_match else None
    return None


def synthesize_value(type_token: str, name: str, source_root: Path, seen: frozenset[str],
                     warnings: list[str], depth: int) -> Any:
    """One value for one field, recursing into a custom type's own declared fields.

    Always a real value where one can be produced — never a null used to dodge an optional, since a
    safety-generated body exists specifically so an optional-gated UI path has something to render.
    A type this can't resolve emits `None` **and** a warning naming the field: the honesty-rail
    case, surfaced rather than guessed at.
    """
    token = strip_optional(type_token)
    if depth > MAX_DEPTH:
        warnings.append(f"max synthesis depth exceeded at field '{name}' ({token}) — emitted null")
        return None

    if token.startswith("[") and token.endswith("]"):
        inner = token[1:-1].strip()
        if ":" in inner:
            key_type, _, value_type = inner.partition(":")
            if strip_optional(key_type.strip()) != "String":
                warnings.append(f"non-String dictionary key '{key_type.strip()}' for field "
                                f"'{name}' — emitted an empty object")
                return {}
            return {"key1": synthesize_value(value_type.strip(), f"{name}.value", source_root,
                                             seen, warnings, depth + 1)}
        return [synthesize_value(inner, f"{name}[]", source_root, seen, warnings, depth + 1)]

    if token in PRIMITIVE_STRING_TYPES:
        return f"sample-{name}"
    if token in PRIMITIVE_INT_TYPES:
        return 1
    if token in PRIMITIVE_FLOAT_TYPES:
        return 1.0
    if token == "Bool":
        return True
    if token == "URL":
        return f"https://example.com/{name}"
    if token == "Date":
        warnings.append(f"field '{name}' is Date — emitted an ISO-8601 placeholder; the app's "
                        "actual decode strategy (ISO-8601 vs epoch millis) can't be read from the "
                        "type name alone, verify manually")
        return "2026-01-01T00:00:00Z"
    if token in DYNAMIC_TYPES:
        warnings.append(f"field '{name}' has dynamic type '{token}' — emitted null")
        return None

    if token in seen:
        warnings.append(f"cycle guard: '{token}' recurses into itself at field '{name}' — "
                        "emitted an empty object")
        return {}

    found = find_type_source(source_root, token)
    if found is not None:
        _, body = found
        fields, renames = declared_fields(body)
        if not fields:
            warnings.append(f"type '{token}' for field '{name}' has no declared stored "
                            "properties — emitted an empty object")
            return {}
        nested_seen = seen | {token}
        return {renames.get(field_name, field_name):
                synthesize_value(field_type, field_name, source_root, nested_seen, warnings, depth + 1)
                for field_name, field_type in fields}

    enum_value = synthesize_enum_value(source_root, token, warnings)
    if enum_value is not None:
        return enum_value

    warnings.append(f"unresolved type '{token}' for field '{name}' — emitted null, verify manually")
    return None


def build_envelope(path: str, value: Any) -> dict[str, Any]:
    """Inverse of `check_baseline.py`'s `select()`: turns `data` / `data[*]` / `data.products[*]`
    back into the nested envelope dict the synthesized leaf value belongs under."""
    tokens = path.split(".")
    leaf_key = tokens[-1]
    fanned = leaf_key.endswith("[*]")
    if fanned:
        leaf_key = leaf_key[:-3]
    envelope: dict[str, Any] = {}
    cursor = envelope
    for token in tokens[:-1]:
        cursor[token] = {}
        cursor = cursor[token]
    cursor[leaf_key] = [value] if fanned else value
    return envelope


def synthesize_body(source_root: Path, type_name: str, path: str) -> tuple[Any, list[str]] | None:
    """The entry point `capture_baseline.py` calls. `None` (never a raised exception) when the type
    can't be found at all, so the caller falls through to `missing` exactly as `seed_from_pack()`
    already does for its own not-found case."""
    found = find_type_source(source_root, type_name)
    if found is None:
        return None
    _, body = found
    fields, renames = declared_fields(body)
    warnings: list[str] = []
    obj = {renames.get(field_name, field_name):
           synthesize_value(field_type, field_name, source_root, frozenset({type_name}), warnings, 1)
           for field_name, field_type in fields}
    return build_envelope(path, obj), warnings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--model", required=True, help="`<SwiftType>[@<path>]`, path defaults to `data`")
    args = parser.parse_args()

    type_name, _, path = args.model.partition("@")
    result = synthesize_body(args.source_root, type_name, path or "data")
    if result is None:
        print(f"could not find `{type_name}` under {args.source_root}", file=sys.stderr)
        return 1
    body, warnings = result
    print(json.dumps(body, indent=2, sort_keys=True))
    if warnings:
        print(f"\n{len(warnings)} warning(s):", file=sys.stderr)
        for warning in warnings:
            print(f"  ! {warning}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
