---
review_of: cdocs/proposals/2026-09-17-graphify-cdocs-integration.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-17T13:20:00-08:00
task_list: code-graph/cdocs-integration
type: review
state: archived
status: done
tags: [fresh_agent, architecture, model_tiering, test_plan, recall_parity, token_efficiency, orchestration_discipline]
---

# Review: Graphify integration into cdocs loops, and the librarian question

## Summary Assessment

The proposal integrates a pre-indexed code-graph substrate (graphify) into cdocs loops as a stateless, role-agnostic scoping surface, recommends shipping the plain tool first and deferring a durable "librarian" subagent, and gates the whole efficiency justification behind discriminator-first token instrumentation.
It is a strong, unusually honest document: thorough section coverage, explicit phase dependencies, a recall-parity hard gate, and a self-aware Investigation Requested block that flags its own weakest joints.
The core architectural decision (tool-first, librarian-deferred, measure-before-claiming) is sound and survives every objection I can mount, and the proposer is right that it "holds regardless" of how the librarian sub-questions resolve.

The verdict is **Revise**, and only because three of the load-bearing arguments the proposal stakes itself on are under-operationalized or overstated as written: (1) the consumer-floor asymmetry that D1 calls "decisive" overclaims for the one named consumer, whose existing search/explore carve-out likely already permits a sonnet librarian's lookups; (2) the recall-parity hard gate, the proposal's central safety claim, is asserted with a clear direction but no ground-truth labeling method, corpus definition, or noise policy, so it is not yet measurable; (3) Phase 1's per-*phase* token attribution, on which falsifiability rests, is asserted rather than designed.
None require rearchitecting. All are tightenings of arguments and test criteria the proposal already gestures at.

## Section-by-Section Findings

### D1 centerpiece: tool-first, librarian deferred

The recommendation is correct and well-argued on multiple independent grounds (statelessly-captured value, smaller bet, cross-target cleanliness). Two of the four supporting arguments need work.

**F1 [blocking] The consumer-floor asymmetry is overstated; D1 calls it "decisive" on a claim that does not hold for the named consumer.**
D1 argues a stateless tool "has NO model, so it sidesteps the floor entirely" while "a sonnet librarian is forbidden until the consumer writes a named carve-out," and calls this "alone a decisive reason to lead with the tool."
But per `model-tiering.md` (Precedence), weftwise, the consumer this argument invokes, already ships a named carve-out: "always use sonnet for search, explore, and research aggregation" above its Opus floor.
A librarian that holds codebase knowledge and answers leads' lookups is squarely search/explore/research-aggregation work.
So for weftwise specifically, a sonnet librarian's lookups are plausibly *already permitted* by the existing carve-out, not "forbidden" pending a new one, and an explicit delegation of search-tier work to a search-tier agent is not the "silent downgrade" the floor targets.
The asymmetry is real but softer than presented: the tool's genuine, defensible advantage is that having no model means no per-consumer carve-out *negotiation* is ever needed and it ships clean to a consumer that has *no* search carve-out, not that a librarian trips a floor for weftwise.
This is the reasoning the proposer explicitly asked to be scrutinized (Investigation Requested, bullet 2), and as written it partially dodges the real question.
Reasoning matters here because D1 is the centerpiece and Phase 4 (line 202) tells the future implementer to "resolve the consumer-floor carve-out" that D1 implies must be written, which is in tension with an existing carve-out that may already cover it.
Fix: reframe the floor argument as "no model means no carve-out negotiation and clean cross-consumer shipping," drop or heavily qualify "forbidden"/"decisive," and note that weftwise's existing search/explore carve-out likely already covers a librarian's lookup tier (so the live question is the *standing warm-agent cost*, not the tier). The tool-first recommendation is unaffected; only the honesty of the justification is at stake.

**F2 [non-blocking] Pillar 3 reconciliation is defensible but hand-waves single-agent unbounded context growth.**
Framing the librarian as a read-only shared service that "owns no files, holds no workstream" is a *sound* escape from the one-per-workstream bound, not a rationalization: the bound exists to stop N parallel large-context specialists, and a single shared index is the opposite of proliferation (it consolidates rather than multiplies).
Read-only + owns-no-files genuinely takes it out of Pillar 1b, and the bound governs workstream ownership, which a shared service lacks.
The gap: one librarian serving M workstreams accumulates M workstreams' worth of resident context, so it does not recreate the *N-specialists* problem but can recreate the *large-context* problem inside a single agent as M grows.
The proposal notes the "standing warm-agent cost that must be earned" but never names the unbounded-single-agent-context risk or how the shared index stays bounded.
This is legitimately deferrable to Phase 4, but D1 should name it so the later evaluation is scoped to test it, rather than discovering it.

### D2 / D3 recall parity and the CRDT blind spot

**F3 [blocking] The recall-parity hard gate is asserted, not operationalized.**
D2 states "any measured increase in missed dependents versus the current unscoped baseline fails the change" and the test plan meters "missed-dependent rate on a labeled fixture set."
The direction is clear and correct, but the gate is not yet measurable as written. Missing:
- **Ground-truth labeling method.** Who produces the "known true dependent sets," and how is a true dependent defined for a CRDT-coupled change where the graph is blind by construction? Without a labeling protocol, "missed-dependent rate" has no denominator.
- **Corpus definition.** "A fixed representative corpus" and "labeled fixture set" are named but never sized or characterized; a hard gate on a tiny or unrepresentative fixture is noise.
- **Noise / tolerance policy.** "Any measured increase" reads as zero-tolerance, but recall is measured on a sample: does a single fixture flip fail the change, or is there a rate with a confidence interval? A zero-tolerance gate on a noisy sample is either unachievable or vacuous.
Because the entire proposal is discriminator-first, and this gate is its central safety claim, the gate must itself be a defined discriminator. Fix: specify the labeling protocol (including how CRDT coupling is labeled), a minimum corpus size/characterization, and the pass rule under measurement noise.

**F4 [non-blocking] The production-time CRDT guard is soft; the fixture only validates at test time.**
D3's guard against a role over-trusting a near-empty graph set is (a) an inline AID caveat and (b) a role instruction not to narrow consideration. The test plan's CRDT fixture (line 152) validates this *at test time* on known cases.
But in production, a CRDT-heavy change *not* in the fixture set has only the soft caveat + instruction standing between it and a recall regression, and a token-pressured role is precisely the actor most likely to treat a small confident set as license to stop.
The WARN callout half-acknowledges this ("the caveat is not decoration"), but a caveat is still the weakest possible enforcement.
The proposal's own Investigation Requested (bullet 3) asks whether the inline note needs "a stronger enforcement mechanism." My answer: yes, consider a *structural* mitigation the brief format enforces by construction, e.g. the brief never presents the dependent set as exhaustive and always co-surfaces a "CRDT/observe sites near these files" signal, so the role cannot receive a bare small set. At minimum, state explicitly that the fixture is a test-time check and the production guard is deliberately soft-and-additive (skip-scope never lowers the baseline), so no reader mistakes the fixture for a production guarantee.

### Discriminator-first instrumentation (Phase 1)

**F5 [blocking] Per-phase token attribution is the crux of falsifiability and is asserted, not designed.**
The central claim under test (line 150) is that *context-gathering-phase* tokens fall while *reasoning/writing* tokens are unmoved. This requires attributing tokens not just per role (tractable) but per *phase within a role's turn* (hard: context-gathering, reasoning, and writing interleave inside a single subagent turn).
Phase 1's success criterion ("the context-gathering phase is isolable per role") asserts this isolation is achievable but says nothing about the mechanism, and the proposal elsewhere admits "there is no established cdocs token-accounting convention today."
If phase boundaries cannot be cleanly metered, the proposal's signature claim is unfalsifiable and the gate in Verification step 3 ("context-gathering tokens fall AND recall holds") cannot be evaluated.
This is the true keystone: everything downstream is admissible only through Phase 1, and Phase 1's hardest sub-problem is unexamined.
Fix: describe how the meter attributes tokens to phase (tool-call-boundary heuristic? explicit phase markers the roles emit? read-vs-generate token split?), and name per-phase attribution as the primary Phase 1 risk with a fallback (e.g. per-role-only attribution + a read-token proxy) if clean phase separation proves infeasible.

### Efficiency-bound honesty (focus area 4)

**F6 [non-blocking, confirmation] The ~10-20% ceiling reads as a bound, not a forecast.**
It appears exactly once (Investigation Requested, line 220), framed as "a hypothesis... the realized figure likely below it... a bound, not a forecast." That framing is correct and honest, and the Objective/Summary make only qualitative efficiency claims with no unbacked magnitude, which is the right call.
Minor oddity: the sole statement of the bound is a self-referential request to "confirm the proposal states this as a bound... everywhere it appears," when it appears only in that request. Consider stating the bound plainly once in Background (carried from the RFP with attribution) so the thesis is honestly bounded in the body, not only in a reviewer-facing aside. Not blocking.

### Consistency and completeness

**F7 [non-blocking] `triage` is listed as a scoping consumer but never integrated.**
Background (line 48) names the `triage` agent among "target surfaces the integration touches," but triage does frontmatter/devlog-state work (glob/filter/parse of `cdocs/**`), not code-symbol context-gathering, and no phase ever wires scoping into it (phases cover reviewer, then implementer + judge).
Either justify why triage consumes a code-dependent set or drop it from the target-surface list; as written it is a loose thread.

**F8 [non-blocking] The RFP's license re-verification diligence item is dropped.**
The source RFP lists "Engine choice under license... Confirm graphify's license under #2's re-verification" as an open question the full proposal must carry. D4 asserts "graphify (Apache/MIT)" as settled and carries only the pre-1.0 *churn* risk, silently dropping the license *re-verification* obligation. Re-add it as an Open Question or a Phase 2 precondition to stay faithful to the RFP decision trail.

**F9 [non-blocking] The `weftwise:cdocs/...` reference scheme is not navigable.**
Writing conventions prefer direct navigable links for external references. The source RFP is cited three times as `weftwise:cdocs/proposals/2026-09-15-code-graph-review-plugin-rfp.md`, a custom scheme neither a repo-relative path (it is a sibling repo) nor an HTTP link. If a canonical URL exists, use it; otherwise note it is a sibling-repo local path so a reader knows where to look.

**Convention compliance (clean):** no prose em-dashes (the flagged `-->` are mermaid arrows), no emojis, BLUF present and two-part, sentence-per-line honored, mermaid used over ASCII, history-agnostic framing with RFP relationship correctly quarantined to a NOTE. Frontmatter is spec-valid. Section coverage for a full implementation proposal is complete: test plan, verification methodology, phased implementation with per-phase success/depends/blocks, explicit dependencies, and what-not-to-change constraints (Phase 1 "adds NO scoping," skip-scope "strictly additive," "integrate into ONE role first") are all present.

## Verdict

**Revise.**

The architecture is right and the document is well above the bar for structure, honesty, and completeness. The revision is narrow: tighten three load-bearing arguments the proposal itself flagged for scrutiny (F1, F3, F5) and address the non-blocking cleanups (F2, F4, F6-F9). No decision needs to change and no section needs rewriting; the tool-first, librarian-deferred, discriminator-first spine is sound and should be preserved verbatim.

## Action Items

1. **[blocking] (F1)** Reframe D1's consumer-floor argument: replace "forbidden until a carve-out is written" / "decisive" with "no model means no carve-out negotiation and clean shipping to a consumer with no search carve-out," and acknowledge that weftwise's existing search/explore->sonnet carve-out likely already covers a librarian's lookup tier, so the live librarian question is standing warm-agent cost, not tier. Reconcile with Phase 4's "resolve the carve-out" step.
2. **[blocking] (F3)** Operationalize the recall-parity hard gate: define the ground-truth labeling protocol (including how CRDT coupling is labeled), a minimum corpus size/characterization, and the pass rule under measurement noise (is it truly zero-tolerance on a sample?).
3. **[blocking] (F5)** Design, do not just assert, Phase 1 per-*phase* token attribution: state the attribution mechanism and name per-phase separation as the primary Phase 1 risk with a fallback if clean separation is infeasible. This is the keystone of falsifiability.
4. **[non-blocking] (F4)** State that the CRDT fixture is a test-time check and the production guard is deliberately soft-and-additive; consider a structural brief-format mitigation (co-surface CRDT/observe sites; never present the set as exhaustive).
5. **[non-blocking] (F2)** In D1, name the single-shared-librarian unbounded-context-growth risk so Phase 4 is scoped to test it.
6. **[non-blocking] (F6)** State the ~10-20% bound plainly once in the body (Background), attributed to the RFP, rather than only in a reviewer-facing aside.
7. **[non-blocking] (F7)** Justify or drop `triage` from the list of scoping-consumer target surfaces.
8. **[non-blocking] (F8)** Re-add the RFP's graphify license re-verification as an Open Question or Phase 2 precondition.
9. **[non-blocking] (F9)** Make the source-RFP reference navigable or mark it explicitly as a sibling-repo local path.

## Questions for the Author (surfaced for routing, not blocking)

- **Recall ground truth (ties to F3):** How do you intend to establish the "known true dependent set" for a CRDT-coupled change, given the graph is blind to exactly that coupling by construction? Options as you see them:
  - (a) Human/opus-labeled per fixture, small hand-curated corpus.
  - (b) Union of graph output + a grep-recall floor + observe-site scan, treated as ground truth.
  - (c) Runtime-trace-derived coupling on a live weftwise fixture.
- **CRDT guard strength (ties to F4):** Is an inline caveat + role instruction the intended *production* guard, or do you want a structural brief-format constraint? Pick:
  - (a) Caveat + instruction only; fixture is the sole check (current text).
  - (b) Brief never presents an exhaustive set and always co-surfaces nearby observe/subscribe sites.
  - (c) Diff-size / near-empty-set trigger that forces an unscoped sweep for that round.
