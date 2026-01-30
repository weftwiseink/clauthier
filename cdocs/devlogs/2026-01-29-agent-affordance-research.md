---
first_authored:
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-29T20:30:00-05:00
task_list: cdocs/research
type: devlog
state: archived
status: done
tags: [research, agents, plugins, hooks, mcp, tool-scoping]
---

# Agent & Plugin Affordance Research: Devlog

## Objective

Thorough investigation of Claude Code's plugin and agent system affordances: agent frontmatter fields, plugin context inheritance, agent invocation mechanisms, tool scoping, hooks for constraint enforcement, MCP server integration, and plugin.json schema.

## Plan

1. Search official Claude Code documentation for all seven research areas
2. Fetch and parse the actual docs pages for subagents, plugins-reference, hooks, and plugin creation
3. Check GitHub issues for undocumented fields and feature requests
4. Cross-reference with our local plugin structure
5. Synthesize into actionable findings

## Implementation Notes

### Key Findings Summary

**Agent frontmatter fields (confirmed from official docs):**
- `name` (required), `description` (required), `tools`, `disallowedTools`, `model`, `permissionMode`, `skills`, `hooks`, `color` (undocumented but functional)
- NO mechanism for tool parameter constraints (e.g., "Edit only for files matching glob")

**Plugin context inheritance:**
- Subagents receive CLAUDE.md but NOT parent plugin rules
- Skills must be explicitly listed in agent `skills:` field
- No `rules/` directory mechanism in plugin spec

**Agent invocation:**
- Via Task tool (automatic delegation based on description)
- Explicit user request ("use the X agent to...")
- Skills cannot directly invoke agents (but `context: fork` with `agent:` field delegates to one)

**Tool scoping:**
- Only allowlist/denylist at tool level (Read, Write, etc.)
- No file-path-based restrictions in tool config
- PreToolUse hooks are the mechanism for path-based validation

**Hooks:**
- Full lifecycle coverage, including in agent frontmatter
- PreToolUse with exit code 2 blocks operations
- Receives file_path in tool_input JSON -- enables path validation
- Three hook types: `command`, `prompt`, `agent`

**MCP servers:**
- Can be bundled in plugins via `.mcp.json`
- Could wrap Edit/Write with constraints, but no per-agent scoping
- `allowedMCPServers` field exists but only filters from already-loaded servers
- Feature request for lazy-loading/agent-exclusive MCP is open (237 upvotes)

**plugin.json schema:**
- Fields: `name`, `version`, `description`, `author`, `homepage`, `repository`, `license`, `keywords`, `commands`, `agents`, `skills`, `hooks`, `mcpServers`, `outputStyles`, `lspServers`
- No `rules` field exists

## Changes Made

| File | Description |
|------|-------------|
| `cdocs/devlogs/2026-01-29-agent-affordance-research.md` | This research devlog |

## Verification

Research verified against official documentation at code.claude.com/docs/en/sub-agents, /plugins-reference, /hooks, /plugins, and /skills. Cross-referenced with GitHub issues #8501 (frontmatter schema), #6915 (MCP agent scoping), #13700 (lazy-load MCP), #8395 (rule propagation).
