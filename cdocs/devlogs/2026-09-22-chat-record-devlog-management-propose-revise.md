---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-22T00:00:00-07:00
task_list: meta/chat-record-devlog-management
type: devlog
state: live
status: wip
tags: [meta, tooling, context-management, agent-memory]
---

# Chat-Record + Devlog-Management Propose/Revise Loop

## Objective

Run `/cdocs:propose-revise` (overseer mode) on RFP-2 from the context-management roadmap: a durable chat-record system complementing the devlog, plus devlog-management changes (semantic-chunk splitting), per `cdocs/reports/2026-09-22-chat-record-scratchpoint-design.md`.

## Scope interpretation (stated up front, invoked command was ambiguous on exact numbering)

Invocation: `/cdocs:propose-revise --first-round fable 2 and 3. ...` — three different numbered lists exist in this session's history (the maintainer's own 7-point list, the original report's 4 workstreams, this artifact's 8 RFPs), so "2 and 3" doesn't resolve unambiguously to one scheme. Proceeding on content, not number-matching:

- **In scope for this proposal:** chat-record + devlog-management (RFP-2), first round on fable.
- **Out of scope, explicitly:** graphify (RFP-3) — maintainer confirmed twice this is WIP elsewhere, not ours to propose. Shared retrieval cache (RFP-4) — maintainer is skeptical it's a real mechanism; routed to a `/cdocs:report` instead of a proposal (dispatched separately, not part of this loop).
- **Maintainer directives folded into the proposer's brief:** chat-record format is `@speaker:`-delimited markdown (e.g. `@opus-4-8:`) with light metadata, not a heavier schema; state the report's resolved design plainly as a decision, not a hedge; this session's hook-reliability findings (dead Bash hooks, `PreCompact` gap #13572) should make the proposal treat "Phase 1 is cheap and ships now" as needing a quick verification spike, not an assumption.
- Bash-wrapper tool-use simplification note: checked against the existing `cdocs/proposals/2026-09-22-haiku-bash-wrapper.md` — already reflects "simple wrapper, no fancy hook wiring" (Phase 3 hook already optional/deferred). No edit made; noted for the record.

## Mid-round steering (relayed to the round-1 proposer via SendMessage while in flight)

Maintainer refinement: the chat-record summarizer should also carry a running "files touched" list — for each important file, a very brief one-liner on what it was useful for / why it mattered in that stretch of work. This is the "awareness-only" half of the dropped RFP-4 mechanism per `cdocs/reports/2026-09-22-shared-retrieval-cache-redundancy-check.md` (a sibling agent can decide whether to re-read or trust the note; it does not by itself save tokens, since it doesn't put the file's bytes in the sibling's context). Must land in the proposal's actual chat-record format/schema, not just prose. If the round-1 proposer had already finished before this was delivered, it becomes review feedback / a revision-round item instead.

## Mid-round steering, round 1 review (relayed to the reviewer via SendMessage while in flight)

Three maintainer refinements/questions to fold into the round-1 review's findings:

1. **Capture trigger/mechanism.** Capture should fire at turn-handoff (not continuously); agent-turn capture can be a skill/convention (agent self-discipline, like devlog upkeep today) rather than hook-enforced if wiring is annoying — but agent turns should be SUMMARIZED when captured, never verbatim. User turns are the exception: always auto-captured verbatim via a reliable hook (`UserPromptSubmit`), since that doesn't depend on agent discipline. Reviewer asked to re-examine the proposal's "Stop-captured assistant turns" judgment call (file-size cost) specifically against this alternative.
2. **Strategic question, explicit section requested**: does this system, fully built, actually obviate the need for Anthropic's native auto-compaction entirely (proactive cap-and-reseed means compaction never has to run cold), or does compaction remain an unavoidable safety net regardless? Reviewer asked for a recommendation, not just acknowledgment.
3. **Reopened as a genuine open question, not blocking round 1**: should chat-record-like capture extend to subagent/inner-loop contexts, not just the overseer, given the mechanism's actual goal (context orientation for agents/subagents) doesn't stop at the human-conversation boundary? For a subagent, "upstream input" is the overseer's dispatch prompt rather than a literal human turn — summarized-per-level applied recursively (per point 1) is the natural shape if so. Reviewer asked to assess whether this is a real Phase-2/3 scope question worth flagging, or whether scratchpoint (for durable specialists) already covers this need, making a separate subagent-chat-record redundant.

## Maintainer decisions on the review's three questions (2026-09-23)

1. **Commit policy: (b) committed by default, no redaction pass in this proposal.** Exposure accepted and documented, not mitigated here. General redaction/secret-scanning scoped out to a separate future workstream: `cdocs/proposals/2026-09-23-chat-record-redaction-scanning-rfp.md` (RFP stub, not elaborated).
2. **Subagent reads in `files=`: (a) exclude via `agent_id` guard**, confirmed — fixes the reviewer's independently-found bug (`PostToolUse` firing inside subagents). BUT the maintainer flagged a strong forward-looking implication while answering: this makes them confident nested chat records will be wanted soon, scoped **per-workstream** (one per set of proposer/reviewer/implementer working the same task_list), not just per-individual-agent — "so much of the point is context preservation for a workstream." This elevates the review's Phase-3 "subagent chronology" item from a hedge to a likely-near-term need, with a specific scoping unit (workstream, not agent) that the review's sketch didn't specify.
3. **Phase-2 A/B third arm: (a) add `/clear`-plus-reseed now**, confirmed — three-arm A/B (carry-indefinitely, cap-and-reseed-from-scratchpoint, `/clear`-plus-reseed) in Phase 2.

## Evidence

- [`_verify/2026-09-22-chat-record-hook-canary.md`](_verify/2026-09-22-chat-record-hook-canary.md): the eight sandboxed hook-canary runs (settings, commands, inputs, log lines, results) behind the proposal's Phase 0, plus the round-1 review's Run A/Run B; open it when you need a hook payload's exact shape or the sandbox recipe.

## Round log

| Round | Model | Proposer/Reviser dispatch | Reviewer dispatch | Verdict |
|---|---|---|---|---|
| 1 | fable | done: `cdocs/proposals/2026-09-22-chat-record-devlog-management.md` (review_ready) | done: `cdocs/reviews/2026-09-22-review-of-chat-record-devlog-management.md` | revise (5 blocking, warm proposer) |
| 2 (revision) | fable (warm, same proposer) | done: 12 action items + 3 maintainer decisions applied, commit `8986747`; evidence artifact `cdocs/devlogs/_verify/2026-09-22-chat-record-hook-canary.md` | done (fresh reviewer, opus-4-8): `cdocs/reviews/2026-09-22-review-of-chat-record-devlog-management-r2.md` | **accept** (5 non-blocking nits) |

## Round 1: proposer (fable-5-1)

Proposal written at `cdocs/proposals/2026-09-22-chat-record-devlog-management.md`, `status: review_ready`.

**Chosen conventions.**
Chat record: one hook-written file per session at `cdocs/_chat/YYYY-MM-DD-<sid8>.md`; blocks headed `@speaker: <ISO ts> key=value...` at column 0, body verbatim until the next header, header-shaped body lines escaped with a leading backslash; speakers `user`, `harness`, `<model-short>` (e.g. `opus-4-8`), `assistant`, `compact`, `session`.
Assistant blocks carry `files="r:path,rw:path"` (hook-written from `PostToolUse`), the mechanical half of the gist log the shared-cache report folded into RFP-2; the judgment half is a `files:` one-liner list in the Scratchpoint.
Scratchpoint: rolling replace-in-place `## Scratchpoint` block in the devlog the agent owns (generalizes the `overseer_thinness` columns; columns kept).
Devlog split: at handoff boundaries past ~12KB, cut at the most recent closed concern into flat `-<concern>` chunk siblings sharing the root's date; root becomes index with a `## Chunks` table (`read this when` column); chunks get `part_of` frontmatter and a backlink NOTE.
Delivery: `/compact <steering>` primary; `PreCompact` nudge, `SessionStart(compact)` reseed pointer, `PostCompact` summary capture secondary.

**Hook canary (Phase 0, run here, CC 2.1.280, sandboxed `CLAUDE_CONFIG_DIR`, haiku, 7 headless runs): confirmed-working.**
`SessionStart` (startup and compact), `UserPromptSubmit`, `Stop`, `SubagentStart/Stop`, `PostToolUse` (Read/Edit), `PreCompact` (manual via stream-json `/compact`, and auto via `--autocompact 100000`), `PostCompact` (manual and auto), `SessionEnd` all fired with usable payloads.
`PostCompact` exists on this version and carries the full `compact_summary`; the research report had assumed it was still an open request.
`additionalContext` from `UserPromptSubmit`, `PreCompact`, `SessionStart(compact)`, and `PostCompact` all reached the model.
`UserPromptSubmit` did not fire for a dispatched subagent's prompt (top-level-only scoping is mechanical), but did fire for a background-subagent completion notification (hence the `@harness` speaker).
Not verified: interactive `/compact` ([#13572](https://github.com/anthropics/claude-code/issues/13572) path), made a Phase-1 manual check.
Evidence: canary scripts and logs in the session scratchpad (`.../scratchpad/canary/`, runs 1-7); the recorder recipe is reproduced in the proposal's Verification Methodology.

**Deviations from the brief.**
`cdocs/rules/cdocs.md` does not exist in this repo (nor `plugins/cdocs/rules/cdocs.md`); the devlog mandate is cited from root `CLAUDE.md` and `writing-conventions.md`.
The coordinator's mid-task steering note (files-touched gist log from `2026-09-22-shared-retrieval-cache-redundancy-check.md`) was folded in before completion, as schema in both artifacts, not prose.

**Not done / for the reviewer.**
No `/cdocs:review` was dispatched (dispatched mode); the overseer's reviewer round covers it.
Open judgment calls a reviewer may push on: committing chat records by default; `Stop`-captured assistant turns adding file size; the mtime heuristic for "active devlog" in the nudge.

## Round 1: reviewer (fable-5-1)

Review at `cdocs/reviews/2026-09-22-review-of-chat-record-devlog-management.md`; proposal `last_reviewed` set to `revision_requested`, round 1.
Verdict: **revise**, warm proposer (all blocking items are bounded spec edits plus one evidence file; no design decision reopens).

**Independent verification performed (not taken from the proposer's summary).**
Re-derived every Phase-0 row from the raw canary logs (`scratchpad/canary/canary*.log`, `run*.in`, `run*.out`, `cfg*/settings.json`): `PostCompact` fires with `compact_summary` (2.8-9.1KB) after `SessionStart(compact)`; manual and auto `PreCompact` fire; run 4's marker output proves `additionalContext` from all three compaction-adjacent hooks reaches the model; `--include-hook-events` omits `PreCompact`/`PostCompact`; run 5 shows no `UserPromptSubmit` between `SubagentStart`/`SubagentStop` and the second `UserPromptSubmit` prompt (from the sandbox transcript) begins `<task-notification>`.
Ran two fresh sandboxed canaries (`scratchpad/rv/`, CC 2.1.280, haiku) with a recorder that logs `agent_id`/`agent_type` on every event:
Run A (foreground `Agent` whose subagent `Read`s a file): `UserPromptSubmit` fired once (scoping claim holds on the foreground path too) but **`PostToolUse` fired inside the subagent with `agent_id` set**, contradicting the proposal's "subagent reads are invisible by construction"; the docs confirm tool hooks run inside subagents.
Run B (`claude -p "/echo hello-world"` with a project command): `UserPromptSubmit` fires with the raw invocation string, not the expanded skill body; built-in `/compact` fires none (run 2).
External: [#13572](https://github.com/anthropics/claude-code/issues/13572) is closed-stale, [#14258](https://github.com/anthropics/claude-code/issues/14258) closed, `PostCompact` in the official hooks table.

**Blocking (5).**
(1) Canary evidence lives only in a session scratchpad; move settings, exact commands, inputs, and payload-key lines to `cdocs/devlogs/_verify/2026-09-22-chat-record-hook-canary.md`; fix six-vs-seven runs; relabel the "real payloads" example as a composite of runs 2, 4, 7.
(2) Add an `agent_id` guard to every chat-record event; correct the subagent-read statements; rest the overseer-only scoping on the documented `agent_id` field.
(3) Pin the grammar: one `HEADER_RE` prefix for writer and reader (strict `header` vs loose reader regex currently disagree on `@alice: hey`, LESS `@var:`, CSS `@page:first`); define quoted-value escapes incl. newline in `instructions=`; file lookup by `*-<sid8>.md` glob plus full `sid=` on the start line.
(4) Commit-by-default: `WARN` must cover assistant bodies and compaction summaries, not only pastes; specify explicit-path staging at handoff and "dispatched agents never stage `cdocs/_chat/`" (always-dirty tree, `git add -A` sweep); choose a redaction stance.
(5) Define "closed concern" (three-part closure test; move every closed concern, one chunk each, ~3KB merge) so two agents split identically.

**Judgment-call verdicts.**
(a) commit by default: keep, with the protocol and exposure fixes above; gitignore-by-default offered as maintainer option.
(b) `Stop`-captured assistant turns: keep verbatim via hook; `Stop` is the turn-handback point and `last_assistant_message` is the final text block only (already summary-shaped); a skill-convention per-turn summary would be a third summarization layer and duplicate the Scratchpoint; add the rule "overseer's final message each turn is its turn summary".
(c) mtime heuristic: reject as primary; use session-scoped "last devlog this session `Edit`/`Write`'d" from the already-wired `PostToolUse` hook, then `grep -l <sid8>`, then mtime.

**Steering items addressed in the review (explicit sections).**
Strategic: the system does not obviate native auto-compaction for the top-level session (no agent-invokable compaction, AFK/headless sessions, uncontrolled growth); it makes the summary's content irrelevant and compaction rare; restate the objective accordingly and add a `/clear`-plus-reseed third arm to the Phase-2 A/B.
Subagent-level capture: one-shot legs already covered by dispatch brief plus return summary; durable specialists have the state half in the Scratchpoint and lack only chronology; `SubagentStart/Stop` + `agent_transcript_path` + `agent_id`-keyed `PostToolUse` make a per-agent record one more `case` branch; recommended as a scoped Phase-3 investigation item, not designed now.

**Scope check.** No creep into graphify or the shared-cache token-cost half; interactive `/compact` correctly a Phase-1 manual check.

## Round 1: revision (fable-5-1, warm proposer)

All 12 action items and the 3 maintainer decisions applied; proposal remains `status: review_ready` (64.7KB, from 46.5KB).

**Blocking.**
(1) Wrote `cdocs/devlogs/_verify/2026-09-22-chat-record-hook-canary.md`: per run, the recorder script, `settings.json`, exact `claude` command, `run*.in`, canary-log lines (`transcript_path` dropped, sandbox path elided), model result; includes the run-5 `<task-notification>` prompt from the transcript and a "Not exercised" list. Phase 0 links it, says seven runs, and the example record is labeled a composite of runs 2, 4, 7.
(2) `agent_id` guard is now the first invariant of the hook contract; "invisible by construction" language replaced with the verified behavior (tool hooks fire inside subagents with `agent_id`); Non-Goals rests the scoping on the documented field; Phase-0 table gained the review's Run A and Run B rows; subagent-`Read` test scenario added.
(3) Grammar pinned: `HEADER_RE := ^@[A-Za-z0-9][A-Za-z0-9._-]*:` is the single writer-escape and reader-split test (with the `@alice:`/LESS/CSS examples stated as escaped); quoted values have exactly four escapes (`\\`, `\"`, `\n`, `\r`); CRLF normalized; file located by `*-<sid8>.md` glob, full `sid=` on the start line, full-id filename fallback on mismatch; adversarial fixture extended.
(4) `WARN` names three leak channels (pastes, assistant bodies, compaction summaries); commit protocol specified (overseer stages by explicit path at handoff in a devlog-class commit; dispatched agents never stage `cdocs/_chat/`); Pillar 1 carve-out sentence added; redaction stance per maintainer decision 1: none, exposure accepted, pointer to `cdocs/proposals/2026-09-23-chat-record-redaction-scanning-rfp.md` in Non-Goals, the `WARN`, and Decision 9.
(5) Closed concern defined by the three-part test (own heading; every handoff Open Todo naming it done or moved; no live table still receiving rows); move every closed concern, one chunk each, ~3KB merge, shared-table rows move with their concern or stay if shared; chunks carry `status: done`.

**Non-blocking.**
(6) Active devlog resolved in three tiers: `<session_id>.devlog` written by the already-wired `PostToolUse` hook on `Edit`/`Write` of `cdocs/devlogs/*.md`, then `grep -l <sid8>`, then mtime; the two-sessions edge case is now resolved rather than documented.
(7) `last_assistant_message` stated as the final text block only; rule added that the overseer ends every turn with a short turn summary (Phase-1 Pillar 2 deliverable); `Stop` capture kept verbatim.
(8) New section "Relationship to native auto-compaction"; Objective and BLUF restated as "make the summary's quality irrelevant and compaction rare"; Phase-2 A/B is three-arm per maintainer decision 3 (carry-indefinitely, cap-and-reseed-from-scratchpoint, `/clear`-plus-reseed) with the arm-3 result feeding the `/cdocs:compact` print decision.
(9) Rewritten per maintainer decision 2 as a Phase-3 design sketch for a **per-workstream** record keyed by `task_list`: key learned from the active devlog's frontmatter; session files are not relocated, the hook appends `@session ... workstream ws=<task_list>` and the workstream record is the `grep -l` set (covers next-day sessions, merges across worktrees); legs' chronology lands in the parent session's file as `@dispatch`/`@return` blocks from `SubagentStart`/`SubagentStop` (`last_assistant_message` as the return body, per-agent `files=` from `agent_id`-keyed buffers), still one writer; gated on Phase-1 landing plus two unverified canary items (`SendMessage` resume firing a fresh `SubagentStart`/`Stop` pair; `PreToolUse` on `Agent` delivering `tool_input.prompt`).
(10) #13572 closed-stale and #14258 closed noted in the Summary NOTE; hooks reference cited for `PostCompact`; Decision 7 rationale is "unverified interactive path".
(11) `notebook_path` for `NotebookEdit`; README "seven entries"; slash-command capture (raw invocation string) and built-in `/compact` non-capture stated with tests; `model` cached from `SessionStart(compact)` as first source for `<model-short>`; steering string is user-typed or `/cdocs:compact`-printed.
(12) Scratchpoint bounded to 15 lines and 8 `files:` entries; staleness maps to the judge's existing `overseer_thinness: signal_missing`; Pillar-1 carve-out sentence (see item 4).

**Not fully resolvable here, flagged.**
The per-workstream sketch (item 9) has two mechanics I could not verify without a durable-specialist canary: whether `SendMessage` resume re-fires `SubagentStart`/`SubagentStop` with the same `agent_id`, and whether `PreToolUse` on the `Agent` tool exposes the brief; both are listed as Phase-3 gating canaries, not assumed.
The interactive TUI `/compact` path remains the Phase-1 manual check, unchanged.

## Round 2: reviewer (opus-4-8, fresh)

Review at `cdocs/reviews/2026-09-22-review-of-chat-record-devlog-management-r2.md`; proposal `last_reviewed` set to `accepted`, round 2.
Verdict: **accept**.

**Method.** Fresh reviewer, no round-1 priors. Re-derived the document's claims independently (grammar walk-through, hook-contract and `_verify` inspection, Phase-3 sketch, cross-reference checks on disk) *before* reading round 1's review; read round 1's review last, only to confirm which blocking items it raised and whether the current text resolves them.

**Round-1 blocking items, all verified resolved (independently, not by trusting round 1):**
(1) `_verify` artifact shows raw per-run evidence (settings, commands, inputs, real payload lines, results); seven runs; composite example labeled.
(2) `agent_id` guard is the concrete first invariant + Phase-1 deliverable; Non-Goals scoping rests on the documented field; `.turn` buffer is `session_id`-keyed so the guard correctly prevents subagent-read pollution. Did not re-run the subagent-`PostToolUse` canary live (treated round-1 Run A + hooks-reference as credible prior per this round's brief).
(3) Single `HEADER_RE` pinned; walked `@alice:`, LESS `@brand-color:`, CSS `@page:` through writer-escape and reader-split, plus stacked-backslash round-trip: unambiguous, bijective.
(4) `WARN` covers all three leak channels; explicit-path staging + "dispatched agents never stage `_chat/`"; redaction stance stated (accepted exposure, RFP deferred).
(5) Closed-concern three-part test + move-every-concern/one-chunk/~3KB-merge rule: decidable, splits identically across agents.

**Maintainer-driven additions, all substantive:** three-arm A/B (rubric + pass condition + arm-3→`/cdocs:compact` decision rule); native-auto-compaction section (correctly: no for top-level, yes for durable specialists; run-3 "four compactions in three minutes" citation checks out); per-workstream Phase-3 sketch (single-writer preserved; both unverified mechanics correctly scoped as gating canaries).

**No new blocking issues from the large revision pass.** Five non-blocking nits recorded as action items (surfaced, not applied - reviewer edits only `last_reviewed`): (1) "stop events fire in subagents with agent_id" conflates `Stop`/`SubagentStop` (only `PostToolUse` carries it among Phase-1 events); (2) fold round-1 Run A raw log into the `_verify` file so the guard-justifying evidence is co-located; (3) Phase-3 sketch under-specifies `PreToolUse`-prompt→`SubagentStart` correlation (`agent_transcript_path` is only on `SubagentStop`), add to gating canary (c); (4) run-3 fixture generator not reproduced; (5) `NotebookEdit` `PostToolUse` assumed by analogy, not canaried/tested.

Recommend advancing the proposal to `status: implementation_ready`.

## Round 2: nit fold-in and close (fable-5-1, warm proposer)

Loop terminates here on **Accept** (round-2 review `cdocs/reviews/2026-09-22-review-of-chat-record-devlog-management-r2.md`, commit `74db42b`).
Per this loop's convention the accepting round's five non-blocking nits were resolved before closing, and the proposal is now `status: implementation_ready` (precedent: `cdocs/proposals/2026-09-17-graphify-cdocs-integration.md`), ready for a future `/cdocs:iterate` pass.

Nits applied:
(1) `agent_id`-guard invariant reworded: defensive on all seven events, `PostToolUse` is the only Phase-1 event that carries `agent_id` in practice; plain `Stop` is top-level-only and `SubagentStop` is unregistered.
(2) Round-1 review Run A's raw log (subagent `PostToolUse` with `agent_id`) and Run B's slash-command result folded into `cdocs/devlogs/_verify/2026-09-22-chat-record-hook-canary.md` as their own section, co-located with the seven proposer runs.
(3) Phase-3 sketch: `@dispatch`-body sourcing stated as unsettled (`PreToolUse` has the prompt but no `agent_id`; `SubagentStart` has `agent_id` but no prompt or transcript path; only `SubagentStop` has the transcript path); gating canary (c) now also asks how the `PreToolUse` prompt is correlated to its `SubagentStart`, choosing between eager correlation and lazy write-at-`SubagentStop`.
(4) Run-3 fixture generator (seeded Python) reproduced in the `_verify` artifact, with a note that fixture content is not load-bearing for the auto-compaction claim.
(5) `NotebookEdit` stated as an assumption by analogy to `Edit`/`Write` (not canaried) in the hook contract, and a `NotebookEdit` scenario added to the Phase-1 hook tests to confirm it.

Final state: proposal `implementation_ready`, `last_reviewed: accepted`, round 2.
Not done in this loop, by design: no implementation; the interactive TUI `/compact` check and the two Phase-3 gating canaries remain for the implementer.
This proposer dispatch is complete.

## Round 3 (reopened, post-acceptance, pre-implementation): maintainer correction on chat-record content and `_verify` placement (2026-09-23)

Loop was reopened before any implementation started. Two corrections, both design-level, not artifact-only:

1. **Chat-record content was wrong.** The accepted design has agent turns captured verbatim via `Stop` (`last_assistant_message`, the final text block). Maintainer's original concept, restated explicitly: chat-record entries should be highly compact orienting summaries — roughly **one bullet point per action item**, not a reply dump. This overturns round 1's judgment call (b) ("keep `Stop`-captured verbatim, a summary would duplicate the Scratchpoint"). Overseer's resolution: chat-record (append-only, compact, chronological action log) and Scratchpoint (rolling, replace-in-place, current-state snapshot) are different *shapes*, not the same job at different granularity — that's what actually resolves the round-1 duplication concern, in the opposite direction from how round 1 resolved it. Mechanism reverts to the overseer's original round-1 steering (skill/convention-driven agent-authored bullets at turn-handoff, not hook-captured raw text); the `Stop` hook may still serve as a trigger/reminder, not as the content source.
2. **`cdocs/devlogs/_verify/` placement questioned.** This namespace was invented reactively by round 1's reviewer as a blocking-item fix (evidence must be reproducible, not asserted) and was never checked against the devlog-chunk scheme this same proposal defines. Overseer's resolution: keep it as a distinct genre (raw reproducible evidence is not devlog narrative prose; inlining it as a chunk would recreate the append-only-bloat failure mode devlog-management exists to prevent) but require it to be backlinked from the owning workstream's devlog via the same `part_of`-style convention the chunks already use, so it's discoverable, not a disconnected namespace.

Dispatched to the same (warm) proposer for a round-3 revision.

## Round 3 follow-up correction (mid-flight, relayed to the round-3 reviewer): `_judge/` rejected, `_verify/` folded into existing devlog Verification + chunking

The round-3 revision (commit `082df8c`) introduced an unrequested `_judge/` namespace and kept `_verify/` as a separate, backlinked genre per the overseer's round-3 brief above. Maintainer overrides both, correctly identifying that the overseer's own "keep `_verify/` separate but backlinked" resolution was itself scope creep:

- **`_judge/`: rejected outright, out of scope.** Never requested; remove.
- **`_verify/`: also rejected as a separate namespace.** This proposal's actual scope is chat-record + devlog CHUNKING, not redesigning what devlogs contain. `plugins/cdocs/skills/devlog/template.md`/`SKILL.md` already has a **Verification** section for pasted build/test/runtime evidence — that predates this proposal. Correct fix: reproducible canary evidence lives in the devlog's own Verification section; if it outgrows one file, that is exactly what this proposal's own chunking mechanism (`-<concern>` naming, `part_of`, backlink NOTE, `## Chunks` index) is for — e.g. a `-verification` chunk, using the SAME machinery as any other closed-concern split. No separate directory, no separate `## Evidence` index-list type.

Relayed live to the in-flight round-3 reviewer (`ae077db08527082d6`) as a further correction on top of the brief it's already reviewing against.

## Round 3: revision (fable-5-1, warm proposer)

Both corrections applied; proposal back to `status: review_ready`.

**1. Chat-record content.** Agent turns are now agent-authored bullet blocks, one bullet per action item (`- <verb> <object>[: <why or outcome>]`, ~120 chars each), written as the last action of any turn that did work via a new `chat-record.sh note [--as <speaker>] <record-path> "<bullets>"` entry mode; the script attaches `p=` (prompt id stashed by `UserPromptSubmit`) and `files=` (from the `PostToolUse` turn buffer) mechanically, so the agent types only the bullets.
`last_assistant_message` is never written to the record.
Reworked: BLUF, Summary table and a reversal NOTE, layer map, speaker table, new "Agent bullet blocks" paragraph, `files=` paragraph, the composite example, the hook contract (two entry modes; `Stop` row; `PostToolUse` matcher widened to `Bash|Agent` for an `acted` mark), the invariants (one append path, two authors; agents never `Edit`/`Write` the record), the Scratchpoint's "different shapes" paragraph, Decisions 4 and 10, Edge Cases, Test Plan (note, forgot-note, no-work scenarios), Phase-1 deliverables and success criteria, and the Phase-3 `@return` sourcing caveat.

**Forgot-the-bullet answer, settled:** (1) first `Stop` of a working turn with no bullet returns `decision: block` with a reminder to call `note`; (2) if the second `Stop` (`stop_hook_active=true`) still finds none, the hook appends a placeholder `@<model-short>: <ts> p=<pid8> files="..." gap=1` with an empty body; (3) the gap is accepted.
No truncated reply is ever used as the fallback: the placeholder's `files=` is real information and `gap=1` is greppable (two or more gaps since the last handoff feed the judge's `overseer_thinness: signal_missing`), whereas a truncated dump is the shape the maintainer ruled out.
Verified the block mechanism with canary run 8 (2026-09-23, CC 2.1.280, haiku): the harness honored the block, the agent performed the requested action, the second `Stop` fired with `stop_hook_active=true`, three turns total; recorded in the `_verify` artifact.
Turns with no tool use owe no bullet and are never blocked.

**2. `_verify/` placement.** Kept as its own genre (with `_judge/`), now linked like chunks: evidence files carry `part_of: <owning devlog>` plus a first-line backlink NOTE, and the owning devlog's index carries an `## Evidence` list adjacent to `## Chunks` (a list, not chunk rows, because the read-when semantics differ). Applied to the canary artifact and to this devlog's new `## Evidence` section; the convention is in the proposal's new "Evidence files" subsection and in Phase-1 deliverable 6 and Phase-2 deliverable 4 (`triage`/`status` flag an evidence file whose owner lacks an `## Evidence` line).

**Not changed.** User-turn capture (hook, verbatim), `@compact` capture (verbatim summary, the one non-compact block), the grammar, the `agent_id` guard, and the splitting rules.
**Flagged for the reviewer:** the `Stop` reminder is the design's only `decision: block`; the bound is the harness's `stop_hook_active`, verified once headless, not interactively.
