---
first_authored:
  by: "@claude-opus-4-6"
  at: 2026-03-19T15:15:00-07:00
task_list: clauthier/plugin-hardening
type: devlog
state: live
status: wip
tags: [rules, hooks, opencode, testing, decoupling]
---

# Plugin Hardening: Devlog

## Objective

Three parallel workstreams to harden the cdocs plugin:

1. **Rules hook testing methodology** — propose a verifiable testing approach for the inject-rules.sh hook against ~/code/weft/lace/main, rolling in the OC skill path convention fix.
2. **OC decoupling completion** — amend the existing proposal to fully migrate OC handling to `.opencode/` config only (no `.claude/` leakage), then review for consistency.
3. **Hook fragility fix** — research frontmatter-stripping methods used in the wild, then propose a robust replacement for the awk-based approach in inject-rules.sh.

## Plan

1. Create devlog (this file).
2. Commit the resume bug report (done).
3. Launch three parallel subagents: propose, amend+review, report+propose.
4. Integrate results, review for cross-cutting concerns.
5. Commit artifacts.

## Testing Approach

Each proposal will define its own verification criteria. The rules hook testing proposal specifically addresses how to verify hook behavior against a real consumer project (lace).

## Implementation Notes

_Updated as subagents complete._

## Changes Made

| File | Description |
|------|-------------|
| cdocs/reports/2026-03-19-resume-no-conversations-bug.md | Committed (6bc1895) |
| cdocs/devlogs/2026-03-19-plugin-hardening.md | This devlog |

## Verification

_Pending subagent completion._
