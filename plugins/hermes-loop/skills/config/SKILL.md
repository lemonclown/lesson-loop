---
name: config
description: View or change hermes-loop settings, mainly the skill storage scope (global / project / auto). Use to control where auto-extracted skills are saved without editing files by hand.
---

Manage hermes-loop configuration, persisted at `~/.hermes-loop/config` (read by the extractor at runtime).

The user request: `$ARGUMENTS`

Do this:

1. If the request asks to SET the scope (e.g. "scope project", "global", "set to auto"):
   - Map it to one of: `global`, `project`, `auto`.
     - global = skills saved to `~/.claude/skills` (loaded in every project)
     - project = skills saved to `<project>/.claude/skills` (only that project)
     - auto = project if cwd looks like a project (`.git` or `.claude` present), else global
   - Write the file `~/.hermes-loop/config` so it contains a line `scope=<value>` (create the file/dir if missing; replace any existing `scope=` line, keep other lines).
   - Confirm the new value and note it takes effect on the next extraction (next SessionEnd or PreCompact).

2. If the request is to SHOW/empty:
   - Read `~/.hermes-loop/config` if it exists and report the current `scope=` (or state it is unset → effective default `auto`).
   - Briefly list the valid values.

Only read/write under `~/.hermes-loop/`. Do not touch skills or other files.
