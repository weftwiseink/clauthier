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

> BLUF: A conversationalist inside the same lace container as its project's overseers needs no messaging relay: same-container sessions already share `/run/user/1000/cc-socks` (verified/empirical: five live `weftwise` sessions plus one stale socket, each with its own inbox), so the parent report's host/container messaging split disappears once the conversationalist moves in.
> The remaining work is audio: `weftwise` (Debian 12) has none of VoiceMode's audio libraries, and the real backend path is PortAudio → ALSA's `pulse` plugin → the bind-mounted `pulse/native` socket, not a PortAudio pulse host API; a complete recipe (packages, ALSA routing, `PULSE_SERVER`, `label=disable`/mount) is below.
> Host-run STT/TTS reached over `host.containers.internal` is verified reachable, but only for services bound off loopback, which under Fedora's default firewalld zone means LAN-exposed unless scoped.
> On the question surface: no mechanism found lets a *bridge* win a live race against an already-open `AskUserQuestion` dialog; the channels relay's "first answer wins" race covers `Bash`/`Write`/`Edit`, and `AskUserQuestion` is not documented as covered.
> Remote Control does forward and answer `AskUserQuestion` concurrently, but only from Anthropic's human-facing clients, not a programmatic bridge; recommendation is tier 3 (answer-relay hook) with a presence-gated, timeout-then-local-fallback, accepting its invisible-wait and lost-late-answer costs, over tier 2's simpler but non-racing redirect.

## Context / Background

[`2026-09-27-conversationalist-bridge-design-questions.md`](2026-09-27-conversationalist-bridge-design-questions.md) recommended host-only overseers for v0: lace bind-mounts `~/.claude` (sharing the session registry) but not `/run/user/1000` (so the inbox socket isn't shared), and fixing that mount would plausibly still hit sender-side endpoint checks across the container boundary.
The user rejected that trade: containerization matters more than one voice across all projects, so this report puts the conversationalist *inside* the project container it serves, one per project, and separately investigates whether a voice bridge can race an open `AskUserQuestion` dialog rather than only substituting for it.

Host: Fedora, Wayland, PipeWire (verified: `pipewire-pulse.service` active; `pactl info` shows `Server String: /run/user/1000/pulse/native`), SELinux enforcing, `podman` and `docker` both installed, lace containers running under `podman`.
The worked example is `weftwise` at `/var/home/mjr/code/weft/weftwise/main`, whose `.devcontainer/devcontainer.json` already solves an almost identical problem (Wayland socket passthrough) and is the template reused here for audio.

## Part 1: a single-project containerized conversationalist

### Same-container messaging already works

The parent report's finding was scoped to *host-to-container* messaging; it doesn't apply once the conversationalist and its overseers are peers inside one container.
Verified/empirical: `weftwise`'s `/run/user/1000` (container-private, on the container's own filesystem; only `wayland-0` inside it is a bind-mounted tmpfs) is live and non-empty, not unset as the task brief risked.
`/run/user/1000/cc-socks` holds six sockets, five backed by live `claude --dangerously-skip-permissions` processes and one stale, all in one PID namespace: multiple concurrent sessions already coexist in this container with working inbox sockets, exactly the case the docs describe as working ("two sessions inside the same container can still message each other").
**Consequence:** the parent report's v0.1 file-relay design is unneeded here; it solved host-to-container delivery, and in-container delivery needs nothing beyond what already ships.
The structural change: the conversationalist's `SessionStart` hook must publish its socket path somewhere container-local, not under the shared `~/.claude` mount, since that directory is bind-mounted into every lace container and the host and would leak the path across projects; a path like `/run/user/1000/conversationalist.sock` avoids that.

### Audio passthrough

**Mount the PulseAudio socket specifically, never the whole runtime directory.**
`weftwise`'s own `devcontainer.json` already passes a `/run/user/1000` socket through for Wayland and states the constraint needed here verbatim: "Mounts ONLY the host's wayland-0 socket - NEVER the whole /run/user/1000, which also holds the dbus session bus, pipewire, and gnupg sockets."
The referenced proposal calls dbus out "in particular" but doesn't clear PipeWire either, so prefer the audio-scoped `pulse/native` socket (verified present, `srw-rw-rw-`) over `pipewire-0`, which exposes the whole PipeWire graph including video/screencast nodes.
Mounting it is an inherent grant regardless: every bypass-mode agent in that container gains microphone access, not just the conversationalist.
The Wayland precedent's mechanics carry over: raw `runArgs --mount` (not lace's typed `customizations.lace.mounts`, whose resolver only validates `sourceMustBe: "file"|"directory"`, which a socket satisfies neither), the same ownership-fixing `postStartCommand`, and `--security-opt label=disable` for SELinux's `unix_stream_socket connectto` permission between `container_t` and the host's `unconfined_t` domain, not a file-label problem.

**The complete recipe: PortAudio → ALSA → the `pulse` plugin, not a PortAudio pulse host API.**
`weftwise` is Debian 12; verified/empirical, the image ships only `libasound.so.2`, with no `libportaudio2`, `libpulse0`, `libasound2-plugins`, or `ffmpeg`, so `sounddevice` has nothing to open today.
Debian's `libportaudio2` is built against ALSA, not PulseAudio directly, so the working path is PortAudio → ALSA's `pulse` PCM (from `libasound2-plugins`) → the bind-mounted socket, exactly why VoiceMode's own Debian install line requires `libasound2-plugins` alongside `pulseaudio`/`pulseaudio-utils` (`README.md:131`).

```jsonc
// devcontainer.json
"runArgs": [
  "--mount", "type=bind,src=/run/user/1000/pulse/native,dst=/run/user/1000/pulse/native",
  "--security-opt", "label=disable"
],
"postCreateCommand": "sudo apt-get update && sudo apt-get install -y libportaudio2 libasound2-plugins libpulse0 ffmpeg && curl -LsSf https://astral.sh/uv/install.sh | sh",
"postStartCommand": "sudo mkdir -p /run/user/1000 && sudo chown node:node /run/user/1000 && sudo chmod 700 /run/user/1000",
"containerEnv": { "PULSE_SERVER": "unix:/run/user/1000/pulse/native" }
```

```
# /etc/asound.conf (or ~/.asoundrc): route ALSA's default device to pulse
pcm.!default { type pulse }
ctl.!default { type pulse }
```

`libasound2-plugins` may already drop an equivalent `alsa.conf.d` snippet; check before duplicating it.
`uv` is VoiceMode's own installer prerequisite, layered via `postCreateCommand` like `weftwise`'s other per-feature tooling.
`PULSE_SERVER` is load-bearing here, unlike the Wayland precedent: host `pactl info` resolves that path by default, but that default isn't sourced from `$PULSE_SERVER` itself, so the container must set it explicitly.
`weftwise` runs as uid 1000 (`node`), matching the host's `mjr`; the host pulse socket is `mjr:mjr`, world-read/writable, so no uid remapping is needed beyond the ownership fix already in `postStartCommand`.
Empirical test 1 should assert `sd.query_devices()` reports a `pulse`/`default` device, not merely that the call doesn't error; no in-container run was performed, so end-to-end capture remains unverified/empirical.
Verified/source: every VoiceMode module doing device I/O imports `sounddevice`/PortAudio, never raw ALSA or ffmpeg directly; `PULSE_SERVER` appears in VoiceMode's own tree only in WSL troubleshooting material, so the Debian routing above is this report's inference from the PortAudio/ALSA chain, not a VoiceMode-documented step.

### Local STT/TTS: host-run, reached over HTTP

VoiceMode's STT/TTS clients default to `http://127.0.0.1:8880/v1` (Kokoro) and `:2022/v1` (whisper.cpp), overridable via `VOICEMODE_TTS_BASE_URLS`/`VOICEMODE_STT_BASE_URLS` (`config.py:777-778`).
Pointing the container at `host.containers.internal` on those ports is simpler than duplicating GPU-hungry model servers per container.
Verified/empirical: from `weftwise`, `curl` reaches host listeners bound to a wildcard address but is refused for ones bound to `127.0.0.1`, so host STT/TTS must bind non-loopback; VoiceMode's whisper launcher already binds `0.0.0.0`, Kokoro's bind address is upstream and unverified.
> WARN(sonnet/audio-interaction): Fedora's default firewalld zone opens ports 1025-65535, so a `0.0.0.0`-bound whisper/Kokoro is LAN-exposed, not merely container-reachable.
> Bind to the pasta-visible host address instead of the wildcard, or scope 2022/8880 to the pasta zone in firewalld.

### Expressing this in lace, and consequences

No new lace feature is needed: a `runArgs`/`postStartCommand`/`containerEnv` block in the *project's* `devcontainer.json`, mirroring the Wayland block, plus nothing for messaging, since same-container `SendMessage` already works.
**Lost:** one voice identity across projects; each container runs its own VoiceMode process and conch lock, hardcoded at `~/.voicemode/conch` independent of `VOICEMODE_BASE_DIR` (`conch.py:133`), and lace mounts no such directory anywhere, so each container's conch is mutually unaware of the others.
Sharing it would need bind-mounting `~/.voicemode` into every container, at the cost of every container gaining RW access to every other project's voice history, a leak in the same family as the `~/.claude` RW mount already accepted; absent that, the mitigation is procedural: one project's conversationalist speaking at a time.
The `Stop`-hook and tier-2 `AskUserQuestion` hook designs are otherwise unchanged inside a container, but should be scoped to the project (`.claude/settings.local.json`), not `~/.claude/settings.json`, since that file is the same shared bind mount and would fire in every session on the host and every other container.

### Wake paths

The parent report's hotkey-wake sketch posted directly into a host-run conversationalist's socket via `socat`.
Containerized, this needs one hop more: `podman exec -i <container> socat - UNIX-CONNECT:/run/user/1000/cc-socks/<pid>.sock` from the host script (neither `socat` nor `nc` is installed in `weftwise` today; add `socat` or use the `python3` that is present), extending `podman exec`'s existing stdin-forwarding already relied on for interactive sessions on this host.
No SELinux `connectto` concern applies here, unlike the cross-machine case: `podman exec` runs inside the container's own domain, sharing one SELinux context with the target socket.

## Part 2: AskUserQuestion as an alternate surface, first-answer-wins

> Direct answer: nothing found lets a *bridge* win a race against an `AskUserQuestion` dialog *already rendering* in a terminal.
> The channels relay's "first answer wins" race covers `Bash`/`Write`/`Edit`; `AskUserQuestion` is simply absent from that list, not documented as covered.
> A human-facing concurrent surface does exist (Remote Control), just not one a bridge process can drive.

**Channels permission relay: real racing, wrong tool.** Docs-verified (`channels-reference`): "Both stay live ... Claude Code applies whichever answer arrives first and closes the other," scoped explicitly to "tool-use approvals like Bash, Write, and Edit."
`AskUserQuestion` isn't in that list, and the docs neither name it excluded nor confirm it relays.
Whether a custom MCP-hosted process can register as a relay target is unverified; no extension point was found.

**Remote Control: concurrent for a human, not for the bridge.** Docs-verified (`remote-control`, Limitations): "Claude Code keeps permission prompts and `AskUserQuestion` questions open until you answer them" when forwarding dialogs, and push notifications cover "permission prompts and questions."
So a pending `AskUserQuestion` is answerable from the Claude app or claude.ai, a documented first-answer surface, but only for a human on Anthropic's clients, with no programmatic entry a bridge could use.

**Cross-session message during an open dialog: queues, doesn't interrupt.** Docs-verified for permission prompts: "a message from another session ... can't answer a pending permission prompt on your behalf."
The wording names "permission prompt," not `AskUserQuestion`; extending it is a reasonable but unverified inference, since both are blocking states and inbound messages process "between tool calls," never during one.

**`tmux send-keys`: the only structurally concurrent mechanism, and the most hacky.** tmux operates on the pty regardless of what runs inside it, so `send-keys` into an overseer's pane works identically whether its foreground process is bare `claude` or `podman exec ... claude`.
Whichever input, real or injected, lands first wins, like the channels race but at the terminal-emulation layer, at the cost of binding-fragile, unversioned key contracts and a real risk of colliding with the user's own keystrokes.
A live session's registry field, `"waitingFor":"dialog open"`, looked like a ready-made gate for knowing a dialog is up, but is weaker than it looks: verified against the installed 2.1.283 binary, roughly fifteen distinct dialog kinds map to that same value, including usage-limit and fallback-model prompts, none of which are `AskUserQuestion`.
It's an undocumented, generic "some modal is up" signal; a real gate needs the dialog *kind*, e.g. a `PreToolUse` hook on `AskUserQuestion` writing a marker first, folding this back into the hook-based hybrid.
Separately, this has a topology mismatch with Part 1: the conversationalist now lives *inside* the container, but `send-keys` into an overseer's pane is a host-side action against the host's tmux server, reintroducing the host/container split Part 1 removes for ordinary messaging.

**Hook-based hybrid: sequential, not concurrent, but the most reliable answer mechanism that exists.** `PreToolUse` matches `AskUserQuestion` and can return `allow` with `updatedInput.answers` to answer with no local prompt, or `deny` to redirect.
Because `PreToolUse` runs before the tool executes, a tier-3 hook waiting up to N seconds for a voice answer prevents the local dialog from appearing during that window; the fallback must be a silent `exit 0` with no output (not `permissionDecision: "ask"`, which adds a confirmation prompt instead of falling through), self-timed a few seconds under the hook's configured `timeout` so the fallback is deliberate rather than a harness kill.
Two real costs: during the wait the question is invisible at the terminal, so a user already typing just sees nothing; and it's voice-first-then-local, not first-answer-wins, so a voice answer arriving after the local dialog appears is lost, since the hook has exited and a cross-session message can't answer an open dialog.
A presence-file check (reusing the `CLAUDE_CLIENT_PRESENCE_FILE` pattern documented for Remote Control push) can skip the relay while the user is already at the keyboard.
Tier 3 also needs its own reply channel; a per-question reply file the in-container conversationalist writes, read by the waiting hook, fits the shared container filesystem.

**Ranking (fidelity / reliability / effort):** (1) tier 3 timeout-then-local-fallback: highest reliability, lowest hackiness, sequential but invisible when voice beats the timeout; (2) `tmux send-keys` gated on dialog kind: the only genuinely concurrent option, binding-fragile, worth a spike not v0; (3) tier 2 deny-and-redirect: simplest, deterministic, never a race; (4) channels relay: concurrent and robust but out of scope, doesn't cover `AskUserQuestion`; (5) Remote Control / plain cross-session messaging: not bridge-drivable surfaces.

**Recommendation:** tier 3 with presence-gated timeout-then-local-fallback, given the user's stated preference, not because it strictly dominates tier 2.
Tier 2 remains the lower-cost, more incremental v0 if the invisible-wait/lost-late-answer costs are unwelcome.
The tmux path, now known to need a dialog-kind gate and a host-side agent, is worth a follow-up spike, but shouldn't gate v0.

## Updated v0 delta vs. the bridge report

- **Container placement flips:** "host-only overseers for v0" is superseded wherever overseers already run in a lace container; the conversationalist joins that container, and the v0.1 file-relay design is unneeded there.
- **New work is audio, not messaging:** the missing piece is the in-image audio stack, ALSA-to-pulse routing, the socket mount, and host-reachable, non-loopback-bound STT/TTS URLs.
- **`AskUserQuestion` tier choice sharpens:** tier 3 should be presence-gated and timeout-gated with local fallback; the tmux/dialog-kind path is a distinct, higher-fidelity follow-up, not a tier alongside 1-3.

## Decision points

1. **Voice question handling when the user is already at the keyboard.** Options: (a) always relay to voice first; (b) relay only when a presence file says the user is away; (c) tier 2 redirect only, no wait window.
   Recommendation: (b); it keeps voice-first exactly when it helps and avoids the invisible-wait cost exactly when it wouldn't.
2. **Host STT/TTS exposure.** Options: (a) bind `0.0.0.0` plus a firewalld rule scoping to the pasta path; (b) run STT/TTS inside each container (GPU passthrough, duplicated per project); (c) accept LAN exposure.
   Recommendation: (a); it keeps the one-shared-instance design over per-container GPU duplication, at the cost of a one-time firewalld rule.

## Empirical tests to run

1. Add the recipe's `runArgs`/`postCreateCommand`/`postStartCommand`/`containerEnv` block to a scratch devcontainer and confirm `sd.query_devices()` lists a `pulse` device.
2. Confirm host STT/TTS bind non-loopback, then `curl` them from the container via `host.containers.internal`.
3. Start a second session inside an existing lace container and confirm ordinary `SendMessage` delivery to a first session there.
4. Trigger a real `AskUserQuestion`, confirm the registry's `waitingFor` value, then test whether a dialog-kind-gated `tmux send-keys` can select an option safely (no real user present).
5. Attempt to register a non-Slack, custom MCP-hosted relay target and see whether channels accepts it.

## Unverified claims

- Whether VoiceMode's PortAudio stack acquires a working device once pointed at a bind-mounted pulse socket in-container; only the wiring is verified, not an end-to-end run.
- Whether Kokoro's upstream start script binds non-loopback, required for `host.containers.internal` reachability.
- Whether a custom relay target can join the channels "first answer wins" race for any tool, let alone `AskUserQuestion`.
- Whether answering a forwarded `AskUserQuestion` via Remote Control dismisses the local terminal dialog (docs confirm it's forwarded and answerable, not the local-side effect).
- Whether the cross-session-messaging "can't answer a pending permission prompt" statement extends to `AskUserQuestion`, or is governed by different internal logic.
- The exact, versioned key-binding contract for answering `AskUserQuestion` via raw terminal input.
