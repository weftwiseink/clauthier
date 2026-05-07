---
first_authored:
  by: Claude Haiku 4.5
  at: 2026-05-06T00:00:00Z
task_list: clauthier/plugin-marketplace
type: report
state: live
status: complete
tags: [plugin-api, marketplace, investigation]
---

# Claude Code Plugin API Updates: March–May 2026

> BLUF: The past 2–3 months brought significant plugin infrastructure improvements, especially for hooks (PostToolUse replacement, MCP tool invocation), MCP server reliability, and marketplace policy enforcement. However, the critical issue #16538 blocking plugin-level SessionStart hook `additionalContext` injection remains unfixed, requiring the workaround of defining hooks at the user level (`~/.claude/settings.json`) instead of within plugin `hooks.json`. Permission rules saw substantial hardening, and skill filtering/search now uses a type-to-filter menu.

## Context / Background

The cdocs plugin currently works around the lack of plugin-level "always-loaded" context by injecting writing conventions, workflow patterns, and frontmatter specs via a SessionStart hook (workaround for issue #14200 and related #16538). This report investigates:

1. Whether Claude Code now supports first-class plugin-level CLAUDE.md or always-loaded rules without hooks
2. New manifest fields, hook capabilities, and plugin features
3. MCP and distribution improvements affecting cdocs packaging
4. Whether issue #16538 was resolved, enabling cleaner rule delivery across CC and OpenCode targets

## Key Findings

### Plugin Manifest & Validation Enhancements

**New validation flexibility** (`claude plugin validate`): As of late March/early April 2026, the validator now accepts:
- `$schema`, `version`, and `description` at the top level of `marketplace.json`
- `$schema` in `plugin.json`

This reduces boilerplate and allows richer plugin metadata declarations [https://github.com/anthropics/claude-code/raw/refs/heads/main/CHANGELOG.md](https://github.com/anthropics/claude-code/raw/refs/heads/main/CHANGELOG.md).

**Experimental fields formalization**: Themes and monitors should now be declared under `"experimental": { ... }` in plugin manifests (top-level still works with warnings). This signals stability phases for plugin features [https://code.claude.com/docs/en/plugins](https://code.claude.com/docs/en/plugins).

**Skill registration via frontmatter**: Plugins can declare `"skills": ["./"]` using the skill's frontmatter name for stable invocation. Plugin skill hooks from YAML frontmatter are no longer silently ignored—a bug fix that strengthens skill integration [https://github.com/anthropics/claude-code/raw/refs/heads/main/CHANGELOG.md](https://github.com/anthropics/claude-code/raw/refs/heads/main/CHANGELOG.md).

### Hook Expansion & MCP Tool Invocation (Major)

**PostToolUse & PostToolUseFailure enhancements**:
- Now include `duration_ms` (tool execution time excluding prompts/pre-hooks), enabling performance monitoring
- `PostToolUse` can replace tool output for all tools via `hookSpecificOutput.updatedToolOutput`, allowing middleware-style output transformation [https://github.com/anthropics/claude-code/raw/refs/heads/main/CHANGELOG.md](https://github.com/anthropics/claude-code/raw/refs/heads/main/CHANGELOG.md)

**UserPromptSubmit hook gains `sessionTitle` field**: Hooks can now set session titles programmatically, improving workflow automation.

**PreCompact blocking**: Hooks can now block compaction by exiting with code 2, giving plugins veto power over context compaction.

**PermissionDenied hook**: New hook fires after auto-mode classifier denials with `{retry: true}` support, enabling fine-grained permission handling.

**MCP tool invocation in hooks**: Hooks can invoke MCP tools directly via `type: "mcp_tool"`, dramatically expanding hook capabilities beyond stdout/additionalContext—this is a major feature enabling hooks to call external systems without subprocess overhead [https://github.com/anthropics/claude-code/raw/refs/heads/main/CHANGELOG.md](https://github.com/anthropics/claude-code/raw/refs/heads/main/CHANGELOG.md).

**Conditional hook execution**: Hooks using permission rule syntax can now filter execution with conditional `if` fields, reducing noise and unnecessary invocations.

**Output size handling**: Hook output exceeding 50K characters now saves to disk with a preview instead of injecting large text into context, preventing context bloat.

### SessionStart Hook Context Injection Issue—Still Unresolved (Critical)

**Issue #16538 status**: Plugin-defined SessionStart hooks still do **not** surface `hookSpecificOutput.additionalContext` to Claude, though the hook executes without error. Claude receives only a generic success message like "SessionStart:Callback hook success: Success" instead of the injected context.

**Workaround remains required**: Defining the same hook at the user level (`~/.claude/settings.json`) works correctly. The bug is specific to hooks defined within plugin `hooks.json` files.

**Impact on cdocs**: This means you **cannot yet** replace the current SessionStart hook workaround with a true plugin-native rule delivery mechanism. The cdocs marketplace plugin still requires either:
1. User-level hook in `~/.claude/settings.json` (current workaround), or
2. Continued SessionStart hook injection within the plugin until issue #16538 is fixed

No first-class plugin-level CLAUDE.md or always-loaded rules have been introduced as of May 6, 2026 [https://github.com/anthropics/claude-code/issues/16538](https://github.com/anthropics/claude-code/issues/16538), [https://code.claude.com/docs/en/hooks](https://code.claude.com/docs/en/hooks).

### MCP & Tool Improvements

**Transient startup error resilience**: MCP servers now auto-retry up to 3 times for transient startup errors, improving reliability for network-dependent servers.

**OAuth & authentication fixes**:
- Follows RFC 9728 Protected Resource Metadata discovery
- Step-up authorization correctly triggers re-authorization for elevated scopes
- `oauth.authServerMetadataUrl` honored on token refresh, fixing ADFS compatibility

**Tool result persistence**: MCP tool results can override persistence limits via `_meta["anthropic/maxResultSizeChars"]` annotation (up to 500K), allowing large database schemas and configs to pass through without truncation.

**Deferred resource loading**: `resources/templates/list` deferred to first `@`-mention for faster startup, reducing initial session latency.

**alwaysLoad option**: New option skips tool-search deferral for specified servers, ensuring critical tools are available immediately [https://github.com/anthropics/claude-code/raw/refs/heads/main/CHANGELOG.md](https://github.com/anthropics/claude-code/raw/refs/heads/main/CHANGELOG.md).

### Skills & Menu Enhancements

**Effort level integration**: Skills can reference `${CLAUDE_EFFORT}` to adapt behavior to user-selected effort (low, medium, high), enabling context-aware skill behavior.

**Skill menu improvements**:
- Added type-to-filter search box for faster discovery
- Alphabetical sorting for easier scanning
- `t` toggle for token-count sorting
- Description capped at 250 characters in `/skills` menu display

**New skill**: `/less-permission-prompts` scans transcripts and proposes allowlist candidates to reduce future permission prompts, a quality-of-life feature for power users.

**Slash command resolution**: Commands from plugins now resolve correctly when multiple plugins share the same command name, fixing a namespace collision bug [https://github.com/anthropics/claude-code/raw/refs/heads/main/CHANGELOG.md](https://github.com/anthropics/claude-code/raw/refs/heads/main/CHANGELOG.md).

### Marketplace Distribution & Policy

**Marketplace blocklist enforcement**:
- `blockedMarketplaces` and `strictKnownMarketplaces` now enforced on install/update/refresh
- Plugins blocked by policy cannot install or enable
- Breaking change for enterprise policy enforcement

**Dependency management**:
- `plugin install` on existing plugins now auto-resolves missing dependencies
- Version constraint conflicts properly detected and reported
- Stale resolved versions after `plugin update` fixed

**Plugin tag release system**: `claude plugin tag` creates release tags with version validation, supporting semantic versioning for marketplace distribution.

**Plugin pruning**: `claude plugin prune` removes orphaned dependencies, helping clean up marketplace installations [https://github.com/anthropics/claude-code/raw/refs/heads/main/CHANGELOG.md](https://github.com/anthropics/claude-code/raw/refs/heads/main/CHANGELOG.md).

### Permission Rules Hardening

**Sandbox network controls**: `sandbox.network.deniedDomains` blocks specific domains even with broader wildcards, providing fine-grained network access control.

**Read-only command detection**: Read-only commands with env-var prefixes now correctly prompt when variables aren't known-safe, closing security gaps.

**Bash deny rules improved**:
- `Bash(find:*)` allow rules no longer auto-approve `-exec`/`-delete`
- Bash deny rules match commands wrapped in `env`, `sudo`, `watch`, `ionice`, `setsid`

**Path symlink resolution**: `Edit(//path/**)` and `Read(//path/**)` rules now resolve symlink targets, preventing bypass via symlinks to protected paths.

**Dangerous removal paths**: `/`, `$HOME`, system directories (`/private/{etc,var,tmp,home}` on macOS) require explicit approval, hardening destructive operation safety [https://github.com/anthropics/claude-code/raw/refs/heads/main/CHANGELOG.md](https://github.com/anthropics/claude-code/raw/refs/heads/main/CHANGELOG.md).

### Third-Party Ecosystem: Prismatic & Skills

On May 4, 2026, Prismatic launched **Prismatic Skills for Claude Code**, an open-source plugin enabling developers to ship integrations faster. The plugin works alongside Prism MCP dev server for direct Prismatic environment access. This demonstrates the maturing skills/MCP plugin ecosystem and shows strong third-party investment in Claude Code extensibility [https://itbusinessnet.com/2026/05/prismatic-launches-skills-for-claude-code-to-help-developers-ship-integrations-faster/](https://itbusinessnet.com/2026/05/prismatic-launches-skills-for-claude-code-to-help-developers-ship-integrations-faster/).

## Recommendations

### For cdocs Plugin Authors

1. **Do not attempt to replace the SessionStart hook workaround yet**. Issue #16538 remains unresolved. Continue using the user-level hook in `~/.claude/settings.json` as the primary rule delivery mechanism until plugin-native context injection is fixed. You may consider filing a feature request with Anthropic to prioritize this issue if cross-target rule distribution becomes critical.

2. **Leverage new hook capabilities for rule distribution at install time**: Consider adding a `PostInstall` hook that writes rule files to the user's `.claude/rules/` directory or project `.claude/rules/` directory. While not as elegant as plugin-level always-loaded context, this gives users flexibility to integrate cdocs conventions without a global SessionStart hook.

3. **Explore skill metadata enhancements**: Use the new `${CLAUDE_EFFORT}` variable in skill prompts to adapt rule verbosity. For example, `effortLevel: "high"` could inject more detailed writing-conventions guidance, while `effortLevel: "low"` could provide abbreviated guidance.

4. **Document the marketplace policy changes**: If cdocs is distributed as a marketplace plugin, clarify how `blockedMarketplaces` and `strictKnownMarketplaces` affect installation. Test that plugin dependencies resolve correctly under new marketplace enforcement.

5. **Add MCP tool invocation patterns to skill docs**: If cdocs skills should integrate with external MCP servers (e.g., fetching docs, accessing knowledge bases), update skill frontmatter to show hook-based MCP tool invocation via `type: "mcp_tool"` for users who want advanced integrations.

6. **Consider permission-rule documentation refresh**: New deny-rule patterns and symlink resolution may affect rule security. Review and test your existing permission rules under the hardened behavior.

### For OpenCode Multi-Target Delivery

1. **Wait for issue #16538 resolution** before attempting to unify plugin-level rule delivery. The SessionStart hook workaround, while functional, remains a limitation that affects the viability of shipping cdocs as a true "always-on" cross-target plugin.

2. **Once fixed, refactor to plugin-native rules**: When `additionalContext` injection works for plugin hooks, move rule content from the SessionStart hook into explicit `rules/` files within the plugin, allowing both CC and OpenCode to load them via the graceful-degradation layers you've designed.

3. **Investigate skill-based rule delivery**: If plugin-native rules remain blocked, consider registering writing-conventions, workflow-patterns, and frontmatter-spec as *skills* that users invoke at project initialization (e.g., `/cdocs:init` could automatically trigger `/cdocs:load-writing-conventions`), providing a more explicit alternative to always-on context.

### General Plugin Author Guidance

- Hook output size management is now cleaner: leverage the new 50K character limit with disk spillover to avoid context bloat when hooks generate verbose context.
- Test MCP tool invocation in hooks (`type: "mcp_tool"`) if your plugin integrates with external systems—this may replace subprocess-based tool calls with more efficient direct MCP invocation.
- Monitor marketplace enforcement: if your plugin ships as part of a curated marketplace with policy controls, test `blockedMarketplaces` and `strictKnownMarketplaces` scenarios.

## What Was Ruled Out

**Plugin-level CLAUDE.md files**: No first-class support for plugin-scoped CLAUDE.md was introduced. The architecture remains project/user-only for CLAUDE.md, with plugin context delivery limited to hooks.

**Issue #14200 direct fix**: While #16538 (the more specific plugin hook issue) was tracked, no evidence of a fix to the underlying #14200 "plugins can't inject always-on context" architectural limitation was found in the March–May 2026 timeframe.

**Experimental plugins marketplace**: While `"experimental"` formalization was added to manifests, no new experimental marketplace or beta plugin channel was announced.

---

## Sources

- [Claude Code Changelog (March–May 2026)](https://github.com/anthropics/claude-code/raw/refs/heads/main/CHANGELOG.md)
- [Hooks Reference – Claude Code Docs](https://code.claude.com/docs/en/hooks)
- [Create Plugins – Claude Code Docs](https://code.claude.com/docs/en/plugins)
- [Plugin SessionStart Hooks Context Injection Issue #16538](https://github.com/anthropics/claude-code/issues/16538)
- [Prismatic Skills for Claude Code Launch (May 4, 2026)](https://itbusinessnet.com/2026/05/prismatic-launches-skills-for-claude-code-to-help-developers-ship-integrations-faster/)
- [Claude Code Sessions Hooks Guide](https://claudefa.st/blog/tools/hooks/session-lifecycle-hooks)
- [Claude Code Plugin Marketplace Docs](https://code.claude.com/docs/en/plugin-marketplaces)
