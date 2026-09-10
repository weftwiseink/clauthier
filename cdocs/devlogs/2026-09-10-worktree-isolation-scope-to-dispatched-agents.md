---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-10T11:50:03-07:00
task_list: clauthier/worktree-isolation-scope
type: devlog
state: live
status: wip
tags: [architecture, orchestration, worktree, isolation, overseer, full-send]
---

# Worktree Isolation → Scope to Dispatched Agents, Not the Overseer: Devlog

## Objective

Loosen/remove worktree-isolation constraints so a **top-level session (overseer) is never
isolation-bound**. Isolation is a property of NESTED DISPATCHED agents (implement/review
subagents) only. The overseer must stay free to land (merge into `main` / resolve a worktree)
and fork (create a new worktree off `main`).

Driver: user request + report
`weftwise/main/cdocs/reports/2026-09-10-worktree-isolation-vs-overseer-guardrails.md`.

User correction to the report's framing: the binding constraint is clauthier-**authored** text
on existing commands (whose scope was meant to be nested-agents-only), not primarily the harness
sandbox. Primary work is the clauthier-side re-scope; harness-advocacy items are secondary
(relay/document only).

This is a `/cdocs:full-send`: `/cdocs:propose-revise` (author + review/revise to accept), then
`/cdocs:iterate` (implement-review to accept-or-escalate). I run both AS overseer.

## Plan

1. Devlog (this file). ✅
2. propose-revise loop: dispatch `/cdocs:propose` → review/revise until accept.
3. iterate loop: dispatch implement/review/judge until accept-or-escalate.
4. Land per repo workflow.

## Overseer Iteration Log

| Turn | Phase | Action | Dispatched | Result | Ctx est. | Inline work |
|------|-------|--------|-----------|--------|----------|-------------|
| 0 | setup | grounding read (report + clauthier surfaces), devlog scaffold | — (inline, setup) | devlog created | ~55K | grounding only |

## Key surfaces (grounding, for the proposer brief)

- `plugins/cdocs/skills/iterate/SKILL.md:18` — "worktree usage practices … contain the workstream" (ambiguous scope).
- `plugins/cdocs/agents/reviewer.md:45,49-51` — nested-agent boundaries (correct home for isolation language).
- `plugins/cdocs/rules/orchestration-discipline.md:59` — "a hard tool-allowlist on the top-level session is not available"; graded enforcement (3 layers); Phase-5 advisory hook (not built).
- `plugins/cdocs/rules/oversee-arc.md:57-81` — claim registry (cooperative clobber-safety to promote to first-class).
- `plugins/cdocs/skills/{oversee,full-send}/SKILL.md` — confirm nothing confines the overseer to a worktree.

## Decisions Made

- Thesis fixed by the user; the proposal must not re-open whether the overseer should be isolated.

## Verification

(pending — recorded at each loop terminal)
