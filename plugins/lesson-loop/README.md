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

## Quality rules

`rules/skill-quality.md` is shared by the hook extractor, `/lesson-loop:reflect` and
`/lesson-loop:mine`: separate general from project-specific knowledge, extend a skill only
within its description, integrate instead of appending addenda, verify paths against the
filesystem, check memory/other skills for contradictions, and record a user preference only
when it is stated as standing.

## Manual trigger

Run `/lesson-loop:reflect` mid-session to extract a skill from the current session now,
without waiting for it to end.

## Mining past sessions (backfill)

Run `/lesson-loop:mine` to scan **previously recorded** Claude Code (`~/.claude/projects`)
and Codex CLI (`~/.codex/sessions`) transcripts and distill the reusable ones into skills.
It is opt-in and best-effort: trivial sessions are skipped, sub-agent transcripts and the
live session are ignored, and existing skills are improved rather than duplicated.

A ledger at `~/.lesson-loop/processed` records every transcript already examined, so re-runs
are idempotent and pick up only newer sessions. Pass filters in natural language, e.g.
`/lesson-loop:mine global last 14 days max 10` or `/lesson-loop:mine codex only`.

## Skill storage scope (global / project / auto)

Controls **where** auto-extracted skills are saved:

Placement is decided by **content**, following `rules/skill-quality.md`:
general knowledge goes to `~/.claude/skills`, project-specific knowledge (paths, ports, services,
repo conventions) goes to the originating project's `.claude/skills`, and plain facts are left
to memory. The scope setting only changes the fallback:

- `auto` (default) / `global` → general → `~/.claude/skills`; project-specific → `<cwd>/.claude/skills` if cwd looks like a project, else skipped
- `project` → `<cwd>/.claude/skills` (only the originating project)

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
| `LESSON_LOOP_MODEL` | `opus` | Model for the headless extractor |
| `LESSON_LOOP_DRYRUN` | unset | If set, log the decision but don't spawn the extractor |
| `LESSON_LOOP_SKIP` | (auto) | Internal recursion guard; do not set manually |

## Logs

- `~/.lesson-loop/log` — one audit line per session (skip / spawn / created / updated / mined)
- `~/.lesson-loop/extractor.log` — stdout/stderr of the headless extractor
- `~/.lesson-loop/processed` — ledger of historical transcripts already examined by `/lesson-loop:mine`

## Install

Lives at `~/.claude/skills/lesson-loop/`, which Claude Code auto-loads as
`lesson-loop@skills-dir` on the next session. Verify with `claude plugin list`.
