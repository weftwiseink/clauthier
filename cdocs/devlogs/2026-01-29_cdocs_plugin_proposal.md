---
first_authored:
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-29T12:00:00-08:00
task_list: cdocs/plugin_architecture
type: devlog
state: live
status: done
tags: [architecture, claude_skills, plugin, proposal]
---

# CDocs Plugin Architecture Proposal: Devlog

## Objective

Author the foundational proposal for reworking the CDocs repo into a Claude Code plugin, as requested in `cdocs_plan.md`.

## Plan

1. Read all repo content (CLAUDE.md, cdocs_plan.md, devlogs/README.md, proposals/README.md).
2. Research Claude Code extension mechanisms (plugins, skills, hooks, rules, MCP).
3. Design the plugin architecture mapping current content to plugin components.
4. Write the proposal following `cdocs/proposals/README.md` format.
5. Write this devlog.

## Implementation Notes

### Key architectural decision: full plugin over bare skills

Bare `.claude/skills/` would work for single-project use, but the plan explicitly targets distributable, reusable tooling.
A plugin (`.claude-plugin/plugin.json`) gives namespaced commands (`/cdoc:devlog`), bundled hooks and rules, and a versioned manifest.

### Skills absorb READMEs

The current `devlogs/README.md` and `proposals/README.md` serve the exact purpose that `SKILL.md` files serve: instructions for Claude.
Keeping both would create duplication.
The proposal specifies removing the READMEs once skills absorb their content (Phase 9).

### Rules for cross-cutting conventions

Writing conventions and frontmatter specs apply to all doc types.
Rather than duplicating in each skill, these become `rules/*.md` files loaded as ambient context.
This aligns with the plan's request to "break the general high-level communication and documentation directives into a resource for reference by all our skills."

### Informational hooks, not blocking

Blocking writes on frontmatter issues would disrupt workflow.
The PostToolUse hook warns but doesn't block - Claude can self-correct in context.

### Review and report types flagged as research-needed

The repo has no review or report READMEs.
The proposal flags Phases 5-6 as requiring research into best practices.
Initial structures are proposed but marked with NOTE callouts.

### Unaccounted conventions catalogued

Identified 8 process-level conventions not currently codified (template prompts, review workflow state machine, task_list linkage, etc.).
These are documented in the proposal for future expansion.

### Self-review findings (round 1)

Fresh-eyes review surfaced 9 action items. Key issues:

1. **Devlog skill misclassified.** Devlogs are work infrastructure (Claude-auto-invoked), not user-requested deliverables. The proposal treats `/cdoc:devlog` identically to `/cdoc:proposal`, but the invocation model is fundamentally different. The "always create a devlog" rule should be the trigger - the skill is the mechanism.
2. **CLAUDE.md migration table moves general patterns into type-specific skills.** "Dispatching Parallel Agents" and "Subagent-Driven Development" are workflow-general, not devlog/proposal-specific. They should stay as rules.
3. **No distribution story.** The proposal designs a plugin but never explains how users install it. Chicken-and-egg with the init skill.
4. **README removal loses plugin-less fallback.** Without READMEs, `cdocs/` is opaque to non-plugin users and GitHub readers.
5. **10 phases over-decomposed** for what is primarily markdown authoring. 4 phases is more honest.

Full review: `cdocs/reviews/2026-01-29_review_of_cdocs_plugin_architecture.md`

### Revision applied (round 1)

All 9 action items addressed in proposal rewrite:
- Skills split into deliverable vs. infrastructure categories - devlog reclassified as infrastructure (auto-invoked).
- CLAUDE.md migration table corrected: parallel agents, subagent dev, checklists -> `rules/workflow_patterns.md` (new rule file).
- Distribution/installation section added (git clone + `--plugin-dir`, vendor option).
- Init skill generates lightweight fallback READMEs for plugin-less discoverability.
- Status skill scaling acknowledged (~100 doc limit, index file mitigation path).
- Hook script path uses `${CLAUDE_PLUGIN_ROOT}`, bash regex-based implementation specified.
- Rules scoping explicit: writing_conventions and workflow_patterns unscoped, frontmatter_spec scoped to `cdocs/**/*.md`.
- Phases consolidated from 10 to 4.
- Plugin dogfooding and rule precedence explanations added to edge cases.

## Changes Made

| File | Description |
|------|-------------|
| `cdocs/proposals/2026-01-29_cdocs_plugin_architecture.md` | Proposal (revised): 6 skills in 2 categories, 3 rules, hooks, 4 phases |
| `cdocs/reviews/2026-01-29_review_of_cdocs_plugin_architecture.md` | Self-review with 9 action items, verdict: revise |
| `cdocs/devlogs/2026-01-29_cdocs_plugin_proposal.md` | This devlog |

## Verification

- Proposal follows required sections from `cdocs/proposals/README.md` (BLUF, objective, background, proposed solution, design decisions, edge cases, test plan, implementation phases).
- Frontmatter follows spec from `cdocs_plan.md`.
- All items from `cdocs_plan.md` addressed: skills, hooks, rules, CLI/status, scaffolding, marketplace (deferred), writing conventions, formatting automation (deferred), reviews/reports (research flagged).
- Author checklist reviewed: BLUF matches settled approach, sources cited, decisions explain "why", NOTE callouts on uncertain areas (review/report structure).
- Self-review completed with revision_requested verdict. All 9 action items resolved in revision.
