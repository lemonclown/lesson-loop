# lesson-loop

A **self-improving learning loop** for Claude Code, modeled on Nous Research's
[Hermes Agent](https://hermes-agent.nousresearch.com/docs/). After a complex session,
it distills the workflow into a reusable **skill** so future sessions load it instead
of re-reasoning from scratch.

## Install

In Claude Code:

```
/plugin marketplace add chaosillu/lesson-loop
/plugin install lesson-loop@lesson-loop
```

Or from the CLI:

```bash
claude plugin marketplace add chaosillu/lesson-loop
claude plugin install lesson-loop@lesson-loop
```

> Replace `chaosillu/lesson-loop` with your `<github-user>/<repo>` if you forked it.
> `lesson-loop@lesson-loop` = `<plugin-name>@<marketplace-name>` (both are `lesson-loop` here).

After installing, restart Claude Code (or run `/reload-plugins`).

## What it does

1. **`SessionEnd` and `PreCompact` hooks** run an extractor when a session ends or just
   before its context is compacted.
2. The extractor counts tool calls in the session transcript. Below the threshold
   (default **5**) it does nothing.
3. Otherwise it spawns a **detached, headless `claude -p`** that reads the transcript,
   judges whether the work is reusable, and writes/patches a skill. New skills auto-load
   on the next session — the self-improving loop.
4. A recursion guard stops the extractor's own session from re-triggering the loop.

## Usage

- **Automatic**: just work; skills get extracted at session end / before compaction.
- **Manual now**: `/lesson-loop:reflect` — extract a skill from the current session immediately.
- **Configure storage scope**: `/lesson-loop:config <global|project|auto>`.

## Configuration

| Option / env | Default | Meaning |
|--------------|---------|---------|
| `scope` (userConfig) / `LESSON_LOOP_SCOPE` | `auto` | Where skills are saved: `global` (`~/.claude/skills`), `project` (`<cwd>/.claude/skills`), or `auto` (project if `.git`/`.claude` present, else global) |
| `LESSON_LOOP_THRESHOLD` | `5` | Min tool calls before extraction runs |
| `LESSON_LOOP_MODEL` | `sonnet` | Model for the headless extractor |
| `LESSON_LOOP_DRYRUN` | unset | Log the decision but don't spawn the extractor |

Logs: `~/.lesson-loop/log` (one audit line per event) and `~/.lesson-loop/extractor.log`.

See [`plugins/lesson-loop/README.md`](plugins/lesson-loop/README.md) for full details.

## Repo layout

```
.
├── .claude-plugin/marketplace.json   # marketplace manifest (lists the plugin)
└── plugins/
    └── lesson-loop/                  # the plugin itself
        ├── .claude-plugin/plugin.json
        ├── hooks/hooks.json
        ├── scripts/extract-skill.sh
        └── skills/{reflect,config}/SKILL.md
```

## License

MIT
