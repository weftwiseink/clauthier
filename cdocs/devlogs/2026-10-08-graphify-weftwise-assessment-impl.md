---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T14:04:00-07:00
task_list: cdocs/graphify-weftwise-assessment
type: devlog
state: live
status: wip
part_of: cdocs/devlogs/2026-10-08-graphify-weftwise-assessment.md
tags: [graphify, performance, evaluation]
---

# Graphify Weftwise Assessment, Implementation: Devlog

> BLUF: Implementer sub-devlog (iterate round 1, all phases) for `cdocs/proposals/2026-10-08-graphify-weftwise-assessment.md`.

## Objective

Execute the three phases of `cdocs/proposals/2026-10-08-graphify-weftwise-assessment.md`: weftwise scope fix, usefulness judging against a grep ground truth, runtime matrix plus candidates, ending in `cdocs/reports/2026-10-08-graphify-weftwise-assessment.md`.

## Scratchpoint

- next_steps: Phase 1 done. Phase 2: await sonnet ground truth, then judge 14 questions (graphify outputs already captured blind in container `/tmp/gfy-assess/q-clean`, `q-pre`). Then Phase 3 matrix.
- graphify_base_query:
- important_files: proposal above; `plugins/cdocs/bin/cdocs-graphify`; weftwise `.graphifyignore`; container scratch `/tmp/gfy-assess/`
- callouts:
  - decision: container scratch root is `/tmp/gfy-assess/` (wrapper copy, saved graphs, scratch `GRAPHIFY_OUT`s); all removed at the end.
  - todo: maintainer worktree state recorded below (Verification › Collateral); re-check at the end.
  - decision: `*.scss.d.ts` added as the one non-markdown ignore line (inventory-proven: 28 tracked typed-scss-modules outputs, 84 nodes, 0 edges to other files).
  - finding: empty-dir builds carry 39 more `imports_from` edges (bare `loro-repo` specifier to the `ref_loro_repo` stub) than updates from the main out dir's cache; node sets equal. Floor counts must come from empty-dir builds.
  - decision: Phase 2 commands fixed before ground truth returned, run blind (status lines only), retries applied mechanically per the skill.

## Plan

1. Phase 1: record state, `gfy-assess` worktree, pre-clean baseline (full build, structural post-edit x3), inventory, `.graphifyignore` commit, main rebuild, move `gfy-assess`, counts, self-heal check.
2. Phase 2: sonnet sampler, sonnet grep ground truth, run on cleaned + pre-clean, judge.
3. Phase 3: runtime matrix, candidates, prototypes, report, floor, cleanup.

## Testing Approach

The proposal's Test Plan: per-prefix zero checks, relation counts, timing variance flags, identity and spot checks per candidate, fidelity diff, cleanup checks, and the floor block run before handoff.

## Implementation Notes

### Phase 1: baseline and scope fix

Setup: `gfy-assess` detached at `5e446a84`; container scratch `/tmp/gfy-assess/` holds the wrapper copy (sha1 `107b0d5c` = clauthier main), `preclean-graph.json`, `preclean-main/` (copy source for pre-clean wrapper runs), `gcount.py` (counts), `gattr.py` (relation attribution), `tm.sh` (wall time + 1-min load to `timings.tsv`), `edit.patch` (structural: `arrow.ts` imports `snap` from `./geometry` and adds `gfyProbeSnap` calling it), `body.patch` (body-only: `* 1` in `arrowMeetsMinLength`).

Pre-clean baseline (ignore `/cdocs/` only, 20 workers, load 1.1-3.8):

| case | runs (s) | median | nodes/edges |
|---|---|---|---|
| raw full build, empty out dir | 11.31, 11.33, 11.39 | 11.33 | 16,129 / 31,311 (all 3) |
| wrapper post-edit (structural) | 14.61, 14.57, 14.49 | 14.57 | 16,130 / 31,314 |
| wrapper revert (structural) | 14.65, 14.67, 14.77 | 14.67 | |
| wrapper first query (copy + update) | 14.92 | | |
| wrapper stamp hit | 0.85 | | |

Inventory (pre-clean graph, `built_at_commit` `ab8edd6e`): matches the proposal's table. Non-markdown cruft search (dist/build/generated/vendor/fixtures/lockfiles/`.d.ts`): only `*.scss.d.ts` qualifies (see callout); `package.json`/`tsconfig*` and `.mcp.json` (3 nodes) stay.

`.graphifyignore` committed on weftwise main as `2791713d` (`/cdocs/`, `/_archive/`, `/docs/references/`, `*.scss.d.ts`).
Main rebuild, plain `update`, explicit `GRAPHIFY_OUT=/var/cache/graphify-weftwise`, no `--force`: `pruned 6398 node(s) from 323 newly-ignored file(s)`, 16,129 -> 9,731 nodes, 31,272 -> 25,121 edges, 362 communities. 6,398 = 6,058 + 256 + 84 exactly.
Per-prefix zeros pass; md nodes 6,913 -> 654 (matches the steering-log tally).

Relation counts, pre-clean main -> cleaned main: imports 6534->6527, imports_from 3735->3725, calls 4760->4741, re_exports 1345=, dynamic_import 36=, references 450->410, method 1246->1244, implements 31=.
Every drop equals the count of edges touching a removed source in the pre-clean graph (`gattr.py`: imports 7, imports_from 10, calls 19, references 40, method 2): archive code files plus the scss types' internal `references`. No edge between kept code was lost.

`gfy-assess` moved to `checkout --detach main` (`2791713d`).
Self-heal check: its index was the pre-clean graph with a matching stamp (`5e446a84 8b137891...`, stamp hit confirmed at the old commit); after the checkout, the wrapper ran `update`: `pruned 6398 node(s) from 323 newly-ignored file(s)`, 9,731 nodes, no `--force` (12.21 s). Maintainer worktrees heal the same way once they merge main.

## Changes Made

| File | Description |
|------|-------------|

## Verification

### Collateral: maintainer worktrees before (2026-10-08T14:03)

```
bocsync-bailout 44d92d40170fe7c98d35f899b4fd3f04f26c68a7 7
df-to-mount f8ff8ac33a9c8ceb693e7a2e5aee480565e028b4 0
dogfood-sept 558bdb180f87e7dde7e1263c4403e280bfa0bddb 55
logical-core a14919805d3833ac173a2806eb2db565efc37369 0
loro-branching 1ad160dbcc21c48bf082262d3bca0b3fdaede23a 0
loro-repo-package bcb0711702c22a97710b75f0d4abd4570dd09715 1
main graph.json mtime 2026-10-08 10:46:05.603 -0700, .graphify_root /workspaces/weftwise/main
```
