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

- next_steps: Phase 3 (skills, rule bullet, loop-skill lines, delete `overseers.md`, sweep, `Stop` reason, `top_level_only` scenario).
- important_files: `scripts/check-rule-refs.ts`, `scripts/check-rule-refs.test.ts`, `plugins/cdocs/rules/overseers.md`, `plugins/cdocs/skills/oversee/`, `plugins/cdocs/bin/chat-record`, `plugins/cdocs/hooks/tests/chat-record.test.sh`
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

## Changes Made

| File | Description |
|------|-------------|
| `scripts/check-rule-refs.ts` | `findSkillRefs`, `skillNames`, `skillRefFiles`, `skillRefProblemsIn`, `skillRefProblems`; wired into the CLI |
| `scripts/check-rule-refs.test.ts` | test 6 (real tree) and 6a-6f fixtures |
| `plugins/cdocs/README.md` | "Referencing rules" describes the skill-reference check; skills-table rename; OpenCode leftover-dir NOTE |
| `plugins/cdocs/skills/oversee-many/` | renamed from `oversee/`; name, H1, usage |
| `plugins/cdocs/AGENTS.md`, `CLAUDE.md`, `.gitignore`, `rules/overseers.md` | rename-only edits |

## Verification

- Phase 1: `npm run test:rules` 18 pass / 0 fail.
- Phase 2: `npm run test:rules` 18/0; `npm run test:opencode` 9/0 (build emits `oversee-many`, no `oversee`).
