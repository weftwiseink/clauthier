---
review_of: cdocs/reports/2026-10-08-graphify-weftwise-assessment.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T14:52:00-07:00
task_list: cdocs/graphify-weftwise-assessment
type: review
state: live
status: done
tags: [fresh_agent, runtime_validated, implementation_review, verification_gate, graphify, usefulness_grading, root_cause]
---

# Review: Graphify Weftwise Assessment Implementation (Round 1)

> BLUF: Revise, `review_proof: confirmed`.
> I re-ran the report's floor block verbatim and it passes: counts exact, timings within 2% of the report, queries and collateral match.
> The execution is careful, and the runtime and per-role speed verdicts hold.
> Three blocking items:
> - **The 39-edge finding is misattributed.** The cause is whether the gitignored `packages/loro-repo/dist/` exists on disk, not the build path or the cache. An empty-dir build with a stub `dist/` gives exactly the main graph's 25,121.
> - **The report missed the root cause of cross-package `path` failures.** The graph has zero edges from `packages/weft` into `packages/loro-repo/src`, although 31 weft files import `loro-repo`. A `source` export condition adds 204 such edges and turns Q7 from misleading into a hit.
> - **Q12 is misgraded.** Its seeds include `prod_server.ts` and the guard test for this exact bug, so the grade is partial, not miss.

## Summary Assessment

The work assesses `/cdocs:graphify` on weftwise after a scope fix: what it costs at runtime and how useful it is, per role.
The scope fix (`2791713d`), the runtime matrix, the candidate rows, and both prototypes are well executed.
Every number I re-ran reproduced, and the speed-side verdicts follow from the bar:
- implementers wait for upstream on blocking refreshes;
- reviewers and startup can use it now.

The usefulness diagnosis is weaker:
- The report treats the weakness of `path` across packages as intrinsic, and the misses as "coupling that is not a static import or call edge".
- In fact, Q7's chain is static. It is invisible only because graphify resolves the workspace package `loro-repo` to its gitignored `dist/` build output, which is not graphed.
- The same mechanism explains the "build-path" edge difference.

This is the missed config lever the maintainer asked about, and it changes the report's diagnosis and its upstream list.
Verdict: **Revise**.

## Floor Re-run (independent)

I extracted the report's floor block (lines 250-285) verbatim and ran it on the host at 2026-10-08T14:44, with load 0.95 beforehand and no other graphify process running.
Output: `<scratchpad>/rev/floor.out` (session scratch), exit 0.

| Step | Expected | Observed |
|---|---|---|
| 1 | `Rebuilt: 9731 nodes, 25160 edges` | `Rebuilt: 9731 nodes, 25160 edges, 361 communities` |
| 2 | prefix zeros, `md_nodes 654`, relation counts | all exact (`imports=6527 imports_from=3764 calls=4741 re_exports=1345 dynamic_import=36 references=410 method=1244 implements=31`) |
| 3 | 9.60 / 0.46 / 11.84 s, ±25% | full build 9.674 / 9.572 / 9.540 (median 9.57); `explain` 0.473 / 0.447 / 0.451 (0.451); wrapper post-edit 11.679 / 11.757 / 11.786 (11.76) |
| 4 | `0`; Q13 seeds; `.mergeBranch()` L429 `<-- .buildBranchOps()`; 4 `affected` files | all match |
| 5 | `no-graphify`; worktrees; mtime `14:09:35.88`; six HEAD lines | all match; `gfy-floor` listed, then removed by the last line |

Collateral, checked before and after my own runs:
- The six maintainer worktree HEADs and dirty counts are identical to the devlog's record (7 / 0 / 55 / 0 / 0 / 1).
- `graph.json`, `.graphify_root`, and `cache/last_query_stamp` in `/var/cache/graphify-weftwise` are unchanged (14:09:35.88, 14:09:36.37, 14:10:23.64).
- No `gfy*` worktree, branch, or `/tmp/gfy*` remains, and no graphify process is running.

Every raw graphify call I made set `GRAPHIFY_OUT` to scratch.
I used one throwaway worktree of my own, `gfy-rev`, for the experiments below, and removed it afterwards.

## Section-by-Section Findings

### Key Findings › Build-path dependence (blocking)

The report says that an empty-dir build has 39 more `imports_from` edges than an `update` from the main graph's cache, and lists this as an upstream issue.
The main-lineage count, however, was only ever produced in the main worktree, and the main worktree has a built `packages/loro-repo/dist/`; fresh worktrees do not.
Graphify's workspace resolver (`extractors/resolution.py` `_package_entry_candidates`) follows `loro-repo`'s `exports` map, which offers only `./dist/*`.
- When `dist/index.js` exists, the import resolves to a gitignored file that has no node, and the edge is dropped.
- When it does not exist, the bare specifier lands on the `ref_loro_repo` node that `packages/weft/package.json` L102 creates.

My experiment: three empty-dir builds at `2791713d` in a fresh worktree, each with a scratch `GRAPHIFY_OUT`.

| Build | Nodes / edges | Edges on `ref_loro_repo` | Edges from `weft` into `loro-repo/src` |
|---|---|---|---|
| A: fresh tree | 9,731 / 25,160 | 40 | 0 |
| B: plus empty `packages/loro-repo/dist/index.{js,d.ts}` | 9,731 / **25,121** | 1 | 0 |
| C: no `dist/`, `"source": "./src/index.ts"` added to `exports["."]` | 9,731 / 25,342 | 1 | 204 (`imports` 116, `references` 40, `imports_from` 31, `calls` 10, `re_exports` 6, `implements` 1) |

Build B reproduces the main graph's count from an empty dir, so the difference is filesystem state, not the build path.
Consequences for the report:
- Rename the finding and fix it wherever it appears: Key Findings, the Nondeterminism paragraph, the Q7 note under Pre-clean vs cleaned, the Runtime Matrix footnote, Residual risks, and the upstream list.
  The upstream-worthy issue is that the graph depends on gitignored build output: resolution prefers `exports` targets that exist on disk, even when they are ignored and ungraphed.
- "Every wrapper copy sees a topology change on its first update" holds only for worktrees without a built `dist/`. A worktree that has run the package build behaves like main.
- **Kept stamp: not unsafe.** It serves exactly main's graph, and the stamp's diff check is sound: I read the wrapper and the `cdocs-graphify-ks` diff.
  Broaden its residual risk from "a main graph built from a dirty tree" to "a main graph built from the main worktree's untracked and ignored state", of which `dist/` is the live example.
  The `source` fix below removes this dependence.

### Usefulness › Holistic, and What would change the verdict (blocking)

The report says the misses share one cause, coupling that is not a static edge, and that `path` is the weak command.
For Q7, that is not the cause:
- The real chain is `mount_branch_control.tsx` -> `document_store.ts` (imported at L27) -> `LoroRepo` (imported from `loro-repo` at L35) -> `mergeFsBranch`.
- The chain is static, but its cross-package hop is missing from the shipped graph: `packages/weft` has 0 edges into `packages/loro-repo/src`, while 31 weft files import `loro-repo`.

On graph C, Q7's original directed command succeeds without any retry:

```
Shortest path (3 hops):
  mount_branch_control.tsx --imports_from--> document_store.ts --imports--> LoroRepo --method--> .mergeFsBranch()
```

That is a hit, against misleading today.
Q8 (CRDT sync) and Q9 (an intra-package hop through `backing.ts`) are unchanged, so the "not a static edge" diagnosis does hold for them.

What the revision needs:
- Correct the holistic paragraph.
- Run `"source"` export conditions as a candidate row. That means `loro-repo`, and `loro-multiplex`, which is also `workspace:*` with `dist/`; check any other workspace packages too.
  The row needs a full build, a post-edit run, relation counts, and the 14-question spot check, which `affected` and `explain` callers across the package boundary will also move.
- Revisit the reviewer verdict's "do not trust `path`" line in light of the result.
- Recommend the config change, with its cost stated. `source` is a non-standard condition: tsc ignores it unless `customConditions` names it, and vite's defaults do not include it. Confirm that against weftwise's `vite.config` and tsconfigs before recommending it.
  Whether it lands is a weftwise decision (see Questions).
- Replace "A `path` that ignores package-stub hops" in What would change the verdict: the stub hop is a symptom of the resolution gap.

### Usefulness › grading spot checks (Q12 blocking, the rest fair)

I checked five rows against the graded output (`q-clean/` in the implementer's artifact tarball) and against the weftwise code.

- **Q12, miss: should be partial.**
  The ground truth is `loro_server_setup.ts:118` `authoritySlot` and `server/prod_server.ts:234-250`.
  Seed 10 of 12 is `prod_realm_split.prodstack.test.ts`, whose header calls itself "the load-bearing durable guard for the prod-authority-realm-wiring fix".
  Seed 11 is `server` in `packages/weft/server/prod_server.ts`, the file that holds the cross-realm tripwire at L240-250, and its community is labeled `loro_server_setup.ts`.
  The cell's "mostly command-deer palette tests ... no `authoritySlot`" is accurate, but it omits the ground-truth file among the seeds.
  By the rubric ("some of them, or right but buried in noise"), this is partial.
  The tally becomes 7 / 5 / 1 / 1, and the base-tagged rows become 2 hit and 1 partial.
  The advice to write base queries as entity names still stands, as a softer conclusion.
- **Q7, misleading: fair today.** The undirected path runs through the `loro-repo` package stub and a test file, and skips `document_store.ts`, which `mount_branch_control.tsx` imports directly.
  It presents a plausible but wrong route. See above for how config changes this.
- **Q6, hit: fair.** `branch_card.tsx:87-90` derives `isArchiveDisabled = card.isPrimary`, and `mount_branch_panel.test.tsx:166` asserts that main's Merge and Archive are disabled.
  `affected BranchCard` names that test file in 165 tokens.
- **Q5, partial: fair.** The break is at `rpc/web.ts:338` (`spareId`) and in the dynamically imported `listMountSharees` and `mountOwner`.
  `affected` lists only the UI callers.
- **Q8, miss: fair.** No path exists on either lineage or on graph C.
  Minor: the `path` source match was ambiguous (a warning, not an error), so the mechanical "ambiguous -> named id" retry never fired. This is harmless here.

### Deviations the overseer asked about

- **`*.scss.d.ts` ignore line: sound.** There are 28 tracked outputs of `typed-scss-modules` (`packages/weft` `scss:types`), and no code imports a `.scss.d.ts`; imports name the `.scss`.
  The line falls within the proposal's "inventory-proven" allowance.
- **The 39 extra edges in a fresh worktree:** this is a graphify behavior worth an upstream note, under the corrected framing above. It does not make the kept stamp unsafe.
- **`--no-cluster` writing raw extraction: not a bug.** `graphify --help` documents `update --no-cluster` as "skip clustering, write raw extraction only".
  The finding is that the proposal's expectation was wrong, which the devlog already says.
  Drop it from "Upstream issues worth filing" (non-blocking).
- **`extract --code-only` missing 56 `calls`:** I did not re-run this.
  The method (a gident diff against a full `update` of the same edited tree) is sound, and the report does not lean on the row.
  Once the `source` candidate exists, re-check whether part of the loss comes from resolution inputs that `--code-only` skips; it drops `package.json` dependency nodes.
- **The stray `explain --help` write:** disclosed in a NOTE, and verified unchanged since.
  `cache/last_query_stamp` is the freshness marker for graphify's strict hook guard (`cli.py` `_query_stamp_fresh`, `GRAPHIFY_HOOK_STRICT_TTL`, default 1800 s), so at worst it suppressed a strict-hook block against the main out dir until about 14:40.
  It has expired, and any implicit-`GRAPHIFY_OUT` query in the container rewrites it anyway.
  Say so in one clause in the NOTE (non-blocking).
- **The background refresh's `.rebuild.lock` check:** right about blocking, since `update` passes `block_on_lock=True`.
  But the prototype tests the file's existence, and graphify unlinks the file only on a clean release (`watch.py` `_rebuild_lock`).
  An update that is killed leaves the file behind, the kernel drops the flock, and the prototype then reports "a refresh is already running" on every call, so the index is never refreshed again.
  There is also a window of about 0.3 s, before Python takes the lock, in which two calls can both launch an update.
  A landing should probe the lock with `flock -n` on the file, or check the liveness of the PID it records (non-blocking: the report recommends an opt-in mode, not this code).

### Runtime Matrix, Candidates, Verdict per Role

The numbers reproduce, and attributing the time to clustering, report, and html is consistent with the body-only and `--no-cluster` rows.
The per-role verdicts:
- **Startup, "Use now" although 11.9 s is over the bar:** argued, not glossed: the cost is paid once per worktree, and the kept stamp is the fix.
- **Implementers, "Wait for upstream" for blocking refreshes:** honest. The background-refresh caveat ("wrong for exactly what was just edited") is the right emphasis.
- **Reviewers:** fine for `explain` and `affected`. The `path` sentence depends on the blocking item above.

The kept-stamp recommendation (11.9 s to 0.9 s) is actionable and honest about what is unverified.
The prototype reads `built_at_commit` with `tail -c 300 | grep`, which depends on where the key sits in the JSON file; a landing should parse it.

### Readability and minimality

The report is dense but navigable.
The main redundancy is the build-path explanation, which appears in five places, and the scope-fix speedup, which appears in three (BLUF, Key Findings, Matrix).
The correction above is a chance to state the `dist/` mechanism once, in Key Findings, and point to it.
The query table is wide but justified: provenance and ground truth are the floor's "kept with provenance" requirement.

### Impl devlog

It is accurate, and the floor record matches what I observed.
One ambiguity: Phase 3 points to the artifact tarball in session scratch, while Collateral says "the artifact tarball removed".
The host scratch copy survives (`<scratchpad>/gfy/container/gfy-assess-artifacts.tgz`, 286 entries); only the container copy was removed.
The tarball holds the graphify outputs, but not the sampler's or the ground-truth agent's raw answers, so the report table is the only durable record of those answers.
Say so (non-blocking).

## Verdict

**Revise.**
The floor passes and the speed-side work stands.
The report must correct the 39-edge attribution, fix the usefulness diagnosis and test the workspace-package resolution lever it hides, and regrade Q12.
None of this changes the implementer verdict, but it changes what the report recommends and what it sends upstream.

## Action Items

1. [blocking] Replace "build-path dependence" with the `dist/`-presence mechanism everywhere it appears (BLUF and Key Findings, Nondeterminism, Pre-clean vs cleaned Q7 note, Runtime Matrix footnote, Residual risks, upstream list), citing the stub-`dist/` empty-dir build that reproduces 25,121.
2. [blocking] Add a candidate row for `"source"` export conditions on the workspace packages (`loro-repo`, `loro-multiplex`, and any other `workspace:*` package with `dist/` exports): full build, post-edit, relation counts (weft into workspace `src` edges), and the 14-question spot check. Confirm whether weftwise's vite and tsc configs ignore `source`.
3. [blocking] Rewrite the Holistic paragraph and What would change the verdict: Q7's miss is a resolution gap, not runtime coupling. Update the reviewer row's `path` guidance from the action 2 result.
4. [blocking] Regrade Q12 as partial (its seeds name `prod_server.ts` and `prod_realm_split.prodstack.test.ts`), or justify the miss against the rubric explicitly; update the tallies in the BLUF, Key Findings, and the startup row.
5. [non-blocking] Drop `--no-cluster` from the upstream list (documented behavior); keep it as a corrected proposal expectation.
6. [non-blocking] Note in the background-refresh recommendation that a landing must probe the lock (`flock -n` or PID liveness), not the file's existence, and must close the double-launch window.
7. [non-blocking] Broaden the kept-stamp residual risk to the main worktree's untracked and ignored state, and parse `built_at_commit` rather than grepping the file's tail.
8. [non-blocking] Add one clause on the effect of `last_query_stamp` (strict-hook TTL, expired) to the deviation NOTE.
9. [non-blocking] Consolidate the repeated build-path and speedup statements once item 1 is done.
10. [non-blocking] In the impl devlog, clarify where the tarball is and what it does not contain.

## Questions for the Maintainer

1. If the `source` condition holds up in action 2, how should it land?
   - (a) Report-only recommendation: the maintainer commits it to weftwise later.
   - (b) The implementer commits it to weftwise `main` in this loop, as a separate commit, after checking the vite and tsc builds, and rebuilds the main graph a second time.
   - (c) Defer it to a follow-up proposal covering workspace-package resolution generally (it also bears on the fork RFP).
2. Should the upstream note on `dist/`-dependent resolution be filed now, alongside the fork RFP, or held until the `source` workaround is measured?
