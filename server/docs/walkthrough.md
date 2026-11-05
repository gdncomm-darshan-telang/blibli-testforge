# Walkthrough kit — design verification gate (workflow-plan §10.2)

_Prepared 2026-10-08 for prototype v8. Development stays paused (D-031) until this passes and the
sign-off is recorded as a decision._

## 1. Purpose and pass criteria

Check that someone who has never seen the TestForge can do real QA work with it, using only the
prototype and `docs/usage.md`.

**Pass (all must hold):**
- Every task completed **unaided** by both participants.
- **At most 1 question per task.** A question is any request for help, or the facilitator stepping in.
- Every point of confusion is written into `usage.md` or the prototype **before** sign-off.
- The open questions in `feasibility-macros.md` §8 are answered.

**Targets to note (not pass/fail):**
- T1 within 5 minutes of clicks.
- T4 (repeat run) within 1 minute.

## 2. Who and what

| Role | Person | Notes |
|---|---|---|
| Participant A | an amateur QA (knows the app, no git/Xcode) | does T1–T4, T6, T7 |
| Participant B | a developer (git/Xcode, little QA tooling) | does T1, T3, T5, T6, T7 |
| Facilitator | reads the task cards, does **not** help | resets the prototype between tasks |
| Observer | fills the sheet in §5 | may be the facilitator |

**Setup:**
- **Prototype:** https://claude.ai/artifact/PG3DEEYHbW1mh2ojvSJHkt. It is private, so share it with
  both participants from the page's **Share** menu before the session.
- **`docs/usage.md`:** open in another tab. Participants may read it whenever they like; that does
  not count as a question.
- **Timing and recording:** a timer; screen recording (optional, with consent).
- **Length:** about 45 minutes per participant.

**Ground rules to read out:**
> "We're testing the design, not you. Please think aloud. I can't help, but you can read the guide.
> The data is fake and nothing really runs; a few buttons just say 'not part of this prototype'."

**Before each task:** click the state named under *Start* in the purple **Prototype** bar at the top.

## 3. Task cards

Read the **card** aloud exactly as written. The cards deliberately avoid the UI's own words. Don't
show the success criteria to the participant.

### T1 — Run one test case on a branch
- **Start:** `Home`
- **Card:** *"A developer says the fix for test SF-001 is on the branch `release/v14.9.0`. Check
  that test, and only that test, and tell me whether it passed."*
- **Success:** starts from Home, then:
  1. picks the GitHub branch `release/v14.9.0`;
  2. reads the test cases;
  3. selects **only SF-001**;
  4. presses Run and waits for the automatic list;
  5. opens the result and agrees with it.
- **Watch for:**
  - Do they find where to begin?
  - Do they understand "Read test cases"?
  - Do they notice the Run button's text changes?
  - Do they read the progress list or ignore it?

### T2 — Something went wrong
- **Start:** `Build fails`
- **Card:** *"You started a run and it stopped. What happened, whose problem is it, and what do you
  do next?"*
- **Success:**
  - says the app didn't build;
  - says it's a code problem on the branch, not their setup;
  - uses **Copy log** to send it to a developer.
  - **Try again** is acceptable after that.
- **Watch for:** do they think *they* broke something?

### T3 — Judge the results and report a real bug
- **Start:** `Results to review`
- **Card:** *"Yesterday's run is done. Go through the results. SF-023 is a real bug; SF-034's
  title casing is fine according to design. Then share a report."*
- **Success:**
  - opens SF-023 and **Agrees** with FAIL;
  - opens SF-034 and uses **Change the verdict** → PASS **with a reason**;
  - agrees with the passes (one by one or "Agree with all passes");
  - SF-084 is *couldn't finish*: either **Run it again** or Agree;
  - **Create report** → **Publish to my Confluence page**.
- **Watch for:**
  - Do they understand "Claude says" versus "Your review"?
  - Do they try to override without a reason?
  - Do they find where the report is?

### T4 — Do it again tomorrow
- **Start:** `Results to review`, all results agreed (or continue on from T3).
- **Card:** *"You'll need to run this same check every morning. Make that as quick as possible,
  then pretend it's tomorrow and run it."*
- **Success:** **Save as a setup** → go to Home (or use the right-hand panel) → **▶ Run again** on
  the saved setup → sees the steps marked "Already up to date / Already built" being skipped.
- **Watch for:**
  - Do they look on Home or on the right-hand panel?
  - Do they trust that it used the *latest* code?

### T5 — Developer: test uncommitted work before pushing (participant B)
- **Start:** `First time`
- **Card:** *"You've changed code on your machine and haven't pushed it yet. Check that Flash Sale
  tests SF-001 and SF-084 still pass with your changes."*
- **Success:**
  1. switches to **A local repository (git working copy)**;
  2. picks the repository;
  3. notices "N uncommitted files — included";
  4. selects the two tests and runs them.
  - **Follow-up:** switch to the `Local repository changed` state and ask *"What does this message
    mean?"* The participant should answer: "the results are for the snapshot taken when I pressed
    Run; run again with my latest code."
- **Watch for:** do they worry the TestForge will change their repository?

### T6 — Verify a bug fix in your own words, then keep it
- **Start:** `Home`
- **Card:** *"Ticket IOS-47031 says the app froze on Flash Sale's 'Tomorrow' tab. There's no test
  case for it. Check that it's fixed, and make it easy to check again on every build."*
- **Success:**
  1. Home → **Describe a check**;
  2. picks **Verify a bug fix**;
  3. enters the ticket and presses **Load Jira** (optional probe: ask them to try `IOS-46729` first —
     it must be rejected as "not a Bug");
  4. writes the check in plain words;
  5. runs it;
  6. reviews the result;
  7. **Save as macro…**, checking the **map** and ticking the review box.
- **Watch for:**
  - Do they understand "by ID" versus "by text ⚠"?
  - Do they look at the map before ticking the box? Can they say which step is fragile?

### T7 — Replay a saved check, and fix it when the app changed
- **Start:** `Replay needs repair`
- **Card:** *"A saved check just stopped halfway. Get it working again."*
- **Success:**
  1. reads "Can't find …";
  2. presses **Ask Claude to repair**;
  3. reads the suggested fix, including that it changes 2 macros;
  4. presses **Approve fix and continue**;
  5. the replay passes.
- **Watch for:**
  - Do they understand what "macro" and "element" mean here?
  - Are they comfortable approving a fix that affects other macros?

## 4. After the tasks (5 minutes)

Ask each participant to rate each question from 1 (disagree) to 5 (agree), then to explain any
answer of 3 or lower:

1. I knew where to start without help.
2. I always knew what the TestForge was doing and whether I had to act.
3. I trust the verdicts after my review.
4. I could explain the difference between a test run, a check in my own words, and a macro replay.
5. I'd use this instead of testing by hand.

Then ask: *"What was the most confusing moment?"* and *"What one thing would you change?"*

## 5. Observation sheet (copy one per participant)

Participant: ____________ Role: ____________ Date: ____________

| Task | Time (min) | Questions asked | Errors / wrong turns | Done? (Y / assisted / N) | Notes, quotes |
|---|---|---|---|---|---|
| T1 | | | | | |
| T2 | | | | | |
| T3 | | | | | |
| T4 | | | | | |
| T5 | | | | | |
| T6 | | | | | |
| T7 | | | | | |

| Rating question | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Score (1–5) | | | | | |

## 6. After the session

1. List every point of confusion. For each one, decide whether to fix it in the **prototype**, in
   **`usage.md`**, or in **both**, and make the change. Republish the prototype to the same link.
2. Add a "Walkthrough results" row to `progress.md`, with the two sheets summarised.
3. If the §1 pass criteria hold, record the sign-off as a new decision in `decision.md` ("v3 design
   signed off"). P1 may then start, beginning with the Code step (repository/branch on Load, the
   separate QA copy) and the removal of the old mirror code (D-033).
4. If any criterion fails, fix the problem, then run only the failed tasks again with a **new**
   participant.
