---
review_of: cdocs/proposals/2026-01-29-nit-fix-agent.md
first_authored:
  by: "@claude-sonnet-4-20250514"
  at: 2026-01-30T09:30:00-08:00
task_list: cdocs/nit-fix-v2
type: review
state: live
status: done
tags: [rereview_agent, writing_conventions, subagent_patterns, multi_rule]
---

# Review of Nit Fix Agent Proposal (Round 3)

> BLUF(sonnet/cdocs/nit-fix-v2): The multi-rule extension successfully generalizes the nit-fix agent from single-file to multi-file rule loading while preserving the core "no hardcoded rules" design principle.
> Decision 6 and the glob-based discovery mechanism are architecturally sound, Story 2b validates the design, and the agent body correctly implements multi-rule startup.
> Two significant findings: the rule file format specification is underspecified (what constitutes a "convention" across multiple heterogeneous rule files?), and the classification override mechanism via `## Classification` sections needs explicit parsing guidance.
> One minor finding: the relationship between this proposal and the project-rules RFP could be clearer.
> Verdict: **Accept** - the multi-rule design is implementation-ready with clarifications needed in Phase 1 agent refinement.

## Summary Assessment

The round 3 revision adds multi-rule support (Decision 6, lines 234-246) by replacing single-file reading with glob discovery of `plugins/cdocs/rules/*.md`.
This change is well-motivated: modular rule files enable independent authoring and targeted enforcement, as demonstrated by the use-mermaid-diagrams proposal.
The agent body (Appendix A, lines 430-440) correctly implements multi-rule startup with glob discovery and aggregation.
The most important finding is that the proposal assumes a uniform rule file format across multiple independent rule files without specifying what that format is.
The mermaid-diagrams proposal uses a different structure than writing-conventions.md (detection heuristics section, explicit classification section), raising questions about how the agent parses heterogeneous rule files.
The verdict is **Accept**: the architectural change is sound and the remaining format questions can be resolved during Phase 1 refinement.

## Section-by-Section Findings

### Frontmatter

**Finding:** The frontmatter correctly reflects round 2 acceptance with `last_reviewed.round: 2` and `status: review_ready` indicating the document was revised again after acceptance.
This is unusual (typically accepted proposals move to implementation), but the BLUF explains the revision adds multi-rule support.

**Category:** Non-blocking.

### BLUF Multi-Rule Changes

**Finding:** The BLUF (lines 19-22) correctly summarizes the multi-rule extension: "reads multiple rule files from `plugins/cdocs/rules/` at runtime", "loads all `rules/*.md` files at startup", "modular conventions... independently authored and enforced."
The note (lines 35-37) correctly positions project-level extensibility as deferred to the RFP rather than included in this proposal.

**Category:** Non-blocking.

### Objective Multi-Rule Changes

**Finding:** Lines 31-33 state the core multi-rule value proposition: "The nit-fix agent reads all rule files from `plugins/cdocs/rules/` at startup and enforces them. No conventions are hardcoded in the agent prompt. Adding a new rule file... extends enforcement automatically."
This correctly generalizes from "adding a new convention to writing-conventions.md" (round 2) to "adding a new rule file."

**Category:** Non-blocking.

### Decision 6: Multi-Rule Loading

**Finding:** Decision 6 (lines 234-246) is the core architectural addition.
The decision correctly states glob-based discovery rather than hardcoded paths.
The rationale identifies the key benefit: modular rule files enable independent authoring and "targeted enforcement" (though targeted enforcement is not defined - does this mean per-file scoping, or just separation of concerns?).
Line 239 correctly positions this as "the foundation for future project-level and cross-plugin rule extensibility."

**Issue 1:** Lines 243-244 introduce a "rule file format" specification: "markdown with `##` headings per convention" and an optional `## Classification` section that "explicitly marks conventions as mechanical or judgment-required, overriding the agent's heuristic classification."
This format is not specified elsewhere in the proposal.
The writing-conventions.md file does not contain a `## Classification` section.
The mermaid-diagrams proposal (lines 115-118 of that file) does contain a `## Classification` section, but the content is prose ("Judgment-required: Converting ASCII diagrams...") rather than structured markup.
How does the agent parse this?
Is the heading sufficient (any section titled "## Classification" triggers override), or must the content follow a specific format?

**Issue 2:** Lines 245 states "Files without classification sections use the agent's default heuristic."
This implies the classification section applies to the entire file, not per-convention.
But writing-conventions.md contains both mechanical and judgment-required conventions.
If a classification section were added to writing-conventions.md, would it override the heuristic for all conventions in the file, or only for conventions explicitly named in that section?
The mechanism is underspecified.

**Issue 3:** The decision states "markdown with `##` headings per convention" but does not define what constitutes a convention heading vs. other `##` headings.
The mermaid-diagrams proposal has `## Rationale`, `## When to Use Mermaid`, `## ASCII Patterns to Avoid`, `## Mermaid Equivalent Examples`, `## Exceptions`, `## Classification`.
Only some of these are "conventions" (the enforceable rule).
How does the agent distinguish convention headings from informational headings?
Does the agent treat every `##` heading as a potential convention and attempt classification, or does it look for specific keywords?

**Recommendation:** Add a subsection to Decision 6 specifying the rule file format:
1. Rule files are markdown documents with `##` headings.
2. Each `##` heading represents a potential convention unless the heading text indicates informational content (e.g., "Rationale", "Examples", "Classification", "Implementation").
3. An optional `## Classification` section may explicitly mark conventions. Format: list each convention heading name followed by MECHANICAL or JUDGMENT-REQUIRED. If present, this overrides the agent's heuristic for named conventions only.
4. Headings not mentioned in a Classification section use the default heuristic.

Alternatively, explicitly defer the format specification to Phase 1 agent refinement with a NOTE acknowledging this needs to be resolved during implementation.

**Category:** Blocking if the format must be specified in the proposal, non-blocking if Phase 1 refinement is acceptable.

### Agent Body Multi-Rule Changes

**Finding:** Appendix A lines 430-440 implement the multi-rule startup correctly:
1. Glob for `plugins/cdocs/rules/*.md`.
2. Read each discovered file.
3. "Each rule file contains one or more conventions organized under `##` headings."
4. "Aggregate all conventions from all rule files into your working set."

Lines 438-439 correctly state the value proposition: "Adding a new rule file to `plugins/cdocs/rules/` extends your enforcement surface with no prompt changes."

**Issue:** Line 432 says "Each rule file contains one or more conventions organized under `##` headings."
This is the same underspecification as Decision 6 Issue 3.
The agent body does not explain how to identify which `##` headings are conventions vs. informational sections.
The mermaid-diagrams file has 9 `##` headings, most of which are not enforceable conventions.

**Recommendation:** Add to Appendix A after line 436: "Conventions are identified by `##` headings that describe rules to enforce. Informational headings (e.g., Rationale, Examples, Classification, Implementation) should be skipped. If a rule file contains a `## Classification` section, read it to determine which conventions are MECHANICAL vs. JUDGMENT-REQUIRED, overriding your default heuristic for those conventions."

**Category:** Non-blocking (can be refined in Phase 1 based on Phase 0 findings).

### Story 2b: New Rule File Auto-Discovery

**Finding:** Story 2b (lines 268-274) validates the multi-rule design end-to-end.
The story correctly demonstrates glob discovery, reading multiple files (writing-conventions.md and use-mermaid-diagrams.md), and processing a convention with explicit classification markup.
The expected behavior (report as judgment-required with detection context) is correct.

**Issue:** Line 272 states "finds the Mermaid convention with its detection heuristics and explicit `## Classification` section."
The use-mermaid-diagrams proposal does contain a Classification section (lines 115-118), but that section contains prose explanation, not structured markup: "Judgment-required: Converting ASCII diagrams to Mermaid requires understanding the diagram's semantic intent..."
Is this sufficient for the agent to parse?
Should the Classification section contain structured data like "Mermaid-over-ASCII: JUDGMENT-REQUIRED"?

**Recommendation:** Story 2b should specify the expected Classification section format or acknowledge that the format will be validated in Phase 0.

**Category:** Non-blocking (Story 2b validates the concept; exact format can be refined).

### Protected Zones Multi-Rule Compatibility

**Finding:** Protected zones (lines 147-163) are document-structure-based, not rule-based, so they apply uniformly across all rule files.
This is correct: frontmatter and code blocks should be protected regardless of which rule file is being enforced.

**Category:** Non-blocking.

### Edge Cases Multi-Rule Impact

**Finding:** Edge cases 1-6 are unchanged from round 2.
None of them are affected by multi-rule loading.
Edge case 5 (lines 333-339) correctly states that protected zone detection operates before convention checking, which applies whether conventions come from one file or many.

**Category:** Non-blocking.

### Test Plan Multi-Rule Coverage

**Finding:** The test plan does not explicitly validate multi-rule loading.
Test 13 (lines 377-378) validates "rules evolution" by adding a test convention to "rules file" (singular), but does not test adding a new rule file.

**Recommendation:** Add a Phase 1 test: "Multi-rule loading: create a test rule file `plugins/cdocs/rules/test-rule.md` with one mechanical convention. Invoke nit-fix, verify the agent discovers and reads both writing-conventions.md and test-rule.md (check 'Rule files loaded: 2' in the report). Verify the test convention is enforced. Remove the test file after."

**Category:** Non-blocking (the test is implicit in Story 2b, but explicit validation is better).

### Implementation Phases Multi-Rule Impact

**Finding:** Phase 0 (lines 382-392) does not reference multi-rule loading.
Phase 0 tests use writing-conventions.md only.
This is acceptable: Phase 0 validates the classification heuristic, which is independent of how many rule files are loaded.

Phase 1 (lines 394-400) states "Write the agent body per Appendix A (refined based on Phase 0 findings)."
This correctly positions agent body refinement (including rule file format parsing) as a Phase 1 activity.

**Category:** Non-blocking.

### Relationship to Project-Rules RFP

**Finding:** Lines 35-37 note that project-level extensibility is deferred to the RFP.
The RFP (cdocs/proposals/2026-01-30-nit-fix-project-rules.md) scopes multi-source rule loading (plugin vs. project-local, conflict resolution, scoping).

**Issue:** The current proposal implements glob discovery of `plugins/cdocs/rules/*.md`, which is plugin-internal.
The RFP extends this to `plugins/*/rules/*.md` (all plugins) and project-local sources.
The architecture is compatible (both use glob discovery and aggregation), but the relationship could be clearer.
Is Decision 6's glob path (`plugins/cdocs/rules/*.md`) intended to be plugin-scoped, or does it already support all plugins?
Line 239 says "foundation for future project-level and cross-plugin rule extensibility" but the implementation is cdocs-scoped.

**Recommendation:** Add a NOTE to Decision 6 clarifying: "This proposal scopes glob discovery to `plugins/cdocs/rules/*.md` (cdocs plugin only). The project-rules RFP extends this to `plugins/*/rules/*.md` (all installed plugins) and project-local paths. The architecture is forward-compatible: the agent's glob pattern is a parameter that can be extended without changing the aggregation logic."

**Category:** Non-blocking (clarification, not a design flaw).

### Internal Consistency Multi-Rule

**Finding:** The BLUF, Objective, Decision 6, Story 2b, and Appendix A all correctly reference multi-rule loading.
The proposal is internally consistent on the glob-based discovery mechanism.

**Category:** Non-blocking.

### Comparison to Mermaid-Diagrams Proposal

**Finding:** The use-mermaid-diagrams proposal (cdocs/proposals/2026-01-30-use-mermaid-diagrams.md) is a concrete example of a standalone rule file designed for multi-rule loading.
It contains:
- Rule content (When to Use Mermaid, ASCII Patterns to Avoid, Mermaid Examples, Exceptions).
- Detection heuristics (lines 121-136).
- Explicit classification (lines 115-118): "Judgment-required: Converting ASCII diagrams..."

**Issue 1:** The mermaid-diagrams proposal's structure does not match the format implied by Decision 6.
Decision 6 says "markdown with `##` headings per convention."
The mermaid-diagrams file has one convention ("Use Mermaid Diagrams Over ASCII Art" - the title) but 9 `##` headings, most of which are informational (Rationale, When to Use, ASCII Patterns, Mermaid Examples, Exceptions, Classification).
If the agent treats every `##` heading as a convention, it would misparse this file.

**Issue 2:** The mermaid-diagrams proposal's `## Classification` section (lines 115-118) contains prose: "Judgment-required: Converting ASCII diagrams to Mermaid requires understanding the diagram's semantic intent and choosing the appropriate Mermaid diagram type."
Is this the expected format for classification overrides?
If so, how does the agent parse it?
Does the agent look for the keywords "Judgment-required" or "JUDGMENT-REQUIRED" or "mechanical"?
What if the classification section says "This is judgment-required because..."?

**Recommendation:** Either:
1. Specify the classification section format: first word must be "MECHANICAL" or "JUDGMENT-REQUIRED" (case-insensitive), followed by optional explanation. Example: "JUDGMENT-REQUIRED: Converting ASCII diagrams requires understanding semantic intent."
2. Or specify that classification sections are prose and the agent must extract the classification by reading the full section and identifying the classification statement. This requires more agent sophistication.
3. Or defer format specification to Phase 1, acknowledging that Phase 0 will test classification parsing with a known-good format (e.g., the mermaid-diagrams example).

**Category:** Blocking if the classification format must be specified, non-blocking if Phase 1 refinement is acceptable.

### Detection Heuristics in Rule Files

**Finding:** The mermaid-diagrams proposal includes a `## Detection Heuristics` section (lines 121-136) with detailed guidance for automated agents.
The writing-conventions.md file does not have a Detection Heuristics section.

**Question:** Is the Detection Heuristics section part of the rule file format specification, or is it informational content that the agent may choose to read?
If it's part of the format, Decision 6 should mention it.
If it's optional, the agent body should clarify that Detection Heuristics sections (if present) provide additional guidance for violation detection.

**Recommendation:** Add a NOTE to Decision 6: "Rule files may include optional `## Detection Heuristics` sections with guidance for automated violation detection. If present, the agent should read these sections to improve detection accuracy for judgment-required conventions."

**Category:** Non-blocking (clarification).

### Rule File Naming Convention

**Finding:** Decision 6 states the glob pattern is `plugins/cdocs/rules/*.md` but does not specify naming conventions for rule files.
The two examples are `writing-conventions.md` (existing) and `use-mermaid-diagrams.md` (proposed).
Are all `*.md` files in that directory treated as rule files, or should there be a naming convention (e.g., `*-conventions.md`, `*-rules.md`)?

**Issue:** If the glob matches all markdown files, then README files, index files, or other documentation in the rules directory would be parsed as rule files.
This could cause spurious conventions to be detected.

**Recommendation:** Either:
1. Specify a naming convention: `plugins/cdocs/rules/*-conventions.md` or `plugins/cdocs/rules/rules-*.md`.
2. Or state that all `*.md` files in the directory are treated as rule files and document authors should not place non-rule markdown files in that directory.
3. Or add frontmatter filtering: rule files must have frontmatter with `type: rule` or similar.

**Category:** Non-blocking (current glob is unambiguous for the two existing files; this becomes important when the directory grows).

## Verdict

**Accept.**

The multi-rule extension is architecturally sound and implementation-ready.
Decision 6 correctly motivates glob-based discovery, the agent body correctly implements multi-rule startup, and Story 2b validates the design end-to-end.
The relationship to the project-rules RFP is clear (this proposal is plugin-scoped, the RFP extends to multi-plugin and project-local).

The following clarifications are needed during Phase 1 implementation:

1. Rule file format specification: what constitutes a "convention" heading vs. informational heading in a rule file with heterogeneous structure?
2. Classification section format: how does the agent parse `## Classification` sections to extract MECHANICAL vs. JUDGMENT-REQUIRED annotations?
3. Detection Heuristics section handling: are these optional informational sections, or part of the format?
4. Rule file naming convention: should the glob pattern be more restrictive than `*.md`?

These are not blocking issues because:
- Phase 0 tests use writing-conventions.md only (homogeneous, known structure).
- Phase 1 agent refinement explicitly includes "refined based on Phase 0 findings" (line 396), which provides the opportunity to address format questions.
- The mermaid-diagrams proposal is `status: review_ready`, not yet implemented, so format adjustments can be made before it's used in production.

The proposal is accepted with the expectation that Phase 1 will refine the rule file format specification based on Phase 0 validation results and the mermaid-diagrams implementation.

## Action Items

1. [non-blocking] Add a NOTE to Decision 6 clarifying the rule file format: convention headings vs. informational headings, Classification section format, Detection Heuristics sections.
   Alternatively, explicitly defer format specification to Phase 1 with a NOTE acknowledging this needs validation.

2. [non-blocking] Add to Appendix A agent body: guidance for parsing Classification sections if present, and skipping informational headings (Rationale, Examples, Implementation, Detection Heuristics).

3. [non-blocking] Add a Phase 1 test: "Multi-rule loading: create a test rule file, verify glob discovery and aggregation."

4. [non-blocking] Add a NOTE to Decision 6 clarifying the scope: "This proposal implements `plugins/cdocs/rules/*.md` (cdocs plugin only). The project-rules RFP extends to `plugins/*/rules/*.md` and project-local paths."

5. [non-blocking] Consider whether rule file naming convention should be more restrictive than `*.md` (e.g., `*-conventions.md`) to avoid parsing non-rule documentation files.

6. [non-blocking] When implementing the mermaid-diagrams proposal, validate that the Classification section format (prose starting with "Judgment-required:") is parseable by haiku, or adjust to structured format if needed.

## Underconsidered Sections / Points for Clarification

A. **Rule file format heterogeneity**: The proposal assumes rule files have a uniform structure (`##` headings per convention) but the mermaid-diagrams example demonstrates significant format variation.
During Phase 1, validate whether haiku can correctly identify conventions across heterogeneous rule files, or whether a more structured format (e.g., frontmatter with `conventions: [list]`) is needed.

B. **Classification section scope**: If a rule file contains multiple conventions, does a `## Classification` section apply to all of them, or only to conventions explicitly named in that section?
The mermaid-diagrams file has one convention (Mermaid-over-ASCII), so this question doesn't arise.
A multi-convention rule file (like writing-conventions.md) would need clearer scoping.

C. **Glob ordering**: When multiple rule files are discovered, does the order matter?
If two rule files define conventions with the same name, which one takes precedence?
The project-rules RFP addresses cross-source conflicts, but this proposal could acknowledge intra-plugin conflicts (two files in `plugins/cdocs/rules/` with overlapping conventions).
Current mitigation: unlikely within a single plugin, and Phase 0 tests with one file.

D. **Rule file frontmatter**: Should rule files have frontmatter (similar to cdocs documents)?
The mermaid-diagrams proposal has frontmatter (`type: proposal`), but if it becomes an implemented rule file, should it have different frontmatter (`type: rule`, `scope: cdocs/**/*.md`)?
This relates to the project-rules RFP's per-file scoping question.
Not urgent for this proposal (cdocs-internal rules apply uniformly) but worth considering for future extensibility.
