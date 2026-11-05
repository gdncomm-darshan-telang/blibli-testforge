#!/usr/bin/env node
// Tells a TestForge Remote Control session what it is (TestForge D-150); silent everywhere else.
if (process.env.TESTFORGE_REMOTE !== "1") process.exit(0);
const context = [
	"This is a TestForge Remote Control session: the person is driving QA on this Mac from the Claude mobile app or claude.ai/code.",
	"Before doing QA work, read .claude/skills/testforge-remote/SKILL.md in this project — it lists the tools (qaw, qaw-lens, the qa-driver tools) and the rules.",
	"Show results the person can see on their phone: verdicts in plain words, and screenshots as images when you can send files.",
].join(" ");
process.stdout.write(JSON.stringify({ hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: context } }));
