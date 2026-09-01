---
review_of: cdocs/proposals/2026-08-31-canonical-codex-support.md
first_authored:
  by: "@gpt-5.6-sol"
  at: 2026-08-31T12:05:06-07:00
task_list: cdocs/codex-support
type: review
state: live
status: done
tags: [fresh_agent, round_2, architecture, codex, portability, internal_consistency, missing_validation]
---

# Review (Round 2): Canonical Codex Support for CDocs

> BLUF(codex/cdocs-support-review-r2): The revision resolves the round-one plugin payload, agent-role, model-precedence, reviewer-loading, and phase-ordering blockers.
> Revise once more because the rule-delivery design still copies Claude-specific orchestration into Codex, the shared payload has no rule path that works in both delivery layouts, and the deployer's declared write boundary contradicts its cross-target synchronization requirement.

## Summary Assessment

The proposal has a coherent repository-first architecture and now gives both Codex surfaces one committed translated skill payload.
The live Clauthier and Weftwise trees and current official OpenAI documentation support its plugin boundary, custom-agent precedence, repository discovery, and exact experimental inventory.
The remaining blockers are narrower than round one but still load-bearing: the proposed rule snapshot is not host-neutral, its resource path changes between plugin and repository layouts, and the deployment contract both forbids and requires writes to existing Claude and OpenCode rule materializations.
Verdict: **Revise**.

## Evidence Reviewed

- The revision from `71e5d92` to `1f366fa` and the complete current proposal.
- The round-one review and each of its seven action items.
- Clauthier's 13 canonical skills, four formal agent definitions, three canonical rule files, OpenCode builder, Claude plugin manifest, and marketplace catalog.
- Weftwise's untracked plugin experiment, root `AGENTS.md`, `.claude/rules/cdocs.md`, Codex plugin and marketplace listings, relevant user-config sections, and exact cache version.
- Codex CLI 0.151.0.
- Official OpenAI documentation for [skills and repository discovery](https://learn.chatgpt.com/docs/build-skills), [custom agents and configuration precedence](https://learn.chatgpt.com/docs/agent-configuration/subagents), [plugin contents](https://developers.openai.com/plugins/build/plugins), and [hooks](https://learn.chatgpt.com/docs/hooks).

## Round-One Action Resolution

| R1 action | Resolution |
| --- | --- |
| 1. One translated payload for both surfaces | Resolved at lines 118-140 and 212-213: `plugins/cdocs/codex/` is committed, generated, and consumed by both surfaces. |
| 2. Plugin formal-agent boundary | Resolved at lines 150-157 and 594-608: plugin mode uses fresh built-in agents plus generated role skills and claims no named-agent installation. |
| 3. Model precedence and reviewer method | Resolved at lines 234-247: generated TOML omits model pins and the reviewer packet incorporates the complete method. This matches current Codex precedence. |
| 4. Shared rule ownership | Partially resolved at lines 257-268: adoption and conservative removal are explicit. The synchronization write boundary remains contradictory, and the shared content is not actually host-neutral. |
| 5. Expanded failure pictures | Resolved for every listed round-one failure at lines 465-482. New rule-topology failures are absent. |
| 6. Phase ordering and independent verification | Resolved at lines 546-608: transformation precedes plugin packaging and both modes receive independent workflow tests. |
| 7. OpenCode wildcard warning | Resolved at lines 65-67, 543, and 561: characterization is required and silent normalization is forbidden. |

## Section-by-Section Findings

### Shared payload and rules delivery

**Blocking:** The proposal requires a canonical rule snapshot while requiring Codex output to contain no executable Claude-only mechanisms.
`plugins/cdocs/rules/workflow-patterns.md` currently instructs readers to invoke `/cdocs:*`, use the Claude `Task` tool with `subagent_type`, preload reviewer skills through Claude agent frontmatter, and reason in terms of `haiku`, `sonnet`, and `opus` tool allowlists.
The proposal nevertheless describes `plugins/cdocs/codex/rules/*.md` as a "canonical rule snapshot" at line 126, says deployment copies canonical rules at line 251, and requires the adapter and `cdocs:init` to share one rule hash at lines 270-271.
Those statements conflict with the transformation invariant at lines 217-245 and 437-441.
Copying the rules violates the Codex-only-token invariant, while translating them makes their content and hash differ from `.claude/rules/cdocs.md` and the shared root marker block.
Define which rule content is genuinely cross-host and which orchestration content is target-specific before implementation.

**Blocking:** One unchanged generated skill tree cannot use the stated rule path in both delivery layouts.
The plugin loads skills from `plugins/cdocs/codex/skills/` beside `plugins/cdocs/codex/rules/`, while repository deployment moves those skills to `.agents/skills/cdocs-*` and rules to `.agents/cdocs/rules/`.
Line 252 says generated skills and agents use repository-root-relative rule paths, but plugin-only projects have neither `.agents/cdocs/rules/` nor a CDocs root `AGENTS.md` block.
A relative path from each skill directory also differs between these two layouts.
Specify a resource-closure strategy, such as a stable topology preserved by both surfaces, per-skill packaged references, or explicitly generated delivery-specific path veneers over one semantic payload.
Add plugin-only and repository-only tests that begin without a CDocs `AGENTS.md` block and prove every formal role reads the intended rule set.

### Deployment ownership and atomicity

**Blocking:** The deployer's declared write boundary excludes files that it later requires the deployer to modify.
Line 192 limits writes to `.agents/cdocs/`, `.agents/skills/cdocs-*`, `.codex/agents/cdocs-*`, and the root `AGENTS.md` marker.
Lines 262-264 require the same operation to update existing `.claude/rules/cdocs.md` and `.opencode/rules/cdocs/*.md` materializations and promise that no rule target changes if any cannot be updated.
Phase 3 repeats both claims at lines 568 and 575.
Expand the authorized managed-path set and specify preflight plus rollback or another concrete all-or-nothing mechanism, or move cross-target refresh to the existing `cdocs:init` owner and make Codex deployment refuse stale shared rules.

**Non-blocking:** `--remove` is safe but is not an exact reversal when deployment starts from an absent marker.
Lines 257-268 explicitly retain even a marker created during first setup, so a Codex-only deploy followed by `--remove` leaves active CDocs instructions in root `AGENTS.md`.
Either rename the promise to exact Codex-discovery cleanup and document the retained behavior prominently, or remove a still-identical block only when the manifest proves this deployment created it and no other recognized materialization depends on it.

### Plugin and custom-agent contracts

The revised plugin boundary is internally consistent with current official documentation.
OpenAI documents plugin packages as skills, MCP configuration, hooks, and assets rather than project custom-agent installation, so the built-in-agent role fallback is appropriate.
OpenAI also documents that custom-agent-file model values win over explicit spawn values, so omitting model fields is the correct way to preserve invocation-level overrides.

The transcript requirement for role-skill loading is suitable as an acceptance test, provided the rule resource-closure blocker above is resolved.

### Hooks boundary

The instruction-enforced boundary is stated honestly and the deliberate out-of-scope write probe is adequate for this proposal.
Current OpenAI documentation confirms `PreToolUse`, `SubagentStart`, and `SubagentStop`, but it also states that `SubagentStart` cannot stop startup and documents specific `PreToolUse` coverage and output limits.
Deferring a preventative Codex hook until a dedicated validated design remains reasonable.

### Cleanup and migration

The live Weftwise inventory still matches lines 303-320 exactly: the wrapper, marketplace, and devlog are untracked; `cdocs@personal` is installed and enabled; marketplace `personal` points to Weftwise; and the only experiment cache version is `0.1.0+codex.local-20260831-102655`.
The CLI-first removal, exact stop conditions, and retention of the audit devlog are sound.

## Verdict

**Revise.**
The proposal may not transition to `implementation_ready` until the canonical-versus-translated rule contract, two-surface rule resource topology, and deployer write boundary are internally consistent and tested.
All round-one blockers outside shared rule ownership are resolved.

## Action Items

1. [blocking] Separate portable rule semantics from host-specific orchestration, or define a transformation and hashing model that does not claim translated Codex rules are byte-identical shared materializations.
2. [blocking] Define a rule-resource topology that works from the same fresh-clone payload in both plugin-only and repository-only modes, then add resource-closure runtime tests for both modes without a pre-existing CDocs `AGENTS.md` block.
3. [blocking] Reconcile the explicit deployment write allowlist with updates to `.claude/rules/cdocs.md` and `.opencode/rules/cdocs/*.md`, including a concrete all-or-nothing failure contract.
4. [non-blocking] Clarify whether `--remove` means exact Codex-discovery cleanup or a full reversal of setup when the deployment created the root marker.

## Design Choice Required

Choose the rule-delivery contract before revision:

1. **Portable core plus host appendix (recommended):** Keep writing and frontmatter rules shared, move executable orchestration instructions into generated host-specific appendices, and hash the portable core separately from each appendix.
2. **Host-neutral canonical rules:** Rewrite canonical workflow rules to describe roles semantically, leaving every executable selector, dispatch mechanism, and model/tool mapping to skills and agent adapters.
3. **Target-specific generated rules:** Generate complete Codex rules and stop requiring their content hash to match Claude and OpenCode materializations.
