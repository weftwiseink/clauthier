---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T10:43:31-07:00
task_list: cdocs/rules-delivery/oversee-workstream-skill
type: proposal
state: live
status: review_ready
last_reviewed:
  status: revision_requested
  by: "@claude-opus-5-5"
  at: 2026-10-08T10:59:02-07:00
  round: 2
tags: [architecture, claude_skills, rules_delivery]
---

# Oversee-Workstream and Chat-Record Skills

> BLUF: Rename `cdocs:oversee` to `cdocs:oversee-many` and delete `rules/overseers.md`.
> Its content moves into two skills: `cdocs:oversee-workstream` (overseer intro and "Stay thin") and `cdocs:chat-record` (the "Chat record" section).
> Loop skills invoke `oversee-workstream` with the Skill tool.
> One rule bullet tells only the top-level session (not Agent-started, not a fork) to invoke `chat-record`, plus `oversee-workstream` when leading a loop.
> A new check fails CI on any `/cdocs:<name>` that does not resolve.
> Design source: [the load-by-reference evaluation](../reports/2026-10-08-skill-load-by-reference-evaluation.md).

## Summary

Subagents stop receiving instructions meant only for the top-level session or a loop lead, which removes the confusion that let a dispatched loop write into its parent's chat record (see Important Design Decisions).
All of `overseers.md` (about 285 words) leaves the always-loaded rules, and about 45 words come back in one bullet.

> NOTE(opus/oversee-workstream-skill): This work lands after the `graphify-overhaul` branch, or rebases over it.
> That branch edits `iterate/SKILL.md`, `.gitignore` (next to line 16), `rules/tool-use-safeguards.md` ("Tools and Skills", where §3's bullet goes), `CLAUDE.md`, both READMEs, `devlog/SKILL.md`, `devlog/template.md` and `init/SKILL.md`.
> Each of this proposal's edits to those files is one or two lines, so resolving the conflicts by hand is cheap.

## Objective

1. Overseer-only and top-level-only guidance reaches only the sessions that need it.
2. That guidance survives compaction for as long as the session needs it.
3. Subagents and forks get no instruction to write the chat record.
4. The skill names say what each skill does.
5. A stale skill or rule reference fails CI instead of failing in a live session.

## Background

- [`cdocs/reports/2026-10-08-skill-load-by-reference-evaluation.md`](../reports/2026-10-08-skill-load-by-reference-evaluation.md) is the primary source.
  It covers the mechanics, which agents can load skills, durability across compaction, cost, and a verdict on each rule section.
- [`2026-10-07-rules-references.md`](./2026-10-07-rules-references.md) says shipped content refers to rules by heading, and `scripts/check-rule-refs.ts` checks this.
- [`2026-10-05-rules-context-decomposition-rfp.md`](./2026-10-05-rules-context-decomposition-rfp.md) moved arc-only material into `skills/oversee/SKILL.md`, under a "compress before relocating" principle.
- `bin/chat-record`'s `UserPromptSubmit` and `Stop` hook modes ignore payloads that carry `agent_id`.
  So the `Stop` block reason only ever reaches the top-level session.

> NOTE(opus/oversee-workstream-skill): A subagent `PreToolUse` deny is verified to work on 2.1.294; see "Runtime Verification" in [the r1 review](../reviews/2026-10-08-review-of-oversee-workstream-skill.md).

## Proposed Solution

### 1. `cdocs:oversee-workstream` skill

New file `plugins/cdocs/skills/oversee-workstream/SKILL.md`:

```markdown
---
name: oversee-workstream
description: Discipline for a session leading a cdocs loop as its overseer
---

# CDocs Oversee Workstream

A session leading a loop (`/cdocs:iterate`, `propose-revise`, `full-send`, `oversee-many`, `ablate`) is the *overseer*: a router and judgment layer, not a workhorse.

Overseers are not nested, and maintain the "top-level" devlog for a workstream.
If the Agent tool dispatched you, your dispatcher owns the chat record.
If asked to oversee multiple workstreams, invoke `/cdocs:oversee-many`.

## Stay thin

[Today's "Stay thin" section of overseers.md, verbatim, including the Isolation paragraph.]
```

> NOTE(opus/oversee-workstream-skill): The "dispatcher owns the chat record" sentence is the overseer's default wording, not the maintainer's; the maintainer may reword or delete it.
> It deliberately says nothing about the devlog, since `iterate` and `propose-revise` have every overseer own its top-level devlog.

### 2. `cdocs:chat-record` skill

New file `plugins/cdocs/skills/chat-record/SKILL.md`:

```markdown
---
name: chat-record
description: Chat record upkeep for the top-level session only
---

# CDocs Chat Record

Top-level session only. If the Agent tool started you, or you are a fork, stop: your dispatcher owns the record.

Maintain the session's chat record with the `chat-record` command.
[Today's "Chat record" section of overseers.md from its second sentence on, verbatim: the per-turn note and heredoc example, the devlog `chat_record:` step, "After a compaction", and the commit line.]
```

Forks need two guards because a fork inherits the parent's context, including any skill text the parent has already invoked:
- The rule bullet (§3) defines top-level as excluding forks, so a fork does not invoke the skill itself.
- The skill's first line tells a fork that already holds the text to stop.

### 3. Rule changes

- Delete `plugins/cdocs/rules/overseers.md`.
- Add one bullet to "CDocs Tool Use Guidance › Tools and Skills":
  "Top-level session only (not started by the Agent tool, and not a fork): invoke `/cdocs:chat-record` with the Skill tool, plus `/cdocs:oversee-workstream` when leading a loop, and again after a compaction when their text is not in context."

No other rule text changes, and no rule file is added.

### 4. Loop skills load `oversee-workstream`

Each loop skill gets one line at the point where it enters overseer mode:

> Before dispatching, invoke `/cdocs:oversee-workstream` with the Skill tool (skip if its text is already in context).

| File | Anchor | Change |
|---|---|---|
| `skills/iterate/SKILL.md` | line 10, "enters *overseer mode*" | append the line |
| `skills/propose-revise/SKILL.md` | line 14, "documented in "CDocs Overseer Rules"" | replace the rule reference with the line |
| `skills/full-send/SKILL.md` | line 13, "defined canonically in "CDocs Overseer Rules"" | replace with the line, which covers both composed loops |
| `skills/oversee-many/SKILL.md` | line 12, "per "CDocs Overseer Rules"" | replace with the line |
| `skills/ablate/SKILL.md` | line 20, "The canonical discipline is …; the inline floor:" | replace the rule reference with the line; keep the ablation-specific bullets |
| `skills/ablate/SKILL.md` | line 290, Links | "Overseer discipline: `/cdocs:oversee-workstream`." |
| `skills/implement/SKILL.md` | line 19, top-level mode | "a thin lead: invoke `/cdocs:oversee-workstream` with the Skill tool before dispatching" |
| `skills/propose/SKILL.md` | line 144, author checklist, top-level mode | same wording as implement |

The "skip if" clause keeps full-send from loading the skill three times: once itself, then again for each of the two loops it composes.

### 5. Rename `oversee` to `oversee-many`

- Run `git mv plugins/cdocs/skills/oversee plugins/cdocs/skills/oversee-many`.
- In the renamed skill, set `name: oversee-many` and change the H1 to "CDocs Oversee Many".
- Change its usage lines and prose from `/oversee` to `/cdocs:oversee-many`, so the §7 check covers them.
- Keep the arc-state directory `.claude/oversee/<arc-id>.json`, so an arc that is already running can still resume.
  For the same reason, keep the `.gitignore:17` entry line and `template.md`'s example `arc_id`.

### 6. Reference sweep

| Location | Change |
|---|---|
| `rules/frontmatter-spec.md:85` | "The top-level session fills it (`/cdocs:chat-record`)." |
| `skills/devlog/SKILL.md:31`, `skills/devlog/template.md:10` | drop the cross-reference; the frontmatter spec is its one home, and devlogs are also written by subagents |
| `bin/chat-record` `hook_stop` reason | add `See /cdocs:chat-record.` after `(record: X).`, keeping the note command; the reason stays under the 300-byte test |
| `skills/init/SKILL.md` step 6 | drop the `## CDocs Overseer Rules` block; step 3 copies step 6's order |
| `plugins/cdocs/AGENTS.md:13-15` | drop the `## Overseers` `@rules/overseers.md` import |
| `plugins/cdocs/AGENTS.md:33` | `/cdocs:oversee-many` (rename only) |
| `CLAUDE.md:48` | drop the Overseers rule import line |
| `CLAUDE.md:51` | skills list: `oversee` becomes `oversee-many` (Phase 2); add `chat-record` and `oversee-workstream` (Phase 3) |
| `CLAUDE.md:61`, `plugins/cdocs/README.md:123`, `scripts/check-rule-refs.ts:5` | example reference becomes `"CDocs Workflow Patterns › Completeness"` |
| `plugins/cdocs/README.md:47` | rename the row (Phase 2); add `oversee-workstream` and `chat-record` rows (Phase 3) |
| `plugins/cdocs/README.md:60` | drop the `overseers.md` bullet |
| `plugins/cdocs/README.md:153` | "per `/cdocs:chat-record`" |
| `plugins/cdocs/README.md` "OpenCode Installation" | NOTE: delete a leftover `.opencode/skills/oversee/`, since `postinstall.js` never prunes skill directories |
| `plugins/cdocs/bin/README.md:64` | point at `../skills/chat-record/SKILL.md` |
| `.gitignore:16` comment | `# /cdocs:oversee-many arc state ...` |
| `rules/overseers.md:6` | `/cdocs:oversee-many` (Phase 2 only; Phase 3 deletes the file) |

The references that stay are listed under Verification step 1; documents under `cdocs/` are history and are not edited.

### 7. Skill-reference check

This check is an addition to the request, kept as the overseer's default: it is cheap and catches stale `/cdocs:oversee` references after the rename, and after §6 `frontmatter-spec.md` refers to a skill.

Add `skillRefProblems()` to `scripts/check-rule-refs.ts`.
- **Matching.** Every `/cdocs:<name>` whose name matches `[A-Za-z0-9][A-Za-z0-9_-]*` must resolve to `plugins/cdocs/skills/<name>/SKILL.md` or `plugins/cdocs/agents/<name>.md`.
  Agents count because "CDocs Tool Use Guidance" names the `/cdocs:bash-runner` agent.
- **Files.** The check has its own file list:
  - every `.md` under `plugins/cdocs/{rules,skills,agents}`, including `init/SKILL.md`;
  - `plugins/cdocs/README.md`, `plugins/cdocs/AGENTS.md` and `plugins/cdocs/bin/README.md`;
  - `CLAUDE.md` and the root `README.md`.

  `SCAN_EXCLUDE` is unchanged, so the filename check still skips `init/SKILL.md`.
- **Fenced code** is included, because usage blocks hold real invocations.
- **Placeholders** such as `/cdocs:<type>` and `/cdocs:*` do not match.

On today's tree the check passes.

### 8. Materialization and OpenCode

- **`/cdocs:init`.** `.claude/rules/cdocs.md` and `.opencode/rules/cdocs/` are built from the `rules/*.md` glob.
  Step 5c removes the orphaned `.opencode/rules/cdocs/overseers.md`.
  The step 6 edit removes the `AGENTS.md` Overseer section.
- **Rule hash.** The rules hash changes, so `inject-rules.ts` tells consumers once to re-run `/cdocs:init`.
- **OpenCode build.** `scripts/build-opencode.ts` copies skills verbatim, so the build emits the three new skill directories with no code change.

## Important Design Decisions

- **Chat-record is a top-level-only skill, not a rule.**
  Subagents never get the instructions, so they cannot follow them by mistake.
  This is guidance against confusion, not an enforcement boundary.
  The `Stop` block reason names the skill, and that reason reaches only the top-level session.
  It is a second loader for that session, at a cost of at most one block per session.
- **The Skill tool, not a relative link or a `Read`.**
  It addresses the skill by name.
  It is also the only form that compaction re-attaches as a skill.
  Content loaded by `Read` falls into the capped "recent files" restore.
- **One rule bullet carries both pointers.**
  The resume-plus-compaction gap only arises when a new process resumes a session, and only a top-level session is resumed.
  In-process compaction re-attaches invoked skills, including inside a dispatched overseer.
  So "top-level only" is the right scope for the `oversee-workstream` pointer as well.
- **The ablate floor stays.**
  Its bullets are specific to ablation (an inline arm contaminates the measurement), and they do not restate "Stay thin".
- **The stale OpenCode skill gets a README note.**
  A prune in `postinstall.js` would be code kept forever for a one-time rename.

## Edge Cases / Challenging Scenarios

- **Opus skips a Skill line inside a long loop skill.**
  This is an inferred risk: the probes used haiku and sonnet.
  The rule bullet is a second path to the skill, and Phase 4 checks a real transcript.
- **A fork inherits the chat-record text.**
  The §2 guards cover it, and so does the extended `top_level_only` scenario.
- **The top-level session misses the rule bullet.**
  The first `Stop` block names `/cdocs:chat-record`, and the note still gets written.
- **A resume followed by a compaction.** Skills are not re-attached; the rule bullet says to re-invoke them.
- **A consumer has not re-run `/cdocs:init`.**
  The stale `.claude/rules/cdocs.md` still carries "CDocs Overseer Rules".
  Guidance is duplicated, not missing, and the SessionStart nudge fires.
- **Muscle memory for `/cdocs:oversee`.**
  The command is gone.
  Arc files are unchanged, so `/cdocs:oversee-many resume` picks up an arc that is already running.
- **The deferred [`2026-10-06-nest-overseers-rfp.md`](./2026-10-06-nest-overseers-rfp.md).**
  A dispatched sub-overseer loads `oversee-workstream` but not `chat-record`.
  That matches the "dispatcher owns the chat record" line.
- **Skill compaction budget.**
  The budget is 25,000 tokens across all skills.
  `iterate` is about 2.1k, and the two new skills are about 0.2k each, so there is ample headroom.

## Test Plan

**`npm run test:rules`:**
- The existing real-tree assertions pass after the sweep.
  Deleting `overseers.md` after the §4 lines are in turns the 3 remaining references red (`frontmatter-spec.md:85`, `devlog/SKILL.md:31`, `devlog/template.md:10`), which shows the check covers them.
- New `skillRefProblems` unit cases:
  - `/cdocs:oversee` fails against a skill set that lacks it.
  - `/cdocs:oversee-many` resolves.
  - `/cdocs:bash-runner` resolves through `agents/`.
  - `/cdocs:<type>` and `/cdocs:*` yield no references.
  - A reference inside fenced code is checked.
  - A reference in `init/SKILL.md` is checked.
- A new real-tree assertion: `skillRefProblems()` returns nothing.

**`chat-record.test.sh --unit`:**
- Add an assertion that the `Stop` block reason names `/cdocs:chat-record`.
- The existing "record path", "heredoc note command" and "under 300 bytes" assertions still pass.

**Headless `top_level_only` scenario** (a manual gate that needs credentials):
- Extend the prompt: remove its "Do not run chat-record yourself unless a hook tells you to" sentence; the parent invokes `/cdocs:chat-record` first.
  It then dispatches the existing `cdocs:proposer`, a `general-purpose` agent, and a fork.
- Assert that the canary logs no chat-record `PreToolUse` carrying `agent_id`.
- Replace the "top-level first Stop still blocks" assertion with a positive control: the parent's record has its own note.
- On 2.1.294 the fork may report "processing in background" even with `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`.
  Relax the scenario's foreground assertion for the fork if it fails on that.

## Verification Methodology

1. **The sweep is complete.**
   Run `grep -rnE 'CDocs Overseer Rules|overseers\.md|/oversee([^-a-z]|$)' plugins scripts .github CLAUDE.md README.md .gitignore`.
   It returns only these exceptions:
   - `.claude/oversee/` arc-state paths in `.gitignore:17`, `skills/oversee-many/SKILL.md` and `template.md`;
   - the `.opencode/skills/oversee/` path in the README "OpenCode Installation" NOTE (§6);
   - the "CDocs Overseer Rules" inline fixtures in `check-rule-refs.test.ts`, which need not name a real rule;
   - the `overseers.md` placeholder in the comment at `check-rule-refs.ts:145`.
2. **CI suites.** `npm run test:rules`, `chat-record.test.sh --unit` and `npm run test:opencode` all pass.
3. **Materialization.** Run `/cdocs:init` in a scratch project that has `opencode.json`, on a sandboxed `CLAUDE_CONFIG_DIR` with `--plugin-dir plugins/cdocs`.
   - `node --import tsx scripts/check-rule-refs.ts --materialized <proj>` passes.
   - `.claude/rules/cdocs.md` and the `AGENTS.md` block contain no "CDocs Overseer Rules".
   - Both contain the top-level bullet.
   - `.opencode/rules/cdocs/overseers.md` is gone.
4. **Subagents stay out of the record.** The extended `top_level_only` scenario passes.
   It fails if a subagent or fork `@<model>:` block appears in the record, or if a chat-record `PreToolUse` carries `agent_id`.
5. **Skills load live.** In the same sandbox, run `/cdocs:propose-revise` on a toy topic with an opus lead, then `/compact`.
   - The transcript shows `Skill(cdocs:chat-record)`, from the rule bullet or the `Stop` reason.
   - It shows `Skill(cdocs:oversee-workstream)` before the first `Agent` call.
   - The post-compaction "Skills restored" attachment lists both.
   - It fails if the first `Agent` call comes before `Skill(cdocs:oversee-workstream)`, or if the restored list lacks either skill.

## Implementation Phases

Run the phases in order, with one implementer.
Commit each logical unit separately, by explicit path, as a conventional commit.

### Phase 1: Skill-reference check (test first)

- Add `skillRefProblems()`, its unit tests and the real-tree test (§7).
- Describe the check in the `README.md` "Referencing rules" paragraph.
- Success: `npm run test:rules` is green on the unchanged tree.

### Phase 2: Rename `oversee` to `oversee-many`

- Make the §5 changes.
- Make §6's rename-only edits: `AGENTS.md:33`, `CLAUDE.md:51` and `README.md:47` (rename only, no new-skill entries, which §7 would fail before Phase 3 creates the skills), `.gitignore:16`, `rules/overseers.md:6`, and the README OpenCode NOTE.
- Success: `npm run test:rules` and `npm run test:opencode` are green.
  `test:rules` would be red on any remaining `/cdocs:oversee`.

### Phase 3: Skills, rule bullet and sweep

1. Create `skills/oversee-workstream/SKILL.md` and `skills/chat-record/SKILL.md` (§1, §2), and add their entries to `CLAUDE.md:51` and the `README.md:47` table.
2. Add the rule bullet (§3) and the loop-skill lines (§4).
3. Delete `rules/overseers.md`.
   `npm run test:rules` should go red on the 3 remaining old references.
4. Apply the rest of §6's sweep until `test:rules` is green.
   Commit steps 3 and 4 together, so `main` never has a red `test:rules`.
5. Change the `Stop` reason, add its unit assertion, and extend the `top_level_only` scenario.

Success: Verification steps 1-4.

### Phase 4: Live verification

- Run Verification step 5.
- Record the transcript evidence in the overseer's devlog.

### Constraints: what not to change

- Never edit documents under `cdocs/`, including `cdocs/_chat/`.
- In the hook modes, change only the `Stop` block reason text; their behavior stays the same.
  Also leave the `note` and `path` agent modes unchanged.
- Add no hooks and no rule files, and move no other rule content (see Follow-up Candidates).
- Do not rename `.claude/oversee/` or change its `.gitignore` entry line.

## Follow-up Candidates

These are listed only; this proposal does not move them.

- **"CDocs Frontmatter Specification"** is the largest rule, at 110 lines and 584 words.
  Its field definitions mostly matter to doc writers.
  Moving it is a separate decision, because nearly every subagent writes cdocs docs.
- **The overseer-only graphify sentence** that `graphify-overhaul` adds to "CDocs Tool Use Guidance › Tools and Skills" could move into `oversee-workstream` once that branch lands.
