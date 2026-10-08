---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T13:10:00-07:00
task_list: cdocs/graphify-overhaul
type: devlog
state: live
status: wip
part_of: cdocs/devlogs/2026-10-08-graphify-overhaul.md
tags: [graphify, claude_skills]
---

# Graphify Overhaul Implementation: Devlog

> BLUF: Iterate round 1 implementation of [`2026-10-08-graphify-overhaul.md`](../proposals/2026-10-08-graphify-overhaul.md), Phases 1-5, in worktree `graphify-overhaul`.

## Objective

Implement the proposal: `cdocs-graphify` replaces `graphify-scope`, `/cdocs:graphify` skill and rule line, `graphify_base_query` wiring, prior proposal superseded, host stub verification, and the weftwise ablation once its container is ready.

## Scratchpoint

- next_steps: Phase 3 base-query wiring.
- graphify_base_query:
- important_files: `plugins/cdocs/bin/graphify-scope`, `plugins/cdocs/hooks/tests/graphify-scope.test.sh`, `.github/workflows/cdocs-hooks.yml`, `plugins/cdocs/skills/iterate/SKILL.md`, `plugins/cdocs/agents/reviewer.md`
- callouts:
  - decision: dispatched mode; the overseer owns the top-level devlog.

## Plan

1. Phase 1: time `update` and check output path formats against real graphify 0.9.61 in the `clauthier` container.
2. Phase 2: tests first, then `bin/cdocs-graphify`; delete old script and test; CI, READMEs, `.gitignore`, `.graphifyignore`.
3. Phase 3: skill, rename, rule line, devlog and iterate skills, reviewer, init, README, `CLAUDE.md`.
4. Phase 4: supersede notes on the two prior proposals.
5. Phase 5: host stub run; weftwise ablation if prerequisites pass.

## Testing Approach

TDD for the wrapper: `cdocs-graphify.test.sh` against a `graphify` stub, written before the script.
Docs changes are checked by the removal greps, `npm run test:rules`, and `npm run test:opencode`.
End-to-end behavior by the proposal's host stub run.

## Implementation Notes

### Phase 1: CLI reconciliation (graphify 0.9.61, `clauthier` container)

Both items confirmed; scratch dirs removed afterwards.

- **Output path formats** (tiny 3-file TS repo):
  - `query`: `NODE x [src=src/app/view.ts loc=L2 ...]`, `EDGE ... at=src/app/consumer.ts:L2`; header names `graphify-out/graph.json`.
  - `explain`: `Source:    src/lib/atoms.ts L2`, connections end `src/app/consumer.ts:L1`.
  - `affected`: `- useMount() [calls] src/app/consumer.ts:L2`.
  - `path`: labels only (`renderView() --calls [EXTRACTED]--> useMount()`), no file paths, so the coupling section never fires on `path`.
  - Extraction: `grep -oE '[A-Za-z0-9_./@+-]+\.[A-Za-z0-9]+'` yields the bare relative path from each form (`src=`, `at=`, `:L2` drop out); file-less labels such as `consumer.ts` are filtered by an existence test; `graphify-out/` paths are excluded.
- **`update` at weftwise scale** (`git archive` of weftwise `1caa585d`, 1228 TS files, 16129 nodes, in the `clauthier` container): cold 13.1 s, warm no-change 11.0 s, one-file edit 11.2 s; `--no-cluster` 10.7 s and strips communities, so it buys nothing.
- **Update prunes deleted files** without `--force` (7 nodes to 5), and writes a dated backup dir inside the output dir when the graph shrinks.

> WARN(claude-opus-5-5/cdocs/graphify-overhaul): The no-stamp default costs about 11 s on every `cdocs-graphify` call at weftwise scale (clauthier: about 2.4 s), since `update` walks the whole corpus even when nothing changed.
> Kept per the proposal; a content stamp (HEAD plus `git diff HEAD` plus untracked-file checksums) would make no-change calls free, at a few more wrapper lines.
> Maintainer decision.

> NOTE(claude-opus-5-5/cdocs/graphify-overhaul): weftwise's `docs/*.md` headings are graphed and surfaced as query start nodes (`Hooks [src=docs/style_guide.md]`) for the proposal's base query.
> The weftwise `.graphifyignore` may want more than `cdocs/`; not in this workstream's scope.

### Phase 2: `cdocs-graphify` replaces `graphify-scope`

- Tests first (`48d4a65`, 15 of 20 failing with no script), then the wrapper (`91b3c1a`): 20/20.
  Mutations each caught (dropping the `.graphify_root` delete, choosing the first worktree instead of branch `main`, zeroing the coupling cap, discarding the passthrough exit code).
- The fixture mirrors this repo: a bare repo with worktrees `aaa` (listed first), `main`, and `wt`.
- Passthrough writes to a `mktemp` file and `cat`s it, so stdout is byte-exact and the coupling grep reads the same bytes.
- Usage errors (subcommand not in `query|explain|path|affected`) exit 2: the proposal does not specify this case.
- Real graphify smoke test (container, this worktree, `GRAPHIFY_OUT=/var/cache/graphify` holding the stale 73-node fixture): copy + update + query 0.58 s, result identical in size to a fresh build (248 nodes), `/var/cache/graphify/graph.json` mtime unchanged, `git status` clean.

> WARN(claude-opus-5-5/cdocs/graphify-overhaul): Deviation: the ignore line is `/cdocs/`, not the proposal's `cdocs/`.
> In gitignore syntax an unanchored `cdocs/` matches a `cdocs` directory at any depth, so graphify dropped `plugins/cdocs/` entirely (0 of its nodes; graph 248 nodes).
> With `/cdocs/`: 732 nodes, 484 under `plugins/cdocs/`, 0 under root `cdocs/`, and a plain `update` on the existing worktree index restored them.
> The wrapper's hint check accepts either form; init writes `/cdocs/`.

## Changes Made

| File | Description |
|------|-------------|

## Verification
