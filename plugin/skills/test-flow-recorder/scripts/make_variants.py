#!/usr/bin/env python3
"""Generates mock variants by mutating one that already works.

A test case rarely needs a *new* response — it needs the working one with one thing changed: one
schedule instead of five, no `background`, `invertMode` flipped, an empty `products` array. Writing
each of those out by hand is where fixture drift comes from, because the twenty fields that were
supposed to stay identical quietly diverge.

So variants are declared as named mutations of a base variant, in a reviewable spec file, and this
script applies them to a pack template (the `bodyJSON` form that `render_fixture.py templatize`
produces). Values may contain fixture tokens (`{{now+2h}}`); `render_fixture.py render` resolves
them afterwards, so a generated variant is still time-relative.

Usage:
    make_variants.py <template.json> <spec.json> [-o out.json]     # in place when -o is omitted

Spec shape:

    {
      "endpointKey": "GET /<service>/<resource>",
      "baseVariant": "Range-FS",
      "variants": {
        "Range-single-campaign": [{"op": "keep", "path": "data", "count": 1}],
        "Range-no-background":   [{"op": "remove", "path": "data[*].background"}],
        "Range-inverted":        [{"op": "set", "path": "data[*].background.invertMode", "value": true}],
        "Range-upcoming":        [{"op": "set", "path": "data[0].start", "value": "{{now+2h}}"}]
      }
    }

Ops: `set` (path, value) · `remove` (path) · `keep` (path, count — truncate a list) ·
`grow` (path, count — repeat a list's items up to count, renumbering nothing) ·
`rename_key` (path, from, to — for the dict-keyed groups Special Placement uses) ·
`move` (path, to — relocate a value, for reshaping one endpoint's body into another's) ·
`renumber` (path, field, format — give each element of a list a unique `{i}`-numbered field,
which is what `grow` deliberately does not do) · `respond` (field, value — edits the response
envelope rather than the body, so `delay` and `statusCode` are reachable from a spec).

Paths are dotted, with `[n]` for one list index and `[*]` for every element of a list or every
value of a dict.

A spec whose `endpointKey` is not in the pack yet must also carry `newEndpointFrom`
(`{"endpointKey": ..., "variant": ...}`) — the mock rule is then created from scratch and each
variant starts as a copy of that other endpoint's body, which `move`/`remove` reshape. That is how
an endpoint the recorded pack never captured gets a fixture without hand-writing one.
"""

from __future__ import annotations

import argparse
import copy
import json
import re
import sys
import uuid
from pathlib import Path
from typing import Any

# Deterministic variant ids: regenerating a spec must not churn the pack file.
ID_NAMESPACE = uuid.UUID("11111111-2222-3333-4444-555555555555")
SEGMENT_PATTERN = re.compile(r"([^.\[\]]+)|\[(\*|\d+)\]")
# The copy `create_mock` seeds a brand-new endpoint with. Dropped once the spec's own variants
# exist, so the un-reshaped source body never ships in the pack.
SEED_VARIANT_NAME = "__seed__"


def parse_path(path: str) -> list[Any]:
    """`data[0].background.invertMode` -> ['data', 0, 'background', 'invertMode']; `[*]` stays '*'."""
    segments: list[Any] = []
    for name, index in SEGMENT_PATTERN.findall(path):
        if name:
            segments.append(name)
        elif index == "*":
            segments.append("*")
        else:
            segments.append(int(index))
    return segments


def resolve(document: Any, segments: list[Any]) -> list[tuple[Any, Any]]:
    """Every (container, key) the path points at — several when the path contains `[*]`."""
    targets: list[tuple[Any, Any]] = [(None, document)]
    for depth, segment in enumerate(segments):
        nxt: list[tuple[Any, Any]] = []
        for _, value in targets:
            if segment == "*":
                if isinstance(value, list):
                    nxt.extend((value, index) for index in range(len(value)))
                elif isinstance(value, dict):
                    nxt.extend((value, key) for key in list(value))
                continue
            if isinstance(value, list) and isinstance(segment, int):
                if -len(value) <= segment < len(value):
                    nxt.append((value, segment))
                continue
            if isinstance(value, dict) and segment in value:
                nxt.append((value, segment))
        # Re-read so the next segment descends into the value, not the (container, key) pair.
        targets = [(container, container[key]) for container, key in nxt] if depth + 1 < len(segments) else nxt
        if not targets:
            return []
    return targets


def apply_operation(body: Any, operation: dict[str, Any]) -> int:
    op = operation["op"]
    segments = parse_path(operation["path"])
    targets = resolve(body, segments)
    if not targets and op == "set" and segments and isinstance(segments[-1], str):
        # A `set` on a key the response omits is the whole point of a `set`: an optional field can
        # be absent from every item in a captured body, and a real backend omits one per-item rather
        # than uniformly. Only the *parent* has to exist — creating one leaf on an
        # object that resolves is unambiguous, inventing the object it hangs off is not.
        parents = resolve(body, segments[:-1]) if len(segments) > 1 else [(None, body)]
        targets = [
            (value if parent is None else parent[key], segments[-1])
            for parent, key in parents
            for value in [body if parent is None else None]
            if isinstance(value if parent is None else parent[key], dict)
        ]
    if not targets:
        raise KeyError(f"path matched nothing: {operation['path']}")

    touched = 0
    for container, key in targets:
        if op == "set":
            container[key] = copy.deepcopy(operation["value"])
        elif op == "remove":
            del container[key]
        elif op == "keep":
            value = container[key]
            if not isinstance(value, list):
                raise TypeError(f"keep needs a list at {operation['path']}")
            container[key] = value[: operation["count"]]
        elif op == "grow":
            value = container[key]
            if not isinstance(value, list) or not value:
                raise TypeError(f"grow needs a non-empty list at {operation['path']}")
            grown = list(value)
            while len(grown) < operation["count"]:
                grown.append(copy.deepcopy(value[len(grown) % len(value)]))
            container[key] = grown
        elif op == "move":
            destination = resolve(body, parse_path(operation["to"]))
            if destination:
                target_container, target_key = destination[0]
                target_container[target_key] = container[key]
            else:
                segments_to = parse_path(operation["to"])
                parent = resolve(body, segments_to[:-1]) if len(segments_to) > 1 else [(None, body)]
                if not parent:
                    raise KeyError(f"move destination unreachable: {operation['to']}")
                holder = parent[0][0][parent[0][1]] if len(segments_to) > 1 else body
                holder[segments_to[-1]] = container[key]
            del container[key]
        elif op == "renumber":
            value = container[key]
            if not isinstance(value, list):
                raise TypeError(f"renumber needs a list at {operation['path']}")
            for index, element in enumerate(value):
                if isinstance(element, dict):
                    element[operation["field"]] = operation["format"].replace("{i}", str(index + 1))
        elif op == "rename_key":
            value = container[key]
            if not isinstance(value, dict):
                raise TypeError(f"rename_key needs a dict at {operation['path']}")
            value[operation["to"]] = value.pop(operation["from"])
        else:
            raise ValueError(f"unknown op {op!r}")
        touched += 1
    return touched


ENVELOPE_OP = "respond"


def apply_envelope_operation(respond: dict[str, Any], operation: dict[str, Any]) -> None:
    """`delay` and `statusCode` live beside the body, not in it — a delayed or failing variant
    is otherwise unreachable from a spec file."""
    respond[operation["field"]] = copy.deepcopy(operation["value"])


def create_mock(pack: dict[str, Any], endpoint_key: str, source: dict[str, Any]) -> dict[str, Any]:
    """Adds an endpoint the recorded pack never captured, seeded from another endpoint's variant."""
    source_mock = find_mock(pack, source["endpointKey"])
    source_variant, _ = base_body(source_mock, source["variant"])
    mock = {
        "activeVariantID": str(uuid.uuid5(ID_NAMESPACE, f"seed:{endpoint_key}")).upper(),
        "endpointKey": endpoint_key,
        "id": str(uuid.uuid5(ID_NAMESPACE, f"mock:{endpoint_key}")).upper(),
        "isEnabled": False,
        "match": {"headers": {}, "query": {}},
        "variants": [copy.deepcopy(source_variant)],
    }
    mock["variants"][0]["name"] = SEED_VARIANT_NAME
    pack.setdefault("mocks", []).append(mock)
    return mock


def find_mock(pack: dict[str, Any], endpoint_key: str) -> dict[str, Any]:
    for mock in pack.get("mocks", []):
        if mock.get("endpointKey") == endpoint_key:
            return mock
    raise KeyError(f"no mock for {endpoint_key!r} — endpoints present: "
                   + ", ".join(mock.get("endpointKey", "?") for mock in pack.get("mocks", [])))


def base_body(mock: dict[str, Any], variant_name: str) -> tuple[dict[str, Any], dict[str, Any]]:
    for variant in mock.get("variants", []):
        if variant.get("name") == variant_name:
            respond = variant["steps"][0]["respond"]["_0"]
            if "bodyJSON" not in respond:
                raise KeyError(f"variant {variant_name!r} has no bodyJSON — run "
                               "`render_fixture.py templatize` on the pack first")
            return variant, respond
    raise KeyError(f"no variant {variant_name!r} on {mock.get('endpointKey')}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("template", type=Path)
    parser.add_argument("spec", type=Path)
    parser.add_argument("-o", "--output", type=Path)
    args = parser.parse_args()

    pack = json.loads(args.template.read_text())
    specs = json.loads(args.spec.read_text())
    if isinstance(specs, dict):
        specs = [specs]

    for spec in specs:
        try:
            mock = find_mock(pack, spec["endpointKey"])
        except KeyError:
            if "newEndpointFrom" not in spec:
                raise
            mock = create_mock(pack, spec["endpointKey"], spec["newEndpointFrom"])
            print(f"  * created endpoint {spec['endpointKey']}")
        base_variant_name = SEED_VARIANT_NAME if SEED_VARIANT_NAME in {
            variant.get("name") for variant in mock.get("variants", [])
        } else spec["baseVariant"]
        template_variant, respond = base_body(mock, base_variant_name)
        generated: list[dict[str, Any]] = []
        for name, operations in spec["variants"].items():
            body = copy.deepcopy(respond["bodyJSON"])
            envelope_operations = [operation for operation in operations if operation["op"] == ENVELOPE_OP]
            for operation in operations:
                if operation["op"] == ENVELOPE_OP:
                    continue
                try:
                    apply_operation(body, operation)
                except (KeyError, TypeError, ValueError) as error:
                    print(f"  ! {name}: {error}", file=sys.stderr)
                    raise SystemExit(1)
            variant = copy.deepcopy(template_variant)
            variant["id"] = str(uuid.uuid5(ID_NAMESPACE, f"variant:{name}")).upper()
            variant["name"] = name
            variant["steps"][0]["respond"]["_0"]["bodyJSON"] = body
            for operation in envelope_operations:
                apply_envelope_operation(variant["steps"][0]["respond"]["_0"], operation)
            generated.append(variant)
            print(f"  + {spec['endpointKey'].split(' ')[-1]} / {name} ({len(operations)} mutation(s))")

        names = {variant["name"] for variant in generated} | {SEED_VARIANT_NAME}
        kept = [variant for variant in mock["variants"] if variant["name"] not in names]
        mock["variants"] = generated + kept
        # A regenerated variant gets a fresh id, so an activeVariantID left pointing at the
        # previous one would import as "no variant selected" rather than as the intended default.
        if mock.get("activeVariantID") not in {variant["id"] for variant in mock["variants"]}:
            mock["activeVariantID"] = mock["variants"][0]["id"]

    output = args.output or args.template
    output.write_text(json.dumps(pack, indent=2, sort_keys=True) + "\n")
    print(f"wrote {output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
