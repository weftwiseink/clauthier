---
review_of: cdocs/proposals/2026-09-22-haiku-bash-wrapper.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T10:05:00-07:00
task_list: meta/token-spend-attribution
type: review
state: live
status: done
tags: [fresh_agent, implementation, prompt_robustness, haiku_compliance, live_canary, cap_safety]
---

# Review: Haiku Bash-Output Wrapper, Implementation Round 1 (Phases 1-2)

> BLUF(opus-5-5/oversee): **Revise**, one small blocking fix.
> The containment floor passes and is reproduced live (`confirmed`): the parent got a 970-char report with the true last line `200000`.
> The runner's own extraction bound is not robust under haiku, though.
> The agent prompt's "Useful shapes" examples break its own `| cut -c1-150 | head -n 10` MUST rule, and haiku copied the looser shape, which produced 2,671- and 3,988-char runner results against the ~2K cap-safety steering.
> The rest is accurate.
> The rule edits, README count, OpenCode build, and deferred-cap text all check out, apart from small non-blocking items.

## Summary Assessment

Phases 1-2 add the `cdocs:bash-runner` haiku agent, a "Bash Output Hygiene" dispatch convention in `orchestration-discipline.md`, a named haiku carve-out in `model-tiering.md`, and README updates.
The capture-to-file-then-extract design works as specified.
Every live run kept the raw dump out of the parent, and the subshell capture form with stdin closed is a real improvement over the proposal's sketch.
The weak point is haiku compliance with the extraction bound.
The prompt states the bound as a MUST and then shows examples that leave out half of it, so it gets violated in practice.
That doesn't threaten containment, because runner-internal results never reach the parent.
It does break the overseer's cap-safety steering, and it inflates the runner's own context.
Verdict: **Revise**.
Fix the prompt's bound instruction (item 1).
Everything else is non-blocking.

## Verification

**Containment canary, re-run by this reviewer (`confirmed`).**
Command: `claude -p --plugin-dir plugins/cdocs --model sonnet --output-format stream-json --verbose --dangerously-skip-permissions '<canary prompt>'`.
The raw stream sits in this reviewer's session scratchpad (`.../e3afd4a9-.../scratchpad/canary-r1.jsonl`, 18,809 bytes, ephemeral).
I extracted it with jq; `parent_tool_use_id` set means the call came from the runner.

```
TOOL[parent] model=claude-sonnet-5-5 Agent: Run: seq 1 200000 ; and return the exit code and last line.
TOOL[runner] model=claude-haiku-4-5-20251001 Bash: OUT="/tmp/bash-runner-$(date +%s%N).log"⏎(⏎seq 1 200000⏎) > "$OUT" 2>&1 < /dev/null⏎echo "exit=$? ..."
TOOL[runner] model=claude-haiku-4-5-20251001 Bash: tail -n 1 /tmp/bash-runner-1791216602404253778.log | cut -c1-150
RESULT[runner] chars=78 / chars=6 ; RESULT[parent] chars=970
Final: BASH RUNNER REPORT / Exit code: 0 / Status: OK / 200000 / Full output: saved to /tmp/bash-runner-...log (1288895 chars, 200000 lines; ...)
```

The string `199999` never appears anywhere in the whole stream (`grep -c` gives 0), so no raw output reached the parent.
The runner used only Bash.
The overseer's four runs in `cdocs/devlogs/_verify/2026-10-05-bash-runner-live-canary.md` agree with this: containment, buried error, and fail-no-spec all pass, and the aggregate sweep passes containment.

**Build.**
`npm run build:cdocs` reports `Agents converted: 7`.
The built `agents/bash-runner.md` has `bash: true` and `read`/`edit`/`write: false`.

**Not re-verified:** the `/cdocs:init` freshness-hook nudge.
The implementer reports sandbox evidence for it (hash `37b01a5f` to `fd12e2bd`), and that evidence is plausible.

## Section-by-Section Findings

### `plugins/cdocs/agents/bash-runner.md`

**F1 [blocking] The extraction bound contradicts itself, and haiku follows the looser example.**
Step 2 says: "EVERY extraction command MUST end in `| cut -c1-150 | head -n 10`".
The first "Useful shapes" bullet then shows `tail -n 10 <file> | cut -c1-150` and `head -n 10 <file> | cut -c1-150`, with no trailing `head`.
Every runner tail call in the live evidence copies that shape:

- grepsweep ran `tail -n 20 ... | cut -c1-150`, a 2,671-char result.
- My canary ran `tail -n 1 ... | cut -c1-150`, which was harmless.

The grepsweep run also ran `awk ... | cut -c1-150 | head -n 30`, a 3,988-char result.
That run kept both stages but raised N to 30, because the prompt says "(or a smaller bound)" and nowhere forbids a larger one.
Separately, fail-no-spec ran `cat <file> | cut | head`, which breaks "Never `cat` the capture file", though the result was bounded.
So haiku treats the bullet list as the real contract and the MUST line as advisory.

On overseer concern 1, my answer is that the instruction is not strong or clear enough for haiku.
Containment is unaffected, so this is not a floor failure.
It matters for three reasons:

1. The overseer's explicit steering (runner results and report at or under ~2K chars) was breached 2 times in 4 calls on a single run.
2. If the deferred cap RFP ever ships a cap in the 4,000-8,000 band, a 3,988-char extraction sits right at the cliff.
3. Unbounded extraction is the runner-context growth that `maxTurns: 8` is supposed to contain.

Fix:

- Make every example literally compliant, for example `tail -n 10 <file> | cut -c1-150 | head -n 10`.
- Restate the bound as a fixed suffix: "the last two pipeline stages are always exactly `| cut -c1-150 | head -n 10`; never raise 10."
- Turn the `cat` prohibition into a positive instruction: "to view a short file, use `head -n 10 <file> | cut -c1-150`."

**F2 [non-blocking] A 10-line salient budget cannot hold an aggregate spec over many files (overseer concern 2).**
"Matches per file plus first 3 per file" over 21 files needs at least 21 + 63 lines.
Under the 10-line rule, the request can't be satisfied.
In the grepsweep report, haiku dealt with this in three ways:

- It went over the budget, with about 13 salient lines including headers and a blank line.
- It paraphrased instead of copying verbatim: "(and 4 more files with 5 matches each)".
- It sampled only 3 files for the first-3 section, with no clear signal that the spec was cut short.

The parent noticed the gap only because it read closely.
The Test Plan item ("per-file grouping, not a flat head/tail") is still met, because the counts are grouped.
Recommendation: add a rule to Step 3 for this case.
When an aggregate spec can't fit, prefer the per-file counts, which are the densest signal.
Then end with one fixed line: `[spec truncated: <what was omitted>; see capture file, e.g. awk -F: 'c[$1]++<3' <path>]`.
Put the matching guidance in the dispatch contract in `orchestration-discipline.md`: an aggregate spec should ask for counts, plus detail for the top few files only.

**F3 [non-blocking] Capture path and lifetime claim (overseer concern 3).**
The `${TMPDIR:-/tmp}` fallback is acceptable.
Under `claude -p`, no scratchpad appears in the runner's environment: all five live runs, mine included, wrote to `/tmp`.
Without the fallback, the agent would have no path to use.
Interactive sessions do list a subagent scratchpad, and this reviewer, a dispatched agent, has one.

Two consequences need addressing:

- (a) The fixed report line hard-codes "session-scoped scratch, disposable", which is false for `/tmp`.
  These files persist until reboot.
  `/tmp` now holds 5 `bash-runner-*.log` files totalling 3.9M, and on Fedora `/tmp` is a RAM-backed tmpfs.
  Make the lifetime phrase conditional ("scratchpad, session-scoped" vs. "/tmp, persists until reboot"), or drop it.
- (b) The deviation is recorded only in the devlog.
  Per Commentary Decoupling, the proposal needs it too (see F6).

**F4 [non-blocking] `Status: WARNINGS` is rarely reached.**
None of the live runs ran the `grep -acE 'warn|WARN'` count that Step 3 depends on.
For default-heuristic dispatches, consider folding the warn count into the Step 1 echo (`warn=$(grep -acE 'warn|WARN' "$OUT")`).
That makes the classification deterministic and costs no extra call.

The rest of the agent file is sound:

- The frontmatter matches the proposal (`model: haiku`, `tools: Bash`, `maxTurns: 8`).
- The newline-before-`)` subshell guard is a good catch.
- Telling the runner to reuse the literal path, never `$OUT`, is correct given that each call gets a fresh shell.
- The Constraints section explicitly allows bounded extraction, which was the proposal's "literal-minded haiku" concern.

### `plugins/cdocs/rules/orchestration-discipline.md` ("Bash Output Hygiene")

The section is accurate and matches the proposal's when-to-dispatch order: sweeps, then builds/tests/installs, then unboundable commands.
It explicitly excludes short-output and interactive commands.
Its "Fork for side-context" cross-reference resolves (line 175).
It contains no `bashOutputMaxChars` or cap recommendation.
It frames residual risk correctly ("platform's built-in Bash output ceiling") and follows the writing conventions.

**F5 [non-blocking]** "grep or read the named capture file" assumes the parent can reach the runner's path.
That holds for `/tmp`, and for the session scratchpad if the parent and subagent share it.
It's fine as written, but F2's truncation line should show a ready-to-run follow-up command.

### `plugins/cdocs/rules/model-tiering.md`

This is accurate.
It names `bash-runner` as a second haiku case after `nit-fix`, and it keeps the consumer-floor-wins Precedence framing that the proposal requires.
It says nothing about a cap.

### `plugins/cdocs/README.md`

The OpenCode agent count changes from 6 to 7, which matches the build output.
The note that `bash-runner` reads no rules sits correctly after the path-resolution caveat.
Non-blocking: the curated "Formal Agents" lists in `plugins/cdocs/AGENTS.md` (line 40) and `rules/workflow-patterns.md` (line 110) don't mention `bash-runner`.
Those lists already leave out `implementer`/`proposer`, so this is not a regression.
Still, `bash-runner` is a dispatch target that any agent is told to use, so a one-line entry in AGENTS.md would help consumers find it.

### Proposal revision (commits 531b17e, ac75f43, 075ec2c)

The cap deferral is applied consistently in the BLUF, Summary, Objective, Proposed Solution, the division-of-labor table, Design Decisions, Edge Cases, Test Plan (no `bashOutputMaxChars` recommendation), Phases, and Resolved Decisions.
The RFP stub (`2026-10-05-bash-output-cap-rfp.md`) carries the evidence faithfully and asks the right central question (runner composition).

**F6 [non-blocking] Leftover inconsistencies:**

- "Capture file location and lifetime" (Edge Cases) and "Maintainer decision - capture-file location" say the file always goes in the scratchpad, "cleaned with the session and needs no explicit teardown".
  In `-p` runs this doesn't hold (F3).
  Add a `NOTE(...)` there recording the `${TMPDIR:-/tmp}` fallback and its lifetime.
- "Q4 cap value: 6,000 chars" still reads as a resolved decision.
  The qualifier comes only in the last bullet.
  Inline "(carried to the RFP, not shipped)" on Q4 itself.
- "Q2 now governs only..." uses "now".
  That's tolerable in a traceability section, but "Q2 governs only..." reads cleaner under History-Agnostic Framing.

### Implementer devlog notes

The notes are thorough.
The deviation NOTE is honest, and the emulated-procedure verification is useful.
The notes correctly flagged live dispatch as unverified, and the overseer canary closed that gap.

## Verdict

**Revise.**
The verification floor (containment canary) passes, reproduced live by this reviewer.
One blocking fix is needed before acceptance: make the runner prompt's extraction bound unambiguous and make its examples follow it (F1).
That's a small prompt edit.
After it, a single re-run of the grepsweep canary should show every runner result under ~1,500 chars.

## Action Items

1. [blocking] In `bash-runner.md` Step 2, make every "Useful shapes" example end in `| cut -c1-150 | head -n 10`.
   Restate the bound as a fixed, non-raisable suffix ("never raise 10").
   Replace the bare `cat` prohibition with a compliant alternative.
   Re-run the grepsweep canary and confirm every `RESULT[runner]` is at most ~1,500 chars.
2. [non-blocking] Add an aggregate-overflow rule to Step 3: counts first, then one fixed `[spec truncated: ...; see capture file, e.g. <cmd>]` line, with no paraphrased lines.
   Mirror the "counts plus top few files" advice in the dispatch contract in `orchestration-discipline.md`.
3. [non-blocking] Make the report's lifetime phrase reflect where the file actually went (scratchpad vs. `/tmp`).
4. [non-blocking] Add a NOTE to the proposal's "Capture file location and lifetime" edge case about the `${TMPDIR:-/tmp}` fallback under `claude -p`.
   Inline "carried to the RFP" on Resolved Decision Q4.
5. [non-blocking] Fold the warn count into the Step 1 echo so that `Status: WARNINGS` is deterministic.
6. [non-blocking] Add a `bash-runner` (haiku) line to the "Formal Agents" list in `plugins/cdocs/AGENTS.md`.

## Questions for the Maintainer

- **Q-A: aggregate overflow.** (a) Counts plus a truncation pointer, as in F2. (b) Raise the salient budget to 20 lines for aggregate specs only, which is still about 3K chars. (c) Leave it to the dispatcher to write specs that fit.
  Reviewer leans (a).
- **Q-B: `/tmp` capture accumulation.** (a) Accept: tmpfs clears on reboot. (b) Have the runner delete captures older than a day under `/tmp/bash-runner-*` in its Step 1 call. That would expand its file-mutation surface. (c) Leave it to the RFP or a later proposal.
  Reviewer leans (a) plus the honest wording from item 3.
