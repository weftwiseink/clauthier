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
| 2 | @claude-opus-4-8 (reviser) | n/a (nit-fold, accepted round 1) | accepted-with-nits-folded | Folded 4 non-blocking review nits: BLUF cost-role framing (proposer 7.4% is smaller of the two conflated roles, not 2nd overall); clarified only `iterate` line 74 is a literal `subagent_type`, `propose-revise` is prose; softened `model: inherit` "reproduces today" claim (omission is the exact no-pin match) and added the OC `MODEL_MAP` unmapped-`inherit` concern with A/B/C Phase 1 gate options. |

## Changes Made

| File | Description |
|---|---|
| `cdocs/proposals/2026-09-22-label-implementer-proposer-agents.md` | New proposal specifying the implementer/proposer dispatch-labeling fix (status: review_ready, accepted round 1). Round 2 folded 4 accepting-round review nits. |
| `plugins/cdocs/agents/implementer.md` | SPEC ONLY (not yet created): `tools: "*"`, `model: inherit`, preloads `cdocs:implement`, Startup rule-reading pattern. A later `/cdocs:iterate` loop creates it. |
| `plugins/cdocs/agents/proposer.md` | SPEC ONLY (not yet created): `tools: "*"`, `model: inherit`, preloads `cdocs:propose`, Startup rule-reading pattern; also serves the reviser role. A later `/cdocs:iterate` loop creates it. |

## Propose-Revise Phase: Result

Proposal `cdocs/proposals/2026-09-22-label-implementer-proposer-agents.md` accepted round 1 (`cdocs/reviews/2026-09-22-review-of-label-implementer-proposer-agents.md`), 4 non-blocking nits folded round 2 (commit `333d8a8`).
Overseer transitioned proposal `status: review_ready` -> `implementation_ready` (trivial frontmatter edit, done inline per `/cdocs:iterate`'s dispatch-carve-out for single-line edits).
Proceeding to `/cdocs:iterate`.

## Iterate Phase

### Turn 0 (Brief)

Scope: full proposal (all 4 implementation phases: create `plugins/cdocs/agents/implementer.md` and `proposer.md`; relabel the two dispatch sites in `iterate/SKILL.md` and `propose-revise/SKILL.md`; update illustrative handles and prose in `iterate/template.md` and `workflow-patterns.md`; update `README.md`'s agent-list and OC-agent-count spots; verify `build-opencode.ts` OC output including the `model:` field per the proposal's A/B/C gate).
Verification floor: config/doc-only change with no runtime service to exercise; verification is static (grep-based confirmation that no remaining `subagent_type: "general-purpose"` literal or prose reference to the old implementer/proposer roles survives at the two dispatch sites, that the new agent files parse as valid frontmatter, and that `npm run build:cdocs` succeeds and the OC agent count/model-field behavior matches the proposal's Phase 4 criteria). Concrete failure-picture: a `grep -rn 'subagent_type: "general-purpose"' plugins/cdocs/skills/iterate/SKILL.md` or the `propose-revise` prose line still matching after the change, or `build:cdocs` erroring/warning unexpectedly, would mean the fix did not land.
`--judge-after` defaults to 3 (not overridden).

Implementer and reviewer this round use the OLD `general-purpose`/`"reviewer"` subagent types, since the new `cdocs:implementer`/`cdocs:proposer` types being created by this very loop do not exist yet (bootstrap constraint, per task instructions).

### Iteration Log

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | overseer_ctx_est | inline_work | notes |
|---|---|---|---|---|---|---|---|---|

### Judge Log

| judge_iteration | trigger | verdict | overseer_thinness | rationale | judge_path |
|---|---|---|---|---|---|

### Dispatch/Return Events

| event | agent_handle | target_files | at | notes |
|---|---|---|---|---|

### Steering Log

| at | kind | target | content | applied_at_iteration |
|---|---|---|---|---|

## Verification

(pending)
