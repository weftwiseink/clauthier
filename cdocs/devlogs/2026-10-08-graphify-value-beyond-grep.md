---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T15:53:00-07:00
task_list: cdocs/graphify-weftwise-assessment
type: devlog
state: live
status: wip
part_of: cdocs/devlogs/2026-10-08-graphify-weftwise-assessment.md
tags: [graphify, evaluation]
---

# Graphify Value Beyond Grep: Devlog

> BLUF: Phase 4 implementer sub-devlog for `cdocs/proposals/2026-10-08-graphify-weftwise-assessment.md`: two-arm (graph-assisted vs grep-only) sonnet runs on discovery tasks, blind opus judges, scenario map and `/cdocs:graphify` guidance in the report.
> In progress.

## Objective

Implement Phase 4 "Value beyond grep" of `cdocs/proposals/2026-10-08-graphify-weftwise-assessment.md`.
Maintainer intent: "the assessor should put more effort into verifying whether graphify could provide value beyond grep and in what scenarios."
Seek graphify's best case honestly, keep reach and efficiency apart, and write the "Value Beyond Grep" section of `cdocs/reports/2026-10-08-graphify-weftwise-assessment.md`.

## Scratchpoint

- next_steps: setup (worktree pair at `2791713d`, warm-up build, counts), feature inventory and card, pilot.
- graphify_base_query:
- important_files: proposal (Phase 4); report; `plugins/cdocs/bin/cdocs-graphify`; scratch `/tmp/gfy-value/` (container and host), `/tmp/gfy-arm-*` (host)
- callouts:
  - decision: container scratch root `/tmp/gfy-value/` (wrapper copy, scratch copy of the main graph as `-e GRAPHIFY_OUT`); removed at the end.

## Plan

1. Record collateral baseline (maintainer worktrees, `loro/`, main graph mtimes).
2. Worktree pair at `2791713d`: `srcpatch.py`, `.graphifyignore`, delete `cdocs/` and `_archive/`; warm the wrapper in the graph worktree; check 9,744 / 25,774.
3. Feature inventory and capability card; pilot graph arm on held-out Q5; fix the card.
4. Sonnet sampler (class names and shapes only); leak check (named entities, lexical traces); pre-investigation worktree pairs where needed.
5. Per task: both arms in parallel; `jq` transcript checks; blind opus judge.
6. Report section, scenario map, guidance, verdict updates.
7. Phase 4 floor; cleanup; `review_ready`.

## Testing Approach

The proposal's Phase 4 floor: graph counts, records present, two tasks re-judged blind, no collateral.
Transcript checks are mechanical (`jq` over subagent `.jsonl`).

## Implementation Notes

### Collateral baseline (2026-10-08T15:52-07:00)

```
bocsync-bailout 44d92d40170fe7c98d35f899b4fd3f04f26c68a7 7
df-to-mount f8ff8ac33a9c8ceb693e7a2e5aee480565e028b4 0
dogfood-sept 558bdb180f87e7dde7e1263c4403e280bfa0bddb 55
logical-core a14919805d3833ac173a2806eb2db565efc37369 0
loro-branching 1ad160dbcc21c48bf082262d3bca0b3fdaede23a 0
loro-repo-package bcb0711702c22a97710b75f0d4abd4570dd09715 1
loro 48198d48a0825b8792f8766721537fb8c793d0a5 0
/var/cache/graphify-weftwise/graph.json 2026-10-08 14:09:35.882274364 -0700
/var/cache/graphify-weftwise/.graphify_root 2026-10-08 14:09:36.365156753 -0700
no-graphify
```

Weftwise `main` at `2791713d`, clean.

## Changes Made

| File | Description |
|------|-------------|

## Verification
