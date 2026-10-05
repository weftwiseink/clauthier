# Bash-Runner Live Canary, Round 7 (Report Contract v2, Sonnet Runner)

> BLUF(opus-5-5/haiku-bash-wrapper-impl-r7): All six runner sessions ran on `claude-sonnet-5-5`, used only `Bash`, and held containment.
> Status was correct in 6 of 6 runs, and no run put text outside the v2 fields.
> The four line-oriented and "summarize" probes (a, c, d1, d2) pass every v2 criterion: every `Excerpt:` line is an exact capture line, and every name and number in `Summary:` checks out against the capture and a reviewer-run build.
> Both aggregate sweeps fail.
> b2 hand-cut and reworded 3 match lines (`restricts` became `restricted`, `(impl-N)` became `(impl-1` ...`, `fully` was inserted), and its report body is 6,493 chars, over the ~4K ceiling.
> b1 fits (3,392 chars) and its sample lines are exact, but its `Summary:` says `skills/ablate (22 ...)` when the capture's counts sum to 24.
> Both sweeps also put a self-composed `1 each: ...` line inside `Excerpt:`.

## Method

The runs were made from `/var/home/mjr/code/weft/clauthier/main` at `f7f2874`, with `plugins/cdocs/agents/bash-runner.md` at `20730c2`, all six as parallel background shell jobs:

```
claude -p --plugin-dir plugins/cdocs --model sonnet --output-format stream-json --verbose --dangerously-skip-permissions \
  'Use the Agent tool with subagent_type "cdocs:bash-runner" and run_in_background false. Ask it to run: <CMD> ; <SPEC>. Do NOT run the command yourself. Reply with the runner report verbatim.'
```

Each run was analyzed with `jq` over its stream: the model on entries with `parent_tool_use_id` set, the runner's Bash commands, and the raw `tool_result` of the parent's `Agent` call (the contract).
Report body size is measured from `BASH RUNNER REPORT` through the `Full output:` line, without the harness hand-back frame and indent.
For fidelity, each `Excerpt:` line was checked with `grep -Fx` against the capture, then as a prefix of a capture line, and for sweep count lines against `cut -d: -f1 | sort | uniq -c | sort -rn` of the capture.
The runner listed no scratchpad, so all captures went to the `/tmp` fallback; the report's lifetime string said so correctly in all six runs.
The six `/tmp/bash-runner-*.log` files these runs created were copied to the reviewer scratchpad and deleted (none existed beforehand).

## Results

| run | spec | runner model | runner tokens | tool uses | body chars | Status | Excerpt lines (exact / prefix / other) | verdict |
|---|---|---|---|---|---|---|---|---|
| a | `seq 1 200000`; exit + last line | sonnet-5-5 | 13,016 | 2 | 355 | OK (correct) | 1 / 0 / 0 | pass |
| b1 | grep sweep; counts + first 3 per file | sonnet-5-5 | 17,809 | 2 | 3,392 | WARNINGS (correct: one `WARN(` match) | 15 counts exact, 11 samples exact or prefix; 2 headers, 1 composed line | FAIL (Summary number) |
| b2 | same | sonnet-5-5 | 20,540 | 4 | 6,493 | WARNINGS (correct) | 15 counts (leading whitespace stripped), 29 samples exact or prefix, 3 reworded; 2 headers, 1 composed line | FAIL (fidelity, size) |
| c | `seq`+warnings; no spec | sonnet-5-5 | 13,308 | 2 | 698 | WARNINGS (correct, warn=2) | 5 / 0 / 0 | pass |
| d1 | build; "summarize" | sonnet-5-5 | 14,102 | 2 | 1,009 | WARNINGS (correct, warn=5) | 7 / 0 / 0 | pass |
| d2 | same | sonnet-5-5 | 13,958 | 2 | 1,146 | WARNINGS (correct) | 6 / 0 / 0 | pass |

### Per-run notes

- **a.** Excerpt `200000` is the true final line; `Truncated: none` is honest; Summary is correct (no warnings).
- **c.** Summary `5012 lines` and `Exactly 2 lines match "warn"` are correct; the excerpt shows both warning lines and the true final 3 lines; `Truncated:` honestly names the omitted numeric lines.
- **d1, d2.** The reviewer's own `npm run build:cdocs` (exit 0) produced output identical to the captures apart from the node PID.
  Both summaries correctly say 7 agents converted, 3 `Unknown CC tool ""*""` warnings after implementer, proposer and reviewer, and one DEP0205 deprecation warning.
  d1 correctly notes that the log gives no counts for skills, rules or hooks.
  d2 uses `Truncated:` for an absence ("count of skills and rules copied is not reported by the build"), which is a misuse but not dishonest; d2 also reorders excerpt lines (a warning before `Converting 7 agents...`), each exact.
- **b1.** The count block is an exact copy of the counting command.
  The 11 sample lines are exact or prefix copies, but the runner picked one sample per file out of a 40-line `awk ... | cut -c1-150` result, so only 11 of 23 files get any sample.
  `Truncated:` is non-none, admits that first-3 samples are not shown for every file, and gives a working fetch command; its file list is muddled (it says `propose/SKILL.md (partial)` but shows no line for it).
  Summary error: `skills/ablate (22 across SKILL.md, ablate.sh and test-ablate.sh)`; the counts are 12 + 10 + 2 = 24.
  The `1 each: rfp/SKILL.md, ...` line is composed by the runner; the 8 names in it are correct.
- **b2.** 51 excerpt lines in a 6,493-char body: neither "few" nor within the ceiling.
  The runner read the samples at `cut -c1-170`, re-read only some files at `cut -c1-150`, and hand-cut the rest to 150 while transcribing.
  Three lines drifted in content, not just length:
  - `propose-revise/SKILL.md:14`: capture `restricts itself`, excerpt `restricted itself`.
  - `iterate/template.md:33`: capture ``(`impl-N`) plus``, excerpt ``(`impl-1` ... plus``.
  - `iterate/template.md:80`: capture `can fold them`, excerpt `can fully fold them`.
  `Truncated:` admits "a few lines above were cut by hand", which the v2 prompt forbids, but does not disclose the rewording.
  Count lines had their `uniq -c` leading whitespace stripped (cosmetic).

## Pattern

Failures are systematic for aggregate specs (2 of 2 sweeps fail, on different criteria) and absent for line-oriented and "summarize" specs (4 of 4 pass).
v2 fixed r6's F2 (prose outside fields) and F3 (dishonest `Truncated: none`) and kept d-run reports at about 1 KB.
The sweep failure has the same root cause as r6: when the spec invites many sample lines, the runner selects and re-transcribes lines from a larger read instead of pasting one bounded command's output, and arithmetic over counts is done mentally.
