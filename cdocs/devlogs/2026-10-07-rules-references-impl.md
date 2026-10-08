---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T22:09:57-07:00
task_list: cdocs/rules-references
type: devlog
state: live
status: wip
part_of: cdocs/devlogs/2026-10-07-rules-references.md
tags: [rules, rules_delivery, init, testing]
---

# Rules References Implementation: Devlog

> BLUF: Iterate round 1 implementation of phases 1-3 of the rules-references proposal, in worktree `../rules-references` (branch `rules-references`).

## Objective

Implement [`cdocs/proposals/2026-10-07-rules-references.md`](../proposals/2026-10-07-rules-references.md) phases 1-3: the `test:rules` check, heading-reference conversion of rules/skills/agents, and dropping the `CLAUDE.md` `@`-import behind the canary gate.

## Scratchpoint

- next_steps: phase 2, convert references and agents.
- important_files: `scripts/check-rule-refs.ts`, `scripts/check-rule-refs.test.ts`, `plugins/cdocs/agents/*.md`, `plugins/cdocs/skills/init/SKILL.md`, `plugins/cdocs/hooks/tests/chat-record.test.sh`
- callouts:
  - decision: headless runs use scratch projects outside the worktree.

## Plan

1. Phase 1: `scripts/check-rule-refs.ts` + test + `test:rules`; run on the pre-change tree; mutations.
2. Phase 2: convert references and agents; CI job; docs.
3. Phase 3: canary gate; `rules_check` comparison; init step 3; `init_real`; delivery docs.

## Testing Approach

`node:test` for the check, run on the pre-change tree first (expected red with exactly the audited hits), then green after phase 2.
Headless `chat-record.test.sh` scenarios for the gate, `rules_check`, and `init_real`; manual headless dispatch for Verification step 4.

## Implementation Notes

### Phase 1: the check

`scripts/check-rule-refs.ts` (pure functions plus a CLI) and `scripts/check-rule-refs.test.ts` (`node:test`, assertions 1-5 as 11 tests); `npm run test:rules`.

> NOTE(@claude-opus-5-5/cdocs/rules-references): Two clarifications beyond the proposal's sketch.
> `Hit` carries `matches: string[]` and `files: string[]` (one hit per line, all offending substrings, every named rule's title in the fix) rather than one match.
> `rules/<name>.md` matches preceded by `.claude/` or `.opencode/` are not flagged: those are materialized paths that exist downstream (`.claude/rules/cdocs.md`), not source rule-file references.

**Pre-change hit list** (tree at `3fa8d3d`, `npx tsx scripts/check-rule-refs.ts`): 31 hits, all in assertion 3; assertions 1, 2, 4 and the fixtures pass.

| Kind | Hits |
|---|---|
| Rule and template text | `rules/frontmatter-spec.md:85`, `skills/devlog/template.md:10` |
| Agent Startup reads (16) | `implementer.md:23,24,27`, `judge.md:21,22,25`, `nit-fix.md:19,20`, `proposer.md:24,25,28`, `reviewer.md:21,22,25`, `triage.md:19,22` |
| Other agent/skill prose | `judge.md:74`, `implement/SKILL.md:53`, `nit_fix/SKILL.md:48` |
| Skill relative links (10) | `ablate/SKILL.md:20,290,291`, `devlog/SKILL.md:31`, `full-send/SKILL.md:13`, `implement/SKILL.md:19`, `iterate/SKILL.md:34`, `oversee/SKILL.md:12`, `propose-revise/SKILL.md:45`, `propose/SKILL.md:144` |

This is exactly the audited set (2 + 16 + 3 + 10 = 31) and no others.
`triage/SKILL.md:69` is path-free prose, not detected, as the proposal expects; fixed by hand in phase 2.
The mutation runs (renamed heading, added filename, misspelled title) need converted references to bite, so they run on the green phase 2 tree (see Verification).

## Changes Made

| File | Description |
|------|-------------|

## Verification
