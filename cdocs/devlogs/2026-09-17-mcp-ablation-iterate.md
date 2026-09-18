---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-17T20:00:00-08:00
task_list: cdocs/mcp-ablation
type: devlog
state: live
status: wip
tags: [cdocs, iterate, ablation, tooling, verification, graphify]
---

# MCP-tool effectiveness ablation harness (iterate loop): Devlog

## Objective

Overseer log for a `/cdocs:iterate` loop implementing
[`cdocs/proposals/2026-09-17-mcp-tool-effectiveness-ablation.md`](../proposals/2026-09-17-mcp-tool-effectiveness-ablation.md)
(`status: implementation_ready`): the `/cdocs:ablate` skill + helper script — an assisted-vs-unassisted
ablation harness that proves whether a given MCP tool helps a cdocs task.

## Turn 0 Brief

### Scope

**Phases 1, 2, and the Phase 4 graphify-wiring reference invocation. Phase 3 (N-trials) DEFERRED.**

- **Phase 1** — minimal single-shot harness: the capability spike (per-subagent single-tool
  gating; per-tool-call transcript visibility) FIRST, then the helper script (fresh throwaway
  worktree per arm off a pinned base, no stash; teardown `git worktree remove --force`; meter
  aggregation from `subagent_tokens`/`duration_ms`), then the `/cdocs:ablate` skill spec that
  dispatches two arms with the tool granted/withheld, meters each, and emits the VALID/VOID/TASK-FAIL
  outcome via the usage precondition.
- **Phase 2** — opus evaluator + `scorecard.json`/`scorecard.md` (context-gap primary causal axis;
  token delta corroborating; wallclock indicative; `gate_admissible` on the machine artifact).
- **Phase 4** — document the graphify invocation as the reference tool-agnostic consumer example.
  The LIVE graphify dogfood is run post-loop as the e2e test inside the lace devcontainer (below).
- **Phase 3 (N-trials) deferred** — the e2e test is single-shot with the loud caveat; N-trials is a
  follow-up.

### Structural constraint (shapes review_proof)

A DISPATCHED implementer subagent **cannot dispatch subagents** (`Task` unavailable inside subagents),
but `/cdocs:ablate` runs by dispatching 3 subagents (2 arms + evaluator). So the implementer BUILDS the
skill + helper script and UNIT-TESTS the deterministic mechanics it can exercise directly (worktree
create/teardown without touching the stash; meter aggregation from a mock payload; transcript
`tool_use` parsing; VALID/VOID/TASK-FAIL decision logic on fixtures). The full multi-subagent dispatch
is `deferred-to-followup`: it is exercised by a TOP-LEVEL session in the post-loop e2e test in the lace
devcontainer, where a real graphify tool is available to the arms.

### Verification floor

> The helper script deterministically creates two isolated worktrees off a pinned base and tears them
> down WITHOUT touching the shared stash stack, and aggregates `subagent_tokens`/`duration_ms` from a
> result payload into per-arm meter files; the `/cdocs:ablate` skill correctly specifies the
> VALID/VOID/TASK-FAIL outcome logic and tool-invocation detection from a transcript `tool_use` block,
> and single-shot runs set `gate_admissible: false`.
> Failure pictures: the harness fabricates meter numbers instead of reading the payload; it uses bare
> `git stash`; or it would emit a "no effect" scorecard for a run where the target tool was never
> invoked (VOID mislabeled). Full multi-subagent dispatch is validated in a separate top-level e2e run
> (`deferred-to-followup`), since a dispatched implementer cannot itself dispatch subagents.

### Parallel work (not part of this loop)

A background subagent is adding the graphify feature to the **lace repo's own** devcontainer and
rebuilding it, to serve as the "depending project" for the post-loop e2e ablate test. Tracked outside
this loop; the e2e test depends on BOTH the loop's accepted skill AND that container.

## Iteration Log

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | overseer_ctx_est | inline_work | notes |
|---|---|---|---|---|---|---|---|---|

## Judge Log

| judge_iteration | trigger | verdict | overseer_thinness | rationale | judge_path |
|---|---|---|---|---|---|

## Dispatch/Return Events

| event | agent_handle | target_files | at | notes |
|---|---|---|---|---|
| dispatch | impl-1 (general-purpose) | plugins/cdocs/skills/ablate/*, scripts/ablate/* (new) | 2026-09-17T20:00:00-08:00 | Phases 1,2 + Phase 4 reference invocation |

## Steering Log

| at | kind | target | content | applied_at_iteration |
|---|---|---|---|---|

## Completed

- Turn 0 Brief written; scope, floor, and the subagent-dispatch structural constraint recorded.

## Decisions Made

- Scope = Phases 1, 2, + Phase 4 reference invocation; Phase 3 (N-trials) deferred.
- Dispatch-dependent verification is `deferred-to-followup` to the post-loop lace-container e2e test.

## Open Todos

- [ ] impl-1 round 1; capture path.
- [ ] Review round 1.
- [ ] Post-loop e2e ablate test in lace devcontainer (depends on background lace-container rebuild).
