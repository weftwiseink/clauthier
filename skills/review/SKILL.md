---
name: review
description: Review a CDocs document with structured findings and a verdict
argument-hint: "<path_to_document>"
allowed-tools: Read, Write, Edit, Glob, Grep
---

# CDocs Review

Conduct a structured review of a CDocs document.

This is a **deliverable skill** -- the user explicitly requests a review.
Reviews evaluate a document's quality, correctness, and completeness, producing findings and a verdict.

## Invocation

1. `$ARGUMENTS` must provide the path to the document to review (e.g., `cdocs/proposals/2026-01-29_topic.md`).
   If missing, prompt the user for the path.
2. Read the target document fully.
3. Determine today's date.
4. Create `cdocs/reviews/YYYY-MM-DD_review_of_{doc_name}.md` using the template below.
5. After writing the review, update the target document's `last_reviewed` frontmatter field.
6. If `cdocs/reviews/` doesn't exist, suggest running `/cdocs:init` first.

## Template

Use the template in `template.md` alongside this skill file.
Fill in:
- `review_of` with the target document path from repo root.
- `first_authored.by` with the current model name or `@username`.
- `first_authored.at` with the current timestamp including timezone.
- `task_list` with the relevant workstream path.
- `type: review`, `state: live`, `status: wip` (set to `done` on completion).
- Tags: always include one of `self`, `fresh` (self = same author, fresh = different author). Add `architecture`, `runtime_validated`, `ui_validated` as applicable.

## Required Sections

### Summary Assessment
2-4 sentences covering:
- What the document is trying to accomplish.
- Overall quality assessment.
- The most important finding(s).
- The verdict (see below).

### Section-by-Section Findings
Evaluate each major section of the target document.
For each finding:
- Reference the specific section or content.
- State the issue clearly.
- Categorize as **blocking** (must fix before acceptance) or **non-blocking** (suggestion/improvement).
- Provide reasoning, not just the verdict.
- When rejecting an approach, suggest an alternative.

### Verdict
One of:
- **Accept** -- Approve as-is. Minor non-blocking suggestions may be noted.
- **Revise** -- Requires changes before acceptance. All blocking issues must be resolved. Specify what must change.
- **Reject** -- Fundamentally flawed. Major rework or abandonment needed. Explain why.

### Action Items
Numbered list of specific tasks:

```
1. [blocking] Reclassify devlog skill as infrastructure, not deliverable.
2. [blocking] Add distribution/installation section.
3. [non-blocking] Consider adding scaling note to status skill.
```

Each action item should be specific enough to act on without re-reading the full review.

## Multi-Round Reviews

For subsequent review rounds:
- Read the previous review(s) to understand prior findings.
- Note which prior action items have been addressed.
- Focus on changes since the last round and any new issues.
- Update the round number in the target's `last_reviewed.round`.
- If all blocking issues are resolved, verdict should shift toward Accept.

## Updating the Target Document

After completing the review, update the target document's frontmatter:

```yaml
last_reviewed:
  status: revision_requested | accepted | rejected
  by: "@reviewer_model_or_username"
  at: TIMESTAMP
  round: N
```

Map verdict to status:
- Accept -> `accepted`
- Revise -> `revision_requested`
- Reject -> `rejected`

## What Makes a Good Review

- Reference specific sections/content, not vague impressions.
- Explain the reasoning behind concerns.
- Distinguish blocking from non-blocking issues.
- Check for internal consistency across sections.
- Verify claims against available evidence.
- Consider maintainability and future impact.
- Suggest alternatives when rejecting approaches.
- Be critical but constructive.
