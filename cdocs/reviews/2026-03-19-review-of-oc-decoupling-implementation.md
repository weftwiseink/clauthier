---
review_of: cdocs/devlogs/2026-03-19-decouple-oc-build-from-cc-plugin.md
first_authored:
  by: "@claude-opus-4-6"
  at: 2026-03-19T17:45:00-07:00
task_list: cdocs/opencode-decoupling
type: review
state: live
status: done
tags: [self, implementation, postinstall, verification, opencode]
---

# Review: OC Decoupling Implementation

## Summary Assessment

This implementation rewrites the OC postinstall script to confine all artifact output to `.opencode/` directories, eliminating `.claude/` leakage.
The code closely follows the proposal's specification and all verification checks pass: skills land flat at `.opencode/skills/<name>/`, rules at `.opencode/rules/cdocs/`, no `.claude/` directories are created, the source-repo guard works, and the build script produces a matching copy.
The documentation amendments to the multi-target marketplace proposal are accurate and well-placed.
Verdict: **Accept** with two non-blocking suggestions.

## Section-by-Section Findings

### Postinstall Rewrite (`plugins/cdocs/scripts/postinstall.js`)

The implementation matches the proposal's code specification exactly.
Key correctness checks:

1. **Source-repo guard** (lines 26-33): correctly checks for `plugins/cdocs/.claude-plugin/plugin.json` relative to `PROJECT_ROOT`.
   Uses `INIT_CWD` (npm-set) with `cwd()` fallback -- this is the standard pattern for npm postinstall scripts.
   Verified: running with `INIT_CWD` pointing to the source repo outputs "source repo detected, skipping postinstall".

2. **Flat skill copying** (lines 49-62): `copySkillsFlat` iterates skill directories with `readdirSync` using `withFileTypes: true` and filters to directories only.
   Each skill copies to `.opencode/skills/<name>/` without a `cdocs/` prefix.
   Verified: all 10 skills appear as flat directories in the test install.

3. **Namespaced rules** (lines 67-75): `copyRules` copies the entire rules directory to `.opencode/rules/cdocs/`.
   The `recursive: true` flag on both `mkdirSync` and `cpSync` handles the nested path creation.
   Verified: all 3 rule files present at `.opencode/rules/cdocs/`.

4. **No `.claude/` references**: the file contains zero occurrences of `.claude` in destination paths.
   The only `.claude` reference is in the JSDoc header explaining what this script does NOT do.
   This is correct.

5. **`.opencode/` creation** (line 78): always creates `.opencode/` before copying.
   This removes the prior conditional logic that fell back to `.claude/`.

**No blocking issues.**

### Build Script Alignment

`npm run build:cdocs` succeeds.
The built `build/cdocs/opencode/scripts/postinstall.js` is byte-identical to the source at `plugins/cdocs/scripts/postinstall.js` (verified via `diff`).
The build script (`scripts/build-opencode.ts`) required no changes -- it copies the postinstall as-is, which is the expected behavior.

**No issues.**

### Documentation Amendment (Multi-Target Marketplace Proposal)

Two changes made:
1. A NOTE callout added after the stale postinstall description in Section 5, clearly referencing the decoupling proposal and stating the new behavior.
2. The inline description of postinstall behavior updated from `.opencode/skills/cdocs/` and `.claude/rules/` to the correct `.opencode/`-only paths.

Both changes address the blocking item #2 from the prior review round.

**No issues.**

### Devlog Updates

The devlog accurately documents the implementation:
- Phase 3 section describes all key changes with a verification transcript.
- Phase 4 section documents the multi-target marketplace amendment and the evolved RFP status.
- The verification commands show concrete PASS results for all checks.

One concern: the verification transcript uses placeholder paths (`/path/to/build/cdocs/opencode`, `/path/to/source/repo`) rather than the actual paths used during testing.
This is minor -- the actual verification was performed with real paths and the results are accurate.

**Non-blocking.** Consider using actual paths in the devlog verification transcript for traceability.

### Prior Review Blocking Items Resolution

The prior review (round 1) identified two blocking issues:
1. **Rule delivery overlap**: the proposal now includes "Postinstall delivers baseline rules; `/cdocs:init` enhances them" as an explicit design decision (lines 283-290 of the proposal).
   This was already present in the proposal before this implementation session.
2. **Multi-target marketplace update**: addressed by this implementation (amendment NOTE added).

Both blocking items are resolved.

### Verification Completeness

The implementation verified:
- Skills at flat `.opencode/skills/<name>/` paths (10 skills confirmed)
- Rules at `.opencode/rules/cdocs/` (3 files confirmed)
- No `.claude/` directory creation
- Source-repo guard detection
- `CDOCS_SKIP_POSTINSTALL=1` opt-out
- Build output matches source
- Build script runs cleanly

Not verified (cannot be verified programmatically):
- CC skills loading after marketplace re-registration (requires new CC session -- Phase 2 was done in a prior session)
- OC skill discovery in a live OC instance

The unverified items are acknowledged limitations of the test environment, not gaps in the implementation.

**Non-blocking.** The devlog could note the verification gap for CC skill loading and OC skill discovery as items that require manual testing in a live session.

## Verdict

**Accept.**
The implementation correctly rewrites the postinstall to confine all output to `.opencode/`, matches the proposal specification, and passes all verifiable test cases.
Documentation amendments are accurate.
Prior review blocking items are resolved.

## Action Items

1. [non-blocking] Use actual paths (not placeholders) in the devlog verification transcript for traceability.
2. [non-blocking] Note in the devlog that CC skill loading and OC skill discovery require manual verification in live sessions.
