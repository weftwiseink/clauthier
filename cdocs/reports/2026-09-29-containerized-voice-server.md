---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-29T11:20:00-07:00
task_list: voice/converser-lace-feature
type: report
state: live
status: review_ready
tags: [analysis, voice, architecture, security, networking, packaging, podman]
---

# Containerizing the converser's host voice server with podman

> BLUF(opus/voice/converser-lace-feature): **Go hybrid.** Run whisper.cpp and Kokoro-FastAPI as rootless Quadlet containers from their upstream images, with loopback-only published ports and the GPU passed in through the host's existing NVIDIA CDI spec.
> Keep `voicemode serve` on the host, exactly as the accepted design has it.
> Nearly all of the mess in the accepted `converser-host install` comes from whisper and Kokoro: brew install and pins, VoiceMode's Kokoro installer, rewriting the start script, the rm/reload/mask dance, and the sudo firewall backstop.
> Hybrid removes that work or reduces it to one line each. It cuts the install from 7 ordered steps (one of them sudo, 6 firewall rules) to about 4 steps plus an optional `setsebool`, and it gets CUDA without installing the CUDA toolkit.
> Containerizing `serve` as well brings audio back into a container: a pulse directory mount, `SecurityLabelDisable`, audio packages, and an image we build ourselves.
> It also adds one bug found in the source (verified/source): separate PID namespaces break the shared conch. `_check_and_clear_stale_lock` unlinks the live lock file when the holder's PID does not exist in the caller's namespace, which reopens cross-project talk-over unless every `serve` container runs with `--pid=host`.
> A shared podman network between the devcontainer and the voice containers is possible, but it means moving lace containers off `pasta`. That is a lace-wide ingress change with a portless precedent for breakage, so it is not worth doing for stage 1.
> Separately, and in any option: a `--secret` mount in the devcontainer's `runArgs` can replace `instance handoff` and its re-run after every rebuild.

## Scope and evidence

Question: can the host side of [`2026-09-29-converser-host-voicemode-serve.md`](https://github.com/weftwiseink/lace/blob/00f6a8e/cdocs/proposals/2026-09-29-converser-host-voicemode-serve.md) (accepted, round 5; read at lace `00f6a8e`) run as rootless podman containers under Quadlet, and does that make the host setup simpler?
Other inputs are the superseded in-container design (`2026-09-28-converser-lace-feature.md`), the vetting, broker-split, and fork-complexity reports, and reviews r1 and r3-r5 of the accepted proposal.

Evidence labels follow the proposal: **verified/live** (read-only inspection of this host, 2026-09-29), **verified/source** (VoiceMode `126d15e` at `build/research/voicemode`), **verified/docs** (the local `podman-systemd.unit(5)` man page or fetched upstream READMEs), **plausible**, **unverified**.
Nothing was pulled, created, or installed.

### Host facts (verified/live)

- podman 5.8.2, netavark with aardvark-dns, rootless, cgroup v2, default rootless network command `pasta`; Quadlet generator at `/usr/lib/systemd/user-generators/podman-user-generator`; systemd 259. There is no `~/.config/containers/systemd/` yet.
- Only the default `podman` bridge network exists. All five lace containers run `net=pasta`, `SecurityOpt=[label=disable]`, and publish their lace ports on `0.0.0.0` (for example weftwise `22425`, `22427`).
- SELinux is Enforcing. `/run/user/1000/pulse/native` and `pipewire-0` are `user_tmp_t`; `pipewire-pulse` runs `unconfined_t`. `pulse/` is a `0700` directory holding `native` and `pid`.
- `pactl list short sources` lists a `.monitor` for every sink (HDMI, Scarlett, generic USB). Any pulse client can record system output.
- Host is Aurora `aurora-dx-nvidia-open` 44, with an RTX 3080 on driver 595.71.05. `/etc/cdi/nvidia.yaml` exists (CDI 0.5.0: `nvidia.com/gpu=0`, `=<UUID>`, `=all`) and injects `libcuda.so` and `nvidia_icd.x86_64.json`, so CUDA and Vulkan both reach a container with no CUDA toolkit on the host. `nvidia-ctk cdi list` works, and the binary is image-provided (no owning rpm). `/dev/nvidia0` and `/dev/dri/renderD12*` are `0666`.
- SELinux booleans: `container_use_devices --> off`, `container_use_dri_devices --> on`.
- The podman secrets directory `~/.local/share/containers/storage/secrets/` is `0700`, and no secrets exist yet.
- In weftwise, `podman exec weftwise id` gives `uid=1000(node)`.

### External facts

- whisper.cpp publishes `ghcr.io/ggml-org/whisper.cpp:main`, `:main-cuda` (amd64 only), `:main-musa`, and `:main-vulkan`. They include `whisper-server`, curl, and ffmpeg; the README runs `$IMAGE whisper-server --host 0.0.0.0 -m /models/...` (verified/docs, [README](https://github.com/ggml-org/whisper.cpp/blob/master/README.md)). The tags float, so pin by digest. The image entrypoint (believed to be `bash -c`) is unverified.
- Kokoro-FastAPI publishes `ghcr.io/remsky/kokoro-fastapi-cpu:latest` and `ghcr.io/remsky/kokoro-fastapi-gpu:latest` (CUDA 12.6; `-cu128` for Blackwell) on port 8880 (verified/docs, [repo](https://github.com/remsky/Kokoro-FastAPI)). These are unverified: whether the image bundles the model weights or fetches them on first start, which health endpoint it exposes, and whether it sets `UVICORN_LIMIT_MAX_REQUESTS`.
- VoiceMode ships no Containerfile or compose file (verified/source: none in the tree), so a `serve` image would be ours to build and maintain.
- NVIDIA's CDI guide runs rootless GPU containers with `--device nvidia.com/gpu=all --security-opt=label=disable`, or suggests `setsebool -P container_use_devices on` for SELinux hosts (verified/docs, [NVIDIA CDI](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/1.16.0/cdi-support.html)). Neither has been tried on this host.
- Quadlet (verified/docs, local man page) supports:
  - templates (`foo@.container` becomes `foo@.service`, with per-instance drop-ins in `foo@inst.container.d/`);
  - the keys `AddDevice=`, `Secret=`, `SecurityLabelDisable=`, `SecurityLabelType=`, `PublishPort=` (IP-qualified), `Network=` (repeatable, `.network` units, `Internal=`), `Pod=`, `HealthCmd=`, and `Notify=healthy`, which delays unit readiness until the healthcheck passes;
  - `PodmanArgs=` for anything without a key, since there is no `Pid=` key.
  - The man page also warns that a first image pull can exceed the 90s start timeout: pre-pull, or set `TimeoutStartSec=900`.

## 1. Can the pieces run as rootless Quadlet containers?

| Piece | Needs host audio? | Container feasibility | Notes |
|---|---|---|---|
| whisper.cpp server | No, pure HTTP | **Yes**, upstream image | `main-cuda` via CDI (no toolkit needed) or `main-vulkan`; the model is a read-only volume |
| Kokoro-FastAPI | No, pure HTTP | **Yes**, upstream image | `kokoro-fastapi-gpu` via CDI, or `-cpu` |
| `voicemode serve` | **Yes**: PortAudio via `sounddevice` for mic and speaker | Yes, with costs | Needs our own image, a pulse socket, SELinux relaxation, the shared conch, and `--pid=host` |

### How audio would reach a `serve` container

Choose between two sockets, and between two ways of mounting one:

- **pipewire-pulse socket.** Mount the directory `/run/user/1000/pulse` and set `PULSE_SERVER=unix:/run/user/1000/pulse/native`; inside the container, PortAudio goes through ALSA's `pulse` plugin (`libportaudio2 libasound2-plugins libpulse0`, plus `asound.conf`). This is the in-container recipe from the superseded proposal, and it is known to work.
- **PipeWire native socket** (`pipewire-0`) with `pipewire-alsa` in the image. It is more capable (a full graph client) and less tested; there is no reason to prefer it.
- **Directory mount, not file mount.** A directory mount avoids inode pinning (verified by the vetting report's namespace test). It still assumes `pipewire-pulse` recreates only the socket and not `pulse/` itself (unverified). A Quadlet `[Unit]` can add `PartOf=pipewire-pulse.service`, which restarts `serve` along with the audio server and removes the pinning concern.
- **SELinux.** A labeled container (`container_t`) connecting to a `user_tmp_t` socket owned by an `unconfined_t` process fails with `EACCES`. The superseded proposal observed exactly that for bind-mounted `pulse/native` without `label=disable`. The `serve` container therefore needs `SecurityLabelDisable=true` or a custom policy module. Devcontainers get `label=disable` from the devcontainer CLI, but a Quadlet container does not, so it would be an explicit line.

### Does a `serve` container bring back the audio risks?

| Risk the host-serve design removed | Containerized `serve` | Why |
|---|---|---|
| Agents in the devcontainer capture the mic or **monitor sources** | **No** | The pulse socket goes to the `serve` container only; the devcontainer still sees only the token-gated MCP port. The `serve` process can record monitors, as host `serve` already can, since it runs as the user. |
| **Inode pinning** on pipewire restart | Reintroduced in reduced form | Mitigated by the directory mount plus `PartOf=`; host `serve` has no such failure mode |
| **Pulse module loading** | Same as host | Any pulse client, host or container, can plausibly load modules (unverified; mutating, so not tested) |
| SELinux confinement | Neutral to slightly better | Host `serve` runs `unconfined_t`. A `label=disable` container is still namespaced and rootless. |
| Audio install inside a container | Reintroduced | Only in an image we own, not in every devcontainer |
| **Cross-project talk-over (the conch)** | **Reintroduced unless `--pid=host`** | See below |

**Conch across PID namespaces (verified/source).**
`Conch.try_acquire` calls `_check_and_clear_stale_lock` first (`conch.py:348,388-440`).
That function reads the holder's `pid` from `~/.voicemode/conch` and calls `LOCK_FILE.unlink()` when `psutil.pid_exists(pid)` is false in the *caller's* namespace.
Suppose `serve@weftwise` and `serve@lace` each run in their own container over a shared `~/.voicemode` volume.
B then sees A's container-local PID as dead and deletes the live lock file. B flocks a fresh inode while A holds the old one, and both talk at once.
The failure is worse when PID 1 is involved: `pid_exists(1)` is true in every namespace, so a stale lock written by a PID-1 `serve` never clears through the PID path.
The fix is `PodmanArgs=--pid=host` on every `serve` container (plausible that rootless podman permits it; unverified here), or all instances in one pod with a shared PID namespace.
Mixing host and container `serve` instances has the same bug.
The accepted host design avoids all of this because every instance shares the host PID namespace.

### One appliance container, a pod, or separate units?

- **One "voice appliance" container** running whisper, Kokoro, and N `serve` processes needs an in-container supervisor and loses per-instance `systemctl` control and journald separation. Reject.
- **A pod** (`converser.pod` with whisper, Kokoro, and `serve@`) shares one network namespace, so members reach each other on `127.0.0.1`. A PID namespace is shared only through `PodmanArgs=--share=...` (Quadlet has no key for it). Pods do not fit per-project `serve@` templates cleanly.
- **Separate `.container` units**, with a `.network` unit if `serve` is containerized, map one-to-one onto the accepted design's three units, and Quadlet's generated service names can keep the same names (`converser-whisper.service`, `converser-kokoro.service`). **Recommended shape.**

## 2. What containerization simplifies

### Every messy step in the accepted design

| Accepted `converser-host` step | Hybrid (whisper and Kokoro containerized) | Full (`serve` too) |
|---|---|---|
| 1. Firewall backstop (sudo, 3 port specs × runtime and permanent) | **Removed** (optional). Its threat was upstream wildcard-bound units, and in hybrid no VoiceMode installer ever runs, so no `0.0.0.0` start script exists on the host. Publishing is explicit `127.0.0.1:`, and `status`'s `ss -ltn` check stays as the gate. | Removed |
| 2. `uv tool install voice-mode==8.12.0` plus the scoping stop-check | **Kept** | Becomes a `podman build` of our `serve` image with the same pin. The scoping check runs against a throwaway container. |
| 3. `brew install whisper.cpp`, `brew pin whisper.cpp ggml llama.cpp`, pull `llama.cpp`/`sdl2-compat` | **Removed.** Replaced by an image pinned by digest. | Removed |
| 3b. Model download to `~/.local/share/converser-host/models/` | **Kept** (mounted `:ro`) | Kept |
| 4. `voicemode kokoro install --no-auto-enable` (several GB, Python and torch environment on the host) | **Removed.** Replaced by `kokoro-fastapi-{gpu,cpu}` at a pinned digest. | Removed |
| 5. `rm` upstream units, `daemon-reload`, `mask` × 3 | **Reduced to one line, no `rm`.** No installer writes unit files, so `mask` cannot collide. Keep it as a zero-cost guard: `voicemode whisper model install` runs `pgrep -f whisper-server`, which also matches the containerized process visible on the host, then tries `systemctl --user start voicemode-whisper` (plausible; `whisper_model_unified.py:169-179`). | Dropped. VoiceMode never runs on the host. |
| 6a. Derive the Kokoro start script (copy, rewrite host, check for a literal `--host 127.0.0.1`, reject `0.0.0.0`) | **Removed.** The bind inside the container is irrelevant; `PublishPort=127.0.0.1:8880:8880` sets the host exposure. | Removed |
| 6b. Carry upstream's `WorkingDirectory`, `UVICORN_LIMIT_MAX_REQUESTS`, `Restart=always` (r5 R3) | **Reduced to `Restart=always`.** The image owns its run context. | Same |
| 6c. Install units, enable, start | **Changed.** Write 2 `.container` files, `daemon-reload`, `podman pull` (or `TimeoutStartSec=900`), start | Changed: 3-4 Quadlet files |
| 7. Verify: `ss -ltn` loopback-only; `is-enabled == masked` | **Kept** (the listener is `rootlessport` or `pasta` on `127.0.0.1`). The mask check stays if the mask does. | `ss` check kept; masks irrelevant |
| `serve@` unit with command-line pins and `ExecStartPre` token length check | **Unchanged** | Becomes `converser-serve@.container`: pins as `Environment=` (Quadlet has no env-file override issue if nothing sets `EnvironmentFile=`), token via `Secret=...,type=env` |
| `instance add`: port, token, `0600` env file | **Kept**, and also `podman secret create` (below) | Token only as a podman secret; port in an instance drop-in |
| `instance handoff` over `podman exec` stdin, re-run after every recreate | **Replaceable in every option** by a `--secret` mount in `runArgs` (below) | Same |
| `pasta:-T,<port>` forward in the devcontainer | Kept | Kept (see the shared-network analysis) |
| Kokoro per-start network fetch (unverified) | Model bundled in the image or fetched once (unverified) | Same |
| CUDA unavailable (no `nvcc`), whisper on Vulkan or CPU | **Improved.** CUDA through CDI, with no toolkit. | Same |

The count drops from 7 ordered host steps (one sudo step with 6 firewall rules, 3 brew pins, one derived script, and a 3-command ordering-sensitive mask sequence) to 4 steps with no ordering hazard: install VoiceMode, download the model, write the Quadlets and start them, verify.
Sudo is needed only for the optional GPU boolean.

### Token handoff: podman secrets, in any option

`instance add` can also run `podman secret create converser-<project> ~/.config/converser-host/instances/<project>.token`.
The token is read from a file and is never on argv.
The secret store is the `0700` directory above, and the file driver stores values unencrypted, which is equivalent to the `0600` env file.
The devcontainer then gets the token at create time from `runArgs`:

```jsonc
"runArgs": ["--network", "pasta:-T,8765",
            "--secret", "converser-weftwise,type=mount,target=/run/secrets/converser-token,uid=1000,mode=0400",
            "--env", "CONVERSER_PORT=8765"]
```

This survives every rebuild with no re-run, and it removes `instance handoff` and the token half of gate (s).
The launcher reads `/run/secrets/converser-token` and `$CONVERSER_PORT` in place of `~/.config/converser/{token,port}`.
Container processes see the token either way, so the exposure is unchanged.
Unverified: that the devcontainer CLI passes `--secret` through `runArgs` unmodified (plausible, since it passes `--network`), and the absolute-`target` plus `uid`/`mode` form on podman 5.8.
`podman inspect` of the devcontainer shows the secret *name*, not the value (plausible).

### Could the devcontainer and the voice containers share a podman network?

Mechanically, yes.
Rootless netavark bridge networks live in a per-user rootless network namespace, so any of the user's rootless containers can join one. A devcontainer started with `--network converser-weftwise` could then reach `serve` by name over aardvark-dns, with no published port and no `-T` forward.
Before adopting it:

- **It replaces `pasta`.** `pasta` is an exclusive network mode that cannot be combined with a bridge network on the same container (plausible, from podman's network-mode semantics). The devcontainer would move to bridge plus `rootlessport` publishing for all of lace's ports. Lace's portless feature already broke once on a subtle difference in how ports are delivered under pasta (a loopback-only proxy never sees pasta-delivered traffic; `devcontainers/features/src/portless/README.md`). Bridge delivery differs again and is untested. This is a lace-wide change, and the accepted design keeps lace out near-term.
- **Isolation needs one network per project.** A shared network lets every member reach every `serve` port, which leaves the token as the only gate, as today. Per-project networks put `serve@<project>` on two networks: its project network, plus a backend network to reach whisper and Kokoro.
- **Gain:** the source address becomes meaningful, so `VOICEMODE_SERVE_ALLOWED_IPS` could pin `serve` to its devcontainer's address as a weak second factor. `pasta:-T` erases this today. And `serve` would have no host listener at all.
- The host cannot reach rootless bridge addresses. So a shared network is only possible when `serve` is containerized; host `serve` must reach whisper and Kokoro through loopback-published ports.

Verdict: a good fit for later lace host-service hooks, where lace owns network creation. For stage 1 it is not worth the lace-wide change.

### Firewall

Rootless published ports bind real host sockets (`rootlessport` or `pasta`), so firewalld's input rules would still apply to them.
The backstop is unnecessary for a different reason: nothing in hybrid or full can create a wildcard listener unless someone edits a Quadlet `PublishPort=` or runs a VoiceMode installer by hand, and the `ss -ltn` verification catches both.

> NOTE(opus/voice/converser-lace-feature): Live inspection shows every lace container publishing its ports on `0.0.0.0`, and the `FedoraWorkstation` zone opens `1025-65535/tcp`, so those ports (for example weftwise `22425`, `22427`) are plausibly LAN-reachable today.
> That is outside this report's scope and independent of voice, but it is a bigger exposure than anything the converser firewall backstop covered.

## 3. What it costs or breaks

- **GPU.** CDI is ready on this host. Under Enforcing, a labeled container with `nvidia.com/gpu=all` is plausibly blocked by `container_use_devices=off`. Two fixes: `sudo setsebool -P container_use_devices on` (host-wide, but it only matters for containers explicitly given devices), or `SecurityLabelDisable=true` on the two GPU containers (they run pinned third-party images unconfined by SELinux, while still rootless and namespaced). Prefer the boolean. CPU-only is acceptable for stage 1 (gate r can run STT-only, and Kokoro has a `-cpu` image). Driver upgrades need a regenerated CDI spec. The spec's boot-time timestamp suggests Aurora regenerates it at boot (plausible).
- **Images.** whisper and Kokoro come from upstream, pinned by digest, with a manual bump that matches the `voice-mode==8.12.0` philosophy. Do not use `AutoUpdate=registry`. Sizes are unverified; `kokoro-fastapi-gpu` is plausibly several GB, comparable to the host Kokoro install it replaces. A `serve` image (full option only) is ours: a Containerfile with Python, `uv`, `voice-mode==8.12.0`, the audio packages, `asound.conf`, and rebuilds on every VoiceMode bump.
- **Shared conch.** In hybrid nothing changes: host `serve` processes share `~/.voicemode/conch` and the host PID namespace. In full, it needs a shared `~/.voicemode` bind (`Volume=%h/.voicemode:<home>/.voicemode`, with `UserNS=keep-id` for matching ownership) plus `--pid=host`, and `--pid=host` also shows every host process's argv to the `serve` container.
- **Per-project instances.** Hybrid is unchanged (`converser-serve@.service`). Full uses `converser-serve@.container` with an instance drop-in `converser-serve@weftwise.container.d/port.conf` carrying `PublishPort=127.0.0.1:8765:8765` and `Secret=converser-weftwise,type=env,target=VOICEMODE_SERVE_TOKEN`.
- **Control socket and hotkey.** Hybrid is unchanged. In full, `control.sock` must land in a bind-mounted state directory; host-side connect to a socket created by a `label=disable` container is plausible. Mapping the conch holder's PID to a project works only with `--pid=host`, via `/proc/<pid>/cgroup` under `converser-serve@<project>.service` (plausible).
- **Latency.** Whisper and Kokoro requests take one extra userspace hop (`rootlessport` or `pasta`) per HTTP call, which is negligible against seconds of STT and TTS. CUDA whisper is likely faster than the bottle's Vulkan or CPU path (unverified: whether that bottle's Vulkan works on this GPU).
- **SELinux.** Hybrid: the whisper and Kokoro containers are labeled (`container_t`), which is stronger than the host processes they replace (`unconfined_t`). The model volume uses `:Z`, so it is relabeled for the container. Full: `SecurityLabelDisable=true` on `serve`, which is no weaker than host `serve`.
- **Startup ordering.** `Notify=healthy` with `HealthCmd=` makes `converser-whisper.service` ready only when the server answers. `serve@`'s existing `After=` then orders against real readiness, which is better than today's process-started ordering. A first start pulls the image, so pre-pull or set `TimeoutStartSec=900`.
- **Updates.** A digest bump in the Quadlet, `daemon-reload`, restart. Rollback is the previous digest. That is simpler than `brew unpin && upgrade && pin` plus re-deriving the Kokoro script.
- **Logout and linger.** Unchanged: Quadlet user services stop with the user manager when `Linger=no`.
- **Debuggability.** `podman logs` and journald both work, since Quadlet logs to the journal. One more layer to understand.

## 4. Recommendation

### Comparison

| | A. Host packages (accepted) | **B. Hybrid: whisper and Kokoro in Quadlet, `serve` on host** | C. Full: `serve@` also in Quadlet | D. C plus a shared devcontainer network |
|---|---|---|---|---|
| Host install steps | 7 ordered, ordering-sensitive | **4**, no ordering hazard | 4-5, plus an image build | C plus network units and lace changes |
| Sudo | Firewall (6 rules) | Optional `setsebool` (GPU) | Same as B | Same as B |
| Security posture | Loopback binds; masks and firewall guard against VoiceMode installers | Loopback publishes; no VoiceMode installer ever runs; STT/TTS `container_t` | B, plus `serve` in a `label=disable` container with `--pid=host` | C, plus source-IP allowlisting possible |
| Audio risk | None added (host `serve`) | **None added** | Pulse mount in the `serve` container: pinning (mitigable), module loading as on host; no agent exposure | Same as C |
| Conch correctness | Correct | **Correct** | Needs `--pid=host` or talk-over returns (verified/source) | Same as C |
| GPU | Vulkan bottle or CPU; CUDA needs the toolkit | **CUDA via CDI**, no toolkit | Same as B | Same as B |
| Maintenance | brew pins ×3, uv pin, Kokoro installer, derived script | 2 image digests, uv pin | 2 digests plus our `serve` image | C plus lace network code |
| Stage-1 fit | As designed | **Drop-in: `serve@` unit, `instance add`, and the container side unchanged** | Rewrites the `serve` path and its gates | Blocks on lace |
| Android/remote and lace host-service hooks | Neutral | Good: Quadlet files are artifacts a future lace hook can emit | Best long-term shape for lace-owned host services | Target shape for hooks, not for stage 1 |

**Recommend B.**
It removes the parts the user finds messy, all of which live in whisper and Kokoro, and it leaves the accepted `serve` design and its five review rounds of audio, conch, and token reasoning intact.
C's only extra gain is that VoiceMode never touches the host, and it pays for that with audio in a container, an owned image, `label=disable`, and a conch bug that needs `--pid=host`.
Revisit C or D if lace host-service hooks land, or if the Android/remote stage moves `serve` off the desk.

### Sketch: Quadlet files for B

`~/.config/containers/systemd/converser-whisper.container`:

```ini
[Unit]
Description=converser STT (whisper.cpp server)

[Container]
ContainerName=converser-whisper
Image=ghcr.io/ggml-org/whisper.cpp:main-cuda@sha256:<pinned>
AddDevice=nvidia.com/gpu=all
Volume=%h/.local/share/converser-host/models:/models:ro,Z
# Host exposure is set here, not by --host: loopback only.
PublishPort=127.0.0.1:2022:2022
# One string: the image entrypoint is believed to be `bash -c` (unverified; check with podman image inspect).
Exec="whisper-server --host 0.0.0.0 --port 2022 --model /models/<model>.bin --inference-path /v1/audio/transcriptions --threads 8 --convert"
HealthCmd=curl -fsS http://127.0.0.1:2022/
Notify=healthy
NoNewPrivileges=true
DropCapability=all

[Service]
Restart=on-failure
TimeoutStartSec=900

[Install]
WantedBy=default.target
```

`~/.config/containers/systemd/converser-kokoro.container`:

```ini
[Unit]
Description=converser TTS (Kokoro-FastAPI)

[Container]
ContainerName=converser-kokoro
Image=ghcr.io/remsky/kokoro-fastapi-gpu:<version>@sha256:<pinned>
AddDevice=nvidia.com/gpu=all
PublishPort=127.0.0.1:8880:8880
# Health path unverified; /v1/models or /health.
HealthCmd=python3 -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8880/v1/models')"
Notify=healthy
NoNewPrivileges=true

[Service]
# uvicorn may exit 0 at its request limit (GH-448); always restart.
Restart=always
TimeoutStartSec=900

[Install]
WantedBy=default.target
```

For CPU-only, drop `AddDevice=` and use `kokoro-fastapi-cpu` and `whisper.cpp:main` instead.
`converser-serve@.service` stays byte-identical: its `After=converser-whisper.service converser-kokoro.service` matches the generated names. Add `Wants=` for the same two units.

### Resulting stage-1 host steps (`converser-host install` v0)

1. `uv tool install voice-mode==8.12.0`, then the throwaway-`serve` scoping stop-check (401 without the token, `[converse]` with it). Unchanged.
2. Download the whisper model into `~/.local/share/converser-host/models/` and record its sha256.
3. Write the two `.container` files, run `systemctl --user daemon-reload`, `podman pull` both digests, and `systemctl --user start converser-whisper converser-kokoro`. Then `systemctl --user mask voicemode-whisper voicemode-kokoro voicemode-serve` as a guard (no `rm` needed). For GPU, a one-time `sudo setsebool -P container_use_devices on` (or CPU images).
4. Verify: `ss -ltn` shows 2022 and 8880 on `127.0.0.1` only, both units are `active` (so healthy), and the masks hold.

`instance add` also runs `podman secret create`, and its printed `runArgs` include the `--secret` and `--env` lines. `instance handoff` becomes a fallback for a devcontainer that cannot take `--secret`.

### What changes in the accepted proposal

- **Facts:** replace the homebrew-core `whisper.cpp` and Kokoro-installer bullets with the image, CDI, and SELinux-boolean facts above. Delete the "no CUDA toolkit" consequence, since CUDA arrives via CDI.
- **`converser-host install`:** steps 1 (firewall), 3 (brew install and pins), 4 (Kokoro installer), and 6a (script derivation) are removed; step 5 becomes a one-line mask; step 6 installs Quadlet files. "Why a script, not a Homebrew formula" shrinks to one line.
- **Units:** `converser-whisper.service` and `converser-kokoro.service` become Quadlet `.container` files. `converser-serve@.service` is unchanged apart from `Wants=`.
- **Token and port contract:** add `podman secret create`, and move the container-side contract to `/run/secrets/converser-token` plus `CONVERSER_PORT`. `instance handoff` and the token and port part of gate (s) become fallback-only.
- **Design decisions:** "Whisper from homebrew-core; remove, reload, then mask" becomes "STT and TTS from pinned upstream images; mask as a guard."
- **Threat table:** "Upstream wildcard-bound whisper/Kokoro starts" drops to Very low (no VoiceMode installer runs). Add "GPU device access widened by `container_use_devices`" (Low/Low).
- **Test Plan gate (q):** drop the firewall checks; add a `podman inspect` check that the published ports are `127.0.0.1` only, and a unit-active-means-healthy check.
- **Open Question 4 (whisper acceleration):** answered by `main-cuda` via CDI, pending a first-start log line confirming the CUDA backend.
- **Stage-3b `uninstall`:** removes Quadlet files and secrets, not firewall rules. `model set` edits the Quadlet `Exec=` in place of a service drop-in.
- **Future Work:** record option D (a shared per-project podman network, source-IP allowlisting) as the lace host-service-hooks shape, and record the `--pid=host` requirement for any containerized `serve`.

## Unverified items to settle at implementation

1. whisper image entrypoint and `Exec=` quoting; ffmpeg presence for `--convert` (the README says it is included).
2. Whether the Kokoro GPU image bundles its model weights or fetches them at first start; its health endpoint; whether it sets `UVICORN_LIMIT_MAX_REQUESTS`.
3. Whether `container_use_devices=on` alone suffices for CDI NVIDIA under Enforcing rootless podman, or `SecurityLabelDisable` is needed.
4. Whether the devcontainer CLI passes `--secret` through `runArgs`, and the podman 5.8 `type=mount,target=<abs>,uid,mode` form.
5. That `pgrep -f whisper-server` on the host matches the containerized process (expected: container processes are host processes).
6. For C only: rootless `--pid=host` under Quadlet; pulse directory-mount durability across a `pipewire-pulse` restart.
