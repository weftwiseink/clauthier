---
review_of: cdocs/proposals/2026-08-28-overseer-alignment.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-01T10:57:20-07:00
task_list: cdocs/overseer-alignment
type: review
state: live
status: done
tags: [fresh_agent, phase2, context_management, iterate, judge, orchestration_discipline, build_validated]
---

# Review: Overseer Alignment Phase 2 (Context persistence and cleanliness)

## Summary Assessment

Phase 2 adds the remaining Pillar 2 context-cleanliness discipline to `orchestration-discipline.md` (handoff-before-compact format, proactive compaction cadence, `CLAUDE.md` reseed mechanic), wires an explicit Checkpoint into `iterate/SKILL.md` at both fire points plus a soft-budget-as-judge-input Termination clause, and extends `judge.md` with one sentence treating a soft context/loop-length cap as a weighed judge input.
The implementation is clean, precise, and additive: all five Phase 2 acceptance criteria are met, the build flows the new rule text to the OpenCode target, no new em-dashes are introduced, `judge.md` frontmatter is valid and its three-verdict output format is unchanged, and the synthetic judge-input walk drives `escalate` on stalled-progress bloat and `continue` on progress-with-bloat as designed.
The reseed claim is correctly qualified rather than overclaimed, with the required source URL cited.
Verdict: **Accept**. No blocking findings. The live iterate-loop behavioral probe is correctly deferred to a separate top-level invocation and is not treated as a blocker here.

## Verification Evidence

- **Build:** `npm run build:cdocs` exits 0 ("build-opencode: Done. Agents converted: 4").
- **OC flow-through:** `grep -nE "Completed|Decisions Made|Open Todos|compaction cadence|reseed" build/cdocs/opencode/rules/orchestration-discipline.md` returns the full Pillar 2 body (handoff subsections at lines 117-119, "Proactive compaction cadence" at 123, "CLAUDE.md reseed mechanism" at 129, caveat at 135), confirming the new rule text materializes to the OpenCode artifact.
- **Em-dashes:** `grep -n "—"` and `grep -n " -- "` across all three changed files return exit 1 (no matches). No new em-dashes.
- **Frontmatter:** `judge.md` frontmatter parses cleanly (`name, model, description, tools, color, maxTurns`); `tools: Read, Glob, Grep, Write` unchanged.
- **Diff scope:** `git diff d64af78 HEAD` on the three files shows purely additive hunks: a new `## Pillar 2` block plus one Cross-Target Degradation sentence in the rule, one Checkpoint subsection plus Accept/Judge wiring plus a Termination clause in iterate, and exactly one sentence in judge.md. No Phase 1 content is deleted or rewritten.

## Section-by-Section Findings

### Criterion 1 - Handoff-before-compact format and dual fire points (met)

The rule (`orchestration-discipline.md` lines 110-121) defines the handoff as "a markdown section with exactly three subsections": **Completed**, **Decisions Made**, **Open Todos**.
It states the write ordering explicitly (line 112: "writes a handoff into the devlog BEFORE compacting") and that skipping is a failure (line 113: "skipping the handoff and compacting anyway is a failure ... which is why the write precedes the compact").

`iterate/SKILL.md` wires the checkpoint at BOTH fire points:
- Turn N.c Accept branch (line 91): "write the final devlog entry, then run the Checkpoint (below)."
- Turn N.d (line 102): "Append a Judge Log row, then run the Checkpoint (below)."
- The Checkpoint subsection (lines 104-109) restates both fire points and adds the proactive 3-5 iteration trigger.

The Checkpoint references the rule for the format rather than restating it (line 108: "the three-subsection Completed / Decisions Made / Open Todos section defined in `orchestration-discipline.md` Pillar 2; do not restate the format here").
Non-blocking observation: iterate names the three subsection labels inline while pointing to the rule for the format. This is the correct compromise (the inline floor at line 14 also names them), not a restatement of the format spec, so no duplication concern.

### Criterion 2 - Proactive compaction cadence, internally consistent (met)

Rule lines 123-127: checkpoint-and-compact "after every 3 to 5 iterations ... OR whenever a judge invocation completes," "proactively at task-unit boundaries, NOT reactively at the window limit," targeting "under roughly 150K tokens."
iterate Checkpoint (line 106): fires "at each judge assessment (Turn N.d) ... and proactively after every 3 to 5 iterations at a task-unit boundary."
The two are consistent: the judge-assessment fire point in iterate is the rule's "whenever a judge invocation completes," and the 3-5 iteration cadence matches verbatim. No contradiction.

### Criterion 3 - Soft context-budget as a judge input, not a hard kill (met)

`judge.md` adds exactly one sentence (line 68): "A soft context-budget or loop-length cap the overseer surfaces ... is one such input, weighed the same way against progress, not a hard trigger."
This is NOT a duplicate of the Phase 1 bloat paragraph (lines 66-67): the Phase 1 lines cover the `overseer_ctx_est`/`inline_work` trend signals; the new sentence adds the overseer-surfaced soft budget and loop-length cap as an additional input class and ties it to the "not a hard trigger" framing.
No fourth verdict is introduced: the Output Format block (lines 88-101) is unchanged and still lists `continue | rotate-implementer | escalate`. The `overseer_thinness` field remains a separate, non-verdict diagnosis.

iterate Termination (lines 116-118) states the same contract consistently: "A soft context-budget signal is a JUDGE INPUT weighed against progress, never a hard kill. ... it does not itself terminate the loop. This preserves the accept/reject/escalate/interrupt contract."
judge.md and iterate agree; the accept/reject/escalate/interrupt contract is preserved on both sides.

**Synthetic Iteration-Log walk (required):**

Scenario (a) - rising `overseer_ctx_est` (row1 ~120K -> row2 ~190K -> row3 ~260K) with a run of `inline_work: yes` AND stalled progress (reviewer findings not shrinking, near-identical commits):
- judge.md line 66 ("weighs toward `escalate` when it coexists with stalled progress") + line 67 ("rising context WITHOUT progress escalates") + line 68 (soft cap weighed the same way) drive **escalate**.
- `overseer_thinness: bloat_detected` is logged (line 80: columns present, rising trend).
Result: escalate + bloat_detected. Correct.

Scenario (b) - same rising trend WITH clear forward progress (reviewer findings shrinking round over round):
- judge.md line 67 ("rising context WITH clear progress may still be `continue` (the bloat is logged, not acted on)") drives **continue**.
- `overseer_thinness: bloat_detected` is still logged (bloat diagnosis independent of verdict, per lines 77 and 98 of the rule / line 80 of judge.md).
Result: continue + bloat_detected. Correct.

The walk confirms the soft budget is weighed against progress, not a hard kill, and that the bloat diagnosis stays auditable independent of the verdict.

### Criterion 4 - CLAUDE.md reseed mechanic, accuracy load-bearing (met, not overclaimed)

Rule lines 129-143 state the confirmed finding with the required qualification:
- Positive claim (line 132): "Project-root `CLAUDE.md` and *unscoped* rules (`.claude/rules/*.md` with no `paths:` frontmatter) are re-injected from disk on both auto-compaction and manual `/compact`."
- CAVEAT (lines 135-136): "**path-scoped** rules (rules with `paths:` frontmatter) and **nested** `CLAUDE.md` files do NOT reliably reseed. They reload only when Claude next reads a matching file."
- Source URL cited (line 133 and 143): `https://code.claude.com/docs/en/context-window.md` ("What survives compaction").
- cdocs-lands-cleanly rationale (line 138): "`/cdocs:init` materializes rules as an unscoped `.claude/rules/cdocs.md`, and source repos deliver the discipline via root `CLAUDE.md` `@`-imports: both are in the auto-reseeded set," with the consumer-loses-guarantee inverse at line 139.

There is no unqualified "everything reseeds" claim; the path-scoped/nested caveat is present and prominent. The `frontmatter-spec.md` itself carries `paths:` frontmatter, which makes the caveat concretely relevant to cdocs' own rule set and reinforces why the discipline is delivered via the unscoped `.claude/rules/cdocs.md` materialization. Criterion satisfied.

Non-blocking: the reseed finding rests on the cited documentation (and the devlog research commit `af20177`), not a live compact-and-reseed probe. This is appropriate for a documentation-citation verification and consistent with the deferred-live-probe posture the task sets.

### Criterion 5 - No Phase 1 duplication, additive only (met)

The `git diff d64af78 HEAD` shows Phase 1 sections (Pillar 1, Inline Discipline Floor, Graded Enforcement, Pillar 1b, Judge-Observable Thinness Signal) untouched.
Pillar 2 references the Phase 1 thinness-signal section rather than restating it (rule line 108: "see 'Judge-Observable Thinness Signal' above").
iterate's Iteration Log section (unchanged) continues to reference the same section (line 135). The additive-fields contract, the thinness columns, and the accept/reject/escalate/interrupt schema are all unchanged. Additive-only confirmed.

### Writing conventions (met)

Sentence-per-line preserved across all three files. No em-dashes (grep confirmed). The new NOTE uses proper attribution `NOTE(claude-opus-4-8/overseer-alignment-phase2)`. External references use direct HTTPS links.

## Verdict

**Accept.**

All five Phase 2 acceptance criteria are met with cited evidence. The build passes and flows the rule text to the OpenCode target, writing conventions hold, `judge.md` remains a three-verdict agent with an unchanged output format, and the synthetic judge-input walk behaves as the soft-budget-weighed-against-progress design requires. The reseed claim is correctly qualified with its source. There are no blocking findings.

## Action Items

1. [non-blocking] When the deferred live iterate-loop behavioral probe runs as its own top-level invocation, capture whether the overseer actually writes the three-subsection handoff before compacting and whether per-turn context stays under the ~150K target, and record it in the Phase 2 devlog (`review_proof: deferred-to-followup` per iterate's convention).
2. [non-blocking] Consider adding, in a future pass, a one-line pointer in the rule's reseed section noting that cdocs' own `frontmatter-spec.md` is path-scoped, as a concrete in-repo illustration of the caveat. Purely illustrative; not required for correctness.

## Questions for the Maintainer

The implementation is accept-ready as-is; these are optional forward-looking calibrations, surfaced as multiple choice rather than blockers:

1. Soft-cap surfacing mechanics. The overseer "surfaces" the soft context/loop-length cap to the judge, but the trigger for surfacing is left to overseer discretion. Which do you prefer?
   - (a) Leave it discretionary (current state); the overseer decides when to flag.
   - (b) Pin a concrete surfacing trigger in a follow-up (e.g., surface once `overseer_ctx_est` exceeds ~200K or iterations exceed N), aligning with the "soft loop cap tuning" open question in the proposal.

2. Reseed verification durability. The reseed mechanic is verified by documentation citation. Do you want to:
   - (a) Treat the citation as sufficient standing verification (current state).
   - (b) Add a lightweight live reseed smoke check to the deferred Phase 2 behavioral-probe invocation, so the load-bearing claim has an empirical backstop in-repo.
