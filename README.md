# hermes-loop

A **self-improving learning loop** for Claude Code, modeled on Nous Research's
[Hermes Agent](https://hermes-agent.nousresearch.com/docs/). After a complex session,
it distills the workflow into a reusable **skill** so future sessions load it instead
of re-reasoning from scratch.

## Install

In Claude Code:

```
/plugin marketplace add chaosillu/hermes-loop
/plugin install hermes-loop@hermes-loop
```

Or from the CLI:

```bash
claude plugin marketplace add chaosillu/hermes-loop
claude plugin install hermes-loop@hermes-loop
```

> Replace `chaosillu/hermes-loop` with your `<github-user>/<repo>` if you forked it.
> `hermes-loop@hermes-loop` = `<plugin-name>@<marketplace-name>` (both are `hermes-loop` here).

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
- **Manual now**: `/hermes-loop:reflect` — extract a skill from the current session immediately.
- **Configure storage scope**: `/hermes-loop:config <global|project|auto>`.

## Configuration

| Option / env | Default | Meaning |
|--------------|---------|---------|
| `scope` (userConfig) / `HERMES_LOOP_SCOPE` | `auto` | Where skills are saved: `global` (`~/.claude/skills`), `project` (`<cwd>/.claude/skills`), or `auto` (project if `.git`/`.claude` present, else global) |
| `HERMES_LOOP_THRESHOLD` | `5` | Min tool calls before extraction runs |
| `HERMES_LOOP_MODEL` | `sonnet` | Model for the headless extractor |
| `HERMES_LOOP_DRYRUN` | unset | Log the decision but don't spawn the extractor |

Logs: `~/.hermes-loop/log` (one audit line per event) and `~/.hermes-loop/extractor.log`.

See [`plugins/hermes-loop/README.md`](plugins/hermes-loop/README.md) for full details.

## Repo layout

```
.
├── .claude-plugin/marketplace.json   # marketplace manifest (lists the plugin)
└── plugins/
    └── hermes-loop/                  # the plugin itself
        ├── .claude-plugin/plugin.json
        ├── hooks/hooks.json
        ├── scripts/extract-skill.sh
        └── skills/{reflect,config}/SKILL.md
```

## License

MIT
