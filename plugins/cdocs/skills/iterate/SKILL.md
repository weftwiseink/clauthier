---
name: iterate
description: Run an implement-review loop on a proposal as the overseer, dispatching fresh implementer, reviewer, and judge subagents until accept-or-escalate
argument-hint: "[proposal_path] [--verification-floor \"<sentence>\"] [--judge-after N] [-m | --model \"<model_description\"] [-f | --first-round [\"<model_description>\"]] [--graphify-scope]"
---

# CDocs Iterate Loop

Run an iterative implement-review loop scoped to a proposal, a phase, or any unit specified using /cdocs:implement and /cdocs:review subagents,
The invoking session agent enters *overseer mode* and restricts itself to orchestration:
it dispatches fresh subagents in alternation, judges their output, periodically dispatches a judge subagent to assess loop health, and terminates on accept-or-escalate.

The overseer discipline is defined in [`overseers.md`](../../rules/overseers.md); this skill references it rather than restating it.
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
  For default tiers, see [`workflow-patterns.md`](../../rules/workflow-patterns.md) "Model Tiering".
- `--graphify-scope`: opt into priming a graphify-resolved dependent-set brief into the reviewer's dispatch (see "Graphify scoping" below).
  DEFAULT OFF: with the flag absent the loop behaves exactly as today and makes zero graphify calls.

## Graphify scoping (flag-gated, reviewer only, default OFF)

When `--graphify-scope` is passed, the overseer primes a compact graph-resolved dependent-set brief into the reviewer's dispatch prompt up front, so the reviewer starts from the change's true MULTI-FILE dependent set instead of a speculative read sweep.
This is deliberately minimal: prime a brief + point the reviewer at the graphify CLI. It is currently wired for the REVIEWER role only (the RFP's original consumer); implementer and judge are out of scope for this increment.

At **Turn N.b (Review)**, before dispatching the reviewer, and ONLY when the flag is on, the overseer runs the helper (on `PATH` from the plugin's `bin/`) against the round's changed files:

```
graphify-scope brief --enable --diff-base <base-ref>
```

The default pipeline derives symbols from the changed files (`explain` a file to get its `[contains]` symbols, then `affected` each symbol for its dependent set). Pass `--symbols "<label> <label>"` to bypass the `explain` step and run `affected` directly on known symbol labels instead.
When a changed file's `explain` output is truncated at graphify's connection cap, the brief carries a `SCOPE-TRUNCATED: <file> ...` marker (its dependents may be under-listed): the reviewer should widen on that file's symbols rather than trust the set as broad.

- If the first line is `SCOPE-STATUS: scoped`, the overseer pastes the brief VERBATIM into the reviewer's dispatch prompt under a "Graphify scoped-context brief" heading, and the reviewer treats it per [`reviewer.md`](../../agents/reviewer.md) (an AID, never a completeness guarantee).
- If the first line is `SCOPE-STATUS: skip-scope` or `disabled` (missing/stale index, missing graphify binary, engine error, or an empty/near-empty set), or the `graphify-scope` command itself is missing (OpenCode, or a non-CLI install without `bin/`; log it as `[graphify: skip-scope no-command]`), the round is a fallback round: the overseer primes NO brief and the reviewer runs today's unscoped sweep. Note the labeled status in the Iteration Log `notes` (e.g. `[graphify: skip-scope missing-index]`) so instrumentation can tell scoped rounds from fallback rounds.

The helper is ADDITIVE ONLY: it can only ever ADD context to a round, never narrow it, so its absence or any fallback never lowers recall below the current baseline.
The overseer never blocks a round on scoping.
Flag off = no helper call at all.

## Roles

- **Overseer**: top-level agent, restricted to orchestration; owns dispatch, freshness, termination.
- **Implementer**: fresh `cdocs:implementer` subagent dispatched with `/cdocs:implement --dispatched`; executes the proposal and self-verifies before reporting done.
- **Reviewer**: fresh `cdocs:reviewer` subagent each iteration; reads the implementer's output with fresh context, inspects the live system, produces a review document with a verdict.
- **Judge**: fresh `cdocs:judge` subagent invoked to assess loop *meta-health*; reads the iteration log and recent reviews, not source. Returns `{continue, rotate-implementer, escalate}` with a short rationale.

## Loop Protocol

### Turn 0 (Brief)

Read the proposal once.
State scope and verification floor explicitly.
Continue the workstream's top-level devlog, which you own: the most recent devlog whose `task_list` matches the proposal's, that cites the proposal, and that has no `part_of` (a propose-revise or an earlier iterate may have started it).
Otherwise create one (`YYYY-MM-DD-<slug>-iterate.md`, citing the proposal in its Brief) and record the choice.
When continuing, orient from its Scratchpoint and any handoff, per the devlog skill's "Handoffs".
Copy from `./template.md` the sections it lacks: `## Scratchpoint`, `## Workstream Devlogs`, and the four log sections (Iteration Log, Judge Log, Dispatch/Return Events, Steering Log).

### Turn N.a (Implement)

Dispatch the implementer via Task with `subagent_type: "cdocs:implementer"` and a prompt that follows `/cdocs:implement --dispatched` conventions, including the proposal path and goals for this iterate session (scope, verification floor, prior review path if any).
Name the sub-devlog it writes, per the devlog skill's "Continuing in a new devlog": the open concern's to continue it, or a new one for a new concern, with the top-level path for its `part_of`.
Add a `## Workstream Devlogs` row for each new sub-devlog, including any successor the implementer reports.

Append a `dispatch` row to the Dispatch/Return Events table when a child (implementer, reviewer, judge, or fork) is dispatched, naming the files it may claim, and a matching `return` row when it reports done.

### Turn N.b (Review)

Dispatch a *new* reviewer subagent (never the previous one) with `subagent_type: "cdocs:reviewer"`, pointing it at the proposal and the sub-devlog the implementer wrote.
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
The judge returns `continue`, `rotate-implementer`, or `escalate` with a rationale in its final message.
Append a Judge Log row, and when the reasoning matters (typically `rotate-implementer` or `escalate`) add a short note beneath the row, then run the Checkpoint (below).

### Checkpoint (handoff)

Keep your Scratchpoint current and write handoffs per the devlog skill's "The Scratchpoint Section" and "Handoffs".
When a finished concern's writer did not mark its sub-devlog `done` (the next concern went to another implementer), mark it.

## Termination

The loop terminates on Accept, Reject, judge `escalate`, or user interrupt.
No retry-count cap on Accept-bound progress: a patient overseer is bounded by review-signal quality and judge meta-assessment.

## Steering

A human message that arrives while a subagent is in flight is queued, never injected: fold it into the next dispatch.
Note each directive in your devlog's `## Steering Log` (free text: when, for whom, what, where applied) as soon as you see it, so a resumed overseer can pick up any not yet applied.

## Iteration Log and Judge Log

Four log sections live in the top-level devlog's body; copy them from `./template.md` on Turn 0 (column examples are at the bottom of that file).

The Iteration Log's `review_proof` takes one value per row:

- `confirmed`: this round's reviewer re-ran the floor and cited an artifact it produced; re-citing an earlier round's artifact does not count.
- `n/a`: the floor needs no runtime evidence (a floor naming browser, dev server, integration, end-to-end, or live behavior never does).
- `deferred-to-followup`: a self-referential change whose smoke runs as a separate top-level invocation; `notes` points at where it will be recorded.
- `skipped`: fail-loud; the overseer justifies it in `notes` before Accept.

The log is the durable resumption point: write a final row before yielding so an interrupted loop never leaves it half-populated.

## Conventions

### Freshness disciplines

Reviewers are fresh every iteration.
The judge is fresh every invocation.
Implementers are fresh only when the judge says `rotate-implementer`: an implementer mid-task carries valuable context and is not replaced reflexively.

### The judge is a meta-reviewer

The reviewer judges the work; the judge judges the loop.
A short rationale is mandatory: the verdict alone is not auditable.

### Sandboxed-runtime trust posture

See [`reviewer.md`](../../agents/reviewer.md) for the reviewer's boundaries.
