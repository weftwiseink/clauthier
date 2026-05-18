# Iterate Skill: Devlog Section Templates

The `/cdocs:iterate` skill appends two table sections to the loop's devlog on Turn 0.
This file is the source for those snippets.

Copy the two H2 sections below into the devlog body verbatim, then append a row to each table as the loop progresses.

## Iteration Log

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | notes |
|---|---|---|---|---|---|---|

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
- `review_proof`: one of `confirmed`, `n/a`, `deferred-to-followup`, `skipped`.
  The overseer assigns the value per row based on the verification floor and the iteration's actual content; see `SKILL.md` "Iteration Log and Judge Log" for the per-value rules.
- `review_path`: path to the review artifact, relative to repo root.
- `notes`: short free text.
  Surfaces implementer uncertainties, supporting evidence summaries, pointer paths (required for `deferred-to-followup`), overseer justifications (required for `skipped`), or `[placeholder-floor]` tags when running without an explicit verification floor.

Example row:

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | notes |
|---|---|---|---|---|---|---|
| 1 | impl-1 (general-purpose) | rev-1 (cdocs:reviewer) | revise | confirmed | cdocs/reviews/2026-05-13-...-r1.md | cards not rendering; Playwright excerpt inlined in review |

**Judge Log**

- `judge_iteration`: the iteration number *before which* the judge ran.
  The judge runs between Turn N.c and Turn (N+1).a; this column records N+1.
- `trigger`: either `review_count >= --judge-after` (rule-driven) or `discretionary` (overseer chose to invoke early).
- `verdict`: one of `continue`, `rotate-implementer`, `escalate`.
- `rationale`: short rationales (one or two sentences) live inline.
  Longer rationales go to a file under `cdocs/devlogs/_judge/` and the inline text becomes a short summary plus a path reference.
- `judge_path`: `inline` if the rationale is in the table cell, otherwise the path to the saved rationale file relative to repo root.
