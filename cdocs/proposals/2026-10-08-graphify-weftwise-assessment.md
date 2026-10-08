---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T13:46:55-07:00
task_list: cdocs/graphify-weftwise-assessment
type: proposal
state: live
status: review_ready
last_reviewed:
  status: revision_requested
  by: "@claude-opus-5-5"
  at: 2026-10-08T13:53:20-07:00
  round: 1
tags: [graphify, performance, evaluation]
---

# Graphify Weftwise Assessment

> BLUF: Cut the weftwise graph down to code (drop `_archive/`, `cdocs/`, docs-only markdown, and other non-code inputs), then measure `/cdocs:graphify` on it: runtime for full build, no-op, commit-only, post-edit, fresh-worktree, and query latency, and usefulness on 12-15 realistic questions a sonnet agent samples from recent weftwise devlogs, each judged against a grep baseline.
> Graphify flags and config are tried for build-time wins that keep query quality.
> The output is one report, `cdocs/reports/2026-10-08-graphify-weftwise-assessment.md`, with a per-role verdict: use now (and with what config), or wait for upstream.

## Summary

Every earlier weftwise number comes from a graph in which 6,058 of 16,129 nodes are from `_archive/`, and in the overhaul ablation 3 of 11 base-query seeds were `_archive/` files.
None of those numbers says how the tool performs on the code people actually query.
This proposal designs a single assessment in three phases:

1. **Scope fix**: inventory the graph, exclude the cruft in weftwise `.graphifyignore`, rebuild the main graph, and record before/after counts.
2. **Usefulness**: sample realistic questions, set a grep ground truth first, then judge the graphify output on a four-level rubric with output token cost.
3. **Runtime and config**: measure the six runtime cases on the cleaned graph against a same-session pre-clean baseline, try candidate flags/config and one wrapper tweak, then write the report.

The aim is a pragmatic verdict, not statistics: three runs per timing and one judgment per query.

> NOTE(claude-opus-5-5/cdocs/graphify-weftwise-assessment): The maintainer's framing: an inefficient tool is tolerable if we wait for upstream, but slow refreshes stop it being used flexibly, especially by implementers mid-edit.
> The verdict must answer that question per role, not only overall.

## Objective

Decide, on a code-only weftwise graph, whether `/cdocs:graphify` is fast and useful enough for:
- **Overseer-briefed agents at startup** (base query, fresh worktree),
- **Reviewers** (`explain`/`path` on changed entities, usually after commits),
- **Implementers mid-edit** (queries after uncommitted code edits),

and which config, if any, buys build/update time without losing the core use case: `query`/`explain` of code entities and blast radius (`affected`, `path`).

## Background

- `cdocs/reports/2026-10-08-graphify-update-performance-audit.md`: `update` has no no-op path, ignores its own manifest, and parses JS/TS twice. No-op ~10.3 s, post-edit ~14 s, query/explain ~0.7-0.8 s on the 16k-node graph. No existing flag helps (`--no-cluster` drops communities). Clustering, report, and `graph.html` run only when topology changes (~4 s of an edited update).
- `cdocs/reports/2026-10-08-graphify-upstream-health.md`: maintainer ships good-report fixes in hours, but the `update` no-op gate and JS/TS cache bypass are unacknowledged; recommendation is pin and stamp.
- `cdocs/proposals/2026-10-08-graphify-fork-rfp.md`: the fixes that would remove the per-refresh cost (manifest gate, JS/TS fact cache).
- `cdocs/devlogs/2026-10-08-graphify-overhaul.md`: ablation row (base query never surfaced the target atom; `_archive/` seeds) and the options explainer's open items (`_archive/` ignore effect, stamp-across-copy safety, post-edit frequency).
- `plugins/cdocs/bin/cdocs-graphify`: copies the main graph into `<worktree>/graphify-out/` if absent (deleting `.stamp`), skips `update` when the base-commit stamp matches (commit-only and ignored-path changes skip), else runs `graphify update` (a full rebuild), then passes through with `--graph` and appends `.observe`/`.subscribe` hits.
- Graphify CLI: https://graphify.net/graphify-cli-commands.html; installed 0.9.61 source at `/usr/local/pipx/venvs/graphifyy/lib/python3.11/site-packages/graphify` in container `weftwise`.

### Starting inventory

From `/var/cache/graphify-weftwise/graph.json` at weftwise `5e446a84` (16,129 nodes, 31,272 edges):

| Source | Nodes | Note |
|---|---|---|
| `packages/` | 9,106 | `weft/src` 5,977; tests/e2e/demo ~1,100; `package.json`/`tsconfig*` ~600 |
| `_archive/` | 6,058 | 248 md + 6 code graphed files; tracked (437 files) |
| `docs/` | 553 | 14 top-level guides + `docs/references/` (256 md nodes) |
| root files | 169 | `AGENTS.md` 77, `CLAUDE.md` 18, `README.md` 14, `package.json` 45 |
| `scripts/` | 118 | sh/js helpers |
| `.claude/` | 117 | rules and commands markdown |
| external modules | ~8 | `@codemirror`, `node:fs`, ... |

By extension: ts 7,457, md 6,913, tsx 734, json 671, mjs 152, sh 104.
About 43% of all nodes are markdown headings.

## Proposed Solution

All work runs in container `weftwise` (`podman exec -u node -w <dir> weftwise ...`, 20 cores, graphify 0.9.61).
The wrapper is not on the container's `PATH` outside Claude: `podman cp` clauthier main's `plugins/cdocs/bin/cdocs-graphify` into a scratch dir in the container and call it by that path.
Measurements use one detached throwaway worktree, `/workspaces/weftwise/gfy-assess` (`git worktree add --detach`), and scratch `GRAPHIFY_OUT` dirs.
The only intended writes outside scratch are the weftwise `.graphifyignore` commit on `main` and the main-graph rebuild at `/var/cache/graphify-weftwise`.

### Phase 1: scope fix

**Rule for what stays:** source code and the config that code resolution reads (`tsconfig*.json`, `package.json` workspace and dependency maps), because those answer "what is X, what uses it, how do A and B connect".
Everything else is cruft unless the Phase 3 docs variant shows it helps a sampled query.

Expected exclusions, all anchored (an unanchored pattern also matches nested dirs):
- `/cdocs/` (kept), `/_archive/`, `/docs/`, `/.claude/`, `/data/`, `/df-feedback/`, `/infra/`.
- Markdown everywhere (`*.md`), covering `AGENTS.md`, `CLAUDE.md`, and READMEs. This pattern is deliberately unanchored.
- Generated, vendored, and build output, plus lockfiles and fixtures, wherever the inventory finds them graphed. Most are already gitignored; confirm against the inventory rather than adding speculative lines.

`docs/` default: **excluded**.
Its headings are prose seeds that compete with code seeds for the query's budget, and the core use case is code entities.
Phase 3 tests a docs-included variant; the report keeps or reverses the default on that evidence.

Tests, e2e, and demo code stay by default, since blast radius should include the tests that exercise a symbol.
Phase 3 measures a tests-excluded variant for its speed and quality trade.

Steps: save the pre-clean `graph.json` to scratch, and measure the pre-clean baseline in the throwaway worktree (see Phase 3's matrix: full build, no-op, post-edit, 3x each).
Then commit `.graphifyignore` on weftwise `main`, rebuild the main graph, and record before/after node and edge counts, per-directory and per-extension tables, and code-to-code import/call edge counts.
That last count is the check that resolution survived.

### Phase 2: usefulness

1. **Sample** (sonnet subagent): read the most recent ~30 weftwise devlogs (`cdocs/devlogs/`, newest first) and proposals as useful.
   Extract 12-15 questions an implementer or reviewer actually had, each with provenance (doc path and a short quote).
   Span four kinds: entity lookup, blast radius ("what breaks if X changes"), cross-package flow ("how does A reach B"), and "where is X handled".
   Each question must concern code still present at the assessment's weftwise commit; drop prose-only questions.
2. **Ground truth first** (sonnet subagent, before anyone sees graphify output): answer each question with grep and reading.
   Record the expected files/entities and the effort (commands, rough tokens read).
3. **Run** each through the wrapper on the cleaned graph as the skill directs (`query`, `explain`, `path`, `affected`), including the skill's retry-with-entity-names rule.
   Also run the same commands against the saved pre-clean graph (`--graph`), recording only the seed and file differences, to show what the scope fix changed.
4. **Judge** (the implementer): one row per question.

| Verdict | Meaning |
|---|---|
| hit | names the ground-truth entities or files, enough to start reading there |
| partial | some of them, or right but buried in noise |
| miss | none, or matched nothing (cheap failure) |
| misleading | points confidently at wrong, stale, or irrelevant code (costly failure) |

Each row also records output tokens (`wc -c` / 4), whether the retry was needed, and a one-line note comparing it to the grep effort.
Close with a holistic paragraph on where graphify beats grep, where it does not, and whether the misses share a cause.

### Phase 3: runtime, config, report

**Runtime matrix**, 3 runs each, on the cleaned graph and (for the first three) on the pre-clean baseline, logging `uptime` load with each run:

| Case | How |
|---|---|
| full build | `graphify update` into an empty scratch `GRAPHIFY_OUT` |
| no-op update | raw `graphify update` on an unchanged tree, plus the wrapper query (stamp hit) |
| post-edit | a small TS edit (one function body in `packages/weft/src`), then the wrapper query |
| commit-only | commit that edit after it was graphed, then the wrapper query (expect a stamp skip) |
| fresh-worktree first query | new detached worktree, wrapper query (copy + full update, since `.stamp` is not copied) |
| query latency | `query`, `explain`, `path` with no refresh, against the graph |

**Candidates**: each is measured on full build and post-edit, then spot-checked by re-running a 5-query subset.
The subset should include at least one blast-radius and one cross-package question, and it should also be checked for a verdict change.
- Scope variants: docs included; tests/e2e/demo excluded; `*.json` excluded except `tsconfig*.json` and `package.json`.
- Output-stage switches: `GRAPHIFY_VIZ_NODE_LIMIT` or any other way to skip `graph.html`, `GRAPH_REPORT.md`, or `suggest_questions` on update. Re-test `--no-cluster` only for whether `query`/`explain` use communities at all.
- Parallelism: `GRAPHIFY_MAX_WORKERS` (expected small; confirm).
- Confirm no LLM or labeling step runs during `update`.
- Anything else the installed source shows (`cli.py`, `watch.py`, `detect.py` env vars and options).
  `extract` is in scope only if it has a code-only incremental path the docs omit.
- Wrapper: a scratch copy that keeps a valid stamp across the copy step.
  One way: whoever rebuilds the main graph writes a stamp in the wrapper's format next to it, and the copy step keeps it.
  Measure the fresh-worktree saving and reason through when a kept stamp could be stale.

Private `_rebuild_code(changed_paths=...)` is out of scope: the audit already showed it lossy on TS.

**Report**: `cdocs/reports/2026-10-08-graphify-weftwise-assessment.md` (clauthier), with the inventory and counts, the query table with provenance, the runtime matrix (median and range, pre vs post), the candidate table, the per-role verdict, and what would change it.
Verdict bar (a default the report may argue against): a refresh of 3 s or less is "flexible, use mid-edit"; 3-10 s is "usable with discipline" (query before editing, batch queries); over 10 s is "wait for upstream" for that role.

## Important Design Decisions

- **Code-only by rule, docs by evidence.** The core use case is code entities; prose headings are what crowded out the target in the ablation. A docs variant, rather than a debate, settles `docs/`.
- **Keep resolution inputs.** `tsconfig*.json` and `package.json` feed JS import resolution (audit: non-code inputs to resolution). Dropping them could silently cut edges, which is why Phase 1 counts code-to-code edges.
- **Ground truth before graph output.** It avoids anchoring the judge on what graphify returned. A separate sonnet agent keeps it cheap.
- **Same-session pre-clean baseline.** The audit's numbers came from another container and commit. Re-measuring pre-clean in the same container and session makes before/after a fair comparison.
- **Three runs, medians, load logged.** Enough to see variance without turning the assessment into a benchmark suite.
- **No clauthier code lands here.** Wrapper changes are prototyped in scratch and recommended in the report. Landing one needs an explicit overseer call, flagged as a deviation.
- **Few phases, serialized timing.** Phases 2 and 3 both need the cleaned graph. Timing runs must not overlap graphify builds or test runs in the container; query judging can overlap only with non-timing work.

## Edge Cases / Challenging Scenarios

- **Shrink guard**: rebuilding the main graph with fewer nodes needs `graphify update --force` (or `GRAPHIFY_FORCE=1`); otherwise `graph.json` is not overwritten. Verify the node count after the rebuild.
- **Ignore pattern semantics**: confirm that `.graphifyignore` honors `*.md` and anchored dirs as gitignore does, by the post-rebuild per-extension table, not by assumption.
- **Maintainer worktrees**: never `cd` into, edit, or run the wrapper in `bocsync-bailout`, `df-to-mount`, `dogfood-sept`, `logical-core`, `loro-branching`, or `loro-repo-package`. Record their HEADs and `git status --short | wc -l` before and after. Their existing `graphify-out/` indexes keep `_archive/` until deleted, and they get the new ignore only once they merge main; the report says so and recommends deleting those indexes, but the assessment does not do it.
- **Shared bare repo**: `git worktree add/remove` writes `.bare/worktrees/`; use `--detach` (no branches), and `git worktree remove` plus `prune` at the end.
- **Wrapper `main_out` resolution**: in the container `GRAPHIFY_OUT` names the main graph. For measurement runs, point it at a scratch copy so that only the intentional rebuild touches `/var/cache/graphify-weftwise`.
- **Stale sampled questions**: drop or rephrase questions about code that has since moved, and record that in the provenance.
- **Nondeterminism**: if repeated full builds of one commit differ in node or edge counts, record the range, and the verification floor uses that range.
- **Kept-stamp staleness**: a stamp written by the main-graph builder is only valid if the builder ran from the commit the stamp names, with the same `.graphifyignore`. The prototype must handle a main graph rebuilt without a stamp: no stamp means a full update, as today.

## Test Plan

This is an assessment, so the "tests" are the checks that its numbers are real:
- After the rebuild: zero nodes whose `source_file` starts with any excluded prefix, and zero `.md` nodes if `*.md` is excluded.
- Code-to-code `imports`/`calls` edge counts within a few percent of pre-clean for `packages/` sources. A larger drop is a finding, not a pass.
- Every timing row has 3 runs and logged load. A row whose range exceeds 50% of its median is re-run once and flagged.
- Each candidate's 5-query spot check has no verdict regression, or the regression is reported against the speed it buys.
- Cleanup: `git worktree list` shows only `main` and the six maintainer worktrees, with HEADs unchanged; scratch `GRAPHIFY_OUT` dirs are removed.

## Verification Methodology

A reviewer can re-run this floor in the container in a few minutes:
1. **Counts reproducible**: at the recorded weftwise commit, `graphify update --force` into an empty scratch `GRAPHIFY_OUT` from a fresh detached worktree. Node and edge counts match the report exactly, or within its recorded range.
2. **Ignore holds**: the per-prefix zero checks above on that graph.
3. **Timings within tolerance**: no-op raw `update`, post-edit wrapper query, and one `explain`, 3 runs each. Medians fall within ±25% of the report's (looser if the report records high variance).
4. **Queries reproducible**: three report-listed commands (one each of `query`, `explain`, and `path`/`affected`) give the same top seeds or files and the same rubric verdict.
5. **No collateral**: maintainer worktree HEADs and dirty counts match the before/after record, and no throwaway worktree remains.

The implementer runs this floor itself before handing off, and records it in its devlog.

## Implementation Phases

Execution: `/cdocs:iterate` with one implementer (opus) and its own sub-devlog (`part_of: cdocs/devlogs/2026-10-08-graphify-weftwise-assessment.md`).
Sonnet subagents do the sampling and the ground truth.
Commits: the `.graphifyignore` change in weftwise `main`, and the report plus devlog in clauthier `main`, all by exact path.

### Phase 1: baseline and scope fix

- Record maintainer worktree state, create `gfy-assess`, copy in the wrapper, and save the pre-clean graph.
- Measure the pre-clean baseline: full build, no-op, post-edit, 3x each.
- Write the inventory (per top-level dir, per nested `packages/*` subtree, per extension) and decide exclusions by the rule.
- Commit `.graphifyignore` in weftwise `main` (`chore(graphify): ignore non-code inputs` or similar). Rebuild `/var/cache/graphify-weftwise` with `--force`. Record the before/after tables and code-edge counts.
- Done when: the ignore checks pass, code-edge counts are explained, and the baseline numbers are recorded.

### Phase 2: query set and usefulness

- Dispatch the sonnet sampler, then the sonnet ground-truth agent; record the set with provenance.
- Run, compare against pre-clean, and judge; write the query table and the holistic paragraph.
- Done when: 12-15 judged rows span all four kinds, each with tokens and a grep comparison.

### Phase 3: runtime, candidates, report

- Run the runtime matrix on the cleaned graph, then the candidates with their 5-query spot checks, then the stamp-across-copy prototype.
- Write the report with the per-role verdict, recommended config (any further `.graphifyignore` lines are a separate weftwise commit), recommended wrapper change (not landed), and what would change the verdict (for example the fork RFP's fixes 1 and 2, or a post-edit refresh under the bar).
- Run the verification floor, remove `gfy-assess` and the scratch dirs, and set the report `review_ready`.

Do not change: maintainer worktrees, `plugins/cdocs/bin/cdocs-graphify` or other clauthier code, the graphify install or version, and the shared `/var/cache/graphify` (the clauthier graph).
