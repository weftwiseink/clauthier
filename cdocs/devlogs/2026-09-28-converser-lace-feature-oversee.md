---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-28T09:00:00-07:00
task_list: voice/converser-lace-feature
type: devlog
state: live
status: done
tags: [oversee, voice, devcontainer_features, converser, security]
---

# converser lace feature: oversee devlog

> NOTE(mjr/converser-migration): Moved from lace cdocs to clauthier cdocs on 2026-09-29; clauthier is the code target.

> BLUF: Overseer devlog for proposing a `converser` lace devcontainer feature: an in-container VoiceMode conversationalist that bridges voice to that project's `/oversee` sessions. Research arc lives in clauthier `cdocs/reports/2026-09-2{6,7}-*` (task_list `cdocs/audio-interaction`).

## User direction (2026-09-28)

- Name: `converser` (was "conversationalist").
- All-or-nothing: when the feature is enabled, converser is fully active (no presence gating); on/off settings may come later.
- Bundle the setup as a lace feature.
- Asked: complexity/setup cost of the firewalld rules, and the security risks overall.

## Inputs

- clauthier reports: `2026-09-27-containerized-conversationalist-and-question-surface.md` (container recipe, tier-3 hook, firewall WARN), `2026-09-27-conversationalist-bridge-design-questions.md`, `2026-09-27-voicemode-deep-dive.md`, `2026-09-27-claude-code-inter-session-messaging.md`.
- Precedent (lace repo): `cdocs/proposals/2026-09-15-graphify-lace-devcontainer-feature.md`.

## Log

- Dispatched sonnet proposer for `cdocs/proposals/2026-09-28-converser-lace-feature.md`.
- Proposer returned with an in-loop round-1 review (revise: feature spec supports securityOpt/mounts; pasta default -T none; crossSessionInbound scope; Stop-hook self-loop) already folded in. pasta -T forwarding verified live. 5408 words. Dispatched independent round-2 review.
- Review r2: revise. Blocking: Write(path) rules are no-ops (need Edit(//**) deny + ! exceptions, gate in Phase 0; workspace bind-mount → host code exec); AskUserQuestion reply-file return path missing + forgery threat row. Resumed proposer.
- Revision returned (3878 words): Edit(//**) deny + carve-outs, reply-file return path, 7 Phase 0 gates, mermaid, cuts. Dispatched round-3 review.
- Review r3: revise. ! carve-outs can't reach //-anchored rules; Edit(//**) = blanket deny. Recommended: drop file-write tools from converser; tiny converser-io MCP (ledger append, reply write) to fixed container-local paths. Tool list mismatch. Resumed proposer.
- Revision returned (3981 words): converser-io MCP (ledger_append, ledger_read, reply), no Edit/Write/Read. Dispatched round-4 review.
- Review r4: accept. Reviewer fixed Phase 2: `--tools` restricts built-ins only; `--tools ListAgents,SendMessage` + `ENABLE_TOOL_SEARCH=false` + exact tool-inventory check. Overseer set proposal `status: implementation_ready`.

## Handoff

### Completed
- `cdocs/proposals/2026-09-28-converser-lace-feature.md` accepted round 4 (~4060 words), `implementation_ready`.

### Decisions Made
- Networking: host STT/TTS bound to loopback, `--network pasta:-T,2022,-T,8880` (verified live); firewalld rich rules as fallback; `--map-host-loopback` rejected.
- Converser has no built-in file tools; `converser-io` MCP (ledger_append, ledger_read, reply) writes only to `/run/user/1000/converser/`.
- Hooks via container-local managed-settings drop-in; `crossSessionInbound: accept` only on the converser launcher; Stop hook skips headless `-p` and the converser itself.

### Open Todos
- Implementation starts with Phase 0 empirical gates (pulse device, socket wire format, pasta, tool inventory incl. claude.ai connector exposure, bypass→bypass delivery).
- OQs: automate host STT/TTS enable in `lace up`?; tune relay timeout (default 12s).
