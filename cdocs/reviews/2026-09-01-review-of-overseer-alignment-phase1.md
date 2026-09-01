---
review_of: cdocs/proposals/2026-08-28-overseer-alignment.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-01T16:20:00-07:00
task_list: cdocs/overseer-alignment
type: review
state: live
status: done
tags: [fresh_agent, architecture, orchestration, judge_remit, runtime_validated, phase1]
---

# Review: Overseer Alignment Phase 1 (foundational rule, resumption/ownership disciplines, judge signal)

## Summary Assessment

Phase 1 promotes the duplicated, drifting overseer-mode prose into a single canonical rule (`orchestration-discipline.md`), wires the judge into a logged thinness signal, adds two empirically-motivated resumption/ownership disciplines (Pillar 1b), and reduces the three loop skills to a reference plus an inline floor.
The implementation is faithful, complete against every Phase 1 acceptance criterion, and mechanically clean: both drift greps return the expected results, the build succeeds with the rule flowing to the OpenCode output, and the judge Output Format schema matches the template column-for-column.
The judge remit reads correctly against all four Test-Plan walkthrough cases (A-D), including the load-bearing distinction that a `bloat_detected` diagnosis can coexist with a `continue` verdict.
The one substantive observation is non-blocking: the Dispatch/Return Events table is defined and its read-path (on-resume reconciliation) is well-specified, but the turn-by-turn Loop Protocol never explicitly instructs the overseer to WRITE an event row at each dispatch and return, leaving the write discipline implied rather than stated at the points where it happens.
Verdict: **Accept**.

## Section-by-Section Findings

### Rule content: `plugins/cdocs/rules/orchestration-discipline.md` (new)

The rule faithfully covers the Phase 1 slice of Pillars 1 and 1b, plus the Phase-1 portion of Pillar 2 (the judge-observable thinness signal).
Verified present and correct:

- Pillar 1 core responsibilities (the four "does NOT" items: no `npm test`, no full reads when a summary serves, no committing code, no build/dev runs), dispatch-by-default with the concrete `>1KB`/`>20 lines`/`>10 lines`/domain-judgment heuristics, the "trivial few-liners" carve-out with the stricter-but-never-looser rule for skills, summary absorption as the contract boundary, and the per-dispatch signaling self-check.
- The inline-floor REQUIREMENT with its rationale (the un-init'd marketplace-install delivery gap) is stated as a rule, not just a skill convention, and carries a NOTE forbidding a later nit-fix from deduplicating it away.
- Graded enforcement is correctly rendered as three layers with the judge backstop explicitly scoped iterate-only, and correctly conditions the backstop's reality on both logged fields existing.
- Pillar 1b on-resume liveness reconciliation and single-writer file ownership are both present, each with the round-2 NOTE attributions carried over from the proposal (the deadlock and the file-clobber incidents).
- The judge-observable thinness signal is split correctly into the overseer-written input and the judge-written `overseer_thinness` output, with the `bloat_detected` + `continue` coexistence spelled out.

Attribution discipline is honored: the proposal's NOTE callouts (claude-sonnet-5/overseer-alignment-round2, claude-opus-4-8/overseer-alignment-round2) are preserved on the corresponding rule passages.
Non-blocking: the rule scopes cleanly to Phase 1 and correctly forward-references Phase 2 for the remaining context-cleanliness discipline, so no Phase 2-5 material leaks in.

### Registration surfaces (three)

All three present and each matches its file's existing pattern.

- `plugins/cdocs/AGENTS.md:13-15`: a `## Orchestration Discipline` heading with `@rules/orchestration-discipline.md`, placed between Workflow Patterns and Frontmatter Specification, matching the sibling `@rules/` entries.
- `CLAUDE.md:47`: `@plugins/cdocs/rules/orchestration-discipline.md`, inserted in the same ordinal position as the AGENTS.md list, matching the sibling import bullets.
- `plugins/cdocs/skills/init/SKILL.md:79-81`: a new `## CDocs Orchestration Discipline` section in the hardcoded AGENTS.md template, ordered consistently with the other two surfaces, closing the split-brain the proposal called out (hashed-but-not-inlined).

The section ordering is consistent across all three surfaces, which is the correct outcome for the init-materialized inline block.

### Drift removal (three skills)

Both required greps return the expected results:

- `rg "top-level session agent enters when invoking this skill" plugins/cdocs/skills/` returns ZERO matches.
- `rg "trivial few-liners|even trivial ones" plugins/cdocs/skills/` resolves to exactly one occurrence per phrase, each as the skill's carve-out (`iterate` line 14 "trivial few-liners", `propose-revise` line 18 "even trivial ones").

Each of the three skills carries a reference to `orchestration-discipline.md` AND an inline floor:

- `iterate/SKILL.md`: reference line 13, floor line 14.
- `propose-revise/SKILL.md`: reference line 17, floor line 18.
- `full-send/SKILL.md`: reference line 13, floor line 14.

Each floor covers the three required floor points (dispatch-by-default with the skill's own carve-out, durable state before compacting, fresh reviewer/judge), and the old multi-paragraph overseer-mode definitions are gone.
The preserved role tables (`iterate` Roles 39-44, `propose-revise` Roles 42-47), the `iterate` Loop Protocol (46-62), and the accept/reject/escalate/interrupt termination contract (`iterate` line 103) are all intact.

Non-blocking nit: each inline floor is a single line joining three clauses with semicolons, and the writing conventions ask that semicolons be used sparingly and prefer one thought per line.
This is a deliberate terse floor and reads fine, so it is a style observation, not a defect.

### On-resume liveness step (iterate and full-send)

Present in both.
`iterate/SKILL.md:106-112` adds an "On-Resume Reconciliation" section that instructs re-deriving dispatch/return state from the events rows, treats a believed-in-flight child as terminated when the harness has returned control, and folds in the file-ownership check before dispatching a writer.
`full-send/SKILL.md:15` carries the same reconciliation instruction inline for both composed loops.
Both point back to Pillar 1b of the rule.

### Additive log fields (`iterate/template.md`)

Confirmed additive by diff against baseline `caa1bd6`: no existing column is removed or renamed.

- Iteration Log gains `overseer_ctx_est` and `inline_work`, inserted before the existing `notes` column; all prior columns (`iteration`, `implementer`, `reviewer`, `review_verdict`, `review_proof`, `review_path`, `notes`) are preserved in order, and the example row is updated to match.
- Judge Log gains `overseer_thinness`, inserted before `rationale`; `judge_iteration`, `trigger`, `verdict`, `rationale`, `judge_path` are preserved in order.
- A new `## Dispatch/Return Events` table (`event`, `agent_handle`, `target_files`, `at`, `notes`) is added with full column semantics.

`iterate/SKILL.md:114-123` references all three tables and the new columns in prose.

### Judge remit (`agents/judge.md`)

The remit is extended correctly and the constraints are intact.

- Escalate keys off the overseer columns as one input weighed against progress, NOT a fourth verdict: line 66-67 make rising `overseer_ctx_est` or a run of `inline_work: yes` weigh toward escalate only when coexisting with stalled progress, and explicitly allow rising-context-with-progress to remain `continue`.
- `overseer_thinness` is written at EVERY invocation (line 75), separate from the verdict (line 76), with the `clean`/`bloat_detected`/`signal_missing` semantics defined (78-81).
- `signal_missing` is written and flagged in the rationale when the input columns are absent, rather than silently passing (80-81).
- Output Format (85-100) and the JUDGE LOG ROW (99) are updated to the six-column shape.
- The no-Bash/no-source/no-Task constraints are intact: frontmatter `tools: Read, Glob, Grep, Write` (line 5), and the Constraints section (105-113) reiterates no source reads, no verification commands, no subagent dispatch.

### Judge-remit walkthrough (Test Plan Tests A-D)

Reading judge.md against each case:

- Test A (rising 80K->150K->200K + escalate criteria met): escalate criteria met implies stalled progress, so lines 66-67 drive `escalate`; line 79 drives `overseer_thinness: bloat_detected`; the escalate rationale requirement plus line 67's trend language drive a trend-naming rationale. Correct.
- Test B (steady ~100K + continue): line 78 drives `clean`, verdict `continue`. Correct.
- Test C (missing columns): lines 80-81 drive `signal_missing` and a flagged omission, not a silent pass. Correct.
- Test D (rising context BUT shrinking reviewer findings): line 67 keeps the verdict `continue` (progress present) while line 79 still logs `bloat_detected`. Correct, and this is the exact independence the design hinges on.

No case is driven wrongly by the current text.

### Liveness/file-ownership probe (Test Plan ~L237-240)

The rule (Pillar 1b, lines 68-88) and both skills instruct a resumed overseer to report a returned child from the event rows rather than as in-flight (rule line 73-74; `iterate` 108-110; `full-send` 15), and to defer or re-scope a write against a path with an open ownership claim (rule 83-85; `iterate` 111).
The Dispatch/Return Events table's `target_files` column is the recorded ownership claim the reconciliation reads.
The text supports both probe behaviors from the log alone.

### Schema consistency (judge.md vs template.md)

Column-by-column match, six columns, same order:
`| judge_iteration | trigger | verdict | overseer_thinness | rationale | judge_path |`
appears identically in `judge.md:99` (JUDGE LOG ROW) and `template.md:15` (Judge Log header).
judge.md:103 additionally asserts the match and requires the rationale to name the missing columns when `signal_missing`.

### Build

`npm run build:cdocs` exits successfully ("build-opencode: Done.", 4 agents converted).
The only warning is the known, unrelated `Unknown CC tool "*"` from reviewer.md, which is out of scope per the task.
The new rule flows to the OpenCode output: `build/cdocs/opencode/rules/orchestration-discipline.md` (8443 bytes) is present with content intact.

## Non-blocking observation: event-row WRITE discipline is implied, not stated at the dispatch points

The Dispatch/Return Events table is well-defined and its READ path (on-resume reconciliation) is explicit.
The WRITE path is thinner: the turn-by-turn Loop Protocol (Turn N.a Implement 71-75, N.b Review 77-82, N.d Judge 95-99) never says "append a dispatch event row here" or "append a return row when the child returns."
The write discipline lives only in the descriptive prose that the table "records each child dispatch and return" (`iterate` line 123, template line 64) and in the Turn-0 instruction to copy the table.
For Phase 1 this is acceptable: the table, its semantics, and the reconciliation that consumes it all exist, and a careful overseer following the descriptive prose will populate it.
But if the overseer does not populate the events table during normal turns, the on-resume reconciliation it feeds has nothing to read, which is the exact failure Pillar 1b exists to prevent.
Sharpening Turn N.a/N.b/N.d to say explicitly "append a dispatch event row on dispatch and a return row on return (with the child's `target_files` claim)" would close the gap between the disciplined read-path and the implied write-path.
This is a strengthening suggestion, not a Phase 1 blocker.

## Verdict

**Accept.**

Every Phase 1 acceptance criterion is met.
The rule content is faithful and correctly scoped, all three registration surfaces are present and well-formed, both drift greps return the expected results, the log fields are additive with no column removed or renamed, the judge remit drives all four Test-Plan cases correctly with the schema matching the template, the liveness/file-ownership text supports both probes from the log alone, and the build succeeds with the rule in the OpenCode output.
The one substantive finding (event-row write discipline) is non-blocking and appropriate to fold into Phase 2's context-cleanliness work rather than to gate Phase 1.

## Action Items

1. [non-blocking] In `iterate/SKILL.md`, make the Dispatch/Return Events WRITE discipline explicit at the dispatch points: instruct Turn N.a/N.b/N.d to append a `dispatch` row on dispatch and a `return` row on return, recording the child's `target_files` ownership claim, so the on-resume reconciliation always has rows to read. Natural to fold into Phase 2.
2. [non-blocking] Optionally reflow the three inline floors to lead with the dispatch-by-default clause on its own line rather than a semicolon-joined single line, aligning with the sentence-per-line and sparing-semicolon conventions. Cosmetic only.

## Clarifications for the maintainer (multiple choice)

1. Event-row write discipline (finding above):
   - (a) Fold the explicit write instruction into Phase 2 alongside the handoff/compaction cadence work (recommended).
   - (b) Add the one-line instruction to the iterate Loop Protocol now, as a Phase 1 follow-up commit.
   - (c) Leave as-is: the descriptive prose is sufficient and a disciplined overseer will populate the table.

2. Inline-floor formatting (cosmetic):
   - (a) Leave the terse single-line floors as-is (recommended; they read fine and stay compact).
   - (b) Reflow to sentence-per-line for strict writing-convention alignment.
