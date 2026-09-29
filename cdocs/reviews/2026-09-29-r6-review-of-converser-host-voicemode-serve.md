---
review_of: cdocs/proposals/2026-09-29-converser-host-voicemode-serve.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-29T15:50:00-07:00
task_list: voice/converser-lace-feature
type: review
state: live
status: done
tags: [fresh_agent, claims_verified, host_install, podman, quadlet, selinux, gpu, token_handling, implementability, stage_1]
---

# Review (round 6): converser on host `voicemode serve`, hybrid Quadlet STT/TTS

> BLUF(opus/voice/converser-lace-feature): **Revise.**
> The r6 hybrid holds up against the live host and upstream.
> I checked the SELinux boolean against policy, the image digests and configs against the registry, the Quadlet files with the generator, pasta `-T` with a live test, and the `--secret`/`runArgs` path against the lace and devcontainer CLI source.
> Two things block a dispatched implementer from reaching the stated end state.
> First, `uv tool install voice-mode==8.12.0` fails on this host: `simpleaudio` ships no Linux wheels and needs `alsa/asoundlib.h`, which the host does not have.
> Second, stage 1.4 needs two interactive `claude` sessions inside `clauthier` and never says who drives them or how.
> The rest is non-blocking.

## Summary Assessment

The proposal moves whisper.cpp and Kokoro into rootless, digest-pinned Quadlet containers published on `127.0.0.1` with CDI GPU access, and keeps `voicemode serve` on the host.
It delivers the token through a podman `--secret` in `runArgs`, and it retargets stage 1 at the `clauthier` container.
Nearly every load-bearing claim checks out, and several "plausible" items can move to verified (listed below).
Two findings block stage 1 as written: the `serve` install step fails on a native build, and the stage 1.4 operator model is missing.
Both are small to fix.
Verdict: **Revise**.

## Verification Log

All checks were read-only or transient (no install, pull, unit, secret, or container was created).

| Claim | Result | Evidence |
|---|---|---|
| `container_use_xserver_devices` is enough for the CDI NVIDIA nodes | **Confirmed (policy)** | `/dev/nvidia{0,ctl,-uvm,-uvm-tools}` are `xserver_misc_device_t`. `sesearch` grants `container_t` `open read write ioctl map getattr` on them only under that boolean, with no `allowxperm` ioctl filter. `/dev/dri/{card1,renderD129}` are `dri_device_t`, which `container_use_dri_devices=on` already covers. The CDI-mounted libs (`lib_t`, `textrel_shlib_t`), binaries (`xserver_exec_t`), and firmware (`lib_t`) are readable or executable by any `domain`. `nvidia-cdi-hook` runs from `container_runtime_t` with no transition to `xserver_t`. Gate u is still the live check. |
| CDI spec current | Confirmed | Spec driver 595.71.05 matches `/proc/driver/nvidia/version`. `ublue-nvctk-cdi.service` is enabled, so the plausible boot-time regeneration has a named mechanism. |
| `pasta -T,A:B` reaches a `127.0.0.1`-bound host port | **Confirmed (live)** | A transient `pasta --config-net -T 18765:18766 -- curl 127.0.0.1:18765` reached `python -m http.server --bind 127.0.0.1 18766`, and the request logged from `127.0.0.1`. The host's `127.0.0.1:18766` is unreachable directly from the namespace. |
| podman keeps a user `-T` | Plausible | Existing containers' pasta argv carries `-T none` only as podman's default. I did not verify with a real `podman run` whether a user `-T` suppresses that default. Gates i and c cover it. |
| devcontainer CLI appends `runArgs`, adds `label=disable` and `keep-id` | Confirmed | Seen in the installed 0.87.0 `devContainersSpecCLI.js`. Lace's `up.ts:1617` pushes `--label`/`--name` onto the user `runArgs` and does not add `--network`. `lace up --rebuild` maps to `--remove-existing-container`. |
| `--secret ...,target=/abs,uid=,mode=` | Confirmed (docs) | `podman-run(1)`: an absolute target is honored; `uid`/`gid`/`mode` apply to the mount type. The container already has `/run/secrets` as a `0700` tmpfs owned by uid 1000, so `node` can reach the file. |
| Quadlet files | Confirmed (generator) | The generator dry-run on podman 5.8.2 turns `Exec="..."` into one argument after the image, `AddDevice=` into `--device nvidia.com/gpu=all`, and `Notify=healthy` into `--sdnotify=healthy` with `Type=notify`. `systemd-analyze --user verify` passes on the `serve@` unit. |
| Image digests | Confirmed | All five digests match `skopeo inspect --raw` today. `:main-cuda` was built 2026-09-29T05:17Z, so the tag floats daily, as stated. |
| Image configs | Confirmed, one wording fix | whisper: entrypoint `["bash","-c"]`, root, `curl` and `ffmpeg` installed, and `whisper-server` on `PATH` via `/app/build/bin`. The flags `--inference-path` and `--convert` and the `/health` route exist upstream. Kokoro: **`Cmd`** (not `Entrypoint`) is `./entrypoint.sh`, user `appuser`, `curl` installed. The entrypoint at `404d122` is as described. |
| Kokoro model baked | **Upgrade to verified** | The image history shows `RUN \|1 DOWNLOAD_MODEL=true ... download_model.py`. |
| Model URLs and sha256 | Confirmed | HF API LFS oids and sizes match both pins. |
| Token gate vs `allow_local` | **Upgrade to verified** | `cli.py`: `TokenAuthMiddleware` is added whenever a token is set, and the IP allowlist is checked first, so both apply. A local caller without the token gets 401 from middleware before MCP parsing. The launcher preflight's "plausible" can be dropped. |
| In-container claude has the needed surface | Confirmed | 2.1.274's binary contains `ListAgents`, `SendMessage`, `crossSessionInbound`, `CLAUDE_CODE_MESSAGING_SOCKET`, and `--append-system-prompt-file`. |
| No container mounts the host-side secret or token paths | Confirmed | All five containers' home mounts are listed. None covers `~/.config/converser-host`, `~/.local/share/containers`, or `~/.local/state`. |
| `uv tool install --python 3.12 voice-mode==8.12.0` "every dependency has wheels" | **False** | See B1. |

## Section-by-Section Findings

### B1 [blocking] Host install step 2: `voice-mode` does not install on this host

`voice-mode` 8.12.0 depends on `simpleaudio` (`pyproject.toml`).
PyPI has `simpleaudio` 1.0.4 as an sdist plus macOS and Windows wheels only, so on Linux it always builds from source.
Its `setup.py` compiles `c_src/simpleaudio_alsa.c` against `alsa/asoundlib.h` and links `-lasound`.
On this host:
- `echo '#include <alsa/asoundlib.h>' | gcc -E -` fails;
- `alsa-lib-devel` is not installed, and `/usr/lib64` has `libasound.so.2` but no `libasound.so` link;
- there is no cached `simpleaudio` wheel in `~/.cache/uv`.

The only copies of the header and link are under Linuxbrew (`/home/linuxbrew/.linuxbrew/include/alsa/`, `.../lib/libasound.so`).
Install step 2 therefore fails at `uv tool install`, before the scoping stop-check, which blocks 1.1 and everything after it.
The Facts line "3.12 ... so every dependency has wheels; plausible" is wrong for this package.
VoiceMode's own Fedora line (`dnf install alsa-lib-devel ... python3-devel`, per the deep-dive report) would mean an rpm-ostree layer and a reboot, which is a second host `sudo` the design says it does not have.

`simpleaudio` is only a playback fallback: `core.py:573` reaches pydub playback only after `sounddevice` fails.
Pick one route and state it in install step 2:
- (a) build against Linuxbrew: `CFLAGS=-I/home/linuxbrew/.linuxbrew/include LDFLAGS=-L/home/linuxbrew/.linuxbrew/lib uv tool install ...`. The extension then loads the system `libasound.so.2` by soname. This needs no `sudo`, but it adds a Linuxbrew dependency to `install`;
- (b) exclude it with a uv override (`simpleaudio; sys_platform == "never"` in an overrides file passed to `uv tool install --overrides`). This is the smallest change and loses only the pydub fallback. It needs a one-line check that `serve` imports cleanly without it;
- (c) layer `alsa-lib-devel` with rpm-ostree. Not recommended: it adds a `sudo` and a reboot to ask B.

Whichever route is chosen, `install` should print the failing package on a build error, not only "stop here".

### B2 [blocking] Stage 1.4 has no operator model for a dispatched implementer

Stage 1.4 says "In a `clauthier` terminal, start a bypass overseer ... In another, run ... converser", then runs Test Plan items 4, 5, 6 and the audio-free part of 8.
Each of those needs two long-lived interactive `claude` sessions inside the container, and `ListAgents`/`SendMessage` need them live at the same time.
The implementer runs on the host without a TTY, the container has no `tmux` (only `script`), and the proposal does not say whether 1.4 is the implementer's work or the user's.
As written, an implementer either stalls or improvises the harness.

State one of:
- (a) the implementer drives panes from the host with `wezterm cli spawn -- podman exec -it -u node -w /workspace/clauthier/main clauthier <cmd>`, plus `wezterm cli send-text` and `get-text`. The user's WezTerm is already the documented control surface on this host;
- (b) 1.4 folds into ask D. The user opens the two terminals, and the implementer supplies an exact script of what to type and what to observe. This makes ask D longer, but it stays one sitting.

Also say which items a headless `claude -p` run with the launcher's flags can cover (for example, gate d's tool inventory), so that less depends on the interactive harness.

### Facts and Background

- [non-blocking] The Kokoro bullet says "the entrypoint is `./entrypoint.sh`": the image sets `Cmd`, and `Entrypoint` is null. With no `Exec=`, the behavior is as intended. Any future `Exec=` would replace the script, not append to it.
- [non-blocking] Upgrade gate u's "plausible that the published image was built with that default" to verified (image history). Upgrade the launcher preflight's "plausible that auth answers before MCP parsing" to verified/source (`TokenAuthMiddleware`).
- [non-blocking] Host Claude Code is 2.1.285, not 2.1.283. This is only a version stamp, and the sessions-registry claim is unaffected.

### Host package and units

- [non-blocking] `converser-kokoro.container` uses `Image=...:v0.9.0@sha256:...`. podman's libimage accepts a tag+digest reference (local lookup verified), but `podman manifest inspect` and `skopeo` reject it ("Docker references with both a tag and digest are currently not supported"). Use the digest-only form, as whisper does, and record the version in a comment. Script checks that reach for `skopeo` or `manifest inspect` would otherwise fail.
- [non-blocking] `instance add` has no re-run semantics, but the "Secret missing on the host" failure picture says to fix it by running `instance add clauthier` again. A naive re-run picks the first *free* port, which is 8766 because its own `serve@clauthier` holds 8765. It also mints a new token and trips on an existing secret name. Specify that an existing project reuses its env file's port and token and recreates only what is missing (`podman secret create` only if absent). Alternatively, make the failure picture say `podman secret create converser-clauthier ~/.config/converser-host/instances/clauthier.token`.
- [non-blocking] Install step order: step 3 downloads 1.6 GB before step 4 can exit on the boolean. Swap them, or run the GPU gate first, so a declined ask B fails fast.
- [non-blocking] whisper's default `HealthRetries` (3) at `HealthInterval=5s` can mark the container unhealthy while `large-v3-turbo` loads. `--sdnotify=healthy` should still wait for healthy, but setting `HealthStartPeriod=60s` removes the doubt.

### Container forward and token

- [non-blocking] Edge case "Secret deleted while a container references it" covers recreate only. `podman-run(1)`'s "modifying the secret ... affects the secret inside the container" suggests podman re-reads the store on start, so a plain `podman start` after a host reboot may also fail. This is plausible, not verified; add it to that edge case and to OQ1's test.
- [non-blocking] The skip-worktree approach is the only option available: lace `user.json` has `mounts`, `features`, `containerEnv`, and `git`, but no `runArgs`. Add a line saying so, so a reader does not look for a lace-native overlay. A per-project `runArgs` overlay is a natural item for the lace host-service-hooks Future Work.

### Test Plan and Implementation Phases

- [non-blocking] Test Plan item 4 (gate p) is a bare heading. Give the procedure: a `converse` call with `listen_duration_max=90`, `disable_silence_detection=true`, and `skip_tts=true`, first with the 600 s `timeout` and then from a second MCP config without it. State that this opens the host mic for 90 s. If that should not happen while the user is away, it belongs in ask D rather than 1.4.
- [non-blocking] Batching: say explicitly that asks A, B, and C are collected in one message once 1.0 is committed. C's consent can be given in advance even though it is exercised at 1.3. This matches the "batched" goal. D and E are inherently separate.
- [non-blocking] `lace up --rebuild` re-resolves the floating feature tags (`lace-fundamentals:1`, `claude-code:1`) when the image rebuilds. The recreated `clauthier` may carry a different `claude` version than the 2.1.274 verified here. Re-check `claude --version` after 1.3.

### Writing conventions

- [non-blocking] "No firewall rules. The r5 backstop guarded against ..." is revision history in the body. Move it into the top NOTE or rephrase it in present tense ("No VoiceMode installer runs, so nothing binds a wildcard").
- [non-blocking] The design map still depicts r5, and the NOTE says so. Regenerate it before the next acceptance, or drop the link from Links.

## Round-5 Action Items

r6 replaces the r5 host-brew design, so the r5 items are mostly moot.
Item 2 (`curl` header off argv) carries forward as `curl -K -` via builtin `printf` and is **resolved**.
Items 1, 3, and 4 (build wording, Kokoro `WorkingDirectory`/restart, `llama.cpp` pin, `handoff` fallback) no longer apply: there is no brew, no derived Kokoro script, and `handoff` is fallback-only.
The throwaway `serve` getting a temp `BASE_DIR` and an out-of-range port is **resolved** (port 8800).

## Verdict

**Revise.**
The architecture, the security posture, and nearly every factual claim are sound, and many are now verified against the live host.
Stage 1 is not followable to its end state by a dispatched implementer: install step 2 fails on `simpleaudio`, and 1.4 has no operator model.
Both are one-paragraph fixes, and a follow-up round should be a quick confirm.

## Action Items

1. [blocking] Install step 2: choose and specify a `simpleaudio` route (uv override excluding it, or a Linuxbrew `CFLAGS`/`LDFLAGS` build). Correct the "every dependency has wheels" fact. Keep ask B as the only host `sudo`.
2. [blocking] Stage 1.4: state who drives the two in-container sessions and how (`wezterm cli spawn`/`send-text`/`get-text` from the host, or fold into ask D with an exact script). Name the items a headless `claude -p` run can cover.
3. [non-blocking] Kokoro `Image=`: digest-only reference; fix "entrypoint" to `Cmd`.
4. [non-blocking] Upgrade the two "plausible" items to verified (Kokoro baked model; 401 before MCP parsing).
5. [non-blocking] Define `instance add` re-run semantics, or change the missing-secret failure picture to a direct `podman secret create`.
6. [non-blocking] Put the GPU gate before the model download; add `HealthStartPeriod` to whisper.
7. [non-blocking] Give Test Plan item 4 (gate p) a procedure and decide whether it runs in 1.4 or ask D.
8. [non-blocking] Batch asks A-C in one message after 1.0. Note the `claude` version re-check after 1.3. Extend the missing-secret edge case to `podman start`.
9. [non-blocking] Move the "r5 backstop" phrasing into the NOTE; regenerate the design map.

## Questions for the Author

1. `simpleaudio`:
   (a) uv override to exclude it, losing only the pydub playback fallback (recommended);
   (b) build against Linuxbrew ALSA headers;
   (c) layer `alsa-lib-devel` (adds `sudo` and a reboot).
2. Stage 1.4 operator:
   (a) implementer-driven WezTerm panes from the host (recommended, keeps ask D short);
   (b) user-driven, folded into the headset sitting with a script.
3. Gate p's 90 s listen opens the host mic:
   (a) run it only during ask D (recommended);
   (b) run it in 1.4 with the user's advance consent.
