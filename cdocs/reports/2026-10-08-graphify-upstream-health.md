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

> BLUF: graphify is a fast-moving, single-gatekeeper project (one committer, a release roughly every 1.4 days) with broad but shallow test coverage, and it is not close to an efficient, consistent TypeScript update path.
> The pieces exist only as unreviewed community PRs: two duplicate `#3326` splits, a Python-only fact cache, and a conflicting incremental-resolution widening.
> No maintainer has engaged on the TS caching or incremental-parity issues.
> Recommendation: stay pinned with the wrapper stamp, treat graph output as a hint rather than ground truth, and do not fork.
> At most, file one focused upstream issue for the manifest gate in `update` (the audit's fix 1), the smallest and highest-value change.

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
