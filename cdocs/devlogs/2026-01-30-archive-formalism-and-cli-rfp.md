---
first_authored:
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-30T12:00:00-08:00
task_list: cdocs/archive-formalism
type: devlog
state: live
status: wip
tags: [proposals, architecture, cli, archival]
---

# Archive Formalism and CLI RFP: Devlog

## Objective

Author two related proposal documents:
1. A full proposal formalizing the cdocs archive layout (`cdocs/$type/_archive/`) with an automated script for archival and path reference renaming.
2. An RFP for a general-purpose CDocs CLI (TypeScript) that the archival script belongs to, alongside other pure-logic actions like frontmatter templating, document search, and status listing.

The archival proposal's implementation is blocked on the CLI RFP being elaborated and accepted.

## Plan

1. Read existing proposals, templates, frontmatter spec, and writing conventions for style alignment.
2. Draft the RFP for the CDocs CLI first (since the archival proposal depends on it).
3. Draft the full archival formalism proposal, referencing the CLI RFP as a dependency.
4. Self-review both documents against the author checklist.

## Testing Approach

Documentation-only session: no code changes to test.
Verification is structural: frontmatter validity, section completeness, cross-references.

## Implementation Notes

Both documents address a real pain point: archived documents currently have no formal home, and path references become stale when documents move.
The CLI RFP is intentionally kept lightweight: it captures the need for a standalone TypeScript tool without over-specifying the design, leaving room for elaboration.

## Changes Made

| File | Description |
|------|-------------|
| `cdocs/proposals/2026-01-30-cdocs-cli.md` | RFP for general-purpose CDocs CLI |
| `cdocs/proposals/2026-01-30-archive-formalism.md` | Full proposal for archive layout and automated renaming |
| `cdocs/devlogs/2026-01-30-archive-formalism-and-cli-rfp.md` | This devlog |

## Verification

Frontmatter validated against `plugins/cdocs/rules/frontmatter-spec.md`.
Both documents follow proposal template structure and writing conventions.
