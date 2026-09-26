---
review_of: cdocs/reports/2026-09-26-connectome-synthesis.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-26T17:20:00-07:00
task_list: cdocs/connectome-research
type: review
state: live
status: done
tags: [fresh_agent, synthesis_faithfulness, identity_fairness, motivated_reasoning, evidence_grading, falsifiability, internal_consistency]
---

# Review: Connectome vs cdocs: Fit, Identity, and What to Adopt

## Summary Assessment

The report synthesizes the three accepted connectome-arc inputs (A deep dive, B landscape, C cdocs-as-memory) into three things: a "different problems" framing, an analysis of identity split into its functions, and six ranked adoption options with evidence grades and falsifiers.
It is strong work.
Nearly every factual claim traces to its source.
The upstream review caveats are mostly carried through.
The identity section avoids dismissing Connectome on its welfare framing, and in places credits values-driven design as good engineering.
Four problems remain, and they follow one pattern: the synthesis applies stricter standards to identity than to cdocs.
- The planned identity experiment (option 4) removes the parts that make it identity, yet the report says a null result would "weakly refute" identity.
- Option 4's falsifier sets an absolute error threshold that cdocs' own documents are never measured against.
- Several risks listed against identity also apply to cdocs, and the report never says so.
- The "overlap" finding contradicts itself.

Option 1's evidence grade is also inflated.
Verdict: **Revise**. The fixes are to framing and grading, not to the research.

## Verification Log

| Claim | Result |
|---|---|
| Workspace "your durable, verbatim memory" (`AGENT-MEMORY-GUIDE.md:156-160`) | Matches A:96. |
| "68 initiations": the fix was ordering, not a fact check | Matches A:506-507. |
| Re-claiming others' lives observed 2026-07-27; witnessed-voice prompt | Matches A:454,517. |
| Model binding is operator doctrine; `compressionModel` is separable | Matches A:384,544. |
| Triumvirate coordinates via shared filesystem and Zulip | Matches A:408. |
| hermes-autobio has a CC session importer; 100-150 commits/month; licensing unclear | Matches A:80-86,529-530,565. |
| 7-hour stall leading to `OverBudgetError`; images decay; lessons decay only via `demote` | Matches A:417-418,520. |
| DreamBench-SWE 11.7% vs 45-54%, single author | Matches B:244. The derived "33-42 points" is arithmetically correct. |
| Poisoning 99.8% / 60-89% (arXiv:2605.15338) | Matches B:63. |
| Kim et al. "meta-knowledge, such as validation routines" | The quote matches B:243. How the synthesis uses it is a stretch (F7). |
| Gloaguen ~20%, CTXbench subset | Matches B:58,241. |
| "Persistent reviewer or overseer role whose judgments stay calibrated" | Matches B:289. |
| Claude Code 200-line `MEMORY.md` | Matches B:52,204. |
| 8→4 re-reads, 334K→173K | Matches C (from `devlog-methodology-value.md`). |
| Transcript spot-check: 13 JSONL files, oldest 2026-03-19 | Verified in `~/.claude/projects/-var-home-mjr-code-weft-clauthier-main/`. Coverage is incomplete, though (see F9). |
| `2026-09-20-read-source-attribution.md`: no agent-initiated eviction | Verified (line 126). |
| "A's round 2 pending at time of writing" | **Stale.** A's `last_reviewed` records round 2 as accepted at 16:45, and its review log confirms it. |

## Section-by-Section Findings

### BLUF and Key Findings

**F1 [blocking] The overlap finding contradicts itself.**
Key Finding 2 says the real overlap "is narrower than it looks, and it is the verbatim side channel."
The Core Contrast then lists five overlaps: verbatim notes, two vantages, consolidation, distilled lessons, and file-based coordination.
The mermaid diagram draws three.
The reader, and the Artifact that Recommendation 5 says will "lead with ... the verbatim-notes overlap," cannot tell whether the overlap is one thing or five.
The accurate statement has tiers:
- One *functional equivalence*: workspace notes and the cdocs corpus.
- Three *partial analogues*: handoff ≈ merge, rules ≈ lessons, vantage by doc type ≈ as-of rule.
- One *convergent practice*: file-based multi-agent coordination.

State it that way in the Key Finding.
"Narrower than it looks" is also unsupported: nothing earlier suggests how broad it looked.

**F2 [blocking, fairness] Risk accounting is asymmetric.**
Several risks presented as costs of identity are properties of any automated or agent-written persistent memory, and cdocs has some of them:
- **Runaway false memories.** The "68 initiations" mechanism is an unverified automated summarizer, not first-person voice. The report's own Net says the case against "rests mostly on the voice," but this, its lead item, does not. It argues against *unreviewed automated consolidation*. That constrains option 1's distill pass as much as it constrains identity, which option 1 partly acknowledges.
- **Attack surface.** The poisoning figures apply to any persistent memory that agents read back. By C's account, the cdocs corpus is agent-written and mostly agent-reviewed. Attributing this risk only to "an unreviewed self" understates cdocs' exposure.
- **The Side-by-Side "Failure modes" consequence.** "Connectome fails by believing wrong things fluently; cdocs fails by not finding or not writing" contradicts its own cdocs cell. That cell lists "stale docs indistinguishable from live ones by grep," which is believing wrong things. A devlog asserting "tests pass" is the same failure as the "I fixed the auth bug" example.
- **"cdocs already captures that value"** (Key Findings, DreamBench). B explicitly says DreamBench "does not establish superiority among memory architectures." Its tasks hinge on non-inferable earlier-session evidence, which cdocs captures only if a devlog recorded it. That evidence equally supports Connectome's lossless archive and option 3.

The fix: tag each item in "The case against" as *identity/voice-specific* (as-of vantage, re-claiming others' lives, model binding) or *general to agent-written memory, shared by cdocs to degree X*. Then correct the failure-modes consequence and the DreamBench sentence.
The brief for this synthesis was explicitly "no tilt toward cdocs," and this is where the tilt shows.

### The Identity Question

**F3 [blocking] The identity experiment cannot refute identity.**
Net says: "If that design shows no gain, identity for coding is weakly refuted in this setting."
But the design (option 4) removes almost everything that makes it identity:
- first person
- as-of vantage
- self-authored content without verification
- model binding
- per workstream, even the *persistent self*

A per-workstream, third-person, cited notes file is essentially the scratchpoint in C and `2026-09-22-chat-record-scratchpoint-design.md`.
A null result would refute "agent-authored working notes beyond handoffs," not identity.
Either scope the conclusion ("a null result weakly refutes the *functional* case for identity in coding; the voice and continuity-of-self hypotheses stay untested"), or make the per-role, cross-workstream variant the required arm so that some persistence of self is actually tested.
The Open Question "Is there a middle ground on voice?" already concedes voice goes untested, so the Net should agree with it.

Non-blocking:
- The "fewer re-onboarding costs" bullet (8→4 re-reads, DreamBench) is evidence for *memory*, not *identity*. It does not separate an agent's own memory from a shared handoff. Say that, so the case for identity is not padded with non-discriminating evidence.
- **F7.** Kim et al.'s "meta-knowledge, such as validation routines" is procedural knowledge of how to validate. It is not self-knowledge of the form "my claims of X were wrong N times." Using it to support self-knowledge (and option 5's grade) stretches the source. If anything it points to rules or lessons. Soften to "adjacent."
- The Side-by-Side line "First person protects voice, not accuracy. cdocs' neutral voice is easier to verify against diffs and tests" has no source. Verifiability comes from citations, not from grammatical person. Label it inference or drop it.
- "A self that curates its own history drifts toward a flattering history" is inference. A marks the sycophancy risk as mechanism-plus-inference, not observed. Label it.
- The "Working-state continuity" row omits Pillar 3 durable specialists, which C calls "the closest analogue to persistent identity." They are also the natural host for option 5, so list them.
- Context says "This report follows" B's requirement not to score Connectome only on coding metrics. The comparison table's only consequence column is coding-workflow, though. The report's own Recommendation 5 admits the evaluation axis is missing, so "follows" is too strong. Either add a short "on its own terms" line (what Connectome achieves for continuity and consistency), or say "acknowledges" rather than "follows."

### Adoption Options

**F4 [blocking] Option 4's falsifier holds identity to a standard cdocs is not held to.**
"Unsupported claims at a meaningful rate (e.g. >5%)" is an absolute bar.
No such audit exists for devlogs, handoffs, or reviews, and C records that cdocs is agent-written and mostly agent-reviewed.
Make the falsifier comparative: sample handoff and devlog claims under the same audit, and falsify only if the notes' unsupported-claim rate is materially worse than that baseline, or if resumption does not improve.
The same applies to option 5's "drifts toward self-flattering summaries on audit": define the audit and the baseline.

**F5 [blocking] Option 1's evidence grade is inflated.**
The **B** cites ForgetEval (general memory stores, not doc supersession), SWE-ContextBench and Kim et al. (abstraction, which is the distill half), and vendor diff-emitting passes.
None of these measures the falsified quantity: agents citing superseded docs less once `supersedes` links exist.
Nor does any measure whether *human* review of consolidation beats agent review in coding; that part rests on a vendor trend (B-by-consistency at best).
Split the grade: distillation into abstracted lessons **B** (arguably A-leaning, given SWE-ContextBench measured it in coding), supersession links **C/D**, human-review gate **B** (product trend).
Also carry B's closing NOTE: the 2026 arXiv sources were read at abstract level, several are single-author and unreviewed.
This matters because the grade scale defines A as "measured ... by independent work" and the table leans on these papers throughout.

Non-blocking:
- Option 2 ranks above option 3 despite carrying the only independent coding measurement, which is negative (**A-negative**, Gloaguen). The ranking may still hold on cost, but say so explicitly. Better: state that the ranking assumes the unpinned mitigation, because the pinned variant has the negative result.
- **F9.** The option 3 cost and the Key Findings line "closing this gap is mostly linking and retention, not capture" overstate how complete the transcripts are.
  - Transcripts are keyed by cwd path. This repo's sessions are split across at least five project directories (`-var-home-...-clauthier`, `-...-clauthier-main`, `-workspace-clauthier-main`, worktree paths), with about 40 top-level JSONL files in total against 87 devlogs.
  - Sessions run in other containers, or remotely, are absent.
  - `cleanupPeriodDays` is 99999 on this machine, not the default, so other machines may be pruning.

  Add a coverage caveat, and a falsifier arm for "the link resolved to a missing transcript."
- **F8.** Option 4 overlaps the unbuilt scratchpoint design (agent-authored working-state checkpoint for the overseer and durable specialists) as much as option 3 overlaps the chat record. Add the same "decide before building either" note.
- Option 6's falsifier ("cache-read share of subagent input tokens") is good and cheap. Consider promoting the narrow variant into the ranked list on its own, because it is independent of the harness limitation.

### "Different problems" framing

Mostly precise: continuity per agent versus per project, and per-turn assembly versus ad hoc pull, are the right axes, and "Stated precisely" is well done.
Non-blocking: say when the problems converge, namely a long-lived, single-project specialist such as a persistent reviewer or a Pillar 3 specialist carried across arcs.
That is exactly the scenario options 4-5 probe.
Without that condition, "different problems" can be read as "nothing to learn," which the rest of the report rightly rejects.

### Context, Open Questions, conventions

- Non-blocking, stale: A is accepted (round 2). Update the Context bullet for A and the Open Question "A's round-2 review was pending." The production-folding-strategy and no-published-evaluation caveats still stand.
- The caveat line "Mint calls set no temperature, so mint text is not reproducible" is accurate. Consider attributing it to A's round-1 review, as the other caveats are attributed.
- Writing conventions: clean. There are no em-dashes, the BLUF matches the body except where F1-F3 require changes, and the mermaid diagram is used appropriately.

### Recommendations

These follow from the options, and deferring 5 and 6 until 4 reports is sound.
After F3, Recommendation 3 should state what a null result will and will not conclude.
After F4, it should name the baseline audit alongside the notes audit.

## Verdict

**Revise.**
The sourcing is faithful and the structure is right for the Artifact.
Four framing and grading fixes are needed before acceptance:
- tier the overlap
- tag risks as identity-specific or shared with cdocs
- scope what the identity experiment can refute
- make option 4's falsifier comparative and split option 1's evidence grade

None of these requires new research.

## Action Items

1. [blocking] Restate Key Finding 2 as a tiered overlap: one functional equivalence (workspace and corpus), three partial analogues, one convergent practice. Drop "narrower than it looks," and align the mermaid diagram and Recommendation 5.
2. [blocking] In "The case against," tag each risk as identity/voice-specific or general to agent-written memory, and say where cdocs shares it (false memories from unverified consolidation, poisoning). Fix the Side-by-Side failure-modes consequence, which contradicts its own "stale docs" cell. Replace "cdocs already captures that value" with a statement that DreamBench does not discriminate between architectures.
3. [blocking] Scope the Net and option 4: a null result weakly refutes the functional case, not voice or continuity of self. Or require the per-role, cross-workstream arm.
4. [blocking] Make option 4's (and option 5's) falsifier comparative against a same-method audit of handoff and devlog claims, not an absolute >5%.
5. [blocking] Split option 1's evidence grade by component (distill **B**, supersession links **C/D**, human-review gate **B** by product trend). Carry B's abstract-level, single-author caveat on the 2026 arXiv sources.
6. [non-blocking] Mark A as accepted (round 2) in Context and Open Questions.
7. [non-blocking] Label the "neutral voice easier to verify" and "drifts toward a flattering history" lines as inference. Soften the Kim et al. to self-knowledge link.
8. [non-blocking] Note that the re-onboarding and DreamBench evidence supports memory, not identity specifically. Add Pillar 3 durable specialists to the identity table.
9. [non-blocking] Change "This report follows that" to "acknowledges," or add an on-its-own-terms line for Connectome.
10. [non-blocking] Add a transcript-coverage caveat to option 3 (path-keyed split across about five dirs, sessions from other machines absent, retention setting per machine).
11. [non-blocking] Add a note on the overlap between option 4 and the scratchpoint design. Justify ranking option 2 above option 3 given the A-negative result, or tie the rank to the unpinned variant.
12. [non-blocking] State when "different problems" converge (a long-lived single-project specialist).

## Questions for the Author

1. What should option 4 test?
   - (a) The functional hypothesis only (per-workstream notes), with the Net scoped to match. Cheapest.
   - (b) A per-role, cross-workstream arm, so some continuity of self is tested (recommended if human audit time exists).
   - (c) Both arms, with the per-workstream arm doubling as the scratchpoint evaluation.
2. For the Artifact, how should the overlap be presented?
   - (a) The tiered overlap from item 1 (recommended).
   - (b) The verbatim-notes equivalence only, with the analogues in a footnote.
   - (c) All five as peers.
3. Who supplies the baseline audit for item 4?
   - (a) The same human auditor, sampling both notes and handoffs.
   - (b) An agent audit checked against git and tests, with human spot-checks.
   - (c) Defer until an auditor is named (which blocks option 4's RFP).
