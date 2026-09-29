---
review_of: cdocs/proposals/2026-09-29-converser-host-voicemode-serve.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-29T10:03:58-07:00
task_list: voice/converser-lace-feature
type: review
state: live
status: done
tags: [fresh_agent, rereview_agent, security, packaging, host_install, claims_verified, runtime_validated, token_handling, placement]
---

# Review (round 4): converser on host `voicemode serve`

> BLUF(opus/voice/converser-lace-feature): Revise, with one small blocker that is new this round.
> Both round-3 blockers are resolved: remove-reload-mask works, and `instance handoff` keeps the token on stdin.
> All nine round-3 non-blocking items are also addressed, and the `$$` token check behaves as claimed.
> The new blocker: homebrew-core's `whisper.cpp` 1.9.4 bottle already ships `whisper-server`. `WHISPER_BUILD_SERVER` is a dead option in that tag, so the proposal's direct-build step (step 3), its stage-1 cost estimate, and its "homebrew-core deliberately omits" premise are all wrong.
> The fix is `brew install whisper.cpp`. It makes stage 1 cheaper, and only a quick confirm round is needed.

## Summary Assessment

This round confirms the round-3 fixes, moves `converser-host` into `plugins/converser/host/` in clauthier, and switches to building `whisper-server` directly against brew's `ggml`.
The round-3 blockers are fixed correctly, and I verified the fixes empirically.
The clauthier placement holds up: nothing in `host/` is auto-loaded or put on PATH, no tooling scans `plugins/`, and no references to a separate repo remain.
One factual premise is false, and a round-3 claim check approved it: the whisper.cpp formula's `-DWHISPER_BUILD_SERVER=OFF` has no effect in v1.9.4, and the x86_64 Linux bottle contains `bin/whisper-server`.
Verdict: **Revise** for that one correction (a handful of lines); everything else is ready.

## Round-3 Action Item Status

| # | Round-3 item | Status |
|---|---|---|
| 1 (F1) | Remove, `daemon-reload`, then mask; verify `masked`; explain why delete-only is unsafe | **Resolved.** Step 5, step 7, Design Decisions, and Edge Cases all match. Verified below. |
| 2 (F6) | Stdin handoff, explicit `-u`, `umask 077`, token never printed; `instance handoff`; token and port files in gate (s) | **Resolved.** Nothing puts the token on host or container argv (checked below). Gate (s) names the token and port files. |
| 3 (F5) | `ExecStartPre` length check; 401 check in `status` | **Resolved.** The `$$` semantics were verified in transient units. |
| 4 (F7) | CLI v0 vs 3b | **Resolved** (Commands paragraph, 3b). |
| 5 (F8) | Split 1.1 so scoping runs before the builds | **Resolved** (install step 2, 1.1). |
| 6 (F2, F3) | Reword the firewall's role; runtime plus permanent, no reload | **Resolved** (step 1). |
| 7 (F4) | Consider a direct `whisper-server` build | **Adopted, but the premise is wrong** (N1). |
| 8 (F9) | Cross-repo contract instead of the "container view" argument | **Resolved, and moot now.** The contract is documented once, in `host/README.md`, and both of its sides now live in one plugin. |
| 9 (F10) | Raw token file; lace file-mount marked plausible | **Resolved** (`instance add` writes `<project>.token`; the Placement row says plausible). |
| 10 (F11) | Tripwire fallback is hand-wired too | **Resolved.** |
| 11 (F12) | `socat` substitute; builtin-`printf` comment | **Resolved** (`python3` socket; the launcher has the comment). |

## Claim Verification

| Claim | Result | Evidence |
|---|---|---|
| `mask` over an existing regular unit file fails; delete, then mask, succeeds | **Correct** | Scratch `--root` on this host (systemd 259.5): mask over the file gives "already exists", rc 1. After `rm`, the mask creates the `/dev/null` symlinks, rc 0. |
| Step 7: `is-enabled` "reports `masked`" | **Correct output, non-zero exit** | `is-enabled` prints `masked` with **rc 1** (N3). |
| `ExecStartPre=/bin/sh -c 'test $${#VOICEMODE_SERVE_TOKEN} -ge 32'` passes a literal `$` and reads the variable from the environment | **Correct** | `systemd-run --user --wait --pipe -p Environment=...`: a 9-char token gives rc 1, a 36-char token gives rc 0, and an unset variable gives rc 1. `$0` is `/bin/sh`, so the value never reached argv. |
| Handoff keeps the token off argv | **Correct** | Host argv is `sed <path>` and `podman exec ... sh -c '<script without token>'`; the token travels on stdin only. `umask 077` before `mkdir`/`cat` gives a `0700` dir and a `0600` file. |
| Runtime plus `--permanent` avoids `--reload` | **Correct** | `--permanent` edits only the stored config; the runtime add takes effect immediately. Rich-rule rejects land in the zone's deny chain, ahead of the zone's `1025-65535/tcp` port allow. The exact rich-rule string was not parsed here, because that needs `sudo`. |
| homebrew-core `whisper.cpp` "builds `-DWHISPER_BUILD_SERVER=OFF`, so it ships no `whisper-server`" | **Incorrect** | In v1.9.4, `WHISPER_BUILD_SERVER` is declared at `CMakeLists.txt:105` and referenced nowhere else. `examples/CMakeLists.txt` runs `add_subdirectory(server)` unconditionally when examples are on, and the formula sets `-DWHISPER_BUILD_EXAMPLES=ON`. The x86_64_linux bottle (`sha256:2a3304c8…`, downloaded to `/tmp` and listed, not installed) contains `whisper.cpp/1.9.4/bin/whisper-server`. |
| Direct build against brew `ggml` is plausible | **Plausible, and unnecessary** | `find_package(ggml)` under `WHISPER_USE_SYSTEM_GGML`; `WHISPER_SDL2` defaults off, so llama.cpp is not needed. brew `ggml` 0.25.3 uses `GGML_BACKEND_DL=ON` with backends in `libexec`, and `whisper-server` calls `ggml_backend_load_all()` (`server.cpp:642`), so Vulkan loads at runtime either way. |
| `whisper-server` flags `--host`, `--inference-path`, `--threads`, `--convert` exist | **Correct** | `examples/server/server.cpp:210-256` |
| VoiceMode auto-starts only Kokoro | **Correct** | The only `AUTO_START` path is `shared.py:44`. |

## Section-by-Section Findings

### Host: `whisper-server` source (Facts, "Why a script", install step 3, Option E, 1.0, OQ4)

**N1 [blocking]: the whisper premise is false, and the proposal's most expensive stage-1 step does not need to exist.**
The Facts bullet ("builds with `-DWHISPER_BUILD_SERVER=OFF`, so it ships no `whisper-server`"), "Why a script" ("which homebrew-core deliberately omits"), install step 3, the Option E row, and the 1.0 cost note ("dominated by the whisper.cpp build") all rest on it.
The bottle ships `whisper-server`, linked against brew's Vulkan- and OpenBLAS-enabled `ggml` with dynamic backend loading, and the formula has no `service do` block, so nothing auto-starts.
Round 3's claim table marked this "Correct" after checking the flag, not the bottle's contents.

Replace step 3 with `brew install whisper.cpp` (this pulls in `llama.cpp` and `sdl2-compat` as runtime deps: extra download, no build) plus the direct model download.
`converser-whisper.service` then runs `$(brew --prefix)/bin/whisper-server` (or the versioned `opt/whisper.cpp/bin` path) with the flags already listed.
Follow-on edits:
- Drop "homebrew-core deliberately omits" and "a Homebrew formula for it is not planned". Option E becomes "not needed: homebrew-core already ships it".
- Stage 1.0 cost becomes the Kokoro download, so the whisper overrun branch in 1.0 largely goes away.
- The gcc-16 toolchain note becomes irrelevant to stage 1.
- Open Question 4 narrows to "does the bottle's Vulkan backend work on the RTX 3080, or does ggml fall back to CPU", which `whisper-server` reports at startup.
- Note that `brew upgrade` can move `whisper.cpp`/`ggml` under the running unit. The bottles are built together, so this is ABI-safe, but `brew pin whisper.cpp ggml` would match the `voice-mode==8.12.0` pin philosophy.
The direct cmake build can stay as a one-line fallback if the bottle misbehaves. If it does, build tag `v1.9.4` exactly (the version brew's `ggml` is paired with), outside the checkout, with a prefix such as `~/.local/share/converser-host/`.

### Host: install steps 5 and 7

**N2 [non-blocking]: remove-reload-mask is correct and now defensive.**
With whisper from brew, `voicemode-whisper.service` usually does not exist, so `rm -f` is a no-op and the mask still lands. That is exactly what is wanted against a later manual `voicemode whisper install`.

**N3 [non-blocking]: `is-enabled` exits 1 for a masked unit.**
Verified above.
A `set -eu` script that runs step 7 as a bare command aborts on success.
Compare output instead, for example `[ "$(systemctl --user is-enabled "$u" || :)" = masked ]`, and use the same pattern in `status`.

### Host: `converser-serve@.service`

The `ExecStartPre` check is correct as written and was verified in transient units.

**N4 [non-blocking]: pin the token encoding and the env file's quoting.**
"Mints a 32-byte token" should name the encoding, for example `openssl rand -hex 32` (64 chars). The `-ge 32` check then has clear margin, and the token is shell- and header-safe.
Write `KEY=value` unquoted: systemd strips quotes, but the handoff's `sed` would not.
Simpler still, have `handoff` read the raw `<project>.token` file that `instance add` already writes, instead of parsing the env file.

### Host: `instance handoff`

**N5 [non-blocking]: `-u node` is weftwise-specific inside a generic subcommand.**
Take `--user`, defaulting to the `remoteUser` from the container's `devcontainer.metadata` label or to `node`.
Also run `rm -f` on the target before `cat >`. `umask` does not re-mode an existing file, which only matters if something recreated it more loosely.

### Host: install step 2 (scoping stop-check)

**N6 [non-blocking]: say how the embedded check runs.**
Inside `install`, run the check against `127.0.0.1` from the host with `curl`, since `tools/list` and 401 need no container, and pass the throwaway token via `VOICEMODE_SERVE_TOKEN`, not `--token`.
Test Plan item 1 keeps the `podman run --network pasta:-T` variant for the forward.

### Where the package source lives (clauthier `plugins/converser/host/`)

The placement is coherent. I checked:
- **Auto-loading and PATH:** Claude Code loads plugin components only from conventional locations (`commands/`, `agents/`, `skills/`, `hooks/`, `.mcp.json`, `bin/`, `settings.json`). `bin/` is the only PATH entry, and only for the Bash tool in sessions where the plugin is enabled. `host/` is none of these.
- **Stages 1-2:** `converser` is absent from `.claude-plugin/marketplace.json` (it lists only `cdocs`), so the plugin cannot be installed and nothing loads.
- **Stage 3a:** the plugin cache will carry a copy of `host/`. That is harmless, and the proposal already says to run from the checkout.
- **Repo tooling:** `scripts/build-opencode.ts` takes a plugin name (`cdocs`), and `opencode-build.yml` triggers on `plugins/cdocs/**` only, so no build or CI step walks `plugins/` and trips on a directory without `plugin.json`.
- **Leftover references:** none. The only "New repo" mention is the rejected row in the source-home table. The kill tripwire deletes `plugins/converser/`, and the archive-a-repo language is gone.

**N7 [non-blocking]: the checkout is writable by host bypass agents, and `install` runs `sudo`.**
Host sessions commit to clauthier `main` often, so the script that escalates is whatever `HEAD` is when the user runs it.
Add one line: review `git log -p plugins/converser/host/` since the last run before `install`, or run it from a pinned tag.
Also tighten "nothing on the host executes from the checkout after install". It is true for units, but `instance add`, `handoff`, and `status` run from the checkout by design.

**N8 [non-blocking]: say where the Kokoro start script comes from.**
Line 139 says the package ships "one Kokoro start-script template", while the Units section says the package copies Kokoro-FastAPI's script and changes the host at install time ("read at install time").
Say which: a shipped template pinned to the installed Kokoro-FastAPI layout, or a copy derived at install time with a check that the host substitution took.

### Links

**N9 [non-blocking]:** "Reviews of this proposal" lists rounds 1-2 only; add rounds 3 and 4.

### Interaction model, security analysis, placement table, test plan

These are unchanged from round 3 apart from the handoff and empty-token rows, which are accurate.
They still match the user's direction (relay-then-readback, intent verification, `<session> #N` labels, keyboard-trust audio, lace out, cheap incremental stage 1).
N1 makes stage 1 cheaper, which is in the direction the user asked for.

## Verdict

**Revise.**
F1 and F6 are resolved correctly and verified, and all round-3 non-blocking items are addressed.
The one blocker is a factual correction: `whisper-server` comes from the homebrew-core bottle, so step 3 becomes `brew install whisper.cpp`, and the surrounding premise and cost text change with it.
A confirm-only round 5 suffices.

## Action Items

1. [blocking] Correct the whisper premise. homebrew-core's `whisper.cpp` 1.9.4 bottle ships `whisper-server` (`WHISPER_BUILD_SERVER` is dead in that tag). Step 3 becomes `brew install whisper.cpp` plus a model download. Update Facts, "Why a script", Option E, Design Decisions, 1.0 cost, and OQ4. Keep the direct build (tag `v1.9.4`, prefix outside the checkout) as a fallback only. Consider `brew pin whisper.cpp ggml`.
2. [non-blocking] Step 7 and `status`: compare `is-enabled` output, not its exit code (rc 1 for `masked`).
3. [non-blocking] Name the token encoding (`openssl rand -hex 32`), write the env file unquoted, and have `handoff` read `<project>.token` rather than `sed` the env file.
4. [non-blocking] `handoff`: `--user` with a `remoteUser`/`node` default; `rm -f` the target before writing.
5. [non-blocking] Install step 2: host-side `curl` against `127.0.0.1`, with the token via env.
6. [non-blocking] Add a review-before-`sudo` line for the writable checkout; scope "nothing executes from the checkout" to units.
7. [non-blocking] Say whether the Kokoro start script is a shipped template or derived at install time.
8. [non-blocking] Add rounds 3 and 4 to Links.

## Questions for the Author

1. Where does `whisper-server` come from?
   (a) `brew install whisper.cpp`, with `brew pin` (recommended: no build, Vulkan via ggml's DL backends);
   (b) `brew install whisper.cpp`, unpinned, accepting upgrades under the unit;
   (c) keep the direct cmake build against brew `ggml` (only if the bottle misbehaves).
2. How is the host script's provenance protected before `sudo`?
   (a) a one-line "review `git log -p host/` first" step (recommended for stage 1);
   (b) run from a pinned tag;
   (c) accept `HEAD` as-is.
