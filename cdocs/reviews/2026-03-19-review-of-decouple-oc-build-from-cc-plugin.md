---
review_of: cdocs/proposals/2026-03-19-decouple-oc-build-from-cc-plugin.md
first_authored:
  by: "@claude-opus-4-6"
  at: 2026-03-19T15:00:00-07:00
task_list: cdocs/opencode-decoupling
type: review
state: live
status: done
tags: [fresh_agent, architecture, postinstall, consistency, cross-target]
---

# Review: Decouple OpenCode Build from Claude Code Plugin Setup

## Summary Assessment

This proposal addresses a genuine architectural violation: the OC postinstall script writing to `.claude/` directories, which breaks the separation of concerns established by the accepted cross-target rules integration and multi-target marketplace proposals.
The amendment successfully consolidates three previously scattered issues (`.claude/` leakage, skill nesting, source-repo guard) into a coherent fix focused on `.opencode/`-only confinement.
The primary finding is a consistency gap between this proposal's rule delivery via postinstall (to `.opencode/rules/cdocs/`) and the accepted rules proposal's specification that `/cdocs:init` is the mechanism for populating `.opencode/rules/cdocs/`.
Verdict: **Revise** -- two blocking issues around rule delivery overlap and the multi-target proposal update need resolution before acceptance.

## Section-by-Section Findings

### BLUF

The BLUF correctly prioritizes the `.claude/` leakage as the primary issue and lists the other concerns in descending order of importance.
One inaccuracy: the BLUF says "The root `package.json` `file:` dependency runs the OC postinstall in the CC source repo on every `npm install`" -- but the Background section later clarifies this dependency has already been removed.
The BLUF should reflect current state, not historical state.

**Non-blocking.** The BLUF's present-tense framing of the `file:` dependency is misleading given it was already removed.
Suggest rewording to "The root `package.json` previously had a `file:` dependency that ran the OC postinstall in the source repo."

### Summary (Issue Enumeration)

The four-issue enumeration is well-structured and each issue has a clear root cause.
The promotion of `.claude/` leakage to issue #1 (from the original proposal's #3 position as part of the postinstall problem) correctly reflects the amended proposal's primary focus.

**No issues.**

### Background: The `.claude/` Leakage Problem

The code excerpts from the current `postinstall.js` accurately reflect the source at `plugins/cdocs/scripts/postinstall.js`.
The analysis of why OC packages should not write to `.claude/` is sound and well-argued.

**No issues.**

### Background: Accepted Proposal Alignment

This section cross-references both accepted proposals.
However, it introduces a tension that the proposal does not fully resolve:

The [cross-target rules integration proposal](2026-03-14-cross-target-rules-integration.md) Layer 3a specifies that `/cdocs:init` populates `.opencode/rules/cdocs/` with OC-enhanced frontmatter (globs, keywords).
This proposal's postinstall *also* writes rules to `.opencode/rules/cdocs/`.
This creates two delivery paths for the same destination:
1. `npm install @weftwise/cdocs-opencode` -> postinstall copies rules to `.opencode/rules/cdocs/`
2. `/cdocs:init` -> copies rules with OC-enhanced frontmatter to `.opencode/rules/cdocs/`

The postinstall copies are plain rules (no OC frontmatter enhancement).
The `/cdocs:init` copies have `globs:` and `keywords:` frontmatter.
If a user runs both (likely: install the package, then run init), the init copies overwrite the postinstall copies, which is the desired behavior.
But if a user only runs `npm install` (no init), they get rules without OC-enhanced frontmatter.

This is not necessarily wrong, but the proposal should acknowledge this interaction explicitly rather than leaving it implicit.

**Blocking.** The proposal should add a design decision or note clarifying the postinstall vs `/cdocs:init` rule delivery overlap: postinstall provides baseline rules, `/cdocs:init` enhances them with OC frontmatter.
This aligns with the accepted rules proposal's progressive enhancement model but needs to be stated.

### Proposed Solution: Section 1 (Confine Postinstall)

The updated `postinstall.js` code is well-structured.
The `copySkillsFlat` function correctly iterates skill directories and copies each to the flat destination.

One issue: the `copySkillsFlat` function uses `readdirSync(src, { withFileTypes: true }).filter(d => d.isDirectory())` but does not handle the case where `src` contains non-directory entries (e.g., a stray `README.md` in the skills directory).
The filter handles this, so no functional issue, but worth noting.

The choice to always create `.opencode/` is correct for an OC-specific package.

**No blocking issues.**

### Proposed Solution: Section 2 (CC Plugin Registration)

This is a manual, one-time fix.
The commands are correct.
No concerns.

**No issues.**

### Proposed Solution: Section 3 (Source-Repo Guard)

The guard is already included in the Section 1 code block, making this section somewhat redundant.
It serves as a standalone explanation, which has documentation value, but the repeated code block creates a maintenance risk (two places to update if the guard logic changes).

**Non-blocking.** Consider removing the standalone code block in Section 3 and referencing the Section 1 code instead.

### Proposed Solution: Section 4 (Build Script Alignment)

Correctly notes that no build script changes are needed.
The verification step is a good call.

**No issues.**

### Important Design Decisions

The decisions are well-reasoned and internally consistent.
The "OC artifacts exclusively in `.opencode/`" decision correctly distinguishes between read paths and write targets.
The "flat skill paths without prefix" decision defers prefixing appropriately.
The "rules namespaced under `cdocs/`" decision is sound.

One gap: the proposal does not have a design decision explaining why skills are flat (no namespace) but rules are namespaced under `cdocs/`.
The asymmetry is justified (skills have discovery constraints, rules do not), but the decision section should explain it as a paired decision rather than two separate entries.

**Non-blocking.** Add a brief sentence to the "flat skill paths" decision noting the contrast with rules namespacing and why the asymmetry exists.

### Edge Cases

The edge cases are thorough.
The stale artifact cleanup guidance (`.claude/skills/cdocs/` and `.claude/rules/` from prior installs) is an important addition that the original proposal lacked.

One missing edge case: what happens if a user has *both* CC (cdocs via marketplace) and OC (cdocs-opencode via npm) installed in the same project?
The CC plugin uses `.claude/` paths; the OC package uses `.opencode/` paths.
Both are valid and should not interfere with each other.
This is the ideal outcome of the `.opencode/`-only confinement, but it should be stated as an edge case with the expected outcome.

**Non-blocking.** Add an edge case for dual CC+OC installation in the same project, confirming no interference.

### Test Plan

The test plan is concrete with verifiable bash commands.
Test 1 (no `.claude/` leakage) is the most critical and is well-specified.
The negative test pattern (`ls .claude/ 2>/dev/null`) is appropriate.

Missing: a test for the rule delivery overlap with `/cdocs:init`.
If a user runs `npm install` then `/cdocs:init`, the init should overwrite postinstall rules with enhanced versions.

**Non-blocking.** Consider adding a test for the postinstall-then-init sequence.

### Verification Methodology

Sound and practical.
The scratch directory approach is the right way to test postinstall behavior in isolation.

**No issues.**

### Implementation Phases

Three phases is appropriate for this scope.
Phase ordering is correct: code change first, manual fix second, documentation third.

One concern: the proposal needs to specify that the [multi-target marketplace proposal](2026-03-14-multi-target-marketplace.md) should be updated to reflect the amended postinstall behavior.
That proposal's Section 5 (Plugin Manifest and npm Packaging) and its NOTE describe the postinstall as writing to `.opencode/skills/cdocs/` and `.claude/rules/`.
After this proposal is accepted and implemented, those descriptions become stale.

**Blocking.** Phase 3 should include updating the multi-target marketplace proposal's postinstall description (or adding a NOTE referencing this proposal as an amendment) to avoid stale documentation in an accepted proposal.

### RFP Evolution

The evolved RFP at `2026-03-19-opencode-skill-path-conventions.md` has been correctly updated with `status: evolved`, `evolved_into` pointing to this proposal, and a NOTE callout.
The original content is preserved below the NOTE.
This follows the expected pattern for RFP evolution.

**No issues.**

### Frontmatter

The frontmatter is valid.
Tags include `postinstall` which is a good addition.
The `task_list` correctly references `cdocs/opencode-decoupling`.

**No issues.**

## Verdict

**Revise.**
Two blocking issues must be addressed:
1. The postinstall vs `/cdocs:init` rule delivery overlap needs an explicit design decision or note.
2. Phase 3 must include updating the multi-target marketplace proposal's stale postinstall description.

The non-blocking suggestions improve clarity but are not required for acceptance.

## Action Items

1. [blocking] Add a design decision or NOTE clarifying the postinstall vs `/cdocs:init` rule delivery overlap for `.opencode/rules/cdocs/`: postinstall provides baseline rules without OC frontmatter, `/cdocs:init` enhances with `globs:`/`keywords:` frontmatter.
   State that this is intentional progressive enhancement and that init overwrites postinstall copies.
2. [blocking] Add to Phase 3: update the multi-target marketplace proposal (Section 5 / NOTE about postinstall) to reference this proposal as an amendment to the postinstall behavior, or add a NOTE that the postinstall now targets `.opencode/` exclusively.
3. [non-blocking] Fix BLUF present-tense framing of the `file:` dependency -- it was already removed, so use past tense.
4. [non-blocking] Remove the redundant standalone code block in Section 3 (source-repo guard); reference the Section 1 code instead.
5. [non-blocking] Merge the "flat skill paths" and "rules namespaced" design decisions into a single paired entry explaining the asymmetry.
6. [non-blocking] Add an edge case for dual CC+OC installation in the same project.
7. [non-blocking] Add a test for the postinstall-then-init rule delivery sequence.
