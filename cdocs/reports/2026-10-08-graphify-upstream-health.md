---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T12:30:00-07:00
task_list: cdocs/graphify-overhaul
type: report
state: live
status: review_ready
tags: [graphify, upstream, maintenance]
---

# Graphify Upstream Health

> BLUF: graphify is not close to an efficient, consistent TypeScript `update` path, but incremental correctness and perf are a known, actively worked area rather than a blind spot.
> The maintainer ships perf and incremental fixes within hours of a good report (#4150 in about 10 h, #4194 in about 5 h, both as cherry-picks of the reporter's PR) and has fixed the core cross-file edge-loss bug class (0.9.68).
> The specific gap that matters, a no-op `update` that rebuilds everything and JS/TS skipping the cache, has had no maintainer response, and its PRs (`#3327`, `#3537`, the Python-only `#3649`) sit unreviewed.
> TS is not an outlier: on 0.9.61 a no-op `update` costs 8-13 ms per Python file versus 6 ms per TS file, so the slowness is a general full-rebuild cost that TS makes somewhat worse.
> Recommendation: stay pinned with the wrapper stamp, treat graph output as a hint rather than ground truth, and do not fork.
> File one focused upstream issue for the manifest gate in `update` (the audit's fix 1): it is language-agnostic, small, and the kind of report this maintainer acts on quickly.

## Maintainer responsiveness and TypeScript (follow-up)

Labels as below, except **[source]** here means the installed 0.9.61 in container `clauthier`.
Raw outputs (`gh` dumps, release notes, timings, profiles) are in the session scratchpad under `followup/`.

### 1. Do the maintainers care, and have they acknowledged it?

- **The named issues: almost no maintainer comments** [verified].
  Of the 17 issues and PRs listed in the fork RFP, `safishamsi` commented on two: [#2230](https://github.com/Graphify-Labs/graphify/issues/2230) ("Go for it Aman", assigning it to the author of #3589) and #4150 (closing it as shipped).
  #3326, #3327, #3537, #3570, #2406, #3328, #3589, #3649, #819, #3643, #2988, #3029, #2459, #4194, and #4236 have none.
- **The wider area: heavy engagement** [verified, GitHub search on titles].
  The maintainer commented on 29 of 45 issues titled "incremental", 34 of 64 titled "cache", and 12 of 20 titled "typescript".
- **Fixes shipped for the same concerns** [verified, release notes]:
  - [v0.9.68](https://github.com/Graphify-Labs/graphify/releases/tag/v0.9.68): "incremental updates ... now preserve a cross-file `imports`/`calls`/`uses` edge whose target symbol lives in an unchanged file" (#3812, closing [#3776](https://github.com/Graphify-Labs/graphify/issues/3776)).
    This is the #2230/#2406/#3328 bug class, yet those issues stay open, so the tracker understates what is fixed [inferred].
    Our pin 0.9.61 predates it, and the audit still saw a TS incremental-versus-full difference on 0.9.80, so the fix is partial [verified via the audit].
  - [v0.9.47](https://github.com/Graphify-Labs/graphify/releases/tag/v0.9.47): `save_manifest` "no longer rewrites `manifest.json` timestamps on a no-op run" (#2838); #2988 and #3643 were filed after it, so the churn persists in some path [inferred].
  - [v0.9.49](https://github.com/Graphify-Labs/graphify/releases/tag/v0.9.49): tsconfig alias and `baseUrl` caches are cleared per run (#2917).
  - [v0.9.59](https://github.com/Graphify-Labs/graphify/releases/tag/v0.9.59): "Python symbol resolution is roughly 47% faster" (#3500-#3502); no JS/TS counterpart shipped [verified, notes scan].
- **#4150 and #4194: shipped fast, but not written by the maintainer** [verified].
  Both were filed by `rohit-jsfreaky` with a fix PR attached, and the maintainer cherry-picked the PR with authorship preserved.
  - #4150: filed 2026-10-06 10:25Z, fix [#4151](https://github.com/Graphify-Labs/graphify/pull/4151) shipped in [v0.9.78](https://github.com/Graphify-Labs/graphify/releases/tag/v0.9.78) at 20:08Z (about 10 h), with the reconcile on graphify's own repo going "from 10.2s to 2.7s".
  - #4194: filed 2026-10-07 11:45Z, fix [#4195](https://github.com/Graphify-Labs/graphify/pull/4195) shipped in [v0.9.80](https://github.com/Graphify-Labs/graphify/releases/tag/v0.9.80) at 17:04Z (about 5 h); the issue and PR are still open.

### 2. Are they regularly making meaningful improvements?

Yes [verified]. Since 2026-08-09 there are 43 releases and 812 commits on `v8`.

- **Release-note bullets (431):** 334 Fix, 59 Feature, 7 Perf, 6 Security, 4 Docs, 4 Chore, 2 Test, 15 unlabeled.
  43 bullets concern incremental `update`, `watch`, or caches, and 23 concern determinism.
- **Commit subjects:** 425 `fix`, 62 `test`, 61 `docs`, 31 `release`, 28 `feat`, 21 `chore`, 11 `perf`, 158 unprefixed.
  149 `fix`/`feat`/`perf` commits are language-scoped (23 of them JS/TS); 47 `fix` commits name incremental, update, watch, cache, manifest, or determinism.
- **Examples of meaningful perf and correctness work:**
  - [`fedf15d`](https://github.com/Graphify-Labs/graphify/commit/fedf15d) and [`1d38e84`](https://github.com/Graphify-Labs/graphify/commit/1d38e84): the #4194 and #4150 path-identity fixes above.
  - [`cd8d99b`](https://github.com/Graphify-Labs/graphify/commit/cd8d99b), [`f077217`](https://github.com/Graphify-Labs/graphify/commit/f077217): memoized `Path.resolve()`, and one parse per Python file across both resolution passes.
  - [`51c05e7`](https://github.com/Graphify-Labs/graphify/commit/51c05e7): incremental rebuilds keep placeholder nodes, so unchanged referrers' edges are not dropped (#4161).
  - [`304d715`](https://github.com/Graphify-Labs/graphify/commit/304d715): an AST cache hit whose import target is gone is treated as a miss.
  - [`ef58341`](https://github.com/Graphify-Labs/graphify/commit/ef58341): tsconfig `references` are followed, so solution-file path aliases resolve (#3745).

### 3. Is TypeScript performance an anomaly?

No [verified]. No-op `graphify update` on 0.9.61, 20 cores, scratch copies and scratch `GRAPHIFY_OUT` (deleted afterwards), median of 3 after a cold run:

| Corpus | Files | Lines | Nodes | Cold | No-op | ms/file | ms/kLOC | ms/node |
|---|---|---|---|---|---|---|---|---|
| Python: `networkx` | 580 | 192K | 11,265 | 6.5 s | 4.8 s | 8.3 | 25 | 0.43 |
| TS: weftwise `packages/` minus `weft/src/lib` | 538 | 86K | 3,929 | 3.6 s | 3.2 s | 5.9 | 37 | 0.81 |
| Python: graphify's whole `site-packages` | 1,216 | 529K | 31,502 | 23.7 s | 15.6 s | 12.8 | 29 | 0.49 |
| TS: weftwise `packages/` | 1,225 | 213K | 8,798 | 8.9 s | 7.4 s | 6.0 | 35 | 0.84 |

- **Only JS-family suffixes bypass the cache** [source].
  `_JS_CACHE_BYPASS_SUFFIXES` (`extractors/models.py:11`) is `.js .jsx .mjs .cjs .ts .tsx .mts .cts .vue .svelte`, used at `extract.py:6131`, `6320`, `6454` and `resolution.py:1894`; no other bypass set exists.
- **But Python is re-parsed every run too** [source + verified by cProfile].
  `_augment_symbol_resolution_edges` runs `_collect_python_symbol_resolution_facts`, which parses every `.py` file; it took 2.2 s of a profiled 11.8 s Python no-op, against 3.4 s of 7.7 s for `_collect_js_symbol_resolution_facts` on TS.
  The rest of both runs is cache replay, `_reconcile_existing_graph`, and `build_from_json`, which scale with node count.
- **Verdict** [inferred from the above]: the slowness is a general full-rebuild cost, not a TS defect.
  TS adds an uncached, parallel extraction parse (about 10% of the profile) and a heavier resolution walk per line, so per node it costs about twice Python; per file it is cheaper.
  A manifest gate in `update` would help both languages; a JS fact cache alone would not fix Python.

### 4. Bottom line

TS perf and incremental consistency sit inside a known, actively worked area: the maintainer fixes incremental edge loss and lands perf PRs within hours when they come with a reproducer and a patch [verified].
The specific design gap, `update` ignoring its own manifest plus the JS cache bypass, is not acknowledged: its issues have no maintainer reply and its PRs no review [verified].
That looks like a priority gap filled by contributor patches, not a blind spot about performance as such [inferred].
TS is not singled out, since Python pays a similar full-rebuild cost [verified].
A small, language-agnostic, reproducible patch for the manifest gate is the change most likely to land [inferred].

Claim labels: **[verified]** observed via `gh` or the cloned source; **[source]** read from code at `v8` HEAD `6478eb7` (0.9.80); **[inferred]** reasoned, not measured.

## Context

The performance audit (`cdocs/reports/2026-10-08-graphify-update-performance-audit.md`) found that `graphify update` always rebuilds everything, and that JS/TS files skip the cache and are parsed twice.
The fork RFP (`cdocs/proposals/2026-10-08-graphify-fork-rfp.md`) linked 25 related upstream issues and PRs.
The maintainer asked whether upstream is actually close to an efficient, consistent version, particularly for TypeScript.

## Key Findings

### 1. Activity and bus factor

- **Popularity:** 124.7K stars and 12K forks, for a repo created 2026-04-03 [verified].
- **Concentration:** one account, `safishamsi`, has 1,143 of the 1,719 contributions among the top 30 contributors (66%) [verified].
- **Single committer:** all 100 most recent commits were committed by `safishamsi`, though their authors vary (contributors are credited as authors) [verified].
  The bus factor is 1.
- **Review practice:** contributor PRs are almost never merged through GitHub.
  - 135 PRs merged ever, against 856 open [verified].
  - Of the last 200 PRs (since 2026-09-29): 0 merged, 117 closed (median 14 h), 83 open [verified].
  - Fixes are re-landed as maintainer commits citing PR numbers ("release: 0.9.80 — include #4195, #4198"), and the release notes credit the contributors [verified].
  - None of the six PRs we care about has a review decision [verified].
- **Releases:** 40 tagged releases between 2026-08-12 and 2026-10-07 (about one every 1.4 days), each with a detailed changelog [verified].
- **CI:** pytest on Python 3.10, 3.12, 3.13 and 3.14, plus `bandit`, `pip-audit`, and skill-generation consistency checks [verified, `ci.yml`].
- **Issues:** 716 open, 1,209 closed [verified].

### 2. Code quality of extraction and update

- **Module size:** 79K lines of Python, dominated by monoliths.
  - `extract.py` 9,375 lines, `extractors/engine.py` 8,531, `cli.py` 5,039, `extractors/resolution.py` 3,976 [verified].
  - `extractors/models.py` is headed "moved verbatim from graphify/extract.py", so a split is in progress [verified].
- **Test volume:** 349 test files and 113K lines, more test code than source [verified].
  - About 20 `test_js_*`/`test_ts_*` files cover individual extractor features [verified].
  - 16 test files touch `tsconfig` or path aliases [verified].
- **Incremental tests:** `test_incremental.py` has 12 tests, and 3 of its lines reference TS [verified].
  `test_watch.py` has 161 tests and 32 TS references [verified].
  I found no test asserting that an incremental rebuild equals a full rebuild on a TS corpus [source, by test-name and grep scan; not exhaustive].
  That parity is exactly what the audit and #3570 show breaking.
- **The #3326 coupling is a shortcut that hides a design gap** [source + inferred].
  One constant, `_JS_CACHE_BYPASS_SUFFIXES`, decides two things: which files skip the per-file AST cache (`extract.py:7350`, `7579`, `7732`), and which files feed cross-file JS resolution (`resolution.py:2054`).
  The per-file cache stores extraction results but not the symbol-resolution facts, so JS/TS must be re-parsed every run for the cross-file join.
  Caching for JS/TS was skipped rather than designed.
  Emptying the set silently drops about 20% of edges with exit code 0 (the #3326 reporter's numbers, not re-measured).
  #3326 has 0 comments [verified].
- **The incremental machinery exists but `update` doesn't use it** [source].
  `extract` already runs `detect_incremental` against the manifest (`cli.py` around line 3591).
  `update` calls `_rebuild_code(..., changed_paths=None)`, which means a full rebuild.
  So the audit's fix 1 is wiring, not new design.

### 3. TypeScript: how close?

Not close [inferred from the PR states below].
The work exists only in fragments, and nobody upstream owns it.

| PR | Purpose | State |
|---|---|---|
| [#3327](https://github.com/Graphify-Labs/graphify/pull/3327) | Split the bypass set from the resolution gate (#3326) | Open, mergeable, +49/-3, no review |
| [#3537](https://github.com/Graphify-Labs/graphify/pull/3537) | Same split, different author | Open, mergeable, +80/-3, no review; duplicates #3327, so only one can land |
| [#3589](https://github.com/Graphify-Labs/graphify/pull/3589) | Widen incremental resolution to unchanged neighbors (#2230) | Open, **conflicting**, +245/-5 |
| [#3649](https://github.com/Graphify-Labs/graphify/pull/3649) | Content-hash fact cache, **Python only** | Open, **conflicting**, +358/-173 |
| [#3029](https://github.com/Graphify-Labs/graphify/pull/3029) | Stop `manifest.json` churning on unchanged inputs | Open, mergeable, CI includes a FAILURE |
| [#4239](https://github.com/Graphify-Labs/graphify/pull/4239) | Namespace the AST cache by grammar version | Open, mergeable, opened 2026-10-08 |

All states above are [verified].

- **Commitment:** there is no roadmap file.
  Maintainer comments on the TS issues: 0 on #3326, 0 on #3570, 1 on #2230 [verified].
  I found no commitment to incremental TS [inferred; issue search, not exhaustive].
- **Remaining work for the audit's fixes** [inferred]:
  1. **Manifest gate in `update`:** small, about 50-150 lines, reusing `extract`'s path.
     Risk: `tsconfig*.json` and `package.json` workspace maps are resolution inputs the manifest doesn't track.
  2. **JS/TS fact cache:** medium to large.
     It needs the #3327/#3537 split first, then a port of #3649's pattern to `_collect_js_symbol_resolution_facts`, plus parity tests.
     Probably a few hundred lines.
  3. **Incremental TS parity:** the largest and least certain, since it is correctness work in `resolution.py`.
     #3589 is a partial start, and it already conflicts.

### 4. Correctness signals

- **Incremental drops edges:** four issues report it ([#3570](https://github.com/Graphify-Labs/graphify/issues/3570), [#2406](https://github.com/Graphify-Labs/graphify/issues/2406), [#2230](https://github.com/Graphify-Labs/graphify/issues/2230), [#3328](https://github.com/Graphify-Labs/graphify/issues/3328)), and the audit reproduced a TS incremental-versus-full difference on 0.9.61 and 0.9.80 [verified via the audit].
- **Ongoing correctness churn:** the 0.9.80 notes alone fix [verified]:
  - an order-dependent dropped `re_exports` edge (#4143);
  - stale absolute-path ids replayed from the cache (#4185);
  - ghost external stubs left after incremental rebuilds (#4181);
  - several resolution gaps.

  The graph is improving, but its content is not stable across versions [inferred].
- **Locally:** weftwise's `@/` alias resolved, and `affected` at depth 2 returned about 43 false positives out of 76 files [verified, weftwise full-send].
  Graph output suits orientation, not authoritative blast-radius answers.

## Recommendation

**Stay pinned and wait**, keeping the wrapper stamp [inferred].

- **Why not fork:**
  - A fork means rebasing against roughly 9K-line modules that change every 1.4 days.
  - The maintainer re-lands fixes as their own commits, so a fork's patches would never merge cleanly back.
- **Why not invest in upstream PRs beyond one issue:** the six relevant PRs show that well-formed contributions sit unreviewed for weeks.
  - **Worth doing:** file one issue for fix 1, citing the audit's stage table and pointing at `extract`'s existing incremental path.
  - **Don't contribute:** fixes 2 and 3 need maintainer design buy-in that hasn't appeared.
- **Pin bump:** bumping 0.9.61 to 0.9.80 is reasonable for its resolution and determinism fixes.
  Re-run the wrapper suite and one weftwise `query`/`affected` check before bumping.
- **If TS precision becomes a hard requirement,** evaluate a compiler-backed indexer instead [inferred, not evaluated]:
  - [`scip-typescript`](https://github.com/sourcegraph/scip-typescript): Sourcegraph's SCIP indexer, built on the TypeScript compiler, giving precise cross-file references.
  - [`dependency-cruiser`](https://github.com/sverweij/dependency-cruiser): module-level dependency graphs that use TS's own resolution (aliases, `paths`), and are fast.

## Method and Limits

- Sources: `gh` against `Graphify-Labs/graphify` (repo, contributors, the last 100 commits, the last 200 PRs, releases, CI workflow, the issues and PRs named above), and a shallow clone of `v8` at `6478eb7` (0.9.80).
  Scratch outputs are in the session scratchpad under `gh-health/`.
- Not done:
  - running graphify's test suite;
  - reading the six PRs' diffs line by line;
  - inspecting the installed 0.9.61 source, beyond relying on the audit's reading of it.
