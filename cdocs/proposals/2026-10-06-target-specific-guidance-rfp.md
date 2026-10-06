---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T09:46:37-07:00
task_list: cdocs/target-specific-guidance
type: proposal
state: live
status: request_for_proposal
tags: [rules, opencode, cross_tool, context_budget, init]
---

# Target-Specific Guidance Without Bloating Always-Loaded Context

> BLUF(@claude-opus-5-5/cdocs/rules-context-decomposition): cdocs rules, skills, and agents carry Claude Code guidance only; decide how guidance that differs per target (OpenCode, `AGENTS.md` tools) reaches those targets without adding words every Claude Code session loads.
> - **Motivated By:** [the rules context decomposition proposal](2026-10-05-rules-context-decomposition-rfp.md), which deleted every Cross-Target block rather than relocating it.

## Objective

The always-loaded rules are short because they hold only lessons a Claude Code lead or worker uses.
Other targets run the same skills under different runtime facts, and some of those differences change what an agent should do.
Find a delivery path that gives each target the guidance it needs while the Claude Code rule set stays at its budget.

## Scope

- Which runtime differences actually need guidance, for example:
  - arcs and loops run sequentially where `fork` or `SendMessage` is absent,
  - OpenCode model mapping for the advisory tiers (see [the model mapping RFP](2026-10-05-opencode-model-mapping-rfp.md)).
- Build-time injection by `scripts/build-opencode.ts` versus per-target materialization in `/cdocs:init` steps 5 and 6.
- Whether the `AGENTS.md` inline block should carry the full rule set at all, or a shorter cross-tool subset.

## Open Questions

- Is any target difference load-bearing enough to need words, or does agent intuition cover it once the runtime lacks a tool?
- Should target guidance live beside the generated artifacts (build output) rather than in the canonical source?
- How is drift between the Claude Code rules and a target variant detected?
