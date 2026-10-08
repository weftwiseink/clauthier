---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T14:04:00-07:00
task_list: cdocs/graphify-weftwise-assessment
type: devlog
state: live
status: review_ready
part_of: cdocs/devlogs/2026-10-08-graphify-weftwise-assessment.md
tags: [graphify, performance, evaluation]
---

# Graphify Weftwise Assessment, Implementation: Devlog

> BLUF: Implementer sub-devlog (iterate round 1, all phases) for `cdocs/proposals/2026-10-08-graphify-weftwise-assessment.md`.
> All three phases ran; the deliverable is `cdocs/reports/2026-10-08-graphify-weftwise-assessment.md` (`review_ready`), and the floor passes verbatim.
> Weftwise has one commit (`2791713d`, `.graphifyignore`), and all scratch is removed.
> Deviations: one implicit-`GRAPHIFY_OUT` call wrote `cache/last_query_stamp` into the main graph dir (graph untouched); the fresh-worktree row and the `--no-cluster` identity expectation did not hold (both findings).

## Objective

Execute the three phases of `cdocs/proposals/2026-10-08-graphify-weftwise-assessment.md`: weftwise scope fix, usefulness judging against a grep ground truth, runtime matrix plus candidates, ending in `cdocs/reports/2026-10-08-graphify-weftwise-assessment.md`.

## Scratchpoint

- next_steps: done; awaiting the loop's reviewer. Proposal stays `implementation_wip` (only the maintainer sets `implementation_accepted`).
- graphify_base_query:
- important_files: proposal above; `plugins/cdocs/bin/cdocs-graphify`; weftwise `.graphifyignore`; container scratch `/tmp/gfy-assess/`
- callouts:
  - decision: container scratch root is `/tmp/gfy-assess/` (wrapper copy, saved graphs, scratch `GRAPHIFY_OUT`s); all removed at the end.
  - todo: maintainer worktree state recorded below (Verification › Collateral); re-check at the end.
  - decision: `*.scss.d.ts` added as the one non-markdown ignore line (inventory-proven: 28 tracked typed-scss-modules outputs, 84 nodes, 0 edges to other files).
  - finding: empty-dir builds carry 39 more `imports_from` edges (bare `loro-repo` specifier to the `ref_loro_repo` stub) than updates from the main out dir's cache; node sets equal. Floor counts must come from empty-dir builds.
  - decision: Phase 2 commands fixed before ground truth returned, run blind (status lines only), retries applied mechanically per the skill.
  - deviation: one raw `graphify explain --help` (inspecting an exit code, ~14:10) ran without an explicit `GRAPHIFY_OUT`, so it wrote `/var/cache/graphify-weftwise/cache/last_query_stamp` (18 bytes, 14:10:23). `graph.json` (14:09:35) and `.graphify_root` (14:09:36) are unchanged since Phase 1, so no restore was needed.
  - finding: `--no-cluster` fails the identity check (raw extraction written); the proposal's expectation that it changes only community attributes was wrong for 0.9.61.
  - finding: the fresh-worktree row lands on "update with topology change" (11.9 s), not the expected about 9 s, because of the 39-edge build-path difference.
  - decision: candidate post-edit timings use raw `update` against a raw `update` baseline (11.14 s), not the wrapper (11.84 s), so the rows compare like with like.
  - decision: the JSON candidate is degenerate by inventory (`.mcp.json` only); one extra all-JSON-out build checks the keep-resolution-inputs assumption instead.

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

### Phase 2: usefulness

- Sampler (sonnet): 14 questions from 13 of the newest non-graphify devlogs (entity 3, blast 3 + Q14, flow 3, where 3, base-tagged Q12-Q14); all entities existence-checked.
  Dropped: Rust-side `loro` fork questions (code outside this repo).
- Ground truth (sonnet, grep/read only, before any graphify output was read): 61 commands, ~21k tokens; all premises ok.
- Graphify commands were fixed per kind before ground truth returned (entity `explain`, blast `affected`, flow `path`, where/base `query`) and run blind; retries applied mechanically: missing node -> file entity (Q1, Q7), ambiguous -> the id the question names (Q3, Q5), "No directed path" -> the tool's own `--undirected` hint (Q7-Q9).
- Tally (cleaned graph): hit 7 (Q1 Q2 Q3 Q6 Q11 Q13 Q14), partial 4 (Q4 Q5 Q9 Q10), miss 2 (Q8 Q12), misleading 1 (Q7). Output ~10.7k tokens over 30 commands.
- Pre-clean vs cleaned: entity/blast/path outputs identical up to ordering and the `ref_loro_repo` edge; `query` seeds lost both `_archive/` headings (Q13 `Persistence`, Q14 `5. Nested Liveblocks Rooms`); Q13 gained `activeBranchStorageKey()`.
  Q7's misleading undirected path exists only on the fresh-build lineage (it routes through the `ref_loro_repo` stub); the main-lineage graph returns no path.
- Remaining md seeds on the cleaned graph: `docs/worktree_development.md` heading (Q12, Q14), `.claude/commands/dogfood-wt.md` heading (Q14).

### Phase 3: runtime, candidates, prototypes

Full numbers are in the report; raw logs are archived at `<scratchpad>/gfy/container/gfy-assess-artifacts.tgz` (session scratch, not durable).
- Cleaned matrix: full 9.60 (9.57-9.66), wrapper post-edit 11.84 (11.74-11.87), raw post-edit 11.14, body-only 9.03, stamp hit 0.63, commit-only 0.54 (skip confirmed), fresh-worktree 11.88 (11.75-11.90), query/explain/path/affected 0.50/0.46/0.50/0.23. No row exceeded a 50% range.
- Candidates: md out -0.1 to -0.3 s, no verdict change; tests out 5.23 / 6.27 s, Q6 hit -> partial, Q7 misleading -> miss; output stages off 7.05 / 8.18 s, all from `--no-cluster`, which writes raw extraction (2,148 extra edges, no `built_at_commit`, no `norm_label`) and flips Q8 miss -> misleading; `MAX_WORKERS` 4/10/20 identical graphs, 20 fastest; `extract --code-only` 3.63 s post-edit on an extract-built index, -59 nodes / -114 code edges vs `update`, 10.03 s when started from an `update`-built index (manifests incompatible).
- Background refresh prototype (`cdocs-graphify-bg`): first query 0.47-0.56 s, 0.31 s during refresh, edit-to-fresh 11.27-11.55 s, stale miss of the edited entity on 3/3 cycles. `update` blocks on `.rebuild.lock` (CLI `block_on_lock=True`), so the prototype checks the lock file before launching.
- Kept-stamp prototype (`cdocs-graphify-ks`): fresh worktree 0.93 (0.63-1.00); its stamp is byte-identical to the current wrapper's post-update stamp; non-ancestor and code-commit negative cases both update.
- No LLM on `update`: `label_communities_by_hub` (`watch.py:1991`).

## Changes Made

| File | Description |
|------|-------------|
| weftwise `.graphifyignore` (`2791713d`) | `/_archive/`, `/docs/references/`, `*.scss.d.ts` added to `/cdocs/` |
| `cdocs/reports/2026-10-08-graphify-weftwise-assessment.md` | the deliverable |
| `cdocs/proposals/2026-10-08-graphify-weftwise-assessment.md` | status `implementation_wip` |
| this devlog | implementation record |

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

### Floor (report's block, extracted verbatim and run on the host, 2026-10-08T14:40)

Exit 0.
1. `Rebuilt: 9731 nodes, 25160 edges` (expected 9,731 / 25,160).
2. Prefix zeros pass, `md_nodes 654`, relations `imports=6527 imports_from=3764 calls=4741 re_exports=1345 dynamic_import=36 references=410 method=1244 implements=31`: exact.
3. Raw full build 9.537 / 9.582 / 9.476 s (report 9.60), `explain` 0.448 / 0.448 / 0.451 s (report 0.46), wrapper post-edit 11.582 / 11.850 / 11.712 s (report 11.84): all within ±25%.
4. Tree clean (`0`); `query` seeds `['LoroDocumentStore', 'branch_checkout_persistence.test.ts', 'activeBranchStorageKey()', ...]`; `explain` `.mergeBranch()` L429 with `<-- .buildBranchOps() [calls]`; `affected BranchCard` lists the 4 expected files: all match.
5. `no-graphify`; worktree list `.bare`, six maintainer worktrees, `gfy-floor`, `main` at `2791713d`; main `graph.json` mtime `2026-10-08 14:09:35.882 -0700`; maintainer lines identical to the before record.
   Floor's last line removed `gfy-floor` and `/tmp/gfy-floor` (checked: 0 `gfy` worktrees, no scratch dir).

The first floor draft had `pgrep -af graphify`, which matches its own `bash -c` line; the report uses `pgrep -af "[g]raphify (update|extract|watch)"`. The step 5 expectation text was corrected to include `gfy-floor` (removed by the next line).

### Collateral: after (2026-10-08T14:41)

Maintainer worktree HEADs and dirty counts identical to the before record (floor step 5 output above).
`git worktree list`: `.bare`, `main` (`2791713d`), the six maintainer worktrees; no `gfy*` worktree, no `gfy*` branch.
Container `/tmp/gfy-assess`, `/tmp/gfy-floor`, and the artifact tarball removed; no `graphify update|extract|watch` process.
Main graph dir: `graph.json`, `.graphify_root`, labels, report, html, and manifest all from the Phase 1 rebuild (14:09:35-36), plus its dated backup dir `2026-10-08/` (written by that rebuild, since `GRAPHIFY_NO_BACKUP` was unset); `cache/last_query_stamp` 14:10:23 (see the deviation callout).
The throwaway detached commits made in `gfy-assess` and `gfy-fresh-neg-b` (`gfy probe (throwaway)`) are unreferenced objects in the shared bare repo, left for `git gc`.

