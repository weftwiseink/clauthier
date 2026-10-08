---
review_of: cdocs/proposals/2026-10-07-rules-references.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T22:07:58-07:00
task_list: cdocs/rules-references
type: review
state: live
status: done
tags: [rereview_agent, runtime_validated, verification_gate, rules_delivery, test_plan]
---

# Review: Rules References (Round 4)

## Summary Assessment

The revision resolves the round-3 blocking item: the phase 3 gate now swaps the canary word on disk before `/compact` and passes only on the new word, which the compaction summary cannot hold.
All four round-3 nits are also resolved: the probe vehicle, the no-import fixture, matching across every post-compaction assistant block, the `rules_check` baseline, and the release unit.
A re-run of the swap probe passed again, and a new no-compaction control showed that a changed rule file is not re-sent without compaction, so the swap isolates compaction re-injection.
The revision adds no contradictions; three small wording nits remain.
Verdict: **Accept**.

## Round-3 action items

| # | Item | Status |
|---|---|---|
| 1 | [blocking] On-disk A→B swap; pass on B; remove the false justification; mirror in Verification step 2 and the Test Plan | Resolved: section 3 items 2-3, the rationale paragraph, Verification step 2, the Test Plan gate row. The optional control run is dropped. |
| 2 | Probe vehicle and no-import fixture | Resolved: a temporary `--only canary_check` extra, removed after the gate (Phase 3 step 1); fixture `hproj` + `init_rules` + `printf '# Project\n' > CLAUDE.md`. |
| 3 | Match every post-`compact_boundary` assistant text block | Resolved: section 3 item 3, with the Stop-hook reason. |
| 4 | `rules_check` baseline | Resolved: run with the import before editing `init_rules`, compare per-assertion pass/fail (section 3, Phase 3 step 2, Test Plan, Verification step 2). |
| 5 | Define "release" | Resolved: one `plugin.json` bump and one push to `main`, with the reason (the nudge follows the hash, and consumers can install from `main`). |

The heading-reference convention and the keep-`cdocs.md` / drop-import delivery are settled by the maintainer and are not revisited.

## Section-by-Section Findings

### Section 3: the canary probe

The fixture recipe works against the current `chat-record.test.sh`:

- `hproj <name>` returns the project path and creates `cdocs/_chat/`, so the Stop hook is active, which item 3 accounts for.
- `init_rules` writes `CLAUDE.md` with the import (`:804`); the `printf` overwrite removes it.
- `inject-rules.ts` reads only the marker from `.claude/rules/cdocs.md` and hashes the plugin's rules, so the appended line and the later `sed` trigger no nudge, as item 1 says.
- The extras block (`want init_real && init_real` ...) takes one more `want canary_check && canary_check` line, and no standard scenario name matches `canary_check`.
- The stream from `claude_run` contains a `compact_boundary` line, the same anchor `rules_check` uses with `awk`.

**Runtime check (this round).**
The round-3 sandbox script (fresh `CLAUDE_CONFIG_DIR`, haiku, stream-json fifo driver, no plugins, `CLAUDE.md` with no import) was re-run on Claude Code v2.1.293 in two variants:

| Run | Turns | Reply | Rule-file `instructions` attachments in the session transcript |
|---|---|---|---|
| swap (round 3) | 2+2, `sed`, `/compact`, question | `marzipan` | `heliotrope` at start; `marzipan` after the boundary |
| plain (round 3) | 2+2, `/compact`, question | `heliotrope` | `heliotrope` at start; `heliotrope` again after the boundary |
| swap (round 4) | 2+2, `sed`, `/compact`, question | `marzipan` | `heliotrope` at start; `marzipan` after the boundary |
| no-compact control (round 4) | 2+2, `sed`, question | `heliotrope` | `heliotrope` at start only |

The control matters.
If Claude Code re-sent the rule file whenever it changed on disk, a `marzipan` reply could pass the gate even if compaction re-injection were broken.
It does not: with no compaction, the changed file is not re-sent and the reply is `heliotrope`.
The plain run shows the same thing from the other side: the unchanged file is re-attached after the boundary, so re-injection is triggered by compaction, not by a change.
So `marzipan` after `/compact` means the file was re-read from disk at compaction, which is what the gate needs.
In the round-4 swap run the summary did not mention the canary at all; in both round-3 runs it carried `heliotrope`.
Either way it cannot hold `marzipan`, so the discriminator does not depend on what the summary contains.
The compaction summary also tells the model it can read the pre-compaction transcript, but that transcript holds only `heliotrope`, so a tool-using reply cannot pass falsely either.

The proposal does not need the control: one swap run is the gate, and this review records the evidence that the swap discriminates.
The implementer still runs and records the gate (Phase 3 step 1); these are reviewer runs outside the suite with no cdocs plugin loaded.

- **Non-blocking: "`drive` sends its messages back to back" is slightly off.**
  `drive` waits for each turn's `result` before sending the next message; what it lacks is a way to run a command between turns.
  Suggested wording: "`drive` has no step between turns, so the extra inlines its send-and-wait loop to run the `sed` after turn one."

- **Non-blocking: "(the probe above)" is now ambiguous.**
  Section 3 now describes a second probe (the canary) a few lines below that sentence.
  "(the dedup probe in Background)" names which one.

### Section 3 and Phase 3 step 2: `rules_check` no-regression

- **Non-blocking: say what a mismatch means.**
  The comparison is one haiku run with the import and one without, and haiku runs vary per assertion (the recorded baseline fails 3 of 5).
  As written, a single flipped assertion blocks Verification step 2, and so phase 3, even though `rules_check` is explicitly not the gate.
  One clause fixes this: "on a mismatch, re-run both once; a difference that repeats is a regression."

### Release coupling

The definition is clear and consistent with the Implementation Phases preamble.
The "one push to `main`" clause holds back pushing `main` from the merge of phase 2 until phase 3 lands or its gate fails.
The failure mode is minor and already stated (a harmless leftover import line), so the constraint costs nothing.

### Consistency sweep

The BLUF, Background NOTE (row three is "gated on a canary probe"), section 3, Test Plan rows 4-5, Verification step 2, and Phase 3 steps 1-2 now describe the same gate and baseline in the same order.
Phase 3 step 1 removes the extra before step 2 changes `init_rules`, so the fixture's `CLAUDE.md` overwrite is never redundant inside a live extra.
No new contradictions found.

## Verdict

**Accept.**
The gate now discriminates, and this round's runs confirm it, including a control for change-triggered re-sends.
Phases 1 and 2 were accepted in round 3 and are unchanged.
The three nits are optional, one clause each, and the implementer can apply them during phase 3.

## Action Items

1. [non-blocking] Section 3 item 2: replace "`drive` sends its messages back to back" with "`drive` has no step between turns".
2. [non-blocking] Section 3: "(the probe above)" → "(the dedup probe in Background)".
3. [non-blocking] Section 3 / Phase 3 step 2: on a `rules_check` per-assertion mismatch, re-run both runs once; only a repeated difference counts as a regression.

## Questions for the author

1. A `rules_check` mismatch between the with-import and no-import runs:
   (a) re-run both once and treat only a repeated difference as a regression (recommended: haiku variance, and `rules_check` is not the gate);
   (b) treat any single-run difference as blocking phase 3;
   (c) record the difference in the devlog without blocking.
