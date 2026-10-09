---
review_of: cdocs/reports/2026-10-08-graphify-weftwise-assessment.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T15:16:00-07:00
task_list: cdocs/graphify-weftwise-assessment
type: review
state: archived
status: done
tags: [fresh_agent, runtime_validated, implementation_review, verification_gate, graphify, readability, bluf]
---

# Review: Graphify Weftwise Assessment Implementation (Round 2)

> BLUF: Accept, `review_proof: confirmed`.
> I re-ran the 7-step floor verbatim: every count, edge total, `xpkg` line, and Q7 path is exact, and timings are within 2.5% of the report.
> All ten r1 items are resolved.
> I reproduced the `source` claims I spot-checked: toolchain inertness, the Q8 regrade, and the 8.99 s fresh-worktree time (8.96 s).
> The remaining issues are presentational and non-blocking.
> The most important one: the BLUF's implementer line says "wait for upstream", while the role table says "usable now with discipline", and the table is the more useful answer to the maintainer's question.

## Summary Assessment

The work measures `/cdocs:graphify` on weftwise after the scope fix, and answers whether implementers mid-edit can use it flexibly or should wait for upstream.
Round 2 corrects the 39-edge attribution to `dist/` presence, measures the `"source"` export-condition lever end to end, regrades Q12, and extends the floor with stub-`dist/` and `source` steps.
Everything I re-ran or spot-checked reproduced.
The report is honest about what is unverified.
It is not minimal: about 5,300 words before the floor, with the tally, the path scores, and the background-refresh caveat each stated three or more times.
Its BLUF puts three sentences of `source` mechanics ahead of the per-role answer, and it understates the "usable with discipline" path that the role table recommends.
Verdict: **Accept**, with non-blocking edits that an overseer nit pass can apply without another review round.

## Floor Re-run (independent)

I extracted the report's floor block (lines 306-364) verbatim with `awk` and ran it on the host from 15:09:08 to 15:11:35, with a 1-minute load of 1.97 beforehand and no graphify process running.
Exit 0.
Output: `<scratchpad>/rev2/floor.out` (session scratch).

| Step | Expected | Observed |
|---|---|---|
| 1 | `Rebuilt: 9731 nodes, 25160 edges` | `Rebuilt: 9731 nodes, 25160 edges, 361 communities` |
| 2 | prefix zeros, `md_nodes 654`, relation counts, `xpkg {}` | all exact |
| 3 | 9.60 / 0.46 / 11.84 s, ±25% | full build 9.638 / 9.721 / 9.826 (median 9.72); `explain` 0.462 / 0.450 / 0.449 (0.450); wrapper post-edit 11.678 / 12.018 / 11.757 (11.76) |
| 4 | `0`; Q13 seeds; `.mergeBranch()` L429 `<-- .buildBranchOps()`; 4 `affected` files | all match |
| 5 | `Rebuilt: 9731 nodes, 25121 edges` | `... 25121 edges, 362 communities` |
| 6 | `nodes 9744 edges 25774`; `xpkg` 72 / 347 / 204; Q7 3-hop path | all exact |
| 7 | `no-graphify`; worktrees; mtime `14:09:35.88`; six HEAD lines | all match; `gfy-floor` listed, then removed by the last line |

Collateral, checked before and after all my runs:
- The main graph dir is unchanged: `graph.json` 14:09:35.88, `.graphify_root` 14:09:36.37, `cache/last_query_stamp` 14:10:23.64.
- The six maintainer worktrees have the same HEADs and dirty counts as the devlog's record (7 / 0 / 55 / 0 / 0 / 1).
- Weftwise `main` is at `2791713d` and clean.
- No `gfy*` worktree, branch, or `/tmp/gfy*` remains, and no graphify process is running.

My experiments used one worktree of my own, `gfy-rev2`, with container scratch `/tmp/gfy-rev2`.
Every raw call set `GRAPHIFY_OUT` to scratch.
Both are removed.

## Spot Checks

### Toolchain inertness (holds; one count is wrong)

I read the installed sources and every config in the container:
- **Vite 7.3.0**: `DEFAULT_CONDITIONS = ["module", "browser", "node", DEV_PROD_CONDITION]`, with client and server variants filtered from it.
- **Vitest 4.0.16**: takes `ctx.vite.config.ssr.resolve?.conditions` for Vite 6 and later, so it inherits Vite's defaults.
- **TypeScript 5.9.3**: under `bundler`, `getConditions` returns `import` and `types` plus `customConditions`, and no tsconfig sets `customConditions`.
- **Configs**: none of the 13 tracked vite, vitest, and playwright configs mentions `conditions` or `mainFields`. No tsconfig maps workspace packages through `paths`.
- **Package builds**: they are `tsc` (`loro-repo`, `loro-multiplex`) and `tsc -p tsconfig.build.json` (`command-deer`), so they are inert too. Playwright e2e specs import no workspace package.

The conclusion holds.
The count does not: the report's "all five vite configs, both vitest configs" is wrong.
Weftwise has seven vite configs (six in `packages/weft`, one in `command-deer/demo`) and five vitest configs (three packages, plus two in `weft`).

### Regrade: Q8 on the `source` graph (holds)

I applied the floor's `srcpatch.py` in `gfy-rev2` and built A (fresh tree) and C (`source`) into scratch.
Both rebuilt to the report's counts (9,731 / 25,160 and 9,744 / 25,774).
- On A, `path claimOwner onDocUpdate` gives no directed path, and `--undirected` gives no path: miss, as graded.
- On C, the directed path still fails, and `--undirected` gives the report's 5-hop path exactly: `.claimOwner() <- AclDoc <- LoroRepo <- server_repo.ts -> AuthoritativeServer -> .onDocUpdate()`.
  It names `server_repo.ts`, one of the three ground-truth sites. It omits the client side (`mount_store.ts claimOwnership`, `acl_sync_doc.ts claimOwnerOnce`) and the shared-doc mechanism.
  Partial is the right grade under the rubric. Misleading would be too harsh, since the route really runs through the server repo's wiring.

### Q4 widening (holds, off by one)

`affected opaque_relay.ts` lists 6 entries on A and **35** on C, not 34.
The added entries are what the report says: weft's relay and ACL tests, `loro_server_setup.ts`, `prod_server.ts`, and `rpc/web.ts` importers.
One of them, `membership_offline_rejoin.test.ts`, is the closest test to the `pendingRejoins` question.
Partial still holds, because nothing in the output says why the guard exists.

### Fresh-worktree first query with `source` (holds)

`cdocs-graphify` takes its copy source from `GRAPHIFY_OUT`.
I ran three fresh copies of C into the patched `gfy-rev2`: 9.066 / 8.959 / 8.963 s (median 8.96, report 8.99), and each `update.log` reads "No code-graph topology changes detected".
As a control, a copy of A into the unpatched tree took 8.885 s.
This confirms the report's reading: main's 11.9 s fresh-worktree cost is entirely the `dist/` topology mismatch, and a mismatch-free full `update` costs about 9 s.

## Round-1 Action Items

1. `dist/` mechanism everywhere: **resolved**. It is stated once in Key Findings, and Nondeterminism, the matrix row, the residual risk, and the upstream draft point to it. No "build path" wording remains in the report. The impl devlog's Scratchpoint line 45 still says "39-edge build-path difference" (nit below).
2. `source` candidate row: **resolved**. It has a full build, post-edit timing, relation and cross-package counts, the 14-question spot check, the `dist/`-presence invariance check, and a toolchain review covering all three `dist/`-export packages.
3. Holistic paragraph, What would change the verdict, and reviewer `path` guidance: **resolved**. The two-cause split is correct, and the reviewer row now distinguishes the cases with and without `source`.
4. Q12 regraded partial: **resolved**, with the tallies updated in the BLUF, Key Findings, Totals, and the startup row.
5. `--no-cluster` dropped from upstream: **resolved**. It stays as a corrected expectation.
6. Lock-probe WARN: **resolved**.
7. Kept-stamp residual risk broadened, and the JSON parsed: **resolved**.
8. `last_query_stamp` clause: **resolved**.
9. Consolidation: **partly resolved**. The `dist/` text is consolidated, but other facts now repeat (see Readability).
10. Tarball location and contents: **resolved** (impl devlog, Cleanup and records).

## Section-by-Section Findings

### BLUF (non-blocking, highest priority)

The maintainer's question is "usable flexibly (implementers mid-edit) or wait for upstream".
The BLUF answers it on its ninth line, after three sentences on the resolver gap and the `source` fix.
Its implementer line ("wait for upstream, or adopt the background-refresh prototype") leaves out the middle path that the Verdict per Role row recommends:
- `explain` before editing, at 0.6 s on a stamp hit, which covers the 4-of-4 entity category;
- one 12 s refresh per edit batch, ahead of blast-radius questions.

A maintainer who reads only the BLUF comes away with "don't use it mid-edit", which is stricter than the report's own verdict.
Suggested lead:

> Use now: startup, reviewers, and implementers with discipline (pre-edit `explain` at 0.6 s; one 12 s refresh per edit batch).
> Flexible mid-edit use waits for upstream: a changed-files-only refresh measures about 3.5 s here.

Then give the two cheap wins, the kept stamp and `source` conditions, then the usefulness tally.
The `source` mechanics can drop to one clause that points to Key Findings.

Also non-blocking:
- "at no measurable runtime cost" reads as app runtime. It means graphify build time.
- "is inert for every tool weftwise builds with" is stated as fact, but it rests on reading configs and resolvers; builds and tests were not run. Not Verified says so; the BLUF should say "by config inspection".

### Pragmatism of the implementer verdict (non-blocking)

The verdict follows the proposal's bar, and 11.84 s is clearly over 10 s, so the report is internally consistent.
Pragmatically, it is a close call, and the 10 s line is a judgment call, not a measured threshold.
The report's own data is the better guide: a single post-edit refresh replaces 3-9 grep commands per question (Usefulness table).
The "What would change the verdict" list already shows the real path to flexibility: the fork RFP's changed-files-only refresh, at about 3.5 s.
I agree with the verdict as written in the table; only the BLUF's emphasis is off (see Questions).

### Readability and minimality (non-blocking)

About 5,300 words before the floor is long for a decision that fits in five lines.
The repetition worth cutting:
- **The tally** appears three times: in the BLUF, in the Key Findings Usefulness bullet, and in the Totals line. The Key Findings bullet adds only the `path` breakdown, which the reviewer row repeats.
- **The `source` row's Result cell** is a paragraph that restates the BLUF and the subsection below it. Keep the numbers in the cell and point to the subsection.
- **The background-refresh caveat** ("right for unedited code, wrong for what was just edited") appears in the BLUF, the subsection, the implementer row, and Recommendation 2.
- **What would change the verdict**, bullet 4, restates the `source` recommendation.

Some content is process ceremony, which belongs in the impl devlog (where most of it already is):
- the Context NOTE about the stray `explain --help` write: it is expired, harmless, and recorded in the devlog's deviation callout;
- the per-extension and per-subtree node lines;
- the commands and token totals in the Method list.

The 14-row query table is wide but earns its place, since provenance is part of the floor.
The 60-line floor block is long but required.

### Key Findings and Inventory (fine)

The `dist/` bullet is now the single clear statement of the mechanism, and it matches what I observed (25,160 vs 25,121, with C invariant to `dist/`).
The "no edge between kept code lost" argument is sound.

### Candidates › `source` conditions (two small factual fixes)

- "all five vite configs, both vitest configs": the actual counts are seven and five (see Spot Checks).
- Q4 "6 -> 34 entries": I observe 35. This appears in the Usefulness table cell and the Candidates row, and in the devlog's round-2 spot check.

### Verdict per Role and Recommendations (fine)

The startup and reviewer verdicts follow from the data.
Keeping `source` as a recommendation that the maintainer commits matches the overseer call, and the report says why: the change is package metadata that the app build reads.
The upstream draft is held, as directed, and its numbers agree with the floor.

### Not Verified (fine)

It is complete for what matters: one grader, three base questions, `source` graded raw rather than through the wrapper, no build or test run with `source`, and a sequential-only background-refresh test.

### Impl devlog (nits)

- Scratchpoint line 45 still attributes the fresh-worktree result to "the 39-edge build-path difference". Line 39's corrected callout supersedes it, but a cold reader sees both. Reword it or mark it superseded.
- The Phase 2 tally (line 93: partial 4, miss 2) is the round-1 grade. Add "(round 1; Q12 regraded partial in round 2)".
- The round-2 section matches what I observed, apart from the Q4 count.

## Verdict

**Accept.**
The floor passes as written, every r1 item is resolved, and the round-2 claims I tested reproduce: the 623 / 551 edge counts, the Q7 hit, the Q8 partial, the 8.99 s fresh-worktree time, and toolchain inertness.
The remaining items are wording and trimming.
None of them changes a number or a verdict, so they need no further review round.
The proposal's `implementation_accepted` remains the maintainer's call.

## Action Items

1. [non-blocking] Rewrite the BLUF to lead with the per-role answer and match the implementer row: "usable now with discipline (pre-edit `explain` 0.6 s, one 12 s refresh per edit batch); flexible mid-edit waits for upstream (about 3.5 s changed-files-only refresh)". Then give the kept stamp and `source` as the two cheap wins, and reduce the `source` mechanics to a pointer.
2. [non-blocking] In the BLUF, say "no measurable graphify build cost", and qualify "inert for every tool" with "by config and resolver inspection; builds not run".
3. [non-blocking] Fix "all five vite configs, both vitest configs" to "every vite (7) and vitest (5) config".
4. [non-blocking] Fix Q4's "34 entries" to 35, in the Usefulness table, the Candidates row, and the impl devlog.
5. [non-blocking] Trim the repetition: drop the Key Findings Usefulness bullet (or reduce it to a pointer), shorten the `source` row's Result cell to numbers, drop bullet 4 of What would change the verdict, and state the background-refresh caveat once (in the subsection) with pointers elsewhere.
6. [non-blocking] Move process detail to the impl devlog: the Context NOTE on the stray write (already there), the per-extension and per-subtree lines, and the Method command and token counts.
7. [non-blocking] Impl devlog: reword or mark superseded Scratchpoint line 45 ("build-path"), and annotate the Phase 2 tally as round 1.

## Questions for the Maintainer

1. How should the implementer verdict read in the headline?
   - (a) "Wait for upstream" for mid-edit refreshes, as the BLUF has it now.
   - (b) "Usable now with discipline; flexible after upstream", as the role table has it (reviewer's recommendation).
   - (c) Treat a 12 s refresh per edit batch as acceptable outright, and relax the bar from 10 s.
2. How much trimming should the report get before you read it?
   - (a) None: accept as is.
   - (b) The overseer applies action items 1-4 and 7 only (accuracy and the BLUF).
   - (c) The overseer also applies 5-6 (repetition and process detail), with no change to any number or verdict.
