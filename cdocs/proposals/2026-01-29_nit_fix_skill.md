---
first_authored:
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-29T14:00:00-08:00
task_list: cdocs/nit_fix
type: proposal
state: live
status: request_for_proposal
tags: [claude_skills, workflow_automation, writing_conventions]
---

# Nit Fix Skill

> BLUF(mjr/cdocs/nit-fix): A haiku-powered `/cdoc:nit_fix` skill that reviews documents for easily-amended rules violations and fixes them directly.
> Targets mechanical writing convention violations (history-agnostic framing in proposals, mermaid vs ASCII diagrams, callout syntax, punctuation preferences) that don't require deep judgment to resolve.

## Objective

CDocs has a growing set of writing conventions (`rules/writing_conventions.md`) that are easy to violate and tedious to enforce manually.
A lightweight haiku subagent can scan documents for mechanical violations and fix them, similar to a linter but for prose conventions.

## Scope

This proposal should explore:

- Which writing conventions are mechanically detectable and fixable by haiku.
- The boundary between "nit fix" (haiku can fix) and "review finding" (requires judgment).
- Whether nit_fix runs as a standalone skill, as part of triage, or both.
- The relationship to the existing PostToolUse frontmatter validation hook.

## Known Convention Targets

- History-agnostic framing violations in proposals (references to "previously", "now updated", "old approach").
- ASCII diagrams that should be mermaid.
- Em-dash usage where colons/spaced hyphens are preferred.
- Missing or malformed callout attributions (`NOTE:` without `(author/workstream)`).
- Emoji usage in documentation.
- Multi-sentence lines (sentence-per-line violations).

## Open Questions

- Should nit_fix apply fixes directly or present them for approval?
- Should it operate on a single file or scan all cdocs?
- How does it interact with the triage subagent (complementary? integrated?)?
