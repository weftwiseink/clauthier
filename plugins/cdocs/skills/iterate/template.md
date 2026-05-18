# Iterate Skill: Devlog Section Templates

The `/cdocs:iterate` skill appends two table sections to the loop's devlog on Turn 0.
This file is the source for those snippets.

Copy the two H2 sections below into the devlog body verbatim, then append a row to each table as the loop progresses.

## Iteration Log

| iteration | implementer | reviewer | review_verdict | review_path | notes |
|---|---|---|---|---|---|

## Judge Log

| judge_iteration | trigger | verdict | rationale | judge_path |
|---|---|---|---|---|

## Column Semantics

**Iteration Log**

- `iteration`: integer, starting at 1, monotonic per loop.
- `implementer`: synthetic per-loop handle (`impl-N`) plus the subagent type in parentheses, e.g. `impl-1 (general-purpose)`.
  The handle increments when the judge returns `rotate-implementer`; it stays the same across continuing iterations.
- `reviewer`: synthetic per-loop handle (`rev-N`) plus the subagent type in parentheses, e.g. `rev-2 (cdocs:reviewer)`.
  Reviewers are fresh every iteration: `rev-N` increments every row.
- `review_verdict`: one of `accept`, `revise`, `reject`.
- `review_path`: path to the review artifact, relative to repo root.
- `notes`: short free text.
  Use to surface implementer uncertainties, tag `[placeholder-floor]` rows when running without an explicit verification floor, or distinguish "tests passed but reviewer found a live-system gap" from "tests failed."
  Every row's `notes` cell must end with one of `[indep-verify: confirmed]`, `[indep-verify: n/a]`, `[indep-verify: deferred-to-followup: <pointer>]`, or `[indep-verify: skipped]`; see the `## Iteration Log and Judge Log` section in `plugins/cdocs/skills/iterate/SKILL.md` for the per-value rules.

Example Iteration Log row with the tag:

| iteration | implementer | reviewer | review_verdict | review_path | notes |
|---|---|---|---|---|---|
| 1 | impl-1 (general-purpose) | rev-1 (cdocs:reviewer) | revise | cdocs/reviews/2026-05-13-...-r1.md | cards not rendering; Playwright excerpt inlined in review [indep-verify: confirmed] |

**Judge Log**

- `judge_iteration`: the iteration number *before which* the judge ran.
  The judge runs between Turn N.c and Turn (N+1).a; this column records N+1.
- `trigger`: either `review_count >= --judge-after` (rule-driven) or `discretionary` (overseer chose to invoke early).
- `verdict`: one of `continue`, `rotate-implementer`, `escalate`.
- `rationale`: short rationales (one or two sentences) live inline.
  Longer rationales go to a file under `cdocs/devlogs/_judge/` and the inline text becomes a short summary plus a path reference.
- `judge_path`: `inline` if the rationale is in the table cell, otherwise the path to the saved rationale file relative to repo root.
