---
review_of: cdocs/proposals/2026-10-08-oversee-workstream-skill.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T10:59:02-07:00
task_list: cdocs/rules-delivery/oversee-workstream-skill
type: review
state: live
status: done
tags: [fresh_agent, architecture, claude_skills, rules_delivery, minimalism, phase_ordering]
---

# Review: Oversee-Workstream Skill, Round 2

## Summary Assessment

The revision restructures the proposal to the maintainer's design: a `chat-record` skill, one top-level-only rule bullet, no hook, and `overseers.md` deleted.
All seven r1 blocking items (r1 listed seven, not five) are applied, and the design is close to minimal.
Three small defects remain, each fixed by moving or deleting a line.
Phase 2 goes red again, this time because two of its rows add `/cdocs:` names for skills that Phase 3 creates.
§1 adds a sentence saying the dispatcher owns the top-level devlog, which contradicts `iterate/SKILL.md:72`.
Verification step 1 misses a hit that the proposal itself adds.
**Verdict: Revise.** All three fixes are mechanical; a short re-check suffices.

## Round 1 Items

| r1 item | Status |
|---|---|
| 1. `chat-record` skill with guard; delete `overseers.md` | Applied (§2, §3) |
| 2. One top-level bullet; drop the Loops line | Applied (§3) |
| 3. Remove the deny hook | Applied; one NOTE remains (Background) |
| 4. `Stop` reason names the skill; unit assertion; constraint relaxed | Applied (§6, Test Plan, Constraints). The reason with `See /cdocs:chat-record.` measures 254 bytes with a full-length session id, under the 300-byte assertion. |
| 5. Extend `top_level_only` | Applied, with a conflict in the existing scenario (finding below) |
| 6. Phase 2 edits `overseers.md:6` | Applied, but Phase 2 has a new red (B1) |
| 7. Verification grep | Pattern and paths applied; the exception list is incomplete (B3) |
| 8-13 (non-blocking) | Applied, apart from a partial dedupe of the rationale (item 12) |

## Footprint Check

`grep -rnE 'CDocs Overseer Rules|overseers\.md|/oversee([^-a-z]|$)' plugins scripts .github CLAUDE.md README.md .gitignore` at `5da9513` returns 51 hits (19 of them `check-rule-refs.test.ts` fixtures).
Every one is covered by §4, §5, §6, the init step 6 row, or a listed exception:
- `AGENTS.md:15`; `README.md:60,123,153`; `bin/README.md:64`; `CLAUDE.md:48,61`; `frontmatter-spec.md:85`; `devlog/SKILL.md:31`; `devlog/template.md:10`; `init/SKILL.md:85,87`; and `check-rule-refs.ts:5`.
- §4 anchors (`iterate:10`, `propose-revise:14`, `full-send:13`, `oversee:12`, `ablate:20,290`, `implement:19`, `propose:144`), all still at the stated lines.
- `oversee/SKILL.md:9,14,19-21` (§5 prose and usage), plus `:50,57`, `template.md:3` and `.gitignore:17` (arc-state exceptions), and `.gitignore:16` (§6).
- The `check-rule-refs.test.ts` fixtures and the `check-rule-refs.ts:145` comment.

The pattern cannot match `/cdocs:oversee`, because `:` comes before `oversee` rather than `/`.
Those references (`AGENTS.md:33`, `README.md:47`, `overseers.md:6`) are in §6, and the §7 check covers them after the change, so nothing is missed.
Bare-name lists (`CLAUDE.md:51`, `overseers.md:3`) are in §6 or deleted.

## Section-by-Section Findings

### Summary and BLUF

- **Non-blocking (remove).** The bulleted "The maintainer asked for three things" list repeats the BLUF and Objective, and it narrates the request rather than the design.
  Delete lines 28-31.
- **Non-blocking (remove).** The Summary restates two Design Decisions: Skill-tool durability (lines 33-35) and the top-level rationale (lines 37-40).
  The fork paragraph says the same as §2.
  Keep one sentence of motivation and point to Design Decisions.
- **Non-blocking.** The `graphify-overhaul` NOTE's file list is inaccurate.
  This proposal never edits `agents/reviewer.md`, and the list omits `.gitignore`.
  The branch appends `graphify-out/` directly after line 17, next to this proposal's line-16 edit, so the conflict is real.
  Either fix the list or drop it and keep the "one or two lines each" claim.

### Background

- **Non-blocking (remove).** The deny-hook NOTE takes three lines; r1 asked for at most one.
  Suggested: "A subagent `PreToolUse` deny is verified to work; see the r1 review's Runtime Verification."

### §1 `oversee-workstream`

- **Blocking (B2).** "If the Agent tool dispatched you, your dispatcher owns the top-level devlog and the chat record" is new text, and it contradicts the loop skills.
  `iterate/SKILL.md:72` says "Continue the workstream's top-level devlog, which you own", and `propose-revise/SKILL.md:19` puts loop state in the overseer's top-level devlog.
  A dispatched full-send, which is the trigger case, would load two contradictory instructions about where its Iteration Log goes.
  That is the kind of subagent confusion this proposal exists to remove.
  Fix: cut it to "If the Agent tool dispatched you, your dispatcher owns the chat record."
  The nest-overseers edge case relies only on that part.
  Deleting the sentence outright is also defensible, because the rule bullet already scopes chat-record to the top-level session.

### §2 `chat-record` and fork guards

- The guard line and the role-only descriptions are right.
- **Trigger-case coverage.** The `Stop` reason is a loader, not a guard: it reaches only payloads without `agent_id`, so it cannot put chat-record text in front of a subagent.
  What prevents the leak:
  - a subagent's context has no chat-record instructions;
  - the rule bullet and the skill description both say "top-level";
  - the first-line guard stops a fork that inherits the text, or a subagent that loads the skill by mistake;
  - for a dispatched overseer, the §1 line once trimmed to "dispatcher owns the chat record" (B2).

  Together these cover the trigger case.

### §3 Rule bullet: the top-level definition

- Clear and actionable.
  Both halves are things a model can check: its dispatch arrived from the Agent tool, or the fork directive says it is a fork.
  This matches the hook's own test (`agent_id` present).
- **Non-blocking.** A fork is itself started by the Agent tool (`subagent_type: "fork"`), so "and not a fork" is emphasis rather than a second condition.
  "(not started by another agent; forks included)" is shorter.
  It also covers agents spawned by Workflow scripts or teams, which the "Agent tool" wording does not name.
  The current text is acceptable.

### §4 Loop-skill lines

- All anchors are verified at `5da9513`.
  The "skip if" clause earns its place.

### §6 Reference sweep

- **Blocking (B1).** Phase 2 cannot go green.
  Phase 2 applies the `AGENTS.md:33` and `README.md:47` rows, and both rows also add `/cdocs:oversee-workstream` and `/cdocs:chat-record` entries.
  Both files are in §7's file list, and neither skill exists until Phase 3, so `skillRefProblems()` fails Phase 2's own success criterion.
  `CLAUDE.md:51` has the same mismatch, but its bare names are not checked.
  Fix: in Phase 2, only rename; move the new-skill additions to Phase 3 step 1 or 4.
- **Non-blocking (remove).** Drop the new `AGENTS.md` bullets entirely.
  That list is "Key skills for workflow composition", with four of about seventeen skills.
  `chat-record` is not a composition skill, and an always-visible pointer to it works against the "top-level only" intent.
  The rename alone is enough there.
  Keep the README table rows, since that table is complete by design.
- **Non-blocking (remove).** "Some references stay as they are" and Verification step 1's exception list say the same thing.
  Keep one list and point to it from the other.

### §7 Skill-reference check

- No change from r1: it is an addition, it is marked as one, and it earns its place.
  If the maintainer wants the minimal cut, this section and Phase 1 are the largest removable unit; the verification grep would then be the only rename guard.

### §8 Materialization and OpenCode

- **Non-blocking (remove).** The "`chat-record` in OpenCode" bullet says nothing changes and why.
  r1 noted that it needs no text.
  Delete it.

### Edge Cases

- **Non-blocking (remove).** "How OpenCode resolves `/cdocs:x`" records a gap this proposal does not touch.
  Delete it.

### Test Plan

- **Non-blocking.** The `top_level_only` extension conflicts with the existing scenario.
  Its prompt says "Do not run chat-record yourself unless a hook tells you to", and it asserts "top-level first Stop still blocks" (`chat-record.test.sh:660,664`).
  A parent that invokes `/cdocs:chat-record` first, then writes its note as the new positive control requires, will not be blocked.
  Say that the extension removes that sentence and replaces the first-Stop-blocks assertion with the note control.
- **Non-blocking (remove).** The `npm run test:opencode` additions are assigned to no phase.
  They can only pass after Phase 3, and they test a verbatim directory copy that §8 says needs no code change.
  Their `skills/oversee/` literal would also be an unlisted Verification step 1 hit.
  Delete them, and keep "`npm run test:opencode` passes" in Verification step 2.

### Verification step 1

- **Blocking (B3).** The README "OpenCode Installation" NOTE that §6 mandates contains `.opencode/skills/oversee/`.
  `/oversee/` matches `/oversee([^-a-z]|$)`, and the NOTE is not in the exception list, so the step cannot return "only these exceptions".
  Fix: add the README NOTE to the exceptions.
- **Non-blocking.** Widening the pattern to `[/:]oversee([^-a-z]|$)` would let the grep alone prove the rename.
  It would also catch `/cdocs:oversee` in `.gitignore` and `scripts/`, which §7 does not scan.

### Implementation Phases

- Phase 1 is green on today's tree (verified in r1; the file list is unchanged).
- Phase 2: see B1.
- **Non-blocking.** Phase 3 step 3 says "red on the 10 old references".
  Step 2 has already replaced the seven §4 references by then, so only three go red: `devlog/SKILL.md:31`, `devlog/template.md:10` and `frontmatter-spec.md:85`.
  Drop the count, or swap steps 2 and 3 inside the same commit.
  The Test Plan's "exactly 10" is right only for the unswept tree.
- Grouping steps 3 and 4 into one commit keeps `main` green, and steps 1 and 2 each stay green on their own.

### History-agnostic framing

- Mostly clean.
  The "maintainer asked" list and "once wrote into" are request and incident narrative; the first goes away with the Summary cut.
  In §7, "now refers to a skill" reads better as "refers to a skill after §6".
  "Today's ... section" in §1 and §2 is an instruction to the implementer and is fine.

### Overlap with `graphify-overhaul`

- That branch rewrites the `/graphify` bullet in "Tools and Skills" and adds an overseer-only sentence: "Overseers write `graphify_base_query` ... and never run graph queries themselves."
  This proposal's bullet joins the same list.
  Two of its four bullets would then be scoped to a role, one to overseers and one to top-level sessions.
  Follow-up Candidates already names moving the overseer sentence into `oversee-workstream`.
  That is the right call, because it keeps the Constraints line ("move no other rule content") true.
- The branch's `iterate/SKILL.md` points to "CDocs Tool Use Guidance › Tools and Skills" for that sentence.
  Whoever does the follow-up must repoint it; the §7 and rule-ref checks will catch a stale heading.
- The branch adds `/cdocs:graphify`.
  If it lands first, §7 resolves it, and `CLAUDE.md:51` gains `graphify` in the same list this proposal edits, which is a one-word conflict.

## Verdict

**Revise.**
Fix B1 to B3; each is one moved or deleted line.
The non-blocking removals would cut about 20 lines and no substance.

## Action Items

1. [blocking] Phase 2: apply only the rename in `AGENTS.md:33`, `README.md:47` and `CLAUDE.md:51`. Move the new `oversee-workstream` and `chat-record` entries to Phase 3, because §7 fails on them before the skills exist.
2. [blocking] §1: replace "your dispatcher owns the top-level devlog and the chat record" with "your dispatcher owns the chat record", or delete the sentence. As written it contradicts `iterate/SKILL.md:72`.
3. [blocking] Verification step 1: add the README "OpenCode Installation" NOTE (`.opencode/skills/oversee/`) to the exceptions.
4. [non-blocking] Delete the Summary's "maintainer asked" list. Cut the Summary rationale that repeats Design Decisions and §2 to one sentence.
5. [non-blocking] Do not add `chat-record` or `oversee-workstream` bullets to the `AGENTS.md` "Key skills" list.
6. [non-blocking] Delete the `test:opencode` additions from the Test Plan.
7. [non-blocking] `top_level_only` extension: remove the "Do not run chat-record yourself" prompt sentence, and replace the "first Stop still blocks" assertion with the parent-note control.
8. [non-blocking] Phase 3 step 3: drop "10", which is 3 after step 2.
9. [non-blocking] Delete the §8 "`chat-record` in OpenCode" bullet and the "How OpenCode resolves `/cdocs:x`" edge case.
10. [non-blocking] Shorten the deny-hook NOTE to one line. Fix the `graphify-overhaul` NOTE's file list: drop `reviewer.md`, add `.gitignore`.
11. [non-blocking] Keep one list of the references that stay, shared by §6 and Verification step 1.
12. [non-blocking] Consider `[/:]oversee([^-a-z]|$)` in Verification step 1.

## Questions for the Maintainer

1. How should a dispatched overseer's instruction about the record read (B2)?
   - (a) "your dispatcher owns the chat record" (recommended: targets the trigger case and contradicts nothing).
   - (b) Delete the sentence: the rule bullet already scopes chat-record to top-level.
   - (c) Keep the devlog clause and also edit `iterate`/`propose-revise` to log into a sub-devlog when dispatched (a behavior change; out of scope here).
2. Should the §7 skill-reference check stay?
   - (a) Keep it (recommended: cheap, and `frontmatter-spec.md` comes to depend on a skill name).
   - (b) Drop §7 and Phase 1 for the minimal cut, and rely on the Verification grep.
