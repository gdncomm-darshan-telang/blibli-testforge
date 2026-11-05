#!/usr/bin/env python3
"""Proposes — never applies — an extension to the target project's own view-code skills, so that
ordinary use of them also grows a per-module accessibility-identifier chain.

**This never writes into `.claude/skills/` or `CLAUDE.md`, anywhere, under any flag.** This plugin
has a standing rule that an automated pass never edits the tooling or the policy that governs it
(`SKILL.md`'s hard constraints; `apply_fixes.py`'s own protected-paths list) — "a pass that can edit
the tooling is not governed by it." A skill extension is exactly that kind of edit, so this script
only ever produces a document a developer reads and applies by hand, batched into one review the
same way an accessibility retrofit is proposed once rather than gap by gap.

**Output defaults outside the target repo.** A project's own `.claude/` is inside its own git
history and, for at least one real target of this plugin, is under a standing "never touch" — so
even a new-folder-only write there is a risk this script has no reason to take. It follows the same
convention this plugin already uses for screenshots and recordings: written under `~/Documents/`,
never the source tree. Pass `--out-dir` to put it somewhere else on purpose — that is the caller's
repo and the caller's call — but the default stays outside every target project.

Discovery, in order of confidence:
1. A codegen-gate hook, if the target project has one (`.claude/hooks/*.py`, matched by an
   `ast.parse` of top-level assignments shaped like `ALLOWED_SKILLS = {...}` or `*_SKILL = "..."` —
   the file is never `exec`'d or imported). This is the same classification `SKILL.md` already says
   this plugin's own accessibility-retrofit chaining mirrors, and it names the governing skills
   directly rather than guessing at them.
2. Failing that, every `.claude/skills/*/SKILL.md`'s frontmatter, flagged by a keyword heuristic
   over its `description` — labelled a heuristic in the output, never presented as certain.

Usage:
    propose_skill_extension.py --project-root <path> [--out-dir <path>] [--dry-run]
"""
from __future__ import annotations

import argparse
import ast
import re
from dataclasses import dataclass
from pathlib import Path

_VIEW_KEYWORDS = re.compile(r"swiftui|uikit|\bview\b|viewcontroller|\bscreen\b", re.IGNORECASE)
_FRONTMATTER = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)


@dataclass
class HookInfo:
    path: Path
    skills: set[str]


@dataclass
class SkillInfo:
    name: str
    description: str
    skill_md: Path
    relevant: bool = False
    via: str = ""  # "hook" or "heuristic"


@dataclass
class Proposal:
    skill: SkillInfo
    snippet: str


def discover_codegen_hook(claude_dir: Path) -> HookInfo | None:
    """The most reliable signal: a hook that already names exactly which skills govern view code.

    Parsed structurally (`ast.parse`), never executed — a hook is arbitrary code from a project this
    script does not own, and running it would be a much larger risk than the constant it names.
    """
    hooks_dir = claude_dir / "hooks"
    if not hooks_dir.is_dir():
        return None
    for hook_path in sorted(hooks_dir.glob("*.py")):
        try:
            tree = ast.parse(hook_path.read_text(encoding="utf-8"), filename=str(hook_path))
        except (SyntaxError, UnicodeDecodeError):
            continue
        skills: set[str] = set()
        for node in ast.walk(tree):
            if not isinstance(node, ast.Assign):
                continue
            target_names = [target.id for target in node.targets if isinstance(target, ast.Name)]
            if not any("ALLOWED_SKILLS" in name or name.endswith("_SKILL") or name.endswith("_SKILLS")
                       for name in target_names):
                continue
            skills |= _string_constants(node.value)
        if skills:
            return HookInfo(path=hook_path, skills=skills)
    return None


def _string_constants(node: ast.AST) -> set[str]:
    """Every string literal directly inside a Set/List/Tuple/frozenset(...) literal, or a bare
    string constant — exactly the two shapes `ALLOWED_SKILLS = {...}` and `SWIFTUI_SKILL = "..."`
    take. Anything more dynamic (a call, a comprehension) is skipped rather than guessed at."""
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return {node.value}
    if isinstance(node, (ast.Set, ast.List, ast.Tuple)):
        return {element.value for element in node.elts
                if isinstance(element, ast.Constant) and isinstance(element.value, str)}
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == "frozenset":
        return {value for argument in node.args for value in _string_constants(argument)}
    return set()


def discover_project_skills(claude_dir: Path) -> list[SkillInfo]:
    skills_dir = claude_dir / "skills"
    if not skills_dir.is_dir():
        return []
    found = []
    for skill_md in sorted(skills_dir.glob("*/SKILL.md")):
        text = skill_md.read_text(encoding="utf-8", errors="ignore")
        match = _FRONTMATTER.match(text)
        name, description = skill_md.parent.name, ""
        if match:
            for line in match.group(1).splitlines():
                if line.startswith("name:"):
                    name = line.split(":", 1)[1].strip()
                elif line.startswith("description:"):
                    description = line.split(":", 1)[1].strip()
        found.append(SkillInfo(name=name, description=description, skill_md=skill_md))
    return found


def classify_relevant(skills: list[SkillInfo], hook: HookInfo | None) -> list[SkillInfo]:
    """A hook-named skill is relevant outright — that hook is the project's own stated authority on
    which skills govern view code. Absent a hook, a keyword scan over `description` is the fallback,
    and every skill it flags carries `via="heuristic"` so the proposal document says so plainly."""
    relevant = []
    for skill in skills:
        if hook and skill.name in hook.skills:
            skill.relevant, skill.via = True, "hook"
            relevant.append(skill)
        elif _VIEW_KEYWORDS.search(skill.description):
            skill.relevant, skill.via = True, "heuristic"
            relevant.append(skill)
    return relevant


def render_proposal(skill: SkillInfo) -> Proposal:
    confidence = ("named by this project's own codegen-gate hook" if skill.via == "hook"
                 else "flagged by a keyword heuristic over its description — not certain, review "
                      "before trusting this one")
    snippet = (
        "After applying an accessibility identifier through this skill's normal flow, also append "
        "one row to `<UITestRoot>/<Module>/<Submodule>/accessibility-chain.md` under a "
        "`## Accessibility Identifier Chain` heading:\n\n"
        "`| Date | Identifier | Enum.Case | File:Line | Added by |`\n\n"
        "Why: so the identifier map test-flow-recorder needs builds up as this skill is used "
        "normally, instead of only being reconstructed ad hoc during a QA run."
    )
    body = (
        f"# Proposed extension — {skill.name}\n\n"
        f"Relevance: {confidence}.\n\n"
        f"**Never auto-applied.** Copy the step below into `{skill.skill_md}` yourself, as a new "
        "step appended after this skill's existing steps — nothing existing is changed or removed.\n\n"
        "## Proposed new step (append only)\n\n"
        f"{snippet}\n"
    )
    return Proposal(skill=skill, snippet=body)


def render_index(proposals: list[Proposal], hook: HookInfo | None) -> str:
    lines = ["# Adaptation-pass proposals — accessibility-chain extension", "",
             "Generated by `propose_skill_extension.py`. **Nothing here has been written to any "
             "skill file or to `CLAUDE.md`.** Each proposal below is a suggestion to apply by hand.",
             ""]
    if hook:
        lines.append(f"Discovery source: codegen-gate hook at `{hook.path}`, naming "
                     f"{len(hook.skills)} skill(s): {', '.join(sorted(hook.skills))}.")
    else:
        lines.append("Discovery source: no codegen-gate hook found — relevance below is a "
                     "heuristic over each skill's own description, not a certain match.")
    lines.append("")
    if not proposals:
        lines.append("No relevant skills found — nothing proposed.")
        return "\n".join(lines) + "\n"
    lines.append("| Skill | Confidence | Proposal file |")
    lines.append("|---|---|---|")
    for proposal in proposals:
        confidence = "hook-named" if proposal.skill.via == "hook" else "heuristic — review"
        lines.append(f"| {proposal.skill.name} | {confidence} | `{proposal.skill.name}.md` |")
    return "\n".join(lines) + "\n"


def default_out_dir(project_root: Path) -> Path:
    # Outside the target repo, matching this plugin's existing "screenshots and recordings live in
    # ~/Documents/, never in the source tree" convention — see the module docstring for why a
    # default under the target project's own .claude/ is not safe to assume.
    return Path.home() / "Documents" / f"{project_root.resolve().name}-QA" / "adaptation-proposals"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--project-root", required=True, type=Path)
    parser.add_argument("--out-dir", type=Path, default=None,
                        help="default: ~/Documents/<project>-QA/adaptation-proposals/ — never "
                             "inside the target project unless you pass this explicitly")
    parser.add_argument("--dry-run", action="store_true", help="print what would be written, write nothing")
    args = parser.parse_args()

    project_root = args.project_root.resolve()
    claude_dir = project_root / ".claude"
    if not claude_dir.is_dir():
        print(f"no .claude/ under {project_root} — nothing to discover")
        return 0

    hook = discover_codegen_hook(claude_dir)
    skills = discover_project_skills(claude_dir)
    relevant = classify_relevant(skills, hook)
    proposals = [render_proposal(skill) for skill in relevant]

    out_dir = args.out_dir or default_out_dir(project_root)
    index_text = render_index(proposals, hook)

    if args.dry_run:
        print(index_text)
        for proposal in proposals:
            print(f"--- {proposal.skill.name}.md ---")
            print(proposal.snippet)
        return 0

    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "README.md").write_text(index_text, encoding="utf-8")
    for proposal in proposals:
        (out_dir / f"{proposal.skill.name}.md").write_text(proposal.snippet, encoding="utf-8")

    print(f"{len(proposals)} proposal(s) written under {out_dir}")
    print("Nothing was written to any skill file or to CLAUDE.md.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
