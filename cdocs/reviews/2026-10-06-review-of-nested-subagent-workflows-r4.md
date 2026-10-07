---
review_of: cdocs/proposals/2026-10-06-nested-subagent-workflows.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T18:36:06-07:00
task_list: cdocs/nested-subagent-workflows
type: review
state: live
status: done
tags: [fresh_agent, rescope, deletion_completeness, test_plan]
---

# Review: Nested Subagent Workflows (Round 4)

> BLUF: **Accept.** The re-scope is faithful: no overseer behavior changes, the nest-overseer material moved whole into the RFP, and every prohibition site in `plugins/cdocs` maps to a table row.
> Six non-blocking nits, the most useful being that "children inherit these boundaries" and the implementer's worktree isolation only hold if the parent writes them into the child's prompt, since the edit-path hook is `agent_type`-scoped.

## Summary Assessment

After the maintainer's re-scope, the proposal deletes cdocs' "subagents cannot dispatch" workarounds (including `## Investigation Requested`) so that non-overseer agents dispatch freely within the platform depth limit, corrects `/oversee`'s stated reason, and defers nested overseers to `2026-10-06-nest-overseers-rfp.md`.
At 1,486 words (down from 2,614), it is a tight deletion plan with a confined live check.
The scope is faithful and the deletion inventory is complete; the remaining gaps are wording and failure-picture coverage, none of which blocks implementation.
Verdict: **Accept**.

## Verification Performed

- **Deletion inventory.** I ran a wider grep over `plugins/cdocs` (the proposal's pattern plus `unavailable inside`, `subagents cannot`, `no nested`, `top-level only`, `nested`, `depth`, `platform forbids`) and `git grep` outside `cdocs/` and `plugins/cdocs`.
  There are 17 prohibition hits, and every one maps to a table row: implementer 38, proposer 39, reviewer 62, implement 20/23/64/94, propose 142, triage 71, iterate 85, oversee 16, and ablate 28 (with 29), 165, 178, 275, 279.
  The "four sites plus the NOTE" count for ablate is correct.
  Nothing outside the plugin matches.
- **Kept sites.** These are correct to keep:
  - `/oversee` TOP-LEVEL ONLY (the maintainer's decision).
  - `orchestration-discipline.md` "Chat record" (`chat-record` is top-level-only, which is true).
  - The "Overseer: top-level agent" role lines in `iterate` and `propose-revise` (overseer mechanics are out of scope).
  - `implement` "(top-level mode)" on step 7 and "Use cdocs skills" (in dispatched mode, the loop's reviewer reviews).
- **Post-edit grep.** Once the table is applied, the static grep is clean.
  `oversee:16` currently matches `cannot dispatch`, which the section 2 reason change removes.
  As intended, the grep no longer matches the kept `TOP-LEVEL ONLY`.
- **Harness facts.** `hooks/tests/chat-record.test.sh` `claude_run` uses `env -i`, a sandboxed `CLAUDE_CONFIG_DIR`, and `--plugin-dir`, and has an `init_rules` helper.
  On this machine, depth-2 `*.meta.json` files carry `parentAgentId`, and depth-1 files omit it, which the jq `// "-"` handles.
  So the cut Background row about meta.json fields loses no needed backing: the fields the jq reads exist.
- **Edit-path hook.** `validate-cdocs-edit-path.sh` restricts by `agent_type` only (`CDOCS_AGENTS="triage nit-fix reviewer"`).
  A reviewer's `general-purpose` child is therefore unrestricted, which the proposal's reviewer row states correctly.
- **Self-evidence.** This review runs as a depth-1 `cdocs:reviewer` (`tools: "*"`), and it has the `Agent` tool even though its `reviewer.md` says it cannot dispatch.

## Re-scope Fidelity

- **No overseer behavior change sneaks in.**
  - Section 2 changes only `/oversee`'s reason string.
  - Section 1's `iterate` edit deletes a paragraph that describes the *implementer's* `--dispatched` mode, not the overseer's.
  - The implement "caller decides" paragraph describes how an overseer handles an `Investigation Requested` block that can no longer arrive, so removing it is vestigial cleanup, not a mechanics change.
  - The Phase 2 constraints explicitly fence off `iterate`, `propose-revise`, `full-send`, `oversee`, and `rules/`.
- **Nothing nest-overseer-specific remains.** The following are all in the RFP's seed design:
  - the chat layer;
  - sub-overseers;
  - the missing-`Agent` fail-loud rule;
  - the `chat_record` pass-down;
  - the depth budget;
  - the arc-devlog and `position` cuts.

  The proposal mentions overseers only to place them out of scope.
- **Nothing load-bearing was lost.** The capability table keeps every r1-r3 empirical finding that still applies, including depth 3, withholding at the limit, `tools:` gating, the return path, waiting for background children, `AskUserQuestion` absence, and hooks at depth.
  The resumed-depth fact moved to the RFP, where it is used.
  The harness keeps the r2 blocker fix (`git init` outside any repo, sandboxed config, `env -i`, `--plugin-dir`, `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`) and the r3 `init_rules` fix.
  Two small items were dropped: the explicit `--permission-mode` and the `requestShape` assertion (see finding 5).
- **The RFP stub is adequate.** It matches the rfp template (Objective, Scope, Open Questions), is `deferred`/`request_for_proposal` with `future_work`, links r1-r3, and carries the seed design, trade-offs, and verification ideas with enough fidelity to restart from.
  The NOTE that the maintainer may negate the RFP sets the right expectation.

## Section-by-Section Findings

### Section 1: Delete the leaf workarounds

1. **`agents/implementer.md` row: "Delete the 'cannot dispatch' sentence."** (non-blocking)
   Line 38 does not contain that literal phrase.
   It reads "When a `/cdocs:iterate` overseer dispatches you, you run in `--dispatched` mode: the platform forbids ...".
   Deleting the whole sentence also drops the only statement in `implementer.md` that ties the agent to `--dispatched` mode.
   That is probably redundant with the Task prompt, but the row should say so.
   Alternatively, keep the leading clause and cut from the colon.
2. **"Children you dispatch inherit these boundaries" (reviewer), and isolation (implementer).** (non-blocking, most substantive)
   A child never reads its parent's agent file, and the edit-path hook binds only listed `agent_type`s, so "inherit" holds only if the parent writes the boundaries into the child's prompt.
   The implementer has the same gap with its worktree isolation (`implement` line 30).
   A child does not start in the implementer's worktree unless it is told the path, so a `bash-runner` could test the main checkout, or a writer child could write there.
   Suggested wording, one clause each:
   - reviewer: "State these boundaries in any child's prompt: the edit-path hook binds only your own `Edit`/`Write`."
   - implement Dispatched bullet: "Give children you dispatch your worktree path; they inherit your isolation."
3. **ablate's replacement reason is too broad.** (non-blocking)
   "Not yet run live (needs a graphify container)" fits the dogfood item.
   Two other deferred items do not need graphify:
   - confirming precondition (a)'s per-dispatch grant expression (any MCP tool, plus a lead with dispatch layers below it);
   - confirming the `toolUseResult` payload nesting.

   Line 165 describes where the spike ran, so the replacement phrase will not parse there.
   The WARN at 178 ("What a subagent CANNOT confirm") becomes false, not merely stale.
   Suggestion: use "not yet run live" generally, and name the graphify container only on the dogfood item.
4. **implement line 18 and step 5.** (non-blocking, optional)
   "Top-level (default): ... Free to dispatch `/cdocs:review` and `/cdocs:report`" now reads as a contrast with dispatched mode, and step 5's dispatched line covers review only.
   A dispatched implementer may still reasonably dispatch `/cdocs:report`.
   Either drop "Free to dispatch ..." or leave it, since the Agent description governs anyway.
   Minimalism favors dropping it.

### Section 2: `/oversee` reason

- The behavior is unchanged, which is correct.
  The new reason cites `AskUserQuestion`, but `oversee/SKILL.md` never uses it.
  Its human contact is hard gates, `full`'s proposal-set choice, and resume's "or ask".
  "It needs the human for hard gates and escalations, whom only the top-level session reaches" is more precise.
  See Question 2 for an alternative framing. (non-blocking)

### Section 3: OpenCode

- No findings. The `mapTools` `"*"` bug stays correctly out of scope, with an rfp filed in Phase 1.

### Test Plan and Verification Methodology

5. **Failure-picture coverage.** (non-blocking)
   The floor (a depth-2 `bash-runner` parented by the depth-1 implementer) is concrete, confined, and detects the main failure: stale text that makes the implementer refuse.
   Three gaps:
   - **No outcome is defined for an implementer that runs the command inline without claiming it cannot dispatch.**
     The floor fails in that case, but neither stated picture explains it.
     Add: "no `bash-runner` and no refusal: the fixture cue was too weak; strengthen it and re-run, not a pass."
     A Verification Methodology instruction in the fixture is a proposal directive rather than coaxing, so r3's concern about a floor item (Q2b) is acceptable here, because nesting is the thing under test.
   - **The `claude -p` invocation does not state `--permission-mode bypassPermissions`.**
     That is how every `claude_run` caller in `chat-record.test.sh` passes it.
     Given [#83421](https://github.com/anthropics/claude-code/issues/83421), add the picture "a depth-2 `bash-runner` exists but its Bash calls appear in `permission_denials`": the mode did not reach the child.
   - **The r3 assertion "every `requestShape` is `foreground`" was dropped.**
     It is cheap (one more jq column) and catches the case where the env var did not take.
     It is optional, because the floor only needs the meta file to exist.

### Edge Cases

- These are adequate for the reduced scope.
  Concurrent writers under a nesting implementer are covered by the existing one-writer-per-file rule, which addresses any dispatcher.

## Verdict

**Accept.**
No blocking issues.
The re-scope keeps overseer mechanics untouched, the deletion inventory is complete against the plugin tree, and the live check is confined and concrete.
The nits sharpen wording for the implementer, reviewer, ablate, and oversee rows and close two gaps in the failure pictures; the implementer can apply them in the accepting round or during Phase 1.

## Action Items

1. [non-blocking] `implementer.md` row: say the whole line-38 sentence goes, including the `--dispatched` clause, or keep "When a `/cdocs:iterate` overseer dispatches you, you run in `--dispatched` mode." and cut from the colon.
2. [non-blocking] Reviewer row: replace "Children you dispatch inherit these boundaries." with "State these boundaries in any child's prompt: the edit-path hook binds only your own `Edit`/`Write`." Add to the implement Dispatched bullet: "Give children you dispatch your worktree path; they inherit your isolation."
3. [non-blocking] ablate row: use "not yet run live" as the general replacement and name the graphify container only on the dogfood item. Note that line 165 and the 178 WARN need rewording rather than a phrase swap.
4. [non-blocking] Optionally drop "Free to dispatch `/cdocs:review` and `/cdocs:report` as supporting subagents" from implement's Top-level bullet.
5. [non-blocking] Section 2: replace "(gates, `AskUserQuestion`)" with "hard gates and escalations", or adopt Question 2(b).
6. [non-blocking] Live check:
   - add `-p --permission-mode bypassPermissions` to the run;
   - add the failure pictures "no `bash-runner` and no refusal: cue too weak, re-run" and "`bash-runner` Bash calls denied: permission mode did not reach the child";
   - optionally restore the `requestShape` column and assert `foreground`.

## Questions for the Author

1. Child boundaries and isolation (action item 2):
   - (a) One clause each in `reviewer.md` and implement's Dispatched bullet (recommended: isolation and the review boundaries are cdocs invariants the hook does not enforce at depth, and the Agent description does not know about them).
   - (b) Leave it to the model, consistent with "no nesting guidance".
2. `/oversee`'s stated reason:
   - (a) "It needs the human for hard gates and escalations, whom only the top-level session reaches" (recommended: true today and behavior-neutral).
   - (b) "Nesting an overseer is the user's decision; see `2026-10-06-nest-overseers-rfp.md`" (states the actual policy, but links a deferred doc from shipped skill text).
