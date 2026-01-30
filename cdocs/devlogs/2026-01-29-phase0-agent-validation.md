---
first_authored:
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-29T20:26:13-08:00
task_list: triage-v2/phase-0-validation
type: devlog
state: live
status: complete
tags: [agents, plugins, hooks, skills, triage-v2, validation]
---

# Phase 0: Plugin Agent Validation Devlog

## Objective

Validate whether Claude Code plugin agents work as documented. This is Phase 0 of the triage-v2 proposal -- testing agent registration, hook enforcement, tool restriction, model override, and skills preloading before building the real triage agent.

## Plan

1. Add `"agents": "./agents/"` to plugin.json and validate.
2. Create a minimal test agent (`agents/test.md`) with hooks in frontmatter.
3. Create a PreToolUse hook script that restricts Edit to cdocs paths.
4. Test agent invocation via CLI and Task (subagent) tool.
5. Test hook enforcement on the agent.
6. Test skills preloading via a second agent.
7. Clean up test files, document findings.

## Findings

### Finding 1: `"agents"` field in plugin.json is NOT supported

Adding `"agents": "./agents/"` to `plugin.json` causes validation failure:

```
$ claude plugin validate plugins/cdocs
agents: Invalid input
Validation failed
```

Agents are discovered by **convention** -- the CLI automatically scans an `agents/` directory at the plugin root. The official `code-simplifier` plugin confirms this: it has `agents/code-simplifier.md` but no `"agents"` field in its manifest.

**Action:** Do not add an agents field to plugin.json. Just create the `agents/` directory.

### Finding 2: Agent registration via `agents/` directory WORKS

Debug logs confirm:
```
Loaded 1 agents from plugin cdocs default directory
Total plugin agents loaded: 1
```

The agent is registered with the naming convention `{plugin}:{agent}`, e.g., `cdocs:test`.

### Finding 3: Supported agent frontmatter fields

From testing and reference to the official `code-simplifier` agent, the confirmed working frontmatter fields are:

| Field | Supported? | Notes |
|-------|-----------|-------|
| `name` | YES | Agent identifier, used in Task tool dispatch |
| `description` | YES | Agent description |
| `model` | YES | Model override (e.g., `haiku`, `opus`) -- confirmed working |
| `tools` | YES | Comma-separated tool list -- restricts available tools |
| `skills` | YES | Array of skill references (e.g., `cdocs:review`) -- preloads skill content |
| `hooks` | NO | Not loaded from agent frontmatter (see Finding 5) |

### Finding 4: Subagent dispatch via Task tool WORKS

When the plugin is loaded (via `--plugin-dir` or installed), the agent is available as a subagent type through the `Task` tool:

```
Task tool subagent_type: "test" -> dispatches cdocs:test agent
```

The system prompt from the agent's markdown body is injected into the subagent. The subagent correctly quoted its instructions:
> "You are a test agent. When invoked, do the following: 1. Read the file at the path provided..."

**Important:** The `Task` tool is only available within a CLI session. It is NOT available through the API-level tools used by outer agents running on the API (e.g., the current session uses `TaskCreate`/`TaskUpdate`/`TaskGet`/`TaskList` for task management, not the subagent dispatch `Task` tool).

### Finding 5: Agent-level hooks in frontmatter are NOT enforced

The `hooks:` field in agent frontmatter is not a supported feature. Debug logs show:

```
executePreToolHooks called for tool: Edit
Getting matching hook commands for PreToolUse with query: Edit
Found 0 hook matchers in settings
Matched 0 unique hooks for query "Edit" (0 before deduplication)
```

Hooks are loaded ONLY from the plugin's `hooks/hooks.json` file. They apply globally to all tool use in the session, not scoped per-agent.

**Workaround:** To enforce agent-specific edit restrictions, use the global `hooks/hooks.json` with a hook that checks context (e.g., environment variable or file path pattern) rather than per-agent hooks.

### Finding 6: Tool restriction WORKS

The `tools: Read, Edit, Glob` frontmatter correctly limited the test agent to only those three tools. Bash and WebSearch were confirmed unavailable.

### Finding 7: Model override WORKS

The `model: haiku` frontmatter was respected for subagent dispatch via the Task tool. The `modelUsage` in JSON output confirmed `claude-haiku-4-5-20251001` was used.

**Note:** `--agent test` via the top-level CLI flag does NOT respect the model from frontmatter -- it uses the default or `--model` flag. Model override only works for subagent dispatch via Task tool.

### Finding 8: Skills preloading WORKS

The `skills: [cdocs:review]` frontmatter successfully loaded the review skill content from `plugins/cdocs/skills/review/SKILL.md` into the agent's system prompt. The test-skills agent quoted specific review instructions verbatim, including verdict options, review philosophy, and workflow steps.

### Finding 9: `--agent` CLI flag does NOT load plugin agent definitions

Using `--agent test` at the CLI top level does NOT load the agent's system prompt or model from the plugin's `agents/test.md`. The flag appears to set an agent identifier for routing but does not inject the agent definition. Agent definitions only take effect when dispatched as subagents via the `Task` tool.

### Finding 10: `--agents` JSON flag works for inline agent definitions

The `--agents '{"name": {"description": "...", "prompt": "..."}}'` CLI flag does work for defining agents inline. Agents defined this way ARE available as subagent types through the Task tool.

## Changes Made

| File | Description |
|------|-------------|
| `plugins/cdocs/hooks/validate-cdocs-edit-path.sh` | New PreToolUse hook script restricting Edit to cdocs document directories (kept for real implementation) |
| `plugins/cdocs/agents/test.md` | Created and deleted (test artifact) |
| `plugins/cdocs/agents/test-skills.md` | Created and deleted (test artifact) |

## Implications for Triage V2

1. **Agent definition approach is viable.** Create `plugins/cdocs/agents/triage.md` with frontmatter specifying `name`, `model`, `tools`, `skills`, and `description`. The markdown body becomes the agent's system prompt.

2. **No per-agent hooks.** Edit restrictions must be enforced through the global `hooks/hooks.json`, not agent-level frontmatter. The hook can inspect file paths and apply restrictions globally.

3. **No `"agents"` in plugin.json.** The `agents/` directory is discovered by convention.

4. **Subagent dispatch is the correct invocation path.** The triage agent should be designed for dispatch via the `Task` tool with `subagent_type: "triage"`, not via `--agent triage` at the CLI level.

5. **Skills preloading enables composable agents.** A triage agent can preload relevant skills (e.g., `cdocs:triage`, `cdocs:propose`) to receive domain knowledge without duplicating content.

6. **Tool restriction works.** Triage agents can be limited to safe tools (Read, Glob, Write) without access to Bash or other dangerous tools.

## Verification

All tests were run via `claude -p` with `--plugin-dir` and `--output-format json` for structured verification. Debug logs (`--debug hooks`) confirmed hook loading and execution paths. Key verifications:

- Agent loaded: `Loaded 1 agents from plugin cdocs default directory` (debug log)
- Model override: `claude-haiku-4-5-20251001` in modelUsage (JSON output)
- Tool restriction: Bash and WebSearch confirmed unavailable by agent self-report
- Skills injection: Review skill content quoted verbatim by agent
- Hook non-enforcement: `Found 0 hook matchers in settings` for PreToolUse:Edit in subagent (debug log)
