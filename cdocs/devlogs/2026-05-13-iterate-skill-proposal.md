---
first_authored:
  by: "@claude-opus-4-7"
  at: 2026-05-13T08:35:00-07:00
task_list: cdocs/iterate-skill
type: devlog
state: live
status: wip
tags: [iterate_skill, oversee, propose, agent_orchestration]
---

# /iterate Skill Proposal: Devlog

## Objective

Author `cdocs/proposals/2026-05-13-iterate-skill.md` for a new `/cdocs:iterate` slash command targeted at "overseer" agents.
The skill encapsulates the iterative implement-review loop the user has repeatedly specified in prompts: an overseer dispatches a fresh implementer, then a fresh QA reviewer, then decides based on verdict, looping with patience until accept-or-escalate.

## Plan

1. Survey existing cdocs (`/oversee` RFP, overseer prompt-engineering report, cdocs skills).
2. Dispatch a research subagent to produce a report on agent-role patterns and the iterative loop, drawing on external prior art (LangGraph, CrewAI, AutoGen, MetaGPT, Aider, OpenHands).
3. Author the proposal informed by the report.
4. Run an iterative `/cdocs:review` loop with fresh subagents until verdict is Accept.
5. Report executive summary back to the user.

## Testing Approach

Proposal-authoring session; no code changes.
Verification is via subagent `/cdocs:review` rounds until Accept.
Dogfoods the iterative-review loop the proposal itself codifies.

## Implementation Notes

- Research subagent wrote a fresh report at `cdocs/reports/2026-05-13-agent-roles-and-iterative-loop.md` rather than amending the existing prompt-engineering report. Rationale: that report's scope is *how to write* the overseer kickoff prompt; the iterative loop deserves equal billing as the most concrete sub-pattern under `/oversee`.
- Naming decision: `/cdocs:iterate` (peer with `/cdocs:implement`, `/cdocs:review`). The `/oversee` RFP names a separate orchestrator skill. `/iterate` is the narrower single-proposal loop; `/oversee` is the multi-proposal arc. They compose.

## Changes Made

| File | Description |
|------|-------------|
| `cdocs/reports/2026-05-13-agent-roles-and-iterative-loop.md` | New report on agent-role taxonomy and iterative loop protocol (research subagent). |
| `cdocs/proposals/2026-05-13-iterate-skill.md` | New proposal for the `/cdocs:iterate` skill. |
| `cdocs/devlogs/2026-05-13-iterate-skill-proposal.md` | This devlog. |

## Verification

Iterative `/cdocs:review` rounds with fresh subagents until Accept; review documents linked from the proposal's `last_reviewed` frontmatter.
