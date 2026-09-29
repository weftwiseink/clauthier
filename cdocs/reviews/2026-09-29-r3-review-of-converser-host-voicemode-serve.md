---
review_of: cdocs/proposals/2026-09-29-converser-host-voicemode-serve.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-29T09:57:07-07:00
task_list: voice/converser-lace-feature
type: review
state: live
status: done
tags: [fresh_agent, rereview_agent, security, packaging, host_install, claims_verified, runtime_validated, proportionality, token_handling]
---

# Review (round 3): converser on host `voicemode serve`

> BLUF(opus/voice/converser-lace-feature): Revise, with two small blockers.
> The rewrite matches the user's direction (host package, no lace, keyboard-trust audio, intent-verification confirmation) and resolves all seven round-2 items.
> The most important finding: step 5's `systemctl --user mask` fails with "File ... already exists", because VoiceMode's installers write regular unit files into the same `~/.config/systemd/user/` directory that `mask` targets.
> The fix is order-sensitive: delete, then mask. Deleting without masking is worse, because VoiceMode then falls back to killing by port and starting the `0.0.0.0` script directly.
> The token handoff (`podman exec`) is unspecified exactly where it could leak the token to argv, `ps`, shell history, and scrollback.

## Summary Assessment

The document replaces the lace-provisioned host side with a self-contained `converser-host` package (shell CLI, three `systemd --user` units, security-ordered install) plus a hand-wired container side, and rewrites the interaction model around relay-then-readback and intent verification.
It is well evidenced and internally consistent, and the homebrew-core, VoiceMode, and plugin-scope claims check out.
Two defects sit in the security-relevant install path: masking over an existing unit file fails (verified empirically with `systemctl --root`), and the binding card's token command is not specified.
Package scope is proportionate in shape but not staged: every subcommand is listed as stage-1 work.
Verdict: **Revise**. Both blockers are a few lines each, so a quick confirm round is enough.

## Round-2 Action Item Status

| # | Round-2 item | Status |
|---|---|---|
| N1 | Firewall first, `--no-auto-enable`, mask not disable, model changes via own unit | **Resolved in intent**; the mask step as written fails (F1) |
| N2 | Container probe checks the bind, not the firewall; off-host probe | **Resolved** (Test Plan item 2) |
| N3 | Drop `family=ipv4`; zone-only sentence | **Resolved** |
| N4 | Whisper `--threads`/`--convert`; commit to the Kokoro script copy | **Resolved** (`--convert` kept, `/usr/bin/ffmpeg` present) |
| N5 | Stage-1 listen trigger | **Resolved** (typed trigger in Listen gating and 1.4a) |
| N6 | Protect the uncommitted `runArgs` edit | **Resolved** (`--skip-worktree`) |
| N7 | Remove review-round provenance | **Resolved**; "round-4 proposal" now names the superseded document, not a review round |

## Claim Verification

| Claim | Result | Evidence |
|---|---|---|
| homebrew-core `whisper.cpp` 1.9.4 has an x86_64 Linux bottle and builds `-DWHISPER_BUILD_SERVER=OFF` | **Correct** | `brew info whisper.cpp`, `bottle.stable.files` has `x86_64_linux`; formula source has `-DWHISPER_BUILD_SERVER=OFF` and `-DWHISPER_USE_SYSTEM_GGML=ON` |
| `ggml` enables Vulkan and OpenBLAS on Linux | **Correct** | `ggml.rb`: `-DGGML_BLAS_VENDOR=OpenBLAS -DGGML_VULKAN=ON if OS.linux?` |
| "homebrew-core deliberately omits" `whisper-server` | **Plausible** | The flag is explicit; the formula gives no reason |
| Installers accept `--no-auto-enable` | **Correct** | `cli.py:810` (kokoro), `:981` and `:1144` (whisper) |
| With `--no-auto-enable`, nothing starts during install | **Correct** | `enable_service` (`service.py:733-742`) runs only when `auto_enable`; the unit file is still written (`whisper/install.py:217-224`, `kokoro/install.py:58`) |
| "A masked unit refuses every start path" | **Correct once masked; the mask step fails as written** | See F1 |
| A VoiceMode reinstall cannot undo a mask | **Correct** | Installers use `Path.write_text` on the unit path, which follows the `/dev/null` symlink; `enable_service` then fails on a masked unit |
| Token read from `VOICEMODE_SERVE_TOKEN` when `--token` absent; banner shows first four chars | **Correct** | `config.py:1663`, `cli.py:2132-2133`, `cli.py:2205` (`mask_secret`, 4 chars) |
| Token auth is independent of the local-IP allowlist | **Correct** | `TokenAuthMiddleware` is stacked separately (`serve_middleware.py:291`); `allow_local` does not bypass it |
| weftwise exec user and runtime dir support the launcher | **Correct** (live) | `podman inspect`: `User=node`, `NetworkMode=pasta`; `/run/user/1000` is `node:node 0700` (postStart); `flock`, `mktemp`, `jq` present; passwordless `sudo` works; `socat` absent |
| Plugin-scope and managed-settings claims | **Unchanged since round 1 verification; still consistent** | `~/.claude` is the shared bind mount (live); no `/etc/claude-code` in the container yet |

## Section-by-Section Findings

### Host: the `converser-host` package, install order

**F1 [blocking]: `systemctl --user mask voicemode-whisper voicemode-kokoro` fails after the installers run.**
Both installers write a regular file to `~/.config/systemd/user/voicemode-{whisper,kokoro}.service`, and `mask` for a user unit wants to place its `/dev/null` symlink at exactly that path.
Verified on this host (systemd 259) in a scratch root: `systemctl --root=$d mask x.service` over an existing regular file prints `Failed to mask unit: File '.../x.service' already exists` and exits 1, even with `--force`; masking a nonexistent unit (the `voicemode-serve` case) succeeds.
Under `set -e` the install aborts at step 5 (fail-safe, since nothing is running); without it, the upstream units stay unmasked and the design's key durability claim is false.

The fix has a trap.
Deleting the upstream unit file without masking is worse than leaving it: VoiceMode's `start_service`/`stop_service` check `Path(...).exists()` on that path (`service.py:431-433`, `:612-614`), and when it is absent they fall back to `find_process_by_port(port).terminate()`, which kills `converser-whisper`, and then `Popen` the upstream `0.0.0.0` start script directly (`service.py:450-470`, `:626-640`).
A mask symlink makes `exists()` true (it resolves to `/dev/null`), so both paths go through `systemctl`, where stop is a no-op and start is refused.
Step 5 should read: `rm -f ~/.config/systemd/user/voicemode-{whisper,kokoro}.service && systemctl --user daemon-reload && systemctl --user mask voicemode-whisper voicemode-kokoro voicemode-serve`, and step 7 should add `systemctl --user is-enabled voicemode-whisper` = `masked`.
The "Mask, not disable" decision and the Edge Cases entry should name the direct-process fallback as the reason delete-only is unsafe.

**F2 [non-blocking]: the firewall's role is overstated for the order given.**
With `--no-auto-enable`, no upstream unit starts during steps 3-5, so "load-bearing only during the install window" is not quite right.
The rejects are load-bearing only if a mask is missing or fails (F1), or if someone runs a VoiceMode installer without the flag later.
Say that; it is a better argument for keeping them.

**F3 [non-blocking]: `firewall-cmd --reload` on a host running Docker.**
Docker is active here (zone `docker`, `docker0`).
A reload flushes and rebuilds the ruleset; Docker re-adds its rules on the reload signal, but there is a gap.
Adding each rule twice, once with `--permanent` and once without, avoids the reload entirely.

**F4 [non-blocking]: consider bypassing `voicemode whisper install` altogether.**
The formula research points at a simpler whisper path: `cmake -DWHISPER_BUILD_SERVER=ON -DWHISPER_USE_SYSTEM_GGML=ON` against brew's Vulkan `ggml`, plus a direct model download.
That removes whisper's upstream unit, `0.0.0.0` start script, and model-install restart path from the host instead of neutralizing them.
Kokoro-FastAPI's setup is where VoiceMode's installer earns its keep.
Masking stays as defense against a later manual `voicemode whisper install`.
This is an option, not a requirement; the time box decides.

### Host: `converser-serve@.service`

**F5 [non-blocking, security]: an empty token silently disables auth.**
`has_token = bool(token)` (`cli.py:2152`); an env file with an empty or missing `VOICEMODE_SERVE_TOKEN` starts `serve` with no auth, and `allow_local` then admits every `pasta:-T` caller.
A missing file fails the unit, but a truncated one does not.
Add `ExecStartPre=/bin/sh -c 'test $${#VOICEMODE_SERVE_TOKEN} -ge 32'`.
The `$$` matters: systemd substitutes `${VAR}` in `Exec*=` lines itself, so the tempting `test -n "${VOICEMODE_SERVE_TOKEN}"` would put the token on the `sh` argv; `$$` passes a literal `$` through, so the shell reads the variable from the environment.
Also add "unauthenticated `tools/list` returns 401" to `converser-host status`; today only the one-off pre-check tests it.

### Token handoff

**F6 [blocking]: the binding card's `podman exec` line is unspecified, and the natural form leaks the token.**
The obvious one-liner, `podman exec weftwise sh -c 'echo <token> > ~/.config/converser/token'`, puts the token on host `podman` argv and container `sh -c` argv (`ps` on both sides), in host shell history, and in terminal scrollback when the card prints it.
That contradicts the stage-3 constraint "never puts the token on argv".
Specify stdin transport and never print the token:

```sh
sed -n 's/^VOICEMODE_SERVE_TOKEN=//p' ~/.config/converser-host/instances/weftwise.env \
  | podman exec -i -u node weftwise sh -c \
      'umask 077; mkdir -p ~/.config/converser && cat > ~/.config/converser/token'
```

It is better for the CLI to run this itself, for example `converser-host instance handoff <project> <container>`, than to print a command to paste.
That also gives a re-run path after every container recreate, which wipes `~/.config/converser/` (gate s currently names only the managed file and launcher; add the token and port files).
Pass `-u` explicitly: weftwise's image user is `node` today, but `podman exec` follows the image, not `remoteUser`.
The launcher's `printf ... "$(cat token)"` is safe because `printf` is a builtin in dash and bash; one comment in the launcher saying so would keep a later edit from swapping in `/usr/bin/printf` or `jq --arg`, both of which put the token on argv.

### Package proportionality and staging

The shape is proportionate: one shell CLI, three units, one script template, no lace or clauthier changes in stages 1-2, and a kill tripwire that archives one repo.
Option B's rejection is sound: an ordering-sensitive install is safer scripted once.

**F7 [non-blocking]: stage v0 of the CLI.**
The Commands list reads as all stage-1 work: `install`, `instance add/rm`, `status`, `uninstall`, `model set`.
Stage 1 needs `install`, `instance add`, `instance handoff` (F6), and a thin `status` that runs the gate-q checks.
Move `instance rm`, `uninstall`, and `model set` to 3b explicitly; this keeps 1.0 inside its time box and away from weftwise dev time.

**F8 [non-blocking]: run the cheap stop-condition before the expensive builds.**
Step 1.1 stops "if token or tool scoping fails", but it runs after the whisper build and the multi-GB Kokoro download.
Token enforcement and `tools/list == [converse]` need only `uv tool install voice-mode==8.12.0` and one hand-run `serve`, since `tools/list` does not touch STT/TTS.
Split 1.1: scoping right after step 2 of `install`; the `converse()` and two-instance conch checks after the builds.

### Where the package source lives

The recommendation (new private repo) is sound on scope and on archive-ability after a stage-2 kill.

**F9 [non-blocking]: the clauthier "Against" leans on a weak argument and misses the real one.**
"Host tooling would sit inside every container's view" is not a harm: the script holds no secrets, and the mount is read-only.
The real cost of any split is the cross-repo contract between `converser-host` (which writes the container's token and port files) and the clauthier launcher (which reads `~/.config/converser/{token,port}`).
State that contract once, in `converser-host`, and point the plugin at it.
The `brew tap weftwiseink/converser-host <url>` claim is right to be marked plausible: an explicit URL lifts the `homebrew-` prefix requirement.

### Placement, plugin scope, managed settings

These claims survived the restructure intact.
User scope is the shared `~/.claude` bind mount (confirmed live), and project scope leaks to the host and collaborators, so the container-local managed file is the only right scope.
`extraKnownMarketplaces` in the managed file removes the dependency on user registration, with gate (t) still honestly open.
`sudo` for `converser setup` works in weftwise (confirmed live).
**F10 [non-blocking]:** the "read-only mount of the instance's token file through lace's existing user-level mount config" option mounts a `KEY=value` env file, not a raw token.
Either have `instance add` also write a raw `token` file for mounting, or have the launcher parse the env file.
Mark lace's user-level file-mount support as plausible, since weftwise's own comment records lace rejecting a socket mount.

### Leftover lace coupling

No content contradicts the new direction.
The remaining lace references are legitimate: weftwise is lace-managed (`lace up` to recreate, gate c on lace ingress under `--network`), rejected Options A and C, and Future Work.
**F11 [non-blocking]:** the Stage-1 tripwire falls back to the round-4 in-container stack, which is a lace devcontainer feature.
Add one clause saying the fallback would also be hand-wired first, consistent with "lace out near-term".

### Interaction model and residual risk

This matches the user's direction point for point:
- relay without asking, then read back;
- no raw-transcript echo;
- comprehension, sensibility, and unsignalled-destructive checks, with the explicit-intent examples;
- correction by follow-on utterance;
- `<session> #N` labels with inferred labels for unnamed sessions;
- human prose both ways;
- the keyboard-trust model accepted explicitly, with fingerprinting and provenance in Future Work.

"Intent verification is not a control" is stated plainly, which keeps the security story honest.
No findings.

### Test Plan

**F12 [non-blocking]:** item 6 pins the raw-post wire format "by a `socat` test", but `socat` is not in the weftwise image.
Name the substitute (`python3 -c` with `socket`, or a `sudo apt-get install socat` in step 1.4).

## Verdict

**Revise.**
The design is right and proportionate in shape, and every round-2 item is addressed.
F1 makes the headline "mask, not disable" guarantee fail on first run, and its obvious workaround (delete the files) opens a worse path.
F6 leaves the one token path that crosses a process boundary unspecified.
Both fixes are a few lines; a confirm-only round 4 suffices.

## Action Items

1. [blocking] Step 5: `rm -f` the two upstream unit files, `daemon-reload`, then `mask` all three; step 7 verifies `is-enabled` = `masked`. Say why delete-only is unsafe (VoiceMode's kill-by-port and direct-`Popen` fallback, `service.py:450-470,626-640`).
2. [blocking] Specify the token handoff as stdin transport with explicit `-u`, `umask 077`, and no token in printed output; prefer a `converser-host instance handoff` subcommand; include token and port files in gate (s).
3. [non-blocking] Add an `ExecStartPre` token-length check to `converser-serve@.service`, and a 401-without-token check to `status`.
4. [non-blocking] Mark CLI v0 (install, instance add, handoff, thin status) versus 3b (rm, uninstall, model set).
5. [non-blocking] Split step 1.1 so token/tool scoping runs before the whisper build and Kokoro download.
6. [non-blocking] Reword the firewall's role (backstop for a missing mask or a later unflagged install); add rules as runtime plus permanent instead of `--reload`.
7. [non-blocking] Consider building `whisper-server` directly against brew's `ggml` instead of `voicemode whisper install`.
8. [non-blocking] Repo placement: replace the "inside every container's view" argument with the cross-repo file contract; document that contract in `converser-host`.
9. [non-blocking] Token-file mount option: raw token file or launcher parsing; mark lace file-mount support plausible.
10. [non-blocking] Tripwire fallback: say it would also be hand-wired first.
11. [non-blocking] Name the `socat` substitute in Test Plan item 6; add a builtin-`printf` comment to the launcher.

## Questions for the Author

1. How should the token reach the container?
   (a) `converser-host instance handoff <project> <container>` runs the stdin pipe itself (recommended);
   (b) the card prints a stdin-pipe command that reads the env file, never the token;
   (c) a read-only mount of a raw token file (survives rebuilds; needs lace user-level mount support).
2. How should whisper be built?
   (a) `voicemode whisper install --no-auto-enable`, then delete and mask (current design with F1 fixed);
   (b) the package builds `whisper-server` against brew's `ggml` and skips VoiceMode's whisper installer (fewer upstream artifacts; recommended if the time box allows).
3. Which commands are in CLI v0?
   (a) install, instance add, handoff, thin status (recommended);
   (b) everything in the Commands list.
