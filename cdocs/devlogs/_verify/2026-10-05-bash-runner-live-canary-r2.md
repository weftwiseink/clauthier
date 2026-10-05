# Bash-Runner Live Canary, Round 2 (Reviewer Re-Run)

> BLUF(opus-5-5/haiku-bash-wrapper-impl-r2): All four live dispatches pass containment, and every runner-internal tool result is at most 1,453 chars (r1 had 2,671 and 3,988).
> Every extraction call ends in the exact `| cut -c1-150 | head -n 10` suffix.
> Minor haiku drift remains: b1 printed 11 salient lines and its truncation line had no command, b2 rewrote the command path to an absolute path, and c dropped the final tail line to stay within 10.

## Method

The runs were made from `/var/home/mjr/code/weft/clauthier/main` at HEAD `c09330c`.
All four ran in parallel:

```
claude -p --plugin-dir plugins/cdocs --model sonnet --output-format stream-json --verbose --dangerously-skip-permissions \
  'Use the Agent tool with subagent_type "cdocs:bash-runner". Ask it to run: <CMD> ; <SPEC>. Do NOT run the command yourself. Reply with the runner report verbatim.'
```

The raw streams are in the reviewer's session scratchpad and are ephemeral.
Evidence below is jq-extracted only.
`TOOL[runner]` means `parent_tool_use_id` was set.
Every run ended with `subtype=success`, `is_error=false`, `num_turns=2`.
Parent tool use in every run was exactly one `Agent` call, and runner tool use was `Bash` only.
Runner model was `claude-haiku-4-5-20251001` and parent model was `claude-sonnet-5-5`.
After the runs, the four `/tmp/bash-runner-*.log` captures they created were deleted (`find -newer <start marker> -delete`).

## a) Containment: `seq 1 200000`, spec "exit code and last line"

```
TOOL[runner] Bash: OUT="${TMPDIR:-/tmp}/bash-runner-$(date +%s%N).log"⏎(⏎seq 1 200000⏎) > "$OUT" 2>&1 < /dev/null⏎echo "exit=$? ... warn=$(grep -acE 'warn|WARN' "$OUT")"
TOOL[runner] Bash: tail -n 1 /tmp/bash-runner-1791216830677641180.log | cut -c1-150 | head -n 10
RESULT[runner] chars=85 | chars=6     RESULT[parent] chars=965
Final: BASH RUNNER REPORT / Command: seq 1 200000 / Exit code: 0 / Status: OK / Salient: 200000
       Full output: saved to /tmp/bash-runner-...log (1288895 chars, 200000 lines; /tmp, persists until reboot; caller may delete)
```

The true last line is `200000`.
The only `199999` hit in the stream is a substring of a `costUSD` float, and `199998` appears 0 times, so no raw dump reached the parent.
**PASS.**

## b1) Grep sweep: `grep -rn "subagent" plugins/cdocs`, spec "match counts per file plus first 3 per file"

```
TOOL[runner] Bash: cut -d: -f1 <cap> | sort | uniq -c | sort -rn | cut -c1-150 | head -n 10
TOOL[runner] Bash: awk -F: 'c[$1]++ < 3' <cap> | cut -c1-150 | head -n 10
RESULT[runner] chars=79 | 489 | 1375     RESULT[parent] chars=2001
Salient: 5 count lines, 5 verbatim match lines, then
  [spec truncated: 5 more files with counts above; more per-file match samples omitted; see capture file]
Full output: ... (18440 chars, 97 lines; /tmp, persists until reboot; caller may delete)
```

Bound compliance: **PASS**, with a maximum of 1,375 chars.
Format drift: the report has 11 salient lines against a limit of 10, and the truncation line names no ready-to-run command.
Its "5 more files with counts above" also edges toward paraphrase.

## b2) Grep sweep, variance re-run (same prompt)

```
TOOL[runner] Bash: ...(⏎grep -rn "subagent" /var/home/mjr/code/weft/clauthier/main/plugins/cdocs⏎)...
TOOL[runner] Bash: cut -d: -f1 <cap> | sort | uniq -c | sort -rn | cut -c1-150 | head -n 10
TOOL[runner] Bash: awk -F: 'c[$1]++ < 3' <cap> | cut -c1-150 | head -n 10
RESULT[runner] chars=79 | 879 | 1453     RESULT[parent] chars=1969
Salient: 9 verbatim count lines, then
  [spec truncated: first 3 matches per file omitted; see awk -F: 'c[$1]++ < 3' /tmp/bash-runner-1791216830315277156.log]
```

Bound compliance and the overflow rule both **PASS**: exactly 10 lines, and the follow-up command is ready to run.
Drift: the runner made the relative path absolute (`plugins/cdocs` became `/var/home/.../plugins/cdocs`).
That breaks "the exact command, verbatim", although it is semantically equivalent here.

## c) Warnings: `seq 1 5000; echo "npm WARN deprecated foo@1.0"; seq 1 10`, no spec

```
TOOL[runner] Bash: (capture with warn= count)
TOOL[runner] Bash: grep -anE 'warn|WARN' <cap> | cut -c1-150 | head -n 10
TOOL[runner] Bash: tail -n 10 <cap> | cut -c1-150 | head -n 10
RESULT[runner] chars=81 | 32 | 20     RESULT[parent] chars=1098
Final: Exit code: 0 / Status: WARNINGS / Salient: 5001:npm WARN deprecated foo@1.0, then 1..9
       Full output: ... (23942 chars, 5011 lines; /tmp, persists until reboot; caller may delete)
```

Status `WARNINGS` is correct, and the warning line comes first.
**PASS.**
Drift: the tail is trimmed to `1..9` so the report fits 10 lines, so the true last line `10` is missing and no `[... N more]` marker was added.
