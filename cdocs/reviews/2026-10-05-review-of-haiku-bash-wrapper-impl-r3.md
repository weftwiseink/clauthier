---
review_of: cdocs/proposals/2026-09-22-haiku-bash-wrapper.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T09:21:02-07:00
task_list: meta/token-spend-attribution
type: review
state: live
status: done
tags: [fresh_agent, implementation, rereview, maintainer_steer, live_canary, haiku_compliance, report_contract]
---

# Review: Haiku Bash-Output Wrapper, Implementation Round 3 (Phases 1-2)

> BLUF(opus-5-5/haiku-bash-wrapper-impl-r3): **Revise**, with one narrow blocking item.
> The steer is applied cleanly: the runner's internal reads are now as free as a direct Bash call, no over-constraint is left behind, and the containment canary passes.
> Live probes show the report contract is not robust, though.
> Under a "summarize" spec, haiku dropped the fixed format in 2 of 2 build runs, once losing the mandatory `Full output: saved to` line.
> The mandatory overflow follow-up command was omitted in 2 of 2 sweep runs.
> The steer keeps the report as the one bounded, fixed-format surface, so a small prompt fix plus a live re-run of those probes is required.

## Summary Assessment

Iteration 3 (`2544f98..2578907`) replaces the r2 fixed `| cut -c1-150 | head -n 10` suffix with judgment-driven reads.
Under the new Step 2, small captures are read whole, larger ones get iterative targeted reads, and the patterns are labelled as examples.
The iteration also sizes the report to the request, adds "keep the true end", makes the overflow follow-up command mandatory, adds a verbatim-command clause, and raises `maxTurns` from 8 to 12.
The proposal and `orchestration-discipline.md` are updated consistently, and the change is recorded in a dated `NOTE(opus-5-5/oversee)`.
The internal relaxation works live: haiku reads a 1,149-byte build log whole, aggregates a 97-line sweep in two calls, and never spills.
The weak spot is the report, which the steer keeps bounded and fixed-format.
Its wording now leans on "sized to the request", and live it bends to a spec that says "summarize" (see F1).
Verdict: **Revise**.

## Verification

Evidence: [`cdocs/devlogs/_verify/2026-10-05-bash-runner-live-canary-r3.md`](../devlogs/_verify/2026-10-05-bash-runner-live-canary-r3.md), with six live dispatches at HEAD `d14fb02`.

- **Floor (smoke): pass.**
  The agent loads, and the runner runs on haiku using only `Bash`.
  The `seq 1 200000` canary returns `Status: OK` and the true last line `200000` in a 229-char report.
  The parent stream holds no `199999`.
  No run hit `maxTurns`, no parent ran the command itself, and the largest parent-facing report body is 3,646 chars, under the ~4K failure threshold.
- **Warnings probe (c): pass.**
  It returns `Status: WARNINGS`, the warn line, and true last line `10`, in the exact format.
- **Sweep probes (b, b2): counts exact, contract partial.**
  The per-file counts match an independent recount (23 files, 97 matches).
  Neither run emits the mandatory `[spec truncated: ...; see capture file: <cmd>]` line, even though 13-14 files' detail was omitted.
  b2 also cut detail lines with `...`.
- **Quality probe (d, d2): facts accurate, format broken.**
  Both reports state the build correctly when checked against the reviewer's own run (7 agents, 3 `Unknown CC tool` warnings, 1 Node deprecation).
  d wraps the report in a code fence and appends a `**Summary:**` paragraph.
  d2 returns a markdown summary with no `BASH RUNNER REPORT` structure and no capture path.
  d also skipped the Step 1 template (no subshell, fixed path `/tmp/bash-runner-build.log`, no `warn=`), and d2 prepended `cd <repo> &&` to the command.

## Steer Conformance (question 1)

**Conforms.**
Step 2 of `bash-runner.md` now gives a size-driven choice ("read it whole" under about 300 lines and 20,000 bytes, iterative targeted reads above that).
Its only guards are the platform ceiling and `cut -c1-N` for very long lines.
The patterns are framed as "Good patterns ... adapt the counts to the question", and the Constraints allow "as many as the question needs within your turn budget".
`maxTurns: 12` gives room for locate, widen, and aggregate.
No stale bound is left: a grep across the proposal, `plugins/cdocs/`, and AGENTS.md finds no `cut -c1-150`, `<=10`, `5 Bash calls`, or `maxTurns: 8`.
The remaining limits are design, not over-constraint: run the command once, verbatim, and run no commands beyond reads of the capture.
An unconstrained parent could also open source files a build log points at, but that belongs to the dispatcher's follow-up, not the runner's (see N3).

## Section-by-Section Findings

### `bash-runner.md`: Output Format and Step 3

- **F1 [blocking] The report contract does not survive spec wording that invites summary.**
  The steer and the proposal NOTE keep "the concise fixed-format report ... mandatory".
  The proposal calls the `saved to` line "load-bearing", and the Test Plan includes "Fixed-format report".
  Live, a spec that says "summarize what the build did" led haiku to paraphrase in 2 of 2 runs, and d2 dropped the capture path entirely.
  The prompt says "With a salience spec, select what it asks for" but never says the spec governs selection only.
  So haiku reads "summarize" as permission to override "never paraphrase" and "EXACTLY this structure".
  The iteration also removed the explicit "at most about 2,000 characters in total" from the Output Format line and the `(<=10 lines)` cue from the template header.
  That left the report's shape signalled only by Step 3 prose.
  A suggested fix, all prompt-only:
  - State in Step 3 or Output Format that a spec chooses WHICH lines to include and never changes the format.
    A spec asking to "summarize" or "describe" is answered with verbatim lines plus counts.
  - State that the report is plain text, with no code fence, markdown headings, or text before or after it.
  - Restore an explicit size cue on the Output Format line, for example "about 2,000 characters, never more than about 4,000".
  - Optionally, end with a one-line self-check: the report's first line is `BASH RUNNER REPORT` and its last line starts with `Full output: saved to`.
  Re-run probes b and d (two runs each) to show the fix holds.
- **F2 [non-blocking] Mandatory overflow follow-up omitted 2/2.**
  This is rev-2 N1, still live despite "The follow-up command is mandatory".
  b invented its own truncation line, and b2 emitted none.
  The F1 self-check could include "if any requested detail was omitted, the last salient line is `[spec truncated: ...; see capture file: <cmd>]`".
  It is non-blocking alone, since the counts are exact and the capture path is present, but it belongs in the F1 re-run.
- **F3 [non-blocking] Step 1 template skipped once (d).**
  The run used a fixed `/tmp/bash-runner-build.log` path, so concurrent runners could collide, and it had no subshell or `warn=`.
  This text is unchanged from r2, so the cause is likely haiku variance plus the parent adding "Working directory: ..." to the prompt.
  The template still controls in 4 of 6 runs.
  Watch for it in the F1 re-run.

### `bash-runner.md`: Step 1 and Constraints

- **N1 [non-blocking] Working-directory hint provokes command rewriting.**
  Sonnet parents add "Working directory: <repo>" on their own, and d2 turned that into a `cd <repo> &&` prefix, which breaks "verbatim".
  The fix is one clause: "your working directory is already the dispatcher's; do not add `cd`".

### `orchestration-discipline.md`, proposal, AGENTS.md, and model-tiering

- **N2 [non-blocking] "bounded" vs "concise".**
  The `bash-runner.md` description now says "concise fixed-format salient extract".
  `plugins/cdocs/AGENTS.md:47` and `model-tiering.md:31` still say "bounded fixed-format extract".
  Both are accurate, since the report stays bounded, so harmonize only if convenient.
- The proposal edits keep a present-tense design body with history confined to the NOTE, which matches the writing conventions.
  The `orchestration-discipline.md` contract ("typically 10-20 verbatim lines", counts plus top few files) matches the agent.

### Devlog

- **N3 [non-blocking] Scope note for the steer.**
  The iteration-3 notes could add one line on why "run no other commands" survives the steer.
  It keeps the runner a single-command container, and a follow-up into source files belongs to the dispatcher.
  That pre-empts a future reading that it is leftover over-constraint.

## r2 Action Items: Disposition

- **N1 (truncation line without command):** addressed in the prompt but **not effective live**, see F2.
- **N2 (relative path rewritten):** the prompt clause is added.
  b, b2, and c kept the command verbatim, but d2 prepended `cd`, see N1.
- **N3 (tail trimmed):** **resolved**.
  "Keep the true end" holds in a and c.

## Verdict

**Revise.**
The steer is applied correctly and completely, and the floor passes.
The single blocking item is F1: make the report format immune to the spec's wording and restore an explicit size cue.
Then show it live with two b-probes and two d-probes.
No change to the relaxed internal-read methodology is requested.

## Action Items

1. [blocking] In `bash-runner.md`, state that a salience spec selects lines but never changes the report format.
   A "summarize" spec still gets verbatim lines plus counts, the report is plain text with no fence and nothing before or after it, and the Output Format line carries an explicit size cue (about 2K, never more than about 4K chars).
   Re-run the d probe (`npm run build:cdocs`, "summarize ..." spec) twice live.
   Both must return the exact `BASH RUNNER REPORT` structure including the `Full output: saved to` line.
2. [non-blocking] Add a closing self-check line to Output Format: first line, last line, and the `[spec truncated: ...; see capture file: <cmd>]` line whenever detail was omitted.
   Verify on two b-probe re-runs (F2).
3. [non-blocking] Add "do not prepend `cd`; your working directory is already the dispatcher's" to the Step 1 bullets (N1).
4. [non-blocking] Harmonize "bounded" and "concise" wording across AGENTS.md and model-tiering if convenient (N2).
5. [non-blocking] Add a devlog line on why "run no other commands" is design, not leftover over-constraint (N3).

## Questions for the Maintainer

1. When a dispatcher's spec asks the runner to "summarize", which should win?
   - (a) The fixed verbatim format always wins, and summaries are the dispatcher's job (recommended, and what F1 assumes).
   - (b) Allow a short, clearly delimited prose summary inside `Salient output:`, with the `saved to` line still mandatory.
   - (c) Drop the verbatim rule entirely, so the report is free-form apart from the header and footer lines.
