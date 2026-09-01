---
name: iterate
description: Run an implement-review loop on a proposal as the overseer, dispatching fresh implementer, reviewer, and judge subagents until accept-or-escalate
argument-hint: "[proposal_path] [--verification-floor \"<sentence>\"] [--judge-after N] [-m | --model \"<model_description\"] [-f | --first-round [\"<model_description>\"]]"
---

# CDocs Iterate Loop

Run an iterative implement-review loop scoped to a proposal, a phase, or any unit specified using /cdocs:implement and /cdocs:review subagents,
The invoking session agent enters *overseer mode* and restricts itself to orchestration:
it dispatches fresh subagents in alternation, judges their output, periodically dispatches a judge subagent to assess loop health, and terminates on accept-or-escalate.

The overseer discipline (thin lead, dispatch-by-default, single-writer file ownership, on-resume liveness reconciliation) is defined canonically in [`orchestration-discipline.md`](../../rules/orchestration-discipline.md); this skill references it rather than restating it.
Inline floor: dispatch by default for all tasks beyond trivial few-liners (single-line edits, one-off checks); write durable state to the Iteration Log and a Completed/Decisions Made/Open Todos handoff before compacting; use a fresh reviewer every iteration and a fresh judge every invocation.
The overseer should feel empowered to ask the user multi-choice questions for feedback and guidance unless otherwise strongly stated.
The human user is the supervisor: they invoke the skill and receive escalations; the agent runs the loop.

If the repo has worktree usage practices (it likely does) they should be used to contain the workstream,
where code and cdocs should be committed early and often.

## Invocation

```
/cdocs:iterate <proposal_path> [--verification-floor "<sentence>"] [--judge-after N]
```

- `<proposal_path>` is required; the proposal should have `status: implementation_ready` (warn but proceed otherwise).
  The overseer states the scope (full proposal, phase N, a subset) in Turn 0's Brief.
- `--verification-floor "<sentence>"`: a one-sentence floor including at least one failure-picture.
  If omitted and the proposal lacks a concrete `## Verification Methodology`, `AskUserQuestion` blocks the loop until provided.
  AFK fallback: write a placeholder floor and tag affected rows `[placeholder-floor]`, with a `> WARN` callout on the final summary.
- `--judge-after N` defaults to 3; the judge runs from the Nth Revise verdict onward, and the overseer may invoke earlier at its discretion.
- `-m | --model "<model_description"`: Which model & config to have implementation and review rounds done with.
  Defaults to preferred model in CLAUDE.md or elsewhere, or the current session's config if none is specified.
- `-f | --first-round ["<model_description"]`: Use a different model config for the first round implementation and review.
  If this flag is passed without a value, any preferred expert expensive model in CLAUDE.md or elsewhere is used.
  If no such preference exists, the overseer selects an appropriate larger model+config, like fable to lead an opus loop (a common pattern).
  For default tier guidance (opus lead/judgment, sonnet search/explore, haiku mechanical; consumer floor wins), see [`model-tiering.md`](../../rules/model-tiering.md).

## Roles

- **Overseer**: top-level agent, restricted to orchestration; owns dispatch, freshness, termination.
- **Implementer**: fresh `general-purpose` subagent dispatched with `/cdocs:implement --dispatched`; executes the proposal and self-verifies before reporting done.
- **Reviewer**: fresh `cdocs:reviewer` subagent each iteration; reads the implementer's output with fresh context, inspects the live system, produces a review document with a verdict.
- **Judge**: fresh `cdocs:judge` subagent invoked to assess loop *meta-health*; reads the iteration log and recent reviews, not source. Returns `{continue, rotate-implementer, escalate}` with a short rationale.

## Loop Protocol

```mermaid
stateDiagram-v2
    [*] --> Brief: receive proposal, scope, verification floor
    Brief --> Implement: dispatch fresh implementer
    Implement --> Review: implementer reports done
    Review --> Decide: verdict produced
    Decide --> Implement: revise, continue (same implementer)
    Decide --> Judge: revise, review_count >= --judge-after
    Decide --> [*]: accepted
    Decide --> Escalate: rejected
    Judge --> Implement: continue
    Judge --> Implement: rotate-implementer (fresh implementer)
    Judge --> Escalate: escalate
    Escalate --> [*]: human decides
```

### Turn 0 (Brief)

Read the proposal and any handoff devlog once.
State scope and verification floor explicitly.
Create or append to a devlog with "Iteration Log" and empty "Judge Log" sections from `./template.md`.
Prefer appending to the most recent devlog whose `task_list` matches the proposal's; otherwise create a new one and record the choice.

### Turn N.a (Implement)

Dispatch the implementer via Task with `subagent_type: "general-purpose"` and a prompt that follows `/cdocs:implement --dispatched` conventions, including the proposal path and goals for this iterate session (scope, verification floor, prior review path if any).

`--dispatched` mode suppresses subagent dispatch and routes investigation requests back to the overseer via `## Investigation Requested` blocks; see `/cdocs:implement` Invocation Modes for the schema.

Append a `dispatch` row to the Dispatch/Return Events table when a child (implementer, reviewer, judge, or fork) is dispatched, naming the files it may claim, and a matching `return` row when it reports done.
These rows are what the on-resume reconciliation reads, so the write is not optional: an unpopulated table leaves a resumed overseer nothing to reconcile against.

### Turn N.b (Review)

Dispatch a *new* reviewer subagent (never the previous one) with `subagent_type: "reviewer"`.
The reviewer inspects the live system rather than only the diff and produces a review document with a verdict.
For verification floors that require empirical evidence (browser, dev server, integration, end-to-end, live behavior), the reviewer empirically re-runs the floor and cites at least one artifact path in the review, inlining excerpts for ephemeral artifacts.
This citation is what makes a `confirmed` row admissible.

### Turn N.c (Decide)

Read the review and branch on the verdict:

- **Accept**: terminate. Update proposal frontmatter per `/cdocs:implement` conventions; write the final devlog entry, then run the Checkpoint (below).
- **Reject**: escalate immediately. Reject pre-empts the judge path even if `review_count >= --judge-after`.
- **Revise**, `review_count < --judge-after`: loop to Turn (N+1).a with the same implementer.
- **Revise**, `review_count >= --judge-after`: dispatch the judge before the next implementer turn.

The overseer may invoke the judge earlier on suspicion of trouble (high uncertainty, structural concerns, near-identical commits); discretionary invocations are logged with `trigger: discretionary`.

### Turn N.d (Judge)

Dispatch a fresh judge with the iteration log and the recent review paths.
The judge returns `continue`, `rotate-implementer`, or `escalate` with a rationale (inline for one or two sentences; longer rationales go to `cdocs/devlogs/_judge/` with the path in `judge_path`).
Append a Judge Log row, then run the Checkpoint (below).

### Checkpoint (handoff-before-compact)

The checkpoint fires at each judge assessment (Turn N.d) and on Accept (Turn N.c Accept branch), and proactively after every 3 to 5 iterations at a task-unit boundary.
Write the handoff into the devlog first, THEN compact (`/compact`, or `/clear` for a hard reset).
The handoff is the three-subsection Completed / Decisions Made / Open Todos section defined in [`orchestration-discipline.md`](../../rules/orchestration-discipline.md) Pillar 2; do not restate the format here.
The checkpoint is not complete until the handoff is written: compacting without it is a failure, because the hand-written handoff is more complete than auto-compaction's lossy summary.

## Termination

The loop terminates on Accept, Reject, judge `escalate`, or user interrupt.
No retry-count cap on Accept-bound progress: a patient overseer is bounded by review-signal quality and judge meta-assessment.

A soft context-budget signal is a JUDGE INPUT weighed against progress, never a hard kill.
Overseer context trending past the ~150K target, a run of inline-work turns, or excessive loop length is surfaced by the overseer to the judge, which weighs it against forward progress; it does not itself terminate the loop.
This preserves the accept/reject/escalate/interrupt contract: the soft budget informs a verdict, it never overrides one.

## On-Resume Reconciliation

Before acting on a resumed loop, reconstruct child-dispatch liveness from the Iteration Log's Dispatch/Return Events rows, not from in-window belief.
The harness notifies the overseer only when NO live children remain, so a session resumed mid-interruption can hold a stale "child in flight" belief.
If you believe a child (implementer, reviewer, or judge) is in flight but the harness has returned control (no live children remain), that child has terminated: inspect its on-disk artifacts (its review file, the devlog, committed work) and proceed from the actual state rather than waiting on a child that is already gone.
Likewise, before dispatching a writer against a path, check the event rows for an open ownership claim by another live agent and serialize or re-scope rather than dispatch a second concurrent writer.
See [`orchestration-discipline.md`](../../rules/orchestration-discipline.md) Pillar 1b for the full liveness-reconciliation and single-writer-ownership disciplines.

## Iteration Log and Judge Log

Three tables live in the devlog body (not in frontmatter); copy them from `./template.md` on Turn 0: the Iteration Log, the Judge Log, and the Dispatch/Return Events table.

The Iteration Log carries two additive thinness columns for overseer-context legibility: `overseer_ctx_est` (an approximate current-context estimate, e.g. "~150K (30% inline)") and `inline_work` (a yes/no flag for whether the overseer did inline work this turn).
The overseer writes these each row; the judge reads them to key `escalate` and writes its own `overseer_thinness` verdict (`clean`/`bloat_detected`/`signal_missing`) in the Judge Log.
Absent the overseer columns, the judge logs `signal_missing`, so the checkpoint is enforceable rather than only inferable from prose.
See [`orchestration-discipline.md`](../../rules/orchestration-discipline.md) "Judge-Observable Thinness Signal."

The Dispatch/Return Events table records each child dispatch and return (with the target files it claims) so a resumed overseer can reconcile liveness and file-ownership from the log rather than from in-window belief (see "On-Resume Reconciliation" above).

The Iteration Log carries a `review_proof` column with one of `confirmed`, `n/a`, `deferred-to-followup`, or `skipped`:

- `confirmed`: the reviewer empirically re-verified the work and cited at least one artifact in the review; ephemeral artifacts have excerpts inlined.
  Re-citing a prior round's artifact does not justify `confirmed`; the row rests on evidence the round-N reviewer produced.
- `n/a`: the verification floor does not require empirical browser/runtime evidence. Floors that mention browser, dev server, integration, end-to-end, or live behavior cannot be `n/a`.
- `deferred-to-followup`: self-referential changes (e.g., to `/cdocs:iterate` itself) whose smoke test runs as a separate top-level invocation. The `notes` column points at where the deferred verification will be recorded.
- `skipped`: fail-loud. The overseer justifies it in `notes` or in `### Overseer synthesis` before Accept.

The overseer assigns the value per row; the reviewer produces the evidence that makes `confirmed` admissible.

The iteration log is the durable resumption point: a fresh overseer reading only the devlog can reconstruct iteration count, current implementer handle, and pending review verdict.
Write a final row before yielding so an interrupted loop never leaves the log half-populated.

## Conventions

### Freshness disciplines

Reviewers are fresh every iteration.
The judge is fresh every invocation.
Implementers are fresh only when the judge says `rotate-implementer`: an implementer mid-task carries valuable context and is not replaced reflexively.

### The judge is a meta-reviewer

The reviewer judges the work; the judge judges the loop.
A short rationale is mandatory: the verdict alone is not auditable.

### Sandboxed-runtime trust posture

The reviewer runs with full tools backed by written-instruction constraints.
See [`reviewer.md`](../../agents/reviewer.md) for the boundaries.
