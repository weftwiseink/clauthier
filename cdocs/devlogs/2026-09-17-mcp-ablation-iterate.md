---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-17T20:00:00-08:00
task_list: cdocs/mcp-ablation
type: devlog
state: live
status: done
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

> RESULT(2026-09-17): graphify feature ADDED + committed to lace's `.devcontainer/devcontainer.json`
> (lace commits `ae6c193` + `d6671d1` bash-history side-fix; NOT pushed); claude-code confirmed
> expansion-provided by lace-fundamentals; `lace validate` passes; graphify 0.9.61 CLI verified against
> lace source (537 nodes) in an EQUIVALENT throwaway container.
> **BLOCKER 1 (sprack):** `lace up --rebuild` failed on a PRE-EXISTING `sprack` local-feature fetch bug.
> RESOLVED per user: sprack commented out w/ maybe-deprecated TODO (lace commit `c3757dd`, not pushed);
> `lace validate` passes (graphify+claude-code retained, no sprack).
> **BLOCKER 2 (node/nvm):** with sprack gone, the build progressed past feature-fetch and image-build
> start, then FAILED installing the transitive `ghcr.io/devcontainers/features/node` feature: nvm
> refuses to run because lace's `.devcontainer/Dockerfile:77` sets
> `ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global`. Pre-existing, independent of graphify+sprack.
> Subagent STOPPED (did not edit the Dockerfile — ENV may be load-bearing for lace's npm-global). REAL
> lace container still does not build. graphify 0.9.61 + claude 2.1.275 already PROVEN in an equivalent
> container (same base+pins, lace source → 537 nodes/1661 edges). e2e execution-env decision → user.

## Iteration Log

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | overseer_ctx_est | inline_work | notes |
|---|---|---|---|---|---|---|---|---|
| 1 | impl-1 (general-purpose) | rev-1 (cdocs:reviewer) | accept | confirmed | cdocs/reviews/2026-09-17-review-of-mcp-tool-effectiveness-ablation-impl-r1.md | ~95K (10% inline) | no | 43/43 tests re-run+cited by reviewer; live 3-subagent dispatch is deferred-to-followup to e2e; accepting-round should-fixes to clear (graphify CLI-first detection is load-bearing for e2e) |

## Judge Log

| judge_iteration | trigger | verdict | overseer_thinness | rationale | judge_path |
|---|---|---|---|---|---|

## Dispatch/Return Events

| event | agent_handle | target_files | at | notes |
|---|---|---|---|---|
| dispatch | impl-1 (general-purpose) | plugins/cdocs/skills/ablate/*, scripts/ablate/* (new) | 2026-09-17T20:00:00-08:00 | Phases 1,2 + Phase 4 reference invocation |
| return | impl-1 (general-purpose) | plugins/cdocs/skills/ablate/{SKILL.md,ablate.sh,test-ablate.sh} | 2026-09-17T20:10:00-08:00 | 43/43 unit tests pass; proposal → implementation_wip; deferred parts named |
| dispatch | rev-1 (cdocs:reviewer) | cdocs/reviews/2026-09-17-review-of-mcp-tool-effectiveness-ablation-impl-r1.md | 2026-09-17T20:11:00-08:00 | re-run tests; verify meter field names + no bare stash + thinness |
| return | rev-1 (cdocs:reviewer) | cdocs/reviews/2026-09-17-review-of-mcp-tool-effectiveness-ablation-impl-r1.md | 2026-09-18T09:00:00-08:00 | ACCEPT round 1; 1 load-bearing should-fix (graphify CLI-first detection) + 2 should-fix + 2 nits |
| dispatch | impl-1 (resumed) | plugins/cdocs/skills/ablate/{SKILL.md,ablate.sh}, proposal frontmatter | 2026-09-18T09:05:00-08:00 | clear accepting-round should-fixes; graphify CLI `.input.command` detection |
| dispatch | lace-infra (resumed, outside loop) | lace repo .devcontainer/devcontainer.json + container rebuild | 2026-09-18T09:05:00-08:00 | comment out sprack (maybe-deprecated) + TODO; lace up --rebuild real container |
| return | lace-infra (outside loop) | lace repo commits d6671d1, ae6c193, c3757dd (not pushed) | 2026-09-18T09:35:00-08:00 | sprack FIXED; real lace container still blocked by 2nd pre-existing bug (node/nvm vs NPM_CONFIG_PREFIX). User → use clauthier lace container instead |
| dispatch | e2e-runner (general-purpose) | in-container run dirs only; reports scorecards | 2026-09-18T09:45:00-08:00 | drive /cdocs:ablate in clauthier lace container; 2 lightweight probes (VALID + VOID honesty path) |
| return | e2e-runner (general-purpose) | /tmp/ablate-e2e-host/{probeA,probeB}/* (host artifacts) | 2026-09-18T10:20:00-08:00 | E2E SUCCESS — real skill, all 3 subagents dispatched vs live graphify; VALID + VOID scorecards emitted + overseer-verified |

## Steering Log

| at | kind | target | content | applied_at_iteration |
|---|---|---|---|---|
| 2026-09-18T09:40:00-08:00 | steer-implementer | e2e-runner | User: use the WORKING clauthier lace container for the e2e (not the real lace container, blocked by 2 pre-existing lace infra bugs). It has graphify + claude-code + the clauthier repo (so cdocs/ablate skill is present). | e2e |

**LOOP ACCEPTED (round 1) — accepting-round should-fixes cleared.** impl-1 resolved all four:
(S1, load-bearing) graphify CLI-first usage detection via a `cli:<regex>` `--tool` form matching a Bash
`tool_use` `.input.command` — the e2e usage gate now works; (S2) dispatch wording reconciled with
single-tool-allowlist gating; (S3) proposal status reverted to spec-valid `implementation_ready`
(no wip enum exists); (nits) `decide` refuses null-completion on non-VOID runs, `resolve-transcript`
warns loudly on agentId fallback. Overseer re-ran `test-ablate.sh`: **49/49 pass**, no worktree leak.
Commits `85809e4`, `751616e`, `caa3e34`. Only remaining verification is the deferred-to-followup e2e
(live 3-subagent dispatch + graphify dogfood) inside the real lace container.

**E2E DOGFOOD — CONFIRMED (overseer-verified against on-disk scorecards).** The real `/cdocs:ablate`
skill ran end-to-end inside the clauthier lace container (`graphify 0.9.61`, `claude 2.1.274`),
dispatching all three subagents (2 arms + opus evaluator) against LIVE graphify. No fallback; no committed
skill files edited. Two probes, single-shot (`gate_admissible:false`, correct):
- **Probe A = VALID** (`/tmp/ablate-e2e-host/probeA/scorecard.json`): assisted 31190 tok / unassisted
  31031 tok (delta +159, corroborating only); `tool_invocation_confirmed:true` (5 real `graphify`
  Bash tool_uses); **`context_gap: 0`** — HONEST: the single-file explain task was fully reconstructable
  by reading one file, so graphify's blast-radius strength was not exercised; the evaluator scored 0 and
  said so rather than manufacturing a positive. Metering populated from real `toolUseResult` payload.
- **Probe B = VOID (`available_unused`)** (`/tmp/ablate-e2e-host/probeB/scorecard.json`): assisted arm
  had graphify but never invoked it → correctly VOID, `context_gap:null`, no evaluator dispatched — the
  "absent != no-effect" honesty path holds end to end.

> FINDING(opus/cdocs/mcp-ablation, follow-up): CLI-tool WITHHOLDING is soft, not a hard capability gate.
> The Agent/Task dispatch surface exposes no per-call `--disallowedTools`/allowlist, so the unassisted
> arm's withhold is expressed at the PROMPT layer (dispatch prompt forbids graphify) + confirmed post-hoc
> by `ablate.sh detect-usage`. It HELD in both probes (unassisted never called graphify), and is honestly
> labeled in `invariants.json`, matching SKILL.md's documented fallback direction — but it relies on arm
> compliance + post-hoc verification, not enforced denial. Follow-up: a per-arm agent definition that
> omits Bash-graphify, or a PATH-scrubbed wrapper, for a hard withhold.

> BUGS SURFACED BY THE E2E (the dogfood earned its keep):
> 1. **jq reserved-word `label` (FIXED, `4f9b353`)** — `cmd_meter` bound `--arg label`/`$label`, a compile
>    error under the container's jq 1.6 (`label` is reserved for `label/break`), breaking every meter call.
>    Host jq tolerated it, so the 49/49 unit tests missed it. Renamed to `$armlabel`; 49/49 still pass.
> 2. **`cli:^` anchor false-VOID (FIXED, `80e4f49`)** — worktree arms prefix commands with `cd <worktree>
>    && …`, so a `^`-anchored `cli:^graphify ` matched the leading `cd`, not `graphify`, and `detect-usage`
>    falsely returned `unused` → a FALSE VOID on a run where the tool WAS used. Fixed: `detect-usage` now
>    matches the `cli:` signature at a COMMAND BOUNDARY (splits `.input.command` on `&&`/`||`/`;`/`|` and
>    tests each segment plus the whole string), so `^` anchors to a real command through the worktree
>    `cd`-prefix; true negatives preserved. SKILL.md reconciled; +4 regression fixtures (53/53 pass).

## Completed

- Turn 0 Brief written; scope, floor, and the subagent-dispatch structural constraint recorded.
- impl-1 r1 + accepting-round fixes; rev-1 ACCEPT; overseer-verified 49/49 unit tests.
- E2E dogfood CONFIRMED in the clauthier lace container: VALID + VOID scorecards, overseer-verified on
  disk. `/cdocs:ablate` works end to end in a real depending project against live graphify.
- impl-1 round 1: `plugins/cdocs/skills/ablate/{SKILL.md, ablate.sh, test-ablate.sh}` created; 43/43 unit
  tests pass (real worktree isolation w/o stash touch; meter aggregation; VALID/VOID/TASK-FAIL fixtures;
  single-shot `gate_admissible:false`). Proposal → `implementation_wip`.

> NOTE(opus/cdocs/mcp-ablation): impl-1 deviation from proposal wording — the real result payload uses
> `toolUseResult.totalTokens`/`totalDurationMs`, NOT `subagent_tokens`/`duration_ms` (those are the
> notification-surface names; both surfaces exist). Meter reader targets the real names and aliases the
> placeholders. Confirmed only from persisted transcripts; live-dispatch nesting deferred to e2e.

## Decisions Made

- Scope = Phases 1, 2, + Phase 4 reference invocation; Phase 3 (N-trials) deferred.
- Dispatch-dependent verification is `deferred-to-followup` to the post-loop lace-container e2e test.

## Open Todos

- [x] impl-1 round 1; captured.
- [x] Review round 1 (rev-1 ACCEPT); accepting-round should-fixes cleared.
- [x] E2E ablate test — done in the clauthier lace container (per user; real lace container blocked by 2
  pre-existing lace infra bugs). VALID + VOID scorecards, overseer-verified.
- [ ] FOLLOW-UP (not started; awaiting user): hard CLI-tool withhold (agent-def omission / PATH scrub) —
  see FINDING above. Also: lace's own container needs its Dockerfile `NPM_CONFIG_PREFIX` vs node-feature
  bug fixed before it can build (lace repo; graphify feature already committed there, not pushed).
- [x] Human acceptance (2026-09-22): user accepted; proposal → `implementation_accepted`. Loop CLOSED.
