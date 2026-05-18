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
  This overrides `/cdocs:implement`'s in-skill review-dispatch instruction for the duration of the loop iteration.
- An explicit directive *not* to dispatch `/cdocs:report` as a subagent.
  This overrides `/cdocs:implement`'s in-skill `/cdocs:report` dispatch text for the duration of the loop iteration.
  The dispatched implementer self-investigates inline using its own tools (Pattern A) or surfaces an `## Investigation Requested` block in its summary for the overseer to action (Pattern B).
- An explicit directive *not* to `git commit` if you want commit authority to rest with the overseer.
  (The default `/cdocs:implement` flow commits inside the iteration; choose explicitly.)

> NOTE(opus/cdocs/iterate-agent-capabilities): include in the dispatch prompt the platform invariant "subagents cannot dispatch subagents" and point at the two-pattern model in this skill's "Subagents cannot dispatch subagents" section.
> This saves the dispatched implementer a turn discovering the runtime error empirically.

The implementer follows `/cdocs:implement` conventions for this single iteration, runs verification commands, and returns a structured summary.

### Turn N.b (Review)

Dispatch a *new* reviewer subagent (never the previous reviewer) via the Task tool with `subagent_type: "reviewer"`.
The reviewer follows `/cdocs:review` conventions, inspects the live system rather than only the diff, and produces a review document with a verdict.
For proposals whose verification floor requires empirical evidence (browser, dev server, integration, end-to-end, or live behavior), the reviewer empirically re-runs the verification floor itself and cites at least one artifact path in the review document, inlining excerpts for ephemeral artifacts.
This citation is what makes a `[indep-verify: confirmed]` Iteration Log row admissible (see "Iteration Log and Judge Log" below).

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

Every Iteration Log row's `notes` column must end with one of `[indep-verify: confirmed]`, `[indep-verify: n/a]`, `[indep-verify: deferred-to-followup]`, or `[indep-verify: skipped]`.
The overseer assigns the tag for each row based on the verification floor stated at Turn 0 and the iteration's actual content; the rules below describe what the overseer must do to justify each value.

- `confirmed` — the reviewer empirically re-verified the work and cited at least one empirical artifact path in the review document (screenshot, Playwright run output, dev-server log excerpt, curl/HTTP response capture).
  For ephemeral artifacts (test runner output, browser screenshots in `/tmp`), the reviewer inlines the relevant excerpt into the review body so the citation remains resolvable after the artifact rotates or is cleaned up.
  The reviewer is the cite-er; the overseer does not author the citation.
  Re-citing a prior round's artifact does not on its own justify `confirmed`: the round-N reviewer must rest the row on an artifact it produced during its own review turn.
- `n/a` — the proposal's verification floor does not require empirical browser/runtime evidence (pure documentation changes, internal refactors verified by unit tests alone).
  Verification floors that mention browser, dev server, integration, end-to-end, or live behavior cannot be `n/a`.
- `deferred-to-followup` — the verification floor *does* require empirical evidence but cannot be exercised inside the loop reviewing it (typically self-referential changes to `/cdocs:iterate` itself, or proposals whose smoke test requires a separate top-level invocation).
  The notes must include a pointer to where the deferred verification will be recorded: a follow-up devlog path or a tracking task identifier.
  This is distinct from `skipped`: deferral is a structural carve-out with a named follow-up.
  The pointer is checked at row-write time; resolution of the pointed-at follow-up is not enforced inside this loop.
- `skipped` — fail-loud absence.
  The overseer must justify a `skipped` tag in the iteration row's notes or in the `### Overseer synthesis` subsection before Accept.
  An auditor reading only the Iteration Log can immediately spot `skipped` rows.

Example `notes` cell with the tag: `initial pass; cards not rendering [indep-verify: confirmed: cdocs/reviews/2026-05-18-...-r1.md cites screenshot + Playwright excerpt]`.
A grep for `[indep-verify:` over devlogs is the auditor query.

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

`/cdocs:implement` instructs the implementor to dispatch `/cdocs:review` after each phase to catch issues early.
Inside the iterate loop, the overseer suppresses that instruction in the dispatched implementer's prompt: the overseer dispatches the review itself.
Without this override, the loop would produce a double-review per iteration and the iteration log would not match the produced reviews.

### Subagents cannot dispatch subagents

The platform invariant: a subagent (implementer, reviewer, judge) cannot itself dispatch further subagents via the `Task` tool.
The Task tool is `not available inside subagents` at runtime; any guidance that instructs a dispatched subagent to itself dispatch `/cdocs:review` or `/cdocs:report` via Task fails on contact.
[`judge.md`](../../agents/judge.md) lines 91-93 already acknowledge this invariant for the judge's toolset; the same constraint applies to reviewers and implementers when they are dispatched by an overseer.

Two legitimate patterns replace the dead second-order-dispatch text:

**Pattern A: Self-investigation (default).**
The dispatched subagent uses its own tools (`Read`, `Grep`, `Bash`, `WebFetch` where available) to do the investigation inline.
Findings land in the review document (for reviewers), the implementation summary (for implementers), or a `cdocs/reports/` artifact written directly by the subagent if the finding is durably useful.

Example: a reviewer hits an unfamiliar API pattern mid-review.
Rather than trying to dispatch `/cdocs:report`, it uses `Grep` and `Read` to find every other call site, runs `Bash` to inspect a sample response (`curl … | head`), and inlines a four-line excerpt of the response into the review document's Findings section.

**Pattern B: Surface to overseer (fallback).**
When a *separate fresh context* is the actual ask (the investigation is large enough that doing it inline would derail the current review or implementation turn, or the question is durably useful beyond this proposal), the subagent returns a structured "investigation requested" item in its output.
The overseer reads it and dispatches `/cdocs:report` itself, or rolls the request into the next implementer's brief.
This mirrors how implementers already surface "I think this proposal is wrong" as structured uncertainty: the subagent does not autonomously escalate, it surfaces.

The structured request is a fenced block:

```
## Investigation Requested

Question: <one sentence>
Context this would unblock: <one sentence on what the current turn cannot conclude without it>
```

The overseer chooses whether to dispatch `/cdocs:report` immediately, roll the request into the next implementer's brief, or note it as deferred follow-up.
The review document or implementer summary records the request inline so the audit trail captures the decision.

An implementer that wants to escalate "I think this proposal is wrong" returns that as a structured uncertainty in its summary (this is Pattern B applied to a different question).
The overseer reads it and may escalate to the user or invoke the judge early.

### The judge is a meta-reviewer, not a second reviewer

The reviewer judges the work; the judge judges the loop.
The judge reads review documents and iteration log entries, not source code.
A short rationale is mandatory: the verdict alone is not auditable.

### Verification floor is mandatory

A one-sentence verification floor with at least one failure-picture is required before the first implementer turn.
If the proposal does not specify one and `--verification-floor` was not passed, `AskUserQuestion` blocks the loop until the user provides it.
AFK fallback: write a placeholder floor and tag rows `[placeholder-floor]` (see Invocation above).

### Sandboxed-runtime trust posture

`/cdocs:iterate`'s tool-surface trust posture (the reviewer with `Bash` and `WebFetch` under written-instruction constraints) assumes a sandboxed (container or equivalent) runtime where mutation blast-radius is recoverable; see [`reviewer.md`](../../agents/reviewer.md) Constraints for the per-tool boundaries.

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
| Reviewer | `reviewer` | opus (per `plugins/cdocs/agents/reviewer.md`) | Read, Glob, Grep, Edit, Write, Bash, WebFetch |
| Judge | `judge` | opus (per `plugins/cdocs/agents/judge.md`) | Read, Glob, Grep, Write |

The reviewer's `Bash` and `WebFetch` allow empirical re-verification (running tests, starting a dev server, fetching API references) under written-instruction constraints; see [`reviewer.md`](../../agents/reviewer.md) Constraints for the boundaries.
The judge's tool allowlist deliberately omits Edit, Bash, and Task.
A judge cannot edit source, run commands, or dispatch subagents; it reads artifacts and writes a verdict-and-rationale.
