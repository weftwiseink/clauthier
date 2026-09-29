---
review_of: cdocs/proposals/2026-09-29-converser-host-voicemode-serve.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-29T09:39:54-07:00
task_list: voice/converser-lace-feature
type: review
state: live
status: done
tags: [fresh_agent, architecture, security, claims_verified, runtime_validated, stage_one_implementability, proportionality]
---

# Review: converser on host `voicemode serve`: staged design and placement

> BLUF(opus/voice/converser-lace-feature): Revise, with two small blocking fixes.
> The placement split holds up, and nearly every factual claim checks out against VoiceMode source, the Claude Code docs, and this host.
> The two blockers are a false source claim that `VOICEMODE_CONCH_TIMEOUT` bounds every opt-in conch wait, and a stage-1 whisper/Kokoro loopback rebind that the doc requires for security but never says how to do.
> Live inspection shows whisper's upstream `0.0.0.0` bind would be LAN-reachable on this host, so the rebind is not optional.

## Summary Assessment

The proposal moves converser audio to one host `voicemode serve` per container, supervised by `systemd --user`.
Each container reaches its instance over a `pasta:-T` forward, and the proposal places every piece across host, lace, clauthier, and dotfiles, with packaging gated behind a week of real use.
It is careful, well-evidenced, and answers all three of the user's placement questions directly.
"Systemd supervises, lace binds" is a sound answer to the shoehorn concern, and the interaction model matches the stated requirements, including an honest residual-risk section.
I verified the requested focus claims: the 60s HTTP timer and the `timeout` field, the `crossSessionInbound` scope quote, systemd `EnvironmentFile=` precedence, and `VOICEMODE_SERVE_TOKEN` and `--port` handling.
All are correct except one conch-timeout claim, which is false.
Gate (t) is more settled by the docs than the WARN admits.
Stage 1 is implementable, except that the host-prerequisite step is underspecified for this host: an rpm-ostree atomic desktop with no system `g++`, where whisper's bind address is hardcoded.
Verdict: **Revise**.

## Claim Verification

| Claim (section) | Result | Evidence |
|---|---|---|
| `--port`/`--host` are click literals; `VOICEMODE_SERVE_PORT` is not read by `serve` | **Correct** | `cli.py:2019-2020`; `config.SERVE_PORT` exists (`config.py:1642`) but `serve()` never consults it |
| Token from `VOICEMODE_SERVE_TOKEN` when `--token` absent | **Correct** | `cli.py` serve body: `if token is None and SERVE_TOKEN: token = SERVE_TOKEN`; `config.py:1664` |
| Default tools `{converse, service}`; `VOICEMODE_TOOLS_ENABLED` narrows | **Correct** | `tools/__init__.py:119`, whitelist branch precedes disabled/legacy |
| Process env beats `voicemode.env` files | **Correct** | `config.py:520` |
| STT/TTS default lists end in `api.openai.com` | **Correct** | `config.py:777-778` |
| Whisper binds `0.0.0.0` | **Correct, and worse than stated** | Hardcoded in `start-whisper-server.sh:149` and `whisper/install.py:146`, not configurable. Live: `firewalld` zone `FedoraWorkstation` opens `1025-65535/tcp` on `enp3s0`, so 2022 would be LAN-reachable |
| `VOICEMODE_CONCH_TIMEOUT=60` "bounds any opt-in conch wait" | **False** | `converse.py:3118-3123`: a numeric `wait_for_conch` replaces `CONCH_TIMEOUT` as the wait bound. See finding B1 |
| HTTP MCP 60s first-byte timer; per-server `timeout` (ms) raises it and floors idle timeout | **Correct** | [mcp](https://code.claude.com/docs/en/mcp): timer is "the greatest of three values: 60 seconds, the tool timeout that applies to the server, and `MCP_TIMEOUT`"; floor applies to a per-server `timeout` of at least 1000. Whether FastMCP emits an early byte is untested; Test Plan item 4 settles it |
| `crossSessionInbound` project/local scope quote | **Correct, verbatim** | [settings-reference](https://code.claude.com/docs/en/settings-reference#crosssessioninbound); values `accept`/`hold`/`refuse` |
| `CLAUDE_CODE_MESSAGING_SOCKET` available to `SessionStart` | **Correct** | [cross-session-messaging](https://code.claude.com/docs/en/cross-session-messaging#the-sessions-inbox-socket): "exports the variable before any hook runs, including `SessionStart`" |
| Container and host sessions cannot message | **Correct** | Same page |
| systemd `EnvironmentFile=` overrides `Environment=` | **Correct** | `systemd.exec(5)`: "Settings from these files override settings made with Environment=" |
| `%S`, `${VAR}` in `ExecStart` | **Correct** | `systemd.unit(5)` specifier table; `systemd.service(5)` variable substitution |
| Plugin agent ignores `permissionMode`/`hooks`/`mcpServers`; plugin `settings.json` honors only `agent`/`subagentStatusLine`; `defaultEnabled` exists | **Correct** | plugins/components; settings-reference `enabledPlugins` names `defaultEnabled` fallback |
| Managed `enabledPlugins` force-enables; user `false` cannot disable | **Correct, and better documented than the WARN says** | [plugins/org](https://code.claude.com/docs/en/plugins/org): managed settings "installs the two plugins at the start of the user's next session... disabling one at their own scope doesn't stop it from loading"; control matrix: `enabledPlugins` "Doesn't install a plugin whose marketplace isn't registered or allowed". See N3 |
| Invalid managed drop-in stops sessions | **Correct** | [managed-settings](https://code.claude.com/docs/en/managed-settings): unparseable drop-in makes Claude Code "refuse to start" |
| `--tools` takes `ListAgents,SendMessage`; `--append-system-prompt-file`, `--name`, `--strict-mcp-config` exist | **Correct** | [cli-reference](https://code.claude.com/docs/en/cli-reference) |
| `ENABLE_TOOL_SEARCH=false` loads MCP tools upfront | **Correct, with a wrinkle** | [mcp](https://code.claude.com/docs/en/mcp): without tool search, Claude uses a `WaitForMcpServers` tool. Whether `--tools` strips it is unknown; gate (d) should expect it |
| "Plugin installation ... installed once for host and containers alike" | **Inaccurate** | Live `~/.claude/plugins/installed_plugins.json` holds separate `cdocs@clauthier` records for `/var/home/mjr/code/weft/weftwise/main` (install path `/home/mjr/...`) and `/workspaces/weftwise/main` (install path `/home/node/...`). See N3 |
| Lace facts (portless daemon, 22425-22499, no `--network` today) | **Correct** | `host-portless.ts`, `port-allocator.ts:8-9`; no `--network` synthesis found |
| `weftwise` on pasta, `XDG_RUNTIME_DIR=/run/user/1000`, clauthier at host path | **Correct** | `podman inspect weftwise`. Note `/run/user/1000` in the container is overlayfs, not tmpfs |

## Section-by-Section Findings

### BLUF, Summary, Objective

Clear, and the BLUF produces no surprises in the body.
The Summary answers the four questions in the order the user asked them.
Non-blocking: "The accepted round-4 proposal put..." and "The heart of the revision" (line 267) use history framing outside a NOTE.
The supersession NOTE already carries that context.

### Facts this design rests on

Strong: every source-backed claim I checked holds except the one in B1.

**B1 [blocking]: the conch-timeout claim is false, and the call-shape floor has a hole.**
The facts list and the "Design points" bullet say `VOICEMODE_CONCH_TIMEOUT=60` "bounds any opt-in conch wait, keeping the server's worst-case call duration computable".
In `converse.py:3118-3123`, `wait_for_conch` accepts a number, and a positive number *replaces* `CONCH_TIMEOUT` as the wait bound.
`wait_for_conch=900` therefore waits up to 900s, which exceeds the 600s client `timeout` and recreates the #522 trigger the design claims to close.
`hold_conch`/`conch_hold_timeout` also have no floor line.
Fix:
(a) State that the env var bounds only `wait_for_conch=true`.
(b) Add to the security floor "`wait_for_conch` only as `false` or `true`, never a number; no `hold_conch`, or `conch_hold_timeout` ≤ 30".
(c) Note that these bounds are prompt-level, like `listen_duration_max` (no server clamp), so the client-timeout argument holds for the converser but not for other token holders (see N6).

### Host: `serve` instance per container

The unit is implementable as written.
`%S`, `StateDirectory=`, `${VOICEMODE_SERVE_PORT}` in `ExecStart`, and `%h/.local/bin/voicemode` (the `uv tool` default bin dir; `pyproject.toml` declares the `voicemode` script) all check out.
Pinning `ALLOW_TAILSCALE`/`ALLOW_ANTHROPIC` is redundant with the defaults but correctly defends against the global `voicemode.env`.

**N1 [non-blocking]: the env-file WARN is correct, but its mitigation is a convention where a structural one is cheap.**
Every `Environment=` line loses to `EnvironmentFile=`, including one in a drop-in, so the "two keys only" contract is enforced only by the Test Plan.
Putting the security pins on the command itself makes them win regardless of the file:
`ExecStart=/usr/bin/env VOICEMODE_TOOLS_ENABLED=converse VOICEMODE_STT_BASE_URLS=... VOICEMODE_TTS_BASE_URLS=... %h/.local/bin/voicemode serve ...`.
Then the `/proc/<pid>/environ` check confirms the pins rather than being the only guard.

**N2 [non-blocking]: the walk-up edge case names the wrong directory.**
The loader walks up from `%S/voicemode-serve/<project>` through `~/.local/state`, `~/.local`, `~`, `/var/home`, and on to `/`.
The file that could actually be picked up is `~/.voicemode.env` in the home directory, not anything in `%S`.
Process-env pins still win, so impact is low, but the edge case should name `~/.voicemode.env`.

Minor: upstream's unit uses `Restart=always` (GH-448) where this one uses `on-failure`; say why if it is deliberate.
The startup banner logs the first four characters of the token to the journal (`mask_secret`), which is negligible but worth one clause in the "token visible to host processes" row.

### Container: the converser session and launcher

The launcher is implementable against Claude Code 2.1.257 in `weftwise`.
`flock` exists at `/usr/bin/flock`, `podman exec` defaults to user `node` with `HOME=/home/node`, and `$XDG_RUNTIME_DIR` is set.
Keeping the token off argv and inlining it into a `0600` temp file is a sound workaround for the unverified `--mcp-config` expansion.

Non-blocking:
- The `trap ... EXIT` does not run in `dash` when the shell dies from SIGHUP (terminal closed), so the token-bearing temp file can survive on the container's overlayfs `/run/user/1000`, which is not tmpfs. Add `trap 'rm -f "$cfg"' EXIT HUP INT TERM`, or delete the file once `claude` has connected (acceptable only if Claude Code never re-reads the file on `/mcp` reconnect, which is unverified).
- fd 9 (the lock) is inherited by `claude` and its children, so a lingering hook or child keeps the lock after `claude` exits. `exec 9>&-` cannot be applied only to `claude`; accept it and note that `fuser` finds the holder.
- Gate (d) should expect `WaitForMcpServers` as a possible extra built-in under `ENABLE_TOOL_SEARCH=false`.

### Overseer hooks

Sound: tier-2 redirect over tier 3 is the right v0 call, and a trace-first Stop hook is proportionate.
The `last_assistant_message`, `background_tasks`, and `async: true` hook fields are documented.
Open Question 5 (headless detection) matters more than its placement suggests.
Until it is settled, every `claude -p` worker in the container that finishes a turn is a potential post.
The trace dry run will show whether that happens, so this needs no change beyond asking the trace to record the parent argv it saw.

### Converser interaction model

This matches every stated requirement:
- The converser cleans speech into the outgoing message and echoes the cleaned message, never the raw transcript.
- It sends without asking and confirms only on incongruity.
- Corrections are follow-on utterances against a numbered, visible history, with no recall.
- Prose is human in both directions and faithful to the speaker's hedges and register.
- Seeding, fingerprinting, and audio provenance are all deferred to Future Work.
- The structural relay rule (only user speech is forwarded) removes the laundering path without a confirmation step, which is elegant.

Non-blocking: the ordering is ambiguous.
The text says the converser "shows ... speaks a short readback ('Sent to weftwise: ...'), and sends".
"Sent" implies the readback comes after the send, but the sentence order puts it first.
State one order.
Send-then-readback is lower latency and consistent with no-confirmation.
Readback-then-send gives the user an interrupt window only if the stage-2 "stop talking" hotkey can abort the send, which it cannot today (the control channel stops playback, not the pending `SendMessage`).
Recommend send-then-readback and saying so.

### Placement, and where host-side `serve` responsibility goes

This is the strongest section, and I agree with its conclusions:
- **Lace feature still needed?** Not for stages 1-2. At stage 3 a thin one is justified as the single per-project switch, with the portless feature as precedent.
- **Clauthier plugin for in-container wiring?** Behavior (agent, skill, hooks) yes. Enablement comes from a container-local managed drop-in. The MCP entry, `crossSessionInbound`, and flags stay with the launcher. The hook-scope analysis (user settings are the shared bind mount; project settings reach host sessions and collaborators) is correct and is the non-obvious part.
- **Host-side responsibility.** Option C ("systemd supervises, lace binds") answers the shoehorn worry. Lace supervising the PID would be the shoehorn, and the doc explicitly rejects that (option A). What remains is binding: allocating the port, minting the token, adding the forward, mounting the token file. Lace already does each of these for other resources.

**N3 [non-blocking]: tighten the plugin-installation claim and the gate (t) WARN.**
First, "installed once for host and containers alike" is inaccurate.
Install records are per scope and project path, and the container already has its own `cdocs@clauthier` record under `/home/node/.claude/...`.
Second, [plugins/org](https://code.claude.com/docs/en/plugins/org) documents what the WARN calls undocumented.
Managed `enabledPlugins` installs from a registered marketplace at session start and overrides a user-scope `false`.
It does not install when the marketplace is unregistered.
Directory marketplaces are a first-class source type.
So:
(a) Cite plugins/org and narrow gate (t) to "a directory-source managed install inside the container works".
(b) Make the stage-3 drop-in self-sufficient by adding `extraKnownMarketplaces.clauthier` (directory source at `/var/home/mjr/code/weft/clauthier/main`, mounted read-only at that path in `weftwise`) next to `enabledPlugins`. Registration then no longer depends on the shared user settings.
(c) Replace the "Drop-in present, plugin not installed" failure state with "marketplace unregistered or path unmounted".

**N4 [non-blocking]: `defaultEnabled: false` is correct but needs one more sentence.**
Project settings take precedence over user settings for `enabledPlugins`.
So a future `weftwise/.claude/settings.json` that enables `converser@clauthier` would re-widen scope to host sessions in that repo.
The constraints list for stage 3 should say the plugin is never listed in any project settings file.

### Security Analysis

The re-derived posture table is correct, and the residual-risk section is honest in the way the user asked for.
It states that a plausible injected instruction passes, that bypass is no backstop, and that correction is not rollback.
The "High" likelihood for whisper LAN exposure is confirmed live (see B2).

**N6 [non-blocking]: add the #521 consequence to the "any container process reads the token" row.**
The single-client-per-process mitigation for #521 holds only while the converser is the only client.
Any container process holding the token can open a second concurrent client and reintroduce the in-memory-guard wedge, and it is not bound by the converser's call-shape floor.
The likelihood is the same as the row's, and the impact is a wedge needing `systemctl --user restart`.
One sentence suffices.

### Edge Cases

Good coverage. Two refinements:
- **`serve` restarts mid-call.** Claude Code reconnects a dropped HTTP server with up to five backoff attempts (about 31s in total) and then marks it failed ([mcp](https://code.claude.com/docs/en/mcp)). `RestartSec=5` fits inside that window, but a longer outage (whisper or Kokoro down at boot, host logout) leaves the converser needing `/mcp` reconnect or a relaunch. Say so, since "retries once" suggests self-healing.
- **Container rebuild** also drops the managed drop-in. That drop-in is the stage-1 Stop hook, so after a rebuild the overseers silently stop posting. Stage 1 accepts this, but "hooks silently absent" is exactly the failure the Stop trace cannot see, because the trace comes from the missing hook. Add a one-line post-rebuild check to the stage-1 checklist.

### Test Plan and Verification Methodology

Observation-based verification (`podman inspect`, `/proc/<pid>/environ`, `/status`) is the right lesson from A14.
Items 1, 2, and 4 are well designed; item 4 in particular turns the timeout claim into an empirical check.

Non-blocking: the plan announces "new gates (p)-(t)", but (r) and (s) appear nowhere, and (p), (q), and (t) are defined only inline.
Add a short gate list defining p-t, or renumber.

### Implementation Phases: implementability and proportionality

**B2 [blocking]: step 1.0 requires a loopback rebind it never specifies, on a host where the obvious path does not exist.**
Whisper's bind is hardcoded in the start script VoiceMode's installer writes, and the Python installer's generated script too.
There is no env var or flag to change it.
"Rebind both to `127.0.0.1`" by hand therefore means editing an installer-generated script that `voicemode whisper install` (or an update) can silently regenerate.
The Security Analysis rates the unrebound state "High", and this host's firewalld zone opens `1025-65535/tcp`, so the step carries real weight while having no concrete procedure.
Fix: specify the mechanism and its durability, for example:
(a) a user-unit drop-in whose `ExecStart=` runs a copied, loopback-bound start script outside VoiceMode's managed tree, or
(b) a direct `whisper-server --host 127.0.0.1` unit that bypasses the upstream script.
Add a firewalld rich rule dropping 2022/8880 on non-loopback interfaces as a second layer.
Do the same for Kokoro once its bind is read (currently unverified).
Test Plan item 2's `ss -ltn` check then verifies a durable configuration rather than a hand edit.

**N5 [non-blocking]: stage 1.0 is the expensive part of a "cheap" stage and should say so.**
This host is an rpm-ostree atomic desktop (`aurora-dx-nvidia-open`).
It has no system `g++`, and a C++ toolchain exists only via linuxbrew (`g++-16`, `cmake`).
`libportaudio.so.2` is present, but PortAudio headers are not.
Building whisper.cpp and installing Kokoro-FastAPI (a torch-sized download) are the likeliest time sinks against weftwise dev time, and "exact subcommand names verified at install time" understates that.
Recommend:
(a) time-box 1.0 and state the fallback if it overruns;
(b) consider a stage 1a that installs whisper only and runs the converser with `skip_tts`, showing readbacks in the terminal history, which answers "does voice input get used" at half the host install;
(c) note that step 1.3 recreates the `weftwise` container, which ends every running overseer session, so it should be scheduled at a natural break.
Also say whether the `runArgs` line in `weftwise/.devcontainer/devcontainer.json` is committed or kept as a local uncommitted edit.
Committing it pushes a host-specific voice forward to every collaborator and worktree; lace's user config supports `containerEnv` but not `runArgs`.

**Proportionality overall.** Stages 1-2 are appropriately hand-wired, and nothing is packaged before real use; this meets the incrementalism requirement.
Stage 1 bundles eleven gates and a full AFK-arc Stop-hook dry run before "does voice get used" is answered.
A reply can reach the converser without the Stop hook, because a bypass overseer's `SendMessage` to a bypass converser is delivered.
So a first checkpoint after 1.4 (one spoken request out, one `SendMessage` reply back) would settle the core question before the Stop-hook work.
The stage-3 design (options table, binding data flow) runs ahead of the gate, but it is what the user asked to resolve and commits no work, so it is acceptable.

### Open Questions

Well chosen.
Question 1 (chezmoi option F versus unmanaged) deserves a default answer now: if stage 2 kills the project, delete the unit; if lace declines 3b, move it to chezmoi.
Question 4 can be closed faster by a one-minute test than by waiting.

## Verdict

**Revise.**
The design, placement, and interaction model are sound and verified. Two factual or procedural gaps must close before acceptance:
- **B1:** the conch-wait bound is false as written, and the call-shape floor lacks the line that would make the worst-case duration actually computable.
- **B2:** the security-critical loopback rebind has no specified mechanism and would not survive an installer re-run.

Both are small edits.
The non-blocking items tighten claims (gate t, plugin installation) and lower stage-1 cost.

## Action Items

1. [blocking] Correct the `VOICEMODE_CONCH_TIMEOUT` claim (Facts and Design points): it bounds only `wait_for_conch=true`, while a numeric value overrides it (`converse.py:3118-3123`). Add to the security floor and stage-1 `SYSTEM_PROMPT.md` list: `wait_for_conch` only `true`/`false`, never numeric; no `hold_conch`, or `conch_hold_timeout` ≤ 30.
2. [blocking] Specify how whisper, and Kokoro once its bind is checked, are bound to loopback durably: a custom unit or a drop-in with a copied script outside VoiceMode's managed tree, since the upstream bind is hardcoded. Add a firewalld drop rule for 2022/8880 on non-loopback interfaces as a second layer, and cite the live `FedoraWorkstation` zone (`1025-65535/tcp` open) as evidence for the "High" rating.
3. [non-blocking] Move the security pins into `ExecStart=/usr/bin/env ...` so an env-file line cannot override them; keep the environ check as confirmation.
4. [non-blocking] Replace "installed once for host and containers alike" with the per-scope, per-path install reality. Cite [plugins/org](https://code.claude.com/docs/en/plugins/org) in the gate (t) WARN and narrow it. Add `extraKnownMarketplaces.clauthier` to the stage-3 drop-in. Add "never enabled from any project settings file" to the stage-3 constraints.
5. [non-blocking] Pick and state the relay order; send-then-readback is recommended.
6. [non-blocking] Add a stage-1a checkpoint (voice loop via `SendMessage` reply, no Stop hook), optionally STT-only with `skip_tts`. Time-box step 1.0 and note the atomic-host toolchain. Schedule the 1.3 container recreate at a break, and say whether the `runArgs` edit is committed.
7. [non-blocking] Add the #521 second-client consequence to the token-holder threat row.
8. [non-blocking] Edge cases: note Claude Code's five-attempt reconnect limit and the `/mcp` recovery; add a post-rebuild drop-in check to the stage-1 checklist; name `~/.voicemode.env` as the walk-up file that matters.
9. [non-blocking] Define gates (p)-(t) in one list, or drop the unused (r)/(s).
10. [non-blocking] Launcher: trap `HUP INT TERM` as well as `EXIT`; expect `WaitForMcpServers` in gate (d).
11. [non-blocking] Move the Summary's round-4 history framing into the existing NOTE; replace "The heart of the revision".

## Questions for the Author

1. Stage-1 relay order:
   (a) send, then speak the readback (recommended);
   (b) speak the readback, then send, with no interrupt path;
   (c) speak the readback, then send, with an interrupt path added at stage 2.
2. Stage-1 host audio scope:
   (a) whisper and Kokoro as written;
   (b) whisper only with `skip_tts` for stage 1a, adding Kokoro at stage 2 (recommended, given the atomic host);
   (c) a time-boxed attempt at (a) that falls back to (b) on overrun.
3. The stage-1 `runArgs` forward:
   (a) a local, uncommitted edit to `weftwise/.devcontainer/devcontainer.json`;
   (b) committed to weftwise;
   (c) wait for lace user-scoped `runArgs`.
   (a) is recommended for a hand-wired experiment.
