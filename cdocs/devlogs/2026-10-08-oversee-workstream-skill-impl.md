---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T11:06:18-07:00
task_list: cdocs/rules-delivery/oversee-workstream-skill
type: devlog
state: live
status: wip
part_of: cdocs/devlogs/2026-10-08-oversee-workstream-skill.md
tags: [claude_skills, rules_delivery]
---

# Oversee-Workstream Skill Implementation: Devlog

> BLUF: Dispatched implementer (iterate round 1) for [the oversee-workstream proposal](../proposals/2026-10-08-oversee-workstream-skill.md), Phases 1-4, in worktree `oversee-workstream`.

## Objective

Implement `cdocs/proposals/2026-10-08-oversee-workstream-skill.md` (accepted r3): skill-reference check, `oversee` to `oversee-many` rename, `oversee-workstream` and `chat-record` skills replacing `rules/overseers.md`, and live verification.

## Scratchpoint

- next_steps: Phase 4 live run in flight (`scratchpad/p4-run.sh`: sandboxed config, opus lead, `/cdocs:propose-revise` toy topic, `/compact`, one follow-up prompt); then extract Skill/Agent order and the post-compaction skills attachment.
- important_files: `scripts/check-rule-refs.ts`, `scripts/check-rule-refs.test.ts`, `plugins/cdocs/skills/{oversee-workstream,chat-record,oversee-many}/SKILL.md`, `plugins/cdocs/rules/tool-use-safeguards.md`, `plugins/cdocs/bin/chat-record`, `plugins/cdocs/hooks/tests/chat-record.test.sh`
- callouts:
  - decision: this implementer is a subagent and never calls `chat-record`.
  - todo: Phase 4 says "record transcript evidence in the overseer's devlog"; the overseer owns that devlog, so evidence lands here and the overseer copies it.

## Plan

1. Phase 1: `skillRefProblems()` + unit and real-tree tests; README "Referencing rules" paragraph.
2. Phase 2: rename `oversee` to `oversee-many` plus rename-only sweep edits.
3. Phase 3: two new skills, rule bullet, loop-skill lines, delete `overseers.md`, sweep, `Stop` reason, `top_level_only` scenario.
4. Phase 4: headless live verification (Verification steps 3-5).

## Testing Approach

Test-first for the skill-reference check: unit fixtures before `skillRefProblems()`, real-tree assertion green on the unchanged tree.
Each phase is gated on `npm run test:rules` (and `test:opencode` for Phase 2+).
Live gates (headless `top_level_only`, materialization, propose-revise transcript) run in a sandboxed `CLAUDE_CONFIG_DIR`.

## Implementation Notes

### Phase 1: skill-reference check

- `skillRefProblems()` is split into a pure `skillRefProblemsIn(entries, names)` (unit fixtures) and a real-tree wrapper; `skillNames()` indexes `skills/*/SKILL.md` plus `agents/*.md`; `skillRefFiles()` is the check's own list (§7).
- Test-first: the new tests failed on import before the implementation existed; then 18/18 green on the unchanged tree.
- Mutation check: appending `/cdocs:bogus-skill` to `init/SKILL.md` made the CLI report `plugins/cdocs/skills/init/SKILL.md:179: /cdocs:bogus-skill: no skill or agent named ...` (reverted).

### Phase 2: rename

- `git mv` plus name/H1/usage/prose; `template.md`'s H1 also became "Oversee-Many Skill: Arc-State Template" (not listed in §5, a consistency edit); its `arc_id` example and every `.claude/oversee/` path are unchanged.
- `rules/overseers.md:3`'s loop list also says `oversee-many` (not listed; the file is deleted in Phase 3 anyway).

> NOTE(opus/oversee-workstream-skill): A failed `git add` (pathspec on the moved-away directory) let the staged rename slip into the README-NOTE commit. Both commits were local and unpushed; I soft-reset them and recommitted as `6ad47c5`, `c24e5ff`, `1237009`.

### Phase 3: skills, rule bullet, sweep

- Skill bodies are the worktree's current `overseers.md` text verbatim, which is newer than the proposal's quoted Chat record wording (the per-turn note is "the most important things you are about to tell the user, in at most 300 words of bullets", not the `gist:`/`query:` types).
  The `chat-record` guard is split onto two lines (sentence-per-line); wording is §2's.
- `propose/SKILL.md` wording: "Top-level mode: as a thin lead, invoke `/cdocs:oversee-workstream` with the Skill tool before dispatching, ..." (§4 says "same wording as implement"; implement's "a thin lead: invoke" reads as a double colon after "Top-level mode:", so the propose line uses a comma).
- Deleting `overseers.md` before the sweep made `check-rule-refs.ts` report exactly the 3 predicted references (`frontmatter-spec.md:85`, `devlog/SKILL.md:31`, `devlog/template.md:10`); deletion and sweep landed in one commit (`7732031`).
- `Stop` reason: `... (record: <path>). See /cdocs:chat-record. Run, then finish: ...`; 254 bytes in the unit suite.
- `top_level_only`: the parent invokes `/cdocs:chat-record`, then dispatches `cdocs:proposer`, `general-purpose`, `fork`.
  New assertions: no subagent `Skill(chat-record)`; the parent invoked it; the parent's note landed; the record's agent-entry count equals the agent_id-free `chat-record note` PreToolUse count (so a subagent block in the record fails it).
  The fork's foreground assertion did not need relaxing on 2.1.294.
- `init_real` (beyond §6's list, needed for Verification 3): seeds `opencode.json` and a stale `.opencode/rules/cdocs/overseers.md`; its two assertions on overseer text in the rules file ("Top-level agents must use ...", "After a compaction") are replaced by the top-level bullet in both rules file and `AGENTS.md`, no "CDocs Overseer Rules" in either, and the stale copy pruned.

> WARN(opus/oversee-workstream-skill): The `rules_check` and `multi_turn` extras assume the post-compaction resumption steps are in the always-loaded rules; they now live in `chat-record`, which compaction re-attaches as a skill. Those extras are not run in this round and may need their expectations revisited.

## Changes Made

| File | Description |
|------|-------------|
| `scripts/check-rule-refs.ts` | `findSkillRefs`, `skillNames`, `skillRefFiles`, `skillRefProblemsIn`, `skillRefProblems`; wired into the CLI |
| `scripts/check-rule-refs.test.ts` | test 6 (real tree) and 6a-6f fixtures |
| `plugins/cdocs/README.md` | "Referencing rules" describes the skill-reference check; skills-table rename; OpenCode leftover-dir NOTE |
| `plugins/cdocs/skills/oversee-many/` | renamed from `oversee/`; name, H1, usage |
| `plugins/cdocs/AGENTS.md`, `CLAUDE.md`, `.gitignore`, `rules/overseers.md` | rename-only edits (Phase 2) |
| `plugins/cdocs/skills/oversee-workstream/SKILL.md`, `plugins/cdocs/skills/chat-record/SKILL.md` | new skills (§1, §2) |
| `plugins/cdocs/rules/tool-use-safeguards.md` | top-level-only `chat-record` bullet (§3) |
| `plugins/cdocs/skills/{iterate,propose-revise,full-send,oversee-many,ablate,implement,propose}/SKILL.md` | load `oversee-workstream` (§4) |
| `plugins/cdocs/rules/overseers.md` | deleted |
| `rules/frontmatter-spec.md`, `skills/devlog/{SKILL,template}.md`, `skills/init/SKILL.md`, `AGENTS.md`, `CLAUDE.md`, `README.md`, `bin/README.md`, `scripts/check-rule-refs.ts` | §6 sweep |
| `plugins/cdocs/bin/chat-record` | `Stop` reason names `/cdocs:chat-record` |
| `plugins/cdocs/hooks/tests/chat-record.test.sh` | unit assertion; `top_level_only` and `init_real` extended |

## Verification

- Phase 1: `npm run test:rules` 18 pass / 0 fail.
- Phase 2: `npm run test:rules` 18/0; `npm run test:opencode` 9/0 (build emits `oversee-many`, no `oversee`).
- Phase 3, `npm run test:rules`: 18 pass / 0 fail. `chat-record.test.sh --unit`: 98 passed, 0 failed (`block reason names the /cdocs:chat-record skill`, `block reason under 300 bytes (254)`). `npm run test:opencode`: 9/0; the build emits `chat-record`, `oversee-many`, `oversee-workstream` and rules without `overseers.md`.
- Verification 1 grep (`CDocs Overseer Rules|overseers\.md|/oversee([^-a-z]|$)` over `plugins scripts .github CLAUDE.md README.md .gitignore`): only `.claude/oversee/` paths (`.gitignore:17`, `oversee-many/SKILL.md:51,58`, `oversee-many/template.md:3`), the README OpenCode NOTE (`README.md:194`), `check-rule-refs.test.ts` fixtures, and the `check-rule-refs.ts:149` comment.

### Headless `top_level_only` (haiku, 2.1.294)

```
== headless: top_level_only - rules loaded; parent loads /cdocs:chat-record; proposer, general-purpose and fork dispatched; no subagent chat-record call
  PASS: no chat-record call with an agent_id
  PASS: no subagent invoked the chat-record skill
  PASS: the parent invoked the chat-record skill
  info: record markers: U A:haiku-5-5 S:95f80c14
  PASS: the parent's note landed in the record
  PASS: every agent entry is a top-level note call
  info: Agent subagent_types dispatched: cdocs:proposer,general-purpose,fork
  PASS: a cdocs:proposer was dispatched
  PASS: a general-purpose agent was dispatched
  PASS: a fork was dispatched
  PASS: the fork dispatch was not refused
  PASS: all dispatches ran in the foreground
  PASS: the fork reported a.txt's first line
  PASS: the proposer wrote its proposal
  info: subagent tool calls: Bash=3,Edit=1,Read=2,Write=1
  PASS: the subagents made tool calls under the rules
  PASS: the general-purpose agent ran Bash

chat-record tests: 14 passed, 0 failed
```

Parent tool sequence: `Skill cdocs:chat-record`, `Agent cdocs:proposer`, `Agent general-purpose`, `Agent fork`, `Bash chat-record note ...`.
The only chat-record `PreToolUse` in the canary log has `agent_id: null`; one `Stop`, no block.
The fork's single tool call was a `Read` of `a.txt`.

### Verification 3: materialization (`chat-record.test.sh --headless --only '^init_real$'`, haiku)

```
== headless: init_real - /cdocs:init scaffolds cdocs/_chat and rules; --minimal does not
  PASS: .gitattributes is the union rule
  PASS: _chat/README.md written
  PASS: rules file carries the top-level chat-record bullet
  PASS: AGENTS.md block carries the top-level chat-record bullet
  PASS: rules file has no overseer rule
  PASS: AGENTS.md has no overseer rule
  PASS: stale .opencode/rules/cdocs/overseers.md pruned
  PASS: CLAUDE.md rules import line is gone
  PASS: check-rule-refs --materialized passes
  PASS: init turn: no record, no Stop decision
  PASS: --minimal created the doc directories
  PASS: --minimal creates no cdocs/_chat

chat-record tests: 12 passed, 0 failed
```

`.opencode/rules/cdocs/` afterwards: `frontmatter-spec.md`, `tool-use-safeguards.md`, `workflow-patterns.md`, `writing-conventions.md`; the `AGENTS.md` block's sections are Writing Conventions, Workflow Patterns, Tool Use Guidance, Frontmatter Specification.
Sandboxes (including credential copies) were deleted after each headless run.

