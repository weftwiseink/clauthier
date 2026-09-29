---
review_of: cdocs/devlogs/2026-09-29-converser-stage1-implementation.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-29T16:37:22-07:00
task_list: voice/converser-lace-feature
type: review
state: live
status: done
tags: [fresh_agent, security, install_safety, static_floor, runtime_validated, token_handling]
---

# Review: converser stage 1.0 implementation

> BLUF: **Accept.** The 1.0 files (commits `fe84afe..7e0e080`, `plugins/converser/**`) faithfully implement [the proposal](../proposals/2026-09-29-converser-host-voicemode-serve.md) stage 1.0.
> Every deviation from the proposal is small, recorded in the devlog, and in most cases an improvement.
> The static floor re-runs clean.
> Scratch runs confirm that the self-install guard, the GPU gate, token-free argv, and `instance add` repair work.
> Nothing blocks the 1.0 work itself.
> Two **procedural conditions apply before 1.1** (`converser-host install` on the host): the installed tree must be the reviewed tree (`310caaa`), and the repo's git config must be free of exec-capable keys.
> Neither needs a code change.
> One real `instance add` bug (a silent token mismatch after a partial manual cleanup) and a few hardening items are non-blocking.

## Summary Assessment

The work authors the host package (`converser-host`, two Quadlet files, `serve@` template, test client, README), the in-container launcher, the system prompt, and the two hooks for stage 1.0, with no host changes.
Quality is high: the shell is POSIX-clean under shellcheck for `sh` and `dash`, the token never reaches an argv on any path I traced, the units match the proposal verbatim, and the devlog's claims matched my own re-runs.
The most important findings concern the review-to-install boundary, not the code.
`install` archives whatever `HEAD` is at run time, and it runs host `git` against a repo whose config is container-writable.
Both are covered by procedural checks at 1.1.
Verdict: **Accept**, with action items 1-2 required before 1.1.

## Reviewed state

- Commits `fe84afe..7e0e080`. `HEAD` is now `1e376bf`, which touches only a devlog.
- The tree `plugins/converser/host` is `310caaaaea65f3957ca0764545ca7c7400ec919a` at both `7e0e080` and `HEAD`. This is the tree this review accepts for install.
- The tree `plugins/converser` is `e72ce7a670663ec26f924023e9580ef2d75f4769` at `7e0e080`.
- The user's ask A answer ("install after the 1.0 reviewer accepts", `1e376bf`) makes this review the pre-install review, so the tree hash above is load-bearing.

## Static floor (re-run by this reviewer)

```
sh -n host/converser-host bin/converser launcher/record-sockpath.sh      -> exit 0
shellcheck 0.11.0 (default and -s dash) host/converser-host bin/converser launcher/*.sh -> exit 0, no findings
QUADLET_UNIT_DIRS=$PWD/plugins/converser/host podman-user-generator --dryrun -> exit 0
  converser-whisper: ExecStart=/usr/bin/podman run ... --security-opt=no-new-privileges --device nvidia.com/gpu=all
    --cap-drop all -v %h/.local/share/converser-host/models:/models:ro,Z --publish 127.0.0.1:2022:2022 ...
    ghcr.io/ggml-org/whisper.cpp@sha256:8a9def3e... "whisper-server\x20--host\x200.0.0.0\x20--port\x202022..."
  converser-kokoro:  ... --device nvidia.com/gpu=all --cap-drop all --publish 127.0.0.1:8880:8880
    --env DOWNLOAD_MODEL=false ... ghcr.io/remsky/kokoro-fastapi-gpu@sha256:9ba15046...
systemd-analyze --user verify host/converser-serve@.service               -> exit 0, no output
python3 -m py_compile hooks/*.py host/mcp-converse.py                     -> exit 0
```

The `--cpu` render (`render_units cpu`, dry-run through the generator) drops `--device`, uses the CPU digests `070afe96...` and `ee3111d6...`, and loads `ggml-base.en.bin`.
Both paths publish only on `127.0.0.1`.

> WARN(opus/voice/converser-lace-feature): `py_compile` wrote untracked `host/__pycache__/` and `hooks/__pycache__/` into the checkout, because `__pycache__` is not gitignored.
> A dirty `host/` makes `install` refuse (fail-safe), so the devlog's own floor command would block 1.1 if its output were left behind.
> I removed both directories. See action item 6.

## Scratch runs (scratch `HOME`, cleaned up)

- **Install from the checkout, GPU boolean off** (the host state today): the tree was self-installed into the scratch `~/.local/share/converser-host/src/`, `installed-rev` recorded `1e376bf`, and the bin link was created. The installed copy then printed the `sudo setsebool -P container_use_xserver_devices on` line and exited 1 before any `uv`, download, or unit step. This confirms step 2 fails fast.
- **Installed copy runs `install`:** refused ("this is the installed copy").
- **`--from-installed` from the checkout:** refused.
- **`instance add demo`** with `podman`/`systemctl` stubs: `0600` env and token files, `0700` dirs, correct `runArgs`, and a repair re-run that reuses the port and token and skips the existing secret. The token appears 0 times in the stub argv log. The names `../x`, `-x`, and `a b` are refused.
- **Token-mismatch bug (reproduced).** Deleting `demo.env` while `demo.token` and the podman secret remain, then running `instance add demo`, prints success. Afterwards the env token differs from both the token file and the secret. `serve` would then accept a token that the container does not hold. See finding H3.
- **Git `core.fsmonitor` (reproduced in a scratch repo).** `git status --porcelain` executed the configured program. `git -c core.fsmonitor=false status` did not. See finding H1.

No host state was touched. `~/.voicemode`, `~/.local/share/converser-host`, `~/.config/converser-host`, and `~/.local/bin/converser-host` are all absent after the run.

## Section-by-Section Findings

### Host CLI `converser-host`: self-install and review boundary

**H1. Host `git` runs against a container-writable repo config (non-blocking; procedural check before 1.1).**
`self_install` runs `git status`, `git rev-parse`, and `git archive` in the checkout.
The bare repo `.bare/config` sits inside the tree that the `clauthier` container mounts read-write.
A session in the container could therefore set `core.fsmonitor`, or a `filter.*` driver plus `info/attributes`, and the host user would run that command at `install` time, before any reviewed code runs.
I confirmed `core.fsmonitor` execution in a scratch repo.
This is the same class that the proposal's threat table already accepts ("the shared read-write `~/.claude` ... already is one"), and the user runs host `git` in this checkout routinely, so the vector is not new.
Still, the README's claim that "the host never runs it in place" is stronger than what the code enforces.
Cheap partial hardening: run `git -c core.fsmonitor=false -c core.hooksPath=/dev/null`.
Procedural check for 1.1: `git config --list --show-origin` shows no `core.fsmonitor`, `filter.*` other than the host's `lfs`, or `core.hooksPath` from `.bare/config` or `config.worktree`.
Today it shows only the `/etc/gitconfig` and `~/.gitconfig` `filter.lfs` entries.

**H2. Nothing binds the install to the reviewed commit (non-blocking in code; required procedurally before 1.1).**
`install` archives whatever `HEAD` is when it runs.
The dirty-tree check catches uncommitted edits but not a new commit.
A bypass session in `clauthier` that commits to `plugins/converser/host/` between this review and 1.1 would be installed unreviewed.
The proposal has the same gap: its "review `git log -p installed-rev..HEAD`" is advisory.
The printed "review before installing" line appears after the copy is already made, so it cannot gate anything.
A second effect: a failed install (for example at the GPU gate) still records `installed-rev`, so the next run's review range is empty even though nothing was installed.
Suggested code fix for a later round or stage 3b: `install --expect-tree <sha>`, refusing unless `git rev-parse HEAD:plugins/converser/host` equals it.
For 1.1, the implementer checks that hash equals `310caaaaea65f3957ca0764545ca7c7400ec919a` immediately before running `install`.

**Self-install mechanics (no finding).**
`git archive "$rev" | tar --strip-components=3` keeps the `0755` mode.
The `.new` staging directory replaces `src/` in one `mv`.
The re-exec with `--from-installed` is refused unless `$0` resolves to the installed copy.
This is stronger than the proposal: every step after the copy runs committed code.

### Host CLI: install steps 2-6

- **GPU gate:** correct, and it runs before any download (scratch-verified).
- **`install_voicemode`:** it checks the `uv` bin dir against `~/.local/bin`, which the `serve@` `ExecStart` hardcodes; unsetting `FORCE_COLOR` fixes this host's ANSI-wrapped paths. `--excludes`, `--exclude-newer`, and `installed-deps` match the proposal.
  **H4 (non-blocking):** `voicemode --version` runs with the real `HOME` and creates `~/.voicemode/voicemode.env`. The devlog WARN records this. I checked VoiceMode's default template (`config.py` around lines 164 and 345): its only uncommented keys are `VOICEMODE_VOICES=af_sky` and `VOICEMODE_PRONOUNCE`, so it has no security effect. `serve@` would create the directory anyway for the conch. Running `--version` with `HOME="$tmp"` would match the proposal's intent more closely, but this is cosmetic.
- **`scoping_stopcheck`:** the throwaway token is exported only in the subshell that execs `serve`, and it goes to `curl` through `printf | curl -K -`. The `trap` cleans up on `die`.
  **H5 (non-blocking):** the `INT`/`TERM` trap handlers do not `exit`. In `sh` a non-exiting `INT` trap resumes the script (verified: `trap "echo trapped" INT; kill -INT $$; echo continued` prints both lines). Here the resumed script still fails at the next check and exits, so the effect is harmless. Append `; exit 130` for clarity.
- **`fetch_model`:** it verifies sha256 before `mv`, and a bad download is deleted. Correct.
- **`write_units`:** the order is write, `daemon-reload`, pull by digest, start, then mask, as in the proposal. Changed units restart and unchanged ones are no-ops. The check that refuses to mask over a regular file is a good addition. `render_units` asserts that the source `Image=` lines equal the script's pins, so the constants and files cannot drift.
  **H6 (nit):** `install_file` runs `cp ... && mv ...; echo 1`. A failed `cp` inside that `&&` list does not trip `set -e`, so the function reports "changed" and continues. Use `cp ... || return 1`, or a plain `cp` then `mv`.
- **Failure mid-install:** each step is idempotent, and a re-run resumes cleanly. After a failed `host_checks`, the Quadlet units stay installed with `WantedBy=default.target`, so they come back at next login. That is acceptable, but README Recovery could say so.
- **`host_checks`/`status`:** they compare `is-enabled` output rather than exit codes, check `HostIp` with `jq`, and check the pins in `/proc/<MainPID>/environ` and the absence of `--token` on argv, all as the proposal specifies. The globals `hrc` and `irc` are separated, which fixes the devlog's noted `rc` clobbering.

### Host CLI: `instance add`

**H3. A fresh add can leave `serve` and the container holding different tokens (non-blocking; small fix).**
The token file is written only `if [ ! -f "$tokf" ]`, and the secret is created only if `podman secret exists` fails.
On the fresh-add path (no env file), a leftover `.token` or secret from an earlier instance is silently kept, while `serve` gets a new token from the env file.
Reproduced above.
Stage 1 has no `instance rm`, so reaching this takes a manual partial cleanup.
`status` would catch it: its authenticated `tools/list` uses the `.token` file.
Fix: on the fresh path, always write the `.token` file, and create the secret with `podman secret create --replace` (or refuse when the secret already exists).
On the repair path, rewrite the `.token` file from the env file rather than trusting a present one.

Everything else matches the proposal.
The token comes only from `openssl rand` into a command substitution and is written with builtin `printf` under `umask 077`.
The secret is created from the file, never argv.
The printed `runArgs` match the proposal byte for byte.
`valid_project` also keeps names safe for systemd `%i` paths.

### Unit files

- `converser-whisper.container` and `converser-kokoro.container` match the proposal's unit block and bullet list exactly: digest-only images, `127.0.0.1:` `PublishPort=`, `NoNewPrivileges`, `DropCapability=all`, `Notify=healthy`, `TimeoutStartSec=900`, `DOWNLOAD_MODEL=false`, and no `Exec=` on Kokoro. The dry run confirms that whisper's `Exec=` reaches `bash -c` as one argument.
- `converser-serve@.service` matches the proposal verbatim. The `EnvironmentFile=` has no `-` prefix, so a missing env file fails closed. The `ExecStartPre` `$${#...}` length check is correct. `StateDirectory=` lands under `~/.local/state`, which is `0700` on this host.
- GPU and CPU paths: both are correct, as shown above. Gate u is reported as `info`/`WARN`, not `FAIL` (deviation 8). That is reasonable because the proposal calls those log lines illustrative, but the 1.1 operator must read that line rather than trusting "all checks passed".

### Launcher `bin/converser` and `record-sockpath.sh`

- **Run dir:** it refuses a symlink or a directory owned by another uid, `chmod 700`s a directory that already exists, and falls back to `/tmp`. This is an improvement over the proposal's `[ -O ]` (deviation 1). A race on `mkdir` fails closed under `set -e`.
- **flock:** fd 9 is inherited by `claude`, as the proposal intends, so `fuser -k` on the lock reaches both processes.
- **Token:** `$(cat "$tokf")` is an argument to builtin `printf`, and `mcp.json` is written under `umask 077`. The devlog's fake-`claude` run confirms 0 occurrences on argv.
- **Deny list:** built once and passed once, and voice-off adds `mcp__voicemode__converse`, as in the proposal.
- **Trap:** it removes `mcp.json`, `prompt.md`, and `converser.sockpath`. `settings.json` stays, but it holds no secret. Because `claude` is not `exec`'d, the trap fires after `claude` exits, including after `fuser -k -TERM`.
- **L1 (nit):** the preflight `curl` has no `--max-time`. If the forward is up but `serve` hangs, the launcher hangs. Add `--max-time 10`, as `mcp_unauth_code` already has.

### `SYSTEM_PROMPT.md`

Every item that proposal stage 1.0 lists for the prompt is present.
The security floor covers no permission or config changes, forwarding only user speech, the voice/typed marker, the call-shape bounds (tightened with `conch_hold_timeout` and `ref_text`, deviation 6), listen gating, and the typed-only control prefix, bound by rules 1-5.
The interaction model covers relay-then-readback, the three intent-verification triggers with the proposal's exact branch examples, one global `#N: <session>` sequence, correction by follow-on, prose in both directions, no acks, silence on unrequested posts, and a spoken budget of about 20 seconds.

**P1 (non-blocking; verify at 1.4).** The prompt tells typed input apart from inbound traffic only by the `From:`/`Kind: stop` header on Stop posts.
It does not say how a `SendMessage` reply or a raw inbox post is rendered.
`inbox.encode` sends a bare `{"type":"user",...}` line, and whether Claude Code wraps it in a sender envelope is unverified.
If it does not, any container process can post a line that the converser reads as typed input.
That is no escalation: the same process can post straight into a bypass overseer's socket.
Still, the typed-prefix rule (rule 6) and the structural relay rule depend on this distinction.
At 1.4 (gates e and f), record how both kinds of inbound message appear in the converser's transcript, and name the marker in the prompt.

### Hooks

- `inbox.py`: this is the single statement of the wire format. Its liveness check is connect-based, and its run-dir expression matches the launcher.
- `stop-post.py`: it always exits 0. It skips the converser (`CONVERSER_SESSION`), headless ancestors (deviation 5), background tasks, and empty messages. It truncates to 600 characters, and it treats a refused or missing socket as "no converser". The trace file is `0600` in an owner-checked directory. Parent argv in the trace holds no token, because the launcher passes only the path.
- **P2 (nit):** a Stop hook run from the checkout writes `hooks/__pycache__/` (from the `inbox` import) into the shared tree. Add a `.gitignore` entry for `__pycache__/`, or set `PYTHONDONTWRITEBYTECODE=1` in the managed hook command.

### `mcp-converse.py`

It reads the token from stdin and refuses a TTY or a short token.
`wait_for_conch=False` holds, and `--list-tools` is audio-free.
The `--listen` cap is 120, which is above the converser floor of 90. That is acceptable for a host-only test client, but gate p and item 1 never need more than 90, so a cap of 90 would match the floor.

### Proposal fidelity

All ten deviations in the devlog NOTE are acceptable.
Deviations 1, 5, 6, and 9, and the `--from-installed` re-exec, strengthen the design.
No deviation weakens a security property.
The proposal's frontmatter `status: implementation_wip` (set in `fe84afe`) is not a value in `frontmatter-spec.md`, which lists `wip`, `implementation_ready`, `implementation_accepted`, and others. This is a nit for the overseer.

## Verdict

**Accept.**
The 1.0 work is correct, safe on every path this review traced, and faithful to the proposal.
Action items 1-2 are conditions on running `install` at 1.1, not revisions to the reviewed files.
Items 3-8 can go into the next implementation turn or stage 3b.

## Action Items

1. [required before 1.1, procedural] Immediately before `sh plugins/converser/host/converser-host install`, confirm that `git rev-parse HEAD:plugins/converser/host` prints `310caaaaea65f3957ca0764545ca7c7400ec919a`. Any other value means unreviewed host code, so stop and get a review first.
2. [required before 1.1, procedural] Confirm that `git config --list --show-origin` in the checkout shows no `core.fsmonitor`, no `core.hooksPath`, and no `filter.*` beyond the host's `lfs` entries from `.bare/config` or a `config.worktree`. Also confirm that `git status --porcelain plugins/converser/host` is empty, with no `__pycache__`.
3. [non-blocking] `instance add`: always write the `.token` file from the env token, and on a fresh add create the secret with `--replace` (or refuse if it exists) (H3).
4. [non-blocking] `install`: add `--expect-tree <sha>` binding to the reviewed tree, and write `installed-rev` only after a successful install (H2).
5. [non-blocking] Run host `git` with `-c core.fsmonitor=false -c core.hooksPath=/dev/null`, and soften the README's "never runs it in place" to name the repo-config caveat (H1).
6. [non-blocking] Add `__pycache__/` to `.gitignore`, or set `PYTHONDONTWRITEBYTECODE=1` for the hook and the floor's `py_compile` (P2).
7. [non-blocking] At 1.4, record how `SendMessage` replies and raw inbox posts render in the converser, and name that marker in `SYSTEM_PROMPT.md` (P1).
8. [non-blocking] Nits: `exit` in the `scoping_stopcheck` `INT`/`TERM` trap (H5); `install_file` error propagation (H6); `--max-time` on the launcher preflight (L1); run `voicemode --version` under the temp `HOME` (H4); change the proposal status `implementation_wip` to a spec value.

## Questions for the user or overseer

1. How should the install be bound to a review, now and later?
   - (a) Procedural tree-hash check at 1.1 only (action item 1) - recommended for now.
   - (b) Add `--expect-tree` to `install` before 1.1, which needs one more short review round.
   - (c) Both: procedural now, `--expect-tree` in stage 3b.
2. Should H3 be fixed before 1.2 (`instance add clauthier`)?
   - (a) Yes: it is about five lines, and 1.2 is the first real use.
   - (b) No: stage 1 has no `instance rm`, so the bug is unreachable without manual cleanup, and `status` catches it.
