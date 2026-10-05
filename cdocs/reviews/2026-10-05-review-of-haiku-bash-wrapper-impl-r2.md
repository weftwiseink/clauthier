---
review_of: cdocs/proposals/2026-09-22-haiku-bash-wrapper.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T09:16:00-07:00
task_list: meta/token-spend-attribution
type: review
state: live
status: done
tags: [fresh_agent, implementation, rereview, haiku_compliance, live_canary, prompt_robustness]
---

# Review: Haiku Bash-Output Wrapper, Implementation Round 2 (Phases 1-2)

> BLUF(opus-5-5/haiku-bash-wrapper-impl-r2): **Accept.** r1's blocking F1 is closed with live evidence.
> Across 4 fresh haiku dispatches, every runner extraction call ends in the exact `| cut -c1-150 | head -n 10` suffix, and the largest runner-internal result is 1,453 chars (r1 had 2,671 and 3,988).
> The containment canary passes, and the r1 non-blocking items 2-6 are all applied.
> The haiku format drift that remains is small and non-blocking.

## Summary Assessment

The fix commits (`a8a3684..31dc86e`) rewrite Step 2 of `bash-runner.md` as a "Fixed suffix rule".
Every example now obeys the suffix literally, and a compliant replacement stands in for the `cat` ban.
The commits also add an aggregate-overflow rule, a conditional capture-lifetime phrase, and a deterministic `warn=` count.
The dispatch contract, AGENTS.md, and the proposal NOTEs are updated to match.
Live re-runs confirm that haiku now follows the bound.
The prompt fix took effect, since every shape haiku used is copied from the example list.
The leftover drift is formatting only: one 11-line report, one truncation line without a command, a relative path made absolute, and a tail trimmed by one line.
None of it threatens containment or cap safety.
Verdict: **Accept**.

## Verification

Evidence: [`cdocs/devlogs/_verify/2026-10-05-bash-runner-live-canary-r2.md`](../devlogs/_verify/2026-10-05-bash-runner-live-canary-r2.md), jq-extracted from four parallel `claude -p --plugin-dir plugins/cdocs --model sonnet` runs at HEAD `c09330c`.

| run | runner results (chars) | parent result | outcome |
|---|---|---|---|
| a containment `seq 1 200000` | 85, 6 | 965 | `200000`, Status OK, no raw dump in the stream (`confirmed`) |
| b1 grep sweep | 79, 489, 1375 | 2001 | bound OK; 11 salient lines; truncation line has no command |
| b2 grep sweep (variance) | 79, 879, 1453 | 1969 | bound OK; 9 counts + 1 `[spec truncated: ...; see awk ... <cap>]`, exact format |
| c warnings, no spec | 81, 32, 20 | 1098 | `Status: WARNINGS`, warn line first |

- The agent definition loads.
  The runner model is `claude-haiku-4-5-20251001`, and it uses only `Bash`.
- Every runner extraction call ends in the exact fixed suffix (9 of 9 calls).
- The parent made exactly one `Agent` call per run and never ran the command itself.
- All four `/tmp/bash-runner-*.log` captures from these runs were deleted after extraction.

## r1 Action Items: Disposition

1. **[blocking] F1 extraction bound.** **Resolved.**
   The "Fixed suffix rule" says "never raise the 10, never raise the 150, never drop either stage", and all 8 shapes carry the suffix.
   Live, the maximum result is 1,453 chars against the target of about 1,500.
2. **Aggregate overflow rule.** **Resolved.**
   b2 follows it exactly.
   b1 follows it loosely (see N1).
   The `orchestration-discipline.md` dispatch contract has the matching "counts plus top few files" sentence.
3. **Lifetime phrase.** **Resolved.**
   All four reports print `/tmp, persists until reboot; caller may delete`.
4. **Proposal NOTE and Q4 qualifier.** **Resolved.**
   The edge case and the maintainer decision both carry the `${TMPDIR:-/tmp}` fallback, with an attributed `NOTE(opus-5-5/impl-1)`.
   Q4 reads "(carried to the RFP, not shipped)".
   The word "now" is gone from Q2.
5. **Deterministic WARNINGS.** **Resolved.**
   The Step 1 echo prints `warn=`, and run c classifies `WARNINGS` correctly.
6. **AGENTS.md entry.** **Resolved.**
   The line matches the house style of the neighbouring entries and cross-references "Bash Output Hygiene".

## Diff-Wide Consistency (`60979d9^..HEAD`)

The agent, rule section, model-tiering carve-out, README, AGENTS.md, and proposal agree on four points:

- haiku tier
- `Bash`-only
- capture-to-file
- no shipped cap: no `bashOutputMaxChars` value appears outside the RFP pointer and the "carried to the RFP" qualifier

No regressions were found.
The writing conventions hold: sentence-per-line, colons over em-dashes, attributed NOTE callouts, and a history-agnostic agent prompt.

## Section-by-Section Findings (new, all non-blocking)

**N1 [non-blocking] Haiku still drifts on the overflow format (b1).**
b1 output 5 count lines, 5 match lines, and a truncation line, which is 11 salient lines against "never exceed 10".
Its truncation line says only "see capture file", with no ready-to-run command.
It also shows only 5 of the 10 extracted counts, even though the rule says counts come first.
b2, from the same prompt, was exact, so this is run-to-run variance and not an ambiguous prompt.
The cost is one extra line of about 150 chars.
Optional fix: in Step 3, phrase it as "at most 9 extract lines plus the truncation line" and make the example command mandatory (`see capture file: <cmd>`).

**N2 [non-blocking] The command was not run verbatim (b2).**
The runner rewrote `plugins/cdocs` to an absolute path inside the capture subshell.
That is equivalent in this case, because the cwd matches.
It still breaks "the exact command, verbatim" and "never run it in a modified form", and a rewrite like this could change semantics for commands that depend on cwd or globs.
Optional: add an explicit "do not rewrite paths or arguments" clause next to the verbatim instruction.

**N3 [non-blocking] The default-heuristic tail can lose the true last line (c).**
To fit 10 lines, the runner kept `1..9` of the tail and dropped the actual last line, `10`, without adding a `[... N more]` marker.
For a pass/fail command the final line is often the summary, which is exactly what the caller wants.
Optional: in the no-spec heuristic, say that when trimming the tail, keep its LAST lines.

**N4 [non-blocking, carried] `/tmp` accumulation under `claude -p`.**
Five pre-existing `bash-runner-*.log` files are still in `/tmp`, from r1-era runs that this reviewer did not create.
This is accepted per the proposal NOTE and Q-B (a).
The rule is unchanged, but this is a reminder for the cap RFP and the runner-composition follow-up.

## Verdict

**Accept.**
The blocking finding is resolved with live evidence, the smoke floor passes, and the remaining issues are non-blocking haiku format variance.

## Action Items

1. [non-blocking] Tighten the Step 3 overflow rule: at most 9 extract lines plus the truncation line, with the ready-to-run command mandatory (N1).
2. [non-blocking] Add "do not rewrite paths or arguments" next to the verbatim-command instruction (N2).
3. [non-blocking] In the no-spec heuristic, when trimming the tail, keep its final lines (N3).

## Questions for the Maintainer

- **Q-A: fold N1-N3 into this arc or defer?** (a) Defer to a later polish pass, since none of them affects containment. (b) Apply them as a quick follow-up commit without another review round. (c) Apply them and re-run the canary.
  The reviewer leans toward (a) or (b).
