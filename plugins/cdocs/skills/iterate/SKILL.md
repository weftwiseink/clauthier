---
name: iterate
description: Run an implement-review loop on a proposal as the overseer, dispatching fresh implementer, reviewer, and judge subagents until accept-or-escalate
argument-hint: "[proposal_path] [--verification-floor \"<sentence>\"] [--judge-after N] [-m | --model \"<model_description\"] [-f | --first-round [\"<model_description>\"]] [--graphify-scope]"
---

# CDocs Iterate Loop

Run an iterative implement-review loop scoped to a proposal, a phase, or any unit specified using /cdocs:implement and /cdocs:review subagents,
The invoking session agent enters *overseer mode* and restricts itself to orchestration:
it dispatches fresh subagents in alternation, judges their output, periodically dispatches a judge subagent to assess loop health, and terminates on accept-or-escalate.

The overseer discipline (thin lead, dispatch-by-default, single-writer file ownership, on-resume liveness reconciliation) is defined canonically in [`orchestration-discipline.md`](../../rules/orchestration-discipline.md); this skill references it rather than restating it.
Inline floor: dispatch by default for all tasks beyond trivial few-liners (single-line edits, one-off checks); write durable state to the Iteration Log and a Completed/Decisions Made/Open Todos handoff at task-unit boundaries; use a fresh reviewer every iteration and a fresh judge every invocation.
Worktree/filesystem isolation binds the dispatched implementer and reviewer, never this overseer session, which stays free to land, resolve, and fork; the principle is canonical in [`orchestration-discipline.md`](../../rules/orchestration-discipline.md) "Isolation is a dispatched-agent property".
The overseer should feel empowered to ask the user multi-choice questions for feedback and guidance unless otherwise strongly stated.
The human user is the supervisor: they invoke the skill and receive escalations; the agent runs the loop.

Code and cdocs should be committed early and often.

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
- `--graphify-scope`: opt into priming a graphify-resolved dependent-set brief into the reviewer's dispatch (see "Graphify scoping" below).
  DEFAULT OFF: with the flag absent the loop behaves exactly as today and makes zero graphify calls.

## Graphify scoping (flag-gated, reviewer only, default OFF)

When `--graphify-scope` is passed, the overseer primes a compact graph-resolved dependent-set brief into the reviewer's dispatch prompt up front, so the reviewer starts from the change's true MULTI-FILE dependent set instead of a speculative read sweep.
This is deliberately minimal: prime a brief + point the reviewer at the graphify CLI. It is currently wired for the REVIEWER role only (the RFP's original consumer); implementer and judge are out of scope for this increment.

At **Turn N.b (Review)**, before dispatching the reviewer, and ONLY when the flag is on, the overseer runs the helper against the round's changed files:

```
plugins/cdocs/scripts/graphify-scope.sh brief --enable --diff-base <base-ref>
```

The default pipeline derives symbols from the changed files (`explain` a file to get its `[contains]` symbols, then `affected` each symbol for its dependent set). Pass `--symbols "<label> <label>"` to bypass the `explain` step and run `affected` directly on known symbol labels instead.
When a changed file's `explain` output is truncated at graphify's connection cap, the brief carries a `SCOPE-TRUNCATED: <file> ...` marker (its dependents may be under-listed): the reviewer should widen on that file's symbols rather than trust the set as broad.

- If the first line is `SCOPE-STATUS: scoped`, the overseer pastes the brief VERBATIM into the reviewer's dispatch prompt under a "Graphify scoped-context brief" heading, and the reviewer treats it per [`reviewer.md`](../../agents/reviewer.md) (an AID, never a completeness guarantee).
- If the first line is `SCOPE-STATUS: skip-scope` or `disabled` (missing/stale index, missing graphify binary, engine error, or an empty/near-empty set), the round is a fallback round: the overseer primes NO brief and the reviewer runs today's unscoped sweep. Note the labeled status in the Iteration Log `notes` (e.g. `[graphify: skip-scope missing-index]`) so instrumentation can tell scoped rounds from fallback rounds.

The helper is ADDITIVE ONLY: it can only ever ADD context to a round, never narrow it, so its absence or any fallback never lowers recall below the current baseline.
The overseer never blocks a round on scoping.
Flag off = no helper call at all.

## Roles

- **Overseer**: top-level agent, restricted to orchestration; owns dispatch, freshness, termination.
- **Implementer**: fresh `cdocs:implementer` subagent dispatched with `/cdocs:implement --dispatched`; executes the proposal and self-verifies before reporting done.
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
Create or append to a devlog, copying from `./template.md` the `## Scratchpoint` (unless the devlog already has one) and all four table sections: the Iteration Log, the (empty) Judge Log, the Dispatch/Return Events table, and the (empty) Steering Log.
Prefer appending to the most recent devlog whose `task_list` matches the proposal's; otherwise create a new one and record the choice.

### Turn N.a (Implement)

Dispatch the implementer via Task with `subagent_type: "cdocs:implementer"` and a prompt that follows `/cdocs:implement --dispatched` conventions, including the proposal path and goals for this iterate session (scope, verification floor, prior review path if any).

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
  If landing the accepted work is a cross-worktree step (a merge into `main`, or a fork off `main`), the overseer is NOT isolation-bound: it surfaces that step as an explicit precondition up front and ROUTES it to the consuming repo's cross-worktree commands (e.g. in weftwise: `/resolve-wt`, `/dogfood-wt`, `/worktree`), warning never refusing. See the "Isolation is a dispatched-agent property" section (Isolation-aware routing) of [`orchestration-discipline.md`](../../rules/orchestration-discipline.md).
- **Reject**: escalate immediately. Reject pre-empts the judge path even if `review_count >= --judge-after`.
- **Revise**, `review_count < --judge-after`: loop to Turn (N+1).a with the same implementer.
- **Revise**, `review_count >= --judge-after`: dispatch the judge before the next implementer turn.

The overseer may invoke the judge earlier on suspicion of trouble (high uncertainty, structural concerns, near-identical commits); discretionary invocations are logged with `trigger: discretionary`.

### Turn N.d (Judge)

Dispatch a fresh judge with the iteration log and the recent review paths.
The judge returns `continue`, `rotate-implementer`, or `escalate` with a rationale (inline for one or two sentences; longer rationales go to `cdocs/devlogs/_judge/` with the path in `judge_path`).
Append a Judge Log row, then run the Checkpoint (below).

### Checkpoint (handoff)

The checkpoint fires at each judge assessment (Turn N.d) and on Accept (Turn N.c Accept branch).
Write the handoff into the devlog.
The handoff is the three-subsection Completed / Decisions Made / Open Todos section defined in [`orchestration-discipline.md`](../../rules/orchestration-discipline.md) Pillar 2; do not restate the format here.
The checkpoint is not complete until the handoff is written: the hand-written handoff is what a resuming reader trusts over a compaction's lossy summary.
Between checkpoints the overseer keeps the devlog's `## Scratchpoint` current per Pillar 2 "Scratchpoint"; the dispatched implementer keeps none.

## Termination

The loop terminates on Accept, Reject, judge `escalate`, or user interrupt.
No retry-count cap on Accept-bound progress: a patient overseer is bounded by review-signal quality and judge meta-assessment.

## Steering

A human message that arrives while a subagent is in flight is queued, never injected: fold it into the next dispatch.
Note each directive in the devlog's `## Steering Log` (free text: when, for whom, what, where applied) as soon as you see it, so a resumed overseer can pick up any not yet applied.

## On-Resume Reconciliation

Before acting on a resumed loop, reconstruct child-dispatch liveness from the Iteration Log's Dispatch/Return Events rows, not from in-window belief.
The harness notifies the overseer only when NO live children remain, so a session resumed mid-interruption can hold a stale "child in flight" belief.
If you believe a child (implementer, reviewer, or judge) is in flight but the harness has returned control (no live children remain), that child has terminated: inspect its on-disk artifacts (its review file, the devlog, committed work) and proceed from the actual state rather than waiting on a child that is already gone.
Likewise, before dispatching a writer against a path, check the event rows for an open ownership claim by another live agent and serialize or re-scope rather than dispatch a second concurrent writer.
See [`orchestration-discipline.md`](../../rules/orchestration-discipline.md) Pillar 1b for the full liveness-reconciliation and single-writer-ownership disciplines.

Re-queue any Steering Log directive not yet applied.

## Iteration Log and Judge Log

Four tables live in the devlog body (not in frontmatter); copy them from `./template.md` on Turn 0: the Iteration Log, the Judge Log, the Dispatch/Return Events table, and the Steering Log (see "Steering").

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

The DISPATCHED reviewer runs with full tools backed by written-instruction constraints; these constraints bind the reviewer, not the overseer session, which is never isolation-bound (see [`orchestration-discipline.md`](../../rules/orchestration-discipline.md) "Isolation is a dispatched-agent property").
See [`reviewer.md`](../../agents/reviewer.md) for the boundaries.
