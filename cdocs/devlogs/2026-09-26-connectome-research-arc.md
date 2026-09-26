---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-26T10:00:00-07:00
task_list: cdocs/connectome-research
type: devlog
state: live
status: done
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
- C accepted r2 (65cf3bf).
- B accepted r2 (fd252ab). A review r1 REVISE-light (41984da): maintenance is timer-driven not per-turn; /checkpoint doesn't branch (/undo,/restore do); temp-0 unsupported. Revision dispatched.
- A revised dc31da0 (timer-driven maintenance section, branching fixed, temp-0 removed); r2 review dispatched. Synthesis (D) dispatched in parallel.
- A accepted r2. Note: a concurrent session (audio-interaction arc, same worktree) swept our r2 review + devlog lines into its commit a2b9e3a; content intact. Subsequent briefs require explicit-path `git add`.
- D synthesis authored 373b211: different problems (one agent over lifetime vs many ephemeral agents over one project); overlap = verbatim notes/workspace ≈ cdocs corpus. Don't adopt runtime or no-hindsight self-summaries for coding recall; adopt archive/view discipline (supersedes + reviewed consolidation, capped live index, devlog→transcript links); identity value unmeasured → one bounded experiment (per-role working notes). Review r1 + artifact build dispatched in parallel.
- D review r1 REVISE (136ec2e: overlap inconsistent, asymmetric risks, Option 4 couldn't test identity, asymmetric falsifiers, Option 1 over-graded) → revised 983dd7b → r2 ACCEPT (9e6be38); overseer folded N1-N3 (content-vs-voice confound, same-role arms, S-vs-N falsifier).
- Artifact built (b40ba63, 10 bespoke SVGs); overseer read in full, added content-vs-voice caveat to Fig 10, published: https://claude.ai/artifact/6mdteEvHWFpv37x5NpnoRm

## Handoff

### Completed
- Four reports, each reviewer-accepted: connectome deep dive (r2), memory landscape (r2), cdocs-as-memory (r2), synthesis (r2).
- Illustrated Artifact published; linked from the synthesis report.

### Decisions Made
- Research arc run under `/oversee` with reports as units (terminal = reviewer accept).
- Reviewers explicitly briefed to check pro-cdocs tilt; two of four reports were materially corrected for it (landscape convergence thesis, synthesis risk symmetry + identity experiment design).

### Open Todos
- Ranked adoption options (synthesis §options): 1a distill pass, 1b `supersedes` links, 2 unpinned live index, 3 devlog→transcript links; 4 two-arm identity experiment should be scoped as an RFP with comparative falsifiers.
- Unverified: which fold solver each Anima resident runs; licensing on several Connectome repos; no independent eval of Connectome recall/drift.
