---
review_of: cdocs/proposals/2026-09-22-chat-record-devlog-management.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-23T10:57:41-07:00
task_list: meta/chat-record-devlog-management
type: review
state: live
status: done
tags: [fresh_agent, hooks, chat_record, stop_hook, scope_creep, evidence_genre, regression_check]
---

# Review: Chat Record, Scratchpoint, and Semantic Devlog Splitting (round 3)

> BLUF(opus-4-8/chat-record-review-r3): **Revise** (two blocking scope-reduction items; the core round-3 work is sound).
> The bullet-block redesign this round exists to deliver is correct and I would accept it on its own: the convention is specified as precisely as the devlog-bullet discipline it extends, the `files=`/`p=` mechanical-vs-agent split is unambiguous, the block-then-placeholder fallback is bounded by `stop_hook_active` (verified reproducibly in run 8) and cannot hang, the chat-record/Scratchpoint complementarity is now argued by shape rather than asserted, and the reversal left no stale verbatim-capture text in the live spec.
> What blocks acceptance is scope creep in the round-3 revision's *other* change: it invented a `_verify/`/`_judge/` evidence "genre" plus a separate `## Evidence` index list, and smuggled in `_judge/` which was never requested.
> Per maintainer direction (2026-09-23): `_judge/` is rejected outright, and the `_verify/` directory and `## Evidence` list must be removed. Reproducible evidence belongs in the devlog's **existing `## Verification` section** (which predates this proposal, template.md:27, SKILL.md:71-90); when it outgrows the root, it splits as a standard closed-concern chunk (`-verification`/`-canary`, `part_of`, backlink NOTE, `## Chunks` row) using the very chunking mechanism this proposal is already building. No new devlog-adjacent genre.
> This is a bounded removal-and-relocation using machinery the proposal already defines: warm reviser, one pass, no core redesign.

## Summary Assessment

The proposal operationalizes the chat-record report into three single-writer artifacts (hook-written chat record, agent-written Scratchpoint, semantically split devlog chunks) on a phased, canary-gated rollout.
This round evaluates the post-acceptance reopening at commit `082df8c`, which (a) reversed agent-turn capture from `Stop`-captured verbatim text to agent-authored bullet blocks, and (b) reworked evidence-file discoverability.
Change (a) is done well and I validated it in detail below.
Change (b) overshot: the proposal's own Objective is chat-record plus devlog *chunking*, not the invention of new devlog-adjacent artifact genres, and the round-3 revision added exactly that. The correct, lower-complexity fix is to route evidence through the devlog `## Verification` section that already exists and to chunk it with the standard mechanism if it grows.
Verdict: **Revise.** The two blocking items are both content-removal/relocation, not design reopenings; the bullet-block and fallback work must be kept intact.

## Independent Verification of the Round-3 Changes

I formed my own judgment on the new content first, then read rounds 1 and 2 only to confirm continuity.

### 1. Agent bullet blocks, and the `files=`/`p=` split — sound

**Bullet convention is adequately specified; one small ambiguity.**
The shape is pinned (`- <verb> <object>[: <why or outcome>]`, one per action item, under ~120 chars), with concrete examples and explicit negative space (no reasoning, tool output, file contents, or user-facing reply).
Two agents would produce similarly *shaped* entries; count still varies with each author's "action item" granularity, but that variance matches the devlog-bullet discipline the system already relies on, and the length cap plus negative-space rules bound verbosity.
The one genuine inconsistency is between the sample read-bullet (`- read hooks.json, inject-rules.ts: copying the SessionStart emit shape`) and the routing rule "Reads that matter for a successor go in the Scratchpoint's `files:` gist list, not in extra bullets." The resolution is coherent (a read that *is* the turn's action earns a bullet; a read whose value is durable awareness goes to the Scratchpoint) but left implicit. Non-blocking; action item 4.

**The mechanical split is unambiguous.**
Header metadata (`timestamp`, `p=` from the `UserPromptSubmit`-stashed prompt id, `files=` from the `PostToolUse` turn buffer) is script-attached; the body bullets are the only thing the agent types. Ordering works: `note` runs as the turn's last action while the buffer is still populated, and `Stop` clears the buffer afterward.

### 2. The forgot-a-bullet fallback (block, then placeholder) — sound and bounded

The `decision: block` fires only while `stop_hook_active=false`; the harness re-fires `Stop` with `stop_hook_active=true`, on which the hook stands down and appends a `gap=1` placeholder instead of blocking again, so the loop guard bounds the detour to one extra short turn. It cannot hang.
Run 8 documents this reproducibly in the `_verify` artifact (recorder, `settings.json`, exact command, both canary-log lines, the model complying, three turns total), meeting the reproducibility bar round 1 demanded. The run correctly canaries the *mechanism* with a marker-file proxy and defers real bullet-detection to the Phase-1 tests, which is the right split at proposal stage.
Degradation is safe (never blocks under `CDOCS_CHAT_RECORD=off`, missing `jq`, or an unlocatable record). A tool-only turn (Bash/Agent) still owes a bullet via the `acted` mark.

**`stop_hook_active` is the right signal, with one robustness caveat (non-blocking).**
It distinguishes a retry-after-block from a cold stop, exactly what the one-reminder guarantee needs, and no unrelated repeat-stop scenario sets it. The caveat: `stop_hook_active` is loop-global, not chat-record-specific. If a project adds its own blocking `Stop` hook, chat-record could see `stop_hook_active=true` on its first encounter with a turn and skip straight to a `gap=1` placeholder without ever issuing its reminder. Worst case is a soft false signal in the staleness count, never a hang, and cdocs ships no other `Stop` hook (confirmed: `hooks.json` wires only `PostToolUse`, `PreToolUse`, `SessionStart`). Action item 5.

### 3. Scratchpoint / chat-record complementarity — load-bearing and correct

Stated in the BLUF, Decision 5/10, and most fully in the Scratchpoint section: the chat record is an append-only chronological action log; the Scratchpoint is a bounded replace-in-place snapshot, with reader guidance (Scratchpoint first, last few bullet blocks second). This is a real structural difference, not a granularity difference, and it resolves the round-1 duplication worry correctly. The one parallel surface (files-touched lists) is pre-empted: mechanical exhaustive `files=` ("which") vs. judgment `files:` gist ("why"). A future reader is unlikely to re-raise "aren't these redundant."

### 4. `_verify/`/`_judge/` genre and `## Evidence` list — BLOCKING scope creep, remove

This is the change that blocks acceptance, on two counts.

**(4a) `_judge/` was never requested — remove every reference.**
The round-3 revision introduced a `_judge/` genre in passing ("kept as its own genre (with `_judge/`)") though nothing asked for it. Maintainer (2026-09-23): "why add judge, why keep verify? Former we're not doing, that's excessive." No new namespace for judge-related artifacts, full stop.
References to strike (`_judge/` genre only): the `### Evidence files: _verify/ and _judge/ are a genre` heading; "long judge rationales ... the existing `cdocs/devlogs/_verify/` and `cdocs/devlogs/_judge/` subdirectories"; "every `_verify/` or `_judge/` file carries `part_of:`"; Phase-1 deliverable 6's "`_verify/` and `_judge/` files"; Phase-2 deliverable 4's "`_verify/`/`_judge/` evidence files".
Keep, do not confuse with the above: Phase-2 deliverable 4's separate clause "`agents/judge.md` gains the Scratchpoint-staleness and chat-record-gap conditions for `overseer_thinness: signal_missing`" is the judge *agent* reading the staleness signal, which is in-scope and core to the design. Only the `_judge/` *directory/genre* goes.

**(4b) The `_verify/` directory and the separate `## Evidence` list exceed this proposal's scope — replace with the existing Verification section plus standard chunking.**
Maintainer (2026-09-23): "the goal here was not to redesign the devlog methodology, it was to chunk it. Classically devlog sections were already a place for tracking evidence/verification results." I verified this: the devlog template already carries a `## Verification` section (template.md:27) and the devlog SKILL documents it as the home for exactly this ("Fresh evidence of completion. No completion claims without pasted evidence," SKILL.md:49, 71-90), entirely predating this proposal. Introducing a separate `_verify/` genre and a separate `## Evidence` index reinvents that, and it is precisely the "is this in scope" question round 1 raised reactively when it coined `_verify/`.
The correct fix, which is strictly less machinery and reuses what this proposal is already building: reproducible canary evidence lives in the owning devlog's `## Verification` section; if that section outgrows the root file (the exact bloat the chunking mechanism exists to handle), it splits into a standard closed-concern chunk (e.g. `-verification` or `-canary`) with the same `-<concern>` naming, `part_of` frontmatter, backlink NOTE, and a `## Chunks` row already designed for any other split. Note `part_of` and the backlink NOTE survive: they are the standard chunk convention, not evidence-genre machinery. What goes away is the top-level `_verify/` directory concept and the separate `## Evidence` list type.
Concretely for this workstream's own artifact: the ~400-line canary at `cdocs/devlogs/_verify/2026-09-22-chat-record-hook-canary.md` should be relocated to a normal chunk of the loop devlog (e.g. `cdocs/devlogs/2026-09-22-chat-record-devlog-management-canary.md`, `status: done`, `part_of`, backlink NOTE), added as a `## Chunks` row, and the loop devlog's `## Evidence` section removed (its one entry becomes the chunk row).

Every proposal reference to update for (4b), so the round-4 reviser need not hunt:
- The whole `### Evidence files: _verify/ and _judge/ are a genre` subsection: delete; replace with a short paragraph "evidence lives in the devlog `## Verification` section; chunk it via the standard mechanism if it grows large."
- BLUF: the `[_verify/2026-09-22-chat-record-hook-canary.md]` link retargets to the canary chunk.
- `agent_id`-guard invariant: "reproduced in the `_verify` artifact" retargets to the canary chunk.
- "Where to cut" edge: "instead move bulky pasted evidence to `cdocs/devlogs/_verify/` as the repo already does" becomes "keep it in the Verification section, and split that section as a chunk if it grows."
- Harness-prompt edge case: "(see the `_verify` artifact)" retargets to the canary chunk.
- "Devlog with no closed concern at 20KB" edge: "move evidence to `_verify/`" becomes "move evidence into a Verification chunk via the standard split."
- Phase-0 section: the `[cdocs/devlogs/_verify/...canary.md]` pointer retargets to the canary chunk.
- Phase-1 deliverable 6: drop "the `## Evidence` list and the `part_of`-plus-backlink rule for `_verify/` and `_judge/` files"; replace with "the `## Verification` section is the evidence home, split as a standard chunk when large."
- Phase-2 deliverable 4: drop "for `_verify/`/`_judge/` evidence files" and "flag an evidence file whose owning devlog lacks a matching `## Evidence` line" (the standard `part_of`/`## Chunks` grouping already covers a verification chunk); keep the `part_of`-for-chunks and the `agents/judge.md` staleness clause.

## Standard Review Scope

**Frontmatter and writing conventions.** Compliant. Proposal frontmatter valid per spec (`type: proposal`, `state: live`, `status: review_ready`, `last_reviewed` accepted round 2). No em-dashes; BLUF present; external issues linked; sentence-per-line largely followed.

**Implementation Phases remain concrete and executable for the bullet redesign.** Phase 1 absorbed the reversal correctly (the `note` entry mode, the widened `PostToolUse` matcher with `acted`-mark semantics, the `Stop` block/placeholder row as the only `decision: block` event). The phases are executable once the (4a)/(4b) evidence-genre text is removed; the deliverables that reference `_verify/`/`_judge/`/`## Evidence` (Phase-1 #6, Phase-2 #4) are the ones needing the rewrite above.

**Test Plan covers the new mechanisms.** The bullet happy path, the block-then-placeholder path (two `Stop` events, `gap=1` placeholder, `last_assistant_message` nowhere), the no-work path, and `NotebookEdit` are all asserted. Good coverage of the new surface; unaffected by the scope reduction. One addition worth making (action item 6): assert that a parent turn whose only action is an `Agent` dispatch gets the `acted` mark and owes a bullet.

**Regression check — round-1/round-2 accepted content intact.** Grammar/escaping (single `HEADER_RE`), the `agent_id` guard, the closed-concern split test, the three-arm Phase-2 A/B, and the Phase-3 per-workstream sketch are all unchanged and consistent with the bullet design. No stale verbatim-capture residue survives: every remaining `last_assistant_message` mention is the reversal NOTE, a "never written" invariant, the rejected-fallback rationale, a factual Phase-0 payload row annotated "not used by this design", or the Phase-3 `@return` sketch that flags itself as the sole hook-captured-content exception. The reversal is clean.

## Verdict

**Revise.**
Two blocking items, both scope reductions, neither reopening the core design:

1. Remove `_judge/` entirely (never requested).
2. Remove the `_verify/` directory concept and the separate `## Evidence` list; route reproducible evidence through the devlog's existing `## Verification` section, and split it as a standard closed-concern chunk (`part_of` + backlink + `## Chunks`) if it grows, relocating this workstream's own canary artifact accordingly.

The bullet-block redesign, the block-then-placeholder fallback (verified via run 8), and the complementarity restatement are sound and must be preserved unchanged. Route to the same warm proposer; this is a one-pass removal-and-relocation, not a rewrite. `last_reviewed` is set to `revision_requested`, round 3; `status` stays `review_ready`.

## Action Items

1. [blocking] Remove every `_judge/` reference (the genre only, not the `agents/judge.md` staleness update): the `### Evidence files` heading, the "long judge rationales" / "`_judge/` subdirectories" sentence, the `_verify/`-or-`_judge/` `part_of` rule, and the `_verify/`/`_judge/` mentions in Phase-1 deliverable 6 and Phase-2 deliverable 4. See finding 4a for the exact list.
2. [blocking] Delete the `### Evidence files: _verify/ and _judge/ are a genre` subsection and the separate `## Evidence` list; replace with "evidence lives in the devlog `## Verification` section (which already exists), chunked via the standard `-<concern>`/`part_of`/`## Chunks` mechanism if it grows large." Keep `part_of` and the backlink NOTE as the standard chunk convention. Retarget the eight cross-references enumerated in finding 4b (BLUF, `agent_id`-guard invariant, two split-edge cases, Phase-0 pointer, Phase-1 #6, Phase-2 #4).
3. [blocking] Relocate this workstream's own evidence out of `cdocs/devlogs/_verify/`: move `2026-09-22-chat-record-hook-canary.md` to a standard loop-devlog chunk (e.g. `cdocs/devlogs/2026-09-22-chat-record-devlog-management-canary.md`, `status: done`, `part_of`, backlink NOTE), add it as a `## Chunks` row in the loop devlog, and delete the loop devlog's `## Evidence` section. (This review's own prose references the `_verify` path only descriptively and can stay.)
4. [non-blocking] Disambiguate read-bullet vs. Scratchpoint routing in the "Agent bullet blocks" paragraph (a read earns a bullet when it is the turn's action; a read whose value is durable awareness for a successor goes to the Scratchpoint `files:` gist only).
5. [non-blocking] Note that the one-reminder guarantee assumes chat-record's `Stop` is the only blocking `Stop` hook (`stop_hook_active` is loop-global); optionally harden Phase 1 with a per-turn `p=`-keyed "blocked once" marker (as run 8's canary used `CANARY_MARK`) instead of trusting `stop_hook_active` alone. Also have the `decision: block` reason interpolate the resolved record path, not the literal `<record>`.
6. [non-blocking] Add a Phase-1 test asserting a parent turn whose only action is an `Agent` dispatch gets the `acted` mark and owes a bullet.
7. [non-blocking, carried from round 2] `NotebookEdit`'s `PostToolUse` firing and `notebook_path` field remain an assumption by analogy; the Phase-1 `NotebookEdit` scenario is what verifies it (already noted in the proposal).

## Questions for the Maintainer

Acceptance already decided (Revise); these refine the round-4 execution.

1. For the relocated canary chunk (action item 3): a dedicated `-canary` chunk (its own file, opened only for payloads), or fold the evidence inline into the loop devlog's `## Verification` section and split only if the root then exceeds the ~12KB trigger? The chunk is ~400 lines, so a dedicated chunk seems right, but inline-then-split is the more literal reading of "chunk it if it grows."
2. Bullet granularity (action item 4): is "a read is a bullet only when it is the turn's action" the intended rule, or should read-only awareness turns never write a bullet (Scratchpoint-only), making the sample read-bullet an annotated exception?
