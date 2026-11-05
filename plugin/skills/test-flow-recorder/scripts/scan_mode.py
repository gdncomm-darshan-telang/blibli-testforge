#!/usr/bin/env python3
"""Records the accessibility surface of screens an operator visits by hand, with no test cases run.

A run currently rebuilds its knowledge of a screen — which identifiers exist, what contains what —
from scratch every time, and throws it away when the session ends. That is the most expensive thing
the skill does twice. Scan mode is the cheap fix: bring the app up with the harness on, walk the
module you are about to test, name each screen as you reach it, and stop. What comes out is a JSON
file a later run reads instead of rediscovering the screen.

The operator names the screens because nothing else can. The trace carries a `screen` field but
nothing populates it (0 of 81 exchanges in Bazaar's own trace), and inferring a screen from its root
identifier or tree shape is a guess that fails precisely where two screens differ only by data — an
empty cart and a full one. So `mark` takes a name, and marking the same name twice records a second
**variant** rather than a second screen.

Four things about the driver shape this tool, and all four were established by measurement against
Bazaar rather than assumed from the command names:

**The driver is pull-only.** There is no subscribe or event stream, so "records what you visit" is a
`dumpTree` poll on a timer. A capture identical to the previous one is not stored.

**`dumpTree` truncates hard at 20,000 characters** and says so — on the wire the flag is spelled
`truncated`. Bazaar's own catalog screen hits exactly the cap, so this is the normal case and not an
edge one. A truncated capture is never written as though it were whole.

**Neither `identifier` nor `elementType` narrows a dump, so neither can recover what truncation
cut.** This was the expected escape hatch and it does not work. A dump scoped to
`Catalog_BannerCarousel` — a banner 130 points tall — comes back holding the product grid 2,000
points below it; scoping to `Catalog_ProductGrid` instead changes the answer by one identifier.
`elementType` is worse: `Button`, `StaticText` and `Other` return byte-identical output containing
nine element types. Both only re-root the printout, which shortens the indentation and lets slightly
more fit inside the cap. Six scoped dumps of one truncated screen cost 7.6 seconds and recovered one
identifier, and that one was an SF Symbol name on the tab bar. So there is no re-dump path here, and
this tool does not pretend to have one: a truncated screen is recorded as truncated, and the way to
see past the cut is to scroll and `mark` again — the tree only ever holds what is rendered, so a
second variant of the same screen is what actually reaches the rest of it.

**A container that accessibility-merges its children reports their identifiers welded together.**
Bazaar's product card is a SwiftUI `Button` whose identifier comes back as
`Catalog_ProductCard_P-001-Catalog_ProductCard_P-001-…` repeated six times. Nobody wrote that string,
and a test that targets the clean identifier matches an inner element rather than the tappable
button. These are flagged per screen with the base identifier extracted, because it is a defect in
the screen worth fixing rather than a quirk worth working around.

What this does not do: it records what the operator walked past, in the data state it was in, on one
build. A screen never visited is written as not-visited, never as not-present, and the file says so
on its face rather than leaving a reader to assume coverage it does not have.

Usage:
    scan_mode.py                       poll, take commands on stdin, write on stop
    scan_mode.py --out cart.json --interval 2.0

Commands, once running:
    mark <name>     record what is on screen now under this name (repeat a name for a variant)
    skip            drop the pending unnamed capture — just passing through
    status          what has been captured so far
    stop            write the file and exit
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent))
from queue_cli import post  # noqa: E402  — the one command seam; it carries a harness restart

SCHEMA_VERSION = 1
DEFAULT_INTERVAL = 1.5

_FRAME = re.compile(r"\{\{(-?[\d.]+), (-?[\d.]+)\}, \{(-?[\d.]+), (-?[\d.]+)\}\}")
_IDENTIFIER = re.compile(r"identifier: '((?:[^'\\]|\\.)*)'")
_LABEL = re.compile(r"label: '((?:[^'\\]|\\.)*)'")
_VALUE = re.compile(r"value: '((?:[^'\\]|\\.)*)'")
_NODE_HEAD = re.compile(r"^(?P<type>[A-Za-z][A-Za-z0-9 ()]*?), 0x[0-9a-f]+")
_SUBTREE_MARKER = "Element subtree:"
# XCTest answers a query that matched nothing with a query chain, not with an empty tree. Reading
# that as "the subtree is empty" would turn "we could not find it" into "it is not there".
_NO_MATCH = ("No matches found", "Query chain:")


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


# The poller runs on its own thread while the command loop captures, so both reach for the queue.
# Its HTTP server serves one connection at a time and closes the second, so concurrent requests cost
# one of them a `RemoteDisconnected`. This lock makes the poll wait for the capture rather than race
# it, which is the right way round: a poll is discardable and a capture is somebody's manual walk.
_QUEUE = threading.Lock()
_EMIT = threading.Lock()
_EVENTS_ON = False
EVENT_PREFIX = "EVENT "
MAX_EVENT_IDENTIFIERS = 40


def emit(kind: str, **fields: Any) -> None:
    """One machine-readable line for a host app (the TestForge), only with `--events`.

    Printed from both the poller thread and the command loop, so it holds its own lock and flushes:
    a host reading a pipe would otherwise see nothing until the buffer filled.
    """
    if not _EVENTS_ON:
        return
    line = EVENT_PREFIX + json.dumps({"event": kind, "at": now(), **fields}, ensure_ascii=False)
    with _EMIT:
        print(line, flush=True)


def send(command: dict[str, Any], attempts: int = 2) -> dict[str, Any]:
    """One command, serialized against every other caller, transport failure returned not raised.

    A dropped connection is retried once, because the queue closing a connection says nothing about
    whether the harness would answer the command. Anything still failing after that comes back as an
    error dict: a scan session must not die holding screens it has already captured.
    """
    for attempt in range(attempts):
        try:
            with _QUEUE:
                return post(command) or {}
        except Exception as error:  # transport, not the harness rejecting the command
            if attempt == attempts - 1:
                return {"error": f"{type(error).__name__}: {error}"}
            time.sleep(0.5)
    return {"error": "unreachable"}


def dump(identifier: str | None = None, element_type: str | None = None) -> dict[str, Any]:
    """One `dumpTree`, unwrapped.

    The queue wraps a result as `{"value": {...}, "id": ..., "at": ...}` and the tree lands under
    `value.tree`, with the truncation flag on the wire spelled `truncated` — not `isTruncated`, which
    is the Swift-side constant name. Reading the wrong key returns `None`, which is falsy, which
    would silently mean "not truncated" on every capture.
    """
    command: dict[str, Any] = {"kind": "dumpTree"}
    if identifier:
        command["identifier"] = identifier
    if element_type:
        command["elementType"] = element_type
    result = send(command)
    payload = result.get("value") if isinstance(result.get("value"), dict) else result
    payload = payload if isinstance(payload, dict) else {}
    return {"tree": payload.get("tree") or "", "truncated": bool(payload.get("truncated")),
            "error": result.get("error")}


def parse_tree(text: str, truncated: bool = False) -> dict[str, Any]:
    """`XCUIElement.debugDescription` into nodes, or a stated reason why not.

    Returns `matched: False` for a query that found nothing, so a caller cannot confuse it with a
    screen that genuinely has no children.

    The last line of a truncated dump is dropped whole. The 20,000-character cut lands wherever it
    lands: sometimes on whitespace, sometimes mid-identifier — and a cut identifier still parses,
    just into a node whose `identifier:` regex found no closing quote and so silently produced a
    node with no identifier at all. One node out of 136 is not worth the chance of recording a
    half-read element as a real one.
    """
    if not text.strip():
        return {"matched": False, "reason": "empty response", "nodes": [], "roots": []}
    if any(marker in text for marker in _NO_MATCH) and _SUBTREE_MARKER not in text:
        return {"matched": False, "reason": "no element matched that identifier", "nodes": [], "roots": []}

    lines = text.splitlines()
    start = next((index + 1 for index, line in enumerate(lines) if line.strip() == _SUBTREE_MARKER), None)
    if start is None:
        return {"matched": False, "reason": "no 'Element subtree:' section", "nodes": [], "roots": []}

    # `Element subtree:` is not the last section: a complete dump goes on to `Path to element:` and
    # `Query chain:`, both carrying further `Application, 0x…` lines that belong to no screen. Every
    # line of the subtree is indented and a section header is not, so column zero ends the tree.
    body = []
    for line in lines[start:]:
        if line.strip() and not line.startswith(" "):
            break
        body.append(line)

    dropped_partial = False
    if truncated:
        while body and not body[-1].strip():
            body.pop()
        if body:
            body.pop()
            dropped_partial = True
    nodes: list[dict[str, Any]] = []
    roots: list[dict[str, Any]] = []
    stack: list[tuple[int, dict[str, Any]]] = []

    for raw in body:
        if not raw.strip():
            continue
        indent = len(raw) - len(raw.lstrip(" "))
        content = raw.strip().lstrip("→↪︎ ").strip()
        head = _NODE_HEAD.match(content)
        if not head:
            continue
        frame_match = _FRAME.search(content)
        identifier_match = _IDENTIFIER.search(content)
        label_match = _LABEL.search(content)
        value_match = _VALUE.search(content)
        node: dict[str, Any] = {"type": head.group("type").strip(), "children": []}
        if identifier_match:
            node["identifier"] = identifier_match.group(1)
        if label_match:
            node["label"] = label_match.group(1)
        if value_match:
            node["value"] = value_match.group(1)
        if frame_match:
            x, y, width, height = (float(group) for group in frame_match.groups())
            node["frame"] = {"x": x, "y": y, "width": width, "height": height, "units": "pt"}
        nodes.append(node)
        while stack and stack[-1][0] >= indent:
            stack.pop()
        if stack:
            stack[-1][1]["children"].append(node)
        else:
            roots.append(node)
        stack.append((indent, node))

    return {"matched": True, "nodes": nodes, "roots": roots, "droppedPartialLine": dropped_partial}


def identifiers_of(nodes: list[dict[str, Any]]) -> list[str]:
    return [node["identifier"] for node in nodes if node.get("identifier")]


def merged_base(identifier: str) -> str | None:
    """The real identifier behind one a merging container welded to copies of itself, else None.

    A SwiftUI container that merges its children for accessibility hands XCUITest one identifier
    built by joining the children's with `-`. Where the children share an identifier the result is
    that identifier repeated, and only that exact shape is reported: `X-X`, `X-X-X`. Anything else
    is left alone, because plenty of hand-written identifiers contain a hyphen and guessing at a
    partial match would flag `Catalog_ProductCard_P-001` itself.
    """
    parts = identifier.split("-")
    if len(parts) < 2:
        return None
    for size in range(1, len(parts) // 2 + 1):
        if len(parts) % size:
            continue
        head = parts[:size]
        if all(parts[start:start + size] == head for start in range(size, len(parts), size)):
            return "-".join(head)
    return None


def capture() -> dict[str, Any]:
    """One screen, from the one dump that carries structure.

    There is deliberately no second dump. Neither `identifier` nor `elementType` narrows the output,
    so a re-dump cannot reach what truncation cut — it only spends a second to return the same
    content re-rooted. See the module docstring for the measurements.
    """
    root = dump()
    if root["error"]:
        return {"error": root["error"], "capturedAt": now()}
    parsed = parse_tree(root["tree"], root["truncated"])
    if not parsed["matched"]:
        return {"error": parsed["reason"], "capturedAt": now()}

    identifiers = identifiers_of(parsed["nodes"])
    merged: list[dict[str, str]] = []
    seen_merged: set[str] = set()
    for node in parsed["nodes"]:
        identifier = node.get("identifier")
        if not identifier or identifier in seen_merged:
            continue
        base = merged_base(identifier)
        if base:
            seen_merged.add(identifier)
            merged.append({"reported": identifier, "base": base, "type": node["type"]})

    complete = not root["truncated"]
    return {
        "capturedAt": now(),
        "tree": parsed["roots"],
        "elementCount": len(parsed["nodes"]),
        "identifierCount": len(identifiers),
        "uniqueIdentifiers": sorted(set(identifiers)),
        "mergedIdentifiers": merged,
        "truncation": {
            "truncated": root["truncated"],
            "characters": len(root["tree"]),
            "droppedPartialLine": parsed.get("droppedPartialLine", False),
        },
        "complete": complete,
        "incompleteReason": None if complete else
            "the dump hit the 20,000-character cap; nothing below the cut is recorded. Scoped and "
            "elementType-filtered dumps do not narrow the output, so there is no re-dump that would "
            "reach it — scroll and mark this screen again to capture the rest as a second variant.",
    }


class Poller(threading.Thread):
    """Counts distinct trees so the session can say how much moved between marks.

    Only the hash of the raw dump is kept between polls — parsing every poll would burn CPU on the
    dozens of trees nobody marks. The count is the honest answer to "did I walk past something I
    forgot to name": twelve distinct trees behind four marks says yes.
    """

    def __init__(self, interval: float) -> None:
        super().__init__(daemon=True)
        self.interval = interval
        self.stop_flag = threading.Event()
        self.distinct_seen = 0
        self.last_hash: str | None = None
        self.last_error: str | None = None

    def run(self) -> None:
        while not self.stop_flag.wait(self.interval):
            result = dump()  # `send` returns transport failures rather than raising them up here
            if result["error"]:
                if self.last_error != str(result["error"]):
                    emit("pollError", error=str(result["error"]))
                self.last_error = str(result["error"])
                continue
            if self.last_error:
                emit("pollRecovered")
            self.last_error = None
            if not result["tree"]:
                continue
            digest = hashlib.sha256(result["tree"].encode()).hexdigest()[:16]
            if digest != self.last_hash:
                self.last_hash = digest
                self.distinct_seen += 1
                if _EVENTS_ON:
                    # Parsed only on a change, and only for the host's live view; marks still capture fresh.
                    parsed = parse_tree(result["tree"], result["truncated"])
                    identifiers = sorted(set(identifiers_of(parsed["nodes"])))
                    emit("screen", hash=digest, distinctSeen=self.distinct_seen,
                         elementCount=len(parsed["nodes"]), identifierCount=len(identifiers),
                         identifiers=identifiers[:MAX_EVENT_IDENTIFIERS], truncated=result["truncated"])


def session_metadata() -> dict[str, Any]:
    device = send({"kind": "deviceInfo"})
    value = device.get("value") if isinstance(device.get("value"), dict) else device
    return {"device": value if isinstance(value, dict) else {"error": "deviceInfo returned nothing"}}


def write_out(path: Path, document: dict[str, Any]) -> None:
    """Whole-file replace through a temporary, so a crash mid-write cannot leave a half-parsed map."""
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".partial")
    temporary.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    temporary.replace(path)


def build_document(metadata: dict[str, Any], started: str, interval: float, poller: "Poller",
                   screens: dict[str, dict[str, Any]], order: list[str], skipped: int,
                   ended: bool, fatal: str | None = None) -> dict[str, Any]:
    document: dict[str, Any] = {
        "schemaVersion": SCHEMA_VERSION,
        "mode": "scan",
        "session": {**metadata, "startedAt": started, "endedAt": now() if ended else None,
                    "pollIntervalSeconds": interval,
                    "distinctTreesSeenWhilePolling": poller.distinct_seen,
                    "skipped": skipped,
                    "complete": ended and not fatal},
        "screens": [screens[name] for name in order],
        "coverage": {
            "basis": "operator-visited",
            "note": "Only screens the operator visited and named are here, in the data state they "
                    "were in, on this build. A screen that does not appear was not visited — that is "
                    "not evidence it does not exist. Where `complete` is false the dump hit the "
                    "20,000-character cap and nothing below the cut was recorded; scoped and "
                    "elementType-filtered dumps do not narrow the output, so the only way past the "
                    "cut is to scroll and mark the screen again as another variant.",
        },
    }
    if fatal:
        document["session"]["endedBy"] = fatal
    return document


def render_markdown(document: dict[str, Any]) -> str:
    lines = ["# Scan mode", "",
             f"{len(document['screens'])} screen(s) named, "
             f"{sum(len(screen['variants']) for screen in document['screens'])} capture(s).", ""]
    lines += ["| Screen | Variant | Elements | Identifiers | Unique | Merged | Complete |",
              "|---|---|---|---|---|---|---|"]
    for screen in document["screens"]:
        for index, variant in enumerate(screen["variants"]):
            name = screen["name"] if index == 0 else "↳"
            lines.append(f"| {name} | {index + 1}/{len(screen['variants'])} | {variant.get('elementCount', '—')} "
                         f"| {variant.get('identifierCount', '—')} "
                         f"| {len(variant.get('uniqueIdentifiers') or [])} "
                         f"| {len(variant.get('mergedIdentifiers') or [])} "
                         f"| {'yes' if variant.get('complete') else 'no'} |")
    merged = {entry["reported"]: entry["base"]
              for screen in document["screens"] for variant in screen["variants"]
              for entry in variant.get("mergedIdentifiers") or []}
    if merged:
        lines += ["", "## Merged identifiers", "",
                  "These containers report their children's identifiers welded together. A test "
                  "targeting the base identifier will not match the container.", ""]
        lines += [f"- `{base}` → reported as `{reported}`" for reported, base in sorted(merged.items())]
    lines += ["", document["coverage"]["note"]]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, default=Path("scan-mode.json"),
                        help="where the map is written (default: %(default)s)")
    parser.add_argument("--interval", type=float, default=DEFAULT_INTERVAL,
                        help="seconds between polls (default: %(default)s)")
    parser.add_argument("--format", choices=["json", "markdown"], default="json",
                        help="what to print on stop; the JSON file is always written")
    parser.add_argument("--events", action="store_true",
                        help=f"also print one '{EVENT_PREFIX.strip()} {{json}}' line per screen change, mark and stop")
    args = parser.parse_args()
    global _EVENTS_ON
    _EVENTS_ON = args.events

    probe = dump()
    if probe["error"] or not probe["tree"]:
        print(f"no tree from the driver ({probe['error'] or 'empty response'}). "
              f"Is the harness collecting? scripts/harness.py status", file=sys.stderr)
        return 1

    metadata = session_metadata()
    print(f"scan mode · polling every {args.interval}s · commands: mark <name> | skip | status | stop")
    device = metadata.get("device") or {}
    if device.get("deviceName"):
        print(f"  device: {device.get('deviceName')} iOS {device.get('osVersion')} "
              f"{device.get('screenPoints', '')}")

    emit("started", device=device, out=str(args.out), interval=args.interval)
    poller = Poller(args.interval)
    poller.start()

    screens: dict[str, dict[str, Any]] = {}
    order: list[str] = []
    skipped = 0
    started = now()
    fatal: str | None = None

    def save(ended: bool) -> None:
        write_out(args.out, build_document(metadata, started, args.interval, poller,
                                           screens, order, skipped, ended, fatal))

    try:
        for raw in sys.stdin:
            line = raw.strip()
            if not line:
                continue
            verb, _, rest = line.partition(" ")
            verb = verb.lower()
            name = rest.strip().strip('"').strip("'")

            if verb == "stop":
                break
            if verb == "skip":
                skipped += 1
                print(f"  · skipped (nothing recorded); {skipped} so far")
                emit("skip", skipped=skipped)
                continue
            if verb == "status":
                total = sum(len(screen["variants"]) for screen in screens.values())
                print(f"  · {len(screens)} screen(s), {total} capture(s), {skipped} skipped, "
                      f"{poller.distinct_seen} distinct tree(s) seen while polling")
                for screen_name in order:
                    print(f"      {screen_name}: {len(screens[screen_name]['variants'])} variant(s)")
                if poller.last_error:
                    print(f"      ! last poll error: {poller.last_error}")
                continue
            if verb != "mark":
                print(f"  ? unknown command {verb!r} — mark <name> | skip | status | stop")
                continue
            if not name:
                print("  ? mark needs a name: mark Cart — empty")
                continue

            captured = capture()
            if captured.get("error"):
                print(f"  ! capture failed: {captured['error']}")
                emit("markFailed", name=name, error=str(captured["error"]))
                continue
            if name not in screens:
                screens[name] = {"name": name, "variants": []}
                order.append(name)
            screens[name]["variants"].append(captured)
            variant_index = len(screens[name]["variants"])
            note = "" if captured["complete"] else "  (truncated — scroll and mark again for the rest)"
            merged = len(captured["mergedIdentifiers"])
            print(f"  + {name} · variant {variant_index} · {captured['elementCount']} elements, "
                  f"{len(captured['uniqueIdentifiers'])} unique identifiers"
                  f"{f', {merged} merged' if merged else ''}{note}")
            # After every mark, not only at stop. A scan is minutes of somebody's manual navigation;
            # losing it to a crash on the tenth screen is the one outcome this tool cannot have.
            save(ended=False)
            emit("mark", name=name, variant=variant_index, elementCount=captured["elementCount"],
                 identifierCount=len(captured["uniqueIdentifiers"]), merged=merged, complete=captured["complete"])
    except KeyboardInterrupt:
        fatal = "interrupted"
        print("\n  · interrupted; writing what was captured")
    except Exception as error:
        fatal = f"{type(error).__name__}: {error}"
        print(f"\n  ! {fatal}; writing what was captured", file=sys.stderr)

    poller.stop_flag.set()

    document = build_document(metadata, started, args.interval, poller,
                              screens, order, skipped, ended=True, fatal=fatal)
    write_out(args.out, document)
    total = sum(len(screen["variants"]) for screen in document["screens"])
    print(f"  → {args.out} · {len(document['screens'])} screen(s), {total} capture(s)")
    emit("ended", out=str(args.out), screens=len(document["screens"]), captures=total, fatal=fatal)
    if args.format == "markdown":
        print()
        print(render_markdown(document))
    return 1 if fatal and fatal != "interrupted" else 0


if __name__ == "__main__":
    sys.exit(main())
