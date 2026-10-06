---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-10-05T14:30:00-07:00
task_list: cdocs/post-compaction-resumption-reliability
type: proposal
state: live
status: request_for_proposal
tags: [rules, resumption, compaction, chat_record, testing, future_work, blocked]
---

# Post-Compaction Resumption Reliability

> BLUF(@claude-sonnet-5/cdocs/post-compaction-resumption-reliability): Lead models don't reliably follow chat-record Pillar 2's post-compaction resumption step 3 (re-read the record tail and the devlog's Scratchpoint/handoff before acting). Re-test with realistic opus-class lead models, deferred until the base rules context is decomposed and decluttered.
> Motivated By: `cdocs/proposals/2026-09-22-chat-record-devlog-management.md`, `cdocs/reviews/2026-10-05-review-of-chat-record-impl-1b-r1.md`, and the rules-decomposition follow-up.

## Objective

Make a lead model reliably execute Pillar 2's `### Resumption` step 3 after a `/compact` boundary: re-read the chat record's tail and the current devlog's `## Scratchpoint`/latest handoff before resuming work, even when the harness's own compaction summary says to "resume directly... as if the break never happened."

## Context

Phase 1b's `rules_check` scenario (`cdocs/devlogs/2026-10-05-chat-record-devlog-management-iterate.md`, "Implementation Notes (impl-2, Phase 1b)") found step 3 unreliable across tiers:

| model | first post-compaction calls | step 3 |
|---|---|---|
| haiku | edits file directly | not followed |
| sonnet | writes file directly | not followed |
| opus | checks record path and tails it | record tailed, but Scratchpoint/handoff not re-read |

The follow-up review (`cdocs/reviews/2026-10-05-review-of-chat-record-impl-1b-r1.md`, item 4) diagnosed this as salience, not retention: the per-turn rule survives compaction, but step 3 sits ~345 lines into a ~60KB materialized `.claude/rules/cdocs.md`, competing against the harness's compaction summary and a concrete next-step prompt. A small A/B there (haiku/sonnet only) found a short block placed outside the bulk rules file (beside the `CLAUDE.md` import line) gave a directional gain over rewording step 3 in place; a copy at the top of the rules file was weaker.

## Maintainer Direction (2026-10-05)

- The haiku/sonnet A/B results are not representative of the target use (opus-class leads). Any re-test must use realistic lead models.
- Defer until the base rules context — currently far too cluttered — is cleaned up and decomposed. `orchestration-discipline.md` alone is ~27KB, and `/cdocs:init` inlines all six rule files.
- Compaction involvement stays rules-side; the `SessionStart(compact)` pointer hook floated as an alternative is not adopted.

## Scope

The full proposal should explore:

- **Placement.** Where should the resumption cue live: a short block in the project `CLAUDE.md` beside the `@.claude/rules/cdocs.md` import line (the reviewer's A/B gave a directional gain here), the top of the rules file itself, a reworded step 3 in place, or some combination?
- **Dependency on rules decomposition.** How much of the salience problem is placement/wording versus sheer file size? Does decomposing `orchestration-discipline.md` and/or un-inlining init's six-file concatenation change the result independent of any resumption-specific fix?
- **Test protocol.** What's the right evaluation: realistic lead models (opus-class) only, minimum 3 runs per arm, majority-rate (not pass/fail) as the criterion, and a check that requires an actual devlog read (`Read`/`cat`/`sed`/`head` on the path) rather than a `grep -l` lookup counting as a read.
- **Resumption A/B (gates the chat-record proposal's Phase 3).** On three real workstreams with a `/compact` forced between handoffs, arm 1 resumes with step 3 removed from the rules and arm 2 with step 3 present; a fresh reviewer scores each resumption on correct next action, no re-litigated decision, and no redundant re-read. Pass: arm 2 wins or ties arm 1 on all three.
- **Acceptance bar.** What counts as "good enough" for step 3 reliability — a majority rate across runs, or something stricter given this governs correctness of resumed work?

## Open Questions

- Should this proposal wait to be scoped until the rules-decomposition follow-up has a committed plan, or can placement options be explored independent of file size?
- Is a single shared mechanism (one resumption cue) sufficient, or does each consuming project's `CLAUDE.md` need its own copy with drift risk?
- Does the 300-ish-byte budget that worked for the chat-record block text apply here too, or does a resumption cue need more room to state the "even when the summary says otherwise" caveat clearly?
