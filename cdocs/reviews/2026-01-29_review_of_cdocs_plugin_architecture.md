---
review_of: cdocs/proposals/2026-01-29_cdocs_plugin_architecture.md
first_authored:
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-29T12:30:00-08:00
task_list: cdocs/plugin_architecture
type: review
state: live
status: revision_requested
tags: [architecture, self]
---

# Review: CDocs Plugin Architecture

## Summary Assessment

The proposal provides a reasonable mapping of CDocs concerns onto Claude Code extension mechanisms and correctly identifies plugins as the distribution unit.
However, it has structural issues in three areas: (1) it misclassifies several CLAUDE.md directives as type-specific when they are workflow-general, (2) it treats all six skills as equivalent when they serve fundamentally different roles, and (3) it underspecifies the plugin distribution and fallback stories.

The 10-phase implementation plan is over-decomposed for what is predominantly a markdown-authoring task.

**Verdict: revise**: the architecture is sound in broad strokes but needs rework on the points below before implementation.

## Section-by-Section Findings

### Devlog as a skill: category mismatch

The proposal treats `/cdoc:devlog` identically to `/cdoc:proposal`, a user-invoked command that creates a document.
This misses the fundamental difference in how devlogs work versus other doc types:

- **Proposal, review, report:** The user explicitly requests a deliverable. "Write me a proposal about X." Skill invocation is the natural entry point.
- **Devlog:** The user requests *work*. "Fix the auth bug." The devlog is infrastructure that Claude creates as a side effect of doing the work. The user should not need to invoke `/cdoc:devlog` - it should happen automatically.

The current CLAUDE.md encodes this correctly: "IMPORTANT: Always create a devlog" is a *rule*, not a command.
The devlog skill is still useful as a scaffolding utility that Claude auto-invokes, but the proposal should:
1. Distinguish between **deliverable skills** (proposal, review, report: user-invoked) and **infrastructure skills** (devlog: Claude-auto-invoked, user-invocable as fallback).
2. Make the "always create a devlog" rule the *trigger*, with the skill as the *mechanism*.
3. Consider whether the skill should default to `disable-model-invocation: false` + document that Claude auto-invokes it, rather than presenting it as a peer of `/cdoc:proposal`.

This isn't a fatal flaw (the skill can work both ways), but the proposal's framing conflates two different usage patterns.

### CLAUDE.md slimming table: misplaced migrations

The migration table moves general workflow patterns into type-specific skills:

| Section | Proposed destination | Problem |
|---------|---------------------|---------|
| "Dispatching Parallel Agents" | `skills/devlog/SKILL.md` | Parallel agent dispatch is a general debugging workflow, not a devlog format concern. You dispatch agents when fixing bugs, not when writing devlogs. |
| "Subagent-Driven Development" | `skills/propose/SKILL.md` | Subagent-driven development applies to any complex implementation, not just proposals. Proposals may *describe* subagent phases, but the workflow guidance applies at the project level. |
| "Final Checklist Review" | Split between propose skill and CLAUDE.md | The checklist applies to all work products, including devlogs and reports. Splitting it loses that. |

These should remain as rules (ambient context) or stay in CLAUDE.md.
Moving them into type-specific skills means they're only loaded when that skill is invoked, not during general work.

### Plugin distribution: unaddressed chicken-and-egg

The proposal says "any project can adopt CDocs by enabling the plugin and running `/cdoc:init`" but never explains how a project gets the plugin.
This is the most important UX question for adoption and it's entirely absent.

Options the proposal should evaluate:
1. **Git clone + `--plugin-dir`**: mentioned only in the test plan, not as a distribution strategy.
2. **Marketplace installation**: deferred to "future work."
3. **Global install** (`~/.claude/plugins/cdocs/`): not mentioned.
4. **Vendored into project** (copy `skills/` and `rules/` into `.claude/`): not mentioned.

Without a distribution story, the plugin architecture is theoretical.
At minimum, the proposal should specify the v1 installation flow and acknowledge the gap.

### Skills absorb READMEs: fallback gap

Removing the READMEs from `cdocs/devlogs/` and `cdocs/proposals/` has a cost the proposal doesn't address: discoverability without the plugin.

Scenarios where this matters:
- A team member uses Claude without the CDocs plugin enabled.
- A developer reads the `cdocs/` directory without Claude at all (e.g., on GitHub).
- A new contributor needs to understand the expected doc format.

The READMEs served as self-documenting fallbacks.
The proposal should either:
- Keep lightweight READMEs that reference the skill for full guidance (e.g., "See `/cdoc:devlog` skill for complete guidelines").
- Have the `init` skill generate format-guide READMEs in the project's `cdocs/` subdirs.
- Accept this as a deliberate tradeoff and state it explicitly.

### Status skill: context cost unaddressed

The status skill scans all `cdocs/**/*.md` files using Glob+Read, parsing frontmatter from each.
For a project with 50+ documents, this reads every file into context to extract a few YAML fields.

The proposal should acknowledge this scaling limitation and either:
- Accept it for v1 with a stated bound (e.g., "practical up to ~100 docs").
- Propose a frontmatter index file (e.g., `cdocs/.index.json`) maintained by hooks.
- Move the MCP server timeline up for the status use case specifically.

### Hook script: missing implementation details

The proposal references `cdocs_validate_frontmatter.sh` but doesn't address:
- Where the script lives in the plugin directory (presumably `hooks/`).
- How the hook command resolves the script path (needs `${CLAUDE_PLUGIN_ROOT}/hooks/cdocs_validate_frontmatter.sh`).
- What the script's dependencies are (parsing YAML in bash is non-trivial - does it shell out to Python/Node?).
- Whether the script is executable and has a shebang.

For a distributable plugin, the hook command should use `${CLAUDE_PLUGIN_ROOT}`:
```json
"command": "${CLAUDE_PLUGIN_ROOT}/hooks/cdocs_validate_frontmatter.sh"
```

### Rules scoping: unspecified

The proposal mentions rules should have "appropriate `paths` frontmatter for scoping" (Phase 2) but doesn't specify what that scoping is.
This matters because:
- `writing_conventions.md` should apply broadly (all files, all communication) - probably **no path restriction**.
- `frontmatter_spec.md` should arguably only apply when working on cdocs files: `paths: ["cdocs/**/*.md"]`.

If both are unscoped, the frontmatter spec pollutes Claude's context when working on non-cdocs files.
If the writing conventions are scoped to cdocs, they don't influence general communication.
The proposal should specify this explicitly.

### Implementation phases: over-decomposed

10 phases for a plugin that is primarily SKILL.md and template.md files.
Most phases involve writing 1-2 markdown files.
The proposal itself applies the "5+ task threshold" for subagent-driven development, but the phases are artificially granular.

A more honest decomposition:

| Phase | Scope | Rationale |
|-------|-------|-----------|
| 1. Foundation | Plugin skeleton + rules + init skill | Must exist before anything else |
| 2. Core skills | Devlog + proposal (well-defined types) | Known requirements, parallel-safe |
| 3. Research skills | Review + report (needs research) | Unknown requirements, serial research |
| 4. Management + cleanup | Status skill + hooks + CLAUDE.md migration + README | Depends on all types being defined |

Four phases.
Phases 2 and 3 can overlap if the research is done first.
This is more realistic for what is essentially a markdown-authoring project.

### Plugin repo conflation: minor clarity issue

The layout shows `cdocs/` (dogfooding) alongside `skills/` (plugin source) at the repo root.
The proposal claims this "works naturally" but doesn't explain *why*: plugin components are discovered from specific paths (`skills/`, `hooks/`, `rules/`), and `cdocs/` is not a plugin discovery path.
A sentence of explanation would prevent confusion.

### Edge case #5 is wrong

> "Rule conflicts with project CLAUDE.md: If a project has its own writing conventions that conflict with CDocs rules, the project's rules should win (higher precedence). This is handled by Claude Code's rule loading order."

Plugin rules are loaded at plugin scope, and project CLAUDE.md is loaded at project scope.
Project scope has higher precedence than plugin scope, so the project's rules do win.
However, the proposal states this as fact without verifying the precedence order.
The research I did confirms this is correct, but the proposal should cite the mechanism rather than asserting it.

## Action Items

1. **Reclassify devlog skill** as infrastructure (Claude-auto-invoked) vs. deliverable (user-invoked). Update the skill description and SKILL.md frontmatter guidance accordingly.

2. **Fix CLAUDE.md migration table.** Move "Dispatching Parallel Agents," "Subagent-Driven Development," and "Final Checklist" to `rules/` (not type-specific skills). These are workflow-general.

3. **Add a distribution/installation section.** Specify the v1 installation flow (likely git clone + `--plugin-dir` or global install). Acknowledge marketplace as future.

4. **Address README fallback.** Decide whether `init` generates lightweight READMEs or whether plugin-less discoverability is an accepted tradeoff. State it explicitly.

5. **Acknowledge status skill scaling limits.** Add a bound or propose the index-file mitigation.

6. **Specify hook script path and dependencies.** Use `${CLAUDE_PLUGIN_ROOT}` in the hook command. State the implementation language.

7. **Specify rules scoping.** Writing conventions: unscoped. Frontmatter spec: scoped to `cdocs/**/*.md`.

8. **Consolidate to 4 phases.** Remove artificial granularity. Keep success criteria.

9. **Add one line explaining why `cdocs/` at repo root doesn't interfere** with plugin component discovery.
