---
review_of: cdocs/proposals/2026-09-22-chat-record-devlog-management.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T10:08:45-07:00
task_list: meta/chat-record-devlog-management
type: review
state: live
status: done
tags: [fresh_agent, document_weight, subagent_scoping, decision_rationale, chat_record, grammar, test_plan]
---

# Review: Chat Record, Scratchpoint, and Semantic Devlog Splitting (round 7)

> BLUF(opus-5-5/chat-record-devlog-management): Both r6 blockers are resolved with evidence (run R7: byte-exact heredoc delivery, no `permission_denials`, identical subagent and top-level environments), and the sign-off line is clean and sound.
> Two blocking items remain, neither a design change: (1) Decision 13 rejects the `PreToolUse` guard on a false cost premise, because the documented hook `if` field (`"if": "Bash(chat-record:*)"`) runs the handler only on `chat-record` calls, not on every Bash call; (2) at 90KB, about 3x its content, the document buries a now-small design under history, duplicated decisions, an evidence ledger, and edge cases that restate the contract, and the duplication has already produced one internal contradiction (the `Stop` table versus the interrupt and suppression rules).
> Target: about 40-45KB for the whole proposal, or about 25KB if Phase 2 and Phase 3 move into their own proposal.
> **Verdict: Revise.** The next round should be a trim plus two sentence-level fixes, with no new design.

## Summary Assessment

The proposal specifies a per-session chat record (two hooks, one `bin/` script, one rule, one init permission rule), a rolling devlog Scratchpoint, and devlog splitting at closed-concern boundaries.
Round 7 closes both r6 blockers correctly: `note` reads its body only from a quoted heredoc on stdin, with run R7 as byte-exact evidence, and "top-level only" is enforced by rule text in Pillar 2 and in all seven agent definitions, backed by a Phase-1 scenario.
The sign-off line `-- <session> at <ts>` fits the maintainer's attribution intent and the grammar handles it with the same escape mechanism as headers.
What remains: Decision 13's stated reason for rejecting a mechanical guard is factually wrong, and the document's weight is now the main obstacle to implementing the small design it describes.

## Verification performed

- Hooks reference (https://code.claude.com/docs/en/hooks.md, "Common fields"): handlers accept `if` in permission-rule syntax, "only evaluated on tool events: `PreToolUse`, ...", and "the hook command only runs if the tool call matches the pattern"; `agent_id` is a common input field "present only when the hook fires inside a subagent call".
  Whether 2.1.289 honors `if` was not checked (the binary's strings were not conclusive); one canary run would settle it.
- Run R7 in the r5 devlog's `## Round 7`: the stub compared stdin with `cmp`, `permission_denials: []`, and env dumps diffed empty between the top-level and the subagent.
  Accepted as sufficient evidence for both claims.
- `plugins/cdocs/agents/` holds exactly the seven files Phase 1 deliverable 7 names.
- `inject-rules.ts` hashes all of `rules/*.md`, so having `/cdocs:init` write Pillar 2 into `.claude/rules/cdocs.md` (deliverable 3) needs no hook change, which agrees with the "do not touch `inject-rules.ts`" constraint.
- Stale-term grep (`@end|--record|SessionStart|PreCompact|PostCompact|qchar|session=|custom_instructions|round N`): hits are only in the history NOTE, Background 10-11, dated decision text, Phase 0, and illustrative bullets (lines 208, 228).
  No design sentence describes removed machinery as current.
- Section sizes (bytes): Block grammar plus gist guidance 9.9K, Test Plan 8.8K, Decisions 8.6K, Script contract 8.4K, Edge Cases 8.1K, Scratchpoint 5.4K, Phase 0 4.6K, Phase 1 4.7K, Location 4.5K, Background 4.2K, Summary 3.5K.

## Section-by-Section Findings

### 1. r6 blockers: resolved.

- **Shell expansion.** One input form only (stdin), and the quoted heredoc is shown in the contract (line 255), the `Stop` reason (line 276), Pillar 2 deliverable 5, and the devlog skill deliverable 6.
  The test plan repeats R7 against the real script (line 519).
  Dropping the positional form entirely is simpler than r6 asked for.
- **Subagents.** The contract states the hazard plainly (line 300), including the `p=` capture that would satisfy the overseer's `Stop`.
  The guard text appears in three places, and the Phase-1 scenario (line 531) asserts both no foreign entry and that the top-level `Stop` still blocks.
- All eleven r6 action items are addressed: stale examples fixed (lines 210, 366-367), `--record` removed, the token-mapped title, `tac | grep -m1`, `path` never creates, `note` omits `p=` with no header, the cwd-change edge case, interactive check (e), init writes Pillar 2 with a presence test, `--plugin-dir` plus `command -v`, and the Phase-3 pointer.

### 2. Decision 13: the `PreToolUse` rejection rests on a false premise. Blocking (rationale only).

Decision 13 says a `PreToolUse` guard "is a third hook on every Bash call of every session to police one command".
With `"matcher": "Bash", "if": "Bash(chat-record:*)"` the handler process spawns only for `chat-record` invocations, once per top-level turn, and the payload's `agent_id` gives an exact, documented subagent signal: deny with a one-line reason.
The real cost is one more `hooks.json` entry and one more mode in the existing script, no per-Bash overhead.

Is rule text alone still the right call? Defensibly yes, because the maintainer fixed the surface at two hooks and the rule text is free.
The decision has to say that, though, because the current wording would steer the Phase-1 fallback away from the cheapest mechanical fix.
One gap also tilts toward the mechanical guard: **forks** (`subagent_type: "fork"`) inherit the full parent transcript, including every prior `chat-record note` call and the per-turn habit.
"If you were dispatched by the `Agent` tool" is the only rule text a fork sees against that history, and no agent definition applies to a fork.
`agent_id` would cover forks, assuming a fork's tool calls carry it like any subagent's.

Fix: rewrite the Decision 13 sentence to give the true cost and the true reason (the two-hook budget), name the `if`-scoped `PreToolUse` as the pre-agreed fallback if the Phase-1 scenario fails, and add a fork dispatch to that scenario.

### 3. Sign-off line: sound, with small grammar gaps. Non-blocking.

- The format is right: plain text, no `@`, no `p=`, and greppable by `SIGNOFF_RE`.
  The escape is symmetric with `HEADER_RE`, and the token mapping removes all quoting.
- `SIGNOFF_RE` contains a placeholder (`<timestamp>`), not a regex.
  Since writer and reader must share "the one pattern", spell it out (for example `^-- [A-Za-z0-9._-]+ at [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]+[+-][0-9]{2}:[0-9]{2}$`).
- An empty or all-stripped title (a `customTitle` of `""` or a title with no mappable characters) can never yield an empty token: the regex needs `+`.
  Mapping turns every character into `-`, so only `""` gives an empty token; say "fall back to sid8 if empty".
- The `body := line* signoff?` rule clashes with "the reader strips trailing blank lines from a body", because the writer puts a blank line *before* the sign-off.
  State that the reader splits off the sign-off first and strips blank lines second.
- **By-position association.** The sign-off is correct whenever `Stop` follows its own turn's blocks: normal turns, blocked-then-recovered turns, ignored blocks (the sign-off follows the `@user` directly), and harness turns.
  It breaks in one known case, a prompt queued mid-turn (interactive check (e)): if `UserPromptSubmit` fires mid-turn, the record reads `@user A`, `@user B`, then the agent's note, which defaults `p=` to B.
  `Stop(A)` then finds no A entry and blocks, the recovery note carries `--p A`, and the sign-off lands after B's block.
  The proposal defers this to (e). Add the consequence in one line ("if (e) shows mid-turn firing, the sign-off's position is not authoritative; correlate by `p=`") so the implementer knows what to write down.
- **Contradiction.** The `Stop` table (line 271) writes the sign-off only when an entry exists or `stop_hook_active` is set, "otherwise nothing" plus a block.
  Two other passages disagree: the interrupt edge case (line 499) says to suppress the block and "only the sign-off written", and the suppression list (line 291, no `prompt_id`) never says whether a sign-off is written.
  Make the table three rows: entry exists or `stop_hook_active` gives a sign-off; no entry and blockable gives a block; no entry and the block suppressed (interrupt, no `prompt_id`) gives a sign-off.
  This is the kind of drift the duplication in Finding 5 produces.

### 4. Stale references. Non-blocking.

- Layer map line 106: the agent's `note` goes to the participant labeled "chat-record (hook mode)".
  Relabel it "chat-record" or add a separate participant.
- Line 617: "a non-null `custom_instructions` value (irrelevant now that `PreCompact` is unregistered)" lists an irrelevant unverified fact; delete it.
- Line 614-615, "Also verified but not relied on": history; move it to the devlog.
- Lines 208 and 228: illustrative bullets about `PostCompact`, which is now outside the design.
  They are harmless as examples but pull a reader back toward compaction hooks; use examples about the two live hooks.
- Line 504: the sentence starts lowercase ("the sign-off falls back").

### 5. Document weight. Blocking.

The design is now about one script of roughly 150 lines, two `hooks.json` entries, one permission line, a Pillar 2 paragraph, a devlog template block, and a splitting rule.
The proposal is 90KB and grew in a round whose purpose was to simplify.
The maintainer has flagged overengineering repeatedly.
More concretely, an implementer has to reconcile the same fact stated in four places (Script contract, Invariants, Decisions, Edge Cases), and Finding 3's contradiction shows that cost is no longer hypothetical.
Nothing below removes anything an implementer needs.

| Material | Now | Action | After |
|---|---|---|---|
| Summary history NOTE (lines 43-48) | 1.5K | move to devlog; keep one sentence on the record versus Scratchpoint shapes | 0.2K |
| Background items 9-11 (shared-cache halves, r5/r6 review evidence) | 2K | one line each with a link; the evidence lives in the reviews | 0.5K |
| Non-Goals | 2K | keep the bullets, drop the repeated rationale (subagent bullet repeats Decision 13) | 1K |
| Location and naming (why per session, why `_chat`, commit protocol) | 4.5K | keep the rules, cut the "why" prose that repeats Decisions 3 and 9 | 2.5K |
| Block grammar and gist guidance | 9.9K | keep the grammar, speakers table, categories, and example; cut the `query:` lineage paragraph, the `read:` versus `files:` lifetime paragraph (said again in Scratchpoint), and the model-short derivation detail beyond one line | 6K |
| Script contract and invariants | 8.4K | merge Invariants with the "per-turn rule, its cost" subsection; drop restatements of the single write path (said three times) | 5K |
| Relationship to native auto-compaction | 1.7K | three sentences | 0.5K |
| Scratchpoint | 5.4K | keep the format and fields; collapse the two "stated plainly" relationship paragraphs into two sentences | 3K |
| Design Decisions | 8.6K | one or two sentences each, as rationale only; delete dated parentheticals and the round-history clause in Decision 10; Decision 8's `bin/` versus shim rationale fits in one sentence | 3.5K |
| Edge Cases | 8.1K | delete the ones that restate the contract (`CDOCS_CHAT_RECORD=off`, session id absent, subagent note, ignored block, `jq` missing, not a cdocs project, header-shaped bodies, note twice); keep harness prompts, pure-chat, interrupts, `--resume`, cwd change, splitting cases, OpenCode | 3.5K |
| Test Plan | 8.8K | keep every scenario, one line each as "setup -> assertion"; move the grammar fixture list into the test-file deliverable | 5.5K |
| Verification Methodology | 1.9K | keep the sandbox command; the canary recorder belongs in the `-canary` devlog chunk | 0.8K |
| Phase 0 | 4.6K | replace the narrative and the 13-row table with a link to the `-canary` chunk and R7, plus a 5-line "facts the script depends on" list (the `prompt_id` equality, `stop_hook_active`, the env var, `bin/` on PATH, no subagent signal) | 1K |
| Phases 1-3 | 8.8K | keep Phase 1 deliverables; deliverable 5 restates the rule text from Script contract, so point at it instead | 7K |

That comes to roughly 41-45KB, the realistic target for this document.
A cleaner option: the Scratchpoint, splitting, A/B, and cap-and-reseed (Phase 2-3, about 15K even after trimming) share no mechanism with the chat record except the Pillar 2 pointer.
Splitting them into a sibling proposal would leave a chat-record proposal of about 25KB that can be accepted and implemented now, while the Phase-2 design waits on its own gate.

### 6. Phases 1-2 implementability and test concreteness. Non-blocking.

Phase 1 is implementable as written: deliverables map one-to-one to files, the constraints are crisp, and the success criteria are measurable (zero gaps over 20 turns, an 80% usefulness sample).
Small gaps:

- The top-level-only scenario (line 531) says "rules materialized by `/cdocs:init`" without saying how inside a headless sandbox.
  Say: copy the init-produced `.claude/rules/cdocs.md` and `CLAUDE.md` import into the sandbox project.
  Add a fork dispatch (Finding 2).
- The "pure-chat prompt" scenario (line 523) uses a Bash call, so it is not pure chat. Rename it "minimal turn".
- The grammar unit test needs a reader, and the script has no read mode.
  Say the test carries its own reference splitter (about 10 lines of awk) built on the same two regexes as the script, ideally sourced from it.
- Phase 2 is unchanged from r5/r6 and remains adequate. Its A/B is the right gate.

## Verdict

**Revise.**
The design is accepted in substance: the r6 blockers are fixed with evidence, and the sign-off line is sound.
Two blocking items remain. One is a false rationale in Decision 13, which shapes the Phase-1 fallback. The other is document weight, which hides the small design and has started to produce internal contradictions.
Round 8 should change no design: correct one decision, fix the `Stop` table, apply the trim, and the next reviewer should accept.

## Action Items

1. [blocking] Decision 13: replace "a third hook on every Bash call" with the true cost (an `if: "Bash(chat-record:*)"`-scoped `PreToolUse` handler runs only on `chat-record` calls and denies when `agent_id` is present). Keep rule text on the maintainer's two-hook budget, and name that hook as the pre-agreed fallback if the Phase-1 scenario fails.
2. [blocking] Trim to about 40-45KB per the Finding 5 table: move history, Phase-0 ledger, and canary recorder to the devlog; cut Edge Cases that restate the contract; compress Decisions to rationale; compress Test Plan scenarios to one line each. Optionally split Phase 2-3 into a sibling proposal (about 25KB for the chat-record core).
3. [non-blocking, fold into 2] Make the `Stop` table three rows (sign-off / block / suppressed-block-writes-sign-off) so it agrees with the interrupt and suppression rules.
4. [non-blocking] Add a fork dispatch to the top-level-only Phase-1 scenario, and say how the sandbox gets the init-materialized rules.
5. [non-blocking] Write `SIGNOFF_RE` as a concrete regex; fall back to sid8 on an empty token; state the reader's order (split sign-off, then strip blanks).
6. [non-blocking] Add one line to interactive check (e) on what a mid-turn `UserPromptSubmit` means for sign-off position (correlate by `p=`, not adjacency).
7. [non-blocking] Fix the stale items in Finding 4 (layer-map participant, `custom_instructions` line, "also verified" list, `PostCompact` example bullets, lowercase sentence start).
8. [non-blocking] Rename the "pure-chat" test scenario; say the grammar test carries a reference splitter on the script's regexes.

## Questions / Options for the Maintainer

- **Subagent guard.** (a) Rule text only, with the `if`-scoped `PreToolUse` as a named fallback if Phase 1 shows leaks (recommended; respects the two-hook budget); (b) ship the `if`-scoped `PreToolUse` deny in Phase 1 (mechanical, covers forks, one more `hooks.json` entry, about 1 process spawn per turn); (c) rule text only, with no fallback recorded.
- **Document shape.** (a) Trim in place to about 40-45KB; (b) trim and split the Scratchpoint and splitting work (Phases 2-3) into a sibling proposal, leaving the chat-record proposal at about 25KB (recommended: the two halves share no mechanism and have different gates); (c) keep as is.
