---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-22T00:00:00-07:00
task_list: meta/agent-dispatch-labeling
type: devlog
state: live
status: wip
tags: [meta, tooling, cost, orchestration, agent-dispatch]
---

# Agent Dispatch Labeling: Full-Send Devlog

> BLUF(claude-sonnet-5/agent-dispatch-labeling): Running `/cdocs:full-send` end-to-end on the proposal to label implementer/proposer subagents at dispatch time (`cdocs:implementer`/`cdocs:proposer` instead of bare `general-purpose`), per action item #1 of `cdocs/reports/2026-09-20-token-spend-by-role.md`.

## Objective

Fix the labeling gap diagnosed in `cdocs/reports/2026-09-20-token-spend-by-role.md`: `/cdocs:iterate` and `/cdocs:propose-revise` dispatch their implementer/proposer/reviser roles with bare `subagent_type: "general-purpose"`, making them invisible to any `cdocs:*`-scoped usage-DB query. Add dedicated `cdocs:implementer` and `cdocs:proposer` agent types, same tool allowlist, update the two dispatch sites, and check `full-send`/`oversee` for their own direct dispatches that would also need the fix.

## Plan

1. `/cdocs:propose-revise` loop (this devlog's Turn 0-N): dispatch a fresh proposer to author `cdocs/proposals/2026-09-22-label-implementer-proposer-agents.md`, then run review/revise rounds to `review_ready` + accepted.
2. `/cdocs:iterate` loop: dispatch fresh implementer/reviewer (old `general-purpose`/`"reviewer"` types, since the new types don't exist until this proposal lands) to implement, review, and drive to accept-or-escalate.
3. Land the work with frequent conventional commits.

## Overseer Mode

This session runs both loops in overseer mode per `orchestration-discipline.md`: dispatch-by-default (propose-revise's stricter "even trivial ones" bar applies through the propose-revise phase), single-writer file ownership, fresh reviewer/judge each round, durable state in this devlog before compacting.

## Propose-Revise Phase

### Iteration Log (propose-revise)

| round | proposer/reviser | reviewer | verdict | notes |
|---|---|---|---|---|
| 1 | @claude-opus-4-8 (proposer) | n/a (self-review) | review_ready | Authored proposal; self-review added the path-restriction-hook trap (do not confine implementer/proposer) as an edge case + Phase 3 constraint. Reviser reuses `cdocs:proposer`; new agents use `model: inherit` (no pin); full-send/oversee confirmed to inherit the fix by composition (no own dispatch). |

## Changes Made

| File | Description |
|---|---|
| `cdocs/proposals/2026-09-22-label-implementer-proposer-agents.md` | New proposal specifying the implementer/proposer dispatch-labeling fix (status: review_ready). |
| `plugins/cdocs/agents/implementer.md` | SPEC ONLY (not yet created): `tools: "*"`, `model: inherit`, preloads `cdocs:implement`, Startup rule-reading pattern. A later `/cdocs:iterate` loop creates it. |
| `plugins/cdocs/agents/proposer.md` | SPEC ONLY (not yet created): `tools: "*"`, `model: inherit`, preloads `cdocs:propose`, Startup rule-reading pattern; also serves the reviser role. A later `/cdocs:iterate` loop creates it. |

## Verification

(pending)
