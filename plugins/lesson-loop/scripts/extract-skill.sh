#!/usr/bin/env bash
# lesson-loop: SessionEnd extractor.
# Reads the just-ended session transcript; if it was a non-trivial, reusable
# workflow, spawns a detached headless `claude` to distill it into a skill.
set -uo pipefail

LOGDIR="$HOME/.lesson-loop"
mkdir -p "$LOGDIR"
LOG="$LOGDIR/log"
ts() { date "+%Y-%m-%dT%H:%M:%S%z"; }

# --- recursion guard: don't fire for the extractor's own headless session ---
if [ -n "${LESSON_LOOP_SKIP:-}" ]; then
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
THRESHOLD="${LESSON_LOOP_THRESHOLD:-5}"
TOOLCALLS="$(grep -oE '"type"[[:space:]]*:[[:space:]]*"tool_use"' "$TRANSCRIPT" 2>/dev/null | wc -l | tr -d ' ')"
TOOLCALLS="${TOOLCALLS:-0}"

if [ "$TOOLCALLS" -lt "$THRESHOLD" ]; then
  echo "$(ts) skip event=$EVENT session=$SESSION toolcalls=$TOOLCALLS threshold=$THRESHOLD reason=below-threshold" >> "$LOG"
  exit 0
fi

# --- resolve skill storage dirs ---
# scope priority: LESSON_LOOP_SCOPE env > config file > plugin userConfig env > default(auto)
#   global/auto: general skills -> ~/.claude/skills; project-specific skills -> <cwd>/.claude/skills
#                (only when cwd looks like a project; otherwise project-specific knowledge is skipped)
#   project:     everything -> <cwd>/.claude/skills
SCOPE="${LESSON_LOOP_SCOPE:-}"
if [ -z "$SCOPE" ] && [ -f "$HOME/.lesson-loop/config" ]; then
  SCOPE="$(grep -E '^scope=' "$HOME/.lesson-loop/config" 2>/dev/null | tail -1 | cut -d= -f2 | tr -d '[:space:]')"
fi
SCOPE="${SCOPE:-${CLAUDE_PLUGIN_OPTION_SCOPE:-}}"
SCOPE="${SCOPE:-auto}"

GLOBAL_DIR="$HOME/.claude/skills"
PROJECT_DIR=""
if [ -n "$CWD" ] && [ "$CWD" != "$HOME" ] && { [ -d "$CWD/.git" ] || [ -d "$CWD/.claude" ]; }; then
  PROJECT_DIR="$CWD/.claude/skills"
fi

case "$SCOPE" in
  project)
    GENERAL_DIR="${CWD:+$CWD/.claude/skills}"; PROJECT_DIR="$GENERAL_DIR" ;;
  global|auto|*)
    GENERAL_DIR="$GLOBAL_DIR" ;;
esac

# Memory notes for this project live next to the transcript.
MEMORY_DIR="$(dirname "$TRANSCRIPT")/memory"
[ -d "$MEMORY_DIR" ] || MEMORY_DIR="(none)"

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RULES="$(cat "$PLUGIN_ROOT/rules/skill-quality.md" 2>/dev/null)"
if [ -z "$RULES" ]; then
  echo "$(ts) error event=$EVENT session=$SESSION reason=rules-file-missing" >> "$LOG"
  exit 0
fi

if [ -n "$PROJECT_DIR" ]; then
  PROJECT_LINE="Project skills directory (for project-specific knowledge): $PROJECT_DIR"
else
  PROJECT_LINE="Project skills directory: NONE (cwd is not a project) -- skip project-specific knowledge entirely"
fi

read -r -d '' PROMPT <<EOF
You are the lesson-loop skill extractor. A Claude Code session just ended and you decide whether it produced a reusable workflow worth saving, and if so, where.

Session transcript (JSONL): $TRANSCRIPT
Session working dir: $CWD
General skills directory: $GENERAL_DIR
$PROJECT_LINE
Project memory directory (read-only, for contradiction checks): $MEMORY_DIR

Follow these quality rules exactly:
----- BEGIN RULES -----
$RULES
----- END RULES -----

Do this:
1. Read the transcript file.
2. Decide if it contains a NON-TRIVIAL, REUSABLE workflow. Save ONLY if at least one is true: a multi-step procedure that achieved a concrete outcome; recovery from a non-obvious error; a user correction that revealed a durable preference or project convention; a setup/config recipe likely to recur. If the session was trivial, purely exploratory, or a one-off Q&A, DO NOTHING except the audit line.
3. Classify each piece of knowledge as general vs project-specific vs memory-fact (rule 1) and pick its directory.
4. Glob "*/SKILL.md" in BOTH skills directories and read every skill on a related topic, plus the memory notes on that topic. Apply rules 2-4: extend only an in-scope skill, integrate instead of appending, verify every concrete path/command with Glob/Read, and resolve contradictions.
5. If a new skill is warranted, create "<dir>/<kebab-name>/SKILL.md" per rule 6.
6. Append exactly one audit line to "$LOGDIR/log": "<created|updated|skipped> <skill-name or none> [<global|project>] -- <one-line reason>".

Hard rule: only create/modify files under the skills directories listed above and "$LOGDIR/". Never modify memory files. Touch nothing else.
EOF

if [ -n "${LESSON_LOOP_DRYRUN:-}" ]; then
  echo "$(ts) DRYRUN event=$EVENT session=$SESSION toolcalls=$TOOLCALLS scope=$SCOPE dir=$GENERAL_DIR project_dir=${PROJECT_DIR:-none} memory=$MEMORY_DIR would-spawn-extractor" >> "$LOG"
  exit 0
fi

MODEL="${LESSON_LOOP_MODEL:-opus}"
CLAUDE_BIN="$(command -v claude || true)"
if [ -z "$CLAUDE_BIN" ]; then
  echo "$(ts) error event=$EVENT session=$SESSION reason=claude-not-on-path" >> "$LOG"
  exit 0
fi

echo "$(ts) spawn event=$EVENT session=$SESSION toolcalls=$TOOLCALLS scope=$SCOPE dir=$GENERAL_DIR project_dir=${PROJECT_DIR:-none} model=$MODEL" >> "$LOG"

# Pre-create the skills dir(s) so the extractor writes into existing, in-bounds dirs.
ADD_DIRS=()
for d in "$GENERAL_DIR" "$PROJECT_DIR"; do
  [ -n "$d" ] || continue
  mkdir -p "$d" && ADD_DIRS+=(--add-dir "$d")
done

# Detach so the work survives this session's exit and never blocks it.
# Instead of a blanket bypassPermissions, grant only the two directories the
# extractor needs (skills + log) via --add-dir, and allowlist a Bash-free toolset.
# This keeps the headless run non-interactive without granting unrestricted access.
LESSON_LOOP_SKIP=1 nohup "$CLAUDE_BIN" -p "$PROMPT" \
  --model "$MODEL" \
  "${ADD_DIRS[@]}" \
  --add-dir "$LOGDIR" \
  --allowedTools "Read" "Write" "Edit" "Glob" "Grep" \
  >> "$LOGDIR/extractor.log" 2>&1 &
disown 2>/dev/null || true

exit 0
