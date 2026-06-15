#!/usr/bin/env bash
# hermes-loop: SessionEnd extractor.
# Reads the just-ended session transcript; if it was a non-trivial, reusable
# workflow, spawns a detached headless `claude` to distill it into a skill.
set -uo pipefail

LOGDIR="$HOME/.hermes-loop"
mkdir -p "$LOGDIR"
LOG="$LOGDIR/log"
ts() { date "+%Y-%m-%dT%H:%M:%S%z"; }

# --- recursion guard: don't fire for the extractor's own headless session ---
if [ -n "${HERMES_LOOP_SKIP:-}" ]; then
  exit 0
fi

# --- read hook input from stdin (single JSON object) ---
INPUT="$(cat)"
get() { printf '%s' "$INPUT" | jq -r "$1 // empty" 2>/dev/null; }
TRANSCRIPT="$(get '.transcript_path')"
SESSION="$(get '.session_id')"
CWD="$(get '.cwd')"
EVENT="$(get '.hook_event_name')"
EVENT="${EVENT:-?}"

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  echo "$(ts) skip event=$EVENT session=$SESSION reason=no-transcript" >> "$LOG"
  exit 0
fi

# --- threshold check: count tool calls in the transcript ---
THRESHOLD="${HERMES_LOOP_THRESHOLD:-5}"
TOOLCALLS="$(grep -oE '"type"[[:space:]]*:[[:space:]]*"tool_use"' "$TRANSCRIPT" 2>/dev/null | wc -l | tr -d ' ')"
TOOLCALLS="${TOOLCALLS:-0}"

if [ "$TOOLCALLS" -lt "$THRESHOLD" ]; then
  echo "$(ts) skip event=$EVENT session=$SESSION toolcalls=$TOOLCALLS threshold=$THRESHOLD reason=below-threshold" >> "$LOG"
  exit 0
fi

# --- resolve skill storage scope: global | project | auto ---
# priority: HERMES_LOOP_SCOPE env > config file > plugin userConfig env > default(auto)
SCOPE="${HERMES_LOOP_SCOPE:-}"
if [ -z "$SCOPE" ] && [ -f "$HOME/.hermes-loop/config" ]; then
  SCOPE="$(grep -E '^scope=' "$HOME/.hermes-loop/config" 2>/dev/null | tail -1 | cut -d= -f2 | tr -d '[:space:]')"
fi
SCOPE="${SCOPE:-${CLAUDE_PLUGIN_OPTION_SCOPE:-}}"
SCOPE="${SCOPE:-auto}"

case "$SCOPE" in
  global)
    SKILLS_DIR="$HOME/.claude/skills" ;;
  project)
    SKILLS_DIR="$CWD/.claude/skills" ;;
  auto|*)
    if [ -n "$CWD" ] && { [ -d "$CWD/.git" ] || [ -d "$CWD/.claude" ]; }; then
      SKILLS_DIR="$CWD/.claude/skills"
    else
      SKILLS_DIR="$HOME/.claude/skills"
    fi ;;
esac

read -r -d '' PROMPT <<EOF
You are the hermes-loop skill extractor. A Claude Code session just ended and you decide whether it produced a reusable workflow worth saving.

Session transcript (JSONL): $TRANSCRIPT
Session working dir: $CWD
Skills directory: $SKILLS_DIR

Do this:
1. Read the transcript file.
2. Decide if it contains a NON-TRIVIAL, REUSABLE workflow. Save ONLY if at least one is true: a multi-step procedure that achieved a concrete outcome; recovery from a non-obvious error; a user correction that revealed a durable preference or project convention; a setup/config recipe likely to recur. If the session was trivial, purely exploratory, or a one-off Q&A, DO NOTHING and stop.
3. Before writing, Glob "$SKILLS_DIR/*/SKILL.md" and read any on a related topic. If a similar skill already exists, IMPROVE it with a targeted Edit instead of creating a duplicate.
4. If new, create "$SKILLS_DIR/<kebab-name>/SKILL.md" with YAML frontmatter:
   ---
   name: <kebab-name>
   description: <one line: what it does AND when to load it, written so a future session knows to pick it>
   ---
   Then a concise, actionable procedure: Goal, Steps, Tools used, Pitfalls/edge cases, and any user-specific preference observed. Do NOT paste the raw transcript.
5. Append exactly one audit line to "$LOGDIR/log": "<created|updated|skipped> <skill-name> -- <one-line reason>".

Hard rule: only create/modify files under "$SKILLS_DIR/" and "$LOGDIR/". Touch nothing else.
EOF

if [ -n "${HERMES_LOOP_DRYRUN:-}" ]; then
  echo "$(ts) DRYRUN event=$EVENT session=$SESSION toolcalls=$TOOLCALLS scope=$SCOPE dir=$SKILLS_DIR would-spawn-extractor" >> "$LOG"
  exit 0
fi

MODEL="${HERMES_LOOP_MODEL:-sonnet}"
CLAUDE_BIN="$(command -v claude || true)"
if [ -z "$CLAUDE_BIN" ]; then
  echo "$(ts) error event=$EVENT session=$SESSION reason=claude-not-on-path" >> "$LOG"
  exit 0
fi

echo "$(ts) spawn event=$EVENT session=$SESSION toolcalls=$TOOLCALLS scope=$SCOPE dir=$SKILLS_DIR model=$MODEL" >> "$LOG"

# Detach so the work survives this session's exit and never blocks it.
HERMES_LOOP_SKIP=1 nohup "$CLAUDE_BIN" -p "$PROMPT" \
  --model "$MODEL" \
  --permission-mode bypassPermissions \
  --allowedTools "Read" "Write" "Edit" "Glob" "Grep" \
  >> "$LOGDIR/extractor.log" 2>&1 &
disown 2>/dev/null || true

exit 0
