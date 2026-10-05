# Bash-Runner Live Canary, Round 4 (Reviewer Re-Run)

> BLUF(opus-5-5/haiku-bash-wrapper-impl-r4): Containment holds in all five live dispatches, and r3 F1 is closed. Every raw runner return is plain text: it starts with `BASH RUNNER REPORT`, ends with the `Full output: saved to` line, and has no fence and nothing before or after.
> A new fidelity failure appears instead. In d2, haiku copied the filled example's `Warning: Unknown CC tool "*" in <file>.md` form, which does not occur in the real build output, and it named the wrong file (`bash-runner.md`, which has `tools: Bash`).
> The `[spec truncated: ...]` line was again missing in 2 of 2 sweeps, and b1's report body was 5,615 chars, over the ~4,000 ceiling.

## Method

The runs were made from `/var/home/mjr/code/weft/clauthier/main` at HEAD `5c781d2` (iteration 4, `6d773d2..df03c9b`), with all five in parallel:

```
claude -p --plugin-dir plugins/cdocs --model sonnet --output-format stream-json --verbose --dangerously-skip-permissions \
  'Use the Agent tool with subagent_type "cdocs:bash-runner". Ask it to run: <CMD> ; <SPEC>. Do NOT run the command yourself. Reply with the runner report verbatim.'
```

The raw streams are in the reviewer's session scratchpad and are ephemeral, and all evidence below is jq-extracted.
The "raw return" is the `tool_result` that answers the parent's `Agent` call (`parent_tool_use_id == null`), which is the runner's real contract, before any re-wrapping by the sonnet parent.
Every run ended with `subtype=success` and `num_turns=2`.
Each parent made one `Agent` call and no `Bash` call.
Every runner turn ran on `claude-haiku-4-5-20251001` using only `Bash`, with 2-3 calls per run.
Every runner used the exact Step 1 template, with a timestamped path in the `/tmp` fallback, the subshell, and `warn=`, and none prepended `cd`.
All five `/tmp/bash-runner-*.log` captures were deleted after extraction; none existed before the runs.

## Results

| run | command / spec | raw report body | structure | content |
|---|---|---|---|---|
| a | `seq 1 200000`; exit code + last line | 243 chars | exact | `Exit code: 0`, `Status: OK`, salient `200000`. The parent stream has 0 occurrences of `199999` |
| b1 | `grep -rn "subagent" plugins/cdocs`; counts + first 3/file | **5,615 chars** | exact | Counts are correct (23 files, 97 matches). The tail is compressed to `1 each: rfp/SKILL.md, writing-conventions.md, ...` (paraphrased, shortened paths). First-3 does not cover every file. **No `[spec truncated]` line** |
| b2 | same | 2,084 chars | exact | 13 files listed, then `(9 more files with 1-2 matches each)`, the exact paraphrase the prompt forbids. First-3 is labelled `(sample)`. **No `[spec truncated]` line** |
| d1 | `npm run build:cdocs`; "summarize ... counts ... warnings" | 680 chars | exact | Mostly real lines, with two problems: the quotes in `""*""` are normalized to `"*"`, and `Agents converted: 7` is moved under the `Starting` line. Does not echo the example |
| d2 | same | 577 chars | exact | **Fabricated lines**: `Warning: Unknown CC tool "*" in bash-runner.md`, `... in implementer.md`, `... in reviewer.md`. The deprecation line is paraphrased: `Deprecation: module.register() deprecated (use module.registerHooks() instead)` |

## Example-echo check (e)

The reviewer ran `npm run build:cdocs` directly (exit 0).
The real warning lines are `  Warning: Unknown CC tool ""*"" — skipping`, three times, each printed after the file it belongs to: `implementer.md`, `proposer.md`, and `reviewer.md`.
These are the three agents with `tools: "*"`.
No line of the form `... in <file>.md` exists in the real output.

The agent prompt's filled example contains `Warning: Unknown CC tool "*" in reviewer.md`, `... in implementer.md`, and `Agents converted: 7`.
d2's runner `cat`-ed the full 38-line capture, then produced the example's line form.
It kept the example's two file names and added `bash-runner.md` as a third (wrong: `tools: Bash`), dropping `proposer.md`.
So d2 reported content shaped by the example, not by its own capture, and it gives the parent a false attribution presented as verbatim output.
d1 is not an echo: its warning lines carry the real `— skipping` suffix.
`Agents converted: 7` matches both the example and the real build, so it cannot discriminate.

## Status classification (incidental)

On the real build capture, `grep -acE 'warn|WARN'` returns `1`.
The one match is node's footnote line `(Use \`node --trace-deprecation ...\` to show where the warning was created)`.
The three `Warning:` lines match neither `warn` nor `WARN`, because the pattern is case-sensitive, and `grep -aci warn` returns `5`.
The `WARNINGS` status in d1/d2 is therefore correct only by accident: a build whose only warnings are `Warning:` lines would report `Status: OK`.

## Parent re-wrapping (informational)

Parent behaviour is outside the runner's contract, but for the record: in a, b2, and d2 the sonnet parent replied with the report verbatim.
d1's parent wrapped it in a code fence.
b1's parent appended its own critique bullets.
