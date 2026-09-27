---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-27T09:00:00-07:00
task_list: cdocs/audio-interaction
type: devlog
state: live
status: wip
tags: [research, oversee, messaging, claude-code]
---

# Inter-session messaging report: oversee devlog

> BLUF: follow-up to the voice companion arc (`2026-09-26-audio-interaction-report-oversee.md`): a sonnet report on native Claude Code session-to-session messaging, constrained to claude.ai subscription auth.

## Objective

User asked for more detail on Channels and other message-passing affordances, suspecting native session-to-session messaging exists; must work with claude.ai subscriptions.

## Primary evidence (overseer, this session)

- `ListAgents` from this session lists 13 peer sessions: 8 local interactive (tmux-hosted, idle/shell state) and 5 Remote Control sessions (idle/offline). This session's own address: `clauth-audio [01b275]`.
- `SendMessage` tool description: cross-session delivery by session name to local, other-machine (Remote Control), and cloud sessions; messages drain at the receiver's next tool round; arrive as `<cross-session-message from=...>`; `notify_when_idle` one-shot idle subscription for same-machine sessions; sessions in a different permission mode hold inbound messages for user approval; no delivery receipt for Remote Control/cloud/Desktop targets; cloud sessions cannot reply.
- `FetchInboxMessage`: Remote Control relays chat-thread messages into a session inbox; `from="rc_owner"` marks server-verified owner messages.
- `PushNotification`: desktop notification, mirrored to phone when Remote Control is connected.
- `RemoteTrigger`: claude.ai routines API (scheduled/webhook cloud agents).
- The v2 voice companion report missed all of this; its bridge analysis covered only Channels, Agent SDK, `claude -p --resume`, MCP.

## Log

- Dispatched sonnet author for `cdocs/reports/2026-09-27-claude-code-inter-session-messaging.md`.
- Author returned: cross-session messaging is GA, subscription-compatible, documented at /docs/en/cross-session-messaging; idle receivers are woken; Agent SDK disallowed on subscription OAuth (invalidates v2 SDK-hosted option). Dispatched reviewer.
- Review r1: revise. SDK-on-subscription overstated (third-party-offering restriction; own-use grey; `claude -p` fine). Blocking: re-rank with CLI-hosted overseer (stream-json + --permission-prompt-tool); add script-posts-to-inbox-socket path (needs empirical test). Resumed author.
