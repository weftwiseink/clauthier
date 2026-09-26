---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-26T10:00:00-07:00
task_list: cdocs/connectome-research
type: devlog
state: live
status: wip
tags: [research, oversee, memory, connectome, anima]
---

# Connectome and long-lived context research arc

> BLUF: `/oversee` research arc: three parallel research reports (connectome deep dive, memory-system landscape, cdocs-as-memory), each reviewed, then a synthesis report and a published Artifact with bespoke SVGs.

## Objective

User asked for rigorous research on Anima Labs' connectome and other long-lived context management systems, weighed for fit in a productivity/coding setting, with a final Artifact comparing connectome against cdocs' log-centric approach.

## Plan

1. Parallel research dispatch (A: connectome, B: landscape, C: cdocs characterization).
2. Reviewer pass on each; revise to accept.
3. Synthesis report (fit analysis, adoption options).
4. Artifact with bespoke SVGs.

## Adaptation note

`/oversee` is proposal-centric; this arc's units are reports.
Terminal contract per unit: report frontmatter `status: review_ready` plus a reviewer `accept` verdict.
Arc-state: `.claude/oversee/2026-09-26-connectome-context-research.json`.

## Log

- No prior connectome notes found in repo or local session history (user recalled earlier work; likely outside this checkout). Starting from primary sources.
- Dispatched A (connectome, opus), B (landscape, opus), C (cdocs-as-memory, sonnet) in parallel; footprints disjoint (one file each).
- C (cdocs-as-memory) authored 80e2c3a; review r1 REVISE (6 blocking: mechanism count, cold-start framing, weftwise size mostly _media, hook scope, review lifecycle, consolidation undersold); revised 2d4448b; r2 review dispatched.
- B (landscape) authored 014c8e9; review r1 REVISE (70c772c): convergence thesis overstated (format converges, authorship doesn't), grep-vs-Mem0 over-weighted, "identity is niche" contradicted by OpenClaw/SOUL.md, bad Cursor cite. Reviewer caught pro-cdocs tilt; revision dispatched with explicit anti-tilt brief.
- A (connectome) authored 873ec4d: 5-lib stack (Chronicle, Membrane, context-manager, agent-framework, connectome-host); lossless branchable event archive + per-turn compiled view with first-person, no-hindsight summaries; cache-aware solver. Review r1 dispatched with code-level verification.
