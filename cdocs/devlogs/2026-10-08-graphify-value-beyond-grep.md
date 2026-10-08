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

### Setup

Container scratch `/tmp/gfy-value/`: the wrapper (copied from clauthier `main`), `gcount.py` and `srcpatch.py` (extracted verbatim from the report floor), and `src-graph/`, a plain copy of `/var/cache/graphify-weftwise` used as `-e GRAPHIFY_OUT` (the safety net, per review r4 N5; no separate scratch `source` build).

Worktree pair `gfy-value-graph` / `gfy-value-grep`, both `git worktree add --detach` at `2791713d` from the container; `srcpatch.py` on `loro-repo`, `loro-multiplex`, `command-deer` (3 files, +16 lines); main's `.graphifyignore` copied (identical to the committed one); `cdocs/` and `_archive/` deleted (3,825 tracked files deleted, 0 untracked).

Warm-up (`cdocs-graphify explain mergeBranch` with `-e GRAPHIFY_OUT=/tmp/gfy-value/src-graph`): 11.79 s, full `update` in the worktree.

```
nodes 9744 edges 25774
prefix _archive/ 0 / cdocs/ 0 / docs/references/ 0; md_nodes 654
imports=6858 imports_from=3873 calls=4812 re_exports=1358 dynamic_import=36 references=485 method=1244 implements=33
xpkg {'loro-repo->loro-multiplex': 72, 'weft->loro-multiplex': 347, 'weft->loro-repo': 204}
GRAPH_REPORT.md 1,697 lines
```

Matches the proposal's 9,744 / 25,774 and the report's floor step 6.

> WARN(claude-opus-5-5/cdocs/graphify-weftwise-assessment): wrapper finding, not fixed (clauthier code is out of scope).
> The worktree's `.stamp` is `2791713d... 8b137891...`, the hash of an empty change set, although three `package.json` files are modified.
> Cause: the wrapper filters ignored paths with `grep -vxF -e "$ign"`; with 3,825 ignored deletions, `$ign` exceeds the kernel's single-argument limit (`Argument list too long`), the error is swallowed by `2>/dev/null`, and the change list comes out empty.
> Effect: in a worktree whose ignored changes against the stamp base run to roughly 128 KB of path names, every later edit hashes to the same stamp, so the wrapper never refreshes: silent staleness.
> Harmless for Phase 4 (arms do not edit, and the warm-up built from the real tree, verified by the 9,744 count).
> Realistic trigger: a branch with thousands of `cdocs/` or other ignored-path changes since its stamp base. Fix: feed the ignore list through a file (`grep -vxF -f`).

### Feature inventory

From `graphify --help` (subcommand `--help` is not supported: `query --help` runs a query for "--help") and probes on the `gfy-value-graph` index.

| Feature | Arm use | Notes |
|---|---|---|
| `explain X` (wrapper or raw) | definition, every in/out neighbour with relation and line | ambiguous names list ids; `path::symbol` works; path suffixes do not |
| `affected X --depth N --relation R` | reverse dependents, transitive | default depth 2, 14 default relations; works on files and symbols |
| `path A B [--undirected]` | shortest edge path | "No directed path" suggests `--undirected` |
| `query "..." --dfs --context C --budget N` | BFS from best-matching names | contexts in this graph: `import` 10,732, `call` 4,813, `re-export` 1,096, `export` 262, `parameter_type` 212, `return_type` 97, `field` 94, `generic_arg` 78, `collection` 76, `argument` 59, `type` 34 |
| raw `god-nodes --top N` | hubs | wrapper rejects it |
| `GRAPH_REPORT.md` God Nodes, Surprising Connections | orientation | 10 hubs, 5 surprising edges |
| `GRAPH_REPORT.md` Import Cycles | cycles lookup | 14 cycles of 3-5 files, all in `packages/weft/src` |
| `GRAPH_REPORT.md` Communities (376, 45 thin omitted) | clusters | labels are hub file/symbol names (`geometry.ts`, `loadCanvasLoroDoc`) |
| `GRAPH_REPORT.md` Knowledge Gaps | dead-code hint | 2,494 isolated nodes, led by `package.json` keys: noisy |
| `GRAPH_REPORT.md` Suggested Questions | none | generic betweenness/cohesion prompts |
| `graph.json` scripting (host `python3`/`jq`/`node`) | in-degree, custom traversals | flagged when used |
| `tree`, `export callflow-html` | unavailable | HTML only |
| `serve.py` MCP tools | unavailable | `mcp` not installed |
| `graphify label`, `extract --backend` (LLM) | out of scope | no-LLM config (overseer call) |

Card: about 870 words, copied verbatim into each graph arm prompt with `{WT}` filled in; final text in the Appendix.

### Pilot (held-out Q5, not graded)

Sonnet graph arm on Phase 2's Q5 (`revokeShareLink` `spareId` fallback): 13 tool calls (3 wrapper `explain`, 5 grep, 4 reads, 1 ls), 62,040 tokens, 76.6 s; transcript check clean.
It drove the card without stumbling: the three-way ambiguous `explain revokeShareLink` was retried with `web.ts::revokeShareLink` as the card says.
The answer is a hit on Phase 2's ground truth (`revokeShareLink`, the `LEGACY-OWNER-SPARE` test) and goes further (callee-side `listMountSharees`, `revokeServerRepoAccess`, sticky revoke in `grantServerRepoAccess`).

Card fixes from the pilot's notes:
- Added: calls through bindings destructured from `await import(...)` appear only as a file-level `imports_from` edge (verified: `explain web.ts::revokeShareLink` shows `--> server_repo.ts [imports_from] L327` but no edge to `mountOwner`, `listMountSharees`, or `revokeServerRepoAccess`, which it calls).
  This is a graph gap in its own right: the pilot found the callee side by grepping `spareId`, not from the graph.
- Added: same-named nodes can differ in degree (the `electron.ts` `revokeShareLink` is a degree-1 stub); `explain` each candidate.

### Sampling

Sonnet sampler, two rounds (class names and shapes only, no feature column): 14 tasks (1 primary + 1 backup per class, not the asked 2 + 1 for two-task classes), then 4 more on request (3 tests, 1 blast) from docs dated 2026-09-01 or later.
Round 1: 102 tool calls, 126,745 tokens, 447 s; it dispatched 7 research subagents of its own (the sampler prompt did not forbid it; the arms' no-subagent rule does not apply to it).
Round 2: 34 tool calls.

> NOTE(claude-opus-5-5/cdocs/graphify-weftwise-assessment): The sampler ranged back to 2026-05 docs in round 1, so several tasks concern code that no longer exists at `2791713d`.
> Weftwise code on `main` is frozen at 2026-09-21 (`cbdd203b`, the last commit touching `packages/`).

### Leak check

Step 1 (named entities, subject exists at `2791713d`) and step 2 (lexical traces: two or three distinctive phrases per task, `rg -i` in `gfy-value-grep`, top hits dated with `git log -S`).

| Task | Source (added) | Step 1 | Step 2 | Code state |
|---|---|---|---|---|
| c1 concept | `proposals/2026-09-05-graceful-unshare-unmount-rfp.md` (`4f268d49`, RFP, unimplemented) | pass (no entities; the RFP's three candidate sites removed) | pass: `force-clos` hits are server-side `revokeShareLink` comments; `tabs/invalidation.ts:38` "Called for mount revocation" dates from `03baa60a` 2026-07-25, before the RFP, so not the fix's trace | `2791713d` |
| b1 blast | `proposals/2026-09-17-relational-meta-surface-rethink.md` (`71bf5cb5`, RFP) | **fail**: `enableRelationalMeta`, `RelationalMetaDelegate`, `requireRelational` have 0 hits at `2791713d` (deleted by the bocsync/DoltLite ripout, `690c64c5`..`d0885a58`, 2026-09-16, after the RFP) | n/a | **`3fbd7251`** (`71bf5cb5^`), where `mount_store.ts` has 3 `enableRelationalMeta` hits |
| b2 blast | `proposals/2026-09-17-distributable-acl-authority-rfp.md` (`ba65dd33`, RFP) | pass (names are the asker's own: the quote cites `acl_doc.ts:51-55`) | pass: "single-writer" / "totally ordered" hit `acl_doc.ts:62-63`, which the quote itself cites | `2791713d` |
| t1 tests | `proposals/2026-09-21-engine-content-sync-robustness.md` (`ca1d323e`) | pass (`classifyBoot` and the write order are in the quote) | pass: "crash-safe" hits `disk_bridge_adapter.ts` (`a5a643ab` 2026-09-20, before the doc); every `classifyBoot` test predates it; no code commit follows 2026-09-21 on `main` | `2791713d` |
| t2 tests | `proposals/2026-09-16-loro-multiplex-branching-carrier-roundtrip-test.md` (`88ef32d6`, RFP) | pass (names are the asker's) | pass: "round-trip" hits generic codec tests, no carrier test exists | `2791713d` |
| x1 cross-package | `proposals/2026-09-17-actor-docs-to-host-app-rfp.md` (`ba65dd33`, RFP) | pass | pass: "profile" hits `actors_doc.ts`/`identity/index.ts`, the subject itself, pre-existing | `2791713d` |
| x2 cross-package | `proposals/2026-09-17-branching-aware-transport-reconsideration.md` (`71bf5cb5`, RFP) | pass | pass: "production consumer"/"only consumer" hits unrelated comments | `2791713d` |
| o1 orientation | `devlogs/2026-07-12-weft-architecture-reports-and-review.md` | pass | n/a (no fix; generic phrasing) | `2791713d` |
| d1 dead code (outside tally) | `devlogs/2026-08-26-weft-code-smell-audit.md` | pass | pass: "dead code" hits one unrelated comment | `2791713d` |
| y1 cycles (outside tally) | `proposals/2026-09-09-prod-build-circular-chunk-warnings.md` (`046212bb`) | pass (the build warning named `mounts/atoms.ts`, `mounts/index.ts`) | **fail**: "circular" top hit is `vite.config.ts:127`, written by the fix `fa4340e5` ("break mounts prod-build circular-chunk warnings via manualChunks", after the RFP) | **`41b30188`** (`046212bb^`) |

Dropped: concept-1 (2026-05 UI-lag report: runtime performance, code since rewritten from Y.js to Loro); blast-2 (same doc as y1, overlapping answer); tests-1 (needs git history of deleted tests); tests-2 (runner config, not a code behaviour); orient-2 (Y.js subdoc architecture, gone); dead-1 (`NativeYjsByGuidBackend` gone, July-era tree); tests-5 (its fix landed characterization tests, so it would need an older commit; two tests tasks already pass).
So the set is 10 tasks: concept 1, blast 2, tests 2, cross-package 2, orientation 1 (8 tallied), plus dead code and cycles outside the tally.

**Older-commit builds.**
At `3fbd7251` and `41b30188`, `packages/loro-repo` does not exist, so `srcpatch.py` as invoked in the floor crashes on its first argument and patches nothing.
It was rerun on every workspace package whose exports point at `./dist/` (`loro-multiplex`, `command-deer`, `doltlite-bocsync`, `doltlite-web` at `3fbd7251`; `loro-multiplex`, `doltlite-bocsync`, `sqlite-web-store` at `41b30188`), in both worktrees of each pair, and the graph worktree rebuilt.

> NOTE(claude-opus-5-5/cdocs/graphify-weftwise-assessment): Deviation: the proposal's `srcpatch.py` targets are the three current packages; at older commits I patched every `./dist/`-exporting workspace package, which is the same `source`-conditions config applied to that tree.
> Without it, `weft -> doltlite-bocsync` (184 edges) is missing at `3fbd7251`, and b1 is about the relational (DoltLite) seam.

| Code state | Nodes | Edges | Cross-package edges into `src/` |
|---|---|---|---|
| `2791713d` | 9,744 | 25,774 | loro-repo->loro-multiplex 72, weft->loro-multiplex 347, weft->loro-repo 204 |
| `3fbd7251` (b1) | 10,327 | 27,153 | doltlite-bocsync->loro-multiplex 30, weft->doltlite-bocsync 184, weft->doltlite-web 9, weft->loro-multiplex 238 |
| `41b30188` (y1) | 8,287 | 20,647 | doltlite-bocsync->loro-multiplex 28, weft->loro-multiplex 228 |

The `41b30188` index's Import Cycles section lists 17 cycles, three through `lib/mounts/`.

## Changes Made

| File | Description |
|------|-------------|

## Verification
