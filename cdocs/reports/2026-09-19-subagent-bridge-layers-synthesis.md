---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-19T15:00:00-07:00
task_list: cdocs/subagent-bridge-layers
type: report
state: live
status: wip
tags: [research, synthesis, a2a, subagents, acp, hybrid, decision_rule]
---

# Delegating Claude Code subagent work across models and harnesses: synthesis of the bridge-layer arc

> BLUF: Use a hybrid.
> Native Claude Code (CC) subagents stay the default: per-call `model`, plus static per-effort agent
> variants to recover missing per-call effort.
> Route to a bridge only for self-contained, one-message, read-mostly or sandboxed tasks where a non-Claude
> model has a demonstrated advantage.
> The bridge is a thin MCP shim over ACP (acpx, Codex and Gemini adapters) first, and OpenCode `serve` when
> provider breadth or concurrency matters.
> Three shim behaviors are load-bearing and unverified (cancel propagation, mid-call elicitation,
> busy-session `prompt_async`); each has a small experiment, and each adoption stage is gated on them.

Sources: [survey][survey] (with its Supplemental section) and [feature breakdown][breakdown].
No live experiments were run for this synthesis.
Facts below are carried from those reports; UNVERIFIED flags are preserved.
Section references use the form `survey: Supplemental` or `breakdown: 7`.

## Problem

- **No per-call effort.** The `Agent` tool takes a per-invocation `model` but `effort` is frontmatter-only.
  Requests are closed or open without a fix (`breakdown: Key Findings`; `survey: Key Findings`).
- **Non-Claude providers are unreachable natively.**
  `model:` accepts Anthropic aliases and IDs only.
  Gateway routing is process-wide and Anthropic states it does not support non-Claude models behind a
  gateway (`survey: Key Findings`).
- **Subscription TOS constrains the direction.**
  Anthropic permits an end user on the unmodified CC binary; third-party use of subscription OAuth is
  prohibited.
  So CC stays orchestrator on the subscription and delegates *out* on each vendor's own auth (`survey: BLUF`).
- **Bash to other CLIs loses the subagent contract.**
  No interrupts, streaming, multi-turn steering, or permission relay (`survey: Context`).

## What native subagents give

Native is a bundle of about a dozen separable mechanisms (`breakdown: BLUF`, `breakdown: Feature table`).
Cheap for a bridge to copy: fresh-context isolation, single-message return, role definitions, parallelism,
model choice.
Expensive or impossible: permission relay into the parent UI, mid-run steering, cache sharing, fork,
in-harness hooks, enforced worktree isolation.

Native gaps a bridge can beat (`breakdown: Recommendations` 2):

- No per-call effort or thinking control.
- No non-Claude targets.
- No subagent-scoped budget.
- Requested model is not always the served model: six open issues, first [#83920][i83920] (`breakdown: 2`).

## Landscape of bridge approaches

![Landscape: CC to approaches to targets, with TOS-risk edges][f1]

*Figure 1. CC reaches other harnesses through five approaches; only the MCP shim path keeps CC unmodified,
  on subscription, with non-Claude traffic on vendor auth.*

| Approach | Gives | Costs | Verdict |
|---|---|---|---|
| A. Proxy (CCR, LiteLLM) | Zero CC-side code | API billing, Anthropic-unsupported, no new harness | Skip |
| B. MCP wrapper | Works today, per-call args | Sync call, hand-built permission relay | Front door |
| C. ACP / A2A protocol | Cancel, steer, permission as state | No CC client; young adapters | Behind B |
| D. CLI subprocess | Trivial | No steering, bypass-or-nothing permissions | MVP only |
| E. SDK / own orchestrator | Full control | Replaces CC; Agent SDK on plan is TOS-gray | Skip |

Source: `survey: Architectural approaches`.
Proxies and swarm frameworks (ruflo, oh-my-claudecode) replace or bypass the subagent contract; the survey
ranks them last (`survey: Recommendations` 5-6).

## Top 2 candidates vs native

Candidates (`survey: Top 2 candidates`, `survey: Supplemental`):

1. **ACP bridge.** ACP vocabulary equals the subagent contract: sessions, cancel, tool calls, permission
   requests.
   A headless client already exists ([acpx][acpx], pre-1.0), so the shim is optional for read-mostly work.
2. **OpenCode server.** One HTTP API with per-message `model` and `agent`, `prompt_async`, `abort`,
   permission endpoint, SSE.
   Claude models via API key only, which is acceptable because Claude work stays in CC.

They are complementary: `opencode acp` lets acpx drive OpenCode (`survey: Supplemental`, conclusion shifts).

![Native vs bridged control flow across six phases][f2]

*Figure 2. Bridged delegation adds a shim hop to every phase; interrupt, permission, and busy-session resume
  depend on unverified links.*

Head-to-head, condensed from `survey: Supplemental, Head-to-head`:

| Dimension | Native | Bridge (ACP or OpenCode) |
|---|---|---|
| Model choice | Claude tiers; served-model bugs | Any provider; read served model back |
| Effort | Frontmatter only | Codex per-call; OpenCode per-agent; Gemini none |
| Hooks | `SubagentStart/Stop`, `agent_id` on child tools | Only the shim MCP call fires hooks |
| Worktree | Enforced | Shim-made; enforced only by Codex sandbox |
| Permission relay | Native, child named | Elicitation or shim (unverified) |
| Fork, prompt cache | Yes | No |
| Depth and spend caps | 20 concurrent, depth 3 | Built in shim |
| Plan tokens for child | Draws on plan | None beyond shim call and result |

## Requirement coverage

Scores follow the checklist in `breakdown: Bridge requirements checklist`.
Bridge scores carry over from `survey: Supplemental` (F/P shown as P).
Native scores and the hybrid column are this report's judgment from `breakdown`: native depth and spend caps
score P because spend caps are SDK-only (`breakdown: 10`).

![Coverage heatmap of the bridge checklist][f3]

*Figure 3. Bridges win only on non-Anthropic targets and (partly) per-call effort; native holds the rest.*

| Requirement | Nat | ACP | OC | Hyb |
|---|---|---|---|---|
| M1 Fresh context | F | F | F | F |
| M2 Bounded, labeled return | F | P | P | F |
| M3 Role definitions | F | P | F | F |
| M4 Model, served model shown | P | P | P | P |
| M5 Tool scoping | F | P | F | F |
| M6 Permission handling | F | P | F | F |
| M6b Relay to human in CC UI | F | U | U | F |
| M7 Fg/bg, notify, cap | F | P | P | F |
| M8 Durable sessions, resume | F | P | F | F |
| M9 Cancellation | F | P | F | F |
| M9b CC-to-shim cancel | F | U | U | F |
| M10 Depth and spend caps | P | N | P | P |
| S11 Per-call effort | N | P | P | P |
| S12 Mid-run steering | F | P | P | F |
| S13 Hooks with identity | F | P | P | F |
| S14 FS isolation enforced | F | P | P | F |
| S15 Fork | F | N | U | F |
| S16 Liveness, usage | P | P | P | P |
| S17 Non-Anthropic targets | N | F | F | F |
| S18 Peer messaging | P | N | N | P |

F full, P partial, N none, U unverified.
Rows 6b and 9b split items the survey scores as a single row; the sub-item is the unverified part.

Reading the matrix:

- The hybrid never scores below the best pure option on any row, by construction of routing.
- Rows where every column is P or worse (M4, M10, S16, S18) are gaps no option closes.
- S11 becomes P only through static agent variants (`survey: Supplemental`, decision rule 1).

## Recommendation: hybrid

| Layer | Choice | Reason |
|---|---|---|
| Default | Native, per-call `model` | Keeps hooks, fork, cache, worktree, permission UX |
| Effort | Static variants (`reviewer-low`, `-xhigh`) | Recovers most of the per-call gap |
| Codex or Gemini target | ACP via acpx, then shim | Protocol-level cancel and permission |
| Wide or concurrent | OpenCode `serve` behind the shim | Broadest providers, warm server |
| Exact Codex effort | `codex app-server` direct | Best per-turn model and effort control |
| Claude on plan creds | Never via the bridge | TOS (`survey: Supplemental`, TOS posture) |

The hybrid dominates pure-bridge outright: a bridge cannot replace hooks, fork, cache, or worktree
enforcement.
It dominates pure-native only if some workload has a non-Claude advantage; otherwise the shim is unjustified
(`survey: Supplemental`).
The hybrid leaves two native gaps open: served-model reliability and true per-call effort.

## Decision rule

![Per-task routing decision tree][f4]

*Figure 4. Four early exits stay native or gated; only tasks passing all five questions reach a bridge.*

Rule, from `survey: Supplemental, When native still wins`:

1. Default to native; pick tier by `model`, effort by variant.
2. Bridge only if the task is self-contained, returns one message, is read-mostly or backend-sandboxed,
   **and** a non-Claude model has demonstrated advantage or a second opinion from another lab is the goal.
   Evidence to date: the flash-tier results in [delegate-model-comparison][cmp], which test 3.5 Flash, not
   the current SKU.
3. Between bridges: Codex or Gemini through ACP; wide provider or many sessions through OpenCode; exact
   Codex effort and interrupt through `codex app-server`.
4. If a shim behavior in the open items is load-bearing for the task, stay native until its experiment passes.

## Open and unverified items

| # | Unverified item | Resolves |
|---|---|---|
| E0 | Served model on installed CC (2.1.278) | Whether native model routing is trustworthy |
| E1 | CC-to-shim cancel propagation | Whether a human stop kills the child |
| E2 | Mid-call elicitation from a stdio server | Whether permission relay to the human works |
| E3 | acpx with two concurrent named sessions | Concurrency, orphaned processes |
| E4 | OpenCode `prompt_async` on a busy session | Queue vs interrupt for steering |
| E5 | OpenCode per-message effort | Agent-level effort is the only verified path |
| E6 | Effort variants honored natively | Whole effort mitigation rests on it |

Smallest experiment per item:

- **E0:** spawn with per-call `model`, env var `CLAUDE_CODE_SUBAGENT_MODEL` set and unset.
  Read the served model from the child transcript.
- **E1:** stub stdio MCP server that logs `notifications/cancelled`, SIGTERM, and stdin close.
  Stop a call older than 2 minutes from `/tasks` and via `TaskStop`.
- **E2:** stub server sends `elicitation/create` mid-call.
  Try 1 call, then 3 in parallel; note whether the call backgrounds.
- **E3:** two acpx sessions (Codex, Gemini); cancel one; kill the parent.
  Check `~/.acpx/` state and stray processes.
- **E4:** send a second prompt to a busy OpenCode session.
  Watch SSE for ordering and `session.idle`.
- **E5:** send a provider option per message; inspect the outgoing provider request.
  Fallback: one agent definition per effort level.
- **E6:** define `reviewer-low` and `reviewer-xhigh`; spawn by `subagent_type`.
  Read effort in `/tasks` and the transcript.

Carried UNVERIFIED with no experiment planned (cite the source section before relying):

- `claude-agent-acp` on subscription auth is TOS-compliant (sources conflict; `survey: Key Findings`).
- OpenAI and Google third-party OAuth posture: secondary sources only.
- a2acode's real-Claude verification, ruflo benchmarks, CCR `<CCR-SUBAGENT-MODEL>` syntax (`survey:
  Unverified / gaps`).
- Whole-turn Esc on plain foreground subagents; `PreToolUse` `updatedInput` on `Agent`; `tools: "*"`
  (`breakdown: Recommendations` 4).
- Whether OpenCode loads CLAUDE.md, per-message metadata for effective model, OpenCode session fork
  (`survey: Supplemental`).
- Cold-start latency of adapters vs a warm OpenCode server (unmeasured).

## Staged adoption

![Adoption stages with experiment gates][f5]

*Figure 5. Stages grow from zero code to optional facades; each gate names the experiment or evidence that
must pass.*

| Stage | Adds | Gate to enter |
|---|---|---|
| 0 Native only | Effort variants, spawn-gating hook, E0, E6 | Now |
| 1 Shimless MVP | acpx via Bash + Monitor; approve-all, read-only sandbox | G1 |
| 2 MCP shim | Five `delegate*` tools, role files, worktree | G2 |
| 3 OpenCode | HTTP + SSE backend; agent per effort level | G3 |
| 4 Optional | `codex app-server`, A2A facade, channel plugin | G4 |

Gates:

- **G1:** a task class with a demonstrated non-Claude advantage; otherwise stay at stage 0.
- **G2:** E3 passes and approve-all is too coarse for the wanted tasks.
- **G3:** E1 and E2 pass; otherwise stay read-only at stage 1.
- **G4:** E4 and E5 resolved, and a network boundary or exact effort is needed.
- The spawn-gating hook is a community mitigation that denies `Agent` calls lacking `model` (`breakdown: 2`).

Stage 1 to 2 rationale: the shimless path has no permission relay, so it is limited to read-mostly work
(`survey: Supplemental, Shared integration surface`).
Shim size is an estimate, not measured.

## Limits of this synthesis

- Both source reports rest on docs, READMEs, and `gh api`; docs were fetched through a summarizing tool, so
  exact wording may differ (`breakdown: Context`).
- Star counts and versions date from 2026-09-19 and age quickly; acpx (v0.17), codex-acp (120 open issues),
  and a2acode (5 stars) are the least mature pieces.
- Native and hybrid scores in the matrix are judgment, not measurement.

[survey]: 2026-09-19-subagent-bridge-layers-survey.md
[breakdown]: 2026-09-19-claude-code-subagents-feature-breakdown.md
[cmp]: 2026-09-17-delegate-model-comparison.md
[acpx]: https://github.com/openclaw/acpx
[i83920]: https://github.com/anthropics/claude-code/issues/83920
[f1]: 2026-09-19-subagent-bridge-layers-synthesis-assets/01-landscape.svg
[f2]: 2026-09-19-subagent-bridge-layers-synthesis-assets/02-control-flow.svg
[f3]: 2026-09-19-subagent-bridge-layers-synthesis-assets/03-coverage-matrix.svg
[f4]: 2026-09-19-subagent-bridge-layers-synthesis-assets/04-routing-tree.svg
[f5]: 2026-09-19-subagent-bridge-layers-synthesis-assets/05-adoption-path.svg
