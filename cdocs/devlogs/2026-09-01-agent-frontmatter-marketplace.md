---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-01T09:10:00-08:00
task_list: cdocs/agent-frontmatter-marketplace
type: devlog
state: live
status: wip
tags: [subagent, frontmatter, marketplace, best-practices, full-send]
---

# Agent Frontmatter & Marketplace Metadata Adoption: Devlog

## Objective

Full-send (propose-revise -> iterate) a scoped adoption of two Claude-Code best practices for the cdocs plugin:

1. Add `color` / `maxTurns` (and selective `memory: project`) to the four cdocs agents
   (`triage`, `nit-fix`, `reviewer`, `judge`). Withhold `memory` from `reviewer` and `judge`
   to preserve the "fresh eyes, no prior commitment" invariant.
2. Add marketplace `category` / `tags` metadata where the schema supports it.

Out of scope (DEFERRED, do not touch): codex support, non-CC/OpenCode packaging.

Branch: `cdocs/agent-frontmatter-marketplace` (isolated worktree).

## Verification: field support (gating research)

### Subagent frontmatter fields (source: https://code.claude.com/docs/en/sub-agents.md)

All three target fields are REAL and currently supported:

| field | supported | type / values |
|---|---|---|
| `color` | YES | one of: red, blue, green, yellow, purple, orange, pink, cyan |
| `maxTurns` | YES | integer (camelCase — NOT `max_turns`); marks output partial when hit |
| `memory` | YES | one of: `user`, `project`, `local` |

Full supported optional set includes: tools, disallowedTools, model, permissionMode, maxTurns,
skills, mcpServers, hooks, memory, background, effort, isolation, color, initialPrompt, experimental.
Note: plugin subagents cannot use `hooks`, `mcpServers`, or `permissionMode`.

### Marketplace / plugin manifest fields

Verified against schemastore draft-07 schemas (generated 2026-04-23), both `additionalProperties`-lenient:

- **marketplace.json** per-plugin entry: `category` (string, no enum) and `tags`
  (array of strings, no enum) both valid. `category: "productivity"` already present; `tags` can be ADDED.
  Neither `category` nor `tags` is valid at top-level or in `metadata`.
- **plugin.json** (plugin-manifest) top-level: `category` ABSENT, `tags` ABSENT — NOT valid.
  `keywords` (array of strings, no enum) IS valid top-level. So the manifest gets `keywords`,
  NOT category/tags. Dropped: `category`/`tags` on plugin.json (unsupported by schema).

## Plan

- Turn 0: research/verify fields (done for subagents; schema pending).
- Propose-revise loop: dispatch proposer -> reviewer until accept.
- Iterate loop: dispatch implementer -> reviewer (-> judge) until accept.
- Verify final YAML/JSON validity; commit per logical unit.

## Iteration Log

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | notes |
|---|---|---|---|---|---|---|

## Judge Log

| judge_iteration | trigger | verdict | rationale | judge_path |
|---|---|---|---|---|
