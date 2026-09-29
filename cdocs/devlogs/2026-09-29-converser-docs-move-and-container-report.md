---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-29T16:00:00-07:00
task_list: voice/converser-lace-feature
type: devlog
state: live
status: done
tags: [voice, converser, migration, containers, rfp]
---

# converser: docs move, container report, RFPs

> BLUF: Moved the converser design record from lace to clauthier cdocs, commissioned an opus report on containerizing the host voice server (recommends a hybrid), and stubbed two RFPs from deferred user direction.

## User direction (2026-09-29)

- Move all cdocs for this work out of lace into clauthier, the eventual code target.
- Have an opus consider containerizing the server with podman to simplify the messy host setup.
- RFP the deferred items (typed-message style seeding, voice fingerprinting, provenance/speaker attribution) plus iterative compose: a buffer/dashboard inbox where response preparation is iterative with incremental (re)compilation previews.

## Work

- **Move** (sonnet): 28 files; clauthier `15b42ae`, lace `197c588`. Lace-specific references made explicit ("lace repo:"); clauthier doc references relativized; devlogs carry a move NOTE.
  Republished both artifacts from their new paths (same URLs); design map's "record lives in lace" caveat dropped (`b848ccd`).
- **Container report** (opus): `cdocs/reports/2026-09-29-containerized-voice-server.md` (`1ce2a52`), status `review_ready`, unreviewed.
  Recommends hybrid: whisper + Kokoro as rootless Quadlet containers on `127.0.0.1` (CUDA via existing `/etc/cdi/nvidia.yaml`), `serve` stays on host.
  Against containerizing `serve`: reintroduces pulse mount, and the conch treats an invisible holder PID as dead (`conch.py:348,388-440`) unless `--pid=host`.
  Side finding: lace containers publish their ports on `0.0.0.0` while the firewalld zone opens 1025-65535, plausibly LAN-reachable today.
- **RFPs** (`0c3020e`): `2026-09-29-converser-iterative-compose-buffer.md` (includes typed-message style seeding), `2026-09-29-converser-audio-input-trust.md`.
