---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-27T12:30:00-07:00
task_list: cdocs/audio-interaction
type: devlog
state: live
status: wip
tags: [research, oversee, voice, devcontainer, askuserquestion]
---

# Containerized conversationalist + AskUserQuestion surface: oversee devlog

> BLUF: Fifth unit in the audio-interaction arc: a focused sonnet report on (1) running the conversationalist inside a single project's lace container alongside its overseers, and (2) whether any mechanism lets the bridge answer an already-open `AskUserQuestion` dialog as an alternate surface.

## User direction (2026-09-27)

- Prefer a single-project containerized conversationalist over un-containerizing overseers. Supersedes the bridge report's "v0 host-only" recommendation.
- On `AskUserQuestion`: wants the bridge to act as an alternate interfacing surface that can answer/interrupt the pending local dialog (first-answer-wins); if impossible, tier 2 (deny-and-redirect hook) is fine.

## Log

- Dispatched sonnet author for `cdocs/reports/2026-09-27-containerized-conversationalist-and-question-surface.md`.
- Author returned: same-container messaging verified (weftwise runs 6 sessions sharing cc-socks tmpfs); audio via pulse socket mount; no concurrent AskUserQuestion race (channels relay covers Bash/Write/Edit only); tmux send-keys the only concurrent path; recommends tier 3 w/ timeout fallback. Dispatched reviewer.
- Review r1: revise. Blocking: weftwise image lacks libportaudio2/libpulse0/libasound2-plugins/ffmpeg; PortAudio→ALSA→pulse plugin path. Reviewer verified host.containers.internal reach (0.0.0.0 only), Remote Control does forward AskUserQuestion (human-only), tier-3 fallback = empty hook output not `ask`. Resumed author.
- Revision r1 returned (2609 words): full audio recipe, container-private socket path, project-scoped hooks, firewall WARN, tier-3 tradeoffs, decision points. Dispatched round-2 review.
