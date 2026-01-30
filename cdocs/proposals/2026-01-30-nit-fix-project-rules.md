---
first_authored:
  by: "@claude-sonnet-4-20250514"
  at: 2026-01-30T09:00:00-08:00
task_list: cdocs/nit-fix-v2
type: proposal
state: live
status: request_for_proposal
tags: [claude_skills, writing_conventions, plugin_idioms, extensibility]
---

# Nit Fix: Project-Configured Rules

> BLUF(mjr/cdocs/nit-fix-v2): Extend the nit-fix agent to read rules from multiple sources (cdocs plugin, other plugins, project-local configuration) rather than only `plugins/cdocs/rules/writing-conventions.md`.
> Enables projects to define their own writing conventions while preserving the "no hardcoded rules" design principle.
> Rules from different sources are evaluated in parallel and synthesized into a single unified report.

## Objective

The nit-fix agent (status: implementation_ready) currently reads conventions from a single hardcoded path: `plugins/cdocs/rules/writing-conventions.md`.
This design works for cdocs-internal documents but does not support:
- Projects that want to enforce their own writing conventions beyond cdocs defaults.
- Other plugins contributing their own rules (e.g., a technical writing plugin with domain-specific conventions).
- Per-project customization of which rules to enforce without modifying the cdocs plugin source.

This RFP scopes an extension to the nit-fix architecture that supports multiple rule sources while preserving the agent's "rules stickler" design: the agent reads rules at runtime rather than having them hardcoded.

## Scope

This proposal should explore:

1. **Rule discovery mechanism**: How does the agent locate rule files from multiple sources (cdocs plugin, other plugins, project-local)?
   - Path conventions for project-local rules (e.g., `.claude/rules/`, `cdocs/rules/`, configurable path).
   - Plugin rule registration (how plugins declare they provide rules, discovery via marketplace metadata or filesystem convention).
   - Explicit vs. implicit discovery (should the agent auto-scan for rules, or require explicit configuration?).

2. **Parallel evaluation**: How does the agent process rules from multiple sources efficiently?
   - Read all rule files in parallel before processing documents.
   - Apply rules from all sources in a single pass over each document.
   - Track which source contributed each fix or violation for reporting.

3. **Conflict resolution**: What happens when rules from different sources contradict?
   - Example: cdocs plugin requires sentence-per-line, but project-local rules allow multi-sentence bullet points.
   - Priority ordering (plugin rules override project rules, or vice versa?).
   - Opt-out mechanism (project can disable specific cdocs rules without forking the plugin).

4. **Rule source attribution**: How does the report indicate which rule file triggered each fix or violation?
   - Report format changes to show rule source alongside convention name.
   - User experience: does the caller need to know which source a rule came from, or is it implementation detail?

5. **Configuration format**: What does project-local rule configuration look like?
   - Inline rules in a markdown file (same format as `writing-conventions.md`).
   - Metadata to declare rule priority, scope, or dependencies.
   - Integration with the plugin marketplace (can a project import rules from an installed plugin?).

## Known Considerations

### Rule discovery

The agent needs a predictable search path for rule files without hardcoding specific locations.
Potential patterns:
- Scan all installed plugins for `rules/writing-conventions.md` (or a different filename for non-cdocs conventions).
- Read a project-level configuration file (e.g., `.claude/nit-fix-config.yaml`) that lists rule sources explicitly.
- Use a naming convention (e.g., `rules/*.conventions.md`) and glob for all matching files.

Discovery should be deterministic: repeated invocations with the same installed plugins and project state should find the same rule files.

### Parallel evaluation

The agent currently reads one rule file at startup.
With multiple sources, the agent should read all sources in parallel (via multiple Read tool calls) before processing documents.
Rule application still happens sequentially per document (Edit tool cannot be parallelized across the same file), but classification and violation detection can consider all rules simultaneously.

### Conflict resolution between rule sources

Conflicts can occur at two levels:
1. **Direct contradiction**: plugin A requires em-dashes, plugin B forbids them. The agent cannot satisfy both.
2. **Scope overlap**: cdocs rules apply to all `cdocs/**/*.md` files, project-local rules apply to all `*.md` files. The union applies to cdocs files.

Potential resolution strategies:
- **Priority order**: cdocs plugin rules always win, then other plugins alphabetically, then project-local last (or inverse: project-local overrides plugins).
- **Explicit override**: project config can disable specific rules by name (e.g., `disabled_rules: [sentence-per-line]`).
- **Union (additive only)**: all rules apply unless explicitly disabled. Conflicts are reported as judgment-required.
- **Namespace isolation**: rules are namespaced by source (e.g., `cdocs:sentence-per-line` vs. `my-plugin:multi-sentence-bullets`) and do not conflict.

### Report format with multi-source rules

Current report format:
```
[line N] <convention>: <description>
```

With multiple sources:
```
[line N] <source>:<convention>: <description>
```

Or keep convention name unqualified if there are no conflicts, only qualify when ambiguous.

### Plugin vs. project-local rule semantics

Plugin rules are versioned with the plugin: upgrading the cdocs plugin might introduce new conventions.
Project-local rules are user-controlled: the project author decides when to add/remove them.
This affects update semantics and blame attribution:
- If a new plugin rule breaks a document, the fix is "upgrade required new conventions."
- If a new project-local rule breaks a document, the fix is "project config needs tuning."

The agent prompt should clarify that both are treated equally at runtime, but the dispatcher skill or documentation should explain the difference to users.

## Open Questions

1. **Where should project-local rules live?**
   - `.claude/rules/writing-conventions.md`? (mirrors plugin structure)
   - `cdocs/rules/project-conventions.md`? (within cdocs namespace)
   - Configurable path in a project-level config file?
   - Multiple locations allowed (union of all found files)?

2. **How does the agent discover rules from installed plugins?**
   - Scan all `plugins/*/rules/*.md` files?
   - Require plugins to declare rules in their manifest/metadata?
   - Hard-code known plugin rule paths (cdocs, technical-writing, etc.)?
   - Use a plugin hook or registration API?

3. **What happens when two rule sources define the same convention name with different criteria?**
   - Report as a configuration error and refuse to run?
   - Apply both and report conflicts as judgment-required?
   - Use priority order to pick one (which priority order?)?

4. **Should the agent support per-file or per-directory rule scoping?**
   - Example: apply cdocs rules only to `cdocs/**/*.md`, project rules to everything else.
   - Implemented via path patterns in rule file frontmatter (like frontmatter-spec.md has `paths: ["cdocs/**/*.md"]`)?
   - Or always apply all discovered rules to all target files?

5. **How does a project disable a specific plugin rule without forking the plugin?**
   - Explicit `disabled_rules: [cdocs:sentence-per-line]` in project config?
   - Override convention: project-local file defines `sentence-per-line` with no criteria (null rule = disabled)?
   - Not supported: project must fork the plugin or accept all its rules?

6. **What is the update/versioning story for plugin-contributed rules?**
   - If cdocs plugin adds a new convention in v2.0, do all projects using nit-fix automatically enforce it (because rules are read at runtime)?
   - Should projects pin to specific rule versions, or is "always latest" acceptable?
   - Does this interact with plugin versioning in the marketplace?

7. **Should rule files from different sources use the same markdown format as `writing-conventions.md`, or support a richer schema?**
   - Same format (all sources are markdown files with `##` heading per convention) keeps the agent simple.
   - Richer schema (YAML with priority, scope, dependencies) enables more sophisticated conflict resolution but complicates the agent.

8. **How should the report attribute fixes/violations to rule sources?**
   - Always show source (verbose but clear): `[line 10] cdocs:sentence-per-line: split multi-sentence line`.
   - Only show source when ambiguous (minimal but potentially confusing).
   - Group by source in the report: separate sections for "CDOCS PLUGIN FIXES" and "PROJECT RULES FIXES".
   - User preference (configurable report format)?
