---
review_of: cdocs/proposals/2026-09-22-chat-record-devlog-management.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T09:01:45-07:00
task_list: cdocs/chat-record-devlog-management
type: review
state: live
status: done
tags: [fresh_agent, implementation_review, phase_2, devlog_splitting, triage, runtime_validated]
---

# Review: Chat-Record Phase 2 Implementation (r1)

> BLUF(opus-5-5/cdocs/chat-record-devlog-management): **Revise.** The proposal asks for one fix.
> The "Splitting a devlog" section, `part_of`, status grouping, the Pillar 2 edit, and the A/B move are all sound and minimal.
> All four verification checks pass on an independent re-run.
> One major regression: triage step 6.1 skips chunks when locating a proposal's iterate devlog.
> A finished loop's `## Iteration Log` is exactly what moves into a chunk, so a split iterate devlog falls back to the blind heuristics.
> Those heuristics can emit a backward `[STATUS]`, which `/cdocs:triage` applies.

## Summary Assessment

Phase 2 (commits `cc7b808..6b63aaf`) adds devlog splitting at closed-concern boundaries, the `part_of` field with grouping in triage and status, and a split check at Pillar 2's handoff step.
It also moves the resumption A/B to the post-compaction RFP and expresses the split thresholds in words.
The skill text tracks the proposal closely, folds its two splitting edge cases in a few words, and adds nothing the maintainer would call over-specified.
The dry-run copies show the rules produce sensible chunks: 900-1,050 words each, with roots of 655 and 777 words.
The implementer added two triage changes beyond grouping. The completeness-check skip is fine.
The iterate-devlog skip breaks the log-state mapping for any iterate devlog split after its loop finishes.
Verdict: **Revise**, for that one line.

## Section-by-Section Findings

### 1. "Splitting a devlog" (`skills/devlog/SKILL.md`)

- Trigger, closed-concern test, cut and merge, naming, the Chunks table, chunk frontmatter, and the backlink all match the proposal's "Devlog splitting at closed-concern boundaries".
  The skill puts the backlink as the first line under the title, before the BLUF, which is the proposal's "first-line" placement.
- The limits are soft (`~1,500 words`, `~400 words`), and the `wc -w` hint makes them measurable without a script.
  At 22 lines, the section has no bans and no extra mechanism, so I see nothing the maintainer would cut.
- The proposal's two splitting edge cases appear as two clauses.
  The first is "No closed concern means no split: tighten prose instead".
  The second is "a live table whose finished rows moved points to their chunk".
  Dropping the 2,500-word number is right: a landed verification campaign already passes the closed-concern test.
- **Nit:** the merge rule does not say what happens when no adjacent chunk exists, as with a single closed concern under ~400 words.
  The natural reading is that it stays in the root.
  Leave this as is unless an agent misreads it.
- **Dry-run inspection.** The cuts follow the rules.
  The merges are the propose-revise record (~250 words) into the loop record, static verification (~260) into implementation, sandbox setup (~270) into runs, and QA (~280) into analysis.
  The open deferred verification stays in root A.
  The Deviations section stays in root B because it spans both chunks.
  The "read this when" column does the navigation work: the fresh scorer opened exactly the expected chunk for four questions and answered A3 and B3 from the roots.
  The validator passes all six files unchanged.
- **Nit (dry-run copies only):** splitting leaves in-root cross-references dangling.
  Root B's Deviations item 1 says "Documented in Pre-Flight Check Results above", but that section is now in `-runs`.
  If the copies are committed as a worked example, repoint it.
  This does not warrant a rule.
- **Observation:** both subjects were finished devlogs, so the mid-loop case is unexercised: a live table keeping a pointer to finished rows.
  The splitter also wrote the six questions.
  This is acceptable for the proposal's one-chunk bar, but the first real mid-loop split is the real test.

### 2. `part_of`, triage, and status

- `frontmatter-spec.md`: the template line and field definition are correct and short.
  The definition gives repo-root semantics, says chunks carry no `chat_record:`, names the grouping consumers, and points to the skill.
  The validator has no unknown-field check, so it needs no change, as the proposal requires.
- `skills/status/SKILL.md` step 6 groups after filtering, so "root not in the filtered results" is well defined.
  The `↳ ` prefix and the `(part_of <root>)` suffix are minimal.
- Triage field check: reporting an unresolved `part_of` without editing it is correct.
  Triage should not guess a root path.
- Triage report grouping: the one sentence is correct.
- **Chunks skip the completeness check (step 5): correct, cheap, keep it.**
  A loop-record chunk has no `## Verification`, so the devlog check would misfire.
  "Recommend `done` if it is not" gives triage something useful to do with a chunk.
- **Chunks skipped when locating the iterate devlog (step 6.1): MAJOR, incorrect as written.**
  The stated rationale is "a chunk holds only finished rows, and the root keeps the live tables".
  That holds only while the loop is live.
  Once an iterate loop accepts, its `## Iteration Log` no longer feeds a live table, so it is a closed concern and moves to a chunk.
  The implementer's own dry-run does this: root A has no Iteration Log, and `-loops` holds it.
  The current `iterate/template.md` uses an H2 `## Iteration Log`, so the chunk is the only file that both cites the proposal and carries the table.
  With chunks skipped, step 6 finds nothing and falls back to the blind step 7.
  Take a proposal at `implementation_accepted` (or `implementation_wip`) with `last_reviewed.status: accepted`.
  Step 7 emits `[STATUS] implementation_ready`, which moves the proposal backward.
  `skills/triage/SKILL.md:61` applies `[STATUS]` directly via Edit.
  For a proposal at `implementation_ready`, the matched log would give `[STATUS] implementation_accepted`, and the blind fallback gives `[NONE]` instead.
  The same fallback fires mid-loop if a split leaves the root's live table with no rows: step 6.5 treats an empty table as "loop never started".
  The open-loop `[NONE]` guard is then lost, and a `[REVIEW]` or `[REVISE]` can land on a document the loop owns.
  Dropping the skip is also wrong.
  A root and a chunk would both qualify, and with a shared filename date and `first_authored.at`, step 6.4 flags ambiguity.
  If the chunk carries a later `first_authored.at`, step 6.4 picks it, and its rows are stale.
  **Fix (one clause):** a chunk stands for its root.
  Match on the root, and when the root's `## Iteration Log` has no rows, read the last row from its newest chunk that has one.

### 3. Pillar 2 handoff step (`orchestration-discipline.md`)

- `### Resumption` step 2 "At each handoff" is the right place.
  It is the only per-handoff action list, and it already holds the Scratchpoint refresh and the commit.
  `### Handoff format` describes the handoff's content, not when actions run.
- The rule points at the skill rather than repeating the threshold, so there is one source.
- The one-line edit does not shift the reseed line: the Phase 1a grep 2 hit is still `:211`.

### 4. Proposal and RFP edits (`cc7b808`, `0630cc6`)

- **The A/B move is complete.**
  In the proposal, `A/B` appears only in the Phase 2 NOTE (line 531) and in the Phase 3 heading (line 540), which points at the RFP.
  The Phase 2 heading, its dependency line, deliverable 3, the success criteria, the Test Plan's Phase 2 list, and Verification Methodology all drop the A/B.
  No Phase-2 A/B reference dangles.
  The RFP's stale "Relationship to ... Phase 2 A/B" question is replaced, not duplicated.
- **Minor: the RFP's A/B bullet conflicts with its neighbors.**
  The A/B's pass bar, "arm 2 wins or ties arm 1 on all three", is a single pass/fail.
  The "Test protocol" bullet two lines up asks for at least 3 runs per arm and a majority rate, "not pass/fail".
  The "Acceptance bar" bullet below leaves the bar open.
  A reader cannot tell whether the A/B bar is fixed or subject to those questions.
  One clause fixes it, such as "scored under the Test protocol above", or marking the bar provisional.
- **Thresholds.** The split trigger, merge floor, Edge Cases case, and Objective example are all in words.
  The arithmetic in the devlog (7.86 bytes/word over 101 devlogs) supports the conversion.
  Remaining sizes: Background item 3's "~10-15KB" quotes the methodology report, and the RFP's ~27KB and ~60KB are measurements.
  **Nit:** two byte budgets remain outside Phase 2's scope.
  The Phase 1b block-text bound "(under 300 bytes)" is at proposal line 231, and the RFP repeats it as the "300-ish-byte budget" open question.
  Both are a hook-output budget, and hook caps are byte-denominated, so leaving them is defensible.
  The maintainer may still want them in words for consistency, at roughly 40 words.

### 5. Verification (independently re-run)

| check | result |
|---|---|
| `cdocs-validate-frontmatter.sh` on the six dry-run files | empty output for all six; a negative control without `status:` yields `missing required frontmatter fields: status` |
| `npm run build:cdocs` | exit 0, "Agents converted: 7"; warnings only `Unknown CC tool "*"` x3 and Node `DEP0205`; "Splitting a devlog" is present in the built devlog skill, `orchestration-discipline.md`, and `frontmatter-spec.md` |
| `chat-record.test.sh --unit` | `95 passed, 0 failed`, exit 0 |
| Phase 1a grep 1 | empty (exit 1) |
| Phase 1a grep 2 | exactly `orchestration-discipline.md:211`, the reseed line |
| `grep -rn chat-record plugins/cdocs/skills plugins/cdocs/agents` | empty |

> NOTE(opus-5-5/cdocs/chat-record-devlog-management): Per the dispatch directive ("Don't edit other files"), this review does not update the proposal's `last_reviewed`; the overseer owns that write.

## Verdict

**Revise.**
One major finding, the triage step 6.1 chunk skip, which regresses the iterate log-state mapping once a finished loop's devlog is split.
Everything else is accept-quality.
After that clause is fixed, this phase should pass without another full round.

## Action Items

1. [blocking] `plugins/cdocs/agents/triage.md` step 6.1: replace "skipping chunks (`part_of` set): ..." with a rule that makes a chunk stand for its root.
   Match on the root; when the root's `## Iteration Log` has no rows, read the last row from its newest chunk that has one.
   Keep step 6.4's tie-break for distinct roots only.
2. [non-blocking] `cdocs/proposals/2026-10-05-post-compaction-resumption-rfp.md` "Resumption A/B" bullet: reconcile its pass/fail bar with the "Test protocol" and "Acceptance bar" bullets, by one clause or by marking the bar provisional.
3. [non-blocking, maintainer call] Decide whether the Phase 1b block-text bound "(under 300 bytes)" and the RFP's "300-ish-byte budget" stay byte-denominated, as hook-output budgets, or move to words.
4. [non-blocking] If the dry-run copies are committed as a worked example, repoint root B's "Pre-Flight Check Results above" to the `-runs` chunk.

## Questions for the Maintainer

1. Hook-output size bounds (proposal line 231, RFP open question):
   (a) keep them in bytes, since the harness caps are byte-based;
   (b) convert them to words like the split thresholds.
2. The dry-run copies:
   (a) leave them uncommitted, with the result recorded in the devlog;
   (b) commit them over the two originals as a worked example of a split.
