---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T17:14:00-07:00
task_list: cdocs/graphify-weftwise-assessment
type: report
state: live
status: review_ready
tags: [graphify]
---

# Informal Graphify Exploration of Weftwise

> BLUF: Of 22 informal queries against the weftwise graph (graphify 0.9.61, commit `2791713d`), 2 gave genuinely useful insight that grep would not have surfaced easily: the `GRAPH_REPORT.md` import-cycle list (14 cycles, spot-checked 4, all real runtime imports) and a file-level reachability pass over `graph.json` that found 12 dead modules, 7 of them hidden behind an unused `lib/storage/sync/index.ts` barrel.
> Neither came from the interactive `query`/`explain`/`path`/`affected` commands, and the reachability pass was a custom Python script over `graph.json`, not a graphify command.
> The interactive commands were at best a convenience over grep: multi-hop dependency chains and caller lists with enclosing function names.
> They were often noisy or misleading: keyword-matched `query` starts, undirected paths through external-package nodes, brittle symbol-level directed paths, hubs inflated by test fixtures, and a blind spot for calls inside object literals.

| # | Query | What it showed | Grep-obvious? | Useful? |
|---|---|---|---|---|
| 1 | `god-nodes --top 20` | `LoroDocumentStore`, `loadCanvasLoroDoc`, `emptyCanvasBytes` lead; #3 is a test fixture (3 non-test users, most of its 114 edges come from tests) | partly | no |
| 2 | Report: Import Cycles | 14 runtime cycles, e.g. `arrow_ops -> shape_read -> shape_registry -> arrow_ops`, `recorder_facet -> transclusion/index -> extension_builder`; 4 checked, none type-only | no | yes |
| 3 | Report: Surprising Connections | 5 edges: 1 spurious name collision (`pressEnter -> view` across unrelated test files), the rest visible in each file's imports | yes | no |
| 4 | `affected descriptorFor --depth 3` | 283 nodes (166 tests), fanned out through the `readShape` hub; depth 2 matched the 21 files grep finds | partly | partly |
| 5 | `path KeybindingService LoroDocumentStore` (undirected) | No path. Correct: weft never imports command-deer, which grep confirms in one line | yes | no |
| 6 | `path electron/main.tsx geometry.ts --undirected` | 4 hops through the external `@tanstack/react-router` node: no real dependency shown | no | no |
| 7 | `explain document_store_adapter.ts` | Its import list plus one importer | yes | no |
| 8 | Python: weft `lib` files with no inbound import edge | 8 candidates, 6 dead (`channel_guids.ts`, `meta_change_summary.ts`, `bool_toggle_ref.ts`, ...); 2 false positives | partly | yes (superseded by 9) |
| 9 | Python: reachability from routes, electron, `main.tsx` and scripts | 16 unreachable, 12 really dead incl. 7/11 of `lib/storage/sync/` (barrel `index.ts` has 0 importers), `mount_share_panel.tsx`, `loading.tsx`; false positives: a vite-alias target and `.d.ts` files | no | yes |
| 10 | `affected expected_write_registry.ts --relation imports_from --depth 4` | Only the `sync/index.ts` re-export; grep gives the same | yes | no |
| 11 | `query "how does a canvas embed get indexed as an outbound link"` | Started from keyword hits (`get()`, `link()`, test `embed`); relevant nodes are grep hits for `canvasEmbedOutboundLinks` | yes | no |
| 12 | `query transactGesture --dfs --context call` | ~40 caller functions (shape/group/frame/layout ops) with enclosing names | partly | partly |
| 13 | Python: communities spanning the most directories | Communities mostly mirror directories; no surprising grouping | yes | no |
| 14 | Report: Communities | Labels are arbitrary members (`geometry.ts`, `deps.ts`), cohesion 0.03-0.10 | partly | no |
| 15 | `path recorder_facet.ts mounts_container.ts` | 4-hop barrel chain via `transclusion/index.ts`; one hop is `import type`, so it overstates runtime coupling | partly | partly |
| 16 | `path konva_canvas_editor.tsx LoroSyncLayer` | Canvas editor reaches the sync layer via `use_presence.ts -> document_store.ts` | partly | partly |
| 17 | `path collaborative_editor.tsx LoroSyncLayer` | Via the `mounts/index.ts` barrel `-> mount.ts -> document_store.ts` | partly | partly |
| 18 | `explain LoroSyncLayer` | Methods, owner, 15 importing test files | yes | no |
| 19 | `affected routeArrow --relation calls --depth 2` | 18 callers; misses the call inside `shape_registry.ts`'s descriptor literal (L353), so indirect callers via `descriptorFor` are absent | partly | no |
| 20 | `query "lazy loaded modules" --context dynamic_import` | 4 irrelevant nodes; `grep "import("` is better | yes | no |
| 21 | `path useCommandDeer KeybindingService` (directed) | No path, although `provider.tsx` imports and uses it: symbol-level directed paths do not cross the file `contains` edge | no | no |
| 22 | `path _app.doc.$mount.$.tsx LoroSyncLayer` (directed) | No path. Correct: the route only imports tanstack | yes | no |

Takeaways: graphify's value on weftwise lies in whole-graph structure (cycles, reachability), not in the per-symbol interactive commands, which mostly restate grep with more noise.
Both wins are available from dedicated tools (`madge --circular`, `knip`), so graphify's edge here is mainly that the graph is prebuilt and already covers every package.
Caveats: the graph has almost no cross-package edges (only `scripts -> weft`), so it cannot answer monorepo-wide questions.
It also does not distinguish `import type`, and labels are ambiguous (two `LoroDocumentStore` and two `MountSearchIndex` nodes triggered "ambiguous match" warnings).
