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
  at: 2026-10-08T16:45:00-07:00
  round: 3
tags: [graphify, performance, evaluation, investigation]
---

# Graphify Weftwise Assessment

> BLUF: Per role, on weftwise `2791713d`:
> - Startup and reviewers: use now.
> - Implementers mid-edit: usable now with discipline, running `explain` before editing (0.5-0.6 s) and one blocking refresh (about 12 s) per batch of edits.
>   A background refresh answers fast but misses just-edited code.
>   Flexible mid-edit querying waits for upstream incremental updates (a changed-files-only refresh measures about 3.5 s here).
>
> Use it alongside grep, not instead of it.
> On 8 discovery tasks answered by a graph-assisted and a grep-only agent and graded blind, neither reliably beat the other: mixed (each found important code the other missed) was the usual outcome, nothing came cheaper, and one of four re-judged outcomes moved.
> The graph's cleanly attributable finds are hub ranking on orientation (one task); its blast-radius leads were mostly reachable by grep.
> The graph arms used the graph lightly, so this measures typical use, not its best case on blast radius and tests.
>
> Recommended: the maintainer adds `"source"` export conditions to the workspace packages, whose imports graphify otherwise resolves to gitignored `dist/`, leaving no cross-package edges.
> They add 623 such edges at no measurable graphify build cost, are inert for weftwise's toolchain from reading configs (builds/tests not run), and lift the 14-question score from 7 hit, 5 partial, 1 miss, 1 misleading to 8 hit, 6 partial.
> Also keep the wrapper's stamp across the copy (fresh-worktree first query 11.9 s -> 0.9 s).
> Known defect (not fixed): the shipped wrapper's stamp silently stops refreshing once a worktree's ignored-path changes exceed about 128 KB of path names, about six weeks of weftwise churn or one archive sweep.
>
> Cleanup: ignoring `_archive/`, `docs/references/`, and generated `*.scss.d.ts` cuts the graph from 16,129 to 9,731 nodes, losing no edge between kept code, and makes every `graphify` operation 15-35% faster.

## Context

The maintainer asked for this assessment after `_archive/` turned out to hold 6,058 of the graph's 16,129 nodes.
Design: `cdocs/proposals/2026-10-08-graphify-weftwise-assessment.md`.
Execution record, process detail, and command and token totals: `cdocs/devlogs/2026-10-08-graphify-weftwise-assessment-impl.md`.
Background: `cdocs/reports/2026-10-08-graphify-update-performance-audit.md` (why `update` is a full rebuild) and `cdocs/proposals/2026-10-08-graphify-fork-rfp.md` (the upstream fixes).
Setup: container `weftwise` (20 cores, graphify 0.9.61); timings are wall time at 1-minute load 0.9-4.3, and no row exceeded a 50% range.
Raw `graphify` calls wrote to a scratch `GRAPHIFY_OUT`; only the Phase 1 rebuild wrote the main graph.

## Key Findings

- **Scope fix** (`.graphifyignore`: `/cdocs/`, `/_archive/`, `/docs/references/`, `*.scss.d.ts`): plain `update`, without `--force`, pruned 6,398 nodes (`_archive/` 6,058, `docs/references/` 256, `*.scss.d.ts` 84, exactly the inventory), taking the main graph from 16,129 / 31,272 nodes / edges to 9,731 / 25,121 and md nodes from 6,913 to 654.
  Every relation-count drop equals the edges touching a removed source, so no edge between kept code was lost; a non-markdown cruft search found nothing else (per-source table in the impl devlog).
  A stale worktree index heals the same way once its branch merges main (verified).
  What remains is code parsing plus about 3 s of clustering, report, and html, so ignores alone cannot reach the bar.
- **Workspace imports resolve to `dist/`.**
  `loro-repo`, `loro-multiplex`, and `command-deer` export only `./dist/*` targets, and graphify's resolver (`_package_entry_candidates`) follows them: with the gitignored `dist/` present the edge is dropped, and without it the import lands on the `ref_loro_repo` stub node.
  Either way there are 0 edges from `weft` into `loro-repo/src` (32 importing files) or `loro-multiplex/src` (53), and 0 from `loro-repo` into `loro-multiplex/src` (7).
  Repeated builds of one tree state are identical, but content varies with `dist/` presence (25,160 edges in a fresh tree, 25,121 with a stub `loro-repo/dist/`: 39 `imports_from` edges onto the stub), so main's graph changes topology on its first update in a fresh worktree (11.9 s rather than about 9 s).
- **Markdown kept**: the 654 md nodes cost 0.1-0.3 s per build, changed no verdict when removed, and take 1-2 seeds of topic `query` output.
- **No free speed lever**: only tests out (6.27 s post-edit) and `extract --code-only` (3.63 s) reach the middle band, and both lose fidelity.
  `update --no-cluster` writes raw extraction (documented), not the proposal's expected "same graph without communities".

## Usefulness

A sonnet agent sampled 14 questions from 13 recent weftwise devlogs, existence-checking every entity; a second answered them with grep and reading only, as ground truth.
The graphify command per kind was fixed beforehand (`explain` for entity, `affected` for blast, `path` for flow, `query` for where and base), with mechanical retries per the skill: missing node -> file entity, ambiguous label -> the id the question names, "No directed path" -> `--undirected`.
Commands ran through the wrapper on the cleaned graph, and raw on the pre-clean and `source`-condition graphs.
Tokens are output bytes / 4 over the question's commands, retries and the wrapper's runtime-coupling block included.
The last column regrades the same commands on the `source`-condition graph; a dash means unchanged.

| Q | Kind | Question (provenance) | Ground truth, essential | Graphify commands (retries) | Verdict | Tokens | vs grep | With `source` |
|---|---|---|---|---|---|---|---|---|
| Q1 | entity | Where is `mergeBranch` defined, and what does `handleConfirmMerge` call? (`2026-09-20-merge-carries-content-rootcause.md`: "Traced `mount_branch_control.tsx` -> `handleConfirmMerge` -> `runOp(() => branchOps.merge(...))`") | `document_store.ts:429 mergeBranch`, `mount_branch_control.tsx:144 handleConfirmMerge`, `document_store.ts:398 buildBranchOps` | `explain mergeBranch`; `explain handleConfirmMerge` (no node: a closure) -> `explain mount_branch_control.tsx` | hit (retry) | 1,093 | grep 5 cmds / ~1.8k; graph names `mergeBranch` L429 and its caller `.buildBranchOps()` L398 directly | - (adds `FsMergeOutcome` reference) |
| Q2 | entity | What is `extractTouchedGuids` and where does it live? (`2026-09-18-fsindex-delta-reactivity.md`: "Event delta in the harness is driven by the backing's REAL emitted `touched` sets") | `fs_index/backing.ts:59 extractTouchedGuids` | `explain extractTouchedGuids` | hit | 213 | grep 1 cmd / ~120; tie, graph adds caller and test | - |
| Q3 | entity | Where is `LoroRepo.authenticate`, and what does `claimOwner` do on `AclDoc`? (`2026-09-18-owner-mount-authz.md`: "Deny-by-default gate `LoroRepo.authenticate` - `packages/loro-repo/src/repo/loro_repo.ts:428-442`") | `loro_repo.ts:826 LoroRepo.authenticate`, `acl_doc.ts:94 AclDoc.claimOwner` | `explain authenticate`, `explain claimOwner` (both ambiguous) -> the `LoroRepo` and `AclDoc` ids | hit (retry) | 493 | grep 3 cmds / ~1.7k; graph locates both, and the devlog's line number was stale; semantics still need a read | - (adds `parseRoomId()` call into `loro-multiplex`) |
| Q4 | blast | If `opaque_relay.ts`'s `JoinRequest` handling changes, what breaks; what does `pendingRejoins` guard? (`2026-09-17-shared-mount-sync-bug-propose.md`: "a solicited rejoin is itself a `JoinRequest` the relay cannot distinguish from a fresh join") | `opaque_relay.ts:83 pendingRejoins`, `opaque_relay.ts:188` `JoinRequest` case | `affected opaque_relay.ts`; `explain pendingRejoins` (fuzzy: `.forgetPendingRejoins()`) | partial | 307 | grep 4 cmds / ~2.8k; graph gives `.onMessage()` L186, the test file and re-exports, not the field or why it exists | - (blast radius grows from 6 to 35 entries: weft's relay tests, `loro_server_setup.ts`, `prod_server.ts`) |
| Q5 | blast | If `revokeShareLink`'s `spareId` fallback reverted to bare `owner()`, what breaks for legacy shared-but-unowned mounts? (`2026-09-18-owner-mount-authz.md`: "a BARE `owner()` on a legacy shared-but-unowned mount... would sweep the real owner into the sharee set") | `rpc/web.ts:338 revokeShareLink`, `owner_mount_authz.test.ts:222` LEGACY-OWNER-SPARE test | `affected revokeShareLink` (not unique) -> `explain` (3 matches) -> `affected` on the `web.ts` id | partial (2 retries) | 447 | grep 7 cmds / ~1.8k; graph lists the UI callers, while the break is on the callee side (`listMountSharees`) and in an authz test it never names | - |
| Q6 | blast | What depends on `BranchCard`'s `isPrimary`-gated disabled props; what breaks if the guard goes? (`2026-09-20-branch-ui-dogfood-defects.md`: "`main` is offered an Archive action (must be guarded - trunk)") | `branch_card.tsx:88-89`, `mount_branch_panel.test.tsx:166` | `affected BranchCard` | hit | 165 | grep 5 cmds / ~1.45k; graph names the breaking test file in 165 tokens | - |
| Q7 | flow | How does a merge gesture flow from `mount_branch_control.tsx` to `FsDoc.merge` / `mergeFsBranch`? (`2026-09-20-merge-carries-content-rootcause.md`: "`mergeFsBranch(main,b_ui)=\"merged\"`") | `handleConfirmMerge` -> `branchOps.merge` (`document_store.ts:398`) -> `mergeBranch` (:429) -> `loro_repo.ts:359 mergeFsBranch` | `path handleConfirmMerge mergeFsBranch` (no node) -> file entity (no directed path) -> `--undirected` | misleading | 102 | grep 3 cmds / ~500; graph's 4-hop path runs through the `loro-repo` package stub and an unrelated test file | **hit**: the file-entity directed path succeeds, `mount_branch_control.tsx -> document_store.ts -> LoroRepo -> .mergeFsBranch()` (43 tokens) |
| Q8 | flow | How does ownership get from the client's `claimOwner` to the server's persisted `__acl__`? (`2026-09-18-owner-mount-authz.md`: "Server ADOPTS a peer's `__acl__` write AUTOMATICALLY: `onDocUpdate` accepts a WRITE peer's ops") | `mount_store.ts:611 claimOwnership` -> `acl_sync_doc.ts:69 claimOwnerOnce` -> `server_repo.ts:104-134 buildServerRepo` (shared `DocManager` room doc) | `path claimOwner onDocUpdate` -> `--undirected` | miss | 81 | grep 9 cmds / ~2.8k; the link is CRDT sync into a shared doc instance, invisible to static edges | **partial**: the undirected path runs `AclDoc <- LoroRepo <- server_repo.ts -> AuthoritativeServer -> .onDocUpdate()`, naming `server_repo.ts`, where the wiring lives, but not the client side or the shared-doc mechanism |
| Q9 | flow | How does an `FsDoc` import event reach the fs-index view's dirty signal? (`2026-09-18-fsindex-delta-reactivity.md`: "Repurpose the post-import signal: `onReproject`->`onBranchImported`") | `fs_doc.ts:345 fireBranchImported`, `fs_index/backing.ts:107` registration and `onDelivering`, `fs_index_view.ts:123` `markDirty` subscribe | `path fireBranchImported markDirty` -> `--undirected` | partial | 81 | grep 7 cmds / ~3k; graph gives the endpoints and `fs_index_view.ts` but skips `backing.ts`, the real hop | - |
| Q10 | where | Where does `branchProvenance` map a loro `PeerID` to an actor profile? (`2026-09-20-branch-ui-dogfood-defects.md`: "`branchProvenance` looks up `actors.profile(String(source.op.peer))`") | `loro_repo.ts:419 LoroRepo.branchProvenance` | `query "where does branchProvenance map a loro PeerID to an actor profile"` | partial | 1,849 | grep 3 cmds / ~720; `.branchProvenance()` L419 is node 23 of 59, among layout and presence noise | - |
| Q11 | where | Where are `hasBranchDiffApi` and `classifyBranchDeltas`? (`2026-09-18-loro-repo-branch-metadata-consumer.md`: "a `hasBranchDiffApi(engine)` probe... `branching/divergence.ts` (re-homed heuristic, pure)") | `branch_diff_api.ts:112`, `divergence.ts:64` | `explain` each | hit | 377 | grep 2 cmds / ~600; tie | - |
| Q12 | where, base | Where is cross-realm authority state shared between the server instance and the prod bundle (the `globalThis` authority slot)? (`2026-09-18-prod-authority-realm-wiring.md`: "authority wiring is realm-local... but read cross-realm in the built prod bundle") | `loro_server_setup.ts:119 authoritySlot`, `server/prod_server.ts:234-250` | `query <the question>` | partial | 1,791 | grep 3 cmds / ~1.1k; seeds 10-11 of 12 are `prod_realm_split.prodstack.test.ts` (the guard test for this fix) and `server` in `prod_server.ts` (community `loro_server_setup.ts`), but buried among command-deer palette tests; no `authoritySlot` | - |
| Q13 | base | Branch checkout persistence and active-branch restore across reload in `LoroDocumentStore` (`2026-09-20-branch-ui-dogfood-defects.md`: "`_activeBranch = \"main\"` is an in-memory field on `LoroDocumentStore`... never persisted nor restored") | `document_store.ts:305 _activeBranch`, `:478 switchBranch`, `:552 persistActiveBranch`, `:584 restorePersistedActiveBranch` | `query <the topic>` | hit | 1,895 | grep 4 cmds / ~1.3k; first seeds `LoroDocumentStore`, `branch_checkout_persistence.test.ts`, `activeBranchStorageKey()`; `.persistActiveBranch()` listed | - |
| Q14 | base, blast | Mount collaboration arming and ACL gating across `armCollaboration`, `isCollaborative`, and the ACL-gated sync rooms (`2026-09-18-owner-mount-authz.md`: "`type:\"loro\"` is collaborative UNCONDITIONALLY (`mount_predicates.ts:20`)") | `mount_predicates.ts:20 isCollaborative`, `mount.ts:199 armCollaboration`, `mount.ts:223 rearmSync` | `query <the topic>` | hit | 1,833 | grep 5 cmds / ~1.3k; both named entities are seeds at the right lines, `mount.ts` listed; 2 of 8 seeds are md headings | - (`AclDoc` replaces a test-file seed) |

Tally: 7 hit, 5 partial, 1 miss, 1 misleading; with `source` conditions, 8 hit and 6 partial.
Graphify used about half of grep's output tokens, though it only locates while grep's totals include reading for full answers.
The pre-clean graph gives the same verdicts; only `query` seeds moved.

Graphify beats grep on named entities: `explain` gives definition, callers, importers, and tests in 100-300 tokens and catches stale devlog line numbers (Q3), and `affected` is a good test-impact list (Q6).
It does not beat grep on behaviors: why a guard exists (Q4), or a callee-side consequence (Q5).
The non-hits have two causes:
- **Missing static edges** from `dist/` resolution (Q7, part of Q4 and Q8), which `source` conditions fix.
- **Coupling that is not a static edge** (Q8's CRDT sync into a shared doc, Q9's subscriber hop through `backing.ts`), which no import config fixes; the wrapper's runtime-coupling block names `.observe`/`.subscribe` sites only in files the output already lists.

Topic `query` returns about 1.8k tokens, 30-60% unrelated: it hits on distinctive entity names (Q13, Q14) and is partial on concepts (Q12).

> NOTE(claude-opus-5-5/cdocs/graphify-weftwise-assessment): These questions name their entities and are graded against a grep ground truth, so they measure efficiency on grep's best case; discovery is measured in Value Beyond Grep below.

## Value Beyond Grep

On discovery tasks, where the agent does not yet know the entity names, does the graph find important code that grep does not (reach), or reach the same answer materially cheaper (efficiency)?

**Method** (design: proposal Phase 4; execution, arm prompt, per-arm usage, transcript summaries, A/B mapping, and the judged answers: `cdocs/devlogs/2026-10-08-graphify-value-beyond-grep.md`).
- 10 tasks sampled by a sonnet agent from weftwise problem statements (RFP stubs, Objectives), phrased as before investigation, and leak-checked; two run at their pre-investigation commit.
- Per task, two sonnet arms ran concurrently in throwaway worktrees with `cdocs/` and `_archive/` deleted, no git, no subagents.
  The graph arm had a capability card beyond the shipped skill, a graph-first guideline, and grep; its graph is the `source`-conditions graph (9,744 nodes, 25,774 edges at `2791713d`).
  The grep arm had everything except graphify (`rg`, scripts, installed `tsc`).
- A fresh blind opus judge per task graded both answers, normalized to `file:entity`, against the verified union of their items plus its own check.
  An important item only one answer found is that arm's **unique** item (its reach).
  Answers were capped at 15 ranked items, so unique counts partly measure what an arm ranked into its list, not only what it found.
- Graph-arm tokens include the card (about 1.2k), and its wall time includes `podman exec` (about 0.5 s per graph call); both are real costs.

| Task | Class | Task (source; code state) | Outcome (first judging) | Complete graph / grep | Unique graph / grep | Graph features used |
|---|---|---|---|---|---|---|
| c1 | concept | A revoked sharee's mount stays visible until refresh: where should client UI state react to a revoke? (`proposals/2026-09-05-graceful-unshare-unmount-rfp.md`) | grep (reach) | 9/13 / 11/13 | 0 / 2 | `query` 2, `explain` 3 |
| b1 | blast | What, beyond direct call sites, assumes the mount store's `enableRelationalMeta`/`requireRelational` seam's "relational" framing? (`proposals/2026-09-17-relational-meta-surface-rethink.md`; `3fbd7251`, the seam is gone at `2791713d`) | mixed; re-judge: graph better (reach) | 13/15 / 13/15 | 1 / 1 | `explain` 2 |
| b2 | blast | `AclDoc.revoke` is single-writer: what else assumes exactly one ACL authority if a second write path appears? (`proposals/2026-09-17-distributable-acl-authority-rfp.md`) | mixed | 11/15 / 10/15 | 4 / 3 | `explain` 7, `affected` 1 |
| t1 | tests | Which unit tests exercise the crash-recovery path (core, file, fingerprint write order; `classifyBoot`)? (`proposals/2026-09-21-engine-content-sync-robustness.md`) | tie | 5/5 / 5/5 | 0 / 0 | `explain` 1, `affected` 1 |
| t2 | tests | Which tests would catch a regression in branching content round-tripping through loro-multiplex's plain-`LoroDoc` `DocManager`/persistence? (`proposals/2026-09-16-loro-multiplex-branching-carrier-roundtrip-test.md`) | grep (reach) | 6/10 / 8/10 | 0 / 2 | `explain` 3, `query` 1 |
| x1 | cross-package | Across weft and loro-repo, what reads or writes the actor doc's profile fields, and which uses are ACL mechanism versus presentation? (`proposals/2026-09-17-actor-docs-to-host-app-rfp.md`) | mixed | 10/15 / 11/15 | 3 / 4 | `explain` 1, `affected` 1 |
| x2 | cross-package | What consumes loro-multiplex's generic transport: is loro-repo's `__fs__` its only production consumer? (`proposals/2026-09-17-branching-aware-transport-reconsideration.md`) | mixed | 11/13 / 12/13 | 1 / 2 | `god-nodes` 1, `affected` 1 |
| o1 | orientation | Brief me on `weft`: subsystems, hubs, how storage/sync, editor, and shell connect (`devlogs/2026-07-12-weft-architecture-reports-and-review.md`) | mixed | 13/20 / 14/20 | 4 / 5 | `god-nodes` 1, report sections 3, `explain` 15, `affected` 1 |
| d1 (synthetic class) | dead code | Across `weft`, what is exported but never imported? (`devlogs/2026-08-26-weft-code-smell-audit.md`) | mixed | 10/17 / 11/17 | 3 / 4 | `graph.json` scripting 10, no CLI call |
| y1 (synthetic class) | cycles | A build warns of a chunk cycle through `mounts/atoms.ts` and `mounts/index.ts`: which modules take part, and how far does it extend? (`proposals/2026-09-09-prod-build-circular-chunk-warnings.md`; `41b30188`, the fix's comment names the cycle at `2791713d`) | grep (reach) | 7/15 / 13/15 | 0 / 6 | Import Cycles section, `path` 2, `explain` 7 |

Code state is `2791713d` unless noted; the older-commit graphs had 10,327 / 27,153 (`3fbd7251`) and 8,287 / 20,647 (`41b30188`) nodes / edges, with every `./dist/`-exporting workspace package given the `source` condition.
Per-arm tokens and wall times are in the devlog; y1's arms started about 70 s apart (subagent limit), so its wall times are not comparable.

Tally over the 8 tallied tasks (d1 and y1 are the synthetic classes, kept outside):
- Outcomes, first judging: grep better (reach) 2, mixed 5, tie 1, graph better 0; no efficiency outcome either way.
- Re-judging: four tasks were re-judged blind by fresh opus agents with A and B swapped (c1, b2, b1, o1).
  c1, b2, and o1 reproduce; b1 flips from mixed to graph better (reach), crediting the graph arm's `document_store.ts` boot-race guards and rating `sharee_store_harness.ts` not relevant.
  So no arm reliably beats the other on any tallied task, and mixed is the usual outcome.
- Unique important items: graph 13, grep 19; completeness on important items: graph 78/106, grep 84/106.
  These are indicative: re-judges move them by one or two items per task.
- Wrong items and "would mislead" flags are not tallied: the misled flags swapped sides on both re-judged tasks that carried them (b2, o1), and o1's re-judge found a wrong item on the grep side as well.
- Cost: graph 659k tokens and 1,260 s, grep 642k and 1,056 s.

**Graph use.**
The arms used the graph lightly: graph calls per tallied arm were c1 5, b1 2, b2 8, t1 2, t2 4, x1 2, x2 2, o1 17.
b1 (blast radius) grepped before its first graph call despite the graph-first guideline, ran two `explain`s, and never ran `affected`, which the card lists for blast radius; t2 (tests) never ran `affected` either, which the card lists for tests that reach an entity.
The result measures sonnet with a card as it typically behaves, not graphify's best case on blast radius and tests.

**Attribution** (from the graph arms' transcripts, after unblinding).
Of the graph arms' 13 unique items:
- 4 came only from graph output: o1's four, from `god-nodes` and `explain`.
- 4 appear in graph output but were reachable without it: b1 `sharee_store_harness.ts` (also in the arm's own grep), b2 `subscribeRevocations` (read in `acl_doc.ts` before the graph call), b2 `broadcastServerUpdate` (named in the task, and read by the grep arm), and x1 `identity.test.ts` (listed by the arm's own grep first).
- 5 the arm found by grep or reading alone.

None came only from the wrapper's RUNTIME COUPLING appendix, and b1's re-judged unique item (`document_store.ts`) first reached its arm through grep.

**Scenario map.**

| Class | Unique important, graph / grep | Outcomes | Why |
|---|---|---|---|
| named-entity lookup (Usefulness, Q1-Q14) | not measured as reach | graph better on output tokens (Phase 2's metric, locating only) | `explain` gives definition, callers, importers, and tests in 100-300 tokens, about half of grep's output; on Phase 4's agent-level efficiency metric no task showed a win |
| transitive blast radius | 5 / 4 | mixed, mixed; b1's re-judge: graph better (reach) | `explain` neighbour lists put leads in front of the graph arm (`sharee_store_harness.ts`, `subscribeRevocations`), but its own grep and reads reached each too: one or two leads per task, mostly reachable by grep. Grep reached invariants stated in comments and orchestration with no edge to the named entity (`computeRedactionInstruction`, `revokeShareLink`). b1's arm never ran `affected` |
| orientation | 4 / 5 | mixed, on both judgings | The only cleanly graph-sourced finds: `god-nodes` and `explain` on hubs named subsystems grep's arm skipped (canvas editor, search index, tabs model, loro-repo's `FsIndexView`); grep's arm read module headers and found the shell composition (`MountsContainer`, `DocumentManager`). `god-nodes` is repo-wide, and it produced the graph arm's false claim that command-deer's `KeybindingService` is weft's keybinding layer. One task |
| cross-package dependents | 4 / 6 | mixed, mixed | `rg 'from "loro-multiplex'` lists importers as completely as `affected`; the extra finds on both sides came from reading, and the graph's one find present in graph output (`identity.test.ts`) its own grep listed first |
| tests covering a behaviour | 0 / 2 | tie, grep (reach) | Tests are identified by names and comments (`GAP A`, `LIVE-FORWARD`), which grep reads. t2's `explain` output listed the tests its arm missed (so did a later grep of its own), and the arm never ran `affected`, which Phase 2 found a good test-impact list (Q6) |
| concept discovery | 0 / 2 | grep (reach), on both judgings | `query` seeds on names; both arms reached the same core (an uncalled revoke handler, a status type with no revoked state), and grep's arm also found the boot-only detection path. One task |
| dead code (outside tally) | 3 / 4 | mixed | In-degree scripting over `graph.json` and a grep export scanner are equivalent methods; each found a different subset of about 17 dead exports |
| dependency cycles (outside tally) | 0 / 6 | grep (reach) | Not the graph win the design expected: Import Cycles lists only cycles of 5 files or fewer and counts `import type` edges, and the graph arm stopped there (plus one type-only edge, wrong). Grep's arm computed the 32-file value-import strongly connected component and the TDZ trigger |

Serendipity (after unblinding; commentary only): the graph output held items its arm did not use in t2 (three server-backed `__fs__` tests, one found only by the judge), o1 (`MountsContainer`, `DocumentManager`, `build_editor_extensions`), and y1 (`extension_builder`, `transclusion_helpers`, `open_link_under_cursor`).
The graph put its arm in the right neighbourhood more often than the arm used it.

**Reading.**
A graph-assisted agent behaves like a differently biased second searcher, not a better first one: its answer and a grep answer overlap on the core and diverge at the edges.
With no grep-vs-grep baseline this stays a hypothesis, since two grep runs may diverge as much.
The graph also brings its own errors: repo-wide hubs read as package hubs, and type-only imports read as runtime edges.
Its likely best case, untested at full use, is `explain` and `affected` around a named entity (blast radius, covering tests) and first orientation in a package.

**Guidance for `/cdocs:graphify`** (proposed skill text; not landed and untested: the blast-radius and tests bullets rest on Phase 2 and on what the arms' graph output held, not on a Phase 4 win):

```md
## When the graph helps

- Blast radius of a named entity: `explain` it and treat each neighbour (callers, importers, INFERRED calls, test files) as a lead, then `affected` it.
  Also grep the name: invariants stated in comments and orchestration with no static edge are grep-only.
- Tests covering a behaviour: run `affected` on the subject and read the tests it lists; also grep test names, `describe`/`it` strings, and comments.
- Orientation in a package: `god-nodes` (repo-wide: drop hubs outside the package), then `explain` the top hubs.
- Named entities: `explain` before reading the file.

When the output lists a file you have not read whose name fits the question, read it before answering.

## When to skip it

- Who imports a package: `rg 'from "<package>'`.
- Concepts with no entity name: grep the domain words; `query` matches names, not behaviour.
- Import cycles: GRAPH_REPORT.md lists only cycles of five files or fewer and counts `import type` edges; compute the strongly connected component over value imports.
```

Wrapper change this suggests (not landed): accept `god-nodes`, which the wrapper rejects today.
The stamp defect Phase 4 surfaced is under Candidates › Stamp ignore filter.

## Runtime Matrix

Median (min-max) seconds, 3 runs unless noted.
The structural post-edit adds an import of `snap` and a new caller of it in `packages/weft/src/lib/canvas/arrow.ts`, so topology changes.

| Case | Pre-clean | Cleaned |
|---|---|---|
| full build (raw `update`, empty dir) | 11.33 (11.31-11.39) | 9.60 (9.57-9.66) |
| post-edit, structural (wrapper) | 14.57 (14.49-14.61) | 11.84 (11.74-11.87) |
| post-edit, structural (raw `update`; candidate baseline) | | 11.14 (11.13-11.15) |
| post-edit, body only: no topology change (1 run) | | 9.03 |
| no-op, stamp hit (wrapper) | 0.85 (1 run) | 0.63 (0.60-0.67) |
| commit-only, stamp skip (1 run) | | 0.54 |
| fresh-worktree first query (copy plus `update`; `dist/` topology change) | 14.92 (1 run) | 11.88 (11.75-11.90) |
| fresh-worktree, kept-stamp prototype | | 0.93 (0.63-1.00) |
| fresh-worktree, `source` conditions (no topology change) | | 8.99 (8.90-9.06) |
| raw `query` / `explain` / `path` / `affected` (ranges within 0.03 s) | 0.74 / 0.69 / 0.76 / 0.27 | 0.50 / 0.46 / 0.50 / 0.23 |

About 3 s of the post-edit refresh is clustering, report, and html (`--no-cluster` 8.18 s vs 11.14 s; body-only 9.03 s vs structural 11.84 s).
The other 8 s is detection, the JS/TS parse with its symbol-resolution pass (mostly `_collect_js_symbol_resolution_facts`, per the audit), and the build.
`extract --timing` on its incremental path prices a changed-files-only refresh: detect 0.8, AST 0.3, build 0.8, cluster 1.0, analyze 0.1, export 0.4 (3.5 s).
No LLM call runs during `update`.

## Candidates

All rows are on `2791713d`; post-edit timings are raw `update`, against the 11.14 s raw baseline.

| Candidate | Full build | Post-edit | Check | Result |
|---|---|---|---|---|
| `"source"` export conditions (measured, not committed) | 9.63 (9.62-9.63), vs 9.61 (9.54-9.71) same-session baseline | 11.32 (11.20-11.42), vs 11.18 (11.11-11.32) | spot check, all 14 | 9,744 / 25,774. Q7 misleading -> hit, Q8 miss -> partial, Q4 blast radius 6 -> 35 entries, no regression |
| all markdown out | 9.50 (9.45-9.51) | 10.86 (10.80-10.89) | spot check, all 14 | No verdict change; the narrower `.claude/` + `AGENTS.md` variant was not run |
| tests, e2e, and demo out | 5.23 (5.22-5.28) | 6.27 (6.27-6.30) | spot check, all 14 | `imports` 6,527 -> 3,258. Q6 hit -> partial; Q4 and Q5 lose their tests; Q7 misleading -> miss |
| `*.json` out except `tsconfig*.json`, `package.json` | 9.57 (1 run) | | inventory | Removes only `.mcp.json` (3 nodes). All JSON out (9.17 s) cuts `imports_from` by 405 and `imports` by 175, so resolution inputs stay |
| output stages off (`--no-cluster` + `VIZ_NODE_LIMIT=0` + `NO_BACKUP=1`) | 7.05 (6.87-7.08) | 8.18 (8.16-8.24) | identity: **fails** | All from `--no-cluster` (the other flags: 11.13, 11.15), which writes raw extraction (no `built_at_commit`, 2,148 extra stub and dangling edges); Q8 flips miss -> misleading |
| `GRAPHIFY_MAX_WORKERS` 4 / 10 / 20 | 10.44 / 9.57 / 9.60 | 11.98 / 11.15 / 11.14 | identity: equal | The default of 20 is best |
| `extract --code-only`, incremental | 8.42 (1 run); no-op 4.51 | 3.63 (3.61-3.74) | spot check + fidelity | No verdict change. Against `update` it misses 59 code nodes and 114 code edges (56 `calls`, 37 `imports`, 17 `dynamic_import`, 4 `rationale_for`); with `source`, 41 and 97. From an `update`-built index it re-extracts all 1,275 files (10.03 s). No markdown |

**`source` conditions.**
The candidate puts `"source": "./src/<stem>.ts"` first in every `exports` entry whose `import` target is `./dist/<stem>.js`: `loro-repo` 4 entries, `loro-multiplex` 8, and `command-deer` 4 (no cross-package importer; consistency only).
Graphify ranks `source` first, so the graph gains 623 cross-package edges into `src/` (`weft` -> `loro-repo` 204, `weft` -> `loro-multiplex` 347, `loro-repo` -> `loro-multiplex` 72), identical with or without a built `dist/`.
It is inert for current tools, from reading configs and installed resolvers (builds/tests not run):
- Vite 7.3.0's default conditions exclude `source`, and none of the 13 vite (7), vitest (5), and playwright configs sets `resolve.conditions`.
- TypeScript 5.9.3 uses `moduleResolution: bundler` with no `customConditions`.
- `tsx` 4.21.0 (`start:prod`) has no `source` condition, and Node honours unknown conditions only with `--conditions`.
- ESLint's `eslint-import-resolver-node` ignores `exports`.

A future `customConditions` or `resolve.conditions` entry naming `source` would switch that tool to `src/`.

**Background refresh (scratch prototype).**
On a stale stamp, the wrapper answers from the existing index and starts `update` in the background, unless `.rebuild.lock` exists.
Over three edit/revert cycles, the first query took 0.47-0.56 s, queries during the refresh 0.31 s, and edit to fresh graph 11.27-11.55 s.
Every cycle's stale answer missed the edit (`explain gfyProbeSnap` found no node; `affected` on `geometry.ts::snap` lacked the new caller).
So it is right for unedited code and wrong for exactly what was just edited, and staleness spans everything edited since the last query-triggered refresh.
Graph writes are atomic (`write_json_atomic`), so no query reads a partial file.

> WARN(claude-opus-5-5/cdocs/graphify-weftwise-assessment): The prototype tests the lock file's existence, which is unsafe to land.
> A killed update leaves `.rebuild.lock` behind, so the prototype would never refresh again, and two calls can both launch an update in the roughly 0.3 s before Python takes the lock.
> A landing must probe the lock (`flock -n`, or the liveness of the PID it records).

`graphify watch` was not measured (`watchdog` is not installed); per the audit it is the same full rebuild per batch.

**Stamp kept across the copy (scratch prototype).**
When `built_at_commit` is an ancestor of HEAD, the wrapper writes at copy time the byte-identical `.stamp` it would write after a first update on that commit.
The first query takes 0.93 s (0.63-1.00) against 11.88 s, and worktrees without `built_at_commit` or with a code commit past it still update.
Residual risk: the copy carries whatever main's untracked and ignored files contributed (`dist/` today).
A landing should parse `built_at_commit` from the JSON rather than grep the file tail.

**Stamp ignore filter (known defect in the shipped wrapper, not fixed).**
`plugins/cdocs/bin/cdocs-graphify` drops ignored paths from its change list with `grep -vxF -e "$ign"`, passing every ignored changed path as one argument.
Past the kernel's single-argument limit (`MAX_ARG_STRLEN`, 131,072 bytes) `grep` fails with `E2BIG`, the `2>/dev/null` around the block hides it, and the change list comes out empty.
The stamp then equals the empty-change stamp (`<base> 8b137891...`), which is also a clean tree's stamp, so nothing looks wrong, and no later edit changes it: the worktree never refreshes again.
The stamp's base commit never advances (the wrapper reuses the old stamp's base and writes it back), so ignored-path changes accumulate over a worktree's life.

| Ignored changes since the stamp base, then a code edit | Update runs |
|---|---|
| 100 `cdocs/` deletions or additions (6.8 KB of paths) | yes |
| 2,500 deletions or additions (174 KB) | **no**; the stamp stays at the empty-change hash |

Repro: a scratch git repo, a stub `graphify` that logs `update` calls, `.graphifyignore` = `/cdocs/`, and a stamp taken on the initial commit.
On weftwise `main`, ignored-path churn into `2791713d` is 2.5 KB over 2 weeks, 52.5 KB over a month, and 127.4 KB over about six weeks.
So a worktree first queried six weeks ago and kept current reaches the limit, and an archive sweep crosses it at once (the Phase 4 worktrees, with 3,825 deleted `cdocs/` files, did).
Fix sketch, deferred pending the maintainer's decision on keeping graphify: select non-ignored paths in one pass (`git check-ignore --no-index --stdin -v -n`, keeping the `::` lines) or pass the list with `grep -f`; stop swallowing stderr there; advance the base to `HEAD` when writing a fresh stamp after a successful update.

## Verdict per Role

The bar: 3 s or less is flexible, 3-10 s is usable with discipline, and over 10 s means wait for upstream.
Every timing range is within 0.4 s, so no verdict sits on a boundary by noise.

| Role | Refresh cost | Usefulness | Verdict |
|---|---|---|---|
| Startup (base query, fresh worktree) | 11.88 s once per worktree; 8.99 s with `source`; 0.93 s with the kept stamp | base rows: 2 hit, 1 partial, about 1.8k tokens each | **Use now**: paid once per worktree, and about 1 s with the kept stamp. Prefer entity names to concepts in base queries |
| Reviewers (`explain`/`path` on changed entities, after commits) | 0.54 s commit-only; queries 0.23-0.50 s; at most one 11.8 s refresh | entity 4/4 hit; `affected` 1 hit, 2 partial; `path` 1 partial, 1 miss, 1 misleading, or 1 hit and 2 partial with `source` | **Use now** for `explain` and `affected`. Without `source`, grep cross-package chains; with it, `path` is a usable first pass that still misses runtime coupling |
| Implementers mid-edit | 11.84 s (11.74-11.87) blocking, once per edit batch; `explain` on a stamp hit 0.6 s | same | **Usable now with discipline**: `explain` before editing, as the skill directs, and batch post-edit questions behind one blocking refresh. **Flexible mid-edit use waits for upstream**: the whole blocking range is over 10 s. Background refresh trades the wait for staleness |

Value Beyond Grep leaves every verdict standing and narrows what "use" means: a second searcher next to grep, not a replacement (see its scenario map).

## Recommendations

- Keep the committed `.graphifyignore`, with markdown, `package.json`, `tsconfig*.json`, and tests in the graph; skip `--no-cluster`, `GRAPHIFY_VIZ_NODE_LIMIT=0`, `GRAPHIFY_NO_BACKUP=1`, and `GRAPHIFY_MAX_WORKERS`.
- **Add `"source"` export conditions to `loro-repo` and `loro-multiplex`** (`command-deer` optional).
  It is package metadata the app's build reads, so the maintainer decides and commits it; the main graph then needs one rebuild.
- Wrapper changes (not landed; a separate decision): **keep the stamp across the copy**, which removes the 12 s first query whenever main's graph is current; offer **background refresh as an opt-in mode only**, with a blocking escape for blast radius and a real lock probe.
- **Fix the wrapper's stamp ignore filter** (Candidates › Stamp ignore filter): a silent-staleness defect in shipped code, deferred pending the maintainer's decision on keeping graphify.
- File upstream, alongside the fork RFP: workspace imports resolved to unextracted `dist/` (draft below), and `extract --code-only`'s edge loss against `update`.

> NOTE(claude-opus-5-5/cdocs/graphify-weftwise-assessment): Overseer call: hold filing; the maintainer files.
> Draft:
>
> **Workspace imports resolve to unextracted `dist/` output, dropping cross-package edges**
> In a pnpm workspace whose packages export only built output (`"exports": {".": {"import": "./dist/index.js", "types": "./dist/index.d.ts"}}`, with `dist/` gitignored), `_package_entry_candidates` follows the `exports` targets.
> When `dist/` exists, the import resolves to a gitignored file that is never extracted, so the edge is dropped; when it does not exist, the import lands on the package's `ref_*` stub node.
> Either way the graph has no edges from consumers into the package's `src/` (here, none of the 623 such edges a `source` condition recovers, across three consumer/package pairs with 32, 53, and 7 importing files), so `path` and `affected` cannot cross package boundaries, and graph content depends on whether the package was built.
> A `"source"` condition works around it, since `_EXPORT_CONDITION_PRIORITY` ranks `source` first.
> Suggested fix: when an `exports` target falls under an ignored or unextracted path, try the source equivalent (via the package tsconfig `rootDir`/`outDir`, or `src/` with the same stem) before giving up.
> Graphify 0.9.61.

What would change the verdict:
- The fork RFP's fixes 1 and 2 (a manifest no-op gate and a JS/TS fact cache): at about 3.5 s per refresh, implementers move to the middle band, near the 3 s bar.
- `extract --code-only` reaching edge parity with `update` and reading `update`-built manifests, so the wrapper could use it at about 3.6 s.
- A runtime-coupling pass that names subscribers, for the remaining flow non-hits (Q8, Q9).
- LLM community labels (`graphify label`): community names here are hub file names (`label_communities_by_hub`), which weakens concept discovery and orientation; labelled communities were not tested (they need credentials and cost per relabel), and they might change those two rows.
- Distinguishing `import type` edges and listing longer cycles, which would make the precomputed Import Cycles an answer rather than a lead.

## Not Verified

- Base-query usefulness rests on 3 questions; the startup verdict leans on the runtime more than on usefulness.
- One judge graded every row, with no second grader.
- The `source` candidate was graded on a raw empty-dir build in a throwaway worktree, not through the wrapper on a rebuilt main graph; weftwise's builds and tests were not run with the change (its inertness is from reading configs and the installed tools' resolvers).
- The background-refresh prototype ran only with sequential queries, never with a concurrent editor writing during the refresh; the stamp-race reasoning is from the code.
- The kept stamp was not exercised against a main graph built from a dirty tree.
- Timings come from one container on a host with other load (1-minute load 0.9-4.3).
- Value Beyond Grep: one run per arm and 8 tallied tasks, 1-2 per class; orientation and concept rest on one task each, yet orientation is the graph's one cleanly attributed row.
- One judge per task, with four re-judged: one outcome flipped (b1, to graph better) and misled flags moved on two; no second judge on the rest.
- No grep-vs-grep baseline, so mixed cannot be told apart from run-to-run variance (overseer call: not run).
- The 15-item answer cap shapes unique counts.
- The graph arms used the graph lightly (four of eight made two graph calls; b1 and t2 never ran `affected`), and b1 and t2 were not rerun with the proposed guidance (overseer call), so the graph's best case on blast radius and tests is unmeasured.
- The arms were sonnet with a capability card, not the shipped skill text; the proposed guidance was not itself tested.

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
pk = lambda f: f.split("/")[1] if f.startswith("packages/") else None
sf = {n["id"]: src(n) for n in g["nodes"]}
x = Counter(f"{pk(sf.get(e['source'], ''))}->{pk(sf.get(e['target'], ''))}" for e in g["links"]
            if pk(sf.get(e["source"], "")) and pk(sf.get(e["target"], "")) and pk(sf.get(e["source"], "")) != pk(sf.get(e["target"], ""))
            and sf.get(e["target"], "").startswith(f"packages/{pk(sf.get(e['target'], ''))}/src/"))
print("xpkg", dict(sorted(x.items())))
PY
podman exec -i -u node weftwise bash -c "cat > $S/srcpatch.py" <<'PY'
import json, os, sys
for pd in sys.argv[1:]:
    p = os.path.join(pd, "package.json"); d = json.load(open(p))
    for k, v in list(d.get("exports", {}).items()):
        if isinstance(v, dict) and str(v.get("import", "")).startswith("./dist/"):
            stem = v["import"][len("./dist/"):].rsplit(".", 1)[0]
            if os.path.exists(os.path.join(pd, "src", stem + ".ts")): d["exports"][k] = {"source": f"./src/{stem}.ts", **v}
    open(p, "w").write(json.dumps(d, indent=2) + "\n")
PY
# the structural edit as a patch (import + new caller in arrow.ts)
x $W "f=packages/weft/src/lib/canvas/arrow.ts; sed -i '15i import { snap } from \"./geometry\";' \$f && printf '\nexport function gfyProbeSnap(v: number): number {\n  return snap(v, 8);\n}\n' >> \$f && git diff > $S/edit.patch && git checkout -- packages"
# 1. counts: build into an empty scratch dir (never the container default)
x $W "env GRAPHIFY_OUT=$S/out graphify update $W 2>&1 | grep Rebuilt"
# 2. ignore holds: nodes, edges, per-prefix zeros, relation counts, cross-package edges
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
# 5. dist/ presence: a stub loro-repo dist/ reproduces the main graph's edge count
x $W "mkdir -p packages/loro-repo/dist && : > packages/loro-repo/dist/index.js && : > packages/loro-repo/dist/index.d.ts
  env GRAPHIFY_OUT=$S/outB graphify update $W 2>&1 | grep Rebuilt; rm -rf packages/loro-repo/dist"
# 6. source conditions (not committed anywhere): counts, cross-package edges, Q7's directed path
x $W "python3 $S/srcpatch.py packages/loro-repo packages/loro-multiplex packages/command-deer
  env GRAPHIFY_OUT=$S/outC graphify update $W >/dev/null 2>&1; python3 $S/gcount.py $S/outC/graph.json | sed -n '1p;7p'
  env GRAPHIFY_OUT=$S/q graphify path mount_branch_control.tsx mergeFsBranch --graph $S/outC/graph.json; git checkout -- packages"
# 7. no collateral, then cleanup
x /workspaces/weftwise/main 'pgrep -af "[g]raphify (update|extract|watch)" || echo no-graphify; git worktree list; stat -c %y /var/cache/graphify-weftwise/graph.json
  for w in bocsync-bailout df-to-mount dogfood-sept logical-core loro-branching loro-repo-package; do
    echo $w $(git --no-optional-locks -C ../$w rev-parse HEAD) $(git --no-optional-locks -C ../$w status --short | wc -l); done'
x /workspaces/weftwise/main "git worktree remove --force $W && git worktree prune; rm -rf $S"
```

Expected:
1. `Rebuilt: 9731 nodes, 25160 edges` (a fresh tree has no `dist/`; see step 5).
2. `prefix` lines all 0, `md_nodes 654`, `imports=6527 imports_from=3764 calls=4741 re_exports=1345 dynamic_import=36 references=410 method=1244 implements=31`, `xpkg {}`.
3. Raw full build 9.60 s, `explain` 0.46 s, wrapper post-edit 11.84 s, each within ±25%.
4. `0` (the tree is clean again), then:
   - `query`: `Start: ['LoroDocumentStore', 'branch_checkout_persistence.test.ts', 'activeBranchStorageKey()', ...` (Q13, hit);
   - `explain`: `.mergeBranch()` at `packages/weft/src/lib/loro/document_store.ts L429`, with `<-- .buildBranchOps() [calls]` (Q1, hit);
   - `affected`: `mount_branch_panel.tsx`, `mount_branch_control.tsx`, `mount_branch_panel.test.tsx`, `dev.branch-ui.tsx` (Q6, hit).
5. `Rebuilt: 9731 nodes, 25121 edges` (the main graph's count).
6. `nodes 9744 edges 25774`; `xpkg {'loro-repo->loro-multiplex': 72, 'weft->loro-multiplex': 347, 'weft->loro-repo': 204}`; `Shortest path (3 hops):` `mount_branch_control.tsx --imports_from [EXTRACTED]--> document_store.ts --imports [EXTRACTED]--> LoroRepo --method [EXTRACTED]--> .mergeFsBranch()` (Q7, hit).
7. `no-graphify`; `git worktree list` shows `.bare`, `main` at `2791713d`, the six maintainer worktrees, and `gfy-floor`, which the last line removes.
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

**Value Beyond Grep floor.**
1. Graph: step 6 above builds the `source`-conditions graph the graph arms used at `2791713d` (`nodes 9744 edges 25774`); the older-commit counts are in the task table's note.
2. Records: this section holds the tasks, outcomes, and grades; the devlog holds per-arm summaries, transcript flags, the A/B mapping, pilot card fixes, the normalized answers, and the judge prompt.
3. Grades: re-judge any two tasks blind from the devlog's normalized answers and judge prompt, with a fresh agent and read access to that task's code state.
   Expect occasional disagreement (one of four re-judges flipped an outcome); record any disagreement next to the table.
4. No collateral: step 7's checks, plus `git worktree list` showing no `gfy-value-*` worktree.
