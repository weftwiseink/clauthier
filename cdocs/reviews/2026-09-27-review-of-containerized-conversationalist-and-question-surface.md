---
review_of: cdocs/reports/2026-09-27-containerized-conversationalist-and-question-surface.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-27T12:20:25-07:00
task_list: cdocs/audio-interaction
type: review
state: live
status: done
tags: [fresh_agent, source_verification, docs_verification, devcontainer, audio_passthrough, askuserquestion, inline_fixes]
---

# Review: containerized conversationalist and AskUserQuestion question surface

## Summary Assessment

The report moves the conversationalist inside the project's lace container, which is right, and asks whether any mechanism lets a voice bridge answer an already-open `AskUserQuestion` on a first-answer-wins basis.
The messaging half is correct: same-container peers work, and I confirmed it read-only.
The question-surface analysis is mostly correct, and its conclusion holds: no *programmatic* concurrent surface exists.
The audio recipe is incomplete in a way that would fail on first try. The `weftwise` image (Debian bookworm) has none of VoiceMode's audio libraries, and the report's backend reasoning (a PortAudio pulse host API) is wrong for Debian's PortAudio.
The `waitingFor: "dialog open"` gate for `tmux send-keys` is weaker than presented.
I fixed a batch of small factual errors inline (listed below).
Verdict: **Revise**, for the audio recipe gap (blocking) plus non-blocking caveats.

## Verification performed

- `podman exec weftwise` (read-only): ran `ls` on `/run/user/1000` and `cc-socks`, checked socket liveness against `/proc`, read `/proc/mounts`, `/etc/hosts`, `/etc/os-release`, listed installed libraries, and checked for `socat`/`nc`/`curl`.
- `podman inspect weftwise`: `SecurityOpt [label=disable]`, `NetworkMode pasta`, and a `wayland-0` bind mount.
- `curl` probes from `weftwise` to `host.containers.internal`, against host ports bound to loopback and to wildcard addresses.
- `weftwise/.devcontainer/devcontainer.json` (Wayland block) and `cdocs/proposals/2026-07-15-in-container-headed-electron.md:115-125`.
- VoiceMode source: `README.md`, `flake.nix`, `config.py:545,777-778`, `conch.py:133`, and the service templates.
- Docs, pulled raw: `channels-reference` (`:440-442`), `channels` (`:280`), `remote-control` (`:14,321,343`), `hooks` (Timeouts, Exit code 0, PreToolUse decision control).
- The `claude` 2.1.283 binary: the dialog-kind to `waitingFor` mapping.

## Section-by-Section Findings

### Part 1: same-container messaging (check 1)

**Verified, with small corrections applied inline.**
`weftwise` has six sockets in `/run/user/1000/cc-socks`, but only five are backed by live processes (all `claude --dangerously-skip-permissions`). `1342209` is a stale socket from an exited session.
`/run/user/1000` inside the container is not a tmpfs: it sits on the container's own filesystem, and only `wayland-0` is a bind-mounted tmpfs.
Neither point changes the conclusion. Same-PID-namespace peers are exactly the case the docs say works.

- **Non-blocking (finding 4).** "Publish the socket path somewhere readable inside the container" needs a caveat.
  `~/.claude` is bind-mounted and shared by the host and *every* lace container, so a path file there would leak across projects. Publish under a container-local path such as `/run/user/1000/`.
- **Non-blocking (finding 5).** The same shared `~/.claude` means a user-scope `Stop` hook or tier-2/3 `AskUserQuestion` hook in `~/.claude/settings.json` fires in every session on the host and in every container.
  Scope these hooks to the project (`.claude/settings.local.json`), or guard them on the container-local path file.
- The overseers all run in bypass mode. The parent report's "conversationalist in bypass mode plus `crossSessionInbound: "accept"`" still applies, and it is worth one line here.

### Part 1: audio passthrough (check 2)

- **Blocking (finding 1): the recipe omits the in-image audio stack, and its backend reasoning is wrong.**
  - `weftwise` is Debian 12 (bookworm), and the only audio library installed is `libasound.so.2`. There is no `libportaudio2`, no `libpulse0`, no `libasound2-plugins`, and no `ffmpeg`, so `sounddevice` has nothing to open.
  - Debian's `libportaudio2` is built against ALSA, not PulseAudio. The working path is PortAudio, then ALSA's `pulse` PCM from `libasound2-plugins`, then the bind-mounted `pulse/native`. That is exactly why VoiceMode's own Debian install line (`README.md:131`) lists `libasound2-plugins`.
  - The Nix flake shipping `libpulseaudio` next to `alsa-lib` does not show that PortAudio's pulse host API is used.
  - The recipe therefore needs:
    - (a) image or `postCreateCommand` packages: `libportaudio2 libasound2-plugins libpulse0 ffmpeg`, plus `uv` for VoiceMode.
    - (b) an ALSA default routed to pulse (`/etc/asound.conf`: `pcm.!default { type pulse }` and `ctl.!default { type pulse }`), unless the package's `conf.d` snippet already does it.
    - (c) `PULSE_SERVER=unix:/run/user/1000/pulse/native`, which is then actually load-bearing.
  - Empirical test 1 should assert `sd.query_devices()` shows a `pulse`/`default` device.
- **Non-blocking (finding 6).** Prefer `pulse/native` over `pipewire-0` rather than presenting them as equivalent.
  The native PipeWire socket exposes the whole PipeWire graph, including video and screencast nodes. The pulse socket is audio-scoped.
  The electron proposal also lists pipewire among the sockets *not* to mount, with dbus called out "in particular". It does not clear pipewire, so "the risk is dbus specifically, not PipeWire" overstates it.
  Also state the inherent grant: every bypass-mode agent in the container can record the microphone.
- **Verified.** The Wayland precedent (`runArgs --mount`, the `postStartCommand` chown, and the lace typed-mount socket limitation in the TODO) is accurately described. `label=disable` is confirmed on `weftwise`.
  The host `pulse/native` is `srw-rw-rw- mjr:mjr` and the container user is uid 1000, so the report's UID reasoning holds.
- **pasta reachability, resolved empirically (inline fix).**
  - Host listeners bound to a wildcard address (`*:22430`, `0.0.0.0:57621`) connect via `host.containers.internal`.
  - Listeners bound to `127.0.0.1` (`:631`, `:8080`) are refused.
  - So host STT/TTS must bind a non-loopback address. VoiceMode's whisper launcher binds `0.0.0.0`; Kokoro's bind address is upstream and unverified.
- **Non-blocking (finding 7).** Fedora Workstation's default firewalld zone opens ports 1025-65535, so `0.0.0.0:2022` and `0.0.0.0:8880` are LAN-exposed by default. Add a `WARN`, and suggest binding to the pasta-visible host address or adding a firewalld rule.
- **Conch path (inline fix).** `conch.py:133` hardcodes `Path.home()/".voicemode"/"conch"`, and `VOICEMODE_BASE_DIR` does not move it. A shared conch needs the mount at each container user's `~/.voicemode`.

### Wake paths

- **Inline fix.** Neither `socat` nor `nc` exists in `weftwise`. Install `socat` or use `python3`, which is present. `podman exec` also needs `-i` to forward stdin.
- The `connectto` reasoning is fine: with `label=disable`, exec'd processes are unconfined anyway.

### Part 2: channels relay and Remote Control (check 3)

- **Channels, verified verbatim.** `channels-reference.md:440`: "Both stay live ... applies whichever answer arrives first and closes the other". `:442`: "Relay covers tool-use approvals like `Bash`, `Write`, and `Edit`. Project trust and MCP server consent dialogs don't relay."
  The docs do not name `AskUserQuestion` as excluded. It is simply absent from the list, and `channels.md:280` disables it under `-p`. The report's "explicitly not `AskUserQuestion`" in Part 2's direct answer and the BLUF slightly overstates this. "Not documented as covered" is accurate.
- **Remote Control: the report was wrong, fixed inline.**
  The quoted "encrypted bridge" sentence does not appear in `remote-control.md`.
  The docs are *not* silent. Limitations (`:343`): "Claude Code keeps permission prompts and `AskUserQuestion` questions open until you answer them" when forwarding dialogs, and push notifications cover "permission prompts and questions" (`:321`).
  So Remote Control is a documented concurrent answer surface for `AskUserQuestion`, but for a human on Anthropic's clients, not a programmatic entry for the bridge. The report's bottom line (no *bridge* mechanism) survives, and the ranking row is corrected.
- **Cross-session messages.** The "queues, doesn't interrupt" inference is sound: messages are read "between tool calls", and `AskUserQuestion` is an in-flight tool call.

### Part 2: tier 3 vs tier 2 (check 4)

- **The semantics are correct.** For the local-dialog fallback the hook returns *nothing*: exit 0 with no output ("no decision; normal permission flow applies").
  A harness timeout has the same effect: "A timed-out `command` ... hook doesn't block the tool call."
  Do not return `ask`; that adds a confirmation prompt instead of simply falling through.
  The hook should self-time-out with `exit 0` a few seconds under its configured `timeout`, so the fallback is deliberate rather than a kill.
  I replaced the report's "fresh docs check ... treated as incomplete search" sentence with the docs citations.
- **Non-blocking (finding 8).** The recommendation is defensible for the user's "alternate surface" wish, but it must state tier 3's two costs:
  - (a) During the wait window the question is invisible at the terminal, so a user at the keyboard just waits.
  - (b) It is voice-first-then-local, not first-answer-wins. A voice answer arriving after fallback is lost, because the hook has exited and a cross-session message cannot answer the open dialog.

  Mitigation: skip the relay while the user is present, reusing the `CLAUDE_CLIENT_PRESENCE_FILE` pattern documented for Remote Control push.
  Also note that tier 3 needs a reply channel, for example a per-question reply file the in-container conversationalist writes. The shared container filesystem makes that easy.
  For incrementalism, tier 2 remains the lower-cost v0. The report should present tier 3 as the pick given the user's preference, not as strictly dominant.

### Part 2: tmux send-keys and `waitingFor` (check 5)

- **Non-blocking (finding 2): `waitingFor: "dialog open"` does not identify `AskUserQuestion`.**
  In the 2.1.283 binary, about 15 dialog kinds map to `waitingFor: "dialog open"`. They include "continue on usage credits or switch models", "retry on fallback model", the managed-settings review, and the auto-mode classifier billing notice (Enter continues).
  So the field is an undocumented, generic "some modal is up" signal. Injecting a digit or Enter gated on it could answer a *different* dialog, some of which change billing or model.
  The report must say this. A real gate would need the dialog kind, for example by pairing it with a `PreToolUse` hook on `AskUserQuestion` that writes a marker, which effectively turns it back into tier 3.
- **Non-blocking (finding 3): topology mismatch.**
  In this report's design the conversationalist lives *inside* the container, but `tmux send-keys` into the overseer's pane is a host-side action, and the user's tmux server is on the host.
  The tmux spike needs a host-side agent, which reintroduces exactly the host/container split this report removes. State that.
- The pane-ID and pty reasoning, and the fragility risks, are accurate. It is correctly kept out of v0.

## Inline edits made to the report

1. The BLUF and Part 1 now say five live sessions plus one stale socket, not six sessions. They also say `/run/user/1000` is a container-private directory, not a tmpfs, and "sixth live peer".
2. The `PULSE_SERVER` citation is corrected. `README.md:131,187` never mention it; it appears only in WSL troubleshooting files. The `README.md:131` package list is now quoted accurately, including `libasound2-plugins`.
3. The pasta "unverified" paragraph is replaced with the empirical wildcard-vs-loopback result and the whisper bind citation. The unverified list and test 2 are updated to match.
4. The conch path is hardcoded and independent of `VOICEMODE_BASE_DIR`, and the mitigation sentence is corrected.
5. The wake path now uses `podman exec -i` and notes that `socat` is missing.
6. The Remote Control paragraph is rewritten with verbatim docs quotes, the non-existent "encrypted bridge" quote is removed, and the ranking row 5 and unverified item are updated.
7. The "fresh docs check ... incomplete search" meta-sentence is replaced with the hooks-docs citations.

## Verdict

**Revise.**
One blocking item: the audio recipe must add the in-image audio stack and the ALSA-to-pulse routing, and correct the backend claim (finding 1). As written it fails at `query_devices()`.
Findings 2, 3 and 8 are caveats the report's recommendations need to carry. The rest is polish.
The same-container messaging conclusion, the channels scoping, the tier-3 fallback semantics, and the "no programmatic concurrent surface" answer all hold.

## Action Items

1. [blocking] Audio recipe: add `libportaudio2 libasound2-plugins libpulse0 ffmpeg` and `uv` to the image or `postCreateCommand`, add the ALSA default-to-pulse config, and set `PULSE_SERVER`. Replace the "PortAudio pulse hostapi" claim with PortAudio to ALSA to the `pulse` plugin.
2. [non-blocking] State that `waitingFor: "dialog open"` covers about 15 dialog kinds, some of which touch billing or model, so it cannot safely gate `send-keys` alone.
3. [non-blocking] Note that the tmux path needs a host-side agent, in tension with the in-container design.
4. [non-blocking] Publish the socket path container-locally, not under the shared `~/.claude`.
5. [non-blocking] Project-scope the `Stop` and `AskUserQuestion` hooks, since `~/.claude/settings.json` is shared across the host and all containers.
6. [non-blocking] Prefer `pulse/native` over `pipewire-0`, soften the "dbus specifically, not PipeWire" line, and note the mic grant to all in-container agents.
7. [non-blocking] Add a `WARN` that `0.0.0.0`-bound STT/TTS are LAN-exposed under Fedora's default firewalld zone.
8. [non-blocking] Tier 3: state that the hook self-times-out with a silent `exit 0` (not `ask`), the invisible-wait and lost-late-answer costs, the presence-file mitigation, and the reply channel. Frame tier 3 as the preference-driven pick and tier 2 as the incremental one.
9. [non-blocking] Soften "explicitly not `AskUserQuestion`" for channels to "not documented as covered".

## Questions for the user

1. Voice question handling when you're at the keyboard?
   (a) Always relay to voice first (tier 3, wait window).
   (b) Relay only when a presence file says you're away.
   (c) Tier 2 redirect only, no wait window.
2. Host STT/TTS exposure?
   (a) Bind `0.0.0.0` and add a firewalld rule restricting to the pasta path.
   (b) Run STT/TTS inside each container (GPU passthrough, more cost).
   (c) Accept LAN exposure.
