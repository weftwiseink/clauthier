---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-27T12:20:00-07:00
task_list: cdocs/audio-interaction
type: report
state: live
status: review_ready
last_reviewed:
  status: revision_requested
  by: "@claude-opus-5-5"
  at: 2026-09-27T12:20:25-07:00
  round: 1
tags: [analysis, voice, devcontainer, askuserquestion]
---

# Single-project containerized conversationalist, and AskUserQuestion as an alternate surface

> BLUF: A conversationalist placed inside the same lace container as its project's overseers needs no messaging relay: same-container sessions already share `/run/user/1000/cc-socks` (verified/empirical: five live `weftwise` sessions each hold their own socket there, plus one stale socket from an exited session), so the parent report's host/container messaging split disappears once the conversationalist moves in rather than staying out.
> The remaining work is audio, not messaging: mount only the PipeWire/PulseAudio native socket, never the whole `XDG_RUNTIME_DIR` (which also carries the host dbus session bus), reusing the exact `--mount`/`label=disable`/`postStartCommand` pattern `weftwise`'s own devcontainer already uses for Wayland; point STT/TTS at host-run services over `host.containers.internal` (verified reachable).
> On the question surface: no mechanism found lets a voice bridge win a live race against an already-open `AskUserQuestion` dialog; the one shipped "first answer wins" race (channels relay) is documented to cover only `Bash`/`Write`/`Edit` tool-permission approvals, not `AskUserQuestion`.
> Recommendation: tier 3 (answer-relay hook) with a timeout-then-local-fallback beats tier 2, since it is closest in spirit to "alternate surface" among the sequential options; `tmux send-keys`, gated on a `waitingFor: "dialog open"` status field found live on this host, is the one genuinely concurrent mechanism, but is unsupported UI automation and belongs on a follow-up spike, not v0.

## Context / Background

[`2026-09-27-conversationalist-bridge-design-questions.md`](2026-09-27-conversationalist-bridge-design-questions.md) recommended host-only overseers for v0: lace bind-mounts `~/.claude` (sharing the session registry) but not `/run/user/1000` (so the inbox socket is not shared), and fixing that mount would plausibly still hit sender-side endpoint checks across the container boundary.
The user rejected that trade: a single voice across all projects matters less than containerization, so this report inverts the design and puts the conversationalist *inside* the project container it serves, one per project.
It also investigates whether a voice bridge can act as a genuinely concurrent alternate answer surface for `AskUserQuestion`, racing the local terminal dialog rather than only substituting for it.

Host: Fedora, Wayland, PipeWire (verified: `pipewire-pulse.service` active; `pactl info` shows `Server String: /run/user/1000/pulse/native`), SELinux enforcing (verified: `getenforce` → `Enforcing`), `podman` and `docker` both installed, with lace containers running under `podman` (verified: six live containers including `weftwise`).
Lace lives at `/var/home/mjr/code/weft/lace/main`; the worked example is `weftwise` at `/var/home/mjr/code/weft/weftwise/main`, whose `.devcontainer/devcontainer.json` already solves an almost identical problem (Wayland socket passthrough) and is the template reused here for audio.

## Part 1: a single-project containerized conversationalist

### Same-container messaging already works

The parent report's finding was scoped to *host-to-container* messaging; it doesn't apply once the conversationalist and its overseers are peers inside one container.
Verified/empirical: `podman exec weftwise sh -c 'echo $XDG_RUNTIME_DIR'` returns `/run/user/1000`, and that directory (container-private, on the container's own filesystem; only `wayland-0` inside it is a bind-mounted tmpfs) is live and non-empty (`cc-socks`, `wayland-0`, `blesh`, `dconf`) — not unset, contrary to the risk flagged in the task brief.
`/run/user/1000/cc-socks` inside `weftwise` holds six sockets, five backed by live `claude --dangerously-skip-permissions` processes and one stale (PID `1342209`, exited), all in one PID namespace, confirming multiple concurrent Claude Code sessions already coexist in one lace container with working per-session inbox sockets.
A conversationalist added there is a sixth live peer in the same directory, sharing the container's PID namespace and user; this is exactly what the docs describe as working: "two sessions inside the same container can still message each other" (`code.claude.com/docs/en/cross-session-messaging`, cited verbatim in the parent report).
**Consequence:** the parent report's v0.1 file-relay design (posting through the shared `~/.claude` bind mount) is unneeded for this topology; it solved host-to-container delivery, and in-container delivery needs nothing beyond what already ships.
The one structural change: the conversationalist's `SessionStart` hook only needs to publish its socket path somewhere readable *inside the container*, not across the host boundary.

### Audio passthrough

**Mount the PulseAudio/PipeWire socket specifically, never the whole runtime directory.**
`weftwise`'s own `devcontainer.json` already passes through a `/run/user/1000`-resident socket for Wayland and states the exact constraint needed here: "Mounts ONLY the host's wayland-0 socket - NEVER the whole /run/user/1000, which also holds the dbus session bus, pipewire, and gnupg sockets (a containment hole...)."
The referenced proposal is explicit the risk is the *dbus session bus* specifically, not PipeWire (`cdocs/proposals/2026-07-15-in-container-headed-electron.md:119-122`), so the same recipe applies to audio: mount `/run/user/1000/pulse/native` (verified present, `srw-rw-rw-`) or `/run/user/1000/pipewire-0` (also verified present), never their parent directory.
The Wayland precedent's mechanics carry over unchanged: a raw `runArgs: ["--mount", "type=bind,src=...,dst=..."]` (not lace's typed `customizations.lace.mounts`, whose resolver validates `sourceMustBe: "file"|"directory"` only — a socket satisfies neither, the exact limitation weftwise's own comment records); the same `postStartCommand` fixing `/run/user/1000` ownership; and `--security-opt label=disable`, already the effective SELinux posture for lace devcontainers, needed for the same reason as Wayland: SELinux's `unix_stream_socket connectto` permission between `container_t` and the host's `unconfined_t` domain (the parent bridge report's own finding), not a file-label problem.
A targeted policy avoiding `label=disable` is possible in principle but unexplored; `label=disable` is the path with precedent.

**Env vars and UID mapping.** PortAudio/pulse clients resolve the server from `PULSE_SERVER`, defaulting to `unix:$XDG_RUNTIME_DIR/pulse/native` (verified/empirical: host `pactl info` shows that path with `$PULSE_SERVER` itself unset).
Since `weftwise` already sets `XDG_RUNTIME_DIR=/run/user/1000` and the bind-mounted socket lands at the identical path, no override is needed; an explicit `PULSE_SERVER` is optional documentation, not a requirement.
`weftwise` runs as uid 1000 (`node`), matching the host's `mjr`; the host pulse socket is `mjr:mjr`, world-read/writable, so no uid remapping is needed for the socket itself, only the mount-point directory (already handled by the existing `postStartCommand`).

**VoiceMode's audio stack speaks the pulse protocol.** Verified/source: every VoiceMode module doing device I/O (`converse.py`, `devices.py`, `audio_player.py`, `streaming.py`, `shared.py`, `core.py`) imports `sounddevice`/PortAudio, never raw ALSA or ffmpeg for live I/O.
PortAudio is compiled against PulseAudio in VoiceMode's own Nix flake, and its Debian/Ubuntu install line lists `libportaudio2`, `libasound2-plugins` (the ALSA-to-pulse plugin) and `pulseaudio`/`pulseaudio-utils` (`README.md:131`); `PULSE_SERVER` appears only in WSL troubleshooting material (`docs/.archive/troubleshooting/wsl2-microphone-access.md:133`, `scripts/diagnose-wsl-audio.py:204`).
This is strong indirect evidence PortAudio's pulse hostapi is the operative Linux backend, and that `PULSE_SERVER` resolution is the lever that reaches a bind-mounted socket.
No direct in-container run was performed; unverified/empirical pending the test list below.

### Local STT/TTS: host-run, reached over HTTP

VoiceMode's STT/TTS clients are plain HTTP, defaulting to `http://127.0.0.1:8880/v1` (Kokoro) and `:2022/v1` (whisper.cpp), overridable via `VOICEMODE_TTS_BASE_URLS`/`VOICEMODE_STT_BASE_URLS` (verified/source, `config.py:777-778`).
Pointing the container at `http://host.containers.internal:8880/v1` / `:2022/v1` is simpler than duplicating GPU-hungry model servers per container: one shared instance serves every project, and GPU access never needs exposing into any container.
`host.containers.internal` is verified reachable from `weftwise` (`/etc/hosts` resolves it to `169.254.1.2`, matching `NetworkMode: pasta`).
Verified/empirical (review round 1): from `weftwise`, `curl http://host.containers.internal:<port>` connects to host listeners bound to a wildcard address (`*:22430`, `0.0.0.0:57621`) but gets connection-refused for listeners bound to `127.0.0.1` (`:631`, `:8080`), so host STT/TTS must bind a non-loopback address. VoiceMode's whisper launcher already binds `0.0.0.0` (`templates/scripts/start-whisper-server.sh:149`, `tools/service.py:471`); Kokoro's bind address comes from the upstream kokoro-fastapi start script and is unverified.

### Expressing this in lace

Two additions, no new lace feature needed: (1) a `runArgs`/`postStartCommand`/`containerEnv` block in the *project's* `devcontainer.json`, mirroring the Wayland block line-for-line — one `--mount` for the pulse/pipewire socket, the ownership-fix `postStartCommand`, and `VOICEMODE_TTS_BASE_URLS`/`VOICEMODE_STT_BASE_URLS` pointed at `host.containers.internal`; (2) nothing for messaging, since same-container `SendMessage` already works.
If this pattern recurs across projects it's a candidate for a proper lace feature with a socket-aware mount primitive, but that needs lace's mount resolver to grow socket-awareness first, a gap weftwise's own `devcontainer.json` TODO already records.

### Consequences of one-conversationalist-per-container

**Lost:** a single voice identity across projects; each container runs its own VoiceMode process and conch lock file.
**Conch arbitration doesn't cross containers by default.** The lock path is hardcoded as `Path.home()/".voicemode"/"conch"` (verified/source, `conch.py:133`), independent of `VOICEMODE_BASE_DIR` (`config.py:545`); lace mounts no such directory into any container, so each container's conch is mutually unaware of the others.
**Mitigation and cost:** bind-mounting the host's `~/.voicemode` at each container user's `~/.voicemode` (setting `VOICEMODE_BASE_DIR` does not move the conch) would let every conversationalist share one conch, at the cost of every container gaining RW access to every other project's voice history — a leak in the same family as the `~/.claude` RW mount already accepted for Claude Code credentials.
Absent that mount, the mitigation is procedural: keep at most one project's conversationalist speaking at a time.
**The `Stop`-hook and tier-2 `AskUserQuestion` hook designs are unchanged inside a container:** both need only a socket path or `ListAgents` check reachable within the container, which same-container messaging already provides.

### Wake paths

The parent report's hotkey-wake sketch posted directly into a host-run conversationalist's socket via `socat`.
Containerized, this needs one more hop: `podman exec -i <container> socat - UNIX-CONNECT:/run/user/1000/cc-socks/<pid>.sock` from the host hotkey script (neither `socat` nor `nc` is installed in `weftwise` today; add `socat` to the image or use a `python3` one-liner, which is present), piping the same wire format across the `exec` boundary.
This extends `podman exec`'s existing stdin-forwarding, already in use on this host: `tmux list-panes` shows a pane whose foreground command is `podman` alongside panes running `claude` directly.
No SELinux `connectto` concern applies here (unlike the cross-machine case): `podman exec` runs inside the container's own domain, sharing one SELinux context with the target socket.

## Part 2: AskUserQuestion as an alternate surface, first-answer-wins

> Direct answer: nothing found lets a bridge win a race against an `AskUserQuestion` dialog *already rendering* in a terminal.
> The shipped "first answer wins" race (channels relay) is documented to cover only `Bash`/`Write`/`Edit` tool-permission approvals, explicitly not `AskUserQuestion`.

**Channels permission relay: real racing, wrong tool.** Docs-verified (`code.claude.com/docs/en/channels-reference`): "Both stay live: you can answer in the terminal or on your phone, and Claude Code applies whichever answer arrives first and closes the other."
Scope is explicit: "Relay covers tool-use approvals like Bash, Write, and Edit. Project trust and MCP server consent dialogs don't relay."
`AskUserQuestion` is a tool call too but isn't in that list, and nothing extends relay to it.
Whether a custom MCP-hosted process can register as a relay target is unverified; no documented extension point was found.

**Remote Control: a real concurrent surface for a human, not for the bridge.** Docs-verified (`code.claude.com/docs/en/remote-control`, Limitations): "Claude Code keeps permission prompts and `AskUserQuestion` questions open until you answer them" when forwarding dialogs to the remote session, and push notifications cover "permission prompts and questions."
So a pending `AskUserQuestion` is answerable from the Claude app or claude.ai as well as the terminal; that is a documented first-answer surface, but only for a human on Anthropic's clients, with no documented programmatic entry a voice bridge could use.

**Cross-session message during an open dialog: queues, doesn't interrupt.** Docs-verified for permission prompts: "a message from another session never counts as your consent, so it can't answer a pending permission prompt on your behalf" (`code.claude.com/docs/en/cross-session-messaging`).
The wording names "permission prompt," not `AskUserQuestion`; extending it is a reasonable but unverified inference (both are blocking, turn-internal states; inbound messages process "between tool calls," i.e. never during one).

**Terminal injection via `tmux send-keys`: the only structurally concurrent mechanism, and the most hacky.** tmux operates on the pty regardless of what runs inside it, so `send-keys` into an overseer's pane (`hunk:@14.%89`-style ids, confirmed live via `tmux list-panes`) works identically whether the pane's foreground process is bare `claude` or `podman exec ... claude` — tmux never sees the container boundary.
This is real concurrency: whichever input, real or injected, lands first wins, like the channels race but implemented at the terminal-emulation layer.
Risks: `AskUserQuestion`'s key bindings are UI behavior, not a versioned contract, so a script can break silently on upgrade; a race with real keystrokes can interleave and corrupt input; the bridge needs to know a dialog is showing before typing blindly.
That last risk has a concrete mitigation found empirically here: a live session's registry entry (`~/.claude/sessions/<pid>.json`, host-readable across the lace bind mount even when the socket isn't) carried `"status":"waiting","waitingFor":"dialog open"` for a real `weftwise` session observed during this investigation.
A host-side bridge can poll that field before injecting keys, turning a blind race into a gated one, with no socket connectivity required.

**Hook-based hybrid: sequential, not concurrent, but the most reliable answer mechanism that exists.** The parent report established, verified/source, that `PreToolUse` matches `AskUserQuestion` and can return `allow` with `updatedInput.answers` to answer it with no local prompt, or `deny` to redirect.
Because `PreToolUse` runs before the tool executes, a tier-3 hook waiting up to N seconds for a voice answer prevents the local dialog from appearing during that window; on timeout, returning no decision lets the tool proceed normally, i.e. the local dialog appears.
The hooks docs confirm the mechanism (PreToolUse decision control, `AskUserQuestion` input table, and "Exit code 0 with no output means the hook has no decision ... the tool call continues through the normal permission flow"); a timed-out command hook likewise "doesn't block the tool call" (Timeouts).

**Ranking (fidelity / reliability / effort):**
1. **Tier 3, timeout-then-local-fallback:** highest reliability, lowest hackiness; sequential, but invisible to the user when the voice answer beats the timeout.
2. **`tmux send-keys`, gated on `waitingFor: "dialog open"`:** the only genuinely concurrent option; binding-fragile, unsupported; worth a spike, not v0.
3. **Tier 2 (deny-and-redirect):** simplest, deterministic, purely a policy substitute — never a race.
4. **Channels relay:** genuinely concurrent and robust, but out of scope: doesn't cover `AskUserQuestion`.
5. **Remote Control / plain cross-session messaging:** Remote Control answers an open dialog but only from Anthropic's human-facing clients; cross-session messages can't answer it at all. Neither is a bridge surface.

**Recommendation:** tier 3 with timeout-then-local-fallback beats tier 2, per the task's own framing ("if not, 4.2 seems fine").
No genuinely concurrent mechanism exists for `AskUserQuestion`; tier 3 gets closest to "alternate surface" in spirit while degrading safely, which tier 2 cannot without implementing its own timeout logic anyway.
The tmux path is worth a follow-up spike given the `waitingFor` discovery, but shouldn't gate v0.

## Updated v0 delta vs. the bridge report

- **Container placement flips:** "host-only overseers for v0" is superseded for any project whose overseers already run in a lace container; the conversationalist joins that container, and the v0.1 file-relay design is unneeded there.
- **New work is audio, not messaging:** the missing piece is the pulse/pipewire socket mount and host-reachable STT/TTS URLs in the *project's* `devcontainer.json`.
- **`AskUserQuestion` tier choice sharpens:** tier 3 should specifically be timeout-gated with local fallback, since no concurrent alternative exists; the tmux/`waitingFor` path is a distinct, higher-fidelity follow-up, not a tier alongside 1-3.

## Empirical tests to run

1. Add the pulse-socket `runArgs`/`postStartCommand`/`containerEnv` block to a scratch devcontainer and confirm `sd.query_devices()` inside lists real host devices.
2. Confirm the host STT/TTS services bind a non-loopback address, then `curl` them from the container via `host.containers.internal` (wildcard-bound host ports are verified reachable; loopback-bound ones are not).
3. Start a second session inside an existing lace container and confirm ordinary `SendMessage` delivery to a first session in the same container.
4. Trigger a real `AskUserQuestion`, confirm the registry shows `waitingFor: "dialog open"`, then test whether `tmux send-keys` can select an option (no real user present, to avoid corrupting input).
5. Attempt to register a non-Slack, custom MCP-hosted relay target and see whether the channels framework accepts it.

## Unverified claims

- Whether VoiceMode's PortAudio stack actually acquires a working device once pointed at a bind-mounted pulse socket inside a container; only the wiring is verified, not an end-to-end run.
- Whether Kokoro's upstream start script binds a non-loopback address (required for `host.containers.internal` reachability).
- Whether a custom, non-built-in relay target can participate in the channels "first answer wins" race for any tool, let alone `AskUserQuestion`.
- Whether answering a forwarded `AskUserQuestion` via Remote Control dismisses the local terminal dialog (docs confirm it is forwarded and answerable, not the local-side effect).
- Whether the cross-session-messaging docs' "can't answer a pending permission prompt" statement extends to `AskUserQuestion`, or whether it's governed by different internal logic.
- The exact, versioned key-binding contract for answering `AskUserQuestion` via raw terminal input, needed before any `tmux send-keys` script could be reliable.
