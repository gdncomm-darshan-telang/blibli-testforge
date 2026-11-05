#!/usr/bin/env python3
"""Parses saved Confluence test-case pages into one case model per row.

A feature's test cases routinely span pages using different table schemas: a parent page with
ALL-CAPS headers and no id column, a component page with its own set, and the rest carrying a real
`Test Case ID`. Columns are therefore matched by what their header *means*, not by position, and
any column that matches nothing is reported rather than dropped silently.

Cases with no id in the document get a minted positional one (`AB-003`) and `isPositionalId: true`.
Minted ids are for local filenames and for the evidence page's own column — the test case document
is read-only to this skill and never gains an id it did not already have.

Usage:
    parse_test_cases.py <pages_dir> -o cases.json [--index pages/index.json]

`<pages_dir>` holds one `<pageId>.md` per page, each the verbatim `body` of a
getConfluencePage(contentFormat="markdown") response.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hash_step import hash_step, normalize  # noqa: E402

# Header text -> field name. Longest match wins, so "test case id" never resolves as "test case".
HEADER_FIELDS: list[tuple[str, str]] = [
    ("test case id", "caseId"),
    ("test scenario", "scenario"),
    ("test case", "scenario"),
    ("scenario", "scenario"),
    ("precondition", "precondition"),
    ("step action", "steps"),
    ("steps", "steps"),
    ("expected", "expected"),
    ("api", "api"),
    ("screenshot", "screenshot"),
    ("ios automation", "iosStatus"),
    ("android automation", "androidStatus"),
    ("module", "section"),
    ("section", "section"),
    ("component", "section"),
    ("priority", "priority"),
    ("type", "caseType"),
    ("trms id", "trmsIds"),
    ("trms", "trmsIds"),
    ("tracker id", "trmsIds"),
    ("tracker", "trmsIds"),
    # Last, and only ever as an exact match: "id" is a substring of "Android automation" and of
    # plenty of other headers, so a substring hit here would claim the wrong column.
    ("id", "caseId"),
]

# A precondition or steps cell naming a saved macro (`macro:Reset App Cache`) instead of spelling
# out every tap. Extraction only — resolving the name to a step sequence happens at plan time
# (`SKILL.md` Stage 3), not here; this stays pure text -> JSON like the rest of the parser.
MACRO_REFERENCE = re.compile(r"macro:\s*([^|\n]+)", re.IGNORECASE)

# TRMS ids ("ENG1072-0001") a case names, for `check_tracker_validation.py` at run time. Scanned
# across every field, not just a dedicated Tracker/TRMS column — a sheet with no such column still
# gets picked up wherever the tester wrote the id inline (a precondition note, an expected-result
# line), same "several signals, union them" approach `auth_requirement` already uses below.
TRMS_ID_PATTERN = re.compile(r"\b[A-Z]{2,4}\d{4}-\d{4}\b")
TRMS_SCAN_FIELDS = ("trmsIds", "scenario", "precondition", "steps", "expected", "api")

# A row is only a test case if it says what to do and what to expect. This is what separates the
# real table from the metadata tables (Jira/Figma/API Contract) sitting above it on the parent page.
#
# "What to do" arrives under either header: some sheets carry a Test Scenario column and fold the
# steps into it, others carry an explicit Steps column and no scenario at all. Demanding both calls
# the second kind "no test-case table found" and parses zero cases off a perfectly ordinary sheet.
ACTION_FIELDS = ("scenario", "steps")
REQUIRED_FIELDS = ("expected",)


def describes_a_case(record: dict) -> bool:
    """A row needs an expectation, plus at least one of the columns that say what to do."""
    if not all(normalize(record.get(field, "")) for field in REQUIRED_FIELDS):
        return False
    return any(normalize(record.get(field, "")) for field in ACTION_FIELDS)

ID_PATTERN = re.compile(r"^[A-Z]{1,4}-\d{1,4}$")
SEPARATOR_PATTERN = re.compile(r"^:?-{2,}:?$")

# Path fragments belonging to endpoints that require a signed-in user. A case whose API cell names
# one of these cannot run as a guest, which decides the order cases are worked in: every non-auth
# case first, then a pause for the user to log in by hand.
#
# Deliberately empty by default. This list is a property of the feature under test, and one carried
# over from another feature would silently mark the wrong cases gated — which produces a confident,
# entirely false discrepancy on every one of them. Supply it with `--auth-endpoint`, from the tech
# document's Auth column or from a 401 probe.
AUTH_PATH_FRAGMENTS: tuple[str, ...] = ()

# Wording that implies a signed-in precondition even when no auth endpoint is listed.
AUTH_TEXT_MARKERS = (
    "logged in",
    "logged-in",
    "login",
    "log in",
    "signed in",
    "sign in",
    "my account",
)


# What decided `requiresAuth`, strongest first. A case gated by `default-gated` is an *unresolved*
# classification, not a known one — the distinction matters when a whole gated batch turns out to
# have been runnable as a guest all along.
def auth_requirement(record: dict[str, str], case_id: str = "",
                     resolution: dict[str, object] | None = None) -> tuple[bool, str, str]:
    """Whether a case needs a signed-in user, what said so, and which signal that was.

    Documented scope answers this from the tech document's Auth column, which is where
    `AUTH_PATH_FRAGMENTS` came from. Scope with no such document has no column to read, so the
    remaining signals are: an explicit answer from the developer, an endpoint observed returning 401
    without a session, the case's own wording, and finally the scope-wide preconditions answer. A
    case still unresolved after all of them is gated — running a gated case as a guest produces a
    confident and entirely false discrepancy, whereas the reverse costs one extra click at the pause.
    """
    resolution = resolution or {}
    # The resolved id, not the document's cell: the two pages with no id column of their own carry
    # minted ids (`PC-001` from row 1), and those are the ids a developer names in an override.
    if case_id and case_id in set(resolution.get("gated") or ()):
        return True, "developer marked this case as needing a signed-in user", "developer"
    if case_id and case_id in set(resolution.get("guest") or ()):
        return False, "", "developer"

    api = normalize(record.get("api", "")).lower()
    for fragment in (*AUTH_PATH_FRAGMENTS, *(resolution.get("documented") or ())):
        if fragment and fragment.lower() in api:
            return True, f"auth endpoint in API column ({fragment})", "techDoc"
    for fragment in resolution.get("probed") or ():
        if fragment and fragment.lower() in api:
            return True, f"endpoint returned 401 without a session ({fragment})", "probe401"

    haystack = " ".join(
        normalize(record.get(field, "")).lower() for field in ("scenario", "precondition", "steps", "expected")
    )
    for marker in AUTH_TEXT_MARKERS:
        if marker in haystack:
            return True, f"wording implies a signed-in user ({marker!r})", "wording"

    preconditions = str(resolution.get("preconditions") or "none")
    if preconditions in ("signed-in", "unknown"):
        return True, (f"no signal either way and the scope's preconditions are `{preconditions}` — "
                      "gated by default rather than risking a false discrepancy"), "default-gated"
    return False, "", ""


def clean_header(cell: str) -> str:
    return normalize(cell.replace("*", "")).lower()


def field_for(header: str) -> str | None:
    """Exact match first, then substring.

    Column headers are short and collide: a sheet whose id column is headed plainly "ID" needs that
    to win, while "Android automation" must not be claimed by the same entry. Trying equality across
    the whole table before any substring test settles both without ordering tricks — and a sheet
    whose ids go unmatched does not fail loudly, it silently mints positional ones and every id in
    the evidence report stops matching the document it came from.
    """
    cleaned = clean_header(header)
    for text, field in HEADER_FIELDS:
        if text == cleaned:
            return field
    for text, field in HEADER_FIELDS:
        if len(text) > 2 and text in cleaned:
            return field
    return None


def split_row(buffer: str) -> list[str]:
    """Cells of a markdown row, dropping the empty strings either side of the outer pipes."""
    parts = buffer.split("|")
    if len(parts) < 3:
        return []
    return [part.strip() for part in parts[1:-1]]


def logical_rows(lines: list[str], column_count: int):
    """Yields rows, re-joining cells that a page wrapped across several physical lines.

    Confluence's markdown puts a hard line break inside a cell (an API column listing six
    endpoints, say), so a row is complete only once its accumulated pipe count matches the header's.
    """
    buffer = ""
    for line in lines:
        stripped = line.rstrip("\n")
        if not stripped.strip():
            if buffer:
                yield buffer
                buffer = ""
            continue
        buffer = stripped if not buffer else f"{buffer}\n{stripped}"
        if len(split_row(buffer)) >= column_count:
            yield buffer
            buffer = ""
    if buffer:
        yield buffer


def parse_page(path: Path, prefix: str,
               resolution: dict[str, object] | None = None) -> tuple[list[dict[str, Any]], list[str]]:
    lines = path.read_text().splitlines()
    page_id = path.stem

    tables = header_rows(lines)
    if not tables:
        return [], [f"{page_id}: no test-case table found"]

    cases: list[dict[str, Any]] = []
    unmapped: list[str] = []
    position = 0
    for table_index, (header_index, mapping, table_unmapped) in enumerate(tables):
        unmapped.extend(table_unmapped)
        end = tables[table_index + 1][0] if table_index + 1 < len(tables) else len(lines)
        column_count = len(split_row(lines[header_index]))
        position, table_cases = parse_rows(lines[header_index + 1 : end], mapping, column_count,
                                           page_id, prefix, resolution, position)
        cases.extend(table_cases)

    return cases, [f"{page_id}: unmapped column {name!r}" for name in dict.fromkeys(unmapped) if normalize(name)]


def header_rows(lines: list[str]) -> list[tuple[int, dict[int, str], list[str]]]:
    """Every test-case table on the page, not just the first.

    A sheet routinely splits its cases into one table per screen under its own heading, and those
    tables need not share a schema. Parsing only the first silently drops the rest; parsing the whole
    page under the first table's column mapping is worse, because the later headers arrive as rows
    and become cases whose id is the word "ID".
    """
    found: list[tuple[int, dict[int, str], list[str]]] = []
    for index, line in enumerate(lines):
        cells = split_row(line)
        if len(cells) < 4:
            continue
        candidate = {position: field_for(cell) for position, cell in enumerate(cells)}
        fields = {field for field in candidate.values() if field}
        if all(required in fields for required in REQUIRED_FIELDS) and fields & set(ACTION_FIELDS):
            mapping = {position: field for position, field in candidate.items() if field}
            unmapped = [cells[position] for position, field in candidate.items() if not field]
            found.append((index, mapping, unmapped))
    return found


def parse_rows(lines: list[str], mapping: dict[int, str], column_count: int, page_id: str,
               prefix: str, resolution: dict[str, object] | None,
               position: int) -> tuple[int, list[dict[str, Any]]]:
    cases: list[dict[str, Any]] = []
    for buffer in logical_rows(lines, column_count):
        cells = split_row(buffer)
        if not cells or all(SEPARATOR_PATTERN.match(cell) for cell in cells if cell):
            continue
        record = {field: cells[index] for index, field in mapping.items() if index < len(cells)}
        if not describes_a_case(record):
            continue

        position += 1
        document_id = normalize(record.get("caseId", "").replace("*", ""))
        is_positional = not ID_PATTERN.match(document_id)
        case_id = document_id if not is_positional else f"{prefix}-{position:03d}"
        requires_auth, auth_reason, auth_source = auth_requirement(record, case_id, resolution)
        case = {
            "caseId": case_id,
            "isPositionalId": is_positional,
            "positionInTable": position,
            "pageId": page_id,
            "requiresAuth": requires_auth,
            "authReason": auth_reason,
            "authSource": auth_source,
            "sourceHash": hash_step(
                " ".join(normalize(record.get(field, "")) for field in ("scenario", "steps", "expected"))
            )[:12],
        }
        for field in ("scenario", "precondition", "steps", "expected", "api", "screenshot", "iosStatus", "androidStatus", "section", "priority", "caseType"):
            if field in record:
                case[field] = record[field]
        macro_refs = [match.strip() for field in ("precondition", "steps")
                     for match in MACRO_REFERENCE.findall(case.get(field, ""))]
        if macro_refs:
            case["macroRefs"] = macro_refs
        trms_source = " ".join(normalize(record.get(field, "")) for field in TRMS_SCAN_FIELDS)
        trms_ids = sorted(set(TRMS_ID_PATTERN.findall(trms_source)))
        if trms_ids:
            case["trmsIds"] = trms_ids
        cases.append(case)

    return position, cases


# Case-id prefixes for pages that carry no id column of their own, as `{pageId: prefix}` supplied
# via `--page-prefix`. Pinning one keeps a minted id naming the same case even if the page is later
# renamed, which deriving the prefix from the title cannot promise.
PAGE_PREFIXES: dict[str, str] = {}


def prefix_for(page_id: str, index: dict[str, dict[str, Any]]) -> str:
    """Initials of the page title after "Test Cases - ", so a minted id hints at its own page."""
    if page_id in PAGE_PREFIXES:
        return PAGE_PREFIXES[page_id]
    title = index.get(page_id, {}).get("title", "")
    tail = title.split(" - ", 1)[1] if " - " in title else title
    words = [word for word in re.findall(r"[A-Za-z]+", tail) if word.lower() not in {"and", "the", "section", "component", "flow", "modal"}]
    initials = "".join(word[0].upper() for word in words[:2])
    return initials or "TC"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("pages_dir", type=Path)
    parser.add_argument("-o", "--output", type=Path, required=True)
    parser.add_argument("--index", type=Path, help="pages/index.json, for page titles and versions")
    parser.add_argument("--preconditions", choices=("none", "signed-in", "state", "unknown"), default="none",
                        help="The scope-wide preconditions answer. `signed-in` or `unknown` gates every case "
                             "no other signal resolved, since a gated case run as a guest is a false "
                             "discrepancy. Default `none` leaves unresolved cases runnable as a guest.")
    parser.add_argument("--gated-case", action="append", default=[], metavar="ID",
                        help="Case the developer says needs a signed-in user. Repeatable, wins over every "
                             "other signal.")
    parser.add_argument("--guest-case", action="append", default=[], metavar="ID",
                        help="Case the developer says runs as a guest, overriding the heuristics. Repeatable.")
    parser.add_argument("--auth-endpoint-doc", action="append", default=[], metavar="FRAGMENT",
                        help="Auth-only endpoint named by the tech document's Auth column. Recorded "
                             "as authSource=techDoc, unlike --auth-endpoint's 401 probe. Repeatable.")
    parser.add_argument("--page-prefix", action="append", default=[], metavar="PAGEID=XX",
                        help="Case-id prefix for a page with no id column of its own. Repeatable.")
    parser.add_argument("--auth-endpoint", action="append", default=[], metavar="FRAGMENT",
                        help="Endpoint path fragment observed returning 401 without a session. Repeatable — "
                             "this is what substitutes for a tech document's Auth column.")
    args = parser.parse_args()

    index: dict[str, dict[str, Any]] = {}
    if args.index and args.index.exists():
        index = {str(entry["id"]): entry for entry in json.loads(args.index.read_text())}

    resolution = {
        "preconditions": args.preconditions,
        "gated": args.gated_case,
        "guest": args.guest_case,
        "probed": args.auth_endpoint,
        "documented": args.auth_endpoint_doc,
    }

    for pair in args.page_prefix:
        page_id, _, prefix = pair.partition("=")
        if not page_id or not prefix:
            raise SystemExit(f"--page-prefix expects PAGEID=XX, got {pair!r}")
        PAGE_PREFIXES[page_id] = prefix

    all_cases: list[dict[str, Any]] = []
    warnings: list[str] = []
    for path in sorted(args.pages_dir.glob("*.md")):
        cases, page_warnings = parse_page(path, prefix_for(path.stem, index), resolution)
        warnings.extend(page_warnings)
        entry = index.get(path.stem, {})
        for case in cases:
            case["pageTitle"] = entry.get("title", "")
            case["pageVersion"] = entry.get("versionNumber")
        all_cases.extend(cases)
        minted = sum(1 for case in cases if case["isPositionalId"])
        gated = sum(1 for case in cases if case["requiresAuth"])
        print(f"  {path.stem}: {len(cases):3d} cases ({minted} minted ids, {gated} need login)  {entry.get('title', '')}")

    duplicates = {case["caseId"] for case in all_cases if [c["caseId"] for c in all_cases].count(case["caseId"]) > 1}
    if duplicates:
        warnings.append(f"duplicate case ids: {', '.join(sorted(duplicates))}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(all_cases, indent=2) + "\n")
    guest_ready = sum(1 for case in all_cases if not case["requiresAuth"])
    print(f"\n{len(all_cases)} cases -> {args.output}")
    print(f"  {guest_ready} runnable as a guest, {len(all_cases) - guest_ready} need a signed-in user")
    sources = [case["authSource"] for case in all_cases if case["requiresAuth"]]
    if sources:
        print("  gated by: " + ", ".join(f"{value} {sources.count(value)}" for value in sorted(set(sources))))
    unresolved = sources.count("default-gated")
    if unresolved:
        print(f"  ! {unresolved} case(s) gated only because nothing resolved them. Narrow this with "
              "--gated-case/--guest-case or an --auth-endpoint from a 401 probe; every one of them "
              "otherwise waits behind the login pause without needing to.")
    for warning in warnings:
        print(f"  ! {warning}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    main()
