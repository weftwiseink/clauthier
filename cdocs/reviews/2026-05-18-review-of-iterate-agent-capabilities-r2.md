---
review_of: cdocs/proposals/2026-05-18-iterate-agent-capabilities.md
first_authored:
  by: "@claude-opus-4-7"
  at: 2026-05-18T11:30:00-07:00
task_list: cdocs/iterate-skill
type: review
state: live
status: done
tags: [fresh_agent, rereview_agent, iterate, reviewer, audit_trail, indep_verify_taxonomy, internal_consistency, round_2]
---

# Review (Round 2): Expand `/cdocs:iterate` Reviewer Capabilities, Delete Dead Sub-Dispatch, Add Audit Tag

## Summary Assessment

The revision lands all four round-1 blocking items substantively, not just verbally: the `deferred-to-followup` taxonomy value is defined and demonstrated on this proposal's own implementation devlog (the prototypical case), the judge-flag claim has been removed and replaced with a clearly-named in-loop enforcer (the overseer's pre-Accept check), Phase 3's scope and grep invariant are both broadened to catch the second `/cdocs:report` site in `implement/SKILL.md`, and the smoke-test acceptance criteria for both UI and non-UI runs are now precise enough to be falsifiable.
All 11 non-blockers are also resolved, mostly through one- or two-sentence additions in exactly the right sections.

The remaining issues are internal-consistency drift: three places in the document still describe the world as it was before the revision (a three-value taxonomy, a `Bash`-without-`WebFetch` allowlist in Phase 2, a "Phase 5" heading reference in the Summary, an `implement/SKILL.md`-line-43-44-only per-file inspection item).
These are small mechanical fixes but two of them are load-bearing for the implementer following the document verbatim: Phase 2's allowlist line and the Test Plan's per-file inspection list are what the implementer and post-implementation reviewer will check against, and they currently disagree with the proposal's own design decisions.

Verdict: **Revise** (mechanical only).
The design is Accept-ready; the four internal-consistency fixes should land in the same commit.

## Round-1 Finding Resolution

Each round-1 finding mapped to its current resolution:

| R1 # | Severity | Resolution |
|---|---|---|
| 1 | non-blocking | Resolved at lines 65 (reviewer constraints) and 313 (Phase 4 Conventions note). Both call-sites pointed at; consistent. |
| 2 | non-blocking | Resolved at line 132 ("structurally identical to the trade the loop already makes for the reviewer's existing `Edit`"). |
| 3 | non-blocking | Resolved at line 61 (allowlist) and 62-63 (rationale). See Finding 1 below for a propagation gap. |
| 4 | non-blocking | Resolved at line 83 (literal example specified for Phase 1 to land). |
| 5 | blocking | Resolved at lines 92-94 (Proposed Solution scope extension to include lines 69-72) and 302-304 (Phase 3 covers both sites; grep invariant broadened to "every `/cdocs:report` call-site"). See Finding 2 below for an unpropagated check item. |
| 6 | non-blocking | Resolved at line 301 (rewritten implement-skill text now includes "Treat yourself as dispatched if your invocation included an explicit dispatch prompt from a parent agent; treat yourself as top-level if you were invoked directly by the user."). |
| 7 | blocking | Resolved at lines 180-182 (judge-flag claim dropped; "the overseer's pre-Accept check is the in-loop enforcement point"; explicit reasoning that extending the judge would re-implement the overseer's job at the wrong layer, with cross-reference to judge.md lines 91-93). |
| 8 | blocking | Resolved at lines 105-107 (taxonomy adds `deferred-to-followup` with required follow-up pointer) and lines 263-266 (NOTE marks this proposal's own devlog as the prototypical case). See Finding 3 below for the inspection-checklist propagation. |
| 9 | non-blocking | Resolved at line 101 (ephemeral-excerpt rule folded into `confirmed` definition itself rather than living in edge cases). |
| 10 | non-blocking | Resolved at lines 122-125 (evidence-producer / verdict-issuer trade explicitly named; the two conditions making the trade acceptable enumerated). |
| 11 | non-blocking | Resolved at lines 203-209 (full edge case for round-N+1 artifact reuse, with the explicit "per-row, not loop-aggregate" rule). |
| 12 | blocking | Resolved at lines 248-249 ("if present, does not contain empirical-verification evidence the reviewer should have produced" plus an explicit positive carve-out for legitimate overseer-synthesis content). |
| 13 | non-blocking | Resolved at line 272 (Implementation Phases preamble) and line 319 (heading is now `### Verification: Smoke test (live, separate top-level invocation; not a commit)`). See Finding 4 below for one unpropagated reference. |
| 14 | non-blocking | Resolved at line 271 ("Phase 1 makes the new patterns documented (Proposed Solution item 2), Phase 2 expands the reviewer (item 1), ..."). |
| 15 | non-blocking | Resolved at lines 252-253 (non-UI smoke-test criterion now requires the `n/a` justification to be visible either in the notes column or in a one-line `### Overseer synthesis` entry). |

All 15 round-1 findings are resolved at the design level; four have propagation gaps surfaced below.

## Section-by-Section Findings

### Proposed Solution item 1 vs Phase 2 (reviewer allowlist)

**Finding 1 (blocking): Phase 2's `tools` instruction omits `WebFetch`.**

Proposed Solution line 61 sets the new reviewer allowlist to `Read, Glob, Grep, Edit, Write, Bash, WebFetch` and dedicates lines 62-63 to justifying `WebFetch`'s inclusion (read-only, required by Pattern A's external-doc lookup).
Phase 2 line 288 says "Update `tools` frontmatter to `Read, Glob, Grep, Edit, Write, Bash`": no `WebFetch`.

An implementer working phase-by-phase from the Implementation Phases section will land the wrong allowlist.
A reviewer auditing the diff against the Test Plan's "frontmatter `tools` line matches the new allowlist exactly" (line 223) catches the mismatch against Proposed Solution only if it cross-references back to line 61; the Phase 2 directive will look internally consistent.

This is the same shape of bug the proposal exists to prevent in `/cdocs:implement` (two call-sites for the same instruction, only one updated).

Recommendation: update Phase 2 line 288 to `Read, Glob, Grep, Edit, Write, Bash, WebFetch`.
Optionally add an inline note in Phase 2's verification line that `WebFetch` is included per Proposed Solution item 1 rationale.

### Test Plan per-file inspection vs Phase 3 scope

**Finding 2 (blocking): Test Plan inspection still lists only `implement/SKILL.md` lines 43-44.**

Test Plan line 230 says "`implement/SKILL.md` lines 43-44 are rewritten to the self-investigate / top-level-only-dispatch framing."
Phase 3 (lines 297-305) and Proposed Solution item 3 (lines 92-94) both cover *two* sites in `implement/SKILL.md`: lines 43-44 and lines 69-72.
The Test Plan's per-file inspection list does not mention lines 69-72.

A reviewer of the implementation diff that uses the Test Plan as a checklist will miss the second rewrite if Phase 3 was partially applied.

Recommendation: add a sibling bullet to line 230 covering lines 69-72: "`implement/SKILL.md` lines 69-72 (the `### Use cdocs skills as appropriate` block) are rewritten with the same self-investigate / top-level-only-dispatch framing as lines 43-44."

Also: the Test Plan's grep invariants (lines 235-238) include `rg "from a subagent"` but the lines-69-72 site does not currently use that phrase, so the existing grep alone will not catch a half-applied Phase 3.
Phase 3's own verification at line 304 calls for "grep invariants on `from a subagent` and on every `/cdocs:report` call-site in `implement/SKILL.md` (each must be qualified for subagent-vs-top-level context)".
The Test Plan's grep section should mirror that second invariant: `rg "/cdocs:report" plugins/cdocs/skills/implement/SKILL.md` should be inspected to confirm every hit is qualified for top-level-vs-dispatched context.

### Audit-tag taxonomy: per-file inspection list is stale

**Finding 3 (blocking): Test Plan line 229 says "lists the three values".**

The audit tag now has four values: `confirmed`, `n/a`, `deferred-to-followup`, `skipped`.
Phase 4 (line 311) correctly enumerates all four.
The Test Plan's per-file inspection bullet at line 229 still says "lists the three values".

A reviewer post-implementation using the Test Plan as a checklist could pass a diff that omits one of the four values from the `SKILL.md` convention paragraph.
This is the same propagation gap the proposal is making `/cdocs:implement` more resistant to in a parallel context.

Recommendation: update line 229 to "lists the four values" (or "lists each of `confirmed`, `n/a`, `deferred-to-followup`, `skipped`").

### Summary section: stale Phase-number reference

**Finding 4 (non-blocking): Summary line 332 still says "The smoke test in Phase 5".**

The Implementation Phases section was renamed: Phase 5 is now "Verification" (line 319).
Summary line 332 reads "The smoke test in Phase 5 is the only behavioral check; everything else is artifact-level invariants verifiable from the diff."

This is cosmetic but it's the same kind of dangling reference the round-1 review flagged at Finding 14 (cross-section ambiguity).

Recommendation: replace "Phase 5" with "the Verification step" in line 332.

### `deferred-to-followup` precision

**Finding 5 (non-blocking): the assigner for `deferred-to-followup` is unnamed.**

The taxonomy paragraph (lines 100-108) names the assigner explicitly for `n/a` ("The overseer assigns `n/a` based on the verification floor stated at Turn 0", line 104) and for `skipped` ("the overseer must justify it", line 108).
For `deferred-to-followup` (lines 105-107), no assigner is named.

Read charitably, the overseer is the assigner for all four values; read uncharitably, an implementer or reviewer could claim `deferred-to-followup` authority unilaterally.
The follow-up-pointer requirement is the structural check against abuse, but the social check (who decides this row gets `deferred-to-followup`) is the assigner.

Recommendation: add a half-sentence to line 105: "The overseer assigns `deferred-to-followup` and the assignment must include..." or restructure the four definitions to share a leading sentence: "The overseer assigns the tag for each row based on the verification floor stated at Turn 0 and the iteration's actual content."

This is non-blocking because the existing text strongly implies overseer assignment and the follow-up-pointer is the real abuse-prevention mechanism, but the consistency across the four values is uneven and a future reader will notice.

**Finding 6 (non-blocking): follow-up-pointer resolution is not enforced.**

The taxonomy at line 106 requires `deferred-to-followup` to include "a pointer to where the deferred verification will be recorded (a follow-up devlog path or a tracking task identifier)".
The pointer is checked at row-write time but no mechanism is described for ensuring the pointed-at follow-up actually materializes.
A `deferred-to-followup` row whose pointer targets a devlog that never gets created has the same auditing weakness as `skipped` without the fail-loud signal.

This is not a fatal flaw for the proposal as written: the proposal's prototypical case (its own implementation devlog deferring to the smoke-test devlog) is small and the operator is the user, so the follow-up will be obvious.
But in a marketplace deployment where other authors use `/cdocs:iterate` and assign `deferred-to-followup` liberally, the pointer-without-resolution gap is the next class of audit-trail bug to surface.

Recommendation (optional): add one sentence to the taxonomy noting that the follow-up pointer is itself an audit obligation; a `/cdocs:status` or `/cdocs:audit` pass that finds an unresolved `deferred-to-followup` pointer older than a threshold is a future enforcement vector.
This is forward-looking and the proposal could legitimately defer it; surfacing the gap in the proposal text is sufficient.

### Internal consistency: counts and enumerations

The four edits above are internal-consistency drift between sections that were updated for the revision and sections that were not.
The pattern is the proposal's design decisions are sharpest in Proposed Solution and Phase descriptions; the Test Plan and Summary sections did not get the same care.

Worth a single explicit consistency pass before Accept.

### New material added in revision: cross-checks

**Pattern B literal example (line 83):** the description specifies a fenced block with `## Investigation Requested` header, a one-sentence question, and a "context this would unblock" line.
The Phase 1 instruction (line 279) calls for "one example each" of Pattern A and Pattern B.
Both call-sites agree.
The literal example in line 83 reads as the schema definition; the actual fenced-block markdown will be authored when Phase 1 lands.
This is acceptable for a proposal: the schema is precise enough to land consistently.

**Round-N+1 edge case (lines 203-209):** the rule "a `[indep-verify: confirmed]` row must rest on an empirical artifact the round-N reviewer produced *during its own review turn*" is precise and grep-checkable in spirit (the review document timestamp vs. the cited artifact's mtime; the review document's own text describing the artifact production).
In practice it relies on the reviewer's diligence to not silently re-cite a prior artifact, but this is the same trust posture the rest of the proposal adopts and is internally consistent.

**Evidence-producer vs verdict-issuer trade (lines 122-125):** clean, honest acknowledgement.
The two conditions making the trade acceptable (reviewer freshness; artifact lives in review doc) are correctly stated and align with the rest of the proposal.

**Container-deployment precondition (lines 65, 313):** both call-sites agree.
The reviewer constraints surface it at the agent boundary; the iterate skill's Conventions section surfaces it at the loop boundary.
A user reading either path encounters the precondition.

**Edit precedent in "Why constraints become written instructions" (line 132):** correctly identifies that the `Bash`/`WebFetch` trade is a continuation of the `Edit`-with-written-constraint posture, not a new trade.

### Spine integrity

The proposal's spine (reviewer tool expansion with written constraints; second-order dispatch text deletion; audit tag with four-value taxonomy; implement-skill cleanup in lockstep) is unchanged from round 1 and remains sound.
The revisions are additive and clarifying; nothing in the round-2 text undermines the round-1 design.

## Verdict

**Revise (mechanical).**

All round-1 blocking and non-blocking items are substantively resolved.
The remaining work is four small consistency fixes that should land before Accept:

- Phase 2 allowlist line must include `WebFetch` (Finding 1).
- Test Plan per-file inspection list must cover `implement/SKILL.md` lines 69-72 (Finding 2).
- Test Plan per-file inspection bullet for the taxonomy must say "four values" not "three values" (Finding 3).
- Summary line 332 should say "the Verification step" not "Phase 5" (Finding 4).

Findings 5 and 6 are non-blocking and surface refinements that are optional for this round.

Once Findings 1-4 land, the proposal is Accept-ready.

## Action Items

1. **[blocking] Fix Phase 2 allowlist.**
   Update line 288: `Read, Glob, Grep, Edit, Write, Bash` -> `Read, Glob, Grep, Edit, Write, Bash, WebFetch`.

2. **[blocking] Extend Test Plan per-file inspection.**
   Add a bullet after line 230 covering `implement/SKILL.md` lines 69-72.
   Add a grep invariant to lines 235-238: `rg "/cdocs:report" plugins/cdocs/skills/implement/SKILL.md` should be checked to confirm every hit is qualified for top-level-vs-dispatched context (mirroring Phase 3's verification at line 304).

3. **[blocking] Fix the taxonomy-value count in Test Plan.**
   Update line 229: "lists the three values" -> "lists the four values" (or enumerate them).

4. **[non-blocking] Fix Summary section's stale Phase-number reference.**
   Line 332: "Phase 5" -> "the Verification step".

5. **[non-blocking] Name `deferred-to-followup`'s assigner.**
   Add half a sentence at line 105 noting the overseer assigns the tag, or restructure the four definitions to share a leading assigner sentence.

6. **[non-blocking] Surface the follow-up-pointer-resolution gap as forward-looking work.**
   One sentence in the taxonomy paragraph or Edge Cases noting that an unresolved `deferred-to-followup` pointer is the next audit-trail bug class and is candidate for a future `/cdocs:audit` enforcement vector.

## Questions for the User

These surface the remaining design ambiguity as multi-choice options per the review skill's preference:

1. **`deferred-to-followup` assigner clarity.**
   The proposal names the overseer as assigner for `n/a` and `skipped` but not for `deferred-to-followup`.
   - (a) Explicitly name the overseer as assigner in the `deferred-to-followup` definition.
   - (b) Restructure the four definitions to share a leading "the overseer assigns the tag based on the verification floor stated at Turn 0" sentence, removing per-value repetition.
   - (c) Leave as-is: the assigner is implicit from the surrounding text.

2. **Follow-up-pointer resolution enforcement.**
   `deferred-to-followup` requires a pointer to a follow-up devlog or tracking task; resolution of that follow-up is not enforced.
   - (a) Note the gap explicitly as forward-looking work (one sentence in the proposal, no mechanism added).
   - (b) Add an enforcement obligation: the overseer revisits unresolved pointers at the start of subsequent loops touching the same proposal.
   - (c) Defer entirely; the marketplace operator's audit practices are out of scope.

3. **Test Plan grep coverage for `/cdocs:report` qualifier.**
   Phase 3 broadens its verification to require every `/cdocs:report` call-site in `implement/SKILL.md` to be qualified for subagent-vs-top-level context.
   The Test Plan's grep section does not mirror this.
   - (a) Mirror the broader invariant in the Test Plan grep section (add `rg "/cdocs:report" plugins/cdocs/skills/implement/SKILL.md` with each hit inspected).
   - (b) Leave the Test Plan tight; Phase 3 owns its own verification.
   - (c) Move the broader invariant into the Test Plan and remove the duplication from Phase 3.
