#!/usr/bin/env python3
"""Count real human turns in a Claude Code or Codex CLI transcript.

Both CLIs record sub-agent and goal-loop runs alongside genuine sessions. Those
carry plenty of tool calls but no human instruction, so they are worthless to
mine. Everything a person did not type is dropped: environment/context blocks,
injected skill bodies, stop-hook feedback, and tool results.

Usage: human_turns.py <transcript.jsonl> [...]  -> one "<count> <path>" per file
"""
import json
import sys

SKIP_PREFIXES = (
    "Stop hook feedback:",
    "This session is being continued from",
    # lesson-loop's own headless extractor runs: the only "user" turn is the
    # prompt the hook generated, so there is no human intent to distill.
    "You are the lesson-loop skill extractor",
)


def human_turns(path):
    n = 0
    with open(path, errors="replace") as f:
        for line in f:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            if not isinstance(d, dict):
                continue
            # Codex nests the message under "payload"; Claude under "message".
            pl = d.get("payload") if isinstance(d.get("payload"), dict) else d
            if not isinstance(pl, dict):
                continue
            m = pl.get("message") if isinstance(pl.get("message"), dict) else pl
            if not isinstance(m, dict) or m.get("role") != "user":
                continue
            c = m.get("content")
            if isinstance(c, str):
                txt = c
            elif isinstance(c, list):
                txt = " ".join(x.get("text", "") for x in c if isinstance(x, dict))
            else:
                txt = ""
            txt = txt.strip()
            if not txt:
                continue
            # "<environment_context>", "<codex_internal_context>",
            # "<recommended_plugins>", "<skill>" — injected, not typed.
            if txt.startswith("<"):
                continue
            if txt.startswith(SKIP_PREFIXES):
                continue
            if "tool_result" in txt:
                continue
            n += 1
    return n


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        sys.exit("usage: human_turns.py <transcript.jsonl> [...]")
    for p in args:
        try:
            n = human_turns(p)
        except OSError:
            n = 0
        print(n if len(args) == 1 else f"{n} {p}")
