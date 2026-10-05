---
review_of: cdocs/proposals/2026-09-22-chat-record-devlog-management.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T12:04:28-07:00
task_list: meta/chat-record-devlog-management
type: review
state: live
status: done
tags: [rereview_agent, pre_implementation, verification, compaction_removal, thinness_signal, phase_scope, test_plan]
---

# Review: Chat Record, Scratchpoint, and Semantic Devlog Splitting (round 11, verification)

> BLUF(opus-5-5/chat-record-devlog-management): All twenty r10 findings are resolved, and the text matches the three maintainer answers (`/clear` is a fresh start, Phase 1 removes agent-side compaction, activation needs the git toplevel and `cdocs/_chat/`).
> Two new majors came from the compaction removal, and each takes a few lines to fix.
> First, the Scratchpoint now replaces `overseer_ctx_est` as a thinness input, but in an iterate loop it has two possible writers, and its staleness rule needs a timestamp the Iteration Log does not have.
> Second, the `triage.md` deliverable names `overseer_ctx_est`, which the Phase-1 success grep requires to be absent.
> **Verdict: Revise.** The fixes can be applied directly, and checking them is a short read.

## Summary Assessment

The proposal specifies a hook-written per-session chat record, a rolling devlog Scratchpoint, the post-compaction resumption steps, and removal of cdocs' agent-side compaction instructions.
The r10 revisions are accurate and well placed, and the hook contract can be implemented as written: modes, the `Stop` table, plan mode, `stop_hook_active`, activation, `--as`, `.gitattributes`, tests and CI are all specified.
I grepped `plugins/cdocs` and checked the removal list (r10 M6) against it.
Every file and section it names exists, and nothing it removes leaves a broken mechanical reference.
The weak spot is the thinness signal after `overseer_ctx_est` goes (M1), plus one contradictory acceptance line (M2).
A few residual phrases fall outside the success grep (N1).

## Prior Findings (r10) Status

| r10 | Resolution in current text | Status |
|---|---|---|
| C1 `/clear` | Resumption covers compaction only; `/clear` and `--fork-session` are a new session with no step (lines 282-283, 368-371); Design Decision 3; Phase-2 A/B forces `/compact`; test asserts the new file and id | resolved, matches maintainer answer |
| M1 activation | Walk-up bounded by `git rev-parse --show-toplevel`, record dir must be `cdocs/_chat/` (107-108); unit test covers `~/cdocs/` above toplevel | resolved (both gates) |
| M2 `--as` | Session-token mapping; empty, leading `.`/`-`, and `user` rejected (218-219); unit tests | resolved; one gap in N2 |
| M3 plan mode | `Stop` table rows 2-3, Edge Case, headless and unit tests | resolved |
| M4 merges | `cdocs/_chat/.gitattributes` `*.md merge=union`; earliest-dated on multiple matches; merge and rebase unit test | resolved |
| M5 cross-target | Scope sentence "Claude Code top-level session only"; Edge Case says other targets keep no record; `cdocs-hooks.ts` header in deliverable 4 | resolved |
| M6 compaction | Deliverable 6 removes the cadence, 150K, compact steps, and `overseer_ctx_est`; handoffs stay at task-unit boundaries | resolved per maintainer; see M1, M2, N1 |
| M7 Scratchpoint ordering | Scratchpoint subsection and template section are Phase 1 (deliverables 5, 7); splitting stays Phase 2 | resolved |
| M8 long pastes | `tail -n 80`, widened by an offset read | resolved |
| M9 tests and CI | `/clear`, fork, `--as`, stdout, plan, `cd`, union-merge scenarios; `--unit` in `.github/workflows/cdocs-hooks.yml` | resolved; CI nit in N6 |
| N1-N10 | Stdout rule, interrupt row, `path` form, `100755`, built-ins generalized, rename lag, non-loop staging, double hooks, "whether or not you are overseeing", append atomicity softened | all resolved |

The "Bash Output Hygiene" section revised in 54f040c does not conflict with the proposal.
The proposal does not edit that section, and its only edit nearby is the Cross-Target Degradation sentence after it.
Step 3's bounded `tail -n 80` read follows the section's "bound what you read" guidance.
The per-turn scope sentence also keeps a dispatched `cdocs:bash-runner` from running `chat-record`.

## Removal List Audit (check 2)

Grep: `compact`, `/clear`, `150K`, `ctx_est`, `context budget`/`context-budget`, `rising context`, `handoff-before-compact` over `plugins/cdocs`.

- Every file and section named in deliverable 6 exists, at the lines the bullets describe.
- Nothing outside `plugins/cdocs` refers to them: no test, script, CI job, or `.ts` file reads `overseer_ctx_est` or the cadence, and this repo has no materialized `.claude/rules/cdocs.md` to go stale.
- The `judge.md` workflow step, verdict text, and `overseer_thinness` definitions all fall under the deliverable's "read the `inline_work` column and the Scratchpoint staleness condition".
  The template's header, field list, and example row are listed, so no mechanical reference dangles.
- These hits are not in the list and survive the success grep: `oversee-arc.md:91` ("the overseer's own context budget"), `iterate/SKILL.md:144,146` ("soft context-budget signal", "soft budget"), "rising context" at `orchestration-discipline.md:114`, `iterate/template.md:61`, and `judge.md:67,80` ("steady context" at :79), `orchestration-discipline.md:238` ("`compact` equivalents"), and `oversee/SKILL.md:72` ("handoff-before-compact"); see N1.
- Descriptive hits that rightly stay: the reseed subsection, `triage/SKILL.md:110`, `ablate/SKILL.md:121`, and the adjective uses in `graphify-scope.sh`, `iterate/SKILL.md:44`, and `bash-runner.md`.

## Section-by-Section Findings

### Major

**M1. The thinness signal that replaces `overseer_ctx_est` is underspecified (Scratchpoint; deliverables 5-7).**
After the removal, the judge's `overseer_thinness` rests on two inputs: `inline_work` and Scratchpoint freshness.
The second input has three gaps:
- *Writer.* "One `## Scratchpoint` section in the devlog the agent owns" names the loop overseer and "any Pillar-3 durable specialist" as writers, and deliverable 7 has `implementer.md` tell a warm implementer to "maintain one".
  In `iterate`, the warm implementer is the Pillar-3 specialist, and it writes into the overseer's loop devlog, where `implementer.md:40` limits it to `## Changes Made` and `### Implementer Notes`.
  The implementer would then either replace the overseer's section, which breaks single-writer ownership and lets implementer writes mask a stale overseer, or add a second `## Scratchpoint`, which contradicts "one".
- *Staleness.* "`as_of` older than two Iteration Log rows" cannot be computed, because the Iteration Log has no time column.
  The nearest timestamps are the Dispatch/Return Events `at` values, which the judge's workflow does not read.
- *Definition drift.* The Scratchpoint section and the `judge.md` bullet make a stale or absent Scratchpoint produce `signal_missing`, but the `iterate/template.md` bullet keys `signal_missing` on the `inline_work` column alone.

Fix:
- The `## Scratchpoint` belongs to the devlog's owner, which in `iterate` is the overseer.
  A warm implementer keeps the same fields as a `#### Scratchpoint` inside its `### Implementer Notes`, or keeps none in `iterate` (Question 1).
- Define staleness as "`as_of` earlier than the `at` of the second-latest reviewer `return` event".
- Have `judge.md` read the Scratchpoint and the Events table.
- Give the template the same `signal_missing` definition as the Scratchpoint section.

**M2. The `triage.md` deliverable contradicts the Phase-1 success grep (deliverable 6 vs Constraints).**
Deliverable 6 says `triage.md` "names `overseer_ctx_est` as a column older devlogs may carry".
The Constraints require `grep -rn 'ctx_est\|150K' plugins/cdocs` to be empty.
No implementation can satisfy both.
Fix: have `triage.md` say "a context-estimate column", or exclude `agents/triage.md` from the grep.
Widen the grep as N1 suggests.

### Nits

- **N1. Residual phrases.** Add the audit's unlisted hits to deliverable 6.
  The `oversee-arc.md:91` "context budget" clause asks the arc overseer to weigh its own context, which the non-goal forbids.
  The rest are leftover framing from the estimate.
  Widen the constraint grep to `grep -rniE 'ctx_est|150K|context.budget|rising context|handoff-before-compact' plugins/cdocs` (minus the `triage.md` case in M2) so acceptance is mechanical.
- **N2. `--as` edge.** The mapping keeps `_`, but `HEADER_RE` needs an alphanumeric first character, so `--as _x` passes validation and writes a body line, which is the r10 M2 failure.
  Validate the mapped result against the speaker part of `HEADER_RE`, and reject `user` case-insensitively (`@User:` reads as a human).
- **N3. `/cdocs:init --minimal`.** It skips "README generation and rules file creation" but still creates directories.
  State that `--minimal` does not create `cdocs/_chat/`, so the hooks never run without the rule.
- **N4. Several devlogs per record.** A session that works on several devlogs lists its record in each, which is the normal case for `/cdocs:oversee` interleaving.
  "The devlog for a record" (line 121) and step 3 are singular.
  Say "each devlog that lists it, newest Scratchpoint `as_of` first".
- **N5. Portability.** `tac` is GNU-only and missing on stock macOS, so titles there fall back silently to sid8.
  Use `grep '"type":"custom-title"' "$transcript_path" | tail -n 1`, or state that the script targets GNU userland, and say the same for `date -Iseconds`.
- **N6. CI details.** Add `.github/workflows/cdocs-hooks.yml` itself to the workflow's path filter, as `opencode-build.yml` does.
  The union-merge unit test must set a local `user.name`/`user.email` to commit on a fresh runner.
- **N7. `hooks.json` description.** Its `description` string lists the hooks' purposes; add the chat record.
- **N8. Timelessness.** Deliverable 3's "(today only `AGENTS.md` inlines it)" is temporal; write "`AGENTS.md` otherwise inlines it" or drop it.
  The rest of the document is present-tense and history-free, with the history in the report, as it should be.

## Phase-1 Scope (check 3)

Phase 1 now touches about 24 files and carries two kinds of verification: runtime evidence for the hooks, and a grep plus a consistency read for the text edits.
It is still coherent: no deliverable is circular, and the success criteria are concrete.
I recommend splitting it anyway, which is not blocking:

- **Phase 1a (text only):** deliverable 6, the Scratchpoint subsection and template section, the thinness rewire in `judge.md`, `iterate`, and the template (M1), the Pillar 2 handoff renames, and the loop-skill one-liners.
  Verified by the widened grep (N1) and one consistency review; no credentials and no runtime.
- **Phase 1b (capture):** script, hooks, tests, CI, init scaffolding, README, the per-turn rule, the three resumption steps, the commit protocol, and the interactive, rules, and usefulness checks.

Three reasons for the split:
- The thinness rewire depends on the Scratchpoint definition, not on the hooks, so the two belong together.
- The state between 1a and 1b is coherent: handoffs stay at task-unit boundaries, a Scratchpoint exists, and nothing schedules compaction.
- 1b's iterate reviewers then judge runtime evidence without also auditing a dozen prose edits.

If the maintainer prefers one phase, the deliverable order already puts the text edits after the capture work, and that order is enough.

## Implementer Completeness (check 4)

- **Hook modes and `Stop` table:** the table is exhaustive over last marker × `stop_hook_active` × `permission_mode`.
  The guards (`agent_id`, opt-out, missing `jq`/`git`, no `_chat/`, no record) and the stdout rule leave no open case.
- **Activation, `--as`, `path` form, multiple matches, `.gitattributes`:** specified and unit-tested, apart from N2.
- **Tests and CI:** the headless and unit suites map to every behaviour above; the CI job has a named file, trigger, and runner; N6 covers the small gaps.
- **Scratchpoint and judge:** M1 is the one real ambiguity.

## Verdict

**Revise.**
M1 and M2 are small edits to the text: an ownership sentence, a staleness definition, aligning one template bullet, and one word in the `triage.md` deliverable.
None of them reopens a settled decision.
After the fixes, a verification read of deliverables 5-7 and the Constraints line is enough.

## Action Items

1. [blocking] M1: give the `## Scratchpoint` to the devlog owner (the overseer in `iterate`), and place or drop the warm implementer's Scratchpoint (Question 1).
   Define staleness against Dispatch/Return `at`, have `judge.md` read the Scratchpoint and the Events table, and align the `iterate/template.md` `signal_missing` definition.
2. [blocking] M2: make `triage.md` describe the old column without its name, or exclude it from the success grep.
3. [non-blocking] N1: add the residual phrases to deliverable 6 and widen the grep.
4. [non-blocking] N2: validate the mapped `--as` value against the `HEADER_RE` speaker form; reject `user` case-insensitively.
5. [non-blocking] N3-N8 as listed.
6. [non-blocking] Consider splitting Phase 1 into 1a (text) and 1b (capture), per "Phase-1 Scope".

## Questions for the Maintainer

1. In `iterate`, where does the warm implementer keep its Scratchpoint?
   - (a) A `#### Scratchpoint` inside its `### Implementer Notes` (same fields; the judge ignores it).
   - (b) Nowhere in `iterate`: the overseer's Scratchpoint plus the implementer's return summary suffice; only a specialist that owns its devlog keeps one.
   - (c) Its own devlog, linked from the loop devlog.
2. Phase-1 shape:
   - (a) Split into 1a (text: compaction removal, Scratchpoint, thinness rewire) and 1b (capture).
   - (b) Keep one phase.
