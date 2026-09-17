---
review_of: cdocs/proposals/2026-09-17-mcp-tool-effectiveness-ablation.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-17T19:10:00-08:00
task_list: cdocs/mcp-ablation
type: review
state: live
status: done
tags: [fresh_agent, rereview_agent, architecture, honesty_taxonomy, verification, orchestration, gate_admissibility]
---

# Review (round 2): MCP-tool effectiveness ablation harness

## Summary Assessment

Round 1 affirmed the architecture and returned Revise on three concrete, cheap blocking items plus a set of tightenings.
This round verifies the revision against those items rather than re-litigating the design.
All three blocking items are genuinely closed, not papered over: the single-shot admissibility guard now rides on the machine-consumed `scorecard.json` via `trials` and `gate_admissible` with a stated refuse-rule (D7); tool-invocation detection commits unambiguously to the assisted arm's full-transcript `tool_use` blocks with a deterministic "invoked" definition and an explicit VOID-over-TASK-FAIL abort precedence (usage precondition); and the two load-bearing runtime capabilities are named as Phase 1 preconditions, each with a fallback and a halt-if-infeasible gate.
Every non-blocking tightening was also folded (worktree teardown/location/cwd, dirty-base semantics, near-ceremonial blinding, CC-only-v1 posture, evaluator input-size posture, and the primary-causal-axis reframe in the BLUF, D3, D7, and the Metering section).
Verdict: **Accept**. One residual internal inconsistency survives the reframe (D2 line 170 still calls token usage the axis that "drives the verdict"), but it is a localized wording slip contradicted by the dominant framing everywhere else, not a design gap.

## Verification of round-1 blocking items

### 1. Single-shot gate guard on the machine artifact - CLOSED
D7 now specifies `scorecard.json` carrying both `trials` (integer) and `gate_admissible` (boolean) as first-class fields on the structured sidecar, not only in `scorecard.md`.
The rule is stated twice and consistently: `trials == 1` sets `gate_admissible: false` and "only an N-trials run may set it true" (D7), and "A downstream gate MUST check `gate_admissible` and refuse a non-admissible scorecard" (D7).
D3 corroborates without contradiction: a single-shot scorecard "is never admissible as a downstream gate verdict; this is enforced structurally on the machine artifact (D7), not left to prose."
Cross-check against the D7 gate description for a NEW contradiction: D7 still says the sidecar "lets a downstream gate consume the verdict programmatically," and the admissibility guard narrows that (consume, but refuse non-admissible) rather than fighting it. No inconsistency introduced.

### 2. Deterministic invocation detection - CLOSED
The transcript-versus-payload contradiction from round 1 (old line 106) is removed. The usage precondition now states invocation "is detected from the assisted arm's FULL TRANSCRIPT (the message JSONL), by matching a `tool_use` block against the target MCP tool's id/name" and explicitly disclaims the payload: "It is NOT read from the compact result payload: only `subagent_tokens` and `duration_ms` are confirmed there."
"Invoked" is now deterministic: at least one target `tool_use` block counts, "INCLUDING a call that returned an error." Abort precedence is stated rather than delegated to the evaluator: no target `tool_use` present is VOID regardless of why the rollout ended; present-but-incomplete is TASK-FAIL; "VOID (no treatment) always takes precedence over TASK-FAIL."
No residual reference to reading invocation from the result payload remains. The mermaid's "tool-invocation check" label and D2's metering-from-payload language are about metering, not detection, and do not reintroduce the contradiction.
Consistency with the VOID taxonomy elsewhere: the Outcome taxonomy (VALID = both completed and tool used; VOID = unavailable or never invoked; TASK-FAIL = one or both failed) and the Edge Cases align with the precedence rule. No new fight between the invocation rule and the taxonomy.

### 3. De-risked capabilities as Phase 1 preconditions - CLOSED
Phase 1 opens with a capability spike naming both (a) per-subagent single-tool gating (D4) and (b) per-tool-call transcript visibility, each with a concrete fallback (explicit tool-set construction or a tool-omitting profile for (a); a sentinel marker emitted after target-tool use for (b)).
The spike gates the rest of the build: "The arms, evaluator, and trials are not built until BOTH preconditions are validated or their fallbacks are in place," and "If neither a direct nor a fallback path exists for (a), the harness is infeasible and the phase halts with that finding." This satisfies both the naming and the halt-if-infeasible requirements.

## Verification of round-1 nits (all folded)

- **Primary causal axis reframe.** Present in the BLUF ("context-gap judgment is the primary CAUSAL axis; the token delta is a corroborating joint measure ... A verdict never rests on a token or wallclock delta alone"), the Metering section ("It is not the primary evidence of tool value"), D3, and D7's `scorecard.json` field annotations. Folded, with one residual leak noted below.
- **Worktree teardown/location/cwd (D1 Mechanics).** Worktrees live under the harness scratchpad, not as siblings of `main/`; each arm is dispatched with its pre-created worktree as cwd; teardown is ordered (capture diff, then `git worktree remove --force`, with the rationale that a plain remove refuses a dirty tree). Folded.
- **Dirty-base / committed-base semantics (D1).** The arms check out the pinned commit, so the committed base is tested and uncommitted WIP is deliberately excluded; the refuse-on-dirty guard is reconciled as a caller-surprise guard that correctness does not require, with commit-or-`--base` as the resolution. Folded.
- **Near-ceremonial blinding (D5).** The per-arm-read-before-reveal step is explicitly called "close to CEREMONIAL, not meaningful blinding ... retained as a cheap up-front anchor," with the transcript-scrub lever deferred. Folded.
- **CC-only-v1 cross-target posture.** The Open Questions now state CC-only for v1, `/cdocs:ablate` UNSUPPORTED (not silently degraded) on OpenCode, gated on an equivalent per-subagent token/duration payload and worktree dispatch. Folded.
- **Evaluator input size (D5).** A bounded-task or summarization-pre-pass posture is stated so the evaluator context stays tractable. Folded.

## Residual findings (non-blocking)

- **[nit, should-fix] D2 line 170 contradicts the reframe.** D2 still reads "Token usage is the stable axis and drives the verdict." This is the exact metering-stability-versus-causal-attribution conflation the round-1 reframe was meant to remove, and it now fights the BLUF ("A verdict never rests on a token or wallclock delta alone"), the Metering section ("not the primary evidence of tool value"), D3, and D7. It is a localized leftover, not a design gap: the correct framing dominates five other locations and the intent is unambiguous. Reword to something like "Token usage is the low-metering-noise axis and corroborates magnitude; the context-gap judgment drives the verdict." Recommended before implementation so the spec has a single voice on its primary axis.
- **[nit] Investigation Requested opening reads slightly as a changelog.** "The round-1 review blockers are resolved in-spec: ..." references the review round in the document body. The Investigation Requested block is inherently a review-loop channel, so this is defensible, but per history-agnostic framing the preamble could drop the "blockers are resolved" meta-reference and simply state the remaining pressure-test items. Cosmetic.
- **[nit] VOID/TASK-FAIL scorecard.json shape.** The taxonomy says only VALID runs yield a scorecard verdict and a VOID run "yields no verdict and says why," while D7 lists `gate_admissible` and `outcome` as `scorecard.json` fields. It is left implicit whether a VOID/TASK-FAIL run emits a `scorecard.json` at all (presumably with `gate_admissible: false`). Harmless for v1; a one-clause note during implementation would remove the ambiguity.

## Convention and completeness check

- No em-dashes in prose (verified); spaced-hyphen ` - ` and colons used throughout, per convention. CLI flags (`--tool`, `--trials`, `--force`) are not punctuation.
- No emojis. BLUF present and within the length bar. History-agnostic framing holds in the body (the superseded proposal is referenced only in Background and NOTE callouts, the allowed exception), modulo the minor Investigation-Requested preamble noted above.
- Sections complete: BLUF, Summary, Objective, Background, Proposed Solution, D1-D7, Edge Cases, Test Plan, Verification Methodology, Implementation Phases (with per-phase Depends/Blocks and the newly-absorbed Phase 1 capability spike), Investigation Requested, Open Questions, Links.

## Verdict

**Accept.** All three round-1 blocking items are genuinely closed and every non-blocking tightening was folded. The revision introduced no new inconsistency between the `gate_admissible` rule and D7's gate description, nor between the invocation rule and the VOID taxonomy. The single residual (D2 line 170) is a wording slip that should be swept during implementation but does not block acceptance, and the direction was already affirmed in round 1.

## Action Items

1. [non-blocking, should-fix] Reword D2 line 170 so token usage is the low-metering-noise corroborating axis and the context-gap judgment drives the verdict, matching the BLUF/D3/D7 reframe.
2. [non-blocking] Optionally drop the "round-1 review blockers are resolved" preamble from Investigation Requested to keep the body history-agnostic.
3. [non-blocking] During implementation, state whether a VOID/TASK-FAIL run emits `scorecard.json` (with `gate_admissible: false`) or none.
