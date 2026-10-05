---
review_of: cdocs/proposals/2026-09-22-chat-record-devlog-management.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T10:25:07-07:00
task_list: meta/chat-record-devlog-management
type: review
state: live
status: done
tags: [fresh_agent, timeless_rewrite, document_weight, grammar, test_plan, supplemental_report]
---

# Review: Chat Record, Scratchpoint, and Semantic Devlog Splitting (round 8)

> BLUF(opus-5-5/chat-record-devlog-management): Both r7 blockers are resolved: Decision 13 now gives the true cost of the `if`-scoped `PreToolUse` guard and names it as the fallback (run R8 confirms `if` is honored on 2.1.289), and the timeless rewrite takes the document from 90KB to 41KB with one place per fact and a three-row `Stop` table that matches the interrupt and suppression rules.
> Spot-checking against `62febaa` found nothing an implementer needs that was lost; what moved is history and evidence, now in a well-formed supplemental report.
> One grammar inconsistency remains (a conditional ` p=` suffix on the sign-off that `SIGNOFF_RE` rejects), along with a weak test assertion and a few report nits; all are non-blocking and small enough to fold in at implementation.
> **Verdict: Accept.**

## Summary Assessment

The proposal specifies a per-session chat record (two hooks, one `bin/chat-record` script, a Pillar 2 rule, one init permission rule), a rolling devlog Scratchpoint, and devlog splitting at closed-concern boundaries, delivered in three phases (Phase 3 gated).
Round 8 made no design change, as r7 asked: it corrected Decision 13, fixed the `Stop` table contradiction, and moved history, rejected approaches, and Phase-0 evidence into [`2026-10-05-chat-record-design-history.md`](../reports/2026-10-05-chat-record-design-history.md).
The result reads as one present-tense contract, and Phases 1-2 can be implemented from it alone.
The remaining findings are one sentence-level grammar fix and test and report polish. **Accept.**

## Verification performed

- Size 41,105 bytes. The largest sections are Test Plan (5.6K), Format (4.7K), Script (4.1K), Decisions (2.7K), and Phase 1 (2.5K), all in proportion to what they specify.
  No section is still carrying bulk that doesn't earn its keep.
- Timelessness grep (`round|r[0-9]|R[0-9]|run [0-9]|today|previously|no longer|was|were|maintainer`): the remaining hits are evidence citations (`history report, run R7`, `verified on 2.1.289, run R8`), one illustrative gist bullet (`reviewer r5 returned revise`), the WARN's `Maintainer decision`, the intentional subagent NOTE, and "today only `AGENTS.md` inlines it" (a true statement about the pre-implementation codebase).
  No passage narrates rounds or dates.
- Old-versus-new content diff (`git show 62febaa:...`) covered Location, Block grammar, Script contract, Compaction, Edge Cases, and Test Plan.
  Every contract rule survives in one place.
  The dropped edge cases either restate guards that now live in "Guards and invariants" (`CDOCS_CHAT_RECORD=off`, session id absent, `jq` missing, not a cdocs project, note twice, ignored block) or carry no design content ("two sessions on one checkout", "very large prompts: no cap").
  Two small details did not carry over (see Finding 4).
- Repo facts: `plugins/cdocs/agents/` holds exactly the seven files deliverable 7 names; `plugins/cdocs/bin/` does not exist yet; `/cdocs:init` step 3 writes `.claude/rules/cdocs.md` with "core conventions", which agrees with deliverable 3's claim that Pillar 2 is inlined only into `AGENTS.md` today.
  `hooks.json` already registers `SessionStart`, `PreToolUse` (Write|Edit), and `PostToolUse`. The fallback `PreToolUse` entry would sit alongside the existing one.
- Devlog `## Round 8` run R8 is consistent with the report's R8 entry and the proposal's citation.
  The fork arm was not exercisable ("Agent type 'fork' not found"), and the proposal handles that correctly: the arm runs "where the installed version offers" forks, and the fork question is listed as owned by Phase 1.

## Section-by-Section Findings

### 1. r7 blockers: resolved.

- **Decision 13 / Top-level only.** The cost is stated correctly (one `hooks.json` entry, about one spawn per turn), backed by R8. The only reason for holding the guard back is the two-hook surface. The fallback is concrete JSON with an exact trigger: it ships before Phase 1 closes if the top-level-only scenario leaks.
  The section is short and self-contained, and its NOTE flags the open subagent-notes question without blocking on it, as the maintainer intends.
  Forks are named in the rule text ("including as a fork") and in the test.
- **Weight and contradiction.** The `Stop` table has three rows (sign-off / block / suppressed block that writes the sign-off). It agrees with the layer map's `alt` branch, the interrupted-turn edge case, and the `stop_hook_active` invariant.
  Decisions are one or two sentences of rationale each, and Edge Cases keep only cases the contract does not already answer.
- All six r7 non-blocking items landed: concrete `SIGNOFF_RE`, empty title falls back to sid8, explicit parse order, mid-turn consequence, layer-map participant split, stale lines moved out, scenario renamed, and an awk reference splitter.

### 2. Sign-off grammar versus the mid-turn edge case. Non-blocking (fold in at implementation).

Edge Cases, "Prompt typed mid-turn": "the sign-off gains a trailing ` p=<pid8>`".
`SIGNOFF_RE` ends at the timestamp with `$`, and the `signoff` production has no `p=`.
If check (e) shows mid-turn firing, the reader would classify such a line as body, and the writer's escape pass would never escape a pasted body line of that shape. Records written before the regex changes would then misparse.
The cheap, timeless fix is to make the suffix part of the grammar now, optional for writers until (e) decides:

```
SIGNOFF_RE := ^-- [A-Za-z0-9._-]+ at <ts-regex>( p=[0-9a-f]{8})?$
signoff    := "-- " session " at " timestamp (" p=" pid8)?
```

Then the edge case only decides whether the writer emits the suffix, and readers and escapes stay stable.
Simpler still: always emit `p=` on the sign-off. It costs 11 bytes, makes correlation position-independent in every case, and removes the conditional. That is a maintainer-visible format choice, though (see Questions).

### 3. Script section. Non-blocking.

- "One append path ... interleaves at line granularity": the preceding clause says one `printf` per whole block, so the claim is block granularity for writes under the pipe or stdio buffer, and unspecified for very large verbatim prompts that bash may split across `write()` calls.
  In practice the writers are sequential within a turn (`UserPromptSubmit`, then `note`, then `Stop`). The only real overlap is a harness or mid-turn `UserPromptSubmit`.
  Suggest: "each block is one `printf` to an `O_APPEND` descriptor; writers within a turn are sequential, so interleaving needs a concurrent prompt event and is at worst between blocks for normal sizes."
- Edge Cases, "`Stop` without a matching `@user` (hook enabled mid-session)": this blocks only if a record file already exists, because "no record file" is a silent exit.
  Add "and the record exists" so the two passages do not appear to disagree.
- Phase 1 constraints say to "register no hook beyond `UserPromptSubmit` and `Stop`", but the plugin already registers three other hook events. Write "register no new hook event beyond ...".

### 4. Content carried over from the old proposal. Non-blocking.

Two small details were lost in the trim:

- The old rules check also asserted that "the post-compaction context must contain the Pillar 2 boundary text". The new one checks only the init file statically plus the first tool calls.
  The tool-call assertion implies it, so this is optional.
- The note that harness classification is an allowlist "to avoid mislabeling humans" (not "starts with `<`") survives only implicitly in "anything else (including pasted HTML) is `@user`".
  That is sufficient.

Nothing else an implementer needs was lost.

### 5. Test Plan. Non-blocking.

- Top-level-only scenario: "no entry with a non-top-level speaker" cannot be asserted reliably. A subagent's `note --as` would write its own model name, which can equal the top-level's (both haiku in the sandbox), so speaker tells you nothing about who wrote the entry.
  The discriminating assertion, which is already present, is that the top-level's first `Stop` still blocks.
  Replace the speaker clause with "the record holds no entry with the turn's `p=` before the top-level's first `Stop` block", or have the stub `PreToolUse` logger (R8's shape) record any `chat-record` call with a non-null `agent_id`, which is exact.
- The rest is concrete: every scenario is setup -> assertion on the record and the hook-event stream, the payload-shape guard catches field renames, and the unit fixture covers each escape case.
- Phase 2 is adequate. The A/B has a pass bar and a decision rule for arm 3, the dry-run names its devlogs and its one-chunk bar, and the `part_of` grouping is testable.

### 6. Supplemental report. Non-blocking.

The frontmatter is valid (`type: report`, `state: live`, `status: review_ready`, tags). The BLUF states the report's role and that the proposal alone is enough to implement. The three tables (evolution, rejected approaches, evidence) are the right shape, and the canary recorder is preserved.
Nits:

- `first_authored.at: 2026-10-05T10:30:00-07:00` is later than this review's real time (10:25). It looks rounded or guessed. Set it to the real commit time (984b636).
- The Platform Evidence row for the subagent environment says "Relied on for: Decision 13: no mechanical subagent guard". Decision 13 now names a mechanical fallback, so the row should read "the rule-text guard, since no environment signal separates subagents (`agent_id` reaches only hooks)".
- "This revision's session" appears in two rows. In a multi-round history that is ambiguous, so name the round (6 or 7).
- The evolution table skips round 2, an accept with nit fold-in. Add a one-line row, or label round 1 as "1-2", so "eight review rounds" adds up.

## Verdict

**Accept.**
Both r7 blockers are resolved without design drift. The proposal is timeless, one place per fact, and implementable for Phases 1-2. The supplemental report holds the history and evidence a re-litigator needs.
Findings 2-6 are small and are best folded in by the implementer at Phase 1 start, or by a quick nit pass. Finding 2 is the one to handle before the grammar unit test is written.

## Action Items

1. [non-blocking, do before writing the grammar test] Make `SIGNOFF_RE` and the `signoff` production accept an optional ` p=[0-9a-f]{8}` suffix, so the mid-turn edge case changes only writer behavior (or always emit it, per the maintainer's choice below).
2. [non-blocking] Top-level-only test: replace "no entry with a non-top-level speaker" with a `p=`/ordering assertion, or with a logged `agent_id` on any `chat-record` call.
3. [non-blocking] Script: restate the append-granularity claim (block, sequential writers); add "and the record exists" to the "`Stop` without a matching `@user`" edge case; Phase-1 constraint becomes "no new hook event".
4. [non-blocking] Report: correct `first_authored.at`; update the subagent-environment row's "Relied on for"; replace "this revision's session" with the round; account for round 2 in the evolution table.

## Questions / Options for the Maintainer

- **Sign-off correlation.** (a) Grammar allows an optional ` p=`, and the writer emits it only if check (e) shows mid-turn prompts (recommended: keeps the postscript minimal and parsing stable); (b) always emit `-- <session> at <ts> p=<pid8>` (position-independent always, slightly noisier); (c) leave as written and change the regex if (e) fires (risks misparsing records written in between).
