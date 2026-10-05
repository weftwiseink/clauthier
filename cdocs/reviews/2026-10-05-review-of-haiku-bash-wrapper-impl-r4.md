---
review_of: cdocs/proposals/2026-09-22-haiku-bash-wrapper.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T09:25:57-07:00
task_list: meta/token-spend-attribution
type: review
state: live
status: done
tags: [fresh_agent, implementation, rereview, live_canary, haiku_compliance, report_contract, example_echo, fidelity]
---

# Review: Haiku Bash-Output Wrapper, Implementation Round 4 (Phases 1-2)

> BLUF(opus-5-5/haiku-bash-wrapper-impl-r4): **Revise**, with one narrow blocking item.
> r3 F1 is closed: the report structure was exact in 5 of 5 live runs, and containment holds.
> The new filled example has caused the risk the implementer flagged. In one of two build probes, haiku reported warning lines in the example's `... in <file>.md` form, which does not occur in the real output, and named a wrong file.
> The fix is to replace the example with one that has nothing in common with any real command's lines. Internal methodology stays untouched.

## Summary Assessment

Iteration 4 (`6d773d2..df03c9b`) hardens only the report contract:
- a spec chooses lines, never the format;
- a plain-text rule (no fence, nothing before or after) and a size cue;
- a filled example and a 3-item self-check;
- a concrete truncation trigger;
- a mandatory Step 1 template and a no-`cd` clause.

Step 2 (the judgment-driven reads) is unchanged, so the maintainer constraint holds: nothing re-tightens internal reading.
Live, the structure fix works fully.
But d2 shows haiku taking content, not just shape, from the example, which breaks the "verbatim from the capture" core of the contract (F1).
The truncation line is still absent in sweeps (now 4 of 4 across r3 and r4), and one sweep report exceeded the size ceiling. Both are non-blocking.
Verdict: **Revise**.

## Verification

Evidence: [`cdocs/devlogs/_verify/2026-10-05-bash-runner-live-canary-r4.md`](../devlogs/_verify/2026-10-05-bash-runner-live-canary-r4.md), with five live dispatches at HEAD `5c781d2`. The checks use each runner's raw `tool_result`, not the parent's reply.

- **Floor (smoke): pass.**
  The agent loads, and the runner runs on `claude-haiku-4-5-20251001` with `Bash` only, in 2-3 calls and well within `maxTurns`.
  The `seq 1 200000` canary returns `Exit code: 0`, `Status: OK`, and the true last line `200000` in a 243-char report.
  The parent stream contains no `199999`.
- **r3 F1 closure: pass.**
  All five raw returns start with `BASH RUNNER REPORT` and end with `Full output: saved to ...`, with no fence and nothing before or after.
  Both "summarize" build probes kept the structure, including the mandatory last line.
- **Example-echo (e): fail in 1 of 2.**
  The real build prints `  Warning: Unknown CC tool ""*"" — skipping` three times (after `implementer.md`, `proposer.md`, `reviewer.md`).
  d2 reported `Warning: Unknown CC tool "*" in bash-runner.md` / `in implementer.md` / `in reviewer.md`.
  That is the example's line form and its two file names, plus a wrong third (`bash-runner.md` has `tools: Bash`).
  d1 used the real lines, though it normalized the quotes and moved one line.
- **Step 1 compliance (r3 F3/N1): pass.** All five used the exact template with a timestamped path, and none prepended `cd`.

## Prior Action Items

| r3 item | status |
|---|---|
| F1 [blocking] report structure under "summarize" specs | **Addressed** (5/5 exact structure) |
| F2 truncation line on overflow | Not effective live: missing in b1 and b2; b2 instead wrote `(9 more files with 1-2 matches each)` |
| F3 / N1 template skips, `cd` prepending | **Addressed** (5/5) |
| N2 "bounded" wording | **Addressed** (`e7ff402`) |
| N3 scope of "run no other commands" | **Addressed** in the devlog rationale; the rationale is sound |

## Section-by-Section Findings

### `bash-runner.md` Output Format: filled example

**F1 [blocking]: the filled example leaks content into reports.**
The example's salient lines (`Warning: Unknown CC tool "*" in reviewer.md`, `Agents converted: 7`) look like this repo's real build output but do not match it.
For a build-like command, haiku pattern-matched onto them in d2.
It produced lines that look verbatim but are not, and they gave the parent a false file attribution.
This is worse than the r3 format drift: a dispatcher has no reason to re-check a line labelled verbatim, so the error spreads silently.
The fix must stay on the report side only:
- Replace the example with abstract placeholders that cannot be mistaken for output. For example, `<count line, e.g. warnings: N>` and `<verbatim line copied from the capture>`, or a deliberately unrelated domain (a test runner's `FAIL tests/foo.test.ts > case`).
- Never use a build-like example.
- Optionally tighten self-check item 2 to "copied character for character from the capture, including quoting".

Do not add a mandatory per-line `grep -F` verification step.
That would grow the runner's internal procedure, which the maintainer constraint cautions against.
Leave it as an optional suggestion at most.

### `bash-runner.md` Step 3: truncation and fidelity

**F2 [non-blocking]: the truncation line is still not emitted, and paraphrase persists in sweeps.**
The concrete trigger did not change behaviour: across 4 of 4 sweep runs (r3 and r4), no run emitted `[spec truncated: ...]`.
b2's `(9 more files with 1-2 matches each)` is the exact example the prompt forbids.
b1's `1 each: rfp/SKILL.md, ...` shortens paths.
Containment and the `Full output` pointer hold, so the dispatcher can still recover the rest, which keeps this non-blocking per the overseer's guidance.
Since this is now systematic, not occasional, consider a change in shape rather than more wording.
For example, make the truncation line a fixed optional field in the template itself (`Truncated: <none | what was omitted; command>`) so it sits in the structure haiku already follows reliably.

**F3 [non-blocking]: report size overrun.**
b1's report body was 5,615 chars against "never more than about 4,000".
That is still a 70% reduction from the 18,440-char capture, so containment holds, but the ceiling is not self-enforced.
The F2 field change plus "counts first" would tend to cap it. No separate fix is required now.

### `bash-runner.md` Step 1: `warn=` pattern (pre-existing)

**F4 [non-blocking, new]: the `warn` count is case-sensitive and misses `Warning:`.**
`grep -acE 'warn|WARN'` returns 1 on the real build capture.
The only match is node's `... the warning was created` footnote, and the three `Warning:` lines go uncounted (`grep -aci warn` gives 5).
d1/d2 got `Status: WARNINGS` by accident: a build without the node footnote would classify as `OK` despite warnings.
Suggested fix: `grep -aciE 'warn'` (or `-acE '[Ww]arn|WARN'`).
This is a one-token change to the capture template and does not touch the reading methodology.

### Maintainer constraint

No finding.
Iteration 4's additions are all on the report surface: the format rule, example, self-check, and truncation trigger.
The Step 1 additions (exact template, no `cd`) constrain how the capture is taken, not how it is read.
Step 2 is byte-identical to r3, and the runners read freely: d2 read the full capture with `cat`, and b2 aggregated in two reads.

### Docs (`AGENTS.md`, `model-tiering.md`, devlog)

Consistent, and the "concise fixed-format extract" wording matches the agent description.
The devlog's Risk note correctly anticipated F1.

## Verdict

**Revise.** The one blocking change is replacing the filled example (F1), followed by a live re-run of the two build probes. That re-run checks that the warning lines carry the real `— skipping` form and the correct files, and that the structure stays exact.
F2-F4 are non-blocking and may ride along. F4 is a cheap correctness fix worth taking now.

## Action Items

1. [blocking] Replace the filled example in `plugins/cdocs/agents/bash-runner.md` with abstract placeholders or a clearly unrelated domain. It must contain no build-like lines, no repo file names, and nothing resembling `Agents converted`/`Unknown CC tool`. Re-run d1/d2 live and diff the salient lines against a direct `npm run build:cdocs`.
2. [non-blocking] Make overflow disclosure a fixed template field (for example `Truncated: none | <omitted>; <command>`) instead of a conditional extra line, since 4 of 4 sweeps omitted the conditional form.
3. [non-blocking] Change the Step 1 `warn=` pattern to case-insensitive (`grep -aciE 'warn'`) so `Warning:` lines drive `Status: WARNINGS`.
4. [non-blocking] Optionally tighten self-check item 2 to "character for character, including quoting". Do not add a mandatory internal verification pass.

## Questions for the Overseer

1. For F1, which replacement example do you prefer?
   - (a) abstract placeholders only
   - (b) an unrelated test-runner example
   - (c) no filled example (the r3 template plus the plain-text rule already fixed the structure)
2. Should F2's template-field change land in this iteration, or be deferred as a follow-up, given that containment does not depend on it?
