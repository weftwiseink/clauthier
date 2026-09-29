---
review_of: cdocs/proposals/2026-09-28-converser-lace-feature.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-28T10:56:36-07:00
task_list: voice/converser-lace-feature
type: review
state: live
status: done
tags: [rereview_agent, security, permissions, tool_surface]
---

# Review (round 4): converser lace devcontainer feature

> BLUF(opus/voice/converser-lace-feature): Accept, after one inline fix.
> B1 and B2 from round 3 are resolved structurally.
> The converser has no file-write or generic-read tool, and a feature-shipped `converser-io` MCP server with three fixed-path tools owns the ledger and reply files.
> The launcher's `--tools ListAgents,SendMessage,mcp__converser-io__*` was wrong in a different way than it appeared.
> Per the CLI reference, `--tools` "restricts which built-in tools Claude can use ... The flag doesn't affect MCP tools", so the `mcp__` entry was a no-op, and `mcp__voicemode__converse` was never at risk of being filtered out.
> The real gap was `ToolSearch`: MCP tools are deferred by default, and `ToolSearch` is a built-in that a restrictive `--tools` list may omit.
> I fixed Phase 2 inline by setting `ENABLE_TOOL_SEARCH=false` and adding an exact tool-inventory success criterion.

## Verification

| Question | Finding (code.claude.com) |
|---|---|
| Does `--tools` need `mcp__voicemode__converse`? | No. From `cli-reference`: `--tools` "Restrict[s] which built-in tools Claude can use ... The flag doesn't affect MCP tools; to deny those too, use `--disallowedTools "mcp__*"`." `converse` stays available. `mcp__converser-io__*` in `--tools` is meaningless and implied a restriction that doesn't happen. |
| Then what bounds the MCP surface? | `--mcp-config` plus `--strict-mcp-config` ("Only use MCP servers from `--mcp-config`, ignoring all other MCP configurations") plus `VOICEMODE_TOOLS_ENABLED=converse`. All three are already in the proposal. |
| Is deferred loading relevant? | Yes. From `mcp`: "Tool search is enabled by default: MCP tools are deferred and discovered on demand", and loading goes through the built-in `ToolSearch` (`tools-reference`). The docs do not say whether `--tools ListAgents,SendMessage` keeps `ToolSearch`; if it drops it, `converse` and `converser-io` are listed by name but uncallable. `ENABLE_TOOL_SEARCH=false` ("All MCP tools loaded upfront") removes that dependency at negligible cost: four small tools. |
| B1: write surface | Resolved. No `Edit`/`Write`/`NotebookEdit`/`Read` tools. The negation limits are cited correctly (Background line 60, lines 146-147), and the denylist is kept only as a rejected alternative with the full mount list. |
| B2: tool-list consistency | Resolved. `ledger_read` replaces `Read`, and `reply` is the tier-3 return path. The mermaid diagram, threat rows, Phase 0(d), and Test Plan 2 all agree. |
| Reply directory | Container-local (`/run/user/1000/converser/replies/`). The launcher creates it with a literal `mkdir -p -m 700` rather than a `${_REMOTE_USER}` expansion, so it is readable by the same-UID overseer hooks. |

## Findings

**Inline fix applied (was blocking in substance, minor in text).**
Phase 2 now reads `--tools ListAgents,SendMessage`.
It notes that `--tools` doesn't affect MCP tools, names what bounds the MCP surface, and adds `ENABLE_TOOL_SEARCH=false`.
Its success criterion now requires an exact tool inventory: `ListAgents`, `SendMessage`, `mcp__voicemode__converse`, the three `converser-io` tools, and the unremovable `EndConversation`, with no claude.ai connector tools.

**N1 [non-blocking] claude.ai connector tools.**
A signed-in session can surface `mcp__claude_ai_*` connector tools.
It is unverified whether `--strict-mcp-config` suppresses them.
The new Phase 2 inventory check catches it.
If they appear, add `--disallowedTools "mcp__claude_ai_*"` to the launcher.
In a bypass-mode converser, those tools would otherwise run unprompted.

**N2 [non-blocking]** Background line 44 still cites the deep-dive report's `--tools` scoping as if it covered MCP tools.
It is harmless now that Phase 2 is explicit.

**N3 [non-blocking]** The proposal is 4,012 words (about 4,060 after the inline fix), at target.
There are no new inconsistencies across the BLUF, Proposed Solution, Important Design Decisions, the threat table, Test Plan, and Phases.

## Verdict

**Accept.**
All blocking items from rounds 1-3 are resolved.
The one remaining tool-surface error was a text-level fix, applied inline.
The empirical Phase 0 gates, (a)-(g), carry the remaining uncertainty.

## Action Items

1. [non-blocking] If the Phase 2 inventory shows claude.ai connector tools, add `--disallowedTools "mcp__claude_ai_*"` to the launcher.
2. [non-blocking] Optionally tighten Background line 44 to "`--tools` (built-ins only)".
