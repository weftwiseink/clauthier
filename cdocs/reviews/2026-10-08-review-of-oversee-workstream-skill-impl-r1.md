---
review_of: cdocs/proposals/2026-10-08-oversee-workstream-skill.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T11:26:36-07:00
task_list: cdocs/rules-delivery/oversee-workstream-skill
type: review
state: live
status: done
tags: [fresh_agent, implementation, runtime_validated, claude_skills, rules_delivery, minimalism]
---

# Review: Oversee-Workstream Skill Implementation, Round 1

## Summary Assessment

Round 1 implements the whole proposal on `oversee-workstream` (`8e9fabb..dacf590`):
- `oversee` is renamed to `oversee-many`.
- `rules/overseers.md` is deleted, and its content now lives in the `oversee-workstream` and `chat-record` skills.
- One top-level-only rule bullet points at `chat-record`.
- Seven skills load `oversee-workstream`.
- A `/cdocs:<name>` resolution check is added.

The implementation is faithful, small and consistent, and I re-ran the whole floor green.
No stale `/cdocs:oversee`, "CDocs Overseer Rules" or `overseers.md` reference remains outside fixtures and the listed exceptions.
The `rules_check` extra is red, but it is equally red on the base commit, so its failure predates this change.
`multi_turn` is green on both trees.
**Verdict: Accept.** Five non-blocking findings follow, and four of them only remove words or fix a stale example.

## Floor (re-run by this reviewer)

Run in the worktree at `dacf590` on Claude Code 2.1.294, with the headless suites on haiku.
Each headless run used the script's own mktemp `CLAUDE_CONFIG_DIR` under my scratchpad.
The kept comparison sandboxes, credential copies included, were deleted afterwards.

| Check | Result |
|---|---|
| `npm run test:rules` | 18 pass, 0 fail (6, 6a-6f included) |
| `chat-record.test.sh --unit` | 98 passed, 0 failed; `block reason names the /cdocs:chat-record skill`, `under 300 bytes (254)` |
| `npm run test:opencode` | 9 pass, 0 fail; build emits `chat-record`, `oversee-many`, `oversee-workstream`, no `oversee`; `rules/` has 4 files, no `overseers.md` |
| headless `--only '^init_real$'` | 12 passed, 0 failed (both bullets present, no overseer rule, stale OpenCode copy pruned, `--materialized` passes) |
| headless `--only '^top_level_only$'` | 14 passed, 0 failed; dispatched `cdocs:proposer,general-purpose,fork`; record markers `U A:haiku-5-5 S:...` (parent only); no `chat-record` `PreToolUse` with `agent_id`; no subagent `Skill(chat-record)` |
| Verification step 1 grep | Listed exceptions only, plus 5 `chat-record.test.sh` lines (see Deviations) |

I also spot-checked the implementer's Phase 4 evidence (`scratchpad/evidence/p4-{stream,transcript}.jsonl`):
- The first two top-level calls are `Skill cdocs:oversee-workstream` and then `Skill cdocs:chat-record`, and the first `Agent` call comes after them.
- After `compact_boundary`, the `invoked_skills` attachment lists `cdocs:chat-record`, `cdocs:oversee-workstream` and `cdocs:propose-revise`.

## `rules_check` and `multi_turn` (previously unverified)

The question was whether these extras assume the post-compaction steps live in the always-loaded rules.
I ran each against `8e9fabb` (extracted with `git archive`) and against the branch.

| Scenario | Base `8e9fabb` | Branch `dacf590` |
|---|---|---|
| `rules_check` | 2 passed, 3 failed (x2) | 2 passed, 3 failed (x3) |
| `multi_turn` | 2 passed, 0 failed; 5/20 turns needed the one-shot block | 2 passed, 0 failed (x2); 11/20 and 5/20 |

- **`rules_check`.** The three failures are the same on both trees: haiku's first post-compaction call is a `Write` or `Edit` on the task, with no `chat-record path`, no devlog read and no `tail -n 80`.
  Earlier runs from 2026-10-07 in the shared scratchpad failed identically.
  On the branch, haiku invoked `Skill(cdocs:chat-record)` in turn 1 in 2 of 2 inspected runs.
  The transcript's `invoked_skills` attachment then restored it after compaction, so the "After a compaction" text was in context and haiku still skipped it.
  The scenario's expectations stay valid; it measures whether haiku complies, not how the text is delivered.
  Only its header comment ("a session under the materialized rules") is now incomplete (F4).
- **`multi_turn`.** The parent invoked `chat-record` once, in turn 1, and its text carried through all 19 `--resume`s.
  The block count is noisy at n=1-2.
  11/20 versus 5/20 on the same tree is within run-to-run variance, and it does not show that the note instruction lost effect when it left the rules.
  No expectation change is needed.

## Section-by-Section Findings

### §1-§2 Skills

- `oversee-workstream/SKILL.md` (20 lines) is the "Stay thin" text verbatim, under §1's intro.
  `chat-record/SKILL.md` (25 lines) is the current `overseers.md` "Chat record" text, under the guard.
  Both are minimal, and neither restates the other.
- The two-line guard follows sentence-per-line and keeps §2's wording.
  Accepted.

### §3 Rule bullet

- **Clarity.** "Top-level session only (not started by the Agent tool, and not a fork)" is clear.
  "and not a fork" is strictly implied, since a fork is an Agent dispatch, but a fork inherits the parent's context and may not see itself as dispatched.
  Keep it.
- **Non-blocking (F1, remove).** Change "invoke `/cdocs:chat-record` with the Skill tool, and again after a compaction when its text is not in context" to "invoke `/cdocs:chat-record` with the Skill tool whenever its text is not in context".
  Compaction restores an invoked skill: Phase 4 showed it, and so did my two `rules_check` runs.
  The only real re-load case is therefore any point where the text is missing, such as session start, or a resume followed by a compaction.
  The edit removes 5 words.
  `init_real`'s regex (`... invoke `/cdocs:chat-record``) still matches.

### §4 Loop skills

- `iterate`, `propose-revise`, `full-send`, `oversee-many` and `ablate` carry the same line, "Before dispatching, invoke `/cdocs:oversee-workstream` with the Skill tool (skip if its text is already in context).", each next to its "overseer mode" sentence.
  Each line sits where the skill enters overseer mode, and the live ordering gate passed.
  The `ablate` floor keeps only its ablation-specific bullets, as §4 asks.
- **Non-blocking (F2, remove).** The `implement` and `propose` lines keep a phrase that only made sense when they cited a rule:
  - `implement/SKILL.md:19`: "When dispatching, a top-level session is a thin lead: invoke `/cdocs:oversee-workstream` with the Skill tool before dispatching, so the discipline is not `iterate`-only."
    It says "dispatching" twice.
    Suggested: "When dispatching, a top-level session is a thin lead: invoke `/cdocs:oversee-workstream` with the Skill tool first."
  - `propose/SKILL.md:144`: drop ", so the discipline is not `iterate`-only".
    The instruction itself now shows that the discipline applies beyond `iterate`.

### §5 Rename

- `name`, H1, usage block and prose all use `/cdocs:oversee-many`.
  `.claude/oversee/` and `.gitignore:17` are unchanged, as specified.
  The README OpenCode NOTE is present.

### §6 Sweep

- All rows are applied.
  `CLAUDE.md` now imports the four remaining rules in `/cdocs:init`'s order, and its skills list includes `chat-record`, `oversee-many` and `oversee-workstream`.
  The `› Completeness` example is updated in `CLAUDE.md`, the README and the `check-rule-refs.ts` header.
- **Non-blocking (F3).** `plugins/cdocs/bin/README.md:55-58` introduces its example as "A real `Stop` block", but the JSON lacks the new " See /cdocs:chat-record." sentence.
  Add the sentence after `(record: ...).` so the example matches what `hook_stop` emits.
  The Verification grep's patterns do not cover it.

### §7 Skill-reference check

- `skillRefProblemsIn` is pure and `skillRefProblems` wraps the real tree.
  The file list matches §7, and tests 6a-6f cover every Test Plan case.
  The implementer's mutation check is recorded.
  This is a minimal, sound implementation.

### §8 Materialization and OpenCode

- `init/SKILL.md` step 6 drops the Overseer block.
  Step 5c pruning is exercised by `init_real`'s new stale-file fixture.
  `test:opencode` shows the build picks up the new skills with no code change.
- The chat-record skill and rule bullet also ship to OpenCode, which keeps no chat record (`cdocs-hooks.ts:15`).
  `overseers.md` shipped there before, so this is not a regression.
  It falls under the existing target-specific-guidance RFP and needs no action here.

### Test changes

- **Non-blocking (F4).** Update the `rules_check` header comment (`chat-record.test.sh:865-867`).
  It should say the resumption steps come from the `chat-record` skill, which compaction restores, rather than from "the materialized rules".
  The assertions can stay.
  Whether to keep an extra that is red on haiku on both trees is a maintainer question (Q1).

## Implementer-Reported Deviations

| Deviation | Judgment |
|---|---|
| 5 grep hits in `chat-record.test.sh` not in the exception list | Accept. They are `init_real`'s stale `overseers.md` fixture and its negative assertions, which test the deletion itself. The proposal's "inline fixtures" exception was too narrow; no code change is needed. |
| `init_real` edits not listed in §6 | Accept, and they were necessary. The old assertions required the deleted "Top-level agents must use ..." and "After a compaction" text in the rules file, so the run would have gone red. The new assertions are what Verification step 3 asks for. |
| Skill text from the current `overseers.md` wording | Accept. §1 and §2 say "today's ... verbatim", and the newer free-form note wording is today's. Quoting the proposal's older `gist:`/`query:` text would have regressed. |
| Guard split across two lines | Accept (sentence-per-line). |
| `propose` worded differently from `implement` | Accept the comma. See F2 for a shorter line in both. |
| Unlisted consistency edits (`template.md` H1, `overseers.md:3` before deletion) | Accept. Both are trivial, and the second is deleted in Phase 3 anyway. |
| Live run with `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` | Accept. The gated properties (`Skill` before the first `Agent` call, `invoked_skills` after `/compact`) do not depend on foreground versus background dispatch. The hooks skip background-notification turns. |

## Other Checks

- **Stale references.** Outside `cdocs/`, the only hits are the Verification step 1 exceptions and the `chat-record.test.sh` fixtures.
  A wider sweep found no "overseer rules", "› Stay thin" or bare `cdocs:oversee` either.
- **Landing.** The branch merges cleanly with `main`, which has no overlapping files.
  Against `graphify-overhaul`, `git merge-tree` reports conflicts in `CLAUDE.md` (skills list) and `rules/tool-use-safeguards.md` ("Tools and Skills").
  The proposal NOTE predicts both, and each is a few lines.
  `graphify-overhaul` adds no `/cdocs:oversee` or "CDocs Overseer Rules" reference.
  The `skillRefProblems` check will catch one if its branch adds it later.
- **Devlog.** The sub-devlog is complete, correctly has no `chat_record:`, and leaves the Phase 4 evidence for the overseer's devlog.
  The proposal remains `implementation_wip`, as asked.

## Verdict

**Accept.**
The floor is green as re-run, the deviations are justified, and the two unverified extras behave the same as on base.
F1-F4 are optional edits, three of which delete words; F5 is a maintainer question.

## Action Items

1. [non-blocking] F1: `rules/tool-use-safeguards.md` bullet: replace ", and again after a compaction when its text is not in context" with " whenever its text is not in context".
2. [non-blocking] F2: `implement/SKILL.md:19` becomes "... invoke `/cdocs:oversee-workstream` with the Skill tool first."; `propose/SKILL.md:144` drops ", so the discipline is not `iterate`-only".
3. [non-blocking] F3: `bin/README.md:58` example: insert ` See /cdocs:chat-record.` after `(record: ...).` to match the real reason.
4. [non-blocking] F4: `chat-record.test.sh:865-867` comment: the resumption steps come from the restored `chat-record` skill.
5. [non-blocking] F5: see Q1.

## Questions for the Maintainer

1. `rules_check` is red on haiku before and after this change (5 of 5 runs fail the same 3 assertions).
   What should happen to it?
   - (a) Keep it as a manual extra and note in its header that it is a known-red haiku compliance probe.
   - (b) Run it on sonnet or opus by default (`CHAT_RECORD_MODEL`), since the post-compaction steps are judgment-heavy.
   - (c) Delete it (recommended for minimalism). `multi_turn` and the `Stop` fallback already guard note completeness, and Phase 4 shows that compaction restores the skill.
