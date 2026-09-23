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

## Round log

| Round | Model | Proposer/Reviser dispatch | Reviewer dispatch | Verdict |
|---|---|---|---|---|
| 1 | fable | done: `cdocs/proposals/2026-09-22-chat-record-devlog-management.md` (review_ready) | done: `cdocs/reviews/2026-09-22-review-of-chat-record-devlog-management.md` | revise (5 blocking, warm proposer) |

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
