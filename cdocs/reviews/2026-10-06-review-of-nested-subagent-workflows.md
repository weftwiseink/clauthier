---
review_of: cdocs/proposals/2026-10-06-nested-subagent-workflows.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T17:39:49-07:00
task_list: cdocs/nested-subagent-workflows
type: review
state: archived
status: done
tags: [fresh_agent, runtime_validated, architecture, orchestration_discipline, degradation_path, test_plan]
---

# Review: Nested Subagent Workflows

> BLUF(opus-5-5/cdocs/nested-subagent-workflows): The capability claims hold up (docs, CHANGELOG, issues, and a fresh layer-2/3 probe all agree), and the deletion half is the right minimal move.
> Verdict: **Revise**, on three blocking points.
> 1. "An agent without `Agent` does the work itself" is wrong for a loop lead: a sub-overseer with no dispatch tool collapses implementer and reviewer into one context.
> 2. Applying the whole rule file, "Stay thin" included, to every agent that has `Agent` tells implementers to delegate their own implementation.
> 3. The only check of the one structural change can be deferred with no runnable path named.

## Summary Assessment

The proposal removes the leaf-role workarounds (the `## Investigation Requested` schema and seven "cannot dispatch" sentences) now that Claude Code nests subagents to three layers.
It also moves `/oversee` loops into dispatched sub-overseers.
The research is careful and the claims are honestly sourced: everything spot-checked below is accurate.
The deletion half is minimal and well-scoped.
The problems are in how the new text generalizes.
The degradation rule and the "this file applies to any lead" sentence are each too broad, and both bear on the one structural change, which has no guaranteed live verification.
None of this needs new formalism to fix: each blocker is a sentence-level scope correction.

## Claim Verification

Each claim was checked independently, not taken from the proposal.

| Claim | Check | Result |
|---|---|---|
| Depth 3 by default, `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`, `1` disables, `Agent` withheld at the limit, a fork at the limit keeps `Agent` but errors | WebFetch of [sub-agents docs](https://code.claude.com/docs/en/sub-agents) | Confirmed verbatim. |
| CHANGELOG 2.1.219 and 2.1.187 | `curl` raw CHANGELOG into the scratchpad, then grep | Confirmed. 2.1.187 also says "resumed subagents now restore their original spawn depth", which supports the sub-overseer resume path and is worth citing. 2.1.217, two versions earlier, *disabled* nesting by default (see finding 5). |
| Layer 2 has `Agent`, layer 3 does not, and `AskUserQuestion` is absent everywhere | Fresh probe: this reviewer (layer 1) dispatched a haiku child, which dispatched a grandchild | `CHILD agent_tool=yes askuserquestion=no`, `GRANDCHILD agent_tool=no askuserquestion=no`. This reviewer (layer 1) also has `Agent` and no `AskUserQuestion`. |
| `subagent_tokens` reaches subagent parents | The probe's task notification to this layer-1 reviewer | Confirmed (`<subagent_tokens>33053`). |
| `Agent(type)` lists ignored in subagent definitions; omitting `Agent` disables nesting | docs | Confirmed. |
| Interactive leads wait for children; headless and SDK leads do not | docs | Confirmed verbatim. |
| Plugin `PreToolUse` hooks apply inside subagents | docs ("Hooks from settings files, managed policy settings, and plugins all apply inside subagents") | Confirmed. The binding is by `agent_type` per `validate-cdocs-edit-path.sh` (`CDOCS_AGENTS="triage nit-fix reviewer"`), so a `general-purpose` child is unrestricted. |
| [#34592](https://github.com/anthropics/claude-code/issues/34592), [#84974](https://github.com/anthropics/claude-code/issues/84974), [#83421](https://github.com/anthropics/claude-code/issues/83421) | `gh issue view` | All three titles match what the proposal says about them (#83421 still open). |
| Leaf agents omit `Agent`; implementer, reviewer, and proposer are `tools: "*"` | grep of `agents/*.md` | Confirmed. |

## Section-by-Section Findings

### BLUF and Summary

- **non-blocking.** The BLUF is accurate and does not oversell.
  The Summary table's word estimates (about -10 net) are honest about being "close to neutral".
  The maintainer wants a net reduction, and the `wc -w` gate in the Test Plan enforces one.
  The fixes below must not push the total positive, so they are worded as replacements, not additions.

### Proposed Solution 1: the `Nesting` section

1. **blocking: "an agent without `Agent` does the work itself" is wrong for loop leads.**
   For a leaf role (implementer, reviewer, `bash-runner` at layer 3) inline fallback is benign, and the proposal is right that it matches the deleted text.
   For a *loop lead* it is not benign.
   A sub-overseer, or an `/iterate` overseer, without `Agent` that "does the work itself" implements and reviews in one context.
   That destroys the fresh-reviewer invariant the loop exists for, and the record would still show a clean accept.
   The current `oversee` note gets this right ("a dispatched `/oversee` declines or runs advisory only, and says so"), and the proposal deletes that safeguard.
   This bites in three cases the proposal names elsewhere: nesting disabled (`=1`, or Claude Code before 2.1.219, including 2.1.217, where nesting was off by default), `/oversee` itself dispatched, and OpenCode, whose subagent `task` availability is unverified (Proposed Solution 4).
   Fix with one clause in the Nesting text, which replaces the oversee-specific degradation sentences rather than adding to them: "a loop lead without `Agent` returns at once and says so; it never plays its own children's roles."
   Add one line to `oversee`: if a sub-overseer returns that, run the loop as the arc overseer (today's behavior).
   Then correct the Edge Cases bullet "A user-lowered `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` degrades the same way": at `=2` the sub-overseer still dispatches leaf implementers (fine), but at `=1` the loop collapses.

2. **blocking: "this file applies to it as it does to a top-level overseer" over-applies "Stay thin".**
   "Stay thin" says to delegate "anything beyond a trivial few-liner (bulk reads, sweeps, builds, tests, implementation)".
   An implementer told that the file applies to it will read this as an instruction to farm out its implementation.
   That contradicts the Nesting section's own "don't nest ... a task whose child would re-read most of what you hold", and it is exactly the reflexive fan-out the Cost edge case worries about.
   The proposal's line "Everything else in the rule file already reads correctly for a nested lead. That includes 'Stay thin'" is true for a sub-overseer and false for an implementer or reviewer.
   Fix by scoping the opening sentence, at no extra length: loop leads (sub-overseers) take the whole file; any other agent that dispatches takes one writer per file, durable state for writers it starts, and the Bash section, and stays the workhorse for its own task.

3. **non-blocking: the Nesting draft can be shorter.**
   The second sentence ("Dispatch from where the need arises: an implementer sends ...") restates the Stories.
   Cutting it to "Dispatch from where the need arises." recovers about 25 words to pay for the two scope fixes above.

4. **non-blocking: the "Resume from disk" qualifier.**
   "Writers and long runners" is the right cut.
   Name the sub-overseer explicitly as a long runner, so the arc overseer logs it in the arc devlog: today oversee's arc file tracks `arc_state` per proposal but has no dispatch/return row for the sub-overseer itself.
   Alternatively, state that `arc_state: in_progress` *is* that row, which costs fewer words.

### Proposed Solution 2: deleting the leaf workarounds

5. **non-blocking: the `ablate` row is underspecified, and the grep misses some of its text.**
   `ablate/SKILL.md` has four sites, not two.
   - Line 28: a NOTE, "This skill CANNOT run from inside a subagent". The edit table does not mention it, although the grep catches it via "subagent-from-subagent". With nesting, ablate can run from layer 1 (arms at layer 2), so the NOTE should become "run it from a lead with two dispatch layers below it" or be deleted.
   - Line 165: "validated as far as is possible from inside a subagent".
   - Line 178: a WARN, "PARTIALLY CONFIRMED from inside a subagent ... What a subagent CANNOT confirm".
   - Lines 275 and 279: the "Deferred to the top-level e2e test" WARN and section.

   The Test Plan grep does not match lines 165, 178, or 275 ("cannot run from inside a subagent").
   Add `inside a subagent` to the grep pattern and list each site in the row.
   Some deferred items (the per-dispatch grant expression, the `toolUseResult.totalTokens` payload shape) are no longer blocked by nesting at all.
   The row's "the deferred items themselves stay" is fine, but their stated reason should be "not yet run live", as the row already says for the WARN.

6. **non-blocking: the reviewer delegation guidance is right, but its rationale overstates the hook.**
   "Reviewers delegate reads, never writes" is correct.
   But the edit-path hook matches only `Write|Edit` (`hooks.json`), and the reviewer already has unrestricted `Bash`, bound only by the prose "Use `Bash` for read-only inspection".
   Delegating to `bash-runner` or `Explore` (both have `Bash`) therefore leaks nothing that is not already prose-bound.
   The true statement is shorter: the boundary is prose, and the hook additionally binds the reviewer's own `Edit`/`Write`, which a `general-purpose` child would not inherit.
   Reword the design-decision bullet to that.
   Also note that `Explore` is one-shot and returns no agent ID (docs), so a reviewer cannot resume or steer it, which is harmless for the stated use.

7. **non-blocking: the sweep missed some "top-level" wording.**
   The full grep of `plugins/cdocs` found no prohibition the proposal missed beyond the ablate lines above.
   Two softer hits deserve a look:
   - `triage/SKILL.md` lines 59-61 assign `[REVISE]`, `[ESCALATE]`, and `[STATUS]` to the "Top-level agent". Under a sub-overseer that is "the loop's lead". Leaving it is tolerable, but the same role-line logic as the `iterate`/`propose-revise` edit applies.
   - `propose-revise/SKILL.md` lines 15 and 20, and `iterate/SKILL.md` lines 13 and 29, tell the overseer to `AskUserQuestion`. A sub-overseer will read these. The Nesting line "a nested lead escalates by returning" covers it generically (the rule file reaches subagents through CLAUDE.md), so no per-file edit is needed if finding 8 lands.

### Proposed Solution 3: `/oversee` sub-overseers

8. **non-blocking (close to blocking): put the escalation instruction where the sub-overseer receives it.**
   The escalation and steering sentences go into oversee's Hard gates, which the *arc* overseer reads.
   The sub-overseer reads `iterate`/`full-send`, which say "AskUserQuestion".
   Put one Down line in the Composition contract instead: "you cannot reach the user: return any question, and the arc overseer resumes you with the answer."
   That is the one channel guaranteed to reach the sub-overseer, and it removes the "stalls looking for `AskUserQuestion`" failure picture at its source.
   One more nuance: an interactive subagent waits for its background children before finishing.
   A sub-overseer that "ends its turn with the question" while an implementer runs will not deliver the question until that implementer returns.
   That is acceptable, but say so, so the arc overseer does not read the silence as a hang.

9. **non-blocking: `chat_record` is not quite "unaffected".**
   Today the `/iterate` overseer is top-level and adds `chat-record path` to the proposal's top-level devlog.
   A sub-overseer must not run `chat-record`, so proposal top-level devlogs written under `/oversee` lose their `chat_record` entry.
   The cheapest resolution: state that under `/oversee` the arc devlog carries `chat_record`, since all human prompts land at the top anyway.
   A heavier alternative is for the arc overseer to add the entry before dispatching, which avoids a concurrent write to a sub-overseer-owned file.

10. **non-blocking: devlog ownership is sound.**
    The proposal's split (the sub-overseer owns the proposal's top-level devlog and tables, the arc overseer owns the arc file and arc devlog) matches the devlog skill's "Top-level. The lead's devlog" and keeps `part_of` one level deep.
    The `~400K` rotation and `SendMessage` resume are consistent with the rule file, and resume restoring the original spawn depth (2.1.187) means a resumed sub-overseer keeps its budget.
    Parallel sub-overseers rely on the existing footprint serialization, which is adequate.

11. **non-blocking:** the depth-budget sentence ("fits exactly") is correct at the default, and the probe confirms layer 3 is a leaf.
    Pair it with finding 1's fallback so "exactly" does not become "silently collapses" under any other setting.

### Proposed Solution 4: OpenCode

12. **non-blocking**, subsumed by finding 1.
    "Degrades to inline work" is acceptable for OC leaves and not for an OC sub-overseer.
    The Summary's out-of-scope NOTE (that `tools: "*"` maps to all-false in OC) makes this sharper: the OC `implementer`/`reviewer`/`proposer` may be broken independently of nesting.
    Recommend that the rfp named in Phase 3 be filed in Phase 1 instead, so it is not lost if Phase 3 is deferred.

### Test Plan and Verification Methodology

13. **blocking: the structural change has no guaranteed live check.**
    The static checks exercise only the deletions.
    Phase 3 is the only test of sub-overseer dispatch, escalation, and devlog ownership, and the proposal lets it be recorded `deferred-to-followup` without naming how it *would* run.
    "Fresh session that loads the edited plugin" is likely to fail by default.
    The installed plugin is the marketplace cache: `~/.claude/plugins/cache/clauthier/cdocs/0.1.0/agents/judge.md` still has `tools: Read, Glob, Grep, Write`, unlike the repo's `Read, Glob, Grep`.
    A headless run changes the very waiting semantics under test.
    Name a concrete harness.
    For example: `claude -p --plugin-dir plugins/cdocs --permission-mode bypassPermissions` in a scratch worktree, with the arc overseer instructed to dispatch the sub-overseer in the foreground, following the pattern `hooks/tests/chat-record.test.sh` already uses.
    Then check `jq` over the session JSONL and the `subagents/` transcripts:
    - the top-level transcript has exactly one `Agent` call;
    - a layer-1 transcript has the implementer, reviewer, and judge calls;
    - a layer-2 transcript has a `bash-runner` call.

    That last check is what makes "children reach layer 3" observable rather than asserted.
    Permit deferral only for a stated blocker, and file an rfp when deferring.

14. **non-blocking:** add one failure picture for finding 1, so a collapse is caught.
    With nesting disabled (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1`), the sub-overseer returns "no `Agent`" and the arc overseer runs the loop itself.
    If, instead, the proposal devlog shows reviewer output written by the same agent that implemented, the change has failed.
    This is a cheap headless run.

15. **non-blocking:** the static check "generated OC agents differ only in body prose" is good.
    Add the `inside a subagent` grep term from finding 5.

### Important Design Decisions

- **non-blocking.** "No replacement schema", "Leaves stay leaves by `tools:`", and "Keep `--dispatched`" are all well-argued and consistent with the maintainer's preference for minimal designs.
  "Sub-overseers under `/oversee` only" is right: `full-send` sharing one devlog across two sequential loops would gain nothing from a layer.

## Verdict

**Revise.**
The research and the deletion half are accept-quality.
Three scope corrections are needed before implementation:
- the inline-fallback rule must exclude loop leads;
- "Stay thin" must be scoped to loop leads;
- the structural change needs a runnable live check.

All three can be made net-neutral in words.

## Action Items

1. [blocking] In the Nesting text, scope the inline fallback to non-lead roles: a loop lead without `Agent` returns at once and says so, and never plays its children's roles. Add the matching `oversee` fallback (the arc overseer runs the loop itself) and correct the `=1`/OpenCode degradation claims in Edge Cases and Proposed Solution 4.
2. [blocking] Scope "this file applies to it as it does to a top-level overseer": loop leads take the whole file, and other dispatching agents take one writer per file, durable state for writers they start, and the Bash section, and stay the workhorse for their own task. Remove "That includes 'Stay thin'" from the claim that the rest of the file reads correctly.
3. [blocking] Make Phase 3 runnable. Name the harness (`--plugin-dir` headless with foreground dispatch, or an equivalent), and name the transcript `jq` checks showing one top-level dispatch, loop dispatches at layer 1, and a helper dispatch at layer 2. Allow `deferred-to-followup` only with a stated blocker and an rfp.
4. [non-blocking] Move the escalation and steering sentences into the Composition contract's Down line (the sub-overseer's channel), and note that a returned question waits for the sub-overseer's live children.
5. [non-blocking] List all four `ablate` sites (lines 28, 165, 178, 275-279) in the edit table, and add `inside a subagent` to the Test Plan grep.
6. [non-blocking] Reword the reviewer-delegation rationale: the boundary is prose (the reviewer already has `Bash`), and the hook adds `Edit`/`Write` binding that children do not inherit.
7. [non-blocking] State where `chat_record` lives under `/oversee` (the arc devlog), and correct "`chat-record` is unaffected".
8. [non-blocking] Trim the Nesting section's examples sentence to offset the scope fixes, and keep the `wc -w` gate.
9. [non-blocking] Consider updating `triage/SKILL.md`'s "Top-level agent" column to "loop lead" alongside the `iterate`/`propose-revise` role lines.
10. [non-blocking] Cite CHANGELOG 2.1.187's "resumed subagents now restore their original spawn depth" in Background, and note the 2.1.217 default flip as the reason the fallback in item 1 matters.
11. [non-blocking] File the OC `tools: "*"` rfp in Phase 1, not Phase 3.
12. [non-blocking] Add the nesting-disabled failure picture (finding 14) to Verification Methodology.

## Questions for the Author

1. When a sub-overseer cannot dispatch, which behavior should apply?
   - (a) The arc overseer runs the loop itself (today's behavior; recommended).
   - (b) The arc halts as a hard gate.
   - (c) An advisory-only run.
2. Where should `chat_record` live for proposals driven by `/oversee`?
   - (a) Only on the arc devlog (recommended).
   - (b) The arc overseer also stamps each proposal's top-level devlog before dispatch.
3. For the Phase 3 harness, which should it be?
   - (a) Headless `--plugin-dir` with foreground dispatch and transcript `jq` checks (cheap, automatable).
   - (b) A tmux-driven interactive session (faithful to the real waiting semantics, more setup).
   - (c) Both: (a) as the floor, (b) as a follow-up.
