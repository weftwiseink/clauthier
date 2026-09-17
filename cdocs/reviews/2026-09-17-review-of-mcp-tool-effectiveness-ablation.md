---
review_of: cdocs/proposals/2026-09-17-mcp-tool-effectiveness-ablation.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-17T18:05:00-08:00
task_list: cdocs/mcp-ablation
type: review
state: live
status: done
tags: [fresh_agent, architecture, test_plan, verification, honesty_taxonomy, orchestration, missing_validation]
---

# Review: MCP-tool effectiveness ablation harness

## Summary Assessment

The proposal specs a `/cdocs:ablate` harness that runs one pinned task twice from byte-identical fresh worktrees, once with a target MCP tool and once without, meters each arm from the harness result payload, and has an opus evaluator emit a scorecard, voiding the run if the assisted arm never actually invoked the tool.
The spec is rigorous, honest about its confounds, and well-structured: reset safety (D1) correctly designs AROUND the shared-stash hazard, metering (D2) rests on the confirmed `subagent_tokens`/`duration_ms` payload with per-arm attribution derived from the orchestrator's view (not a child reading its own count), the VOID/VALID/TASK-FAIL taxonomy is applied consistently, and the phasing carries per-phase criteria, dependencies, and what-not-to-change constraints.
The most important gaps are two: (1) the single-shot-versus-gate admissibility question is flagged but not DECIDED, and the machine-consumed `scorecard.json` carries no guard against a downstream gate silently consuming a one-draw scorecard as a pass/fail verdict; and (2) the tool-invocation detection source is internally contradictory (transcript versus result payload) and the "used" definition is not crisp enough to make VOID-versus-VALID deterministic, while the capabilities the whole harness rests on (per-subagent MCP gating, per-tool-call visibility) are asserted rather than named as preconditions to de-risk.
Verdict: **Revise**. The direction is settled and sound and most of the spec meets the buildable bar; the blocking items are concrete and cheap to close.

## Section-by-Section Findings

### BLUF, Summary, Objective, Background
Non-blocking. BLUF is 467 characters (under the ~500 bar), no em-dashes, no emojis, history-agnostic framing with the superseded proposal referenced only in Background and NOTE callouts (the allowed exception).
Confirmed the salvage claim: the superseded [`target-setup-validation-and-verification.md`](../proposals/2026-09-17-target-setup-validation-and-verification.md) is now `status: evolved` (line 8) with the pointer NOTE (line 19) naming this proposal and the salvaged PASS/ABSENT/FAIL taxonomy and lace facts. The frontmatter housekeeping the maintainer asked me to confirm is done correctly.
The Background's scoping discipline ("this owns the ablation method, graphify owns graphify") is clean and prevents re-litigating the accepted graphify proposal.

### Metering (D2) and per-arm attribution
Non-blocking, verified sound. The orchestrator meters each arm from THAT arm's completion payload after it returns; nothing asks a child to read its own token count mid-rollout, which it generally cannot.
Because an arm is a dispatched leaf subagent that cannot itself dispatch workers, `subagent_tokens` cleanly attributes the arm's full rollout to that arm. The evaluator is metered separately and correctly excluded from the arms' comparison. This axis is the strongest part of the spec.

### Reset safety (D1)
Mostly strong; two non-blocking specification gaps.
D1 correctly designs around the load-bearing environment fact: in the bare-repo-plus-sibling-worktrees layout the stash stack is SHARED, so a bare `git stash` could clobber a concurrent session. Fresh worktree per arm off a pinned commit sidesteps the stash entirely and gives genuine cross-arm filesystem isolation. This is the right design and the rejected alternatives are correctly rejected.
Gaps:
- **Teardown of a dirty tree.** Each arm produces a diff, so its worktree is dirty at teardown; `git worktree remove` REFUSES a dirty worktree without `--force`. The spec says teardown is `git worktree remove` but not that it must capture the diff first and then force-remove (or commit-then-remove). Specify the ordering and the `--force`.
- **Worktree location and arm binding.** The spec does not say WHERE the fresh worktrees live (a scratchpad/throwaway path versus polluting the sibling-worktree namespace) nor HOW a dispatched arm subagent is bound to its pre-created worktree as its cwd. One sentence each would close it.
- **Dirty-base semantics.** Arms check out the pinned COMMIT, so uncommitted work in the invoking worktree is not part of the ablation. That is correct behavior, but it sits in mild tension with "refuse on a dirty base" and could surprise a caller who expected their WIP tested. State that the ablation tests the committed base and reconcile the refuse-on-dirty rule with it.

### The usage precondition and tool-invocation detection (D-honesty core)
**Blocking.** The VOID/VALID gate is the honesty spine of the whole proposal, and its detection mechanism is currently underspecified in two ways:
- **Contradictory source.** Line 106 says invocation "is confirmed from the assisted arm's transcript, by detecting a real tool-call to the named MCP tool (tool-call boundaries are visible in the result payload)." The transcript (full message JSONL with `tool_use` blocks) and the compact result payload are DIFFERENT artifacts. The confirmed harness fields are `subagent_tokens` and `duration_ms` only; per-tool-call boundary visibility in the result payload is asserted, not confirmed. Commit to the full transcript's `tool_use` blocks as the detection source (they reliably carry the tool name), not the result payload.
- **"Used" is not crisply defined.** For VOID-versus-VALID to be deterministic, define "invoked" precisely: e.g. at least one `tool_use` to the target tool id in the assisted arm's transcript counts, including a call that RETURNED AN ERROR (the treatment still occurred), and decide the aborted/cut-off-rollout case explicitly rather than leaving it to the evaluator. The proposal raises the nested/aborted question in Investigation Requested but must DECIDE it in the spec.

### Fair construction (D4) and load-bearing capability assumptions
**Blocking (name the assumptions).** D4's grant/withhold mechanism assumes the dispatch layer can include exactly one named MCP tool in the assisted arm's tool set and exclude it from the unassisted arm's while holding everything else identical. This is the foundational feasibility assumption: if per-subagent MCP-tool gating of a single named tool is not supported, the ablation is impossible. Per-agent tool restriction clearly exists, so this is plausible, but it and the tool-call-visibility assumption above are the two runtime capabilities the entire harness rests on and neither is confirmed.
Add both as explicit Phase 1 preconditions to validate first (a small spike), each with a fallback: for detection, a sentinel marker the assisted arm emits after tool use if the transcript does not expose tool ids; for gating, an alternative grant mechanism if a single-tool withhold is not directly expressible. This converts two silent assumptions into named, de-risked preconditions.

### Variance, path-divergence, and the primary axis (D3, Edge Cases)
**Blocking-adjacent, classed as must-fix framing.** The spec is honest that nondeterministic path divergence can dominate the token delta, and it mitigates with the evaluator's divergence flag plus N-trials median-plus-spread. That posture is acceptable for v1. The problem is a conflation: D2 and the scorecard call token usage "the stable, primary axis," but "stable" there means low METERING noise, not low CAUSAL-ATTRIBUTION noise. The token delta is a JOINT measure of tool-effect plus path-variance and does not decompose them; the axis that actually attributes causation to the tool is the evaluator's context-gap judgment. Reframe so the context-gap is the primary CAUSAL axis and the token delta is a corroborating magnitude, not the primary evidence of tool value. This is a small wording change with real honesty payoff and resolves Investigation-Requested item 2's direction (N-trials plus divergence-flag is sufficient for an indicative read; a more constrained/narrow task is the lever for a cleaner attribution, and representative-task selection is already an open question).

### Single-shot admissibility (D3, D7, Verification)
**Blocking.** Phases 1 and 2 ship a single-shot scorecard; D7 says "the structured sidecar lets a downstream gate (e.g. graphify's) consume the verdict programmatically." The loud noise caveat lives in `scorecard.md` (human-readable), but the machine-consumed `scorecard.json` carries no field distinguishing a single-shot draw from an N-trials estimate and no admissibility guard. A downstream gate reading `scorecard.json` could therefore silently treat one noisy A/B pair as a pass/fail verdict, which is exactly the hazard the honesty stance exists to prevent.
Decide Investigation-Requested item 4 in the spec: a single-shot scorecard is INDICATIVE-ONLY and MUST NOT be consumed as a gate verdict. Enforce it structurally by adding to `scorecard.json` an explicit `trials` count and a `gate_admissible` (or `indicative_only`) boolean, set false for single-shot, so the guard rides on the machine-consumed artifact and not only in prose.

### Evaluator and blinding (D5)
Non-blocking; honest ceiling, with one caveat. D5 is refreshingly honest that full blinding is impossible and discloses the residual bias in the scorecard. That is the right posture and does not overclaim (Investigation-Requested item 3 is an honest ceiling as stated).
Caveat worth stating: the "per-arm read before arm identity is revealed" protocol gives only weak protection because the discriminating feature (the tool calls) is IN the transcript the evaluator reads, so the evaluator can trivially infer which arm is assisted. The protocol is close to ceremonial; the real lever (a transcript-scrubbing pass) is correctly deferred. Just acknowledge the protocol's limited value rather than presenting it as meaningful blinding.
Minor: two full transcripts plus two diffs plus two meters is a large evaluator context; note a bounded-task or summarization posture so the evaluator input stays tractable.

### Packaging and thinness (D6)
Non-blocking, well-aligned. The thin-overseer framing is correct: the skill pins, dispatches the two arms and the evaluator as subagents, and assembles the scorecard without doing an arm's work inline, and it explicitly calls out that inline work would both violate thinness AND contaminate the ablation with the overseer's own tokens. That second reason is exactly right and matches `orchestration-discipline.md`. The helper-script/subagent split (mechanics in the script, judgment in subagents) is sound.

### Test Plan, Verification Methodology, Phases
Non-blocking; complete and well-formed. The Test Plan covers reset isolation, metering source, the three-fixture usage precondition, fair construction, task-fail handling, the evaluator rubric, trials, and the scorecard artifact. The dogfood-on-graphify is present and correctly scoped by the NOTE as a coherence check on the instrument, not a verdict on graphify. Phases carry explicit Depends/Blocks and per-phase what-not-to-change constraints. The one thing the phases should absorb is the Phase 1 capability spike from the D4 finding above.

### Cross-target degradation
Non-blocking but thinner than sibling docs. Both `orchestration-discipline.md` and `model-tiering.md` carry real Cross-Target Degradation sections; this proposal defers OpenCode entirely to an Open Question ("payload shape, worktree dispatch ... unspecified here"). Deferring is more honest than hand-waving a degradation story for a deeply CC-runtime-coupled harness, so this is acceptable. Strengthen it slightly by stating the POSTURE rather than leaving it fully open: CC-only for v1, OC support gated on an equivalent per-subagent token/duration payload and worktree dispatch, and `/cdocs:ablate` unsupported (not silently degraded) on OC until then.

## Verdict

**Revise.** The direction is settled and the spec is largely buildable, honest about its confounds, and well-structured. Three blocking items must land before acceptance: the single-shot gate-admissibility guard on the structured scorecard, the tool-invocation detection source and crisp "used" definition, and naming the two load-bearing harness-capability assumptions as de-risked Phase 1 preconditions. The remaining items are non-blocking tightenings. None of the blockers challenge the approach; all are cheap.

## Action Items

1. [blocking] Decide single-shot admissibility in the spec: state that a single-shot scorecard is indicative-only and must never be consumed as a downstream gate verdict, and enforce it structurally by adding `trials` and `gate_admissible`/`indicative_only` fields to `scorecard.json` so the guard rides on the machine-consumed artifact, not only in `scorecard.md` prose. (Investigation item 4.)
2. [blocking] Fix the tool-invocation detection source: commit to the assisted arm's full transcript `tool_use` blocks (not the compact result payload) and reconcile line 106's contradiction. Define "invoked" crisply and deterministically: at least one `tool_use` to the target tool id, error-returning calls count, and decide the aborted/cut-off-rollout case in the spec. (Investigation item 1.)
3. [blocking] Name the two load-bearing capability assumptions as explicit Phase 1 preconditions with fallbacks: (a) per-subagent gating that can withhold exactly one named MCP tool while holding all else identical (D4), and (b) per-tool-call visibility in the transcript (item 2). Each needs a stated fallback (sentinel marker for detection; alternative grant path for gating).
4. [non-blocking] Reframe the primary axis: distinguish metering-stability from causal-attribution. Make the evaluator context-gap the primary CAUSAL axis and the token delta a corroborating joint tool-plus-path magnitude, not the primary evidence of tool value. (Investigation item 2.)
5. [non-blocking] Specify worktree teardown precisely: capture the diff, then `git worktree remove --force` (arms leave dirty trees); state where the worktrees live and how a dispatched arm is bound to its pre-created worktree as cwd.
6. [non-blocking] Clarify dirty-base semantics: the ablation tests the committed base, so the invoking worktree's uncommitted work is excluded; reconcile with the refuse-on-dirty-base rule.
7. [non-blocking] Acknowledge the blinding protocol's limited value (the transcript reveals the tool calls, so per-arm-read-before-reveal is near-ceremonial) rather than presenting it as meaningful blinding; keep the transcript-scrub lever deferred. (Investigation item 3, confirmed honest ceiling.)
8. [non-blocking] State the cross-target POSTURE: CC-only v1, OC gated on an equivalent payload and worktree dispatch, unsupported (not silently degraded) until then.
9. [non-blocking] Note the evaluator's input size (two full transcripts plus diffs) and a bounded-task or summarization posture to keep the evaluator context tractable.

## Clarifications For The Proposer (multiple choice)

These steer the revision; pick per item.

**A. Single-shot as a gate.** How should a single-shot scorecard relate to a downstream gate (graphify's)?
  1. Never gate-admissible: `gate_admissible: false` always for `trials == 1`; only N-trials runs may be consumed as a gate. (Reviewer-preferred, strongest honesty.)
  2. Gate-admissible only with an explicit caller override that acknowledges the one-draw caveat.
  3. Gate-admissible with the caveat surfaced; caller's risk.

**B. "Used" definition for the VOID gate.** What counts as the tool being invoked?
  1. Any `tool_use` to the target tool id, success OR error, counts; an aborted rollout with a completed call still counts. (Reviewer-preferred, most deterministic.)
  2. Only a call that RETURNED (no error) counts.
  3. Any call counts, but an aborted rollout is its own outcome (ABORTED, distinct from VOID and TASK-FAIL).

**C. Cross-target.** How to treat OpenCode in this proposal?
  1. State CC-only v1 posture with an explicit unsupported-on-OC stance and the gating conditions. (Reviewer-preferred.)
  2. Leave fully deferred as an Open Question (status quo).
  3. Add a full Cross-Target Degradation section now.
