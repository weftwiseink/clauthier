---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-27T15:40:00-07:00
task_list: cdocs/audio-interaction
type: report
state: live
status: review_ready
last_reviewed:
  status: revision_requested
  by: "@claude-opus-5-5"
  at: 2026-09-27T11:25:45-07:00
  round: 1
tags: [analysis, voice, voicemode, messaging, devcontainer]
---

# Conversationalist bridge: five design questions, answered from source

> BLUF: The conch is a real single-speaker lock (verified/source) but scoped to one host's `~/.voicemode/conch` file: it arbitrates VoiceMode agents sharing one mic, not overseers sharing a speaker, and has no cross-session-messaging awareness.
> Lace devcontainers don't block same-machine messaging by policy, but they break it structurally: the session *registry* (`~/.claude/sessions/`) is shared via lace's bind mount, so `ListAgents` can see a container session, but the inbox *socket* it points at lives in `/run/user/1000`, which lace does not mount (verified/empirical, corroborated by docs: "a session inside a container and a session on the host can't reach each other").
> A per-session specialist subagent is the right shape only as an in-process ledger/summarizer, never as the delivery boundary, since inbound `SendMessage` always lands on the top-level session first.
> Turn-end context should reach the conversationalist via `notify_when_idle` plus an explicit `SendMessage` convention in the overseer's skill, not hooks: `Stop` has no verified path into another session's socket.
> `AskUserQuestion` is interceptable by a `PreToolUse` hook (empirically confirmed by third-party bug reports) but denial-reason propagation is unreliable today, so v0 uses a convention instead: overseers `SendMessage` questions when a conversationalist is attached.

## Context / Background

[`2026-09-27-voicemode-deep-dive.md`](2026-09-27-voicemode-deep-dive.md) established the shape: one dedicated conversationalist session running VoiceMode, idle-waking on `SendMessage`. [`2026-09-27-claude-code-inter-session-messaging.md`](2026-09-27-claude-code-inter-session-messaging.md) inventoried Claude Code's messaging affordances. This report answers five follow-up questions against that design. VoiceMode source is read at the parent report's clone commit, `126d15e` (2026-09-15), at `build/research/voicemode/` (gitignored). Devcontainer findings come from `/var/home/mjr/code/weft/lace/main` plus live, read-only inspection of the host and its running lace containers.

## 0. Audio-out control and the conch

> Direct answer: VoiceMode has a narrow playback-control channel (pause/resume/stop/skip, opt-in) and a real single-speaker lock (the conch), but neither knows about Claude Code sessions, and the conch solves "don't let two VoiceMode agents step on one mic/speaker," not "arbitrate several overseers speaking to one user."

**TTS/playback control, verified/source.** `voice_mode/control_channel.py` defines a transport-agnostic state machine (`running`/`paused`/`stopped`/`skip_forward`, [`control_channel.py:44-51`](https://github.com/mbailey/voicemode/blob/master/voice_mode/control_channel.py#L44)) driven by JSON commands (`pause`/`resume`/`stop`/`skip_forward`/`skip_back`, `control_channel.py:58-76`). It ships no listener beyond the socket primitive itself and is off by default (`VOICEMODE_CONTROL_CHANNEL_ENABLED=false`, parent report). A security detail matters here: `stop`'s free-text `message` is never surfaced to the model; only a fixed, server-owned `hint` table (`switch-to-text`, `brevity`, `quiet`, `pause-timeout`, `control_channel.py:96-104`) can inject a sentence, closing a prompt-injection path (source comment). Any future "relay a stop instruction" design should route through this allowlist, not free text.

`converse()` takes call-level `voice`/`speed` ([`converse.py:546,551`](https://github.com/mbailey/voicemode/blob/master/voice_mode/tools/converse.py#L546)); `wait_for_response=false` (default `true`) makes a call speak-only, no microphone access (module PRIVACY note, `converse.py:3080`). **Distinct voices per overseer: unverified/design.** Nothing ties `voice` to a session identity; it's a plain per-call string. Nothing stops the conversationalist from picking a voice keyed off the sender's name, but that's a policy the conversationalist's own skill would implement, not a VoiceMode feature. The conch's own `voice` field exists so *another agent* can read the current speaker's voice and avoid a clash — evidence the pattern is designed-for, just for peer VoiceMode agents, not Claude Code sessions.

**The conch, in depth.** Module docstring: it's a lock file "to indicate when a voice conversation is active," so "other processes... can check whether to suppress their audio output" ([`conch.py:1-4`](https://github.com/mbailey/voicemode/blob/master/voice_mode/conch.py#L1)) — a single-speaker mutex for one machine's mic/speaker, not a router for multiple conversational partners. Mechanism: `Conch` ([`conch.py:102`](https://github.com/mbailey/voicemode/blob/master/voice_mode/conch.py#L102)) is a `~/.voicemode/conch` lock file guarded by a kernel `flock` during an active call (`held: false`, stale ceiling `CONCH_LOCK_EXPIRY`, 120s default), with a separate opt-in "hold across turns" mode (`held: true`, flock released, a short refreshed TTL — `CONCH_HOLD_EXPIRY`, 10s default, or a per-call override via `conch_hold_timeout`). A FIFO waiter registry, `ConchQueue`, offers `wait` (block, capped at 25s over MCP) and `callback` (register-and-return, delivered out-of-band). States aren't a named enum: `free` is true only when there's neither a live holder nor an unclaimed grant, avoiding a race where a second waiter steals a just-issued grant. `converse()` exposes queueing via `wait_for_conch`/`conch_mode`/`hold_conch`/`conch_hold_timeout` ([`converse.py:2948-2952`](https://github.com/mbailey/voicemode/blob/master/voice_mode/tools/converse.py#L2948)). **Unverified**: exact fallback when `wait_for_conch=false` (the default) and the conch is busy — proceeds anyway or fails — not traced in this pass. A remote-agent front end also exists (`tools/conch.py`, `status|wait|callback|heartbeat|leave|give|bump|release`, keyed by caller-supplied `session_id` since a remote agent has no host PID).

**Could overseers speak short notices while the conversationalist holds the conch? Design answer: technically via the queue, but wrong for this architecture.** It only works if overseers also run VoiceMode's `converse` tool, which the parent report explicitly avoids (token cost, duplicated STT/TTS dependencies). The conch also only arbitrates one host's `~/.voicemode/conch` file, disconnected from the `SendMessage`/`ListAgents` graph this design is built on. **Recommendation: keep audio-out concentrated in the conversationalist; overseers `SendMessage` text, never call `converse()` directly.**

**Granularity available, from shipped primitives:** interrupting speech (`skip_forward`, needs the control channel plus an external trigger, none ships); "shorter please"/"quiet" (the `stop` hint table already includes `brevity`/`quiet`); replay last (`skip_back`, a documented history-buffer transport request); per-source mute (no equivalent — a conversationalist-skill-level policy layered on plain text, since VoiceMode has no concept of "source"). All four need the control channel (off by default) plus a trigger not wired today.

## 1. Devcontainers and cross-session messaging

> Direct answer: same-machine messaging is rooted at `/run/user/<uid>` (or a `/tmp/cc-socks-<uid>` fallback), not `~/.claude`. Lace's feature bind-mounts `~/.claude` but not `/run/user/1000`. Verified on this host: the registry is visible across the boundary, the socket is not.

**Where sessions register.** Verified/empirical (Fedora, uid 1000): each session writes `~/.claude/sessions/<pid>.json` plus a `<pid>.<hash>.key` auth file. A real entry:

```json
{"pid":1413851,"pidDomain":"linux:a6d8486bf8314670b75c79adf53a6a46:pid:[4026531836]",
 "messagingSocketPath":"/run/user/1000/cc-socks/1413851.sock","name":"clauth-audio"}
```

`pidDomain` is `linux:<machine-id-prefix>:pid:[<PID-namespace-inode>]`, confirmed by cross-checking `/etc/machine-id` and `readlink /proc/self/ns/pid` against this exact JSON. This is Claude Code's own PID-collision guard: a bare PID isn't stable across containers (namespaces reuse small integers), so it stamps the namespace too. Directly answers "shared process namespace": **no, it's namespace-aware by construction.**

**Where sockets live, and why lace's mount misses them.** Verified: `$CLAUDE_CODE_MESSAGING_SOCKET` resolves to `/run/user/1000/cc-socks/<pid>.sock`; docs confirm the `/tmp/cc-socks-<uid>` fallback ("The session's inbox socket"). Lace's `claude-code` feature (`devcontainers/features/src/claude-code/devcontainer-feature.json`) declares only two mounts: `~/.claude` and `~/.claude.json`. Verified via `podman inspect jif`: `/home/mjr/.claude -> /home/ubuntu/.claude ([rbind])` — a real recursive bind mount, so `~/.claude/sessions/*` is one shared directory across host and every lace container. Confirmed directly: a container (`weftwise`) with a live `claude --resume` process (PID `3002342`, `pidDomain: linux:c45dc044...:[4026533606]`, different machine-id and PID-namespace than the host's `a6d8486b...:[4026531836]`, and `podman inspect` shows `PidMode: private`, `UsernsMode: private`) has its `~/.claude/sessions/3002342.json` readable straight from the host filesystem. But `/run/user/1000` isn't mounted by lace: inside `weftwise`, `/run/user/1000/cc-socks/3002342.sock` exists in its own private tmpfs; on the host, that same path is "No such file or directory." **The registry entry crosses the boundary; the socket it names does not.**

**Docs corroborate directly.** code.claude.com/docs/en/cross-session-messaging, "Message sessions on other machines": **"A session inside a container and a session on the host can't reach each other. Two sessions inside the same container can still message each other."** Matches the empirical finding exactly and generalizes it: for messaging purposes the conversationalist and any lace-contained overseer are always different "machines," regardless of what the kernel actually shares.

**Liveness/PID reuse.** Docs' "own-child messages" section directly addresses lace's shape: on Linux Claude Code verifies a poster via `/proc` process evidence, but "in a container where Claude Code runs as process ID 1 it has no process evidence at all," falling back to `CLAUDE_CODE_MESSAGING_TOKEN` verification. Combined with the `pidDomain` stamp, the mechanism is robust to namespace/PID-reuse hazards; it's the *mount topology*, not the liveness logic, that breaks delivery.

**What mounting `/run/user/1000/cc-socks` would need, unverified/untested, not recommended without dedicated testing:** SELinux relabeling of a live, growing tmpfs (riskier than the static `~/.claude` mount lace already relabels); rootless-podman UID remapping (verified working today for `~/.claude`, e.g. `ubuntu:ubuntu` inside the container vs. `mjr:mjr` on host — plausible the same handling extends, untested); PID-namespace liveness is not a blocker, per above.

**Remote Control fallback.** Same-machine delivery uses the local socket exclusively; there's no automatic fallback to Anthropic-server routing when the local path fails — cross-machine/cloud routing is a separate code path gated on a live Remote Control connection, which a container-hosted overseer and the host conversationalist would each need to opt into independently. Unverified whether Remote Control's client works normally from inside a lace container (no obvious blocker, not tested).

**Concrete test** (no session messaging performed, out of scope here): start a bare session inside a lace container, note its name via `/status`; from the host run `/list-agents` and check whether it appears; if so, attempt `SendMessage` and observe delivered/refused/dropped; check the container session's own `/status` `Peer address` row; as a positive control, start a second session *inside the same container* and confirm it can message the first (docs say this should work, isolating the break to host<->container specifically).

## 2. A specialist subagent per connected session

> Direct answer: worth building only as an in-process ledger/summarizer resumed by name, never as the message *receiver* — inbound traffic always lands in the top-level conversationalist's own conversation first, by protocol design.

Per docs: "The receiving Claude reads the message between tool calls..." — the delivery target is the session that owns the inbox socket/registry entry. A subagent has neither; it's addressed only via in-process `SendMessage` to a named background subagent, a different mechanism from the peer-session socket. So an overseer's message to "the conversationalist" is always received by the top level, full stop.

Given that, the useful pattern is orchestration-discipline.md's Pillar 3 (durable specialists, resume-by-name, one-per-workstream), applied with "workstream" = "connected overseer": the top level stays a thin router, and on an inbound message its next action is a one-line in-process `SendMessage` to a specialist named for that overseer — "condense this, update your ledger, tell me what to speak" — the specialist owning a per-overseer ledger file (satisfying Pillar 1b's single-writer guarantee "by construction," per Pillar 3), carrying that overseer's running context across turns so the top level never re-explains it.

**The bound**, per Pillar 3: at most one specialist per *actively conversing* overseer, spun up lazily on first traffic, spun down after an idle window — dormant-but-resumable specialists still cost context if never explicitly closed. Given a voice conversation is inherently serial, realistic concurrency is 1-3, well inside the bound.

**Latency cost.** Every inbound message pays an extra in-process hop before `converse()` can speak it — a real tax on a design whose parent report already treats voice latency as first-order. **Recommendation: gate the hop on complexity, not apply it unconditionally.** A short status ping should be spoken directly by the top level (a "trivial few-liner," per Pillar 1's carve-out); route to the specialist only for long/structured messages, follow-ups needing prior context, or multi-overseer triage (reusable for Q4's batching).

**Cheaper alternatives.** A per-session ledger file with *no* specialist subagent: the top level reads/appends a small JSON file per overseer inline, keeping its own context thin without an extra hop — strictly cheaper, sufficient at 1-3 concurrent overseers, at the cost of the top level re-reading the relevant ledger slice each time instead of a specialist reasoning over resumed context. `/compact` cadence (Pillar 2) applies to the conversationalist's own session regardless of which pattern is chosen, independently.

**Recommendation for v0: skip specialists; use the ledger-file pattern.** Less to build, no latency hop, adequate at this scale. Revisit specialists only if a specific overseer relationship grows large enough that re-reading its ledger slice each turn becomes its own cost.

## 3. Turn-end context flow

> Direct answer: no single mechanism carries both "turn ended" and "what happened." The working combination: `notify_when_idle` as the zero-cost push trigger, plus an explicit `SendMessage` line in the overseer's skill as the payload carrier. Hooks are weaker: `Stop` has no *verified* path into another session's socket, and `Notification` is observational only.

**`notify_when_idle`** (docs): one-shot, same-machine only, subscribable only by "the Claude in your main conversation," targeting "your sessions on this machine" — same lace-boundary constraint as Q1. Payload: "the time that session's turn finished and a one-line status" — thin. Expires after 12 hours unwatched; must re-subscribe after every firing, a small but real per-notice tax given an overseer idles at the end of nearly every turn.

**Overseer `Stop` hook.** Verified/docs: input includes `transcript_path` and `last_assistant_message` (the final assistant text of the current turn) — a real, structured payload confirming the user's question. But it fires locally as a shell command, with no native path to another session's socket except an explicit script write to `$CLAUDE_CODE_MESSAGING_SOCKET`. The docs' auth-line convention is documented only for a script posting to its *own* session's socket — **whether a Stop-hook script in overseer A can write into conversationalist B's socket at all is unverified**, the load-bearing gap in this option. If it works, non-own-child inbound rules apply (a bypass-mode conversationalist holds it unless `crossSessionInbound: "accept"`, already recommended by the parent report).

**`Notification` hook.** Fires on `permission_prompt`, `idle_prompt`, `agent_needs_input`, `agent_completed`, etc., but is non-blocking/observational with no injectable output — same cross-socket-post caveat as `Stop`, no richer payload.

**Explicit `SendMessage` at turn end.** Cleanest option, using the one mechanism verified end-to-end: a short skill/`CLAUDE.md` addition instructing the overseer to `SendMessage` a structured summary whenever a turn concludes with something worth relaying. Cost: a convention, not a guarantee.

**`claude agents --json`/logs, devlog/arc-state.** Both remain valuable as pull-based "catch me up" reads (parent report's conclusion stands for the former; the latter lag real-time to iteration boundaries, not turn boundaries) — neither is a turn-end push trigger.

**Recommendation.** Primary: `SendMessage` convention, reusing the parent report's contract shape in reverse — `Intent: status|finding|decision|blocking-question`, `From: <overseer>`, `Summary: <2-4 speakable sentences>`, `Detail: <optional, for the ledger not speech>`. Backstop: `notify_when_idle`, re-subscribed per actively-tracked overseer, catching silent idles the convention misses. Skip `Stop`/`Notification` hooks for v0 given the unverified cross-socket gap; skip devlog/arc-state polling as a *push* trigger specifically. Written by the overseer inline (a trivial few-liner, not dispatched).

## 4. AskUserQuestion relay and triage

> Direct answer: today it's a local terminal dialog the conversationalist can't see or answer (cross-session messages "can't approve anything," per docs). A `PreToolUse` hook can match and deny it (confirmed empirically via third-party bug reports), but denial-reason propagation is documented as unreliable and a denied call can still render its widget client-side. **v0 uses a convention, not a hook**: overseers `SendMessage` instead of calling `AskUserQuestion` when a conversationalist is attached.

**Today, unmodified:** 1-8 questions/call, 2-4 options, an automatic "Other," blocking that session's terminal until answered locally. Not exposed to `ListAgents`/`SendMessage` by any mechanism found.

**Can anything external answer it?** Channels' permission-relay capability (docs, code.claude.com/docs/en/channels) is documented specifically for *permission prompts* (Bash/Edit approval), not `AskUserQuestion`; the same docs state that under `-p`/non-interactive channels mode, "tools that need terminal input, such as multiple-choice questions... are disabled so the session never stalls" — Anthropic's own answer to this exact problem is to turn the tool off, not relay it. Remote Control/peek-reply answering `AskUserQuestion`: no documentation found either way, unverified. `PreToolUse` interception: **verified/empirical**, not theoretical — [wxtsky/CodeIsland#340](https://github.com/wxtsky/CodeIsland/issues/340) documents a hook unintentionally denying every `AskUserQuestion` call, direct evidence the tool name is matchable. But [anthropics/claude-plugins-official#4260](https://github.com/anthropics/claude-plugins-official/issues/4260) reports `permissionDecisionReason` doesn't reach the model on deny, undermining "deny with a reason"; [nimbalyst/nimbalyst#1577](https://github.com/nimbalyst/nimbalyst/issues/1577) reports a denied call can still render its widget, confusing the user. These are current third-party bug reports, not confirmed-permanent limits.

**Recommendation: skip interception, use a convention.** Add to `oversee/SKILL.md`/`CLAUDE.md`: *"If a session named `conversationalist` (or `--name conversationalist*`) is reachable via `ListAgents`, prefer `SendMessage` over `AskUserQuestion` for anything the user could answer verbally: send `Intent: question` with the text and up to 4 short options, and wait for the reply as a normal inbound message."* Detection reuses `ListAgents`, already needed for `SendMessage`; falls back to ordinary `AskUserQuestion` when no conversationalist is present.

**Triage design.** Priority: tag blocking questions (`Blocking: true`) so they preempt status pings in speaking order. Batching: announce multiple overseers' questions together rather than picking one arbitrarily (reuses Q2's specialist/ledger pattern if concurrency grows). Spoken menus: reuse `AskUserQuestion`'s own 2-4-option, speakable shape rather than reformatting into prose. Default under silence: unverified/design, no source establishes one — recommend the question message itself state an explicit timeout-and-default ("if no reply in N minutes, proceed with option 1"), since neither `SendMessage` nor `AskUserQuestion` provides one natively. Verbatim echo: the relayed reply should carry the user's exact words, not just the conversationalist's option-mapping, so the overseer can sanity-check it (mirrors the parent report's outbound contract).

**Risk: permission laundering.** Docs are explicit: an inbound message "can't approve anything... can't answer a pending permission prompt on your behalf," and Claude is told never to change permission settings because another session asked. The recommended convention holds this automatically, since the conversationalist only relays questions/answers, never approvals. The sharper risk belongs to a future `PreToolUse`-interception design (not v0): an auto-deny-and-default-answer could look, from inside the overseer, indistinguishable from a real user answer — unless marked as relayed, which the harness's own message framing ("the message came from another session, not from you") already provides for the `SendMessage` path, a second reason to prefer it over hook interception.

## Recommended minimal bridge v0

1. **Audio-out stays single-source.** Only the conversationalist calls `converse()`; no cross-session conch coordination needed, since there's only one speaker. Per-overseer voice selection (Q0) is an optional nicety, not required.
2. **No lace mount changes.** Run the conversationalist on the bare host, outside any lace container, given Q1's structural finding and the docs' explicit "container and host can't reach each other." Don't attempt the `/run/user/1000` mount without dedicated SELinux/tmpfs testing.
3. **Ledger file, no specialists.** One JSON file per actively-conversing overseer under `.claude/conversationalist/ledger/<name>.json`, read/written inline by the top level. Revisit specialists only if a relationship grows large enough to make re-reading costly.
4. **Turn-end: `SendMessage` convention plus `notify_when_idle` backstop.** A short addition to `oversee/SKILL.md` for the outbound contract; the conversationalist re-subscribes `notify_when_idle` per actively-tracked overseer.
5. **Question relay: the attached-conversationalist convention, not a hook.** Same skill addition point: `ListAgents`-detect, then prefer `SendMessage` over `AskUserQuestion`.

Net new artifacts: one conversationalist skill file (parent report), a few lines in `oversee/SKILL.md`/`CLAUDE.md` for points 4-5, a ledger-file convention. No hooks, no lace changes, no VoiceMode fork.

## Empirical tests to run

1. The devcontainer cross-boundary test from Q1 (5 steps above), without messaging any real overseer.
2. `wait_for_conch=false` default behavior when the conch is busy: read `converse.py:3115-3151` forward, or observe directly.
3. Whether a `Stop`-hook script in one session can post into a *different* session's socket (Q3's load-bearing gap): a scratch two-session test.
4. `PreToolUse` matching/denying `AskUserQuestion` on this Claude Code version: whether `permissionDecisionReason` reaches the model and whether the widget still renders on deny (issues [#4260](https://github.com/anthropics/claude-plugins-official/issues/4260), [#1577](https://github.com/nimbalyst/nimbalyst/issues/1577)) — only relevant if interception is revisited past v0.
5. End-to-end `ListAgents`-based "attached conversationalist" detection with a real named session.

## Unverified claims

- Exact fallback behavior of `converse(wait_for_conch=false)` when the conch is already held.
- Whether a per-call `voice` keyed to sender identity is workable without testing against the configured TTS provider's actual voice list.
- Whether Claude Code prunes a `ListAgents` entry whose registered socket is unreachable (whether a lace-contained overseer even *appears* before `SendMessage` fails).
- Whether a `Stop`/`Notification`-hook script in session A can write into session B's inbox socket at all; the docs' own-child section is written for a script posting to its own session, not cross-session posting.
- Whether Remote Control's client works normally from inside a lace container (no obvious blocker, not tested).
- Whether lace's mount tooling could safely bind-mount a live, growing `/run/user/1000/cc-socks` tmpfs with correct SELinux relabeling and rootless-podman UID mapping; not attempted here.
- Whether peek-reply in agent view can answer a pending `AskUserQuestion`; no documentation found either way.
- Current reliability of `PreToolUse` denial-reason propagation and UI-widget suppression for a denied `AskUserQuestion`, beyond the specific issues cited (dated against a specific release, e.g. Claude Code 2.1.261, and may already be fixed).
