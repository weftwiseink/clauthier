---
review_of: cdocs/proposals/2026-10-05-rules-context-decomposition-rfp.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T09:57:37-07:00
task_list: cdocs/rules-context-decomposition
type: review
state: archived
status: done
tags: [fresh_agent, implementation_review, rules, context_budget, live_smoke, evidence_audit]
---

# Review: Rules Context Decomposition, Implementation r1

## Summary Assessment

Implementation r1 of the rules context decomposition (commits `209ec08..a57c78e`, notes in the loop devlog's "Implementation Notes (impl-1)") compresses the always-loaded rules to 297 lines / 2,145 words, deletes `oversee-arc.md` and the thinness, claim-registry, and Cross-Target machinery, and files the follow-up RFP.
The rewritten rules match the proposal's wording, keep every load-bearing lesson, and read as coherent, actionable guidance for a cold lead.
Every static check re-runs clean, the `rules_check` failure is identical on both trees, and the loop smoke evidence is adequate for a no-regression floor.
The findings are nits plus two misattributions in the implementer's smoke notes, so the verdict is **Accept**.

## Static Checks (re-run by this reviewer)

| check | result |
|---|---|
| `npm run build:cdocs` | exit 0; `build/cdocs/opencode/rules/` lists the five rule files |
| `bash plugins/cdocs/hooks/tests/chat-record.test.sh --unit` | `95 passed, 0 failed` |
| frontmatter validator (proposal, loop devlog, follow-up RFP) | silent, rc 0 |
| Test Plan dead-reference grep over `plugins/cdocs CLAUDE.md` | one hit, `CLAUDE.md:54:### Cross-Target Rules Architecture` (the allowed one) |
| `wc -l -w plugins/cdocs/rules/*.md` | 297 / 2,145 (orchestration 64 / 683): within the ~300 / ~2,200 and ~70 / ~700 guideline |
| Bash section of `orchestration-discipline.md` | byte-identical to `209ec08^` (`diff` empty) |
| `postinstall.js` `rmSync` target | `RULES_DEST` is `.opencode/rules/cdocs` (namespaced), so the clear cannot touch a user's other rules |

Inbound links: every heading named by a pointer in `plugins/cdocs`, `README.md`, `AGENTS.md`, and root `CLAUDE.md` ("Stay thin", "Resume from disk, not memory", "Durable state", "Chat record", "Bash: Avoid context bloat...") exists in the new rule.
A wider sweep for retired section names (`Summary absorption`, `Resume-by-name`, `Handoff format`, `Commit protocol`, `since_handoff`, `Injection points`, `Column Semantics`) is empty.
Stale references remain only in live `cdocs/` docs outside the proposal's inbound list (see Findings 5 and 6).

## Section-by-Section Findings

### 1. Rule files read whole as a fresh lead

`orchestration-discipline.md` reads cleanly top to bottom.
Each heading is a lesson, each line is an instruction, and no line depends on a deleted section.
The checklist of load-bearing lessons is all present:

- resume from disk and liveness ("Resume from disk, not memory"),
- single writer, serialize when overlap is unsure, and explicit-path staging ("One writer per file"),
- dispatch/return rows (rule line 1 of "Resume from disk", plus `iterate` Turn N.a),
- fresh reviewer and judge (rule isolation line plus each loop skill's inline floor and `iterate` "Freshness disciplines"),
- handoffs at task-unit boundaries ("Durable state"),
- `confirmed` needs this round's evidence (`iterate` `review_proof`),
- the overseer lands, merges, and forks ("Stay thin" last line),
- `/oversee` top-level only (skill NOTE),
- verification floor depth and isolating faults before costly retries ("Verification and stuck loops").

`model-tiering.md` and `workflow-patterns.md` match the proposal text verbatim.
Nothing reads as over-formal, and nothing is cut so far that it becomes ambiguous.
The one place a cold reader might hesitate is "The harness notifies you only when *no* children remain live", which only makes sense with the sentence after it; it does have that sentence, so this is fine.

**Non-blocking.** `propose-revise` keeps its devlog optional ("If the overseer keeps a devlog"), while the rule says to log every dispatch and return in "the devlog".
A propose-revise run without a devlog has nowhere to put rows.
This is pre-existing and arguably fine (short proposal loops), but one clause in either place would remove the gap.

### 2. Skills, templates, and agents

`iterate/SKILL.md` keeps Invocation, Graphify (untouched), Roles, Turns 0 through N.d, the inline floor, freshness, and the row instruction.
It drops the Mermaid diagram, the isolation restatements, `pause`, the thinness paragraphs, and the five Steering kinds, as specified.
`iterate/template.md` gives the five fields, the seven-column Iteration Log, an empty Steering Log heading, and example rows behind a "do not copy" separator.
The smoke lead copied it exactly as intended: an empty Steering Log and no example row in the live devlog.
`oversee/SKILL.md` and its template match the proposal's arc sections.
`judge.md` carries the compressed output contract and the one prose line about an overseer doing the work itself.

**Non-blocking (pre-existing bug, observed in this loop's evidence).** `iterate/SKILL.md` line 89 still says to dispatch the reviewer with `subagent_type: "reviewer"`.
The baseline smoke lead followed it literally and got `Agent type 'reviewer' not found`, then retried with `cdocs:reviewer`.
The new-tree lead happened to use `cdocs:reviewer`.
It is a one-word fix in a file this proposal already rewrote.

**Non-blocking.** Two minor details from the old `iterate` text are gone without a replacement:
- under `override-judge`, the Judge Log row is never edited,
- the weftwise cross-worktree routing hint (route a merge into `main` to the consumer's `/resolve-wt`-style commands).

Both are fine to drop under the maintainer's stance, since the consumer's own `CLAUDE.md` owns its worktree commands.
They are listed here only so the drop is deliberate.

### 3. Implementer's judgment calls

All are sound:
- **`oversee` "Hard gates":** a necessary replacement once escalation marker files went, and short.
- **Trimmed arc template:** "add whatever fields a cold resume needs" covers it.
- **Steering Log and example rows behind a separator:** validated by the smoke.
- **`reviewer.md` drops the isolation sentence; `implement` keeps one clause:** both proportionate.
- **`triage.md` "eight" becomes "seven":** correct, since the template now has seven columns.
- **Size misses on `iterate` (157 / 1,644) and `judge` (75 / 600):** acceptable.
  The proposal states those sizes as approximate, and the unchanged Graphify section accounts for most of the `iterate` gap.

**Nit.** Leaving root `CLAUDE.md`'s "Workflow patterns (parallel agents, subagent dev, checklists)" description stale is defensible on approval scope, but "subagent dev" no longer describes the file.
It is a five-word edit the maintainer would likely wave through.

### 4. Live loop smoke evidence

The evidence is adequate for the floor.
The floor asks whether the compressed rules still produce delegation, dispatch/return rows, and explicit-path staging.
The prior question is whether the run tested the new text at all, and it did:
- the sandbox's `.claude/rules/cdocs.md` is 299 lines with `## Stay thin`, against 800 lines with `## Pillar 1` and `# CDocs Overseer Arc` in `loop_smoke_base`,
- the lead read `plugins/cdocs/skills/iterate/template.md` from the new tree,
- the lead produced the new shapes: no `inline_work` column, a free-text Steering Log, a Completed / Decisions Made / Open Todos handoff, `chat-record path` into `chat_record:`, and a `chat-record note` at the end.

On the three criteria:
- **Delegation:** the lead made 4 `Bash` calls and 2 `Agent` calls (`cdocs:implementer`, `cdocs:reviewer`); `greet.sh` was written and committed only by the implementer.
- **Rows:** 4 dispatch/return rows.
- **Staging:** explicit paths in all three transcripts (`git add greet.sh`, `git add cdocs/reviews/...`, and the lead's `git add cdocs/devlogs/... cdocs/proposals/... cdocs/_chat/*.md`).
  If anything this is tighter than the baseline lead, which ran `git add cdocs` twice.

The smoke does not discriminate between the wordings: n=1, sonnet, a two-line task.
Under the maintainer's stance that small canary differences are not the point, a non-discriminating no-regression smoke is what this floor needed.
More runs would not change the decision.

The "3 of 4 rows written after the fact" caveat holds on **both** trees.
The baseline lead also wrote the impl-1 dispatch row up front and the other three in one batch at the end.
So it is a pre-existing compliance gap in single-shot `-p` loops (the lead dispatches the reviewer right after the implementer returns), not a regression.
If it matters, the cheap lever is one clause in `iterate` Turn N.a ("append the return row before the next dispatch"), not more rule text.
That belongs in a follow-up or the resumption RFP.

**Non-blocking: two misattributions in the implementer's notes (Phase 5 "Loop smoke" and "Deviations and gaps").**
- "its reviewer staged the broad `git add cdocs`": in the baseline it was the **lead** (`parent_tool_use_id` null) that ran `git add cdocs` twice; the baseline reviewer did not commit at all.
- "The loop smoke reviewer ran `git commit` although `reviewer.md` forbids mutating VCS commands... an existing compliance gap": the new-tree **lead's dispatch prompt** told the reviewer "Commit the review by explicit path."
  The reviewer followed an explicit instruction from the overseer, which holds commit authority.
  This loop's own overseer gives reviewers the same instruction (this review's dispatch included).

**The reviewer-commits finding is a follow-up, not in scope.**
It is not a regression, since the rule and agent text are unchanged on that point and the behavior came from the dispatch prompt.
The real issue is that `reviewer.md`'s flat "Do not run `git commit`" contradicts practice: overseers routinely delegate a scoped, explicit-path commit.
Under the "guidelines over bans" stance, a fitting rewording would be "commit only the review file, by explicit path, when the dispatch prompt asks; never commit source".
Track it in a follow-up rather than this loop.

### 5. `rules_check` is not a regression

I inspected all six kept sandboxes (`/tmp/chat-record-test.*`):
- three run the old rules (`## Pillar 1`), two on haiku and one on sonnet-5-5,
- three run the new rules (`## Stay thin`), two on haiku and one on sonnet-5-5.

Every run compacts once, and every first post-compaction call goes straight to the task (`Edit`/`Write greeter.py`, or `Edit` the devlog).
None runs `chat-record path` or reads the record tail first.
The failure is identical across both wordings and both models, so it predates this change.
It is owned by `cdocs/proposals/2026-10-05-post-compaction-resumption-rfp.md`, which already calls for opus-class re-tests that none of these six runs were.

### 6. Stale references in live docs outside the inbound list

**Non-blocking, but worth one commit.** `cdocs/proposals/2026-10-05-post-compaction-resumption-rfp.md` (`request_for_proposal`, the next consumer of this text) still points at "chat-record Pillar 2's post-compaction resumption step 3" and "Pillar 2's `### Resumption` step 3".
Neither exists now.
The equivalent is the "**After a compaction:**" line in "Chat record".
An agent elaborating that RFP will go looking for a section that is gone.

**Nit.** `cdocs/proposals/2026-09-17-browser-delegation-plugin.md` (`accepted`, unimplemented) cites "Pillar 3 (Durable Specialists)" and "Pillar 1b" five times.
The durable-specialist lesson survives as the "named subagent resumed with `SendMessage`" line in "Stay thin", so an update to the pointer is cosmetic until that proposal is picked up.
The other hits (`2026-03-26-rfp-oversee-skill.md`, and `implementation_accepted` proposals) are history and fall under the proposal's "not rewritten" rule.

### 7. Follow-up RFP

`cdocs/proposals/2026-10-06-target-specific-guidance-rfp.md` covers the three scope items the proposal named and links the OpenCode model-mapping RFP.
The root `CLAUDE.md` sentence points at it.
It is fine as a stub.

## Verdict

**Accept.**
The implementation matches the accepted proposal and loses no load-bearing lesson, and every static check passes on re-run.
The smoke evidence meets the no-regression floor, and the `rules_check` failure is shown to be pre-existing.
The remaining items are nits, a pre-existing one-word bug the loop surfaced, and two evidence misattributions that change no conclusion.

## Action Items

1. [non-blocking] Fix `iterate/SKILL.md` line 89: `subagent_type: "reviewer"` becomes `"cdocs:reviewer"` (the baseline smoke lead hit `Agent type 'reviewer' not found`).
2. [non-blocking] Update the stale "Pillar 2 ... `### Resumption` step 3" pointers in `cdocs/proposals/2026-10-05-post-compaction-resumption-rfp.md` to `orchestration-discipline.md` "Chat record" ("**After a compaction:**").
3. [non-blocking] Correct the two smoke-note misattributions in the loop devlog: the baseline's `git add cdocs` was the lead's, and the new-tree reviewer committed because the lead's dispatch prompt asked it to.
4. [follow-up] Reconcile `reviewer.md`'s "Do not run `git commit`" with the practice of overseers delegating a scoped explicit-path commit (suggested: allow it only when the dispatch asks, review file only).
5. [follow-up] If as-it-happens dispatch/return rows matter in single-shot loops, add one clause to `iterate` Turn N.a ("append the return row before the next dispatch"); the gap exists on both trees.
6. [nit] Refresh root `CLAUDE.md`'s "Workflow patterns" parenthetical, and the Pillar 3 / 1b pointers in `2026-09-17-browser-delegation-plugin.md` when it is picked up.
7. [nit] Optionally add one clause tying `propose-revise`'s optional devlog to the rule's dispatch/return-row instruction.
