#!/usr/bin/env python3
"""Compares a captured baseline against the Swift type that decodes it.

Where every field on a response model is `decodeIfPresent`, a body missing a field decodes cleanly
and the app behaves as though the backend had not sent it. That is how an authored fixture ships
without a field the UI depends on: the decoder is happy, and the only symptom is one control that
does nothing. Nothing else in the pipeline can catch it — this script is that missing check.

Two findings, and neither is a hard failure, because both are legal:

  model-only   the Swift type declares it, the baseline does not carry it. The dangerous class:
               any case depending on such a field is silently unexercisable.
  body-only    the baseline carries it, the Swift type ignores it. Either a stale capture against
               an older contract, or a field the app has not adopted yet.

Usage:
    check_baseline.py --responses-dir fixtures/<feature>/api-responses \\
        --manifest fixtures/<feature>/manifest.json \\
        --source-root <app source dir> \\
        [--model "/<service>/<resource>=<ResponseType>@data[*]"]

Each endpoint's decoding type is normally recorded in the manifest as `models: ["<Type>@<path>"]`,
in which case no `--model` is needed at all; `--model` overrides the manifest for a one-off.

`@<path>` selects the node to compare — `data`, `data[*]` for every element of a list, or a deeper
`data.products[*]`. Omit it and `data` is assumed.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

DECLARATION = r"(?:struct|final\s+class|class)\s+{name}\b"
STORED_PROPERTY = re.compile(r"^\s*(?:@\w+\s+)*(?:private\s+|public\s+|internal\s+)?(?:let|var)\s+_?(\w+)\s*[:=]")
CODING_KEY = re.compile(r"^\s*case\s+([\w,\s]+?)(?:\s*=\s*\"([^\"]+)\")?\s*$")
# Above this share of declared fields missing, the type is a shared union model (`HomeProduct`
# carries every field any surface ever needed) rather than the baseline being incomplete.
UNION_MODEL_SHARE = 0.5
MAX_REPORTED = 12
REDACTION_PLACEHOLDER = "<redacted>"


def find_type_source(source_root: Path, type_name: str) -> tuple[Path, str] | None:
    """The declaring file and the type's own body, by brace matching from the declaration."""
    pattern = DECLARATION.format(name=re.escape(type_name))
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
                    return Path(path), text[start + 1:index]
    return None


def declared_keys(body: str) -> tuple[set[str], set[str]]:
    """(json keys the type decodes, property names) — CodingKeys raw values win where present.

    Only depth-0 declarations count. Every model here writes an explicit `init(from decoder:)` whose
    first line is `let values = try decoder.container(...)`, and a nested `enum`/`struct` has stored
    properties of its own — read at any depth, both land in the set as fields the outer type never
    decodes, and the comparison reports phantom gaps.
    """
    properties: set[str] = set()
    keys: set[str] = set()
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
                    keys.add(match.group(2))
                else:
                    keys.update(names)
            if depth + opening <= coding_keys_depth:
                coding_keys_depth = None
        elif re.match(r"(?:private\s+|public\s+)?enum\s+CodingKeys\b", stripped):
            # A one-line `enum CodingKeys: String, CodingKey { case a, b }` closes on its own line.
            for name in re.findall(r"case\s+([\w,\s]+)", stripped):
                keys.update(part.strip() for part in name.split(",") if part.strip())
            if opening > 0:
                coding_keys_depth = depth
        elif depth == 0:
            match = STORED_PROPERTY.match(line)
            if match:
                properties.add(match.group(1))

        depth += opening
    return (keys or properties), properties


def abridge(names: list[str]) -> str:
    """A 90-name list scrolls the real finding off the screen."""
    if len(names) <= MAX_REPORTED:
        return ", ".join(names)
    return ", ".join(names[:MAX_REPORTED]) + f", … (+{len(names) - MAX_REPORTED} more)"


def select(body: Any, path: str) -> list[dict[str, Any]]:
    """Every object the path points at. `data[*]` fans out over a list; `data` is the node itself."""
    nodes: list[Any] = [body]
    for segment in re.findall(r"([^.\[\]]+)|(\[\*\])", path):
        name, star = segment
        nxt: list[Any] = []
        for node in nodes:
            if star:
                if isinstance(node, list):
                    nxt.extend(node)
                elif isinstance(node, dict):
                    nxt.extend(node.values())
            elif isinstance(node, dict) and name in node:
                nxt.append(node[name])
        nodes = nxt
    return [node for node in nodes if isinstance(node, dict)]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--responses-dir", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--model", action="append", default=[],
                        help="`<endpoint path>=<SwiftType>[@<json path>]`. Repeatable. "
                             "Omit and the manifest's own `models` entries are used.")
    parser.add_argument("--update-manifest", action="store_true",
                        help="Record each endpoint's gaps under `modelCheck`, so a later run can say "
                             "why a case that needs an absent field is unexercisable.")
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text())
    endpoints = manifest.get("endpoints", {})
    findings = 0

    mappings = list(args.model)
    if not mappings:
        # The manifest is the one place an endpoint's decoding type belongs: `capture_baseline.py`
        # writes the body, this reads it back, and neither needs the mapping retyped on a CLI.
        for endpoint, entry in endpoints.items():
            for model in entry.get("models", []):
                mappings.append(f"{endpoint}={model}")
    if not mappings:
        raise SystemExit("no --model given and no `models` entries in the manifest")

    for mapping in mappings:
        endpoint, _, target = mapping.partition("=")
        type_name, _, path = target.partition("@")
        path = path or "data"
        entry = endpoints.get(endpoint)
        if not entry or entry.get("provenance") == "missing":
            print(f"  · {endpoint}: no baseline ({(entry or {}).get('provenance', 'unknown')}) — skipped")
            continue

        body = json.loads((args.responses_dir / entry["file"]).read_text())
        nodes = select(body, path)
        if not nodes:
            # An empty-list `data` is a legitimate baseline (a real 200 with nothing in it); there is
            # simply no object to compare, which is not a finding.
            shape = entry.get("dataShape", "?")
            print(f"  · {endpoint}: '{path}' matched no object (data {shape}) — nothing to compare")
            continue

        found = find_type_source(args.source_root, type_name)
        if not found:
            print(f"  ! {endpoint}: could not find `{type_name}` under {args.source_root}")
            findings += 1
            continue
        source_path, source_body = found
        keys, properties = declared_keys(source_body)

        present: set[str] = set()
        blanked: set[str] = set()
        for node in nodes:
            present |= set(node.keys())
            blanked |= {key for key, value in node.items() if value == REDACTION_PLACEHOLDER}
        model_only = sorted(keys - present)
        body_only = sorted(present - keys)

        if args.update_manifest:
            entry.setdefault("modelCheck", {})[f"{type_name}@{path}"] = {
                "modelOnly": model_only,
                "bodyOnly": body_only,
                "redacted": sorted(blanked),
                "declaredFields": len(keys),
                "objectsSampled": len(nodes),
            }

        label = f"{endpoint} @{path} vs {type_name}"
        if blanked:
            # NetworkLens redacts by key term, and the terms match on token prefixes: `card` blanks
            # `productCardOverlayMessage` and `productCardType`, which are UI copy, not payment data.
            # The key is present so neither model-only nor body-only fires — the value is simply
            # unusable, and a case asserting on it would "pass" against the placeholder.
            print(f"  ! {label}: redacted value(s), unusable for an assertion: {abridge(sorted(blanked))}")
            findings += len(blanked)
        if not model_only and not body_only:
            if not blanked:
                print(f"  ✓ {label}: {len(keys)} field(s), all present")
            continue
        union = keys and len(model_only) / len(keys) >= UNION_MODEL_SHARE
        print(f"  {'~' if union else '!'} {label}  ({source_path.name}, {len(nodes)} object(s) sampled)")
        if model_only:
            if union:
                print(f"      {len(model_only)}/{len(keys)} declared fields absent — shared union model, "
                      "not a baseline gap; compare against the surface's own type instead")
            else:
                print(f"      model-only, absent from the baseline: {abridge(model_only)}")
                findings += len(model_only)
        if body_only:
            print(f"      body-only, not decoded by the model:  {abridge(body_only)}")
    if args.update_manifest:
        args.manifest.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
        print(f"  manifest updated: {args.manifest}")
    print(f"  {findings} finding(s) — none are failures; a field absent from a baseline is legal, "
          "just usually a mistake.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
