---
review_of: cdocs/proposals/2026-10-08-graphify-overhaul.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T09:35:00-07:00
task_list: cdocs/graphify-overhaul
type: review
state: archived
status: done
tags: [fresh_agent, runtime_validated, architecture, minimalism, cli_contract]
---

# Review: Graphify overhaul, round 2

> BLUF: Accept.
> All four round-1 blockers are resolved, and the design follows the maintainer's direction.
> A run against real graphify 0.9.61 in the lace container confirms the copy-seed premise (node paths are relative).
> It also shows that three pieces of the wrapper are unnecessary or wrong as written, and all three fixes remove text: drop the `cdocs/` purge step (`update` already evicts `.graphifyignore`d nodes), drop or rekey the stamp (`git status --porcelain` misses repeat edits), and delete `.graphify_root` from the seed copy (otherwise the first update keeps nodes for files deleted on the branch).
> Several Background, D4, D9, and Edge Case sentences about `update` are false on 0.9.61 and should be corrected or deleted before Phase 2, so the implementer does not build tests around them.

## Summary Assessment

The proposal replaces the overseer-run `graphify-scope` with `code-query`, a thin wrapper that each code-reading agent runs.
The wrapper gives each worktree its own index, copied from the main graph, and passes `query`/`explain`/`path`/`affected` through to graphify.
The revision addresses round 1 cleanly and stays close to the maintainer's direction: a copy-seed, an incremental update, passthrough, no lock, the observe/subscribe grep with a TODO, and `cdocs/` excluded through `.graphifyignore`.
Container checks answer most of Phase 1 now.
They show the wrapper has more parts than it needs: the purge step and most of the "update never prunes" reasoning describe behavior 0.9.61 does not have.
Verdict: **Accept**, with the action items below applied as text edits before or during Phase 2.

## Round 1 action items

| R1 item | Status |
|---|---|
| 1 [blocking] no fresh agent writes a shared index | Resolved: per-worktree indexes (D3); passthrough uses `--graph`, so query side effects also stay in the worktree (verified below). |
| 2 [blocking] accurate lace D3 NOTE | Resolved (Phase 4). Drop "with `--force`" per F2. |
| 3 [blocking] runtime-coupling action, accurate Phase 4 NOTE | Resolved: appended `.observe`/`.subscribe` hits, the skill's "floor, not the ceiling" line, and a Phase 4 NOTE that names what is kept and what is dropped. |
| 4 [blocking] transcript check on the dispatcher, positive control, marker on every line | Resolved (Verification step 4). |
| 5-10 [non-blocking] | All addressed: Summary states the every-round `stale-index` skip; the refined query comes back in the report; the skill has no overseer bullet and passing lives in the rule line; the live run is a one-round iterate; the host stub is time-boxed; Phase 1 checks D5; there is a `[seed: set\|empty]` tag. |

## CLI verification (graphify 0.9.61, lace container)

All checks ran in container temp dirs on tiny fixtures, plus one build of the real repo into a temp `GRAPHIFY_OUT`.
`/var/cache/graphify` was inspected but not written; `git status` on the repo stayed clean, and the temp dirs are removed.

**Confirmed:**
- `graphify update <path>` accepts only `--force` and `--no-cluster`; `update --code-only` exits 2 (`unknown update option`).
  The help text reads "re-extract code files and update the graph (no LLM needed)".
- `update` also builds AST heading nodes for markdown (`extractors/markdown.py`; `watch.py` `_rebuild_code` "Include document files that have AST extractors").
  On a fixture, `cdocs/x.md` and `README.md` became graph nodes with no LLM involved.
  On the real repo, `cdocs/` is 6637 of 7375 nodes (90%), which strongly supports D9.
- `.graphifyignore` is honored by `update`, and nodes that are already in the graph and now ignored are evicted on the next plain `update`, without `--force` (fixture: 10 to 7 nodes; source comment #2495: "evict on every rebuild").
- `--graph <path>` works on `query`, `explain`, `path`, and `affected`.
  The query side-effect file (`cache/last_query_stamp`) is written next to `--graph`, not under `$GRAPHIFY_OUT`.
- Node `source_file` values and `manifest.json` keys are relative; `.graphify_root` holds the absolute scan root.
  A copied index updates correctly in a sibling worktree, and the main graph is unchanged.
- The CLI `update` is a full-corpus AST pass with a per-file cache (`changed_paths=None`), not a changed-files pass.
  It prunes nodes for deleted files, except in the first update after a copy (F3).
- `update` takes a blocking per-output-dir `flock` (`_rebuild_lock(out, blocking=True)`), so same-worktree callers serialize inside graphify.
- `extract <path> --code-only` exists but is not needed. There is no user-facing `--exclude` flag (only `--exclude-hubs`), as the proposal says.
- The container's `~/.claude` has no graphify skill or `hook-guard` (D5).
- Timing on clauthier: a cold full build into an empty dir and a warm re-update both take about 2.4 s.

**Not confirmed:** concurrency behavior beyond reading the source; timing at weftwise scale; macOS portability of the wrapper; behavior with an LLM backend configured (none is set, and the `update` path does not call one).

**Environment finding:** `/var/cache/graphify` currently holds a 73-node fixture rooted at `/tmp/gfx-trunc2-340495/src` (`.graphify_root`, written 2026-09-23 13:37), left by the prior workstream's truncation test.
This is the shared-index overwrite D3 removes, seen in practice.
It also means the live run's precondition ("a built `/var/cache/graphify`") is false today.

## Section-by-Section Findings

### F1 [non-blocking, removes a step] Wrapper "Purge `cdocs/`" is unnecessary, and harmful without the ignore line

With `cdocs/` in `.graphifyignore`, a plain `update` evicts inherited `cdocs/` nodes (verified), so the grep and forced rebuild never do anything useful.
Without the line, every `update` re-adds `cdocs/` markdown nodes, so the grep matches on every call and the wrapper runs a forced rebuild every time, which never converges.
Delete the step, its test case, the "forced code-only rebuild form" Phase 1 item, and D9's "Pre-exclusion graphs" paragraph down to one sentence: a plain `update` after the line lands evicts old `cdocs/` nodes.
Rule changes already prompt consuming projects to re-run `/cdocs:init` through the SessionStart freshness hook, which adds the line, so the missing-line case needs no wrapper machinery.

### F2 [non-blocking, corrects text] `update` claims that are false on 0.9.61

These sentences would lead the implementer to write tests for behavior that does not exist:
- Background "Pruning: `update` does not remove nodes for deleted files", D9 "`update` never prunes", and Edge Cases "Deleted files: `update` keeps their nodes": all false for the CLI `update` (F3 covers the one exception).
- D9 "Code-only updates alone would add no new markdown nodes" and Edge Cases "`.graphifyignore` missing the `cdocs/` line ... add no markdown nodes": false.
  `update` graphs markdown headings, so the ignore line is the only thing keeping `cdocs/` out, not a belt-and-braces measure.
- Edge Cases "Docs-heavy repos (clauthier): code-only updates graph the TypeScript and shell, not the markdown skills": false.
  Skill markdown is graphed as heading structure.
- D4: collapse to one sentence: `graphify update <toplevel>` is AST-only on 0.9.61 (`--code-only` is rejected), so no markdown edit ever triggers LLM extraction.
  Drop `$CODE_ONLY` from the sketch and the D4 item from Phase 1.
- Phase 4 lace NOTE and D9: the operator's one-time main-graph refresh needs no `--force`.
- Background `update <path>`: "re-extracts changed files only" should read "re-extracts all code with a per-file cache".

### F3 [non-blocking, one line] Seed copy must drop `.graphify_root`

The copied `.graphify_root` points at the main checkout, and the first `update` in the worktree resolves stored paths against it.
Nodes for files deleted or renamed on the worktree's branch therefore survive the first update.
A second update prunes them, but the stamp keeps a reviewer's unchanged tree from ever triggering a second update.
Verified: copy as-is gives 6 nodes after update 1 (including the deleted `src/b.ts`) and 4 after update 2; copy with `.graphify_root` removed gives 4 after one update.
In the sketch, add `rm -f "$tmp/.graphify_root"` after the `cp`, and replace the D3 WARN with this one sentence (relative paths are confirmed, so the `extract` fallback is moot).
This also covers the container's current fixture seed, whose root no longer exists.

### F4 [non-blocking, removes or fixes a step] The stamp misses repeat edits

`git status --porcelain` prints ` M src/a.ts` whether the file was edited once or ten times.
An implementer who edits an already-dirty file and then `explain`s it gets the index as of its first edit until it commits.
`update` takes about 2.4 s on clauthier, cold or warm, so the stamp saves little here.
Preferred: drop the stamp, its file, and its test case, and run `update` on every call.
If Phase 1 measures `update` as materially slower on a weftwise-sized tree, key the stamp on `git diff HEAD` plus `git ls-files -o --exclude-standard` instead of porcelain status.

### F5 [non-blocking, removes text] Smaller trims

- The WARN on locking: graphify serializes `update` per output dir (confirmed in source), so the wrapper's "no lock" is safe; replace the WARN with one clause in Edge Cases.
- `CODE_QUERY_MAIN_OUT`: `GRAPHIFY_OUT` already overrides the main-graph location, so drop the extra variable.
- `--budget 2000` is `query`'s default; drop it from the skill draft, the sequence diagram, and the role table.
- Edge Cases "Main checkout is the caller": true on the host only.
  In the container, `GRAPHIFY_OUT` names `/var/cache/graphify` as the main graph, so the main checkout gets its own copy like any worktree.
  Say "on the host".

### F6 [non-blocking] Live-run precondition

The devcontainer live run needs `/var/cache/graphify` rebuilt from the repo after `.graphifyignore` lands: `graphify update /workspace/clauthier/main` with the baked `GRAPHIFY_OUT`, about 2.4 s.
Add this as the live run's first step; today the run would seed every worktree from an unrelated fixture.

### Minimalism

The design matches the maintainer's direction, and nothing in it goes beyond that direction other than the purge, the stamp, and `CODE_QUERY_MAIN_OUT`.
F1, F4, and F5 remove those.
With them removed, the wrapper is availability, path discovery, seed (copy, drop root, rename), `update`, passthrough, and the coupling grep, which fits comfortably in about 80 lines.
The skill draft, rule line, and iterate section are lean, and each duty is stated once.

## Verdict

**Accept.**
The architecture is settled and correct.
The findings are text corrections and step removals, backed by verification against the real binary, and none reopens a decision.
Apply F1 through F5 as edits to the proposal before Phase 2 starts (or have the implementer record them as Phase 1 results and implement accordingly), so the wrapper and its tests are built against 0.9.61's real `update` behavior.

## Action Items

1. [non-blocking, before Phase 2] Delete the wrapper's purge step, its test case, its Phase 1 item, and most of D9's "Pre-exclusion graphs" paragraph (F1).
2. [non-blocking, before Phase 2] Correct or delete the false `update` claims in Background, D4, D9, Edge Cases, and the Phase 4 lace NOTE. Drop `$CODE_ONLY` and the D4 Phase 1 item (F2).
3. [non-blocking, before Phase 2] Add `rm -f "$tmp/.graphify_root"` to the seed, assert in the test that the seed has no `.graphify_root`, and replace the D3 WARN (F3).
4. [non-blocking, before Phase 2] Drop the stamp (preferred), or key it on `git diff HEAD` plus untracked files (F4).
5. [non-blocking] Replace the lock WARN with one clause, drop `CODE_QUERY_MAIN_OUT`, drop `--budget 2000`, and qualify "Main checkout is the caller" as host-only (F5).
6. [non-blocking] Make "rebuild `/var/cache/graphify` from the repo" the live run's first step (F6).
7. [non-blocking] Phase 1 shrinks to: time `update` on the target repo (for F4) and confirm the coupling grep's path extraction against real `query`/`explain`/`affected` output formats (`Source: src/a.ts L2`, `src/a.ts:L2`).

## Questions for the maintainer

1. When a consuming repo's `.graphifyignore` lacks `cdocs/`, what should `code-query` do?
   (a) nothing: the `/cdocs:init` re-run prompted by the rule change adds the line (recommended);
   (b) print one stderr line naming `/cdocs:init`, then proceed;
   (c) skip `update` and query the seed as-is.
2. The stamp:
   (a) drop it; `update` costs about 2.4 s per call on clauthier (recommended);
   (b) keep it, keyed on `git diff HEAD` plus untracked files.
