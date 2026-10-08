---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T12:54:40-07:00
task_list: cdocs/delete-ablate
type: devlog
state: live
status: wip
part_of: cdocs/devlogs/2026-10-08-delete-ablate.md
tags: [ablate, implementation]
---

# Delete Ablate: Implementation

> BLUF: Round 1 implementer for `cdocs/proposals/2026-10-08-delete-ablate-rfp.md`: move `detect-usage` to `scripts/`, then delete `/cdocs:ablate` and its live references.

## Objective

Implement Phases 1-2 of `cdocs/proposals/2026-10-08-delete-ablate-rfp.md` in the `delete-ablate` worktree (branch `delete-ablate`, base `19981a8`).

## Scratchpoint

- next_steps: Phase 1, `scripts/detect-usage.sh` and its test.
- graphify_base_query:
- important_files: `plugins/cdocs/skills/ablate/ablate.sh` (`cmd_detect_usage`), `plugins/cdocs/skills/ablate/test-ablate.sh` (TEST 3), `scripts/`
- callouts:
  - decision: parity of the moved script is checked by running the new test against an `ablate.sh detect-usage` wrapper in scratch, not by adding an env override to the shipped test.

## Plan

1. Phase 1: `scripts/detect-usage.sh`, `scripts/detect-usage.test.sh`, graphify-overhaul NOTE; parity run against `ablate.sh`.
2. Phase 2: delete `plugins/cdocs/skills/ablate/`; drop ablate from `oversee-workstream`, `CLAUDE.md`, `plugins/cdocs/README.md`; NOTE in `2026-09-27-clauthier-improvement-verification.md`; run the verification floor.

## Testing Approach

The 11 `detect-usage` checks move with assertions byte-unchanged except the invocation (`bash "$SH" detect-usage ...` becomes `bash "$SH" ...`).
Phase 2 floor: `detect-usage.test.sh`, `npm run test:rules`, `npm run build:cdocs && npm run test:opencode`, `chat-record.test.sh --unit`, `cdocs-graphify.test.sh`, and the proposal's final grep.

## Implementation Notes

## Changes Made

| file | change |
|---|---|

## Verification
