---
name: reflect
description: Reflect on the current session and, if it held a reusable workflow, create or improve a skill under ~/.claude/skills/. Use to trigger the learning loop manually right now instead of waiting for session end.
---

Review what we have done in this session so far, then run the learning loop on it.

Decide whether the session contains a NON-TRIVIAL, REUSABLE workflow worth saving as a skill. Save only if at least one is true:
- a multi-step procedure (~5+ meaningful steps) that achieved a concrete outcome
- recovery from a non-obvious error
- a user correction that revealed a durable preference or project convention
- a setup/config recipe likely to recur

**Read `../../rules/skill-quality.md` (relative to this skill's base directory) first and follow it for everything below.** It decides what is general vs project-specific, when an existing skill may be extended, and what must be verified.

Resolve the target dirs: read `~/.lesson-loop/config` for a `scope=` line (global / project / auto; default `auto`).
- global / auto → general skills go to `~/.claude/skills`; project-specific skills go to `<this project>/.claude/skills` if the cwd looks like a project (`.git` or `.claude` present, and cwd is not `$HOME`), otherwise project-specific knowledge is skipped
- project → everything goes to `<this project>/.claude/skills`

Memory notes for this project are in `~/.claude/projects/<encoded-cwd>/memory/` (the auto-memory directory); read the related ones before writing so the skill doesn't contradict them.

If yes:
- Glob `*/SKILL.md` in both target dirs and read every related skill. Extend one only if the new material is within its description (rules 2-3); otherwise create a new, narrowly-scoped skill.
- New skill: `<dir>/<kebab-name>/SKILL.md` per the rules' output shape. Verify every concrete path/command you write. Do not paste the raw transcript.

If the session was trivial, exploratory, or one-off, say so and create nothing.

Report what you created/updated/skipped and why.

$ARGUMENTS
