---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T13:10:00-07:00
task_list: cdocs/script-location
type: devlog
state: live
status: wip
part_of: cdocs/devlogs/2026-10-07-cdocs-script-location.md
tags: [plugin-architecture, graphify]
---

# CDocs Script Location: Implementation

> BLUF: Implements `cdocs/proposals/2026-10-07-cdocs-script-location.md` (dispatched by the iterate overseer): `graphify-scope` moves to `plugins/cdocs/bin/`, its test to `plugins/cdocs/hooks/tests/`, `iterate` calls it from `PATH`, CI runs its suite on Linux, and `bin/README.md` documents it.

## Objective

Implement the accepted proposal `cdocs/proposals/2026-10-07-cdocs-script-location.md` in full (reviews: `cdocs/reviews/2026-10-07-review-of-cdocs-script-location.md`, `-r2.md`).

## Scratchpoint

- as_of: 2026-10-07T13:10:00-07:00
- now: starting; baseline stale-path grep lists six hits, as the proposal predicts.
- next: commit 1 (the two `git mv`s plus in-file edits).
- open: none.
- files touched: this devlog, the proposal (status).

## Plan

One phase, four commits per the proposal's Implementation Phases:

1. `refactor(cdocs): move graphify-scope to bin/ and its test to hooks/tests`
2. `fix(iterate): call graphify-scope from PATH`
3. `ci(cdocs): run the graphify-scope suite on Linux`
4. `docs(bin): document graphify-scope`

## Testing Approach

The existing 51-case suite is the regression floor; it runs from its new location after commit 1.
The consumer-path fix is proven by running the bare command from a scratch git repo outside this checkout.
Constraint: another agent is editing `plugins/cdocs/rules/*.md` and the devlog skill concurrently, so those files are not touched here.

## Implementation Notes

## Changes Made

| File | Change |
|---|---|

## Verification
