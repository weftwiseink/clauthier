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

- next_steps: awaiting maintainer: acceptance (`implementation_accepted`), `source` condition decision, upstream note filing decision, kept-stamp wrapper change decision.
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
  - decision (overseer call): `source` export condition measured fully but kept a report recommendation, not committed to weftwise main (changes package metadata the app build reads).
  - decision (overseer call): upstream `dist/` resolution note drafted in the report, filing held for the maintainer.
  - decision (overseer call): BLUF leads with per-role answer; implementers "usable now with discipline, flexible mid-edit waits for upstream".
  - decision (overseer call): full trim to ~half (maintainer prefers minimal docs).
  - todo: weftwise has other worktrees (`bocsync-bailout`, `df-to-mount`, `dogfood-sept`, `logical-core`, `loro-branching`, `loro-repo-package`); the assessment must not touch them.

## Workstream Devlogs

| devlog | concern | status | read this when |
|---|---|---|---|
| `cdocs/devlogs/2026-10-08-graphify-weftwise-assessment-impl.md` | assessment execution | review_ready | per-phase commands, raw numbers, deviations |

## Iterate Brief (Turn 0)

`/cdocs:iterate cdocs/proposals/2026-10-08-graphify-weftwise-assessment.md` (`implementation_ready`, `39e8244`), overseer: this top-level session; implementer commits clauthier docs on `main` by exact path and the ignore change on weftwise `main`; throwaway weftwise worktree `gfy-assess`.
Verification floor: proposal floor block passes as written on the cleaned graph; ignore commit and node counts reproducible; query set, grep ground truth and graded results kept with provenance; maintainer worktree HEADs unchanged; main graph written only by Phase 1.
Failure picture: `_archive/` silently back in a cleaned build, a raw command overwriting the main graph, timings taken on a busy container, usefulness judged after seeing graphify output.

## Iteration Log

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | notes |
|---|---|---|---|---|---|---|
| r1 | prop-1 (cdocs:proposer, opus) | rev-1 (cdocs:reviewer, opus, fresh) | revise | n/a | `cdocs/reviews/2026-10-08-review-of-graphify-weftwise-assessment.md` | md scope inverted, `GRAPHIFY_OUT` hazard, `--force` wrong, post-edit shape, background refresh missing |
| r2 | prop-1 (warm) | rev-2 (cdocs:reviewer, opus, fresh) | proposal_accepted | n/a | `cdocs/reviews/2026-10-08-review-of-graphify-weftwise-assessment-r2.md` | 3 pre-dispatch fixes + trims |
| impl-1 | impl-1 (cdocs:implementer, opus) | rev-impl-1 (cdocs:reviewer, opus, fresh) | revise | confirmed | `cdocs/reviews/2026-10-08-review-of-graphify-weftwise-assessment-impl-r1.md` | `dist/` resolution gap + `source` condition fix; 39-edge misattribution; Q12 regrade |
| impl-2 | impl-1 (warm) | rev-impl-2 (cdocs:reviewer, opus, fresh) | accept | confirmed | `cdocs/reviews/2026-10-08-review-of-graphify-weftwise-assessment-impl-r2.md` | accept-round: BLUF framing, trim, small fixes |

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
| return | prop-1 | `39e8244` | 2026-10-08T20:33 | `implementation_ready`: worktree move after ignore commit + node count per build; `bash -c` floor; `watch` dropped with report note; trims (6 candidate rows + 2 prototypes); stale-edge yes/no check; pgrep cleanup; floor renumbered with wrapper copy |
| dispatch | impl-1 (cdocs:implementer, opus) | clauthier report + impl sub-devlog on main; weftwise `.graphifyignore` on main; throwaway `gfy-assess` worktree | 2026-10-08T20:35 | iterate round 1, all phases |
| return | impl-1 | clauthier `88b959f..af3d6d8`; weftwise `2791713d` (unpushed) | 2026-10-08T21:15 | floor passes. Verdict: startup agents and reviewers use now; implementers mid-edit wait (blocking refresh 11.84 s > 10 s bar) unless disciplined or background refresh (0.5 s, stale for just-edited code, missed new edge 3/3). Nodes/edges 16,129/31,272 to 9,731/25,121, no kept-code edge lost, no `--force`. Cleaned: full 9.60 s, structural post-edit 11.84 s, body-only 9.03 s, no-op 0.63 s, commit-only 0.54 s, fresh worktree 11.88 s, queries 0.23-0.50 s. Candidates: md out 0.1-0.3 s; tests out 6.27 s but loses test blast radius; `--no-cluster` 8.18 s but writes raw extraction (fails identity, Q8 miss to misleading); workers no gain; `extract --code-only` 3.63 s but -56 `calls`; kept stamp fresh worktree 11.88 to 0.93 s. Usefulness 7 hit / 4 partial / 2 miss / 1 misleading of 14; ~half the commands and tokens of grep. Deviations: stray `explain --help` wrote `cache/last_query_stamp` to main cache; `*.scss.d.ts` ignore; fresh worktree +39 `imports_from` edges forces topology change; JSON candidate degenerate; `.rebuild.lock` check. Unverified: 3 startup questions, single judge, background refresh during editor writes, kept stamp vs dirty-tree main build; host load 0.9-4.3. Maintainer worktree HEADs unchanged |
| dispatch | rev-impl-1 (cdocs:reviewer, opus, fresh) | `cdocs/reviews/2026-10-08-review-of-graphify-weftwise-assessment-impl-r1.md` | 2026-10-08T21:17 | impl round 1; must re-run floor; spot-check grading |
| return | rev-impl-1 | `57a6f66` | 2026-10-08T21:35 | revise, `review_proof: confirmed` (floor within 2%, counts exact, collateral clean). Blocking: 39-edge diff is `packages/loro-repo/dist/` presence (gitignored, main only), not build path, kept stamp safe; graph has 0 edges weft to `loro-repo/src` (31 importers) because import resolves via `exports` to unextracted `dist/`, adding `"source": "./src/index.ts"` export condition added 204 edges and turned Q7 misleading to hit; Q12 miss to partial (7/5/1/1). Non-blocking: `--no-cluster` raw write is documented, lock-file existence check breaks after a killed update, stray write was an expired freshness marker, build-path text repeated 5x. 2 maintainer questions (`source` disposition, upstream note timing) |
| dispatch | impl-1 (warm, SendMessage) | report, impl devlog; throwaway weftwise worktree | 2026-10-08T21:37 | r1 revisions; measure `source` condition fully (deltas, re-grade, timing, other packages, toolchain honouring `source`); report recommendation only; upstream note drafted not filed; re-run floor |
| return | impl-1 | `9ed344b`, `8138133`, `0022b00` | 2026-10-08T22:00 | all r1 items applied, floor (6 steps) passes. `source` conditions on loro-repo + loro-multiplex (command-deer optional): +653 edges, 623 cross-package into `src/`, timing within noise, fresh-worktree first query 11.87 to 8.99 s (no topology change); Q7 misleading to hit, Q8 miss to partial, Q4 blast radius 6 to 34; tally on that graph 8 hit / 6 partial. Toolchain inert (no `resolve.conditions`/`customConditions`, vite 7.3.0 defaults, tsx, eslint resolver). Background-refresh lock WARN; kept-stamp residual risk broadened. Not verified: weftwise builds/tests with `source`, single grader, 3 startup questions. Weftwise unchanged at `2791713d`. impl-1 ~346K |
| dispatch | rev-impl-2 (cdocs:reviewer, opus, fresh) | `cdocs/reviews/2026-10-08-review-of-graphify-weftwise-assessment-impl-r2.md` | 2026-10-08T22:02 | impl round 2; re-run floor; spot-check toolchain + one regrade; final holistic read |
| return | rev-impl-2 | `92f1522` | 2026-10-08T22:15 | accept, `review_proof: confirmed`: 7-step floor exit 0, counts exact, timings within 2.5%, collateral clean; toolchain inert (vite 7.3.0 / vitest 4.0.16 / tsc 5.9.3 bundler; 7 vite + 5 vitest configs, not 5 + 2); Q8 partial confirmed; Q4 35 not 34; fresh-worktree with `source` 8.96 s. Non-blocking: ~5,300 words, BLUF reaches per-role answer on line 9 and is stricter than the role table for implementers; repetition (tally, `path`, background caveat 3-4x); process detail belongs in devlog. 2 maintainer questions (BLUF framing, trim depth) |
| dispatch | trim-1 (cdocs:implementer, opus, fresh) | report, impl devlog | 2026-10-08T22:17 | accept-round items: BLUF per-role first, full trim to ~half, wording/count fixes; docs only, no number or verdict change |
| return | trim-1 | `72fc23c`, `f962f61` | 2026-10-08T22:35 | accept-round items applied; BLUF per-role first; 5,265 to 3,668 words before floor (~30%, not half: kept sections ~1,570 words; further cuts would drop Runtime Matrix/Candidates rows); process detail moved to impl devlog; floor byte-identical; only new values Q4 35 and config counts 7/5/13; nit_fix clean (semicolons left) |

## Steering Log

- 2026-10-08T19:30: maintainer: "_archive is in the weftwise graph!? Ok, all the speed results are totally moot if that's the case. Have a more fully-fledged dedicated performance assessment /full-send in weftwise with cdocs, _archive, and any other cruft fixed. The assesser should have a sonnet sample recent devlogs for query ideas, and then the results from cdocs:graphify should be evaluated heuristically/holsitically. The assesser should aim to weigh the results pragmatically, both WRT to runtime performance and usefulness quality. Maybe there are some flags we can switch to improve graph build time or something without impacting our core usecase? An inefficient tool isn't the end of the world and maybe we do just wait for improvements, but it does hinder our ability to use the tool flexibly, ie for active implementers etc"

- 2026-10-08T19:55: maintainer: "where do those other markdown headings come from? In weftwise docs/references should prob be excluded but otherwise markdown can prob be included unless detrimental". Overseer measured md heading nodes (current graph, 6,913 total): `_archive` 6,003 (devlogs 3,539, proposals 1,870, reports 576), `docs/` 553 (references 256, other 297), `packages/` 131, `.claude/` 117 (rules/cdocs.md 70, commands 47), `AGENTS.md` 77, `CLAUDE.md` 18, `README.md` 14. Proposal default flips to markdown in, except `/_archive/`, `/cdocs/`, `/docs/references/`; other exclusions only if shown detrimental.

- 2026-10-08T22:30: maintainer: "Sounds like no meaningful improvement to graphify performance, only tiptoe-ing around their poor perf, right? How did the usefulness assessment fare?" then "It never found useful info beyond grep across all sample scenarios? What were the scenarios?" Overseer: correct on perf; usefulness grading was against a grep ground truth, so it measured efficiency, not discovery, and the devlog-sampled questions name their entities (favouring grep). Offered a discovery-style follow-up (questions without entity names, second grader); not dispatched.
