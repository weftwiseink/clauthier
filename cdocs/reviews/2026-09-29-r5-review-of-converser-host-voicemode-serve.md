---
review_of: cdocs/proposals/2026-09-29-converser-host-voicemode-serve.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-29T10:07:46-07:00
task_list: voice/converser-lace-feature
type: review
state: live
status: done
tags: [fresh_agent, rereview_agent, confirm_round, host_install, packaging, token_handling, claims_verified]
---

# Review (round 5): converser on host `voicemode serve`

> BLUF(opus/voice/converser-lace-feature): Accept.
> Round 4's blocker N1 is fixed consistently: whisper now comes from `brew install whisper.cpp` plus `brew pin` and a direct model download, and no passage still presents building whisper as the primary path.
> Items N3-N9 are all addressed.
> Four leftover phrases still read as if there were a build step, and one host-side token-on-argv gap remains in the `status`/scoping `curl`.
> The Kokoro unit also needs `WorkingDirectory` and restart semantics carried over from upstream.
> None of this blocks: each is a one-line fix to make during implementation.

## Summary Assessment

The proposal specifies a host-side `converser-host` package (`plugins/converser/host/` in clauthier) that runs VoiceMode `serve` with safe defaults, plus a hand-wired in-container converser session.
This round replaces the direct whisper build with the homebrew-core bottle and applies round 4's non-blocking items.
The correction holds up and I checked it against `brew info`: the design no longer depends on a build.
The remaining findings are wording leftovers and small implementation details.
Verdict: **Accept**.

## Round-4 Action Item Status

| # | Round-4 item | Status |
|---|---|---|
| 1 (N1) | Whisper from the homebrew-core bottle; `brew pin`; model download; dependent passages | **Resolved.** Facts (l.101), "Why a script" (l.143-147), install step 3 (l.157), the unit's binary path (l.182), Option E (l.363), Design Decisions (l.407), the threat row (l.443), the 1.0 cost (l.541), and OQ4 (l.619) all agree. Nothing presents `cmake`, `WHISPER_BUILD_SERVER`, or VoiceMode's whisper installer as the path. See R1 for stale wording. |
| 2 (N3) | Compare `is-enabled` output | **Resolved** (l.164, and `status` uses the same pattern). |
| 3 (N4) | `openssl rand -hex 32`, unquoted env file, `handoff` reads `.token` | **Resolved** (l.165, l.171). |
| 4 (N5) | `--user` defaulting from `remoteUser`; `rm -f` before write | **Resolved** (l.170, l.174). |
| 5 (N6) | Host-side `curl`, token via env | **Resolved** (l.156). See R2 for how `curl` should carry the header. |
| 6 (N7) | Review before `sudo`; scope "nothing executes from the checkout" | **Resolved** (l.380-381, l.540). |
| 7 (N8) | Kokoro script: template or derived | **Resolved as derived** (l.185). See R3; one leftover "template" remains at l.362. |
| 8 (N9) | Links lists rounds 3-4 | **Resolved** (l.624). |

## Claim Verification (read-only)

| Claim | Result | Evidence |
|---|---|---|
| `whisper.cpp` 1.9.4 is bottled; runtime deps `ggml`, `llama.cpp`, `sdl2-compat` | **Correct** | `brew info whisper.cpp`: "stable 1.9.4 (bottled)", "Required (3): ggml, llama.cpp, sdl2-compat". |
| `ggml` enables Vulkan and OpenBLAS | **Consistent** | `brew info ggml`: deps `openblas`, `spirv-headers`, `vulkan-loader`. |
| Model files are not bundled | **Correct** | The formula caveat points at the Hugging Face `ggerganov/whisper.cpp` repo, which matches step 3. |
| `remoteUser` is readable from `devcontainer.metadata` | **Correct** | On all five running containers (weftwise, clauthier, whelm, jif, dioxus), the label's `remoteUser` equals the image user (`node`, `ubuntu`, `vscode`). |
| Upstream Kokoro unit semantics | **Not carried over** (R3) | VoiceMode's `templates/systemd/voicemode-kokoro.service` sets `WorkingDirectory={KOKORO_DIR}`, `Restart=always` (uvicorn exits 0 at `UVICORN_LIMIT_MAX_REQUESTS`, GH-448), and that env var. |

## Findings

### R1 [non-blocking]: leftover build wording from the pre-N1 design

- l.140: "treats the installers as fetch-and-build steps". Only the Kokoro installer runs now. Suggest "runs VoiceMode's Kokoro installer as a fetch step".
- l.362 (Option D): "one script template". l.185 now says the script is derived, not shipped. Suggest "one derived Kokoro start script".
- l.545 (1.1): "before any build" and "After the builds". Suggest "before the whisper and Kokoro installs" and "After the installs".
- l.100: the `gcc-16`/`cmake` host fact is still accurate but no longer bears on stage 1. Optionally tag it "(relevant only to a fallback or CUDA build)".

None of these changes the plan; they are misleading only on a skim.

### R2 [non-blocking]: `status` and the scoping check must not put the token on `curl`'s argv

l.156 and l.175 have the host `curl` send an authenticated `tools/list`.
The obvious `curl -H "Authorization: Bearer $tok"` puts the real instance token on the host's process list.
That contradicts the Stage 3 constraint "never puts the token on argv" (l.598) and the threat row at l.441.
Say how the header travels.
One option: `printf 'header = "Authorization: Bearer %s"\n' "$tok" | curl -K - ...`, where builtin `printf` feeds curl's config from stdin.
Another: `-H @<file>` from a `0600` temp file.
This matters most for `status`, which uses the real token; the scoping check uses a throwaway one.

### R3 [non-blocking]: `converser-kokoro.service` should carry upstream's run context

The derived script is the right call, and the `127.0.0.1`/no-`0.0.0.0` check fails closed.
Three details are unspecified:
- **`WorkingDirectory`.** Upstream Kokoro-FastAPI's `start-gpu.sh` derives `PROJECT_ROOT` from `$(pwd)` (plausible; the fork's script is not read). The copy in `~/.config/converser-host/` therefore needs `WorkingDirectory=<kokoro install dir>`, as VoiceMode's own unit sets.
- **Restart.** Upstream uses `Restart=always` because uvicorn exits 0 at `UVICORN_LIMIT_MAX_REQUESTS`, its memory-leak mitigation. If the package keeps that variable with `on-failure`, TTS dies silently after N requests. Use `always` for Kokoro, or drop the variable deliberately.
- **Host guard strength.** "Contains `127.0.0.1` and no `0.0.0.0`" would pass a script whose host comes from a variable (`--host "$HOST"`) that also names `127.0.0.1` elsewhere. Match the actual `--host` argument instead (for example, require exactly `--host 127.0.0.1` on the `uvicorn` line).

The script may also run `uv pip install` and a model download on every start (plausible, per upstream). If so, each boot fetches from the network; note it, or strip those lines in the derivation.

### R4 [non-blocking]: pin set and throwaway `serve` hygiene

- `brew pin whisper.cpp ggml` leaves `llama.cpp` unpinned. `llama.cpp` also depends on `ggml`, so a later `brew upgrade` can stall or warn on the pinned `ggml`. Pinning all three (`whisper.cpp ggml llama.cpp`) keeps upgrades clean. Recording the model file's sha256 would match the pinning philosophy.
- The step-2 throwaway `serve` should run with a temporary `VOICEMODE_BASE_DIR` and `WorkingDirectory`, on a port outside 8765-8799 (or be stopped before `instance add`). Otherwise it can leave state in `~/.voicemode` or hold the port `instance add` picks first.
- In `handoff`, a `node` fallback is wrong for non-`node` images that lack the label. Omitting `-u` (the image user) is the safer fallback. All current containers carry the label, so this is cosmetic.

### Independent pass: nothing else introduced

The pre-`sudo` review line, the `rm -f` in `handoff`, and the `is-enabled` comparison are all correct.
The architecture, security analysis, interaction model, placement, and test plan are unchanged from round 4 and remain accepted.

## Verdict

**Accept.**
N1 is resolved consistently across every dependent passage, and N3-N9 are addressed.
R1-R4 are small and can be applied during implementation of stage 1.0; none needs another review round.

## Action Items

1. [non-blocking] Fix the leftover build wording at l.140, l.362, and l.545 (and optionally l.100).
2. [non-blocking] Specify how the host `curl` in `status` and step 2 sends the bearer header without argv (`curl -K -` via builtin `printf`, or `-H @file`).
3. [non-blocking] `converser-kokoro.service`: `WorkingDirectory` set to the Kokoro install dir; `Restart=always` if `UVICORN_LIMIT_MAX_REQUESTS` is kept; match the literal `--host 127.0.0.1` in the derivation check.
4. [non-blocking] Pin `llama.cpp` too; give the throwaway `serve` a temp `BASE_DIR` and an out-of-range port; make `handoff` fall back to no `-u`.

## Questions for the Author

1. Kokoro restart policy:
   (a) `Restart=always` plus `UVICORN_LIMIT_MAX_REQUESTS`, matching upstream (recommended);
   (b) `on-failure` without the request limit, accepting the upstream memory leak.
2. Per-start network fetches in the Kokoro script, if present:
   (a) strip them in the derivation (recommended);
   (b) keep them, as upstream does.
