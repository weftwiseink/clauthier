---
review_of: cdocs/proposals/2026-09-22-haiku-bash-wrapper.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T09:54:23-07:00
task_list: meta/token-spend-attribution
type: review
state: live
status: done
tags: [fresh_agent, implementation, rereview, live_canary, sonnet_runner, report_contract_v2, fidelity, report_size, aggregate_specs]
---

# Review: Bash-Output Wrapper, Implementation Round 7 (Report Contract v2)

> BLUF(opus-5-5/haiku-bash-wrapper-impl-r7): **Revise**, narrowly.
> Contract v2 works for line-oriented and "summarize" specs: a, c, d1 and d2 pass every criterion, with exact excerpts, correct summaries and reports of about 0.4-1.1 KB.
> It fails for both aggregate sweeps, which is systematic and not an isolated slip.
> b2 hand-cut and reworded 3 match lines inside a 6.5 KB report, over the ~4K ceiling.
> b1 fit the ceiling with exact samples, but its `Summary:` miscounts `skills/ablate` as 22 (the capture's counts sum to 24).
> The fix should make the sweep excerpt one bounded command's output pasted whole, not add another prohibition.

## Summary Assessment

Iteration 7 applies the maintainer-approved report contract v2 to `cdocs:bash-runner` (`20730c2`), the dispatch guidance (`8d8d138`) and the proposal (`bbd802f`).
The prompt text is clear and faithful to the Steering Log entry of 11:45, and Step 2 (the runner's internal reads) is untouched, as required.
Live evidence ([`_verify/...-r7.md`](../devlogs/_verify/2026-10-05-bash-runner-live-canary-r7.md)) shows v2 resolved r6's F2 (prose outside fields) and F3 (dishonest `Truncated: none`): no run put text outside the fields, and every non-none `Truncated:` gave a working command.
r6's F1 (transcription drift in sweeps) persists in b2, and b1 adds a new failure, a wrong number in `Summary:`.
Verdict: **Revise**, limited to aggregate-spec handling.

## Acceptance Bar, Per Run

| criterion | a | b1 | b2 | c | d1 | d2 |
|---|---|---|---|---|---|---|
| (i) containment | pass | pass | pass | pass | pass | pass |
| (ii) structure (v2 fields only, plain text) | pass | pass (minor: composed line, headers in Excerpt) | pass (same minor) | pass | pass | pass |
| (iii) fidelity, Excerpt | pass | pass (minor: composed `1 each:` line) | **FAIL** (3 reworded lines) | pass | pass | pass |
| (iii) fidelity, Summary | pass | **FAIL** (22 vs 24) | pass | pass | pass | pass |
| (iv) Status | pass | pass | pass | pass | pass | pass |
| (v) <= ~4K body | 355 | 3,392 | **6,493** | 698 | 1,009 | 1,146 |
| (vi) Truncated honest | pass | pass (muddled list) | partial (admits hand-cutting, not rewording) | pass | pass | pass (misused for an absence) |

Every runner turn ran on `claude-sonnet-5-5` with only `Bash` (2-4 tool uses, 13.0-20.5K runner tokens).
The reviewer's own `npm run build:cdocs` output matched both d captures apart from the node PID.

## Section-by-Section Findings

### `bash-runner.md` Step 3 and Output Format (`20730c2`)

**F1 (blocking): sweep excerpts are still re-transcribed by hand, and drift.**
b2 read samples at `cut -c1-170`, re-read only some files at `cut -c1-150`, then hand-cut the remainder while typing 51 excerpt lines.
Three lines changed content: `restricts` to `restricted`, `` (`impl-N`) `` to `` (`impl-1` ... ``, and an inserted `fully`.
The prompt already says "copy that command's output exactly ... never retyped, shortened by hand", so another prohibition will not help; r6 made the same point.
The structural lever is volume and selection: when the runner may pick lines from a larger read, it transcribes rather than pastes.
Suggested fix: for aggregate specs, the excerpt must be the complete output of ONE final command, chosen so it is short enough to paste whole, for example `awk -F: 'c[$1]++ < 1' <file> | cut -c1-120 | head -n 12`.
State a hard excerpt bound (for example at most 15 lines and 120 chars each) so a full paste always fits the 4K ceiling.
If the spec asks for more samples than fit, the excerpt shows what fits and `Truncated:` carries the rest, which the contract already handles.

**F2 (blocking): Summary arithmetic is done mentally.**
b1 summed `skills/ablate` as 22; the counts in its own excerpt give 12 + 10 + 2 = 24.
The v2 rule "every name and number ... supported by the capture or by a command you ran" is the right rule, but a sum across lines is not supported by any command the runner ran.
Suggested fix: one sentence in the Summary bullet, "a total or grouped count must come from a counting command (for example `awk` or `grep -c`), not mental arithmetic; otherwise quote the per-line counts".

**F3 (blocking, folds into F1): b2's report is 6,493 chars, over the ~4K ceiling.**
The ceiling is stated once in the Output Format; nothing ties it to the excerpt's size.
The F1 hard excerpt bound makes the ceiling mechanical rather than a judgment the runner skips.

**F4 (non-blocking): composed lines inside `Excerpt:`.**
Both sweeps added a runner-written `1 each: rfp/SKILL.md, rules/...` line and heading lines (`Counts per file:`, `Sample matches (cut to 150 chars):`) inside `Excerpt:`.
The `1 each` names were correct, but the line is not a capture copy and weakens the "Excerpt is verbatim" guarantee the parent relies on.
Suggested fix: such condensations go in `Summary:`; the count block is pasted whole from the counting command (23 short lines fit easily) or cut with `head -n N` and noted under `Truncated:`.

**F5 (non-blocking): `Truncated:` precision.**
b1's list of files without samples is muddled (`propose/SKILL.md (partial)` when no line is shown), and d2 used `Truncated:` to say the build does not report skill counts, which is an absence, not an omission.
Neither is dishonest; both would be fixed if `Truncated:` named omitted items by a command (for example the files absent from the sample command's output).

### `orchestration-discipline.md` (`8d8d138`) and proposal (`bbd802f`)

No issues: the dispatch contract describes v2 accurately, and the proposal's superseded-premise NOTE and v2 NOTE are well sourced.
**F6 (non-blocking):** once F1 lands, the dispatch guidance could tell callers that sweep reports carry one sample per top file by default and that deeper samples come from the capture path, setting the parent's expectations.

### Runner scratchpad

All six runs fell back to `/tmp` (the runner's environment lists no scratchpad), and the lifetime string said so correctly.
This matches prior rounds and is non-blocking, but the dispatch guidance could note that captures persist in `/tmp` and the caller may delete them.

## Verdict

**Revise.**
Line-oriented and "summarize" specs are ready.
Aggregate specs fail in 2 of 2 runs on different criteria (fidelity and size in b2, Summary arithmetic in b1), so the failure is systematic for that spec class.
F1-F3 are one prompt change in Step 3: a single, bounded, pasted-whole sweep excerpt command plus command-derived totals.

## Action Items

1. [blocking] In `bash-runner.md` Step 3, require the aggregate-spec excerpt to be the complete output of one final bounded command (counts, then a one-sample-per-file `awk ... | cut -c1-120 | head -n N`), pasted whole with no selection; state a hard excerpt bound (for example <= 15 sample lines, <= 120 chars) that keeps the report under 4K.
2. [blocking] Add to the Summary bullet: totals and grouped counts must come from a counting command, not mental arithmetic.
3. [blocking] Re-run the two sweep canaries (b1, b2) live; a-d can be spot-checked with one run each.
4. [non-blocking] Keep composed or heading lines out of `Excerpt:` (condensations belong in `Summary:`).
5. [non-blocking] Have `Truncated:` list omitted files from a command, and not use it for things the output never contained.
6. [non-blocking] Note in the dispatch guidance that sweep reports carry about one sample per top file and that captures fall back to `/tmp`.

## Questions for the Maintainer

After seven iterations, the remaining failure is confined to aggregate sweeps. How should iteration 8 proceed?

- **(A) Bounded paste (recommended):** apply Action Items 1-3 and re-test the sweeps. This is the smallest change that makes sweep samples mechanical.
- **(B) Counts-only sweeps:** for aggregate specs the runner returns only the pasted count block plus `Truncated:` with a sample-fetch command, and no sample lines. This is the most reliable option but gives less signal per dispatch.
- **(C) Accept with documented caveat:** accept now, and document in `orchestration-discipline.md` that sweep sample lines may drift and should be confirmed against the capture before anyone relies on them. This is the fastest, but it weakens the "Excerpt is verbatim" guarantee.
