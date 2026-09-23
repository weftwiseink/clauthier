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

## Round log

| Round | Model | Proposer/Reviser dispatch | Reviewer dispatch | Verdict |
|---|---|---|---|---|
| 1 | fable | pending | pending | pending |
