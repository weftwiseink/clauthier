---
review_of: cdocs/proposals/2026-09-17-graphify-cdocs-integration.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-17T14:05:00-08:00
task_list: code-graph/cdocs-integration
type: review
state: archived
status: done
tags: [fresh_agent, rereview_agent, architecture, recall_parity, token_efficiency, model_tiering, writing_conventions]
---

# Review (round 2): Graphify integration into cdocs loops, and the librarian question

## Summary Assessment

Round 2, fresh context, verifying that the revision closed the three round-1 blocking gaps rather than papering over them.
All three are genuinely resolved: the D1 consumer-floor argument is reframed accurately and stays consistent with Phase 4; the D2 recall-parity gate is now a defined, falsifiable three-part discriminator whose CRDT-label-from-non-graph-signals claim holds; and Phase 1 per-phase attribution is designed (preference-ordered mechanism plus a stated coarser fallback) rather than asserted.
The six round-1 nits (F2, F4, F6, F7, F8, F9) are all addressed, several structurally (D3 gained a genuine structural guard, not just a restated caveat).
Verdict is **Accept**. Two residual nits remain, both non-blocking and both introduced by the edits: an Investigation Requested opening that reads as a changelog (writing-convention miss), and an Edge Cases bullet whose "caveat plus instruction is the guard" wording lags the now-hardened D3.

## Verification of round-1 blocking items

### MUST-FIX 1 (F1): consumer-floor asymmetry, reframed - RESOLVED

D1 (line 106) now drops "forbidden" and "decisive" entirely (confirmed by scan: neither word appears).
The advantage is restated correctly and narrowly: "having NO model, it needs no per-consumer carve-out negotiation at all and ships clean even to a consumer with NO search carve-out. So the tool wins on carve-out-free portability, not because a librarian trips a floor."
It explicitly concedes weftwise's existing search/explore->sonnet carve-out "plausibly already" covers a librarian's lookups, and lands the live question where round 1 asked: "its standing warm-agent cost, not its model tier."
Phase 4 (line 225) is reconciled: it now says "Confirm the consuming project's model policy admits its tier rather than authoring a new carve-out... making this a confirmation step; a consumer with NO search carve-out would need one." No residual tension with D1, and no residual overstatement anywhere in the section.

### MUST-FIX 2 (F3): recall-parity gate, operationalized - RESOLVED

D2 (lines 119-126) now defines the gate in three falsifiable parts:
- **Labeling protocol**: candidate union of graph output + grep-recall floor + observe-site scan, opus/human-adjudicated, hardened on a CRDT subset by runtime-trace coupling.
- **Corpus**: sized and case-mix-characterized before any reading is admissible, floored at enough per-category fixtures for a meaningful per-category rate; exact size a Phase 1 deliverable.
- **Pass rule under noise**: per-category recall >= baseline within the labeling CI, AND zero tolerance for a systematic-miss *class*.

The load-bearing sub-claim holds: the CRDT label is sourced from non-graph signals (observe-site scan plus runtime trace), explicitly "never the graph itself" (line 121), so the graph is never asked to grade its own blind spot. This is coherent.

On the noise policy as a potential loophole: it does not create one. Every category carries both a rate check (regression larger than the CI fails) and an absolute systematic-miss check (a dropped coupling class fails regardless of rate). A real regression is therefore caught either as an above-CI per-category drop or as a class miss; only a sub-CI single-fixture flip is absorbed, which is the honest statistical floor for sampled recall, not an escape hatch. The NOTE at line 125 states this reconciliation directly.

Minor coherence note (folded here, not a separate finding): the BLUF and D2's opening line still use the absolute "misses a dependent is a regression" framing, while the operational rule refines "regression" to a statistically real or systematic loss. These read as value-statement versus operational-definition and are bridged by the line-125 NOTE, so they are reconcilable; no change required.

### MUST-FIX 3 (F5): per-phase token attribution, designed - RESOLVED

Phase 1 (lines 197-198) names per-phase separation the "PRIMARY PHASE 1 RISK" and gives a preference-ordered mechanism: (1) tool-call boundaries, (2) read-vs-generate token split, (3) explicit phase markers only if the proxies are too lossy. The fallback is explicit: per-role/per-turn totals plus a context-gathering proxy (read-token volume plus tool-call count), with the efficiency claim restated at that coarser resolution and the Verification gate reading on the proxy.

The fallback preserves falsifiability rather than dissolving it: "total per-role burn falls AND the read-token proxy falls, recall held" is measurable and can fail on any of the three conjuncts. It is an honest, stated downgrade of *resolution*, not a hidden retreat into unfalsifiability, and Investigation Requested bullet 1 (line 240) flags that if the spike judges the proxies too lossy the claim "should be stated at that resolution from the outset." One observation, not blocking: the fallback restatement emphasizes the read-token (context-gathering) half and total burn, and does not restate the "reasoning/writing unmoved" half that the read/generate split (option 2) would supply for free; the full two-sided claim survives only in the fine-grained path (test plan line 170). This is a modest, acknowledged loss of specificity, not a gap.

## Verification of round-1 nits

- **F2 (single-shared-librarian growth)**: addressed. D1 (line 107) now names it plainly ("resident context accumulates M workstreams' worth of knowledge and grows unbounded as M rises") and directs Phase 4 to "test that the shared index stays bounded... not merely that it cuts burn." Phase 4 (line 225) and Investigation Requested (line 241) carry it forward.
- **F4 (soft production guard)**: addressed, and more than asked. D3 (lines 134-139) adds a genuine structural guard: the brief format never presents the set as exhaustive and always co-surfaces nearby observe/subscribe sites, and a near-empty graph set on files carrying observe sites triggers an unscoped sweep. It states the fixture is the test-time check and the production guard is the structural brief format plus trigger. Test plan line 172 is retitled "CRDT guard (structural)" to match.
- **F6 (efficiency bound in body)**: addressed. Background (line 48) now states the ~10-20%-of-total-burn ceiling once, attributed to the RFP as "a BOUND, not a forecast," with reasoning/writing tokens called out as untouched.
- **F7 (triage)**: addressed. Background (line 54) now excludes triage explicitly with rationale ("frontmatter/devlog-state work... consumes no dependent set") instead of listing it as a consumer.
- **F8 (license re-verification)**: addressed. Restored in D4 (line 146), Phase 2 precondition (line 206), and Open Questions (line 249).
- **F9 (sibling-repo reference)**: addressed. The non-navigable `weftwise:cdocs/...` scheme is gone; Background (line 45) and Links (line 254) now mark it a sibling-repo local path in the weftwise checkout with no canonical URL yet.

## Section-by-Section Findings (residual)

### N1 [non-blocking] Investigation Requested opens as a changelog

Line 238: "Round-1 review (...) resolved the consumer-floor framing (D1), the recall-gate operationalization (D2), and the per-phase-attribution keystone (Phase 1); those are settled in the body above, and the efficiency bound now sits plainly in Background."
This narrates the revision history ("resolved", "now sits plainly in Background"), which the writing conventions' history-agnostic framing rule disfavors, and reads as a changelog rather than a present-state design doc.
It is confined to one sentence in a process-facing block, and the design body itself is clean and present-tense, so this does not warrant another round.
Fix on acceptance: state the remaining pressure-test items directly without the retrospective preamble, e.g. drop the first sentence and open at "Items a further review round could pressure-test:".

### N2 [non-blocking] Edge Cases CRDT bullet lags the hardened D3

Line 161 still describes the CRDT guard as "The brief's caveat plus the role instruction to not narrow consideration is the guard," the pre-revision soft framing. D3 was upgraded to a structural guard (co-surfaced observe sites plus a near-empty-set-triggers-sweep escalation), but this echo was not updated to match, so the two sections now describe the same guard at different strengths.
Fix: align line 161 with D3, e.g. note the guard is the structural brief format plus the near-empty-plus-observe-sites trigger, with the caveat and instruction as the additive floor.

### Convention and completeness (clean)

No em-dashes or en-dashes (mermaid `-->` and the `->` in "search/explore->sonnet" are notation, not prose dashes); no emojis; BLUF present and two-part; sentence-per-line honored; history-agnostic framing holds throughout the body with the RFP relationship correctly quarantined to a NOTE (the sole lapse is N1, in a process block). Frontmatter is spec-valid and unchanged in shape. Section coverage remains complete: objective, background, design decisions, edge cases, test plan, verification methodology, phased implementation with per-phase success/depends/blocks, investigation-requested, and open questions.

## Verdict

**Accept.**

All three round-1 blocking items are genuinely closed, not deflected, and each survives fresh scrutiny: the D1 reframe is accurate and internally consistent, the D2 gate is a defined falsifiable discriminator with a sound noise policy and a CRDT label that never derives from the graph, and Phase 1 attribution is designed with a falsifiability-preserving fallback. The six nits are resolved, two of them structurally. The only residual issues are two non-blocking cleanups the edits themselves introduced (N1, N2), neither of which touches correctness or direction. The tool-first, librarian-deferred, discriminator-first spine is sound and should ship as written once the two nits are swept.

## Action Items

1. [non-blocking] (N1) Rewrite the Investigation Requested opening to state remaining items directly, dropping the "round-1 resolved... now sits in Background" changelog preamble.
2. [non-blocking] (N2) Update Edge Cases line 161 so the CRDT guard description matches the structural guard in D3 (co-surfaced observe sites plus near-empty-set trigger), rather than the caveat-plus-instruction soft framing.
3. [non-blocking, optional] In the Phase 1 fallback (line 198), note that the read/generate split also proxies the "reasoning/writing unmoved" half, so the coarser claim retains both sides rather than only the read-token half.
