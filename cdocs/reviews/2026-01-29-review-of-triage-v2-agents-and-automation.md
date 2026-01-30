---
review_of: cdocs/proposals/2026-01-29-triage-v2-agents-and-automation.md
first_authored:
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-29T17:30:00-08:00
task_list: cdocs/haiku-subagent
type: review
state: live
status: done
tags: [fresh_agent, architecture, workflow_automation, subagent_patterns, plugin_idioms, hook_enforcement]
---

# Review: Triage v2 - Agent Abstraction with Hook-Scoped Edits

## Summary Assessment

This proposal redesigns the cdocs triage system from a skill-with-embedded-prompt-template into a formal agent architecture with infrastructure-enforced tool restrictions, skills preloading, and automated review dispatch.
The proposal is well-structured, clearly motivated by concrete v1 failures, and addresses the three identified problems (wrong abstraction, fragile safety, no automated review dispatch) with appropriate architectural mechanisms.
The most important finding is that the proposal relies on several undocumented or unverified Claude Code platform affordances (agent-scoped hooks, `skills` frontmatter field, `${CLAUDE_PLUGIN_ROOT}` expansion) that Phase 0 is designed to validate, but the entire architecture collapses if any of these affordances do not exist as described, and the fallback plan is underspecified.
Verdict: **Revise** - several blocking issues around unverified platform assumptions, hook script gaps, and the mechanical/semantic boundary need resolution before implementation begins.

## Section-by-Section Findings

### BLUF

The BLUF is dense but accurate.
It correctly summarizes the three v1 problems and the four-part v2 solution (agent definitions, PreToolUse hooks, skills preloading, read-at-runtime rules).
The characterization of the triage agent's dual role (mechanical fixes via Edit, status/workflow recommendations to dispatcher) is clear.

No issues.

### Objective

The three problems are well-defined and trace directly to v1 evidence.

**Non-blocking:** Problem 2 could benefit from explicitly stating that the v1 workaround (full read-only) was itself documented in the v1 devlog and review as an acceptable resolution, making the case for why v2 needs to revisit this. As written, the proposal implies read-only was simply "overly conservative," but the v1 review accepted it as the right call given the available infrastructure. The v2 proposal is motivated by the existence of new infrastructure (agent-scoped hooks) that was not available in v1. This distinction matters for understanding why revisiting the decision is warranted.

### Background: Claude Code Agent System

**Blocking:** This section documents a detailed agent system specification (YAML frontmatter with `name`, `model`, `description`, `tools`, `hooks`, `skills` fields, auto-discovery from `agents/` directory, PreToolUse lifecycle hooks, etc.) that is treated as established fact throughout the proposal. However, no source is cited, and the current `plugin.json` has no `agents` field. The `agents/` directory does not exist in the repository.

Phase 0 is designed to validate these affordances, which is the right approach. But the proposal should explicitly acknowledge that this entire section describes *expected* behavior that has not been verified in this plugin context. The difference between "the platform supports X" and "we expect the platform supports X, pending Phase 0 validation" is critical for risk assessment.

Specific concerns about the documented affordances:

1. **Agent-scoped PreToolUse hooks in YAML frontmatter:** The existing `hooks.json` uses a JSON schema for hooks at the plugin level. The proposal assumes agents can define PreToolUse hooks in YAML frontmatter with the same schema. This is plausible but unverified.

2. **`skills` frontmatter field:** The claim that `skills: [cdocs:review]` injects "full skill content at startup" is a strong assertion. This could mean the skill's markdown body is concatenated into the agent's system prompt, or it could mean the skill becomes available for invocation. These are different behaviors with different implications. If it is invocation-availability rather than content-injection, the reviewer agent would need to explicitly call the skill rather than having the review methodology in its context.

3. **`${CLAUDE_PLUGIN_ROOT}` expansion:** The hook command uses `${CLAUDE_PLUGIN_ROOT}/hooks/validate-cdocs-edit-path.sh`. This variable is used in the existing `hooks.json`, so it likely works at the plugin level. Whether it works inside agent-scoped hook definitions is a separate question.

4. **"Agents cannot spawn other subagents":** This constraint is stated without citation. If incorrect, it has implications for the reviewer agent potentially spawning sub-subagents.

### Context Inheritance Constraints

This section is valuable: it explicitly documents what subagents do and do not inherit, which is critical for the read-at-runtime strategy.

**Non-blocking:** The statement "there is no `rules` field in the plugin spec" should be verified in Phase 0 alongside the other affordance checks. If a `rules` field existed, it would simplify the architecture by eliminating the need for read-at-runtime rule loading.

### V1 Implementation State and Test Results

Well-presented. The file tree, problem list, and test result table are clear and concrete.

**Non-blocking:** The test results table would benefit from noting *which* three unrelated files haiku edited in Test 1. This detail is in the v1 devlog but is useful here for assessing whether the hook regex would have prevented them (i.e., were they in `cdocs/` subdirectories or completely outside cdocs?).

### Architecture: Agent + Hook + Skill Separation

The file tree is clear and the three-layer enforcement model is well-articulated.

**Blocking:** The three-layer model has a gap at layer 3. The proposal states: "If haiku edits a different cdocs file, the hook allows it (it's a valid cdocs path) but the damage is limited to the cdocs domain. This is an acceptable blast radius."

This underestimates the potential damage. Consider: the triage agent is asked to triage `cdocs/devlogs/2026-01-29-foo.md`. Haiku instead edits `cdocs/proposals/2026-01-29-bar.md`, which is a reviewed-and-accepted proposal in `implementation_ready` status. The hook allows this edit because the path matches `cdocs/(devlogs|proposals|reviews|reports)/`. Haiku could modify the proposal's frontmatter (changing `status: implementation_ready` to `status: wip`) or body content, silently corrupting a finalized document.

The v1 evidence supports this exact scenario: Test 1 showed haiku editing 3 unrelated files. The hook addresses the *path domain* problem (non-cdocs files) but does not address the *file scope* problem (wrong cdocs files). The proposal acknowledges this but characterizes the blast radius as "a correct tag being added to a file that wasn't requested: low-severity, easily reverted." The v1 evidence shows the actual blast radius includes status field modifications and content changes, which are higher severity.

Mitigation options to consider:
- Pass the list of allowed file paths to the hook via environment variable, so the hook can restrict edits to exactly the files being triaged.
- Accept the risk explicitly but add a post-triage verification step where the dispatcher checks `git diff` to confirm only expected files were modified.

### Triage Agent Definition

The YAML frontmatter and behavior description are clear.

**Non-blocking:** Step 1 says "Reads `plugins/cdocs/rules/frontmatter-spec.md` (one Read call, no duplication)." This costs one Read call per triage invocation. For frequent end-of-turn triage, this is a recurring cost. Not a significant concern for haiku (fast, cheap), but worth noting that the `skills` approach (one-time injection) was chosen for the reviewer's review skill but not for the triage agent's rule dependencies. The rationale in Decision 2 ("they're reference documents, not action instructions") is reasonable but could also justify converting the frontmatter spec to a skill for the triage agent.

### Reviewer Agent Definition

Clean design. The `skills: [cdocs:review]` approach is the right pattern if the platform supports it.

**Non-blocking:** The NOTE correctly identifies that the reviewer needs both Write (new review file) and Edit (update target's `last_reviewed`). One question: can the reviewer Edit the target document's frontmatter if the target is in `cdocs/proposals/`? Yes, the hook regex allows this. But should the reviewer be able to Edit *any* cdocs document, or only the review it is creating and the specific target it is reviewing? The same file-scope concern from the architecture section applies here.

### Hook Script: `validate-cdocs-edit-path.sh`

**Blocking:** The hook script has several gaps:

1. **Relative vs. absolute paths:** The script checks `$FILE_PATH` against a regex `cdocs/(devlogs|proposals|reviews|reports)/`. If the tool provides an absolute path (e.g., `/var/home/mjr/code/weft/cdocs/cdocs/proposals/...`), the regex will still match because it is not anchored to the start. This is likely fine in practice. However, if the path is relative but uses a different prefix (e.g., `./cdocs/proposals/...`), it also matches. The concern is path traversal: could a crafted path like `../some-other-repo/cdocs/proposals/malicious.md` match the regex? The regex `cdocs/(devlogs|proposals|reviews|reports)/` would match this. This is a defense-in-depth concern, not a primary attack vector (the agent would need to construct such a path), but the regex should be tightened to anchor against the working directory or use an absolute path check.

2. **Empty `file_path` fallback:** The script exits 0 (allow) when `$FILE_PATH` is empty. For a PreToolUse hook on Edit/Write, an empty file path would be anomalous. Exiting 0 (allow) is permissive. Exiting 2 (block) would be safer, since an Edit/Write without a file path should not proceed.

3. **No Write-specific handling:** The reviewer agent's hook matches `Edit|Write`. The Write tool creates new files. The script validates the *path* but not whether the file already exists. This is probably fine (the reviewer should be able to Write new review files to `cdocs/reviews/`), but consider whether the triage agent's hook should also match Write to prevent haiku from accidentally creating new files. Currently, the triage agent's tools list is `Read, Glob, Grep, Edit` (no Write), so this is handled at the tool allowlist layer. Good defense-in-depth.

4. **No `jq` availability check:** The script uses `jq` to parse stdin. If `jq` is not installed, `set -euo pipefail` will cause the script to exit with a non-zero code. What exit code? Likely 1, which is neither "allow" (0) nor "block" (2). The behavior for exit code 1 in a PreToolUse hook is undocumented in this proposal. If exit code 1 is treated as "allow," a missing `jq` would silently bypass the guard.

### Triage Skill (Thin Dispatcher)

The six-step orchestration flow is clear and well-sequenced.

**Non-blocking:** Step 4 says "The dispatcher applies status recommendations it agrees with." This anthropomorphizes the skill: a skill is instructions for the main agent, not an autonomous decision-maker. More precisely: the main agent, following the skill's instructions, evaluates status recommendations and applies those it judges appropriate. This is a framing issue, not a functional one.

**Non-blocking:** Step 6 says "After review completes, re-triage the review document to validate its frontmatter." This creates a recursive invocation: triage -> review -> triage. The proposal states agents cannot spawn other subagents, so the re-triage would be dispatched by the main agent. But the orchestration flow should explicitly state this to avoid confusion about whether the reviewer agent triggers re-triage itself.

### Hook-Scoped Edit Decision (Decision 1)

The mechanical/semantic split is the core design decision of this proposal.

**Blocking:** The definition of "mechanical" edits is: "tag additions/removals, timestamp fixes, adding missing required fields with defaults. These are deterministic corrections."

This is not entirely accurate:
- **Tag additions/removals:** Determining which tags to add requires analyzing document content and matching it to a tag vocabulary. This is a judgment call, not a deterministic correction. A document about "hook enforcement" might warrant `hooks` or `enforcement` or `security` or all three. The v1 triage prompt says "Be conservative: only change tags clearly supported by document content," which acknowledges the judgment involved.
- **Adding missing required fields with defaults:** What is the default `task_list`? What is the default `state`? These require context the triage agent may not have. The v1 review (action item 5) noted this exact issue.

The proposal should either:
1. Tighten the definition of "mechanical" to exclude tag analysis (only timestamp fixes and presence checks for required fields without filling defaults).
2. Accept that "mechanical" includes low-stakes judgment calls and document this explicitly, including what happens when haiku makes a wrong judgment call (e.g., adds an inappropriate tag).

The v1 evidence is directly relevant: haiku's difficulty was not limited to status edits. In Test 1, it also modified unrelated files, suggesting broader judgment failures. The question is whether hook-scoping the Edit path is sufficient to make tag-addition judgment calls safe, given that the worst case is an incorrect tag on the right file (low severity, easily reverted). This is probably an acceptable risk, but the proposal should state it explicitly rather than claiming tag edits are "deterministic."

### Skills Field Decision (Decision 2)

Sound reasoning. The distinction between skills (action instructions) and rules (reference documents) is a good conceptual separation. The read-at-runtime approach for rules is pragmatic.

No issues.

### Shared Hook Script Decision (Decision 3)

Appropriate. One script, one maintenance point.

No issues.

### Separate Agents Decision (Decision 4)

Well-reasoned cost/capability separation.

**Non-blocking:** The proposal says "Combining them would require either over-provisioning model (giving triage sonnet's cost) or under-provisioning tools (giving the reviewer haiku's limitations)." A third option exists: a single agent definition with model selection at invocation time. The proposal does not need to adopt this, but acknowledging and dismissing it would strengthen the decision.

### Thin Dispatcher Decision (Decision 5)

Clean separation of concerns. The v1 conflation of dispatch and prompt is correctly identified.

No issues.

### Sonnet Default Decision (Decision 6)

Reasonable. The note about dispatcher override to opus for high-stakes documents raises a question: how does the dispatcher determine "high-stakes"? By document type (proposals are high-stakes)? By content? By user configuration? This is a minor loose end.

### Edge Cases

Edge cases 1-6 are well-considered. Specific findings:

**Edge case 1 (registration/hook failure):** The fallback to v1 approach is mentioned but not specified. What does "falls back to v1" mean in practice? The v1 skill still exists (as a thin dispatcher). If agents don't work, the dispatcher has nothing to dispatch to. Does the skill detect that agents are unavailable and revert to inline prompt template behavior? This should be explicit.

**Edge case 2 (skills field resolution):** The fallback (Read-at-runtime) is well-specified. The testing of multiple reference formats is good.

**Edge case 3 (wrong cdocs files):** Addressed above in the architecture section. The blast radius characterization is too optimistic.

**Edge case 4 (incorrect mechanical fixes):** The PostToolUse hook validates field *presence* but not field *correctness*. A triage agent that adds `type: devlog` to a proposal would pass the PostToolUse check. The dispatcher spot-check is the real safety net here, but it is described as optional ("can also re-read files"). This should be a required step.

**Edge case 5 (busy session):** The isolated context claim is strong. If agents truly run in separate processes with their own system prompts, this is solved. Phase 0 should verify this isolation property.

**Edge case 6 (rules changes):** Correctly identified as a non-issue for read-at-runtime and skills preloading.

### Test Plan

The nine test cases cover the major scenarios.

**Blocking:** The test plan lacks a negative test for the hook script itself. Test 2 ("have it attempt to Edit a non-cdocs file") validates the hook blocks disallowed paths, but there is no test for:
- What happens when the hook script fails (exit code 1 vs. 2)?
- What happens when `jq` is unavailable?
- What happens with edge-case paths (absolute paths, relative paths with `./`, paths with `..`)?
- What happens when the hook receives malformed JSON on stdin?

Add a test case: "Hook robustness: invoke the hook script directly with various edge-case inputs (empty stdin, malformed JSON, absolute paths, relative paths, path traversal attempts) and verify correct exit codes."

**Non-blocking:** Test 4 (skills preloading) should include a verification method. "Verify the agent receives review instructions without inlining" is vague. How do you verify this? By examining the agent's behavior (it follows the review methodology)? By checking logs? The verification method should be explicit.

**Non-blocking:** No test for the triage agent editing the wrong cdocs file (the layer-3 concern). Adding a test where haiku is asked to triage file A but also has file B visible would validate the prompt-scoping defense.

### Implementation Phases

The four phases (0-3 plus cleanup in Phase 4) are well-sequenced with appropriate success criteria.

**Blocking:** Phase 0 step 5 tests `skills` field but does not test `model` field behavior. The v1 Phase 0 validated `model: "haiku"` for Task tool invocations, but the v2 agent system uses `model: haiku` in YAML frontmatter, which is a different mechanism. Phase 0 should verify that the agent's model field actually selects haiku (vs. defaulting to the parent model).

**Non-blocking:** Phase 1 step 3 says "Refactor `skills/triage/SKILL.md` to thin dispatcher." This is the highest-risk step because it replaces working v1 behavior with v2 orchestration. If Phase 0 succeeds but Phase 1 introduces bugs, there is no rollback path described. Consider: keep the v1 skill content in a NOTE block or a separate file until Phase 3 validates end-to-end behavior, then remove it in Phase 4 cleanup.

**Non-blocking:** Phase 2 depends on Phase 1 (needs the triage agent working before the reviewer agent can be tested in the dispatch flow). Phase 2 can be developed in parallel with Phase 1 at the agent level, but integration testing requires Phase 1 completion. The proposal does not call out this dependency explicitly.

## Underconsidered Scenarios

### 1. Plugin reinstallation disrupting agent state

The proposal mentions `plugin.json` updates and reinstallation in Phase 0. What happens to in-flight agent invocations during reinstallation? If the user reinstalls the plugin while a triage agent is running, does the agent lose its hook enforcement? This is probably an edge case of plugin lifecycle management that is outside this proposal's scope, but it is worth noting.

### 2. Concurrent triage and review agents

The dispatcher invokes triage, then (on `[REVIEW]` recommendation) invokes the reviewer. Both agents have Edit access scoped to cdocs paths. If triage is re-invoked (e.g., on a different file) while the reviewer is still running, both agents could Edit the same file concurrently. The proposal's agent isolation (separate processes) prevents context interference but does not prevent file-level race conditions.

### 3. Hook enforcement on tool allowlist violations

The proposal says the tool allowlist is "enforced at infrastructure level." If a triage agent (tools: Read, Glob, Grep, Edit) somehow attempts to call Write, is the tool call silently dropped, or does the agent receive an error? The agent's behavior on receiving a tool-call rejection should be documented, as it affects prompt design (the agent prompt should not include Write-related instructions that would confuse haiku).

### 4. Frontmatter spec drift

The triage agent reads `frontmatter-spec.md` at runtime. If the spec adds new required fields, the triage agent will start flagging all existing documents as missing those fields. This is correct behavior, but it could cause a flood of mechanical edits across many files. The proposal should consider whether batch triage (across all cdocs files) should have a rate limit or require user confirmation before applying widespread changes.

## Verdict

**Revise.** The architecture is sound and addresses the v1 problems at the right level of abstraction. The core insight (infrastructure-enforced tool restrictions via hooks instead of prompt-based restrictions) is correct. However, several blocking issues need resolution:

1. The platform affordances are described as established fact rather than hypotheses pending Phase 0 validation.
2. The hook script has gaps (empty path handling, jq failure mode, path traversal).
3. The mechanical/semantic split mischaracterizes tag analysis as "deterministic."
4. The blast radius of layer-3 failure (wrong cdocs file) is understated.
5. The test plan lacks hook robustness testing and model-field validation.

None of these are architectural: the design is fundamentally right. They are specification-level issues that should be tightened before implementation.

## Action Items

1. [blocking] Add explicit caveats to the "Claude Code agent system" background section acknowledging that the described affordances are expected behavior pending Phase 0 validation. List specific verification targets: agent-scoped PreToolUse hooks, `skills` field content injection, `${CLAUDE_PLUGIN_ROOT}` expansion in agent hook definitions, `model` field selection.
2. [blocking] Tighten the hook script: change empty `$FILE_PATH` from exit 0 (allow) to exit 2 (block). Document expected behavior for exit code 1 (script failure). Consider anchoring the regex or normalizing paths.
3. [blocking] Revise the mechanical/semantic split definition. Either narrow "mechanical" to exclude tag analysis (tags become recommendations), or explicitly document that tag edits involve low-stakes judgment and characterize the failure mode (wrong tag on right file, low severity, easily reverted via git).
4. [blocking] Add post-triage verification to the dispatcher flow: after the triage agent completes, the dispatcher runs `git diff` (or re-reads modified files) to confirm only the expected files were changed. Promote this from optional ("can also re-read") to required.
5. [blocking] Add Phase 0 validation of `model` field in agent frontmatter (verify haiku is actually selected, not the parent model).
6. [blocking] Add a hook robustness test case: invoke the hook script directly with edge-case inputs (empty stdin, malformed JSON, absolute paths, path traversal patterns) and verify correct exit codes.
7. [non-blocking] Revise edge case 1 (registration failure) to specify the concrete fallback: does the skill detect missing agents and revert to v1 inline prompt behavior, or does it fail explicitly?
8. [non-blocking] Revise edge case 3 blast radius characterization to acknowledge that v1 evidence showed status modifications (not just tag additions) when haiku edited wrong files. Consider passing allowed file paths to the hook as an environment variable for per-invocation scoping.
9. [non-blocking] Add a test case for triage agent editing wrong cdocs files (layer-3 failure scenario).
10. [non-blocking] Document expected agent behavior when a tool-call is rejected by the allowlist (silent drop vs. error message to agent).
11. [non-blocking] Consider a rollback strategy for Phase 1: preserve v1 skill content until Phase 3 end-to-end validation succeeds.
