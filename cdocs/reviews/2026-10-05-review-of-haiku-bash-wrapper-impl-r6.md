---
review_of: cdocs/proposals/2026-09-22-haiku-bash-wrapper.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T09:42:44-07:00
task_list: meta/token-spend-attribution
type: review
state: live
status: done
tags: [fresh_agent, implementation, rereview, live_canary, sonnet_runner, report_contract, fidelity, report_size]
---

# Review: Bash-Output Wrapper, Implementation Round 6 (Phases 1-2, Sonnet Runner)

> BLUF(opus-5-5/haiku-bash-wrapper-impl-r6): **Revise.**
> Sonnet fixes the haiku-specific failure: the build-warning attributions are now correct, and every runner turn ran on `claude-sonnet-5-5` with only `Bash`.
> Containment and Status hold in 6 of 6 runs.
> But Judge-1's bar fails on two criteria.
> (iii) Fidelity: both aggregate sweeps re-typed match lines with changed wording, one change undisclosed, inside 8.6-10 KB reports.
> (ii) Structure: d2 appended a prose `Summary:` after `Full output:`, the same class as r3 and r5.
> The prompt already forbids both, so the next fix should reduce how much the runner re-types, not add more prohibitions.

## Summary Assessment

Iteration 6 applies the maintainer's decision to run `cdocs:bash-runner` on sonnet.
It removes the prompt scaffolding that only compensated for haiku and adds an explicit fidelity rule and a strict `Truncated:` rule.
The doc changes are consistent, and the agent file is cleaner.
Live evidence ([`_verify/...-r6.md`](../devlogs/_verify/2026-10-05-bash-runner-live-canary-r6.md)) shows that the model switch closed r5 F1, the fabricated attribution.
It did not close the structure class, and it exposed a volume-driven transcription failure in the sweeps.
In both sweeps the runner ignored the ~4,000-character ceiling, then re-typed about 50 long lines and changed their content as it went.
Verdict: **Revise**.

## Prior Action Items (r5)

| r5 item | status |
|---|---|
| 1 [blocking] remove the licence to compose summary lines | **Partially addressed.** The "summarize = counts + key lines" sentence is gone, and d1/d2 have no fabricated count *line*. d2 still composes a prose summary paragraph with its own tallies (correct ones), and d1 puts prose in `Truncated:` |
| 2 [blocking] re-run d1/d2 to confirm 0 non-verbatim lines and exact structure | Done. Copied lines are 100% verbatim, but the structure is not exact (F2) |
| 3 [non-blocking] mechanical cue for false `Truncated: none` | Wording added. The sweeps now say non-`none`, but d1/d2 still say `none` after dropping the true final line (F3) |
| 4 [non-blocking] dispatch guidance favoring selection specs over "summarize" | Not done; it is now more relevant (see F2) |

## Live Canary Results (floor and Judge-1 bar)

| criterion | a | b1 | b2 | c | d1 | d2 |
|---|---|---|---|---|---|---|
| runner model sonnet, only Bash | yes | yes | yes | yes | yes | yes |
| (i) containment (no raw dump to parent) | yes (261 B) | yes, but 10.0 KB | yes, but 8.6 KB | yes | yes | yes |
| (ii) exact structure | yes | extra `Note:` prose | extra `Warn line` prose | yes | **prose in `Truncated:`** | **`Summary:` after `Full output:`** |
| (iii) verbatim fidelity | yes | **4 placeholders, 2 reworded** | **3 silent edits, 1 undisclosed** | `5001:` prefix | yes | yes (summary tallies are self-composed) |
| (iv) Status | OK, correct | WARNINGS, correct | WARNINGS, correct | WARNINGS, correct | WARNINGS, correct | WARNINGS, correct |

The floor holds: the agent loads, `seq 1 200000` returns `200000` in a bounded report, the parent holds no raw dump, no runner used a non-Bash tool, and no runner hit `maxTurns`.
Per-run token and cost figures are in the `_verify` file.
Runner `subagent_tokens` were 12.8-14.1K for the line-oriented runs and about 21.5K for the sweeps.

## Findings

**F1 [blocking]: sweep reports re-type match lines with changed content.**
b1's placeholders are not mere ellipses.
`iterate/SKILL.md:3:description: Run an indicated...` contains a word that is not in the line.
`workflow-patterns.md:27:The skill is a peer to /cdocs:iterate...` contradicts the real line, which says `/cdocs:implement`.
`ablate/SKILL.md:19:The invoking session agent enters...` is the wording of a different file.
b2 silently edited three lines: it changed `rev-N` to `rev-2`, dropped "as the overseer", and dropped "and restricts itself to orchestration".
The last edit is not disclosed anywhere in `Truncated:`.
Every count line was exact (23/23 in both runs), so the drift is in re-typing long prose lines, not in reading the capture.
The cause is volume.
The spec asks for 51 first-3 lines, and the runner emitted all of them (4.5K output tokens) instead of following the existing rule: "counts first, `Truncated:` for the rest", with the report "never more than about 4,000".
Suggested fix: make the ceiling bind for aggregate specs.
Return all count lines, then first-N detail only for as many files as fit, ordered by count, and put the rest in `Truncated:` with the ready `awk` command.
Instruct the runner to cut long lines with a command (for example `cut -c1-200`), copy that command's output exactly, and name the cut width in `Truncated:`.
A line that does not fit is omitted, never retyped as a placeholder or a paraphrase.
This keeps Step 2 unconstrained, per the binding steer, and limits only what the report carries.

**F2 [blocking, recurrence of the r3/r5 class]: prose outside the report fields in "summarize" probes.**
d2 appended a `Summary:` paragraph after `Full output:`.
d1 put four sentences of prose into `Truncated:`.
The prompt already says "no ... prose before or after it" and that a "summarize" spec "is still answered with capture lines and counts, never prose".
This has now recurred on two models across three wording rounds, so another prompt sentence is unlikely to hold.
There are two options, and the choice is the maintainer's (see Questions).
(a) Give the runner a sanctioned place for this content: an optional final `Notes:` field limited to one line, in which every name or number must come from a copied line.
(b) Move the fix to the dispatch side: r5 item 4's guidance in `orchestration-discipline.md` to phrase specs as selections ("the warning lines plus the final summary block") rather than "summarize".
The content of d2's summary was accurate, so F2 is a contract/UX issue, not misinformation.

**F3 [non-blocking, not a gate, reported per Judge-1]: `Truncated: none` is false in d1/d2.**
Both reports omit the capture's true final line, ``(Use `node --trace-deprecation ...` to show where the warning was created)``, and its header block (including `Version: 0.1.0`, which d1/d2 then cite in prose).
Both still say `none`.
This also violates "Keep the true end" for a summary spec.
The sweeps' `Truncated:` fields were non-`none`, but b1's undercounts its placeholders ("three", where there are four), and b2's omits one edited line.

**F4 [non-blocking, size follow-up]: report size.**
Sweep reports were 8.6 KB and 10.0 KB.
The other four runs were 0.3-1.4 KB.
Fixing F1 also fixes this.

**F5 [non-blocking]: `c` prefixes its warn lines with `grep -n` line numbers (`5001:npm WARN ...`).**
This is the output of a command the runner ran, but it is not capture text.
Either allow `grep -n` prefixes explicitly (they are useful for `sed -n` follow-ups) or ask for bare lines.

**F6 [observation]: b2's parent `Agent` call returned an async-launch stub, and the report arrived by `task_notification`.**
Containment is unaffected.
Any harness that treats the `Agent` tool_result as the report should expect this platform behavior.

### Doc changes (model-tiering, AGENTS.md, orchestration-discipline, proposal)

These are consistent.
`model-tiering.md` moves `bash-runner` into the sonnet tier with a rationale that matches the maintainer NOTE ("the saving comes from keeping raw output out of the parent's context").
The Precedence framing ("opts `bash-runner` down to sonnet") is correct.
No current-state "haiku" reference to `bash-runner` remains in `plugins/cdocs/` (checked by grep).
`AGENTS.md` and the dispatch contract read correctly.
The proposal NOTE is dated and attributed, and it cites r3-r5.

Non-blocking: the earlier steer NOTE in the proposal (Output Format area) still says "Runner-internal results cost only haiku context" and "the cheaper model is the main saving".
These are kept as history, which the new NOTE says, but the second phrase now contradicts the current rationale.
A one-line `(superseded by the 2026-10-05 sonnet NOTE)` suffix would prevent misreading.

Out of scope: `scripts/build-opencode.ts` `MODEL_MAP` maps sonnet to `anthropic/claude-sonnet-4-20250514`, which is possibly stale and does not block.

## Verdict

**Revise.**
F1 fails gate (iii), and F2 fails gate (ii).
Gates (i) and (iv) pass 6/6.
I recommend one more iteration rather than escalation.
F1 has a concrete, mechanical lever: binding the report volume for aggregate specs.
Unlike the r3-r5 haiku sequence, it is not another wording patch on the same failure.
F2 needs a maintainer choice (below) to avoid a fourth wording round.

## Action Items

1. [blocking] Bind the ~4,000-character ceiling for aggregate specs.
   The runner returns all count lines, then first-N detail for the top files that fit, and puts the rest in `Truncated:` with the `awk` command.
   It cuts long lines with a command and copies that command's output exactly.
   It never types placeholders or paraphrased lines.
   Re-run b1/b2 and diff every match line with `grep -qxF`, allowing a strict prefix only when the cut is disclosed.
2. [blocking] Resolve F2 using the maintainer's choice of (a), a sanctioned one-line `Notes:` field, or (b), dispatch-side selection-spec guidance plus re-wording the d probes.
   Re-run d1/d2 and confirm the exact field structure.
3. [non-blocking] Strengthen "Keep the true end" for summary specs so the capture's final line is always included.
   That makes `Truncated: none` honest in d1/d2.
4. [non-blocking] Decide on the `grep -n` prefix (F5).
5. [non-blocking] Mark the earlier steer NOTE's "cheaper model is the main saving" as superseded.

## Questions for the Maintainer

1. Prose in "summarize" probes (F2):
   - (a) Allow one optional `Notes:` line whose names and numbers must all come from copied lines.
   - (b) Keep the strict structure and fix it on the dispatch side (selection specs, not "summarize").
   - (c) Accept trailing prose as non-blocking when it is accurate, and drop exact structure for it from the bar.
2. Disclosed placeholders and cut lines in sweeps (F1):
   - (a) A disclosed strict-prefix cut is compliant, and any reworded or placeholder line is a failure (this review's reading).
   - (b) Only undisclosed alterations fail.
