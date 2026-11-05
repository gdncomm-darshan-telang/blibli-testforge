#!/usr/bin/env python3
"""The apply-fixes pass: gate, apply, re-run, settle. A separate invocation, never part of a run.

A run proposes; this applies. The split is the whole safety model, because the two have opposite
failure modes: a run that gets a verdict wrong costs a conversation, while a pass that edits code on
a verdict nobody adjudicated costs a defect nobody knows was introduced.

So every check here is one that answers "may this diff land", and none of them are advisory:

  * the entry gate  — has this run earned the right to edit code at all (`healing.md`)
  * eligibility     — is the patch one a run was allowed to propose (`build_evidence.patch_faults`,
                      imported rather than restated, so the two can never drift apart)
  * applicability   — is the diff something `git apply` can land, on a file that is clean, inside
                      the boundary, at a blast radius the patch's own class claims
  * all-or-nothing  — every patch is checked before any is applied, and a failure part-way through
                      reverts what already landed
  * settle          — a patch whose case does not now pass is rolled back, per `healing.md`

What this script does *not* do is re-run the cases. Driving the app belongs to the harness and to
whoever is holding the conversation; the script owns the file mutations and the bookkeeping, and
those two responsibilities are kept apart on purpose — a script that both edits code and judges
whether the edit worked has nobody checking it.

Usage:
    apply_fixes.py plan   <results>.json [--case TC-012]… [--ruled-by NAME] [--repo .] [--json]
    apply_fixes.py apply  <results>.json [--journal <run>/fixes.json] [--case TC-012 --ruled-by NAME]
                          [--repo .] [--dry-run]
    apply_fixes.py settle --journal <run>/fixes.json --rerun <rerun-results>.json [--repo .]
    apply_fixes.py revert --journal <run>/fixes.json [--repo .]
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))

# Eligibility is defined once, in the script that writes the report, and imported here. Restating it
# would let the gate that refuses a patch and the gate that applies one disagree, and the direction
# that drift takes is always the same: the applier ends up more permissive than the reporter.
from build_evidence import (  # noqa: E402
    authority_of,
    patch_faults,
    patch_of,
    rca_of,
    read_results,
    summary_counts,
)

# `healing.md`'s entry gate. A run that could not reach half its preconditions has not earned the
# right to edit code, and a five-case page cannot clear a rate gate on two passes.
PASS_RATE_FLOOR = 0.80
ADJUDICATED_FLOOR = 10
ADJUDICATED = ("PASS", "DISCREPANCY")

# A whitelisted class is a claim about blast radius. A "spacing constant" arriving as a 300-line diff
# is not that class of change, whatever the field says.
MAX_CHANGED_LINES = 24

# Paths no automated pass may touch here, and why each one:
#   .claude/, CLAUDE.md   — the tooling and the policy that governs it. A pass that can edit its own
#                           rules is not gated by them.
#   project.pbxproj       — a generated-looking file that is order-sensitive and merge-hostile; this
#                           project's standing rule is hand-edit only, verified by diff.
#   test targets          — the whitelist is app-side. A patch that edits a test to match the app is
#                           the exact inversion this whole skill exists to prevent.
FORBIDDEN_SUBSTRINGS = (
    ".claude/", "CLAUDE.md", ".github/", "project.pbxproj", ".xcodeproj/", ".xctestplan",
    ".xcscheme", "Package.resolved", "XCUITest", "UITests/", "Tests/", "-SwiftTesting/",
)


def run_git(repo: Path, *arguments: str, stdin: str | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", str(repo), *arguments], input=stdin, capture_output=True,
                          text=True, check=False)


def git_root(repo: Path) -> Path | None:
    completed = run_git(repo, "rev-parse", "--show-toplevel")
    return Path(completed.stdout.strip()) if completed.returncode == 0 else None


def load(path: Path) -> Any:
    return json.loads(path.read_text())


def digest(text: str) -> str:
    return hashlib.sha256(text.encode()).hexdigest()[:12]


def diff_files(diff: str) -> list[str]:
    """The paths a unified diff writes to, read from its `+++` lines."""
    paths = []
    for line in diff.splitlines():
        if line.startswith("+++ ") and not line.startswith("+++ /dev/null"):
            path = line[4:].strip().split("\t")[0]
            paths.append(path[2:] if path[:2] in ("a/", "b/") else path)
    return paths


def changed_lines(diff: str) -> int:
    return sum(1 for line in diff.splitlines()
               if (line.startswith(("+", "-")) and not line.startswith(("+++", "---"))))


def applicability_faults(repo: Path, result: dict[str, Any]) -> list[str]:
    """Why this diff cannot be landed, as opposed to why it should not have been proposed.

    Separate from `patch_faults` because the two run in different places: the report is built where
    the results are, often with no checkout at all, while this needs the repository in front of it.
    """
    patch = patch_of(result)
    diff = str(patch.get("diff") or "")
    faults: list[str] = []

    if "@@" not in diff or "+++ " not in diff:
        return [f"`diff` is not a unified diff — apply-fixes lands patches with `git apply`, so the "
                f"field needs `--- a/<path>`, `+++ b/<path>` and `@@` hunk headers, not a fragment"]

    for marker, why in (("new file mode", "creates a file"), ("deleted file mode", "deletes a file"),
                        ("rename from", "renames a file")):
        if marker in diff:
            faults.append(f"the diff {why}; every whitelisted class edits an existing file in place")

    targets = diff_files(diff)
    if len(targets) != 1:
        faults.append(f"the diff writes to {len(targets)} file(s) — a whitelisted change is "
                      "single-file by construction")
    for target in targets:
        if any(fragment in target for fragment in FORBIDDEN_SUBSTRINGS):
            faults.append(f"`{target}` is outside the boundary an automated pass may edit")
        elif not (repo / target).is_file():
            faults.append(f"`{target}` is not a file in this checkout — wrong repo, or a stale patch")

    count = changed_lines(diff)
    if count > MAX_CHANGED_LINES:
        faults.append(f"{count} changed lines exceeds the {MAX_CHANGED_LINES}-line cap for a "
                      f"`{patch.get('class')}` change — that is a different kind of change than the "
                      "class claims")

    dirty = {line[3:].strip() for line in
             run_git(repo, "status", "--porcelain", "--", *targets).stdout.splitlines() if line}
    if dirty:
        faults.append("target file has uncommitted changes (" + ", ".join(sorted(dirty))
                      + ") — a revert could not tell this pass's edit from the developer's work")

    if not faults:
        check = run_git(repo, "apply", "--check", "-", stdin=ensure_newline(diff))
        if check.returncode != 0:
            faults.append("`git apply --check` refused it: "
                          + (check.stderr.strip().splitlines() or ["no detail"])[0])
    return faults


def ensure_newline(diff: str) -> str:
    return diff if diff.endswith("\n") else diff + "\n"


def entry_gate(results: list[dict[str, Any]], run: dict[str, Any],
               named: list[str], ruled_by: str | None) -> tuple[bool, list[str]]:
    """`healing.md`'s two preconditions, plus the named-case override.

    The rate says whether the harness was trustworthy. The posture says whether any failure could be
    adjudicated at all — a run on scope with no tech document can score 95% and still have nothing
    eligible, because nothing there reaches `app-wrong` on evidence. So posture is checked first and
    separately, exactly as the contract has it.

    The override is for the one case the contract carves out: a developer who has already ruled on
    specific cases. It bypasses the rate, the floor and the posture, because a human ruling is what
    those three were standing in for — and it demands a name, recorded in the journal, so the
    authority behind the edit is attributable afterwards rather than implied.
    """
    lines: list[str] = []
    counts = summary_counts(results)
    adjudicated = sum(counts.get(verdict, 0) for verdict in ADJUDICATED)
    passed = counts.get("PASS", 0)
    rate = passed / adjudicated if adjudicated else 0.0
    posture = str(run.get("posture") or "documented")

    if named:
        if not ruled_by:
            lines.append("! --case needs --ruled-by: the override exists for a developer who has "
                         "ruled on those cases, and the ruling has to be attributable")
            return False, lines
        lines.append(f"override: {len(named)} named case(s), ruled by {ruled_by} — rate, floor and "
                     "posture gates bypassed, eligibility gates are not")
        return True, lines

    lines.append(f"adjudicated {adjudicated} (PASS {passed} + DISCREPANCY "
                 f"{counts.get('DISCREPANCY', 0)}); BLOCKED {counts.get('BLOCKED', 0)} and "
                 f"UNVERIFIABLE {counts.get('UNVERIFIABLE', 0)} excluded")
    ok = True
    if posture != "documented":
        lines.append(f"! posture is `{posture}` — with no tech document a discrepancy records a "
                     "disagreement, not a proven fault, so no case here can reach `app-wrong` on "
                     "evidence. Rule on specific cases and name them with --case instead")
        ok = False
    if adjudicated < ADJUDICATED_FLOOR:
        lines.append(f"! {adjudicated} adjudicated case(s) is below the floor of {ADJUDICATED_FLOOR}")
        ok = False
    if rate < PASS_RATE_FLOOR:
        lines.append(f"! pass rate {rate:.0%} is below {PASS_RATE_FLOOR:.0%} — a run with this much "
                     "in disagreement is not one to let a loop edit unattended")
        ok = False
    if ok:
        lines.append(f"pass rate {rate:.0%}, posture `{posture}` — gate open")
    return ok, lines


def select(results: list[dict[str, Any]], named: list[str]) -> tuple[list[dict[str, Any]], list[str]]:
    """Cases carrying a patch, split into those that may land and the reasons the rest may not."""
    faults = patch_faults(results)
    refused = [f"{case_id}: {reason}" for case_id, reason in faults]
    blocked = {case_id for case_id, _ in faults}
    candidates = []
    for result in results:
        if not patch_of(result).get("diff"):
            continue
        if named and result["caseId"] not in named:
            continue
        if result["caseId"] in blocked:
            continue
        candidates.append(result)
    missing = [case_id for case_id in named
               if case_id not in {result["caseId"] for result in results}]
    refused += [f"{case_id}: named with --case but not in this results file" for case_id in missing]

    # The journal is keyed by case id and `settle` looks a verdict up by it, so two patched results
    # sharing an id would let one edit be judged by the other's re-run. Refuse both rather than pick.
    patched_ids = [result["caseId"] for result in candidates]
    duplicated = {case_id for case_id in patched_ids if patched_ids.count(case_id) > 1}
    if duplicated:
        candidates = [result for result in candidates if result["caseId"] not in duplicated]
        refused += [f"{case_id}: two patched results share this id — the journal and the re-run are "
                    "both keyed by it, so neither patch can be judged by its own case"
                    for case_id in sorted(duplicated)]
    return candidates, refused


def plan_lines(repo: Path, candidates: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[str]]:
    """Split candidates into landable and unlandable, keeping the reason with the case."""
    landable, refused = [], []
    for result in candidates:
        faults = applicability_faults(repo, result)
        if faults:
            refused += [f"{result['caseId']}: {fault}" for fault in faults]
        else:
            landable.append(result)
    return landable, refused


def rerun_plan(landable: list[dict[str, Any]]) -> list[str]:
    """What has to be re-driven once the patches are in, and with which commands.

    A patch is not evidence. The case it came from has to run again, against the same fixture, and
    the report has to carry the new clip beside the old one — which is why the recorded command trail
    is reproduced here rather than left to be reconstructed.
    """
    lines = []
    for result in landable:
        commands = result.get("commands") or []
        fixture = result.get("fixture") or "none"
        lines.append(f"    {result['caseId']}: {len(commands)} command(s), fixture {fixture}")
    return lines


def journal_path(explicit: Path | None, results_file: Path) -> Path:
    return explicit or results_file.parent / "fixes.json"


def write_journal(path: Path, entries: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"entries": entries}, indent=2) + "\n")


def read_journal(path: Path) -> list[dict[str, Any]]:
    return list(load(path).get("entries") or [])


def command_plan(args: argparse.Namespace) -> int:
    repo = git_root(args.repo)
    if repo is None:
        print(f"! {args.repo} is not inside a git repository — apply-fixes lands and reverts "
              "patches with git, and has no other way to undo itself")
        return 1
    results, run = read_results(args.results)
    open_gate, gate_notes = entry_gate(results, run, args.case, args.ruled_by)
    candidates, refused = select(results, args.case)
    landable, unlandable = plan_lines(repo, candidates)
    refused += unlandable

    if args.json:
        print(json.dumps({
            "gate": {"open": open_gate, "notes": gate_notes},
            "landable": [{"caseId": result["caseId"], "class": patch_of(result).get("class"),
                          "file": (diff_files(str(patch_of(result).get("diff") or "")) or [None])[0],
                          "rca": rca_of(result)} for result in landable],
            "refused": refused,
        }, indent=2))
        return 0 if open_gate and landable else 1

    print(f"apply-fixes plan · repo {repo}")
    for note in gate_notes:
        print(f"  {note}")
    print(f"  {len(landable)} patch(es) landable, {len(refused)} refusal(s)")
    for result in landable:
        patch = patch_of(result)
        target = (diff_files(str(patch.get("diff"))) or ["?"])[0]
        print(f"    + {result['caseId']}  {patch.get('class')}  {target}  "
              f"({changed_lines(str(patch.get('diff')))} changed lines)")
    for reason in refused:
        print(f"    ! {reason}")
    if landable and open_gate:
        print("  re-run after applying:")
        print("\n".join(rerun_plan(landable)))
    if not open_gate:
        print("  gate closed — nothing may be applied. See contracts/healing.md")
        return 1
    return 0 if landable else 1


def command_apply(args: argparse.Namespace) -> int:
    repo = git_root(args.repo)
    if repo is None:
        print(f"! {args.repo} is not inside a git repository")
        return 1
    results, run = read_results(args.results)
    open_gate, gate_notes = entry_gate(results, run, args.case, args.ruled_by)
    for note in gate_notes:
        print(f"  {note}")
    if not open_gate:
        print("  gate closed — nothing applied. See contracts/healing.md")
        return 1

    candidates, refused = select(results, args.case)
    landable, unlandable = plan_lines(repo, candidates)
    for reason in refused + unlandable:
        print(f"  ! {reason}")
    if not landable:
        print("  no landable patch — nothing applied")
        return 1
    if args.dry_run:
        print(f"  dry run: {len(landable)} patch(es) would land, none written")
        return 0

    # Everything was checked above before anything is written. A patch that fails here fails after a
    # passing `--check`, which means the tree moved under us — so the whole set comes back out rather
    # than leaving a half-applied state nobody chose.
    entries: list[dict[str, Any]] = []
    for result in landable:
        patch = patch_of(result)
        diff = ensure_newline(str(patch.get("diff")))
        applied = run_git(repo, "apply", "-", stdin=diff)
        if applied.returncode != 0:
            print(f"  ! {result['caseId']}: apply failed after a passing check — "
                  f"{applied.stderr.strip()}")
            for entry in reversed(entries):
                run_git(repo, "apply", "-R", "-", stdin=ensure_newline(entry["diff"]))
            print(f"  reverted {len(entries)} patch(es) already applied — the tree is as it was")
            return 1
        entries.append({
            "caseId": result["caseId"],
            "class": patch.get("class"),
            "file": (diff_files(diff) or [None])[0],
            "diff": diff,
            "diffSha": digest(diff),
            "verdictBefore": result.get("verdict", "").upper(),
            "authority": authority_of(result),
            "rca": rca_of(result),
            "ruledBy": args.ruled_by,
            "appliedAt": datetime.now().isoformat(timespec="seconds"),
            "verdictAfter": None,
            "reverted": False,
        })
        print(f"  + {result['caseId']}  {entry_file(entries[-1])}")

    path = journal_path(args.journal, args.results)
    write_journal(path, entries)
    print(f"  {len(entries)} patch(es) applied, journal at {path}")
    print("  next: re-run exactly these cases through the harness, then settle with")
    print(f"    apply_fixes.py settle --journal {path} --rerun <rerun-results>.json")
    return 0


def entry_file(entry: dict[str, Any]) -> str:
    return f"{entry.get('class')}  {entry.get('file')}"


def command_settle(args: argparse.Namespace) -> int:
    """Keep a patch only if the case now passes; revert every other one.

    `healing.md`'s rollback rule, applied to app-side changes: a heal that does not change the
    verdict is rolled back. Stricter here than "changed" — the bar is `PASS`. A case that moved from
    `DISCREPANCY` to `BLOCKED` changed verdict without being fixed, and leaving that edit in the tree
    on the strength of the movement is how a loop reports progress it did not make.
    """
    repo = git_root(args.repo)
    if repo is None:
        print(f"! {args.repo} is not inside a git repository")
        return 1
    entries = read_journal(args.journal)
    if not entries:
        print(f"  journal {args.journal} has no entries — nothing to settle")
        return 1
    rerun, _ = read_results(args.rerun)
    verdicts = {result["caseId"]: result.get("verdict", "").upper() for result in rerun}

    kept, rolled, unjudged = [], [], []
    for entry in entries:
        if entry.get("reverted"):
            continue
        verdict = verdicts.get(entry["caseId"])
        entry["verdictAfter"] = verdict
        if verdict is None:
            unjudged.append(entry["caseId"])
        if verdict == "PASS":
            kept.append(entry)
            continue
        reverted = run_git(repo, "apply", "-R", "-", stdin=ensure_newline(entry["diff"]))
        if reverted.returncode != 0:
            print(f"  ! {entry['caseId']}: revert failed — {reverted.stderr.strip()}. The edit is "
                  "still in the tree; back it out by hand before committing anything")
            continue
        entry["reverted"] = True
        rolled.append(entry)

    write_journal(args.journal, entries)
    for entry in kept:
        print(f"  kept    {entry['caseId']}  {entry_file(entry)}  "
              f"{entry['verdictBefore']} → PASS")
    for entry in rolled:
        after = entry["verdictAfter"] or "not re-run"
        print(f"  rolled  {entry['caseId']}  {entry_file(entry)}  "
              f"{entry['verdictBefore']} → {after}")
    print(f"  {len(kept)} kept, {len(rolled)} rolled back")
    if unjudged:
        print(f"  ! {len(unjudged)} patched case(s) absent from the re-run: "
              f"{', '.join(unjudged)} — rolled back, because an unmeasured edit is not a fix")
    if kept:
        print("  the kept edits are unstaged in the working tree: review the diff, then commit them "
              "as their own change with the case ids in the message")
    return 0


def command_revert(args: argparse.Namespace) -> int:
    repo = git_root(args.repo)
    if repo is None:
        print(f"! {args.repo} is not inside a git repository")
        return 1
    entries = read_journal(args.journal)
    live = [entry for entry in entries if not entry.get("reverted")]
    if not live:
        print("  nothing left to revert — every journal entry is already rolled back")
        return 0
    failed = []
    for entry in reversed(live):
        reverted = run_git(repo, "apply", "-R", "-", stdin=ensure_newline(entry["diff"]))
        if reverted.returncode == 0:
            entry["reverted"] = True
            print(f"  reverted {entry['caseId']}  {entry_file(entry)}")
        else:
            failed.append(entry["caseId"])
            print(f"  ! {entry['caseId']}: {reverted.stderr.strip()}")
    write_journal(args.journal, entries)
    print(f"  {len(live) - len(failed)} reverted, {len(failed)} left in the tree")
    return 1 if failed else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--repo", type=Path, default=Path("."),
                        help="Anywhere inside the checkout to patch. Defaults to the cwd.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    def add_case_flags(target: argparse.ArgumentParser) -> None:
        target.add_argument("--case", action="append", default=[],
                            help="Restrict to these case ids, bypassing the rate, floor and posture "
                                 "gates. For a developer who has ruled on them; needs --ruled-by.")
        target.add_argument("--ruled-by",
                            help="Who ruled on the named cases. Recorded in the journal.")

    plan = subparsers.add_parser("plan", help="What would land, what is refused, and why. Writes nothing.")
    plan.add_argument("results", type=Path)
    add_case_flags(plan)
    plan.add_argument("--json", action="store_true")
    plan.set_defaults(handler=command_plan)

    apply_parser = subparsers.add_parser("apply", help="Land the eligible patches and open a journal.")
    apply_parser.add_argument("results", type=Path)
    add_case_flags(apply_parser)
    apply_parser.add_argument("--journal", type=Path,
                              help="Defaults to fixes.json beside the results file.")
    apply_parser.add_argument("--dry-run", action="store_true")
    apply_parser.set_defaults(handler=command_apply)

    settle = subparsers.add_parser("settle", help="Keep the patches whose cases now pass, revert the rest.")
    settle.add_argument("--journal", type=Path, required=True)
    settle.add_argument("--rerun", type=Path, required=True,
                        help="results.json from the re-run of exactly the patched cases.")
    settle.set_defaults(handler=command_settle)

    revert = subparsers.add_parser("revert", help="Roll back everything in the journal.")
    revert.add_argument("--journal", type=Path, required=True)
    revert.set_defaults(handler=command_revert)

    args = parser.parse_args()
    return args.handler(args)


if __name__ == "__main__":
    sys.exit(main())
