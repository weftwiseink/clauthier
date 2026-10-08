---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T13:10:00-07:00
task_list: cdocs/graphify-overhaul
type: devlog
state: live
status: wip
part_of: cdocs/devlogs/2026-10-08-graphify-overhaul.md
tags: [graphify, claude_skills]
---

# Graphify Overhaul Implementation: Devlog

> BLUF: Iterate round 1 implementation of [`2026-10-08-graphify-overhaul.md`](../proposals/2026-10-08-graphify-overhaul.md), Phases 1-5, in worktree `graphify-overhaul`.

## Objective

Implement the proposal: `cdocs-graphify` replaces `graphify-scope`, `/cdocs:graphify` skill and rule line, `graphify_base_query` wiring, prior proposal superseded, host stub verification, and the weftwise ablation once its container is ready.

## Scratchpoint

- next_steps: Phase 1 reconciliation in the `clauthier` container.
- graphify_base_query:
- important_files: `plugins/cdocs/bin/graphify-scope`, `plugins/cdocs/hooks/tests/graphify-scope.test.sh`, `.github/workflows/cdocs-hooks.yml`, `plugins/cdocs/skills/iterate/SKILL.md`, `plugins/cdocs/agents/reviewer.md`
- callouts:
  - decision: dispatched mode; the overseer owns the top-level devlog.

## Plan

1. Phase 1: time `update` and check output path formats against real graphify 0.9.61 in the `clauthier` container.
2. Phase 2: tests first, then `bin/cdocs-graphify`; delete old script and test; CI, READMEs, `.gitignore`, `.graphifyignore`.
3. Phase 3: skill, rename, rule line, devlog and iterate skills, reviewer, init, README, `CLAUDE.md`.
4. Phase 4: supersede notes on the two prior proposals.
5. Phase 5: host stub run; weftwise ablation if prerequisites pass.

## Testing Approach

TDD for the wrapper: `cdocs-graphify.test.sh` against a `graphify` stub, written before the script.
Docs changes are checked by the removal greps, `npm run test:rules`, and `npm run test:opencode`.
End-to-end behavior by the proposal's host stub run.

## Implementation Notes

## Changes Made

| File | Description |
|------|-------------|

## Verification
