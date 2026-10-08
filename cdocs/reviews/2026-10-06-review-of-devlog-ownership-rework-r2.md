---
review_of: cdocs/proposals/2026-10-06-devlog-ownership-rework.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T11:56:48-07:00
task_list: cdocs/devlog-ownership-rework
type: review
state: archived
status: done
tags: [fresh_agent, rereview, architecture, devlog, orchestration_discipline, test_plan, evidence_checked]
---

# Review: Devlog Ownership Rework (round 2)

> BLUF(@claude-opus-5-5/cdocs/devlog-ownership-rework): **Accept.** Every r1 item is resolved without new structural problems, and the retroactive split machinery is actually gone.
> One fixture is mis-specified against the real data: fixture 4's proposal and devlog family have different `task_list` values, so triage falls back to the blind path and returns exactly the regression the fixture names as failure, whatever this change does.
> That is a one-line setup fix, best applied before the implementer is dispatched; the rest are nits.

## Summary Assessment

The revision folds in design A as decided: the lead's top-level devlog is the index and state record, sub-devlogs are cut forward at soft content seams, one writer at a time, loop tables stay top-level, reviewers keep no devlogs.
Read fresh as its implementer would, each phase names its files and a checkable success bar, and the greps and fixture sources mostly check out against the current tree.
The restart flow with the ~400K cap is coherent: the outgoing implementer writes its handoff, the overseer names the sub-devlog to continue, and the successor replaces the Scratchpoint.
The one substantive finding is fixture 4's setup (see Test Plan); the verdict is Accept with nits.

## r1 Action Items

| # | item | status |
|---|---|---|
| 1 | Fold in the steer (concern-named sub-devlogs, succession, one writer at a time) | resolved: BLUF, Summary table, Roles, diagram, Who writes what, Decision 2, Restart, Edge Cases |
| 2 | Seam check at every return or handoff | resolved ("Look at every return or handoff") |
| 3 | One live Scratchpoint per writer per workstream | resolved (lines 100-101; the lead's stays in the top-level) |
| 4 | Tables do not count toward size | resolved (Continuing forward, Decision 5) |
| 5 | Iterate Turn 0 continues the top-level (no `part_of`) | resolved (Changes by file) |
| 6 | Restart dispatch names the top-level | resolved (Restart step 2) |
| 7 | Grep adds `top of its own`, `notes section` | resolved |
| 8 | Fixture 4 on copies; haiku fixture; reshape fixture 2 and the smoke | resolved, but fixture 4 has a data problem (below) |
| 9 | Arc-devlog and root-table claims | resolved |
| 10 | Dead writer's devlog may be set `done` | resolved |
| 11 | Open Questions answered and removed | resolved |

## Section-by-Section Findings

### Lightness

- The split procedure (closed-concern test, cut, ~400-word merge floor, moved-row lines, rewording moved text, the ~5-round trigger) is gone; what remains is five bullets and a sentence of size guidance ("size prompts the look; the content chooses the cut").
- Triage's lookup stays one sentence; the highest-iteration rule is simpler than the current empty-root-table clause and handles both legacy chunks and forward tables.
- **non-blocking:** the `## Workstream Devlogs` columns (`devlog | writer | status | read this when`) add upkeep the old `## Chunks` table did not have: under succession `writer` changes per restart, and `status` duplicates the sub-devlog's frontmatter now that sub-devlogs are live.
  `| devlog | concern | status | read this when |` (the old columns) drops the churny one; the Scratchpoint already names the current writer.
- **nit:** 44 semicolons; writing-conventions asks for them sparingly. "around ~1,500 words" double-hedges. Line 81's "a seam worth cutting" reads as retroactive; "a seam" suffices.

### Roles, Who writes what, Continuing forward

- Coherent. One gap: when a concern finishes and the next concern goes to a different implementer, nobody is told to close the finished sub-devlog (the "closes the one it leaves" rule binds only a writer that moves on).
  **non-blocking:** one clause, such as "the overseer sets a finished concern's sub-devlog to `done` when no writer remains on it", or rely on triage's step 5 recommending it.
- **nit:** a forward table continuation is an overseer-written sub-devlog with no Scratchpoint (the lead's stays top-level), which sits oddly beside "a sub-devlog is a normal devlog: ... Scratchpoint".
  Half a sentence ("a table continuation holds only the tables") covers it.

### Restart and rotation

- Reads coherently against "Stay thin" and the implementer's restart-request handoff; "when it can" covers a dead writer, and Edge Cases picks up the rest.

### Lookup

- Sound. Checked: the Judge Log keys rows by `judge_iteration`, so "highest iteration number" applies to both tables; iteration cells like `4 (2)` and `1 (propose)` parse as leading integers.
- **non-blocking, pre-existing:** a top-level shared by propose-revise and iterate (now explicit: "continued by later loops on the same proposal") carries design-review rows in its Iteration Log, so a propose-revise `accept` as the latest row reads as an implementation accept (`[STATUS] implementation_accepted`).
  Full-send devlogs already do this (this loop's devlog has a `1 (propose)` row), so it is out of scope; worth a follow-up RFP or a clause in triage keying off the `(propose)` label.

### Changes by file

- Coverage is complete against a sweep of `plugins/cdocs` (`split`, `part_of`, `chunk`, `own section`, `Implementer Notes`): every current hit is in a listed file.
- **nit:** `skills/triage/SKILL.md` has no chunk or `part_of` text today; its row in the table may be a no-op.
- **nit:** the nested-`part_of` report (Edge Cases) belongs in the triage step 2 wording; the change row says only "Steps 2 and 5 wording".

### Test Plan

- Stale-reference grep: run against the current tree, its patterns hit every stale line (`implementer.md:39`, `devlog/SKILL.md:31,43,120-140`, `implement/SKILL.md:85`, `iterate/SKILL.md:113`, `orchestration-discipline.md:33-34`, `frontmatter-spec.md:30,86-90`, `triage.md:42,52,58,119`, `status/SKILL.md:55`), and `chunk` matches only devlog-split text, so Phase 2's empty-grep bar is achievable.
- Validator: `cdocs-validate-frontmatter.sh` checks only presence of required fields, so a `part_of` + `wip` fixture is silent as expected.
- Fixture 5 checks out: the arc root cites the haiku proposal, has an empty Iteration Log, chunks hold rows 1-5 and 6-8 (row 8 accept), Judge rows at 5 and 8, the proposal is `implementation_accepted`, and the `p1-propose-revise` chunk has no Iteration Log, so `[NONE]` is the right expectation.
- **non-blocking, fix before dispatch:** fixture 4 cannot pass as written.
  `cdocs/proposals/2026-09-22-chat-record-devlog-management.md` has `task_list: meta/chat-record-devlog-management`; its iterate family (`2026-10-05-chat-record-devlog-management-iterate*.md`) has `task_list: cdocs/chat-record-devlog-management`.
  The `meta/` devlogs (`2026-09-22-...-propose-revise*`, `...-revise-r5`) have no `## Iteration Log`, so step 6 finds nothing and the blind path (`last_reviewed: accepted`, status not `implementation_ready`) returns `[STATUS] implementation_ready`: the named failure, on both the old and new triage text.
  Fix: in the scratch copies, set the proposal's `task_list` to `cdocs/chat-record-devlog-management` (the family's highest row is 6, accept, and the proposal is `implementation_accepted`, so `[NONE]` follows).
  The mismatch also means triage on the real chat-record proposal regresses today; that is outside this proposal, but worth a note to the overseer.
- **nit:** fixture 1's `implementation_wip` status is valid per implement's convention; no change.

### Verification Methodology

- Matches the loop devlog's restated Brief floor (build, validator, unit suite, grep, triage fixtures, sonnet iterate smoke with lead-only top-level and implementer-only sub-devlog) and adds the two-Scratchpoint failure.
- **non-blocking:** "Every Write/Edit on the top-level comes from the lead" misses Bash writes.
  The precedent smoke (rules-context devlog, Phase 5) records the lead writing its devlog through heredocs, and bypass-permissions agents edit with `sed -i` and redirects; count any tool call that writes the path (Write, Edit, or a Bash redirect, heredoc, or `sed -i` naming it).
- The smoke driver the proposal cites exists in the session scratchpad (`scratchpad/loop_smoke.sh`), so "adapt" is concrete, though `/tmp` is ephemeral; the devlog's description is enough to rebuild it.

### Implementation Phases

- Each phase is executable and checkable as written.
- **nit:** Phase 1's Durable state wording points at the devlog skill's continuation section, which lands in Phase 2; harmless between sequential commits.
- Phase 4's "this repo has none to regenerate" is correct (no `.claude/rules/cdocs.md`, no `AGENTS.md`).

## Verdict

**Accept.**
All r1 blocking items are resolved, the design is light, and the remaining items are nits plus one fixture-setup correction that is mechanical and can be applied inline before the implementer is dispatched (or left to the implementer, who works on copies in a scratch repo).

## Action Items

1. [non-blocking, before dispatch] Fixture 4: align the copied proposal's `task_list` with the iterate family's (`cdocs/chat-record-devlog-management`); otherwise it fails on unchanged and changed triage alike.
2. [non-blocking] Smoke authorship check: count Bash writes (redirects, heredocs, `sed -i`) as well as Write/Edit.
3. [non-blocking] Say who closes a finished concern's sub-devlog when the next concern goes to another implementer (the overseer, or leave it to triage's step 5).
4. [non-blocking] Workstream Devlogs columns: consider `devlog | concern | status | read this when` (no churny `writer`).
5. [non-blocking] Put the nested-`part_of` report in the triage step 2 change row; check whether `skills/triage/SKILL.md` needs any edit.
6. [non-blocking] Half a sentence noting a forward table continuation holds only tables (no Scratchpoint).
7. [nit] Trim semicolons; "around ~1,500"; "a seam worth cutting".
8. [follow-up, out of scope] Triage reads a propose-revise `accept` row in a shared top-level as an implementation accept; and the real chat-record proposal and its iterate family disagree on `task_list`.

## Questions for the Maintainer

1. Fixture 4's `task_list` fix:
   a. overseer applies the one line inline before dispatch (recommended), or
   b. leave it to the implementer, noting it in the dispatch prompt.
2. Propose-revise `accept` rows in a shared top-level Iteration Log:
   a. follow-up RFP (recommended; pre-existing with full-send), or
   b. one clause in this proposal's triage change (rows labelled `(propose)` are design reviews and do not map to `implementation_accepted`).
