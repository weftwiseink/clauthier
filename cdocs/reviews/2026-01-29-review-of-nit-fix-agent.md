---
review_of: cdocs/proposals/2026-01-29-nit-fix-agent.md
first_authored:
  by: "@claude-sonnet-4-20250514"
  at: 2026-01-29T17:00:00-08:00
task_list: cdocs/nit-fix-v2
type: review
state: live
status: done
tags: [fresh_agent, writing_conventions, subagent_patterns, plugin_idioms]
---

# Review of Nit Fix Agent Proposal

> BLUF(sonnet/cdocs/nit-fix-v2): The nit-fix agent proposal follows the v2 agent architecture correctly and addresses a real maintainability need (prose convention enforcement).
> The design is sound with one critical gap: no test validation of the core design claim (haiku can read rules and self-classify mechanical vs. judgment-required fixes).
> The mechanical fix implementation section lacks sufficient detail about protected zone handling and edge cases.
> Verdict: **Revise** - blocking issues around test plan validation and implementation specification must be addressed.

## Summary Assessment

The proposal establishes a formal CDocs agent for enforcing writing conventions via read-at-runtime rules and mechanical fixes.
The architecture follows the v2 pattern established by triage-v2: formal agent definitions, tool allowlists, read-at-runtime rules, and a thin dispatcher skill.
The most important finding is that the proposal's core design claim (haiku can read `writing-conventions.md` and correctly classify conventions as mechanical vs. judgment-required) is untested and must be validated before implementation.
The verdict is **Revise**: the proposal is architecturally correct but underspecified in critical areas.

## Section-by-Section Findings

### Frontmatter

**Finding:** Frontmatter is correctly structured per the frontmatter spec.
The `task_list: cdocs/nit-fix-v2` value correctly distinguishes this from the v1 proposal.
Tags appropriately reflect the content.

**Category:** Non-blocking.

### BLUF

**Finding:** The BLUF accurately summarizes the proposal: formal agent, v2 architecture, rules-reading enforcement, mechanical/judgment split.
The statement "Supersedes `cdocs/proposals/2026-01-29-nit-fix-skill.md` (status: evolved)" is correct.

**Category:** Non-blocking.

### Objective

**Finding:** The objective section clearly states the problem (conventions easy to violate, tedious to enforce) and positions the v2 agent architecture as the solution.
The claim "Adding a new convention to `rules/writing-conventions.md` extends enforcement automatically" is the proposal's core value proposition and architectural constraint.

**Category:** Non-blocking.

### Background

**Finding:** The background section correctly summarizes the v2 agent architecture and accurately identifies what's missing (prose convention enforcement).
The reference to the v1 nit-fix proposal and its status (`evolved`) is correct.

**Issue:** The statement "The core design (rules-reading enforcement agent, mechanical/judgment boundary) is sound" carries over from v1 without validation.
The v1 proposal was never implemented, so this claim remains untested.

**Category:** Non-blocking (flagged for attention in Test Plan).

### Proposed Solution - Agent Definition

**Finding:** The agent definition frontmatter is correct: `model: haiku`, `tools: Read, Glob, Grep, Edit`.
The tool allowlist matches triage exactly.

**Issue:** The agent body description lists 5 steps but does not provide the actual prompt text or detailed instructions.
Triage provides its full prompt in `plugins/cdocs/agents/triage.md` (see lines 8-93 of triage.md).
The proposal should either provide the full agent body or explicitly defer it to implementation phase.

**Category:** Blocking.
The agent body is the core deliverable; the proposal should specify it or explain why specification is deferred.

### Proposed Solution - Tool Allowlist Rationale

**Finding:** The rationale correctly explains why each tool is included and why Write/Bash are excluded.
The reasoning matches the triage precedent.

**Category:** Non-blocking.

### Proposed Solution - Thin Dispatcher Skill

**Finding:** The dispatcher skill description is correct: collect paths, invoke agent, present results.
The phrase "The skill contains no agent instructions" correctly reflects the v2 separation of concerns.

**Category:** Non-blocking.

### Proposed Solution - Mechanical vs. Judgment-Required Classification

**Finding:** This section is critical: it defines the boundary between what the agent fixes and what it reports.

**Issue 1:** The proposal states "The agent determines this at runtime by reading the rules file" but does not explain how the agent makes this determination.
Is there markup in `writing-conventions.md` that tags conventions as mechanical/judgment-required?
If not, how does haiku infer this classification?
The v1 proposal (lines 95-109 of nit-fix-skill.md) had the same gap.

**Issue 2:** The examples given (mechanical: sentence-per-line, callout attribution, punctuation, emoji removal; judgment-required: history-agnostic framing, BLUF quality, brevity, commentary decoupling) are reasonable classifications.
However, the proposal does not specify whether these examples are hardcoded guidance to the agent or whether the agent must infer them from the rules text.

**Recommendation:** Either add explicit classification markup to `writing-conventions.md` (e.g., `> MECHANICAL` or `> JUDGMENT` callouts) or provide detailed prompt instructions that guide haiku's classification logic.
The current approach (implicit inference) is high-risk for a haiku agent.

**Category:** Blocking.
The classification boundary is the proposal's core mechanism; it must be specified.

### Proposed Solution - Protected Zones

**Finding:** Protected zones are correctly identified: YAML frontmatter, code blocks, inline code, tables.

**Issue 1:** The instruction "The agent must not modify content inside [these zones]" is stated but not enforced.
Triage has a similar constraint ("Do not modify document body content: only edit YAML frontmatter") which is prompt-based, not infrastructure-enforced.
The proposal should acknowledge that protected zone enforcement is prompt-based and accept the risk (as triage does) or propose additional safeguards.

**Issue 2:** Code blocks are defined as "between `` ``` `` delimiters" but the proposal does not address nested code blocks, indented code blocks, or HTML comment blocks.
These edge cases should be documented.

**Recommendation:** Add an Edge Cases section entry for "Protected zone detection failures" and specify the mitigation (prompt guidance + low-severity blast radius).

**Category:** Blocking.
Protected zone handling is safety-critical; the proposal must specify how detection works and what happens when it fails.

### Proposed Solution - Output Format

**Finding:** The output format is well-structured and mirrors the triage report format.

**Category:** Non-blocking.

### Important Design Decisions - Decision 1

**Finding:** Decision 1 correctly states the core architectural constraint: no hardcoded rules.
The rationale is sound.

**Category:** Non-blocking.

### Important Design Decisions - Decision 2

**Finding:** Decision 2 correctly explains why a formal agent is preferred over a skill-embedded prompt.
The reasoning aligns with the v2 architecture.

**Category:** Non-blocking.

### Important Design Decisions - Decision 3

**Finding:** Decision 3 correctly matches the tool profile to triage.
The blast radius reasoning is sound.

**Category:** Non-blocking.

### Important Design Decisions - Decision 4

**Finding:** Decision 4 correctly separates nit-fix from triage based on domain (prose vs. frontmatter), rules files, protected zones, invocation timing, and single responsibility.

**Issue:** The claim "Nit-fix runs at author discretion or pre-review (deliberate)" contradicts workflow integration (Phase 3 implementation plan, line 293-298) which positions nit-fix as part of an automated pipeline.
Clarify whether nit-fix is manual, automatic, or both.

**Category:** Non-blocking.
The inconsistency should be resolved but does not block the design.

### Important Design Decisions - Decision 5

**Finding:** Decision 5 correctly establishes a conservative approach to uncertain fixes.
The rationale (false positives worse than false negatives) is sound.

**Category:** Non-blocking.

### Stories

**Finding:** The stories cover representative use cases: pre-review pass, new convention auto-enforcement, batch mode, and pipeline integration.

**Issue:** Story 2 ("New convention auto-enforcement") demonstrates the core value proposition but is untested.
The proposal should flag this as requiring Phase 0 validation (similar to triage-v2's platform validation).

**Category:** Non-blocking (flagged for Test Plan).

### Edge Cases

**Finding:** Five edge cases are identified.
Each has a mitigation strategy.

**Issue 1:** Edge case 1 ("Nit-fix edits wrong files") references "Same mitigation as triage" but triage's mitigation is two-layer (tool allowlist + prompt guidance).
The proposal should explicitly restate the mitigation rather than referencing it.

**Issue 2:** Edge case 2 ("Sentence splitting in ambiguous contexts") lists abbreviations, URLs, and inline code as challenges.
The mitigation ("split only at clear boundaries") is stated but not specified.
What regex or logic defines a "clear boundary"?

**Issue 3:** Edge case 4 ("Frontmatter/body boundary") states "the existing PostToolUse hook validates frontmatter integrity."
The triage-v2 proposal (line 144) confirms the global PostToolUse hook exists.
However, this hook validates field presence, not semantic correctness.
If nit-fix edits frontmatter fields (e.g., tags), the hook won't catch semantic errors.

**Issue 4:** Edge case 5 ("Code blocks containing prose-like content") states "This is a strict rule: no exceptions for 'prose-like' code blocks."
This is correct but conflicts with the agent's judgment-based operation.
How does the agent enforce this strict rule if it's classifying fixes at runtime?

**Recommendation:** Expand edge case 2 with specific detection logic for sentence boundaries.
Clarify edge case 4's scope (frontmatter vs. body).
Resolve edge case 5's apparent conflict.

**Category:** Blocking.
Edge case handling is implementation-critical; the proposal must specify detection logic.

### Test Plan

**Finding:** The test plan covers agent registration, tool restriction, rules reading, mechanical fix accuracy, judgment-required detection, protected zones, conservative splitting, batch mode, rules evolution, and pipeline.

**Critical gap:** Test 9 ("Rules evolution: add a test convention to the rules file, verify nit-fix enforces it on next invocation") is the core design validation but is positioned as a post-implementation test.
This should be Phase 0 validation, not Phase 3 testing.

**Issue 1:** Test 4 ("Mechanical fix accuracy") does not specify the expected behavior.
How is "fixed correctly" determined?
What's the ground truth?

**Issue 2:** Test 7 ("Conservative splitting: test tricky sentence boundaries") does not specify what constitutes correct behavior for abbreviations, URLs, and inline code.
The test should define expected outputs.

**Issue 3:** Test 6 ("Protected zones: test document with code blocks, tables, frontmatter containing 'violations.' Verify these are not modified.") is critical but does not specify how to verify.
Should the agent report these as violations (detection without fix) or ignore them entirely?

**Recommendation:** Add Phase 0 validation step before Phase 1 implementation.
Phase 0 should test: (a) haiku can read `writing-conventions.md` and classify conventions, (b) haiku can detect mechanical violations without fixing, (c) haiku respects protected zones.
This mirrors the triage-v2 validation approach.

**Category:** Blocking.
The core design assumption (haiku can self-classify conventions from reading the rules file) is untested and must be validated before implementation.

### Implementation Phases

**Finding:** Three phases are defined: agent definition, dispatcher skill, workflow integration.

**Issue:** No Phase 0 validation step exists.
Triage-v2 included Phase 0 to validate platform affordances (tool allowlists, skills preloading, model override) before committing to the architecture.
Nit-fix should validate the core design assumption (haiku can read rules and self-classify) before implementation.

**Recommendation:** Add Phase 0: Validate haiku's ability to read `writing-conventions.md`, classify conventions as mechanical/judgment-required, and detect violations without fixing.
Use a test document with known violations.
If Phase 0 fails, the design requires adjustment (e.g., explicit markup in the rules file, or a higher-tier model for the nit-fix agent).

**Category:** Blocking.
Phase 0 validation is essential to de-risk the proposal's core design claim.

## Verdict

**Revise.**

The proposal is architecturally sound and follows the v2 agent pattern correctly.
The identified problems are implementation gaps, not design flaws.
The following blocking issues must be addressed:

1. The mechanical vs. judgment-required classification mechanism is underspecified.
The proposal must explain how haiku determines this boundary from reading the rules file.
2. The agent body (prompt) is not provided.
Either specify it in the proposal or explain why specification is deferred to implementation.
3. Protected zone detection logic is not specified.
The proposal must explain how code blocks, frontmatter, and other excluded zones are identified.
4. Edge case 2 (sentence splitting) lacks specific detection logic.
5. Test Plan lacks Phase 0 validation of the core design assumption.

Non-blocking improvements:

1. Resolve the manual vs. automatic invocation inconsistency in Decision 4.
2. Expand edge case mitigations with more specific logic.
3. Specify expected behavior in test cases (what "correct" means).

## Action Items

1. [blocking] Add Phase 0 to Implementation Phases: validate haiku can read `writing-conventions.md` and classify conventions as mechanical vs. judgment-required without explicit markup.
2. [blocking] Specify the classification mechanism: either add markup to `writing-conventions.md` (e.g., `> MECHANICAL` callouts) or provide detailed prompt guidance for haiku to infer classification from convention text.
3. [blocking] Provide the full agent body (prompt) or explicitly defer it to Phase 1 with a rationale.
4. [blocking] Specify protected zone detection logic: how are frontmatter boundaries, code blocks, inline code, and tables identified?
5. [blocking] Specify sentence-splitting detection logic for edge case 2: what regex or rules define a "clear sentence boundary"?
6. [blocking] Expand Test Plan test cases 4, 6, and 7 with expected behavior and ground truth definitions.
7. [non-blocking] Resolve Decision 4 inconsistency: clarify whether nit-fix invocation is manual, automatic, or both.
8. [non-blocking] Restate triage mitigation in edge case 1 rather than referencing it.
9. [non-blocking] Clarify edge case 4 scope: does the PostToolUse hook validate frontmatter edits by nit-fix or only by other agents?
10. [non-blocking] Resolve edge case 5 conflict: how does a judgment-based agent enforce strict rules?
