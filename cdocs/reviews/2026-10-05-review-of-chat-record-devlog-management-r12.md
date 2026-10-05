---
review_of: cdocs/proposals/2026-09-22-chat-record-devlog-management.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T12:14:02-07:00
task_list: meta/chat-record-devlog-management
type: review
state: live
status: done
tags: [rereview_agent, pre_implementation, verification, compaction_removal, phase_scope, acceptance_criteria]
---

# Review: Chat Record, Scratchpoint, and Semantic Devlog Splitting (round 12, verification)

> BLUF(opus-5-5/chat-record-devlog-management): Every r11 finding (M1, M2, N1-N8) is resolved, and the text now matches the three settled answers: only the owner writes a Scratchpoint, thinness is read from `inline_work` alone, and Phase 1 is split into 1a and 1b.
> I ran the Phase-1a greps against the repo: all 45 hits from the first grep and all 7 from the second are planned removal targets, except the reseed line, which is meant to stay.
> Nothing outside `plugins/cdocs/{rules,skills,agents}` needs to change, and `bash-runner.md` and "Bash Output Hygiene" have no hits.
> One new major: Phase 1b's success criteria require "Phase 1a's two greps still hold", but 1b's own test script has to contain `/compact` and `/clear` scenarios under `plugins/cdocs`, so the second grep cannot stay clean.
> **Verdict: Revise.** The fix is one clause scoping the greps, so another review round is not needed: the overseer can apply it and confirm by reading, and Phase 1a can start now.

## Summary Assessment

The proposal specifies a hook-written per-session chat record, a rolling devlog Scratchpoint, the post-compaction resumption steps, and removal of cdocs' agent-side compaction instructions, in phases 1a (text) and 1b (capture).
The r11 revision is accurate.
The Scratchpoint, the judge, the iterate deliverables and the success criteria now agree.
No bare "Phase 1" reference is left.
Phase 1a's removal list matches the repo hit for hit.
The one defect is in an acceptance line (M1): Phase 1b's own deliverables break the second 1a grep, the same kind of problem as r11 M2.
The remaining findings are nits about how the repo reads between 1a and 1b, and about phrases the greps do not catch.

## Prior Findings (r11) Status

| r11 | Resolution in current text | Status |
|---|---|---|
| M1 Scratchpoint writer, staleness, definition drift | Owner-only throughout: the Summary table, the Scratchpoint "Writers" bullet (line 309-310), 1a deliverable 2 (Pillar 3 "only in a devlog it owns", `implement` top-level only), the 1a Constraint that leaves `implementer.md` unchanged, and Phase 3's "if it owns a devlog". Staleness is dropped. Thinness reads `inline_work` alone in "Not a thinness input" (312), Decision 10, and the OD, iterate, template and judge bullets (479, 483-485, 488) | resolved; matches the settled answers |
| M2 `triage.md` vs grep | Deliverable says "eight" columns and an unnamed "context-estimate column" (489). I confirmed eight columns remain after `overseer_ctx_est` is removed | resolved |
| N1 residual phrases | `oversee-arc.md:91`, `iterate/SKILL.md:144-146`, every "rising context" and "steady context", OD:238 and `oversee/SKILL.md:72` are all now in deliverable 1. The grep is widened (498) | resolved |
| N2 `--as` | The mapped value is checked against the `HEADER_RE` speaker part, and `user` is rejected case-insensitively (220). Unit tests cover `-x`, `_x` and `User` (428) | resolved |
| N3 `--minimal` | Creates no `cdocs/_chat/` (513) | resolved |
| N4 several devlogs | "every match is a root" (121); step 3 reads "each devlog that lists that path, newest Scratchpoint `as_of` first" (280) | resolved |
| N5 portability | `grep | tail -n 1` for the title, and a `date` plus `sed` form that runs on BSD (151-152) | resolved |
| N6 CI | The workflow file is in its own path filter (511). The merge test sets a local `user.name` and `user.email` (433) | resolved |
| N7 `hooks.json` description | 1b deliverable 1 | resolved |
| N8 timelessness | The "(today only ...)" parenthetical is gone | resolved |

Frontmatter bookkeeping: the r11 commit recorded `last_reviewed.round: 12`, one ahead of its file name.
This review keeps `round: 12`, so the counter and the review file names agree again.

## Phase-1a Grep Audit (check 2)

**First grep** (`ctx_est|150K|context.budget|...`): 45 hits in 11 files.

| File | Hits | Deliverable-1 bullet that removes them |
|---|---|---|
| `rules/orchestration-discipline.md` | 12 | Inline floor (52); thinness estimate and example (111) and rising-context (114); NOTE (119); Pillar 2 lead (123); Handoff heading and two sentences (126-129); cadence subsection (139, 143); Cross-Target `compact` equivalent and cadence sentence (238-239) |
| `skills/iterate/SKILL.md` | 8 | Inline floor (14); Checkpoint (129-134); Termination soft budget (144-146); Iteration Log paragraph (180) |
| `agents/judge.md` | 7 | Step 4 (45); escalate weighing (66-68); thinness definitions (79-81) |
| `skills/iterate/template.md` | 5 | Headers (10, 50); field (41); "rising context" (61); `signal_missing` (62) |
| `skills/oversee/SKILL.md` | 5 | Inline floor (13); Transition-write (72); concurrency cap (114); Checkpoint (127, 129) |
| `rules/oversee-arc.md` | 3 | Arc-state write and handoff (54-55); Decision step context budget (91) |
| `agents/triage.md` | 1 | Schema-drift note (62) |
| `skills/oversee/template.md`, `full-send`, `propose-revise`, `ablate` | 1 each | "before compacting" lines |

**Second grep** (`/compact\|/clear`): 7 hits.
The deleted cadence line (OD:141), the replaced Cross-Target sentence (OD:239), the deleted `oversee-arc.md:141` bullet, `iterate/SKILL.md:132`, and `oversee/SKILL.md:127,171` are all removal targets.
OD:148 is the reseed line, which the success criterion allows.

**Coverage outside the grep set.** A broad `compact` sweep adds only descriptive hits: the reseed subsection (147-160), `triage/SKILL.md:110`, `ablate/SKILL.md:121`, `graphify-scope.sh:4`, `iterate/SKILL.md:44`, `bash-runner.md:81`, and OD:134 (see N3).
Outside `plugins/cdocs`, nothing tracked mentions the removed terms or section names.
`plugins/cdocs/AGENTS.md` only `@`-imports the rule, the README only names the file, `scripts/*.ts` and `hooks/*.ts` do not parse rule text, and `.opencode/` is untracked build output.
Both greps can therefore pass after 1a, and the scope constraint "no file outside `plugins/cdocs/rules`, `skills`, and `agents`" is achievable.

**Concurrent workstream.** `agents/bash-runner.md` has no hit from either grep.
Its single broad hit, the adjective at line 81, is on the "descriptive mentions stay" list.
"Bash Output Hygiene" (OD:200-233) has no hit from either grep.
The only nearby 1a edit is the Cross-Target Degradation section after it (OD:235-240).
Neither is a removal target.

## Section-by-Section Findings

### Major

**M1. The 1b success criteria cannot pass the second 1a grep (Phase 1b success criteria vs Test Plan).**
1b's success line ends "Phase 1a's two greps still hold".
The second grep is `grep -rn '/compact\|/clear' plugins/cdocs`.
1b deliverable 2 puts `plugins/cdocs/hooks/tests/chat-record.test.sh` under that tree, and its headless list requires "stream-json `/compact` between two prompts" and "stream-json `/clear` then a prompt".
The script therefore has to contain both strings, and no honest implementation passes both criteria.
The README "Hooks" section (`plugins/cdocs/README.md`) and the Pillar 2 resumption text are also likely to mention `/clear` in a purely descriptive way.
That is legitimate, since the proposal's own Resumption section says `/clear` starts a new session.
The greps exist to catch *instructions* to compact, and those live in rules, skills, and agents.
Fix: scope both greps to `plugins/cdocs/rules plugins/cdocs/skills plugins/cdocs/agents`, which matches the 1a file-scope constraint and drops none of today's 52 hits.
Also do one of the following:
- say that the Pillar 2 resumption text names no slash command (write "a cleared or forked session");
- add any descriptive line it does need to the second grep's allowed hits.

### Nits

- **N1. Between 1a and 1b, Claude Code sessions get no rule to read the Scratchpoint (check 3).**
  After 1a, owners write a Scratchpoint every state-changing turn, but no on-Claude-Code rule tells a post-compaction or resumed reader to use it: step 3 ships in 1b.
  Meanwhile the 1a Cross-Target sentence gives off-Claude-Code targets exactly that guidance ("resumption reads the devlog's Scratchpoint and latest handoff").
  1a also removes the old implicit link, "handoff before compact".
  The repo stays coherent: nothing breaks and nothing contradicts.
  But Claude Code gets weaker resumption guidance than other targets, and the Scratchpoint is written but never read until 1b.
  Suggest a one-line reader rule in 1a's Scratchpoint subsection: "after a compaction or resume, read the Scratchpoint and latest handoff before acting".
  1b's step 3 then *replaces* that line and adds `chat-record path` and the record tail.
  Phrase it as a replacement so the Phase-2 A/B arm 1 ("step 3 removed") does not keep a stray copy.
- **N2. The "Writers" list reads as exhaustive but leaves out owners that the template and deliverables include.**
  Line 309 says the owner is "the overseer of any loop ..., or a Pillar-3 durable specialist".
  Deliverable 2, however, makes top-level `implement` reference the rule, and `devlog/template.md` gives every devlog a `## Scratchpoint`, including one a plain top-level session keeps.
  Say "the agent that owns the devlog (for example ...)", or add "or the top-level session that keeps it".
- **N3. Some phrases the greps miss.**
  - "The thinness columns" (OD:124, Pillar 2 lead) and "two additive thinness columns" (`iterate/SKILL.md:180`) become singular.
  - "re-litigated after the compact" (OD:134, Handoff format) presumes a scheduled compact. Write "after a compaction or in a fresh session".
  - `triage.md:62` names `overseer_ctx_est` twice: in the 05-18 clause and in the "all nine" clause. Deliverable 1's triage bullet should cover both.

  The consistency read (success criterion 3) and the first grep catch most of these.
  Listing them in deliverable 1 makes the implementer's work mechanical.
- **N4. The 1a constraint says too much.** "no file outside `plugins/cdocs/rules`, `skills`, and `agents` changes" forbids the implementation devlog and the proposal-status update.
  Write "no plugin file outside ...".

## Phase Independence (check 3)

- **1a lands and verifies alone.** It is text only.
  It is checked by two greps, which I confirmed can pass (subject to M1's scoping), and by one fresh consistency read.
  It needs no credentials or runtime.
  It has no dependency on 1b: it names no chat record, and the 1b-only items (per-turn rule, resumption steps, commit protocol, "no chat record off Claude Code") all sit in 1b deliverable 5.
- **The repo is coherent after 1a.** Handoffs still fire at task-unit boundaries (`iterate` Checkpoint on judge and Accept; `oversee` at proposal boundaries).
  The judge has one input and one definition, nothing schedules compaction, and implementers are unchanged.
  The one gap is read guidance on Claude Code (N1).
- **1b lands and verifies after 1a.** Its only dependency is stated (step 3 reads the Scratchpoint).
  Its verification is runtime: the unit suite in CI, the headless scenarios, and the interactive, rules and usefulness checks.
  Its carry-over criterion is M1.
- **Ordering into Phase 2** is unchanged and correct: the A/B measures 1b's step 3.

## New Issues From the Revision (check 4)

- M1 is new: the split created a cross-phase criterion that the earlier single-phase text did not have.
- N1 is new: splitting the phases separated the Scratchpoint's writer (1a) from its reader (1b).
- I found no other regression.
  Moving old deliverable 7's pieces left nothing behind: "`## Verification` as evidence home" went to 1a, "records quoted only in fences" went to 1b, and the "no compact instruction" constraint became the 1a greps.
  The Cross-Target sentence was split correctly between 1a and 1b.
  The Layer map, Edge Cases, and Test Plan only reference 1b, and they do so correctly.

## Verdict

**Revise.**
M1 is a one-clause edit to the grep scope, plus one sentence on what the Pillar 2 resumption text calls `/clear`.
It touches no settled decision and does not block starting Phase 1a.
After the fix, the overseer can confirm M1 by reading the 1a and 1b success lines; another full review round is not needed.
N1-N4 are optional.

## Action Items

1. [blocking] M1: scope both 1a greps to `plugins/cdocs/rules plugins/cdocs/skills plugins/cdocs/agents`. Also either keep `/compact` and `/clear` literals out of the Pillar 2 resumption text, or list any descriptive line as an allowed hit.
2. [non-blocking] N1: add a one-line Scratchpoint reader rule to 1a, which 1b's step 3 replaces.
3. [non-blocking] N2: make the Scratchpoint "Writers" list non-exhaustive, or add the top-level session that keeps a devlog.
4. [non-blocking] N3: add OD:124, OD:134, `iterate/SKILL.md:180` (plural), and both `triage.md:62` clauses to deliverable 1.
5. [non-blocking] N4: write "no plugin file outside ..." in the 1a constraint.

## Questions for the Maintainer

1. How should a post-compaction reader learn about the Scratchpoint between 1a and 1b (N1)?
   - (a) Add a one-line reader rule in 1a, which 1b's step 3 replaces.
   - (b) Leave it until 1b and accept the gap, since 1b follows directly.
2. Where should the second grep's allow-list live (M1)?
   - (a) Scope the greps to rules, skills and agents, and keep Pillar 2's resumption text free of slash-command literals.
   - (b) Scope the greps the same way, and allow a descriptive `/clear` line in Pillar 2.
