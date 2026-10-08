---
review_of: cdocs/proposals/2026-10-08-graphify-weftwise-assessment.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T14:00:46-07:00
task_list: cdocs/graphify-weftwise-assessment
type: review
state: live
status: done
tags: [fresh_agent, source_verified, runtime_validated, graphify, performance, scope_bloat]
---

# Review: Graphify Weftwise Assessment (Round 2)

## Summary Assessment

The proposal plans one assessment of `/cdocs:graphify` on weftwise.
It removes `_archive/` and `docs/references/` from the graph, then measures runtime and judges 12-15 sampled questions against a grep ground truth, ending in a per-role verdict.
All 13 round-1 action items are resolved, and the design is sound: markdown stays in by default, `GRAPHIFY_OUT` is explicit, the post-edit is structural, background refresh is a measured candidate, and there is no `--force`.
Three probes found small execution defects, and none of them changes the design:
- the floor block's `time` fails in the container's dash `sh`;
- `graphify watch` cannot run because `watchdog` is not installed and the plan forbids changing the install;
- the plan never moves `gfy-assess` onto the cleaned `.graphifyignore`, so "cleaned" runs there would silently rebuild the pre-clean scope.

The plan is still executable by one implementer in one session, but about a third of the candidate work is ceremony that can be cut.
Verdict: **Accept**. The three defects are one-line edits the overseer can apply directly or put in the implementer's dispatch prompt, without another review round.

## Evidence Gathered

Every probe was read-only, run in container `weftwise` as `node`.

- **Container shell**: `/bin/sh` is `/usr/bin/dash`. `time` is neither a builtin nor a binary (no `/usr/bin/time`), and `sh -c 'time true'` exits 127 with `time: not found`.
  `/usr/bin/bash` exists, and `bash -c 'time true'` works.
- **`graphify watch`**: `watch.py` imports `watchdog`, and `import watchdog` fails in the graphify pipx venv (`ModuleNotFoundError`).
  `watch` also takes no `--out` and resolves its output dir through `GRAPHIFY_OUT`, so the implicit-write hazard applies to it too.
- **Atomic `graph.json`**: `export.to_json` writes through `paths.write_json_atomic` (temp file plus replace).
  `update` holds a per-out-dir `fcntl` lock (`watch._rebuild_lock`, non-blocking by default).
  The Edge Cases race check is therefore a one-line confirmation: a query during a refresh reads the old or the new file, never a partial one.
- **`GRAPHIFY_NO_BACKUP`** exists (`export.py` line 53). `GRAPHIFY_VIZ_NODE_LIMIT` and `GRAPHIFY_MAX_WORKERS` exist. `extract` accepts `--code-only`, `--timing`, `--out`, and `--no-cluster`.
- **Wrapper** (`plugins/cdocs/bin/cdocs-graphify`): it reads `$GRAPHIFY_OUT` only as the copy source, and runs both its `update` and the pass-through query with `GRAPHIFY_OUT="$wt_out"`.
  The operating rule ("wrapper runs set `GRAPHIFY_OUT` to a scratch copy") is therefore safe.
  The copy writes `graphify-out/.gitignore` as `*`, so throwaway worktrees stay clean.
- **Weftwise state**: main is at `5e446a84` and clean (0 entries in `git status --short`), `.graphifyignore` is just `/cdocs/`, and the six maintainer worktrees match the proposal's list.
  The main graph has `built_at_commit` `ab8edd6e`, 16,129 nodes, 31,272 edges, and `.graphify_root` `/workspaces/weftwise/main`.
  `git diff --stat ab8edd6e HEAD -- . ':!cdocs'` is empty.
- **Markdown kept by the default**: 654 md nodes remain once `_archive/` and `docs/references/` are excluded. That is 297 + 131 + 117 + 77 + 18 + 14, matching the steering-log tally.
- **Sampler input**: weftwise main has 497 devlog files.
  The newest dated ones are the two `2026-10-08-graphify-devcontainer-feature*` logs, which the `*graphify*` skip catches. After them come a solid run of September feature devlogs.
- **Audit context**: about 8 s of the 10.3 s no-op is `_collect_js_symbol_resolution_facts`, which is code, not markdown.
  Removing markdown is therefore unlikely to move refresh time much. The report should expect that rather than be surprised by it.

## Round-1 Action Items

| # | Item | Status |
|---|---|---|
| 1 | Explicit `GRAPHIFY_OUT` on raw calls | Resolved (Operating rules, Edge Cases, floor). `watch` missing from the list: see F2 |
| 2 | Shrink guard, no `--force`, self-heal check | Resolved (Phase 1 step 3, step 5, Edge Cases) |
| 3 | Structural post-edit, optional body-only row | Resolved |
| 4 | Background-refresh candidate | Resolved, as a measured scratch prototype (overseer call) |
| 5 | Markdown default inverted, `*.md` as a variant, island cited | Resolved (BLUF, Phase 1, decisions, Test Plan) |
| 6 | Speculative lines dropped, `/cdocs/` wording, maintainer call | Resolved. The cdocs-rules question is recorded as an overseer-call NOTE |
| 7 | `--no-cluster`, `extract --code-only` with fidelity diff, `NO_BACKUP`, `--timing` | Resolved |
| 8 | Named relation set | Resolved |
| 9 | Sampler sort, skip, base-query tagging | Resolved |
| 10 | Duplicate no-op rows merged, commit-only once | Resolved |
| 11 | `built_at_commit` labeling | Resolved |
| 12 | Stamp from `built_at_commit`, dirty-builder risk | Resolved |
| 13 | Copy-pasteable floor, step 4 on the step 1 graph, no `--force` | Resolved in shape. The block itself does not run: see F1 |

## Section-by-Section Findings

### BLUF, Summary, Objective

Clear and faithful to the steering log.
The per-role objective and the maintainer-framing NOTE give the report a definite question to answer.

**Non-blocking (wording)**: "Variants that drop all markdown and other config" reads as if markdown were config.
Suggest "Scope variants (all markdown out, and others) and config flags, plus a background-refresh prototype, ...".

### Operating rules and Edge Cases

The single `GRAPHIFY_OUT` rule is the right fix, and the wrapper source confirms that the wrapper side is safe.

**F2. Non-blocking (subsumed by F3 if `watch` is dropped)**: the rule's explicit list (`update`, `extract`, `query`, `explain`, `path`, `affected`) omits `watch`.
`watch` resolves its output through `GRAPHIFY_OUT` too, so an implicit `watch` run from `gfy-assess` would rebuild into the main graph on every batch.
Say "every raw `graphify` subcommand".

**Non-blocking**: add one cleanup check: no `graphify` process (background `update` or `watch`) is left running before worktrees are removed.
The background-refresh prototype is the first thing in this plan that starts detached processes.

### Phase 1: scope fix

Sound.
The self-heal check is a good way to settle the maintainer-worktree question without touching those worktrees.

**F4. Non-blocking, apply at dispatch: move `gfy-assess` onto the cleaned ignore.**
`gfy-assess` is created before the `.graphifyignore` commit, which step 2 needs for the pre-clean baseline.
Nothing then moves it to the new `main`.
Phase 3 runs "on the cleaned graph" in `gfy-assess`, and both its raw full builds and the wrapper's `update` read that worktree's `.graphifyignore`.
Left on the old commit, every "cleaned" build would quietly regrow `_archive/`.
The wrapper case fails the same way: a copied cleaned graph carries no `.stamp`, so its first `update` runs against the old ignore and regrows `_archive/`.
The Test Plan's zero-prefix checks cover only the main rebuild, so nothing would catch this.
Fix: after the ignore commit, add `git -C /workspaces/weftwise/gfy-assess checkout --detach main`, and record the node count of every Phase 3 full build, which also feeds the nondeterminism range.

### Phase 2: usefulness

Proportionate and well ordered.
Ground truth comes first, the rubric scores misleading output separately, every row records tokens, and the run on the pre-clean graph is cheap.
No findings.

### Phase 3: runtime matrix

**Non-blocking (framing)**: in 0.9.61 every refresh is a full `update`.
The full-build, post-edit, and fresh-worktree rows are therefore expected to collapse to two numbers: `update` with a topology change (about 13-14 s pre-clean) and without one (about 10 s).
The fresh-worktree row lands on "without", because the copied graph already matches the tree.
State that expectation, so that the rows read as confirmation rather than as three independent findings.
They cost little compute, so keep them.

### Phase 3: candidates (bloat check)

The table has 11 rows, each with a full build, a structural post-edit, and a 5-query spot check.
The compute is small, since each build takes about 10-15 s.
The cost lies in implementer attention and in the report's length.
Three cuts keep the useful signal:

1. **Spot checks only where `graph.json` can change.** `GRAPHIFY_VIZ_NODE_LIMIT=0`, `GRAPHIFY_NO_BACKUP=1`, and `GRAPHIFY_MAX_WORKERS` cannot change the graph, so a query spot check on them is ceremony.
   Replace it with a graph-identity check: sorted node and edge sets equal to the baseline.
   `--no-cluster` changes only community attributes, so compare the identity check with those attributes stripped.
   The spot checks remain for the scope variants and for `extract --code-only`.
2. **Merge the output-stage flags into one row.** Run `--no-cluster`, `VIZ_NODE_LIMIT=0`, and `NO_BACKUP=1` together, and attribute the saving per stage from `extract --timing` or the update log.
   Measure `MAX_WORKERS` with one sweep, not as a full candidate.
3. **Fold "`.claude/` and `AGENTS.md` out" into "all markdown out".** The all-md variant already removes those files.
   Run the narrower variant only if the all-md variant shows seed-noise harm that traces to them.

With these cuts, Phase 3 comes down to five substantive candidates: all-md out, tests out, json out, output-stage flags, and `extract --code-only`.
Add the two prototypes, and the plan fits comfortably in one implementer session.

### Phase 3: background refresh and kept stamp

The design is sound, and both are scratch prototypes with no clauthier landing, which is correctly minimal.
The atomic-write probe settles the race edge case.
The stamp prototype's "hash of the empty change set" is what the wrapper itself computes for an empty diff: `git hash-object --stdin` of a single newline.
The implementer should take it from the wrapper rather than invent a format.

**F3. Non-blocking, apply at dispatch: drop the `graphify watch` measurement.**
`watchdog` is absent from the graphify venv, and "Do not change: the graphify install" forbids adding it.
As written, the implementer must either break the constraint or quietly skip a planned measurement.
The audit (options table) already characterizes `watch` as the same full rebuild per batch, with a per-worktree long-lived process.
Replace the sentence with a one-line report note: `watch` needs `watchdog` (not installed); its mechanism and cost equal the prototype's background `update`.

**Non-blocking: define or drop "the share of the sampled questions that a stale-by-one-edit graph would answer differently".**
The sampled questions are not tied to the timed edit, so this share is near zero by construction and says nothing.
Either measure it only on questions whose ground truth touches the edited file, with a purpose-made edit, or replace it with a reasoned bound: staleness affects only queries about entities edited since the last refresh.

### Report and verdict bar

The bar (3 s or less, 3-10 s, over 10 s) and the "variance, not only the median" requirement are right.
Given the audit's breakdown, the honest prior is that cleaned refreshes land at about 8-10 s, close to the upper edge of the middle band.
The variance language will matter there, and `extract --code-only` is the one candidate that could plausibly reach 3 s or less.
No change needed.

### Verification Methodology (floor block)

**F1. Non-blocking, apply at dispatch: the floor's `time` lines fail.**
`x()` runs `sh -c`, which is dash, and dash has no `time` (exit 127, `time: not found`), so the timed `update` never runs.
Fix: change `x()` to `bash -c "$2"`.
Do not time on the host side: `time podman exec ...` adds exec overhead that distorts the sub-second `explain` timings.
This failure is loud, so the implementer would hit it on the first timing. It still belongs fixed in the shape the report copies.

**Non-blocking (completeness of the block)**:
- The steps are numbered 1, 3, 4. Renumber them, or restore the missing step.
- The post-edit line calls `<scratch>/cdocs-graphify`, but the block never copies the wrapper in. Add the `podman cp` line, or state that the wrapper path is a prerequisite.

### Test Plan and Implementation Phases

Sound.
The cleanup check, the named relation counts, and the `extract` fidelity diff are the right exact checks.
One opus implementer plus two sonnet agents is the right staffing.
The phases stay at three.

## Verdict

**Accept.**
Every round-1 item is resolved, and the design answers the maintainer's question: a per-role verdict with a concrete config, weighed on both runtime and usefulness.
F1, F3, and F4 are execution defects, each a one-line edit that changes no design decision:
- F1 fails loudly.
- F3 is a contradiction the implementer would notice.
- F4 is the one that fails silently, and it matters most.

Fixing them does not need a third review round.
The overseer can apply them to the proposal, or state them in the implementer's dispatch prompt.
The candidate trims are recommended but optional.

## Action Items

1. [non-blocking, apply at dispatch] F4: after the Phase 1 `.graphifyignore` commit, `git -C /workspaces/weftwise/gfy-assess checkout --detach main`, so that Phase 3's "cleaned" builds and wrapper runs use the new ignore. Record the node count of every Phase 3 full build.
2. [non-blocking, apply at dispatch] F1: in the floor block, change `x()` to `bash -c "$2"`. Dash has no `time`, and host-side `time` distorts sub-second timings. Use the same helper for all Phase 3 timings.
3. [non-blocking, apply at dispatch] F3: drop the `graphify watch` measurement. `watchdog` is not installed and the install must not change. Note in the report that `watch` equals the prototype's background `update` in mechanism and cost.
4. [non-blocking] F2: make the `GRAPHIFY_OUT` rule "every raw `graphify` subcommand", and add a cleanup check that no `graphify` process is left running.
5. [non-blocking] Trim candidates: graph-identity checks instead of query spot checks for the flags that leave the graph unchanged; one combined output-stage row attributed by `--timing`; a single `MAX_WORKERS` sweep; the `.claude/` and `AGENTS.md` variant only if all-md out shows harm traced to them.
6. [non-blocking] Define the stale-by-one-edit share on questions touching the edited file, or replace it with a reasoned bound.
7. [non-blocking] State the expectation that the full-build, post-edit, and fresh-worktree rows collapse to "update with or without a topology change" in 0.9.61.
8. [non-blocking] Floor: renumber its steps, and add the wrapper `podman cp` line.
9. [non-blocking] BLUF wording: separate the scope variants from the config flags.

## Questions for the Maintainer

1. Candidate trims (action item 5):
   - (a) Apply all three cuts. Phase 3 keeps five substantive candidates plus two prototypes (reviewer's recommendation).
   - (b) Keep the full 11-row table as written. It costs more attention, but nothing is skipped.
   - (c) Apply only the identity-check cut, and keep separate rows for each flag.
2. `graphify watch` (action item 3):
   - (a) Drop it and note why (reviewer's recommendation).
   - (b) Allow `pipx inject graphifyy watchdog` in the container for this assessment only, then remove it. This relaxes "do not change the graphify install".
