---
review_of: cdocs/proposals/2026-01-30-archive-formalism.md
first_authored:
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-30T12:45:00-08:00
task_list: cdocs/archive-formalism
type: review
state: live
status: done
tags: [rereview_agent, architecture, archival]
---

# Review: Archive Formalism (Round 2)

## Summary Assessment

> BLUF(@claude-opus-4-5-20251101/archive-formalism): The revised proposal addresses all 7 action items from round 1, cleanly separating the immediately-adoptable directory convention from the CLI-dependent automation. The two blocking issues (convention/CLI separation and lazy/eager creation contradiction) are fully resolved. The proposal is well-structured, internally consistent, and ready for acceptance. Verdict: Accept.

## Round 1 Action Item Disposition

### 1. [blocking] Separate convention from CLI: RESOLVED

The revision adds a dedicated "Manual archival procedure" section with a clear 5-step process usable without any CLI tooling.
The BLUF explicitly states the convention is "adoptable immediately via a manual procedure."
The Implementation Phases NOTE clarifies that Phase 1 has no CLI dependency while Phases 2-5 are blocked on the CLI RFP.
This cleanly unblocks the convention from the CLI's lifecycle.

### 2. [blocking] Resolve lazy vs. eager creation contradiction: RESOLVED

The revision consistently specifies lazy creation in both locations.
The directory convention section states: "`_archive/` directory is created lazily: it appears only when a document is first archived."
Phase 1 states: "`_archive/` directories are created lazily on first use, not eagerly scaffolded by `/cdocs:init`."
The `.gitkeep` mention from the original Phase 1 is removed.
No contradiction remains.

### 3. [non-blocking] Acknowledge fragment identifiers: RESOLVED

The path reference scanning section now includes: "Fragment identifiers (e.g., `cdocs/proposals/foo.md#section-heading`) and query strings are handled naturally by literal replacement: the path portion is rewritten and the suffix is preserved."

### 4. [non-blocking] Note binary file skipping: RESOLVED

The scanning section now states: "The scanner skips binary files (detected by null byte presence or file extension heuristics) to avoid corrupting non-text content."

### 5. [non-blocking] Specify unarchive state behavior: RESOLVED

The unarchive section now explicitly states: "Unarchive always sets `state: live` regardless of the pre-archive state.
This is a deliberate simplification: `deferred` or other pre-archive states are not tracked, and the user can manually adjust `state` after unarchiving if needed."
This is a reasonable design choice, clearly documented.

### 6. [non-blocking] Acknowledge symlinks: RESOLVED

A dedicated "Symlinks" subsection in edge cases acknowledges the issue and recommends using path references rather than filesystem symlinks.
This goes beyond the one-liner requested and provides actionable guidance.

### 7. [non-blocking] Track bulk archival as future work: RESOLVED

A dedicated "Bulk archival" subsection in edge cases explicitly marks this as out of scope and tracked as future work for the CDocs CLI.

## New Issues Introduced by Revision

### Manual procedure grep example

**Non-blocking**: The manual archival procedure suggests `grep -r "cdocs/$type/$filename"` but does not mention excluding `.git/` or `node_modules/`.
The automated scanner section specifies these exclusions, but the manual procedure does not.
A user following the manual procedure verbatim could get noisy results from `.git/` objects.
Consider adding `--exclude-dir=.git` or noting that `git grep` is preferable.

### Frontmatter round number

**Non-blocking**: The proposal's `last_reviewed.round` is currently set to `2`, but only round 1 has been completed at the time of revision.
This appears to be a premature update.
This will be corrected as part of this review's frontmatter update.

## Verdict

**Accept.**

All blocking issues from round 1 are resolved.
All non-blocking suggestions have been addressed.
The proposal is internally consistent, well-structured, and follows cdocs writing conventions.

The two new observations are minor: a grep example that could be slightly more robust, and a frontmatter round number that was prematurely incremented.
Neither rises to blocking status.

The proposal is ready for `implementation_ready` status once this review's acceptance is reflected in its frontmatter.

## Action Items

1. [non-blocking] Consider adding `--exclude-dir=.git` to the manual procedure's grep example, or suggesting `git grep` as the preferred search tool.
