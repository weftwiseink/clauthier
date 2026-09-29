---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-28T11:10:00-07:00
task_list: voice/converser-lace-feature
type: report
state: live
status: review_ready
last_reviewed:
  status: accepted
  by: "@claude-opus-5-5"
  at: 2026-09-28T11:27:00-07:00
  round: 3
tags: [analysis, voice, voicemode, complexity]
---

# How complex would forking or replacing VoiceMode actually be

> BLUF(sonnet/voice/converser-lace-feature): VoiceMode is a real, actively-engineered project (~44K non-test LOC, 1,865 tests, 2,149 commits, a dominant maintainer plus an AI collaborator, 161 tags) with hard-won subsystems: VAD endpointing, provider health-checked failover, the conch turn-taking lock, and an authenticated HTTP `serve` mode over FastMCP.
> It already ships the seam a host-side "audio broker" design would want: `voicemode serve --transport streamable-http` runs as a host-side MCP server a container reaches over `pasta:-T,<port>` with zero source changes, audio staying on the host.
> That mode is ~8.5 months old, has 58 tests but none for concurrency, and has two open, reporter-diagnosed, maintainer-unaddressed issues ([#521](https://github.com/mbailey/voicemode/issues/521)/[#522](https://github.com/mbailey/voicemode/issues/522)) where a shared `serve` process can wedge the conch indefinitely, from overlapping playback or a client reconnecting mid-listen.
> Recommendation: adopt the accepted vetting report's first experiment, host `serve` (one process, token, and loopback bind per container, `VOICEMODE_TOOLS_ENABLED=converse`, loopback-only STT/TTS), no source patch, in-container as fallback; forking is credible work (3-6 person-days first patch set, a likely-large first rebase) that should wait for a named tripwire, and a from-scratch broker is 15-25 person-days for rough parity.
> Upstream's own near-term roadmap (mobile apps, "Hey Claude" wake word, barge-in, multi-speaker rooms) substantially overlaps the broker's goals, raising the bar for forking further.

## Scope

The prior deep dive (`cdocs/reports/2026-09-27-voicemode-deep-dive.md`, clauthier repo) read `converse()`, the conch, the control channel, and config knobs, and concluded VoiceMode-unmodified-as-an-MCP-tool is the right substrate for a conversationalist session talking to `SendMessage`/`ListAgents`.
That conclusion stands and is not re-argued here.
This report answers a narrower question raised by a parallel report exploring a host-side "audio broker" (mic/speaker/VAD/STT/TTS behind a narrow speak/listen API, containers as thin clients, a later Android remote): how sophisticated is VoiceMode, and how much work is a fork, a wrapper, or a from-scratch broker.
Source: `build/research/voicemode` in the clauthier checkout, commit `126d15e` (2026-09-15), unshallowed for this report; GitHub state queried live via `gh` on 2026-09-28.

## 1. How sophisticated is VoiceMode, really

### Scale

| Metric | Value | Source |
|---|---|---|
| Python files (total) | 278 | `find` |
| Non-test Python LOC | ~43,600 | `wc -l`, tests excluded |
| Test Python LOC | ~35,300 | `wc -l` on `tests/` |
| `def test_*` functions | 1,865 | `grep` |
| Largest single file | `tools/converse.py`, 4,620 lines | `wc -l` |
| `voice_mode/*.py` (top-level only) | 17,167 lines | incl. `cli.py`; excl. all subpackages |
| `voice_mode/tools/*.py` | 7,612 (top-level) / 12,185 (all 33 files) | 26 `@mcp.tool` entry points |
| `cli.py` + `cli_commands/` | ~5,900 lines | 3,189 in `cli.py` alone |
| Total commits | 2,149 | `git log --oneline` |
| Commits by top author | Mike Bailey 78%, "Cora" (AI collaborator, `ai-cora`) ~19% | `git log --format='%aN'` |
| Tags | 161 | `git tag` |
| Numbered releases | v8.0.0-v8.12.0 (2026-07-21) | `CHANGELOG.md`, ~monthly Jan-Jul |
| First commit | 2025-06-09 | `git log --reverse` |
| GitHub stars / forks | 1,380 / 195 | `gh repo view` |
| CI matrix | ubuntu-latest + macos-latest, Python 3.10-3.12 | `.github/workflows/test.yml` |
| Coverage tooling | `coverage.py` + `codecov` | `pyproject.toml` |

This is not a weekend script: 1,865 test functions is a real regression net, and CI exercises two OSes and three Python minors on every push.
The commit history reads as continuous engineering: `VM-####` issue references are dense throughout, bug reports get root-caused with thread dumps and repro scripts (see #521/#522 below), and fixes come with new tests.

Two things temper "sophisticated," though.
Bus factor is thin: Mike Bailey wrote 78% of all commits, an AI collaborator ("Cora") most of the rest, and the next-most-active humans are single-digit-commit drive-bys.
And the public commit stream shows a two-month gap: the last substantive commit before this clone's HEAD is `5c1b3e4` (2026-07-21, the 8.12.0 bump), and the only commit before clone time (2026-09-15) is a one-line CI fix.
`ai-cora`'s reply to #545 cites a line at "current HEAD" not matching the 8.12.0 tag, so upstream has unpushed internal commits: a public-push gap, not necessarily a development gap.
Live `gh` queries on 2026-09-28 show the numbered-release gap continuing (still v8.12.0), and the maintainer's [#546](https://github.com/mbailey/voicemode/issues/546) comment (2026-09-27) says the team is "putting the finishing touches on some new features" (Section 4) rather than shipping incremental releases.
Meanwhile diagnosed, tested community fix PRs sit open for weeks to months: [#523](https://github.com/mbailey/voicemode/pull/523) opened 2026-08-18, still unmerged; [#281](https://github.com/mbailey/voicemode/pull/281) (barge-in continuation) opened 2026-02-20, still open.

### What's genuinely hard-won

- **VAD-based endpointing.** `record_audio_with_silence_detection` (`converse.py:1335`) drives `webrtcvad` frame classification, a grace period, a minimum recording floor, and a configurable silence threshold.
  [#545](https://github.com/mbailey/voicemode/issues/545) shows the loop's fragility: a lazily-imported `scipy.signal` inside the per-chunk read loop stalled the VAD ~24s on Windows, re-running every ~30ms chunk instead of once, root-caused externally and confirmed by `ai-cora` same-day.
  That is the class of platform-specific timing bug that makes rolling this from scratch (Option D) expensive; the fix needs sequencing against another in-flight PR ([#537](https://github.com/mbailey/voicemode/pull/537)) on the same loop.
- **Provider failover and health checks.** `provider_discovery.py`/`providers.py` (367 + 331 lines) implement live health-checked, capability-matched discovery across an ordered `TTS_BASE_URLS`/`STT_BASE_URLS` list, biased local-first by `PREFER_LOCAL`/`ALWAYS_TRY_LOCAL`.
  `detect_provider_type` special-cases OpenAI, Cartesia, Kokoro, whisper.cpp, and MLX Audio by URL shape, not a static map.
- **The conch.** `conch.py` (676 lines), `conch_queue.py` (696), `conch_ops.py` (446), `conch_notify.py` implement a FIFO-queued, flock-based single-speaker lock with TTL-based hold/refresh and an unfilled remote-waiter seam (`_remote_marker`, `conch_notify.py:153`, reserved for VM-970).
  Two open issues expose two distinct wedge triggers under real concurrency, both against `serve` (detail in Section 2): [#521](https://github.com/mbailey/voicemode/issues/521) (`conch.py:337`, an in-process guard that never re-acquires the flock) and [#522](https://github.com/mbailey/voicemode/issues/522) (a client reconnect leaving a stale holder), both zero-response as of 2026-09-28.
  [PR #523](https://github.com/mbailey/voicemode/pull/523) fixes #522's stream-death symptom but has zero reviews five-plus weeks in, and does not address #521's serialization gap.
- **Barge-in and the control channel.** `control_channel.py` (503 lines) and `control_socket.py` (699) implement a Unix-socket command channel (`pause`/`resume`/`stop`/`skip_forward`/`skip_back`), off by default, interrupting TTS *playback*, not the blocking `converse()` listen call.
- **TTS streaming.** `streaming.py` (1,241 lines) and `cartesia_tts.py` (209, Cartesia's own SSE PCM endpoint) implement chunked synthesis/playback, with a `NonBlockingAudioPlayer` decoupling generation from playback.
- **Cross-platform audio and service installers.** `whisper_model_unified.py` (230 lines) plus install/uninstall tools generate systemd/launchd units and handle model downloads; open PRs [#517](https://github.com/mbailey/voicemode/pull/517) and [#524](https://github.com/mbailey/voicemode/pull/524) extend this to Fedora Atomic and native Windows, each surfacing platform-specific breakage.
- **The HTTP/SSE MCP transport.** `serve` (`cli.py:2017-2273`) wires FastMCP's `http_app()` to `uvicorn`, with IP-allowlist, bearer-token, and secret-path middleware (`serve_middleware.py`, 394 lines).
  It landed 2026-01-15 (VM-434), middleware 2026-01-19: ~8.5 months old, not new, with 58 tests (13 `test_serve.py`, 45 `test_serve_middleware.py`) but none exercising concurrent clients.
  Upstream also ships a stdio-to-HTTP bridge, `mcp_bridge.py`, used when `VOICEMODE_MCP_URL` is set: an existing path for a stdio-only client to reach a remote `serve`.

### What's incidental complexity, not load-bearing

- **CLI sprawl.** `cli.py` is 3,189 lines and `cli_commands/` another ~2,700; much is command-line ergonomics, not core voice functionality.
- **Removed LiveKit residue.** `CHANGELOG.md` records LiveKit's removal under 8.0.0, but a docstring and two docs pages still reference it: documentation drift, not a live feature.
- **Dashboards and cloud-product hooks.** `docs/web/`, the mkdocs site, `voicemode-dev` (a Cloudflare Workers backend, per this repo's `CLAUDE.md` "VoiceMode Suite"), and iOS/macOS app references are adjacent product surface, not code this integration touches.
- **Selective tool loading and the `voice-only` example agent** are convenience layers over the same 26 `@mcp.tool` functions, not separate implementations.

## 2. Seams for modularity

The central question for the broker design is whether VoiceMode already separates "own the mic/speaker/VAD/STT/TTS" from "be an MCP tool a Claude Code session calls," and whether it can run remotely from the container with no source change.

**Audio I/O is not separated from the MCP tool layer at the module level, but it is separated by process today.** `core.py` (1,088 lines: `text_to_speech`, `synthesize_tts_audio`, chime playback, `_wait_for_player_with_control`) and `audio_player.py` (`NonBlockingAudioPlayer`) hold the actual PortAudio/sounddevice calls, and neither imports anything from `tools/` (verified: `grep -n "^from .tools\|^from voice_mode.tools" voice_mode/core.py voice_mode/streaming.py` returns nothing), so tools depend on core, not the reverse.
But `tools/converse.py` (the file most integration work would touch) imports directly from ten-plus internal modules (`converse.py:33-105`: `server`, `conch`, `conch_queue`, `config`, `provider_discovery`, `core`, `audio_player`, `control_channel`, `control_socket`, `history_buffer`, more), a Python-import dependency, not an HTTP/IPC boundary, between "the tool surface" and "the audio engine."
There is no separately-importable `voicemode-core` package; a wrapper (Option b) would import `core`/`audio_player` alongside the rest of the package, not instead of it.

**There is a transport abstraction, and it is real: MCP itself, via FastMCP's `stdio`/`streamable-http`/`sse` transports.** `server.py:104` (the stdio entry point) hardcodes `mcp.run(transport="stdio")`, but `cli.py:2239` builds a second app via `mcp.http_app(transport=transport, path=endpoint_path)` off the *same* `mcp` object imported from `server.py` (`cli.py:2092`), and `serve()` exposes both `streamable-http` (recommended) and `sse` (deprecated).
That is the whole tool surface (26 `@mcp.tool` functions) available over HTTP, unmodified, with no fork; `mcp_bridge.py`/`VOICEMODE_MCP_URL` is upstream's own path for a stdio-only client to reach it.

**VoiceMode can run as a host MCP server over HTTP/SSE today, and a container can just connect, without binding beyond loopback.** `serve`'s `--host` defaults to `127.0.0.1` (`cli.py:2019`), not `0.0.0.0`.
A container reaches it via `--network pasta:-T,8765` in the project's `runArgs`: `pasta` makes the host-side connection itself, so the peer address the server sees is `127.0.0.1`, admitted by `IPAllowlistMiddleware`'s default `LOCAL_CIDRS` (`serve_middleware.py:59-64`) with no `--host 0.0.0.0` and no `--allow-*` flag needed.
This is the same mechanism the accepted proposal's Security Analysis verified empirically for the 2022/8880 forwards; not independently re-run here for 8765, but nothing in `serve` differs from those listeners.
A container session then runs `claude mcp add --transport http voicemode http://127.0.0.1:8765/mcp`.
**Do not bind `--host 0.0.0.0`**: when only `LOCAL_CIDRS` is active the startup banner omits its security section entirely (`has_security` is False), and `0.0.0.0` would expose the full tool surface, unauthenticated, to every RFC1918 peer including other podman networks on the host, not just the intended container.
Add `--token`: since any process with a `pasta` forward to the port arrives as `127.0.0.1` and passes the IP allowlist regardless, the token is the only effective gate against other host/container processes, not defence in depth on top of one; the check is a plain `provided_token != self.token` (`serve_middleware.py:383`), not `hmac.compare_digest`, so it is not timing-safe, but still a meaningful bar against a casual local process, not a co-resident timing attacker.
Scope the exposed surface explicitly with `VOICEMODE_TOOLS_ENABLED=converse`: the unset default is `converse,service` (`tools/__init__.py:113`), and `service` can start/stop/enable host `systemd --user` units; a broader whitelist or a blacklist can also expose `update_config` and the whisper/kokoro install tools against host state.
Also set loopback-only `VOICEMODE_STT_BASE_URLS`/`VOICEMODE_TTS_BASE_URLS` on host `serve`, since the defaults fall back to OpenAI.

**This mode's real caveat is concurrency, with two distinct triggers.** #521 is the *shared-process* trigger: two simultaneous MCP clients on one `serve` process share one in-process `Conch` guard that never re-engages the kernel flock (`conch.py:337`), so overlapping `converse()` calls collide and, per the reporter's own follow-up, "the victim will still replay its entire message" even after #523.
#522 is a *single-client* trigger needing no second caller: a client-side timeout during a long listen, followed by reconnect and a fresh `converse()`, can leave the original server-side call holding the conch with nothing to release it.
Single-caller discipline closes #521 but not #522, whose second caller is the *same logical client*, reconnected.
**Closing both requires an in-process lock inside `serve` (an `asyncio.Lock` around conch acquisition, per #521's own analysis) or one process per container plus a client tool timeout set above the server's maximum `converse()` duration, so the client never abandons a live call; process-per-container alone is not enough.**

**Config for remote STT/TTS endpoints already exists and needs nothing new.** `VOICEMODE_STT_BASE_URLS`/`VOICEMODE_TTS_BASE_URLS` (`config.py:777-778`) are comma-separated ordered lists, pointed at `http://127.0.0.1:2022/v1` (whisper.cpp) and `:8880/v1` (Kokoro) by default, with cloud fallback; nothing assumes co-location with the MCP process, since it is already just an HTTP client, the mechanism the accepted proposal already leans on (`sttBaseUrl`/`ttsBaseUrl` in the feature's `devcontainer-feature.json`).

## 3. Host `serve` versus the accepted in-container design, and options with effort estimates

**What one host `serve` process per container, each on its own `pasta` port, would replace.** The accepted proposal runs VoiceMode inside each devcontainer over stdio: a `pulse/native` socket bind-mount plus `label=disable`, the Debian audio package set and `/etc/asound.conf`, and `pasta:-T,2022,-T,8880` forwards to host STT/TTS.
Host `serve` per container removes the pulse mount, audio packages, and `asound.conf`; it still needs one `pasta` forward per container (the MCP port), and STT/TTS calls become local instead of crossing a forward.
**One claimed saving does not hold.** `label=disable` is not a cost the in-container design pays that host `serve` avoids: the vetting report (finding A14) verified the devcontainer CLI already injects it into every podman-on-Linux container by default, so neither design pays or saves it.

**What host `serve` closes or opens on the cross-container conch gap.** The accepted proposal gives each project its own `~/.voicemode-${lace.projectName}` directory, so today two containers' converser sessions share one host mic and speaker with no lock at all.
Per-container host `serve` processes close that gap automatically: the conch path is hardcoded to `Path.home() / ".voicemode" / "conch"` (`conch.py:133`, queue files as siblings) and ignores `VOICEMODE_BASE_DIR`, so every same-user host `serve` process shares one lock file, and the conch's flock is a real cross-process lock on Linux (unlike #521's in-process guard).
A per-project `VOICEMODE_BASE_DIR` (`config.py:545`) still keeps transcripts, audio, and logs isolated per project while the conch stays shared; only a per-process `HOME` override would split it.
This gain does not fix #521/#522, both single-process failure modes.

**The trust cost.** A host `serve` process, even scoped, is a long-lived listener a bypass-mode container session can reach; at the unset default it exposes `service` (host `systemd --user` start/stop/enable), and a broader tool set adds `update_config` and the install tools against real host state, a materially larger blast radius than the in-container design's file-write-free converser (the accepted proposal removed `Edit`/`Write` to avoid a host-code-execution chain via shared mounts).
Mitigate with `VOICEMODE_TOOLS_ENABLED=converse` plus the Section 2 token; this narrows, not eliminates, the boundary.

| Option | Person-days (first landing) | Ongoing maintenance | Upstream-drift risk | Gained |
|---|---|---|---|---|
| (a) Upstream as-is, host `serve`, one process per container | 1.5-3 (loopback bind, `pasta` forward, token, tool scoping, a `systemd --user` unit; no code) | Near zero: version bump, watch CHANGELOG | Low: a stable, documented CLI surface | Whole tool surface, conch, failover, statistics, for free; audio stays on host |
| (b) Thin wrapper importing VoiceMode's library modules | 3-6 (a narrow speak/listen facade around `core`/`converse` internals) | Low-moderate: pinned to internal API, no stability contract | Moderate: internals can change with no deprecation | A narrower tool surface, without owning audio/VAD/provider code |
| (c) Maintained fork, targeted patches | 3-6 first patch set (`asyncio.Lock` for #521, non-blocking `listen`, a conch event stream); first rebase larger given unpushed HEAD and pending Ambient Voice; 0.5-2 days/release after | Real and compounding: rebasing a 4,620-line `converse.py`/676-line `conch.py` under active revision | High if diverging from upstream; low if upstream-acceptable | Non-blocking listen, remote-audio transport, an event stream: what the broker wants and upstream doesn't yet expose |
| (d) Roll our own minimal broker | 15-25 for rough parity (sounddevice capture, one VAD, whisper.cpp/Kokoro clients, a small MCP server); edge-case fixing is extra, unbounded | High: every edge case VoiceMode already paid for becomes ours to rediscover | None (no upstream) | Full API control from day one; loses the conch, failover, statistics, survey turns, and every fixed platform bug for free |
| (e) Different foundation (Pipecat, Wyoming) | Out of scope; the parallel broker-ecosystem report covers this | — | — | Both real, more transport-native, but VoiceMode-incompatible: abandons Section 1's work rather than extending it |

**Reading this against the converser's stated goals:** the in-container design sidesteps #521/#522's *within-process* hazard for free, but its per-project conch leaves cross-container talk-over unmediated: two hands-free conversers in two containers can both transcribe and act on the same utterance, since each container's conch directory is private.
The accepted vetting report treats that talk-over, alongside the pulse socket's mic/monitor-source capture and inode-pinning findings, as a primary reason to prefer host `serve` first, not a neutral tradeoff.
Closing it requires combining both mechanisms above: Section 2's single-client-per-process and above-max-duration client timeout (avoiding #521/#522) *and* the automatically shared host conch file (the real cross-process flock); the in-container design cannot close it without bind-mounting one conch directory into every container, and stays the fallback if `serve` proves unstable.

## 4. Upstream relationship

**Maintainer responsiveness is real but slow on non-trivial fixes, and uneven.** `ai-cora`, an AI collaborator with `COLLABORATOR` GitHub association, replied to #545 within hours, confirming the exact line and opening an internal tracking ID (VM-2254): a high floor for triage quality on some issues.
But #521 and #522, both opened 2026-08-17, have zero maintainer or `ai-cora` response as of 2026-09-28, and a diagnosed, tested community PR can sit unmerged for a long time: #523 five-plus weeks with zero reviews, #281 (barge-in continuation) since February.
The likely explanation, given Section 1's commit-author concentration, is a review bottleneck that triages unevenly, not indifference.
License and contribution path are unambiguous and low-friction: MIT, a standard fork-PR workflow in `CONTRIBUTING.md`, `pytest`/`pytest --cov`, no CLA.

**Roadmap alignment is substantial, and cuts strongly against forking now.** The maintainer's comment on #546 (2026-09-27): *"Cora, Pip and I are currently putting the finishing touches on some new features that are working here: Hey Claude, iOS and Android chat / calls, Barge in, Multi-speaker rooms.
Hope to get to this soon when the new features are released."*
A second maintainer comment on #545 confirms: *"We've been busy working on Ambient Voice ('Hey Claude', 'barge-in', 'constant recording' and more)."*
Cross-referencing this repo's `CLAUDE.md` ("VoiceMode Suite": `voicemode-ios`, `voicemode-macos`, `voicemode-dev`, a `voicemode-connect` skill for "Remote voice via mobile/web clients"), the picture is a maintainer actively building mobile clients, wake-word activation, real barge-in, and multi-speaker turn-taking: most of what the parallel broker report's "later Android remote" goals ask for.
VM-970 (`_remote_marker`, `conch_notify.py:153`) remains unmerged but is the mechanism this feature set needs, plausibly landing with the same push.

**Viability of contributing rather than forking:** an in-process lock around conch acquisition inside `serve` (#521's own implied fix direction) is the shape of change upstream's architecture already anticipates.
Submitting it, alongside #523, is materially cheaper than forking with no rebase-tax liability, though #521/#522's five-week silence (versus #545's same-day response) means it should not be assumed to land quickly.

## 5. Recommendation

**Reuse: everything in Section 1's "hard-won" list.** VAD endpointing, provider failover, the conch, TTS streaming, and the HTTP/SSE transport are non-trivial, tested outside concurrency, and improving; none should be reimplemented speculatively.

**Own for the first slice: configuration and deployment discipline, not source.** The accepted vetting report's first experiment is host `voicemode serve` against an unmodified container: one `serve` process and token per container, loopback bind, `VOICEMODE_TOOLS_ENABLED=converse`, loopback-only STT/TTS URLs, the container's converser connecting over HTTP with no in-container audio packages; the accepted proposal's stdio in-container stack is the fallback if `serve` proves unstable.
Both this report's Option (a) and the experiment require zero VoiceMode source changes.
A source patch (an in-process lock, or a bounded playback-wait timeout: `core.py:68`'s `_wait_for_player_with_control` calls the player wait with no timeout argument, so no config knob exists today) is not part of the zero-source baseline; treating it as such was this report's round-1 BLUF error.
As a no-patch mitigation for a hung `converse()`, the control channel's `stop` command (`control_channel.py:60,161`, off by default) breaks the wait loop without a source change, but needs empirical verification (Unverified claims).

**Tripwires that would justify moving from (a)/(b) toward (c)/(d):**
- **Concurrency**: needing more than one simultaneous MCP client per `serve` process, or unable to keep the client's tool timeout above the server's max call duration (the #522 reconnect path), is not solved by #523 alone; it needs an in-process lock (propose upstream first) or strict one-process-per-client.
- **Non-blocking listen**: if "the container calls `listen()`, gets control back immediately, results arrive async" proves necessary, propose it upstream first, fork only if rejected or stalled past a defined SLA (30 days, calibrated against #545's same-day precedent versus #521/#522's five-plus-week silence).
- **Upstream's remote/mobile features land and don't fit**: once VM-970 and Ambient Voice ship, re-evaluate directly; if they solve Android-remote outright, Option (d) is unlikely to ever be worth building.
- **The release gap recurs, or #521/#522-class issues stay unaddressed past an SLA**: the bus-factor risk materializing, the strongest argument for a minimal independent patch set.

## Decision points

1. **Should the converser track move from the accepted in-container design to host `serve`?**
   Recommendation: **adopt the vetting report's first experiment: host `serve` with an unmodified container, in-container as fallback.** Cross-container talk-over is a real cost of the in-container design, not a neutral tradeoff (Section 3), and one of the vetting report's stated reasons to prefer `serve` first, alongside avoiding the pulse socket's mic/monitor-source capture and inode pinning. Concretely: one `serve` process and token per container, loopback bind, `VOICEMODE_TOOLS_ENABLED=converse`, loopback-only STT/TTS URLs, single-client-per-process, and a client tool timeout above the server's max `converse()` duration (Section 2), so #521/#522 stay closed from the start. Fall back to in-container stdio only if `serve` proves unstable. For the in-container fallback, bind-mounting one conch directory into several containers is worth a follow-up spike, but its stale-hold reclaim uses `psutil.pid_exists` (`conch.py:232`), blind to PIDs in another container's PID namespace, so a hold left by one container can look dead and get cleared by another; needs verifying before depending on it.

2. **For a host `serve`, which tool surface is acceptable to expose to a bypass-mode container session?**
   Recommendation: **(A) `converse`.** `converse()` acquires and releases the conch itself (`wait_for_conch`); the separate `conch` tool only adds cross-turn floor holds, which a single converser does not need. The full surface exposes `service`, `update_config`, and the install tools against host state for no benefit.

3. **Should the report propose an upstream PR for #521's in-process lock alongside #523, given the review bottleneck?**
   Recommendation: **(A) yes, file it now, but don't gate the converser track on it landing.** The fix is small and in the shape of change upstream's architecture anticipates; #545's same-day response shows some issues get fast engagement, but #521/#522's five-plus weeks of silence is the base rate to plan around.

## Unverified claims

- Whether `serve`'s middleware has been security-reviewed or pen-tested by anyone besides its author.
- Whether `pasta:-T,8765` reachability works like the accepted proposal's verified 2022/8880 forwards; inferred by analogy, not re-run.
- Whether the control channel's `stop` unwedges a `converse()` call stuck in `_wait_for_player_with_control`; plausible, not tested live.
- Whether the `psutil.pid_exists` stale-reclaim gap across container PID namespaces (Decision point 1) is exploitable, or only theoretical.
- Exact behavior of `serve` under "one process, N containers, calls serialized over time"; #521/#522 cover simultaneous/reconnecting clients, not strictly sequential access.
- Whether an in-process `asyncio.Lock` patch for #521 would compose cleanly with `serve`'s request-handling path.
- The real-world timeline for VM-970 and "Ambient Voice"; no target date was given.
- Whether "Cora"/`ai-cora` is autonomous or a human using AI-branded tooling; inferred from style, not confirmed.
- The Option (d) estimate (15-25 person-days) is a rough analogy against VoiceMode's module sizes, not bottom-up.
