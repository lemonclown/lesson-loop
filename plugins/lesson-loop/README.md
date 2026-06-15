# lesson-loop

A self-improving learning loop for Claude Code, modeled on Nous Research's Hermes Agent.
After a complex session ends, it distills the workflow into a reusable **skill** so future
sessions load it instead of re-reasoning from scratch.

## How it works

1. **`SessionEnd` and `PreCompact` hooks** (`hooks/hooks.json`) run `scripts/extract-skill.sh`
   when a session ends *or* just before the context is compacted. `PreCompact` is the better
   moment for long sessions: the context is heavy (likely reusable work) and detail is about
   to be summarized away, so skills are captured before that loss.
2. The script counts tool calls in the session transcript. If the count is below the
   threshold (default **5**), it does nothing.
3. Otherwise it spawns a **detached, headless `claude -p`** extractor that reads the
   transcript, judges whether the work is reusable, and writes/patches a skill under
   `~/.claude/skills/<name>/SKILL.md`. New skills auto-load on the next session.
4. A recursion guard (`LESSON_LOOP_SKIP`) stops the extractor's own session from
   re-triggering the loop.

The extractor only ever writes under `~/.claude/skills/` and `~/.lesson-loop/`.

## Manual trigger

Run `/lesson-loop:reflect` mid-session to extract a skill from the current session now,
without waiting for it to end.

## Skill storage scope (global / project / auto)

Controls **where** auto-extracted skills are saved:

- `global` → `~/.claude/skills` (loaded in every project)
- `project` → `<cwd>/.claude/skills` (only the originating project)
- `auto` (default) → project dir if cwd looks like a project (`.git` or `.claude` present), else global

Set it (any of these; precedence top to bottom):

1. `LESSON_LOOP_SCOPE=project` environment variable (one-off override)
2. Config file `~/.lesson-loop/config` with a line `scope=project` — set it easily with
   **`/lesson-loop:config project`** (works after install, any install type)
3. Plugin userConfig: at install `claude plugin install lesson-loop@<marketplace> --config scope=project`,
   or edit `pluginConfigs["lesson-loop@skills-dir"].options.scope` in `~/.claude/settings.json`
4. Default: `auto`

## Configuration (environment variables)

| Var | Default | Meaning |
|-----|---------|---------|
| `LESSON_LOOP_SCOPE` | (unset) | `global`/`project`/`auto` override for skill storage location (see above) |
| `LESSON_LOOP_THRESHOLD` | `5` | Min tool calls before extraction runs |
| `LESSON_LOOP_MODEL` | `sonnet` | Model for the headless extractor |
| `LESSON_LOOP_DRYRUN` | unset | If set, log the decision but don't spawn the extractor |
| `LESSON_LOOP_SKIP` | (auto) | Internal recursion guard; do not set manually |

## Logs

- `~/.lesson-loop/log` — one audit line per session (skip / spawn / created / updated)
- `~/.lesson-loop/extractor.log` — stdout/stderr of the headless extractor

## Install

Lives at `~/.claude/skills/lesson-loop/`, which Claude Code auto-loads as
`lesson-loop@skills-dir` on the next session. Verify with `claude plugin list`.
