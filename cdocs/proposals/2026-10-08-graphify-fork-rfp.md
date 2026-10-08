---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T11:22:39-07:00
task_list: cdocs/graphify-fork
type: proposal
state: live
status: request_for_proposal
tags: [future_work, graphify, performance, upstream]
---

# Fork and fix graphify

> BLUF(claude-opus-5-5/cdocs/graphify-fork): Fix graphify's slow, lossy `update` and our other graphify defects, either through a patch fork or by sending patches upstream first, and ship the fixed build through the lace `graphify` devcontainer feature.
> `update` has no no-op path: it ignores its own AST manifest, and it skips the cache for JS/TS files and parses each of them twice, so a no-op costs about 10 s on weftwise and an edit about 14 s.
> No upstream issue or PR covers the no-op gate or the JS/TS fact cache.
> The prerequisite split ([#3326](https://github.com/Graphify-Labs/graphify/issues/3326)) has two open PRs, and neither is in 0.9.80.
> Upstream is Apache-2.0, releases almost daily, and takes outside fixes within days, so this RFP leans toward sending patches upstream first, with a thin patch branch as a bridge.
>
> - **Motivated By:**
>   - [`2026-10-08-graphify-update-performance-audit.md`](../reports/2026-10-08-graphify-update-performance-audit.md)
>   - `cdocs/proposals/2026-10-08-graphify-overhaul.md` and `cdocs/devlogs/2026-10-08-graphify-overhaul-impl.md`, both on branch `graphify-overhaul`
>   - [`2026-09-17-graphify-mcp-vs-cli-value-add.md`](../reports/2026-09-17-graphify-mcp-vs-cli-value-add.md) and `cdocs/devlogs/2026-09-23-graphify-cdocs-integration-full-send.md`

## Objective

Make `graphify update` cheap enough to run before every query: about 1 s for a no-op and a few seconds for one edited file on a repo the size of weftwise (1269 JS/TS files, 16129 nodes).
It must also produce the same graph as a full rebuild.
Once it does, the wrapper's staleness stamp can go.
The stamp lives in `plugins/cdocs/bin/cdocs-graphify` on branch `graphify-overhaul`, marked `TODO(claude-opus-5-5/cdocs/graphify-overhaul): remove once graphify update is incremental`.
Fix, or route around, the query-side defects the overhaul found as well.

## Scope

- **Fixes, in priority order** (the numbers are the audit's "(c) Upstream fixes"):
  1. Gate `update` on `detect_incremental(kind="ast")`, and exit early when the manifest shows no change.
     The gate must also cover `tsconfig*.json` and `package.json` workspace maps.
  2. Cache each JS/TS file's extraction and its `_SymbolResolutionFacts` by content hash, so each run does only the cross-file join.
     This builds on the [#3326](https://github.com/Graphify-Labs/graphify/issues/3326) split and the Python fact cache in PR [#3649](https://github.com/Graphify-Labs/graphify/pull/3649).
  3. Make an incremental `changed_paths` rebuild produce the same TS graph as a full rebuild, then route `update` through it.
  4. Optional: `update --no-report`.
  5. Query side: `explain` disambiguation, `affected` precision at depth 2, and a non-zero exit when no node matches.
- **Fork vs upstream-first:** choose one, with criteria: upstream turnaround, rebase cost against a fast-moving upstream, and who maintains the fork.
- **Pinning and distribution:** the lace feature `ghcr.io/weftwiseink/devcontainer-features/graphify` runs `pipx install "graphifyy==${VERSION}"` (default 0.9.61) and exposes no option for extras or the install source.
  A fork needs a source option (for example `git+https://github.com/<org>/graphify@<tag>`) or a published package.
  The feature also needs an extras option, since `terraform` and `leiden` are not installed today.
  Moving the pin to 0.9.80 or later is a prerequisite either way.
- **Acceptance harness:** the audit's weftwise timings, plus a check that the graph from an incremental update equals the graph from a full rebuild.

## Known Defects

Versions are 0.9.61 unless noted.

| Defect | Evidence |
|---|---|
| `update` has no no-op path: it never calls `detect_incremental` and always runs `_rebuild_code(changed_paths=None)` | A no-op takes 10.2-10.3 s on weftwise and 10.1-10.4 s on 0.9.80. In the 0.9.80 source, `cli.py` calls `detect_incremental` only from `extract` (audit) |
| JS/TS skip the AST cache (`_JS_CACHE_BYPASS_SUFFIXES`) and are parsed twice for symbol resolution | Every run logs "1279/1279 uncached files". `_augment_symbol_resolution_edges` takes 4.14 s, and cProfile shows 8.7M `_walk_js_tree` iterations (audit) |
| The incremental `changed_paths` path is slow and does not match a full rebuild on TS | One edited `.ts` file takes 8.6 s. Against a full rebuild, 0.9.61 is missing 18 nodes and 29 edges; 0.9.80 is missing 2 nodes and 12 edges and has 7 extra edges (audit) |
| An edited `update` costs about 14 s, about 4 s of it clustering, report, and HTML | 13.8-14.3 s. Clustering falls back to networkx because `graspologic` (the `leiden` extra) is not installed (audit) |
| `--no-cluster` degrades the graph | 0 of 16129 nodes carry `community`, and the graph has 33563 edges against 31311 (audit) |
| `update` rejects `--code-only`; `.graphifyignore` is the only way to exclude paths | Overhaul proposal D4. With unanchored `cdocs/`, `plugins/cdocs/` drops out too: 248 nodes against 732 (overhaul devlog, Phase 2) |
| Markdown bodies become headings only, so references written in prose produce no edges | Without `/cdocs/` ignored, 6637 of clauthier's 7375 nodes are cdocs headings and a no-op takes 2.16 s against 0.41 s. Markdown links do yield `references` edges ([#4177](https://github.com/Graphify-Labs/graphify/issues/4177)) |
| The HCL parser is not installed | `tree-sitter-hcl` ships only in the `terraform` and `all` extras (PyPI metadata), and the lace feature installs bare `graphifyy` |
| `affected` at depth 2 over-reports | Depth 1 gives 26 files, all confirmed by grep. Depth 2 adds 7 real re-export hops and about 43 false positives (overhaul devlog, Round 3) |
| An ambiguous `explain` returns a list of ids instead of an answer, and heading nodes collide with code symbols | `cdocs-graphify` matched both a README heading and the script, so the skill tells agents to rerun with an id. `explain` truncates at about 20 connections, and an unknown node exits 0 with "No unique node match" (2026-09-23 full-send devlog) |
| A shared `GRAPHIFY_OUT` is overwritten silently, and graphify does not flag a graph whose root no longer exists | `/var/cache/graphify` held a stale 73-node fixture rooted at a deleted `/tmp` dir (overhaul proposal, Phase 4 NOTE) |
| Upgrading graphify does not invalidate cached state | The stamp misses version changes (audit). The AST cache ignores the grammar version ([#4236](https://github.com/Graphify-Labs/graphify/issues/4236)) |
| A no-op still rewrites `manifest.json` | "Only `manifest.json` is rewritten" (audit). Its `mtime` and `seen` fields churn on every run ([#3643](https://github.com/Graphify-Labs/graphify/issues/3643)) |

> NOTE(claude-opus-5-5/cdocs/graphify-fork): None of these sources records the HCL defect as a runtime warning; the PyPI metadata and the feature's install line are the evidence.

## Upstream Open Issues

The repo is [Graphify-Labs/graphify](https://github.com/Graphify-Labs/graphify), Apache-2.0, with 716 open issues and 857 open PRs.
The maintainer lands contributor fixes as commits and leaves the PRs open, so "PR open" does not mean the fix is unreleased; the status column was checked against the release notes and, where noted, the v0.9.80 source.

| Item | Summary | Upstream fix status |
|---|---|---|
| [#3326](https://github.com/Graphify-Labs/graphify/issues/3326) | `_JS_CACHE_BYPASS_SUFFIXES` also gates JS/TS symbol resolution; emptying it dropped about 20% of edges | PRs [#3327](https://github.com/Graphify-Labs/graphify/pull/3327) and [#3537](https://github.com/Graphify-Labs/graphify/pull/3537) are open; not in v0.9.80 (source checked) |
| PR [#3649](https://github.com/Graphify-Labs/graphify/pull/3649) | Content-hash fact cache that removes the warm-run re-parse, for Python only | Open; a template for fix 2 on JS/TS |
| PR [#3353](https://github.com/Graphify-Labs/graphify/pull/3353) | Free JS parse trees between symbol-fact files | Open; reduces memory, not time |
| [#3570](https://github.com/Graphify-Labs/graphify/issues/3570) | Changed-files incremental rebuild drops cross-file edges | Open; commenters could not reproduce it on 0.9.61 or later, but the audit reproduces it on TS in 0.9.61 and 0.9.80 |
| [#2406](https://github.com/Graphify-Labs/graphify/issues/2406), [#2230](https://github.com/Graphify-Labs/graphify/issues/2230), [#3328](https://github.com/Graphify-Labs/graphify/issues/3328) | Incremental update loses edges between changed and unchanged files | PR [#3589](https://github.com/Graphify-Labs/graphify/pull/3589) (widen resolution to unchanged neighbors) is open |
| [#4194](https://github.com/Graphify-Labs/graphify/issues/4194), [#4150](https://github.com/Graphify-Labs/graphify/issues/4150) | `update` recomputes path identities tens of thousands of times | Fixed in v0.9.80 and v0.9.78; the no-op still takes about 10 s |
| [#819](https://github.com/Graphify-Labs/graphify/issues/819) | Performance on large codebases: per-stage timing benchmark | Open, no PR |
| [#3643](https://github.com/Graphify-Labs/graphify/issues/3643), [#2988](https://github.com/Graphify-Labs/graphify/issues/2988) | `manifest.json` `mtime` and `seen` churn on every update | PR [#3029](https://github.com/Graphify-Labs/graphify/pull/3029) is open |
| [#2459](https://github.com/Graphify-Labs/graphify/issues/2459) | The skill's update path calls `detect_incremental` with `kind="semantic"`, so it over-reports changes | PR [#2560](https://github.com/Graphify-Labs/graphify/pull/2560) is open; it fixes the skill path only, not the CLI `update` |
| [#4236](https://github.com/Graphify-Labs/graphify/issues/4236) | The AST cache ignores the tree-sitter grammar version | PR [#4239](https://github.com/Graphify-Labs/graphify/pull/4239) is open |
| [#187](https://github.com/Graphify-Labs/graphify/issues/187) | Terraform support | An HCL extractor ships behind the `terraform` extra; PR [#2980](https://github.com/Graphify-Labs/graphify/pull/2980) (cloud stitching) is open |
| [#951](https://github.com/Graphify-Labs/graphify/issues/951), [#4177](https://github.com/Graphify-Labs/graphify/issues/4177) | Markdown links as first-class edges; links with spaces in the target dropped | PR [#1216](https://github.com/Graphify-Labs/graphify/pull/1216) is open; the #4177 fix shipped in v0.9.80. Neither extracts prose |
| [#1969](https://github.com/Graphify-Labs/graphify/issues/1969), [#569](https://github.com/Graphify-Labs/graphify/issues/569) | `explain` resolves ambiguous terms silently; request for scoped resolution in `explain`, `query`, and `path` | PRs [#1970](https://github.com/Graphify-Labs/graphify/pull/1970) and [#2264](https://github.com/Graphify-Labs/graphify/pull/2264) are open; the related [#3176](https://github.com/Graphify-Labs/graphify/issues/3176) and [#3485](https://github.com/Graphify-Labs/graphify/issues/3485) are closed |
| [#2420](https://github.com/Graphify-Labs/graphify/issues/2420) | `explain` caps connections at 20 | PRs [#2423](https://github.com/Graphify-Labs/graphify/pull/2423) and [#2563](https://github.com/Graphify-Labs/graphify/pull/2563) (`--limit`) are open |
| [#2004](https://github.com/Graphify-Labs/graphify/issues/2004), [#2352](https://github.com/Graphify-Labs/graphify/issues/2352) | `affected` false negatives, and no per-edge confidence in its output | PRs [#4134](https://github.com/Graphify-Labs/graphify/pull/4134) (non-zero exit on a miss), [#2431](https://github.com/Graphify-Labs/graphify/pull/2431) (confidence), and [#1478](https://github.com/Graphify-Labs/graphify/pull/1478) (weighted traversal) are open; none targets false positives at depth 2 |
| [#3917](https://github.com/Graphify-Labs/graphify/issues/3917) | The MCP server silently picks a wrong match for an ambiguous or near-miss name | Open |
| [#2841](https://github.com/Graphify-Labs/graphify/issues/2841) | A stale or partially built `graphify-out/` goes undetected | PR [#2858](https://github.com/Graphify-Labs/graphify/pull/2858) is open; v0.9.80 `graph_stats` reports the build commit against HEAD |

No issue or PR covers fixes 1 or 2, and the audit's drafts have not been filed.

## Open Questions

- **Fork or upstream-first?**
  Upstream shipped 19 releases between 0.9.61 (2026-09-12) and 0.9.80 (2026-10-07), and it lands outside fixes within days: #4150 shipped in 0.9.78 the same day it was filed.
  But the PRs this work depends on (#3327, #3537, #3649) have been open for 3-5 weeks.
  Is a patch branch, rebased on each release and installed from git, an acceptable bridge, and who rebases it?
- If we fork, where does the fork live and under what name?
  How do we meet the Apache-2.0 obligations (NOTICE, marking modified files)?
- Why do JS/TS bypass the AST cache in the first place?
  If cross-file context leaks into per-file extraction, fix 2 needs the content-only versus filesystem-dependent split that #3649 uses for Python.
- Should we move to 0.9.80 before patching?
  That needs a graph diff between 0.9.61 and 0.9.80 on weftwise, and 0.9.80 raises the floor to `tree-sitter>=0.25`.
- Which latency is acceptable before the wrapper drops its stamp (no-op and one-file edit, on weftwise)?
- Should the `affected` and `explain` fixes wait for upstream, or should `cdocs-graphify` work around them (depth-1 default, an id-qualified rerun)?
- Should the feature install the `terraform` and `leiden` extras by default, or behind an option?
  Do any weft repos have `.tf` files?
- Is prose extraction from markdown bodies in scope, or should cdocs stay excluded through `/cdocs/`?
