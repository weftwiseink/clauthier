---
first_authored:
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-29T12:00:00-08:00
last_reviewed:
  status: accepted
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-29T13:00:00-08:00
  round: 2
task_list: cdocs/haiku_subagent
type: proposal
state: live
status: result_accepted
tags: [architecture, workflow_automation, claude_skills, subagent_patterns]
---

# Haiku Subagent for Frontmatter Maintenance and Workflow Automation

> BLUF(mjr/cdocs/haiku-subagent): Add a lightweight haiku subagent as an end-of-turn triage step that analyzes cdocs frontmatter/tags and recommends updates and workflow continuations (auto-review, auto-revision).
> Triage is recommendation-only: it reads documents and returns a structured report, but does not make direct edits.
> The top-level agent applies recommended frontmatter changes and dispatches workflow actions (opus for reviews, inline for revisions).
> A future utility script can handle structured YAML mutations for machine-oriented correctness.
> The approach is a new `/cdoc:triage` skill backed by a haiku-model Task subagent, codified as a workflow pattern in `rules/workflow_patterns.md`.

## Objective

CDocs documents have a well-defined lifecycle (wip -> review_ready -> reviewed -> done) with frontmatter tracking state transitions, review status, and tags.
Currently, all of this bookkeeping is manual: the authoring agent must remember to update frontmatter, mark documents as review_ready, notice when reviews request revisions, and invoke the appropriate next skill.

This proposal explores adding a lightweight haiku-model subagent that runs at the end of agent turns to:
1. Maintain frontmatter accuracy (status, tags, timestamps).
2. Recommend which cdoc skill should be invoked next based on document state.
3. Enable automated workflow continuations: review_ready docs get reviewed, revision_requested docs get revised.

## Background

### Current state

- **Frontmatter spec** (`rules/frontmatter_spec.md`): defines required fields, valid values, status transitions.
- **PostToolUse hook** (`hooks/cdocs_validate_frontmatter.sh`): validates field presence after Write/Edit, but only checks existence, not semantic correctness.
- **Skills**: devlog, propose, review, report, status, init. Each operates independently.
- **Workflow patterns** (`rules/workflow_patterns.md`): parallel agents and subagent-driven development patterns. No end-of-turn triage pattern exists.

### What's missing

- No automated frontmatter updates (status transitions lag behind actual document state).
- No mechanism to detect "this document is done, trigger a review."
- No mechanism to detect "this review requests revisions, start revising."
- Tags often reflect initial creation context but aren't updated as content evolves.
- The review skill suggests Claude "may suggest a review when a document reaches review_ready" but there's no systematic trigger.

### Claude Code constraints

- **Hooks** run shell commands, not agent invocations. A hook cannot spawn a haiku Task subagent.
- **Task tool** supports `model: "haiku"` for cheap/fast subagents.
- **Context window** is managed by automatic compaction. Agents don't have programmatic access to context utilization percentage.
- **Skills** are loaded as prompts, not as executable code. A skill instructs the agent what to do, but the agent must choose to follow it. A skill cannot programmatically invoke another skill; inter-skill dispatch relies on the top-level agent's judgment.

## Proposed Solution

### Architecture: three-layer design

```
Layer 1: Triage (haiku subagent) - READ-ONLY
  - Reads modified cdocs files
  - Analyzes frontmatter correctness (tags, status, timestamps)
  - Returns structured recommendations (no direct edits)

Layer 2: Dispatch (top-level agent)
  - Receives triage recommendations
  - Applies frontmatter updates recommended by triage
  - Decides whether to act on workflow recommendations
  - Spawns appropriate agents or invokes skills

Layer 3: Execution (opus subagent or top-level agent)
  - Reviews (opus subagent via Task tool)
  - Revisions (top-level agent, needs full context)
  - Status updates (top-level agent, quick edits)
```

### The triage subagent

A haiku-model Task subagent invoked at the end of substantive work on cdocs documents.
Triage is read-only: it analyzes documents and returns recommendations, but does not make direct edits.
The top-level agent applies any recommended changes.

**Invocation:** the top-level agent spawns a haiku Task subagent after completing substantive cdocs work.
"End of turn" means: after the agent finishes responding to a user message that involved creating or modifying cdocs documents.
Triage is not invoked mid-authoring or after trivial edits (typo fixes, formatting).

**Inputs (via prompt):**
- List of cdocs file paths created or modified in the current turn (absolute from repo root).
- The triage prompt template (see Appendix A).

**Responsibilities:**
1. **Frontmatter analysis**: read each file, check that `status`, `state`, `tags`, and `last_reviewed` fields are present and reflect actual document content. Report discrepancies.
2. **Tag recommendations**: scan document headings and content for topic keywords, compare to existing tags. Recommend additions/removals.
3. **Status transition detection**: if a document appears complete but status is still `wip`, recommend updating to `review_ready`. Completeness signals: all template sections filled, verification section with evidence (for devlogs), BLUF present and consistent with content (for proposals/reports).
4. **Workflow recommendations**: return a structured list of recommended next actions based on document state.

**Output format** (returned to top-level agent):

```
TRIAGE REPORT
=============
Files triaged: N

FRONTMATTER RECOMMENDATIONS:
- cdocs/proposals/2026-01-29_foo.md:
  tags: add [hooks, workflow], remove [future_work]
  status: recommend wip -> review_ready (all sections filled, BLUF present)
- cdocs/devlogs/2026-01-29_bar.md:
  tags: no changes needed
  status: no change (verification section empty)

WORKFLOW RECOMMENDATIONS:
- [REVIEW] cdocs/proposals/2026-01-29_foo.md is review_ready. Recommend: spawn opus review subagent.
- [REVISE] cdocs/proposals/2026-01-28_bar.md has revision_requested (round 1). Recommend: top-level agent revises inline.
- [ESCALATE] cdocs/proposals/2026-01-27_baz.md has revision_requested (round 3). Recommend: escalate to user.
- [NONE] cdocs/devlogs/2026-01-29_qux.md: no action needed.
```

### Workflow continuations

Based on triage recommendations, the top-level agent dispatches:

| Recommendation | Action | Agent |
|----------------|--------|-------|
| `[REVIEW]` review_ready doc | Invoke review skill | Opus subagent (Task tool, model: opus or sonnet) |
| `[REVISE]` revision_requested doc | Revise inline per review action items | Top-level agent (needs authoring context) |
| `[ESCALATE]` round >= 3, still revision_requested | Report to user for decision | Top-level agent (presents options) |
| `[STATUS]` status update needed | Update frontmatter | Top-level agent (quick edit) |
| `[NONE]` | No action | - |

### Auto-review flow

When triage detects a `review_ready` proposal or devlog:
1. Triage returns `[REVIEW]` recommendation with document path.
2. Top-level agent spawns an opus (or sonnet) subagent via Task tool.
3. Subagent reads the document and the review skill instructions, writes the review.
4. Triage runs again on the review output to validate review frontmatter.
5. Top-level agent reports the review verdict to the user.

### Auto-revision flow

When triage detects a document with `last_reviewed.status: revision_requested`:
1. Triage returns `[REVISE]` recommendation with document path and review path.
2. Top-level agent reads the review's action items.
3. Top-level agent revises the document inline (it has the authoring context).
4. Top-level agent updates `status: review_ready` for re-review.
5. If context is heavy, the user may want to compact first. Since agents can't programmatically check context utilization, this is a user decision or a heuristic based on turn count.

NOTE(mjr/cdocs/haiku-subagent): The user suggested compaction when context > 50%.
Claude Code's automatic compaction handles this transparently.
A practical heuristic: if the revision is the third or later major task in a session, suggest compaction or a fresh agent.

## Important Design Decisions

### Decision 1: Skill vs. rule vs. hook for the triage pattern

**Decision:** New `/cdoc:triage` skill + workflow pattern in `rules/workflow_patterns.md`.

**Why:** Hooks cannot spawn agents (shell-only).
A rule alone is advisory and easily forgotten.
A skill gives explicit invocability and discoverability, while the workflow pattern establishes the convention of "always triage at end of turn."
The skill contains the haiku subagent prompt; the rule establishes when to invoke it.

### Decision 2: Haiku for triage, opus for reviews

**Decision:** Use haiku for the triage/bookkeeping layer, opus (or sonnet) for review execution.

**Why:** Triage is mechanical: read frontmatter, compare to content, update fields, emit recommendations.
This doesn't require deep reasoning, just accurate pattern matching.
Reviews require critical analysis: evaluating proposal quality, finding gaps, making judgment calls.
Haiku keeps the triage step cheap and fast (sub-second), which matters if it runs at the end of every turn.

### Decision 3: Triage is recommendation-only (no direct edits)

**Decision:** The haiku triage agent analyzes documents and returns recommendations.
It does not make Edit calls.
The top-level agent applies recommended frontmatter changes.

**Why:** YAML frontmatter is whitespace-sensitive and structurally precise.
Haiku-class models are less reliable at structured editing than opus-class models.
A malformed Edit call could corrupt frontmatter, and the existing PostToolUse hook only validates field presence via regex, not YAML structural integrity.
By making triage recommendation-only, we eliminate this risk entirely.
The top-level agent (opus-class) is more reliable at applying structured edits and can validate recommendations before acting.

TODO(mjr/cdocs/haiku-subagent): A wrapping utility script (shell or Python) that accepts structured update instructions and applies them to YAML frontmatter would provide machine-oriented correctness for frontmatter mutations.
This is a natural future enhancement that would benefit both triage-applied updates and manual frontmatter maintenance.
It could be invoked via a hook or as a standalone tool.

### Decision 4: Structured text output, not JSON

**Decision:** Triage output uses structured plain text, not JSON.

**Why:** The consumer is the top-level Claude agent, not a program.
Structured text is easier for the agent to parse and act on.
JSON adds formality without benefit since the agent interprets natural language natively.

### Decision 5: Revisions stay with the top-level agent

**Decision:** Auto-revision is performed by the top-level agent, not a subagent.

**Why:** The authoring agent has the full context of what was written and why.
A fresh subagent would need to reconstruct this context from the document alone, losing nuance.
Reviews, by contrast, benefit from a fresh perspective (a subagent hasn't seen the authoring process).

### Decision 6: Context management is heuristic, not programmatic

**Decision:** Use turn-count heuristics and user judgment for context management before revisions, rather than attempting to measure context utilization programmatically.

**Why:** Claude Code's context utilization is not exposed to the agent.
Automatic compaction handles the mechanical concern.
The deeper concern (whether the agent has "fresh enough" perspective for revisions) is better addressed by the user deciding whether to continue or start a fresh session.
A practical heuristic: if the revision is the Nth major task in a session, the triage agent can note this in its recommendations.

## Stories

### Story 1: Author finishes a proposal

Agent completes writing a proposal.
Triage haiku runs, reads the proposal, notices all sections are filled and BLUF is present.
Recommends `status: wip -> review_ready` and tag additions.
Top-level agent applies the frontmatter updates and acts on the `[REVIEW]` recommendation.
Top-level agent spawns opus review subagent.
Review is written, verdict returned.
If `revision_requested`: top-level agent revises, re-triages, re-reviews.
If `accepted`: top-level agent updates `status: done` or `result_accepted`.

### Story 2: Agent resumes work on a previously-reviewed proposal

Agent opens a proposal with `last_reviewed.status: revision_requested`.
Triage (or the top-level agent reading status) identifies the pending revision.
Top-level agent reads the review's action items, revises the proposal.
Triage runs, recommends `status: review_ready` for re-review.
Top-level agent applies the update, opus subagent writes round 2 review.

### Story 3: Devlog reaches natural completion

Agent finishes implementation work, devlog is updated with verification results.
Triage notices the devlog has a verification section with evidence (non-empty, contains pasted output or concrete results).
Recommends `status: wip -> review_ready`.
Returns `[REVIEW]` recommendation (devlog reviews evaluate work quality, not just doc quality).
Top-level agent decides whether to invoke review or defer.

### Story 4: Multiple documents modified in one turn

Agent modifies a proposal and its devlog.
Triage reads both, analyzes frontmatter on each independently.
Returns recommendations for each document (frontmatter updates + workflow actions).
Top-level agent applies frontmatter updates, batches workflow actions or prioritizes.

## Edge Cases / Challenging Scenarios

### 1. Haiku misjudges document completeness

Risk: haiku prematurely recommends a document as `review_ready` when the author intended to continue editing.

Mitigation: triage is recommendation-only (Decision 3).
The top-level agent (or user) reviews all recommendations before applying any frontmatter changes.
This includes both status transitions and tag updates.

### 2. Triage runs on partially-written documents

If triage runs mid-authoring (not end-of-turn), it might flag incomplete documents incorrectly.

Mitigation: triage is explicitly an end-of-turn operation.
The workflow pattern and skill instructions make this clear.

### 3. Conflicting triage recommendations

Triage recommends both reviewing and revising the same document (shouldn't happen with valid state, but could with corrupted frontmatter).

Mitigation: triage detects frontmatter inconsistencies, reports contradictions, and only recommends actions after flagging the issue.
The top-level agent resolves contradictions before acting on workflow recommendations.

### 4. Review subagent lacks plugin context

An opus review subagent spawned via Task doesn't automatically load the cdocs plugin's rules and skill instructions.

Mitigation: the triage prompt includes instructions to pass relevant skill content (review skill SKILL.md) to the review subagent's prompt.
Alternatively, the top-level agent invokes the review skill directly rather than spawning a subagent.

NOTE(mjr/cdocs/haiku-subagent): This is a real constraint of the Task tool.
Subagents don't inherit plugin context.
The practical solution is to inline the review skill instructions into the subagent prompt.

### 5. Infinite review-revision loop

A review requests revisions, revision triggers re-review, re-review requests more revisions, etc.

Mitigation: cap at 2-3 review rounds.
After round 3, triage recommends escalating to the user rather than continuing the loop.
The `last_reviewed.round` field tracks this.

### 6. Context budget for chained operations

Authoring + triage + review + revision in one session could consume significant context.

Mitigation: triage can recommend deferring review to a fresh session.
Heuristic: if this is already the second major task in the session, recommend deferring.

## Test Plan

1. **Manual triage invocation**: invoke `/cdoc:triage` on a known set of cdocs files, verify frontmatter updates and recommendations are correct.
2. **Auto-review flow**: write a proposal, run triage, verify it recommends review, spawn review subagent, verify review is written correctly.
3. **Auto-revision flow**: given a reviewed proposal with `revision_requested`, run triage, verify it recommends revision, revise, re-triage, verify status update.
4. **Tag maintenance**: create a document with missing/stale tags, run triage, verify tags are updated.
5. **Edge case: partial document**: run triage on a wip document with empty sections, verify it does NOT recommend review_ready.
6. **Edge case: round cap**: simulate 3 review rounds, verify triage recommends user escalation instead of round 4.
7. **Recommendation accuracy**: run triage across all existing cdocs (N documents), verify recommendations are sensible and conservative (no false review_ready recommendations on incomplete documents).

## Implementation Phases

### Phase 0: Validate Task tool model parameter

1. Verify that the Task tool's `model: "haiku"` parameter works as expected.
2. Confirm haiku subagents can read files via the Read tool and return structured text.
3. Document any limitations discovered.

NOTE(mjr/cdocs/haiku-subagent): This was validated during dogfooding of this proposal.
The Task tool's model parameter works correctly: haiku subagents can read files, analyze content, and return structured reports.

**Success criteria:** haiku Task subagent successfully reads cdocs files and returns structured output.

### Phase 1: Triage skill and workflow pattern

1. Create `skills/triage/SKILL.md` with the haiku subagent prompt template (Appendix A).
2. Add "End-of-Turn Triage" section to `rules/workflow_patterns.md`.
3. The skill instructs the top-level agent to spawn a haiku Task subagent with:
   - The list of modified cdocs file paths.
   - The prompt template from Appendix A.
4. The skill also instructs the top-level agent how to interpret and act on the triage report.

**Success criteria:** `/cdoc:triage` can be invoked, spawns a haiku agent, and returns a triage report.

### Phase 2: Frontmatter analysis logic

1. Refine the triage agent's analysis rules (iterated from Appendix A):
   - Tags: scan document headings and content for topic keywords, compare to existing tags.
   - Timestamps: verify `first_authored.at` is present and valid ISO 8601 with timezone.
   - Status: detect completeness signals per type (see Appendix A, step 4). Recommend transitions conservatively.
2. Test on existing cdocs in this repo: run triage against all documents, verify recommendations are sensible.

**Success criteria:** triage correctly identifies frontmatter issues and makes conservative, accurate recommendations.

### Phase 3: Workflow recommendation engine

1. Define recommendation rules:
   - `status: review_ready` + no `last_reviewed` -> `[REVIEW]` (first review)
   - `status: review_ready` + `last_reviewed.status: revision_requested` -> `[REVIEW]` (re-review)
   - `status: wip` + `last_reviewed.status: revision_requested` -> `[REVISE]` (revision needed)
   - `last_reviewed.status: accepted` + `status` not yet `done` -> `[STATUS]` (update to done/result_accepted)
   - `last_reviewed.round >= 3` + still `revision_requested` -> `[ESCALATE]`
2. Integrate into triage agent prompt.

**Success criteria:** triage returns correct recommendations for each document state.

### Phase 4: Review dispatch integration

1. Define how the top-level agent acts on `[REVIEW]` recommendations.
2. Write the review subagent prompt template (includes inlined review skill instructions).
3. Test end-to-end: author -> triage -> review -> triage -> report to user.

**Success criteria:** a review_ready document automatically gets reviewed when triage recommends it.

### Phase 5: Revision dispatch integration

1. Define how the top-level agent acts on `[REVISE]` recommendations.
2. The top-level agent reads the review action items and revises inline.
3. Test end-to-end: review with revision_requested -> triage -> revision -> triage -> re-review.
4. Implement round cap (3 rounds) and escalation.

**Success criteria:** revision_requested documents get revised and re-reviewed, with loop protection.

### Phase 6: CLAUDE.md and documentation updates

1. Add `/cdoc:triage` to the skills reference in CLAUDE.md.
2. Update README.md skill table.

**Success criteria:** triage is discoverable in project documentation.

## Appendix A: Haiku Triage Agent Prompt Template

This is the prompt passed to the haiku Task subagent.
The top-level agent fills in `$FILES` with the list of modified cdocs file paths.

```
You are a CDocs triage subagent. Your job is to analyze cdocs documents and return
a structured triage report. You do NOT make edits. You only read and recommend.

## Files to triage

$FILES

## Your tasks

For each file:
1. Read the file completely.
2. Check frontmatter fields against the CDocs frontmatter spec:
   - Required: first_authored (by, at), task_list, type, state, status, tags
   - Reviews also require: review_of
   - Non-reviews may have: last_reviewed (status, by, at, round)
3. Analyze tags: scan document headings and content for topic keywords.
   Compare to existing tags. Recommend additions (topics clearly present in content
   but missing from tags) and removals (tags with no corresponding content).
   Be conservative: only recommend changes clearly supported by document content.
4. Analyze status: check for completeness signals.
   - Proposals: all template sections filled, BLUF present and consistent with content.
   - Devlogs: verification section non-empty with concrete evidence (pasted output, results).
   - Reports: BLUF present, key findings and analysis sections filled.
   - If document appears complete and status is wip, recommend review_ready.
   - If unsure, do NOT recommend a status change.
5. Check workflow state:
   - status: review_ready + no last_reviewed -> [REVIEW] (first review)
   - status: review_ready + last_reviewed.status: revision_requested -> [REVIEW] (re-review: author marked revised doc ready)
   - status: wip + last_reviewed.status: revision_requested -> [REVISE] (revision not yet started)
   - last_reviewed.status: accepted + status not yet done -> [STATUS] (recommend done/result_accepted)
   - last_reviewed.round >= 3 + still revision_requested -> [ESCALATE]
   - Otherwise -> [NONE]

NOTE: The distinction between [REVISE] and [REVIEW] hinges on the status field.
If status is review_ready, the author has declared the revision complete.
If status is still wip with revision_requested, the revision hasn't started.
This subtlety was discovered during dogfooding: haiku triage recommended [REVISE]
on a proposal that had already been revised and marked review_ready.

## Output format

Return EXACTLY this structure:

TRIAGE REPORT
=============
Files triaged: N

FRONTMATTER RECOMMENDATIONS:
- <path>:
  fields: <missing or invalid fields, or "all present">
  tags: <add [x, y], remove [z], or "no changes needed">
  status: <recommend X -> Y (reason), or "no change">

WORKFLOW RECOMMENDATIONS:
- [ACTION] <path>: <explanation>

Be precise. Use repo-root-relative paths. Do not editorialize.
```
