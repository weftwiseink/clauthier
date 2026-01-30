---
review_of: cdocs/proposals/2026-01-29-rfp-skill.md
first_authored:
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-29T18:30:00-08:00
task_list: cdocs/rfp-skill
type: review
state: archived
status: done
tags: [fresh_agent, proposal_lifecycle, claude_skills, workflow_integration]
---

# Review: RFP Skill

## Summary Assessment

This proposal defines a `/cdocs:rfp` skill for scaffolding lightweight `request_for_proposal` stubs that feed into the existing `/cdocs:propose` pipeline.
The proposal is well-structured, internally consistent, and thoroughly reasoned: seven design decisions each include explicit rationale, edge cases are plausible and well-mitigated, and the relationship to `/cdocs:propose` is clearly articulated with a lifecycle diagram.
The most significant finding is that Phase 2 (propose skill integration for in-place elaboration) describes behavior changes to a separate skill (`/cdocs:propose`) without adequately scoping the complexity of that modification or acknowledging that propose currently has no concept of operating on an existing file.
Two blocking issues and several non-blocking suggestions follow.
Verdict: **Revise.**

## Section-by-Section Findings

### BLUF

The BLUF is comprehensive: five sentences covering the skill's purpose, required sections, pipeline relationship, tag strategy, and hook validation posture.
It lines up with the full proposal body with no surprises.

**Finding [non-blocking]:** The BLUF is at the upper end of appropriate length for an RFP-skill proposal.
Four of the five lines are "negative claims" (what the skill does *not* do: tags are not auto-populated, no special hook validation is needed).
While these are valuable for setting expectations, the density of negations makes the BLUF read more as a FAQ than a summary.
Consider leading with the two positive claims (what the skill creates and how it feeds the pipeline) and folding the negations into a single sentence or omitting them from the BLUF entirely since they are well-covered in the Design Decisions section.

### Objective

Clear and well-motivated.
The framing that manual RFP creation "requires manual knowledge of frontmatter fields, proposal template structure, and the `request_for_proposal` status value" correctly identifies the knowledge burden that a skill eliminates.

No issues found.

### Background: Current State

Accurate characterization of the two existing RFP stubs and their shared structure.
The NOTE callout correctly observes that the nit-fix-skill stub has been elaborated past the RFP stage.

**Finding [non-blocking]:** The statement "Both were created with knowledge of the frontmatter spec and proposal conventions" is true but somewhat tautological: any document in the repo was created with knowledge of relevant conventions.
The more useful observation (which the Objective captures better) is that creating RFP stubs *requires* this knowledge, whereas a skill would not.

### Background: Relevant Plugin Components

This section accurately describes all five relevant components: frontmatter spec, propose skill, PostToolUse hook, triage subagent, and status skill.
Each description is concise and correctly characterizes the component's role.

**Finding [non-blocking]:** The description of the triage subagent says "handles post-authoring tag refinement as a triage responsibility, not an authoring responsibility."
This is accurate but undersells the triage proposal: triage also handles status transition recommendations and workflow dispatch.
Since this proposal only references triage for tag maintenance, the narrower description is acceptable, but a parenthetical noting triage's broader scope would help readers unfamiliar with that proposal.

### Background: Skill Conventions

The five-point pattern (accept arguments, determine date, create file, scaffold sections, suggest init) accurately describes the convention shared by existing skills.
The note that "the RFP skill follows this same pattern with a reduced section set" is a clean summary.

No issues found.

### Proposed Solution: Skill Definition

The invocation pattern, output file naming, and directory placement are all consistent with existing skill conventions.
The explicit statement that RFP stubs "are proposals: `type: proposal`, `status: request_for_proposal`" resolves a question raised in the round 1 review.

No issues found.

### Proposed Solution: Template

The YAML frontmatter template and markdown section scaffold are minimal and correct.
All required frontmatter fields are present.
The `tags: []` default is appropriate given the decision to let the author supply tags.

**Finding [non-blocking]:** The template uses `WORKSTREAM/TASK` for `task_list`, while the propose skill's template uses the same placeholder.
This is consistent, but neither template provides guidance on what a good `task_list` value looks like for an RFP.
Since RFPs capture nascent ideas, the author may not have a well-defined workstream yet.
Consider adding a brief guidance note in the SKILL.md (not the template) suggesting that `task_list` can use a provisional workstream path that gets refined during elaboration.

### Proposed Solution: Required Sections

The four-section structure (BLUF, Objective, Scope, Open Questions) is well-justified by the two existing RFP exemplars.
The table mapping each section to its purpose is clear.

No issues found.

### Proposed Solution: Optional Freeform Sections

The approach of suggesting optional sections "by example, not by template enforcement" is sound.
The three suggested optional sections (Known Requirements, Prior Art, Context) are reasonable additions to the examples drawn from existing stubs.

No issues found.

### Proposed Solution: Relationship to `/cdocs:propose`

The mermaid lifecycle diagram is clear and correctly shows the RFP-to-proposal pipeline.
The four-step elaboration flow (detect stub, switch to elaboration mode, preserve first_authored, transition status) is well-defined.

**Finding [blocking]:** The proposal states in step 2 that propose "detects `status: request_for_proposal`, and switches to elaboration mode."
However, the current propose skill SKILL.md (read during this review) has no concept of receiving an existing file path as input.
Its Invocation section says: "If `$ARGUMENTS` provides a topic, use it. Otherwise, prompt the user."
Arguments are topics, not file paths.
The proposal acknowledges this in a NOTE callout ("The propose skill's SKILL.md currently assumes creating a new file") and defers it to Phase 2.
The problem is that Phase 2's description underestimates the scope of this change.

Adding an "elaborate existing RFP" path to propose requires:
1. Argument parsing changes: propose must distinguish between a topic string and a file path argument.
2. Status detection: propose must read and parse frontmatter to check for `request_for_proposal`.
3. Content preservation: propose must understand which existing sections to keep and where to insert new sections around them.
4. A new invocation mode in SKILL.md with its own instructions and edge cases.

This is not a small extension: it is a second invocation mode for the propose skill.
The proposal should either expand Phase 2 to acknowledge this complexity (with success criteria that cover the argument parsing, content preservation, and error cases) or consider an alternative approach (e.g., the rfp SKILL.md itself providing elaboration guidance rather than modifying propose's invocation logic).

**Finding [non-blocking]:** The four-step elaboration flow says propose "fills in the full section set (Background, Proposed Solution, Design Decisions, Edge Cases, Phases) around the existing BLUF, Objective, and Scope content."
The phrase "around the existing content" is ambiguous: does propose insert new sections after Scope and before Open Questions?
Does it rewrite the BLUF to be more comprehensive?
Does it preserve Open Questions as-is or resolve them inline?
Clarifying the content-merging strategy would help an implementer.

### Proposed Solution: Argument Handling

Clean and well-scoped.
The explicit statement that rfp "does not accept a reference to an existing document" correctly separates rfp's concerns from propose's.

No issues found.

### Important Design Decisions

All seven decisions are well-structured with "Decision" and "Why" subsections.
Each provides concrete rationale, not just the choice.

**Decision 1 (proposals directory):** Sound.
The argument that a separate `cdocs/rfps/` directory would fragment the pipeline and break status filters is compelling.

**Decision 2 (four required sections):** Sound.
Grounded in evidence from the two existing stubs.

**Decision 3 (author-supplied tags):** Sound.
Correctly references the triage subagent's tag maintenance design, resolving a blocking item from the round 1 review.

**Decision 4 (no special hook validation):** Sound.
The argument that section-completeness validation in bash is fragile and out of scope is correct, and I verified against the actual hook implementation that it only checks field presence via regex.

**Decision 5 (in-place elaboration):** The rationale is strong: two files for one proposal creates confusion, in-place editing preserves attribution and path stability.
However, see the blocking finding above regarding the complexity of implementing this in the propose skill.

**Decision 6 (no auto-linking):** Sound.
The argument that cross-referencing adds latency to a fast scaffolding operation is appropriate.

**Decision 7 (skill name `rfp`):** The reasoning is transparent about the acronym convention break.
The argument that `rfp` is concise, unambiguous, and already in the project vocabulary is persuasive.

**Finding [non-blocking]:** Decision 7 mentions that "other skills use verbs (propose, review, report, implement) or nouns (devlog, status, init)."
`rfp` is technically a noun (it names an artifact type), so it fits the noun category alongside `devlog` and `status`.
The framing of `rfp` as a convention break is slightly overstated: the break is the acronym, not the part of speech.

### Edge Cases / Challenging Scenarios

Five scenarios are covered, each with plausible mitigations.

**Finding [blocking]:** Edge case 3 ("User invokes `/cdocs:propose` on an RFP without knowing it's a stub") describes propose detecting `status: wip` and warning about a full proposal.
But the scenario title says "without knowing it's a stub," implying the user passes a stub path and is surprised.
The scenario body then describes the *opposite* case: the user passing a full proposal (not a stub) to propose.
This is a legitimate edge case, but the title is misleading.

More importantly, this edge case reveals another gap in Phase 2: propose must handle not just `request_for_proposal` stubs but also reject or warn on other status values.
This further supports the finding that Phase 2 is under-scoped.

Edge case 1 (name collision) has a good mitigation: check before writing, ask the user.
Edge case 2 (never elaborated) correctly identifies this as acceptable and surfaceable via status filters.
Edge case 4 (too much content) has a practical mitigation: convention guidance, not enforcement.
Edge case 5 (duplicate topics) defers to status filters and triage, which is appropriate.

### Test Plan

Seven test items cover the main paths.
Tests 1-5 cover Phase 1 (the rfp skill itself), test 6 covers Phase 2 (propose elaboration), and test 7 covers the collision edge case.

**Finding [non-blocking]:** Test 6 ("Propose elaboration") is a single test case for Phase 2, which as noted above is a substantial modification.
Phase 2 needs additional test cases: argument parsing (topic string vs. file path), error handling (file not found, file is not a proposal, file is already `wip`), and content preservation verification (existing sections are kept intact, new sections are added in the right positions).

**Finding [non-blocking]:** No test case covers the scenario where `/cdocs:rfp` is invoked but `cdocs/proposals/` does not exist.
The skill conventions say the skill should suggest running `/cdocs:init` in this case.
A test verifying this behavior would strengthen the plan.

### Implementation Phases

Three phases with clear success criteria and dependency declarations.
Phase 3's note that it is "parallel-safe with Phase 2" is a useful annotation.

**Finding [non-blocking]:** Phase 1's step 3 says "Test: invoke `/cdocs:rfp test-topic`, verify output file and frontmatter."
This is a single test case.
The test plan section defines seven test cases, of which tests 1-5 apply to Phase 1.
Cross-referencing the test plan from Phase 1's description would ensure the implementer runs all relevant tests, not just the one mentioned.

**Finding [non-blocking]:** Phase 2 has a single success criterion: "`/cdocs:propose` detects an RFP stub and elaborates it in-place."
This does not address the error cases (non-stub passed to propose, file not found, content preservation verification).
Expanding the success criteria would provide better guardrails for the implementer.

## Consistency Check

### Internal Consistency

The proposal is internally consistent across sections.
The BLUF accurately summarizes the body.
Design decisions align with the proposed solution.
Edge cases map to realistic scenarios arising from the proposed design.
The test plan covers the features described in the solution.

One minor inconsistency: the BLUF says "RFP stubs have four required sections" and lists them parenthetically, but the parenthetical content is missing.
Reading the BLUF again: "RFP stubs have four required sections (BLUF, Objective, Scope, Open Questions)" is actually present.
No inconsistency.

### External Consistency

The proposal's claims about external components are verified:
- The frontmatter spec does define `request_for_proposal` as a valid proposal status.
- The propose skill's SKILL.md does only handle topic-string arguments, confirming Phase 2 is a new capability.
- The PostToolUse hook does only check field presence, not status values or section completeness, confirming Decision 4.
- The status skill does support `--status=request_for_proposal` filtering, confirming no changes are needed.
- The triage proposal does assign tag maintenance as a triage responsibility, confirming Decision 3.

### Writing Convention Compliance

The proposal follows CDocs writing conventions:
- BLUF present with `(mjr/cdocs/rfp)` attribution.
- Sentence-per-line formatting is used throughout.
- NOTE callouts use proper attribution format.
- Mermaid diagram used for the lifecycle flow.
- No emojis.
- History-agnostic framing: present-tense throughout.
- Colons preferred over em-dashes.

No convention violations found.

## Verdict

**Revise.**

The proposal is well-written, well-structured, and internally consistent.
Phase 1 (the rfp skill itself) is ready for implementation.
The blocking concern is Phase 2: the proposal describes modifying the propose skill to support in-place elaboration of RFP stubs, but underestimates the scope of that change.
The propose skill currently only handles topic-string arguments and creates new files; adding an "elaborate existing file" mode is a second invocation path that requires argument parsing, status detection, content preservation logic, and error handling.
The proposal should either expand Phase 2 to adequately scope this work or consider deferring the elaboration-mode design to a separate, dedicated proposal.

The second blocking item is a mislabeled edge case (case 3) that obscures a real gap in Phase 2 error handling.
Both blocking issues can be resolved with targeted revisions.

## Action Items

1. [blocking] Expand Phase 2 to adequately scope the propose skill modification. The current description ("Add invocation path: if `$ARGUMENTS` is a path to a file with `status: request_for_proposal`, elaborate in-place") undercounts the work. Phase 2 should address: argument parsing to distinguish topic strings from file paths, frontmatter reading and status detection, content preservation strategy (which sections to keep, where to insert new sections, whether to modify existing content), and error handling (file not found, file is not a proposal, file has a status other than `request_for_proposal`). Alternatively, split Phase 2 into its own proposal since it modifies a different skill and has its own design decisions.
2. [blocking] Fix Edge Case 3's title-body mismatch. The title says "User invokes `/cdocs:propose` on an RFP without knowing it's a stub" but the body describes the opposite scenario (user passes a full proposal to propose). Rewrite to cover both scenarios: (a) user unknowingly passes a stub to propose (expected behavior: elaborate), (b) user passes a non-stub proposal to propose (expected behavior: warn and suggest review/revision).
3. [non-blocking] Trim the BLUF. Consider reducing the five-sentence BLUF to three sentences by folding the two negative claims (tag strategy, hook validation) into one sentence or removing them from the BLUF entirely, since they are thoroughly covered in Design Decisions 3 and 4.
4. [non-blocking] Clarify the content-merging strategy for in-place elaboration. The statement that propose "fills in the full section set around the existing BLUF, Objective, and Scope content" should specify: which sections are inserted, in what order, whether the existing Open Questions section is preserved or resolved, and whether the BLUF is rewritten or extended.
5. [non-blocking] Add test cases for Phase 2. The current test plan has a single test (test 6) for propose elaboration. Add cases for: argument type detection, error handling (invalid path, non-proposal file, wrong status), and content preservation verification.
6. [non-blocking] Add a test case for the missing-directory scenario. When `cdocs/proposals/` does not exist, the skill should suggest `/cdocs:init` per skill conventions.
7. [non-blocking] Cross-reference the test plan from Phase 1's description. Phase 1 mentions a single test; the test plan has five relevant cases (tests 1-5). Reference these explicitly.
8. [non-blocking] Soften Decision 7's framing of the naming convention break. `rfp` is a noun naming an artifact type, which fits the existing pattern of noun-based skill names (devlog, status, init). The convention break is the acronym form, not the part of speech.
