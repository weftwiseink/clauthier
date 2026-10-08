---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T13:46:55-07:00
task_list: cdocs/graphify-weftwise-assessment
type: proposal
state: live
status: review_ready
last_reviewed:
  status: accepted
  by: "@claude-opus-5-5"
  at: 2026-10-08T14:00:46-07:00
  round: 2
tags: [graphify, performance, evaluation]
---

# Graphify Weftwise Assessment

> BLUF: Remove the weftwise graph's cruft (`/_archive/` and `/docs/references/`; `/cdocs/` is already ignored) while keeping other markdown.
> Then measure `/cdocs:graphify` on the cleaned graph:
> - **runtime**: full build, post-edit, commit-only, fresh worktree, and query latency;
> - **usefulness**: 12-15 questions a sonnet agent samples from recent weftwise devlogs, each judged against a grep baseline.
>
> Variants that drop all markdown and other config, plus a background-refresh prototype, test what might speed up builds or mid-edit queries without hurting query quality.
> The deliverable is one report, `cdocs/reports/2026-10-08-graphify-weftwise-assessment.md`, giving a verdict per role: use now and with what config, or wait for upstream.

## Summary

Every earlier weftwise number comes from a graph in which 6,058 of 16,129 nodes come from `_archive/`; in the overhaul ablation, 3 of 11 base-query seeds were `_archive/` files.
None of those numbers says how the tool performs on what people actually query.
The assessment has three phases:

1. **Scope fix**: inventory the graph and add the cruft lines to weftwise `.graphifyignore`. Then rebuild the main graph and record counts before and after.
2. **Usefulness**: sample realistic questions and fix a grep ground truth first. Then judge graphify's output on a four-level rubric, with the token cost of each output.
3. **Runtime and config**: measure the runtime cases on the cleaned graph against a pre-clean baseline taken in the same session. Try the candidate flags, the scope variants, and two scratch wrapper prototypes (a background refresh and a stamp kept across the copy). Then write the report.

This is not a statistics exercise: timings take three runs, and each question gets one judgment.

> NOTE(claude-opus-5-5/cdocs/graphify-weftwise-assessment): The maintainer's framing: an inefficient tool is tolerable if we wait for upstream, but slow refreshes keep it from being used flexibly, especially by implementers mid-edit.
> The verdict must answer that question per role, not only overall.

## Objective

Decide whether `/cdocs:graphify`, on a cleaned weftwise graph, is fast and useful enough for each of these roles:
- **Overseer-briefed agents at startup**: base query, fresh worktree.
- **Reviewers**: `explain`/`path` on changed entities, usually after commits.
- **Implementers mid-edit**: queries after uncommitted code edits.

Also decide which config, if any, buys build or update time without hurting the core use case.
That core use case is `query`/`explain` of code entities, plus blast radius (`affected`, `path`).

## Background

- `cdocs/reports/2026-10-08-graphify-update-performance-audit.md`:
  - `update` has no no-op path. It ignores its own manifest and parses JS/TS twice.
  - Measured on the 16k-node graph: no-op about 10.3 s, post-edit about 14 s, query/explain about 0.7-0.8 s.
  - Clustering, the report, and `graph.html` run only when topology changes, and cost about 4 s of an edited update.
  - The audit also designs a background-refresh option, (d), and argues against it.
- `cdocs/reports/2026-10-08-graphify-upstream-health.md`: the upstream maintainer ships fixes for well-reported issues within hours. The `update` no-op gate and the JS/TS cache bypass have no maintainer response. Recommendation: stay pinned and keep the stamp.
- `cdocs/proposals/2026-10-08-graphify-fork-rfp.md`: the fixes that would remove the per-refresh cost (manifest gate, JS/TS fact cache).
- `cdocs/devlogs/2026-10-08-graphify-overhaul.md`:
  - The ablation row: the base query never surfaced the target atom, and `_archive/` files were among its seeds.
  - The options explainer's unverified items: the effect of ignoring `_archive/`, whether keeping the stamp across the copy is safe, and how often queries follow an edit.
- `plugins/cdocs/bin/cdocs-graphify` works in four steps:
  - Copies the main graph into `<worktree>/graphify-out/` if absent, deleting `.stamp`.
  - Skips `update` when the base-commit stamp matches; commits alone and changes to ignored paths both skip.
  - Otherwise runs `graphify update`, which is a full rebuild.
  - Passes the arguments through with `--graph`, then appends `.observe`/`.subscribe` hits.

  It reads `$GRAPHIFY_OUT` only as the copy source and writes only to `<worktree>/graphify-out`.
- Graphify CLI: https://graphify.net/graphify-cli-commands.html. The installed 0.9.61 source is at `/usr/local/pipx/venvs/graphifyy/lib/python3.11/site-packages/graphify` in container `weftwise`.

### Starting inventory

From `/var/cache/graphify-weftwise/graph.json` (16,129 nodes, 31,272 edges).
The graph's `built_at_commit` is `ab8edd6e`, 6 commits behind main `5e446a84`; they differ only under `cdocs/`, so the counts hold for `5e446a84`.

| Source | Nodes | Note |
|---|---|---|
| `packages/` | 9,106 | `weft/src` 5,977; tests, e2e, and demo ~1,100; `package.json`/`tsconfig*` ~600; READMEs 131 |
| `_archive/` | 6,058 | 248 md files + 6 code files graphed; tracked (437 files) |
| `docs/` | 553 | `docs/references/` 256; the other ~297 come from 14 guides |
| root files | ~160 | `AGENTS.md` 77, `CLAUDE.md` 18, `README.md` 14, `package.json` 45 |
| `scripts/` | 118 | sh/js helpers |
| `.claude/` | 117 | `rules/` 70 (materialized cdocs rules), `commands/` 47 |
| external modules | ~8 | `@codemirror`, `node:fs`, ... |

By extension: ts 7,457, md 6,913, tsx 734, json 671, mjs 152, sh 104.
No node comes from `cdocs/`, `data/`, `df-feedback/`, or `infra/`.
**Markdown is an island**: no edge joins an `.md` node to a non-`.md` node.
Markdown therefore never adds to `affected` or `path` results; its only effect on queries is competing with code for seeds.

## Proposed Solution

### Operating rules

- **Where it runs**: everything runs in container `weftwise` (`podman exec -u node -w <dir> weftwise sh -c '...'`; 20 cores; graphify 0.9.61).
- **The wrapper**: it is not on the container's `PATH` outside Claude. `podman cp` clauthier main's `plugins/cdocs/bin/cdocs-graphify` into a scratch dir in the container and call it by full path.
- **`GRAPHIFY_OUT` is explicit on every raw `graphify` call** (`update`, `extract`, `query`, `explain`, `path`, `affected`), set as `env GRAPHIFY_OUT=<scratch> graphify ...`.
  The container's environment sets `GRAPHIFY_OUT=/var/cache/graphify-weftwise`, so a raw call that does not override it writes into the main graph, and even `query` writes `cache/last_query_stamp` there.
  Only the Phase 1 main rebuild targets `/var/cache/graphify-weftwise`.
  Wrapper runs set `GRAPHIFY_OUT` to a scratch copy of the main graph, so that what the wrapper copies is under the implementer's control.
- **Worktrees**: one long-lived detached throwaway, `/workspaces/weftwise/gfy-assess`, plus short-lived detached ones for the fresh-worktree row. All are created with `git worktree add --detach` and removed at the end.
- **What gets written outside scratch**: only the weftwise `.graphifyignore` commit on `main` and the main-graph rebuild.

### Phase 1: scope fix

The default scope follows maintainer direction: exclude cruft, and keep markdown unless the assessment shows it does harm.
After the fix, `.graphifyignore` contains:
- `/cdocs/` (already present). Keep it as this exact line, because the wrapper's hint greps for `/cdocs/?`.
- `/_archive/`: 6,058 nodes, mostly superseded prose plus 6 stale code files.
- `/docs/references/`: 256 nodes of external reference material.
- Any non-markdown line the inventory proves graphed and useless (generated, vendored, build output, lockfiles, fixtures). No speculative lines: `data/`, `df-feedback/`, and `infra/` have no nodes.

Everything else stays, including `docs/` guides, package READMEs, `.claude/`, `AGENTS.md`, and `CLAUDE.md`.
`tsconfig*.json` and `package.json` stay in every variant, because JS import resolution reads them.

> NOTE(claude-opus-5-5/cdocs/graphify-weftwise-assessment): Overseer call (maintainer may override): `/.claude/rules/cdocs.md` (70 nodes) and the inlined cdocs block in `AGENTS.md` (77 nodes) are clauthier tooling text duplicated into weftwise.
> They stay in by default and are tested only as the Phase 3 exclusion variant.

Steps:
1. Save the pre-clean `graph.json` to scratch.
2. Measure the pre-clean baseline in `gfy-assess`: full build and post-edit (see the Phase 3 matrix).
3. Commit `.graphifyignore` on weftwise `main` and rebuild the main graph with a plain `graphify update`, no `--force`.
   In 0.9.61, sources newly matched by the ignore are evicted as deletions and pass the shrink guard.
   A refusal from the guard therefore signals an unexplained loss: report it as a finding and do not override it.
4. Record node and edge counts before and after, per-directory and per-extension tables, and code-edge counts for these relations: `imports`, `imports_from`, `calls`, `re_exports`, `dynamic_import`, `references`, `method`, `implements`.
   Markdown removal cannot cut a code edge, so the code-edge counts should match. Attribute any drop to nondeterminism or to a variant.
5. Self-heal check, run once in `gfy-assess`:
   1. Copy in the pre-clean graph as its index, with a matching stamp.
   2. Apply the new `.graphifyignore`.
   3. Run the wrapper.
   4. Confirm that the node count drops without `--force`.

   This shows that other worktrees' indexes heal once those worktrees merge main.

### Phase 2: usefulness

1. **Sample** (sonnet subagent).
   - Source: the ~30 newest weftwise devlogs, by filename date rather than mtime, plus proposals where useful.
     Skip graphify meta-devlogs (`*graphify*`).
   - Extract 12-15 questions an implementer or reviewer actually had. Record provenance for each: doc path and a short quote.
   - Cover four kinds: entity lookup, blast radius ("what breaks if X changes"), cross-package flow ("how does A reach B"), and "where is X handled".
   - Tag 2-3 of them as overseer-style topic queries, the kind a `graphify_base_query` would carry. These give the startup role evidence of its own.
   - Every question must concern code that still exists at the assessed commit.
2. **Ground truth first** (sonnet subagent, before anyone sees graphify output): answer each question with grep and reading.
   Record the expected files and entities, plus the effort (commands run, rough tokens read).
3. **Run** each question through the wrapper on the cleaned graph, the way the skill directs: `query`, `explain`, `path`, or `affected`, including the skill's retry with entity names.
   Also run the same commands against the saved pre-clean graph (`--graph`). Record only how the seeds and files differ, to show what the scope fix changed.
4. **Judge** (the implementer): one row per question.

| Verdict | Meaning |
|---|---|
| hit | names the ground-truth entities or files, enough to start reading there |
| partial | some of them, or right but buried in noise |
| miss | none, or matched nothing (a cheap failure) |
| misleading | points confidently at wrong, stale, or irrelevant code (a costly failure) |

Each row also records:
- the output token count (`wc -c` / 4),
- whether the retry was needed,
- a one-line comparison with the grep effort.

Close the phase with a short holistic paragraph: where graphify beats grep, where it does not, and whether the misses share a cause.

### Phase 3: runtime, candidates, report

**Runtime matrix.**
Every run logs `uptime` load.
The post-edit edit **adds a call or an import** in a `packages/weft/src` file, so that topology changes and clustering, the report, and `graph.html` all run.

| Case | Runs | How |
|---|---|---|
| full build | 3 (pre-clean and cleaned) | raw `update` into an empty scratch `GRAPHIFY_OUT` |
| post-edit | 3 (pre-clean and cleaned) | the structural edit, then the wrapper query |
| post-edit, body only | 1 (optional) | a body-only edit, which shows the cost when topology does not change |
| no-op | 3 | wrapper query on an unchanged tree (stamp hit). Raw `update` has no no-op path, so the full-build row stands for it |
| commit-only | 1 | commit the graphed edit, then the wrapper query; confirms a stamp skip |
| fresh-worktree first query | 3 | a new short-lived worktree, then the wrapper query (copy plus full update, because `.stamp` is not copied) |
| query latency | 3 each | `query`, `explain`, `path` against the graph, with no refresh |

Use `extract --timing` where a stage breakdown explains a number. No ad hoc profiling.

**Candidates.**
Each candidate gets a full build and a structural post-edit run.
It is then spot-checked by re-running a 5-query subset that includes at least one blast-radius question and one cross-package question, watching for a changed verdict.

| Candidate | What it tests |
|---|---|
| all markdown out (unanchored `*.md`) | Seed noise: does markdown crowd code seeds out, in the subset and the full set? Also markdown's share of build time. Cite the island evidence |
| `.claude/` and `AGENTS.md` out | Seed noise from the duplicated cdocs rules text |
| tests, e2e, and demo out | Speed against losing tests from blast radius |
| `*.json` out except `tsconfig*.json` and `package.json` | Speed against code-edge loss (compare relation counts) |
| `update --no-cluster` | The query path never reads communities; `explain` prints one `Community:` line |
| `GRAPHIFY_VIZ_NODE_LIMIT=0` | Skips `graph.html` |
| `GRAPHIFY_NO_BACKUP=1` | Skips the backup, which fires on every write when labels are derived from hub nodes |
| `GRAPHIFY_MAX_WORKERS` | Expected small (it only affects the parse stage); confirm |
| `extract --code-only` (incremental, no `--force`) | Manifest-gated, re-extracts changed files only. **Fidelity check**: after the same edit, diff its node and edge sets against a full `update`. TS cross-file resolution may be lossy, as the audit found for `_rebuild_code(changed_paths=...)` |
| background refresh (scratch wrapper) | See below |
| stamp kept across the copy (scratch wrapper) | See below |

Also confirm that no LLM or labeling call runs during `update`; labels come from `label_communities_by_hub`, so this is a single check.
The private `_rebuild_code(changed_paths=...)` is out of scope: the audit already showed it lossy on TS.

**Background refresh.**
This is the one candidate aimed directly at implementers mid-edit.

> NOTE(claude-opus-5-5/cdocs/graphify-weftwise-assessment): Overseer call (maintainer may override): this is measured, not only discussed. It is a scratch prototype, and no clauthier code lands.

The scratch wrapper works like this on a stale stamp:
1. Query the existing index immediately.
2. Start `graphify update` in the background. Graphify locks per output dir.
3. Print a one-line staleness note.

Measure three things: query latency while a refresh runs, the time from edit to fresh graph, and the share of the sampled questions that a stale-by-one-edit graph would answer differently.
Also measure `graphify watch` (3 s debounce, a full rebuild per batch) the same way, as the off-the-shelf version.
The report weighs these results against the audit's concern: `affected` right after an edit sees the old graph.

**Stamp kept across the copy.**

> NOTE(claude-opus-5-5/cdocs/graphify-weftwise-assessment): Overseer call (maintainer may override): the stamp is derived from the copied graph's `built_at_commit`, with no dependence on whatever builds the main graph. It is a scratch prototype, measured.

At copy time, the scratch wrapper writes `.stamp` as `<built_at_commit> <hash of the empty change set>`.
If `built_at_commit` is missing, unknown, or not an ancestor of HEAD, it writes no stamp, which means a full update as today.
A `.graphifyignore` change since the build shows up in the diff and forces an update.
Residual risk: a main graph built from a dirty tree. The report states it.
Measure the fresh-worktree first query with this prototype against the matrix row.

**Report.**
Write `cdocs/reports/2026-10-08-graphify-weftwise-assessment.md` in clauthier. It contains:
- the inventory and counts;
- the query table with provenance;
- the runtime matrix (median and range, pre-clean against cleaned);
- the candidate table;
- the per-role verdict;
- what would change the verdict;
- the floor command block (see Verification Methodology).

Default verdict bar, which the report may argue against:

| Refresh cost | Verdict for that role |
|---|---|
| 3 s or less | flexible, use mid-edit |
| 3-10 s | usable with discipline (query before editing, batch queries) |
| over 10 s | wait for upstream |

State the result against the bar with its variance, not only the median.
The implementer verdict considers background refresh, not refresh latency alone.

## Important Design Decisions

- **Cruft out, markdown in unless shown harmful.** This follows maintainer direction. Markdown is an island in the graph, so its only cost is seed competition and build time, and the all-markdown-out variant measures both.
- **Keep the resolution inputs.** `tsconfig*.json` and `package.json` feed JS import resolution. The relation counts catch any variant that cuts code edges.
- **Ground truth before graph output.** This avoids anchoring the judge on what graphify returned, and a separate sonnet agent keeps it cheap.
- **A pre-clean baseline from the same session.** The audit's numbers come from another container and commit, so the before/after comparison needs one taken here.
- **Explicit `GRAPHIFY_OUT`, one rule.** The container's global setting points at the main graph, so any implicit call is a write to it.
- **A structural post-edit.** A body-only edit can skip the output stages, which would under-measure the edit cost and make the output-stage candidates look useless by construction.
- **Prototypes, not landings.** Background refresh and the kept stamp live only in a scratch wrapper. The report recommends; landing either one in clauthier is a separate decision.
- **Few phases, serialized timing.** Timing runs must not overlap graphify builds or tests in the container. Query judging may overlap only with work that is not being timed.

## Edge Cases / Challenging Scenarios

- **Shrink guard**: plain `update` should evict newly ignored sources. If the guard refuses, stop and report the loss rather than forcing it.
- **Maintainer worktrees**: never `cd` into, edit, or run the wrapper in `bocsync-bailout`, `df-to-mount`, `dogfood-sept`, `logical-core`, `loro-branching`, or `loro-repo-package`.
  Record their HEADs and `git status --short | wc -l` before and after.
  Their indexes keep `_archive/` until those branches merge main, after which the changed `.graphifyignore` triggers an update and the index heals. The Phase 1 self-heal check covers this.
- **Shared bare repo**: `git worktree add/remove` writes `.bare/worktrees/`. Use `--detach` so no branches are created, and finish with `git worktree prune`.
- **Implicit `GRAPHIFY_OUT`**: an implicit call writes into the main graph (see Operating rules).
  If the main graph's mtime or `.graphify_root` changes outside the Phase 1 rebuild, restore it from the Phase 1 output and flag the change.
- **Background refresh races**: a query issued during a refresh should read the old `graph.json`. Confirm, from the source or by running queries during a refresh, that graphify replaces the file atomically and that no query ever sees a partial file. If it does not, the prototype queries a snapshot copy.
- **Stale sampled questions**: drop or rephrase questions about code that has moved, and note it in the provenance.
- **Nondeterminism**: if repeated full builds of one commit differ in node or edge counts, record the range. The floor uses that range.

## Test Plan

The tests here check that the assessment's numbers are real:
- After the rebuild:
  - zero nodes whose `source_file` starts with `_archive/`, `cdocs/`, or `docs/references/`;
  - remaining md node counts close to the starting inventory minus those prefixes;
  - code-relation counts unchanged, within the build-to-build range.
- The all-markdown-out variant has zero `.md` nodes.
- Every timing row records its runs and load. A row whose range exceeds 50% of its median is re-run once and flagged.
- Each candidate's 5-query spot check either shows no verdict regression, or the report weighs the regression against the speed gained.
- The `extract --code-only` fidelity diff is recorded as nodes and edges missing or extra compared with a full `update`.
- Cleanup: `git worktree list` shows only `main` and the six maintainer worktrees, all with HEADs unchanged, and the scratch dirs are removed.

## Verification Methodology

The report carries a copy-pasteable floor block, filled in with the assessed commit and paths, that a reviewer can re-run in a few minutes.
Its shape:

```sh
C=<assessed weftwise commit>; W=/workspaces/weftwise/gfy-floor; S=/tmp/gfy-floor
x() { podman exec -u node -w "${1}" weftwise sh -c "$2"; }
x /workspaces/weftwise/main "git worktree add --detach $W $C"
# 1. counts: build into an empty scratch dir (never the container default)
x $W "env GRAPHIFY_OUT=$S/out graphify update $W"
x $W "python3 <count script from the report> $S/out/graph.json"   # nodes, edges, per-prefix zeros, relation counts
# 3. timings (3x each): raw full build, post-edit wrapper query, explain
x $W "rm -rf $S/out2; time env GRAPHIFY_OUT=$S/out2 graphify update $W"
x $W "time env GRAPHIFY_OUT=$S/out graphify explain '<entity>' --graph $S/out/graph.json"
# post-edit: apply the report's edit patch, then: time env GRAPHIFY_OUT=$S/out <scratch>/cdocs-graphify query '<q>'
# 4. queries against the step 1 graph
x $W "env GRAPHIFY_OUT=$S/out graphify query '<q1>' --graph $S/out/graph.json"
x /workspaces/weftwise/main "git worktree remove --force $W && git worktree prune; rm -rf $S"
```

Pass criteria:
1. **Counts reproducible**: node and edge counts match the report exactly, or fall within its recorded range.
2. **Ignore holds**: the per-prefix zero checks pass on the step 1 graph.
3. **Timings within tolerance**: the medians of raw full build, post-edit wrapper query, and one `explain` fall within ±25% of the report's, or within a looser band if the report records high variance.
4. **Queries reproducible**: three report-listed commands (one each of `query`, `explain`, and `path`/`affected`), run against the step 1 graph, give the same top seeds or files and the same rubric verdict.
5. **No collateral**: maintainer worktree HEADs and dirty counts match the recorded before/after, no throwaway worktree remains, and the main graph's mtime is unchanged since Phase 1.

The implementer runs this floor itself before handing off and records the result in its devlog.

## Implementation Phases

**Execution**: `/cdocs:iterate` with one opus implementer, whose sub-devlog sets `part_of: cdocs/devlogs/2026-10-08-graphify-weftwise-assessment.md`.
Sonnet subagents do the sampling and the ground truth.
Commits, all by exact path: the `.graphifyignore` change in weftwise `main`, and the report and devlog in clauthier `main`.

### Phase 1: baseline and scope fix

- Record the maintainer worktrees' state. Create `gfy-assess`, copy in the wrapper, and save the pre-clean graph.
- Run the pre-clean baseline: full build and structural post-edit, 3 runs each.
- Write the inventory: per top-level directory, per nested `packages/*` subtree, and per extension.
  Confirm the default lines, and add a non-markdown line only where the inventory proves it graphed.
- Commit `.graphifyignore` in weftwise `main` (`chore(graphify): ignore archive and reference docs` or similar). Rebuild `/var/cache/graphify-weftwise` with plain `update`.
- Record the before/after tables and relation counts, then run the self-heal check.
- Done when: the ignore checks pass, the relation counts are explained, and the baseline is recorded.

### Phase 2: query set and usefulness

- Dispatch the sonnet sampler, then the sonnet ground-truth agent. Record the question set with its provenance.
- Run each question on the cleaned graph and on the pre-clean graph, then judge it. Write the query table and the holistic paragraph.
- Done when: 12-15 judged rows cover all four kinds, include 2-3 base-query-style rows, and each records tokens and a grep comparison.

### Phase 3: runtime, candidates, report

- Run the runtime matrix on the cleaned graph.
- Run the candidates with their 5-query spot checks, including the `extract --code-only` fidelity diff and the two scratch-wrapper prototypes.
- Write the report.
  It includes the per-role verdict and the recommended config; any further `.graphifyignore` line is a separate weftwise commit.
  It also gives the recommended wrapper changes, which are not landed, and what would change the verdict: for example, the fork RFP's fixes 1 and 2, or a post-edit refresh below the bar.
- Run the verification floor. Remove `gfy-assess`, the short-lived worktrees, and the scratch dirs. Set the report to `review_ready`.

**Do not change**:
- the maintainer worktrees;
- `plugins/cdocs/bin/cdocs-graphify` or other clauthier code;
- the graphify install or version;
- the shared `/var/cache/graphify` (the clauthier graph).
