---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-28T11:02:34-07:00
task_list: voice/converser-lace-feature
type: report
state: live
status: review_ready
last_reviewed:
  status: accepted
  by: "@claude-opus-5-5"
  at: 2026-09-28T11:25:49-07:00
  round: 2
tags: [analysis, voice, converser, architecture, android]
---

# Splitting converser: a host-side audio broker instead of raw mic/speaker in the container

> BLUF(sonnet/voice/converser-lace-feature): A host-side "audio broker" behind a narrow API (`speak`, `listen`, `converse`, `barge_in`) removes the container's raw mic/speaker file descriptor and the PortAudio/ALSA/pulse-control stack.
> It does not restore SELinux confinement: the devcontainer CLI already applies `--security-opt label=disable` to every podman container regardless of design (vetting report, finding A14), so that line is not a broker-specific cost or gain anywhere here.
> What the container keeps: on-demand room transcription and arbitrary TTS, the same functional capability delivered over a narrower channel.
> VoiceMode already ships a working broker, `voicemode serve`, but its access control is thin: the default IP allowlist is loopback plus all of RFC1918 with no token, and a `pasta:-T` forward arrives as `127.0.0.1` (empirically verified), so the allowlist cannot distinguish a container from the host or one container from another.
> The bearer token is the only real gate, readable by every process in the container holding it, and the default tool set exposes host service control and an OpenAI fallback, both of which the deployment must close.
> This aligns with the parallel fork-complexity report's recommendation: upstream `serve` unmodified, one process per container, token-gated, `VOICEMODE_TOOLS_ENABLED=converse` only.
> For Android, VoiceMode's own cloud relay (VoiceMode Connect) and the maintainer's roadmap are the strongest prior art, ahead of Wyoming/Home Assistant, whose Companion app does not actually speak Wyoming.
> Recommendation: treat the accepted proposal's v0 audio work and a per-container `voicemode serve` split as near-peers, not option 0 as an obvious default, and let the smallest experiment below decide.

## Context / Background

The accepted proposal, [`cdocs/proposals/2026-09-28-converser-lace-feature.md`](../proposals/2026-09-28-converser-lace-feature.md), packages an audio recipe into a lace devcontainer feature, and its Security Analysis treats "every in-container process/agent gains mic+speaker access" and "`label=disable` weakens SELinux confinement... for every process" as accepted, inherent costs.
This report asks whether those costs can be removed by moving capture, VAD, and STT/TTS behind a narrow host-side API, with a later Android satellite as the reason a clean boundary is worth building now.

Two parallel reports bear directly on this one, referenced throughout rather than re-derived.
[`2026-09-28-voicemode-fork-complexity.md`](2026-09-28-voicemode-fork-complexity.md) evaluates host `serve` against the accepted proposal and recommends the same shape this report converges on, its option (a).
[`2026-09-28-converser-options-vetting.md`](2026-09-28-converser-options-vetting.md) found `label=disable` is not a project-opted-in cost: the devcontainer CLI 0.87.0 injects it into every podman-on-Linux container by default, verified live against `weftwise` and `jif` (finding A14), which changes section 2's security-gain analysis.

Read-only: no host services started, no lace files changed, no settings modified.
VoiceMode's source was read from the existing clone at `/var/home/mjr/code/weft/clauthier/main/build/research/voicemode` (commit `126d15e`), not re-cloned.

## 1. Split architectures: what crosses the boundary, and how

Every option shares one shape: the container gets a small, fixed API with no raw audio, and the host process alone touches PortAudio, VAD, or STT/TTS.
A minimal API trims VoiceMode's own `converse` (~25 parameters, `converse.py:4308`) to four calls: `speak`, `listen`, `converse`, plus events `user_started_speaking`/`barge_in`.
What differs is the transport.

**Unix socket, bind-mounted into the container.**
Mount one broker socket (e.g. host `/run/user/1000/audio-broker.sock`), the `runArgs --mount` pattern the accepted proposal already uses for the pulse socket, verified for a narrowly-scoped socket, not a whole runtime directory.
Permissions gate it as any bind-mounted socket does: `srw-rw-rw-`, or a tighter `0660` under a dedicated broker UID.
The cost is an in-container stdio-to-socket relay, since no MCP client speaks Unix sockets natively; a wrapper around `socat - UNIX-CONNECT:...` (the same pattern already used for a wake-hotkey path) turns it into one.
Advantage: no network stack, so the `pasta:-T` loopback-peer ambiguity (below) disappears with the pulse mount.
It does not avoid `label=disable`, applied to the whole container regardless of what is mounted, and does not automatically avoid the SELinux `connectto` problem either, since a socket crossing the `container_t`/`unconfined_t` boundary needs `label=disable` or a custom policy no matter which process created it.
Nor does it reuse VoiceMode's `serve` command, which speaks HTTP/SSE only; the broker, or a socket-to-HTTP shim, needs writing.

**HTTP/WebSocket over `pasta:-T`.**
The transport the accepted proposal already uses for whisper.cpp/Kokoro, verified end to end: a wildcard-bound host listener is `curl`-reachable from the container, a `127.0.0.1`-bound one is refused absent the forward, and succeeds with `pasta:-T,<port>`.
A broker speaking plain HTTP (`POST /speak`, `POST /listen`, an `/events` stream for `barge_in`) is reachable with the same `runArgs` line, pointed at a new port.
One caveat applies to every option on this transport, including the MCP-server option below: `pasta` makes the host-side connection itself, so the peer address any host listener sees is always `127.0.0.1` regardless of source container (reviewer-verified empirically, this host), so an IP allowlist alone cannot tell one project's container from another's or from a host process, and whatever auth runs here has to be a real per-container secret, not a source-IP rule.

**gRPC.**
Buys typed schemas and native streaming, useful for `barge_in` events, at the cost of a protobuf toolchain on both ends.
Nothing in the existing recipe speaks gRPC; worth it only once the API outgrows the four calls above.
Unverified: whether `pasta:-T` forwards gRPC's HTTP/2 framing, only plain HTTP/1.1 has been tested here.

**D-Bus: probably no.**
The natural host-native IPC bus, but it does not cross the container boundary cleanly: its socket sits alongside sockets already flagged for mount exclusion, and mounting it hands the container "connect to any service on the bus," far larger than audio.
No gain over a Unix socket for this narrow a call set.

**An MCP server hosted on the host, exposed to the container.**
Removes VoiceMode from the container entirely with the least new code, since VoiceMode already implements it.
`voicemode serve` (`cli.py:2016-2090`) starts VoiceMode's own FastMCP server over HTTP/SSE (`streamable-http` recommended), with `--host`/`--port` (default `127.0.0.1:8765`) and three all-opt-in controls: an IP allowlist, a URL `--secret` segment, and `--token` bearer auth (`serve_middleware.py`).
With no flags it binds loopback and admits `LOCAL_CIDRS` (all of RFC1918 plus `127.0.0.0/8`, `::1/128`, `cli.py:2118-2150`, `config.py:1645-1664`) with no token; `--allow-tailscale`/`--allow-anthropic` are separate opt-in flags.
Because `pasta:-T` traffic arrives as `127.0.0.1` regardless of source, that default allowlist admits every forwarded container and every host process by IP, distinguishing nothing.
**`--token` is the only control that actually discriminates**, and it is a shared secret: whatever process in the container holds it can drive the mic, the same reach the pulse socket already grants any same-UID process today.
Per-project isolation follows directly: one `serve` process, one port, one token, per container, each getting its own `pasta:-T,<port>` entry and its own `--mcp-config` token, instead of running VoiceMode in-container at all.
This does not remove `label=disable`, applied by the devcontainer CLI regardless.

**Tool scoping needs a host-side fix, not a container-side one.**
`--strict-mcp-config` only restricts the launcher's own client. Any process in the container can still POST raw MCP JSON-RPC at the forwarded port and call whatever the host `serve` process registers.
What it registers is `VOICEMODE_TOOLS_ENABLED` in the host process's own environment, and the unset default is `{converse, service}` (`tools/__init__.py:116-120`).
`service` exposes `start`/`stop`/`restart`/`enable`/`disable`/`logs` against host `whisper`/`kokoro`/`voicemode` systemd units, control the in-container design never grants today, and it chains with `STT_BASE_URLS`'s default fallback (`config.py:777-778`, `...,https://api.openai.com/v1`): a container process can stop `whisper` then `converse()`, and mic audio fails over to OpenAI if the host has a key set.
Required, not optional: run host `serve` with `VOICEMODE_TOOLS_ENABLED=converse` and `VOICEMODE_STT_BASE_URLS`/`VOICEMODE_TTS_BASE_URLS` pinned to loopback only.
`converser-io`'s write-path scoping is unaffected, since it touches container-local ledger/reply files, not audio.
> NOTE(sonnet/voice/converser-lace-feature): the fork-complexity report reaches this same design independently as its recommended option (a), with the same tool-scoping and token requirements, and found `serve` also carries an open concurrency bug with no maintainer response ([#521](https://github.com/mbailey/voicemode/issues/521)/[#522](https://github.com/mbailey/voicemode/issues/522), fix [PR #523](https://github.com/mbailey/voicemode/pull/523) unmerged) that wedges the conch when two simultaneous clients hit one process.
> That does not bite the one-converser-per-container shape both reports recommend, since each `serve` process then has exactly one client; it would bite a later design sharing one process between an Android client and the container converser.

## 2. Security gain versus the current design

The accepted proposal's threat table names two costs.
Only "every in-container process/agent gains mic+speaker access" is genuinely broker-removable.
"`label=disable` weakens SELinux confinement" is not: the devcontainer CLI 0.87.0 injects it into every podman-on-Linux container by default, verified live against `weftwise` and `jif` (vetting report, finding A14), regardless of whether the project mounts a pulse socket.
No option in section 1 restores SELinux type enforcement, since `label=disable` comes from the CLI regardless of `runArgs`.
Correcting the accepted proposal's own threat table on this point is out of scope here.

What a broker genuinely removes: the container's file descriptor to the pulse socket (raw PCM capture/playback, plus pulse's own module-loading/control protocol, larger than audio I/O alone), and the in-image PortAudio/ALSA/`libpulse` stack.

What the container keeps, under any option: on-demand microphone access as text.
`converse()` with `disable_silence_detection=true` and a caller-set `listen_duration_max` (default 120s) is ambient room transcription in everything but name, plus arbitrary TTS through the speaker.
Under the unscoped `serve` default, it also keeps host service control.
So "every in-container process/agent gains mic+speaker access" does not disappear as a row.
It degrades to "every in-container process can transcribe the room and speak," likelihood staying High, since the broker's token is as widely readable within the container as the pulse socket is today.
Other named risks are unaffected by where capture happens: `AskUserQuestion` reply-file forgery and inbox-socket injection are about the container's own filesystem surface, and acoustic injection persists because the broker still hands the container an unvetted transcript, mitigated only at the prompt level.

The genuine gain is narrower than "a single choke point deciding which container, which project, whose voice."
With `voicemode serve`, the actual decision one process makes is "does the caller hold this token," nothing about project or speaker identity; per-project separation comes only from running one process per container.
What is real: no raw audio, no pulse control protocol in the container, a narrower and more auditable surface than a full pulse socket grant, at the cost of the broker becoming a new host-resident trust boundary whose token discipline now carries the weight the socket permissions used to carry.

One gain outside the threat table favors the broker specifically: the accepted proposal gives each project its own `~/.voicemode-${lace.projectName}` directory, so two containers' conversers today share one host mic/speaker with no lock between them.
Per-container host `serve` processes gain real cross-project turn-taking by default, since the conch's `flock` is a genuine cross-process lock, unlike the in-process guard #521/#522 expose within one process.
The conch path is hardcoded to `Path.home() / ".voicemode" / "conch"` (`conch.py:133`, with the queue files as siblings, `conch_queue.py:131-136`) and ignores `VOICEMODE_BASE_DIR`, so every same-user host `serve` process shares it automatically.
Transcripts, audio, and logs do follow `VOICEMODE_BASE_DIR` (`config.py:545-550`), so a per-project `VOICEMODE_BASE_DIR` keeps the proposal's per-project transcript isolation while the conch stays shared.
This does not itself fix #521/#522.

## 3. Existing building blocks for the broker

**VoiceMode run on the host, as an MCP server,** is the closest existing broker: `voicemode serve` is not stdio-only (`cli.py:2016-2090`), changes transport only, and neither `mcp_bridge.py` nor `serve_middleware.py` adds cross-session messaging.
`voicemode mcp-bridge`, a shipped native stdio-to-streamable-HTTP bridge, means "point the container at a host-run `serve`" needs no new bridge code, only the `pasta:-T` forward and either `--transport http` in `claude mcp add` or this bridge as a stdio wrapper.

**Wyoming protocol** ([`OHF-Voice/wyoming`](https://github.com/OHF-Voice/wyoming)) connects a satellite to STT/TTS/wake-word services over a plain socket, "no authentication or encryption, by design" (verified/web), a poor fit for the container boundary but usable behind the broker.

**Pipecat** ([pipecat-ai/pipecat](https://github.com/pipecat-ai)) lists Daily, FastAPI WebSocket, LiveKit, Small WebRTC, Vonage, WebSocket Server, WhatsApp, and Local as transports (README), and ships maintained Android client transports (`pipecat-client-android-transports`: Daily, Small WebRTC, OpenAI Realtime WebRTC, Gemini Live).
Small WebRTC is self-hostable, needing no vendor.
Relevant only as a broker implementation choice: building on Pipecat inherits a maintained Android WebRTC client, at the cost of adopting its pipeline model instead of VoiceMode's `converse` loop.

**LiveKit** ([livekit/livekit](https://github.com/livekit/livekit)) is a self-hostable, Apache-2.0 WebRTC SFU plus agents framework, but VoiceMode itself removed LiveKit support (`CHANGELOG.md`, 8.0.0), so a LiveKit broker reuses nothing from VoiceMode, the heaviest option here.

**Rhasspy** is superseded within its own ecosystem: the original project is archived, Rhasspy3 adopted Wyoming internally, and the `rhasspy/wyoming-satellite` README itself now states it is "no longer maintained... replaced by Linux Voice Assistant that uses the ESPHome protocol" (verified against the repo README).
Its history is the reason Wyoming, not Rhasspy, is the artifact worth reusing.

**Speaches** ([speaches-ai/speaches](https://github.com/speaches-ai/speaches)) is an OpenAI-API-compatible STT/TTS server (faster-whisper, Piper/Kokoro), a possible backend swap behind the broker, not a broker replacement. No local OpenAI-realtime-protocol server was found.

**Home Assistant Assist and its Android Companion app** are the most complete "wake-word phone satellite" prior art found, though not a Wyoming client.
Verified against `home-assistant.io/voice_control/android/`: the Companion app runs on-device wake-word detection (microWakeWord: "Okay Nabu"/"Hey Jarvis"/"Hey Mycroft") even when locked, against Assist as the default assistant app, needing Companion 2026.2.3+.
The app speaks to the user's own Home Assistant instance. Wyoming is what Home Assistant uses to reach satellites behind it, not what the app itself speaks, so it is not a client this broker's own Wyoming listener could reuse.
Its value is proof that wake-word-while-locked on Android is a solved, shipped problem, reusable only by routing through a real Home Assistant instance (section 4).

**VoiceMode Connect** is VoiceMode's own cloud-relay mobile path, and the most directly relevant prior art for this broker, reusing the same `converse` tool shape as a mobile client rather than an adjacent ecosystem.
Verified/source (`.claude/skills/voicemode-connect/SKILL.md`): agents connect via MCP to `voicemode.dev`, phone/web clients connect over WebSocket, the platform relays between them, and an iOS app plus web dashboard exist today.
The maintainer's 2026-09-27 comment on issue [#546](https://github.com/mbailey/voicemode/issues/546) (quoted in the fork-complexity report) names "iOS and Android chat / calls, Barge in, Multi-speaker rooms" as near-term, so a maintained Android client may ship upstream before a bespoke one would be built.
Tradeoff: Connect routes voice through a third-party cloud service, not this project's own host.

No actively maintained, dedicated Linux desktop voice daemon distinct from the above was found; VoiceMode-as-host-service remains the most direct building block.

## 4. Android remote-control extension point

Five shapes, roughly cheapest to most capable.

**OS dictation into Remote Control, zero build.**
The phone's own keyboard dictation, typed into the Claude app's text field over Remote Control (below), is voice input today with no broker, no app, and no new code, at the cost of no voice output and no hands-free wake.
The floor everything else is measured against.

**A plain web PWA over Tailscale.**
A page using `MediaRecorder`/`getUserMedia`, POSTing audio to the broker's `listen` endpoint, reachable only over Tailscale.
Two corrections: `getUserMedia` needs a secure context (Tailscale Serve's own HTTPS certificates, not a plain `http://100.x` address), and `--allow-tailscale` admits the whole `100.64.0.0/10` tailnet, not just the user's phone, so a token is still required.
With both fixed, this reuses the HTTP transport directly, no native app, at the cost of PWA background-execution limits: locked-screen always-listening is unrealistic, tap-to-talk is fine.

**A WebRTC client (Pipecat- or LiveKit-based).**
If the broker is built on either, their maintained Android SDKs give a real always-on, low-latency, barge-in-capable app for the cost of adopting that framework's transport, not hand-rolled WebRTC.
Best matches a first-class satellite feel, at the cost of committing the broker to that framework.

**VoiceMode Connect, upstream's own path.**
Point the phone at `voicemode.dev` instead of this project's broker. An iOS app and web dashboard exist today, and the roadmap names Android chat/calls and barge-in as near-term.
Cheapest in build cost if upstream ships it, at the cost of a third-party cloud relay rather than this project's own host.

**The Home Assistant app pattern, via a real instance.**
No maintained Android app speaks Wyoming to an arbitrary endpoint; the Companion app's satellite mode only ever points at the user's own Home Assistant instance.
Reusing it means standing up Home Assistant and a Wyoming bridge to the broker, letting the Companion app be the client, at the cost of routing every utterance through Assist first.
The only path to wake-word-while-locked without waiting on VoiceMode Connect or building a WebRTC client.

**Would Claude Remote Control cover this for free?** Partially, for a different slice.
Verified/docs (`code.claude.com/docs/en/remote-control`): Remote Control connects `claude.ai/code` or the Claude iOS/Android app to a local session over outbound HTTPS, no inbound forwarding needed, and already forwards `AskUserQuestion`/permission dialogs, keeping them open until answered.
This overlaps the accepted proposal's tier-3 relay and could substitute for it via text/tap, not voice.
The protocol itself gives the phone no microphone; OS dictation into its text field, above, is the actual zero-build voice-in path riding on top of it.
Not a substitute for any broker option, at most a fallback channel for the text-answer half of the relay.

## 5. Options ladder

Dev-time for option 0 is not zero: acceptance is not implementation.
Its Phase 0 gates (pulse device, Wayland under Enforcing) and Phase 1 (audio packages, `asound.conf`, the pulse mount) are still ahead.
Option 2 skips all of that. Phases 2-3 (launcher, hooks, `converser-io`) are identical in both, so they are not a point of difference.

| Option | Dev-time | New work | Security posture | Flexibility | Viability |
|---|---|---|---|---|---|
| **0. Accepted proposal, in-container VoiceMode** | Phases 0-1 ahead: pulse/Wayland gates, audio packages, `asound.conf`, the mount | The audio recipe only | Loses pulse's raw-audio/control surface; `label=disable` not this design's cost (section 2) | Low: API already "call an MCP tool," a broker slots in behind it later | Good stepping stone, no host process |
| **1. Unix-socket broker, bespoke protocol** | Days: host daemon, relay shim | Broker process, wire protocol, shim | No loopback-peer ambiguity, but no `label=disable`/`connectto` avoidance (section 1) | Low: bespoke, no Android story | Medium: all maintenance is ours |
| **2. `voicemode serve` per container** | Hours-a day: config only | A `pasta:-T` line, a token, `VOICEMODE_TOOLS_ENABLED=converse`, pinned URLs | Token is the real gate, one per container; #521/#522 does not apply with one client each; gains cross-project turn-taking by default (shared host conch) | Medium: shared `converse` shape, no per-project audio setup | Good, matches fork report's option (a); costs are host process lifecycle and a newer code path |
| **3. Bespoke HTTP/gRPC broker** | 15-25 person-days (fork report's from-scratch estimate) | API, auth, docs, VAD, turn-taking | Purpose-built, minimal, but inherits the loopback-peer problem over `pasta:-T` | High: exactly the four-call API | Medium: VoiceMode's fixed edge cases become ours |
| **4. Pipecat/LiveKit broker + WebRTC Android client** | Weeks: pipeline, transport, app | Pipeline glue, app packaging | Best long-term once built: real barge-in | Highest: the actual extension point asked for | Best only with real investment |

Option 2, one `serve` process and token per container, is a credible v0 alternative to option 0, not an obviously inferior one: simpler in the container, better on cross-project turn-taking (the host conch is shared by default), and no better on SELinux, since `label=disable` is not either design's cost.
Option 0's genuine advantage is operational: no host process to keep alive, no per-container port/token provisioning, already accepted.
This report aligns with the fork-complexity report's option (a) recommendation rather than proposing a different broker shape.

## 6. Recommendation and the smallest experiment

Run the smallest experiment below before committing to either baseline, rather than shipping option 0 and treating a broker as a someday retrofit.
It is a throwaway-container pre-check for the accepted vetting report's first experiment (option S: host `serve` with a converser in `weftwise` carrying no audio stack, the in-container stack as fallback), not a competing plan.
The two are close, which is the reason to test rather than assume.

**Smallest experiment**, zero changes to any real project's `devcontainer.json`: run `voicemode serve --host 127.0.0.1 --port 8765 --token <random>` on this host with `VOICEMODE_TOOLS_ENABLED=converse` and `VOICEMODE_STT_BASE_URLS`/`VOICEMODE_TTS_BASE_URLS` pinned to loopback.
No existing lace project has a `pasta` forward today, since the accepted proposal's forward line is unimplemented.
Instead, launch a throwaway container: `podman run --rm --network pasta:-T,8765 <image with claude or voicemode> voicemode mcp-bridge http://127.0.0.1:8765/mcp --token <random>`, or `claude mcp add --transport http voicemode-remote http://127.0.0.1:8765/mcp --header "Authorization: Bearer <random>"`, followed by one `converse()` call.

Success criteria: a raw `curl` `tools/list` call with no token returns 401, the same call with the token lists only `converse`, one `converse()` call completes end to end, and two throwaway containers each with their own `serve` process pointed at one shared conch directory serialize rather than collide (the cross-project gain from section 2).
A token-check or tool-scoping failure means option 2 needs more hardening; the IP allowlist itself cannot fail this test, since every forwarded connection already arrives as `127.0.0.1` regardless of source.

## Decision points

1. **Which v0 baseline?** (a) keep option 0, broker later; (b) switch v0 to per-container `voicemode serve`, dropping Phase 1's audio stack; (c) near-peers, let the experiment decide.
   Recommendation: (c); neither wins outright on security since `label=disable` is not either design's cost, and the experiment is cheap enough to run before committing.
2. **Is a cloud relay acceptable for Android?** (a) VoiceMode Connect is acceptable in principle; (b) self-hosted-only is a hard requirement.
   Recommendation: (a) as a watch item, not a default build, since Connect depends on a third party with room audio; defer a bespoke Android decision until its Android client ships and can be weighed against (b).
3. **How should per-container `serve` processes lay out VoiceMode state?** (a) one shared `~/.voicemode` for everything; (b) a per-project `VOICEMODE_BASE_DIR` for transcripts, audio, and logs, with the conch shared automatically (section 2); (c) a per-process `HOME` override, splitting the conch too.
   Recommendation: (b). It keeps the accepted proposal's per-project transcript isolation and still closes the vetting report's double-capture gap (two hands-free conversers acting on one utterance), which (c) would reopen.

## Unverified claims

- Whether `pasta:-T` forwards gRPC's HTTP/2 framing correctly. Only plain HTTP/1.1 has been empirically verified on this host.
- Whether Kokoro's or whisper.cpp's servers could be swapped for Speaches without behavior change, since Speaches was only confirmed OpenAI-API-compatible in general.
- Whether a Unix-socket-bind-mount broker needs anything beyond the stdio-relay shim sketched in section 1 to present as a well-formed MCP server.
- Whether FastMCP's streamable-HTTP transport validates `Host`/`Origin` on its own; `TokenAuthMiddleware`'s `!=` comparison is not constant-time, a negligible timing risk over loopback but an unverified DNS-rebinding exposure absent a token.
- The exact SELinux `connectto` behavior for a broker socket created by a host process rather than bind-mounted from an existing host socket.
- Whether VoiceMode Connect's Android client, once shipped, will support self-hosted STT/TTS or route audio through `voicemode.dev` unconditionally.

## Links

Accepted proposal: [`cdocs/proposals/2026-09-28-converser-lace-feature.md`](../proposals/2026-09-28-converser-lace-feature.md).
Round-1 review: [`cdocs/reviews/2026-09-28-review-of-host-audio-broker-split.md`](../reviews/2026-09-28-review-of-host-audio-broker-split.md).
Parallel reports: [`2026-09-28-voicemode-fork-complexity.md`](2026-09-28-voicemode-fork-complexity.md) (option (a), concurrency bug, person-day estimates, roadmap); [`2026-09-28-converser-options-vetting.md`](2026-09-28-converser-options-vetting.md) (finding A14, `label=disable`).
Clauthier trail (`cdocs/reports/`, 2026-09-27): [`containerized-conversationalist-and-question-surface.md`](2026-09-27-containerized-conversationalist-and-question-surface.md), [`voicemode-deep-dive.md`](2026-09-27-voicemode-deep-dive.md).
VoiceMode source, local: `/var/home/mjr/code/weft/clauthier/main/build/research/voicemode` (`126d15e`): `server.py`, `cli.py:2016-2298` (`serve`, `mcp-bridge`), `serve_middleware.py`, `tools/__init__.py:116-120`, `config.py:777-778,1645-1664`, `.claude/skills/voicemode-connect/SKILL.md`.
External, verified/web: [Wyoming](https://github.com/OHF-Voice/wyoming), [`wyoming-satellite`](https://github.com/rhasspy/wyoming-satellite), [HA Wyoming docs](https://www.home-assistant.io/integrations/wyoming/), [HA Assist on Android](https://www.home-assistant.io/voice_control/android/), [Pipecat](https://github.com/pipecat-ai), [`pipecat-client-android-transports`](https://github.com/pipecat-ai/pipecat-client-android-transports), [LiveKit](https://github.com/livekit/livekit), [LiveKit self-hosting](https://docs.livekit.io/transport/self-hosting/), [Speaches](https://github.com/speaches-ai/speaches), [Remote Control docs](https://code.claude.com/docs/en/remote-control).
