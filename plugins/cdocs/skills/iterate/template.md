# Iterate Skill: Devlog Section Templates

These are the workstream's top-level devlog sections, which the overseer owns: copy each one the devlog lacks on Turn 0, then keep the Scratchpoint current and add rows as the loop progresses.

## Scratchpoint

- as_of:
- now:
- next:
- open:
- files:

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

## Steering Log

---

Example rows (do not copy into a devlog):

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | notes |
|---|---|---|---|---|---|---|
| 1 | impl-1 (cdocs:implementer) | rev-1 (cdocs:reviewer) | revise | confirmed | cdocs/reviews/2026-05-13-...-r1.md | cards not rendering; Playwright excerpt inlined in review |

| judge_iteration | trigger | verdict | rationale |
|---|---|---|---|
| 4 | review_count >= --judge-after | rotate-implementer | same selector bug across three reviews |

- 2026-05-13T10:05: same root cause (stale selector) recurs under a new name each review; implementer's residual uncertainty is growing, not shrinking.

| event | agent_handle | target_files | at | notes |
|---|---|---|---|---|
| dispatch | impl-1 (cdocs:implementer) | src/cards.tsx | 2026-05-13T10:00 | iteration 1 |

- 2026-05-13T10:02, for impl-2: also cover the empty-list case (applied: iteration 3)
