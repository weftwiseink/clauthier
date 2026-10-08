---
review_of: cdocs/proposals/2026-09-17-browser-delegation-plugin.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T18:25:55-07:00
task_list: cdocs/browser-delegation
type: review
state: live
status: done
tags: [fresh_agent, staleness, architecture, rereview_agent]
---

# Review (round 2, staleness): Browser Delegation Plugin

> BLUF: Revise before implementation.
> The core design (sonnet delegate driving `@playwright/cli` via Bash, named sessions, no verdicts) holds, but two premises are contradicted by later evidence, the verdict handoff conflicts with `/cdocs:iterate`'s proof rule, and the surface is heavier than the `bash-runner` shape warrants.

> NOTE(opus-5-5/browser-delegation): Recorded verbatim by the propose-revise overseer from a read-only fresh opus `cdocs:reviewer` staleness assessment run 2026-10-07; the original scratch file was ephemeral.
> Round 1 was the 2026-09-17 single sonnet accept (`2026-09-17-review-of-browser-delegation-plugin.md`).

## Verdict

**Revise.**

## Findings and Action Items

Frontmatter: `status: accepted` (line 8) is not a valid proposal status; original acceptance was a single sonnet round, so re-review with opus.

1. [blocking] D2's "decisive" subagent-MCP-inheritance argument is likely false now (lines 20, 35, 112-115, 214, 262). Evidence: cdocs/reports/2026-09-19-claude-code-subagents-feature-breakdown.md §8 (subagents inherit all parent MCP tools by default, background included); plugins/cdocs/skills/ablate/SKILL.md:189 samples mcp__playwright__browser_click in a subagent transcript; dispatched subagents have mcp__claude_ai_* tools. Re-ground D2 on what survives: native named sessions, the version-pin regression class, keeping MCP tool schemas out of the lead's context, and plugin agents dropping mcpServers. Turn the Test Plan inheritance item into a current-behavior check.
2. [blocking] "Existing R1-R6 discipline" is not in code (lines 21, 34, 75-77, 156-158, Phase 3). R1-R6 are recommendations in cdocs/reports/2026-08-04-visual-review-gaps-and-pixel-grounding-handoff.md (still review_ready); `git log -S'R1-R6' -- plugins/` is empty; reviewer.md has no visual pass. Phase 3's "zero reviewer-side changes" check is vacuous. Either drop R1-R6 claims (hand off to plain reviewer + iterate's review_proof) or make R1/R2/R6 an explicit dependency.
3. [blocking] Verdict handoff conflicts with /cdocs:iterate (lines 95-98, 156-158, Phase 3). Iterate's `confirmed` row requires the current round's reviewer to re-run the floor and cite an artifact it produced; third-party artifacts don't count (iterate/SKILL.md lines 91, 130-133). Reviewers can dispatch subagents now (2026-10-06-nested-subagent-workflows accepted), so within iterate the reviewer should dispatch browser-delegate itself. State that reviewer-dispatched delegate artifacts count as reviewer-produced.
4. [blocking] Delegate writing devlog tables conflicts with one-writer-per-file (lines 194-201, 209, 249; Phase 4). tool-use-safeguards.md "One writer per file" and the 2026-10-06 devlog-ownership rework (686b40b, 916063b, 6d3d59e). Delegate returns session/registry facts in its report; the dispatcher writes the table and logs re-opens.
5. [high] Mirror bash-runner's dispatch and report shape (lines 131-154, D6). Agent-only with a "Prompt with:" description (session, route, actions, optional baseline), model: sonnet, effort, maxTurns, tools: Bash, Read, Write with no Agent (stays a leaf). Fixed plain-text report with no verdict field (e.g. BROWSER DELEGATE REPORT: Session, Route, Status OK|FAILED|WARNINGS, Artifacts (absolute paths), AE score, Facts, Truncated/see). TMPDIR-honoring scratch artifact path (7be4e44); the proposal doesn't say where artifacts go. Makes the `drive` skill redundant; drop it (minimal-design preference).
6. [high] Plugin rules/*.md won't reach the lead (lines 69, 125, 141-142). No native plugin rule loading (https://github.com/anthropics/claude-code/issues/14200); cdocs works around via /cdocs:init materialization. toolset-selection.md is lead-facing guidance the lead would never see; bash-runner reads no rules. Fold session naming/sanitization into the agent body, toolset guidance into README and the agent description.
7. [high] Marketplace + OpenCode handling missing (lines 133-142, 256). File table omits the required .claude-plugin/marketplace.json entry. scripts/build-opencode.ts hardcodes cdocs specifics. Maintainer wants OC minimally invasive: declare v1 Claude Code-only as an explicit non-goal with no build changes; replace the "degrades cleanly cross-target" edge case (line 256).
8. [medium] Dead rule references (lines 59, 79-81, 161, 229, 366-367): model-tiering.md and orchestration-discipline.md are gone. Re-point to workflow-patterns.md "Model Tiering", overseers.md "Stay thin" (named subagent resumed via SendMessage, ~400K handoff cap for long-lived delegates), tool-use-safeguards.md "One writer per file". "Durable specialist" is no longer a rule term.
9. [medium] Nesting depth (Multi-client sync, D4). `sync` must stay a skill the dispatcher runs inline, never a wrapper agent. Chain top-level, sub-overseer, reviewer, delegate hits layer 3 exactly; a wrapper agent pushes delegates past the limit where Agent is withheld. One line.
10. [medium] Fold in cdocs/reports/2026-09-17-delegate-model-comparison.md (accepted 2026-09-18; maintainer leaned Gemini Pro vs Sonnet; a "pluggable-model amendment" awaits maintainer). Add to Background; state driving stays Claude/sonnet in v1 (CC `model:` is Anthropic-only); visual-model choice belongs to the reviewer leg, out of the delegate's scope.
11. [low] Sync simplification (lines 179-180). Per-role background delegates have no channel to sequence cross-client actions. Either dispatcher-mediated SendMessage, or default to one delegate driving N named sessions (simpler, cheaper); keep per-role agents for genuinely independent driving.

Still open since 2026-09-17 (no spike run): @playwright/cli SIGTRAP exposure, named-session isolation sufficiency, first-party browser-use tool GA/in-harness availability, Healer `claude` integration.

Obsoleted by recent work: D2 point 1 and the Test Plan's inheritance regression check; "existing R1-R6 / reviewer.md hosts it" framing; delegate-writes-devlog-table; `drive` skill and both plugin rules files (under the bash-runner shape); cross-target "degrades cleanly" claim.
