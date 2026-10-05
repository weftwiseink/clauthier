# Bash-Runner Live Canary, Round 6 (Reviewer Re-Run, Sonnet Runner)

> BLUF(opus-5-5/haiku-bash-wrapper-impl-r6): All six runner sessions ran on `claude-sonnet-5-5`, used only `Bash` (2 calls each), and held containment: no raw dump reached the parent, and `seq 1 200000` returned the true last line `200000` in a 261-byte report.
> Status was correct in 6 of 6 runs.
> The fidelity gate fails in both aggregate sweeps.
> b1 and b2 returned 8.6-10.0 KB reports in which several match lines were reworded, not just cut.
> These include `Run an indicated...`, `peer to /cdocs:iterate`, `rev-N` changed to `rev-2`, and one silently dropped clause that the `Truncated:` field does not disclose.
> The structure gate fails in both "summarize" build probes: d2 appended a prose `Summary:` paragraph after `Full output:`, and d1 put prose in `Truncated:`.
> Both d runs also dropped the capture's true final line while saying `Truncated: none`.
> The haiku-era fabricated warning attribution is gone: sonnet's attributions are correct.

## Method

The runs were made from `/var/home/mjr/code/weft/clauthier/main` at `164a043`, with `plugins/cdocs/agents/bash-runner.md` at `f345ddb` (`model: sonnet`), all six as parallel background shell jobs:

```
claude -p --plugin-dir plugins/cdocs --model sonnet --output-format stream-json --verbose --dangerously-skip-permissions \
  'Use the Agent tool with subagent_type "cdocs:bash-runner". Ask it to run: <CMD> ; <SPEC>. Do NOT run the command yourself. Reply with the runner report verbatim.'
```

The raw streams are in the reviewer's session scratchpad and are ephemeral; all evidence below was extracted with `jq`.
The "raw return" is the `tool_result` that answers the parent's `Agent` call (`parent_tool_use_id == null`).
For b2, the parent's `Agent` call came back as an async launch: its `tool_result` was the "Async agent launched" metadata, and the report arrived through a `task_notification`.
b2's report below is therefore the runner's final assistant text.
Every parent made exactly one `Agent` call and no other tool call.
Every runner turn (`parent_tool_use_id` set) reported `.message.model == "claude-sonnet-5-5"`.
Every runner used the exact Step 1 template (a timestamped path in the `${TMPDIR:-/tmp}` fallback, a subshell, and `grep -aic 'warn'`), did not prepend `cd`, and made one Step 2 read call.
Ground truth came from the runners' own capture files, which were checked before deletion, and from the build script source.
b1 and b2 salient match lines were checked with `grep -qxF` against the capture; a line counts as cut when it is a strict prefix of a real line.
No `/tmp/bash-runner-*.log` existed before the runs, and the six captures were deleted after extraction.

## Results

| run | command / spec | report body | structure | Status | content |
|---|---|---|---|---|---|
| a | `seq 1 200000`, exit + last line | 261 B | exact | OK (correct) | `200000`, true last line; `Truncated: none` honest |
| b1 | `grep -rn subagent`, counts + first 3/file | 10,013 B | extra `Note:` prose line in body | WARNINGS (correct, 1 `WARN(` content hit) | 23/23 count lines exact; 51 first-3 lines, 13 prefix-cut at 220 chars, **4 replaced by non-verbatim placeholders**, 2 of which carry words absent from the line (`Run an indicated...`, `peer to /cdocs:iterate`; the real line says `/cdocs:implement`); `Truncated:` says "three" placeholders, but there are four |
| b2 | same | 8,642 B | extra `Warn line` prose | WARNINGS (correct) | 23/23 count lines exact; **silent edits**: `iterate/SKILL.md:3` drops "as the overseer", `template.md:35` changes `rev-N` to `rev-2`, `propose-revise/SKILL.md:14` drops "and restricts itself to orchestration" (**not disclosed** in `Truncated:`); 2 lines replaced by `- (see Truncated)` |
| c | warn mix, no spec | 407 B | exact | WARNINGS (correct; capture warn=2) | warn lines carry a `5001:`/`5002:` `grep -n` prefix (not capture text); tail `6`-`10`, true last line `10` |
| d1 | build, "summarize ... counts ... warnings" | 1,153 B | **prose in `Truncated:`** | WARNINGS (correct) | 22 copied lines, all verbatim, attributions correct; true last line `(Use \`node --trace-deprecation ...\`...)` **omitted** while saying `Truncated: none` |
| d2 | same | 1,410 B | **`Summary:` paragraph after `Full output:`** | WARNINGS (correct) | same copied lines as d1, all verbatim; the summary tallies "3 ... warnings" and "1 Node DEP0205" itself (correct, but a self-composed count); true last line omitted, `Truncated: none` |

The build ground truth is 38 lines and 1,150 bytes, with exit 0.
`implementer.md`, `proposer.md`, and `reviewer.md` declare `tools: "*"`, and `scripts/build-opencode.ts` prints the file name before the `Unknown CC tool` warning, so the d-run attributions are correct.
The sweep ground truth is 97 lines and 18,440 bytes, with 23 files and 51 first-3 lines.

## Cost and size

`subagent_tokens` comes from the parent's `Agent` tool result (`tool_use_result.totalTokens`, which matches the runner's final-turn usage).
Session cost is the whole headless session (parent plus runner, both `claude-sonnet-5-5`), from the `result` event's `total_cost_usd`.

| run | runner subagent_tokens | runner final-turn output tokens | runner duration | session cost (USD) | parent tool_result size (with hand-back frame) |
|---|---|---|---|---|---|
| a | 12,834 | 116 | 3.9 s | 0.113 | 932 B |
| b1 | 21,659 | 4,479 | 23.8 s | 0.232 | 10,685 B |
| b2 | 21,400 (notification) | n/a (async) | 25.1 s | 0.216 | 1,073 B launch stub, then an 8.6 KB report via notification |
| c | 13,073 | 191 | 6.6 s | 0.106 | 1,078 B |
| d1 | 13,824 | 492 | 6.0 s | 0.125 | 1,824 B |
| d2 | 14,088 | 596 | 6.8 s | 0.060 | 2,081 B |

The sweeps carry most of the cost: they emit 4-5K output tokens, almost all spent re-typing long match lines, and the transcription drift occurs in that re-typing.
