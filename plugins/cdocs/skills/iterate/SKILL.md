---
name: iterate
description: Run an implement-review loop on a proposal as the overseer, dispatching fresh implementer, reviewer, and judge subagents until accept-or-escalate
argument-hint: "[proposal_path] [--verification-floor \"<sentence>\"] [--judge-after N]"
---

# CDocs Iterate

Run an iterative implement-review loop on a single proposal.
The invoking session agent enters *overseer mode* and restricts itself to orchestration: it dispatches fresh subagents in alternation, judges their output, periodically dispatches a judge subagent to assess loop health, and terminates on accept-or-escalate rather than retry-count.

> NOTE(opus/cdocs/iterate-skill): The overseer role is a behavioral mode the top-level session agent enters when invoking this skill: that agent restricts itself to orchestration for the duration of the loop.
> The human user is the supervisor, not the overseer: the user invokes the skill and receives escalations; the agent runs the loop.

## Invocation

```
/cdocs:iterate <proposal_path> [--verification-floor "<sentence>"] [--judge-after N]
```

- `<proposal_path>` is required.
  The proposal should have `status: implementation_ready`: warn but proceed if it does not.
- `--verification-floor "<sentence>"` is optional.
  If omitted and the proposal lacks a concrete `## Verification Methodology` section, `AskUserQuestion` the user before starting.
  If the user is not reachable (AFK), write a placeholder floor ("verification was not specified; tests pass and the proposal's stated objective is met") to the iteration log, tag affected rows `[placeholder-floor]`, and prepend a `> WARN` callout to the final summary.
- `--judge-after N` defaults to 3.
  The judge runs starting from the Nth Revise verdict and again before each subsequent Revise-driven iteration.
  The overseer may also invoke the judge earlier at its discretion.

## Four Roles

The loop has four roles.
Synonyms from prior art are surfaced for cross-framework readers.

- **Overseer** (Supervisor, Manager, Orchestrator): the top-level agent in the invoking session, restricted to orchestration.
  Dispatches subagents and judges their output.
  Does not Edit, Write, or run mutating commands during the loop.
  Owns termination, freshness, and escalation decisions.
- **Implementer** (Worker, Engineer, Coder, Editor): a fresh general-purpose subagent dispatched via the Task tool with a prompt that instructs it to follow `/cdocs:implement` conventions for a single iteration.
  Executes the proposal and self-verifies against real-world state before declaring done.
- **Reviewer** (Critic, QA Engineer, Critique Agent): a fresh subagent dispatched via the Task tool with `subagent_type: "reviewer"`.
  Reads the implementer's output with fresh context and a critical mindset.
  May only Edit the target's `last_reviewed` frontmatter; the review document is the artifact it produces.
- **Judge** (Arbiter, Meta-reviewer): a fresh subagent dispatched via the Task tool with `subagent_type: "judge"` to reason about loop *meta-health*, not about the work itself.
  Reads the iteration log and the recent review documents.
  Does not read source code.
  Returns one of `{continue, rotate-implementer, escalate}` plus a short written rationale.

## Loop Protocol

```mermaid
stateDiagram-v2
    [*] --> Brief: receive proposal + verification floor
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
State the verification floor explicitly: from `--verification-floor`, from the proposal's `## Verification Methodology` section, or from `AskUserQuestion`.
Create or append to a devlog with an "Iteration Log" section and an empty "Judge Log" section.
Use the template at `plugins/cdocs/skills/iterate/template.md` (alongside this skill file: `./template.md`).
Prefer appending to the most recent devlog whose `task_list` matches the proposal's `task_list`; otherwise create a new devlog with the proposal's `task_list` and record the choice.

### Turn N.a (Implement)

Dispatch an implementer via the Task tool with `subagent_type: "general-purpose"`.
The prompt must include:

- The proposal path and the verification floor.
- The previous review document path if any.
- An explicit directive *not* to dispatch its own reviewer.
  This overrides `/cdocs:implement`'s in-skill "Request `/cdocs:review` from a subagent after each phase" instruction for the duration of the loop iteration.
- An explicit directive *not* to `git commit` if you want commit authority to rest with the overseer.
  (The default `/cdocs:implement` flow commits inside the iteration; choose explicitly.)

The implementer follows `/cdocs:implement` conventions for this single iteration, runs verification commands, and returns a structured summary.

### Turn N.b (Review)

Dispatch a *new* reviewer subagent (never the previous reviewer) via the Task tool with `subagent_type: "reviewer"`.
The reviewer follows `/cdocs:review` conventions, inspects the live system rather than only the diff, and produces a review document with a verdict.

### Turn N.c (Decide)

Read the produced review document and branch on the verdict:

- **Accept**: terminate.
  Update proposal frontmatter per `/cdocs:implement` conventions and write the final devlog entry.
- **Reject**: escalate immediately.
  The reviewer is asserting "the approach is wrong" at the work level: the overseer does not autonomously override.
  Reject pre-empts the judge path: do not dispatch the judge on a Reject verdict even if `review_count >= --judge-after`.
- **Revise, review count < `--judge-after`**: loop directly to Turn (N+1).a with the same implementer (context carries forward).
- **Revise, review count >= `--judge-after`**: dispatch the judge before the next implementer turn (see Turn N.d).

The overseer may also dispatch the judge before `--judge-after` is reached if it senses trouble (an implementer returning unusually high uncertainty, a review surfacing structural concerns, repeated near-identical commits).
Discretionary invocations are recorded in the Judge Log's `trigger` column.

### Turn N.d (Judge)

Dispatch a *new* judge subagent via the Task tool with `subagent_type: "judge"`.
The Task prompt provides the iteration log entries and the paths to the recent review documents.
The judge reads only those artifacts, returns one of three verdicts, and produces a rationale:

- **continue**: the loop is healthy; the implementer is making progress that the reviewer's bar simply has not yet cleared.
  Loop with the same implementer.
- **rotate-implementer**: the implementer appears stuck, thrashing, or circling the same failure modes.
  Retire the implementer; loop with a *new* implementer that onboards from the iteration log.
- **escalate**: the loop is structurally stuck (conflicting requirements, reviewer and implementer talking past each other, unresolvable design tension).
  Surface to the user with the judge's rationale.

Append a Judge Log row capturing the verdict, the rationale (or a path to a saved rationale file if it does not fit inline), and the trigger.

## Termination Conditions

1. Reviewer returns **Accept**.
2. Reviewer returns **Reject**.
3. Judge returns **escalate**.
4. The user interrupts.

No retry-count cap on Accept-bound progress.
A patient overseer is bounded by review-signal quality and judge meta-assessment, not by clock or retry count.

## Iteration Log and Judge Log

Two tables live in the devlog body (not in frontmatter).
The template at `plugins/cdocs/skills/iterate/template.md` provides the snippets; append them on Turn 0.

**Iteration Log** captures per-iteration implement-and-review activity:

| iteration | implementer | reviewer | review_verdict | review_path | notes |
|---|---|---|---|---|---|
| 1 | impl-1 (general-purpose) | rev-1 (cdocs:reviewer) | revise | cdocs/reviews/2026-05-13-...-r1.md | initial pass; cards not rendering |

The `implementer` and `reviewer` columns hold a synthetic per-loop handle (`impl-N` / `rev-N`) plus the subagent type in parentheses.
Task-tool dispatch does not surface a session identifier: the synthetic handle is generated by the overseer and is the durable cross-reference for "which agent made which iteration."
`review_path` points to the review artifact, relative to repo root.
`notes` distinguishes "tests passed but reviewer found a live-system gap" from "tests failed."

**Judge Log** captures per-judge-invocation meta-assessments:

| judge_iteration | trigger | verdict | rationale | judge_path |
|---|---|---|---|---|
| 3 | review_count >= 3 | rotate-implementer | impl-1 has circled the same scss border bug across r1-r3; fresh perspective likely to unblock | inline |

`judge_iteration` is the iteration number *before which* the judge ran (the judge runs between Turn N.c and Turn (N+1).a).
`trigger` is either `review_count >= --judge-after` or `discretionary` if the overseer invoked early.
`rationale` is inline for short explanations (one or two sentences); longer rationales are saved to a file under `cdocs/devlogs/_judge/` and `judge_path` points to it.

The iteration log is the durable resumption point: a fresh overseer agent reading only the devlog can reconstruct iteration count, current implementer handle, and pending review verdict.
Write a final iteration-log row before yielding so an interrupted loop never leaves the log half-populated.

## Conventions

### Freshness disciplines are rules

Reviewers are fresh every iteration.
The judge is fresh every invocation.
Implementers are fresh when the judge says `rotate-implementer`.
A reviewer that participated in implementation has lost the perspective that justifies a separate review step.
An implementer mid-task carries valuable context and is not replaced reflexively: rotation happens on the judge's call, not on a counter.

### `/cdocs:iterate` overrides `/cdocs:implement`'s in-skill review-dispatch instruction

`/cdocs:implement` says "Request `/cdocs:review` from a subagent after each phase to catch issues early."
Inside the iterate loop, the overseer suppresses that instruction in the dispatched implementer's prompt: the overseer dispatches the review itself.
Without this override, the loop would produce a double-review per iteration and the iteration log would not match the produced reviews.

### Asymmetric second-order dispatch

The loop is auditable from the iteration log and judge log, so write-side subagent dispatch by any of the loop's workers is forbidden.
Implementers do not dispatch reviewers (the overseer owns review dispatch).
The judge does not dispatch implementers or reviewers (the overseer owns rotation and re-review).
None of them dispatch `/cdocs:implement` or other code-mutating subagents.

Read-side investigative dispatch is allowed for reviewers and implementers: a reviewer may dispatch `/cdocs:report` to investigate a recurring bug class without leaving the review turn, and an implementer may dispatch `/cdocs:report` if it needs context the proposal does not provide.
Read-only investigation does not perturb the audited control flow.
The judge's toolset omits Task entirely: a judge that wanted to dispatch a sub-investigation would be re-implementing the overseer's job at the wrong layer.

An implementer that wants to escalate "I think this proposal is wrong" returns that as a structured uncertainty in its summary.
The overseer reads it and may escalate to the user or invoke the judge early.

### The judge is a meta-reviewer, not a second reviewer

The reviewer judges the work; the judge judges the loop.
The judge reads review documents and iteration log entries, not source code.
A short rationale is mandatory: the verdict alone is not auditable.

### Verification floor is mandatory

A one-sentence verification floor with at least one failure-picture is required before the first implementer turn.
If the proposal does not specify one and `--verification-floor` was not passed, `AskUserQuestion` blocks the loop until the user provides it.
AFK fallback: write a placeholder floor and tag rows `[placeholder-floor]` (see Invocation above).

## Edge Cases

- **Implementer ships partial work and returns "I'm stuck."**
  Still dispatch a reviewer; the reviewer's job is to assess what was shipped.
  Surface uncertainties in the iteration log notes.
- **Reviewer crashes mid-review.**
  Re-dispatch a *different* fresh reviewer (not a retry of the same one).
  If three reviewers in a row crash, escalate.
- **Judge crashes mid-assessment.**
  Re-dispatch a *different* fresh judge once.
  If the second judge also crashes, continue the loop with the same implementer for one more iteration and record the crash in the Judge Log notes; if the next required judge invocation also fails, escalate.
- **Implementer dispatches its own reviewer despite the directive.**
  The implementer's review is not authoritative; the skill's reviewer runs anyway.
  Log "implementer dispatched unauthorized review" in the iteration row notes.
- **`status: implementation_accepted` proposal.**
  Warn and ask whether the user intends a re-implementation; if confirmed, tag iteration log entries `[re-implementation]`.
- **Non-`implementation_ready` proposal.**
  Warn but proceed on user confirmation; the skill is intentionally permissive for `wip` proposals.
- **Parallel `/cdocs:iterate` invocations.**
  Out of scope for v1; the skill is single-threaded.
- **Token-budget exhaustion or auto-compaction mid-loop.**
  The iteration log in the devlog is the durable resumption point: write a final row before yielding.

## Subagent Dispatch Reference

| Role | `subagent_type` | Model | Tools |
|---|---|---|---|
| Implementer | `general-purpose` | session default | full |
| Reviewer | `reviewer` | opus (per `plugins/cdocs/agents/reviewer.md`) | Read, Glob, Grep, Edit, Write |
| Judge | `judge` | opus (per `plugins/cdocs/agents/judge.md`) | Read, Glob, Grep, Write |

The judge's tool allowlist deliberately omits Edit, Bash, and Task.
A judge cannot edit source, run commands, or dispatch subagents; it reads artifacts and writes a verdict-and-rationale.
