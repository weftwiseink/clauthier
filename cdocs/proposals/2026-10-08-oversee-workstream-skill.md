---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T10:43:31-07:00
task_list: cdocs/rules-delivery/oversee-workstream-skill
type: proposal
state: live
status: review_ready
tags: [architecture, claude_skills, rules_delivery, hooks]
---

# Oversee-Workstream Skill and Oversee-Many Rename

> BLUF: Rename `cdocs:oversee` to `cdocs:oversee-many`, and move the overseer intro and "Stay thin" out of the always-loaded `rules/overseers.md` into a new `cdocs:oversee-workstream` skill.
> Loop skills tell the overseer to invoke it with the Skill tool.
> "Chat record" stays a universal rule, moved into "CDocs Tool Use Guidance", and `overseers.md` is deleted.
> A `chat-record PreToolUse` mode denies `note` and `path` to subagents, which closes the nested-full-send leak.
> A new check fails on any `/cdocs:<name>` reference that does not resolve.
> The design follows [the load-by-reference evaluation](../reports/2026-10-08-skill-load-by-reference-evaluation.md); departures from the literal request are listed under Open Questions.

## Summary

The maintainer asked for two changes: rename `oversee` to `oversee-many`, and turn the overseer rules into an `oversee-workstream` skill that the other overseer skills load by reference.
The evaluation report found that load-by-reference works: an "invoke `/x` with the Skill tool" line is followed, and invoked skills are re-attached after compaction (up to 5,000 tokens each).
It also found that only part of `overseers.md` is overseer-specific:

- **Intro and "Stay thin"** (about 140 words): only loop leads need them.
  In other subagents they push toward over-delegation.
  They move to the skill.
- **"Chat record"**: the `Stop` hook requires a note from every top-level session, loop or not.
  It stays a rule, as `## Chat record` in "CDocs Tool Use Guidance".
- **The trigger** (a dispatched full-send wrote into the parent's chat record) is not fixed by moving text.
  A subagent running full-send loads the skill and sees its text anyway.
  The rule already said "subagents should never", and that did not stop it.
  The fix is mechanical: a PreToolUse hook denies `chat-record note|path` when the payload carries `agent_id`.

Two gaps in the report get small fixes:

- **Resume plus compaction.** A resumed process re-attaches no skills after compaction.
  A one-line pointer in "CDocs Workflow Patterns › Loops and multi-phase plans" says to re-invoke the skill.
- **Stale skill references.** `npm run test:rules` gains a check that every `/cdocs:<name>` resolves to a shipped skill or agent, so a leftover `/cdocs:oversee` fails CI.

> NOTE(opus/oversee-workstream-skill): This work lands after the `graphify-overhaul` branch, or rebases over it.
> That branch edits `iterate/SKILL.md`, `agents/reviewer.md`, `rules/tool-use-safeguards.md`, `CLAUDE.md`, both READMEs, `devlog/SKILL.md`, `devlog/template.md` and `init/SKILL.md`, all of which this proposal also touches.

## Objective

1. Overseer-only guidance reaches loop leads, and is not loaded into every session and subagent.
2. The guidance survives compaction for as long as the loop runs.
3. A dispatched subagent cannot write to the parent session's chat record.
4. The skill names say what they do: `oversee-many` for an arc of proposals, `oversee-workstream` for the discipline of leading one workstream's loop.
5. Stale skill or rule references fail CI, not a live session.

## Background

- [`cdocs/reports/2026-10-08-skill-load-by-reference-evaluation.md`](../reports/2026-10-08-skill-load-by-reference-evaluation.md) is the primary source: mechanics, reach, compaction durability, cost, and a section-by-section verdict on the rules.
  Its probes were n=1 on haiku and sonnet with toy skills.
- [`2026-10-07-rules-references.md`](./2026-10-07-rules-references.md) set the convention that shipped content refers to rules by heading (`"CDocs X › Section"`), checked by `scripts/check-rule-refs.ts`.
  It rejected having agents read rule files from the plugin.
- [`2026-10-05-rules-context-decomposition-rfp.md`](./2026-10-05-rules-context-decomposition-rfp.md) moved arc-only material into `skills/oversee/SKILL.md` and set a "compress before relocating, no shared reference file" principle.
  This proposal applies the same principle to the per-workstream overseer discipline.
- `plugins/cdocs/bin/chat-record` hook modes already ignore payloads that carry `agent_id`.
  Its agent modes cannot tell a subagent from the main session, because the Bash environment is byte-identical in both (report §2).
- `plugins/cdocs/hooks/validate-cdocs-edit-path.sh` is the precedent for gating a tool by agent identity in a PreToolUse hook (exit 2, reason on stderr).

## Proposed Solution

### 1. `cdocs:oversee-workstream` skill

New `plugins/cdocs/skills/oversee-workstream/SKILL.md`, about 200 tokens:

```markdown
---
name: oversee-workstream
description: Discipline for a session leading a cdocs loop as its overseer; loaded by iterate, propose-revise, full-send, oversee-many and ablate
---

# CDocs Oversee Workstream

A session leading a loop (`/cdocs:iterate`, `propose-revise`, `full-send`, `oversee-many`, `ablate`) is the *overseer*: a router and judgment layer, not a workhorse.

Overseers are not nested, and maintain the "top-level" devlog for a workstream.
If the Agent tool dispatched you, your dispatcher owns the chat record and the top-level devlog.
If asked to oversee multiple workstreams, invoke `/cdocs:oversee-many`.

## Stay thin

[The current "Stay thin" section of overseers.md, verbatim, including the Isolation paragraph.]
```

The description names a role, not instructions, because every subagent's skill listing shows it (report §2).
The skill stays user-invocable, so a user can put an ad-hoc session into overseer mode with `/cdocs:oversee-workstream`.

### 2. Loop skills load it by reference

Each loop skill gets one line at the point where it enters overseer mode:

> Before dispatching, invoke `/cdocs:oversee-workstream` with the Skill tool (skip if its text is already in context).

| File | Current anchor | Change |
|---|---|---|
| `skills/iterate/SKILL.md` | line 10, "enters *overseer mode*" | append the line |
| `skills/propose-revise/SKILL.md` | line 14, "documented in "CDocs Overseer Rules"" | replace the rule ref with the line |
| `skills/full-send/SKILL.md` | line 13, "defined canonically in "CDocs Overseer Rules"" | replace with the line, which covers both composed loops |
| `skills/oversee-many/SKILL.md` | line 12, "per "CDocs Overseer Rules"" | replace with the line |
| `skills/ablate/SKILL.md` | line 20, "The canonical discipline is …; the inline floor:" | replace the rule ref with the line; keep the ablation-specific bullets |
| `skills/ablate/SKILL.md` | line 290, Links | "Overseer discipline: `/cdocs:oversee-workstream`." |
| `skills/implement/SKILL.md` | line 19, top-level mode | "a thin lead: invoke `/cdocs:oversee-workstream` with the Skill tool before dispatching" |
| `skills/propose/SKILL.md` | line 144, author checklist, top-level mode | same wording as implement |

The "skip if already in context" clause keeps full-send from loading the skill three times (full-send, then propose-revise, then iterate).

### 3. Rule changes

- **Delete** `plugins/cdocs/rules/overseers.md`.
- **"CDocs Tool Use Guidance"** gains `## Chat record`: the current Chat record section, verbatim except the first sentence.
  The first sentence becomes "Top-level sessions maintain the chat record with the `chat-record` command; a hook denies it to subagents, which put the content in their report or devlog instead."
- **"CDocs Workflow Patterns › Loops and multi-phase plans"** gains one line:
  "Leading a loop makes you its overseer: invoke `/cdocs:oversee-workstream` with the Skill tool, and again after a compaction or resume when its text is not in context."
- Net effect on always-loaded rules: about 140 words leave (intro and Stay thin), Chat record moves unchanged, and about 40 are added (the pointer line and the hook clause), so about 100 fewer words load per session and subagent.

### 4. Rename `oversee` to `oversee-many`

- `git mv plugins/cdocs/skills/oversee plugins/cdocs/skills/oversee-many`.
- Set `name: oversee-many`, make the H1 "CDocs Oversee Many", and write the usage lines and prose as `/cdocs:oversee-many` (they are `/oversee` today), so the new reference check covers them.
- `.claude/oversee/<arc-id>.json` (the arc-state directory) and its `.gitignore` entry stay as they are.
  The directory name is runtime state, not a skill name, and keeping it lets an in-flight arc resume.
  `template.md`'s example `arc_id` stays.

### 5. Reference sweep

Every reference to the deleted rule or the old skill name is repointed.

| Location | Change |
|---|---|
| `rules/frontmatter-spec.md:85` | "CDocs Tool Use Guidance › Chat record" |
| `skills/devlog/SKILL.md:31`, `skills/devlog/template.md:10` | same |
| `skills/init/SKILL.md` step 6 | drop the `## CDocs Overseer Rules` block; step 3 follows step 6's order, so it needs no edit |
| `plugins/cdocs/AGENTS.md:13-15` | drop the `## Overseers` `@rules/overseers.md` import |
| `plugins/cdocs/AGENTS.md:33` | `/cdocs:oversee-many`; add a `/cdocs:oversee-workstream` bullet |
| `CLAUDE.md:48` | drop the Overseers rule import line |
| `CLAUDE.md:51` | skills list: replace `oversee` with `oversee-many, oversee-workstream` |
| `CLAUDE.md:61` | example ref becomes `"CDocs Tool Use Guidance › Chat record"` |
| `plugins/cdocs/README.md:47` | skills table: rename the row; add an `oversee-workstream` row |
| `plugins/cdocs/README.md:60` | drop the `overseers.md` bullet; the `tool-use-safeguards.md` bullet gains "chat record" |
| `plugins/cdocs/README.md:123` | example refs move to a live rule ("CDocs Tool Use Guidance › Chat record") |
| `plugins/cdocs/README.md:153` | "per "CDocs Tool Use Guidance › Chat record"" |
| `plugins/cdocs/README.md` Hooks | add a "PreToolUse (Bash)" bullet for the deny mode |
| `plugins/cdocs/bin/README.md:64` | point at `../rules/tool-use-safeguards.md` "Chat record" |
| `scripts/check-rule-refs.ts:5` | docstring example becomes a live rule |

`scripts/check-rule-refs.test.ts` uses "CDocs Overseer Rules" only in inline fixtures, which need not name a real rule, so they stay.
Documents under `cdocs/` (proposals, devlogs, reviews, reports) are history and are not edited.

### 6. Subagent deny hook

`bin/chat-record` gains a `PreToolUse` hook mode of about 10 lines.
It denies a subagent's `chat-record note` or `chat-record path` and passes everything else through:

```bash
hook_pretool() {
  local input cmd
  input="$(cat)"   # drain stdin first
  [ "${CDOCS_CHAT_RECORD:-}" = "off" ] && return 0
  command -v jq >/dev/null 2>&1 || return 0
  [ -n "$(printf '%s' "$input" | jq -r '.agent_id // ""' 2>/dev/null)" ] || return 0
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)"
  printf '%s' "$cmd" | grep -Eq '(^|[[:space:];&|(/])chat-record[[:space:]]+(note|path)([[:space:]]|$)' || return 0
  echo "chat-record: top-level sessions only; put this in your report or devlog" >&2
  exit 2
}
```

The `hooks.json` entry:

```json
"PreToolUse": [
  { "matcher": "Write|Edit", "hooks": [ ...unchanged... ] },
  {
    "matcher": "Bash",
    "hooks": [{
      "type": "command",
      "if": "Bash(chat-record:*)",
      "command": "${CLAUDE_PLUGIN_ROOT}/bin/chat-record PreToolUse",
      "timeout": 3
    }]
  }
]
```

The script header comment ("Hook modes always exit 0") gains the one exception.

Judgment on whether the hook is worth adding, given the preference for fewer hooks: it is.
The report shows that no text placement and no environment check can stop the leak.
The hook adds no new file: it is one `hooks.json` entry plus a mode in an existing script.
Because of the `if` filter, Claude Code only spawns it on `chat-record` calls, so it costs nothing on other Bash calls.
Without it, the only fix for the trigger is the sentence the trigger already ignored.

### 7. Skill-reference check

`scripts/check-rule-refs.ts` gains `skillRefProblems()`.

- **What it matches:** every `/cdocs:<name>`, where the name matches `[A-Za-z0-9][A-Za-z0-9_-]*`.
- **What counts as resolved:** the name must match `plugins/cdocs/skills/<name>/SKILL.md` or `plugins/cdocs/agents/<name>.md`.
  The agent form is needed because "CDocs Tool Use Guidance" names the `/cdocs:bash-runner` agent.
- **Where it looks:** the existing scan directories (rules, skills and agents, including `init/SKILL.md`), plus `plugins/cdocs/README.md`, `plugins/cdocs/AGENTS.md`, `plugins/cdocs/bin/README.md`, `CLAUDE.md` and the root `README.md`.
- **Fenced code is included,** because usage blocks hold real invocations.
- **Placeholders are skipped:** `/cdocs:<type>` and `/cdocs:*` do not match, since the name must start with a letter or digit.

The check passes on `main` today (verified: every `/cdocs:` name in those files resolves).

### 8. Materialization and OpenCode

- **`/cdocs:init`:** `.claude/rules/cdocs.md` and `.opencode/rules/cdocs/` are built from the `rules/*.md` glob, so deleting the file is enough.
  Step 5c already removes `.opencode/rules/cdocs/overseers.md`.
  The `AGENTS.md` block loses its Overseer section through the step 6 edit.
- **Consumer refresh:** the rules hash changes, so `inject-rules.ts` tells each consumer once to re-run `/cdocs:init`.
  The hook itself needs no change.
- **OpenCode build:** `scripts/build-opencode.ts` copies skills verbatim, so the build emits `skills/oversee-many/` and `skills/oversee-workstream/` with no code change.
- **Stale OpenCode skill:** `plugins/cdocs/scripts/postinstall.js` gains a retired-skill prune.
  A `RETIRED_SKILLS = ["oversee"]` list removes `.opencode/skills/<name>/`, but only when its `SKILL.md` H1 begins `# CDocs `, so a consumer's own skill with that name is left alone.
  The flat `.opencode/skills/` directory is shared with other packages, so a whole-directory wipe like `copyRules` uses is not safe.
- **Claude Code consumers** get the rename with the plugin update, and need no prune.

## Important Design Decisions

- **The Skill tool, not a relative link or `Read`.**
  It addresses the skill by name, and it is the only form that compaction re-attaches as a skill.
  Content loaded with `Read` falls into the capped "recent files" restore (report §1, §3).
- **The chat record stays a rule (departure: OQ1).**
  `hook_stop` blocks any top-level human turn that has no note, whether or not the session is an overseer.
  If the guidance lived in an overseer skill, every non-loop session would pay a one-turn block on each human turn.
  It would also lose the devlog `chat_record:` step and the after-compaction recovery steps.
- **It goes into "CDocs Tool Use Guidance", not a new rule file.**
  The section is about using one command.
  This keeps the rule-file count flat and removes the "Overseer" title, which no longer describes it.
- **The ablate floor stays.**
  The report suggests dropping ablate's "inline floor".
  On inspection, its bullets are specific to ablation: inline arm work contaminates the measurement, and `ablate.sh` owns the mechanics.
  Only the reference to the rule is replaced.
- **Deny with exit 2, not JSON `permissionDecision`.**
  This matches `validate-cdocs-edit-path.sh`.
  Claude Code passes the stderr reason to the model, and the deny holds under bypass-permissions mode [docs; Phase 4 checks it headless].
- **The deny hook fails open.**
  A malformed payload or missing `jq` allows the call, as every other `chat-record` hook mode does.
  A broken hook should not block Bash.
- **The pointer line goes in the universal rules.**
  It is the only remedy for the resume-plus-compaction gap (report §3), and the decision to lead a loop comes before any skill is loaded.
- **Resolve skill references against skills and agents.**
  This is the smallest check that catches the rename's stale references without rewriting the existing `/cdocs:bash-runner` wording.

## Edge Cases / Challenging Scenarios

- **Opus skips the Skill line inside a long loop skill** [inferred risk; the probes used haiku and sonnet].
  The universal pointer line is a second path to the same skill.
  Phase 5 checks the first real loop's transcript for a `Skill(cdocs:oversee-workstream)` call.
- **Resume, then compaction.** Skills are not re-attached, and the pointer line covers this.
  If the model misses it, the loss is the Stay-thin discipline, not the chat record, which stays in the rules.
- **A subagent legitimately wants `chat-record path`** (for example, an implementer filling a sub-devlog's `chat_record:` frontmatter).
  The call is denied.
  The Chat record rule already makes this the overseer's job, and the deny reason says to put the content in the report or devlog.
- **Fork subagents.** Fork payloads are expected to carry `agent_id` [inferred].
  The existing `top_level_only` headless scenario already dispatches a fork, and Phase 4 adds a deny assertion for it.
- **Absolute-path invocation** (`/path/to/bin/chat-record note`): the `if: Bash(chat-record:*)` filter does not spawn the hook, so the call is not denied.
  `bin/` is on `PATH` and every instruction uses the bare name, so this is accepted.
  If it matters, drop the `if` filter: the script's own regex already matches the absolute form, at the cost of a bash plus jq spawn on every Bash call.
- **Compound commands** (`cd x && chat-record note …`): the script regex matches.
  Whether the `if` filter matches a non-leading `chat-record` follows Claude Code's permission-rule matching for compound commands [docs].
  A headless case checks it.
- **Stale consumer materialization:** until the consumer re-runs `/cdocs:init`, its `.claude/rules/cdocs.md` still carries "CDocs Overseer Rules" and lacks "Tool Use Guidance › Chat record".
  This means duplicated guidance, not missing guidance, and the SessionStart nudge fires.
- **Muscle memory for `/cdocs:oversee`:** the command is gone.
  Arc files under `.claude/oversee/` are unchanged, so `/cdocs:oversee-many resume` picks up an in-flight arc.
- **OpenCode resolution of `/cdocs:oversee-workstream`:** OpenCode names the skill `oversee-workstream`.
  This is the same gap every existing `/cdocs:x` cross-reference has (report §4), and it is not widened here.
- **Deferred [`2026-10-06-nest-overseers-rfp.md`](./2026-10-06-nest-overseers-rfp.md):** a dispatched sub-overseer would be denied `chat-record`.
  That fits the "dispatcher owns the chat record" line, but the RFP should account for it if it is picked up.
- **Skill compaction budget:** 25,000 tokens are shared across skills, filled most-recent-first.
  iterate is about 2.1k tokens and oversee-workstream about 0.2k, so there is ample headroom.

## Test Plan

**`npm run test:rules`** (`scripts/check-rule-refs.test.ts`):
- The existing real-tree assertions (rule invariants, resolution, no rule filenames) pass once `overseers.md` is deleted and every reference is repointed.
  Deleting the rule before the sweep should turn 10 references red, which shows the check covers them.
- New `skillRefProblems` unit cases:
  - `/cdocs:oversee` against a skill set without `oversee` is a problem.
  - `/cdocs:oversee-many` resolves.
  - `/cdocs:bash-runner` resolves through `agents/`.
  - `/cdocs:<type>` and `/cdocs:*` yield no references.
  - A reference inside fenced code is checked.
- A new real-tree assertion: `skillRefProblems()` is empty.

**`chat-record.test.sh --unit`** (new cases in `unit_suite`):
- `agent_id` set, `chat-record note --as x <<'EOF' …`: exit 2, reason on stderr, record unchanged.
- `agent_id` set, `chat-record path`: exit 2.
- `agent_id` set, `cd sub && chat-record note …`: exit 2.
- `agent_id` set, `/abs/bin/chat-record note`: exit 2 (the script-level match).
- `agent_id` set, `git status`: exit 0, no output.
- `agent_id` set, `echo chat-record-notes` and `grep chat-record README.md`: exit 0 (no false positives).
- No `agent_id`, `chat-record note …`: exit 0, no output.
- Malformed JSON payload: exit 0.
- `CDOCS_CHAT_RECORD=off`: exit 0.

**Headless chat-record scenario** (credentialed manual gate, alongside `top_level_only`): `subagent_denied`.
- A `general-purpose` subagent and a fork are each told to run `chat-record note`.
- Assert both tool results carry the deny reason and the record has no block from them.
- Assert the top-level `chat-record note` still succeeds and `Stop` signs off.
- This is the report's one-off acceptance probe, kept as a regression scenario.

**`npm run test:opencode`**: the build output has `skills/oversee-many/SKILL.md` and `skills/oversee-workstream/SKILL.md`, and no `skills/oversee/`.

**`postinstall.js` prune** (manual, in a temp project):
- Seed `.opencode/skills/oversee/SKILL.md` with a `# CDocs Oversee` H1 and run postinstall: the directory is gone.
- Seed it with a non-cdocs H1: the directory is kept.

## Verification Methodology

1. **Reference sweep is complete.**
   `grep -rnE 'CDocs Overseer Rules|/cdocs:oversee([^-a-z]|$)|overseers\.md|/oversee\b' plugins CLAUDE.md README.md` returns nothing, apart from the `check-rule-refs.test.ts` fixtures and `.claude/oversee/` paths.
2. **CI suites pass:** `npm run test:rules`, `chat-record.test.sh --unit` and `npm run test:opencode`.
3. **Materialization.** Run `/cdocs:init` in a scratch project (with `opencode.json`) on a sandboxed `CLAUDE_CONFIG_DIR` with `--plugin-dir plugins/cdocs`.
   Then `node --import tsx scripts/check-rule-refs.ts --materialized <proj>` passes.
   `.claude/rules/cdocs.md` and the `AGENTS.md` block contain no "CDocs Overseer Rules" and do contain "CDocs Tool Use Guidance" › "Chat record".
   `.opencode/rules/cdocs/overseers.md` is gone.
4. **The deny works live.** The `subagent_denied` headless scenario passes.
   Failure picture: a subagent's `@<model>:` block appears in the parent's record, or the deny reason is absent from the subagent's tool result.
5. **Load-by-reference works live.** In the same sandbox, run `/cdocs:propose-revise` on a toy topic with an opus lead, then `/compact`.
   The transcript shows `Skill(cdocs:oversee-workstream)` before the first `Agent` call.
   The post-compaction "Skills restored" attachment lists `cdocs:oversee-workstream`.
   Failure picture: the first `Agent` call comes before any `Skill(cdocs:oversee-workstream)` call, or the restored list lacks it.

## Implementation Phases

Phases run in order: each is small, and Phases 2 and 3 share files.
One implementer is enough.
Commit each phase (or a logical unit within it) separately, by explicit path, as a conventional commit.

### Phase 0: Sequencing

Land after `graphify-overhaul` merges into `main`, or rebase over it if this work starts first.
The conflicts are in the files listed in the Summary NOTE.
Each is a one- or two-line edit on this side, so resolving them by hand is cheap.

### Phase 1: Skill-reference check (test first)

- Add `skillRefProblems()` and its unit and real-tree tests to `scripts/check-rule-refs.ts` and `.test.ts` (§7).
- Update the file's docstring and the `README.md` "Referencing rules" paragraph to describe the skill check.
- Success: `npm run test:rules` is green on the unchanged tree.

### Phase 2: Rename `oversee` to `oversee-many`

- §4, plus the `/cdocs:oversee` rows of §5 (`AGENTS.md:33`, `CLAUDE.md:51`, `README.md:47`).
- Add the `postinstall.js` retired-skill prune (§8).
- Success: `npm run test:rules` is green (it would be red if any `/cdocs:oversee` remained), `npm run test:opencode` is green, and the prune check passes.

### Phase 3: `oversee-workstream` skill and rule move

1. Create `skills/oversee-workstream/SKILL.md` (§1).
2. Add `## Chat record` to `rules/tool-use-safeguards.md` and the pointer line to `rules/workflow-patterns.md` (§3).
3. Add the Skill lines to the loop skills (§2).
4. Delete `rules/overseers.md` and run `npm run test:rules`: expect red on the 10 old references.
5. Apply the rest of §5's sweep until it is green.

Steps 4 and 5 can be one commit, so `main` never has a red `test:rules`.

Success: Verification steps 1-3.

### Phase 4: Subagent deny hook

- Add the `PreToolUse` mode and dispatch case to `bin/chat-record`, the header-comment exception, and the `hooks.json` entry (§6).
- Add the unit cases and the `subagent_denied` headless scenario.
- Add the README Hooks bullet, and update `.github/workflows/cdocs-hooks.yml`'s header comment if it lists the hook modes.
- Success: the unit suite is green, and Verification step 4 passes.

### Phase 5: Live verification

- Verification step 5.
- Record the transcript evidence (the `Skill` call order and the restored-skills attachment) in the overseer's devlog.

### Constraints: what not to change

- Leave history docs under `cdocs/` alone, and never edit `cdocs/_chat/`.
- Do not change the `UserPromptSubmit` or `Stop` hook modes, or the `note` and `path` agent-mode behavior for top-level sessions.
- Do not rename `.claude/oversee/` or touch its `.gitignore` entry.
- Do not move any other rule content (see Follow-up Candidates).
- Do not add a new rule file.

## Follow-up Candidates

These are non-universal rule content named by the report.
They are listed only and are out of scope here.

- **"CDocs Frontmatter Specification"** (110 lines, 584 words, the largest rule): field definitions mostly matter to doc writers.
  Doc skills carry templates, and the PostToolUse validator gives feedback.
  Moving it is a separate decision, because nearly every subagent writes cdocs docs.
- **The graphify overseer sentence** that `graphify-overhaul` adds to "CDocs Tool Use Guidance › Tools and Skills" ("Overseers write `graphify_base_query` … never run graph queries themselves").
  It is overseer-only, so it is a candidate for `oversee-workstream` once that branch lands.

The report rates everything else in the rules universal.

## Open Questions

> WARN(opus/oversee-workstream-skill): Open questions 1-3 are departures from the maintainer's literal request ("turn the overseer rules into a `cdocs:oversee-workstream` skill").
> They follow the evaluation report's recommendation and need the maintainer's sign-off.

1. **Departure: Chat record stays a universal rule.**
   This proposal moves only the intro and "Stay thin" into the skill.
   **Alternative:** move all of `overseers.md`, including "Chat record" and "After a compaction", into `oversee-workstream`, and delete the rule.
   - *Gain:* one home for everything overseer-related, and about 285 words out of the always-loaded rules instead of about 100.
   - *Cost:* every top-level session that is not leading a loop hits one `Stop` block per human turn (the block reason is self-sufficient, so notes still get written).
     It also loses the devlog `chat_record:` step and the post-compaction recovery read.
     The three frontmatter and devlog references would point at a skill that non-overseers never load.
   - *Middle option:* keep a slim rule file, "CDocs Chat Record", instead of a section in "CDocs Tool Use Guidance".
2. **Departure: the deny hook is not in the request.**
   It is added because the report shows that moving text does not stop the trigger.
   **Alternative:** no hook; rely on the skill's "your dispatcher owns the chat record" line, and accept that a nested loop can still leak.
3. **Departure: a universal pointer line stays in the rules.**
   "CDocs Workflow Patterns" keeps one sentence pointing at `oversee-workstream`, so not all overseer text leaves the rules.
   **Alternative:** drop it, and accept that a resumed process silently loses Stay-thin after compaction.
4. **Stale OpenCode skill:** this proposal prunes `.opencode/skills/oversee/` through a guarded retired-skill list in `postinstall.js`.
   Is a README note ("delete `.opencode/skills/oversee/`") preferred, to keep `postinstall.js` unchanged?
