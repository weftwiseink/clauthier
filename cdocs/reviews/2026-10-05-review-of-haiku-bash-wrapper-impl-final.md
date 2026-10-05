---
review_of: cdocs/proposals/2026-09-22-haiku-bash-wrapper.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T11:34:24-07:00
task_list: meta/token-spend-attribution
type: review
state: live
status: done
tags: [fresh_agent, implementation, live_canary, runtime_validated, sonnet_runner, task_quality, completeness, over_conditioning, caller_guidance, wording_balance]
---

# Review: Bash-Output Wrapper, Final Implementation Review (Size-Aversion vs. Task Quality)

> BLUF(opus-5-5/haiku-bash-wrapper-impl-final): **Revise (wording only).**
> In practice the sonnet runner does not under-investigate.
> In 6 of 6 live runs with an explicit "every failure" or "complete list" spec, it read enough of the capture and reported every item correctly: 17/17 and 45/45 test failures, 49/49 call sites.
> But it got there by bending or breaking its own contract in 5 of the 6, and one run made its 45 lines less readable to fit the ~4K cap.
> The text is over-conditioned. It names about 14 report-size limits and never says "list every item the spec asks for", so a good report depends on sonnet overriding its prompt.
> Two problems show up in behaviour, not just in text.
> The no-spec default named **none** of 17 failing tests.
> The caller-side "self-bound" advice (`| tail -n 5`) throws away diagnostics and masks the exit code.
> The fixes are wording changes in `bash-runner.md` and "Bash Output Hygiene"; no mechanism changes.

## Summary Assessment

The work ships `cdocs:bash-runner`, a sonnet agent that captures one verbose command to a file and returns a fixed-format report.
It also ships caller guidance in `orchestration-discipline.md`'s "Bash Output Hygiene" section.
Across rounds r1-r8 the contract gained a ~4K hard cap, a 3-line Summary, "a FEW" Excerpt lines, a 20+12-line two-command aggregate form, and verbatim-provenance rules.
Each addition answered a real fidelity failure, but every acceptance bar in those rounds measured containment, format, verbatim fidelity and size.
None measured whether a caller could act on the report.
This review ran that missing test ([`_verify/2026-10-05-bash-runner-quality-canary.md`](../devlogs/_verify/2026-10-05-bash-runner-quality-canary.md), 8 runs).
The runner's investigation is sound, the containment mechanism is sound, and the path to the full output (capture file plus `see:` command) is sound.
The problem is the report contract's priorities and the caller guidance's examples.
Verdict: **Revise**, with major wording deltas below; nothing is critical.

## Evidence Summary

| run | case | complete & correct | how it got there |
|---|---|---|---|
| A1, A2 | 17 failures, "every failing test" spec | 17/17 exact | Excerpt lines retyped from a read (forbidden), 17 lines (not "a few") |
| E1 | 45 failures, same spec | 45/45 exact | `awk`-built lines; **4,715 chars, over the cap on purpose** ("your spec asked for every failure") |
| E2 | 45 failures, same spec | 45/45 exact | **kept ~4K by compressing to `billing:35 caches split shipment c 28 197 190`** (actual/expected unlabelled) |
| B1 | 49 call sites, "complete list" | 49/49 | list hand-condensed into a 4th `Summary:` line |
| B2 | same | 49/49 | 49-line Excerpt; misstates its provenance ("printed with `cut -d: -f1,2`") |
| N1 | 17 failures, **no spec** | **0/17 names** | totals plus six suite-level `✖ auth (12.48ms)` lines |
| C1 | opus caller, hygiene text only | 17/17 exact | did not dispatch: `cmd > file 2>&1; echo exit; tail`, then a targeted grep (5K in context) |

Runner Bash calls were 2-4 per run, so `maxTurns: 12` never bound.

## Section-by-Section Findings

### `bash-runner.md`: does the runner investigate enough before reporting?

**Yes, in observed behaviour.**
Every spec'd run found the failure section (`grep ✖`), then read all of it (`sed -n '<start>,$p' | grep/awk`) before writing.
Line 14 ("read the output as freely as the question needs") and Step 2's judgment-driven reads are working as the maintainer's 09:50 steer intended.
`maxTurns: 12` is ample (max 4 used) and is not a quality constraint.
Keep Step 2 and the capture template as they are.

### `bash-runner.md` Step 3 and Output Format: the report contract (major)

**F1 (major): no rule says "report every item the spec asks for", while about 14 lines push the other way.**
Report-facing size limits:
- L12 "short".
- L13 "a short summary plus a few verbatim lines".
- L81 "up to 3 lines".
- L83 "a FEW short".
- L84 `head -n 8`.
- L85 "a line that does not fit is omitted".
- L89-96: two bounded commands, 20 and 12 lines, 120 characters, "about 4,000".
- L104 "never more than about 4,000".

The completeness-side lines are L80 (FAILED always reported), L82 ("answering the spec"), L97 (true end) and L98-100 (honest `Truncated:`).
The `Truncated:` field discloses what is missing; nothing asks the runner to avoid omitting it.
The canary shows how runs resolve this tension: each one picks its own trade-off.
E1 broke the cap, E2 degraded its format to keep it, A1, A2 and B1 broke the composed-line rule, and B2 broke "a few".
All of them happened to put completeness first, but nothing in the text makes them do so.
A model that follows the text more literally, or a longer list, would get a sampled report plus `Truncated: ...; see:`.
The caller would then have to read the 53-77K capture, which is the cost the runner exists to avoid.

**F2 (major): the cap is a hard ceiling, with no override for a spec that asks for completeness.**
For a caller that asked for every failure, a complete 5-10K report is far cheaper than any follow-up: reading the raw capture, re-dispatching, or running the `see:` command and ingesting its output.
E2 shows the cost of the hard ceiling: 45 lines squeezed into `c 28 197 190` with a legend, so the caller must remember which number is actual and which is expected.
That is the kind of degraded result the maintainer is worried about.

**F3 (major): the no-spec default under-reports diagnostics (N1).**
"With no spec, prefer error-matching lines, then the true final lines", plus "a FEW", produced totals and suite-level lines on a failing test run, with zero test names.
Callers often skip the spec: the hygiene text asks for one only "for high-stakes calls".
So the default should name each distinct failure.
N1's `Truncated:` also claimed "per-test failure names beyond the first 13" were omitted, when none had been given: an honesty slip.

**F4 (major): the aggregate form overrides the caller's spec.**
L92 says: "Take as many samples per file as the spec asks only if they fit in 12 lines; otherwise take 1 per file."
For the r8 spec "first 3 per file", 11 of 23 files got no sample and the rest got 1, so a fixed number overrode an explicit request.
The two-command form fixed real r7 drift and is a good default for open-ended sweeps.
But the spec, not the fixed 12, should size the sampling command.
L95 (the "20 count lines and 12 sample lines ... 4,000 characters" arithmetic) is internal bookkeeping that frames size as the goal, and can go.

**What to keep.** The verbatim-provenance rule, "produce lines with a command and paste its output", is not the problem.
E1 and E2 met it with one `awk` over the capture, completely and exactly.
r6-r8 earned this rule with real drift evidence on sonnet.
The fix is to allow one command-built line per item, not to drop fidelity.

### `bash-runner.md`: haiku-era and verifier-era leftovers (nit)

**F5 (nit): L87 "Use bare capture lines (`grep -h`, no `-n`) unless the spec asks for line numbers"** came from r6 F5, where `-n` prefixes failed the reviewer's `grep -Fx` check.
That serves the verifier, not the caller.
Capture line numbers are the cheapest path from an excerpt to its context (`sed -n '1200,1260p' <capture>`).

**F6 (nit): L119 "nothing in the report is copied from this prompt"** answers the r4 haiku leak of a filled example that no longer exists.
L93's `(such as "1 each: ...")` quotes an r7 artifact.
Both cost little, but they are scaffolding sonnet does not need.

**F7 (nit): Status is mechanical.**
`warn=` counts any line containing "warn", so every r8 sweep reported `WARNINGS` because a `WARN(` callout matched.
And an exit code of 0 from `cmd | tail` hides a failing `cmd`.
One Summary clause covers both.

**F8 (nit): E2 wrote `/tmp/x.$$` (7K, left behind).**
The Constraints already forbid it; one Step 2 clause ("use pipes, not temp files") makes that concrete.

### `orchestration-discipline.md` "Bash Output Hygiene": caller side

**F9 (major): the "self-bound" examples lose diagnostic context and the exit code.**
L212 recommends `| tail -n 5` for "pass/fail, a count, the last few lines".
For a build or test run, a "pass/fail" need turns into "why did it fail" exactly when it fails, and `| tail -n 5` has already thrown the details away, which forces a re-run.
Without `pipefail`, `cmd | tail -n 5` also reports `tail`'s exit status, so the pass/fail signal itself is lost.
C1 shows the better pattern: an opus caller, given only this section, chose it on its own.
It wrote `cmd > file 2>&1; echo exit=$?; tail -n 12 file`, followed by a targeted grep: 17/17, about 5K in context, no round trip, fully recoverable.
The guidance should name that pattern instead of `| tail -n 5`.

**F10 (major): "large or unpredictable AND relevant" is the wrong dispatch test when the caller needs every line.**
If the caller will read a diff line by line, a relay adds a round trip and a lossy excerpt.
The runner earns its keep when the caller needs a distillation (which failed and why, where the matches are), even an exhaustive one like B's 49 call sites taken from 255 noisy lines.

**F11 (major): the dispatch contract tells callers about runner internals and limits, not about what they can ask for.**
L226-227 restate the 3-line Summary, "a few short" lines, "about 4,000 characters" and the two-bounded-commands mechanics.
That primes the caller to expect, and to spec for, a small sample.
The text also duplicates `bash-runner.md`, which the repo's dedup rule discourages.
Callers are not told the lever that matters: say "every" when they need completeness.
L229's follow-up path ("grep or read the named capture file") is correct but passive, and it omits re-dispatching the runner with a narrower spec over the capture.

**Wording balance (caller side).**
One sentence (L204) speaks to not losing information.
L212-213, L226-227 and L232 speak to cost or size.
The spec is framed as for "high-stakes calls" only.

### `model-tiering.md`, `AGENTS.md`, `README.md`

**F12 (nit):** "concise fixed-format extract" (model-tiering L25, AGENTS.md L47, agent `description`) is what callers see when choosing an agent, and it advertises brevity, not answers.
model-tiering L26 frames the runner's risk as verbatim drift only; under-reporting is the other half.
README L106 is accurate.

### Process observation (not a text defect)

All eight rounds and both judge bars measured format and fidelity.
Under those bars, A1/A2 (composed lines) and E1 (over 4K) would have failed, even though they were the most useful reports in this canary.
The contract was tuned to its verifier.
The proposal's Test Plan and Verification Methodology have no completeness probe.

## Verdict

**Revise.**
The mechanism (capture-to-file, judgment-driven reads, capture path and `see:` follow-up, containment) is sound, and sonnet's investigation is thorough.
The report contract and the caller guidance put size ahead of completeness.
Today, good results depend on the runner overriding its prompt, and two paths (no-spec default, `| tail -n 5` self-bounding) lose information in practice.
The deltas below are wording-only and keep every fidelity gain from r6-r8.

## Action Items

Exact wording deltas, by file.
Line numbers refer to the current files (`orchestration-discipline.md` numbers are absolute; the section starts at L200).

### `plugins/cdocs/agents/bash-runner.md`

1. [major] **L12-13 (purpose).** Replace with:
   > You run ONE shell command on behalf of a dispatching agent and return a fixed-format report.
   > Your purpose is containment without loss: the raw output stays in a capture file on disk, and the dispatcher gets everything it needs to act on that output, without the noise around it.
   > A complete answer matters more than a short one: a thin report sends the dispatcher back to the raw output, the cost you exist to avoid.
2. [major] **Step 3, new first bullet (completeness), before Status:**
   > - **Answer the spec completely.** When the spec asks for every failure, error, or match, list every one, one compact line per item (for example `tests/a.test.mjs:39 rejects expired token: expected false, actual true`), never a sample. Build the list with one command over the capture (`grep`, `awk`) and paste its output. Read as much of the capture as that takes.
3. [major] **L81 Summary:** "up to 3 lines in your own words" -> "a few lines in your own words (usually 1-3)".
   **L83 Excerpt:** "a FEW short verbatim lines that back the summary or answer the spec" -> "the verbatim lines that answer the spec: a few for a pass/fail or open-ended question, one per item when the spec asks for a list".
   **L86:** append "A command that formats one line per item (for example an `awk` over the capture) is command output, and is the preferred way to build a list."
4. [major] **L88 default heuristic.** Replace with:
   > With no spec, report what the dispatcher needs to act: for a failing build or test run, each distinct error or failing test (name, location, message), one line each; otherwise error-matching lines; and always the true final lines.
5. [major] **L92 and L95 (aggregate).**
   Replace L92 with: "Take as many samples per file as the spec asks, sizing the sampling command's `head` to the spec and the report size below, not to a fixed 12. When the spec asks for every match, the second command is the complete filtered list."
   Delete L95 (the 20/12/120/4,000 arithmetic).
   In L90-91, change "for example ... `head -n 20`" and "`head -n 12`" to "for example" defaults with the `head` count set by the spec.
6. [major] **L104 size.** "never more than about 4,000 characters" -> "usually under about 4,000 characters. When the spec asks for a complete list, include all of it up to about 12,000 characters; past that, list what fits, give the total from a command, and name the rest in `Truncated:`. Never compress lines into an unlabelled shorthand to save space."
   (The 12K figure is a proposal; see Question A.)
7. [nit] **L4 `description`:** "...and return a concise fixed-format salient extract" -> "...and return a fixed-format report that answers the dispatcher's question (every failure or match when asked) without the raw output".
8. [nit] **L87:** replace with "Keep capture line numbers (`grep -n`) when they help the dispatcher jump to context in the capture; drop them when they are noise."
9. [nit] **L119:** delete "nothing in the report is copied from this prompt". **L93:** delete `(such as "1 each: ...")`.
10. [nit] **L79-80 Status:** append "If the output shows failures despite exit 0 (for example a command ending in `| tail`), say so first in `Summary:`. For a search, a non-zero `warn` count usually means the pattern matched text, not a warning; say so."
11. [nit] **Step 2:** append "Chain multi-stage reads with pipes; do not write temporary files."
12. [nit] **L100:** append "Never list as omitted something you did not report at all; say what was reported instead." (N1's `Truncated:` slip.)

### `plugins/cdocs/rules/orchestration-discipline.md`, "Bash Output Hygiene"

13. [major] **L212 self-bound bullet.** Replace with:
    > - **Known need: bound what you read, not what you keep.** When you know exactly what you need (pass/fail, the last few lines), capture to a file and read just that: `cmd > /tmp/<name>.log 2>&1; echo "exit=$?"; tail -n 20 /tmp/<name>.log`. The exit code survives (`cmd | tail -n 5` reports `tail`'s status, not `cmd`'s), and if the run fails, the details are one `grep -n -C3 <pattern> /tmp/<name>.log` away, with no re-run. Pipe straight into `grep -c`/`grep -q` only when the count or match is the whole answer.
14. [major] **L209 dispatch test.** Replace with:
    > Dispatch when a command's output is large or unpredictable and what you need from it is a distillation: which tests failed and why, every call site, whether the build warned. When you need every line itself (a diff you will review line by line), read it yourself in pieces: a relay adds a round trip and nothing else.
15. [major] **L224-229 dispatch contract.** Replace with:
    > The Task prompt gives the exact command and, for anything you will act on, a salience spec saying what you need, since a runner misjudging "salient" is the main failure mode.
    > Say when you need completeness ("every failing test with file:line and expected vs actual", "every call site as file:line"): the runner then lists every item instead of sampling.
    > For sweeps, a per-file shape ("matches per file, first 3 per file") beats a blind head/tail, which destroys a sweep's signal.
    > The report carries `Status`, a short `Summary:`, verbatim `Excerpt:` lines, a `Truncated:` field with a ready-to-run `see:` command, and the capture path.
    > If the report is not enough, do not act on a partial picture and do not re-run the command: run the `see:` command, read a bounded range of the capture (`sed -n`, `grep -n -C`), or dispatch the runner again with a narrower spec over the capture file.

    This drops the runner-internal 3-line, 4,000-character and two-command mechanics from the caller rule; `bash-runner.md` keeps them.

### `plugins/cdocs/rules/model-tiering.md`, `plugins/cdocs/AGENTS.md`

16. [nit] model-tiering L26: "a runner that drifts from verbatim extraction misleads the dispatcher or forces a follow-up" -> "a runner that drifts from the capture, or under-reports what the dispatcher asked for, misleads it or forces a follow-up".
    In model-tiering L25 and AGENTS.md L47: "concise fixed-format extract" -> "fixed-format report".

### Proposal and verification

17. [major] Add a completeness probe to the proposal's Test Plan, and make it part of any future acceptance bar.
    The probe is a multi-failure test run with an "every failure" spec, plus the same run with no spec, each checked against ground truth for completeness.
    It sits alongside the existing format and fidelity checks.
    [`_verify/2026-10-05-bash-runner-quality-canary.md`](../devlogs/_verify/2026-10-05-bash-runner-quality-canary.md) is a ready template.

## Questions for the Maintainer

**A. Report ceiling when the spec asks for completeness (item 6):**
- (a) ~12K: about 40% of the 30K Bash ceiling and far below the 53-77K raw outputs here. Recommended.
- (b) ~8K: covers about 50 one-line items; past that, truncate with a total.
- (c) Keep ~4K and rely on `Truncated:`/`see:`. Not recommended: E2 shows the format degrading under it.

**B. Where a complete per-item list goes:**
- (a) In `Excerpt:` as one command's output (an `awk` or `grep | cut`), so the verbatim rule still holds. Recommended: E1, E2 and B2 already do this.
- (b) A new `Findings:` field, between Summary and Excerpt, for runner-composed per-item lines grounded in the capture.

**C. Should the caller guidance name the self-capture pattern as the first cheap path, before dispatch (item 13)?**
- (a) Yes. Recommended: C1 shows an opus caller using it unprompted, at full quality, with no round trip.
- (b) No: keep the guidance runner-centric.
