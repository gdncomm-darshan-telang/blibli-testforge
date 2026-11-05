# test-flow-recorder — progress

Current build state — what's actually built and working, not a proposal or a changelog narrative.
See `plan.md` for the architecture map, standing invariants, and open items. No dates, timestamps,
or contributor names in this file, same convention as `plan.md`.

## Commands shipped

`/qa-init`, `/qa-harness`, `/qa-run`, `/qa-fix`, `/qa-scan`, `/qa-macro`.

## Setup (`/qa-init`)

Wires `QADriverKit` into a project's `.xcodeproj`/`.xcworkspace` additively (`scripts/qa_init.py`),
hard-fails on ambiguity (multiple UI test targets, unclassifiable build configurations) rather than
guessing. Nine numbered steps, ending in:
- **Step 8 — skill audit, not skippable.** `scripts/audit_platform_skills.py` checks whether the
  host project has the platform's required governing skill (iOS: a view-code codegen skill). Found
  → delegates to the extension-proposal path below. Missing and required → drafts a labelled
  scaffold under `~/Documents/<project>-QA/` and blocks `/qa-init` until the skill actually exists on
  a later re-run. Missing and not required (Android/web today) → reported, never blocking.
- **Step 9 — adaptation pass, optional, propose-only.** `scripts/propose_skill_extension.py`
  discovers the project's governing view-code skill(s) (a codegen-gate hook's `ALLOWED_SKILLS`, else
  a keyword heuristic) and proposes an accessibility-chain-building step to append to it — never
  applied automatically.

## Preflight (`scripts/preflight.py`)

Nine gates, fails closed, exit code 1 gates a run: skill-audit (new — re-checks the fingerprint from
`/qa-init` step 8, catches a skill deleted/renamed since setup), device unambiguous, driver
reachable, media roots agree, data channel has a rule, container freshness, rule schema, proof of
mock (`isMockServed: true` in the trace), fixture health.

## Fixtures (`scripts/capture_baseline.py` / `check_baseline.py`)

Provenance ladder, always explicit: `captured` (real 200 from trace) > `pack` (recorded pack
variant) > `authored` (hand-written, never clobbered by a re-run) > `synthesized` (new — no capture,
no pack: `scripts/synthesize_from_model.py` reads the endpoint's Swift `Codable` response model and
builds a schema-conformant body, every optional filled with a real value rather than left null;
every field it couldn't confidently fill lands in `synthesisWarnings`) > `missing`. `check_baseline.py`
compares a baseline's fields against the model's declared keys (`model-only` / `body-only` findings);
running it against a synthesized body is a self-check, not a validation.

## Accessibility identifiers (`scripts/scan_identifiers.py`, `a11y_map.py`)

Resolves an identifier to the string the app actually applies, following value-transforming
accessors. `--chain-out` (new) appends every resolved `(file, line, identifier)` site to a
standing, deduped map that accumulates across runs instead of each scan overwriting the last.

## Network trail (`scripts/check_network_trail.py`)

Per case, in its recorded `networkWindowStart`/`networkWindowEnd` window: an endpoint the case named
that never fired (missing), one that fired that nothing named (unexpected), one that fired more than
it should have (duplicate). Informational only, same as everything below.

## Tracker validation

- `scripts/extract_trackers.py` — standalone, whole-session report: which TRMS ids fired, with what
  payload, checked against a hand-supplied `--contract`. Unchanged, still the tool a human runs
  directly.
- `scripts/check_tracker_validation.py` — the per-case gate. For each TRMS id a case names
  (`parse_test_cases.py` picks it up from a tracker column or an inline mention), checks fires inside
  the case's own window against a contract sourced from a saved TRMS tracker-detail snapshot (never
  hand-typed) via the host project's own `ios-analytics-tracker/scripts/extract_webarchive_contract.py`
  — cross-validated against itself, so a stale or half-edited TRMS page surfaces as a warning. Three
  findings: **did not fire**, **fired with a payload problem** (wrong event, blank required field),
  **duplicate fire** (new — exact-payload-equality comparison, so a list-impression tracker firing
  once per distinct item isn't mistaken for a bug). An id nobody named, firing anyway, is reported
  under `unexpectedTrmsIds`.

## Mocking (NetworkLens only)

All mock state goes through the host project's `networklens` MCP (`mcp__networklens__lens_*`) under
`QA_DATA_PLANE=simctl` (alias `networklens`); this plugin ships no mock server of its own.

- **2026-10-13 — `qa-mock` removed.** `mcp/qa-mock-server`, `mcp/qa-mock-mcp`, their `.mcp.json`
  entry, the `qa-mock` data-plane choice (`qa_init.py --data-plane`, `dataplane.py`, `preflight.py`'s
  live-state branch) and its `lens_set_offline` wildcard rule are gone. Why: never used on iOS here,
  and its unresolved `QA_MOCK_SERVER_URL` / `QA_MOCK_TRACE_DIR` placeholders made QA runs report
  "qa-mock unusable" and sometimes refuse to arm mocks. (Dated by explicit request, an exception to
  the no-dates convention above.)

## Macros (`scripts/macro_cli.py`, `/qa-macro`)

Records a named sequence of real `qa-driver` commands under `<root>/macros/<slug>.json`, for a
case's precondition to reference instead of re-describing the same taps every time. Never drives
anything itself; a replay re-executes and re-checks each stored step live, never as one trusted
atomic batch.

## Evidence (`scripts/build_evidence.py`)

Fixed eleven-column results table; renders the network-trail and tracker-trail findings in their own
sections after it.

## Not built / deliberately absent

- Android and web drivers — contracts only (`platforms/android.md`, `web.md`).
- An `api-mock` skill — mocking is authored directly instead (see `plan.md`'s invariants).
- Item-level (`items[]`) tracker parameter checking.
- `context-resumption.md` (see `plan.md`'s open items).
