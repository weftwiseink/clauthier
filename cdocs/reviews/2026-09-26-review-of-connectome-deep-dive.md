---
review_of: cdocs/reports/2026-09-26-connectome-deep-dive.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-26T15:30:00-07:00
task_list: cdocs/connectome-research
type: review
state: live
status: done
tags: [fresh_agent, architecture, source_verified, provenance, lifecycle_accuracy]
---

# Review: Anima Labs' Connectome: architecture deep dive

## Summary Assessment

The report maps Anima Labs' Connectome stack (Chronicle, Membrane, Context Manager, Agent Framework, connectome-host) at pinned commits, describes the per-turn compile lifecycle and fold solver concretely, and assesses transferability to coding agents.
It is unusually rigorous: of roughly 30 `path:line` citations and provenance claims spot-checked against the clones and live sources, nearly all hold, and inference is consistently labeled.
Three factual errors matter for the downstream diagrams and determinism argument: mints are claimed to be temperature-0 (no such setting exists in context-manager), `/checkpoint` is claimed to create a Chronicle branch (it records an in-memory position; `/restore` and `/undo` branch), and background maintenance is drawn as following the turn when it is timer-driven.
Verdict: **Revise** (light): three small, targeted corrections, no structural rework.

## Verification Log

Checked directly against the scratchpad clones (all nine HEADs match the commit table) and live sources.

| Claim | Result |
|---|---|
| Commit table hashes and dates | Exact match, all 9 repos |
| `autobiographical.ts` 11,748 lines; `framework.ts` 14,669; onboarding runbook 566 | Exact |
| ≈270 chunks / 260k tokens, turns 2-4 in 1.7-1.9 s, <2 GB, from 20-21 s / 12-23 GB (`CHANGELOG.md:30-41`) | Exact (0.11.0 entry, kv-unified label-key fix, #105) |
| `compile()` does not await pending compression; "this turn doesn't have the very latest L1" (`context-manager.ts:701-711`) | Exact |
| Injection splice: `system` → `systemInjections`, `beforeUser`/`afterUser` around last `user` as `system_context:<ns>` | Exact (`context-manager.ts:760-820`) |
| Picker steps: solve → commit resolutions → route produced ops → `OverBudgetError` above W×1.02 → emit | Exact (`adaptive-resolution-design.md:436-469`) |
| Recall pair: `Context Manager` asks, `summaryParticipant` (default `'Claude'`) answers, dedup per ancestor, `sourceRelation: 'derived'` | Exact (`autobiographical.ts:8577-8605`, `strategy.ts:1558,1563`) |
| No hindsight in L1 mint | Verified: "There is intentionally NO tail_after_chunk: that would leak future information" (`autobiographical.ts:5668-5670`); merges likewise (`:7388-7390`) |
| No synthetic summarizer header; current (not historical) host prompt used | Verified (`autobiographical.ts:5928-5950`), including the recoloring caveat |
| Turn start order: locus pin → `inference:started` → early typing → tool snapshot → `gatherContext` → MCPL hooks, fail-open | Verified (`framework.ts:8256-8337`, lines offset by ≤5) |
| `MAINTENANCE_TICKS_PER_PASS` loop; drain breaker 8 ticks | Verified (`framework.ts:731,2123-2133,11667-11680`) |
| Chronicle `Record`, `Branch`, `StateStrategy` shapes | Verified; `Record` also carries `encoding` (omitted, harmless) |
| Model-integrity rule, "mildly identity-adjacent", identity call | Verified (`DEPLOYMENTS.md:16-19`, `AGENT-ONBOARDING.md:457-461,323-324`) |
| Credentials never model-visible; "reads as exfiltration to safety classifiers" | Verified (`identity-module.ts:1-27`) |
| Retrieval: ≤5 lessons, conf ≥0.3, `afterUser` (for KV-cache reasons); lessons ±0.1 dynamics | Verified; ARCHITECTURE.md "top 10 … system position" drift confirmed |
| Founders Janus + Antra Tessera, 2025, SF 501(c)(3) | Verified ([/about/story/](https://animalabs.ai/about/story/)) |
| Connectome definition, five components, "months of work and social life", branching quote | Verified ([/connectome/](https://animalabs.ai/connectome/)) |
| Licenses: AF/membrane MIT; CM/chronicle `package.json` MIT with no LICENSE file (GitHub "none"); host neither; issue #146 open | Verified via `gh api` |
| `connectome-ts`, `antra-tess/connectome` 404; chapter2 Artistic-2.0, empty description | Verified |
| Contributor list | Verified (`claude` account present in agent-framework) |
| 30-day commit counts | Consistent within window-boundary noise (membrane 46 since 08-26, 34 since 08-27) |
| Solver rev 1 → rev 6 "about four months" | rev 1 2026-05-12, rev 6 spec 2026-08-19: closer to three-plus months; fine |

## Section-by-Section Findings

### BLUF and Key Findings

Accurate and well-hedged; the confidence line (high architecture, medium production, low outcomes) is the right calibration.
The "~1.8 s @ 260k" figure used in the BLUF-adjacent assessment is kv-unified-specific (see Latency below).

### Architecture: Per-turn context lifecycle

**Blocking: maintenance trigger is misdrawn.**
Step 9 says maintenance runs "after or between turns", and the sequence diagram's closing `Note` places `tick()` as a continuation of the turn.
In code, `startQueuedMaintenance()` is driven by a `setInterval` of `maintenanceIntervalMs` (default `DEFAULT_MAINTENANCE_INTERVAL_MS`), plus once at `start()`, the operator `maintenanceTick()` path, and the OverBudget drain breaker (`framework.ts:1768-1777,2070-2133,3313-3321,11667-11680`).
A pass iterates *all* agents whose CM is not `isReady()`, skipping those blocked by the provider gate, and refreshes tool definitions (`cm.setToolDefinitions`) before ticking.
There is no turn-end hook that kicks it.
For an illustrator this is the difference between drawing a post-turn arrow and drawing an independent clock-driven loop; the report positions this section as "the one an illustrator should draw", so it must be correct.
Fix: reword step 9 as "periodic, turn-independent", and draw it as a separate loop (or a `par` block) in the sequence diagram.

Non-blocking: the tool-definitions refresh matters for the lifecycle because mints are deferred until the host has pushed tools (`autobiographical.ts:5920-5926`: "deferring chunk compression: host has not provided tool definitions yet").
One line noting that summarizer requests carry the agent's live tool list would make the mint box drawable too.

### Architecture: The fold solver

Accurate.
Non-blocking: rev 5.1 (2026-08-05) records that the shipped kv-stable solve is "a lexicographic branch cascade, not the drafted" formulation; the trust-region description is fine as a summary but could cite the 5.1 reconciliation.

### Architecture: Write path / L1 mint

Accurate and concrete.
Non-blocking: the "68 initiations" incident (`autobiographical.ts:5646-5652`), where head-after-recall ordering caused the summarizer to narrate the head as fresh events, "compounding across merges into runaway false memories", is the strongest code-documented evidence for the report's self-narrative-drift failure mode.
It belongs in Failure modes, where the report currently says the sycophancy risk is inferential.

### Time, decay, consolidation

**Blocking: branching claim is partly wrong.**
"`/undo` and `/checkpoint` create Chronicle branches" is not accurate for `/checkpoint`.
`handleCheckpoint` records `{branchName, messageId}` into `app.branchState.checkpoints` without creating a branch (`connectome-host/src/commands.ts:914-920`: "A checkpoint is a *position*, not just a branch").
`/restore` branches from that position; `/undo` creates a branch via `store.createBranchAt(undoBranchName, …, checkpoint.sequenceBefore)` (`agent-framework/src/framework.ts:5413`).
Fix: "`/undo` and `/restore` create Chronicle branches; `/checkpoint` records a (branch, message) position that `/restore` branches from."
Also worth checking whether `branchState` is persisted; `createBranchState()` suggests in-process state, which would mean checkpoints do not survive a host restart.

### Design philosophy table

Fair and well-sourced.
Non-blocking: the "Lossless append-only branchable archive" row cites "Chronicle README", which does not exist at `013f138`; cite `chronicle/src/lib.rs:1-11` or `docs/loom-of-looms.md`.

### Practical assessment

**Blocking: "Mints are separate temperature-0 inferences" is unsupported.**
There is no `temperature` anywhere in `context-manager/src` or `docs`; the mint calls (`autobiographical.ts:6215,6236,7858,7873`) pass no sampling parameter, so the provider default applies.
The only temperature-0 calls found are RetrievalModule's (`retrieval-module.ts:303,412`), and `agent-framework/src/types/agent.ts:110` notes signed-thinking models enforce `temperature: 1`.
This strengthens the report's own conclusion (content is less deterministic than stated), so the fix is simply to drop or correct the clause.

Non-blocking, token cost: "Large-tail deployments send ~160-178k tokens per turn on 200k models" misreads `AGENT-ONBOARDING.md:444-452`, which gives 160-178k as the *budget ceiling* to avoid silent 400s, noting the equilibrium "creeps up" toward it.
Reword as "budgets of 160-178k on 200k-window models, with steady-state context approaching the budget".

Non-blocking, latency: the 1.7-1.9 s figure is kv-unified only, and the report's own Open Questions say production may run kv-stable.
Qualify it ("kv-unified, after the #105 fix") so the synthesis does not generalize it to all folding strategies.
Also, "regressed by an order of magnitude shortly before this snapshot" is labeled inference, but the changelog describes a label-key bug that made compiles grow with the forest, not a regression from a faster prior state; "was 10× slower until the 0.11.0 fix" is what the evidence supports.

Fairness: the transfers / does-not-transfer split is balanced.
It credits the cache-aware solver, summarize/fold separation, and fail-loud budgeting on engineering merits, and rejects self-voiced as-of memory on a concrete task-fit argument (hindsight is what coding memory needs), not on the identity framing.
The KV-perturbation analysis correctly separates open-weights KV evidence from the hosted-API prompt-cache effect, and labels the gap as inference.
One missing counterweight: `compressionModel` is decoupled from the speaking model (host defaults it to the agent model, `connectome-host/src/framework-strategy.ts:87`, and the runbook recommends a stable one), which softens "model-bound identity does not transfer": the binding is operator doctrine, not an architectural constraint on the memory layer.

### Open questions

Good and honest.
Non-blocking: "No hindsight" has two small as-of leaks worth listing next to the system-prompt caveat: the summarizer request carries the *current* tool definitions and the *current* `compressionModel`, neither of which is the as-of state.

## Verdict

**Revise.**
Architecture, provenance, and figures are verified; inference is labeled; the assessment is fair.
Three factual corrections are required before this feeds diagrams and the synthesis: maintenance trigger, `/checkpoint` semantics, and the temperature-0 claim.

## Action Items

1. [blocking] Correct lifecycle step 9 and the sequence diagram: maintenance is a periodic, turn-independent timer pass over all not-ready agents (plus start-up, operator `maintenanceTick`, and OverBudget drain), not an after-turn step. Cite `framework.ts:1768-1777,2070-2133`.
2. [blocking] Fix the branching claim: `/undo` and `/restore` create branches; `/checkpoint` records a position (`commands.ts:914-920`, `framework.ts:5413`).
3. [blocking] Remove or correct "Mints are separate temperature-0 inferences"; no temperature is set on mint calls.
4. [non-blocking] Add the "68 initiations" runaway-false-memory incident (`autobiographical.ts:5646-5652`) to Failure modes as observed evidence of self-narrative drift.
5. [non-blocking] Qualify the 1.7-1.9 s figure as kv-unified post-#105; reword "regressed" as "was ~10× slower until the 0.11.0 fix".
6. [non-blocking] Reword the 160-178k figure as a budget ceiling, not observed per-turn send size.
7. [non-blocking] Replace the nonexistent "Chronicle README" citation.
8. [non-blocking] Note that `compressionModel` is separable from the speaking model, softening the model-binding non-transfer argument; note current-tools/current-model as additional as-of leaks.
9. [non-blocking] Mention the rev 5.1 "lexicographic branch cascade" reconciliation in the kv-stable description.

## Questions for the Author

1. For the illustrated artifact, how should background maintenance be drawn?
   (a) A separate clock-driven loop beside the turn sequence (recommended, matches code).
   (b) A `par` block inside the sequence diagram.
   (c) A footnote only.
2. Should the synthesis treat kv-stable or kv-unified as "the" Connectome solver?
   (a) kv-stable, per the runbook, with kv-unified as the direction of travel.
   (b) kv-unified, per changelog activity.
   (c) Present both, explicitly unresolved (recommended until production config is confirmed).
