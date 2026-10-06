# Iterate Skill: Devlog Section Templates

Copy the five H2 sections below into the loop's devlog on Turn 0 (skip `## Scratchpoint` if the devlog already has one), then keep the Scratchpoint current and add rows as the loop progresses.

## Scratchpoint

- as_of:
- now:
- next:
- open:
- files:

## Iteration Log

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | notes |
|---|---|---|---|---|---|---|

## Judge Log

| judge_iteration | trigger | verdict | rationale | judge_path |
|---|---|---|---|---|

## Dispatch/Return Events

| event | agent_handle | target_files | at | notes |
|---|---|---|---|---|

## Steering Log

---

Example rows (do not copy into a devlog):

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | notes |
|---|---|---|---|---|---|---|
| 1 | impl-1 (cdocs:implementer) | rev-1 (cdocs:reviewer) | revise | confirmed | cdocs/reviews/2026-05-13-...-r1.md | cards not rendering; Playwright excerpt inlined in review |

| judge_iteration | trigger | verdict | rationale | judge_path |
|---|---|---|---|---|
| 4 | review_count >= --judge-after | rotate-implementer | same selector bug across three reviews | inline |

| event | agent_handle | target_files | at | notes |
|---|---|---|---|---|
| dispatch | impl-1 (cdocs:implementer) | src/cards.tsx | 2026-05-13T10:00 | iteration 1 |

- 2026-05-13T10:02, for impl-2: also cover the empty-list case (applied: iteration 3)
