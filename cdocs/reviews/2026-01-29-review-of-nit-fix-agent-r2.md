---
review_of: cdocs/proposals/2026-01-29-nit-fix-agent.md
first_authored:
  by: "@claude-sonnet-4-20250514"
  at: 2026-01-29T17:45:00-08:00
task_list: cdocs/nit-fix-v2
type: review
state: live
status: done
tags: [rereview_agent, writing_conventions, subagent_patterns, plugin_idioms]
---

# Review of Nit Fix Agent Proposal (Round 2)

> BLUF(sonnet/cdocs/nit-fix-v2): All blocking issues from round 1 have been adequately addressed.
> Phase 0 validation has been added with clear success/failure paths, the mechanical vs. judgment classification mechanism is now specified via a prompt-guided heuristic with fallback markup, protected zone detection logic is explicit, sentence-splitting rules are detailed, and Appendix A provides the full agent body.
> One remaining concern: the haiku-based classification heuristic is ambitious and Phase 0 may reveal it needs the markup fallback or model upgrade.
> Verdict: **Accept** - the proposal is implementation-ready with Phase 0 as the appropriate gate.

## Summary Assessment

The round 2 revision successfully addresses all six blocking issues from the previous review.
The proposal now specifies the classification mechanism (prompt-guided heuristic with explicit fallback to HTML comment markup), provides the full agent body in Appendix A, details protected zone detection logic across six zone types, specifies sentence-splitting boundary rules with abbreviation handling, and adds Phase 0 validation as the first implementation step.
The most important finding is that the classification mechanism is ambitious: asking haiku to infer mechanical vs. judgment-required from convention text alone may fail in Phase 0, but the proposal correctly positions this as a validation gate with a clear fallback strategy.
The verdict is **Accept**: all blocking concerns are resolved and the proposal provides a sound implementation plan.

## Section-by-Section Findings

### Frontmatter

**Finding:** Frontmatter correctly reflects round 1 review feedback.
`last_reviewed.round: 1` indicates this is the first review cycle.
The `status: review_ready` is appropriate.

**Category:** Non-blocking.

### Round 1 Blocking Issue 1: Classification Mechanism

**Previous finding:** "The mechanical vs. judgment-required classification mechanism is underspecified. The proposal must explain how haiku determines this boundary from reading the rules file."

**Resolution:** Lines 108-122 now specify the classification mechanism.
The agent body (Appendix A, lines 416-422) provides a clear principle: "A convention is MECHANICAL if the fix preserves meaning. A convention is JUDGMENT-REQUIRED if fixing requires understanding what the author meant."
The proposal acknowledges this is a heuristic (line 116: "haiku may misclassify edge cases") and provides a fallback (lines 119-121): if Phase 0 shows misclassification, add explicit `<!-- MECHANICAL -->` or `<!-- JUDGMENT -->` HTML comments to `writing-conventions.md`.

**Assessment:** This is a sound approach.
The principle is clear enough for haiku to apply to most conventions, and the fallback preserves the "no hardcoded rules" constraint while giving clearer signals.
The Phase 0 validation (lines 321-333) tests this directly with expected classifications listed.

**Category:** Resolved.

### Round 1 Blocking Issue 2: Agent Body

**Previous finding:** "Provide the full agent body (prompt) or explicitly defer it to Phase 1 with a rationale."

**Resolution:** Appendix A (lines 388-483) provides the complete agent body as a markdown document ready for `plugins/cdocs/agents/nit-fix.md`.
The body includes: startup instructions (read rules), classification principle, protected zone definitions, processing steps with specific logic for each mechanical convention, output format, and constraints.

**Assessment:** The agent body is comprehensive and follows the triage agent pattern.
The level of detail is appropriate: specific enough to guide haiku but not so prescriptive that it hardcodes conventions.

**Category:** Resolved.

### Round 1 Blocking Issue 3: Protected Zone Detection

**Previous finding:** "Specify protected zone detection logic: how are frontmatter boundaries, code blocks, inline code, and tables identified?"

**Resolution:** Lines 145-156 now provide explicit detection logic for six zone types:
1. YAML frontmatter: first block delimited by `---` on line 1.
2. Fenced code blocks: lines between `` ``` `` delimiters.
3. Indented code blocks: lines indented 4+ spaces or 1+ tab following a blank line.
4. Inline code: text between single backticks.
5. Tables: lines starting with `|`.
6. HTML comments: `<!-- ... -->` blocks.

Lines 154-156 add a NOTE about nested code blocks in blockquotes, acknowledging this as a best-effort heuristic rather than full markdown parsing.

**Assessment:** The detection logic is clearly specified.
The acknowledgment that this is prompt-guided heuristics (not infrastructure-enforced, per line 142) is consistent with the triage pattern and acceptable given the constrained tool surface.
Edge case 6 (lines 311-317) addresses detection failures with appropriate mitigation.

**Category:** Resolved.

### Round 1 Blocking Issue 4: Sentence-Splitting Detection Logic

**Previous finding:** "Specify sentence-splitting detection logic for edge case 2: what regex or rules define a 'clear sentence boundary'?"

**Resolution:** Lines 276-287 and Appendix A lines 443-444 specify the boundary detection rules:
- Sentence boundary: period/!/? followed by space followed by capital letter.
- Skip if: period follows known abbreviations (e.g., i.e., etc., vs., Dr., Mr., Mrs., St., No., Vol.).
- Skip if: period inside inline code (between backticks).
- Skip if: period inside URL (preceded by `://` or followed by TLD pattern).
- Skip if: line inside protected zone.
- When uncertain: report as judgment-required.

Lines 284-287 provide expected behavior examples including the tricky URL-adjacent case.

**Assessment:** The rules are sufficiently detailed for implementation.
The URL case note (lines 287: "if Phase 0 shows haiku mishandling it, the agent can report URL-adjacent splits as judgment-required") is a good pragmatic escape hatch.

**Category:** Resolved.

### Round 1 Blocking Issue 5: Test Plan Expected Behavior

**Previous finding:** "Expand Test Plan test cases 4, 6, and 7 with expected behavior and ground truth definitions."

**Resolution:**
- Test 4 (now test 8, lines 340-341): specifies input violations and expected output with ground truth comparison to hand-edited file.
- Test 6 (now test 10, lines 342): specifies expected behavior (zero modifications) and verification method (diff before/after).
- Test 7 (now test 11, lines 343-346): specifies three test cases with expected split counts and clear input/output examples.

**Assessment:** Expected behaviors are now well-defined and verifiable.

**Category:** Resolved.

### Round 1 Blocking Issue 6: Phase 0 Validation

**Previous finding:** "Add Phase 0 to Implementation Phases: validate haiku can read `writing-conventions.md` and classify conventions."

**Resolution:** Phase 0 is now the first implementation phase (lines 353-362) with four validation tests (lines 321-333) that must pass before Phase 1 begins.
Tests cover: convention classification, mechanical fix application, judgment-required reporting, and protected zone respect.
Success criteria and failure paths are specified (lines 361-362): if classification fails, add markup; if tests 2-4 fail, evaluate prompt refinement or model upgrade.

**Assessment:** Phase 0 appropriately gates the implementation on the core design assumption.
The tests are concrete and the failure paths are clear.

**Category:** Resolved.

### Round 1 Non-blocking Issue 1: Manual vs. Automatic Invocation

**Previous finding:** "Resolve Decision 4 inconsistency: clarify whether nit-fix invocation is manual, automatic, or both."

**Resolution:** Decision 4 (line 215) now states: "Nit-fix is primarily deliberate (author invokes before review) but can also be triggered by the triage dispatcher as part of the pre-review pipeline (see Story 4)."
This clarifies it's both, with Story 4 (lines 253-259) providing the automated pipeline context.

**Assessment:** The inconsistency is resolved. Invocation mode is now clear.

**Category:** Resolved.

### Round 1 Non-blocking Issues 2-4: Edge Case Details

**Previous finding:** Expand edge case mitigations, clarify PostToolUse hook scope, resolve edge case 5 conflict.

**Resolution:**
- Edge case 1 (lines 263-270): mitigation is now fully restated (tool allowlist + prompt guidance) rather than referenced.
- Edge case 4 (lines 294-301): clarifies that the PostToolUse hook validates field presence, not semantic correctness, and that nit-fix prose changes applied to frontmatter would break parsing (which the hook would catch).
- Edge case 5 (lines 303-309): resolves the conflict by clarifying that protected zone detection operates on document structure before convention checking, not per-convention. The agent identifies zones first, then only checks non-protected prose.

**Assessment:** All edge case mitigations are now clear and internally consistent.

**Category:** Resolved.

### New Content: Appendix A Agent Body

**Finding:** Appendix A (lines 388-483) provides the full agent body draft.
The structure follows the triage agent pattern: domain context, startup instructions (read rules), classification principle, protected zone list, processing steps, output format, constraints.
The mechanical fix steps (lines 443-446) are specific without hardcoding conventions: sentence-splitting uses the specified boundary rules, callout attribution uses `task_list`, punctuation and emoji are pattern-based.

**Issue:** Line 444 lists abbreviations in the agent prompt.
This could be seen as hardcoding, though the list is implementation detail (how to detect boundaries) rather than policy (what conventions to enforce).

**Assessment:** The abbreviation list is acceptable.
It's operational guidance for a mechanical convention, not a new convention itself.
If needed, this list could be moved to `writing-conventions.md` under the "Sentence-per-Line Formatting" section as a NOTE, but the current approach is pragmatic.

**Category:** Non-blocking.

### Classification Realism

**Finding:** The classification mechanism (lines 108-122, Appendix A 416-422) asks haiku to infer mechanical vs. judgment-required from convention text using a high-level principle.
The principle is sound: "fix preserves meaning" vs. "fix could change meaning."
However, applying this principle requires haiku to reason about what constitutes "preserving meaning" across diverse conventions.

**Concern:** Haiku may struggle with edge cases.
For example, "Punctuation: Prefer Colons Over Em-Dashes" could be misread as judgment-required because choosing between a colon and a spaced hyphen requires understanding sentence structure.
The proposal mitigates this with expected classifications (lines 123-138), conservative defaults (Decision 5), and the markup fallback.

**Assessment:** The approach is appropriately ambitious with appropriate safeguards.
Phase 0 test 1 (lines 326) will reveal whether haiku can perform this classification.
If it fails, the fallback (add explicit markup to `writing-conventions.md`) is sound and preserves the design constraint.

**Category:** Non-blocking (Phase 0 will validate).

### Internal Consistency

**Finding:** The proposal is internally consistent.
The tool allowlist (Read/Glob/Grep/Edit) matches triage and aligns with the agent's scope (prose edits, no file creation).
The protected zones correctly exclude frontmatter (triage's domain) and code blocks (where prose conventions don't apply).
The output format matches triage's structure.
The workflow integration (Story 4) correctly positions nit-fix before triage in the pipeline.

**Category:** Non-blocking.

### Comparison to Triage Agent

**Finding:** The proposal correctly follows the triage-v2 architecture pattern:
- Formal agent definition with infrastructure-enforced tool allowlist (consistent with triage).
- Read-at-runtime rules (consistent with triage reading `frontmatter-spec.md`).
- Thin dispatcher skill (consistent with triage skill structure).
- Prompt-based protected zone enforcement (consistent with triage's "do not modify document body" constraint).
- Mechanical fixes applied directly, judgments reported (consistent with triage's tag analysis approach).

The triage agent body (lines 86-93 of triage.md) includes: "Do not modify document body content: only edit YAML frontmatter."
Nit-fix reciprocates (Appendix A line 481): "Do not modify protected zones (frontmatter, code blocks, inline code, tables, HTML comments)."
This creates a clean separation: triage owns frontmatter, nit-fix owns prose.

**Category:** Non-blocking.

### Test Plan Completeness

**Finding:** The test plan now covers 14 test cases across Phase 0 validation (tests 1-4) and implementation (tests 5-14).
Tests 1-4 validate the core design assumptions before any implementation.
Tests 5-14 validate agent registration, tool restriction, rules reading, fix accuracy, protected zones, edge cases, batch mode, rules evolution, and end-to-end pipeline.

**Missing test:** No test validates the fallback classification markup approach.
If Phase 0 test 1 fails and explicit markup is added to `writing-conventions.md`, a follow-up test should verify haiku correctly reads and respects the markup.

**Recommendation:** Add to Phase 0 (between current steps 2 and 3): "If classification test requires markup, add `<!-- MECHANICAL -->` comments to 2-3 conventions in a test copy of `writing-conventions.md`, re-run test 1, verify haiku correctly identifies marked conventions."

**Category:** Non-blocking (minor test plan gap).

## Verdict

**Accept.**

All six blocking issues from round 1 have been resolved:

1. Classification mechanism is specified (prompt-guided heuristic with HTML comment fallback).
2. Agent body is provided in full (Appendix A).
3. Protected zone detection logic is explicit (six zone types with detection rules).
4. Sentence-splitting logic is detailed (boundary rules, abbreviation handling, URL cases).
5. Test cases specify expected behavior and ground truth.
6. Phase 0 validation is positioned as the first implementation step.

The three non-blocking issues have also been resolved:
1. Manual vs. automatic invocation is clarified.
2. Edge case mitigations are expanded and internally consistent.
3. PostToolUse hook scope is clarified.

The proposal is implementation-ready.
The classification mechanism is ambitious (asking haiku to infer from convention text) but Phase 0 appropriately gates implementation on validation of this assumption, with a clear fallback strategy if needed.

## Action Items

1. [non-blocking] Consider moving the abbreviation list (Appendix A line 444) to `writing-conventions.md` as a NOTE under "Sentence-per-Line Formatting" if you want to avoid any appearance of hardcoding implementation details in the agent prompt. Current approach is acceptable.

2. [non-blocking] Add a Phase 0 sub-test: if test 1 (classification) requires markup fallback, validate that haiku correctly reads and respects `<!-- MECHANICAL -->` / `<!-- JUDGMENT -->` comments added to a test copy of `writing-conventions.md`.

3. [non-blocking] After Phase 0 completes, consider documenting the validation results (pass/fail on each test, whether markup was needed) in the implementation devlog for future reference.

## Underconsidered Sections / Points for Clarification

The following aspects could benefit from consideration during implementation:

A. **Classification markup syntax**: If the fallback is needed, should the markup be `<!-- MECHANICAL -->` on the line before the heading, or inline after the heading like `## Sentence-per-Line <!-- MECHANICAL -->`? The proposal doesn't specify. Recommendation: before-heading placement is cleaner and won't affect rendered output.

B. **Batch mode performance**: Story 3 (lines 247-251) describes globbing `cdocs/**/*.md` and processing all files. With 50+ cdocs files, this could be slow and produce a large consolidated report. Should the skill impose a file count limit or chunk processing? Or is this acceptable as-is for deliberate batch invocations?

C. **Integration with existing workflow**: The proposal positions nit-fix as pre-review (Story 1) and in a pipeline before triage (Story 4). However, `rules/workflow-patterns.md` currently documents "End-of-Turn Triage" as automatic. Should nit-fix also be automatic end-of-turn, or remain deliberate-only? This affects whether the skill needs end-of-turn hook integration.

These are not blocking issues, just areas where implementation choices will need to be made.
