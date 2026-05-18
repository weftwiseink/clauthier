---
review_of: cdocs/proposals/2026-05-18-iterate-agent-capabilities.md
first_authored:
  by: "@claude-opus-4-7"
  at: 2026-05-18T10:05:00-07:00
task_list: cdocs/iterate-skill
type: review
state: live
status: done
tags: [fresh_agent, iterate, reviewer, tool_surface, audit_trail, written_constraints, archive_immediate]
---

# Review: Expand `/cdocs:iterate` Reviewer Capabilities, Delete Dead Sub-Dispatch, Add Audit Tag

## Summary Assessment

The proposal does what it sets out to do: it aligns reviewer tool surface with the stated container-deployed-general-purpose intent, deletes runtime-dead `Task`-from-subagent guidance, and adds a grep-visible audit tag for independent verification.
The four-phase decomposition is coherent, atomically commitable, and ordered for safe partial rollout; the BLUF, Objective, and Implementation Phases agree with each other.
The proposal's load-bearing weakness is that it elides one specific cost of dropping the verifier-subagent (the reviewer is now *both* the producer of empirical evidence and the issuer of the verdict on that evidence, where the prior design separated them) and underspecifies two enforcement-by-side-channel claims (judge polices `n/a` misuse; overseer discards violating reviews) without updating the agents whose roles those claims extend.

Verdict: **Revise** (non-fundamental).
All blocking items are scoped and additive; the proposal's spine is sound.

## Section-by-Section Findings

### BLUF and Objective

The BLUF accurately summarizes the four changes and the underlying intent realignment.
The Objective's "two coupled gaps" framing matches both the prior report's empirical findings and the more recent report's revised analysis.

No findings.

### Background

The background correctly enumerates source artifacts, prior decisions to preserve, and the deployment-intent reframing.
Cross-references to `judge.md` lines 91-93 are accurate and load-bearing for the proposal's "the judge already acknowledges this invariant" argument.

No findings.

### Proposed Solution (item 1: reviewer agent tool surface)

**Finding 1 (non-blocking): the new reviewer constraints are silent about container deployment as a precondition.**

The proposal's "Important Design Decisions / Why constraints become written instructions" argues that container isolation is one of three legs of the trust trade (alongside reviewer freshness and overseer discard-authority).
But the reviewer agent definition itself does not mention container deployment, and `clauthier` ships via marketplace to users who may install in any environment.
A user running `/cdocs:iterate` outside a container loses one of the three legs silently.

Recommendation: add a single line to the reviewer `## Constraints` section noting that the written-instruction trust posture assumes a sandboxed (container or equivalent) runtime, and that operators running outside such a sandbox should consider a narrower tool surface.
This is documentation, not enforcement; it surfaces the assumption at the agent boundary.

**Finding 2 (non-blocking): `Edit` keeps the same written-only constraint it already had, but the proposal does not flag this as a continuation rather than a new trade.**

The reviewer already has `Edit` today with the same written-only-edit-`last_reviewed`-frontmatter constraint; the proposal reuses that text without noting that the `Bash` trade is structurally identical to a trade the loop has already been making for `Edit`.
A reader unfamiliar with the prior reviewer config could read the proposal as inventing the written-constraint posture, when in fact it is extending an existing one.

Recommendation: one short sentence in "Why constraints become written instructions" noting the `Edit` precedent makes the proposal's argument stronger and easier to land.

**Finding 3 (non-blocking): `Pattern A` lists `WebFetch` as a tool the subagent uses to self-investigate, but `WebFetch` is not in the proposed reviewer allowlist.**

Line 71 of the proposal says "the dispatched subagent uses its own tools (`Read`, `Grep`, `Bash`, `WebFetch` where available)".
The new reviewer allowlist (line 56) is `Read, Glob, Grep, Edit, Write, Bash`.
The "where available" hedge papers over the inconsistency, but a reviewer reading the proposal will notice and may add `WebFetch` to make the pattern work, which is a scope creep the proposal did not authorize.

Recommendation: either add `WebFetch` explicitly to the reviewer allowlist (it is a read-only tool and arguably fits the written-constraint regime), or drop it from the Pattern A example.

### Proposed Solution (item 2: sub-dispatch model)

The two-pattern replacement is well-motivated and structurally clean.

**Finding 4 (non-blocking): Pattern B's "structured 'investigation requested' item" is named but not specified.**

The proposal says the subagent returns a "structured 'investigation requested' item in its output" and the overseer reads it.
There is no schema, no required fields, no example structure beyond the prose paraphrase.
The implementer's existing structured uncertainty pattern (`SKILL.md` lines 190-191) is referenced as the analog, but that pattern is itself only one sentence in the skill.

This is a non-blocker because the implementation phase can land prose that is sufficient and the schema can crystallize empirically.
Worth surfacing as a follow-on tracking note.

Recommendation: in Phase 1, when writing Pattern B's "short example of each pattern", include a literal example of the structured request (e.g., a fenced block with a `## Investigation Requested` header, a one-sentence question, and a "context this would unblock" field).
The example anchors the schema without committing to it formally.

### Proposed Solution (item 3: implementer dispatch override + implement skill cleanup)

**Finding 5 (blocking): the `implement/SKILL.md` cleanup scrubs lines 43-44 but leaves a second copy of the dead text at line 71.**

The proposal targets `implement/SKILL.md` lines 43-44 for rewrite.
The same skill at lines 69-72 (the `### Use cdocs skills as appropriate` block) also says:

```
- `/cdocs:report` if the implementation reveals findings worth documenting separately.
```

This is the same `/cdocs:report` dispatch guidance the proposal is trying to make subagent-aware, in a sibling subsection.
Phase 3's verification ("grep invariants on `from a subagent` and the new dispatch language") would not catch this because the line 71 text does not use the phrase "from a subagent": it just says "request `/cdocs:report`" implicitly without the subagent qualifier.

Recommendation: extend Phase 3 to update lines 69-72 with the same "self-investigate or top-level-dispatch only" framing the rewrite of lines 43-44 adopts, and broaden the Phase 3 grep invariant to catch both call-sites (e.g., grep for `/cdocs:report` in `implement/SKILL.md` and verify each call-site is qualified for subagent-vs-top-level context).

**Finding 6 (non-blocking): the new line 271 text assumes the implementer can tell whether it is at top-level or dispatched, but the proposal does not say how.**

The rewritten text at line 271 reads "only available when `/cdocs:implement` itself runs at the top level; subagent-dispatched `/cdocs:implement` should self-investigate or surface the request to its caller".
The implementer has no automatic detection mechanism for "am I at top-level?".
In practice the dispatcher must signal it (the iterate-overseer NOTE addition in Phase 3 does exactly this for the iterate case), but the standalone `/cdocs:implement` path has no such signal.

Recommendation: add a short sentence to the rewritten text that names the signal: "Treat yourself as dispatched if your invocation included an explicit dispatch prompt from a parent agent; treat yourself as top-level if you were invoked directly by the user."
This is imperfect but actionable, and matches how the implementer would actually decide.

### Proposed Solution (item 4: audit tag)

**Finding 7 (blocking): the `[indep-verify: n/a]` policing claim extends the judge's role without updating the judge.**

The proposal's "Edge Cases / `[indep-verify: n/a]` is used as a default to dodge empirical work" (lines 159-163) says "if the overseer marks `n/a` for such a proposal, the judge can flag it on its next invocation and the audit trail makes the mismatch grep-visible".

The current judge agent (`agents/judge.md` lines 53-65) has three verdicts (`continue`, `rotate-implementer`, `escalate`) keyed on loop-progress symptoms (thrashing, stuck-ness, conflicting requirements).
"Verification-tag mismatch with the verification floor" is not on this list.
The proposal asks the judge to enforce policy it has not been told about.

This matters because the proposal's argument for not adopting the verifier-subagent is partly "freshness, not tool restriction, is the independence mechanism" and partly "the overseer's discard-authority and the judge's flag-authority are the enforcement".
The latter half is load-bearing for the proposal but is not implemented by the proposal.

Recommendation: either add a phase to update `judge.md` with explicit guidance to flag `[indep-verify: n/a]` mismatches with the verification floor (a small addition to the judge's "Verdicts" section), or drop the "judge can flag it" sentence and let the audit-trail grep be the sole detection mechanism with the overseer's pre-Accept check as enforcement.

**Finding 8 (blocking): the proposal's own verification floor straddles its own `[indep-verify]` definition.**

The proposal at lines 228-234 (`## Verification Methodology`) states that text-level invariants are inspectable from the diff but behavioral invariants require the live smoke test, which is "the only way to catch 'the agent ignored the new instructions in practice'".

Under the proposal's own definition:
- A `[indep-verify: confirmed]` row requires the review document to cite at least one empirical artifact.
- A `[indep-verify: n/a]` row is for proposals whose verification floor does not require empirical browser/runtime evidence.

The proposal's own verification floor *does* require runtime evidence (the smoke test is mandatory before final Accept by the proposal's own text).
So the proposal cannot be `[indep-verify: n/a]`.
But the Phase 5 NOTE explicitly carves the smoke test out of the review loop ("the live smoke test is a separate top-level run"), which means the loop reviewing this proposal cannot produce a `[indep-verify: confirmed]` row backed by the smoke-test artifact either.

This is not a fatal flaw, but it is exactly the kind of self-test failure the proposal exists to prevent in other places.
Either the tag taxonomy needs a fourth value (something like `[indep-verify: deferred-to-followup]` with a required follow-up reference), or the verification floor needs a structural carve-out for "proposals whose floor cannot be exercised inside the loop reviewing them".

Recommendation: add an explicit clause to the `[indep-verify]` taxonomy covering "the verification floor requires a separate top-level invocation that cannot run inside the review loop", with a required pointer to where the deferred verification will be recorded.
This is the cleanest extension and matches the proposal's own situation literally.

**Finding 9 (non-blocking): `confirmed` requires citing an empirical artifact, but does not require the artifact be reproducible from the citation alone.**

The current text says "`confirmed` requires the corresponding review document to cite at least one empirical artifact path (screenshot, Playwright run output, dev-server log excerpt, curl/HTTP response capture)".
Citing a path is sufficient under this text.

The edge-case section at lines 178-182 acknowledges artifact drift and recommends copying the relevant excerpt into the review document body for ephemeral artifacts.
This is the right answer but is not part of the `confirmed` definition itself; it lives in edge cases and could be missed by a reviewer skimming the convention paragraph.

Recommendation: fold the "inline excerpt for ephemeral artifacts" rule into the `confirmed` definition itself, so it reads "`confirmed` requires the review document to cite at least one empirical artifact path AND, for ephemeral artifacts (test runner output, browser screenshots in `/tmp`), inline the relevant excerpt into the review body".

### Important Design Decisions

**Finding 10 (non-blocking): "Why Option A" elides that the reviewer is now both evidence-producer and verdict-issuer.**

The prior report's recommended hybrid (verifier-subagent + overseer turn) separated *who produces the empirical evidence* from *who issues the verdict on it*: the verifier-subagent had no verdict authority, the reviewer cited the verifier's structured artifact and issued the verdict.
This proposal collapses both roles into the reviewer.
The proposal's argument is that "freshness is the independence mechanism" (true) and that the reviewer cites the artifact in the review document (true), but the collapse loses one specific guarantee: the evidence and the verdict are now produced by the same context.
A reviewer that overcommits to a verdict early can cherry-pick its own empirical evidence to support it.

This is acceptable under the container-deployed-general-purpose intent (and the proposal's argument is internally consistent), but the proposal does not name this cost when explaining why the verifier-subagent design was dropped.

Recommendation: add a sentence to "Why Option A" acknowledging that the verifier-subagent design's evidence-producer/verdict-issuer separation is the specific guarantee being traded for the simpler tool surface, and that the trade is acceptable because (a) the reviewer is fresh per iteration and (b) the empirical artifact lives in the review document where the overseer and any future re-reviewer can re-inspect it.
This is a one-sentence honesty addition that strengthens the design rationale.

### Edge Cases

**Finding 11 (non-blocking): edge cases enumerate single-reviewer failure modes but not the "two reviewers in a row both confirm with the same artifact reference" pattern.**

The proposal handles "reviewer runs a command that mutates state" and "reviewer's empirical check breaks the dev server" individually.
It does not address: in a multi-round loop, the reviewer in round N+1 may reuse the same empirical artifact path the round-N reviewer cited (because they are looking at the same proposal and the same artifact dir).
Is that legitimate independent verification (the artifact is still there, fresh eyes inspect it) or a regression to self-report (the artifact was generated by round-N's reviewer who is no longer in the loop)?

The freshness discipline says the reviewer is fresh per iteration, so re-citing a prior reviewer's artifact is not literally self-citation.
But the audit-trail value of `confirmed` weakens if successive `confirmed` rows reuse the same upstream evidence.

Recommendation: add a single edge-case entry noting that round-N+1 reviewer should produce its own empirical artifact (not re-cite round-N's), and the `confirmed` tag's audit value rests on independent generation per row.
Even if the answer is "re-cite is okay", the question is worth resolving up front.

### Test Plan

**Finding 12 (blocking): the smoke test acceptance criterion at line 221 is overly strict.**

The criterion reads "The overseer does not author an `### Overseer synthesis` empirical-verification subsection (the reviewer owns that work now)".

The overseer may legitimately author an `### Overseer synthesis` for other reasons (judge invocation summary, terminal decision rationale, etc.).
The criterion as written would fail if the overseer writes that section for any reason, which is broader than the proposal actually requires.

Recommendation: tighten to "The `### Overseer synthesis` section, if present, does not contain empirical-verification evidence the reviewer should have produced (i.e., the overseer does not act as a verifier-of-last-resort the way it did in the mermaid loop)".

**Finding 13 (non-blocking): the non-UI proposal smoke test does not verify the `n/a` justification text appears in the iteration row or overseer synthesis.**

Lines 225-227 say the non-UI proposal's row "notes column ends with `[indep-verify: n/a]`. The overseer cites the verification floor as justification for `n/a`".
But the acceptance criterion does not actually require the overseer's citation to appear anywhere checkable; it just states the overseer "cites" it.

Recommendation: tighten to "the iteration row's notes column ends with `[indep-verify: n/a]`, and the verification floor that justifies `n/a` is visible either inline in the row's notes (preferred) or in a one-line `### Overseer synthesis` entry for that iteration".

### Implementation Phases

**Finding 14 (non-blocking): Phase numbering: "Four atomic changes" (line 50) vs five phases (Phase 5 is the smoke test).**

The proposal text consistently says four atomic changes, but the Implementation Phases section runs Phase 1-5 with Phase 5 explicitly "not a commit; a verification step".
A reader counting commits will get four; a reader counting headers will get five.

Recommendation: rename "Phase 5" to "Verification" or "Post-implementation verification" to make the not-a-commit nature explicit in the heading rather than only in the body, and update Implementation Phases preamble (lines 240-242) accordingly.

**Finding 15 (non-blocking): Phase ordering is intentional but the rationale is only one sentence.**

The Phases reorder Proposed Solution items: Phase 1 = item 2, Phase 2 = item 1, Phase 3 = item 3, Phase 4 = item 4.
The reordering is reasonable ("1 makes the new patterns documented, 2 expands the reviewer, 3 propagates the cleanup, 4 closes the audit-trail loop") but a reader cross-referencing the two sections might wonder if the reorder was deliberate.

Recommendation: a short note in Implementation Phases preamble explicitly mapping each Phase to its Proposed Solution item number would remove the cross-section ambiguity for future readers.

### Verification Methodology

See Finding 8 (the proposal's own verification floor straddles its `[indep-verify]` definition).
The Phase 5 NOTE (lines 236-237) correctly identifies that the smoke test cannot run inside the review loop, which is the right structural call but creates the self-test gap noted there.

### Summary section

The closing summary is accurate and the closing NOTE about the verifier-subagent option being intentionally not adopted is appropriately scoped.

## Verdict

**Revise.**

The proposal's spine (reviewer tool expansion, dead-text scrub, audit tag) is sound and the four phases as written are coherent and individually commitable.
The blocking items are additive: a second `implement/SKILL.md` site to scrub, a judge-role policy update or removal of the judge-flag claim, the proposal's own `[indep-verify]` taxonomy gap, and an over-strict smoke-test acceptance criterion.
None of these requires architectural rework; all are scoped edits to the existing proposal.

## Action Items

1. **[blocking] Phase 3 scope extension.**
   Update `plugins/cdocs/skills/implement/SKILL.md` lines 69-72 (the `### Use cdocs skills as appropriate` block) with the same self-investigate / top-level-dispatch framing applied to lines 43-44.
   Broaden the Phase 3 grep invariant to catch both call-sites.

2. **[blocking] Resolve the judge `[indep-verify: n/a]` policing claim.**
   Either add an explicit phase (or expand Phase 4) to update `agents/judge.md`'s Verdicts section with verification-tag-mismatch flagging, or drop the "judge can flag it" sentence from the proposal's edge-case discussion and rely solely on the audit-trail grep + overseer's pre-Accept check.

3. **[blocking] Address the proposal's own verification-floor self-test gap.**
   Add a `[indep-verify: deferred-to-followup]` taxonomy value (or equivalent structural carve-out) for proposals whose verification floor cannot be exercised inside the loop reviewing them, with a required pointer to the deferred verification record.

4. **[blocking] Tighten the smoke-test acceptance criterion at line 221.**
   Replace "The overseer does not author an `### Overseer synthesis` empirical-verification subsection" with "The `### Overseer synthesis` section, if present, does not contain empirical-verification evidence the reviewer should have produced".

5. **[non-blocking] Add container-deployment precondition to the reviewer agent constraints.**
   One line in `agents/reviewer.md`'s new Constraints section noting that the written-instruction trust posture assumes a sandboxed runtime.

6. **[non-blocking] Resolve `WebFetch` inconsistency.**
   Either add `WebFetch` to the reviewer allowlist or remove it from Pattern A's tool list in the new "Subagents cannot dispatch subagents" section.

7. **[non-blocking] Strengthen the "Why Option A" rationale.**
   Add one sentence acknowledging that the verifier-subagent design's evidence-producer/verdict-issuer separation is the specific guarantee being traded, and why the trade is acceptable.

8. **[non-blocking] Specify Pattern B's "structured investigation requested" item with a literal example.**
   Include the example in Phase 1 when writing Pattern B's example block.

9. **[non-blocking] Name the top-level-vs-dispatched detection signal.**
   Extend the rewritten `implement/SKILL.md` text to tell the implementer how to decide whether it is at top-level (e.g., "explicit dispatch prompt from a parent agent" vs. "invoked directly by the user").

10. **[non-blocking] Fold the "inline ephemeral artifact excerpt" rule into the `confirmed` definition itself.**

11. **[non-blocking] Add an edge case for "round-N+1 reviewer reusing round-N's empirical artifact citation".**

12. **[non-blocking] Add the `Edit` precedent to "Why constraints become written instructions".**
    One sentence noting the trade is a continuation of the existing `Edit` posture, not a new trade.

13. **[non-blocking] Rename Phase 5 to "Verification" or "Post-implementation verification".**
    Make the not-a-commit nature explicit in the heading.

14. **[non-blocking] Cross-reference Proposed Solution items with Implementation Phases.**
    A short mapping table or inline parenthetical removes the cross-section ambiguity.

15. **[non-blocking] Tighten the non-UI smoke-test acceptance criterion.**
    Require the `n/a` justification to appear visibly in the iteration row or `### Overseer synthesis`.

## Questions for the User

These are surfaced as multi-choice options per the review skill's preference over blocking:

1. **`[indep-verify]` taxonomy: how to handle proposals whose floor cannot run inside the reviewing loop?**
   - (a) Add a fourth value (`deferred-to-followup` or `out-of-loop`) with a required follow-up reference.
   - (b) Treat such proposals as inherently `[indep-verify: n/a]` for the loop's purposes, with a `> NOTE` in the iteration row explaining the deferral.
   - (c) Forbid this pattern: proposals whose floor cannot run inside the loop must restructure to one that can.

2. **`[indep-verify: n/a]` policing: who owns the mismatch check?**
   - (a) Judge agent: extend `judge.md`'s Verdicts section with verification-tag-mismatch handling.
   - (b) Overseer: pre-Accept check by the overseer, with the judge unchanged.
   - (c) External tooling: a future `/cdocs:audit` skill that greps iteration logs for tag/floor mismatches across the corpus.

3. **`WebFetch` for the reviewer: include or exclude?**
   - (a) Include: it's read-only and complements `Bash`-driven empirical inspection.
   - (b) Exclude: keep the allowlist minimal; the reviewer can use `Bash`+`curl` if HTTP is needed.

4. **Container-deployment precondition: how strongly to surface?**
   - (a) Note in reviewer constraints only.
   - (b) Note in reviewer constraints AND in the iterate skill's Conventions section.
   - (c) Note nowhere; the marketplace README is the right place to document deployment assumptions.
