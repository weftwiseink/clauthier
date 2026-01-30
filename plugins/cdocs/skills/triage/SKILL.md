---
name: triage
description: Triage cdocs documents for frontmatter maintenance and workflow recommendations
argument-hint: "[file1.md file2.md ...]"
---

# CDocs Triage

Run a read-only haiku subagent to analyze cdocs frontmatter and recommend changes and workflow actions.

**Usage:** Auto-invoked at the end of agent turns that created or modified cdocs documents.
The user can also invoke it directly.
The most common entry point is auto-invocation after substantive cdocs work.

## Invocation

### With file paths
```
/cdocs:triage cdocs/proposals/2026-01-29-topic.md cdocs/devlogs/2026-01-29-topic.md
```
Triage the specified files.

### Without arguments
```
/cdocs:triage
```
Scan for cdocs files modified in the current turn (based on recent Write/Edit operations on `cdocs/**/*.md` paths). If none found, prompt the user for paths or suggest running `/cdocs:status` to find documents.

## Behavior

1. **Collect file paths**: from `$ARGUMENTS` or from recent cdocs modifications in the current turn.
2. **Spawn haiku subagent**: use the Task tool with `model: "haiku"` and `subagent_type: "general-purpose"`, passing the triage prompt (see below).
3. **Receive triage report**: the subagent returns a read-only analysis with field, status, and workflow recommendations.
4. **Apply recommendations**: the top-level agent reviews the report, applies field/status changes via Edit, and dispatches workflow actions.

## Triage Subagent Prompt

Pass the following prompt to a haiku Task subagent, replacing `$FILES` with the newline-separated list of absolute file paths to triage.

```
You are a CDocs triage subagent. Your job is to analyze cdocs frontmatter and
recommend changes and workflow actions.

CRITICAL: You are READ-ONLY. Do NOT use the Edit tool or Write tool. Do NOT
modify any files. Your only job is to read files and produce a report.
All edits will be applied by the top-level agent based on your recommendations.

## Files to triage

$FILES

## Your tasks

For each file:
1. Read the file completely using the Read tool. If frontmatter is missing or
   unparseable, report the file as "frontmatter missing or malformed" and skip
   further analysis.
2. Check frontmatter fields against the CDocs frontmatter spec:
   - Required: first_authored (by, at), task_list, type, state, status, tags
   - Reviews also require: review_of
   - Non-reviews may have: last_reviewed (status, by, at, round)
   - If required fields are missing, recommend adding them with sensible defaults.
3. Analyze tags: scan document headings and content for topic keywords.
   Compare to existing tags. Recommend adding missing tags, removing stale tags.
   Be conservative: only recommend tag changes clearly supported by document content.
4. Analyze status (check for completeness signals):
   - Proposals: all template sections filled, BLUF present and consistent with content.
   - Devlogs: verification section non-empty with concrete evidence (pasted output, results).
   - Reports: BLUF present, key findings and analysis sections filled.
   - Reviews: all sections filled, verdict present.
   - If document appears complete and status is wip, recommend review_ready.
   - If unsure, do NOT recommend a status change.
5. Check workflow state:
   - status: review_ready + no last_reviewed -> [REVIEW] (first review)
   - status: review_ready + last_reviewed.status: revision_requested -> [REVIEW]
     (re-review: author marked revised doc ready)
   - status: wip + last_reviewed.status: revision_requested -> [REVISE]
     (revision not yet started)
   - last_reviewed.status: accepted + type proposal + status not implementation_ready
     -> [STATUS] (recommend implementation_ready)
   - last_reviewed.status: accepted + type not proposal + status not done
     -> [STATUS] (recommend done)
   - last_reviewed.round >= 3 + still revision_requested -> [ESCALATE]
   - Otherwise -> [NONE]

NOTE: The distinction between [REVISE] and [REVIEW] hinges on the status field.
If status is review_ready, the author has declared the revision complete.
If status is still wip with revision_requested, the revision hasn't started.

## Output format

Return EXACTLY this structure:

TRIAGE REPORT
=============
Files triaged: N

FIELD RECOMMENDATIONS:
- <path>:
  tags: add [x, y], remove [z] (or "no change")
  missing fields: <list of missing required fields and suggested values> (or "none")
  timestamps: <issues found> (or "valid")

STATUS RECOMMENDATIONS:
- <path>:
  status: recommend X -> Y (reason) (or "no change")

WORKFLOW RECOMMENDATIONS:
- [ACTION] <path>: <explanation>

Be precise. Use repo-root-relative paths. Do not editorialize.
Do NOT use Edit or Write tools. ONLY use Read tool and return your report.
```

## Acting on the Triage Report

After receiving the triage report, the top-level agent should:

### Field Recommendations
For each file, the report lists recommended tag changes, missing fields, and timestamp issues.
The top-level agent applies sensible recommendations via Edit (add missing tags, fix timestamps, add missing required fields).

### Status Recommendations
For each status transition recommendation, the top-level agent decides whether to apply it:
- If the recommendation is sensible, update the document's frontmatter via Edit.
- If unsure, defer or ask the user.

### Workflow Recommendations

| Recommendation | Action | Agent |
|----------------|--------|-------|
| `[REVIEW]` | Spawn a review subagent (opus or sonnet via Task tool). Pass the review skill instructions and document path. | Opus/Sonnet subagent |
| `[REVISE]` | Read the review's action items, revise the document inline. | Top-level agent (has authoring context) |
| `[ESCALATE]` | Report to the user with options. Review round >= 3 without acceptance indicates the loop needs human judgment. | Top-level agent presents options |
| `[STATUS]` | Apply the recommended frontmatter status update directly. | Top-level agent |
| `[NONE]` | No action needed. | - |

### Review Dispatch Details

When acting on a `[REVIEW]` recommendation:
1. Spawn an opus or sonnet subagent via the Task tool.
2. Include in the subagent prompt:
   - The path to the document to review.
   - The full review skill instructions (inlined from `skills/review/SKILL.md`).
   - The frontmatter spec (inlined from `rules/frontmatter-spec.md`).
   - The writing conventions (inlined from `rules/writing-conventions.md`).
3. The subagent writes the review to `cdocs/reviews/`.
4. The subagent updates the target document's `last_reviewed` frontmatter.
5. After the review subagent completes, run triage again on the review output to validate its frontmatter.
6. Report the review verdict to the user.

> NOTE(mjr/cdocs/haiku-subagent): The review subagent should consider if clarification is needed from the user.
> If the subagent can request user input, it should get clarification right then.
> Otherwise, it should surface to its invoker that clarification is needed, with suggested multi-choice options for the user.

### Revision Dispatch Details

When acting on a `[REVISE]` recommendation:
1. Read the review document to find the action items.
2. Address each blocking action item in the original document.
3. Update non-blocking items where practical.
4. Update the document's `status` to `review_ready` after revision.
5. Run triage again to trigger re-review.

### Escalation Details

When acting on an `[ESCALATE]` recommendation:
1. Summarize the review history (rounds, key blocking issues).
2. Present options to the user:
   - Continue revising (another round).
   - Accept as-is despite open issues.
   - Defer or archive the document.
   - Start fresh with a new approach.

## When to Invoke Triage

Triage should run at the **end of agent turns** that involved substantive cdocs work:
- After creating a new cdocs document (devlog, proposal, review, report).
- After significant edits to an existing cdocs document.
- After completing a revision cycle.

Triage should **not** run:
- After trivial edits (typo fixes, formatting-only changes).
- Mid-authoring (while still writing a document).
- On non-cdocs files.

## Context Management

If the current session has already performed multiple major tasks (authoring + review + revision), triage may recommend deferring further workflow actions to a fresh session. This is a heuristic, not a hard rule. Claude Code's automatic compaction handles the mechanical concern; the deeper question is whether the agent has enough fresh perspective for quality revisions.
