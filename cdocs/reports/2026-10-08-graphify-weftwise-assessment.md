---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T14:35:11-07:00
task_list: cdocs/graphify-weftwise-assessment
type: report
state: live
status: review_ready
last_reviewed:
  status: revision_requested
  by: "@claude-opus-5-5"
  at: 2026-10-08T14:52:00-07:00
  round: 1
tags: [graphify, performance, evaluation, investigation]
---

# Graphify Weftwise Assessment

> BLUF: With `_archive/`, `docs/references/`, and generated `*.scss.d.ts` ignored (weftwise `2791713d`), the weftwise graph drops from 16,129 to 9,731 nodes with no loss of edges between kept code.
> Every `graphify` operation gets 15-35% faster: a structural post-edit refresh goes from 14.6 s to 11.8 s, and queries from 0.7 s to 0.5 s.
> On 14 questions sampled from recent devlogs, graphify scores 7 hit, 4 partial, 2 miss, and 1 misleading against a grep ground truth, using about half of grep's tokens.
> It is strong on entity lookup and weak on cross-package flow (`path`).
> Per role:
> - Startup and reviewers: use now.
> - Implementers mid-edit: the blocking refresh (11.84 s) is over the 10 s bar, so wait for upstream, or adopt the background-refresh prototype, which answers in 0.5 s but misses entities edited since the last refresh.
>
> No config flag buys speed for free.
> - `--no-cluster` saves 3 s but writes a different, raw graph that turns one miss into a misleading answer.
> - Dropping tests saves 5 s but removes the breaking tests from blast-radius output.
> - `extract --code-only` reaches 3.6 s but drops 56 `calls` edges and is incompatible with `update`-built indexes.
>
> Recommended wrapper change: keep the stamp across the copy, which cuts the fresh-worktree first query from 11.9 s to 0.9 s.

## Context

The maintainer asked for a dedicated assessment after finding that `_archive/` made up 6,058 of the weftwise graph's 16,129 nodes, which made earlier speed numbers moot.
The design and its review history are in `cdocs/proposals/2026-10-08-graphify-weftwise-assessment.md`; execution notes are in `cdocs/devlogs/2026-10-08-graphify-weftwise-assessment-impl.md`.
Background: `cdocs/reports/2026-10-08-graphify-update-performance-audit.md` (why `update` is a full rebuild) and `cdocs/proposals/2026-10-08-graphify-fork-rfp.md` (the upstream fixes).

Setup: container `weftwise` (20 cores, graphify 0.9.61), assessed commit `2791713d` (weftwise main after the ignore commit).
Every timing is wall time inside the container, with the 1-minute load average logged (0.9-4.3 across the session; no row exceeded a 50% range, so none was re-run).
Raw `graphify` calls set an explicit scratch `GRAPHIFY_OUT`, and only the Phase 1 rebuild wrote the main graph.
> NOTE(claude-opus-5-5/cdocs/graphify-weftwise-assessment): One exploratory `graphify explain --help` ran without the override and wrote `cache/last_query_stamp` (18 bytes) into `/var/cache/graphify-weftwise`; `graph.json` and `.graphify_root` are unchanged since the Phase 1 rebuild.

## Key Findings

- **Scope fix** (`.graphifyignore`: `/cdocs/`, `/_archive/`, `/docs/references/`, `*.scss.d.ts`): 6,398 nodes pruned (6,058 + 256 + 84), exactly the inventory.
  Plain `update` evicts newly ignored sources without `--force`, and a stale worktree index heals the same way once its branch merges main (verified).
- **Speed from the scope fix**: full build 11.33 -> 9.60 s, structural post-edit 14.57 -> 11.84 s, query/explain/path 0.69-0.76 -> 0.46-0.50 s.
  It cannot reach the bar alone: what remains is code parsing plus about 3 s of clustering, report, and html on a topology change.
- **Markdown kept**: the 654 remaining md nodes cost 0.1-0.3 s per build and changed no verdict when removed.
  They do take 1-2 of the 6-12 `query` seeds on topic queries (Q12, Q14), which is mild noise, not harm.
- **Usefulness**: 7 hit, 4 partial, 2 miss, 1 misleading.
  Entity lookups (`explain`) hit 4 of 4; blast radius (`affected`) gives static importers and callers, including tests, but not behavioral reasons; `path` is the weak command (1 partial, 1 miss, 1 misleading).
- **Build-path dependence (upstream-worthy)**: an empty-dir build has 39 more `imports_from` edges (bare `loro-repo` imports to the `ref_loro_repo` stub) than an `update` from the main graph's cache.
  Every wrapper copy therefore sees a topology change on its first update, which is why the fresh-worktree first query costs 11.9 s rather than the about 9 s of an unchanged topology.
- **`--no-cluster` is not "clustering off"**: in 0.9.61 it writes the raw merged extraction (no `norm_label`, no `built_at_commit`, 2,148 extra dangling or stub edges).
- **`extract --code-only` is lossy against `update`** (56 `calls`, 37 `imports`, 17 `dynamic_import` edges, plus `package.json` dependency nodes) and re-extracts everything when started from an `update`-built index.

## Inventory and Counts

Pre-clean is the main graph as found (`built_at_commit` `ab8edd6e`; it differs from `5e446a84` only under `cdocs/`).
Cleaned is the Phase 1 rebuild of `/var/cache/graphify-weftwise` at `2791713d`.

| Source | Pre-clean nodes | Cleaned nodes |
|---|---|---|
| `packages/` | 9,106 | 9,022 (`*.scss.d.ts` -84) |
| `_archive/` | 6,058 | 0 |
| `docs/` | 553 | 297 (`docs/references/` -256) |
| root files | 169 | 169 |
| `scripts/` | 118 | 118 |
| `.claude/` | 117 | 117 |
| external module stubs | 8 | 8 |
| **total nodes / edges** | **16,129 / 31,272** | **9,731 / 25,121** |
| md nodes | 6,913 | 654 |

Per extension (cleaned): ts 7,327, tsx 732, json 671, md 654, mjs 152, sh 104, js 66.
Per `packages/*` subtree, the largest: `weft/src` 5,893, `command-deer/src` 557, `weft/e2e` 367, `loro-repo/src` 315, `weft/package.json` 293.
Non-markdown cruft search (dist, build, generated, vendor, fixtures, lockfiles, `.d.ts`): only the 28 tracked `typed-scss-modules` outputs qualified (84 nodes, 0 edges to other files).

Code relations, pre-clean -> cleaned main: `imports` 6,534 -> 6,527, `imports_from` 3,735 -> 3,725, `calls` 4,760 -> 4,741, `re_exports` 1,345, `dynamic_import` 36, `references` 450 -> 410, `method` 1,246 -> 1,244, `implements` 31.
Each drop equals the number of edges touching a removed source in the pre-clean graph (the 6 `_archive/` code files and the scss types' internal `references`), so no edge between kept code was lost.
No edge joins an `.md` node to a non-`.md` node, before or after.

Nondeterminism: repeated empty-dir builds of one commit are identical (sorted node and edge sets equal, community attributes included).
The only count variation is the build-path difference above: empty-dir builds give 9,731 / 25,160 at `2791713d`, and `update` from the main graph's cache gives 9,731 / 25,121.

## Usefulness

Method:
1. A sonnet agent sampled 14 questions from 13 of the newest non-graphify weftwise devlogs, by filename date. It existence-checked every entity at this commit and dropped Rust-side questions about the separate `loro` fork.
2. A second sonnet agent answered every question with grep and reading only, before any graphify output was read. It used 61 commands and about 21k tokens, and every question's premise held.
3. The graphify command per question was fixed by kind before ground truth returned: `explain` for entity, `affected` for blast, `path` for flow, and `query` for where and base.
4. Retries were mechanical, per the skill: a missing node falls back to the file entity, an ambiguous label takes the id the question names, and "No directed path" takes the tool's own `--undirected` hint.
5. Commands ran through the wrapper on the cleaned graph, and raw on the saved pre-clean graph.

Tokens are output bytes / 4 summed over the question's commands, including retries and the wrapper's runtime-coupling block.

| Q | Kind | Question (provenance) | Ground truth, essential | Graphify commands (retries) | Verdict | Tokens | vs grep |
|---|---|---|---|---|---|---|---|
| Q1 | entity | Where is `mergeBranch` defined, and what does `handleConfirmMerge` call? (`2026-09-20-merge-carries-content-rootcause.md`: "Traced `mount_branch_control.tsx` -> `handleConfirmMerge` -> `runOp(() => branchOps.merge(...))`") | `document_store.ts:429 mergeBranch`, `mount_branch_control.tsx:144 handleConfirmMerge`, `document_store.ts:398 buildBranchOps` | `explain mergeBranch`; `explain handleConfirmMerge` (no node: a closure) -> `explain mount_branch_control.tsx` | hit (retry) | 1,093 | grep 5 cmds / ~1.8k; graph names `mergeBranch` L429 and its caller `.buildBranchOps()` L398 directly |
| Q2 | entity | What is `extractTouchedGuids` and where does it live? (`2026-09-18-fsindex-delta-reactivity.md`: "Event delta in the harness is driven by the backing's REAL emitted `touched` sets") | `fs_index/backing.ts:59 extractTouchedGuids` | `explain extractTouchedGuids` | hit | 213 | grep 1 cmd / ~120; tie, graph adds caller and test |
| Q3 | entity | Where is `LoroRepo.authenticate`, and what does `claimOwner` do on `AclDoc`? (`2026-09-18-owner-mount-authz.md`: "Deny-by-default gate `LoroRepo.authenticate` - `packages/loro-repo/src/repo/loro_repo.ts:428-442`") | `loro_repo.ts:826 LoroRepo.authenticate`, `acl_doc.ts:94 AclDoc.claimOwner` | `explain authenticate`, `explain claimOwner` (both ambiguous) -> the `LoroRepo` and `AclDoc` ids | hit (retry) | 493 | grep 3 cmds / ~1.7k; graph locates both, and the devlog's line number was stale; semantics still need a read |
| Q4 | blast | If `opaque_relay.ts`'s `JoinRequest` handling changes, what breaks; what does `pendingRejoins` guard? (`2026-09-17-shared-mount-sync-bug-propose.md`: "a solicited rejoin is itself a `JoinRequest` the relay cannot distinguish from a fresh join") | `opaque_relay.ts:83 pendingRejoins`, `opaque_relay.ts:188` `JoinRequest` case | `affected opaque_relay.ts`; `explain pendingRejoins` (fuzzy: `.forgetPendingRejoins()`) | partial | 307 | grep 4 cmds / ~2.8k; graph gives `.onMessage()` L186, the test file and re-exports, not the field or why it exists |
| Q5 | blast | If `revokeShareLink`'s `spareId` fallback reverted to bare `owner()`, what breaks for legacy shared-but-unowned mounts? (`2026-09-18-owner-mount-authz.md`: "a BARE `owner()` on a legacy shared-but-unowned mount... would sweep the real owner into the sharee set") | `rpc/web.ts:338 revokeShareLink`, `owner_mount_authz.test.ts:222` LEGACY-OWNER-SPARE test | `affected revokeShareLink` (not unique) -> `explain` (3 matches) -> `affected` on the `web.ts` id | partial (2 retries) | 447 | grep 7 cmds / ~1.8k; graph lists the UI callers, while the break is on the callee side (`listMountSharees`) and in an authz test it never names |
| Q6 | blast | What depends on `BranchCard`'s `isPrimary`-gated disabled props; what breaks if the guard goes? (`2026-09-20-branch-ui-dogfood-defects.md`: "`main` is offered an Archive action (must be guarded - trunk)") | `branch_card.tsx:88-89`, `mount_branch_panel.test.tsx:166` | `affected BranchCard` | hit | 165 | grep 5 cmds / ~1.45k; graph names the breaking test file in 165 tokens |
| Q7 | flow | How does a merge gesture flow from `mount_branch_control.tsx` to `FsDoc.merge` / `mergeFsBranch`? (`2026-09-20-merge-carries-content-rootcause.md`: "`mergeFsBranch(main,b_ui)=\"merged\"`") | `handleConfirmMerge` -> `branchOps.merge` (`document_store.ts:398`) -> `mergeBranch` (:429) -> `loro_repo.ts:359 mergeFsBranch` | `path handleConfirmMerge mergeFsBranch` (no node) -> file entity (no directed path) -> `--undirected` | misleading | 102 | grep 3 cmds / ~500; graph's 4-hop path runs through the `loro-repo` package stub and an unrelated test file |
| Q8 | flow | How does ownership get from the client's `claimOwner` to the server's persisted `__acl__`? (`2026-09-18-owner-mount-authz.md`: "Server ADOPTS a peer's `__acl__` write AUTOMATICALLY: `onDocUpdate` accepts a WRITE peer's ops") | `mount_store.ts:611 claimOwnership` -> `acl_sync_doc.ts:69 claimOwnerOnce` -> `server_repo.ts:104-134 buildServerRepo` (shared `DocManager` room doc) | `path claimOwner onDocUpdate` -> `--undirected` | miss | 81 | grep 9 cmds / ~2.8k; the link is CRDT sync into a shared doc instance, invisible to static edges |
| Q9 | flow | How does an `FsDoc` import event reach the fs-index view's dirty signal? (`2026-09-18-fsindex-delta-reactivity.md`: "Repurpose the post-import signal: `onReproject`->`onBranchImported`") | `fs_doc.ts:345 fireBranchImported`, `fs_index/backing.ts:107` registration and `onDelivering`, `fs_index_view.ts:123` `markDirty` subscribe | `path fireBranchImported markDirty` -> `--undirected` | partial | 81 | grep 7 cmds / ~3k; graph gives the endpoints and `fs_index_view.ts` but skips `backing.ts`, the real hop |
| Q10 | where | Where does `branchProvenance` map a loro `PeerID` to an actor profile? (`2026-09-20-branch-ui-dogfood-defects.md`: "`branchProvenance` looks up `actors.profile(String(source.op.peer))`") | `loro_repo.ts:419 LoroRepo.branchProvenance` | `query "where does branchProvenance map a loro PeerID to an actor profile"` | partial | 1,849 | grep 3 cmds / ~720; `.branchProvenance()` L419 is node 23 of 59, among layout and presence noise |
| Q11 | where | Where are `hasBranchDiffApi` and `classifyBranchDeltas`? (`2026-09-18-loro-repo-branch-metadata-consumer.md`: "a `hasBranchDiffApi(engine)` probe... `branching/divergence.ts` (re-homed heuristic, pure)") | `branch_diff_api.ts:112`, `divergence.ts:64` | `explain` each | hit | 377 | grep 2 cmds / ~600; tie |
| Q12 | where, base | Where is cross-realm authority state shared between the server instance and the prod bundle (the `globalThis` authority slot)? (`2026-09-18-prod-authority-realm-wiring.md`: "authority wiring is realm-local... but read cross-realm in the built prod bundle") | `loro_server_setup.ts:119 authoritySlot`, `server/prod_server.ts:234-250` | `query <the question>` | miss | 1,791 | grep 3 cmds / ~1.1k; 52 nodes, mostly command-deer palette tests; one md seed; no `authoritySlot` |
| Q13 | base | Branch checkout persistence and active-branch restore across reload in `LoroDocumentStore` (`2026-09-20-branch-ui-dogfood-defects.md`: "`_activeBranch = \"main\"` is an in-memory field on `LoroDocumentStore`... never persisted nor restored") | `document_store.ts:305 _activeBranch`, `:478 switchBranch`, `:552 persistActiveBranch`, `:584 restorePersistedActiveBranch` | `query <the topic>` | hit | 1,895 | grep 4 cmds / ~1.3k; first seeds `LoroDocumentStore`, `branch_checkout_persistence.test.ts`, `activeBranchStorageKey()`; `.persistActiveBranch()` listed |
| Q14 | base, blast | Mount collaboration arming and ACL gating across `armCollaboration`, `isCollaborative`, and the ACL-gated sync rooms (`2026-09-18-owner-mount-authz.md`: "`type:\"loro\"` is collaborative UNCONDITIONALLY (`mount_predicates.ts:20`)") | `mount_predicates.ts:20 isCollaborative`, `mount.ts:199 armCollaboration`, `mount.ts:223 rearmSync` | `query <the topic>` | hit | 1,833 | grep 5 cmds / ~1.3k; both named entities are seeds at the right lines, `mount.ts` listed; 2 of 8 seeds are md headings |

Totals: graphify 30 commands and about 10.7k output tokens; grep 61 commands and about 21k tokens.
The comparison flatters graphify somewhat, since grep's totals include reading for full answers while graphify only locates.

**Pre-clean vs cleaned.**
`explain`, `affected`, and `path` outputs are identical up to ordering, plus the build-path `ref_loro_repo` edge.
The scope fix changed only `query` seeds: Q13 lost an `_archive/` heading (`Persistence`) and gained `activeBranchStorageKey()`, and Q14 lost `5. Nested Liveblocks Rooms` (`_archive/`) along with `AclSyncDoc`.
Q7's misleading path exists only on the empty-dir lineage, because it routes through the 39 `ref_loro_repo` edges; on the main lineage, the same command finds no path.
No verdict differs between the two graphs.

**Holistic.**
Graphify beats grep where the question names an entity.
`explain` returns definition, callers, importers, and tests in 100-300 tokens, and catches stale devlog line numbers (Q3).
`affected` is a good test-impact list (Q6).
It does not beat grep where the answer is a behavior rather than a symbol: why a guard exists (Q4), a callee-side consequence (Q5), or a runtime link (Q8, CRDT sync into a shared doc instance).
`path` is the weakest command.
Directed paths fail on every flow question, and the undirected fallback wanders through package stubs and unrelated test files (Q7).
`query` on a topic sentence returns about 1.8k tokens of BFS, 30-60% unrelated.
It hits when the sentence carries distinctive entity names (Q13, Q14) and misses when it carries concepts (Q12 "authority slot").
The misses share one cause: coupling that is not a static import or call edge.
The wrapper's runtime-coupling block is the intended mitigation, but it only lists `.observe`/`.subscribe` sites in files the output already names.

## Runtime Matrix

Median (min-max) seconds, 3 runs unless noted.
The structural post-edit adds an import of `snap` and a new function calling it in `packages/weft/src/lib/canvas/arrow.ts`, so topology changes.

| Case | Pre-clean | Cleaned | How |
|---|---|---|---|
| full build | 11.33 (11.31-11.39) | 9.60 (9.57-9.66) | raw `update` into an empty scratch dir; 16,129 / 31,311 and 9,731 / 25,160 on every run |
| post-edit, structural (wrapper) | 14.57 (14.49-14.61) | 11.84 (11.74-11.87) | edit, then `cdocs-graphify query` |
| post-edit, structural (raw `update`) | | 11.14 (11.13-11.15) | baseline for the candidate rows |
| post-edit, body only (1 run) | | 9.03 | no topology change: clustering, report, and html skipped |
| no-op, stamp hit | 0.85 (1 run) | 0.63 (0.60-0.67) | wrapper on an unchanged tree |
| commit-only (1 run) | | 0.54 | stamp skip confirmed (`update.log` untouched) |
| fresh-worktree first query | 14.92 (1 run) | 11.88 (11.75-11.90) | new worktree, copy plus full `update` |
| fresh-worktree, kept-stamp prototype | | 0.93 (0.63-1.00) | no update |
| `query` / `explain` / `path` / `affected` | 0.74 / 0.69 / 0.76 / 0.27 | 0.50 / 0.46 / 0.50 / 0.23 | raw, no refresh; ranges within 0.03 s |

The proposal expected the fresh-worktree row to land on "update without a topology change" (about 9 s).
It lands on "with" (11.9 s), because of the build-path difference: the copied main-lineage graph gains 39 `imports_from` edges on its first update.

Stage attribution:
- About 3 s of the post-edit refresh is clustering, report, and html (`--no-cluster` 8.18 s vs 11.14 s; body-only 9.03 s vs structural 11.84 s).
- `GRAPHIFY_VIZ_NODE_LIMIT=0` and `GRAPHIFY_NO_BACKUP=1` measure 0.0 s each.
- The remaining 8 s is detection, the JS/TS parse with its symbol-resolution pass, and the build. The audit attributes most of it to `_collect_js_symbol_resolution_facts`.
- `extract --timing` on its incremental path shows what a changed-files-only refresh costs: detect 0.8, AST 0.3, build 0.8, cluster 1.0, analyze 0.1, export 0.4 (3.5 s).

No LLM call runs during `update`: community labels come from `label_communities_by_hub` (`watch.py`), and the log prints only a Gemini tip.

## Candidates

Every row is on `2791713d` with the committed ignore unless it says otherwise.
Post-edit timings are raw `update`, compared with the 11.14 s raw baseline.

| Candidate | Full build | Post-edit | Check | Result |
|---|---|---|---|---|
| all markdown out (`*.md`) | 9.50 (9.45-9.51) | 10.86 (10.80-10.89) | spot check, all 14 | 0 md nodes, code relations unchanged; no verdict change. Q12's md seed becomes `mapPointBetweenBboxes()` (noise either way), and Q14 drops its 2 md seeds. Saves 0.1-0.3 s. The narrower `.claude/` + `AGENTS.md` variant was not run: no harm traced to those files |
| tests, e2e, and demo out | 5.23 (5.22-5.28) | 6.27 (6.27-6.30) | spot check, all 14 | 7,045 nodes; `imports` 6,527 -> 3,258. Q6 hit -> partial (drops `mount_branch_panel.test.tsx`); Q4 and Q5 lose their tests; Q7 misleading -> miss (its stray path ran through a test file); Q5 resolves without the ambiguity retry |
| `*.json` out except `tsconfig*.json`, `package.json` | 9.57 (1 run) | | inventory | Degenerate: removes only `.mcp.json` (3 nodes). An all-JSON-out check (9.17 s) cuts `imports_from` by 405 and `imports` by 175, which confirms that the resolution inputs must stay |
| output stages off (`--no-cluster` + `VIZ_NODE_LIMIT=0` + `NO_BACKUP=1`) | 7.05 (6.87-7.08) | 8.18 (8.16-8.24) | identity: **fails** | Per flag (1 run each): `--no-cluster` 8.18, `VIZ_NODE_LIMIT=0` 11.13, `NO_BACKUP=1` 11.15. `--no-cluster` writes the raw merged extraction: no `norm_label`, no `built_at_commit`, 27,312 edges (2,148 extra stub and dangling edges). The follow-up spot check flips Q8 from miss to misleading (a 6-hop path through `ref_loro_crdt`) |
| `GRAPHIFY_MAX_WORKERS` 4 / 10 / 20 | 10.44 / 9.57 / 9.60 | 11.98 / 11.15 / 11.14 | identity: equal | The default of 20 is already best; parse parallelism is not the bottleneck past 10 workers |
| `extract --code-only`, incremental | 8.42 (1 run); no-op 4.51 | 3.63 (3.61-3.74) | spot check + fidelity | No verdict change on all 14. Fidelity against a full `update` of the edited tree: 59 code nodes missing (mostly `package.json` dependency nodes) and 114 code edges missing (56 `calls`, 37 `imports`, 17 `dynamic_import`, 4 `rationale_for`), no extras; the edit itself is captured. Starting from an `update`-built index it re-extracts all 1,275 files (10.03 s) with the same loss. It drops all markdown by construction |

**Background refresh (scratch prototype).**
On a stale stamp, the wrapper queries the existing index at once and starts `graphify update` in the background, unless `.rebuild.lock` exists, since `update` blocks on that lock rather than skipping.
It then prints a one-line staleness note.
Three edit/revert cycles:
- first query after the edit: 0.47-0.56 s, against the 11.84 s blocking refresh;
- queries during the refresh: 0.31 s each, unslowed by the 20-worker update;
- edit to fresh graph: 11.27-11.55 s;
- the stale query misses the new edge on every cycle: `explain gfyProbeSnap` finds no node after the edit and a phantom node after the revert, and `affected` on `geometry.ts::snap` lacks the new `arrow.ts` caller.

`graph.json` is written atomically (`write_json_atomic`), so a query during a refresh reads the old or the new file, never a partial one.
The staleness bound is "everything edited since the last refresh a query triggered", not a fixed 11 s window: an implementer who edits for ten minutes and then queries gets ten minutes of staleness on the first answer.
That is exactly the audit's concern, `affected` right after an edit sees the old graph, and the data confirms it.
`graphify watch` was not measured: it needs `watchdog`, which is not installed.
The audit shows it is the same full rebuild per batch as this prototype's background `update`, plus a long-lived process per worktree.

**Stamp kept across the copy (scratch prototype).**
At copy time, the wrapper writes `.stamp` as `<built_at_commit> <git hash-object of a single newline>`, the wrapper's own empty-change-set hash, when `built_at_commit` is an ancestor of HEAD.
This stamp is byte-identical to the one the current wrapper writes after its first update on the same commit.
Fresh-worktree first query: 0.93 s (0.63-1.00) against 11.88 s.
Negative cases behave:
- a worktree whose HEAD does not contain `built_at_commit` gets no stamp and a full update (it rebuilt against its own older ignore, regrowing `_archive/`, as it should);
- a worktree with a code commit past `built_at_commit` updates and graphs the edit.

Residual risks:
- a main graph built from a dirty tree;
- the copied graph is served as built, so a fresh worktree on the main lineage keeps lacking the 39 `ref_loro_repo` edges until its first real update.

## Verdict per Role

The bar: 3 s or less is flexible, 3-10 s is usable with discipline, and over 10 s means wait for upstream.

| Role | Refresh cost on the cleaned graph | Usefulness | Verdict |
|---|---|---|---|
| Overseer-briefed agents at startup (base query, fresh worktree) | 11.88 s (11.75-11.90) once per worktree; 0.93 s (0.63-1.00) with the kept stamp | base-tagged rows: 2 hit, 1 miss, about 1.8k tokens each with 30-60% noise | **Use now.** The one-time 12 s is over the bar, but it is paid once per worktree. Land the kept stamp to make it about 1 s. Write base queries as entity names, not concepts (Q12 vs Q13/Q14) |
| Reviewers (`explain`/`path` on changed entities, after commits) | 0.54 s commit-only (stamp skip); queries 0.23-0.50 s; at most one 11.8 s refresh when the index predates the last edit | entity 4/4 hit, `affected` 1 hit and 2 partial, `path` unreliable | **Use now** for `explain` and `affected`. Do not trust `path` for flow questions; grep the call chain instead |
| Implementers mid-edit | 11.84 s (11.74-11.87) blocking, every query after an edit batch | same | **Wait for upstream** for blocking mid-edit refreshes: the whole range is over 10 s. Usable now with discipline: `explain` before editing, as the skill directs (stamp hit, 0.6 s), and batch post-edit questions behind one refresh. With the background-refresh prototype, answers take 0.5 s and are right for unedited code, but wrong for exactly what was just edited |

The variance is small throughout (every timing range is within 0.4 s), so no verdict sits on a boundary by noise.
Only the tests-out variant (6.27 s) and `extract --code-only` (3.63 s) move the implementer refresh into the middle band, and each costs fidelity (see Candidates).

## Recommendations

Config:
- Keep the committed weftwise `.graphifyignore` (`2791713d`). No further ignore line is recommended, so no second weftwise commit was made.
- Keep markdown, `package.json`, `tsconfig*.json`, and tests in the graph.
- Do not use `--no-cluster`, and do not bother with `GRAPHIFY_VIZ_NODE_LIMIT=0`, `GRAPHIFY_NO_BACKUP=1`, or `GRAPHIFY_MAX_WORKERS`.

Wrapper changes (recommended, not landed; a separate decision):
1. **Keep the stamp across the copy**, derived from `built_at_commit` as prototyped. It is safe in the tested cases and removes the 12 s first query whenever main's graph is current.
2. **Background refresh as an opt-in mode** (an env var), with a blocking escape for blast radius on just-edited code. As a default it would silently answer `affected` from the pre-edit graph, which is the implementer's most common post-edit question.

Upstream issues worth filing, alongside the fork RFP:
- the build-path `imports_from` difference;
- `--no-cluster` writing raw extraction;
- `extract --code-only`'s edge loss against `update`.

What would change the verdict:
- The fork RFP's fixes 1 and 2 (a manifest no-op gate and a JS/TS fact cache). The `extract` incremental path already shows that a changed-files-only refresh costs about 3.5 s here, which would put implementers in the middle band and near the 3 s bar.
- `extract --code-only` reaching edge parity with `update` and reading `update`-built manifests. The wrapper could then swap to it at about 3.6 s.
- A post-edit refresh below 3 s by any route, which would make implementers flexible.
- A `path` that ignores package-stub hops, or a runtime-coupling pass that names subscribers rather than only files already in the output, which would lift the flow-question verdicts.

## Not Verified

- Base-query usefulness rests on 3 questions; the startup verdict leans on the runtime more than on usefulness.
- One judge graded every row, with no second grader.
- The background-refresh prototype ran only with sequential queries, never with a concurrent editor writing during the refresh; the stamp-race reasoning is from the code.
- The kept stamp was not exercised against a main graph built from a dirty tree, which is its stated residual risk.
- Timings come from one container on a host with other load (1-minute load 0.9-4.3).

## Verification Floor

Run on the host.
Expected values follow each step.

```sh
C=2791713d; W=/workspaces/weftwise/gfy-floor; S=/tmp/gfy-floor
x() { podman exec -u node -w "$1" weftwise bash -c "$2"; }   # bash: the container's sh is dash, which has no `time`
x /workspaces/weftwise/main "git worktree add --detach $W $C && mkdir -p $S/q"
podman exec -i -u node weftwise bash -c "cat > $S/cdocs-graphify && chmod +x $S/cdocs-graphify" \
  < /var/home/mjr/code/weft/clauthier/main/plugins/cdocs/bin/cdocs-graphify
podman exec -i -u node weftwise bash -c "cat > $S/gcount.py" <<'PY'
import json, sys
from collections import Counter
g = json.load(open(sys.argv[1])); src = lambda n: n.get("source_file") or ""
print("nodes", len(g["nodes"]), "edges", len(g["links"]))
for p in ("_archive/", "cdocs/", "docs/references/"): print("prefix", p, sum(src(n).startswith(p) for n in g["nodes"]))
print("md_nodes", sum(src(n).endswith(".md") for n in g["nodes"]))
rc = Counter(e["relation"] for e in g["links"])
print(*(f"{r}={rc[r]}" for r in "imports imports_from calls re_exports dynamic_import references method implements".split()))
PY
# the structural edit as a patch (import + new caller in arrow.ts)
x $W "f=packages/weft/src/lib/canvas/arrow.ts; sed -i '15i import { snap } from \"./geometry\";' \$f && printf '\nexport function gfyProbeSnap(v: number): number {\n  return snap(v, 8);\n}\n' >> \$f && git diff > $S/edit.patch && git checkout -- packages"
# 1. counts: build into an empty scratch dir (never the container default)
x $W "env GRAPHIFY_OUT=$S/out graphify update $W 2>&1 | grep Rebuilt"
# 2. ignore holds: nodes, edges, per-prefix zeros, relation counts
x $W "python3 $S/gcount.py $S/out/graph.json"
# 3. timings (3x each), timed inside the container: raw full build, explain, post-edit wrapper query
x $W "for i in 1 2 3; do rm -rf $S/out2; time env GRAPHIFY_OUT=$S/out2 graphify update $W >/dev/null 2>&1; done"
x $W "for i in 1 2 3; do time env GRAPHIFY_OUT=$S/q graphify explain mergeBranch --graph $S/out/graph.json >/dev/null; done"
x $W "export GRAPHIFY_OUT=$S/out; $S/cdocs-graphify explain mergeBranch >/dev/null 2>&1
  for i in 1 2 3; do git apply $S/edit.patch; time $S/cdocs-graphify query 'arrow endpoint snapping to the grid' >/dev/null 2>&1
    git checkout -- packages; $S/cdocs-graphify explain mergeBranch >/dev/null 2>&1; done"
# 4. queries against the step 1 graph
x $W "git status --short | wc -l; q() { env GRAPHIFY_OUT=$S/q graphify \"\$@\" --graph $S/out/graph.json; }
  q query 'Branch checkout persistence and active-branch restore across reload in LoroDocumentStore' | head -1
  q explain mergeBranch | sed -n '1,3p;9,10p'; q affected BranchCard | tail -n +4"
# 5. no collateral, then cleanup
x /workspaces/weftwise/main 'pgrep -af "[g]raphify (update|extract|watch)" || echo no-graphify; git worktree list; stat -c %y /var/cache/graphify-weftwise/graph.json
  for w in bocsync-bailout df-to-mount dogfood-sept logical-core loro-branching loro-repo-package; do
    echo $w $(git --no-optional-locks -C ../$w rev-parse HEAD) $(git --no-optional-locks -C ../$w status --short | wc -l); done'
x /workspaces/weftwise/main "git worktree remove --force $W && git worktree prune; rm -rf $S"
```

Expected:
1. `Rebuilt: 9731 nodes, 25160 edges` (the empty-dir lineage; the main graph's own count is 9,731 / 25,121, see Key Findings).
2. `prefix` lines all 0, `md_nodes 654`, `imports=6527 imports_from=3764 calls=4741 re_exports=1345 dynamic_import=36 references=410 method=1244 implements=31`.
3. Raw full build 9.60 s, `explain` 0.46 s, wrapper post-edit 11.84 s, each within ±25%.
4. `0` (the tree is clean again), then:
   - `query`: `Start: ['LoroDocumentStore', 'branch_checkout_persistence.test.ts', 'activeBranchStorageKey()', ...` (Q13, hit);
   - `explain`: `.mergeBranch()` at `packages/weft/src/lib/loro/document_store.ts L429`, with `<-- .buildBranchOps() [calls]` (Q1, hit);
   - `affected`: `mount_branch_panel.tsx`, `mount_branch_control.tsx`, `mount_branch_panel.test.tsx`, `dev.branch-ui.tsx` (Q6, hit).
5. `no-graphify`; `git worktree list` shows `.bare`, `main` at `2791713d`, the six maintainer worktrees, and `gfy-floor`, which the last line removes.
   The main graph's mtime is `2026-10-08 14:09:35.88 -0700` (the Phase 1 rebuild).
   The worktree lines read:
   ```
   bocsync-bailout 44d92d40170fe7c98d35f899b4fd3f04f26c68a7 7
   df-to-mount f8ff8ac33a9c8ceb693e7a2e5aee480565e028b4 0
   dogfood-sept 558bdb180f87e7dde7e1263c4403e280bfa0bddb 55
   logical-core a14919805d3833ac173a2806eb2db565efc37369 0
   loro-branching 1ad160dbcc21c48bf082262d3bca0b3fdaede23a 0
   loro-repo-package bcb0711702c22a97710b75f0d4abd4570dd09715 1
   ```
   Dirty counts belong to the maintainer and may move with their own work; HEADs must match unless they committed.
