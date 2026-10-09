---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T14:04:00-07:00
task_list: cdocs/graphify-weftwise-assessment
type: devlog
state: archived
status: review_ready
last_reviewed:
  status: accepted
  by: "@claude-opus-5-5"
  at: 2026-10-08T15:16:00-07:00
  round: 2
part_of: cdocs/devlogs/2026-10-08-graphify-weftwise-assessment.md
tags: [graphify, performance, evaluation]
---

# Graphify Weftwise Assessment, Implementation: Devlog

> BLUF: Implementer sub-devlog (iterate rounds 1-2, all phases) for `cdocs/proposals/2026-10-08-graphify-weftwise-assessment.md`.
> Round 2 applied impl review r1 (`cdocs/reviews/2026-10-08-review-of-graphify-weftwise-assessment-impl-r1.md`): the 39-edge difference is `dist/` presence, the `source`-condition lever is measured (report recommendation only), Q12 is partial (7/5/1/1), and the floor gains two steps and passes.
> All three phases ran; the deliverable is `cdocs/reports/2026-10-08-graphify-weftwise-assessment.md` (`review_ready`), and the floor passes verbatim.
> Weftwise has one commit (`2791713d`, `.graphifyignore`), and all scratch is removed.
> Round 3 is a docs-only pass on impl review r2 (accept): BLUF leads with the per-role answer, the report is trimmed (process detail moved here), and four factual nits are fixed; no number or verdict changed.
> Deviations: one implicit-`GRAPHIFY_OUT` call wrote `cache/last_query_stamp` into the main graph dir (graph untouched); the fresh-worktree row and the `--no-cluster` identity expectation did not hold (both findings).

## Objective

Execute the three phases of `cdocs/proposals/2026-10-08-graphify-weftwise-assessment.md`: weftwise scope fix, usefulness judging against a grep ground truth, runtime matrix plus candidates, ending in `cdocs/reports/2026-10-08-graphify-weftwise-assessment.md`.

## Scratchpoint

- next_steps: round 3 (docs-only, accept-round items of impl review r2) done; awaiting the maintainer. Proposal stays `implementation_wip` (only the maintainer sets `implementation_accepted`).
- graphify_base_query:
- important_files: proposal above; `plugins/cdocs/bin/cdocs-graphify`; weftwise `.graphifyignore`; container scratch `/tmp/gfy-assess/`
- callouts:
  - decision: container scratch root is `/tmp/gfy-assess/` (wrapper copy, saved graphs, scratch `GRAPHIFY_OUT`s); all removed at the end.
  - todo: maintainer worktree state recorded below (Verification › Collateral); re-check at the end.
  - decision: `*.scss.d.ts` added as the one non-markdown ignore line (inventory-proven: 28 tracked typed-scss-modules outputs, 84 nodes, 0 edges to other files).
  - finding (corrected in round 2): the 39 extra `imports_from` edges onto `ref_loro_repo` come from the absence of the gitignored `packages/loro-repo/dist/`, not the build path: a stub `dist/index.{js,d.ts}` gives the main graph's 25,121 from an empty dir.
  - decision (overseer call): the `source` export conditions are measured in a throwaway worktree and recommended in the report; not committed to weftwise (package metadata the app build reads; maintainer decides).
  - decision (overseer call): upstream note on `dist/` resolution is held; a draft is in the report for the maintainer to file.
  - decision: Phase 2 commands fixed before ground truth returned, run blind (status lines only), retries applied mechanically per the skill.
  - deviation: one raw `graphify explain --help` (inspecting an exit code, ~14:10) ran without an explicit `GRAPHIFY_OUT`, so it wrote `/var/cache/graphify-weftwise/cache/last_query_stamp` (18 bytes, 14:10:23). `graph.json` (14:09:35) and `.graphify_root` (14:09:36) are unchanged since Phase 1, so no restore was needed.
  - finding: `--no-cluster` fails the identity check (raw extraction written); the proposal's expectation that it changes only community attributes was wrong for 0.9.61.
  - finding: the fresh-worktree row lands on "update with topology change" (11.9 s), not the expected about 9 s, because of the 39-edge difference, which round 2 attributes to `dist/` presence (see the corrected finding above).
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
- Tally (cleaned graph, round 1 grade; Q12 regraded partial in round 2): hit 7 (Q1 Q2 Q3 Q6 Q11 Q13 Q14), partial 4 (Q4 Q5 Q9 Q10), miss 2 (Q8 Q12), misleading 1 (Q7). Output ~10.7k tokens over 30 commands.
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

## Round 2: impl review r1

Review: `cdocs/reviews/2026-10-08-review-of-graphify-weftwise-assessment-impl-r1.md` (revise, `review_proof: confirmed`, floor reproduced within 2%).
All throwaway work ran in `/workspaces/weftwise/gfy-src` (detached at `2791713d`) with container scratch `/tmp/gfy-src`; every raw call set `GRAPHIFY_OUT` to scratch.

### Workspace packages and toolchain (host reads, read-only)

- `dist/`-only `exports`: `loro-repo` (consumed by `weft`, 32 importing files), `loro-multiplex` (`weft` 53 files, `loro-repo` 7), `command-deer` (no cross-package importer). `weft` exports nothing.
- `loro-repo`'s `./index-doc` and `./branch` exports have no `src` file and no importer (stale entries; noted in the report, not acted on).
- Graphify's `_EXPORT_CONDITION_PRIORITY` starts with `source`, so key order does not matter to it.
- Toolchain: vite 7.3.0 default conditions `module`/`browser`/`node`/`development|production` (read from `dist/node/chunks/logger.js`), no `resolve.conditions` in any weftwise vite/vitest config; TS 5.9.3, all `moduleResolution: bundler`, no `customConditions`; `tsx` 4.21.0 has no `source` condition; ESLint uses `eslint-import-resolver-node` for `import/no-default-export` only. So `source` is inert for current tools.

### Measurements (`source.patch`: 16 `source` keys across the three packages)

| Build | Runs (s) | Nodes / edges | Cross-package edges into `src/` |
|---|---|---|---|
| A: fresh tree | full 9.71 / 9.61 / 9.54; post-edit 11.32 / 11.11 / 11.18 | 9,731 / 25,160 | 0 (`ref_loro_repo` 40 edges) |
| B: A + stub `loro-repo/dist` | full 9.54 | 9,731 / 25,121 | 0 (`ref_loro_repo` 1) |
| C: `source` conditions | full 9.63 / 9.63 / 9.62; post-edit 11.32 / 11.20 / 11.42 | 9,744 / 25,774 | 623 (`weft->loro-repo` 204, `weft->loro-multiplex` 347, `loro-repo->loro-multiplex` 72) |
| C + stub `dist/` in all three | full 9.64 | identical to C | same |
| C fresh-worktree wrapper (copy of C + update) | 8.99 (8.90-9.06) | no topology change | |
| A fresh-worktree wrapper from B's graph | 11.87 (11.74-11.93) | 9,731 / 25,160 | |

The 13 new nodes are the `source` keys in `package.json`.
The report's "551 cross-package edges" is `weft` into both packages' `src/` (204 + 347); with `loro-repo->loro-multiplex` (72) the total is 623, and the graph delta vs main is +653 edges.
`extract --code-only` on C vs C's `update`: 41 code nodes and 97 code edges missing (`calls` 56, `imports` 37, `rationale_for` 4); the 17 `dynamic_import` losses from round 1 were resolution edges; all 551 `weft` cross-package edges kept.

Spot check, all 14 question commands, A vs C (raw, `qgraph.sh`): Q7 file-entity directed path succeeds (3 hops via `document_store.ts` and `LoroRepo`): misleading -> hit. Q8 undirected path now `AclDoc <- LoroRepo <- server_repo.ts -> AuthoritativeServer -> .onDocUpdate()`: miss -> partial. Q4 `affected` grows from 6 to 35 entries (still partial: no reason for the guard; recorded here as 34, corrected to 35 per impl review r2's count). Q1 and Q3 gain one cross-package neighbour each; Q14 swaps a test seed for `AclDoc`; seeds otherwise unchanged. Tally on C: 8 hit, 6 partial.

### Report changes

- The `dist/` mechanism is stated once in Key Findings; Nondeterminism, the matrix row, the kept-stamp residual risk, and the floor point to it. The Q7 pre-clean note is removed (it was the same mechanism).
- New candidate row and safety subsection for `source`; a "With `source`" grading column; fresh-worktree `source` matrix row.
- Q12 regraded partial (seeds 10-11 are the realm-split guard test and `prod_server.ts`); tally 7/5/1/1, base rows 2 hit 1 partial.
- Holistic: two causes (missing static edges from `dist/` resolution; coupling that is not static), replacing "the misses share one cause".
- Reviewer verdict: `path` cannot cross workspace packages without `source`; with it, a usable first pass.
- Upstream: `--no-cluster` dropped (documented), `dist/` resolution added with a held draft (overseer call).
- WARN on the background-refresh lock probe (`flock -n` or PID liveness; double-launch window); kept-stamp residual risk broadened to main's untracked and ignored state, and "parse the JSON"; NOTE on `last_query_stamp` as an expired strict-hook freshness marker; scope-fix speedup stated once in Key Findings.
- Floor: gcount prints `xpkg`; new step 5 (stub `dist/` -> 25,121) and step 6 (`source` -> 9,744 / 25,774, `xpkg`, Q7 path).

### Floor re-run (report block extracted verbatim, host, 2026-10-08T15:05)

Exit 0.
1. `Rebuilt: 9731 nodes, 25160 edges`.
2. Prefix zeros, `md_nodes 654`, relations exact, `xpkg {}`.
3. Full build 9.640 / 9.544 / 9.577 s; `explain` 0.471 / 0.447 / 0.450 s; wrapper post-edit 11.654 / 11.665 / 11.770 s: all within ±25% of 9.60 / 0.46 / 11.84.
4. `0`; Q13 seeds, `.mergeBranch()` L429 with `.buildBranchOps()`, 4 `affected` files: match.
5. `Rebuilt: 9731 nodes, 25121 edges`.
6. `nodes 9744 edges 25774`; `xpkg {'loro-repo->loro-multiplex': 72, 'weft->loro-multiplex': 347, 'weft->loro-repo': 204}`; Q7 3-hop path: match.
7. `no-graphify`; worktrees `.bare`, six maintainer, `gfy-floor`, `gfy-src` (mine, removed right after), `main` `2791713d`; main graph mtime 14:09:35.88; maintainer HEAD and dirty lines identical to the before record.

### Cleanup and records

- `gfy-src` and `gfy-floor` worktrees removed and pruned; `/tmp/gfy-src`, `/tmp/gfy-floor` removed; no `gfy*` worktree, branch, or `/tmp` entry; no graphify process; weftwise `main` still `2791713d`, clean; main `graph.json` 14:09:35.88 and `.graphify_root` 14:09:36.37 unchanged.
- Artifact locations (session scratch, not durable): round 1 container artifacts at `<scratchpad>/gfy/container/gfy-assess-artifacts.tgz` (the host copy survives; only the container copy was removed); round 2 `source.patch`, `timings-src.tsv`, and `src-q/gfy-src-q.tgz` (A and C question outputs) under `<scratchpad>/gfy/`.
  Neither tarball holds the sampler's or the ground-truth agent's raw answers: the report's query table is the only durable record of those.

## Round 3: impl review r2 accept-round items (docs only)

Review: `cdocs/reviews/2026-10-08-review-of-graphify-weftwise-assessment-impl-r2.md` (accept, `review_proof: confirmed`).
Scope: report and this devlog only; no weftwise change, no measurement, no number or verdict changed; `last_reviewed` kept.

Overseer calls on the review's questions: (1) the BLUF leads with the per-role answer, using the role table's "usable now with discipline" framing for implementers; (2) full trim toward half the pre-floor length.

Report changes:
- BLUF: per-role answer first (implementers: `explain` before editing, one about-12 s blocking refresh per edit batch, background refresh fast but stale on just-edited code; flexible mid-edit waits for upstream), then the `source` recommendation, then the cleanup result.
  "No measurable runtime cost" now reads "graphify build cost"; toolchain inertness is qualified "from reading configs (builds/tests not run)".
- Factual fixes: "all five vite configs, both vitest configs" -> 7 vite and 5 vitest (13 vite/vitest/playwright configs, none sets conditions), per r2's container read; Q4 blast radius 34 -> 35 (table cell and candidate row), per r2's re-run.
- Each fact stated once: tally (BLUF and Usefulness), `path` scores (reviewer row), background-refresh caveat (BLUF and its subsection; the implementer row and recommendation point to it).
  The Key Findings usefulness bullet, the `source` paragraph-length Result cell, and "What would change" bullet 4 are gone; Inventory folds into the Key Findings scope bullet.
- Kept: the floor block (byte-identical), the graded query table (only the Q4 count changed), the upstream draft (verbatim), and every Not Verified item.
- Words before the floor: 5,265 -> 3,668.
- `/cdocs:nit_fix` on the trimmed report: clean, no fixes. Not flagged but worth knowing: the report still leans on semicolons (rule: sparingly), left as is to keep this pass from rewording table cells.
- No-change check: every numeric token in the new report also appears in the pre-trim report, except the corrected Q4 count (35) and the config counts (7, 5, 13); the floor block is byte-identical.

> NOTE(claude-opus-5-5/cdocs/graphify-weftwise-assessment): The roughly-half target (about 2,650 words) was not reached.
> The kept-verbatim parts (query table about 1,040 words, upstream draft about 180, Not Verified about 130, frontmatter and BLUF about 220) already total about 1,570, so half would leave about 1,100 words for every finding, data table, and recommendation.
> The remaining prose was cut by about 40%; the next cut would drop data rows (Runtime Matrix, Candidates) rather than repetition.

### Moved from the report

Process detail and supporting counts the trimmed report no longer carries:
- Stray write (report Context NOTE, also the deviation callout above): it wrote `cache/last_query_stamp`, the freshness marker for graphify's strict hook guard (`GRAPHIFY_HOOK_STRICT_TTL`, default 1800 s), so at most it suppressed a strict-hook block against the main out dir until about 14:40; it has expired.
- Totals: graphify 30 commands and about 10.7k output tokens; grep 61 commands and about 21k tokens (Phase 2).
- Pre-clean `built_at_commit` `ab8edd6e` differs from `5e446a84` only under `cdocs/`.
- Per-source inventory, pre-clean -> cleaned nodes: `packages/` 9,106 -> 9,022 (`*.scss.d.ts` -84); `_archive/` 6,058 -> 0; `docs/` 553 -> 297 (`docs/references/` -256); root files 169; `scripts/` 118; `.claude/` 117; external module stubs 8; total 16,129 / 31,272 -> 9,731 / 25,121 nodes / edges; md 6,913 -> 654.
- Per extension (cleaned): ts 7,327, tsx 732, json 671, md 654, mjs 152, sh 104, js 66.
  Largest `packages/*` subtrees: `weft/src` 5,893, `command-deer/src` 557, `weft/e2e` 367, `loro-repo/src` 315, `weft/package.json` 293.
- Relation counts per relation (Phase 1 above); no edge joins an `.md` node to a non-`.md` node, before or after.
- Full-build counts on every run: pre-clean 16,129 / 31,311, cleaned 9,731 / 25,160; repeated builds equal as sorted node and edge sets, community attributes included.
- Pre-clean vs cleaned `query` seeds: Q13 lost `Persistence` (`_archive/`) and gained `activeBranchStorageKey()`; Q14 lost `5. Nested Liveblocks Rooms` (`_archive/`) along with `AclSyncDoc`.
- `source` candidate: +13 nodes (the `source` keys), +653 edges over main's 25,121; the 623 cross-package edges are `imports` 323, `imports_from` 141, `references` 74, `calls` 71, `re_exports` 13, `implements` 1; timing delta +0.02 s full / +0.14 s post-edit, within load noise.
  Toolchain detail: Vite defaults `module`, `browser`, `node`, `development|production` plus `import`/`default`; electron builds go through `vite-plugin-electron`; ESLint's node resolver is used for `import/no-default-export` only.
- md out: Q12's md seed becomes `mapPointBetweenBboxes()` (noise either way); Q14 drops its 2 md seeds.
- Tests out: 7,045 nodes; Q7's stray path ran through a test file; Q5 resolves without the ambiguity retry.
- Output stages off: `GRAPHIFY_VIZ_NODE_LIMIT=0` and `GRAPHIFY_NO_BACKUP=1` measure 0.0 s each; `--no-cluster` output lacks `norm_label` and has 27,312 edges; Q8's misleading path is 6 hops through `ref_loro_crdt`.
- `MAX_WORKERS`: parse parallelism is not the bottleneck past 10 workers.
- `extract --code-only`: the 59 missing nodes are mostly `package.json` dependency nodes, no extras, the edit itself is captured; with `source`, all 551 `weft` cross-package edges are kept.
- Background refresh: the prototype prints a one-line staleness note; `update` blocks on `.rebuild.lock` rather than skipping; queries during the refresh are unslowed by the 20-worker update; after the revert `explain gfyProbeSnap` finds a phantom node; graphify unlinks the lock only on a clean release (the kernel drops the flock); `graphify watch` adds a long-lived process per worktree.
- Kept stamp: format `<built_at_commit> <git hash-object of a single newline>`; the prototype reads `built_at_commit` with `tail -c 300 | grep`; the non-ancestor case rebuilt against its own older ignore, regrowing `_archive/`.
- `update` log prints only a Gemini tip; labels from `label_communities_by_hub` (`watch.py`).
