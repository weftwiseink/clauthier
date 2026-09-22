# Iterate Skill: Devlog Section Templates

The `/cdocs:iterate` skill appends four table sections to the loop's devlog on Turn 0.
This file is the source for those snippets.

Copy the four H2 sections below into the devlog body verbatim, then append a row to each table as the loop progresses.

## Iteration Log

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | overseer_ctx_est | inline_work | notes |
|---|---|---|---|---|---|---|---|---|

## Judge Log

| judge_iteration | trigger | verdict | overseer_thinness | rationale | judge_path |
|---|---|---|---|---|---|

## Dispatch/Return Events

| event | agent_handle | target_files | at | notes |
|---|---|---|---|---|

## Steering Log

| at | kind | target | content | applied_at_iteration |
|---|---|---|---|---|

## Column Semantics

**Iteration Log**

- `iteration`: integer, starting at 1, monotonic per loop.
- `implementer`: synthetic per-loop handle (`impl-N`) plus the subagent type in parentheses, e.g. `impl-1 (cdocs:implementer)`.
  The handle increments when the judge returns `rotate-implementer`; it stays the same across continuing iterations.
- `reviewer`: synthetic per-loop handle (`rev-N`) plus the subagent type in parentheses, e.g. `rev-2 (cdocs:reviewer)`.
  Reviewers are fresh every iteration: `rev-N` increments every row.
- `review_verdict`: one of `accept`, `revise`, `reject`.
- `review_proof`: one of `confirmed`, `n/a`, `deferred-to-followup`, `skipped`.
  The overseer assigns the value per row based on the verification floor and the iteration's actual content; see `SKILL.md` "Iteration Log and Judge Log" for the per-value rules.
- `review_path`: path to the review artifact, relative to repo root.
- `overseer_ctx_est`: overseer-written approximate current-context estimate for the turn, e.g. `~150K (30% inline)`.
  It makes the overseer's context trend visible across rows so the judge can key `escalate` off a rising trend.
- `inline_work`: overseer-written `yes`/`no` flag for whether the overseer performed inline work (bulk reads, edits, or command runs it could have dispatched) this turn.
  A run of `yes` rows is a workhorse signal the judge weighs.
- `notes`: short free text.
  Surfaces implementer uncertainties, supporting evidence summaries, pointer paths (required for `deferred-to-followup`), overseer justifications (required for `skipped`), or `[placeholder-floor]` tags when running without an explicit verification floor.

Example row:

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | overseer_ctx_est | inline_work | notes |
|---|---|---|---|---|---|---|---|---|
| 1 | impl-1 (cdocs:implementer) | rev-1 (cdocs:reviewer) | revise | confirmed | cdocs/reviews/2026-05-13-...-r1.md | ~120K (10% inline) | no | cards not rendering; Playwright excerpt inlined in review |

**Judge Log**

- `judge_iteration`: the iteration number *before which* the judge ran.
  The judge runs between Turn N.c and Turn (N+1).a; this column records N+1.
- `trigger`: either `review_count >= --judge-after` (rule-driven) or `discretionary` (overseer chose to invoke early).
- `verdict`: one of `continue`, `rotate-implementer`, `escalate`.
- `overseer_thinness`: judge-written diagnosis of overseer context health, one of `clean`, `bloat_detected`, `signal_missing`.
  This is distinct from `verdict`: a judge may log `bloat_detected` while returning `continue` when rising context coexists with clear progress, keeping the bloat diagnosis auditable independent of the loop verdict.
  `signal_missing` is written when the Iteration Log's `overseer_ctx_est`/`inline_work` columns are absent, making an unenforced checkpoint visible in the log.
- `rationale`: short rationales (one or two sentences) live inline.
  Longer rationales go to a file under `cdocs/devlogs/_judge/` and the inline text becomes a short summary plus a path reference.
- `judge_path`: `inline` if the rationale is in the table cell, otherwise the path to the saved rationale file relative to repo root.

**Dispatch/Return Events**

Records each child dispatch and return so a resumed overseer can reconcile liveness and file-ownership from the log rather than from in-window recollection (see `SKILL.md` "On-Resume Reconciliation").

- `event`: one of `dispatch`, `return`.
- `agent_handle`: the child's per-loop handle, e.g. `impl-1 (cdocs:implementer)` or `rev-2 (cdocs:reviewer)`.
- `target_files`: the file paths this child will `Write`/`Edit` (its ownership claim), so a second concurrent writer against the same path can be detected before dispatch.
  `n/a` for a read-only child (e.g. the judge).
- `at`: ISO 8601 timestamp of the event.
- `notes`: short free text, e.g. the return summary pointer or a re-scope note.

**Steering Log**

Records human directives that arrive after Turn 0 so the overseer can fold them into the *next* dispatch (never an in-flight subagent) and a fresh overseer can recover pending directives on resume (see `SKILL.md` "Injection points" and "On-Resume Reconciliation").

- `at`: ISO 8601 timestamp the directive was received.
- `kind`: one of `steer-implementer`, `steer-reviewer-floor`, `pause`, `resume`, `override-judge`.
- `target`: which future actor/turn the directive applies to, e.g. `impl-2`, `rev-3`, `judge-escalate@i4`.
- `content`: the actual instruction, floor text, or override rationale, as free text.
- `applied_at_iteration`: the iteration number where the overseer folded the directive into a dispatch prompt; `pending` while queued/not-yet-applied; `n/a` for a `pause`/`resume` marker row.
  The overseer appends the row the moment it notices the directive (even if application is deferred) and updates this field when it actually folds the content into a dispatch.
