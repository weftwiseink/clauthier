---
review_of: cdocs/proposals/2026-09-03-overseer-arc.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-03T13:15:00-08:00
task_list: cdocs/oversee-skill
type: review
state: live
status: done
round: 2
tags: [fresh_agent, round2, architecture, agent_orchestration, composition, cdocs_meta, verification]
---

# Review (Round 2): `/oversee` Multi-Proposal-Arc Orchestration

## Summary Assessment

The revision resolves the single round-1 blocking inconsistency and every one of the eight non-blocking items, cleanly and without introducing a spanning-constraint violation.
The Troubleshooting-budget section is now arc-altitude-only: retry count is watched in the arc-state file, over-budget escalates the proposal as `blocked`, and any signal for a composed loop's judge travels through the down-channel brief/verification-floor prose the overseer already controls, with an explicit "does NOT reach into the composed loop's judge" statement closing the black-box hole.
The design remains coherent, still answers consolidation §A, and still composes rather than reimplements.
A handful of minor phrasing nits remain (below), none blocking.
**Verdict: Accept (accepted).**

## Round-1 Item Disposition

### Blocking (1): Troubleshooting-budget reach-in - RESOLVED

The revised "Troubleshooting budgets" section leads with "Enforcement is at the ARC altitude ONLY, to stay inside the black-box return contract," tracks `budget.full_cycle_retries_max` in the arc-state file inferred from what the loop reports UP (devlog handoff + iteration count), and escalates the proposal as `blocked` past budget.
It explicitly disclaims the reach-in ("It does NOT reach into the composed loop's judge: that channel is internal to `iterate`... injecting into it would either break the black box or require a new `iterate` parameter, both forbidden") and routes any judge-directed signal through "the down-channel it already controls: the dispatch brief and `--verification-floor` prose."
This is exactly the resolution round-1 action item 1 asked for. No residual reach-in remains anywhere in the document (grep-confirmed).

### Non-blocking, all eight RESOLVED

2. **Interleaving concurrency cap quantified - RESOLVED.** New "Concurrency cap" paragraph sets a default of 3 footprint-disjoint proposals interleaved, tied to the Pillar 2 ~150K target and Pillar 3's one-per-workstream bound, with `--max-parallel N` to adjust and serialize-or-re-scope past the cap. Replaces the round-1 hand-wave.
3. **OQ3 arc-state-vs-devlog - RESOLVED.** "Why a structured JSON file and not a section of a top-level arc devlog (resolves OQ3)" gives a real argument (programmatic cross-session reconciliation: glob intersection, claim-staleness, drift diff vs mirrored frontmatter), keeps the human narrative in a normal arc devlog, and the NOTE frames the write-before-compact discipline as the arc-altitude analogue of Pillar 2, not a competing artifact. OQ3 in the Open Questions list is now marked "resolved."
4a. **Terminal-write-race + up-contract - RESOLVED.** The Up contract now reads back a "reconciled TRIPLE, not frontmatter alone" (frontmatter `status` + devlog handoff + `arc_state`), and Edge Cases adds a named "Terminal-write race" scenario resolved by forward-reconciliation. No longer frontmatter-alone.
4b. **Down autonomy signal is prose not a flag - RESOLVED.** The Down contract now states the autonomy signal "is conveyed as dispatch-BRIEF PROSE, not a flag," with the explicit reason that adding a flag would modify a composed skill.
5. **`required_rung` chain fallback - RESOLVED.** Rung selection is now a four-item precedence list: frontmatter field, else read the proposal's `## Verification Methodology` (as `iterate` does), else fall back to `iterate`'s floor rule (`AskUserQuestion` or AFK placeholder), plus a `full <topic>` default.
6. **OQ1 rationale corrected - RESOLVED.** OQ1 now states the deferral reason is unsettled field names, "NOT a no-touch boundary: `frontmatter-spec.md` is not in this proposal's spanning no-change set."
7. **Interleaving restatement de-duplicated - RESOLVED.** The one-overseer/interleave-not-nest rule is stated canonically under "The arc overseer is the ONLY overseer" with a NOTE declaring it canonical there; Important Design Decisions and other sites now point at it rather than re-argue it.
8. **Claim-independent resume split earlier - RESOLVED.** Resume is now its own Phase 3 ("Cross-session resume (claim-independent)"), depending only on Phase 2's state file, with stale-claim reconciliation left in Phase 5. The headline durability guarantee is no longer gated behind the claim work.
9. **`arc_id` derivation + resume disambiguation - RESOLVED.** `arc_id` is minted as `YYYY-MM-DD` plus a slug of the topic (or first proposal basename for a chain); `/oversee resume` with no argument resumes the sole non-terminal arc, else lists candidates and `AskUserQuestion` (or under AFK resumes the most-recent non-terminal arc and logs it).

## Fresh Pass

### Implementation Phases - correctly ordered, dependencies sound

Phase 1 (rule/schema) → Phase 2 (sequential MVP, scenario 1) → Phase 3 (resume, scenario 5, claim-independent, depends on Phase 2 only) → Phase 4 (AFK, scenarios 4/7, composes with Phase 3) → Phase 5 (footprint/interleave/claims, scenarios 2/3/6, depends on Phase 2 and Phase 3) → Phase 6 (optional init/cross-target).
Each phase names its dependency and a "Do NOT" guard; success criteria map to concrete Test-Plan scenarios (Phase 1/6 prose criteria acceptable for rule/docs). The reordering from round-1 action item 8 is clean and the dependency graph is acyclic and honest.

### Spanning constraint - RESPECTED

No modification or prose restatement of `orchestration-discipline.md`, `model-tiering.md`, `iterate`, `propose-revise`, or `full-send`. Pillars are referenced by pointer; the claim registry extends Pillar 1b, the ladder is new, arc AFK is distinct from iterate's per-loop AFK, and `--max-parallel` is a new `/oversee` flag (not a composed-skill parameter). The one round-1 at-risk site (troubleshooting reach-in) is now closed.

### New inconsistencies - none blocking

The revision introduces no new blocking inconsistency. The Edge Cases forward-reconciliation ("adopt on-disk terminal state if frontmatter accepted + devlog handoff present, else re-run") is internally consistent across the "Interrupted mid-proposal" and "Terminal-write race" cases.

### Writing conventions - clean

History-agnostic present-tense framing holds (prior-approach references confined to Summary/Background/NOTE/Open Questions, permitted for proposals). Zero em-dashes (grep-confirmed). BLUF present, Mermaid used, `[[wikilink]]` cross-refs consistent. Round-1's repetition strain is resolved.

## Residual Nits (fold in opportunistically, non-blocking)

1. **Up-contract "frontmatter alone could be misread" (Composition, Up bullet).** In the specific terminal-write race, frontmatter-alone would also read stale-in-progress and also trigger a re-run, so the triple's advantage in THAT case is marginal. The Edge Cases framing ("no single field is trusted to have been written atomically at the terminal moment") is the sound justification; consider aligning the Up-bullet wording to it rather than "misread."
2. **`arc_state` inside the "return contract" triple.** `arc_state` is the overseer's own bookkeeping, not something the composed loop produces, so calling it part of the loop's "return contract" slightly conflates live-return (frontmatter + devlog) with resume-reconciliation (all three). Harmless, but a half-sentence distinguishing the two moments would sharpen it.
3. **Ladder rung-selection precedence list (Verification-depth ladder).** Items 1-3 are a true precedence chain for chains; item 4 is a separate `full <topic>` mode branch folded into the same numbered list. Consider splitting item 4 out as a mode note so the "precedence order" reads cleanly.

## Verdict

**Accept (accepted).**
The blocking inconsistency and all eight non-blocking items are resolved, the phase reordering is sound, the spanning constraint is respected, and no new blocking issue was introduced. The three residual nits are cosmetic and may be folded in at implementation time.
