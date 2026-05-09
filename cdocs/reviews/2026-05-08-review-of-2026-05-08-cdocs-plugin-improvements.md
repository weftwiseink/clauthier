---
review_of: cdocs/proposals/2026-05-08-cdocs-plugin-improvements.md
first_authored:
  by: "@claude-opus-4-7-1m"
  at: 2026-05-08T16:00:00-07:00
task_list: clauthier/cdocs-improvements
type: review
state: live
status: done
tags: [fresh_agent, plugin_api, devcontainer, scoping, marketplace]
---

# Review: CDocs Plugin Improvements: May 2026 Round

## Summary Assessment

The proposal collects a credible "round of improvements" mix: cheap manifest polish, a generalization of an in-flight devcontainer fix, and gated investigations for the riskier rule-delivery rework.
Phase ordering and the explicit gating of Phases 3-4 behind verification are well-judged: the report's `PostInstall` recommendation is treated with appropriate skepticism, and #16538 is correctly flagged as still-open.
The most significant gaps are (1) the BLUF mentions "five phases" only obliquely (says "fifth phase"), so a reader skimming it could miss Phases 3 and 4; (2) Phase 2's "parameterization" still hardcodes the maintainer's host path as the default, which is inconsistent with the stated goal of generalization; and (3) writing-conventions compliance is mostly clean but contains a few em-dash equivalents and history-flavored framing that should be tightened.
Verdict: **Revise** - blocking items are small and mechanical.

## Section-by-Section Findings

### BLUF

The BLUF references "phases 1-2" and "phases 3-4" and "a fifth phase" but never states up front that the proposal contains five phases.
A reader who only reads the BLUF gets surprises (Phase 5 is mentioned, but Phases 3 and 4 are framed as "defer the SessionStart-hook replacement," which buries the install-time investigation entirely).

**Non-blocking:** Rewrite the BLUF to explicitly say "five phases: two commitments (manifest polish, devcontainer doc), two scoped investigations (SessionStart retest, install-time hook viability), one deferred ergonomics phase."

### Objective and Background

Accurate and concise.
Correctly summarizes the report and the 2026-05-08 incident.
The NOTE callout flagging the `PostInstall` recommendation as unverified is well-placed and appropriately skeptical.

One minor factual nuance: the report attributes #16538 to "plugin-defined SessionStart hooks" specifically; the proposal's Background section conflates `#14200 / #16538` as if they are the same issue ("Today's CLAUDE.md still claims #14200 / #16538 is unresolved").
They are related but distinct (#14200 is the broader "always-on plugin context" architectural gap; #16538 is the specific symptom of plugin-defined SessionStart hooks not surfacing `additionalContext`).

**Non-blocking:** Adjust the Phase 3 wording to test #16538 specifically; note that #14200 may remain open even if #16538 is resolved, since the "always-loaded rules" model is broader than SessionStart injection.

### Phase 1: Marketplace and release-flow polish

The three sub-items are individually cheap, but a few hidden gotchas deserve mention:

1. **`$schema` URL.** The validator accepting `$schema` does not mean a canonical schema URL exists.
   The proposal does not specify which URL to point at.
   If no public schema is published, the field is decorative; if one is published, the proposal should name it (or commit to discovering it during implementation).

2. **`version` already exists.** `plugins/cdocs/.claude-plugin/plugin.json` already has `"version": "0.1.0"` and `"description"`.
   `marketplace.json` already has `"version": "0.1.0"` and `"description"` under `metadata`.
   The "where absent" qualifier in the proposal mostly applies to `$schema` only.
   Worth restating so the implementer does not duplicate or move existing fields.

3. **`claude plugin tag` interaction with monorepo layout.** The marketplace lives at the repo root and the plugin lives at `plugins/cdocs/`.
   The report describes `claude plugin tag` as semver-validating, but says nothing about how it handles a plugin nested inside a marketplace inside a monorepo.
   The Edge Cases section flags this for the OpenCode build dir but not for the basic monorepo layout.

4. **`strictKnownMarketplaces` test wording.** The phase says "Verify a fresh install under `strictKnownMarketplaces: true`."
   This is slightly ambiguous: do you mean the install of cdocs into a project that has `strictKnownMarketplaces: true` set, or do you mean publishing under that policy?
   The Test Plan clarifies, but the phase description should match.

**Non-blocking:** State the `$schema` URL or commit to identifying it during implementation.
**Non-blocking:** Acknowledge that `version`/`description` already exist; the only genuinely new field is `$schema`.
**Non-blocking:** Add a brief verification step that `claude plugin tag` correctly identifies the cdocs plugin in this monorepo layout.

### Phase 2: Devcontainer onboarding documentation

This is the section with the most material concern.

The "Generalize the Dockerfile symlink" decision says: "The hardcoded `/var/home/mjr/code/weft/clauthier` symlink may stay as a default."
That is not a generalization: it is a parameterization with a leaky default.
A teammate on macOS who fails to set `HOST_PROJECT_PARENT` will get the same broken behavior plus the false reassurance of having "configured" something.

A cleaner design:
- Default `HOST_PROJECT_PARENT` to empty.
- If empty, skip the symlink entirely and rely on the user's `installLocation` in `~/.claude/plugins/installed_plugins.json` matching `/workspace/clauthier` directly (which it does for any contributor who installs the plugin from inside the devcontainer rather than the host).
- Document the symlink as the workaround for contributors whose host already has the plugin installed via a host-side path.

The proposal's Phase 2 acceptance criterion ("a fresh contributor with a different host path can clone the repo, set one env var, and `lace up` to a working cdocs install") only works if the contributor's flow involves installing cdocs on the host first.
A contributor whose first install is inside the container does not need the symlink at all; the proposal should either say so or explain why this case is excluded.

Additionally, the proposal does not define `HOST_PROJECT_PARENT`'s exact semantics.
Is it the parent of the project ("/var/home/mjr/code/weft" so the symlink is `${HOST_PROJECT_PARENT}/clauthier -> /workspace/clauthier`) or the project itself ("/var/home/mjr/code/weft/clauthier")?
The Test Plan implies the former, but the design section should make this explicit.

**Blocking:** Replace the hardcoded default with empty, or justify why the maintainer's host path is a reasonable global default (it isn't).
**Blocking:** Define `HOST_PROJECT_PARENT` semantics precisely (parent dir vs. full path).
**Non-blocking:** Add a note that contributors installing cdocs from inside the container may not need the symlink at all.

### Phase 3 (investigation): SessionStart-hook replacement viability

Well-scoped.
The decision to produce a report and not code changes is correct.

One pitfall:
- A "minimal repro plugin" is the right approach, but the test should also verify that the existing cdocs SessionStart hook continues to work via the user-level fallback.
  A regression in the workaround (e.g., due to changes in the hook output size handling described in the report) would be invisible to a clean-room repro.

**Non-blocking:** Add a step to the Phase 3 test plan that confirms the user-level hook fallback still injects rule content correctly on the build under test.

### Phase 4 (investigation): install-time rule materialization

Correctly gated on Phase 3, correctly skeptical of the `PostInstall` claim.

A subtle issue: even if no formal `PostInstall` event exists, CC has a `postinstall` execution surface via the OpenCode build's npm package (`scripts/postinstall.js` is referenced in the README).
The proposal does not distinguish between "CC plugin install-time hook" and "npm postinstall," which is the existing OC mechanism.
If the goal is install-time rule materialization, the npm postinstall path is already proven for OC and might be adaptable for CC if CC plugins support an analogous mechanism.

**Non-blocking:** Phase 4's investigation should explicitly ask "does CC have a plugin install-time hook analogous to npm postinstall?" rather than only "does `PostInstall` exist?"
The latter is one possible answer; the question is broader.

### Phase 5 (deferred): skill ergonomics

Reasonable to defer.
The 250-character description audit is genuinely cheap and could move to Phase 1 if convenient (it has no risk and no dependencies).

**Non-blocking:** Consider folding the 250-character audit into Phase 1. It is mechanical, low-risk, and aligns with "manifest/release polish."

### Important Design Decisions

The four bullets here largely restate phase content.
The "Skip `extraKnownMarketplaces`" item is the only one with substantive new content (the empirical findings from 2026-05-08 are not in the Background).
Consider promoting the empirical findings to Background and trimming the Decisions section to genuinely net-new commitments.

**Non-blocking:** Trim or merge the Decisions section to avoid restating phase content.

### Edge Cases / Challenging Scenarios

Good coverage.
The "Multi-user devcontainer" and "`claude plugin tag` and the OpenCode build" cases are concrete and useful.

One missing edge case: the existing in-tree symlink (`/var/home/mjr/code/weft/clauthier -> /workspace/clauthier`) was introduced as the immediate fix.
If Phase 2 keeps that as a default but parameterizes alongside it, the build may end up creating two symlinks (the hardcoded one plus the parameterized one), or fail because the parent directory already exists.
The implementation needs to handle this idempotently.

**Non-blocking:** Add an edge case noting the interaction between the existing in-tree symlink and the new parameterized symlink, or commit to removing the hardcoded one as part of Phase 2.

### Test Plan and Verification Methodology

Mostly solid.
The Phase 1 strict-mode test is well-specified; the Phase 2 test correctly distinguishes "unset" from "set to maintainer path."

Missing: a test that the Phase 2 README cross-references actually link correctly (a broken cross-reference is a real failure mode for documentation phases).

**Non-blocking:** Add a doc-lint or visual verification step to Phase 2's test plan.

### Implementation Phases section

Mostly redundant with the Proposed Solution section above.
The Constraints lists are useful (they call out what *not* to change), but the Files Touched and Acceptance restate prior content.

The Proposal could combine Proposed Solution and Implementation Phases into a single section per phase to reduce duplication.
This is structural, not blocking.

**Non-blocking:** Consider merging "Proposed Solution" sub-sections with "Implementation Phases" sub-sections to avoid duplicated phase descriptions.

### Writing Conventions Compliance

Generally good.
A few specific issues:

1. **Em-dash usage.** Line in Important Design Decisions: "but rest on partly-unverified claims (`PostInstall` hooks, exact #16538 status)" - acceptable.
   But the Phase 1 description uses dashes that may not be em-dashes but read like list-prefixes; verify rendering.
   The bigger issue is in the Background NOTE callout: "the report agent likely conflated this with `SessionStart:startup` or a future feature" reads cleanly but contains no em-dashes - this is fine.
   Net: I did not find clear em-dash violations, but check the rendered output once.

2. **History-agnostic framing.** Phase 2 says "The Dockerfile symlink already landed for this repo's local issue; this phase generalizes it."
   This is acceptable for a proposal (which can reference prior approaches), but the phrase "already landed" is borderline.
   Frame as: "This proposal generalizes the existing Dockerfile symlink so contributors with different host paths can opt in."

3. **Sentence-per-line.** Mostly observed.
   A few places use semicolons that could be periods (e.g., "alias collisions with user-level entries silently prefer the user-level" - this clause-stacking is fine but could be split).

4. **Tags.** The frontmatter uses `[cdocs, plugin-api, devcontainer, hooks, marketplace]` with hyphens.
   The frontmatter spec example uses underscores (`[architecture, future_work, ...]`).
   The spec does not strictly require underscores but existing reviews use them consistently.

**Non-blocking:** Reword "already landed" in Phase 2 to be more present-tense.
**Non-blocking:** Align tags to underscore convention if maintaining consistency with prior cdocs documents.

## Verdict

**Revise.**

The proposal is fundamentally sound: phase ordering, gating of investigations, and overall scope are all reasonable for a "round of improvements."
Two blocking issues to address before acceptance:

1. Phase 2's parameterized symlink design still hardcodes the maintainer's host path as a default. This contradicts the stated generalization goal.
2. `HOST_PROJECT_PARENT` semantics are undefined (parent dir vs. full path). Implementer cannot proceed unambiguously.

After those are resolved, the remaining items are non-blocking improvements that would tighten the document but do not require another review round.

## Action Items

1. **[blocking]** Phase 2: Replace hardcoded `/var/home/mjr/code/weft/clauthier` symlink default with empty, or justify why the maintainer's path is a sensible global default.
2. **[blocking]** Phase 2: Define `HOST_PROJECT_PARENT` semantics precisely (parent dir of the project, or full project path).
3. **[non-blocking]** Rewrite BLUF to explicitly enumerate all five phases so a skim does not miss Phases 3 and 4.
4. **[non-blocking]** Phase 1: Specify the `$schema` URL or commit to identifying it during implementation.
5. **[non-blocking]** Phase 1: Acknowledge `version` and `description` already exist in both manifests; the genuinely new field is `$schema`.
6. **[non-blocking]** Phase 1: Add verification that `claude plugin tag` works correctly with the monorepo layout (plugin nested under marketplace).
7. **[non-blocking]** Phase 3: Add a step verifying the existing user-level hook fallback continues to work, not only that the repro behaves as expected.
8. **[non-blocking]** Phase 4: Broaden the question from "does `PostInstall` exist?" to "does CC have any plugin install-time hook analogous to npm postinstall?"
9. **[non-blocking]** Consider folding the 250-character skill-description audit from Phase 5 into Phase 1.
10. **[non-blocking]** Add an edge case for the interaction between the existing in-tree symlink and the new parameterized symlink (idempotency).
11. **[non-blocking]** Reword Phase 2's "already landed" to history-agnostic present tense.
12. **[non-blocking]** Align frontmatter tags to underscore convention to match existing cdocs documents.
13. **[non-blocking]** Distinguish #14200 from #16538 in Phase 3 framing; resolution of one does not imply resolution of the other.

## Open Questions for the Author

1. **Phase 2 default behavior.** Which of these is preferred?
   - A: `HOST_PROJECT_PARENT` defaults to empty; symlink only created when set; document maintainer's path as an example, not a default.
   - B: Keep maintainer's path as default; document `HOST_PROJECT_PARENT` as override for non-maintainers.
   - C: Detect host path automatically from `installed_plugins.json` (more complex, more robust).

2. **Phase 1 scope.** Should the 250-character skill description audit move from Phase 5 to Phase 1 (zero-risk mechanical change), or stay deferred for grouping reasons?

3. **Phase 3 success criteria.** If #16538 is partially fixed (e.g., `SessionStart:startup` works but `SessionStart:resume` does not), does that count as "resolved" for the purposes of triggering the follow-up proposal, or do we wait for full resolution?

4. **Phase 4 alternatives.** If neither a CC install-time hook nor a `PostInstall` event exists, is the npm postinstall mechanism already used for OC a candidate for CC delivery (via a hybrid install path), or is that out of scope for this round?
