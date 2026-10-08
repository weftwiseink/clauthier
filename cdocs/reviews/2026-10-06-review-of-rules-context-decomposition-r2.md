---
review_of: cdocs/proposals/2026-10-05-rules-context-decomposition-rfp.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T09:36:46-07:00
task_list: cdocs/rules-context-decomposition
type: review
state: archived
status: done
tags: [fresh_agent, formalism_reduction, rules, phase_gating, verification, dead_references]
---

# Review: Rules Context Decomposition (round 2)

> BLUF(@claude-opus-5-5/cdocs/rules-context-decomposition): All four r1 blockers and every non-blocking item the revision took on are resolved without new design problems.
> The budget still checks out (296 / 2,145 lines/words for the always-loaded set), and the phase checks are well-formed against the current tree.
> Three phase-boundary nits remain, each of which an implementer can fix in passing: the README Rules-list line trips the Phase 1 grep, the judge NOTE is both deleted in Phase 3 and replaced in Phase 4, and the rule's Scratchpoint field list omits `as_of`.
> Verdict: **Accept**.

## Summary Assessment

The proposal compresses the always-loaded cdocs rules by about 63% in lines and 74% in words, deletes `oversee-arc.md` and the Cross-Target blocks, and moves the arc-only material into the `oversee` skill.
Revision `3f60b53` fixed each r1 blocker in a sentence or two: Phase 2 is no longer gated, the split-trigger clause is back, the smoke requires positive explicit-path staging, and Phase 1 now owns the init step 3 sentence.
It also merged the cleanup phases, trimmed the restated drop lists, and moved status-of-the-world sentences out.
Read fresh, the five phases are executable as written; what remains are phase-ordering nits.

## Method

- Diffed `3f60b53` against its parent and checked each r1 action item.
- Re-measured the quoted replacement text plus the verbatim Bash section and the two unchanged files: orchestration 63 / 682, model-tiering 9 / 136, workflow-patterns 21 / 191, total 296 / 2,145. This matches the table's 63 / 680 and ~300 / ~2,150.
- Ran `chat-record.test.sh --unit` on the current tree: 95 passed, 0 failed.
- Ran the validator command from the Test Plan against this proposal: silent, exit 0.
- Ran the Phase 1 `Pillar [0-9]` grep and the full dead-reference grep on the current tree.
  For every hit, I confirmed that some phase's spec removes it, and checked which phase does.
- Confirmed the smoke harness pieces exist: `--headless --only rules_check`, the `init_rules` and `init_rule_order` functions, the two asserted phrases (test lines 819-820, both present verbatim in the new text), README "Sandbox testing notes", and `postinstall.js` reading `INIT_CWD` with `PKG_ROOT` from `__dirname`.
  This makes the Phase 4 scratch `postinstall` check well-formed.
- I did not run `npm run build:cdocs`, because it is codegen; the `package.json` script exists.

## r1 Action Items

| r1 item | Status |
|---|---|
| 1 [blocking] F10 Phase 2 gate | Resolved. The maintainer approved; the gate is removed, and Phase 2 step 2, the Test Plan's single allowed hit, and Open Questions agree. |
| 2 [blocking] F1 split trigger | Resolved. "Durable state" now says "check the devlog against the devlog skill's split trigger". |
| 3 [blocking] F11 positive staging | Resolved. The smoke needs at least one explicit `git add`, and the sandbox sets a git identity. |
| 4 [blocking] F7 Phase 1 vs init | Resolved. The init step 3 sentence is in Phase 1 step 2. |
| 5 F2 dispatch/return logging | Resolved: the first line of "Resume from disk". |
| 6 F8 grep gaps | Resolved. The four section-name patterns are added and root `AGENTS.md` is dropped. |
| 7 F9 chat-record `/compact` grep | Resolved: new Edge Cases entry. |
| 8 same-commit deletion | Resolved: Phase 2 step 2. |
| 9 F5/F6 | Resolved. The isolation line is under "Stay thin", and the TOP-LEVEL ONLY note is self-contained. |
| 10 Phase 4-6 merge | Resolved: one "Cleanup" phase, five phases total. |
| 11 line cites, drops list | Resolved: section names, and one "everything else goes" sentence. |
| 12 status-of-the-world | Resolved. The Background bullet and the Sequencing NOTE line are gone. |
| 13 template example rows | Resolved: stated in the template spec. |

F3 (post-compaction for a dispatched agent) was optional and stays out, which is fine.

## Section-by-Section Findings

### Replacement rule text

- The added lines read naturally and fit the maintainer's altitude.
  "Resume from disk" is now three lines, and "Durable state" takes the split check as a clause rather than a step.
- **N3 [non-blocking]** The rule's Scratchpoint parenthetical says "(now, next, open, files touched)", but the iterate and devlog templates use `as_of`, `now`, `next`, `open`, `files`.
  An agent writing a Scratchpoint from the rule alone omits the timestamp, and `as_of` is what tells a resumer how stale the Scratchpoint is.
  Add "as_of" to the parenthetical, or leave it to the templates; either is fine.

### Phases (read as the implementer)

- **N1 [non-blocking] Phase 1's grep trips on README line 52.**
  The README Rules-list description of `orchestration-discipline.md` reads "plus Pillar 2's Scratchpoint, chat-record rule, and resumption steps".
  Phase 1 step 2 lists "the README hooks pointer" (line 131) but not this line.
  Phase 2 step 3 lists "the README rules list", and the Phase 1 exception list does not include README.
  As written, the Phase 1 check returns a hit.
  Fix in passing: re-describe the orchestration entry in Phase 1, since it targets this rule; Phase 2 still drops the `oversee-arc.md` entry.
  The grep itself points the implementer at the line, so this will not stall a loop.
- **N2 [non-blocking] The judge NOTE is handled twice.**
  The `judge` spec deletes "the stale startup NOTE" in Phase 3.
  That NOTE is `judge.md:27`, the same "SessionStart hook injection" fallback NOTE the other five agents carry.
  The Phase 3 check, which requires the dead-reference grep to be clean for `judge`, needs that deletion.
  Phase 4 step 1 then "replaces" the same NOTE with the plain fallback sentence.
  Fix in passing: in Phase 3, swap the judge NOTE for the plain sentence, so the agents stay uniform and Phase 4 touches the other five.
- Phase 3 step 3 names "Termination" and "conventions", which the `iterate` spec no longer names as such.
  They map clearly to the Delete bullet (the `pause` and soft-thinness paragraphs live under `## Termination`) and to "Sandboxed-runtime trust posture" under `## Conventions`, so no change is needed.
- I checked every current dead-reference hit against the phases.
  Each one is in a file that a phase's spec rewrites or removes: the `iterate` lines 15, 116, 133-135, 155-163, 173, 181-184, and 216 all fall inside the Keep/Delete/replace bullets, and the Graphify section has no hits.
  The only surviving hit is root `CLAUDE.md:55`, as the Test Plan states.
- The phase order still holds the invariant "unit suite passes after every phase".
  The only coupling the suite checks, the init list against `rules/`, lands in one commit in Phase 2.

### Verification

- The loop smoke now discriminates on all three failure-picture items: delegation, dispatch rows, and explicit staging.
  With the git identity set, a run that never commits fails instead of passing vacuously.
- The `rules_check` extra uses `init_rules` and the two asserted phrases, which survive verbatim, so step 2 runs without test edits.

### Formality and timelessness

- The proposal is leaner than r1 (43 insertions, 77 deletions) and no longer restates lists that the keep lists imply.
- The remaining structure is all used by the implementer: the budget table, Inbound references as a checklist, and the Do-not-change list.
  Nothing reads as over-formal.
- "None open: the maintainer approved..." in Open Questions is a decision record, which is acceptable there.

## Verdict

**Accept.**
No blocking issues remain.
N1 and N2 are phase-boundary nits that the per-phase checks themselves surface, and N3 is one word.

## Action Items

1. [non-blocking] N1: re-describe README's `orchestration-discipline.md` Rules-list entry in Phase 1 (it carries "Pillar 2"), or the Phase 1 grep returns one hit.
2. [non-blocking] N2: replace `judge.md`'s fallback NOTE with the plain sentence in Phase 3 rather than deleting it there and replacing it in Phase 4.
3. [non-blocking] N3: optionally add `as_of` to the rule's Scratchpoint field list so it matches the templates.
