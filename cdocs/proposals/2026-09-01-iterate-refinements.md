---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-01T10:18:03-07:00
task_list: cdocs/iterate-skill
type: proposal
state: live
status: implementation_accepted
last_reviewed:
  status: accepted
  by: "@claude-opus-4-8"
  at: 2026-09-06T11:05:00-07:00
  round: 2
tags: [iterate, triage, agent_orchestration, audit_trail, human_in_the_loop]
---

# `/cdocs:iterate` Refinements: Triage Log-Awareness and Mid-Loop Steering

> BLUF(sonnet-5/cdocs/iterate-refinements): Two follow-on gaps in the shipped `/cdocs:iterate` loop, both named as open questions in [`2026-09-01-overseer-consolidation.md`](2026-09-01-overseer-consolidation.md) §B (items 10-11).
> (A) `/cdocs:triage` judges a proposal's frontmatter blind to any `/cdocs:iterate` history: it cannot tell "round-3 thrashing on a plain `/cdocs:review` cycle" from "loop already judge-escalated at round 2" or "loop accepted, frontmatter update simply missed."
> This proposal teaches triage to locate the loop's devlog and read its Iteration Log / Judge Log before recommending a status transition.
> (B) The loop has no formalized way for a human to steer a running loop (redirect the next implementer, tighten a verification floor, pause/resume, override a judge escalation) without either interrupting a live subagent (breaking freshness) or silently mutating loop state out-of-band (breaking the audit trail).
> This proposal adds a `## Steering Log` devlog table and defines turn-boundary injection points that fold human input into the *next* dispatch only.
> Two adjacent open questions (judge cadence, implementer return schema) are explicitly out of scope; see below.

## Summary

`/cdocs:iterate` shipped via [`2026-05-13-iterate-skill.md`](2026-05-13-iterate-skill.md) and was hardened by [`2026-05-18-iterate-agent-capabilities.md`](2026-05-18-iterate-agent-capabilities.md) (reviewer tool surface, dead sub-dispatch text, the `[indep-verify]` tag).
That second proposal's own Objective named four coupled follow-on gaps but only closed two of them.
The other two, triage awareness and mid-loop steering, were re-surfaced independently during the 2026-09-01 overseer-consolidation survey and are this proposal's scope.

Both refinements are additive to the existing loop protocol: neither changes the Accept/Reject/Revise verdict taxonomy, the freshness disciplines, or the judge's read-only meta-reviewer posture.
Refinement A changes what `/cdocs:triage` reads before recommending a status transition; it is additive for proposals with no iterate history, but on the accept path it also introduces one new recommendation output value (`[STATUS] implementation_accepted`) the blind table lacks.
Refinement B only changes what happens at turn boundaries the overseer already has (it does not add new interrupt machinery); it formalizes and extends the existing "write a final row before yielding" resumption discipline to cover a deliberate pause, not just a crash.

## Objective

Close the two remaining `/cdocs:iterate`-scoped open questions from [`2026-09-01-overseer-consolidation.md`](2026-09-01-overseer-consolidation.md) §B:

- **Item 10**: "Triage awareness of the Iteration Log / Judge Log: should `/cdocs:triage` recommend workflow status based on latest review/judge verdicts in a devlog?"
- **Item 11**: "User mid-loop participation controls: `--pause-after N`, `--pause-on-judge`, or a mechanism to override a judge verdict."

Both gaps share a root cause: `/cdocs:iterate`'s devlog (Iteration Log, Judge Log) is currently a write-only audit trail from every consumer's perspective except the overseer mid-loop.
Triage cannot read it to inform frontmatter recommendations; a human cannot write to it to steer the loop.
This proposal makes the devlog a two-way surface for both.

## Background

### Prior art / predecessor

[`2026-05-18-iterate-agent-capabilities.md`](2026-05-18-iterate-agent-capabilities.md) (`status: implementation_accepted`, archived) is the direct predecessor.
Its Objective named the same coupled-gaps framing this proposal uses, closed two of the four gaps it identified (reviewer tool surface, dead sub-dispatch text) plus the `[indep-verify]` audit tag, and left the other two (now items 10-11 above) unaddressed.
This proposal is the next increment against the same `cdocs/iterate-skill` workstream.

### Relevant components

- Loop skill: [`plugins/cdocs/skills/iterate/SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md), especially "Iteration Log and Judge Log" and "Termination".
- Devlog table templates: [`plugins/cdocs/skills/iterate/template.md`](../../plugins/cdocs/skills/iterate/template.md).
- Triage skill and agent: [`plugins/cdocs/skills/triage/SKILL.md`](../../plugins/cdocs/skills/triage/SKILL.md), [`plugins/cdocs/agents/triage.md`](../../plugins/cdocs/agents/triage.md), specifically the "Check workflow state" table (`triage.md` lines 56-63).
- Judge agent: [`plugins/cdocs/agents/judge.md`](../../plugins/cdocs/agents/judge.md), read-only, `escalate` verdict.
- Open-questions source: [`2026-09-01-overseer-consolidation.md`](2026-09-01-overseer-consolidation.md) §B, items 8-11.

### Current state

`/cdocs:triage`'s workflow-state table (`triage.md` lines 56-63) keys entirely off a document's own frontmatter (`status`, `last_reviewed.status`, `last_reviewed.round`).
It has no step that looks for a devlog, let alone one with `## Iteration Log` / `## Judge Log` sections.
A proposal driven through `/cdocs:iterate` updates its `last_reviewed` frontmatter only via the reviewer agent's per-round convention and via the overseer's Accept-turn update; nothing keeps triage's blind heuristics (e.g. `round >= 3` triggers `[ESCALATE]`) aligned with what the loop's own judge already decided.

`/cdocs:iterate` has no protocol turn or log column for human input arriving after Turn 0.
The human is stated to be "the supervisor: they invoke the skill and receive escalations" (`SKILL.md` line 16), but nothing describes what happens if the supervisor wants to say something *before* an escalation, mid-loop.
In practice a user typing into the overseer's session between subagent dispatches already reaches the overseer; what's missing is a convention for what the overseer does with it and how that's recorded.

## Proposed Solution

### A. Triage awareness of Iteration/Judge Logs

**What triage reads.** When triaging a `type: proposal` document, the triage agent gains a new analysis step, run before "Check workflow state":

1. Glob `cdocs/devlogs/*.md` for documents whose frontmatter `task_list` matches the proposal's `task_list`.
2. Among matches, keep only devlogs containing a `## Iteration Log` heading (i.e., produced by `/cdocs:iterate` Turn 0).
3. `task_list` match is necessary but not sufficient (a workstream can span multiple proposals): further keep only devlogs whose body names this proposal's path explicitly (the Turn 0 Brief cites `<proposal_path>`).
4. If multiple devlogs remain, take the most recently dated one (filename date, tie-broken by `first_authored.at`).
5. If none remain, fall back to the existing blind `last_reviewed`-based heuristics unchanged: for the no-devlog path this refinement is additive and degrades gracefully for proposals with no iterate history. (The accept path is not merely additive: it introduces a new recommendation output value, `[STATUS] implementation_accepted`, that the blind table never produces; see the mapping table below.)
6. Otherwise, read the matched devlog's Iteration Log and Judge Log tables and take the **last row of each**, keying every field off its column *header name*, never a fixed column position (the Iteration Log schema drifts across devlog vintages; see Phase 1).

**How log state maps to frontmatter recommendations.** These rules are checked before the existing "Check workflow state" table and, when a matching devlog exists, take precedence over it:

| Log state (last row of each table) | Recommendation |
|---|---|
| Iteration Log last row `review_verdict: accept`, proposal not yet `implementation_accepted` | `[STATUS] implementation_accepted`. An `/cdocs:iterate` Accept is an *implementation* Accept, whose terminal status is `implementation_accepted` (`iterate/SKILL.md` Turn N.c Accept branch, line 92: "update proposal frontmatter per `/cdocs:implement` conventions"), not the design-review `implementation_ready` the blind accepted-mapping emits (`triage.md` line 60). This is a NEW recommendation value the blind table never produces. |
| Iteration Log last row `review_verdict: accept`, proposal already `implementation_accepted` | `[NONE]` — no transition. Cross-check against `last_reviewed.status` and flag a mismatch in the report ONLY if `last_reviewed.status` was never updated post-Accept. |
| Iteration Log last row `review_verdict: reject` | `[ESCALATE]`, mirroring the loop's own "Reject pre-empts judge" rule; do not wait for `round >= 3`. |
| Judge Log last row `verdict: escalate` (and no later Iteration Log row superseding it) | `[ESCALATE]`, regardless of round count; surface the judge's rationale (inline text or `judge_path`) verbatim in the triage report. |
| Judge Log last row `verdict: rotate-implementer`, or Iteration Log last row `review_verdict: revise` with no Judge Log row yet | `[NONE]` — the loop is still open and owns this document; note "in-flight iterate loop, devlog: `<path>`" in the report so a human reading the triage output understands why no action was recommended. |
| No matching devlog found | Fall back to the existing blind heuristics (`triage.md` lines 56-63), unchanged. |

The rationale for `[NONE]` on an open loop is the same fresh-subagent discipline the loop itself is built on: triage dispatching an ad hoc `[REVIEW]` or acting on a `[REVISE]` recommendation against a document an active iterate loop already owns would create a second, uncoordinated reviewer outside the loop's protocol, exactly the kind of silent-relocation failure the predecessor proposal closed for empirical verification.

**Output format.** The triage agent's report gains an `ITERATE LOOP STATE:` block (empty/omitted when no matching devlog is found) naming the devlog path and the last row of each table, so the report stays auditable even when the only recommendation is `[NONE]`.

### B. Mid-loop user participation controls

**Injection points.** The overseer already pauses between turns (it dispatches one subagent, waits for it to report, then decides).
These existing pauses are the only injection points; no new interrupt handling is introduced.
The concrete point where the overseer consults the Steering Log is **Turn N.c (Decide)** — its own reasoning turn between Review and the next dispatch (`iterate/SKILL.md` Turn N.c), where it already reads the verdict and branches.
Concretely: after Turn N.b (Review) resolves, the overseer at Turn N.c (Decide) consults the Steering Log before the next dispatch (Turn (N+1).a, or Turn N.d if the judge threshold fired); and after Turn N.d (Judge) resolves it consults again before Turn (N+1).a — this is the post-judge dispatch boundary, not a second Decide (N.c) turn, since the judge verdict branches directly to the next dispatch with no named Decide turn after it.
A user message that arrives while a subagent is actively dispatched (mid Task call) is **queued**, not injected: the overseer never interrupts or reinjects into an in-flight subagent, since that would breach the same freshness/isolation invariant the reviewer and judge are built on.
The queued message is applied at the next injection point instead.

**The Steering Log.** A new devlog table — the *fourth*, alongside the three that already exist (Iteration Log, Judge Log, and Dispatch/Return Events; `iterate/SKILL.md` line 131) — copied from `template.md` on Turn 0 like the existing three:

```
## Steering Log

| at | kind | target | content | applied_at_iteration |
|---|---|---|---|---|
```

- `at`: timestamp the directive was received.
- `kind`: one of `steer-implementer`, `steer-reviewer-floor`, `pause`, `resume`, `override-judge`.
- `target`: which future actor/turn it applies to (e.g. `impl-2`, `rev-3`, `judge-escalate@i4`).
- `content`: the actual instruction, floor text, or override rationale, free text.
- `applied_at_iteration`: the iteration number where the overseer folded it into a dispatch prompt, or `pending` while queued, or `n/a` for a `pause`/`resume` marker row.

The overseer appends a row the moment it notices the directive (even if application is deferred), and updates `applied_at_iteration` when it actually folds the content into a dispatch.
This mirrors the Iteration Log's own durable-resumption-point role: a fresh overseer resuming a paused loop reads the Steering Log to recover any pending, not-yet-applied directives.

**Steer implementer / steer reviewer-floor.** At the next injection point, the overseer includes the `content` of any `pending` `steer-implementer` row verbatim in the next implementer's dispatch prompt (as additional Brief context, not a rewrite of the proposal), and any `pending` `steer-reviewer-floor` row replaces the active verification floor for the next Review turn onward.
Prior Iteration Log rows keep their already-recorded `review_proof` value: per the history-agnostic writing convention, a floor change does not retroactively invalidate past `confirmed` rows.

**Pause / resume.** `pause` is not a fourth loop-terminal verdict; it does not touch the Accept/Reject/Escalate taxonomy.
On a queued `pause` directive, the overseer finishes the turn currently in flight (writes its Iteration Log or Judge Log row exactly as it would have anyway), then writes a closing devlog note naming the resumption point (e.g. "Turn 4.a, impl-2 continues") and stops without invoking Accept, Reject, or the judge.
This extends the existing convention ("write a final row before yielding so an interrupted loop never leaves the log half-populated") from crash-driven interruption to deliberate interruption; no new mechanism, just an explicit trigger for the mechanism that already exists.
`resume` (possibly in a fresh overseer session) re-reads the devlog's Iteration Log, Judge Log, and Steering Log, reconstructs the resumption point named in the closing note, and continues from there.

**Override judge escalation.** An `override-judge` Steering Log row lets a human explicitly instruct the overseer to continue past a judge `escalate` verdict.
The Judge Log row itself is never edited: the judge's actual assessment must remain a legible, honest record even when overridden, matching cdocs's general no-history-erasure posture.
The next Iteration Log row's `notes` column cross-references the override (e.g. `[user-override: see Steering Log <at>]`) so the audit trail shows a human, not the judge, authorized continuation.

## Out of Scope

- **Judge trigger cadence** ([`overseer-consolidation.md`](2026-09-01-overseer-consolidation.md) §B item 8): already handled by `--judge-after N` (default 3) plus overseer discretion plus Reject-preempts-judge; no gap to close.
- **Implementer structured-return schema** ([`overseer-consolidation.md`](2026-09-01-overseer-consolidation.md) §B item 9): rejected as overkill; the devlog (Iteration Log row plus the implementer's own summary) already carries that record, and a named-header contract would be machinery for legibility the freeform report already provides.

## Important Design Decisions

### Triage precedence: additive for the no-devlog path, a new output value on the accept path

The log-state mapping only activates when a matching devlog is found; every proposal with no iterate history behaves exactly as `triage.md` already specifies, so the change cannot regress triage's behavior on the majority of documents that were never run through `/cdocs:iterate`.
The accept path is the one place the change is not purely additive: it emits `[STATUS] implementation_accepted`, a recommendation value the blind workflow-state table (`triage.md` lines 56-63) never produces.
An iterate-loop Accept means the *implementation* was accepted, whose terminal status is `implementation_accepted`, not the design-review `implementation_ready` the blind accepted-mapping (`triage.md` line 60) emits; deferring to that blind mapping would recommend the wrong status.
The new value is scoped to the matched-devlog path, so it still cannot regress the no-devlog majority.

Because `triage.md` carries a single `model:` field, the bump runs *all* triage on sonnet — including pure-mechanical frontmatter fan-out with no iterate history, not just the iterate-aware path; this is the accepted tradeoff of choosing the model bump over splitting the skill.

### `task_list` match plus explicit path citation, not `task_list` match alone

A workstream (`task_list`) can span multiple proposals (this very workstream, `cdocs/iterate-skill`, already does).
Matching on `task_list` alone risks pairing a proposal with a devlog for a *different* proposal in the same workstream.
Requiring the devlog body to cite this proposal's path (already a Turn 0 requirement: "State scope... explicitly") costs nothing extra to check and removes the ambiguity.

### A new Steering Log table, not a `notes`-column tag on the Iteration Log

The predecessor proposal chose a notes-tag (`[indep-verify: ...]`) over a new column for verification proof, reasoning that the tag rides an existing once-per-iteration row.
Steering directives are not once-per-iteration: they arrive at arbitrary times (including mid-turn, when queued) and some (`pause`, `resume`) have no natural Iteration Log row to ride on at all.
A separate table with its own cadence and a distinct `## Steering Log` heading keeps the concern grep-able independently and avoids overloading a row that may not exist yet when the directive arrives.

### Pause is not a verdict

The predecessor proposal explicitly listed "the verdict taxonomy (Accept / Revise / Reject)" as unchanged, and this proposal preserves that.
Pause suspends turn *advancement*; it makes no claim about the work's quality.
Folding it into the verdict taxonomy would conflate "the loop should stop because a human stepped away" with "the loop should stop because the work is done or broken," which are orthogonal.

### Override-judge never rewrites the Judge Log row

Editing the judge's row to reflect the override would erase the fact that a fresh, context-limited meta-reviewer said "escalate" and a human overrode it.
That fact is exactly the kind of information a future auditor (or a future judge, reading the Judge Log for a rotate/escalate pattern) needs.
The override is recorded as a new, additive Steering Log row plus an Iteration Log cross-reference, never as a mutation of the original verdict.

### No new interrupt machinery

The overseer already has natural pause points between subagent dispatches.
Building a separate signaling channel (a lock file, a poll loop, a `--pause-after N` flag as originally speculated in the open-questions memo) would duplicate control flow the overseer's own turn structure already provides.
The `--pause-after N`-style flag from the open-questions memo is deliberately not adopted: it's a scheduled pause, whereas the actual ask (a human injecting direction reactively) is served by the existing turn boundaries plus the Steering Log convention.

## Edge Cases / Challenging Scenarios

### Triage: multiple candidate devlogs share the same date

If two devlogs matching `task_list` and citing the same proposal path share a filename date (rare but possible with multiple sessions on the same day), tie-break on `first_authored.at` (most recent wins); if that also ties, the triage report flags the ambiguity and recommends `[NONE]` rather than guessing.

### Triage: devlog exists but has an empty Iteration Log (Turn 0 only, loop never actually started)

Treat as "no matching devlog" for the purposes of the mapping table (fall back to blind heuristics); an empty Iteration Log carries no verdict to key off.

### Steering: directive targets an implementer that the judge is about to rotate out

A `steer-implementer` row queued just before a judge `rotate-implementer` verdict becomes stale for the outgoing implementer.
The overseer re-targets it to the incoming fresh implementer at application time (updating `target`), since the directive's intent (steer the *next* work, not a specific handle) survives the rotation; this is noted inline when it happens.

### Steering: user pauses mid-way through a queued directive that was never applied

The closing note on `pause` must include not just the resumption Turn but a pointer to any `pending` Steering Log rows, so `resume` does not silently drop them.
This is captured by `resume` re-reading the full Steering Log, not just the closing note; the closing note is a convenience summary, not the source of truth.

### Steering: user attempts to override an Accept or Reject verdict

Out of scope for this proposal: Accept and Reject are Decide-turn verdicts the overseer already acts on directly (loop termination), not judge escalations.
Overriding a terminal verdict is a "reopen a closed loop" operation, materially different from overriding an in-progress judge assessment, and is not designed here; flagged as future work if a concrete need arises.

### Steering: verification floor changed mid-loop, but a `deferred-to-followup` pointer from before the change now targets stale context

The `steer-reviewer-floor` directive changes the floor going forward only; a pre-existing `deferred-to-followup` pointer keeps pointing at whatever follow-up devlog it named.
If the floor change makes that follow-up's scope stale, that is a manual judgment call for whoever resolves the pointer, same as any other `deferred-to-followup` resolution today.

## Test Plan

### Phase A (triage)

- **Dry-run against real history**: run the updated triage analysis (read-only rehearsal, no edits) against this repo's own `2026-05-18-iterate-agent-capabilities-implementation.md` devlog and its proposal, and against `2026-05-13-iterate-skill-implementation.md` and its proposal.
  Both target proposals already carry `status: implementation_accepted`, and both cited devlogs end their Iteration Log on an `accept` row, so the correct recommendation is `[NONE]` (already-accepted branch) with no false mismatch flag, keyed off the log's `accept` row rather than `last_reviewed.round`.
- **Synthetic accept-transition fixture**: construct a throwaway devlog (in the scratch directory, not committed) whose Iteration Log ends on an `accept` row, paired with a synthetic proposal still at `status: implementation_ready`.
  Confirm the mapping recommends `[STATUS] implementation_accepted` (the new output value), not the blind mapping's `[STATUS] implementation_ready`.
- **Synthetic escalate fixture**: construct a throwaway devlog (in the scratch directory, not committed) with an Iteration Log ending in a `revise` row at round 2 and a Judge Log ending in an `escalate` row.
  Confirm the mapping recommends `[ESCALATE]` despite `round < 3`, which the current blind heuristic would miss.
- **Synthetic in-flight fixture**: construct a throwaway devlog with an Iteration Log ending in `revise` and no Judge Log row.
  Confirm the mapping recommends `[NONE]`, not `[REVIEW]`/`[REVISE]`.

### Phase B (steering)

This is a live-loop-interaction feature; a genuine test requires actually running `/cdocs:iterate` and sending mid-loop input, which cannot execute inside this proposal's own review loop for the same reason the predecessor proposal deferred its smoke test (`/cdocs:iterate` cannot be dispatched from inside a subagent).

- **Table-top walkthrough** (executable as part of this proposal's own review): trace one synthetic pause+resume and one synthetic override-judge sequence against the Steering Log schema on paper/in a scratch devlog, confirming every column is populated correctly and no Judge Log row is mutated.
- **Live smoke test** (deferred, separate top-level invocation): run `/cdocs:iterate` on a small real proposal; mid-loop, send a `steer-implementer` directive and confirm it appears in the next implementer's dispatch prompt; send a `pause` directive and confirm the loop stops cleanly with a resumable closing note; `resume` in a fresh session and confirm continuation from the correct turn.

## Verification Methodology

Phase A is verified by direct inspection of the updated `triage.md` table plus the dry-run and synthetic fixtures above (the mapping is deterministic table lookups over header-keyed log rows, statically inspectable against the example devlogs).
Static inspection alone is insufficient here: a `subagent_type: "triage"` dispatch against the dry-run targets and the synthetic fixtures is a REQUIRED success gate, not optional, because the multi-step glob/filter/parse/map is exactly the kind of work a mechanical-tier agent can get subtly wrong even when the written instructions are internally consistent. The dispatch confirms the *agent* — at its bumped tier — actually follows the updated instructions and produces the documented recommendations (`[NONE]` for the two already-accepted targets with no false mismatch flag; `[STATUS] implementation_accepted` for the synthetic still-`implementation_ready` fixture; `[ESCALATE]` for the synthetic escalate fixture; `[NONE]` for the synthetic in-flight fixture).

Phase B's structural correctness (schema, injection-point rules, non-mutation of Judge Log rows) is verified by inspection and the table-top walkthrough.
Its behavioral correctness (the overseer actually applies a queued directive at the right turn, actually stops cleanly on pause) can only be verified by the deferred live smoke test.

> NOTE(sonnet-5/cdocs/iterate-refinements): Per the predecessor's precedent, this proposal's own implementation devlog should tag the Phase B live-loop verification row `deferred-to-followup` with a pointer to the smoke-test devlog, for the same self-referential reason: `/cdocs:iterate` cannot verify a change to its own loop protocol from inside that loop.

## Implementation Phases

### Phase 1: Triage reads Iteration/Judge Logs

Files: [`plugins/cdocs/agents/triage.md`](../../plugins/cdocs/agents/triage.md), [`plugins/cdocs/skills/triage/SKILL.md`](../../plugins/cdocs/skills/triage/SKILL.md), [`plugins/cdocs/rules/model-tiering.md`](../../plugins/cdocs/rules/model-tiering.md) (reconcile the triage tier mention with the model bump).

- Add the devlog-location analysis step (glob by `task_list`, filter to `## Iteration Log` presence, filter to explicit path citation, pick most recent) before "Check workflow state" in `triage.md`.
- Add the log-state → recommendation mapping table to `triage.md`, documented as taking precedence over the existing blind heuristics when a matching devlog exists; the accept path emits `[STATUS] implementation_accepted` (or `[NONE]` when already accepted) per Proposed Solution §A, a recommendation value the current table does not have.
- Parse the last row of each table by column *header name*, not by fixed position. The Iteration Log schema drifts across devlog vintages: `2026-05-13-iterate-skill-implementation.md` has `iteration | implementer | reviewer | review_verdict | review_path | notes` (no `review_proof`, no `overseer_ctx_est`/`inline_work` thinness columns); `2026-05-18-iterate-agent-capabilities-implementation.md` adds `review_proof` but still lacks the two thinness columns; the current `template.md` carries all nine. The mapping only needs `review_verdict` (and the Judge Log's `verdict`), but positional indexing would misread the older logs, so `triage.md` must instruct locating the field by header.
- Bump the triage agent's model tier so the multi-step glob/filter/parse/map is not asked of the haiku floor. The base mechanical-fix workload keeps triage at the `model: haiku` Mechanical/Deterministic Fan-Out tier (`model-tiering.md`), but the iterate-aware step (glob `cdocs/devlogs/*.md`, filter by frontmatter, filter by body citation, tie-break, then parse two header-keyed markdown tables and apply a precedence mapping) is parse/reasoning work that sits in the Search/Explore tier. Since `triage.md` declares a single `model:` frontmatter field (`triage.md` line 3, currently `model: haiku`), raise it to `model: sonnet`; and reword `model-tiering.md` line 28 — which today names both `nit-fix` and `triage` as canonical `model: haiku` Mechanical cases — so `nit-fix` remains the canonical haiku example while triage's bump to sonnet (for the iterate-aware glob/filter/parse/map, Search/Explore tier) is explained, leaving the file free of the contradiction that triage is both haiku and sonnet.
- Add the `ITERATE LOOP STATE:` block to the agent's Output Format.
- Cross-reference the new step from `skills/triage/SKILL.md`'s Behavior section so the dispatcher's expectations match the agent's actual steps.

**Success criteria**: dry-run and synthetic-fixture cases from Test Plan Phase A produce the documented recommendations (including `[NONE]` for the two already-accepted dry-run targets and `[STATUS] implementation_accepted` for the synthetic still-`implementation_ready` fixture); proposals with no iterate history are unaffected (spot-check one); the required `subagent_type: "triage"` fixture dispatch (see Verification Methodology) passes against the fixtures.

### Phase 2: Steering Log convention and injection points

Files: [`plugins/cdocs/skills/iterate/SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md), [`plugins/cdocs/skills/iterate/template.md`](../../plugins/cdocs/skills/iterate/template.md).

- Add the `## Steering Log` table to `template.md`, with column semantics matching Proposed Solution item B.
- Add an "Injection points" subsection to `SKILL.md` (near "Iteration Log and Judge Log" or "Termination"): the turn-boundary rule naming Turn N.c (Decide) as the point the overseer consults the Steering Log, the queue-don't-interrupt rule for mid-dispatch messages, and the five `kind` values with their handling (steer-implementer, steer-reviewer-floor, pause, resume, override-judge).
- Extend "Termination" to state explicitly that `pause` is not a fourth verdict and does not invoke Accept/Reject/judge logic.
- Update the Turn 0 devlog-scaffolding instruction (`SKILL.md` line 69, which currently names only "Iteration Log and empty Judge Log") to copy the Steering Log alongside the existing three tables, and reconcile the table count in the "Iteration Log and Judge Log" section (`SKILL.md` line 131, currently "Three tables") to *four*. These two lines currently disagree on the count (line 69 implies two, line 131 says three); both must be brought to four so the scaffolding instruction and the table inventory agree.
- Fold Steering-Log pending-directive recovery into the existing On-Resume Reconciliation section of `iterate/SKILL.md` (lines 121-127), which today reconstructs liveness only from the Dispatch/Return Events rows. That section is the single source of truth for resume, so the resume behavior asserted in Proposed Solution §B ("a fresh overseer resuming a paused loop reads the Steering Log to recover any pending, not-yet-applied directives") must be codified there — a fresh overseer re-reads the Steering Log for rows whose `applied_at_iteration` is `pending` and re-queues them — rather than living only in prose the reconciliation section would otherwise contradict. Do NOT add a separate resume subsection.

**Success criteria**: Test Plan Phase B's table-top walkthrough traces cleanly against the documented schema; grep for `## Steering Log` finds it in both `SKILL.md`'s references and `template.md`; the Turn 0 scaffolding instruction, the "Iteration Log and Judge Log" table count, and the On-Resume Reconciliation section all reflect the four-table inventory and the pending-directive recovery.

### Verification: Live smoke test (deferred, separate top-level invocation; not a commit)

Run `/cdocs:iterate` on a small real proposal; exercise `steer-implementer`, `pause`, and `resume` as described in Test Plan Phase B.
The resulting devlog becomes the pointer target for this proposal's own `deferred-to-followup` tag.
