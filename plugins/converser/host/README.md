# converser-host

> BLUF: Host side of the converser. It runs VoiceMode `serve` on the host (one loopback instance and bearer token per container project), whisper.cpp and Kokoro as rootless, digest-pinned Quadlet containers, and hands each container its token as a podman secret.
> Design: [`cdocs/proposals/2026-09-29-converser-host-voicemode-serve.md`](../../../cdocs/proposals/2026-09-29-converser-host-voicemode-serve.md).

This directory is host tooling shipped beside the plugin, not executed by the plugin runtime.
Nothing here holds secrets.

## Review before install

The clauthier checkout is writable from the `clauthier` container, so the host never runs its code in place.
One caveat: `install` still runs host `git` against that repo, whose config a container session could edit. `install` disables `core.fsmonitor` and `core.hooksPath`, but not every exec-capable key (for example `filter.*` drivers), so check `git config --list --show-origin` before each install.
`install` refuses a dirty `plugins/converser/host/`, copies the committed tree (`git archive HEAD`) to `~/.local/share/converser-host/src/`, links `~/.local/bin/converser-host` to that copy, records the commit in `~/.local/share/converser-host/installed-rev`, and re-executes from the copy.
Every later command runs from the installed copy.

Before each install, review what will run:

```sh
git log -p "$(cat ~/.local/share/converser-host/installed-rev)"..HEAD -- plugins/converser/host/
# first install: the whole directory
git log -p -- plugins/converser/host/
```

## Commands

```sh
sh plugins/converser/host/converser-host install [--cpu]   # from the clean checkout
converser-host instance add <project> [--port N] [--uid U]
converser-host status [<project> [<container>]]
```

- `install`: requires `container_use_xserver_devices` on (it prints the one `sudo setsebool -P container_use_xserver_devices on` line and stops otherwise; it never runs `sudo`), or `--cpu`.
  It installs `voice-mode==8.12.0` with `uv` (Python 3.12, `simpleaudio` excluded via `uv-excludes.txt`), runs a throwaway `serve` on `127.0.0.1:8800` that must answer 401 without its token and list exactly `converse` and `pause_conversation` with it, downloads and checksums the whisper model, writes the units, pulls the pinned images, starts STT and TTS, masks VoiceMode's own unit names, and verifies loopback-only exposure.
- `instance add`: picks a port in 8765-8799, mints a 64-hex token into `~/.config/converser-host/instances/<project>.{env,token}` (`0600`), creates the podman secret `converser-<project>` from the file, enables `converser-serve@<project>`, and prints the `runArgs` to add. Re-running it repairs a missing or stale token file, secret, or unit without changing the port or token, and restarts a running `serve@` that holds a different token.
A replaced secret reaches only newly created containers: an existing container keeps the old token until it is recreated (`lace up --rebuild`), and `status` does not check the container's copy.
- `status`: loopback listeners, `127.0.0.1` port bindings, active units, masked upstream units, the GPU backend line; per instance: 401 without the token, exactly `converse` and `pause_conversation` with it, the pinned environment in `/proc/<MainPID>/environ`, and no `--token` on any argv. Given a container, it also checks the forward and secret in its `CreateCommand`.

`mcp-converse.py` is the host MCP test client (Test Plan item 1). Run it with the tool venv's interpreter from the installed copy, token on stdin: `~/.local/share/uv/tools/voice-mode/bin/python ~/.local/share/converser-host/src/mcp-converse.py --port 8765 --listen 30 < ~/.config/converser-host/instances/<project>.token`. Without `--list-tools` it opens the host mic and speakers.

## The container contract

This is the one interface between the host package and the container side (`bin/converser`, `launcher/`, `hooks/`):

| Item | Value |
|---|---|
| Token | file `/run/secrets/converser-token`, mode `0400`, owned by the container user, from `--secret converser-<project>,target=/run/secrets/converser-token,uid=<uid>,mode=0400` |
| Endpoint | `http://127.0.0.1:8765/mcp` in every container, whatever the host port: `--network pasta:-T,8765:<host port>` |
| Auth | `Authorization: Bearer <token>`; an unauthenticated `POST /mcp` answers 401 |
| Tools | exactly `converse` and `pause_conversation` (the client disallows `pause_conversation`) |
| Run dir | `${XDG_RUNTIME_DIR:-/tmp}/converser-$(id -u)`, `0700`, owner-checked; holds `lock`, `mcp.json`, `settings.json`, `prompt.md`, `converser.sockpath`, `stop-trace.jsonl` |

The run-dir expression is shared verbatim by the launcher, `launcher/record-sockpath.sh`, and `hooks/inbox.py` (used by `hooks/stop-post.py`).
The `/tmp` fallback matters: `clauthier` sets no `XDG_RUNTIME_DIR`.

The two `runArgs` entries go into the project's `.devcontainer/devcontainer.json` as a local edit protected by `git update-index --skip-worktree`, never committed: a host without the secret cannot create the container.

## Invariants

- Nothing binds or publishes off loopback: `serve` binds `127.0.0.1`; STT and TTS bind `0.0.0.0` only inside their own network namespaces and publish on `127.0.0.1:2022` and `127.0.0.1:8880`.
- No token on any command line: tokens live in `0600` files, the podman secret store, and process environments; `curl` gets the header from the `printf` builtin through `curl -K -`.
- Security pins sit on the `serve@` `ExecStart` command line, so the env file cannot override them.
- Images, VoiceMode, and the model are pinned (digests, `==8.12.0` with `--exclude-newer`, sha256) and bumped by hand.

## Files installed

| Path | From |
|---|---|
| `~/.config/containers/systemd/converser-{whisper,kokoro}.container` | this directory (`--cpu` rewrites images and model) |
| `~/.config/systemd/user/converser-serve@.service` | this directory |
| `~/.config/systemd/user/voicemode-{whisper,kokoro,serve}.service` | mask symlinks to `/dev/null` |
| `~/.config/converser-host/instances/<project>.{env,token}` | `instance add` |
| `~/.local/share/converser-host/{src/,models/,installed-rev,installed-deps,mode}` | `install` |
| `~/.local/state/converser-serve/<project>/` | `serve@` `StateDirectory` (VoiceMode `BASE_DIR`) |

## Recovery

- Wedged or pinned `serve` (for example a long `pause_conversation` from another token holder): `systemctl --user restart converser-serve@<project>`.
- Secret missing after a host change: `converser-host instance add <project>` recreates it from the stored token.
- GPU denied: `sudo ausearch -m avc -ts recent`, then the boolean above, or `install --cpu`.
- Logs: `journalctl --user -u converser-whisper -u converser-kokoro -u converser-serve@<project>`.
