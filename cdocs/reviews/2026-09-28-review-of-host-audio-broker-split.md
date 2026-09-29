---
review_of: cdocs/reports/2026-09-28-host-audio-broker-split.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-28T11:12:07-07:00
task_list: voice/converser-lace-feature
type: review
state: live
status: done
tags: [fresh_agent, security, threat_model, networking, options_ladder, android, prior_art, empirical_check]
---

# Review: Splitting converser: a host-side audio broker

## Summary Assessment

The report asks whether the accepted `converser` proposal's two worst security costs (every in-container process gets the pulse socket, and `label=disable` for the whole container) can be removed by moving audio behind a narrow host-side API, with an Android client as a later extension point.
The transport survey is useful. `voicemode serve` is correctly identified as a broker that already exists, and Remote Control and LiveKit check out against their sources.
The security analysis rests on an access-control model that does not hold. I confirmed empirically on this host that a connection forwarded by `pasta:-T` reaches the host listener from peer `127.0.0.1`. VoiceMode's default allowlist is loopback plus RFC1918 ranges, with no token by default. So the allowlist cannot tell a container from a host process, or one container from another. The token is the only gate, and every process in the container can read it. The default host tool set also includes `service`, which gives the container control of host systemd units. The report's claims that the "mic+speaker" threat row "disappears" and that the broker is a "choke point" deciding "which container, which project" are therefore overstated.
The options ladder also favours option 0 unfairly: "Dev-time: zero" counts acceptance as if it were implementation. Section 4 builds on a Wyoming premise that the Home Assistant Android docs do not support, and it leaves out VoiceMode's own mobile-client path.
Verdict: **Revise**.

## Inline fixes applied

These fixes are minor, factual and non-structural, so I made them directly in the report:

- BLUF and the section 1 NOTE: the concurrency bug was called "maintainer-acknowledged". The parallel fork report says #521, #522 and PR #523 have received no maintainer response. The wording now says so.
- BLUF: removed "at the cost of losing the container-local `converser-io` write-scoping trick". Section 1's body says `converser-io` "keeps running regardless", so the BLUF contradicted it.
- Section 1 NOTE: added links to #521, #522 and #523 on first mention (convention: direct links).
- Section 3 Pipecat: `pipecat-client-android-transports` is not "Daily-backed". It ships Daily, Small WebRTC, OpenAI Realtime WebRTC and Gemini Live transports (verified against the repo README). This matters because Small WebRTC is self-hostable and needs no vendor.

## Section-by-Section Findings

### BLUF

- **F1 [blocking]** The BLUF says `voicemode serve` has "Tailscale/IP-allowlist and bearer-token auth". This reads as if it were on by default, and it is not.
  `cli.py:2118-2150` and `config.py:1645-1664` show the defaults: `allow_local=True` (`LOCAL_CIDRS`: `127.0.0.0/8`, `10/8`, `172.16/12`, `192.168/16`, `::1`), Tailscale off, Anthropic off, no token, no secret.
  Plain `voicemode serve` computes `has_security == False`: loopback-only binding is its only protection.
  The BLUF should say that token auth is opt-in and is the only control that actually discriminates in the container case (see F3).

### Section 1: Split architectures

- **F2 [non-blocking]** The allowlist description ("covering local, Tailscale (`100.64.0.0/10`), and Anthropic CIDRs") reads as one default set. Tailscale and Anthropic are opt-in flags (`--allow-tailscale`, `--allow-anthropic`), and "local" includes all of RFC1918.
  This matters with any `--host 0.0.0.0` bind: every LAN device on those ranges is admitted by IP, which repeats the firewalld WARN from the conversationalist report.
- **F3 [blocking]** Answer to question 1: **yes, a `pasta:-T` connection appears as `127.0.0.1`.**
  Empirical check on this host: a Python `http.server` bound to `127.0.0.1:38765` logged peer `127.0.0.1` for a host `curl`, and `127.0.0.1` again for `podman run --rm --network pasta:-T,38765 node:24-bookworm curl http://127.0.0.1:38765/`.
  `IPAllowlistMiddleware` decides on the direct TCP peer (`serve_middleware.py:get_client_ip`, which ignores X-Forwarded-For without `--trust-proxy`). So the loopback allowlist admits:
  - every process in every container given that `-T` forward;
  - every host process of every UID (TCP loopback has no UID check, unlike the pulse socket's `srw-rw-rw-`, which is at least file-permissioned).

  The IP layer is therefore useless for separating container from host or container A from container B.
  `TokenAuthMiddleware` is the only real gate, and it takes a single token per `serve` process.
  Consequences the report must state:
  1. The token sits in the container's `--mcp-config` file or env, readable by every same-UID process in the container. Within a container, the token grants exactly what the pulse socket grants: any co-located agent can use it.
  2. Separating projects requires one `serve` process per container, each with its own port and token. That is the same topology the fork report already recommends for #521 (fork report section 3, "one `serve` process per active converser, never shared"). The two reports converge on it, and this report should say so.
  3. Without `--token`, any host process, including a browser-driven DNS-rebinding page (the middleware does no Host-header validation; I did not verify whether FastMCP's transport does), can drive the mic.

  The unverified-claims bullet ("whether `TokenAuthMiddleware`/`IPAllowlistMiddleware` is sufficient defense-in-depth") can be resolved now: the IP layer contributes nothing here, and the token is a shared secret with container-wide visibility.
  Minor: the token comparison is a plain `!=` (not `hmac.compare_digest`). The timing risk over loopback is negligible, but worth one line.
- **F4 [blocking]** The report says `VOICEMODE_TOOLS_ENABLED=converse` and `--strict-mcp-config` "still bound the tool set offered". In the host-serve world this is wrong in both halves.
  `--strict-mcp-config` is a client-side restriction on the launcher's own Claude session. Any in-container process can POST raw MCP JSON-RPC to the forwarded port and call whatever the server registers.
  What the server registers is set by `VOICEMODE_TOOLS_ENABLED` **in the host `serve` process's environment**. The default with nothing set is `{"converse", "service"}` (`tools/__init__.py:117-121`).
  `service` exposes `start`/`stop`/`restart`/`enable`/`disable`/`logs` for the host's `whisper`, `kokoro` and `voicemode` units. That is new container-to-host control that the in-container design never grants.
  It also chains with a default VoiceMode setting: `STT_BASE_URLS` defaults to `http://127.0.0.1:2022/v1,https://api.openai.com/v1` (`config.py:777-778`). An in-container attacker can call `service("whisper","stop")` and then `converse(...)`, and host mic audio fails over to OpenAI if the host env has an API key.
  Required mitigations: host `serve` runs with `VOICEMODE_TOOLS_ENABLED=converse` and with `VOICEMODE_STT_BASE_URLS`/`VOICEMODE_TTS_BASE_URLS` pinned to the loopback endpoints only.
- **F5 [non-blocking]** gRPC, D-Bus and the Unix-socket analysis are sound.
  One correction: in the Unix-socket option, "`label=disable` ... disappear[s]" only if SELinux permits `connectto` on the broker socket. The conversationalist report's own finding is that a bind-mounted host socket fails `EACCES` under `container_t` without `label=disable`.
  A host-created broker socket has the same `unconfined_t` peer problem, so option 1 needs either `label=disable` again or a custom SELinux policy/label (for example, the broker runs as `container_t` or the socket's context is set).
  Only the TCP options (2, 3) genuinely avoid `label=disable`. Options 1 and 3 are graded on this in the ladder, so this changes option 1's "Best transport" security cell.

### Section 2: Security gain versus the current design

- **F6 [blocking]** Answer to question 2. What the container loses under a broker:
  - its file descriptor to the pulse socket (raw PCM capture, playback, and pulse's module-loading and control surface, which the report does not mention and which is itself a larger attack surface than audio I/O);
  - `label=disable` (a real, whole-container SELinux gain; in the TCP options only, see F5);
  - the in-image PortAudio/ALSA/`libpulse` stack.

  What it keeps:
  - on-demand mic capture as text: `converse` with `disable_silence_detection=true` and `listen_duration_max` (default 120s, caller-settable) is ambient transcription of the room;
  - arbitrary TTS through the speaker;
  - under the default tool set, host service control (F4).

  So the "every in-container process gains mic+speaker access" row does not disappear. It degrades to "every in-container process can transcribe the room and speak", and the likelihood stays High because the token is container-wide (F3).
  The genuine gains are narrower but real: no raw audio, no pulse control protocol, and SELinux restored. The section should state it that way.
  The "single host-owned choke point ... (which container, which project, whose voice)" claim should be qualified. With `voicemode serve` the decision is "does the caller hold this process's token". Per-project decisions come only from per-container processes, and nothing in `serve` identifies "whose voice".
- **F7 [non-blocking]** The section is missing a gain that favours option 2 in the ladder.
  The conch is a kernel `flock` on `~/.voicemode/conch` (`conch.py:133`). The accepted proposal gives each project its own `voicemode-state` directory, so two containers' conversers have **no** shared conch and can talk over each other on the one host mic and speaker.
  Per-container host `serve` processes that share the host's `~/.voicemode` coordinate through a cross-process flock. #521 concerns concurrency inside one process, not across processes.
  So option 2 as per-container `serve` gains cross-project turn-taking that option 0 lacks. This needs a light empirical check, but the source supports it.

### Section 3: Existing building blocks

- **F8 [blocking]** Home Assistant Companion as a "Wyoming-speaking satellite" is not supported by the source the report cites.
  The HA "Assist on Android" docs (home-assistant.io/voice_control/android/) do not mention Wyoming. The app runs Assist against the user's Home Assistant instance, and Wyoming is the protocol HA uses to reach satellites and services, not what the phone app speaks.
  The wake-word details are roughly right: microWakeWord on device, "Okay Nabu"/"Hey Jarvis"/"Hey Mycroft", works when locked, noticeable battery cost, requires Companion 2026.2.3 or later and Assist as the default assistant app.
  The docs I read do not list the "battery-optimization exemption, lock-screen display" requirements; mark them as unverified or drop them.
  This premise carries weight in section 4 (see F11).
- **F9 [non-blocking]** Wyoming: "no authentication or encryption, by design... trusted network" is verified verbatim against the `OHF-Voice/wyoming` README.
  `wyoming-satellite`: the repo README now carries "no longer maintained as it has been replaced by Linux Voice Assistant that uses the ESPHome protocol". The unverified-claims bullet on this can be marked verified and removed.
- **F10 [non-blocking]** Pipecat: the "five pluggable transports" list (including `moq-transport`) does not match the README, which lists Daily, FastAPI Websocket, LiveKit, SmallWebRTC, Vonage, WebSocket Server, WhatsApp and Local.
  Either cite the source for the five-item list or use the README's.
  LiveKit: the VM-353 removal is confirmed (`CHANGELOG.md:669-672`, 8.0.0).
  Remote Control: outbound HTTPS/443 only, no inbound ports, `AskUserQuestion` and permission prompts kept open until answered. All verified against the docs page.

### Section 4: Android extension point

- **F11 [blocking]** The section omits VoiceMode's own mobile path, the most directly relevant prior art.
  The source clone ships `.claude/skills/voicemode-connect/SKILL.md`: "VoiceMode Connect". Agents connect over MCP to `voicemode.dev`, and phone and web clients connect over WebSocket, with the same `converse` tool shape.
  Today it has an iOS app plus a web app, and the fork report quotes the maintainer (issue #546, 2026-09-27) on "iOS and Android chat / calls, Barge in" as near-term.
  The tradeoff is a cloud relay through a third-party service, a privacy and dependency cost that should be weighed. Still, "upstream will likely ship the Android client" is the single biggest input to whether building one is worth it, and the fork report treats this as its strongest roadmap finding.
  Section 4 should cover it and cross-reference the fork report instead of re-deriving it.
- **F12 [blocking]** The "Wyoming satellite on Android" and "HA app pattern reused directly" options both assume an Android Wyoming client exists (F8). The report does not name a maintained Android app that speaks Wyoming to an arbitrary endpoint.
  Reframe as follows: the HA pattern proves that wake word plus satellite on Android is feasible. Reusing it means either routing through a real HA instance (the last option, which stays valid) or writing a Wyoming client.
  The first option as written should be dropped or merged into the last one.
- **F13 [non-blocking]** The PWA-over-Tailscale option is sound. Note the interaction with F2: `--allow-tailscale` admits the whole `100.64.0.0/10`, which is every node on the tailnet (including shared-in nodes), so a token is still required.
  The PWA also needs a secure context (HTTPS) for `getUserMedia`, which means Tailscale Serve/HTTPS certificates, not plain `http://100.x`.
- **F14 [non-blocking]** Remote Control: "no mic input" is accurate for the protocol. The phone's OS keyboard dictation into the Claude app text field is a zero-build voice-in path, with no voice out. Worth one line as the true cheapest rung.

### Section 5: Options ladder

- **F15 [blocking]** Answer to question 4: option 0 is not clearly the most incremental baseline, and the table does not weigh it fairly.
  - "Dev-time: Zero (already accepted)" confuses accepted with built. The proposal's audio work is still ahead: Phase 0 gates (a) pulse device and (g) Wayland under SELinux Enforcing, Phase 1 `install.sh` steps 1-2 (apt audio packages, `asound.conf`), the pulse mount, and `label=disable` plus its audit rationale.
  - Option 2 skips all of that. The launcher, hooks and `converser-io` (Phases 2-3) are identical in both.
  - Option 2 adds:
    - one host `serve` per container, on its own port with its own token (VoiceMode already ships a `service voicemode enable` systemd unit, which would need a per-project instance template);
    - `VOICEMODE_TOOLS_ENABLED=converse` and pinned STT/TTS URLs on the host (F4);
    - one more `-T` port in the same `runArgs` line the proposal already adds.
  - The concurrency bug does not bite in that shape: the proposal has one converser per container, and only the converser calls `converse`, so each `serve` process has exactly one MCP client. The table's "caps it at one client" is true but, for this design, not a limit. The fork report's section 3 already reaches this conclusion, so the two reports overlap here and should cross-reference, not diverge.
  - Option 2's residual costs:
    - host-side process lifecycle per project, which lace does not orchestrate today;
    - a newer, less-reviewed code path (`serve`) than stdio;
    - the in-container launcher depends on a host service being up.

  Fair conclusion: option 2 as per-container `serve` is a credible v0 alternative, arguably simpler than option 0 in the container, and strictly better on SELinux and cross-project turn-taking (F7).
  Option 0 wins only on "no host orchestration" and "already reviewed".
  The report should either rank them honestly as near-peers or make the case that host orchestration outweighs dropping `label=disable`. It should also recommend reshaping the proposal's Phase 0/1 behind the option-2 experiment's outcome, not running the experiment "in parallel" with v0 unchanged.
- **F16 [non-blocking]** Option 1's "Best transport ... no `label=disable`" cell is wrong per F5. Option 3's "Best: purpose-built, minimal surface" should note that it inherits F3's loopback-peer problem when carried over `pasta:-T`.
  Options 3 and 4 largely duplicate fork-report options (d) and (e). A one-line cross-reference with the fork report's 15-25 person-day estimate for (d) would replace the unsourced "1-2 weeks".

### Section 6: Recommendation and smallest experiment

- **F17 [blocking]** The experiment has three problems.
  - It says to add `pasta:-T,8765` "alongside its whisper/Kokoro forwards" in weftwise's `runArgs`, but no weftwise `devcontainer.json` has a `--network pasta` entry today. Those forwards exist only in the unimplemented proposal.
  - Adding `--network` changes the container, so "unmodified container" is wrong, and the change hits the proposal's own Phase 0 gate (c) on lace ingress under a custom `--network`.
  - The cheaper, truly zero-change experiment: `voicemode serve --token T` on the host with `VOICEMODE_TOOLS_ENABLED=converse`, then a throwaway `podman run --rm --network pasta:-T,8765 <image-with-claude-or-voicemode>` running `voicemode mcp-bridge http://127.0.0.1:8765/mcp --token T` or `claude mcp add --transport http ... --header "Authorization: Bearer T"`, then one `converse()`.

  Add these to the success criteria:
  - a raw `curl` MCP `tools/list` from the container without the token returns 401;
  - with the token, `tools/list` shows only `converse`;
  - two concurrent per-container `serve` processes serialize on the shared conch (F7).

  The stated reading of a failure ("Failure at the token-auth or allowlist layer signals ... hardening") misreads what the experiment can show. The allowlist cannot fail, since everything arrives as loopback (F3).

### Unverified claims and Links

- **F18 [non-blocking]** Resolve or retire the following:
  - the `wyoming-satellite` bullet (verified, F9);
  - the middleware-sufficiency bullet (answered by F3/F4);
  - the HA Companion bullet (now "does not speak Wyoming per the docs", F8).

  Add as unverified:
  - whether FastMCP's streamable-HTTP transport validates `Host`/`Origin` (DNS-rebinding exposure without a token);
  - the SELinux `connectto` behaviour for a host-created broker socket (F5).

### Conventions

- **F19 [non-blocking]** The BLUF runs to six dense lines, and line 16 alone is 650+ characters with several clauses. Trim it to the decision and the key caveat.
  There are 29 semicolons across the doc, where the convention asks for sparing use. The heaviest are in sections 1, 2 and 5; several can become periods.
  There are no em-dashes. Callout attribution format is correct. Frontmatter is valid.

## Verdict

**Revise.**
The survey value is real, but the report's two load-bearing conclusions (the size of the security gain, and option 0 as the obviously right baseline) rest on an access-control model that the source and a direct empirical test contradict, and on an unfair dev-time comparison.
The Android section needs its Wyoming premise corrected, and it needs the VoiceMode Connect / upstream-mobile path, which is the most relevant prior art.

## Action Items

1. [blocking] State in the BLUF and section 1 that `serve`'s auth defaults to "loopback + RFC1918 by IP, no token", and that `--token` is the only discriminating control (F1, F2).
2. [blocking] Add the empirical finding that `pasta:-T` traffic arrives as `127.0.0.1`. State that the IP allowlist therefore admits every forwarded container and every host process. State that the token is readable by every process in the container, and that per-project isolation requires one `serve` process and token per container (F3).
3. [blocking] Correct the tool-scoping claim. `--strict-mcp-config` does not constrain raw HTTP callers. The host `serve` must set `VOICEMODE_TOOLS_ENABLED=converse`, because the default exposes `service`. Pin the STT/TTS base URLs so that `service stop whisper` plus `converse` cannot fail host mic audio over to OpenAI (F4).
4. [blocking] Rewrite the security gain in section 2 as "loses raw audio, the pulse control surface, and `label=disable` (TCP options only); keeps room transcription and TTS". Qualify the "choke point" claim (F6). Fix the `label=disable` claim for the Unix-socket option (F5, F16).
5. [blocking] Correct the HA Companion "Wyoming satellite" claim and drop or merge the "Wyoming satellite on Android" option (F8, F12).
6. [blocking] Add VoiceMode Connect and the upstream iOS/Android roadmap to section 4, with its cloud-relay tradeoff, cross-referencing the fork report (F11).
7. [blocking] Rebalance the options ladder. Option 0's dev time is its remaining Phases 0-1 audio work, not zero. Present option 2 as per-container `serve`, under which #521 does not apply with one converser per container. Note the cross-container conch gain. Reconcile explicitly with the fork report's option (a) and its "one `serve` per converser" conclusion (F7, F15).
8. [blocking] Fix the smallest experiment. weftwise has no existing `pasta` forwards, and adding one modifies the container. Use a throwaway `podman run --network pasta:-T,8765` instead. Add the 401 / `tools/list` / cross-process conch checks, and drop the "allowlist failure" reading (F17).
9. [non-blocking] Align the Pipecat transport list with the README (F10). Add the PWA HTTPS requirement and the tailnet-wide scope of `--allow-tailscale` (F13). Add the OS-dictation-into-Remote-Control rung (F14).
10. [non-blocking] Update the unverified-claims list per F18, and trim the BLUF and semicolons per F19.

## Questions for the author / user

1. Which v0 baseline should the report recommend?
   - (a) Keep option 0 and treat the broker as a later retrofit.
   - (b) Switch v0 to per-container host `serve`, removing Phase 1's audio stack and `label=disable` from the proposal, gated on the fixed smallest experiment.
   - (c) Present both as near-peers and let the experiment decide.
2. For the Android extension point, is a cloud relay (VoiceMode Connect via `voicemode.dev`) acceptable in principle, or is self-hosted-only (Tailscale PWA or Pipecat Small WebRTC) a hard requirement?
3. Should per-container `serve` processes share one host `~/.voicemode` (a cross-project conch, shared logs and config) or use per-project `VOICEMODE_HOME`s (isolation, no cross-project turn-taking)?
