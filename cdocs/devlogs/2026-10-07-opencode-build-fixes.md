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

- next_steps: iterate Turn 1.a: impl-1 implementing full proposal; then fresh reviewer.
- graphify_query:
- important_files: `scripts/build-opencode.ts`, `.github/workflows/opencode-build.yml`, `package.json`
- callouts:
  - deferred: model policy (omit vs pin) surfaced to maintainer in final report; overseer chose omit (portability across providers, no bumps).
  - todo: README "model mapping" phrase in plugins/cdocs/README.md left stale (HR: plugins/ untouched); surface to maintainer.
  - decision: proposer chose to omit OC `model:` (inherit caller) instead of pinning ids; brief's floor said "current model ids". Reviewer asked to weigh this against tier fidelity.
  - blocker:

## Workstream Devlogs

| devlog | concern | status | read this when |
|---|---|---|---|
| cdocs/devlogs/2026-10-07-opencode-build-fixes-impl.md | implementation of the proposal (all phases) | wip | resuming implementation or reviewing verification evidence |

## Iteration Log

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | notes |
|---|---|---|---|---|---|---|
| p1 | prop-1 (cdocs:proposer) | rev-p1 (cdocs:reviewer) | revise | n/a | cdocs/reviews/2026-10-07-review-of-opencode-build-fixes.md | blockers: parse error must warn+skip (HR2); NOTE that omit-model supersedes brief's "current model ids" floor |
| p2 | prop-1 (cdocs:proposer) | rev-p2 (cdocs:reviewer) | proposal_accepted | n/a | cdocs/reviews/2026-10-07-review-of-opencode-build-fixes-r2.md | 7 non-blocking nits sent to warm proposer; reviewer loaded output in OpenCode 1.17.5 (`opencode agent list --pure`) |

## Judge Log

| judge_iteration | trigger | verdict | rationale |
|---|---|---|---|

## Dispatch/Return Events

| event | agent_handle | target_files | at | notes |
|---|---|---|---|---|
| dispatch | prop-1 (cdocs:proposer) | cdocs/proposals/2026-10-07-opencode-build-fixes.md | 2026-10-07T18:23 | round 0 authoring |
| return | prop-1 (cdocs:proposer) | proposal + 3 RFP frontmatters | 2026-10-07T18:29 | 080ab4f, 6d84667; review_ready |
| dispatch | rev-p1 (cdocs:reviewer) | cdocs/reviews/2026-10-07-review-of-opencode-build-fixes.md | 2026-10-07T18:30 | proposal review r1 |
| return | rev-p1 (cdocs:reviewer) | review + proposal last_reviewed | 2026-10-07T18:34 | a2c5c76; revise |
| dispatch | prop-1 (cdocs:proposer, warm) | proposal | 2026-10-07T18:35 | revision r1 |
| return | prop-1 (cdocs:proposer) | proposal | 2026-10-07T18:45 | be140f5; review_ready |
| dispatch | rev-p2 (cdocs:reviewer) | cdocs/reviews/2026-10-07-review-of-opencode-build-fixes-r2.md | 2026-10-07T18:46 | proposal review r2 |
| return | rev-p2 (cdocs:reviewer) | review r2 + proposal frontmatter | 2026-10-07T18:52 | 121875d; proposal_accepted |
| dispatch | prop-1 (cdocs:proposer, warm) | proposal | 2026-10-07T18:53 | accept nits |
| return | prop-1 (cdocs:proposer) | proposal | 2026-10-07T19:00 | 1d1695c |
| dispatch | impl-1 (cdocs:implementer) | scripts/build-opencode.ts, scripts/build-opencode.test.ts, package.json, package-lock.json, .github/workflows/opencode-build.yml, cdocs/devlogs/2026-10-07-opencode-build-fixes-impl.md | 2026-10-07T19:01 | iteration 1, full proposal |

## Iterate Brief

Scope: full proposal `cdocs/proposals/2026-10-07-opencode-build-fixes.md` (all phases).
Verification floor: the proposal's Verification Methodology steps 0-8, plus the brief's floor as amended by the proposal's Decision 3 NOTE (no `model:` line instead of current model ids).
Failure picture: a generated agent with `description: |` and nothing after it, `implementer.md` with `edit: false`, or any stale `anthropic/claude-*-2025*` id.

## Steering Log
