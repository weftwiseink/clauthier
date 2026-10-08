---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T19:35:00-07:00
task_list: cdocs/graphify-weftwise-assessment
type: devlog
state: live
status: wip
tags: [graphify, performance]
chat_record:
  - cdocs/_chat/2026-10-07-63ac45de-462d-4f43-ae1c-4ab6d59049b8.md
---

# Graphify Weftwise Assessment: Devlog

> BLUF: Top-level `/cdocs:full-send` of a dedicated graphify performance and usefulness assessment on weftwise, after cutting the graph to code (no `cdocs/`, `_archive/`, or other cruft).
> Earlier speed numbers are moot: the weftwise graph had 6,058 of 16,129 nodes from `_archive/`.

## Objective

Decide whether `/cdocs:graphify` is usable flexibly on weftwise, including by implementers mid-edit, or whether we wait for upstream improvements.
Weigh runtime (full build, no-op, post-edit, fresh-worktree first query) and usefulness (realistic queries sampled from recent weftwise devlogs, judged holistically) pragmatically, and look for graphify flags or config that cut build time without hurting query/explain of code entities.

## Scratchpoint

- next_steps: prop-1 applying r2 accept-round fixes; then `/cdocs:iterate` with a fresh implementer.
- graphify_base_query:
- important_files: `plugins/cdocs/bin/cdocs-graphify`, `plugins/cdocs/skills/graphify/SKILL.md`, `cdocs/reports/2026-10-08-graphify-update-performance-audit.md`, `cdocs/reports/2026-10-08-graphify-upstream-health.md`, weftwise `.graphifyignore`
- callouts:
  - decision (overseer call): docs for this workstream live in clauthier (it evaluates `/cdocs:graphify`); only the scope fix and any graphify config are weftwise commits.
  - decision (overseer call): `graphify_base_query` left empty: the code under study is graphify's installed source and the weftwise graph itself, which the assessment queries directly.
  - decision (overseer call): `/.claude/rules/cdocs.md` and `AGENTS.md` stay in by default, tested as an exclusion variant.
  - decision (overseer call): background refresh (stale-index query + background refresh, `graphify watch`) measured as a scratch-prototype candidate.
  - decision (overseer call): fresh-worktree stamp derived from the copied graph's `built_at_commit`; scratch prototype.
  - decision (overseer call): apply r2 candidate trims (graph-identity check for non-graph flags, one output-stage row, `.claude/`+`AGENTS.md` folded into all-md-out).
  - decision (overseer call): drop `graphify watch` rather than install watchdog; audit shows it is the same full rebuild.
  - todo: weftwise has other worktrees (`bocsync-bailout`, `df-to-mount`, `dogfood-sept`, `logical-core`, `loro-branching`, `loro-repo-package`); the assessment must not touch them.

## Workstream Devlogs

| devlog | concern | status | read this when |
|---|---|---|---|

## Iteration Log

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | notes |
|---|---|---|---|---|---|---|
| r1 | prop-1 (cdocs:proposer, opus) | rev-1 (cdocs:reviewer, opus, fresh) | revise | n/a | `cdocs/reviews/2026-10-08-review-of-graphify-weftwise-assessment.md` | md scope inverted, `GRAPHIFY_OUT` hazard, `--force` wrong, post-edit shape, background refresh missing |
| r2 | prop-1 (warm) | rev-2 (cdocs:reviewer, opus, fresh) | proposal_accepted | n/a | `cdocs/reviews/2026-10-08-review-of-graphify-weftwise-assessment-r2.md` | 3 pre-dispatch fixes + trims |

## Judge Log

| judge_iteration | trigger | verdict | rationale |
|---|---|---|---|

## Dispatch/Return Events

| event | agent_handle | target_files | at | notes |
|---|---|---|---|---|
| dispatch | prop-1 (cdocs:proposer, opus) | `cdocs/proposals/2026-10-08-graphify-weftwise-assessment.md` | 2026-10-08T19:38 | assessment plan: scope fix, sonnet devlog query sampling, holistic usefulness rubric, runtime matrix, flags/config exploration, report deliverable |
| return | prop-1 | `2ee96f8`, `0de4e1c` | 2026-10-08T19:45 | `review_ready`, 3 phases: (1) same-session baseline, ignore `/_archive/ /docs/ /.claude/ /data/ /df-feedback/ /infra/` + unanchored `*.md` (keep tsconfig/package.json), `--force` rebuild (shrink guard), node/edge + code-to-code edge counts; (2) sonnet samples 12-15 questions from ~30 recent devlogs, separate sonnet grep ground truth first, rubric hit/partial/miss/misleading + tokens, vs pre-clean graph; (3) 6 timing cases x3 with load, candidates (docs back, tests out, JSON out, skip html/report, `GRAPHIFY_MAX_WORKERS`, `--no-cluster`, stamp-across-copy scratch prototype) with 5-query spot checks; thresholds <=3 s usable mid-edit, >10 s wait. Findings: 6,913 of 16,129 nodes are md headings; `_archive/` tracked (437 files); `cdocs-graphify` not on container PATH; main graph has no `.stamp`. Maintainer worktrees keep stale indexes (report recommends deletion, not touched) |
| dispatch | rev-1 (cdocs:reviewer, opus, fresh) | `cdocs/reviews/2026-10-08-review-of-graphify-weftwise-assessment.md` | 2026-10-08T19:47 | round 1; probe scope fix, flag existence, missed speed levers, measurement minimality, floor re-runnability, stamp prototype |
| steer | rev-1 (SendMessage) | review | 2026-10-08T19:55 | maintainer markdown direction relayed + overseer md-node breakdown |
| return | rev-1 | `2c0c62b` | 2026-10-08T20:05 | revise. Blocking: markdown scope inverted vs maintainer direction (md nodes have no code edges, affect only seed ranking); container-global `GRAPHIFY_OUT` makes raw update/extract/query write the main graph; `--force` unneeded (ignore removal counts as deletion, worktree indexes self-heal on merge); body-only post-edit may skip cluster/report/html (~4 s) so under-measures; background refresh / `graphify watch` missing. Missed levers: `extract --code-only` (incremental; check TS cross-file edges), `GRAPHIFY_NO_BACKUP=1`, `extract --timing`; `--no-cluster` worth a full row (query ignores communities). Non-blocking: speculative ignore lines, graph built at `ab8edd6e`, trim duplicate no-op rows, sampler sort/skip graphify devlogs, copy-pasteable floor block, stamp from `built_at_commit`. 3 maintainer questions |
| dispatch | prop-1 (warm, SendMessage) | proposal | 2026-10-08T20:07 | round-1 revisions + maintainer md direction + overseer calls on the 3 questions |
| return | prop-1 | `6e4d7e1` | 2026-10-08T20:15 | `review_ready`: all r1 items applied; default ignore `/cdocs/ /_archive/ /docs/references/`; all-md-out and `.claude/`+`AGENTS.md`-out as variants; explicit scratch `GRAPHIFY_OUT` rule (only Phase 1 writes main graph); plain `update`, shrink-guard refusal reported not forced; structural post-edit; background refresh + `graphify watch` rows incl. stale-answer count; stamp from `built_at_commit` (ancestor check); `extract --code-only` parity, `GRAPHIFY_NO_BACKUP`, `--no-cluster`, `--timing`. Rough edge: floor `time` in `sh -c` |
| dispatch | rev-2 (cdocs:reviewer, opus, fresh) | `cdocs/reviews/2026-10-08-review-of-graphify-weftwise-assessment-r2.md` | 2026-10-08T20:16 | round 2; r1 resolution + fresh pass, bloat check |
| return | rev-2 | `9f74a07` | 2026-10-08T20:25 | proposal_accepted; 13/13 r1 items resolved. Pre-dispatch fixes: `gfy-assess` never moves onto cleaned ignore (silent `_archive/` return); container `sh` is dash so floor `time` exits 127; `graphify watch` needs uninstalled watchdog. Bloat: spot checks on non-graph flags meaningless, output-stage flags one row, `.claude/`+`AGENTS.md` variant subsumed. Verified: wrapper scopes `GRAPHIFY_OUT` to worktree, `graph.json` written atomically, default scope keeps 654 md nodes, weftwise main clean. Did not flip status (reviewer may edit only `last_reviewed`) |
| dispatch | prop-1 (warm, SendMessage) | proposal | 2026-10-08T20:27 | accept-round fixes + trims, `implementation_ready` |

## Steering Log

- 2026-10-08T19:30: maintainer: "_archive is in the weftwise graph!? Ok, all the speed results are totally moot if that's the case. Have a more fully-fledged dedicated performance assessment /full-send in weftwise with cdocs, _archive, and any other cruft fixed. The assesser should have a sonnet sample recent devlogs for query ideas, and then the results from cdocs:graphify should be evaluated heuristically/holsitically. The assesser should aim to weigh the results pragmatically, both WRT to runtime performance and usefulness quality. Maybe there are some flags we can switch to improve graph build time or something without impacting our core usecase? An inefficient tool isn't the end of the world and maybe we do just wait for improvements, but it does hinder our ability to use the tool flexibly, ie for active implementers etc"

- 2026-10-08T19:55: maintainer: "where do those other markdown headings come from? In weftwise docs/references should prob be excluded but otherwise markdown can prob be included unless detrimental". Overseer measured md heading nodes (current graph, 6,913 total): `_archive` 6,003 (devlogs 3,539, proposals 1,870, reports 576), `docs/` 553 (references 256, other 297), `packages/` 131, `.claude/` 117 (rules/cdocs.md 70, commands 47), `AGENTS.md` 77, `CLAUDE.md` 18, `README.md` 14. Proposal default flips to markdown in, except `/_archive/`, `/cdocs/`, `/docs/references/`; other exclusions only if shown detrimental.
