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

Run a discovery pass (adapt the caps/age to the user's filters). This skips already-mined sessions, the still-live session, sub-agent transcripts, and below-threshold noise. It prints the **total un-mined count** first, then the bounded batch (busiest first) you will actually process this run:

```bash
SKILL_DIR=<the "Base directory for this skill" path given at the top of this prompt>
LEDGER=~/.lesson-loop/processed; touch "$LEDGER"
NOW=$(date +%s); THRESH=5; BATCH=5          # process at most BATCH sessions per invocation

# Codex can import Claude sessions; those rollouts duplicate a transcript that is
# already reachable under ~/.claude/projects. List them so they can be skipped.
IMPORTS=$(mktemp); python3 - "$IMPORTS" <<'IMPEOF'
import json, os, sys, glob
out = open(sys.argv[1], "w")
try:
    recs = json.load(open(os.path.expanduser("~/.codex/external_agent_session_imports.json")))["records"]
except Exception:
    recs = []
ids = {r["imported_thread_id"] for r in recs if r.get("imported_thread_id")}
for p in glob.glob(os.path.expanduser("~/.codex/sessions/**/*.jsonl"), recursive=True):
    tid = os.path.basename(p)[:-6].rsplit("-", 5)[-5:]
    tid = "-".join(tid)
    if tid in ids:
        out.write(p + "\n")
IMPEOF
ALL=$({ find "$HOME/.claude/projects" -name '*.jsonl' -type f -not -path '*/subagents/*' -print0 2>/dev/null
        find "$HOME/.codex/sessions" -name '*.jsonl' -type f -print0 2>/dev/null; } |
while IFS= read -r -d '' f; do
  grep -qxF "$f" "$LEDGER" && continue                              # already mined
  age=$(( (NOW - $(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f")) / 60 ))
  [ "$age" -lt 2 ] && continue                                      # skip the live / just-ended session
  n=$(grep -oE 'tool_use|function_call' "$f" | wc -l | tr -d ' ')   # cheap tool-call signal
  [ "$n" -lt "$THRESH" ] && continue                                # below threshold
  h=$(python3 "$SKILL_DIR/human_turns.py" "$f")                     # real human turns, not agent scaffolding
  [ "$h" -lt 1 ] && continue                                        # subagent / goal-driven rollout: nothing to distill
  grep -qxF "$f" "$IMPORTS" && continue                             # a Codex copy of a Claude session (mine the original)
  printf '%s\t%s\t%s\n' "$n" "$h" "$f"
done | sort -rn)
TOTAL=$(printf '%s' "$ALL" | grep -c .)
echo "UN-MINED CANDIDATES: $TOTAL  (processing up to $BATCH this run)"
printf '%s\n' "$ALL" | head -"$BATCH"
```

Notes: `stat -f %m` is macOS, `stat -c %Y` is Linux — the fallback handles both.
The columns are `<tool-calls>\t<human-turns>\t<path>`.

**The human-turn filter matters more than the tool-call count.** Both CLIs write
sub-agent and goal-loop transcripts into the same directories as real sessions,
and those can carry hundreds of tool calls with no human instruction at all — on
one history, 17 of 39 remaining Codex rollouts were agent-only. A transcript with
zero human turns has no intent to distill: the agent was executing someone else's
plan, and whatever is worth keeping belongs to the parent session. `--not-path
'*/subagents/*'` only catches the Claude-side convention, so filter on content.
A second duplicate source: Codex can **import** a Claude session, which writes a
second copy of the same conversation under `~/.codex/sessions/`. The mapping is
in `~/.codex/external_agent_session_imports.json` (`imported_thread_id` → the
original `source_path`); the thread id is the trailing UUID of the rollout
filename. Always mine the Claude original, never the import — on one history 6 of
39 remaining Codex rollouts were imports, and half of those duplicated sessions
that had already been mined.

`human_turns.py` (next to this SKILL.md) counts user messages after dropping
`<environment_context>`, `<codex_internal_context>`, `<recommended_plugins>`,
injected `<skill>` bodies, `Stop hook feedback:` lines, and tool results — i.e.
everything a person did not type. Prefer a transcript with many human turns over
one with a higher tool-call count; long agent monologues are where a run stalls. Filter to a project by grepping the encoded path. Capture `TOTAL` and the batch list — you must report both later. If `TOTAL` is 0, say everything is already mined and stop. Do **not** raise `BATCH` to "do them all in one go": one invocation = one small batch, and the ledger lets the user re-run to continue. Bigger batches are exactly what makes the run stall midway.

## 3. Extract — every item in the batch, one at a time

Process **every** transcript in the batch from step 2 — do not stop after the first one or two. Go strictly one at a time, finish each (including its ledger + log line) before moving to the next, so progress is durable even if you are interrupted. The batch is small on purpose; there is no reason to quit before it is exhausted.

For each candidate transcript:

1. **Read it — but bound the cost.** Recover the human intent: Claude transcripts carry an `ai-title` line and a `cwd`; Codex rollouts open with the first user message. For a **large transcript** (the tool-call count from step 2 is high, e.g. > 1500), do NOT read the whole file — that is what exhausts context and makes the run stall. Instead read selectively: the `ai-title`/`cwd`, the user turns (e.g. `grep '"role":"user"'` or `grep '"type":"user"'`), and a sample of the head and tail. Skip sub-agent/tool-only noise.
2. **Judge reusability** with the reflect skill's bar — save only if at least one holds: a multi-step procedure that achieved a concrete outcome; recovery from a non-obvious error; a user correction that revealed a durable preference or project convention; a setup/config recipe likely to recur. If the session was trivial, exploratory, or one-off, save nothing for it.
3. **Dedup before writing.** Glob `<target-dir>/*/SKILL.md` and read any on a related topic. If a similar skill exists, **IMPROVE** it with a targeted edit; only create `<target-dir>/<kebab-name>/SKILL.md` if none fits. Frontmatter: `name` and `description` (the description must say what it does AND when to load it), then a concise procedure — Goal, Steps, Tools used, Pitfalls/edge cases, and any user preference observed. Never paste the raw transcript.
4. **Record the outcome** regardless of decision:
   - Append the transcript's absolute path to `~/.lesson-loop/processed` (so future runs skip it).
   - Append one audit line to `~/.lesson-loop/log`: `mined <created|updated|skipped> <skill-or-session> -- <one-line reason>`.

## 4. Report — always, even if you stopped early

End with a coverage summary so the user knows exactly how much of their history was covered. This is mandatory: produce it even if you had to stop before finishing the batch. Report the real numbers, never imply you reviewed everything when you reviewed a batch.

```
Mined this run: <R> of <TOTAL> un-mined candidates
  created:  <skill names + paths>
  updated:  <skill names + paths>
  skipped:  <count> (trivial/one-off)
Remaining un-mined: <TOTAL - R>
To continue: re-run /lesson-loop:mine   (the ledger skips everything already processed)
```

If `TOTAL - R > 0`, explicitly tell the user to re-run to cover the rest — the ledger makes each run pick up only what is left, so repeated runs are cheap and incremental.
