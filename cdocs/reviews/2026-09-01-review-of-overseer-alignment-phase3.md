---
review_of: cdocs/proposals/2026-08-28-overseer-alignment.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-01T11:10:00-07:00
task_list: cdocs/overseer-alignment
type: review
state: live
status: done
tags: [fresh_agent, durable_specialists, orchestration_discipline, cross_target, deduplication, architecture]
---

# Review: Overseer Alignment Phase 3 (Durable Specialists / Pillar 3)

## Summary Assessment

Phase 3 formalizes the durable-specialist pattern as a new `## Pillar 3: Durable Specialists` section in `orchestration-discipline.md`, with pointer cross-references from `workflow-patterns.md` and the top-level `implement`/`propose` skills.
The implementation is complete, additive (43 insertions / 0 deletions, confirmed against disk), and faithful to the proposal's Phase 3 and Pillar 3 intent.
All seven acceptance criteria pass: the four required elements are present, Pillar 1b is referenced by name without restatement, the enforcement backbone is extended rather than restated, discoverability is achieved by pointer without duplication, the OC build succeeds and carries the new text, and writing conventions hold on all edited files.
Verdict: **Accept**.

## Section-by-Section Findings

### Criterion 1: Four required elements (all present) - PASS

The new Pillar 3 section covers all four required elements, each in its own subsection:
- (a) Resume-by-name via `SendMessage` (line 154): "One specialist per active workstream, resumed by name via `SendMessage`, so the specialist IS the retained context." The specialist-is-the-context framing is explicit.
- (b) `fork` carve-out (lines 160-163): "A `fork` subagent is the tool for a side-investigation that needs full parent context WITHOUT growing the parent thread," with the disposable-context contrast against a durable specialist made explicit.
- (c) One-per-workstream bound (lines 166-169): "at most one durable specialist per active workstream, not one-per-subtask and not workstream-count plus advisory specialists," with the escalate-or-rescope path when the count grows.
- (d) Degradation fallback (lines 177-179): "degrades to starting a fresh session from the handoff doc plus the Iteration Log's event rows."

Non-blocking: the proposal's optional "specialist hygiene" bullet (reads its own devlog once, overseer transmits a pointer not full context) is folded into the resume-by-name prose (line 155) rather than given a subsection. This is acceptable compression, not an omission.

### Criterion 2: Pillar 1b cross-reference by name, no restatement - PASS

The `### File ownership by construction` subsection (lines 172-174) references "Pillar 1b: Single-Writer File Ownership" by exact section name and states the by-construction satisfaction coherently: "the single writer of those paths is the one named specialist across turns, so no second concurrent writer is ever dispatched against them."
It explicitly defers the guarantee itself to that section ("See that section for the guarantee itself; this pillar supplies the constructive case") rather than restating Pillar 1b's content.
The logic is sound: a named specialist owning its own paths across turns is by definition the single writer, so the per-dispatch check that Pillar 1b enforces is satisfied automatically.

### Criterion 3: Extends enforcement backbone, does not restate - PASS

The section intro (line 150) states: "It extends the graded enforcement and judge backstop of Pillar 1 (see 'Graded Enforcement'), it does not restate them: a proliferation of specialists is a bloat pattern the same judge layer flags."
This correctly points at Phase 1's Graded Enforcement / judge backstop as what the pattern extends, and ties specialist proliferation back to the existing judge layer rather than inventing a parallel enforcement mechanism.

### Criterion 4: Additive only, zero deletions - PASS

`git diff` confirms 43 insertions / 0 deletions, matching the implementation claim exactly.
The insertion sits between the Pillar 2 `CLAUDE.md reseed` NOTE and the existing `## Cross-Target Degradation` section.
Pillar 1, both Pillar 1b sections, the Judge-Observable Thinness Signal, Pillar 2, and the Cross-Target Degradation section are untouched.

### Criterion 5: Discoverability without duplication - PASS

Canonical prose lives only in `orchestration-discipline.md`. The three pointers resolve correctly and are genuine references, not restatements:
- `workflow-patterns.md` line 37 (Iterative Implementation Loop) and line 55 (Subagent-Driven Development) both link to `orchestration-discipline.md` "Pillar 3: Durable Specialists" with a one-line framing; same-directory relative link resolves.
- `implement/SKILL.md` line 19 links `../../rules/orchestration-discipline.md` (resolves to `plugins/cdocs/rules/orchestration-discipline.md`).
- `propose/SKILL.md` line 144 links the same path.

Both skills previously had zero orchestration-discipline references (confirmed: the diff adds the first reference to each), so the pattern is now reachable from `workflow-patterns.md` and from both skills, satisfying the Phase 3 success condition.

### Criterion 6: Build + OC flow - PASS

`npm run build:cdocs` exits 0. The `Unknown CC tool ""*""` warning is pre-existing (the `claude` agent's wildcard tool spec) and unrelated to this change.
The new Pillar 3 text reaches `build/cdocs/opencode/rules/orchestration-discipline.md`: `## Pillar 3: Durable Specialists` (line 146), `### File ownership by construction` (line 171), the `SendMessage` resume-by-name line (154), and the phase3 NOTE (181) are all present in the OC output.

### Criterion 7: Writing conventions - PASS

- Em-dash grep across all four edited files returns zero matches (exit 1).
- Sentence-per-line holds throughout the new block (no multi-sentence lines detected).
- NOTE attribution is correct: `NOTE(claude-opus-4-8/overseer-alignment-phase3)` follows the `author/workstream` format.
- The section uses colons in place of em-dashes per the punctuation convention.

Non-blocking: the new block uses a handful of semicolons (lines 162, 174, 179). The convention says semicolons should be used "sparingly," not never, and the density matches the surrounding established file style, so this is consistent rather than a violation.

## Deduplication Check

No content duplicates (rather than references) Pillar 1b or the Cross-Target Degradation section.
One item worth naming as non-blocking: the `### Cross-target degradation` subsection (line 178) re-uses the phrase "starting a fresh session from the handoff doc plus the Iteration Log's event rows," which also appears in the canonical `## Cross-Target Degradation` section.
This is an explicit reference, not a silent restatement: the sentence names the canonical section ("the same runtime fallback the 'Cross-Target Degradation' section names for Pillar 1b") in the same clause.
Stating the fallback primitive once in-context, while pointing to the canonical section for the general rule, is the minimum needed for the subsection to stand on its own, and it correctly scopes the Pillar 3 primitives (`SendMessage`/`fork`) rather than Pillar 1b's (`SendMessage`/`fork`/`compact`). Acceptable.

## Verdict

**Accept.**

The implementation satisfies all seven acceptance criteria against disk, is strictly additive, builds cleanly to both targets, and honors the project's deduplication value by keeping canonical prose in one file with resolving pointers elsewhere.
No blocking issues.

## Action Items

None blocking.

1. [non-blocking] Optional: if a later readability pass touches this file, consider trimming the semicolon density in the Pillar 3 block for consistency with the brevity convention, though current usage is in line with the file's established style.
