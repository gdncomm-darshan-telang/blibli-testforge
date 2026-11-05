import { test } from "node:test";
import assert from "node:assert/strict";
import { extractVerdict } from "../lib/claude-stream.js";

test("D-070: only a stated verdict line counts, never a bare word", () => {
	// Seen in the P8 pilot: a case that never ran, and a PASS that mentioned a failed first preflight.
	assert.equal(extractVerdict("SF-035 did not run. Preflight failed: `skill-audit FAIL`.", []), null);
	assert.equal(extractVerdict("SF-090 passes.\n- the first preflight was BLOCKED, then re-run\n\nVERDICT: PASS — labels correct", []), "PASS");
	assert.equal(extractVerdict("**Verdict:** FAIL\nmore text", []), "FAIL");
	assert.equal(extractVerdict("Verdict — blocked by the skill-audit gate", []), "BLOCKED");
	// The last stated line wins; the streamed tail is only a fallback.
	assert.equal(extractVerdict("VERDICT: FAIL\nre-ran\nVERDICT: PASS", ["VERDICT: FAIL"]), "PASS");
	assert.equal(extractVerdict("", ["● step", "VERDICT: EVIDENCE_ONLY"]), "EVIDENCE_ONLY");
});
