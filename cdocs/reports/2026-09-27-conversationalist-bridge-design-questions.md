---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-27T11:26:00-07:00
task_list: cdocs/audio-interaction
type: report
state: live
status: review_ready
tags: [analysis, voice, voicemode, messaging, devcontainer]
---

# Conversationalist bridge: five design questions, answered from source

> BLUF: The conch is a real single-speaker lock (verified/source) but scoped to one host's `~/.voicemode/conch` file: it arbitrates VoiceMode agents sharing one mic, not overseers sharing a speaker, and has no cross-session-messaging awareness.
> Lace devcontainers don't block same-machine messaging by policy, but they break it structurally: the session registry is shared via the bind mount, the inbox socket is not, and even bind-mounting the socket directory would plausibly still be refused at the sender by Claude Code's own foreign-PID-domain and socket-ownership checks.
> A per-session specialist subagent is right only as an in-process ledger/summarizer, never as the delivery boundary, since inbound `SendMessage` always lands on the top-level session first and queues behind a blocking `converse()` listen regardless of specialist topology.
> For turn-end context, an overseer's `Stop` hook posting `last_assistant_message` into the conversationalist's socket is documented, deterministic, and costs zero overseer tokens: a stronger v0 default than the `SendMessage` convention, provided it is filtered and stamped with a sender name.
> For `AskUserQuestion`, three real tiers exist (a written convention, a small `PreToolUse` deny-and-redirect hook, and a full answer-relay hook via `allow` + `updatedInput.answers`); v0 should pick one deliberately rather than defaulting to the weakest by omission.

## Context / Background

[`2026-09-27-voicemode-deep-dive.md`](2026-09-27-voicemode-deep-dive.md) established the shape: one dedicated conversationalist session running VoiceMode, idle-waking on `SendMessage`.
[`2026-09-27-claude-code-inter-session-messaging.md`](2026-09-27-claude-code-inter-session-messaging.md) inventoried Claude Code's messaging affordances.
This report answers five follow-up questions, reading VoiceMode source at the parent report's clone commit, `126d15e` (`build/research/voicemode/`, gitignored), and lace findings from `/var/home/mjr/code/weft/lace/main` plus live, read-only inspection of the host and its running lace containers.

## 0. Audio-out control and the conch

> Direct answer: VoiceMode has a narrow playback-control channel (pause/resume/stop/skip, opt-in) and a real single-speaker lock (the conch), but neither knows about Claude Code sessions.
> The conch solves "don't let two VoiceMode agents step on one mic/speaker," not "arbitrate several overseers speaking to one user."

**TTS/playback control, verified/source.**
`voice_mode/control_channel.py` defines a transport-agnostic state machine (`running`/`paused`/`stopped`/`skip_forward`, [`control_channel.py:44-51`](https://github.com/mbailey/voicemode/blob/master/voice_mode/control_channel.py#L44)) driven by JSON commands (`pause`/`resume`/`stop`/`skip_forward`/`skip_back`, `control_channel.py:58-76`).
It ships no listener beyond the socket primitive and is off by default (`VOICEMODE_CONTROL_CHANNEL_ENABLED=false`, parent report).
`stop`'s free-text `message` is never surfaced to the model: only a fixed, server-owned `hint` table (`CONTROL_INTENTS`: `switch-to-text`, `brevity`, `quiet`, `pause-timeout`, [`control_channel.py:103-108`](https://github.com/mbailey/voicemode/blob/master/voice_mode/control_channel.py#L103)) can inject a sentence, closing a prompt-injection path (security comment, `control_channel.py:90-102`).
Any future "relay a stop instruction" design should route through this allowlist, not free text.

`converse()` takes call-level `voice`/`speed` ([`converse.py:546,551`](https://github.com/mbailey/voicemode/blob/master/voice_mode/tools/converse.py#L546)); `wait_for_response=false` (default `true`) makes a call speak-only, no microphone access (module PRIVACY note, `converse.py:3080`).
**Distinct voices per overseer: unverified/design.**
`voice` is a plain per-call string with no session-identity tie, but nothing stops the conversationalist from picking one keyed off the sender's name, a policy its own skill would implement.
The conch's own `voice` field exists so *another agent* can read the current speaker's voice and avoid a clash, evidence the pattern is designed for peer VoiceMode agents, not Claude Code sessions.

**The conch, in depth.**
Module docstring: it's a lock file "to indicate when a voice conversation is active," so "other processes... can check whether to suppress their audio output" ([`conch.py:1-4`](https://github.com/mbailey/voicemode/blob/master/voice_mode/conch.py#L1)).
`Conch` ([`conch.py:102`](https://github.com/mbailey/voicemode/blob/master/voice_mode/conch.py#L102)) is a `~/.voicemode/conch` file guarded by a kernel `flock` during an active call (stale ceiling `CONCH_LOCK_EXPIRY`, 120s default), plus an opt-in "hold across turns" mode (flock released, a short refreshed TTL, `CONCH_HOLD_EXPIRY` 10s default or a per-call `conch_hold_timeout` override).
A FIFO waiter registry, `ConchQueue`, offers `wait` (block, capped at 25s over MCP) and `callback` (register-and-return, delivered out-of-band); `free` is true only when there's neither a live holder nor an unclaimed grant, avoiding a race where a second waiter steals a just-issued grant.
`converse()` exposes queueing via `wait_for_conch`/`conch_mode`/`hold_conch`/`conch_hold_timeout` ([`converse.py:2948-2952`](https://github.com/mbailey/voicemode/blob/master/voice_mode/tools/converse.py#L2948)).
**Verified/source:** the `wait_for_conch=false` default fallback is documented in `converse.py:3026-3029`: "If another agent is speaking, return a status immediately WITHOUT queuing; the status names the holder and tells you how to queue."
A remote-agent front end also exists (`tools/conch.py`, keyed by caller-supplied `session_id`, since a remote agent has no host PID).

**Could overseers speak short notices while the conversationalist holds the conch? Design answer: technically via the queue, but wrong for this architecture.**
It only works if overseers also run VoiceMode's `converse` tool, which the parent report explicitly avoids (token cost, duplicated STT/TTS dependencies), and the conch only arbitrates one host's `~/.voicemode/conch` file, disconnected from the `SendMessage`/`ListAgents` graph this design is built on.
**Recommendation: keep audio-out concentrated in the conversationalist; overseers `SendMessage` text, never call `converse()` directly.**

**Granularity from shipped primitives:** interrupting speech (`skip_forward`, needs the control channel plus a trigger, none ships); "shorter please"/"quiet" (the `stop` hint table already includes both); replay last (`skip_back`, a documented history-buffer request); per-source mute (no equivalent, a skill-level policy, since VoiceMode has no concept of "source").
Three of four need the control channel (off by default) plus an unwired trigger; per-source mute needs neither.

## 1. Devcontainers and cross-session messaging

> Direct answer: same-machine messaging is rooted at `/run/user/<uid>` (or a `/tmp/cc-socks-<uid>` fallback), not `~/.claude`.
> Lace's feature bind-mounts `~/.claude` but not `/run/user/1000`.
> Verified on this host: the registry is visible across the boundary, the socket is not, and even fixing the mount would plausibly still fail at the sender's own endpoint checks.

**Where sessions register.**
Verified/empirical (Fedora, uid 1000): each session writes `~/.claude/sessions/<pid>.json` plus a `<pid>.<hash>.key` auth file, e.g.:

```json
{"pid":1413851,"pidDomain":"linux:a6d8486bf8314670b75c79adf53a6a46:pid:[4026531836]",
 "messagingSocketPath":"/run/user/1000/cc-socks/1413851.sock","name":"clauth-audio"}
```

`pidDomain` is `linux:<machine-id-prefix>:pid:[<PID-namespace-inode>]`, confirmed by cross-checking `/etc/machine-id` and `readlink /proc/self/ns/pid` against this JSON: Claude Code's own PID-collision guard, since a bare PID isn't stable across containers.

**Where sockets live, and why lace's mount misses them.**
Verified: `$CLAUDE_CODE_MESSAGING_SOCKET` resolves to `/run/user/1000/cc-socks/<pid>.sock`; docs confirm a `/tmp/cc-socks-<uid>` fallback.
Lace's `claude-code` feature (`devcontainers/features/src/claude-code/devcontainer-feature.json`) declares only two mounts: `~/.claude` and `~/.claude.json`.
Verified via `podman inspect jif`: `/home/mjr/.claude -> /home/ubuntu/.claude ([rbind])`, a real recursive bind mount, so `~/.claude/sessions/*` is one shared directory across host and every lace container.
Confirmed: a container (`weftwise`) with a live `claude --resume` process (PID `3002342`, `pidDomain: linux:c45dc044...:[4026533606]`, differing from the host's `a6d8486b...:[4026531836]`; `podman inspect` shows `PidMode: private`, `UsernsMode: private`) has its `~/.claude/sessions/3002342.json` readable straight from the host filesystem.
But `/run/user/1000` isn't mounted by lace: inside `weftwise`, `/run/user/1000/cc-socks/3002342.sock` exists in its own private tmpfs; on the host, that path is "No such file or directory."
The registry entry crosses the boundary; the socket it names does not, and docs corroborate directly: "A session inside a container and a session on the host can't reach each other. Two sessions inside the same container can still message each other" (code.claude.com/docs/en/cross-session-messaging) — the conversationalist and any lace-contained overseer are always different "machines," regardless of what the kernel shares.

**Bind-mounting the socket directory would plausibly still be refused at the sender, not just blocked by a missing mount.**
The docs' errors page lists sender-side endpoint checks: the connected endpoint is not the expected process, its identity could not be read, or it is not owned by this user.
Across a private PID namespace the host sees the container's process under a different PID than the registry's `3002342`, and rootless-podman remapping can also fail ownership, so even with `/run/user/1000/cc-socks` bind-mounted a host `SendMessage` would plausibly still be refused: the mechanism behind the docs' "can't reach each other," not merely a missing mount.
The installed `claude` binary (2.1.283) carries explicit foreign-PID-domain handling (`foreign_pid_space`, `isHeldInAnotherPidDomain`), consistent with a designed rejection.

**SELinux is about `connectto`, not file labels.**
Connecting across the container boundary is governed by the `unix_stream_socket connectto` permission between the two process domains (`container_t` to the host's `unconfined_t`), not by relabeling the socket file, the same restriction `docker.sock`/`podman.sock` access hits (Fedora typically needs `--security-opt label=disable`).
A raw `socat` post bypassing Claude Code's own sender checks would still hit this boundary first.

**Own-child verification does not save this either, but for a different reason than PID 1.**
Claude Code is not PID 1 in lace containers (`weftwise`'s PID 1 is a shell init loop), so it retains `/proc` evidence for its own children and the "PID 1" token fallback doesn't apply; the `ubuntu`-owned files observed earlier are specific to `jif`, `weftwise`'s user is `node`.
Either way it's irrelevant here: a hook posting from inside the container into a socket on the *host* is never that host session's own child, independent of container or user.

**Remote Control fallback, and a registry-collision risk.**
Same-machine delivery uses the local socket exclusively; there's no automatic fallback to Anthropic-server routing when the local path fails.
Because the container's registry entry lives in the *same shared* `~/.claude/sessions` directory as host entries, `ListAgents` may present it as an ordinary local session rather than routing it through Remote Control, even though it isn't reachable locally.
Unverified whether Remote Control's client works from inside a lace container, and whether such a session shows up once (as remote) or twice (a broken local entry plus remote) in `ListAgents`.

**Concrete test:** start a bare session inside a lace container, note its name via `/status`; from the host run `/list-agents` and check whether/how many times it appears; if it appears locally, attempt `SendMessage` and capture the refusal against the errors-doc's checks; as a positive control, start a second session *inside the same container* and confirm it can message the first.

## 2. A specialist subagent per connected session

> Direct answer: worth building only as an in-process ledger/summarizer resumed by name, never as the message receiver, since inbound traffic always lands on the top-level session first and queues behind a blocking listen regardless of specialist topology.

Per docs: "The receiving Claude reads the message between tool calls during an active turn," meaning the delivery target is the session owning the inbox socket/registry entry.
A subagent has neither; it's addressed only via in-process `SendMessage` to a named background subagent, a different mechanism from the peer-session socket, so an overseer's message to "the conversationalist" is always received by the top level.
The constraint that actually bounds this design further: while the top level is blocked inside a long `converse()` listen, any inbound message queues until that call returns, regardless of how many specialists exist underneath; a specialist cannot shorten that wait, since it never touches the delivery path, only what happens to the message once the top level's next turn begins.

Given that, the useful pattern is orchestration-discipline.md's Pillar 3 (durable specialists, resume-by-name, one-per-workstream), applied with "workstream" meaning "connected overseer": the top level stays a thin router, and on an inbound message its next action is a one-line in-process `SendMessage` to a specialist named for that overseer, which owns a per-overseer ledger file (satisfying Pillar 1b's single-writer guarantee "by construction") and carries that overseer's running context across turns so the top level never re-explains it.
**The bound**, per Pillar 3: at most one specialist per *actively conversing* overseer, spun up lazily on first traffic, spun down after an idle window; a voice conversation is inherently serial, so realistic concurrency (1-3) sits well inside the bound.

**Latency cost.**
Every inbound message pays an extra in-process hop before `converse()` can speak it, on top of the queuing delay above.
**Recommendation: gate the hop on complexity.**
A short status ping should be spoken directly by the top level (a "trivial few-liner," per Pillar 1's carve-out); route to the specialist only for long/structured messages, follow-ups needing prior context, or multi-overseer triage (reusable for Q4's batching).

**Cheaper alternative, and the v0 pick.**
A per-session ledger file with no specialist subagent: the top level reads/appends a small JSON file per overseer inline, strictly cheaper than a specialist hop and sufficient at 1-3 concurrent overseers, at the cost of re-reading the relevant slice each time instead of a specialist reasoning over resumed context.
`/compact` cadence (Pillar 2) applies to the conversationalist's own session regardless.
**Recommendation for v0: skip specialists; use the ledger-file pattern**, revisiting specialists only if a relationship grows large enough that re-reading its ledger slice each turn becomes its own cost.

## 3. Turn-end context flow

> Direct answer: an overseer's `Stop` hook posting `last_assistant_message` into the conversationalist's socket is documented, deterministic, and free of overseer tokens; it is the stronger v0 default, with the `SendMessage` convention reserved for content the model itself judges worth escalating.

**The `Stop` hook and cross-socket posting are both real and already load-bearing in the parent reports.**
`Stop`'s input schema includes `transcript_path` and, per the hooks docs, `last_assistant_message` ("use this field rather than reading `transcript_path`").
The inbox-socket docs open with "Read this section... when you want a script or hook to post into a session," and every arriving post runs through the same inbound controls, with an own-child exception meaningful only because non-child posting is allowed at all: "When Claude Code can verify neither way, it treats the message like any other that asserts no permission class."
Nothing restricts a poster to its own session's socket; the auth-line token only scopes an *own-child* claim, and the line itself is optional on Linux.
The parent deep-dive's hotkey wake path and the messaging report's "direct inbox-socket posting" row both already rely on this non-child posting path, so treating it as an unresolved gap here contradicts the same arc's own findings.
The wire format is the same one the binary's `--debug` inbox log documents: `{ echo '{"type":"auth","token":"<token>"}'; echo '{"type":"user","message":{"role":"user","content":"<text>"}}'; } | socat - UNIX-CONNECT:<sock>`, auth line optional on Linux.

**So a `Stop` hook in the overseer can post the turn's final text into the conversationalist's socket for zero overseer tokens**, with the socket path published by a `SessionStart` hook, as the deep-dive's hotkey-wake sketch already does.
Weighed fairly: `Stop` fires on every overseer turn, including each subagent-completion wake in an AFK arc, so it needs a filter (post past a marker, only on a question, or rate-limited) or it floods the conversationalist; a raw post carries no sender name, so the hook must stamp `From: <overseer>` itself; delivery still depends on `crossSessionInbound: "accept"`; and it does not cross the lace boundary, the same limitation `SendMessage` has (Q1).
By contrast, `SendMessage` is model-judged and spends overseer tokens per message, but yields a structured, content-aware summary rather than a raw transcript tail.

**Recommendation: `Stop` hook as primary push for status/liveness, `SendMessage` for content the model judges worth escalating** (findings, decisions, questions): a peer pairing, since the hook is free but dumb and the convention is smart but costly and only as reliable as the model's judgment.

**`Notification`, corrected:** it cannot inject a decision into its own session's turn, but its script can post to another session's socket exactly like `Stop`'s can; the reason to still prefer `Stop` is a thinner payload, not an inability to post.

**`notify_when_idle`, cost restated:** each notice starts a new turn in an idle conversationalist, which typically re-subscribes in that same turn, a small but real tax, and drops the status entirely under `hold` on either side.
If `Stop` is adopted, it becomes largely redundant for hook-equipped overseers, worth keeping only as a fallback for those without the hook.

**Payloads.**
`Stop`-hook: a short, filtered shell script stamping `From:`.
`SendMessage`: `Intent: status|finding|decision|blocking-question`, `From:`, `Summary: <2-4 speakable sentences>`, `Detail: <optional, ledger-only>`.

## 4. AskUserQuestion relay and triage

> Direct answer: three real tiers exist, not one.
> A convention (overseers `SendMessage` instead of asking), a small `PreToolUse` deny-and-redirect hook enforcing that convention deterministically, and a full answer-relay hook that lets the overseer keep its native tool by supplying `updatedInput.answers`.
> v0 should pick deliberately among these three, not default to the convention by omission.

**Today, unmodified:** the hooks docs list `AskUserQuestion` outright as a matchable `PreToolUse` tool, asking one to four multiple-choice questions per call, each with a handful of short options plus an automatic "Other," blocking that session's terminal until answered locally, and not exposed to `ListAgents`/`SendMessage` on its own.

**Tier 1: convention.**
Add to `oversee/SKILL.md`/`CLAUDE.md`: if a session named `conversationalist` (or `--name conversationalist*`) is reachable via `ListAgents`, prefer `SendMessage` over `AskUserQuestion` for anything the user could answer verbally.
Cheapest, weakest to enforce, working only if the model reliably follows the written rule.

**Tier 2: a deny-and-redirect `PreToolUse` hook.**
A roughly ten-line hook matching `tool_name == "AskUserQuestion"`, active only when a conversationalist socket path is published, returning `permissionDecision: "deny"` with `permissionDecisionReason: "a voice conversationalist is attached; SendMessage the question to it instead."`
A `deny` reason is shown to Claude, deterministically forcing the fallback the convention only hopes for, at the cost of one small hook file.

**Tier 3: a full answer-relay hook.**
The hooks docs document answering `AskUserQuestion` from a hook directly: `permissionDecision: "allow"` paired with `updatedInput` echoing the original `questions` plus `answers: {"<question>": "<label>"}` runs the tool with no local prompt.
A relay hook posts the question into the conversationalist's socket, waits on a reply file, and returns the answer via `updatedInput.answers`, within the default 600s command-hook timeout (configurable).
Keeps the overseer's native tool and framing, at the highest dev cost of the three; `defer` is `-p`-only, unusable by an interactive overseer to buy extra time.

**Corrected reading of the cited issues, since the previous pass misread all three.**
[claude-plugins-official#4260](https://github.com/anthropics/claude-plugins-official/issues/4260) is a bug in the third-party **hookify** plugin's own deny branch, and cites the docs stating the reason reaches the model: not evidence Claude Code drops it.
[nimbalyst#1577](https://github.com/nimbalyst/nimbalyst/issues/1577) is a rendering bug in Nimbalyst's own Electron UI, not the Claude Code terminal, and states "Claude Code honours the deny."
[wxtsky/CodeIsland#340](https://github.com/wxtsky/CodeIsland/issues/340) is a closed third-party-bridge bug; the hooks docs already list `AskUserQuestion` as a matchable tool outright, so no third-party evidence is needed for matchability.

**Triage, across all three tiers:** tag blocking questions (`Blocking: true`) to preempt status pings; batch multiple overseers' questions together rather than picking one arbitrarily (reuses Q2's ledger pattern); reuse `AskUserQuestion`'s own short-option, speakable shape; echo the user's exact words back, not just the option-mapping.
Default under silence: unverified/design, no source establishes one; the question message should state an explicit timeout-and-default itself.

**Risk: permission laundering, tier-specific.**
Docs state an inbound message "can't approve anything... can't answer a pending permission prompt on your behalf," which holds automatically for tiers 1-2 (plain-text relay only).
Tier 3 differs: the overseer sees a normal native tool result via `updatedInput.answers`, provenance otherwise invisible, so it should prefix each answer, e.g. `"<label> (relayed by voice conversationalist; user said: '...')"`.

## Recommended minimal bridge v0

Answering the review's core objection directly: **lace-contained overseers are out of reach for v0 as designed, and this must be stated rather than dropped silently.**
Options, cheapest first:
- **(a) Run voice-attached overseers on the host.** Zero new plumbing; `SendMessage`/`Stop`-hook posting both work as documented between host sessions.
- **(b) A file relay through the one thing lace already shares: the `~/.claude` bind mount.** A container overseer's `Stop` hook writes a line to `~/.claude/conversationalist/inbox/<overseer>.jsonl`; a host-side watcher tails it and posts into the conversationalist's socket using the same wire format as the direct `Stop`-hook path. The reverse direction is a small container-side poster into the overseer's own *local* socket, entirely inside that container. Uses only documented socket posting plus the existing mount, no `connectto`/SELinux work, no dependency on the sender-endpoint checks a direct cross-boundary `SendMessage` would hit.
- **(c) Remote Control on both ends.** Unverified (Q1); adds server-hop latency and an unconfirmed in-container client path.

1. **Audio-out stays single-source:** only the conversationalist calls `converse()`.
2. **Pick a stance on lace-contained overseers rather than defaulting to host-only:** (a) is cheapest; (b) is the only option reaching a session like the user's live `weftwise` container without new mounts or SELinux changes.
3. **Ledger file, no specialists:** one JSON file per actively-conversing overseer under `.claude/conversationalist/ledger/<name>.json`, read/written inline by the top level.
4. **Turn-end: adopt the `Stop` hook as primary**, `SendMessage` for model-judged findings/decisions/questions, `notify_when_idle` only as a fallback.
5. **Question relay: pick one of Q4's three tiers deliberately**, tier 2 at minimal extra cost for deterministic enforcement.

**Shared prerequisite:** the conversationalist's `SessionStart` hook publishing its socket path to a known file, needed by the `Stop`-hook path, the file relay, and any hotkey wake path alike.

## Decision points

The review raised three open questions; recommendations follow, referencing the option letters/tiers above.

1. **Where do voice-attached overseers run** (host-only / often lace-contained / both)?
   Recommendation: both, per v0 options (a)+(b): live sessions include lace-contained overseers today, and the file relay is small enough to build alongside the host-only path.
2. **Turn-end push mechanism for v0** (Q3's a/b/c)?
   Recommendation: (c), the `Stop` hook for routine status plus `SendMessage` for content needing the model's own judgment.
3. **`AskUserQuestion` handling for v0** (Q4's tiers 1/2/3)?
   Recommendation: tier 2, which costs one small hook file over the convention and removes dependence on the model following instructions; tier 3 is worth it once voice question-answering is frequent.

## Empirical tests to run

1. The devcontainer cross-boundary test from Q1 (registry-appears-once-or-twice check included), without messaging any real overseer.
2. A single `socat` post of the documented wire format into a scratch session's own socket, confirming delivery and the inbound-controls outcome.
3. The file-relay path from v0 option (b): a scratch container `Stop` hook writing to the shared mount, a host-side watcher posting it onward.
4. Whether a host `SendMessage` to a bind-mounted container socket is refused, and against which sender-endpoint check.
5. End-to-end `ListAgents`-based "attached conversationalist" detection with a real named session.

## Unverified claims

- Whether Claude Code prunes a `ListAgents` entry whose registered socket is unreachable.
- Whether Remote Control's client works from inside a lace container, and whether such a session appears once or twice in `ListAgents`.
- Whether lace's mount tooling could safely bind-mount a live, growing `/run/user/1000/cc-socks` tmpfs past the `connectto` boundary and sender-endpoint checks; not attempted, and now expected to fail regardless.
- Whether peek-reply in agent view can answer a pending `AskUserQuestion`.
- The exact default-timeout-and-default-answer convention for a batched, unanswered voice question; no source establishes one.
