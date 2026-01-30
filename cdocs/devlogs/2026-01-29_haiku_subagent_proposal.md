---
first_authored:
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-29T12:00:00-08:00
task_list: cdocs/haiku_subagent
type: devlog
state: live
status: done
tags: [architecture, claude_skills, workflow_automation, frontmatter, plugin, design]
---

# Haiku Subagent for Workflow Automation: Devlog

## Objective

Author a proposal exploring options for adding a haiku-model subagent to the cdocs workflow.
The subagent would run at the end of agent turns to maintain frontmatter, update tags, and recommend workflow actions (auto-review, auto-revision).
Dogfood the concept by running subagents at the end of this session.

## Plan

1. Read and understand the full codebase: plugin structure, skills, frontmatter spec, workflow patterns.
2. Identify the design space: where the haiku agent fits, what it does, how it communicates.
3. Explore options for each concern (frontmatter maintenance, workflow recommendations, auto-review, auto-revision, context management).
4. Write the proposal with recommendations.
5. Dogfood: run a haiku subagent at the end to demonstrate the concept.

## Testing Approach

Manual verification: does the proposal cover all the user's requirements?
Dogfooding: does the haiku subagent pattern work in practice when run at end of session?

## Implementation Notes

### Codebase exploration

Read all 6 skills, 3 rules, hooks, existing proposals/reviews/devlogs, and templates.
Key insight: the plugin already has a well-defined document lifecycle (wip -> review_ready -> reviewed -> done) but transitions are manual.
The haiku subagent would automate the "bookkeeping" layer while keeping substantive decisions (accept/revise/reject) with opus-class agents.

### Design space

Three distinct concerns emerged:
1. **Frontmatter maintenance** (tags, status, timestamps): mechanical, haiku-appropriate.
2. **Workflow recommendations** (what skill to invoke next): requires reading document state, haiku-appropriate for triage.
3. **Workflow execution** (actually running reviews/revisions): requires deep reasoning, opus-appropriate.

The key architectural question: is this a hook, a skill, a rule, or a workflow pattern?
Hooks can't spawn agents (shell commands only).
Skills are explicitly invoked.
Rules guide behavior but don't execute.
A new workflow pattern codifying "end-of-turn triage" seems like the right fit, with a potential skill as the interface.

### Dogfooding results

Ran both subagent patterns at end of session to demonstrate the concept:

**Haiku triage subagent** (model: haiku):
- Triaged both cdocs files (proposal + devlog).
- Updated tags on both files: added `frontmatter`, `hooks`, `workflow`, `automation` to proposal; added `frontmatter`, `plugin`, `design` to devlog.
- Correctly identified both as `review_ready` and recommended `[REVIEW]` for each.
- Did not attempt status transitions (as instructed).
- Executed in sub-second time, validating the "cheap and fast" premise.

**Opus review subagent** (model: opus):
- Wrote a thorough 222-line review of the proposal.
- Verdict: Revise. 3 blocking issues, 6 non-blocking suggestions.
- Key blocking concerns: haiku YAML editing reliability, missing prompt template, overstated hook safety net.
- Updated the proposal's `last_reviewed` frontmatter to `revision_requested`, round 1.

**Observations:**
- The two-subagent pattern works mechanically: haiku for triage, opus for review.
- Haiku successfully read files and made Edit calls to tags without corrupting YAML, but this was a single test, not a reliability proof.
- The opus review was high-quality and identified real architectural concerns.
- Edge Case 4 (subagents lack plugin context) was visible: both subagents needed skill instructions inlined into their prompts.
- The triage -> review pipeline executed correctly as parallel tasks, demonstrating the dispatch pattern.

WARN(mjr/cdocs/haiku-subagent): The review's blocking concern about haiku YAML editing reliability is well-founded.
The dogfood test succeeded, but N=1 is not a reliability proof.
A recommendation-only mode for triage (no direct edits) may be the safer default.

### Revision and round 2 review

Revised the proposal to address all 3 blocking issues:
1. Redesigned triage as recommendation-only (no direct edits). This eliminates the YAML editing reliability risk entirely.
2. Added Appendix A with the complete haiku agent prompt template.
3. Corrected Decision 3 to accurately characterize the PostToolUse hook's limitations. Added TODO for future utility script.

Also addressed all 6 non-blocking items: defined "end of turn", added `[ESCALATE]` to workflow table, added Phase 0, specified devlog completeness signals, added recommendation accuracy test, added Phase 6 for documentation updates.

**Dogfooding discovery:** haiku triage in round 2 recommended `[REVISE]` on the proposal even though revisions were already applied (`status: review_ready`).
Root cause: the triage logic didn't distinguish between "revision needed" (`status: wip` + `revision_requested`) and "revision done, ready for re-review" (`status: review_ready` + `revision_requested`).
Fixed in the proposal by splitting the workflow state rules.
This is a genuine edge case that wouldn't have surfaced without dogfooding.

**Round 2 opus review:** Accept. All blocking issues resolved. 3 minor non-blocking suggestions for implementation (degenerate-case handling, backlog tracking for utility script, recommendation-only contract test).

### Status vocabulary and implement skill

The proposal lifecycle uses `implementation_ready` (design accepted, ready to build) and `implementation_accepted` (implementation completed and accepted).
The `/cdoc:implement` skill lists `implementation_ready` proposals and primes the implementor with conventions: frequent commits, devlog maintenance, cdoc skill usage, deviation tracking.

> NOTE(mjr/cdocs/haiku-subagent): These status values and the implement skill were added alongside this proposal work.
> They apply to the broader frontmatter spec, not just the triage system.

## Changes Made

| File | Description |
|------|-------------|
| `cdocs/proposals/2026-01-29_haiku_subagent_workflow_automation.md` | Proposal document |
| `cdocs/devlogs/2026-01-29_haiku_subagent_proposal.md` | This devlog |
| `cdocs/reviews/2026-01-29_review_of_haiku_subagent_workflow_automation.md` | Review by opus subagent |
| `skills/implement/SKILL.md` | New implement skill |
| `rules/frontmatter_spec.md` | Added `implementation_ready`, `request_for_proposal`, `implementation_accepted` statuses |
| `rules/writing_conventions.md` | Added mermaid over ASCII convention |
| `skills/status/SKILL.md` | Updated status filter values |
| `cdocs_plan.md` | Updated status vocabulary |
| `cdocs/proposals/2026-01-29_nit_fix_skill.md` | RFP stub for nit_fix skill |

## Verification

Proposal written with all required sections, reviewed by author checklist.
Dogfooding executed across two full cycles:
- **Round 1:** haiku triage (tag updates + `[REVIEW]` recommendation) -> opus review (Revise, 3 blocking issues).
- **Revision:** addressed all 3 blocking + 6 non-blocking issues. Discovered and fixed triage state logic edge case.
- **Round 2:** haiku triage (correct analysis, surfaced the REVISE/REVIEW distinction bug) -> opus review (Accept, 3 minor non-blocking suggestions).

Proposal accepted at round 2. Full triage -> review -> revise -> re-review cycle demonstrated end-to-end.
