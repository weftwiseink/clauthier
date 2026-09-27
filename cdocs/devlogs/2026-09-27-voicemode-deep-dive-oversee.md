---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-27T11:00:00-07:00
task_list: cdocs/audio-interaction
type: devlog
state: live
status: done
tags: [research, oversee, voice, voicemode]
---

# VoiceMode deep dive: oversee devlog

> BLUF: Third unit in the audio-interaction arc: a sonnet deep-dive report on VoiceMode (github.com/mbailey/voicemode) and whether a dedicated VoiceMode-equipped "conversationalist" Claude Code session can bridge to existing overseers via native cross-session messaging.

## Objective

User direction (2026-09-27): incrementalism; don't compete with weftwise devtime.
Keep `/oversee` usage as-is; add one Claude Code session that is the voice conversationalist and bridges to other overseers.
Biggest bang for buck is the voice-to-prompt bridge; VoiceMode "seems to manage a decent voice<>prompt setup."
Question: what to reuse from VoiceMode's design, or can we use it directly with inter-Claude prep/send as a separate component.

## Decisions

- Deprioritized spike A (`claude -p` hosted overseer): user wants to keep launching overseers as-is.
- Spike B (inbox socket) also deprioritized: a Claude-session conversationalist uses `SendMessage` natively; no raw socket needed.
- Key new question for the report: interaction between VoiceMode's blocking `converse` and cross-session message delivery (messages drain at tool rounds).

## Log

- Dispatched sonnet author for `cdocs/reports/2026-09-27-voicemode-deep-dive.md`.
- Author returned (3422 words). Commit draft; dispatched fresh reviewer (source-level checks against scratchpad clone).
- Review r1: revise. Blocking: always-listening converse loop burns ~180-360 model calls/hour idle; redesign around idle-wake + explicit user wake. Reviewer fixed checklist inline (plugin scope, match overseer permission mode, --name/--tools, ledger path). Resumed author.
- Revision r1 returned (3597 words): idle-wake default, hands-free opt-in, wake-options table, --model rec, bypass-default checklist. Dispatched round-2 review.
- Review r2: accept. Reviewer fixed hotword wake path (control channel only handles playback; hotword must post to inbox socket like the hotkey) and added checklist step 6 (SessionStart hook writes socket path, not token).

## Handoff

### Completed
- `cdocs/reports/2026-09-27-voicemode-deep-dive.md` accepted round 2 (~3600 words).

### Decisions Made
- Recommended first step: option (A), unmodified VoiceMode in a dedicated `--name conversationalist` session (local-scope plugin, smaller model), plus one cdocs bridge skill; idle-wake default, hands-free loop opt-in; (B) config tuning next.

### Open Todos
- User decisions: wake method (terminal / hotkey / hotword via inbox socket); overseer permission mode.
- Empirical checks before build: message timing around `converse()`, inbox-socket wire format, PipeWire audio path.
- Candidate next unit: proposal for the conversationalist bridge skill.
