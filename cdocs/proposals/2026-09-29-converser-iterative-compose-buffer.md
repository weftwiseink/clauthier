---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-29T15:30:00-07:00
task_list: voice/converser-compose-buffer
type: proposal
state: live
status: request_for_proposal
tags: [voice, converser, ux, dashboard, weftwise]
---

# converser: iterative compose buffer and inbox dashboard

> BLUF(opus/voice/converser-compose-buffer): Make preparing a message to an agent an iterative, visible thing: a compose buffer the converser (re)compiles incrementally as the user speaks, previewed on a dashboard alongside an inbox of agent turn-ends, so voice input becomes less input-sensitive and more visually collaborative.
> - **Motivated By:** [`2026-09-29-converser-host-voicemode-serve.md`](2026-09-29-converser-host-voicemode-serve.md) (v0 relays one utterance per send; history lives only in the converser terminal), user direction 2026-09-29.

## Objective

The v0 converser compiles one utterance into one message, sends, then reads back; mistakes are fixed after the fact by a follow-on correction.
That is fine for short requests, but brittle for anything the user thinks through aloud: a single listen window must carry the whole intent, and a mis-hear or false start becomes a sent message.

The goal is a user-facing surface where a response is *prepared* rather than *fired*:
- speech accumulates into a per-target draft buffer;
- the converser re-compiles the draft incrementally as more speech arrives, showing a live preview of what would be sent;
- the user amends, reorders, or discards by voice ("drop the second point", "make that softer") or by keyboard/pointer, and sends explicitly or by a natural cue;
- an inbox view shows condensed agent turn-ends and pending questions next to the drafts that answer them.

This is the "user-interpretable view of active state" from the original arc, and the likely seam for a weftwise integration.

## Scope

- **Buffer model.** Per-target drafts vs one active draft; how speech segments append, and how the converser re-renders the whole draft (not just the tail) while preserving the speaker's meaning and style.
- **Send semantics.** Explicit send ("send it") vs cue-based vs timeout; how this coexists with v0's send-then-readback default and the intent-verification rule (a draft is itself the confirmation surface).
- **Voice editing grammar.** How far to go with spoken edits ("drop the second point", "scratch that", "add: …") before it becomes a command language the user must learn.
- **Dashboard surface.** Candidates: a tmux pane rendered by the converser; a local web page (host or container) fed by a fixed-path `converser-io` MCP/ledger; a claude.ai artifact with a shared DB; eventually weftwise. What updates live, who can write (user edits in the UI must flow back into the buffer).
- **Inbox.** Condensed Stop-hook turn-ends, pending `AskUserQuestion` redirects, and their linkage to drafts; read/unread and triage state; the `#N: <session>` history as the durable log beneath it.
- **Style seeding (deferred from v0).** Seeding the converser with the user's earlier typed messages to target sessions, so compiled drafts match how the user writes, not just how they speak.
- **Incremental listening.** Whether VoiceMode's blocking `converse()` supports streaming partial transcripts well enough for live preview, or whether this needs the non-blocking listen / event stream noted in the fork-complexity report (upstream first, fork on tripwire).
- **Staging.** Smallest useful slice (e.g. a single draft buffer rendered in a tmux pane, explicit "send it") vs the full dashboard.

## Open Questions

1. Does live preview need partial transcripts from `serve`, or is re-compiling after each short listen window good enough?
2. Where does buffer state live so both the converser and a UI can edit it without the converser getting `Write` (the v0 security floor)? A `converser-io` MCP with fixed-path tools is the default candidate.
3. How does the dashboard reach the user when the converser runs in a container and audio runs on the host (and later on Android)?
4. Is the weftwise integration the target surface from the start, or a later consumer of a converser-owned view?
5. How do drafts interact with the `#N` numbering: numbered on send only, or drafts get provisional labels?

## Prior Art

- [`2026-09-26-voice-companion-architecture.md`](../reports/2026-09-26-voice-companion-architecture.md): the talker/thinker framing and "user-interpretable view of active state".
- [`2026-09-28-host-audio-broker-split.md`](../reports/2026-09-28-host-audio-broker-split.md) and [`2026-09-28-voicemode-fork-complexity.md`](../reports/2026-09-28-voicemode-fork-complexity.md): non-blocking listen and event-stream seams.
- [`2026-09-29-converser-host-voicemode-serve.md`](2026-09-29-converser-host-voicemode-serve.md) Future Work: persistent ledger as a fixed-path `converser-io` MCP tool.
