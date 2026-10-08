---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-19T08:30:00-07:00
task_list: cdocs/subagent-bridge-layers
type: report
state: live
status: wip
tags: [research, subagents, claude_code, delegation, model_selection, baseline]
---

# Claude Code native subagents: feature breakdown as the baseline for bridge-layer comparison

> BLUF: Claude Code (CC) subagents are a bundle of about a dozen separable mechanisms: fresh-context isolation with a single-message return contract, a declarative definition format (tools, model, effort, permissions, hooks, MCP, skills, memory, isolation), harness-level permission relay, background execution with `SendMessage`/resume, JSONL transcripts, lifecycle hooks, prompt-cache reuse (forks and resumes), and depth/concurrency/spend caps.
> An external bridge (A2A/ACP/MCP delegation, another harness) can replicate the return contract, parallelism, and definition format cheaply.
> The expensive parts are permission relay into the parent's UI, mid-run steering, cache sharing, in-harness tool/MCP scoping, and cost/liveness observability.
> Model and effort control has real gaps that a bridge could plausibly beat: no per-call effort parameter (open, [#77298](https://github.com/anthropics/claude-code/issues/77298)), no subagent-scoped effort/thinking setting, no non-Claude model target without an Anthropic-compatible gateway, and multiple open bugs where the requested model is not the served model.
> A minimum viable bridge checklist is at the end.

## Context / Background

The `cdocs/subagent-bridge-layers` arc compares alternative delegation transports against native CC subagents.
This report is the baseline: what native subagents provide, what can and cannot be overridden per invocation, and what a bridge must replicate to be a credible replacement.
Grounding: CC docs (fetched 2026-09-19, CC v2.1.278 installed locally), `anthropics/claude-code` issues (queried via `gh api` 2026-09-19), and local plugin agents (`plugins/cdocs/agents/{judge,reviewer,nit-fix,triage}.md`, `rules/model-tiering.md`, `rules/orchestration-discipline.md`).

Verification note: docs pages were fetched through WebFetch, which summarizes with a small model.
Claims below are attributed to the page they came from; items where the summary was inconsistent or where behavior differs between docs and issues are marked **UNVERIFIED** or **CONFLICT**.
No live spawn experiments were run for this report.

Sources:
- Subagents: https://code.claude.com/docs/en/sub-agents
- Tools reference: https://code.claude.com/docs/en/tools-reference
- Model config: https://code.claude.com/docs/en/model-config
- Hooks: https://code.claude.com/docs/en/hooks
- Agent teams: https://code.claude.com/docs/en/agent-teams
- Prompt caching: https://code.claude.com/docs/en/prompt-caching
- Costs: https://code.claude.com/docs/en/costs
- Agent SDK subagents: https://code.claude.com/docs/en/agent-sdk/subagents

## Key Findings

- **Definition surface is broad and declarative.** 18 frontmatter fields, including `model`, `effort`, `permissionMode`, `hooks`, `mcpServers`, `skills`, `memory`, `isolation`, `background`, `maxTurns`, `omitClaudeMd`, and `experimental.cacheTtl`.
  Plugin-distributed agents silently drop `hooks`, `mcpServers`, and `permissionMode`.
- **Model precedence (current docs, post-v2.1.251):** per-call `model` param, then frontmatter `model`, then `CLAUDE_CODE_SUBAGENT_MODEL`, then the parent's model.
  `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` (v2.1.257+) inverts this and forces all subagents, teammates, and workflow agents.
- **Effort has no per-call parameter.** Effort is settable only as static frontmatter or `--agents` JSON, otherwise inherited from the session.
  Per-call effort requests were closed not-planned ([#72596](https://github.com/anthropics/claude-code/issues/72596)) and remain open as [#77298](https://github.com/anthropics/claude-code/issues/77298).
  The Workflow tool does accept per-call `effort` (per maintainer comment on [#67647](https://github.com/anthropics/claude-code/issues/67647), closed completed 2026-08-17).
- **No per-subagent thinking control.** Subagents inherit the session's extended-thinking configuration since v2.1.198 (sub-agents page: "No per-subagent thinking setting exists").
- **Models are Claude-only natively.** `model` accepts `sonnet|opus|haiku|fable`, a full ID, or `inherit`.
  Non-Claude targets work only via `ANTHROPIC_BASE_URL`/gateway or cloud-provider model IDs (model-config page), and that setting is process-wide, not per-subagent.
  [#88916](https://github.com/anthropics/claude-code/issues/88916) (open) requests per-subagent local OpenAI-compatible endpoints.
- **The requested model is not always the served model.** At least six open issues report per-call or frontmatter `model` being ignored or mislabeled ([#83920](https://github.com/anthropics/claude-code/issues/83920), [#83522](https://github.com/anthropics/claude-code/issues/83522), [#81198](https://github.com/anthropics/claude-code/issues/81198), [#85592](https://github.com/anthropics/claude-code/issues/85592), [#91160](https://github.com/anthropics/claude-code/issues/91160), [#93157](https://github.com/anthropics/claude-code/issues/93157)).
- **Return contract is one message.** The parent sees only the final message, scanned for instruction-shaped text since v2.1.210; intermediate tool calls stay in the child's context.
- **Interrupt story is asymmetric.** Esc at a permission prompt denies one tool call without stopping the child; stopping a child is `x` in `/tasks` or the `TaskStop` tool.
  Esc while viewing a teammate's transcript interrupts that teammate's turn (agent-teams page).
- **Cost multipliers are real.** A subagent's first request misses the parent's cache, subagents get a 5-minute cache TTL by default, and agent teams run roughly 7x tokens (costs page, teammates in plan mode).

## Analysis

### 1. Definition formats

Definitions are markdown with YAML frontmatter in `.claude/agents/` (project), `~/.claude/agents/` (user), managed settings, a plugin's `agents/`, or JSON via `--agents` (session-only).
Priority: managed, `--agents`, project, user, plugin.
Same-name collisions resolve by that order; nested project dirs resolve to the definition nearest the cwd (v2.1.178+).
The SDK equivalent is `AgentDefinition` passed in `query({ options: { agents } })`, which takes precedence over filesystem agents of the same name.

Frontmatter fields (sub-agents page, fetched 2026-09-19):

| Field | Semantics |
|---|---|
| `name`, `description` | Required. `name` is the `agent_type` in hooks and cannot contain `:` (reserved for plugin scope, e.g. `plugin:agent`). Combined descriptions over 15,000 tokens trigger a startup warning. |
| `tools` | Allowlist; omit to inherit all subagent-available tools. Supports `Agent(a, b)` to restrict spawnable subagent types (main-thread agents only) and `mcp__server` / `mcp__server__*` patterns. |
| `disallowedTools` | Denylist, applied before `tools`. Removes the whole tool even when the entry carries a specifier. |
| `model` | Alias, full ID, or `inherit`. |
| `effort` | `low|medium|high|xhigh|max`; SDK also accepts a number. Inherits the session level if omitted. |
| `permissionMode` | `default|acceptEdits|auto|dontAsk|bypassPermissions|plan|manual`. Parent's `bypassPermissions`/`acceptEdits`/`auto` overrides the child's setting. Ignored for plugin agents. |
| `maxTurns` | Hard turn cap; result marked partial (v2.1.246+) and resumable. |
| `skills` | Preloads full skill content at startup. Skills with `disable-model-invocation: true` cannot be preloaded. |
| `mcpServers` | Names (reuse parent's) or inline definitions (stdio/http/sse/ws), connected at start and torn down at end. Inline project-level servers need workspace trust (v2.1.238+). Ignored for plugin agents. |
| `hooks` | `PreToolUse`, `PostToolUse`, `Stop` (rewritten to `SubagentStop`), scoped to the child's lifetime. Ignored for plugin agents. |
| `memory` | `user|project|local` persistent directory; first 200 lines or 25 KB of `MEMORY.md` injected; auto-enables Read/Write/Edit. |
| `background` | Force background execution. |
| `isolation` | `worktree`. |
| `omitClaudeMd` | Skip user/project/local CLAUDE.md; managed policy still loads (v2.1.271+). |
| `color`, `initialPrompt` | Display color; auto-submitted first turn when the agent runs as the main session (`--agent`). |
| `experimental.cacheTtl` | `5m|1h` prompt-cache lifetime for this agent's requests (v2.1.248+). |

Built-ins: `Explore` (read-only, skips CLAUDE.md and git status; inherits parent model capped at Opus on the API, v2.1.198+), `Plan`, `general-purpose`.
Explore and Plan are one-shot: no agent ID, not resumable.
`claude plugin validate .claude/agents` (v2.1.233+) lints definitions; it does not flag a missing `name`.
An agent can also run as the main session (`claude --agent <name>` or `"agent"` setting), taking on the definition's prompt, tools, and model.

Local corroboration: `plugins/cdocs/agents/*.md` use `name`, `model`, `description`, `tools`, `color`, `maxTurns`, and `skills` (reviewer preloads `cdocs:review`).
The reviewer uses `tools: "*"`, which is not in the documented syntax (**UNVERIFIED**: docs describe "omit to inherit"; `"*"` likely works as a wildcard but is not documented on the fetched page).

### 2. Model selection mechanics

Precedence (sub-agents page; the docs note that before v2.1.251 `CLAUDE_CODE_SUBAGENT_MODEL` was first and overrode everything):

1. Per-invocation `model` parameter on the Agent tool call.
2. Frontmatter `model` (`inherit` selects the parent's model).
3. `CLAUDE_CODE_SUBAGENT_MODEL` (alias or full ID).
4. The parent conversation's model.

Force switch: `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` (v2.1.257+) pins every subagent, teammate, and workflow agent to `CLAUDE_CODE_SUBAGENT_MODEL` (or the session model if unset), bypassing frontmatter and per-call values.
Exceptions: forks and `model: inherit` skills follow the parent.
The model-config page summary showed `_FORCE=sonnet` (a model alias) and listed FORCE as precedence 1: **CONFLICT** with the sub-agents page (`=1`).
The sub-agents page is the more specific source; treat the model-config example as unverified.

Other model mechanics:
- `availableModels` allowlist applies to per-call, frontmatter, and env values. A blocked family alias substitutes the newest permitted version of that family; any other blocked value falls back to the inherited model, with a warning in interactive sessions.
- `fallbackModel` chains apply to subagents: on failover the subagent continues on the next chain model while the session model is unchanged. Docs for frontmatter-pinned agents are flagged unspecified in [#85902](https://github.com/anthropics/claude-code/issues/85902).
- Built-in Explore inherits the parent model unless a custom `Explore` agent overrides it; Plan inherits unless `CLAUDE_CODE_SUBAGENT_MODEL` is set.
- Forks stay on the inherited model.
- `/tasks` shows a running subagent's model and effort. Multiple issues report the TUI label showing the parent's model ([#87851](https://github.com/anthropics/claude-code/issues/87851), [#93324](https://github.com/anthropics/claude-code/issues/93324), [#77655](https://github.com/anthropics/claude-code/issues/77655)).

What can be overridden dynamically (per invocation, by the orchestrating model):

| Knob | Per-call override | Static override | Env / global | Notes |
|---|---|---|---|---|
| Model | Yes, `model` param | Frontmatter, `--agents` | `CLAUDE_CODE_SUBAGENT_MODEL`, `_FORCE` | Env var interaction has regressed at least twice (#85592, #91160). |
| Effort | **No** | Frontmatter, `--agents` | None subagent-scoped; `CLAUDE_CODE_EFFORT_LEVEL` is session-wide | Feature requests: #77298 (open), #79135 (env var + setting, open), #92660 (`modelSettings` effort does not reach subagents, open), #72596 (closed not-planned). |
| Thinking on/off, budget | **No** | **No** | Inherited session toggle, `alwaysThinkingEnabled`, `MAX_THINKING_TOKENS` | Sub-agents page: no per-subagent thinking setting. |
| Tools | No | Frontmatter | Deny rules `Agent(name)` | Tool set fixed by definition. |
| Permission mode | No | Frontmatter | Parent mode overrides | Cannot be set per-teammate at spawn. |
| Isolation | Yes (`isolation` on the call, per agent-teams page wording) | Frontmatter | None | Passing `isolation` on the call keeps a named spawn a subagent rather than a teammate. |
| Foreground/background | Yes (`run_in_background`) | `background: true` | `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` | Fork mode makes interactive spawns background regardless. |
| Non-Claude model | No | No | Gateway/`ANTHROPIC_BASE_URL` is process-wide | #88916 open. |

Evidence from this session's own Agent tool schema (the harness that launched this report's author): parameters `description`, `prompt`, `subagent_type`, `model` (enum `sonnet|opus|haiku|fable`), `isolation`; no `effort`.
The docs additionally describe `name`, `run_in_background`, and fork-related inputs that this (nested-context) schema does not list: **UNVERIFIED** whether the schema differs by depth or by version.

Known gap classes (all open unless noted):
- **Silent inheritance cost.** Parallel fleets inherit the session model and effort ([#87815](https://github.com/anthropics/claude-code/issues/87815): a 7-agent fleet on Fable consumed a weekly allocation; [#74171](https://github.com/anthropics/claude-code/issues/74171); [#92660](https://github.com/anthropics/claude-code/issues/92660): xhigh session multiplies cost; #79135 commenter: three trivial `env | grep` workflow agents cost 175k tokens at inherited xhigh). Community mitigation: a `PreToolUse` hook on `Agent` that denies spawns lacking an explicit `model`.
- **Alias drift.** `model: "opus"` resolved to `claude-opus-4-8` rather than `claude-opus-5` ([#82359](https://github.com/anthropics/claude-code/issues/82359)); bare aliases fail through `modelOverrides` ([#81995](https://github.com/anthropics/claude-code/issues/81995)).
- **Per-call ignored.** #83920 (per-call param ignored, 2.1.220), #83522 (`fable` request served on Sonnet), #81198 (three different model answers in one session), #93157 (`opusplan` overrides frontmatter).
- **Env var regression.** #85592 (per-call silently discarded when `CLAUDE_CODE_SUBAGENT_MODEL` set, regression window 2.1.220 to 2.1.223) and #91160 (env var acts as hard override on 2.1.236). A maintainer comment on #85592 confirmed parts on 2.1.233. The docs' note that precedence changed at v2.1.251 suggests a fix landed afterward; **UNVERIFIED** against a live run on 2.1.278.
- **Output-token ceiling.** [#78460](https://github.com/anthropics/claude-code/issues/78460): reporter first claimed subagents are capped at 8000 `max_tokens` (thinking at high effort exhausts it), then retracted the "subagent-only" framing while keeping the 8000 ceiling claim measurable. Treat as **UNVERIFIED**.
- **Observability.** #85416 (effort unobservable for background subagents), #88508 (status line JSON lacks effort for non-custom subagents), #84223 (transcripts often lack final cumulative `usage`), #88107 (usage empty for custom-provider models).

Local relevance: `rules/model-tiering.md` assumes per-agent `model:` frontmatter is honored (opus judge/reviewer, sonnet triage, haiku nit-fix).
The precedence note means a consumer setting `CLAUDE_CODE_SUBAGENT_MODEL` no longer flattens those tiers on v2.1.251+, but `_FORCE=1` still does.

### 3. Context isolation and the return contract

A non-fork subagent starts with: its own system prompt plus environment details (not the CC prompt), the parent's delegation prompt, CLAUDE.md files at all levels (unless `omitClaudeMd`; Explore/Plan skip them), a git-status snapshot from parent session start, preloaded skills, and a sibling roster of named agents (v2.1.206+).
It does not receive: parent conversation history, output style, auto memory (use `memory` instead), or the parent's system prompt.
The only channel from parent to child is the Agent-tool prompt string.

Return: the child's final message becomes the Agent tool result, with `agentId: <id>` appended for resume.
Since v2.1.210 the harness scans the message: it backslash-escapes control-tag imitations and turn markers (`Human:`, `Assistant:`) and prepends a `[harness: ...]` marker for permission-config mentions; it never deletes text.
The parent may paraphrase the result in its user-facing reply; the SDK page recommends an explicit verbatim instruction when needed.
API errors mid-stream: foreground with partial text returns text plus a cut-off note; tool-calls-only fails with `Agent terminated early due to an API error`; background is marked failed.

This is the contract `rules/orchestration-discipline.md` builds on: the overseer records the summary and does not re-read the child's files (lines 35-38), and a dispatched subagent cannot dispatch its own workers at the top-level overseer layer (line 4).

> NOTE(opus-5-5/cdocs/triage-state): `orchestration-discipline.md` no longer exists, and subagents can dispatch subagents (three layers by default); see `cdocs/proposals/2026-10-06-nested-subagent-workflows.md`.

### 4. Parallelism and background execution

- Default concurrency cap: 20 (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`); the 21st spawn fails with `Concurrent subagent limit reached`. Resume of a finished agent takes a fresh slot without a check. Ultracode sessions bypass the cap.
- Foreground vs background is chosen by first match: teammate-spawned (foreground), `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` (foreground), fork mode on (background; interactive default), fork mode off (background by default in `-p`/SDK, foreground when the model needs the result).
- Background subagents get a restricted built-in tool set (Read, Grep, Glob, Bash, Edit, Write, WebFetch, WebSearch, TodoWrite, Skill, ToolSearch, worktree tools, Monitor, TaskStop, SendMessage, Artifact, plus all MCP tools). Foreground keeps the full set after the always-removed list (`Agent` at depth limit, `AskUserQuestion`, `EnterPlanMode`, `ExitPlanMode` unless plan mode, `ScheduleWakeup`, `TaskOutput`, `Workflow`, and others).
- Ctrl+B backgrounds a running foreground task.
- Completion delivers a notification to the parent in a later turn; long-running commands started by a background subagent can outlive it.
- Dynamic Workflows (`Workflow` tool, TS SDK v0.3.149+) move fan-out orchestration into a script for dozens to hundreds of agents; out of scope here beyond noting it exists and honors per-call `effort`.

### 5. Resume, SendMessage, and continuation

- Each spawn is a new instance. Continuation is `SendMessage(to: <agent-id-or-name>, ...)`. The resumed agent retains full history, tool results, and its prior tool set, and its first request can hit the cache the original run warmed.
- Named subagents (Agent tool `name` param) are addressable and appear in a roster reminder given to other agents that hold `SendMessage`. A resumed agent reports to its sender, not necessarily the main conversation, and the sender waits.
- Name aliasing (v2.1.199): if a newer agent took the name, `SendMessage` refuses and reports the current holder; use the ID.
- A manually stopped agent (`x` in `/tasks`) does not auto-resume; it can be resumed by typing into its transcript while its row is visible (v2.1.191+).
- Session resume (`/resume`) does not restore in-process teammates (agent-teams limitation); the sub-agents page does not state an equivalent limitation for plain subagents (**UNVERIFIED**).
- `SendMessage` also reaches other Claude Code sessions (v2.1.224+), which is relevant as a native cross-session bridge; messages from other agents are labeled as non-user input and cannot supply consent.
- SDK resume: capture `session_id` and parse `agentId` from the tool result text, then `resume: sessionId` with the same `agents` map.

### 6. Transcript persistence and observability

- Transcripts: `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`, independent of the main conversation and surviving its compaction; cleaned after `cleanupPeriodDays` (default 30).
- Subagents auto-compact with the main-conversation logic (`autoCompaction`, `CLAUDE_CODE_DISABLE_AUTO_COMPACTION`).
- Views: `/tasks` (running and recent rows, model and effort, Enter opens the transcript), `/agent-view` for background agents. Success rows clear immediately with a 30-second footer hint; failed or stopped rows persist 30 seconds.
- Hook payloads carry `agent_id`, `agent_type`, `agent_transcript_path`, and (on stop) `last_assistant_message`, which makes an external observer feasible.
- SDK messages emitted from inside a subagent carry `parent_tool_use_id`; the Agent tool appears as `"Agent"` in `tool_use` blocks and `"Task"` in the `system:init` tool list (older SDKs emit `"Task"`).
- Gaps: no liveness/progress signal for background subagents ([#91093](https://github.com/anthropics/claude-code/issues/91093)); ListAgents omitting running in-process subagents ([#85764](https://github.com/anthropics/claude-code/issues/85764)); usage accounting holes in transcripts (#84223, [#93620](https://github.com/anthropics/claude-code/issues/93620)).

### 7. Permission prompting, relay, and steering

- Foreground: prompts appear in the main terminal at the moment of the tool call.
- Background (v2.1.186+): prompts surface in the main session, name the requesting subagent, and Esc denies that single call without stopping the child. Before v2.1.186 background children auto-denied anything that would prompt.
- `permissionMode` inheritance: parent in `bypassPermissions`/`acceptEdits`/`auto` overrides the child. Under `auto` the classifier evaluates the child's tool calls with the parent's rules and also reviews the child's final report before delivery. A child declaring `bypassPermissions` keeps the parent's mode (v2.1.267+).
- `dontAsk` denies anything not pre-allowed, including `AskUserQuestion`; the child never has `AskUserQuestion` at all, so a subagent cannot ask the user a clarifying question directly.
- Steering: the parent model can call `TaskStop` on a background agent by ID or name and `SendMessage` to redirect it. The human can Esc a prompt, `x` a row, or open the transcript and type. Whether the human's main-thread Esc interrupts a running foreground child: the docs describe only prompt-level Esc; whole-turn interrupt is documented for teammates ("While you're viewing a teammate's transcript, Escape interrupts that teammate's current turn"). **UNVERIFIED** for plain foreground subagents.
- Agent output is untrusted: scanning does not replace tool restrictions or sandboxing (docs).

### 8. Tool and MCP inheritance and scoping

- Default inheritance: all subagent-available built-in and MCP tools from the parent; `tools`/`disallowedTools` narrow it; unresolved-only `tools` lists refuse to launch (v2.1.208+).
- MCP: string references reuse the parent's connected server; inline definitions spin up a private server for the child's lifetime, which keeps a heavy server's tool schemas out of the parent's context (docs' stated benefit). `allowedMcpServers`/`deniedMcpServers`, `--strict-mcp-config`, and enterprise policy apply; `--strict-mcp-config` does not filter inline servers from `--agents` or SDK `agents`.
- Deferred MCP tools (tool search) are the default, so MCP additions generally keep the parent's cache.
- `Agent(name, ...)` in a main-thread agent's `tools` whitelists spawnable types; `permissions.deny: ["Agent(Explore)"]` blocks specific types.
- Plugin agents lose `hooks`, `mcpServers`, `permissionMode`; workaround is copying the file into `.claude/agents/` or `~/.claude/agents/`.

### 9. Hooks

- Session-level: `SubagentStart` (matcher on agent type; informational, cannot block spawn) and `SubagentStop` (informational; carries `last_assistant_message`). Exact-name matching for hyphenated names since v2.1.195; plugin-scoped names need anchored regex.
- Tool hooks (`PreToolUse`/`PostToolUse`) fire for child tool calls with `agent_id`/`agent_type` attached, so session-wide policy hooks cover children.
- Frontmatter hooks are child-scoped and need workspace trust for project agents (v2.1.218+).
- A `PreToolUse` hook on the `Agent` tool itself can gate spawns (used as a community mitigation in #87815). Whether `PreToolUse` on `Agent` can rewrite `model` via `updatedInput`: the costs page shows `updatedInput` for Bash, so it is plausible for `Agent` but **UNVERIFIED**.
- Team hooks: `TeammateIdle`, `TaskCreated`, `TaskCompleted`; agent-teams page says exit code 2 blocks and feeds back, while the hooks-page summary said "informational" (**CONFLICT**, likely summarizer error; check the hooks page directly before relying on either).

### 10. Nesting, concurrency, and spend limits

- Nesting: default 3 layers below main (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`; `1` disables nesting). History: v2.1.172-216 up to 5 unconfigurable, v2.1.217-218 default 1, v2.1.219+ default 3. At the limit the `Agent` tool is removed (forks keep it but it errors).
- Concurrency: 20 (see section 4).
- Spend (SDK): `maxBudgetUsd` refuses new spawns with `Budget limit reached`, stops running background subagents, and ends the query with `error_max_budget_usd`. Subagent cost counts toward `total_cost_usd`.
- Turns: `maxTurns` per agent.
- Opus 5 delegates more readily; with the `claude_code` preset CC injects "do not call the Agent tool unless asked" for Opus 5 only ([#80988](https://github.com/anthropics/claude-code/issues/80988) reports this silently overriding user delegation policy).

### 11. Fork-style subagents

- Fork = subagent that inherits the parent's system prompt, output style, full conversation, tool pool (no background filter), and model. Created with `/subtask <prompt>`, `@agent-name` forms, or `Agent(fork=true)`; enabled by default interactively (`CLAUDE_CODE_FORK_SUBAGENT`, `forkSubagent`; disable with `CLAUDE_CODE_DISABLE_FORK_MODE=1`).
- Because its prefix is identical, the fork's first request reads the parent's cache; ordinary subagents do not.
- Forks bypass the concurrency block (still take a slot), stay on the inherited model, and are exempt from `_FORCE`.
- `rules/orchestration-discipline.md` line 177 already names fork as the tool for side-investigations that need parent context without growing the parent thread.

### 12. Worktree isolation

- `isolation: worktree` (frontmatter or call): temporary git worktree branched from the default branch, auto-cleaned if unchanged.
- Enforcement (v2.1.203/210+): Bash/PowerShell/Monitor working directories must resolve inside the worktree; Bash also blocks git redirects into the main checkout and refuses commands whose git usage cannot be verified to stay inside. If the main session is itself in a worktree, the same checks apply to all its subagents.
- Interaction with cache: worktrees have their own cwd, so they miss each other's prompt cache (prompt-caching page, "Cache scope").

### 13. Plugin-distributed agents

- Discovered from a plugin's `agents/` recursively; subfolders become part of the scoped name (`plugin:review:security`). Lowest priority; no trust prompt needed.
- `hooks`, `mcpServers`, `permissionMode` are ignored (security boundary).
- Plugin agents without `name` or with unparseable frontmatter still load under the filename (other agent sources skip them).
- Adding or removing plugin agents is cache-safe (appended, not prefix-changing).
- Local example: the cdocs plugin ships `judge`, `reviewer`, `nit-fix`, `triage` and relies on relative `rules/*.md` reads plus `/cdocs:init` materialization because plugins cannot ship rules natively (CLAUDE.md, "Cross-Target Rules Architecture").

### 14. Agent teams (experimental)

Contrasted with subagents, from the agent-teams page (v2.1.178 semantics):
- Enable with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`; interactive sessions only (`-p`/SDK run named subagents as ordinary subagents).
- When enabled, an Agent call with a `name` launches a teammate (not a subagent) unless it is a fork or passes `isolation`. Claude can name subagents on its own, so teams can form unprompted; set the variable to `0` to disable.
- Teammates are full independent sessions with mailboxes (`~/.claude/teams/{name}/inboxes/{agent}.json`), a shared task list with file-locked claiming and dependencies (`~/.claude/tasks/{name}/`), and direct peer messaging.
- Model selection: spawn prompt, then definition `model`, then `CLAUDE_CODE_SUBAGENT_MODEL`, then lead; `_FORCE` overrides the first two. `teammateDefaultModel` removed v2.1.234. A teammate's model is fixed at spawn and `/model` affects only the lead; effort follows the lead.
- Definitions applied to teammates: `tools` (plus `SendMessage`/Task tools added), `model`, and body. `skills` are not applied; `mcpServers` apply only to split-pane teammates.
- Limits: no `/resume` of in-process teammates, one team per session, no nested teams, no background subagents from in-process teammates, permissions inherited (except `dontAsk`) and not settable per teammate at spawn, teammate permission prompts surface in the lead.
- Cost: agent team spawns are billed as separate instances (costs page: about 7x tokens with teammates in plan mode; recommends Sonnet teammates); in-process teammates get a 5-minute cache TTL unless `subagentPromptCacheTtl` is set.
- Relevance: agent teams are the closest native analog to a peer-to-peer A2A layer; subagents are the analog to hierarchical delegation.

### 15. Cost and prompt-cache implications

- A non-fork subagent's first request does not read the parent's cache (different system prompt and tool set), so each spawn pays a cold prefix. The parent's cache is unaffected (call and result are appended).
- Subagent requests fall in the "everything else" TTL bucket: 5 minutes by default even on a subscription (main conversation gets 1 hour there). Override with `subagentPromptCacheTtl`/`CLAUDE_CODE_SUBAGENT_PROMPT_CACHE_TTL` or per-agent `experimental.cacheTtl`. 1-hour writes cost more.
- Cache is keyed by model and (on most models) by effort level; forks and resumes are the cache-sharing paths; workflow fan-outs hold all but the first same-prefix agent up to 5 seconds.
- Model tiering economics: `rules/model-tiering.md` estimates 100 opus overseer turns plus 9,900 cheaper subagent turns as an order of magnitude cheaper than 10,000 opus turns; the docs' costs page recommends `model: haiku` for simple subagent tasks and warns that verbose output should be delegated so only a summary returns.
- `/usage` attributes plan usage to subagents; the `Prompt cache (main)` line covers the main conversation only, not subagents.

### 16. Known limitations and open issues (summary)

| Area | Issue | State (2026-09-19) |
|---|---|---|
| Per-call effort | #77298 | open |
| Per-call effort (earlier) | #72596 | closed not-planned, locked |
| Subagent-scoped effort env/setting | #79135, #92660 | open |
| Frontmatter effort undocumented (older) | #91415 | open (docs now list `effort`) |
| Per-call `model` ignored / mislabeled | #83920, #83522, #81198, #87851, #94575 | open |
| Env var overrides per-call/frontmatter | #85592, #91160 | open |
| `opusplan` overrides frontmatter | #93157 | open |
| Non-Claude subagent targets | #88916 | open |
| Effort unobservable in background | #85416 | open |
| Background liveness/progress | #91093 | open |
| Silent premium-tier inheritance | #87815, #74171, #94534 | open |
| Output token ceiling | #78460 | open, claim partly retracted |

## Feature table

Replication difficulty is for an external bridge that does not control the CC harness (A2A/ACP/MCP delegation or another harness driving the child): Low (protocol-level, straightforward), Medium (needs custom glue or convention), High (needs harness integration or cannot be matched without one).

| Feature | Native behavior | Benefit | Replication difficulty for an external bridge |
|---|---|---|---|
| Fresh-context isolation | Child starts with its own prompt, CLAUDE.md, git status, and only the delegation string | Parent context stays small; verbose exploration is discarded | Low: any RPC with a fresh session |
| Single-message return | Only the final message returns, scanned for injection patterns | Bounded, predictable parent context growth; reviewable contract | Low for return shape; Medium for the injection scanner and untrusted-output labeling |
| Declarative definition (markdown + YAML) | 18 fields, 5 scopes with priority, plugin distribution | Reusable, versioned, team-shared roles | Medium: need a portable schema and loader; mapping fields onto another runtime is lossy |
| Per-call model override | `model` param on the Agent tool | Orchestrator picks tier per task | Low to Medium: trivial in a bridge's own API; the difficulty is the bridge's model set and cost tables |
| Static model tiering by role | `model:` frontmatter plus env precedence and `_FORCE` | Cost tiering by role (opus judge, haiku mechanical) | Low |
| Per-call effort / thinking | Not supported (effort frontmatter only; thinking inherited) | n/a | Low: a bridge can expose these as call parameters; this is a differentiation opportunity |
| Non-Claude model targets | Only via gateway/provider IDs, process-wide | Cross-vendor tiering (e.g. cheap Flash-class drivers) | Low for a bridge; the hard part is tool-use parity and output-shape parity |
| Tool allowlist/denylist | `tools`/`disallowedTools`, `Agent(x)` spawn allowlist, MCP patterns | Least privilege per role | Medium: enforcement must live in the child's harness, not in prompt text |
| MCP scoping | Inline per-agent servers; reuse by name; managed policy applies | Heavy MCP schemas kept out of parent context | Medium |
| Permission modes and relay | Modes per agent; background prompts surface in the parent UI naming the child; Esc denies one call | Human stays in the loop for any child's sensitive action | High: needs a UI/relay channel from child to the human; a bridge without it must pre-approve or auto-deny |
| Foreground/background execution | Blocking or concurrent; notification on completion; Ctrl+B | Parallel work without blocking the parent | Medium: async job + completion notification is standard; injecting completion into the parent's turn loop needs harness support |
| Parallelism limits | 20 concurrent, depth 3, spend cap (SDK) | Bounded blast radius | Low to Medium |
| Resume / continue by ID or name | `SendMessage`, full history restored, cache-warm | Warm specialists across turns; no re-briefing | Medium: needs durable child sessions and stable IDs; name aliasing rules |
| Transcript persistence | JSONL per agent, 30-day retention, survives compaction | Audit, debugging, resumption | Low to Medium |
| Steering and interrupt | Esc denies a prompt; `x`/`TaskStop` cancels; type into transcript to redirect | Human and parent can correct a drifting child | High: mid-run cancellation and message injection require a cooperative child loop |
| Lifecycle hooks | `SubagentStart`/`SubagentStop`, child-scoped frontmatter hooks, tool hooks with `agent_id` | Policy, logging, and gating around delegation | Medium: a bridge can emit its own events, but existing CC hooks will not fire for out-of-harness children |
| Fork (inherit parent context) | Identical prefix, full tool pool, cache hit | Side investigation without growing the parent thread | High: requires shipping the entire history and identical system prompt; cache sharing only works within one provider and prefix |
| Worktree isolation | Auto worktree with cwd/git enforcement in Bash/Monitor | Parallel writers without file collisions | Medium: creating worktrees is easy; enforcing that the child cannot escape is the hard part |
| Persistent memory | `memory: user|project|local` directory, 200-line/25 KB injection | Role-specific learning across sessions | Low |
| Preloaded skills | Full skill text injected at startup | Domain instructions without discovery cost | Low to Medium |
| Plugin distribution | Scoped names, `hooks`/`mcpServers`/`permissionMode` stripped | Safe third-party agent packs | Medium |
| Agent teams | Mailboxes, shared task list with locking, peer messaging | Debate/parallel-hypothesis workflows | Medium: this is closest to A2A; a shared task store plus messaging is well-understood, but the lead/permission/teardown lifecycle is not |
| Prompt-cache reuse | Forks and resumes hit the cache; per-agent `cacheTtl`; TTL bucketing | Large cost reduction on long-lived specialists | High: depends on identical prefix on the same provider; a bridge to another vendor gets its own cache semantics or none |
| Cost and usage attribution | `/usage` attributes subagent share; OTel; `maxBudgetUsd` in SDK | Budget control and chargeback | Medium: aggregate usage from each child; enforce caps in the bridge |
| Observability | `/tasks`, `/agent-view`, transcript paths in hooks, `parent_tool_use_id` in SDK stream | Live status and after-the-fact audit | Medium: needs liveness/progress signals that CC itself lacks (#91093) |

## Recommendations

Reference recommendations for the comparison arc, not decisions:

1. Treat native subagents' return contract, definition format, and parallelism as table stakes; compare bridges on the High-difficulty rows (permission relay, steering, cache, fork).
2. Highlight where a bridge can exceed native: per-call effort/thinking, non-Claude targets, subagent-scoped budgets, and honest effective-model reporting.
3. Before any bridge benchmark that depends on native model routing, run a live check on the installed CC version (2.1.278 here): spawn with per-call `model` under each of `CLAUDE_CODE_SUBAGENT_MODEL` set/unset and read the served model from the child transcript, since the requested-vs-served bugs above are unresolved.
4. Verify the UNVERIFIED items directly (foreground-child Esc semantics, `PreToolUse` `updatedInput` on `Agent`, `tools: "*"` wildcard, team-hook blocking) before quoting them in a proposal.

## Bridge requirements checklist

Minimum capability set for an external delegation layer to be a credible replacement for CC native subagents (M = must, S = should):

- [ ] (M) Fresh child context with an explicit delegation prompt as the only parent-to-child channel; child transcript never merged into the parent.
- [ ] (M) Single bounded final-message return, labeled as untrusted agent output, with the child ID appended for continuation.
- [ ] (M) Declarative role definitions (name, description, system prompt, tools, model) loadable from project, user, and plugin scopes with defined precedence.
- [ ] (M) Per-role and per-call model selection with a defined precedence order, plus reporting of the effective (served) model per child.
- [ ] (M) Least-privilege tool scoping enforced by the child runtime (allowlist and denylist), including MCP server scoping.
- [ ] (M) Permission handling for child tool calls: either relay to the human/parent with the child named, or an explicit pre-approved/auto-deny policy; a child must never silently escalate.
- [ ] (M) Foreground and background execution with completion notification to the parent, concurrent children, and a concurrency cap.
- [ ] (M) Durable child sessions with stable IDs, resume/continue by ID, and transcript persistence with retention.
- [ ] (M) Cancellation of a running child by the parent and by the human, and a turn/step cap per child.
- [ ] (M) Depth cap (or no-nesting default) and a spend/token budget cap that also stops running children.
- [ ] (S) Per-call effort and thinking controls (native gap; a bridge should not inherit it).
- [ ] (S) Mid-run message injection and steering of a running child.
- [ ] (S) Lifecycle events (start, stop, tool-use) exposed to policy hooks, with child identity attached.
- [ ] (S) Filesystem isolation option (worktree or equivalent) with escape enforcement.
- [ ] (S) Fork mode: child seeded from the parent's full context, with cache sharing where the provider allows.
- [ ] (S) Liveness/progress signal and per-child usage/cost attribution (native gaps #91093, #84223).
- [ ] (S) Non-Anthropic model targets with tool-use and structured-output parity checks.
- [ ] (S) Peer messaging and shared task list if teams-style workflows are in scope.
