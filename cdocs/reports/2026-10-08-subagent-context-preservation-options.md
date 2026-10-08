---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T10:17:43-07:00
task_list: cdocs/interfacer-agent
type: report
state: live
status: wip
tags: [investigation, subagents, claude_code, interfacer, runtime_validated]
---

# Subagent context preservation: reusing a helper without sleep-polling

> BLUF: The "caller never gets the reply" stall is a headless (`claude -p`/SDK) behavior, not a general one.
> On claude 2.1.293, an interactive-session subagent that ends its turn while its own child runs is parked and woken by the child's task-notification, including after a `SendMessage` resume (verified, two probes); a headless subagent is never woken (verified, five runs), and the reply surfaces at the root instead.
> No blocking resume exists by default: the Agent tool has no `resume` parameter, `SendMessage` blocks only when `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` (session-wide), and the only wait tool is `Monitor` (a harness-run until-loop).
> Recommendation: drop the warm agent; make the interfacer's durability its instance directory (a `notes.md` it keeps, plus per-check `report.md`), run each check as a fresh dispatch that names that directory, and tell callers to dispatch in the foreground where `run_in_background` is offered and otherwise end their turn to wait.
> The canaries suggest a warm resume saves about one to two tool rounds per follow-up check and no tokens worth defending: warm contexts grow to 30-35K while a fresh check restarts near the agent's base.

## Context / Background

`cdocs/proposals/2026-10-08-interfacer-agent.md` (branch `interfacer-agent`) keeps one warm `cdocs:interfacer` per caller and resumes it with `SendMessage` for each follow-up check.
Its canaries (`cdocs/devlogs/2026-10-08-interfacer-agent-impl.md`, `cdocs/reviews/2026-10-08-review-of-interfacer-agent-impl-r1.md`, both on that branch) found that a resume runs in the background, its reply lands at the caller's next tool round, and a caller that ends its turn never gets it (devcontainer run 2 stalled and left a server running).
The shipped workaround tells callers to stay in-turn with short Bash `sleep`s.
The harness refuses `sleep 30` with `Blocked: standalone sleep 30. To wait for a condition, use Monitor with an until-loop ... Do not chain shorter sleeps to work around this block.`: the workaround is exactly what that message forbids.

Every canary ran under `claude -p`, so every observation of the stall is a headless one.

## Method

- **Headless probes** (claude 2.1.293, host): `claude -p --output-format stream-json --verbose`, sonnet top level, a throwaway sandbox `CLAUDE_CONFIG_DIR` per run (credential copy deleted after each run), and an `--agents` `memo` agent (haiku, Bash only) that runs `sleep 12` and replies `MEMO: <words so far>`.
  The top level dispatches a `general-purpose` caller (depth 1), which dispatches `memo` (depth 2) with "word: apple", resumes it with `SendMessage` "word: banana", and ends its turn; if woken, it must say `CALLER-WOKEN`.
  Streams are in the session scratchpad under `ctxprobe/` (ephemeral).
- **Interactive probes**: this report's author is itself a depth-1 subagent of an interactive session, so it dispatched the same caller/memo pattern (caller depth 2, memo depth 3) from inside that session.
- **Binary strings** of 2.1.293 (`claude.exe`), for tool descriptions and the `task_started` schema; these are cited as code-read, not behavior.
- **Docs** via a `claude-code-guide` agent and `cdocs/reports/2026-09-19-claude-code-subagents-feature-breakdown.md`.

## Key Findings

| # | Finding | Evidence |
|---|---|---|
| 1 | Headless: a caller that ends its turn is never woken by its child, whether the child is a background first dispatch or a `SendMessage` resume, and whether the caller is itself foreground or background; the child's notification goes to the root. | Verified: probes `p1`, `p3a`, `p3b`, `p3c`, `p4fork` (fork mode forced on); no `CALLER-WOKEN` in any stream, no second `task_started` for the caller. |
| 2 | Interactive: a caller that ends its turn with a live child is parked and woken by the child's task-notification, after a first dispatch and again after a `SendMessage` resume; its own parent gets one notification, when it stops with no live children. | Verified: two interactive probes, each woken twice and ending with `MEMO: apple, banana` (probe 2 cleanly: three tool calls, no Bash; probe 1 added one stray `Bash true`). The notification text reads "fires each time this agent stops with no live background children of its own"; telemetry name `subagent_park` in the binary. |
| 3 | Headless depth-1 callers get `run_in_background` (described as "background by default"); passing `false` blocks and returns the child's report as the tool result. | Verified: `p1` (`is_backgrounded: false`, `spawn_depth: 2`, report inline), matching the devlog's run 5. |
| 4 | Interactive subagent callers (depth 1 and 2 observed) get no `run_in_background` parameter, and every dispatch is async. | Verified: this session's own Agent tool and interactive probe 2's caller both list only `description`, `isolation`, `model`, `prompt`, `subagent_type`, and return "Async agent launched"; the binary's launch logic forces async for non-headless subagent callers in fork mode (code-read). |
| 5 | A `SendMessage` resume always runs in the background by default (`task_started.is_backgrounded` doc: "A resumed subagent is always registered in the background"); the tool result is only `Resuming agent <id>`. | Verified (`p1`, `p3b`) and code-read. |
| 6 | With `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`, `SendMessage` blocks and returns the resumed agent's report inline ("Resumed agent. Its final report follows this JSON"), `awaited: true`; the Agent tool loses `run_in_background` and runs in the foreground. | Verified: `p2`. Session-wide: it also stops the overseer's background agents and Bash `run_in_background`. |
| 7 | The Agent tool has no `resume` parameter at any depth observed (`description`, `effort`, `isolation`, `model`, `prompt`, `run_in_background`, `subagent_type` headless); a new Agent call always starts fresh. | Verified by the probe caller's schema report in `p1`/`p2`; docs agree ("a new Agent call starts fresh"). |
| 8 | Wait primitives available to a subagent: `Monitor` (deferred, an until-loop the harness runs) only; no `TaskOutput`; `SendMessage.notify_when_idle` is "from the main conversation only" and for cross-session idle notices. | Verified: probe caller tool lists in `p1`/`p2`; `notify_when_idle` wording quoted from the tool description. |
| 9 | Agent teams do not apply: experimental, interactive only, teammates cannot spawn teammates, and a depth-1 subagent is not a teammate. | Docs only (agent-teams page via `claude-code-guide`; feature breakdown section 14). |
| 10 | No hook returns a child's result into a calling subagent (`SubagentStop` and team hooks feed the harness, not the caller's context). | Docs only. |

> NOTE(opus-5-5/cdocs/interfacer-agent): The headless/interactive split comes from the probes; the binary has a `callerIsHeadlessSubagent` input to the foreground/background decision and a parking path, but this report did not trace the exact gate.
> SDK sessions are non-interactive like `-p` and are assumed to behave like finding 1 (not probed).

## What warm context actually saves

`task_notification.usage.total_tokens` (end-of-run context size, as it rises across resumes) and `tool_uses`, from the surviving streams:

| Run | Check 01 (fresh) | Resumed checks |
|---|---|---|
| Host canary, playwright (implementer) | 25.5K, 7 tools, 26 s | 30.8K / 6 / 20 s; 34.2K / 9 / 55 s; 35.4K / 12 / 76 s (tear down) |
| Container, curl (review r1) | 19.8K, 5 tools, 17 s | 20.7K / 1 / 6 s; 21.8K / 2 / 29 s; 22.4K / 3 / 52 s |

> NOTE(opus-5-5/cdocs/interfacer-agent): `tool_uses` is not consistently per-run across these streams (review r1's host run reports 8, 11, 14, 17, which looks cumulative), so tool counts are indicative only.

- Setup discovery (read the README, make the instance dir, start the server or browser) is about two to four tool rounds in check 01.
  A fresh follow-up that is handed the instance directory and reads a `notes.md` skips discovery and replaces it with one `Read` plus a liveness check: a net cost of about one to two tool rounds (a few seconds) per check.
- Tokens favor fresh dispatch: a warm resume re-sends its whole history on every request (25-35K by the third check), while a fresh check starts near the agent's base context; the agent's system prompt prefix is identical across dispatches of the same type, so it should hit the prompt cache within the TTL (docs-only inference; not measured).
- What warmth really carries is tacit knowledge: the host run's wrong `server.pid` (the `setsid` wrapper), and a stale-ref click retry.
  A notes file captures this explicitly, and it survives the caller's own turn boundaries, compaction, and caller replacement, which a warm agent's history does not.

## Options

| Option | Interactive | Headless | Polling | Complexity |
|---|---|---|---|---|
| A. Warm agent, `SendMessage`, caller ends its turn to wait | Works (verified) | Stalls; reply lands at the root (verified) | None | Low, but mode-dependent |
| B. Warm agent, caller stays in-turn with `sleep` (shipped) | Works | Works | Yes; the harness forbids chained sleeps | Low, fragile |
| C. Warm agent, caller waits with `Monitor` on the next `report.md` | Likely | Unverified | Harness-run until-loop | Medium |
| D. `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`, blocking `SendMessage` | Works | Works (verified) | None | Session-wide side effects; not a plugin default |
| E. Fresh dispatch per check, state in the instance dir | Works: async, caller ends its turn and is woken | Works: `run_in_background: false` blocks (verified) | None | Lowest; one design for both modes |

## Recommendations

Adopt E.
It keeps the instance directory as the unit of durability (where tooling, media, and reports already live), costs one to two tool rounds per follow-up, and works the same way in interactive and headless sessions with no waiting instructions beyond the platform default.

- **Interfacer agent** (`plugins/cdocs/agents/interfacer.md`): replace the "Durable by default ... `SendMessage`" and "stay in your turn (`sleep`)" description lines with "For a follow-up check or tear down, dispatch a fresh interfacer naming the instance directory; dispatch in the foreground (`run_in_background: false`) where offered, else end your turn and the report wakes you."
  In the body, keep `<instance>/notes.md` (how the target is driven, what is running with real PIDs, gotchas), read it first when the prompt names an instance, and take the next free `NN`.
- **Proposal** (`cdocs/proposals/2026-10-08-interfacer-agent.md`): rewrite D5 and "Durable by default" so durability means a durable instance directory with live tooling across fresh dispatches, not a warm `agentId`, and drop the `SendMessage` sequence and in-turn-wait NOTEs; D6 (fresh per reviewer, implementer reuses its own instance) carries over with "instance" in place of "agent".
  Rerun the Phase 4 canary headless with the stand-in passing `run_in_background: false` per check and no sleeps, plus one interactive run.

> NOTE(opus-5-5/cdocs/interfacer-agent): If headless use is ever out of scope, option A is the zero-change alternative: delete the `sleep` line and tell callers to end their turn.
> It is not recommended, because the canary, CI, and SDK-driven loops are headless and would stall silently.
