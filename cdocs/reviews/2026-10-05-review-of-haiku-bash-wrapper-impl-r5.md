---
review_of: cdocs/proposals/2026-09-22-haiku-bash-wrapper.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T09:31:31-07:00
task_list: meta/token-spend-attribution
type: review
state: live
status: done
tags: [fresh_agent, implementation, rereview, live_canary, haiku_compliance, report_contract, fidelity, escalation_recommended]
---

# Review: Haiku Bash-Output Wrapper, Implementation Round 5 (Phases 1-2)

> BLUF(opus-5-5/haiku-bash-wrapper-impl-r5): **Revise, and escalate to the maintainer rather than run iteration 6.**
> The r4 blocker is closed: no prompt-sourced lines appear (0/6), and containment and Status hold 6/6.
> But the Judge-1 bar fails on two criteria in the "summarize" build probes.
> (iii) Fidelity: 2/2 runs composed their own `Warnings: 3 (...)` line that names the wrong agent files.
> (ii) Structure: d1 appended a markdown `## Summary` after the `Full output:` line.
> With the example removed, the fabrication comes from haiku itself. This is a new mechanism of the fidelity class, and one more wording round is unlikely to close it.

## Summary Assessment

Iteration 5 (`295f0b7..12baa90`) makes three changes:
- it replaces the filled example with abstract placeholders and adds "never from this prompt";
- it makes the `warn=` count case-insensitive;
- it moves overflow disclosure into a mandatory `Truncated:` field.

Step 2 (internal reading) is byte-identical to r4, so the maintainer constraint holds.
Live, F1 (example echo) and F4 (Status) are closed, and the `Truncated:` field is emitted 6/6.
Even so, the acceptance bar is not met: both build probes contain a fabricated interpretive line, and one build probe breaks the report structure.
Verdict: **Revise**, with a recommendation to escalate per Judge-1's rule.

## Verification

Evidence: [`cdocs/devlogs/_verify/2026-10-05-bash-runner-live-canary-r5.md`](../devlogs/_verify/2026-10-05-bash-runner-live-canary-r5.md), from six live dispatches. The checks use the runner's raw `tool_result`, and every salient line was checked with `grep -xF` against a direct run of the same command.

- **Floor (smoke): pass.**
  The agent loads, the runner runs on `claude-haiku-4-5-20251001` with `Bash` only in 2-4 calls, and no run hits `maxTurns`.
  `seq 1 200000` returns `Exit code: 0`, `Status: OK`, and the true last line `200000` in a 245-char body.
  The parent stream has no `199999`.
- **(i) Containment: pass, 6/6.** The largest body is 2,675 chars.
- **(ii) Structure: 5/6.** d1 appended `---`, `## Summary`, and bold prose bullets after `Full output:`.
- **(iii) Fidelity.**
  - Prompt-sourced lines: pass, 0/6. The real `Warning: Unknown CC tool ""*"" — skipping` form was copied correctly in both d runs.
  - Fabricated lines: fail.
    d1 wrote `Warnings: 3 (unknown CC tool "*" in judge, reviewer, triage agents; ...)`.
    d2 wrote `... in bash-runner, judge, and reviewer agents; ...`.
    In the real output the warnings follow `implementer.md`, `proposer.md`, and `reviewer.md`.
    b1 also cut 4 match lines with `...` and compressed 8 files into `1 each: rfp/SKILL.md, ...`.
- **(iv) Status: pass, 6/6.**
  Canary c returns `WARNINGS` with `warn=2` and true last line `10`.
  The build probes return `WARNINGS` with `warn=5`.

## Prior Action Items

| r4 item | status |
|---|---|
| 1 [blocking] remove the build-like example, re-run d1/d2 | **Addressed** for echo: no example content appears in either run. The underlying fidelity risk remains (F1 below) |
| 2 `Truncated:` template field | **Partly addressed.** Emitted 6/6, but `none` in both overflowing sweeps (false) |
| 3 case-insensitive `warn=` | **Addressed** (c and d) |
| 4 optional tighter self-check | **Addressed** ("nothing comes from this prompt") |

## Section-by-Section Findings

### `bash-runner.md` Output Format: "summarize" guidance

**F1 [blocking]: the runner fabricates an interpretive count line in 2/2 "summarize" runs.**
The new sentence "For a 'summarize' spec, the salient output is a few counts (for example `<pattern> lines: <n>`)..." licenses a non-capture line.
Haiku fills that slot with a prose summary carrying a guessed attribution: it pairs each warning with the wrong neighbouring agent filename, and the guess differs between runs.
A dispatcher reads this line as the summary the spec asked for, so it is exactly the silent false attribution r4 F1 warned about.
This time it comes from haiku itself, not from the prompt.
The verbatim capture lines in the same reports are correct, so the failure is confined to the one sentence the runner is allowed to compose.

This is the mechanism to escalate on.
r3 (fence and drift), r4 (example echo), and r5 (self-composed attribution) each closed the previous shape of the same "summarize" weakness and exposed a new one.

**F2 [blocking, recurrence of the r3 class]: d1 emitted content after the final line.**
The plain-text and self-check rules held 5/5 in r4 and 5/6 here.
The break is again on a "summarize" spec: haiku added the summary prose it was told not to write, after the report.

### `bash-runner.md` Step 3: `Truncated:` field

**F3 [non-blocking, not a gate]: `Truncated: none` is false in both overflowing sweeps.**
Moving disclosure into the template fixed emission (0/4 in r3-r4, 6/6 now).
But b1 returned 7 of 51 first-3 lines and b2 returned 10 of 51, plus 9 of 23 count lines, and both said `none`.
A false `none` is worse than a missing line, because it asserts completeness.
The `Full output` path still allows recovery.
A mechanical cue would help, for example "if you returned fewer lines than your read produced, `Truncated` is not `none`".

**F4 [non-blocking]: residual sweep paraphrase.** b1's `1 each: ...` with shortened paths and its `...`-cut match lines persist from r3 and r4.

### Maintainer constraint

No finding.
The Step 2 text is unchanged since r4, and the runners read freely (`cat`, a combined counts plus first-3 read, `grep -ain`).
None of the remedies below re-tighten internal reading.

### Docs

The `Truncated:` field is consistent across the agent, the proposal output contract (`4e849f9`), and `orchestration-discipline.md` (`bec3e79`).
No stale `spec truncated` text remains.

## Verdict

**Revise.** Judge-1's bar fails on (ii) and (iii), so the round is not acceptable as is.
Because F1 is a new mechanism of a blocking haiku-compliance class that has moved with each wording fix since r3, I recommend that the overseer **escalate to the maintainer** instead of running iteration 6.

## Action Items

1. [blocking] Remove the runner's licence to compose summary lines.
   Either allow only bare `<label>: <n>` counts whose number comes from a `grep -c`/`wc` the runner ran (no parentheses, no file names, no prose), or drop the "summarize" sentence entirely.
2. [blocking] Re-run d1/d2 (and ideally 2 more "summarize" probes) to confirm 0 non-verbatim lines and exact structure.
3. [non-blocking] Make a false `Truncated: none` less likely with a mechanical cue (returned fewer lines than read means not `none`).
4. [non-blocking] Dispatch guidance in `orchestration-discipline.md`: prefer selection specs ("the warning lines plus the final summary block") over "summarize/describe" specs.

## Questions for the Maintainer (escalation)

1. How should the "summarize"-spec fidelity weakness be handled?
   - (a) Runner-side: forbid composed lines except bare counts (action item 1), and accept after one confirming re-run.
   - (b) Dispatcher-side: steer dispatchers away from "summarize" specs in `orchestration-discipline.md`, and accept with a documented caveat that any non-capture line is untrusted.
   - (c) Both (a) and (b). This is the reviewer's preference.
   - (d) Raise the runner tier for interpretive specs. This conflicts with the haiku premise.
2. Does a false `Truncated: none` on overflowing sweeps block acceptance, or stay a follow-up, as F2/F3 were under Judge-1?
