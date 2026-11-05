# Walkthrough kit — v4 Mac app design (R0 gate)

_Prepared 2026-10-13 (D-076). Run on the Design artifact
<https://claude.ai/artifact/EPisTUsbZ1rTuov3qvKfwW>, boards C1–C14, with `tutorials.md` read aloud as
the tips. No code is written until this passes and sign-off is recorded as a decision. The v3 kit
(`walkthrough.md`) is history._

## 1. Purpose and pass criteria

Check that people who have never seen the TestForge can say **where to start** and **what the app
does**, the exact complaint from QA, the Engineering Manager and the Technology VP.

**Pass (all must hold):**

- Each participant answers Q0 correctly within 60 seconds of seeing C1.
- Every task is completed **unaided**, with **at most 1 question per task**.
- Every point of confusion is fixed in the boards or `tutorials.md` before sign-off.

**Targets to note (not pass/fail):** T1 under 2 minutes of pointing; T5 under 1 minute.

## 2. Who

| Role | Person | Does |
|---|---|---|
| Participant A | a developer (git/Xcode, little QA tooling) | Q0, T1–T5, T7 |
| Participant B | a QA engineer (knows the app, no git/Xcode) | Q0, T1–T4, T6, T7 |
| Optional C | a manager or leader | Q0, T1, T7 only |
| Facilitator | shows boards, reads tips, never helps | — |
| Observer | fills §5 | may be the facilitator |

**Setup:** share the screen with the Design canvas zoomed to one board at a time. The participant
"clicks" by pointing or saying what they would press; the facilitator moves to the board that
results. 30–40 minutes per participant.

## 3. Task cards

### Q0 — First impression (show C1 for 60 s, then hide it)

"What does this app do, and what would you press first to test something?"
**Expected:** it runs app tests on the phone and shows each step; tick tests → Run (or Get ready
first if something is not green).

### T1 — First launch (C2 → C6)

"You just installed the app. Get it ready to test."
**Expected:** reads the checks; on C6 picks the right Fix for each item (Build app…, Open System
Settings, Connect…) and explains what Connect will change.

### T2 — Run three tests on your branch (C1 → C3)

"Run SF-011, SF-025 and SF-012 three times each on fix/flashsale-header-invert, and watch them."
**Expected:** ticks the tests, sets Repeat 3×, presses Run, uses Arrange with Simulator, and on C3
can say which step is in progress and where it is on the phone.

### T3 — A test failed (C9)

"One test failed. Is it a real bug? What do you do next?"
**Expected:** finds SF-010, reads expected vs seen, opens the proof, notices it is flaky (failed 1 of
3), and chooses Re-run 3× or Ask Claude to look, knowing the latter uses Claude usage.

### T4 — Did my branch break anything? (C10)

"Before you merge, show what changed compared with develop, and share it."
**Expected:** uses Compare with develop, names the newly failing and fixed tests, exports or
publishes the report to their own page.

### T5 — Developer: a test that was never run (C1 → C7)

"Run SF-016 for the first time."
**Expected:** sees it needs a first run with Claude, approves or denies the fake-data request with a
reason, can read the usage pill, and knows later runs replay without Claude.

### T6 — QA: add a corner case with fake data (C12 → C13)

"Check what the Flash Sale page does when the Sub Flash Sale server returns an error."
**Expected:** finds Fake server data, picks Sub Flash Sale range → Server error, knows it switches
off by itself; then finds the saved steps for a test in Recorded steps.

### T7 — Find help (C4)

"You forgot how the console works. Get the tutorial again, then show someone the whole flow."
**Expected:** uses the panel's ? button or Settings › Tutorials › Play; starts the Demo run.

## 4. After the tasks (5 minutes)

1. "In one sentence, what does this app do?"
2. "What was the most confusing moment?"
3. "Which word or icon did you not understand?"
4. "Would you present this to your manager? What would you change first?"

## 5. Observation sheet (one per participant)

| Task | Done unaided? | Questions | Time | Confusion (words, icons, screens) |
|---|---|---|---|---|
| Q0 | | | | |
| T1 | | | | |
| T2 | | | | |
| T3 | | | | |
| T4 | | | | |
| T5 | | | | |
| T6 | | | | |
| T7 | | | | |

## 6. After the session

- Fix every confusion point in the boards or `tutorials.md`; republish the artifact.
- Record the outcome as a decision (`decision.md`): pass/fail per criterion, changes made, sign-off.
- Then R1 may start.
