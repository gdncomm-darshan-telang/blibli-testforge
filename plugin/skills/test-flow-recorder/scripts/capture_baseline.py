#!/usr/bin/env python3
"""Captures one real response body per endpoint out of a NetworkLens trace.

A fixture authored from a Swift `Codable` model is only as complete as whoever read the model. Miss
one optional field and, where every field is `decodeIfPresent`, the decoder accepts the body in
silence — the only symptom is one control that quietly does nothing, which reads as a bug in the
app. A body lifted from a real response cannot have that hole.

So a baseline is captured, not written, whenever the endpoint has ever answered for real. Each one
lands as plain response JSON — not pack-shaped — so a backend contract change shows up as a real
diff in review rather than as a changed base64 blob. `manifest.json` records where each came from;
`provenance: "authored"` marks the ones to distrust and to re-capture when traffic allows.

Timestamps are turned into `{{anchor±N}}` tokens on the way in (`--templatize`, the default), so a
captured baseline is time-relative from the start and never goes stale the way an absolute one does.

A capture is only as good as the backend having data when it runs. An environment that answers the
entry endpoint with an empty collection leaves every endpoint downstream of a selection uncalled, so
a screen's later requests never happen and have nothing to capture. `--from-pack` covers that gap:
it seeds a baseline
from a recorded pack variant and marks it `provenance: "pack"` (real traffic, but second-hand and
undated). Re-run the capture in any session where live data flows and the entry upgrades itself to
`captured`.

Neither a live 200 nor a pack variant always exists — a scope with no pack and a backend that has
never answered leaves an endpoint with nothing at all. `--source-root` covers that last gap: it
reads the endpoint's own Swift `Codable` response model (`synthesize_from_model.py`) and synthesizes
a schema-conformant body, marked `provenance: "synthesized"`. This is the lowest-trust tier there
is — a blind schema fill to unblock a run, never a substitute for a real capture — so it is never
silently mistaken for the other three: `synthesisWarnings` names every field it could not
confidently synthesize, and a case depending on such a baseline should be flagged for review before
it's trusted. Four trust levels, always explicit: `captured` > `pack` > `authored` > `synthesized`,
with `missing` for none of the above.

Usage:
    capture_baseline.py --out-dir fixtures/<feature>/api-responses \\
        --manifest fixtures/<feature>/manifest.json \\
        --endpoint "/<service>/<resource>" [--endpoint …] \\
        --bundle-id <app bundle id> [--trace <path>] [--no-templatize]
"""

from __future__ import annotations

import argparse
import base64
import gzip
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent))
from dataplane import exchanges, trace_dir  # noqa: E402
from render_fixture import EPOCH_MILLIS_PATTERN, apply_replacements, offset_token  # noqa: E402
from synthesize_from_model import synthesize_body  # noqa: E402

NEGATIVE_VARIANT = re.compile(r"^(empty|error|.*-error|.*-empty)\b", re.IGNORECASE)


def slugify(endpoint: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", endpoint.lower()).strip("-") or "endpoint"


def resolve_trace(explicit: str | None, bundle_id: str) -> Path:
    """The NetworkLens directory — not one trace file. `--trace` is the escape hatch for a data
    plane `dataplane.py` cannot resolve on its own; everything else goes through it, so a
    `networklens-mcp` holding a stale container never gets a chance to say "no trace" for a trace
    that is sitting right there under the new one.
    """
    return Path(explicit) if explicit else trace_dir(bundle_id)


def decode_body(response: dict[str, Any]) -> Any:
    raw = base64.b64decode(response["body"])
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    return json.loads(raw)


def best_exchange(rows: list[dict[str, Any]], endpoint: str) -> dict[str, Any] | None:
    """The largest live 200 for this path.

    Largest rather than latest because an endpoint answers with an empty payload far more often
    than with a populated one, and an empty baseline teaches a fixture author nothing about the
    shape. Mock-served exchanges are skipped: a baseline captured from our own mock is circular.
    """
    candidates = [
        row for row in rows
        if row.get("endpointKey", "").split("?")[0].rstrip("/").endswith(endpoint.rstrip("/"))
        and not row.get("isMockServed")
        and row.get("response", {}).get("statusCode") == 200
        and "body" in row.get("response", {})
        and not row.get("response", {}).get("bodyTruncated")
    ]
    return max(candidates, key=lambda row: row["response"].get("originalBodyByteCount") or 0) if candidates else None


def seed_from_pack(pack: dict[str, Any] | None, endpoint: str, variant_name: str | None) -> tuple[Any, str] | None:
    """A recorded pack variant, as the fallback when the endpoint has not answered for real.

    Already templatized by `render_fixture.py templatize`, so the body arrives token-bearing and
    needs no second pass.
    """
    if not pack:
        return None
    for mock in pack.get("mocks", []):
        if not mock.get("endpointKey", "").split("?")[0].rstrip("/").endswith(endpoint.rstrip("/")):
            continue
        variants = mock.get("variants", [])
        chosen = next((variant for variant in variants if variant.get("name") == variant_name), None)
        if chosen is None:
            # An `Empty` or `Error 500` variant is a fixture, not a baseline — seeding from one
            # would teach every later mutation the wrong shape. Largest positive body wins.
            positive = [variant for variant in variants if not NEGATIVE_VARIANT.match(variant.get("name", ""))]
            chosen = max(positive, key=lambda variant: len(json.dumps(
                variant.get("steps", [{}])[0].get("respond", {}).get("_0", {}).get("bodyJSON", ""))), default=None)
        if chosen is None:
            return None
        body = chosen["steps"][0]["respond"]["_0"].get("bodyJSON")
        if not isinstance(body, dict) or body.get("data") in (None, [], {}):
            return None
        return body, chosen.get("name", "?")
    return None


def templatize_body(body: Any) -> tuple[Any, int]:
    found = sorted({int(value) for value in EPOCH_MILLIS_PATTERN.findall(json.dumps(body))})
    if not found:
        return body, 0
    anchor = found[0]
    return apply_replacements(body, {value: offset_token(value, anchor) for value in found}), len(found)


def describe(body: Any) -> dict[str, Any]:
    """What the manifest carries so a fixture author can plan a mutation without opening the file."""
    data = body.get("data") if isinstance(body, dict) else None
    if isinstance(data, list):
        shape = f"list[{len(data)}]"
        keys = sorted(data[0].keys()) if data and isinstance(data[0], dict) else []
    elif isinstance(data, dict):
        shape = "object"
        keys = sorted(data.keys())
    else:
        shape = type(data).__name__
        keys = []
    return {
        "envelopeKeys": sorted(body.keys()) if isinstance(body, dict) else [],
        "dataShape": shape,
        "dataKeys": keys,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--endpoint", action="append", required=True,
                        help="Request path to capture, e.g. /backend/<service>/<resource>. Repeatable.")
    parser.add_argument("--trace", help="NetworkLens directory holding trace*.ndjson. Resolved from the "
                                        "booted container when omitted.")
    parser.add_argument("--from-pack", type=Path,
                        help="Fall back to this pack template's variant body when the trace has no live 200.")
    parser.add_argument("--pack-variant", action="append", default=[],
                        help="`<endpoint path>=<variant name>` naming which variant seeds which endpoint.")
    # No default: a bundle id that is right for some other app resolves a real container and
    # captures that app's traffic, which reads as a baseline rather than as a mistake.
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--feature", default="")
    parser.add_argument("--source-root", type=Path,
                        help="App source root. When given, an endpoint with no live 200 and no pack "
                             "variant is synthesized from its Swift Codable response model instead "
                             "of left `missing` — the lowest-trust tier, for unblocking a run only.")
    parser.add_argument("--model", action="append", default=[],
                        help="`<endpoint>=<SwiftType>[@<path>]`, for synthesis only. Repeatable. "
                             "Falls back to each endpoint's own manifest `models` entry when omitted "
                             "— same format as check_baseline.py's own --model.")
    parser.add_argument("--no-templatize", action="store_true",
                        help="Keep absolute epoch millis. Only for a body with no time-dependent behaviour.")
    args = parser.parse_args()

    trace = resolve_trace(args.trace, args.bundle_id)
    rows = exchanges(trace) if trace.is_dir() else []
    if not rows:
        print(f"  = no trace under {trace} — falling back to --from-pack where given")
    pack = json.loads(args.from_pack.read_text()) if args.from_pack else None
    pack_variants = dict(pair.split("=", 1) for pair in args.pack_variant)
    model_overrides = dict(pair.split("=", 1) for pair in args.model)
    args.out_dir.mkdir(parents=True, exist_ok=True)

    manifest: dict[str, Any] = {}
    if args.manifest.exists():
        manifest = json.loads(args.manifest.read_text())
    manifest.setdefault("feature", args.feature or manifest.get("feature", ""))
    manifest.setdefault("endpoints", {})

    captured = 0
    for endpoint in args.endpoint:
        entry = manifest["endpoints"].setdefault(endpoint, {})
        model_mapping = model_overrides.get(endpoint) or next(iter(entry.get("models", [])), None)
        exchange = best_exchange(rows, endpoint)
        if not exchange:
            seeded = seed_from_pack(pack, endpoint, pack_variants.get(endpoint))
            entry["lastCaptureAttempt"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
            if seeded is None:
                synthesized = None
                if args.source_root and model_mapping:
                    type_name, _, model_path = model_mapping.partition("@")
                    synthesized = synthesize_body(args.source_root, type_name, model_path or "data")
                if synthesized is not None:
                    body, warnings = synthesized
                    target = args.out_dir / f"{slugify(endpoint)}.json"
                    target.write_text(json.dumps(body, indent=2, sort_keys=True) + "\n")
                    entry.update({
                        "file": target.name,
                        "provenance": "synthesized",
                        "modelSynthesizedFrom": model_mapping,
                        "synthesisWarnings": warnings,
                        **describe(body),
                    })
                    print(f"  ~ {endpoint} -> {target.name}  (synthesized from {model_mapping}, "
                          f"{len(warnings)} warning(s))")
                    continue
                entry["file"] = f"{slugify(endpoint)}.json"
                # Not setdefault: a file that has since been deleted must not keep claiming the
                # provenance of the run that wrote it.
                if not (args.out_dir / entry["file"]).exists():
                    entry["provenance"] = "missing"
                reason = "no live 200 in the trace and no pack variant"
                if model_mapping and not args.source_root:
                    reason += " (no --source-root given, so the model can't be read)"
                elif args.source_root and not model_mapping:
                    reason += " (no model mapping to synthesize from)"
                print(f"  ! {endpoint}: {reason} — {entry['provenance']}")
                continue
            body, variant_name = seeded
            target = args.out_dir / f"{slugify(endpoint)}.json"
            target.write_text(json.dumps(body, indent=2, sort_keys=True) + "\n")
            entry.update({
                "file": target.name,
                "provenance": "pack",
                "packVariant": variant_name,
                "packFile": str(args.from_pack),
                **describe(body),
            })
            print(f"  ~ {endpoint} -> {target.name}  (from pack variant '{variant_name}', data {entry['dataShape']})")
            continue

        body = decode_body(exchange["response"])
        tokens = 0
        if not args.no_templatize:
            body, tokens = templatize_body(body)

        target = args.out_dir / f"{slugify(endpoint)}.json"
        target.write_text(json.dumps(body, indent=2, sort_keys=True) + "\n")
        entry.update({
            "file": target.name,
            "provenance": "captured",
            "capturedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "sourceStartedAt": exchange.get("startedAt"),
            "statusCode": exchange["response"].get("statusCode"),
            "bytes": exchange["response"].get("originalBodyByteCount"),
            "timestampTokens": tokens,
            **describe(body),
        })
        captured += 1
        print(f"  + {endpoint} -> {target.name}  ({entry['bytes']}B, {tokens} timestamp token(s), "
              f"data {entry['dataShape']})")

    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"  {captured}/{len(args.endpoint)} captured · manifest {args.manifest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
