---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T11:34:24-07:00
task_list: meta/token-spend-attribution
type: devlog
state: live
status: done
tags: [verification, live_canary, bash_runner, quality, completeness]
---

# Bash-Runner Quality Canary (Completeness Under Size Pressure)

> BLUF(opus-5-5/haiku-bash-wrapper-impl-final): This canary asks what rounds r1-r8 never asked: can a caller act on the report?
> With an explicit "every failure" or "complete list" spec, the sonnet runner read enough and reported **every item correctly in 6 of 6 runs** (17/17, 45/45, 49/49 call sites, each checked against ground truth).
> But 5 of those 6 runs had to bend or break a written contract rule to do it: composed `Excerpt:` lines, a list in `Summary:`, more than "a few" lines, or a report over ~4K.
> One run kept under 4K by compressing 45 lines into an unlabelled shorthand.
> With **no spec**, the runner reported "17 failed" but named **none** of the failing tests (suite-level lines only).
> An opus caller given only the "Bash Output Hygiene" text did not dispatch. It captured the output to a file itself, then grepped it, and listed all 17 failures with about 5K of tool output.

## Fixtures (scratchpad, outside the repo)

- **A (17 failures):** `node --test --test-reporter=spec "tests/*.test.mjs"` over 6 files (360 tests, 17 distinct `deepStrictEqual` failures with distinct values). 53,190 chars, 1,088 lines, exit 1.
- **E (45 failures):** same shape, 9 files (450 tests, 45 failures). 76,804 chars, 1,833 lines, exit 1.
- **B (find all):** `grep -rn legacyFetch src` over 30 files: 255 lines, of which 49 are real `legacyFetch(` call sites in 24 files. The other 206 are imports plus `// was legacyFetch before migration` comment decoys. 30,039 chars.

## Method

Each run is `claude -p --plugin-dir <abs>/plugins/cdocs --model sonnet --output-format stream-json --verbose --dangerously-skip-permissions '<prompt>'`, run from the fixture dir.
The runner prompt asks the parent to dispatch `cdocs:bash-runner` with the stated spec and to relay the report verbatim.
For run C1 the parent is `--model opus`, given `--append-system-prompt` with the full "Bash Output Hygiene" section and a plain task, without being told to use the runner.
Analysis uses `jq`: runner entries have `parent_tool_use_id` set; the report is the parent `Agent` call's `tool_result`.
Ground truth is derived from the fixture sources (test line, assertion line, actual, expected) and from `grep -rn 'legacyFetch(' src | cut -d: -f1,2`, and is compared with `diff`.
Runner model was `claude-sonnet-5-5` in every run; Claude Code `2.1.289`.

## Results

| run | fixture / spec | runner Bash calls | report chars | complete & correct | contract deviations |
|---|---|---|---|---|---|
| A1 | A / "every failing test: name, file:line, expected vs actual" | 4 | 3,168 | 17/17 exact | Excerpt lines retyped/composed from a grep/sed read (disclosed in `Truncated:`); not "a few" |
| A2 | same | 3 | 3,149 | 17/17 exact | same; `Truncated:` admits "transcribed" |
| E1 | E / same spec | 4 | 4,715 | 45/45 exact | over the "never more than about 4,000" cap, deliberately: "more than the usual 12 sample lines because your spec asked for every failure"; lines are `awk` output |
| E2 | same | 4 | 4,244 | 45/45 exact | stayed near 4K by encoding each line as `billing:35 caches split shipment c 28 197 190` with a legend in `Summary:` (actual/expected unlabelled per line); created `/tmp/x.$$` (Constraints forbid other files; removed by the reviewer) |
| B1 | B / "every real call site as file:line; I need the complete list" | 3 | 2,382 | 49/49 (set-exact) | complete list hand-condensed into a 4th `Summary:` line (`mod00: 13, 35. mod01: 14. ...`); Excerpt 2 lines; capture written into the dispatcher's working dir (fixture dir was under the scratchpad, likely fixture-induced) |
| B2 | same | 4 | 2,545 | 49/49 (set-exact, capture order) | 49-line Excerpt; claims "printed with `cut -d: -f1,2`" but no such command produced it (list matches its `grep \| cut -c1-200` read) |
| N1 | A / **no spec** | 3 | 1,105 | 17 count right; **0 of 17 failing test names** | none against the contract: excerpt is `ℹ` totals, six suite-level `✖ auth (12.48ms)` lines, and one actual/expected pair; `Truncated:` says "per-test failure names beyond the first 13", but none were given |
| C1 | A / opus caller, hygiene text only, "list every failing test" | (no dispatch) | 5,010 largest parent result | 17/17 exact | n/a: ran `cmd > /tmp/fx-test-out.txt 2>&1; echo exit; tail -n 12`, then a targeted `sed \| grep \| head -150` |

Costs per run: $0.08-0.13 (sonnet parent + runner); C1 $0.19 (opus).
Runner Bash calls: 2-4 per run, well under `maxTurns: 12`.

## Observations

- **No early reporting.** In every spec'd run the runner located the failure section (`grep ✖`, then `sed -n '<start>,$p'`) and read all of it before reporting. Size pressure did not cut the investigation short.
- **The contract and the spec pull in opposite directions, and runs resolve it differently.** A1, A2 and B1 met the spec by composing lines the contract forbids, and E1 by going over the cap. E2 met the cap by making its lines less readable. Same input, different trade-offs: the text does not say which wins.
- **`awk` reconciles fidelity and completeness.** E1 and E2 produced their per-failure lines with one `awk` over the capture and pasted its output: verbatim and complete. The fidelity rule is compatible with completeness when the contract allows one line per item.
- **The default (no-spec) path under-reports diagnostics.** "Prefer error-matching lines, then the true final lines" with "a FEW" lines yields totals plus suite-level lines on a node test run. A caller that skips the spec must follow up to learn which tests failed.
- **The self-capture pattern works without the runner.** C1 kept full recoverability (capture file), the true exit code, and complete output at about 5K of context, with no round trip. The hygiene text does not describe this pattern; its "self-bound" examples (`| tail -n 5`) discard both the diagnostics and, without `pipefail`, the exit status.
