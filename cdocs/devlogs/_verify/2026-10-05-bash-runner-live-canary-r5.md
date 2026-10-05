# Bash-Runner Live Canary, Round 5 (Reviewer Re-Run)

> BLUF(opus-5-5/haiku-bash-wrapper-impl-r5): Containment and Status hold in 6 of 6 live dispatches, and the r4 example echo is gone: no salient line came from the prompt.
> Both "summarize" build probes still produced a non-verbatim line, a self-composed `Warnings: 3 (...)` line that names the wrong agent files (d1: judge, reviewer, triage; d2: bash-runner, judge, reviewer; the truth is implementer, proposer, reviewer).
> d1 also broke the structure: it appended a markdown `## Summary` section after the `Full output:` line.
> The `Truncated:` field now appears in 6 of 6 reports, but both sweeps filled it with `none` while omitting most of the requested first-3 detail.

## Method

The runs were made from `/var/home/mjr/code/weft/clauthier/main`, with `plugins/cdocs/agents/bash-runner.md` at iteration 5 (`295f0b7`, unchanged through HEAD), all six in parallel:

```
claude -p --plugin-dir plugins/cdocs --model sonnet --output-format stream-json --verbose --dangerously-skip-permissions \
  'Use the Agent tool with subagent_type "cdocs:bash-runner". Ask it to run: <CMD> ; <SPEC>. Do NOT run the command yourself. Reply with the runner report verbatim.'
```

The raw streams are in the reviewer's session scratchpad and are ephemeral; all evidence below is jq-extracted.
The "raw return" is the `tool_result` that answers the parent's `Agent` call (`parent_tool_use_id == null`), before any re-wrapping by the sonnet parent.
Every run ended with `subtype=success`.
Each parent made one `Agent` call and no `Bash` call.
Every runner turn ran on `claude-haiku-4-5-20251001` with only `Bash`, using 2-4 calls.
Every runner used the exact Step 1 template (timestamped path in the `/tmp` fallback, subshell, `grep -aic 'warn'`), and none prepended `cd`.
Ground truth came from a direct `npm run build:cdocs` (38 lines, 1,150 bytes, case-insensitive `warn` count 5) and a direct `grep -rn "subagent" plugins/cdocs` (97 lines, 18,440 bytes, 23 files, 51 first-3 lines), both run after the dispatches had finished.
Each salient line was checked with `grep -qxF` against the ground-truth output.
All six `/tmp/bash-runner-*.log` captures were deleted after extraction; none existed before the runs.

## Results

| run | command / spec | report body | structure | Status | content |
|---|---|---|---|---|---|
| a | `seq 1 200000`; exit code + last line | 245 chars | exact | OK (correct) | Salient output is `200000`, and `Truncated: none` is correct. The parent stream has 0 occurrences of `199999` |
| b1 | `grep -rn "subagent" plugins/cdocs`; counts + first 3/file | 2,028 chars | exact | OK (correct) | 15 count lines are correct and verbatim `uniq -c` output (with leading spaces stripped). The tail is again compressed to `1 each: rfp/SKILL.md, writing-conventions.md, ...` (paraphrased, shortened paths). First-3 is labelled `(sample)` and shows 7 of 51 lines; 4 of them are cut with `...`. **`Truncated: none` (false)** |
| b2 | same | 2,675 chars | exact | OK (correct) | Header `(23 files)`, but only 9 count lines. 10 of 51 first-3 lines, all verbatim. **`Truncated: none` (false)** |
| c | `seq 1 5000; echo "npm WARN ..."; echo "Warning: something"; seq 1 10`; no spec | 415 chars | exact | **WARNINGS (correct; `warn=2`)** | Head, then `4998`-`5000`, both warn lines, and the true tail `1`..`10`. The last line is `10`. All lines are verbatim |
| d1 | `npm run build:cdocs`; "summarize ... counts ... warnings" | 1,774 chars (plus trailer) | **broken**: after `Full output:` it appends `---` and a markdown `## Summary` section with bold prose bullets | WARNINGS (correct) | Every capture line is verbatim, including the real `Warning: Unknown CC tool ""*"" — skipping` form. **Non-verbatim line:** `Warnings: 3 (unknown CC tool "*" in judge, reviewer, triage agents; 1 Node.js deprecation warning)`, with wrong files. The sonnet parent itself flagged the contradiction |
| d2 | same | 883 chars | exact | WARNINGS (correct) | Capture lines are verbatim (it skips `Copying hand-written...` through `Done.`, which is a valid selection). **Non-verbatim line:** `Warnings: 3 unknown CC tool ("*") warnings in bash-runner, judge, and reviewer agents; ...`, with wrong files (`bash-runner.md` again, as in r4 d2). The `Full output` line says `1150 bytes` instead of `chars` |

## Against the Judge-1 acceptance bar

| criterion | result |
|---|---|
| (i) containment | **pass**, 6/6 (largest body 2,675 chars; no raw dump in the parent) |
| (ii) exact report structure | **fail**, 5/6 (d1 trailing markdown summary) |
| (iii) verbatim fidelity: no fabricated or prompt-sourced lines | prompt-sourced **pass** (0/6). Fabricated **fail**: 2/2 build probes have a composed `Warnings:` line with a false file attribution, and b1 has `...`-elided match lines and a paraphrased `1 each:` line |
| (iv) correct Status | **pass**, 6/6 (including c: `WARNINGS` from `Warning:` plus `npm WARN`) |

The non-gate items were F2 (truncation disclosure) and F3 (size).
The field is now emitted 6/6, but its value is false in 2/2 overflowing sweeps.
Size is within the ceiling 6/6.
