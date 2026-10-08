---
review_of: cdocs/proposals/2026-10-05-rules-context-decomposition-rfp.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T09:31:19-07:00
task_list: cdocs/rules-context-decomposition
type: review
state: archived
status: done
tags: [fresh_agent, formalism_reduction, rules, phase_gating, verification, dead_references, orchestration_discipline]
---

# Review: Rules Context Decomposition (round 1)

> BLUF(@claude-opus-5-5/cdocs/rules-context-decomposition): The proposal is sound and close to accept.
> The replacement rule text keeps every item on the simplification review's keep list at the right altitude, the budget figures check out exactly (797 / 8,054 before, 296 / 2,121 after), and the delivery analysis is correct.
> Four small blockers: the Phase 2 approval gate reads two ways, the devlog split-trigger pointer is dropped without saying so, the loop smoke can pass without showing explicit-path staging, and the Phase 1 check cannot pass as written.
> Verdict: **Revise**.

## Summary Assessment

The proposal compresses the always-loaded cdocs rules by about 63% in lines and 74% in words, deletes `oversee-arc.md` and the Cross-Target blocks, and moves the arc-only material into the `oversee` skill.
It applies the maintainer's decisions faithfully and does not reopen them.
The rewritten `orchestration-discipline.md` is at about the altitude of the `bash-runner` rewrite: descriptive headings, one or two sentences per lesson, no schemas.
The blockers are about consistency and verification, not design: an implementer would hit each one mid-loop.

## Method

- Measured the current rules (`wc -l -w`: 797 / 8,054) and the proposal's quoted replacements plus the verbatim Bash section (orchestration 63 / 658, model-tiering 9 / 136, workflow-patterns 21 / 191; total with the two unchanged files 296 / 2,121). The table is accurate.
- Grepped `plugins/cdocs`, root `CLAUDE.md`, `scripts/`, and `.github/` for every removed section name, "Pillar N", `oversee-arc`, and the proposal's dead-reference pattern.
- Read `chat-record.test.sh` (`init_rule_order`, the unit sync check, `init_rules`, `init_real`, `rules_check`), init steps 3/5/6, `postinstall.js` `copyRules`, and `build-opencode.ts`.
- Checked the asserted phrases against the new text. Both survive verbatim.

## Section-by-Section Findings

### Keep-list coverage (focus 1)

| Keep-list item | Where it lands | OK? |
|---|---|---|
| Resume-from-disk liveness | Rule "Resume from disk, not memory" | yes |
| Single writer | Rule "One writer per file" | yes |
| Explicit-path staging | Rule "One writer per file", plus Chat record | yes |
| Dispatch/return rows | Read by the rule; written only per `iterate` Turn N.a | partial, see F2 |
| Fresh reviewer and judge, warm implementer | Skill inline floors, `iterate` Roles (kept unchanged), "named subagent resumed with `SendMessage`" | yes |
| Handoffs at task boundaries | Rule "Durable state" | yes |
| `confirmed` needs this round's evidence | `iterate` Iteration Log compression | yes |
| Overseer can land/merge | One sentence at the end of "Durable state" | yes, see F5 |
| `/oversee` top-level only | `oversee` TOP-LEVEL ONLY note kept | yes, see F6 |
| Bash section verbatim | Explicit in the spec and the Do-not-change list | yes |

Things dropped that are not on the keep list:

- **F1 [blocking] The devlog split trigger loses its only always-loaded pointer.**
  Current Resumption step 2 tells a loop overseer, at each handoff, to "check the devlog against the split trigger in the devlog skill's 'Splitting a devlog'".
  `grep -rn 'Splitting a devlog\|split trigger' plugins/cdocs` shows this is the only place a loop overseer meets the trigger: `iterate`, `full-send`, and `propose-revise` never mention it, and an overseer does not load the devlog skill unless it invokes `/cdocs:devlog`.
  The new "Durable state" section drops it, and the proposal does not say so.
  The mechanism is from the accepted chat-record proposal and saw its first real use on 2026-10-06.
  Fix: either add one clause to the handoff sentence ("...and check the devlog skill's split trigger") or record in Design Decisions that splitting becomes opt-in by invocation only.
- **F2 [non-blocking] Dispatch/return rows are read but never asked for outside `iterate`.**
  "Resume from disk" re-derives state "from the devlog's dispatch/return rows", but only `iterate` Turn N.a instructs writing them.
  `propose-revise`, `full-send`, `oversee`, and a top-level `implement` lead have no instruction, although this very loop's devlog relies on them.
  The current rule has the same gap, so this is not a regression.
  Still, one clause closes it, and the simplification review calls the rows "the substrate the liveness check reads": "Log each dispatch and return (agent, target files) in the devlog as it happens."
- **F3 [non-blocking] Post-compaction for a dispatched agent.**
  The dropped line "without a record (a dispatched agent...), read your devlog's Scratchpoint and latest handoff alone" was the only post-compaction instruction for a long-running dispatched specialist.
  "Durable state" plus model intuition probably covers it, so this one is optional.
- Speaker-id derivation is safe to drop: `bin/chat-record` normalizes `--as` itself (line 35), and the Stop block message names the heredoc form.

### Replacement text altitude and proposal shape (focus 2)

- The orchestration text is lean.
  The only dense section is Chat record (13 of 48 lines), and two of its phrases are pinned by the test extras, so it is about as small as it can be.
- **F4 [non-blocking] The verification-floor sentence carries a five-rung ladder in a parenthetical.**
  This is fine as written, since it is prose and not a table.
  A tighter form would be "at the depth the change needs (from 'it compiles' up to 'it behaves against live state')".
- **F5 [non-blocking]** The isolation sentence sits under the `## Durable state` heading, where it reads as part of that lesson.
  Move it under "Stay thin", where it qualifies what the overseer does itself, or above the first heading.
- **Quoting full text is the right call for the three rule files.** They are the deliverable, the maintainer will judge the literal wording, and quoting removes implementer drift.
  It is less needed elsewhere.
  - The `oversee` "It drops:" list (10 bullets) and the `iterate` bullet list restate what the keep lists already imply.
    "Keep X; everything else in the section goes" would cut about 25 lines with no loss.
  - The Inbound references list is useful, but it cites line numbers ("lines 31 and 42", "Line 41", "Line 131", "line 57") that Phase 1 edits will shift.
    Prefer section names, or let the grep drive the list.
- **F6 [non-blocking]** `oversee`'s TOP-LEVEL ONLY note cites `orchestration-discipline.md` for "no nested dispatch".
  The new rule no longer says that (the old preamble did), so the Phase 2 rewrite should make the note self-contained ("subagents cannot dispatch").
- **Timelessness [non-blocking].** Background's "the chat-record proposal is `implementation_accepted`, so..." and the closing NOTE's "Sequencing" line are status-of-the-world statements that will go stale.
  They belong in the devlog.
  The closing NOTE's salience and adjacency answers are design decisions and can stay.

### Breakage (focus 3)

- **Init list vs unit check: correct.**
  `init_rule_order` parses `[Full content of X.md, frontmatter stripped]` from init's SKILL.md, and the unit check compares it to `ls rules/*.md`.
  Deleting `oversee-arc.md` and the step 6 entry in the same commit (Phase 2 steps 2 and 3) keeps it green.
  The proposal should say "same commit" explicitly, because a split commit fails the suite.
- **`build-opencode.ts`: no change needed.** It `rmSync`s the output directory before copying, so no stale file survives.
- **`postinstall.js`: the fix is correct and needed.** `copyRules` is `mkdirSync` plus `cpSync`, with no clear, so `.opencode/rules/cdocs/oversee-arc.md` would linger.
  The scratch-run check is feasible with `INIT_CWD=<scratch>`, because `PROJECT_ROOT` reads it and the source-repo guard keys on the target directory.
- **`inject-rules.ts`** hashes sorted bodies, so the deletion just changes the hash and nudges consumers, as the Edge Cases say.
- **F7 [blocking] Phase 1's check cannot pass as written.**
  `skills/init/SKILL.md:26` says "including Pillar 2 (handoff, Scratchpoint, chat record, resumption)", and Phase 4 is the phase that rewrites it.
  The Phase 1 grep exception list (`oversee-arc.md`, `workflow-patterns.md`, `iterate`, `oversee`) does not include init.
  Fix: move the init step 3 sentence into Phase 1, where it naturally belongs because it describes the orchestration rule, or add init to the exception list.
- **F8 [non-blocking] Dead-reference grep gaps.**
  - Section-name references that do not say "Pillar" survive it: "Isolation is a dispatched-agent property" (`reviewer.md:55`, `implement:30`, `iterate:15,116,155,216`, `oversee:100`), "Judge-Observable Thinness Signal" (`iterate:184`), and "Inline Discipline Floor".
    The spec covers each file, but the grep is the safety net, so add `Isolation is a dispatched|Judge-Observable|Durable Specialist|Inline Discipline Floor`.
  - The grep also names root `AGENTS.md`, which does not exist, so grep exits 2 rather than 1.
    Drop it, or judge the check by output and not by exit code.
- **F9 [non-blocking] Chat-record Phase 1a "grep 2" changes meaning.**
  The accepted chat-record proposal verifies that `grep -rn '/compact\|/clear' plugins/cdocs/{rules,skills,agents}` returns exactly one line, the reseed subsection's.
  Today it does.
  After this proposal it returns zero, because the reseed text moves to the README, which is outside that grep's scope.
  Add one Edge Cases line saying this supersedes that check, so a later re-run is not read as a regression.
- **Skill inline floors:** kept, and the README sentence preserves the rationale the deleted "do not deduplicate" NOTE carried.
  The floors' parenthetical "(thin lead, dispatch-by-default, single-writer file ownership...)" in `iterate:13` and `propose-revise:17` names terms that are no longer headings, which is harmless.
- **Chat record in the orchestration rule:** consistent with the review and with both test-asserted phrases.
  `frontmatter-spec.md:84` and README:131 are retargeted to "Chat record", which is correct.
- **Template example rows [non-blocking]:** when the Column Semantics prose becomes example rows, keep them below the five copied H2 sections, as the template does today.
  An example `review_verdict: accept` row copied into a live devlog would be read by `triage` as the loop's last row.

### Phases (focus 4)

- **F10 [blocking] The Phase 2 gate has two readings.**
  The Phase 2 text says "surface the root `CLAUDE.md` edit to the maintainer ... before deleting the rule" (ask, then proceed).
  Edge Cases says "Phase 2 is therefore gated on that approval" (wait).
  The Test Plan allows the "Overseer arc" line to remain "until the maintainer approves", which only makes sense if deletion can happen before approval.
  Under `full-send` running to accept, the waiting reading stalls the loop at Phase 2 with Phases 3 to 7 queued behind it, although none of them depends on the gate.
  Pick one policy. Recommended:
  - The full-send overseer asks at the propose-to-iterate boundary, together with the other two open questions, so the answer is usually in hand before Phase 2.
  - If it is not, Phase 2 deletes the rule anyway, skips step 4, and records a devlog open todo.
    The dangling `@`-import is in the maintainer's own file, and the Test Plan already tolerates it.
    Verify once that Claude Code ignores a missing `@`-import silently.
  - Alternatively, move "delete `oversee-arc.md` + init step 6 + `CLAUDE.md` line" into the final pre-verification phase, so nothing else waits on it.
- **Overlap [non-blocking]:** Phase 4 lists the `model-tiering.md` and `oversee/SKILL.md` Cross-Target blocks, but Phases 5 and 2 already remove them by full replacement.
  Trim Phase 4 to the init NOTE and the six agent NOTEs.
  Phases 4, 5, and 6 are each a few minutes of work; merging them into one "cleanup" phase saves two review rounds in an iterate loop.
- Phase 3 is the largest and correctly keeps the thinness columns and their readers in one commit.
  The order (rule first, then the arc fold, then the loop skills) is sensible: each intermediate commit leaves only harmless dangling section anchors.

### Verification (focus 5)

- The Test Plan plus steps 2 and 3 cover every floor item: build, validator, unit suite, dead-reference grep, and a live `claude -p --plugin-dir plugins/cdocs --model sonnet` iterate smoke with delegation and dispatch/return rows.
- **F11 [blocking] Explicit-path staging is checked only by absence.**
  The floor says the smoke "shows ... explicit-path staging".
  The pass criteria check only that `git add -A`, `git add .`, and `commit -a` are absent, so a run that never commits passes vacuously.
  Require at least one `git add <explicit path>` in a transcript.
  The sandbox also needs `git config user.name/user.email`, or commits fail and the check is vacuous anyway.
- [non-blocking] "The lead makes no `Write` or `Edit` to `greet.sh`" misses a lead writing via a Bash heredoc.
  Checking that no lead-side tool call names `greet.sh` (other than reads) is tighter.
- [non-blocking] `init_rules` is a function inside `chat-record.test.sh`, not a standalone helper, so the implementer needs to replicate it.
  Name the three steps (marker, concatenation in init order, `CLAUDE.md` import) or say "copy `init_rules`".
  Pass `--plugin-dir` as an absolute path, since the smoke runs from the sandbox directory.

## Verdict

**Revise.**
The design is right and the replacement text is at the maintainer's altitude.
The four blockers are each a sentence or two: F10 (one Phase 2 gate policy), F1 (keep or explicitly drop the split-trigger pointer), F11 (positive staging evidence in the smoke), and F7 (Phase 1 check vs init line 26).
With those fixed, round 2 should accept.

## Action Items

1. [blocking] F10: state one Phase 2 gate policy and make Phase 2, Edge Cases, and the Test Plan agree. Recommended: ask at the propose-to-iterate boundary, and if no answer arrives, delete anyway, skip the `CLAUDE.md` step, and log it.
2. [blocking] F1: restore the split-trigger pointer as one clause in "Durable state", or record its removal as a design decision.
3. [blocking] F11: loop-smoke pass requires at least one explicit-path `git add` in a transcript; the sandbox sets a git identity.
4. [blocking] F7: move the init step 3 "Pillar 2" sentence fix into Phase 1, or add init to the Phase 1 grep exceptions.
5. [non-blocking] F2: add "log each dispatch and return (agent, target files) in the devlog" to "Resume from disk".
6. [non-blocking] F8: extend the dead-reference grep with the four section-name patterns, and drop the nonexistent root `AGENTS.md`.
7. [non-blocking] F9: note in Edge Cases that the chat-record 1a `/compact` grep now returns zero lines.
8. [non-blocking] Say that the `oversee-arc.md` deletion and the init step 6 edit land in one commit.
9. [non-blocking] F5, F6: move the isolation sentence out of "Durable state", and make `oversee`'s TOP-LEVEL ONLY note self-contained.
10. [non-blocking] Trim the Phase 4 overlap; consider merging Phases 4 to 6.
11. [non-blocking] Replace line-number citations in "Inbound references" with section names; compress the `oversee` "drops" list to "everything not kept".
12. [non-blocking] Move the status-of-the-world sentences (chat-record `implementation_accepted`, sequencing) to the devlog.
13. [non-blocking] Keep template example rows outside the copied H2 sections.

## Questions for the Maintainer

1. Phase 2 gate when the `CLAUDE.md` approval has not arrived:
   - (a) Delete the rule anyway, leave the dangling import, and log a todo (recommended).
   - (b) Block Phase 2 until approval and run Phases 3 to 6 first.
   - (c) Grant approval now for the proposed `CLAUDE.md` line.
2. Devlog split trigger:
   - (a) Keep one clause in the rule's "Durable state" (recommended).
   - (b) Drop it; splitting happens only when someone invokes the devlog skill.
3. Phases 4 to 6:
   - (a) Merge them into one cleanup phase (recommended).
   - (b) Keep them separate.
