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

First determine the storage scope (where to save): read `~/.lesson-loop/config` for a `scope=` line (global / project / auto). If unset, treat as `auto`. Resolve the target dir:
- global → `~/.claude/skills`
- project → `<this project>/.claude/skills`
- auto → the project's `.claude/skills` if the cwd looks like a project (`.git` or `.claude` present), else `~/.claude/skills`

If yes:
- Glob `<target-dir>/*/SKILL.md` and read any on a related topic. If a similar skill exists, IMPROVE it with a targeted edit rather than duplicating.
- Otherwise create `<target-dir>/<kebab-name>/SKILL.md` with `name` and `description` frontmatter (the description must say what it does AND when to load it), followed by a concise procedure: Goal, Steps, Tools used, Pitfalls/edge cases, and any user preference observed. Do not paste the raw transcript.

If the session was trivial, exploratory, or one-off, say so and create nothing.

Report what you created/updated/skipped and why.

$ARGUMENTS
