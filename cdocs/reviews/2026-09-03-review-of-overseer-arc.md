---
review_of: cdocs/proposals/2026-09-03-overseer-arc.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-03T12:30:00-08:00
task_list: cdocs/oversee-skill
type: review
state: live
status: done
tags: [fresh_agent, architecture, agent_orchestration, composition, cdocs_meta, verification]
---

# Review: `/oversee` Multi-Proposal-Arc Orchestration

## Summary Assessment

The proposal designs `/oversee` as the arc layer above `full-send`: it sequences multiple proposals through their lifecycle by composing `full-send`/`iterate`/`propose-revise` per proposal, adding five genuinely arc-level primitives (durable arc-state file, repo-global claim registry, footprint-overlap serialization, troubleshooting budget, verification-depth ladder) and inheriting rather than restating `orchestration-discipline.md`.
The architecture is coherent and the core discipline is right: composition-not-reimplementation, one-overseer-per-arc forced by the no-nested-dispatch rule, and cross-arc state living in a repo-global location a per-session devlog cannot reach.
It respects its spanning no-modify/no-restate constraint carefully and answers all seven consolidation §A questions.

One blocking internal inconsistency stands: the troubleshooting-budget section says the arc overseer "surfaces the signal into that loop's judge," which directly contradicts the black-box return contract the proposal itself defines (arc overseer reads back only frontmatter `status` + devlog, never loop internals) and, if taken literally, would require modifying `iterate` (forbidden by the spanning constraint).
The remainder are non-blocking clarifications plus the author's own well-scoped Open Questions.
**Verdict: Revise (revision_requested).**

## Answers to the Six Flagged Points

**1. No-nested-dispatch / interleaving model - SOUND.**
The interleaving model is legally consistent with the no-nested-dispatch rule: one overseer does all dispatch, subagents never dispatch, and parallel subagent dispatch is supported.
It does NOT collapse to sequential: the expensive dispatched work (two implementers) runs concurrently while only the overseer's own thin review/decide turns serialize.
That is genuine parallelism at the work layer, honestly modest (concurrency of dispatched work, not of judgment), and the proposal frames it accurately.
It is consistent with Pillar 3's one-specialist-per-workstream bound: two footprint-disjoint proposals are two workstreams with one specialist each (`arc-impl-a`, `arc-impl-b`).
The residual gap is the AGGREGATE bound: interleaving N streams means the overseer absorbs summaries from 2N+ interleaved children plus holds N warm specialists against the Pillar 2 ~150K target, and the proposal caps this only by hand-wave ("subject to... the overseer's own context budget"). See action item 2.

**2. State-file vs. devlog duplication - PARTIALLY SOUND (needs-change, non-blocking).**
The justification must be split, because it is really two claims of unequal strength.
The claim registry being repo-global and OUTSIDE any devlog is strongly justified: a per-session devlog is invisible to a concurrent second overseer in another worktree, so cross-arc visibility genuinely needs a shared location.
The arc-state file being a separate JSON rather than a section of a top-level ARC devlog is under-justified and the author flags it as OQ3. The machine-legibility argument is asserted, not argued (iterate resumes fine from a markdown Iteration Log), and the proposal introduces a parallel "write the state file before compacting" discipline for a second durable artifact, exactly the kind of divergence from devlog-is-single-source-of-truth the dedup value cautions against. See action item 3.

**3. Claim registry vs. Pillar 1b - SOUND (genuinely extends).**
Pillar 1b guards single-writer ownership WITHIN one overseer's loop, checked against that loop's private Iteration Log. The registry addresses the case Pillar 1b explicitly does not (its own NOTE describes the clobber, and consolidation §A.4 marks multi-overseer coordination out of scope for `overseer-alignment`): a second top-level overseer with no visibility into the first's Iteration Log.
The proposal references Pillar 1b and Pillar 3 ("file ownership by construction") by pointer and adds only the cross-arc/cross-session delta. This is new content, not a restatement.

**4. Composition return contract - MOSTLY SOUND (needs a clarifying edge case, non-blocking).**
Reading proposal frontmatter `status` is a reasonable primary signal because `iterate`'s Accept branch sets `implementation_accepted`, and the proposal correctly pairs it with the devlog handoff rather than relying on frontmatter alone.
Two gaps: (a) the terminal-write race - a loop that dies between the review-Accept decision and the frontmatter/devlog write leaves BOTH signals stale, and the arc overseer would re-run the loop; this is safe (re-review finds it passing and re-Accepts) but is never named, while only the reverse drift (frontmatter accepted, arc_state in_progress) is enumerated in Edge Cases; (b) the down-channel "autonomy signal derived from the arc AFK field" has no formal flag in `iterate`/`full-send` (confirmed: iterate exposes no `--afk`/autonomy flag), so it can only be conveyed as dispatch-brief prose - adding a flag would modify `iterate` and violate the spanning constraint. State both explicitly. See action item 4.

**5. Verification ladder vs. `review_proof` - SOUND (line is clean).**
The two are orthogonal axes: the ladder (compile/unit/integration/smoke/live) is a DEPTH taxonomy that selects the required rung and GENERATES the `--verification-floor` sentence passed into `iterate`; `review_proof` (confirmed/n-a/deferred/skipped) is a per-ROUND audit of whether the reviewer produced evidence, living in the Iteration Log inside the loop.
They compose, not compete, and the proposal states this. Even the near-collision (`deferred` rung intuition vs `review_proof: deferred-to-followup`) stays clean in the Test Plan, which correctly uses `deferred-to-followup` as a `review_proof` value distinct from the `smoke` rung.

**6. Frontmatter-field creep - SOUND deferral, adequate footprint interim, under-specified `required_rung` interim (needs-change, non-blocking).**
Deferring `frontmatter-spec.md` edits is the right call: the field NAMES are still open (OQ1), so cementing them now is premature, and derive-on-absence keeps the skill functional without the fields.
The `footprint` interim (sonnet footprint scout, serialize-on-uncertainty) is adequate.
The `required_rung` interim is under-specified for the `chain`-of-authored-proposals-with-no-rung case: the proposal names a default only for `full <topic>`. State the chain fallback (read the proposal's `## Verification Methodology` as `iterate` does, else escalate/AFK-placeholder per `iterate`'s existing floor rule). See action item 5.
Note: `frontmatter-spec.md` is NOT in the spanning no-change set, so "would touch a file outside the current no-change set" (OQ1) is imprecise - the real reason to defer is unsettled field names, not a hard no-touch boundary; correct the rationale. See action item 6.

## Section-by-Section Findings

### Troubleshooting budgets - BLOCKING inconsistency
"When a proposal's loop trends past it, surfaces the signal into that loop's judge (the same soft-budget-as-judge-input mechanism `iterate` uses)... or escalates the proposal as blocked."
The "surface into that loop's judge" mechanism contradicts the Composition-return-contract section ("it does NOT re-read the loop's Iteration Log turns... reads a status field and a handoff, never the loop's raw turns"). `iterate`'s soft-budget-to-judge channel is INTERNAL: iterate's own overseer surfaces to iterate's own judge. For the ARC overseer to inject into a composed loop's judge, it must either reach into loop internals (breaking the black box) or gain a new `iterate` parameter (modifying `iterate`, forbidden). Both violate stated constraints. The clean resolution is arc-altitude enforcement only: the overseer watches `budget.full_cycle_retries_max` in the arc-state file and escalates the proposal as blocked; any signal it wants the composed loop's judge to see travels through the down-channel brief/verification-floor prose it already controls, not by reaching in. See action item 1.

### Composition, not reimplementation - sound, one clarification
The two directional contracts are the right shape and the "reads status + devlog, not loop internals" discipline is the correct thinness posture (and is exactly what the troubleshooting section above must not contradict).
Clarify (action item 4b) that the down autonomy signal is brief prose, not a flag.

### The arc overseer is the ONLY overseer - sound but over-repeated
The load-bearing constraint is correct and important. It is, however, restated in at least four places (this section, the Composition section, Important Design Decisions, the NOTE callout, and Cross-Target Degradation). Tighten to one canonical statement plus pointers per the "say it once" convention. Non-blocking. See action item 7.

### Cross-session durability: the arc-state file - sound, see point 2
The drift-detection design (arc_state vs mirrored frontmatter status) is good. The only issue is the separate-JSON-vs-arc-devlog-section choice left fully open (OQ3), which weakens Phase 2's foundation; recommend resolving before implementation. Non-blocking. See action item 3.

### Implementation Phases - logically ordered, one sequencing suggestion
Dependencies are correct: Phase 5 rightly depends on both Phase 2 (state file) and Phase 4 (claims, for stale-claim reconciliation).
Observation: minimal cross-session resume (reconstruct `position`, do-not-re-run-done, Test scenario 5) needs only the state file from Phase 2 and is claim-independent; it is the headline durability value (the AFK rationale calls resume "the DEFINING requirement") yet is gated behind Phase 4. Consider splitting: claim-independent resume right after Phase 2, stale-claim reconciliation (scenario 6) stays in Phase 5. Non-blocking. See action item 8.
Minor: the "`/oversee`-of-`/oversee`" dogfooding methodology is circular for Phases 1-2 (the skill does not exist yet); the "or a plain `iterate` per phase" fallback saves it. Nit.
Per-phase success criteria are concrete (tied to Test Plan scenarios); Phase 1/6 prose criteria are acceptable for rule/docs phases.

### Under-specified items (all non-blocking)
- Interleaving concurrency cap / how many streams one overseer may hold (point 1).
- `arc_id` derivation (topic? user-supplied? first proposal?) - schema shows one but never says how it is minted.
- `/oversee resume` with no argument: how it disambiguates among multiple arcs in `.claude/oversee/`. Test scenario 5 assumes a single arc.
See action item 9 (bundles these).

### Spanning constraint (no modify/restate) - RESPECTED
The proposal references Pillars by pointer and adds only arc-level delta; the Background Pillar enumeration is a pointer list, not a prose restatement. The claim registry "extends, does not restate" Pillar 1b; the ladder is new (not in `iterate`); the arc AFK is distinct from iterate's per-loop AFK. No composed skill needs modification for the design as written - EXCEPT the troubleshooting-budget "surface into the loop's judge" claim, which is the one place the constraint is at risk (action item 1).

### Writing conventions - clean
History-agnostic present-tense framing holds (prior-approach references are confined to Summary/Background/NOTE callouts, permitted for proposals). No em-dashes (verified). Mermaid used for the flow diagram. `[[wikilink]]` internal cross-refs match the house convention used by sibling proposals. BLUF present. The only convention strain is repetition of the interleaving point (action item 7).

## Verdict

**Revise (revision_requested).**
The design is fundamentally sound and does not need rework; it needs one blocking consistency fix and a set of clarifications. All blocking issues resolved should shift this toward Accept in round 2.

## Action Items

1. [blocking] **Troubleshooting budgets section.** Remove or rework the "surfaces the signal into that loop's judge" mechanism: it contradicts the black-box return contract and would require modifying `iterate`. State that the budget is enforced at ARC altitude - the overseer watches `budget.full_cycle_retries_max` per proposal in the arc-state file and escalates the proposal as blocked; any signal to the composed loop's judge travels only through the down-channel brief/verification-floor prose the arc overseer already controls.
2. [non-blocking] **Interleaving section / Important Design Decisions.** State a concrete cap heuristic for how many footprint-disjoint proposals may interleave under one overseer, tied to the Pillar 2 ~150K context budget and the Pillar 3 one-per-workstream bound (e.g., a small N with escalate-or-re-scope past it), rather than "subject to the overseer's own context budget."
3. [non-blocking] **Arc-state file section (resolve OQ3).** Either strengthen the machine-legibility/cross-session justification for a separate JSON over a top-level arc-devlog section, or adopt the arc-devlog-section approach; leaving the durability substrate fully open weakens Phase 2. If JSON is kept, note explicitly that the "write-before-compact" discipline for it is the arc-altitude analogue of Pillar 2's devlog handoff, not a competing artifact.
4. [non-blocking] **Composition / Edge Cases.** (a) Add an Edge Case for the terminal-write race (loop dies between review-Accept and the frontmatter/devlog write): both signals stale, overseer re-runs, and re-run is safe because `iterate` re-reviews and re-Accepts already-done work; state that the reliable return signal is the reconciled triple (frontmatter `status` + final devlog handoff + `arc_state`), not frontmatter alone. (b) Clarify that the down "autonomy signal derived from the arc AFK field" is conveyed as dispatch-brief prose, since `iterate`/`full-send` expose no `--afk`/autonomy flag and adding one would violate the no-modify constraint.
5. [non-blocking] **Verification-depth ladder section.** Specify the `required_rung` fallback for a `chain` of authored proposals with no `required_rung` field: read the proposal's `## Verification Methodology` (as `iterate` does), else escalate / write an AFK placeholder floor per `iterate`'s existing floor rule.
6. [non-blocking] **Open Question 1.** Correct the rationale: `frontmatter-spec.md` is not in the spanning no-change set, so the reason to defer the field additions is unsettled field names, not a hard no-touch boundary.
7. [non-blocking] **"The arc overseer is the ONLY overseer" + duplicated spots.** Consolidate the one-overseer/interleaving-not-nested explanation to a single canonical statement plus pointers; it currently recurs in four-plus places.
8. [non-blocking] **Implementation Phases.** Consider splitting claim-independent cross-session resume (Test scenario 5) to immediately after Phase 2, leaving stale-claim reconciliation (scenario 6) in Phase 5, so the headline durability guarantee is not gated behind Phase 4.
9. [non-blocking] **Schema / resume specification.** Specify `arc_id` derivation and how `/oversee resume` (no argument) disambiguates among multiple arcs under `.claude/oversee/`.

## Open Questions Surfaced for the Author

- OQ3 (arc-state file vs. arc-devlog section) is load-bearing enough that leaving it fully open weakens Phase 2. Prefer: (a) resolve it in-proposal to the separate JSON with a strengthened machine-legibility argument; (b) resolve it to an arc-devlog section for single-artifact simplicity; or (c) keep it open but add explicit decision criteria the implementer applies. Recommendation: (a) or (b), not (c).
- Troubleshooting-budget enforcement altitude (action item 1): confirm arc-altitude-only enforcement (watch-and-escalate) is the intended and sole mechanism, with no channel into the composed loop's internal judge.
