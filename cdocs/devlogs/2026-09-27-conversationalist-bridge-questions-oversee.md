---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-27T14:00:00-07:00
task_list: cdocs/audio-interaction
type: devlog
state: live
status: done
tags: [research, oversee, voice, voicemode, messaging, devcontainer]
---

# Conversationalist bridge design questions: oversee devlog

> BLUF: Fourth unit in the audio-interaction arc: a sonnet report answering the user's follow-up design questions on the VoiceMode conversationalist bridge.

## Objective

User follow-ups (2026-09-27) on `2026-09-27-voicemode-deep-dive.md`:
- Agent audio-out with control granularity is likely wanted (correcting the overseer's "won't need" framing of VoiceMode's playback control channel); wants more on the conch feature.
1. Do lace devcontainers break cross-session messaging (shared process namespace, sockets)?
2. Specialist subagent per connected session inside the conversationalist, to protect the top-level converse agent's context?
3. How does context / turn-end info flow from an overseer to the conversationalist?
4. Can the conversationalist relay and triage `AskUserQuestion`-style requests from overseers to the user?

## Notes

- Scratchpad is gone; VoiceMode re-clone goes to `build/research/voicemode` (gitignored).
- Known constraint to check: a subagent's cross-session sends go out under its parent session's address, replies land in the parent's conversation (bears on Q2).

## Log

- Dispatched sonnet author for `cdocs/reports/2026-09-27-conversationalist-bridge-design-questions.md`.
- Author returned (3271 words). Key: lace mounts ~/.claude (registry) but not /run/user/1000 (sockets) → host↔container messaging broken today. Dispatched fresh reviewer.
- Review r1: revise. Stop-hook→socket is documented (wire format found in claude 2.1.283 debug log; last_assistant_message in Stop input); AskUserQuestion PreToolUse deny reason is shown to Claude and updatedInput.answers enables full answer relay; container v0 gap + PID/connectto checks. Resumed author.
- Revision r1 returned (3598 words): Stop hook primary for turn-end, three-tier AskUserQuestion, explicit container gap. Dispatched round-2 review.
- Review r2: accept, with non-blocking R2-1..R2-5; sonnet polish pass applied them (liveness-gated fail-open AskUserQuestion hook, WARN on shared-mount relay, file relay demoted to v0.1). Overseer fixed a stale "v0 option (b)" test reference.

## Handoff

### Completed
- `cdocs/reports/2026-09-27-conversationalist-bridge-design-questions.md` accepted round 2 (~3700 words).

### Decisions Made
- v0: host-only voice-attached overseers; single-source audio in the conversationalist; per-overseer ledger files, no specialists; `Stop` hook posting `last_assistant_message` as primary turn-end push, `SendMessage` for model-judged content; tier-2 deny-and-redirect `AskUserQuestion` hook gated on conversationalist liveness, failing open.
- v0.1: `~/.claude` file relay for lace-contained overseers (e.g. `weftwise`).

### Open Todos
- Empirical tests: inbox-socket wire format via `socat`; container boundary refusal; `ListAgents` attached-detection.
- User decisions: where voice-attached overseers run; confirm v0 turn-end and AskUserQuestion picks; wake method; overseer permission mode.
- Candidate next unit: proposal for conversationalist v0 (skill + two overseer hooks + launch config).
