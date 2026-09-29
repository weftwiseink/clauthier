---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-28T13:00:00-07:00
task_list: voice/converser-lace-feature
type: devlog
state: live
status: done
tags: [oversee, voice, converser, research, artifact]
---

# converser directions arc: oversee devlog

> NOTE(mjr/converser-migration): Moved from lace cdocs to clauthier cdocs on 2026-09-29; clauthier is the code target.

> BLUF: Research arc vetting the accepted `converser` proposal and alternatives: three parallel reports (opus vetting deep-dive; host-side audio broker split; VoiceMode fork/rewrite complexity), each reviewed, then an opus-built decision artifact with SVG diagrams and tables.

## User direction (2026-09-28)

- Opus deep-dive report vetting the converser options; find what's missing.
- Parallel exploratory report: split design so audio services are exposed to the container more narrowly via an intermediate host-side app/tool; future extension point for an Android remote-control app.
- Separate report: complexity of forking or rolling our own VoiceMode/audio stack for that modularity; how sophisticated is VoiceMode.
- User unsure why converser permissions matter; suggests a separate OS user in the devcontainer for the converser.
- Final: comprehensive high-level artifact (opus; rich SVG diagrams; 140ch width; rich tables; details collapsed in `<details>`) on difficulty, flexibility, long-term viability.

## Plan

1. Parallel: R1 `2026-09-28-converser-options-vetting.md` (opus), R2 `2026-09-28-host-audio-broker-split.md` (sonnet), R3 `2026-09-28-voicemode-fork-complexity.md` (sonnet). Disjoint footprints.
2. Opus review each; revise to accept.
3. Opus artifact.

## Log

- Dispatched R1, R2, R3 in parallel.
- R3 (fork complexity) returned: VoiceMode ~44K LOC, 1865 tests, bus factor ~1; ships `voicemode serve --transport streamable-http` (host MCP broker may exist upstream, no fork) with open conch concurrency bug #521/#522 (PR #523 unmerged). Forwarded serve finding to R2; dispatched R3 review.
- R2 (broker split) returned: voicemode serve w/ Tailscale/IP-allowlist/token auth as rung 3; Wyoming + HA Companion as Android prior art; Remote Control has no mic input. Recommends ship proposal v0 + half-day serve-over-pasta experiment. Dispatched R2 review.
- R1 (opus vetting) returned: label=disable already applied by devcontainer CLI to all podman containers (claim false); jif audio already works incl. monitor sources; 12s relay timeout infeasible; Stop-hook volume 50-150 wakes/h; pin socket file breaks on pipewire restart; separate OS user kills messaging. 12 amendments; amend, prototype hand-wired first. Dispatched R1 review.
- R3 review r1: revise. serve default loopback + pasta = 127.0.0.1 passes allowlist; 0.0.0.0 example opens 26 tools to RFC1918 unauth; single-client wedge via timeout-reconnect; PR #523 misread (no concurrency fix); host serve underplayed (drops pulse mount/label/audio pkgs; per-project conch gap). Resumed R3 author.
- R2 review r1: revise. serve default allowlist = loopback+RFC1918, no auth; pasta traffic = 127.0.0.1 (empirically verified) → token is the only gate, one serve+token per container; host serve exposes `service` (host systemd) + OpenAI STT fallback → VOICEMODE_TOOLS_ENABLED=converse + pin local URLs; HA Companion not Wyoming; missed VoiceMode Connect; ladder unfair to host serve; experiment should use throwaway container. (Vetting report 'disappearance' = my commit 716948f.) Resumed R2 author.
- R1 review r1: revise. Facts hold (label=disable universal, jif audio, latency, file-vs-dir mount verified). Blocking: F1 narrow 'any boundary' to local sockets (RC route unverified, spike); F2 separate-UID viable via own-child poster relay (removes forced-bypass converser); F3 amendment 5 would drop answers; F4 broker SELinux gain is zero, pulse-removal gain stronger; F4a reconcile first experiment with host serve. Resumed R1 author.
- R1 revised (4541 words): first experiment = host serve + unmodified container; separate-UID feasible via own-child relay, rejected for v0 on cost; RC-routed spike (o). Dispatched R1 round-2 review.
- R1 review r2: accept (non-blocking: presence-file writer/path; gate (n) token fallback; latency 'Floor' cell is a range).
- R3 revised (3800 words): loopback+token, #522 single-client wedge, #523 scope fixed, host serve first-class. Dispatched R3 round-2 review.
- R3 review r2: revise (one blocking: decision point 1 must align with accepted vetting report's host-serve-first). Reviewer fixed tool list (default serve = converse+service), #522 wording, DP2. Resumed R3 author.
- R2 revised (3799 words): token-only gate, tool scoping, honest security gain, HA/Wyoming fixes, VoiceMode Connect, fair ladder aligned with fork (a), throwaway-container experiment. Dispatched R2 round-2 review.
- R2 review r2: accept. Reviewer fixed DP3: conch path hardcoded ~/.voicemode/conch (all host serve processes share it automatically); recommend per-project VOICEMODE_BASE_DIR + shared conch.
- R3 round-3 fix returned (3847 words): DP1 aligned to host serve first. Dispatched round-3 check.
- R3 review r3: accept (reviewer fixed residual 'deliberately shared conch' wording). All three reports accepted. Dispatching opus artifact build.
- Opus artifact built and published: https://claude.ai/artifact/PmEGPBue14yvxaBni6bvCd (source `cdocs/reports/2026-09-28-converser-directions-assets/index.html`). Overseer read full file before publish.

## Handoff

### Completed
- Three reports accepted: options vetting (r2), host audio broker split (r2), VoiceMode fork complexity (r3).
- Decision artifact published.

### Decisions Made
- Cross-report consensus: first experiment = host `voicemode serve` (loopback, one process + token per container, `VOICEMODE_TOOLS_ENABLED=converse`, loopback STT/TTS URLs, per-project `VOICEMODE_BASE_DIR`, shared conch) against an unmodified container via `pasta:-T,8765`; in-container stack = fallback; tier-2 question redirect for v0; fork/own only on tripwires.
- `label=disable` is universal (devcontainer CLI), not a differentiator.
- Separate OS user feasible via own-child relay, rejected for v0 on cost.

### Open Todos
- User: 10 open decisions listed in the artifact.
- Accepted proposal needs amending to the host-serve direction before `/cdocs:iterate`.
