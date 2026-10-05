---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T14:03:13-07:00
task_list: meta/token-spend-attribution
type: devlog
state: live
status: done
tags: [verification, live_canary, bash_runner, maintainer_rewrite, capture_collision]
---

# Bash-Runner Rewrite Canary (commit `6821b43`)

> BLUF(opus-5-5/bash-runner-rewrite-review): The loosened runner gives correct, useful reports.
> Every list a spec asked for was complete and exact: 17/17 failures twice, 64/64 call sites, then 5/5 and 3/3 after test fixes.
> Bodies were 0.4-3.0K, every report named its capture file, and no runner re-ran or rewrote the command.
> With no spec, the runner named all 17 failing tests by suite and case, but gave no file:line and values for only 2.
> The one real defect is the capture step: "Append ... to a file in `/tmp/claude-<uid>/`", with no naming guidance.
> Runners picked generic names (`run.txt`, `run1.txt`, `out.txt`, `lf.txt`) at the top of the shared per-uid dir and appended with `>>`.
> In 5 of 9 runs, the capture already held another run's output.
> No final answer was wrong, but runners mis-stated run boundaries, and in C3 and C6b `Output:` line counts or `see:` ranges point into another run.
> C3 read a concurrent sibling's copy, not its own.
> The `cdcos:` typo did not break dispatch in the one probe that used it.

## Fixtures (session scratchpad, outside the repo)

A seeded Python generator (`gen.py`) writes the fixtures and the ground truth from the fixture sources, not from command output.

- **P (all pass):** `cd P && node --test --test-reporter=spec "tests/*.test.mjs"`, 6 files, 360 tests, 740 lines, 31,914 chars, exit 0.
- **F (17 failures):** same shape, 17 distinct `deepStrictEqual` failures on `{total, id}`, 1,184 lines, 49,176 chars, exit 1.
  For C6, 12 failures were fixed in place, leaving 5; for C7, 2 more were fixed, leaving 3.
- **B (sweep):** `grep -rn legacyFetch B/src` over 30 files, 387 lines, 25,415 chars.
  Of these, 64 are real `legacyFetch(` call sites in 24 files; the rest are imports and `// was legacyFetch before migration` comment decoys.

## Method

`claude -p --plugin-dir <abs>/plugins/cdocs --model sonnet --output-format stream-json --verbose --dangerously-skip-permissions '<prompt>'`, run from the fixture root.
The plugin is at `6821b43`; Claude Code `2.1.289`; the runner model is `claude-sonnet-5-5` in every run.
The prompt tells the parent to dispatch `cdocs:bash-runner` in the foreground with a fixed runner prompt (command, plus an "I need:" spec unless the run has no spec), not to run the command itself, and to relay the report verbatim.
C1 also asks the parent to quote the runner's `description` as its Agent tool lists it, to check the YAML block scalar.
C5 is the typo probe: the parent gets the new "Bash: Avoid context bloat" section via `--append-system-prompt`, and is told to delegate to "the agent that guidance names", which the guidance spells `cdcos:bash-runner`.
C1-C5 ran concurrently; C6a, C6b, C7a and C7b ran one after another, with the earlier captures left in place.
The normal `HOME` was used, so no credential copies were made; a `find` over the scratchpad and `/tmp/claude-1000` for credential files found none.
Each report is checked against ground truth with a Python matcher: name, `it` line, expected total and actual total for tests, and the exact `file:line` set for the sweep.

## Results

| run | fixture / spec | runner Bash calls | report body chars | correct vs ground truth | capture | notes |
|---|---|---|---|---|---|---|
| C1 | P / "did it pass, and the test totals" | 1 | 448 | yes (OK, 360/360) | `run.txt`, `>` | appended `rc=0` into the capture; parent quoted the full multi-line description, flattened |
| C2 | F / no spec | 4 | 1,344 | 17/17 named (suite plus case number); file:line for none; values for 2 | `run1.txt`, `>>` (first writer) | `Summary:` says "I read two in detail, and I only counted the rest"; its `see:` grep now returns 3x the lines |
| C3 | F / "every failing test: name, file:line, expected vs actual" | 4 | 2,953 | 17/17 exact | `run1.txt`, `>>` (shared) | "The spec report appears twice ... I don't know why the output repeats"; read lines 742-1190, which are C2's copy, not its own; `Output:` reports 2,368 lines (two runs) |
| C4 | B / "every real legacyFetch( call site as file:line; complete list" | 4 | 1,647 | 64/64 set-exact | `lf.txt`, `>` | prefixed an absolute `cd` and `pwd && ls` to the command |
| C5 | F / typo probe, rules text only | 5 | 2,986 | 17/17 exact | `run1.txt`, `>>` (shared, 3 runs) | parent dispatched `cdocs:bash-runner` correctly; runner noticed the append and used the first copy; one start line inferred, said so |
| C6a | F (5 failing) / "every failing test" | 3 | 2,263 | 5/5 exact | `out.txt`, `>>` (fresh) | |
| C6b | same, sequential | 4 | 2,009 | 5/5 exact | `out.txt`, `>>` (C6a's file) | says the copies are lines "~1-741 and ~742-1744"; they are 1-872 and 873-1745, so its `see: sed -n '742,870p'` reads C6a's run |
| C7a | F (3 failing) / same | 3 | 2,110 | 3/3 exact | `out.txt`, `>>` (2 prior runs) | read its own (last) block; suggests the 2 extra failures in older runs "may be flaky" |
| C7b | same, sequential | 5 | 2,166 | 3/3 exact | `out.txt`, `>>` (3 prior runs) | claims lines 1746-3386 as "my run"; that range is C7a's run plus its own; "I did not find why" |

Costs: $0.05-0.13 per run (sonnet parent plus runner).
Runner Bash calls: 1-5, under `maxTurns: 12`.
No runner set the Bash `timeout` parameter (all commands finished in under a second, so this is untested).
Every runner created the directory with `mkdir -p /tmp/claude-1000`, so the path does not need to exist beforehand.

Final capture sizes before cleanup: `run1.txt` 3,552 lines (3 runs), `out.txt` 3,386 lines (4 runs), `run.txt` 741, `lf.txt` 387.
The reviewer copied them to the session scratchpad (`rwruns/captures/`) and deleted them from `/tmp/claude-1000/`, so later runners cannot append to them.

## Other Checks

- **Block-scalar `description`, Claude Code:** parses (yq gives the 6-line string), and the C1 parent quoted it in full.
- **Block-scalar `description`, OpenCode build:** `npm run build:cdocs`, run on a scratch copy, emits `description: |` followed by `mode: subagent`.
  YAML parses this as an empty string (`yq`: `"description": ""`).
  `scripts/build-opencode.ts` `parseFrontmatter` reads frontmatter one line at a time, so it keeps only the `|` and drops the indented lines.
- **Dedupe idiom in the agent body** (`difflib.SequenceMatcher` against every kept line): it is quadratic in the number of distinct lines.
  On repetitive test output, 2,000 lines took 2.1s.
  On diverse `grep -rn` output, 2,000 lines took 56.6s, and 5,000 lines did not finish in 150s.
  The agent suggests it for "_unreasonably_ large" files, where it will hit the 2-minute Bash default.

## Observations

- **Completeness holds without the old excerpt rules.** Every spec'd list was complete and exact, and it went in a labelled list or table outside `Excerpt:`, which the loosened format allows.
  No run used shorthand or overran the ~4K guidance.
- **The no-spec default is thinner.** C2 named all 17 failing tests but gave locations for none and values for 2, so a caller fixing them would follow up.
  The new `description` tells callers to state what they need, which puts that choice on the caller.
- **Append plus free naming is the failure mode.** "Append" led 7 of 9 runners to use `>>`; generic names led 5 of 9 to share a file with another run.
  Runners spent extra turns working out which block was theirs, and three (C3, C6b, C7b) got the boundaries wrong.
  With identical or monotonically fixed output this did not change an answer.
  With concurrent runs of a long command (parallel worktrees running one test suite), `>>` would interleave lines from both processes, and no reader could separate them.
- **The typo is masked by the agent listing.** In C5 the parent dispatched `cdocs:bash-runner` correctly despite the guidance text.
