# lesson-loop skill-quality rules

These rules apply every time lesson-loop creates or edits a skill (SessionEnd/PreCompact
extractor, /lesson-loop:reflect, /lesson-loop:mine). They exist because earlier extractions
produced skills that were wrong, contradicted each other, or dragged one project's details
into general-purpose skills.

## 1. Decide where the knowledge belongs before writing anything

- **Project-specific** = depends on one repo/app/vault: its paths, ports, service labels,
  commit hashes, ledger/DB files, module names, team members, or its own conventions.
  Save it under that project's `<project>/.claude/skills/`, never in the global
  `~/.claude/skills/`. If the scope you were given is global but the knowledge is purely
  project-specific, skip it and say so in the audit line (or put it in project scope if
  that directory was given to you).
- **General** = would help in a different project on this machine. Write it without the
  originating project's concrete values: use placeholders (`<port>`, `<service-label>`,
  `<repo>`) and at most one short "e.g." example. No absolute home paths, no commit
  hashes, no people's names, no dated session narratives.
- **A fact that is not a procedure** (where a server runs, which port is taken, a model
  pin) belongs in memory, not in a skill. Skip it and say so.

## 2. Extend a skill only when the new material is inside its scope

Before editing an existing skill, re-read its `description`. Add to it only if the new
material is what that description promises. A pitfall from a different domain that came up
in the same session (an Ollama bug inside a web-dev-loop skill, a 3D-rig fix inside a
generic HTML-dev skill) does NOT go there: create a separate narrowly-scoped skill, or drop
it if it was a one-off.

## 3. Integrate, don't append

- Never add sections named "Addendum", "Phase N (from X session)", "Follow-up (observed
  <date>)", or similar diary entries. Put each new step or pitfall into the existing
  Steps/Pitfalls list where it belongs, and rewrite or delete any older line it supersedes.
- If the new material contradicts what the skill already says, the skill must end up with
  ONE correct instruction, not both.
- Keep each SKILL.md under ~150 lines. If an edit would push it past that, first compress
  or remove stale/duplicated material, or split a coherent sub-topic into its own skill.

## 4. Verify before you write

- Every path, file, command, port, service name, or config key you write must be checked
  against the real filesystem now (Glob/Read it). The transcript may describe a state that
  has since changed. If you cannot verify it, leave it out or mark it `(unverified)`.
- Before saving, read the project's memory directory (given in your instructions, if any)
  and every related skill. If your text would contradict a memory note or another skill,
  stop: either fix the other skill so they agree, or don't write the conflicting line.
- Don't generalize from one incident: "happened once in session X" is not "reliably" or
  "the most common pattern". State the observed condition, not a law.

## 5. User preferences

Record a user preference only when the user stated it as standing ("앞으로", "항상", "always",
"from now on", "never") or it recurred across sessions. A one-time instruction for the task
at hand ("this time, delegate implementation to Opus") is NOT a standing preference.
Quote the user's words briefly; don't escalate them into a default behavior they didn't ask
for.

## 6. Output shape

Frontmatter `name` + one-line `description` (what it does AND when to load it, scoped as
narrowly as the content really is). Body: Goal, Steps, Pitfalls, and preferences only if
rule 5 allows. No raw transcript, no session history.
