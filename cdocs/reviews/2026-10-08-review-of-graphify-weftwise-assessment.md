---
review_of: cdocs/proposals/2026-10-08-graphify-weftwise-assessment.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T13:53:20-07:00
task_list: cdocs/graphify-weftwise-assessment
type: review
state: live
status: done
tags: [fresh_agent, source_verified, test_plan, graphify, performance]
---

# Review: Graphify Weftwise Assessment

## Summary Assessment

The proposal plans one assessment that cuts the weftwise graph to code, then judges `/cdocs:graphify` on runtime and on 12-15 sampled questions against a grep ground truth, ending in a per-role verdict.
It tracks the maintainer's request closely, and its structure holds up: the scope rule, ground truth before graph output, a same-session baseline, and a re-runnable floor.
Its default markdown scope (unanchored `*.md` and `docs/` excluded) is inverted against the maintainer's mid-review direction: keep markdown except `/_archive/`, `/cdocs/`, and `/docs/references/` unless the assessment shows harm.
Probes of the installed graphify 0.9.61 source also contradict two of its factual claims, and two further gaps affect the maintainer's question about implementers mid-edit.
The shrink guard does not need `--force` for newly ignored paths.
Raw `graphify` calls in the container write to the main graph unless `GRAPHIFY_OUT` is overridden.
The post-edit case as specified may not change topology, which hides the stages the output-stage candidates target.
Background refresh, the one lever that changes mid-edit latency without upstream fixes, is missing.
Verdict: **Revise**: five blocking fixes, all local edits, plus trimming the speculative ignore lines.

## Evidence Gathered

All probes were read-only: source greps under `/usr/local/pipx/venvs/graphifyy/lib/python3.11/site-packages/graphify`, `git` reads in `/workspaces/weftwise/main`, and a Python read of `/var/cache/graphify-weftwise/graph.json`.

- **Main graph**: 16,129 nodes and 31,272 edges, as stated.
  `built_at_commit` is `ab8edd6e`, 6 commits behind `5e446a84`, and `git diff --stat ab8edd6e HEAD -- . ':!cdocs'` is empty, so the counts match `5e446a84` in substance.
  No `.stamp` is present in `/var/cache/graphify-weftwise`.
- **Top-level sources graphed**: `packages` 9,106, `_archive` 6,058, `docs` 553, `scripts` 118, `.claude` 117, root files about 160, plus a handful of external-module stubs.
  No node has a source under `data/`, `df-feedback/`, `infra/`, or `cdocs/`.
- **Markdown is an island**: there are zero edges between `.md` and non-`.md` nodes in the graph.
  Excluding `*.md` cannot cut a code-to-code edge, and 131 of the md nodes are in-package READMEs (`packages/weft` 112).
- **Shrink guard** (`watch.py` `_check_shrink`, plus the reconcile at about lines 830-905): a source that exists on disk and is matched by `.graphifyignore` is added to `deleted_paths` (#2495), and `rebuilt_sources |= deleted_paths`.
  Its lost nodes therefore count as accounted for, and the guard passes without `--force`.
  `--force` only bypasses the check that catches a silent shrink from a failed extraction.
- **`GRAPHIFY_OUT`**: in the container it is set to `/var/cache/graphify-weftwise` (an absolute path), and `paths.py` uses it as-is.
  An `update`, `extract`, or even `query` (which writes `cache/last_query_stamp`) that does not override it writes into the main graph dir.
  The wrapper only reads `main_out` (the copy source) and writes to `<worktree>/graphify-out`.
- **Flags**: `update` accepts only `--force` and `--no-cluster` (any other `-` option exits 2).
  `GRAPHIFY_VIZ_NODE_LIMIT` (0 disables graph.html, default 5,000), `GRAPHIFY_MAX_WORKERS`, and `GRAPHIFY_FORCE` all exist.
  `--no-viz` exists only on `cluster-only` and `export html`, not on `update`.
- **Levers the proposal does not name**:
  - `graphify extract --code-only` without `--force` is manifest-gated and incremental (`cli.py` about lines 3420-3470).
    It AST-extracts only new or changed code files and merges them into the existing graph.
  - `extract --timing` prints a per-stage breakdown.
  - `GRAPHIFY_NO_BACKUP=1` skips `backup_if_protected`.
    That backup runs whenever `.graphify_labels.json` holds any non-`Community N` label, and the hub-derived labels that `update` writes qualify.
  - `graphify watch` (3 s debounce, full `_rebuild_code` per batch) keeps a graph fresh in the background.
- **Communities and queries**: the `query` path (`serve.py` `_query_graph_text`, `cli.py` `query`) does not read communities.
  `explain` prints one `Community:` line.
  `--no-cluster` therefore looks close to free for the core use case.
- **No LLM on `update`**: labels come from `label_communities_by_hub`, so the planned confirmation is a one-line check.
- **Ignore semantics**: `detect.py` implements anchored patterns (`_match_anchored_ignore_pattern`), unanchored basename and segment matches, and `!` negation.
  The wrapper's stamp uses `git check-ignore` against the same file, so the two agree on standard patterns.

## Section-by-Section Findings

### BLUF, Summary, Objective

Clear, and faithful to the steering log: it is scope fix first, a sonnet sampler, a holistic judgment, flags that keep query/explain intact, and a per-role verdict.
The NOTE carrying the maintainer's framing is useful.

**Non-blocking**: the per-role framing names "overseer-briefed agents at startup (base query)", yet Phase 2 has no base-query rows.
No weftwise devlog has a filled `graphify_base_query`, so the sampler cannot find one.
Tag two or three sampled questions as overseer-style topic queries, so that role's verdict has evidence behind it.

### Background and Starting inventory

The inventory matches the graph, with one exception: the graph was built at `ab8edd6e`, not `5e446a84`.
Only `cdocs/` differs between the two, so this is a labeling fix.
**Non-blocking.**

### Phase 1: scope fix

> NOTE(claude-opus-5-5/cdocs/graphify-weftwise-assessment): The overseer relayed this maintainer direction mid-review: "In weftwise docs/references should prob be excluded but otherwise markdown can prob be included unless detrimental."
> The findings below apply it.

The rule (code plus the resolution inputs `tsconfig*.json` and `package.json`) is right for code.
Applied to markdown, though, it runs against the maintainer's intent.

**Blocking: the default markdown scope is inverted.**
The proposal makes "code only" the default and the docs variant the exception: unanchored `*.md` plus `/docs/` excluded.
The maintainer wants the opposite: markdown in by default, minus `/_archive/`, `/cdocs/`, and `/docs/references/`, with other markdown excluded only if the assessment shows harm.
The default ignore should therefore be `/cdocs/`, `/_archive/`, `/docs/references/`, plus inventory-proven non-md lines.
Overseer counts: this drops about 6,003 + 256 md nodes and keeps about 297 `docs/` md nodes, 131 in-package README nodes, 117 `.claude/` nodes, and 109 root md nodes.
The `*.md` exclusion becomes the Phase 3 variant, judged on two measures:
- Seed noise: does markdown crowd code seeds out of the 5-query subset, or out of the full set?
- Build-time share: md files go through the AST quick-scan on every `update`.

The md-island probe is relevant evidence for that variant, and the report should state it.
Markdown nodes have no edges to code, so they never add to `affected` or `path` results.
Their only effect on queries is seed competition, for good or ill.
The rationale bullet "Code-only by rule, docs by evidence" needs rewording to match.

**Question (non-blocking, but the maintainer should rule)**: `/.claude/rules/cdocs.md` (70 nodes) and the inlined cdocs block in `AGENTS.md` (77 nodes) are the materialized cdocs rules.
They are clauthier tooling text duplicated into weftwise, not weftwise project docs, and they surface cdocs-convention headings for any query that mentions devlogs, reviews, or proposals.
`/.claude/rules/cdocs.md` is a clean anchored line.
`AGENTS.md` cannot be partly excluded, so it is all or nothing.
See Questions for the Maintainer.

**Non-blocking (over-engineering)**: the anchored directory list breaks the proposal's own rule, "confirm against the inventory rather than adding speculative lines".
- `/data/`, `/df-feedback/`, and `/infra/` have zero graphed nodes.
  `data/` is gitignored, `df-feedback/` has no tracked files, and `infra/` holds terraform files with no extractor.
- `/_archive/` is needed (md plus 6 code files), and `/cdocs/` must stay as the exact line `/cdocs/`, because the wrapper's `/cdocs/?` hint greps for it.

The bullet "`/cdocs/` (kept)" inside "Expected exclusions" also reads as a contradiction.
Say "already present, keep".

**Non-blocking**: the Test Plan's "zero `.md` nodes if `*.md` is excluded" check moves to the variant.
For the default, the checks are zero nodes under `_archive/`, `cdocs/`, and `docs/references/`, with the remaining md counts matching the overseer's tally above.

**Non-blocking**: "code-to-code `imports`/`calls` edge counts" should name the actual relations: `imports`, `imports_from`, `calls`, `re_exports`, `dynamic_import`, `references`, `method`, and `implements`.
Since md removal cannot cut code edges (probe), any drop comes from the `*.json` variant or from extraction nondeterminism, and the report should say which.

### Phase 2: usefulness

The sampler, ground truth first, then the run and judge sequence is practical and cheap, and the four-level rubric with "misleading" as a separate costly failure is the right shape.
Running the same commands on the saved pre-clean graph is a cheap way to show what the scope fix bought.

**Non-blocking**: "most recent ~30 devlogs, newest first" should sort by filename date, not mtime, because a checkout sets mtimes.
The sampler should also skip the graphify meta-devlogs at the top of the list (`2026-10-08-graphify-devcontainer-feature*.md`), which would yield questions about graphify rather than weftwise code.

### Phase 3: runtime matrix and candidates

**Blocking: `GRAPHIFY_OUT` must be explicit on every raw `graphify` call.**
The "no-op update" row ("raw `graphify update` on an unchanged tree"), the query-latency row, and floor step 3 do not set it.
In the container they inherit `/var/cache/graphify-weftwise`.
A raw `update` run from `gfy-assess` would overwrite the main graph and its `.graphify_root` with a worktree path that is later removed.
The Edge Cases bullet "Wrapper `main_out` resolution" points at the wrong actor: the wrapper never writes `main_out`.
Fix: one rule, "every raw `graphify` invocation sets `GRAPHIFY_OUT=<scratch>`; only the Phase 1 rebuild targets `/var/cache/graphify-weftwise`".

**Blocking: the post-edit edit must change topology, or both kinds must be measured.**
"One function body in `packages/weft/src`" may leave the graph's topology unchanged.
In that case `no_change` skips clustering, the report, and `graph.html` (about 4 s of an edited update, per the audit).
The post-edit time is then under-measured, and the output-stage candidates (`--no-cluster`, `GRAPHIFY_VIZ_NODE_LIMIT=0`) show no gain by construction.
Implementers mid-edit usually add calls, so specify an edit that adds a call or import as the main case.
A body-only edit can optionally be a second row.

**Blocking: the mid-edit lever is missing.**
Without upstream fixes, a post-edit refresh costs at least the JS/TS double parse, and the candidates mostly shave seconds off that.
The audit already designs the option that changes the implementer verdict: query the existing index right away and refresh in the background on a stale stamp, at about 0.85 s per query with a bounded staleness window.
`graphify watch` is the off-the-shelf version of the same idea.
Add one scratch-wrapper candidate for background refresh, measuring query latency during a refresh and the time from edit to fresh graph.
Alternatively, have the per-role verdict argue explicitly why it is excluded.
Either way, the implementer verdict should not rest on refresh latency alone.

**Non-blocking: promote two candidates the source already supports.**
- `--no-cluster`: the query path ignores communities and `explain` only prints a `Community:` line.
  Measure it as a full candidate with the 5-query spot check, rather than only "re-test whether query/explain use communities".
- `extract --code-only` (incremental, no `--force`): the condition "only if it has a code-only incremental path" is met in 0.9.61.
  It needs a fidelity check: after the same edit, diff its node and edge sets against a full `update`.
  The audit found `_rebuild_code(changed_paths=...)` lossy on TS, and the same cross-file resolution gap may apply here.
  Note that `extract` writes to `<--out or path>/$GRAPHIFY_OUT`, which is the main graph unless overridden.

**Non-blocking: free extras.** `GRAPHIFY_NO_BACKUP=1` is a zero-risk env candidate, since the backup fires on every accepted write when labels are hub-derived.
`extract --timing` gives the stage breakdown, so the report does not need ad hoc profiling.

**Non-blocking (trim)**: raw `update` has no no-op path (audit), so the pre/post "no-op update" rows mostly duplicate "full build".
Keep the wrapper stamp-hit measurement and drop or merge the raw no-op row.
"Commit-only" is a stamp-logic confirmation and needs one run, not three.

**Thresholds (3 s / 10 s)**: these are reasonable as stated defaults.
With query/explain at about 0.8 s, 3 s means a refresh costs about four queries, which is tolerable inside an edit loop.
10 s matches the audit's no-op cost that already pushed agents away.
The proposal correctly lets the report argue against them.
The audit's post-edit figure (about 14 s), minus md parsing and clustering, could plausibly land near 10 s, so the report should state the variance-adjusted position against the bar, not only the median.

### Stamp-across-copy prototype

The plan is coherent, and the staleness reasoning in Edge Cases is right.
One simplification to weigh: graphs written by 0.9.61 carry `built_at_commit`.
At copy time, the wrapper could write `.stamp` as `<built_at_commit> <hash of an empty change set>`.
That needs no cooperation from "whoever rebuilds the main graph", which is otherwise unnamed: a devcontainer mount and a manual or feature rebuild, outside clauthier.
`.graphifyignore` is tracked and not self-ignored, so an ignore change since the build shows up in the diff and forces an update.
The "same `.graphifyignore`" concern is therefore handled automatically, provided the builder ran with a committed ignore.
The remaining risk is a builder that ran on a dirty tree.
Today's state also shows the payoff: main is 6 commits past `built_at_commit`, all `cdocs/`-only, so a fresh worktree would get a stamp hit.
**Non-blocking**: the prototype should state its stamp source and treat "unknown or non-ancestor `built_at_commit`" as no stamp.

### Edge Cases

**Blocking: the shrink-guard bullet is wrong for 0.9.61, and it drives a wrong recommendation.**
Newly ignored live sources are evicted as deletions and pass the guard without `--force` (see Evidence).
Default to rebuilding without `--force`: if the guard refuses, that is a finding (an unexplained loss), not something to override by reflex.
The maintainer-worktree bullet follows from the same mechanism.
Once a worktree merges main, `.graphifyignore` shows as changed in its stamp diff, the wrapper runs `update`, and the index self-heals with no deletion needed.
Verify this once in the throwaway worktree: copy the pre-clean graph, apply the new ignore, run the wrapper, and check that the node count drops with no `--force`.
Then correct both bullets.

The remaining edge cases (shared bare repo, `--detach`, nondeterminism, stale questions) are sound.

### Test Plan and Verification Methodology

These are sound and proportionate.
The per-prefix zero checks and the zero-`.md` check are exact and cheap.

**Non-blocking**: to make the floor re-runnable by a cold reviewer, the report should carry a copy-pasteable command block with explicit `GRAPHIFY_OUT`, worktree path, and commit.
Step 4 should state that the queries run against the floor's own freshly built graph from step 1.
`--force` in step 1 is a no-op on an empty output dir and can be dropped.
"Measurements use one detached throwaway worktree" conflicts with the fresh-worktree row, which needs a new worktree per run.
Say "one long-lived throwaway plus short-lived ones for that row, all removed".

### Implementation Phases

The proportions are right: a single implementer, sonnet for sampling and ground truth, and no clauthier code landing.
Phase 1 currently commits `.graphifyignore` before any query evidence, which is fine given the md-island probe.

## Verdict

**Revise.**
The design is sound and appropriately small for the maintainer's ask, but four items must change before implementation:
1. A markdown default inverted per the maintainer's direction.
2. An explicit `GRAPHIFY_OUT` on raw calls.
3. A shrink-guard and `--force` claim consistent with the source.
4. A post-edit edit that changes topology.
5. The mid-edit background-refresh option, considered as a candidate.

Most are a sentence or a table row.
The markdown inversion touches the BLUF, Phase 1, one design decision, and the test plan, but needs no re-architecture.

## Action Items

1. [blocking] Add a rule that every raw `graphify` call (update, extract, query) sets `GRAPHIFY_OUT` to a scratch dir, with only the Phase 1 rebuild targeting `/var/cache/graphify-weftwise`. Rewrite the "Wrapper `main_out` resolution" edge case accordingly, and apply the rule to the no-op row, the query-latency row, and floor step 3.
2. [blocking] Correct the shrink-guard edge case: in 0.9.61, newly ignored sources pass the guard without `--force`. Rebuild without `--force`, and treat a refusal as a finding. Fix the maintainer-worktree bullet (indexes self-heal after merging main) and add a one-run verification in the throwaway worktree.
3. [blocking] Make the post-edit edit add a call or import, so that clustering, the report, and html run. Optionally add a body-only row.
4. [blocking] Add a background-refresh scratch-wrapper candidate (stale-index query plus async update, or `graphify watch`), measuring query latency during refresh and the edit-to-fresh window. Alternatively, require the implementer verdict to argue why it is excluded.
5. [blocking] Per maintainer direction, invert the markdown default. The default ignore is `/cdocs/`, `/_archive/`, `/docs/references/`, plus inventory-proven non-md lines, with markdown otherwise kept. Make unanchored `*.md` a Phase 3 variant, judged on seed noise and build-time share, and cite the md-island evidence. Reword the "Code-only by rule" decision and move the zero-`.md` test check to the variant.
6. [non-blocking] Drop the speculative `/data/`, `/df-feedback/`, and `/infra/` lines (none are graphed), and reword "`/cdocs/` (kept)". Record the maintainer's call on `/.claude/rules/cdocs.md` and `AGENTS.md` (question 1 below).
7. [non-blocking] Promote `--no-cluster` and `extract --code-only` (incremental) to full candidates. Give `extract` a node and edge fidelity diff against a full update, and add `GRAPHIFY_NO_BACKUP=1`. Use `extract --timing` for stage breakdowns.
8. [non-blocking] Name the code-edge relation set for the resolution check.
9. [non-blocking] Sampler: sort devlogs by filename date, skip graphify meta-devlogs, and tag 2-3 questions as overseer-style base queries.
10. [non-blocking] Merge or drop the raw no-op update rows (raw update has no no-op path), and run commit-only once.
11. [non-blocking] Inventory: record `built_at_commit` `ab8edd6e`, noting it is equivalent to `5e446a84` outside `cdocs/`.
12. [non-blocking] Stamp prototype: consider deriving the stamp from `graph.json` `built_at_commit` at copy time, and state the dirty-builder residual risk.
13. [non-blocking] Floor: require a copy-pasteable command block in the report, run step 4 against the step 1 graph, and drop `--force` on the empty-dir build.

## Questions for the Maintainer

1. Materialized cdocs rules in weftwise, `/.claude/rules/cdocs.md` (70 nodes) and the inlined block in `AGENTS.md` (77 nodes):
   - (a) Exclude `/.claude/rules/cdocs.md` as duplicated tooling text, and keep `AGENTS.md`, which cannot be split (reviewer's recommendation).
   - (b) Exclude both as cruft, accepting the loss of `AGENTS.md`'s weftwise-specific headings.
   - (c) Keep both by default, and let the `*.md` variant's seed-noise evidence decide.
2. Mid-edit lever:
   - (a) Prototype and measure background refresh in the scratch wrapper (reviewer's recommendation).
   - (b) Reason about it in the report only, without measuring.
   - (c) Out of scope; wait for upstream.
3. Kept-stamp source for the fresh-worktree prototype:
   - (a) The wrapper derives it from `built_at_commit` at copy time (no builder coupling).
   - (b) The main-graph builder writes a wrapper-format stamp (the proposal's plan).
