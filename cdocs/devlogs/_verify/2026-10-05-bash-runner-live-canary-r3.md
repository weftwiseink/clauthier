# Bash-Runner Live Canary, Round 3 (Reviewer Re-Run)

> BLUF(opus-5-5/haiku-bash-wrapper-impl-r3): Containment holds in all six live dispatches: the `seq 1 200000` canary returns the true last line `200000` in a 229-char report, and no raw dump reaches any parent.
> Relaxed reads work as intended: haiku reads small captures whole and aggregates sweeps in 2-3 calls, with no spill.
> The report contract does NOT hold under a "summarize" spec: both build probes (d, d2) broke the fixed format, and d2 dropped the mandatory `Full output: saved to` line entirely.
> Both sweep probes (b, b2) omitted the mandatory `[spec truncated: ...; see capture file: <cmd>]` line, and b's report body was 3,646 chars against the ~2,000 guidance.

## Method

The runs were made from `/var/home/mjr/code/weft/clauthier/main` at HEAD `d14fb02` (iteration 3, `2544f98..2578907`).
a, b, c, and d ran in parallel, and d2 and b2 ran afterwards as a variance pair:

```
claude -p --plugin-dir plugins/cdocs --model sonnet --output-format stream-json --verbose --dangerously-skip-permissions \
  'Use the Agent tool with subagent_type "cdocs:bash-runner". Ask it to run: <CMD> ; <SPEC>. Do NOT run the command yourself. Reply with the runner report verbatim.'
```

The raw streams are in the reviewer's session scratchpad and are ephemeral.
Evidence below is jq-extracted only.
`TOOL[runner]` means `parent_tool_use_id` was set.
Every run ended with `subtype=success` and `num_turns=2`.
The `init` event lists `cdocs:bash-runner`, and every runner turn ran on `claude-haiku-4-5-20251001`.
No runner used a tool other than `Bash`, and no parent ran the command itself (one `Agent` call per run).
All six `/tmp/bash-runner-*.log` captures were deleted after extraction.
The runner used the `/tmp` fallback in every run, as in r2.

## Results

The "parent" size is the tool_result the parent received, including about 600 chars of harness hand-back framing and usage.

| run | runner calls | runner result chars | parent result | outcome |
|---|---|---|---|---|
| a containment | capture; `tail -n 1` | 85, 6 | 951 | PASS: `200000`, Status OK, exact format, `grep -c 199999 a.jsonl` = 0 |
| b grepsweep | capture; `cut\|sort\|uniq -c`; `awk 'c[$1]++<3' \| head -n 70` | 79, 1064, 9559 | 4406 (body 3,646) | counts exact (23 files, 97 matches, verified); only 10 of 23 files' first-3 shown; truncation line `[…first 3 per file truncated for brevity; full output below]` has no command |
| b2 grepsweep | same shapes, `head -n 60` | 79, 1064, 9559 | 3458 | counts exact; 9 detail lines, several cut with `...` (not verbatim); no truncation line at all; report wrapped in a code fence |
| c warnings, no spec | capture; `grep -anE 'warn\|WARN'`; `tail -n 15` | 81, 32, 68 | 1104 | PASS: `Status: WARNINGS`, warn line present, true last line `10`, exact format |
| d build, "summarize" spec | `npm run build:cdocs > /tmp/bash-runner-build.log ...` (no subshell, fixed path, no `warn=`); `cat` | 26, 1141 | 1898 | facts correct; paraphrased lines, fenced report, then a `**Summary:**` paragraph after it |
| d2 build, same spec | capture with `cd <repo> &&` prepended; `cat` | 78, 1141 | 1750 | facts correct; NO `BASH RUNNER REPORT` structure, NO `Full output: saved to` line, markdown headings, `✓` glyph |

## Build quality comparison (d, d2)

The reviewer ran `npm run build:cdocs` separately.
It exits 0, prints 1,149 bytes in 38 lines, and gives `warn=1` under the runner's `grep -acE 'warn|WARN'`.
The salient lines are `Converting 7 agents...`, three `Warning: Unknown CC tool ""*"" — skipping` lines (after implementer, proposer, and reviewer), `Agents converted: 7`, and a Node `[DEP0205] DeprecationWarning`.
The runner's capture in d matches this output byte for byte, apart from the node PID.

- **Accuracy:** both reports state the facts correctly: 7 agents, 3 unknown-tool warnings, 1 deprecation warning, and the output dir.
  d labels "Warnings (3 total)" but then counts 4 in its prose summary.
- **Fidelity:** neither report is verbatim.
  d shows lines like `Warning: Unknown CC tool ""*"" — skipping (in 3 agents)` and `Skills copied, rules copied, hooks plugin copied (cdocs-hooks.ts)`.
  d2 is entirely a markdown summary.
- **Read efficiency:** this improves on r2.
  A 1,149-byte capture is read whole in one call, where the r2 fixed suffix would have needed several `head -n 10` slices.

## Haiku compliance tally

| rule | pass | fail |
|---|---|---|
| Step 1 capture form (subshell, unique path, `warn=`) | a, b, b2, c | d (fixed path, no subshell, no `warn=`) |
| Command verbatim | a, b, b2, c, d | d2 (prepended `cd <repo> &&`) |
| Fixed-format report, nothing else | a, b, c | b2 (fence), d (fence + summary), d2 (no structure) |
| `Full output: saved to` line | a, b, b2, c, d | d2 |
| Verbatim salient lines | a, c | b2, d, d2 |
| Mandatory follow-up command on overflow | (none) | b, b2 |
| True last line kept | a, c | n/a |
