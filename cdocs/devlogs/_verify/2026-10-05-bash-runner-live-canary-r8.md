# Bash-Runner Live Canary, Round 8 (Two-Command Aggregate Excerpt, Sonnet Runner)

> BLUF(opus-5-5/haiku-bash-wrapper-impl-r8): All seven runner sessions ran on `claude-sonnet-5-5`, used only `Bash`, and held containment: the parent's only tool call was `Agent`.
> All four aggregate sweeps (b1 and b2, twice each) pass the judge-2 bar.
> Each sweep's `Excerpt:` is the counting command's output plus the sampling command's output, both from the runner's own tool results; `97 matches across 23 files` and every per-file number in `Summary:` match the capture.
> Report bodies are 3,353-3,363 chars (b1) and 4,209-4,308 chars (b2, absolute paths): within "~4K", but the "under 4,000 by construction" claim does not hold for long paths.
> There were three cosmetic slips, each in a different run and none changing content: b1b wrapped `Excerpt:` in a code fence, b2b added one character (`use the T`, still a true prefix of the capture line), and c inserted a `...final lines of the capture:` label.
> The a, c and d1 spot-checks pass; d1's capture is identical to a reviewer-run build apart from the node PID.

## Method

The runs were made from `/var/home/mjr/code/weft/clauthier/main` at `b3dda8d`, with `plugins/cdocs/agents/bash-runner.md` at `c17ad00`, as seven parallel background shell jobs:

```
claude -p --plugin-dir plugins/cdocs --model sonnet --output-format stream-json --verbose --dangerously-skip-permissions \
  'Use the Agent tool with subagent_type "cdocs:bash-runner" and run_in_background false. Ask it to run: <CMD> ; <SPEC>. Do NOT run the command yourself. Reply with the runner report verbatim.'
```

Each stream was analyzed with `jq`.
The runner model and tools come from the entries with `parent_tool_use_id` set.
The runner's Bash commands and their raw `tool_result`s were extracted too.
The contract is the parent `Agent` call's raw `tool_result`.
Body size runs from `BASH RUNNER REPORT` through the `Full output:` line, after the 2-space harness indent is stripped.
Fidelity was checked per `Excerpt:` line in four ways:
- `grep -Fx` against the capture.
- A prefix check against a capture line, for lines cut with `cut -c1-120`.
- An exact `diff` of the sample block against the runner's own sampling command, re-run on the capture.
- An exact `diff` of the count block against `cut -d: -f1 | sort | uniq -c | sort -rn | head -n 20 | cut -c1-120`.
All seven captures fell back to `/tmp`, and each report's lifetime string said so.
They were copied to the reviewer scratchpad and then deleted; no `/tmp/bash-runner-*.log` existed before the runs.

## Results

| run | spec | runner tokens | tool uses | body chars | Status | Excerpt lines | fidelity | verdict |
|---|---|---|---|---|---|---|---|---|
| a | `seq 1 200000`; exit + last line | 13,415 | 1 | 358 | OK (correct) | 1 | 1 exact (`200000`, true final line) | pass |
| b1a | relative sweep; counts + first 3 per file | 19,525 | 4 | 3,363 | WARNINGS (correct, warn=1) | 20 counts + 12 samples | counts identical to command; samples identical to `awk c<1 \| cut -c1-120 \| head -n 12` | pass |
| b1b | same | 16,418 | 2 | 3,353 | WARNINGS (correct) | 20 + 12, plus 2 fence lines | counts identical; samples identical to `awk c<3 \| cut -c1-120 \| head -n 12` | pass (cosmetic: fence) |
| b2a | absolute sweep; same spec | 17,848 | 3 | 4,308 | WARNINGS (correct) | 20 + 12 | counts identical apart from stripped `uniq -c` leading spaces; samples identical | pass |
| b2b | same | 18,572 | 3 | 4,209 | WARNINGS (correct) | 20 + 12 | counts identical apart from leading spaces; 11 samples identical, 1 has an extra char (`use the T`), still a capture prefix | pass (cosmetic) |
| c | `seq`+warnings; no spec | 13,713 | 2 | 589 | WARNINGS (correct, warn=2) | 6 | 5 exact; 1 composed label | pass (cosmetic: label) |
| d1 | build; "summarize" | 14,591 | 2 | 1,123 | WARNINGS (correct, warn=5) | 6 | 6 exact | pass |

### Summary checks (criterion iii)

- **All sweeps:** `97 matches across 23 files` is right: the capture has 97 lines and `cut -d: -f1 | sort -u | wc -l` gives 23. Every runner computed both numbers with a command (r7 F2 closed).
- **Top counts** in b1b and b2b (12, 12, 11, 10) and the files named in b1a and b2a are correct.
- **The one `warn` hit** is the `WARN(...)` line in `skills/ablate/SKILL.md`, as all four sweeps say.
- **Dropped count lines:** b2a names the 3 files the counting command dropped (`agents/proposer.md`, `agents/judge.md`, `agents/implementer.md`), and they are right. b1a and b1b describe them correctly ("3 files with 1 match each"), and b1b names 2 of the 3.
- **d1:** 7 agents (all named), 3 `Unknown CC tool ""*""` warnings after implementer, proposer and reviewer, and 2 DEP0205 lines. "The log doesn't report counts for skills or rules" is put in `Summary:`, as the contract now requires. All of this is correct.
- **c:** `5012 lines` and 2 warning lines are correct; the excerpt includes the true final lines `8`, `9`, `10`.

### Truncated checks (criterion vi)

Every sweep's `Truncated:` is non-none and honest.
Each states that 3 count lines, the samples for 11 of 23 files, and matches 2-3 were omitted, and that lines were cut at 120 characters.
Each `see:` command runs correctly over the capture.
b1b's "files after orchestration-discipline.md in path order" is imprecise, since the capture is in `grep -r` traversal order and not path order.
b2b's parenthetical about `agents/reviewer.md` is muddled.
Neither is dishonest.
b2a also notes that the first-seen sample order leaves out the four top-count files.

### Observations

- **Two-command construction followed in 4/4 sweeps.** The runners ran the counting command, a `sort -u | wc -l` total, and one sampling command, then pasted the outputs.
- **Contract deviation in b1b.** It sampled with `c[$1]++ < 3 | head -n 12`, which gives 3 samples for the first 4-5 files. The contract says to fall back to 1 per file when 3 per file does not fit. The output was still pasted whole and the deviation was disclosed.
- **Capture order differs between runs.** The two relative-path captures have the same content in a different order, and so do the two absolute-path captures. So "first 12 files" varies from run to run. This is expected for `grep -r` and harmless.
- **Size.** Absolute-path sweeps reach about 4.3K. Twelve 120-char samples plus 20 count lines of about 90 chars is about 3.3K of excerpt, and Summary and Truncated push it past 4K. The ceiling is approximate, but "by construction" overstates it.
