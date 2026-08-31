---
first_authored:
  by: "@gpt-5.6"
  at: 2026-08-31T11:37:54-07:00
task_list: cdocs/codex-support
type: devlog
state: live
status: review_ready
tags: [architecture, codex, proposal]
---

# CDocs Codex Support Proposal Devlog

> BLUF: Define canonical, repository-scoped Codex support for CDocs in the Clauthier source without implementing the design.

## Objective

Author a review-ready proposal that extends the CDocs multi-target architecture to Codex and specifies safe cleanup of the downstream Weftwise experiment.

## Plan

1. Inspect the existing CDocs Claude and OpenCode architecture and strong proposal precedents.
2. Inspect the Weftwise-local wrapper, its devlog, and machine-local Codex state.
3. Verify current Codex plugin and skill behavior against official OpenAI guidance and empirical CLI probes.
4. Specify canonical ownership, packaging boundaries, workflow portability, cleanup, tests, and verification.
5. Run mechanical nit-fix and frontmatter triage, then hand the review-ready proposal to the overseer.

## Testing Approach

This work changes documentation only.
Verification checks document structure, internal references, repository state, and the proposal's testable implementation criteria.

## Investigation Notes

CDocs already uses Claude Code as its canonical authoring format and generates OpenCode-specific agent and package artifacts through `scripts/build-opencode.ts`.

Official Codex guidance distinguishes repository skill discovery under `.agents/skills/` from plugin marketplace installation.
Repository marketplaces are catalogs, while installed plugin cache and enablement remain in `~/.codex`.

Codex custom agents use project-scoped `.codex/agents/*.toml` files rather than Claude markdown agent frontmatter.
The CDocs roles therefore need a narrow generated adapter, especially for `iterate`, reviewer freshness, judge dispatch, tool constraints, and model-role defaults.

The Weftwise experiment is wholly untracked in the repository, but it also created two exact sections in `~/.codex/config.toml` and one versioned plugin cache directory.
Cleanup must use Codex CLI removal commands and verify those exact targets before deleting repository paths.

The existing OpenCode build completes but warns that the Claude reviewer tool declaration `"*"` is unknown and skipped.
The proposal treats this as a characterization requirement before shared build refactoring rather than claiming the current adapter is warning-free.

## Changes Made

| File | Purpose |
| --- | --- |
| `cdocs/devlogs/2026-08-31-cdocs-codex-support-proposal.md` | Session record and evidence trail. |
| `cdocs/proposals/2026-08-31-canonical-codex-support.md` | Canonical Codex packaging, repository deployment, portability, cleanup, and verification design. |

## Verification

The proposal author checklist is complete: the BLUF matches the design, authoritative sources are linked, decisions explain their rationale, failure pictures are observable, and implementation phases carry acceptance criteria.

The nit-fix workflow ran inline because the dispatched environment does not expose formal CDocs agent dispatch.

```text
NIT FIX REPORT
==============
Files processed: 2
Rule files loaded: 3
Mechanical fixes applied: 0

FIXES APPLIED:
- cdocs/proposals/2026-08-31-canonical-codex-support.md: no fixes needed
- cdocs/devlogs/2026-08-31-cdocs-codex-support-proposal.md: no fixes needed

JUDGMENT-REQUIRED:
- No unresolved convention violation found.
```

The triage workflow also ran inline against both documents.

```text
TRIAGE REPORT
=============
Files triaged: 2
Mechanical fixes applied: 0

FIELD FIXES APPLIED:
- cdocs/proposals/2026-08-31-canonical-codex-support.md: no fixes needed
- cdocs/devlogs/2026-08-31-cdocs-codex-support-proposal.md: no fixes needed

TAG CHANGES:
- cdocs/proposals/2026-08-31-canonical-codex-support.md: no change
- cdocs/devlogs/2026-08-31-cdocs-codex-support-proposal.md: no change

STATUS RECOMMENDATIONS:
- cdocs/proposals/2026-08-31-canonical-codex-support.md: recommend wip -> review_ready
- cdocs/devlogs/2026-08-31-cdocs-codex-support-proposal.md: recommend wip -> review_ready

WORKFLOW RECOMMENDATIONS:
- [REVIEW] cdocs/proposals/2026-08-31-canonical-codex-support.md: dispatched author must return an investigation request to the overseer
- [NONE] cdocs/devlogs/2026-08-31-cdocs-codex-support-proposal.md: session record is complete
```

```text
npm run build:cdocs: exit 0
git diff --check: exit 0
proposal structure: PASS
canonical references: PASS
```

The OpenCode build emitted one existing warning while still exiting successfully: `Unknown CC tool "*"` for the reviewer agent.
The proposal surfaces this warning as a Phase 1 characterization item.
