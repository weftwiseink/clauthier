---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T18:22:20-07:00
task_list: build/opencode-build-fixes
type: devlog
state: live
status: wip
tags: [build, opencode, multi-target]
---

# OpenCode Build Fixes (full-send): Devlog

> BLUF(opus-5-5/build/opencode-build-fixes): Overseer devlog for a `/cdocs:full-send` on one proposal subsuming three `scripts/build-opencode.ts` RFPs (YAML block scalars, wildcard tools, stale model ids), on branch `opencode-build-fixes`.

## Objective

Brief: author one proposal (`cdocs/proposals/2026-10-07-opencode-build-fixes.md`) subsuming:
- `cdocs/proposals/2026-10-05-opencode-build-yaml-parser-rfp.md`
- `cdocs/proposals/2026-10-06-opencode-wildcard-tools-mapping-rfp.md`
- `cdocs/proposals/2026-10-05-opencode-model-mapping-rfp.md`

Run propose-revise to `proposal_accepted`, then iterate to implementation Accept.
Mark the three RFPs `status: evolved` pointing at the new proposal.
Out of scope: `cdocs/proposals/2026-10-06-target-specific-guidance-rfp.md`.

Hard requirement (maintainer): OC support stays minimally invasive.
Changes stay within the OC build path (`scripts/build-opencode.ts`, its tests/CI, build output); nothing changes, constrains, or burdens the CC setup (`plugins/cdocs/` authoring format, rules, skills, agents, hooks, CC install).
If a fix cannot be made without that, stop and escalate with a recommendation.

Verification floor: `npm run build:cdocs` succeeds and `build/cdocs/opencode/` shows the three bugs fixed (non-empty bash-runner description, wildcard agents with tools enabled, current model ids), plus the validation `.github/workflows/opencode-build.yml` runs.
Failure picture: a generated agent with `description: |` and nothing after it, or `implementer.md` with `edit: false`.

Chat record: skipped (overseer is a dispatched subagent, per the invoking agent's instruction).

## Scratchpoint

- next_steps: proposal review r1 in flight.
- graphify_query:
- important_files: `scripts/build-opencode.ts`, `.github/workflows/opencode-build.yml`, `package.json`
- callouts:
  - deferred:
  - todo:
  - decision: proposer chose to omit OC `model:` (inherit caller) instead of pinning ids; brief's floor said "current model ids". Reviewer asked to weigh this against tier fidelity.
  - blocker:

## Workstream Devlogs

| devlog | concern | status | read this when |
|---|---|---|---|

## Iteration Log

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | notes |
|---|---|---|---|---|---|---|

## Judge Log

| judge_iteration | trigger | verdict | rationale |
|---|---|---|---|

## Dispatch/Return Events

| event | agent_handle | target_files | at | notes |
|---|---|---|---|---|
| dispatch | prop-1 (cdocs:proposer) | cdocs/proposals/2026-10-07-opencode-build-fixes.md | 2026-10-07T18:23 | round 0 authoring |
| return | prop-1 (cdocs:proposer) | proposal + 3 RFP frontmatters | 2026-10-07T18:29 | 080ab4f, 6d84667; review_ready |
| dispatch | rev-p1 (cdocs:reviewer) | cdocs/reviews/2026-10-07-review-of-opencode-build-fixes.md | 2026-10-07T18:30 | proposal review r1 |

## Steering Log
