---
first_authored:
  by: "@Claude Opus 4.7 (1M context)"
  at: 2026-05-12T13:30:00-07:00
task_list: clauthier/cdocs-rule-delivery
type: proposal
state: live
status: request_for_proposal
tags: [cdocs, plugin_api, hooks, rule_delivery, sessionstart, install_time]
---

# CDocs Rule Delivery Investigation

> BLUF(opus/cdocs-rule-delivery): Determine whether the cdocs SessionStart-hook rule-injection workaround can be retired, simplified, or supplemented; if not, identify any plugin install-time hook surface that could deliver rules without depending on SessionStart context injection.
> **Motivated By:** [cdocs/proposals/2026-05-08-cdocs-plugin-improvements.md](2026-05-08-cdocs-plugin-improvements.md), [cdocs/reports/2026-05-06-cc-plugin-api-updates.md](../reports/2026-05-06-cc-plugin-api-updates.md).

## Objective

The cdocs plugin currently delivers its writing conventions, workflow patterns, and frontmatter spec to the model via a user-level SessionStart hook that injects rule content as `additionalContext`.
This is a workaround for upstream Claude Code issues: #14200 (no first-class "always-on plugin context") and #16538 (plugin-defined SessionStart hooks specifically do not surface `additionalContext`).
The workaround is brittle, lives outside the plugin proper, and complicates cross-target delivery to OpenCode.

Determine the current technical landscape for plugin-native rule delivery and recommend a path forward.

## Scope

The full proposal should explore:

- **Current state of #16538.**
  Has the upstream bug been resolved between 2026-05-06 (report date) and now?
  Empirical retest needed across all three SessionStart subtypes (`SessionStart`, `SessionStart:startup`, `SessionStart:resume`).
  Partial fix is not sufficient to trigger migration; need full resolution.

- **Current state of #14200.**
  The broader "always-on plugin context" gap.
  Resolution of #16538 alone does not close #14200, but progress on either changes the cost-benefit of alternative mechanisms.

- **Regression check on the existing workaround.**
  Verify the user-level hook fallback still injects rule content correctly on the latest CC build.
  The new 50K hook-output cap with disk spillover could silently break the workaround; a clean-room retest of #16538 would not catch this.

- **Plugin install-time hook surfaces.**
  Frame the question as: "does CC have any plugin install-time hook analogous to npm postinstall?"
  Candidates to consider:
  - Literal `PostInstall` hook (claimed by the May 2026 report; unverified, likely incorrect)
  - `Setup` trigger via `--init`
  - `SessionStart:startup` on first session after install (heuristic detection)
  - Lifecycle scripts referenced from `plugin.json`
  - Any other CC-side mechanism not yet documented

- **Hybrid mechanisms.**
  The OpenCode build already uses `scripts/postinstall.js` for npm-side delivery.
  If no CC-side install-time hook exists, evaluate a hybrid: npm postinstall writes rule files; a CC-side activation step (e.g., a one-time skill invocation) registers them.
  Track whether the complexity is worth the benefit over the existing SessionStart hook.

- **Cross-target delivery implications.**
  Cdocs ships for both CC and OpenCode.
  Any new mechanism should preserve or simplify the dual-target story.
  Especially: the OpenCode artifacts in `build/cdocs/opencode/` and the AGENTS.md fallback.

## Known Requirements

- Rule content currently injected: writing-conventions, workflow-patterns, frontmatter-spec.
  All three must remain available at session start without the user manually invoking a skill.
- Migration must not regress existing CC + OpenCode consumers.
- A "known limitations" README subsection is the fallback if no better mechanism exists.

## Prior Art

- [cdocs/reports/2026-05-06-cc-plugin-api-updates.md](../reports/2026-05-06-cc-plugin-api-updates.md): broader May 2026 plugin API survey.
- `plugins/cdocs/hooks/inject-rules.ts` and `plugins/cdocs/hooks/cdocs-hooks.ts`: current SessionStart hook implementation.
- `plugins/cdocs/AGENTS.md`: cross-target fallback strategy for OpenCode.
- `scripts/build-opencode.ts` and `scripts/postinstall.js` (or equivalent): existing npm-postinstall delivery for OC.
- [CC Issue #14200](https://github.com/anthropics/claude-code/issues/14200), [Issue #16538](https://github.com/anthropics/claude-code/issues/16538).

## Open Questions

1. **Migration trigger threshold.**
   If #16538 is fully resolved but #14200 is not, is moving rules into plugin-native files worth doing immediately, or wait for both?
2. **Hybrid mechanism scope.**
   If only a hybrid (npm postinstall + CC-side activation) is viable, is that worth pursuing, or does the SessionStart workaround remain less complex in aggregate?
3. **OpenCode parity.**
   Does any candidate mechanism need an OpenCode equivalent to be acceptable, or is "CC-native, with OC keeping the AGENTS.md fallback" sufficient?
4. **Backwards compatibility.**
   If we move off the SessionStart hook, do existing cdocs installs need a migration step (uninstalling the user-level hook), or can the new mechanism coexist quietly?

## Investigation Plan

A supplemental `/cdocs:report` (see `cdocs/reports/`) deepens the technical survey before this RFP is elaborated into a full proposal.
The report's expected outputs:

- Empirical retest of #16538 on the current CC build.
- Confirmation that the user-level hook fallback still works.
- A catalog of any CC plugin install-time hook surfaces, with citations.
- An evaluation of the npm-postinstall hybrid approach including OC implications.

Once the report lands, `/cdocs:propose` against this RFP path elaborates it into a full proposal with implementation phases.
