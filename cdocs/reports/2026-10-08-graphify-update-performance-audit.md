---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T10:52:14-07:00
task_list: cdocs/graphify-overhaul
type: report
state: archived
status: wip
tags: [investigation, audit, performance, graphify, runtime_validated]
---

# graphify `update` performance audit

> BLUF: `graphify update` has no no-op path.
> Every call is a full-corpus rebuild, and JS/TS files skip the AST cache by design, so all 1279 weftwise JS/TS files are parsed twice with tree-sitter every time, once to extract and once more for cross-file symbol resolution.
> That costs about 10.3 s on a no-op, almost all of it per-file (startup is about 0.15 s).
> Upgrading to 0.9.80 does not help (about 10.1 s), and no existing flag or env var avoids the work.
> Recommended: add a staleness stamp to the wrapper (+5 lines, 15-40 ms), which cuts a no-op query from about 11.1 s to about 0.85 s while still picking up edits; separately, report the missing no-op gate and the JS/TS re-parse upstream.
> An edited tree still costs about 14 s per refresh until upstream fixes it.

Claim labels: **[verified]** measured or observed in this audit; **[source]** read from graphify source; **[inferred]** reasoned, not measured.

## Context

`cdocs-graphify` (`plugins/cdocs/bin/cdocs-graphify` on branch `graphify-overhaul`) runs `GRAPHIFY_OUT=<worktree>/graphify-out graphify update <toplevel>` before every query.
The implementer measured 13.1 s cold, about 11 s for a no-op, and 10.7 s with `--no-cluster` on weftwise.

Setup: graphify 0.9.61 (pipx, container `clauthier`, 20 cores, Python 3.11) and 0.9.80 (scratch venv).
The weftwise tree was a `git clone` of `weftwise/main@864a2789` (5258 tracked files, 1269 JS/TS source files in the graph, `.graphifyignore` = `/cdocs/`).
All outputs went to scratch `GRAPHIFY_OUT` dirs, which have since been deleted.

## Measurements

| Case (0.9.61 unless noted) | Wall time |
|---|---|
| weftwise cold `update` | 11.6-11.8 s |
| weftwise no-op `update` (x5) | 10.2-10.3 s |
| weftwise no-op `update --no-cluster` | 9.9 s |
| weftwise no-op `update`, **0.9.80** | 10.1-10.4 s (cold 13.0 s) |
| weftwise `update` after a 4-line edit to one `.ts` file | 13.8-14.3 s |
| clauthier `graphify-overhaul` worktree (`/cdocs/` ignored, 713 nodes) no-op | 0.41-0.44 s |
| clauthier `main` (no `.graphifyignore`, so cdocs headings are graphed) no-op | 2.16 s |
| `graphify --version` (interpreter + entrypoint) | 0.04 s |
| `graphify query` / `explain` on the weftwise graph (20 MB) | 0.7-0.8 s |
| Wrapper stamp (A1 / A2 below), weftwise | 16-39 ms / 21-42 ms |

All rows are [verified].

### No-op stage breakdown (weftwise, wall clock, wrapped functions)

| Stage | 0.9.61 | 0.9.80 |
|---|---|---|
| imports | 0.10 s | 0.09 s |
| `detect()` (walk + ignore rules) | 0.58 s | 0.61 s |
| `extract()` total | 6.64 s | 6.52 s |
| - tree-sitter parse of "uncached" files (20 threads) | 0.83 s | 1.06 s |
| - JS/Py symbol resolution (`_augment_symbol_resolution_edges`) | 4.14 s | 4.21 s |
| - remainder (cache loads, id remap, other resolvers) | ~1.7 s | ~1.25 s |
| `_reconcile_existing_graph` | 1.23 s | 0.74 s |
| `build_from_json` | 0.70 s | 0.81 s |
| `save_manifest` | 0.30 s | 0.42 s |
| unattributed (graph reloads, topology compare) | ~0.7 s | ~0.75 s |
| **total** | **10.2 s** | **9.9 s** |

[verified] cProfile of the same no-op (26 s under the profiler) agrees: `_collect_js_symbol_resolution_facts` is 8.1 s cumulative, with 8.7M `_walk_js_tree` iterations and 1270 more `Parser.parse` calls on the main thread; `pathlib` construction and `resolve()` add about 5 s (inflated by the profiler).
Clustering, `GRAPH_REPORT.md`, and `graph.html` do **not** run on a no-op, because `update` stops after a topology comparison ("No code-graph topology changes detected; outputs left untouched").
On an edit they add about 4 s: Louvain clustering (networkx fallback, since `graspologic` is not installed), `to_json`, `suggest_questions`, the report, and the HTML.

**Fixed vs per-file cost** [verified, arithmetic]: startup is about 0.15 s (interpreter 0.04 s, imports 0.1 s).
The rest scales with the corpus: 0.3 s for 71 source files / 713 nodes (clauthier) versus 10 s for 1637 source files / 16129 nodes, about 7.7 ms per JS/TS file.

## Code path of a no-op `update` (0.9.61)

- **Always a full rebuild.** [source] `cli.py` `update` calls `_rebuild_code(watch_path, force, no_cluster, block_on_lock=True)` with `changed_paths=None`, which `watch.py` treats as "re-extract the full code corpus".
  0.9.80 has the same flags and the same call (`--force`, `--no-cluster`, one path).
- **It ignores its own manifest.** [source] Every update writes `manifest.json` with per-file `ast_hash` (via `save_manifest(kind="ast")`), and `detect.py` has `detect_incremental(kind="ast")`, whose docstring says "Use this for `graphify update`".
  No caller uses it: only `graphify extract` calls `detect_incremental`, for semantic runs.
- **It re-walks and hashes, but cheaply.** [source + verified] `detect()` walks the tree (prunes `node_modules`, `.git` by name) and evaluates ignore rules (0.6 s).
  Content hashing uses a size+mtime stat-index fast path (`cache/stat-index.json`).
- **JS/TS skip the AST cache.** [source + verified] `_JS_CACHE_BYPASS_SUFFIXES = {.js,.jsx,.mjs,.cjs,.ts,.tsx,.mts,.cts,.vue,.svelte}` (`extractors/models.py`) skips both `load_cached` and `save_cached`.
  The no-op log reports "1279/1279 uncached files" on every run, and only 350 entries exist in `cache/ast/` (the non-JS files).
- **JS/TS are parsed a second time.** [source + verified] `_collect_js_symbol_resolution_facts` re-reads and re-parses every JS-family file (`_parse_js_tree`) and walks each full tree in Python to collect export, import, alias, and use facts.
  This is the largest single cost (about 4.1 s), and per-file caching cannot avoid it because the facts are not cached at all.
  Upstream [#3326](https://github.com/Graphify-Labs/graphify/issues/3326) (open) notes that the bypass set also gates JS symbol resolution, and that emptying it lost about 20% of edges on a 2300-file TS monorepo.
- **It reloads `graph.json`, but rewrites only on change.** [source] The existing 20 MB graph is parsed for reconcile and again for the topology compare.
  When topology is unchanged, graph.json, the report, and the HTML are left untouched; only `manifest.json` is rewritten.
- **Imports and grammar loading are not the problem.** [verified] Imports total 0.1 s.

## Existing cheaper paths

| Path | Result | Usable? |
|---|---|---|
| `update --no-cluster` | 9.9 s no-op [verified]. The first run rewrote graph.json **without communities** (0/16129 nodes carry `community`) and with 33563 rather than 31311 edges [verified] | No: saves about 0.4 s and degrades the graph |
| `GRAPHIFY_MAX_WORKERS` | Affects only the 0.8 s parallel parse [source] | No |
| `GRAPHIFY_FORCE`, `GRAPHIFY_NO_INCREMENTAL_CACHE` | Force the shrink guard; semantic/LLM cache only [source] | No |
| `graphify watch` | Runs the same full `_rebuild_code(watch_path)` on every debounced batch [source]. It needs a long-lived process per worktree and races with queries [inferred] | No |
| `graphify hook install` | Post-commit runs incremental `_rebuild_code(changed_paths=git diff HEAD~1 HEAD)`, detached [source]. Uncommitted edits are never reflected, and it installs into the shared `.git/hooks` of the bare repo [inferred] | No |
| Hook-style incremental via private `_rebuild_code(changed_paths=[...])` | Empty change set: 0.87-0.91 s. One edited `.ts` file: 8.6 s, and the graph **differs from a full rebuild**: 18 nodes and 29 edges missing on 0.9.61 (external-module nodes, `dynamic_import`/`imports`/`calls` edges); 2 nodes and 12 edges missing plus 7 extra on 0.9.80 [verified] | No: private API, lossy on TS, and an edit still costs 8.6 s |

No `--changed`, `--if-stale`, `--no-report`, or skip-outputs option exists in 0.9.61 or 0.9.80 [source].

## Fix options

### (a) Wrapper-side staleness stamp

Skip `update` when HEAD plus the working-tree changes match the stamp from the last successful update.
Two variants were measured on the weftwise clone across clean, tracked-edit, untracked-file, staged-delete, and prose-only states:

- **A1** (3 lines, 16-39 ms): HEAD + `git diff HEAD` + untracked names and blob hashes.
  Correct, but any edit, including a devlog under the ignored `cdocs/`, triggers a full 10-14 s update.
- **A2** (5 lines, 21-42 ms): A1, with paths matching `.graphifyignore` (via `check-ignore --no-index`) left out of the stamp.
  A prose-only edit gives the same stamp as the clean tree, while code edits, new files, and deletions each change it [verified].
  This matters in cdocs workflows, where devlogs change between almost every pair of queries.

```bash
# Skip the refresh when HEAD and the graphed working-tree changes match the last successful update.
stamp=$(cd "$top" && {
  chg=$({ git diff HEAD --name-only; git ls-files -o --exclude-standard; } | sort -u)
  ign=$(printf '%s\n' "$chg" | git -c core.excludesFile="$top/.graphifyignore" check-ignore --no-index --stdin)
  chg=$(printf '%s\n' "$chg" | grep -vxF -e "${ign:-//}"); git rev-parse HEAD; printf '%s\n' "$chg"
  printf '%s\n' "$chg" | while IFS= read -r f; do [ -f "$f" ] && echo "$f"; done | git hash-object --stdin-paths
} 2>/dev/null | git hash-object --stdin)
[ "$stamp" = "$(cat "$wt_out/.stamp" 2>/dev/null)" ] ||
  { GRAPHIFY_OUT="$wt_out" graphify update "$top" >"$wt_out/update.log" 2>&1 && echo "$stamp" >"$wt_out/.stamp"; } ||
  note "update failed (graphify-out/update.log); querying existing index"
```

Correctness [inferred unless noted]:
- Edits are picked up: any content change to a non-ignored tracked or untracked file changes the stamp [verified], so the next query runs the same full `update` as today.
- The stamp is computed before the update and written only after it succeeds, so an edit made during the update or a failed update triggers a refresh next time.
- A worktree whose graph was copied from main has no stamp, so its first query runs an update; the copy step must also `rm` `.stamp`, as it does `.graphify_root`.
- Gaps: files ignored by `.gitignore` but graphed by graphify (only if a build disabled gitignore), an untracked non-ignored directory with many files (slower stamp), and a graphify upgrade (the stale graph survives until the next edit).
  All are minor for cdocs' use.

Cost: no-op query about 0.85 s instead of about 11.1 s on weftwise.
An edited tree is unchanged at about 14 s + 0.8 s.

### (b) Existing graphify option

None helps; see the table above.
`--no-cluster` is a net loss.

### (c) Upstream fixes (not filed)

1. **Use the AST manifest in `update`.** Call `detect_incremental(kind="ast")` (already used by `extract`) and exit early when nothing is new, changed, or deleted, and no exclude rules changed.
   Expected no-op cost is about `detect` + startup, roughly 0.7 s on weftwise [inferred].
   The gate must also cover non-code inputs to JS resolution (`tsconfig*.json`, `package.json` workspace maps), which the manifest does not track [source/inferred].
2. **Cache JS/TS per-file work.** Cache each file's extraction result *and* its `_SymbolResolutionFacts` keyed by content hash, and run only the cross-file join (`_apply_symbol_resolution_facts`) each run.
   This removes the double parse and the Python tree walk (about 5 s of the 10 s) from every full rebuild, including edited ones [inferred].
   Prerequisite: [#3326](https://github.com/Graphify-Labs/graphify/issues/3326)'s split of the bypass set from the resolution gate.
3. **Make incremental `changed_paths` rebuilds match full rebuilds for TS**, then route `update` through them.
   As it stands, the incremental rebuild drops external-module nodes and import/call edges [verified, above].
4. Optional: an `update --no-report` that skips `suggest_questions`, `GRAPH_REPORT.md`, and `graph.html` (about 2-3 s of an edited update) for query-only consumers [inferred from profile shares].

### (d) Combinations

- **A2 now, plus (c1)/(c2) upstream**: the stamp handles the no-op case today (0.85 s), and the upstream fixes bring edited updates down from about 14 s.
  Once (c1) ships, the stamp is redundant and could be dropped (graphify's own gate is about 0.7 s versus 0.04 s for the stamp).
- **A2 + refresh in the background on a stale stamp** (query the old index immediately and refresh asynchronously; graphify locks per output dir [source]): every query would cost about 0.85 s, but a query right after an edit sees the old graph.
  This breaks the "edited files must be picked up" requirement for `affected`, so it is not recommended unless the wrapper flags the lag [inferred].

## Recommendations

1. Add A2 to `cdocs-graphify` (+5 lines, plus `.stamp` in the copy's `rm` list), so the wrapper grows from 49 to about 55 lines.
   It is the only option that removes the 10 s no-op today without changing graph content.
2. Accept that a query after a code edit costs about 14 s on weftwise-sized TS repos until upstream changes, and say so in the wrapper's header comment or the proposal.
3. Draft upstream issues for (c1) and (c2), citing #3326 and the stage table above; (c3) is a correctness bug in its own right.
4. Ensure every consuming repo has `.graphifyignore` with `/cdocs/`: without it, clauthier's no-op is 2.16 s rather than 0.41 s [verified].
   The wrapper already hints at this.
