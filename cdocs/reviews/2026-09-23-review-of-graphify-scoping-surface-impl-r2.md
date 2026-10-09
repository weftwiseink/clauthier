---
review_of: cdocs/devlogs/2026-09-23-graphify-cdocs-integration-full-send.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-23T14:20:00-08:00
task_list: code-graph/cdocs-integration
type: review
state: archived
status: done
tags: [fresh_agent, rereview_agent, runtime_validated, fixture_verified, graphify, scoping, recall_parity, cli_reconcile]
---

# Review: Graphify scoping surface (Phase 2 implementation), round 2 (reconciled to real graphify 0.9.61)

> BLUF(claude-opus-4-8/code-graph/cdocs-integration): ACCEPT. The iteration-2 reconcile lands the correct real-CLI contract: the dependent set now comes from `affected "<symbol>"` (reverse traversal) fed by `explain "<basename>"` `[contains]` symbols, parsed from PLAIN TEXT, over a resolved-and-stat'd `--graph` path. I reproduced the host suite (43 passed, 0 failed), verified the awk/grep parsing LINE-FOR-LINE against the real `affected-output.txt` / `explain-file-contains.txt` fixtures, and confirmed every floor branch, D4 CLI-only compliance, and scope discipline hold in the reconciled code.
> The four live-run defects are genuinely fixed and the known limitations degrade additive-safely.
> One accepting-round SHOULD-FIX: the `explain` ~20-connection truncation (limitation a) is noted in-code but never surfaced in the brief the reviewer reads, so a god-node changed file silently under-lists dependents with no round-specific signal. Additive-safe, so not blocking. Nits enumerated.

## Summary Assessment

The reconcile corrects a genuine functional defect: the shipped helper assumed `explain <target> --json` and would have skip-scoped or mis-targeted against every real graphify invocation. The reconciled helper implements the real pipeline (changed file -> `explain "<basename>"` -> `[contains]` symbols -> `affected "<symbol>"` per symbol -> union dependent paths - changed files), parses graphify's plain-text output, and resolves the graph path through a precedence chain (`--graph`/`--index` -> `CDOCS_GRAPHIFY_GRAPH` -> `GRAPHIFY_OUT` -> `/var/cache/graphify/graph.json` -> `graphify-out/graph.json`), stat'ing exactly the file it passes to `--graph` so staleness can no longer false-skip against a hard-coded path. Quality remains high: the graphify-shape coupling is confined to one clearly-marked block (D4), the additive-only / skip-scope / AID / CRDT-guard disciplines are enforced mechanically, and scope stayed exactly at the helper + reviewer wiring + tests. The single most important finding is that the primary residual (the `explain` truncation) is documented in-code but not surfaced at the point of consumption, which is a recall-safety honesty gap worth closing though it fails additive-safe.

## Verification performed (empirical, reproduced not trusted)

- **Host test suite.** `bash plugins/cdocs/scripts/test-graphify-scope.sh` -> `RESULTS: 43 passed, 0 failed`. All nine groups green: flag-off (sentinel-proven zero graphify calls), scoped-brief shape, and the missing-binary / missing-index / stale-index / engine-error / CRDT-near-empty / empty-set fallbacks, plus the healthy co-surfaced-observe case. New reconcile assertions confirm the `explain`->`affected` pipeline fires in order, that `affected` is queried on a SYMBOL label parsed from `explain` (not a basename: `affected renderWidget()`), and that a self-referential dependent path is dropped.
- **Parsing verified LINE-FOR-LINE against the REAL fixtures** (not just the stub):
  - `explain` `[contains]` extraction (`awk -F' \[contains\]' ...`) run on the real `explain-file-contains.txt` correctly pulled every `--> <label> [contains] [EXTRACTED]` symbol (convertAgent(), main(), parseFrontmatter(), ...) and dropped the `[imports_from]` and "Grouped by file" lines.
  - `affected` path extraction (`grep -oE '[^[:space:]]+:L[0-9]+' | sed 's/:L[0-9]+$//'`) run on the real `affected-output.txt` correctly yielded the deduped dependent path (`build-opencode.ts` from L244 + L345), and the header lines (`Relations:`, `Depth: 2`, `No affected nodes found.`) yielded no path token, so the empty case parses to an empty set (not a false dependent).
- **D4 (no raw `graph.json` ingestion).** `grep` confirms `$graph`/`$index` is referenced only by `[ -f "$graph" ]`, `stat -c %Y "$graph"`, and as the `--graph "$graph"` value passed to `explain`/`affected`. Never `cat`/`jq`/`read`. Graph data enters solely through the two subcommands inside the isolated block. **CLI-subcommands only, confirmed.**
- **Live E2E is the overseer's cited artifact.** `live-e2e-proof.txt` shows `brief --enable --files mod_a.ts` -> `SCOPE-STATUS: scoped`, `SCOPE-DEP-COUNT: 2`, set `{mod_b.ts, mod_c.ts}` (correct multi-hop across the coupled fixture), AID caveat + observe channel + CLI follow-ups present; flag-off -> `disabled`; missing index -> `skip-scope`. I did not re-run graphify (absent on host; a dispatched agent cannot dispatch ablate). Treated as the overseer's validation-of-record.

## Section-by-Section Findings

### Reconcile defect-fix 1-4: real CLI contract (the point of iteration 2)

Each of the four live-run defects is fixed and matches the fixtures:

1. **`affected` for the dependent set.** `graphify_affected_paths` (128-137) runs `affected "<symbol>"` (reverse traversal = blast radius), not `explain --json`. Confirmed against `affected-output.txt`. **Correct.**
2. **Plain-text parsing.** No `--json` anywhere (help confirms `--json` exists only on `god-nodes`/`diagnose`); awk/grep/sed parse text. **Correct.**
3. **Symbol targets, not basenames.** The pipeline derives symbols via `explain "<basename>"` `[contains]` (109-122) then queries `affected` per symbol (143-166). Test asserts `affected renderWidget()`, not a basename. **Correct.**
4. **Graph-path resolution + staleness coherence.** `resolve_graph_path` (93-107) yields the actual file, passed via `--graph` to both subcommands AND stat'd for staleness (231). The stat'd file == queried file, so the prior hard-coded-path false-skip is gone. **Correct.** `--graph` matches graphify's real flag (help: `--graph <path>` on both `explain` and `affected`).

**Non-blocking, verified.**

### Floor branches (verification-floor items 1-4): all hold in the reconciled code

- flag off -> `skip "disabled"` (203), before any binary/index probe; test 1 sentinel proves zero graphify calls;
- no changed files -> `skip skip-scope no-changed-files` (221);
- missing binary -> `no-binary` (224); missing index -> `missing-index` (228); stale index -> `stale-index` (235);
- engine error -> `engine-error` (248), reached only when a subcommand exits nonzero (rc captured through `graphify_symbols_for_file` -> `graphify_dependents` -> `cmd_brief`);
- CRDT near-empty trigger -> `crdt-near-empty-trigger` (272-274), fires when `dep_count <= near_empty` AND `site_count > 0`;
- empty set -> `empty-set` (276-278).

`skip()` (59-67) emits only the labeled `SCOPE-STATUS:`/`SCOPE-REASON:`/`SCOPE-FALLBACK:` markers plus an explicit "ADDITIVE fallback, not a narrowing" instruction and `exit 0`. Nothing it emits can narrow context. The scoped brief (281-314) never presents the set as exhaustive (`NOT exhaustive` header 291, standing AID caveat 302-306), always co-surfaces the observe/subscribe channel (294-300) including the "0 sites found (still not a guarantee)" line, and carries the CLI follow-ups. Live proof shows all of this in real output. **Non-blocking, verified.**

### Known limitations (task item 4): recall-safety assessment

- **(a) `explain` ~20-connection truncation -> under-listed `[contains]` symbols -> missed dependents.** Real: `explain-file-contains.txt` shows 29 connections with `... and 9 more` after 20. A god-node changed file therefore under-lists its symbols, so some `affected` queries never run and some dependents are dropped. Degradation is additive-safe (AID caveat + "fall back to the unscoped sweep" stand; recall floor = unscoped baseline) and there is an in-code NOTE (112-113). **BUT the truncation is invisible in the brief the reviewer reads** (`grep` confirms the helper never detects `... and N more` nor surfaces it). On a hub file the dependent set is materially more incomplete than the generic caveat implies, with no round-specific honesty signal. See SHOULD-FIX 1. **Additive-safe -> accepting-round, not blocking.**
- **(b) Unknown node exits 0 (`No unique node match` / `No affected nodes found.`).** Live proof confirms `affected "doesNotExist999()"` -> `exit=0`. `graphify_affected_paths` gets rc=0 and no `:L<n>` tokens -> empty, so one unknown changed file yields empty rather than an engine-error skip of the whole round. **Correct.** Residual: the live proof exercised the exit code on `affected`, not on `explain`; if `explain` on an unknown basename exits nonzero, that one file would engine-error-skip the whole round (still additive-safe: unscoped fallback = baseline). See nit 2.
- **(c) Basename input-exclusion over-drop.** Line 258 still drops a resolved dependent whose basename matches a changed file's basename, in any directory. This is now a JUSTIFIED tradeoff, not the open r1 nit-1: the fixtures prove graphify 0.9.61 emits BARE BASENAMES (`build-opencode.ts:L244`, `mod_b.ts:L1`), so a full-path-only comparison would fail to self-drop the changed file. Basename comparison is required for the self-drop to work against basename-only output. The cross-dir collision residual persists (and the dependent set itself is basename-only, so monorepo duplicate-basename dependents are ambiguous in the brief) but that is a graphify output-granularity limit the helper faithfully passes through. See nit 3.

### D4 isolation and scope discipline (task items 2, 6)

The graphify-shape coupling is confined to the four functions in the marked block (69-166): `resolve_graph_path`, `graphify_symbols_for_file`, `graphify_affected_paths`, `graphify_dependents`. `cmd_brief` downstream operates only on plain file-path strings (dedup, input-exclusion, rendering). A future adapter/MCP swap is a real one-block change. **D4 verified.**

Scope: `git log` for the helper shows exactly four commits (feat `07af3d4`, test `d7d6fca`, reconcile-fix `10e8f71`, reconcile-test `bb2b873`); the reconcile touched only `graphify-scope.sh`, `test-graphify-scope.sh`, and `reviewer.md` (one line, correctly re-led on `affected` with the plain-text/no-`--json`/never-raw-`graph.json` note). No Phase 1 meter, Phase 3 gate, implementer/judge roll-out, librarian, or adapter leaked in. `iterate/SKILL.md` wiring (flag DEFAULT OFF, `SCOPE-STATUS: scoped` verbatim-paste vs `skip-scope`/`disabled` no-brief-plus-labeled-note) is intact. **No over-build. Verified.**

## Continuity with round 1

r1 (ACCEPT, `2026-09-23-review-of-graphify-scoping-surface-impl-r1.md`) reviewed the ASSUMED-CLI code and correctly deferred the shape reconciliation to the live run. This round reviews the reconciled result. Disposition of r1's four action items:

1. **Reconcile assumed `explain <basename> --json` shape (r1 AI-1):** DONE and verified against real fixtures.
2. **Tighten basename input-exclusion (r1 AI-2 / nit-1):** resolved by evidence, not code change: real graphify emits basenames, so basename comparison is the correct call; residual documented (nit 3 here).
3. **`stat -f %m` fallback for non-GNU hosts (r1 AI-3 / nit-2):** NOT addressed; carried forward (nit 4).
4. **`--symbols` pointer in the iterate skill (r1 AI-4 / nit-3):** `--symbols` exists as a helper flag (205-245) but is still not pointed at in the skill's Graphify-scoping section; minor.

## Verdict

**Accept.**

The reconcile lands the correct real graphify 0.9.61 contract, the host suite reproduces green (43/43), the parsing verifies line-for-line against the real fixtures, every floor branch and D4/scope discipline hold, and all three documented limitations degrade additive-safely. The one recall-safety honesty gap (truncation invisible in the brief) is real but fails safe, so it is an accepting-round should-fix, not a blocker. The overseer's live E2E is the cited validation-of-record; on its strength the proposal may flip to `implementation_accepted` per the devlog's Open Todos.

## Action Items

1. [should-fix] Surface `explain` truncation at the point of consumption. Detect the `... and N more` marker in `graphify_symbols_for_file` and (a) emit a per-round brief line (e.g. `SCOPE-TRUNCATED: <file> symbol list partial (N more)`) so the reviewer sees that THIS round's dependent set is extra-incomplete, and/or (b) promote the in-code NOTE (112-113) to an explicit `KNOWN-LIMITATION` block. Additive-safe, so accepting-round.
2. [nit] Confirm `explain`'s exit code on an unknown/absent changed-file basename in a future live run. The live proof verified exit 0 only for `affected`; if `explain` exits nonzero on unknown, one unknown changed file engine-error-skips the whole round (additive-safe, availability not recall).
3. [nit] Anchor the `[contains]` extraction to the `--> ` connection-line prefix. The current `/\[contains\]/` match extracts from ANY line containing the literal `[contains]` (demonstrated: the fixture's `### CMD ... [contains] symbols` annotation was parsed as a "symbol"). Real `explain` output has no such lines and the failure is harmless (a bogus symbol -> `affected` -> `No unique node match` -> empty), but anchoring to `^[[:space:]]*-->` is strictly correct.
4. [nit] Add a `stat -f %m` fallback (carried from r1 AI-3) so staleness detection is not silently disabled on non-GNU/BSD hosts, where both mtimes resolve to 0 and a stale index would be scoped. Target is the Linux devcontainer, so not a live risk; portability hardening only.
5. [nit] Add a one-line `--symbols` pointer in `iterate/SKILL.md`'s "Graphify scoping" section (carried from r1 AI-4) for operators who want to bypass the file->explain derivation.

## Questions for the maintainer (multiple choice)

Judgment calls the review surfaces rather than blocks on:

1. **Truncation surfacing (AI-1):** how should a truncated `explain` be handled?
   - (a) Surface a per-round `SCOPE-TRUNCATED` brief line only (my recommendation: honest at the point of consumption, zero recall cost).
   - (b) On truncation, force skip-scope for that god-node file (most conservative; loses the partial dependent set the reviewer could still use).
   - (c) Leave as-is (generic AID caveat covers it): accept the silent under-list.
2. **Near-empty threshold default (=1), carried from r1:** keep `1`, use `0`-only, or `<=2` on this CRDT-heavy codebase, or decide from the live ablate corpus?
   - (a) Keep `1`. (b) `0` only. (c) `<=2`. (d) Decide from the live corpus.
