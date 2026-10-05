---
review_of: cdocs/proposals/2026-09-22-haiku-bash-wrapper.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T10:00:31-07:00
task_list: meta/token-spend-attribution
type: review
state: live
status: done
tags: [fresh_agent, implementation, rereview, live_canary, runtime_validated, sonnet_runner, report_contract_v2, fidelity, report_size, aggregate_specs]
---

# Review: Bash-Output Wrapper, Implementation Round 8 (Two-Command Aggregate Excerpt)

> BLUF(opus-5-5/haiku-bash-wrapper-impl-r8): **Accept.**
> Option A fixes the aggregate-sweep failures from r7.
> In all four sweeps (b1 and b2, twice each), `Excerpt:` holds the output of the runner's counting command and its sampling command, the totals come from a command, and no line was reworded.
> Every report is 4.3K chars or less.
> Spot-checks a, c and d1 pass.
> The remaining slips are isolated, cosmetic, and each in a different run: a code fence, one extra true character, and one label line.
> One follow-up: the "under 4,000 by construction" sentence is about 300 chars optimistic when paths are absolute.

## Summary Assessment

Iteration 8 (`c17ad00`, `9e8393e`, `2eae8da`, `3381767`) changes the aggregate-spec bullet of `bash-runner.md` Step 3.
The excerpt now comes from two bounded commands pasted whole: counts at `head -n 20 | cut -c1-120`, and samples at `cut -c1-120 | head -n 12`.
Headings and composed lines are moved to `Summary:`, totals must come from a command, and the change notes that `Truncated:` is for omissions, not absences.
Step 2 is untouched, as the binding requires.
The dispatch guidance and the proposal describe the change accurately and briefly.
Live evidence ([`_verify/...-r8.md`](../devlogs/_verify/2026-10-05-bash-runner-live-canary-r8.md)) closes r7's F1-F3 and F4 in all four sweeps.
Verdict: **Accept.**

## Acceptance Bar (judge-2), Per Run

| criterion | a | b1a | b1b | b2a | b2b | c | d1 |
|---|---|---|---|---|---|---|---|
| (i) containment | pass | pass | pass | pass | pass | pass | pass |
| (ii) structure, no composed lines in Excerpt | pass | pass | minor: code fence | pass | pass | minor: one label line | pass |
| (iii) Excerpt fidelity | pass | pass (identical to commands) | pass (identical) | pass (count leading spaces stripped) | pass (1 line +1 true char; leading spaces stripped) | pass | pass |
| (iii) Summary names and numbers | pass | pass | pass | pass | pass | pass | pass |
| (iv) Status | pass | pass | pass | pass | pass | pass | pass |
| (v) <= ~4K body | 358 | 3,363 | 3,353 | 4,308 | 4,209 | 589 | 1,123 |
| (vi) honest Truncated | pass | pass | pass (imprecise wording) | pass | pass (muddled aside) | pass | pass |

In every run the runner was `claude-sonnet-5-5` and used only `Bash` (1-4 calls, 13.4-19.5K tokens).
The parent's only tool call was `Agent`.
d1's capture is identical to a reviewer-run `npm run build:cdocs` apart from the node PID.

## Section-by-Section Findings

### `bash-runner.md` Step 3, aggregate bullet (`c17ad00`)

**r7 F1 and F3 (sweep transcription drift, size) are closed.**
All four sweep runners ran the prescribed counting command and one sampling command, then used those outputs as the excerpt.
The reviewer re-ran each command on the capture.
All four count blocks match, b2 apart from stripped `uniq -c` leading spaces.
Three of four sample blocks are byte-identical.
The fourth (b2b) differs in one character on one line, covered by F2 below.
r7's three reworded lines (`restricted`, `(impl-1 ...`, `fully`) have no counterpart this round.
Bodies fell from r7's 6,493 to at most 4,308.

**r7 F2 (mental arithmetic in Summary) is closed.**
All four sweeps got `97 matches across 23 files` from `cut -d: -f1 | sort -u | wc -l` and a line count.
Per-file numbers in `Summary:` were read off the count block and are correct.

**r7 F4 (composed or heading lines in sweep excerpts) is closed.**
No sweep put a heading or a `1 each:` line inside `Excerpt:`.
The condensations ("samples cover 12 files at 1 match each") are now in `Summary:` or `Truncated:`.

**F1 (non-blocking): the "by construction" size claim is about 300 chars optimistic.**
With absolute paths, the count block is about 90 chars × 20 lines and the sample block 120 × 12.
Add 600-900 chars of Summary and Truncated, and b2 lands at 4.2-4.3K.
That fits "~4K" and the bar, but the sentence "stays under about 4,000 characters by construction" is not literally true.
Options: lower the sample cut to `cut -c1-100`, or reword the sentence to "about 4K".

**F2 (non-blocking): pasting is still token regeneration, so single-character slips remain possible.**
b2b's last sample is `...: use the T`; its command output ended at `use the`.
The extra `T` is true capture content (the line continues `Task tool`), so the prefix check passes, but the line is not a byte-exact paste.
b2b's count lines also lose the `uniq -c` leading spaces (b2a's do too; r7 noted the same).
Both are cosmetic.
They are the residual risk of any model-relayed excerpt, and no prompt edit removes them.
The dispatch guidance could say that excerpt lines are a guide and the capture file is the source of truth for exact bytes.

**F3 (non-blocking): b1b broke two minor rules, and disclosed what it left out.**
It wrapped `Excerpt:` in a ```` ``` ```` fence, which the Output Format forbids.
It also sampled `c[$1]++ < 3 | head -n 12`, which covers only the first 4-5 files.
The prompt says to fall back to 1 per file when 3 per file does not fit, and it did not.
The output was still pasted whole and `Truncated:` disclosed the gap, so no criterion that matters failed.
This happened in 1 of 4 sweeps, so it is not systematic.

### `bash-runner.md`, default (no-spec) path

**F4 (non-blocking): c put a `...final lines of the capture:` label inside `Excerpt:`.**
The rule against composed lines is written inside the aggregate bullet, so a no-spec run may not read it as applying to itself.
A one-clause addition to the general Excerpt bullet ("no labels or composed lines; those go in `Summary:`") would make the rule global.
This is isolated: r7's c had no such line.

### `orchestration-discipline.md` (`9e8393e`) and proposal (`2eae8da`)

The changes are accurate and brief.
The proposal's description ("at most 20 lines", "at most 12 lines of at most 120 chars", "under ~4K by construction") carries F1's slight overstatement; one edit fixes both places.

### Devlog notes (`3381767`)

The iteration-8 implementation notes match the commits.
Step 2 is unchanged, as the binding requires (`git show c17ad00` touches only the Step 3 aggregate bullet).

## Verdict

**Accept.**
Every judge-2 criterion passes in all seven runs.
The sweep class that failed 2 of 2 in r7 passes 4 of 4 here, with excerpts that match the commands and totals that come from commands.
The remaining slips (a fence, a label, one extra true character, stripped leading spaces) are isolated, cosmetic and do not change content.

## Action Items

1. [non-blocking] Make the size claim match the evidence: lower sample lines to `cut -c1-100`, or say "about 4K" instead of "under about 4,000 ... by construction" (in `bash-runner.md` and the proposal).
2. [non-blocking] Move "no labels, headings or composed lines inside `Excerpt:`" into the general Excerpt bullet so no-spec runs follow it too (F4).
3. [non-blocking] Note in the `orchestration-discipline.md` dispatch guidance that excerpt lines are relayed by a model, and that callers needing exact bytes should read the capture path (F2).
4. [non-blocking, carried] Captures still fall back to `/tmp` because the runner lists no scratchpad. Callers should delete `/tmp/bash-runner-*.log` themselves (tracked as an arc follow-up).
