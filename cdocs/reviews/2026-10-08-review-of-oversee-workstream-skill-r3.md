---
review_of: cdocs/proposals/2026-10-08-oversee-workstream-skill.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T11:04:20-07:00
task_list: cdocs/rules-delivery/oversee-workstream-skill
type: review
state: live
status: done
tags: [fresh_agent, architecture, claude_skills, rules_delivery, minimalism, phase_ordering]
---

# Review: Oversee-Workstream Skill, Round 3

## Summary Assessment

The proposal deletes `rules/overseers.md` and splits its content into a `cdocs:oversee-workstream` skill (which the loop skills load) and a top-level-only `cdocs:chat-record` skill, renames `oversee` to `oversee-many`, and adds a `/cdocs:` reference check.
r2's three blocking items are fixed, and so are its non-blocking items except the optional pattern widening.
A simulated run on `eca42cd` shows each phase goes green in order.
The Verification step 1 exception list is complete, but one entry is worded too narrowly and one depends on a line number that Phase 1 may shift.
The design is also slightly larger than it needs to be: the §1 "dispatcher owns the chat record" sentence and its NOTE duplicate guards that §2 and §3 already provide.
**Verdict: Accept.** None of the remaining findings blocks implementation; each is a deletion or a few-word fix that the implementer can apply in place.

## Round 2 Items

| r2 item | Status |
|---|---|
| 1. [B1] Phase 2 renames only | Fixed. The §6 rows for `AGENTS.md:33`, `CLAUDE.md:51` and `README.md:47` are split by phase, and Phase 3 step 1 adds the new entries. |
| 2. [B2] §1 dispatcher line | Fixed. The line is cut to "owns the chat record", and a NOTE says why it leaves out the devlog. See F1 for a further cut. |
| 3. [B3] README NOTE exception | Fixed (Verification step 1, second bullet). |
| 4. Summary cuts | Fixed. The Summary is two sentences. |
| 5. No `AGENTS.md` key-skill bullets | Fixed ("rename only"). |
| 6. Drop the `test:opencode` additions | Fixed. |
| 7. `top_level_only` prompt and assertion | Fixed. |
| 8. Phase 3 step 3 count | Fixed ("3 remaining"), and the Test Plan names all three. |
| 9. §8 and Edge Case OpenCode cuts | Fixed. |
| 10. Deny-hook NOTE; `graphify-overhaul` file list | Fixed. The NOTE is one line, `reviewer.md` is out of the list and `.gitignore` is in. |
| 11. One list of references that stay | Fixed. §6 points to Verification step 1. |
| 12. `[/:]oversee` pattern | Not applied. It was optional, and §7 covers the scanned files. |

## Phase Ordering (fresh check)

Verified against `scripts/check-rule-refs.ts` at `eca42cd`:
- **Phase 1.** A shell simulation of §7 runs over its exact file list (`rules`, `skills` and `agents` `.md` files including `init/SKILL.md`, the three plugin docs, `CLAUDE.md` and the root `README.md`), and every `/cdocs:<name>` resolves.
  Green.
- **Phase 2.** The only `/cdocs:oversee` references in scanned files are `AGENTS.md:33`, `README.md:47`, `overseers.md:6`, and the usage lines that §5 rewrites.
  Neither `scripts/` nor `build-opencode*` mentions `oversee`, and the OpenCode test has no skill count, so `test:opencode` is unaffected.
  Green.
- **Phase 3.** Step 1 adds skills whose verbatim "Stay thin" and "Chat record" text holds no rule references.
  Step 2's §4 lines point to a skill that step 1 created, and `overseers.md` still resolves at that point.
  Step 3: `SCAN_DIRS` is `rules`, `skills` and `agents` only, so `AGENTS.md:15`, `CLAUDE.md:48` and the README hits do not go red.
  The red set is exactly the three that the Test Plan names.
  Steps 3 and 4 share one commit.
  Green.
- All §4 anchors are still at the stated lines.

## Verification Step 1 Exceptions (fresh check)

I ran the grep on `eca42cd` and projected it onto the finished tree.
The remaining hits are:
- `.gitignore:17`;
- `.claude/oversee/` at `oversee-many/SKILL.md:50,57` and `template.md:3`;
- the README OpenCode NOTE;
- `check-rule-refs.ts:145`;
- 20 lines in `check-rule-refs.test.ts`.

Every hit maps to a listed exception, and the new skill text, the rule bullet and the `Stop` reason add none.
Two entries are not exact:

- **Non-blocking (F2).** The exception "the 'CDocs Overseer Rules' inline fixtures in `check-rule-refs.test.ts`" is too narrow.
  Lines 133, 136, 137 and 146 of that file are `overseers.md` filename fixtures (test 5g), not "CDocs Overseer Rules" strings.
  Read literally, the step cannot return "only these exceptions".
  Fix by deleting words: "the inline fixtures in `check-rule-refs.test.ts`".
  The trailing "which need not name a real rule" can go too.
- **Non-blocking (F3).** "`check-rule-refs.ts:145`" is a line number in the file that Phase 1 edits.
  If the helper for `skillRefProblems()` lands near `findFilenameRefs` (lines 125-152), the comment moves.
  Name it by content instead: "the `overseers.md` placeholder comment in `findFilenameRefs`".

## Section-by-Section Findings

### §1 `oversee-workstream`

- **Non-blocking (F1, remove).** Delete "If the Agent tool dispatched you, your dispatcher owns the chat record." along with its two-line NOTE.
  The sentence is now consistent with the loop skills; the B2 contradiction is gone.
  It is also redundant three times over:
  - The §3 rule bullet reaches every subagent, because rules arrive with the CLAUDE.md hierarchy, and it already scopes chat-record to sessions that the Agent tool did not start.
  - The chat-record skill's first line repeats the guard.
  - The `Stop` reason never reaches a payload that carries `agent_id`.

  It also sits right after "Overseers are not nested".
  `oversee-many/SKILL.md` ("runs each composed loop as itself") is consistent with that, so the dispatched case the sentence guards only arises from misuse or from the deferred nest-overseers RFP.
  If the sentence is deleted, the last two lines of the nest-overseers edge case go too.
  That edge case stays true without them: a dispatched sub-overseer is not top-level, so the rule bullet already keeps it off `chat-record`.
  Net: about 4 lines removed and nothing lost.

### §3 Rule bullet

- **Non-blocking (F4, question).** The "plus `/cdocs:oversee-workstream` when leading a loop" clause is not part of the maintainer's request, which asked for a rule about chat-record only.
  The proposal gives it two reasons: a backstop if opus skips the §4 line, and the resume-plus-compaction gap.
  The second reason is weak.
  After a resume and a compaction, the loop skill's own text is gone too, and re-invoking the loop skill re-runs its §4 line.
  The backstop reason alone holds up, and Phase 4 tests it directly.
  Dropping the clause would also remove the Design Decision "One rule bullet carries both pointers" (4 lines).
  This is the maintainer's call; see Questions.

### §6 Reference sweep

- **Non-blocking (F5).** `README.md:123` has two examples, `"CDocs Overseer Rules"` (whole rule) and `"CDocs Overseer Rules › Chat record"` (section).
  The shared row says "example reference becomes ... › Completeness" in the singular.
  The whole-rule example should become `"CDocs Workflow Patterns"`.
  The Verification grep would catch the miss, so this is a clarity fix only.
- **Non-blocking (trivial).** The `Stop` reason row is part of §6, which Phase 3 step 4 applies ("the rest of §6's sweep"), and step 5 assigns it again.
  This is harmless; the implementer may do it in either step.

### §7 Skill-reference check

- **Non-blocking (remove).** Cut the opening "This check is an addition to the request, kept as the overseer's default:" to the reason alone.
  The request narrative is process history (see "History-Agnostic Framing"), and Questions for the Maintainer in r2 already recorded the choice.

### Summary

- **Non-blocking (trivial).** The bullet is 37 words, not "about 45".
  Either correct the figure or drop both word counts.

### Contradictions with the loop skills

None remain.
- `iterate:72` and `propose-revise:19` give the overseer the top-level devlog, which agrees with §1's "maintain the 'top-level' devlog".
- `oversee-many` runs its loops as itself, which agrees with "not nested".
- `implement` and `propose` load the skill as "a thin lead" without being in §1's list of loops.
  That keeps today's behavior, since they cite "Stay thin" today.

## Verdict

**Accept.**
All r2 blocking items are resolved, the phases go green in order, and the exception list covers every hit.
F1 through F5 are optional: the implementer can apply F2, F3 and F5 inline, and F1 and F4 cut text if the maintainer agrees.

## Action Items

1. [non-blocking] F1: delete §1's "If the Agent tool dispatched you, your dispatcher owns the chat record." and its NOTE, plus "That matches the 'dispatcher owns the chat record' line." in the nest-overseers edge case.
2. [non-blocking] F2: Verification step 1, change the exception to "the inline fixtures in `check-rule-refs.test.ts`", which also covers the `overseers.md` fixtures at lines 133-146.
3. [non-blocking] F3: name the `check-rule-refs.ts:145` exception by content, since Phase 1 edits that file.
4. [non-blocking] F4: consider dropping "plus `/cdocs:oversee-workstream` when leading a loop" from the rule bullet, and with it the "One rule bullet carries both pointers" Design Decision.
5. [non-blocking] F5: the `README.md:123` row names both replacements, `"CDocs Workflow Patterns"` and `"CDocs Workflow Patterns › Completeness"`.
6. [non-blocking] Trim the §7 opening request narrative, and fix or drop the Summary word counts.

## Questions for the Maintainer

1. Should the rule bullet also point at `oversee-workstream` (F4)?
   - (a) Keep it: a second path in case a long loop skill's Skill line is skipped, which Phase 4 checks.
   - (b) Drop it (recommended for minimalism): the rule then covers chat-record only, as requested, and the loop skills load `oversee-workstream` themselves.
2. Should §1 keep the "dispatcher owns the chat record" sentence (F1)?
   - (a) Delete it (recommended): §2 and §3 already cover the case.
   - (b) Keep it as a third reminder for a dispatched overseer.
