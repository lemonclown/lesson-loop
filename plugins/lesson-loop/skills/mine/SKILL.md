---
name: mine
description: Mine your *previous* Claude Code and Codex CLI sessions on disk for reusable workflows and turn the good ones into skills. Use to backfill skills from history as a one-off catch-up; for the current session use reflect instead.
disable-model-invocation: true
---

Goal: scan past sessions already recorded on disk, find the few that hold a non-trivial reusable workflow, and distill each into a skill — without duplicating skills you already have. This is best-effort and opt-in: most old sessions are trivial and will be skipped, and that is the expected outcome.

User request (optional filters, e.g. "global", "codex only", "last 14 days", "max 10", a project name): `$ARGUMENTS`

## 1. Resolve settings

- **Storage scope** (where skills are saved): read `~/.lesson-loop/config` for a `scope=` line (`global` / `project` / `auto`; default `global`). Resolve the target dir the same way the reflect skill does:
  - `global` → `~/.claude/skills`
  - `project` → `<this project>/.claude/skills`
  - `auto` → the project's `.claude/skills` if cwd looks like a project (`.git` or `.claude`), else `~/.claude/skills`
  - Because history spans many projects, prefer **global** here unless the user asked otherwise or set `scope=project`.
- **Threshold**: minimum tool calls for a session to be worth examining — default **5** (honor the user if they gave a number).
- **Ledger** of already-mined transcripts: `~/.lesson-loop/processed` (one absolute path per line). Sessions listed here are skipped so re-runs do not redo work.

## 2. Discover candidate transcripts

- Claude Code sessions: `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl`
- Codex CLI sessions (only if `~/.codex` exists): `~/.codex/sessions/**/rollout-*.jsonl` (and any `*.jsonl`)

Run a discovery pass (adapt the caps/age to the user's filters). This skips already-mined sessions, the still-live session, sub-agent transcripts, and below-threshold noise, then lists the busiest first:

```bash
LEDGER=~/.lesson-loop/processed; touch "$LEDGER"
NOW=$(date +%s); THRESH=5; MAX=20
{ find "$HOME/.claude/projects" -name '*.jsonl' -type f -not -path '*/subagents/*' -print0 2>/dev/null
  find "$HOME/.codex/sessions" -name '*.jsonl' -type f -print0 2>/dev/null; } |
while IFS= read -r -d '' f; do
  grep -qxF "$f" "$LEDGER" && continue                              # already mined
  age=$(( (NOW - $(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f")) / 60 ))
  [ "$age" -lt 2 ] && continue                                      # skip the live / just-ended session
  n=$(grep -oE 'tool_use|function_call' "$f" | wc -l | tr -d ' ')   # cheap tool-call signal
  [ "$n" -lt "$THRESH" ] && continue                                # below threshold
  printf '%s\t%s\n' "$n" "$f"
done | sort -rn | head -"$MAX"
```

Notes: `stat -f %m` is macOS, `stat -c %Y` is Linux — the fallback handles both. Filter to a project by grepping the encoded path. If nothing comes back, report that and stop.

## 3. Extract — per candidate, busiest first

For each candidate transcript:

1. **Read it.** Recover the human intent: Claude transcripts carry an `ai-title` line and a `cwd`; Codex rollouts open with the first user message. Skip sub-agent/tool-only noise.
2. **Judge reusability** with the reflect skill's bar — save only if at least one holds: a multi-step procedure that achieved a concrete outcome; recovery from a non-obvious error; a user correction that revealed a durable preference or project convention; a setup/config recipe likely to recur. If the session was trivial, exploratory, or one-off, save nothing for it.
3. **Dedup before writing.** Glob `<target-dir>/*/SKILL.md` and read any on a related topic. If a similar skill exists, **IMPROVE** it with a targeted edit; only create `<target-dir>/<kebab-name>/SKILL.md` if none fits. Frontmatter: `name` and `description` (the description must say what it does AND when to load it), then a concise procedure — Goal, Steps, Tools used, Pitfalls/edge cases, and any user preference observed. Never paste the raw transcript.
4. **Record the outcome** regardless of decision:
   - Append the transcript's absolute path to `~/.lesson-loop/processed` (so future runs skip it).
   - Append one audit line to `~/.lesson-loop/log`: `mined <created|updated|skipped> <skill-or-session> -- <one-line reason>`.

Work through a bounded batch (the `MAX` cap). Mining the whole history at once is wasteful — the cap plus the ledger make repeated runs cheap and incremental.

## 4. Report

Summarize: how many candidates were scanned, which skills you created or updated (with paths), and which sessions you skipped and why. Note that re-running later picks up only newer/un-mined sessions, since the ledger excludes everything already processed.
