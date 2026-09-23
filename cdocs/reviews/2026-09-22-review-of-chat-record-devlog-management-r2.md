---
review_of: cdocs/proposals/2026-09-22-chat-record-devlog-management.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-23T08:47:59-07:00
task_list: meta/chat-record-devlog-management
type: review
state: live
status: done
tags: [fresh_agent, rereview_agent, hooks, chat_record, grammar, architecture, test_plan]
---

# Review: Chat Record, Scratchpoint, and Semantic Devlog Splitting (round 2)

> BLUF(opus-4-8/chat-record-devlog-management-review): **Accept.**
> I re-derived the document's claims independently before reading round 1's review, then checked round 1's five blocking items against the current text: all five are genuinely resolved, not merely gestured at.
> The grammar is now unambiguous under a single `HEADER_RE` (I walked `@alice:`, LESS `@brand-color:`, and CSS `@page:` through both the writer's escape test and the reader's split test); the `agent_id` guard is a concrete first-invariant with the Non-Goals scoping resting on the documented field; the `_verify` artifact shows raw per-run evidence rather than asserting it; and the three maintainer-driven additions (three-arm A/B, native-auto-compaction section, per-workstream Phase-3 sketch) are substantive and internally consistent.
> Remaining findings are all non-blocking precision nits; none reopens a design decision and none blocks acceptance.
> The proposal is ready for `status: implementation_ready`.

## Summary Assessment

The proposal operationalizes the chat-record report into three single-writer artifacts (hook-written chat record, agent-written Scratchpoint, semantically split devlog chunks) on a phased, canary-gated rollout.
This is the round-2 read of the revision at commit `8986747`, conducted fresh: I re-derived the grammar, the hook contract, the `_verify` evidence, and the Phase-3 sketch from the current document and cross-checked referenced artifacts on disk, then read round 1's review last to confirm which blocking items it raised.
The quality is high and the revision is disciplined: every round-1 blocking item resolves to concrete spec text, the added sections answer the maintainer's questions with decision rules rather than acknowledgments, and I found no new blocking issue introduced by the large revision pass.
Verdict: **Accept**, with a handful of non-blocking precision nits listed as action items (I am barred from editing the proposal body, so I surface them for the proposer/overseer to fold in).

## Verification of Round-1 Blocking Items

I checked each round-1 blocking item against the current text independently, treating round 1's conclusions as claims to re-verify, not as ground truth.

**(1) Evidence artifact reproducibility.** Resolved.
`cdocs/devlogs/_verify/2026-09-22-chat-record-hook-canary.md` exists and *shows* rather than asserts: per run it carries the recorder script, the `settings.json`, the exact `claude` invocation, the stream-json input (`run2.in`, `run4.in`), the verbatim canary-log lines with real `session_id`s / timestamps / payload fields, and the model's printed result.
From runs 1, 2, 4, 5, 6, and 7 I could reconstruct and re-run the canary as written and expect the same event sequences; the elisions (`<SANDBOX>`, `transcript_path`) do not remove anything load-bearing.
Phase 0 links it, states "seven runs" (the six-vs-seven inconsistency round 1 flagged is gone), and the example record is explicitly labeled "a composite assembled from Phase-0 runs 2, 4, and 7".
Two minor gaps remain (non-blocking, action items 4 and 5): run 3's fixture generator is described ("a seeded Python snippet") but not reproduced, so that one run is not byte-reproducible (the property it tests, auto-compaction firing, is robust to fixture content, so this does not undermine the claim); and the single most load-bearing fact for the whole scoping design, that `PostToolUse` fires inside a subagent with `agent_id` set, lives in round 1's Run A rather than in this artifact (run 7 did not log `agent_id`).

**(2) `agent_id` guard.** Resolved.
It is a concrete implementation detail, not prose: the first Invariant of the hook contract reads "`agent_id` guard, first thing on every event. If the payload carries `agent_id`, exit 0 before any read or write", and Phase-1 deliverable 1 restates "`agent_id` guard first".
The Non-Goals scoping is now consistent with it: the exclusion of subagent chat records "rests on a documented guard rather than on the (also observed) fact that `UserPromptSubmit` does not fire for a subagent's dispatch prompt", exactly the stronger basis round 1 asked for.
The mechanism is sound: the `.turn` buffer is keyed by `session_id`, which a subagent shares with its parent (canary run 5 confirms), so without the guard a subagent's `PostToolUse` reads would land in the parent's buffer and pollute the overseer's `files=`; the guard on `PostToolUse` prevents exactly that.
I did **not** re-run the subagent `PostToolUse`/`agent_id` canary live: per this round's brief the round-1 Run A finding is credible prior verification for this specific fact, the hooks reference documents the behavior, and a live re-run is expensive and flaky. I treat it as verified.
One precision nit (non-blocking, action item 1): the invariant's justifying sentence says "Tool and stop events fire inside dispatched subagents with `agent_id`", but among the seven Phase-1-registered events only `PostToolUse` actually carries `agent_id` in practice. Plain `Stop` fires with `agent_id: null` (run 5); a subagent's turn-end is `SubagentStop`, which is not registered in Phase 1. The guard-on-all-events is correct defensively, but the "stop events" phrasing conflates `Stop` and `SubagentStop`.

**(3) Grammar fix.** Resolved, and I verified it concretely rather than trusting the prose.
`HEADER_RE := ^@[A-Za-z0-9][A-Za-z0-9._-]*:` is stated as "the ONE pattern both writer and reader use". Walking round 1's named adversarial cases:

- `@alice: hey` (plain body text): `@alice:` matches `HEADER_RE`. The writer escapes any body line matching `^\*HEADER_RE` with one backslash to `\@alice: hey`; the reader strips one backslash from any line matching `^\+HEADER_RE`. Round-trips, and the reader does not mis-split there because a real header must match `HEADER_RE` with no preceding backslash. Correct.
- LESS `@brand-color: #333;`: `brand-color` is `[A-Za-z0-9][A-Za-z0-9._-]*` (hyphen allowed), so `@brand-color:` matches and is escaped. Correct.
- CSS `@page:first {`: `@page:` matches and is escaped. Correct.

The escape/unescape is a bijection even under stacked backslashes (a pasted `\@user:` writes as `\\@user:` and reads back to `\@user:`), because both sides key off the same `HEADER_RE` core with `^\*` (writer) / `^\+` (reader) prefixes.
Quoted-value escapes are now pinned to exactly four (`\\`, `\"`, `\n`, `\r`), CRLF is normalized before the escape pass, and the file is located by `*-<sid8>.md` glob with a full `sid=` on the start line plus a full-id-filename fallback on prefix collision. The single-pattern requirement round 1 raised is met.

**(4) Commit-by-default exposure.** Resolved.
The `WARN` now names all three leak channels (human pastes, `@<model>` assistant bodies, `@compact` summaries), the commit protocol is specified (overseer stages by explicit path at handoff in a devlog-class bookkeeping commit; dispatched agents never stage `cdocs/_chat/`, with no `git add -A` / `git commit -a` sweep), the Pillar-1 carve-out sentence is present, and the redaction stance is stated per maintainer decision (none in-hook, exposure accepted, general redaction deferred to `2026-09-23-chat-record-redaction-scanning-rfp.md`, which exists on disk). `CDOCS_CHAT_RECORD=off` and `.gitignore` opt-outs are documented.

**(5) Closed-concern definition.** Resolved.
The three-part closure test is concrete and decidable (own H2/H3 heading; every naming Open Todo done-or-moved; no live root table still receiving its rows), the "move every closed concern, one chunk each, ~3KB merge" rule answers the one-vs-many question, shared-table rows move with their producing concern or stay in the root if shared, and chunks carry `status: done`. Two agents applying this test would split identically, which is what makes the Phase-2 dry-run scoreable.

## Section-by-Section Findings (new material this round)

### Three-arm Phase-2 A/B and "Relationship to native auto-compaction"

Both are substantive, not box-checking.
The A/B has three concrete arms (carry-indefinitely from the native summary; steered `/compact` then resume from Scratchpoint + handoff + chat-record tail; `/clear` then reseed from the same durable state with no summary), a scoring rubric ("correct next action, no re-litigated decision, no re-read of already-read files"), a pass condition (arm 2 wins-or-ties arm 1 on all three workstreams), and a decision rule that wires arm 3's outcome to `/cdocs:compact`'s behavior (if arm 3 ties arm 2, print `/clear` plus a resume pointer instead of a steering string). It is modeled on the cited Factory.ai eval.
The native-auto-compaction section correctly answers the maintainer's strategic question: **no**, the system does not obviate native auto-compaction for the top-level session (no agent-invokable compaction; AFK/headless have no typist; growth is not agent-controlled), **yes** for durable specialists (the sawtooth reset is replaced by dispatch-level cap-and-reseed). Its empirical citation checks out: run 3 in the `_verify` artifact shows four compactions between 18:21:13 and 18:24:08, i.e. "four times in three minutes under a 100K window". [non-blocking: sound as written.]

### Phase-3 per-workstream sketch

The mechanics hang together and single-writer is preserved.
The key is `task_list`, resolved from the active devlog's frontmatter via the same `<session_id>.devlog` tier-1 pointer Phase 1 already ships; the hook appends `@session ... workstream ws=<task_list>` and the workstream record is the `grep -l 'ws=<task_list>'` set (covers next-day sessions, merges across worktrees because each session file is distinct); files are not relocated (glob stability), which is a good reason correctly stated; legs' chronology lands in the parent's file as `@dispatch`/`@return` blocks from `SubagentStart`/`SubagentStop`, with per-agent `files=` from `agent_id`-keyed buffers; the hook remains the only writer.
The two flagged-unverified mechanics are correctly scoped as gating canaries, not silently assumed: item (b) `SendMessage`-resume re-firing `SubagentStart`/`SubagentStop` under the same `agent_id`, and item (c) `PreToolUse` on `Agent` exposing `tool_input.prompt`, both appear in the Phase-3 gating list and in the success criteria ("canary items (b) and (c) have answers recorded before any implementation of item 3 begins"). This is the right treatment for a design sketch that is explicitly not built now.
One under-specification worth folding into gating canary (c) (non-blocking, action item 3): the `@dispatch` body wants the dispatch prompt, but `PreToolUse` on `Agent` delivers `tool_input.prompt` with no `agent_id`, while `SubagentStart` delivers `agent_id` with (per canary run 5's key list) neither the prompt nor `agent_transcript_path` (that field is only on `SubagentStop`). So the stated fallback "or from the first user message of `agent_transcript_path`" is not available at `SubagentStart` time, and correlating the `PreToolUse` prompt to the later `SubagentStart` `agent_id` is an unspecified step (likely by tool-use id or dispatch ordering). The sketch is sound enough as a Phase-3 investigation item; the canary should just also answer "how is the `PreToolUse` prompt correlated to its `SubagentStart`".

### Frontmatter, cross-references, and writing conventions

Frontmatter is valid per spec: `type: proposal`, `state: live`, `status: review_ready`, `last_reviewed` at round 1, well-formed `first_authored`. Tags are focused.
No em-dashes or bare ` -- ` in the body (convention compliant); BLUF present; external issues linked with URLs on first mention; sentence-per-line largely followed.
Every cross-referenced artifact resolves: the four background reports, the redaction RFP, the autoflush RFP (`cdocs/proposals/2026-09-01-devlog-autoflush-hook.md`, linked relatively and correctly, `type: proposal` so `status: evolved` in Phase-1 deliverable 8 is valid), the two split-dry-run devlogs (19257B and 17121B on disk, matching the "19KB"/"17KB" claims), the `2026-09-01-overseer-alignment-phase{1..4}` naming precedent, and the existing hooks. The `part_of` field is correctly introduced as a proposed Phase-2 addition, not assumed to already exist in the spec.

### New issues introduced by the revision

None blocking. The revision grew the document substantially (round 1 notes 46.5KB to 64.7KB) without introducing internal contradictions I could find. The only new-material precision nits are those in action items 1 and 3, plus one artifact-completeness item (fold round-1 Run A's raw log into the `_verify` file so the guard-justifying evidence is co-located) and one test-coverage nit (`NotebookEdit`'s `PostToolUse` firing is assumed by analogy to `Edit`/`Write`; the canary and the Phase-1 test list exercise `Read`/`Edit`/`Write` but not `NotebookEdit`).

## Verdict

**Accept.**
All five round-1 blocking items are resolved in concrete spec text, verified independently rather than by trusting round 1's review. The three maintainer-driven additions are substantive and consistent. The remaining findings are non-blocking precision and completeness nits that do not reopen any design decision.
Recommend advancing the proposal to `status: implementation_ready`. The `last_reviewed` frontmatter is updated to `accepted`, round 2.

## Action Items

All non-blocking. I am constrained to editing only the proposal's `last_reviewed` frontmatter, so these are surfaced for the proposer or a `/cdocs:nit_fix` pass to fold in; none gates acceptance.

1. [non-blocking] In the hook-contract `agent_id`-guard invariant, tighten "Tool and stop events fire inside dispatched subagents with `agent_id`": among Phase-1-registered events only `PostToolUse` carries `agent_id` in practice (plain `Stop` is `agent_id: null` per run 5; the subagent turn-end is the unregistered `SubagentStop`). State the guard as defensive-on-all-events with `PostToolUse` as the load-bearing case.
2. [non-blocking] Fold round-1 Run A's raw `agent_id`-in-subagent canary log into `cdocs/devlogs/_verify/2026-09-22-chat-record-hook-canary.md` (currently run 7 defers to the review), so the single most load-bearing scoping fact is co-located with the rest of the reproducible record.
3. [non-blocking] In the Phase-3 sketch, add the `PreToolUse`-to-`SubagentStart` correlation question to gating canary (c): `PreToolUse` on `Agent` gives the prompt but no `agent_id`; `SubagentStart` gives `agent_id` but neither the prompt nor `agent_transcript_path` (only `SubagentStop` carries the transcript path). The `@dispatch`-body fallback via `agent_transcript_path` is therefore unavailable at `SubagentStart` time, and the correlation step is unspecified.
4. [non-blocking] In the `_verify` artifact, include the run-3 fixture generator (the "seeded Python snippet") or note explicitly that the fixture content is not load-bearing for the auto-compaction claim, so the run is either byte-reproducible or documented as content-agnostic.
5. [non-blocking] Add a `NotebookEdit` scenario to the Phase-1 hook tests (or a one-line note that its `PostToolUse` firing is assumed by analogy to `Edit`/`Write` and canaried transitively), since the matcher includes `NotebookEdit` but neither the canary nor the test list exercises it.

## Questions for the Maintainer

Acceptance does not depend on these; they are optional refinements the maintainer may weigh for the implementation phase.

1. Evidence co-location (action item 2): fold Run A's raw log into the `_verify` artifact now, or leave the `agent_id`-in-subagent evidence in the round-1 review with a pointer? The design's own Verification Methodology principle ("a failing assertion shows the actual shape") argues for co-location, but the pointer is defensible since the fact is also platform-documented.
2. Phase-3 `@dispatch` sourcing (action item 3): should the Phase-3 canary settle the `PreToolUse`-prompt-to-`SubagentStart` correlation before the sketch commits to `PreToolUse` as the prompt source, or is the `agent_transcript_path`-at-`SubagentStop` route (prompt recovered lazily at return time) the intended primary, with `PreToolUse` as an optimization?
