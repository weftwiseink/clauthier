---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T16:49:00-07:00
task_list: cdocs/graphify-weftwise-assessment
type: report
state: live
status: review_ready
last_reviewed:
  status: revision_requested
  by: "@claude-opus-5-5"
  at: 2026-10-08T17:10:00-07:00
  round: 2
tags: [analysis, subagents, context_bloat, graphify, performance]
---

# Search Subagent for Context Prep

> BLUF: Build no searcher agent and no prep pass.
> Discovery search plus exploratory reads is about 14% of growth to peak context for weftwise code implementers, and 11% at the 800K+ peaks.
> Those peaks track session length, and the agent's own output is 43% of their growth.
> The code-work sample is old (Opus 4.8, September, pre-0.2.0 rules), so the next step is a baseline on current-rules `cdocs:implementer` runs on weftwise code (Opus 5.5).
> Overseer calls: graphify keep/drop belongs to the assessment's Phase 5, and no `Explore` guideline ships on this evidence.

## Context

The maintainer judged graphify not worth its upkeep after the weftwise assessment ([report](2026-10-08-graphify-weftwise-assessment.md), "Value Beyond Grep").
The original motivator was context bloat in the opus implement and review agents.
This report asks whether a sonnet search and context-prep subagent, along the lines of `cdocs:bash-runner`, would cut that bloat.

The maintainer has not said which harm "bloat" means, so the conclusion is given for each meaning:

- **Cost per loop**: a searcher does not pay.
  For clauthier work, one `Explore` dispatch ($0.31-0.43) costs more than the search output it would replace.
  For weftwise implementers, exploratory reads cost about $1.8 per agent at the median (review's figure, Opus 4.8 rates), about four dispatches.
  That pays only if the searcher displaces reads, and the one observed case shows no displacement (below).
- **Hitting context limits**: only weftwise implementers come close (p90 739K, max 999K; 3 of 61 compacted).
  Their peaks track request count (Spearman 0.84), and the agent's own output is 43% of growth at the top 10.
  The lever is session length, not search.
- **Quality at depth**: not measured.
  A searcher would remove at most about 14% of median weftwise implementer growth; whether that changes quality is unknown.

clauthier peaks (110K and 163K medians, 401K max, on 1M-context models) show no bloat to cut.
Search is the largest tool slice there (15-18% of growth), so clauthier's conclusion rests on there being little to save, not on search being small.

## Method

- **Transcripts**: every `cdocs:implementer` and `cdocs:reviewer` subagent since 2026-09-20 under `~/.claude/projects/-var-home-mjr-code-weft-clauthier-main` and `-workspaces-weftwise-main`, plus the `Explore` and `bash-runner` runs.
  Added to these: 61 weftwise implementers, which are `general-purpose` dispatches whose description says "implement", since 2026-09-01, excluding one artifact build and one Sonnet search.
- **Context**: each request's context is `input + cache_read + cache_creation`, deduplicated by `requestId`.
  Growth is measured from the start of the peak's segment (after the last compaction, detected as a drop of 40% or more) up to the peak request.
  Tool-result tokens are characters divided by a per-agent chars-per-token ratio calibrated from context deltas.
  That ratio is constant within an agent, so it does not skew shares among tool kinds, only the tool-versus-output split.
- **Classifier**: Bash commands are classified by any verb in a compound command, in this order:
  1. test/build (`pnpm|npm|npx|vitest|tsc|...`);
  2. discovery (`grep|rg|find|fd|ls|tree`, `git grep|ls-files`, plus the Grep and Glob tools);
  3. git history (`git log|show|diff|blame`);
  4. file reads (`cat|sed|head|tail|awk|jq`, plus the Read tool).
- **Read slices**: these are subsets of reads, and they overlap.
  - Exploratory: a path the agent never edited (full-path match), outside `cdocs/`.
  - Re-read: a path read earlier in the run.
  - Whole-file large read: a Read with no `offset`/`limit` of a file of 300 or more lines.
- **Denominators**: shares are of growth to peak, or of tool results only (no attachments) where labeled.
- **Prices**: list API, as a proxy.
  - Opus 5.5: $4 / $20 per MTok, cache reads $0.20.
  - Sonnet 5: $2 / $10, cache reads $0.20.
  - Opus 4.8: $5 / $25, cache reads $0.50.
  - Fable 5: cache reads $1.
  - Fable 5.1: cache reads $0.25.
- **Scripts**: `v2.py` and `agg2.py` in the session scratchpad (`.../scratchpad/ctxsearch/`, ephemeral).
  The review re-measured the same transcripts independently (`d581087`); where its counts differ from these, both are given.

## Key Findings

**Sample limits.**
- The code-work population is stale and conditioned differently from current loops.
  All 61 weftwise implementers ran 2026-09-01 to 09-21 on Opus 4.8 or Fable, as `general-purpose` dispatches with ad hoc prompts, under weftwise cdocs rules v0.1.0 (no `bash-runner`, no graphify, no tool-use guidance).
- No current-rules Opus 5.5 `cdocs:implementer` has done code work in this sample.
- clauthier implementers do docs work: 46% of their reads are proposals, devlogs, and reviews.
- Every code-work number below therefore comes from a population that a current guideline would not reach.

**Where peak context goes** (share of growth to peak):

| Population | n | Base | Peak median / p90 / max | Requests (median) | Own output | All reads | Whole-file 300+ line reads | Exploratory reads | Re-reads | Discovery search | Git history |
|---|---|---|---|---|---|---|---|---|---|---|---|
| clauthier implementers, Opus 5.5 | 29 | 39K | 163K / 332K / 401K | 52 | 43% | 27% | 9% | 5% | 4% | 15% | 2% |
| clauthier reviewers, Opus 5.5 | 111 | 35K | 110K / 164K / 288K | 22 | 32% | 36% | 13% | 8% | 3% | 18% | 5% |
| weftwise reviewers, Opus 4.8 or Fable 5.1 | 22 | 59K | 146K / 190K / 260K | 25 | 31% | 43% | 19% | 14% | 8% | 9% | 8% |
| weftwise implementers, Opus 4.8 or Fable | 61 | 55K | 330K / 739K / 999K | 129 | 35% | 31% | 12% | 9% | 4% | 5% | 0% |
| top 10 of those, by peak | 10 | 55K | 823K / 999K / 999K | 460 | 43% | 22% | 6% | 6% | 5% | 5% | 0% |

The rest of growth is test and build output, other tools, and attachments (7-14%).

- **Per-agent whole-run medians, weftwise implementers**:
  - Discovery plus history search: 14K, which is 12% of tool results.
  - Exploratory reads: 25K (p75 42K, p90 60K).
  - Whole-file large reads: 33K.
  - Re-reads: mean 15K, and 45K in the top 10.
  - Own output: 74K.
- **Per-agent whole-run medians, clauthier**: search is 26K for implementers and 16K for reviewers, which is 35-37% of tool results.
- **What peak tracks** (weftwise implementers, Spearman):

  | Peak against | ρ |
  |---|---|
  | Request count | 0.84 |
  | Total reads | 0.85 |
  | Discovery search | 0.71 |
  | Own output | 0.69 |
  | Exploratory reads | 0.60 |
  | Whole-file large reads | 0.53 |

**Searcher guidance and its uptake.**
- No rule tells implementers or reviewers to dispatch `Explore`.
  The model-tiering line "`sonnet` for search, explore" picks a model for subagents; it does not say when to dispatch one.
  Zero `Explore` dispatches by the 162 Opus implementers and reviewers therefore says nothing about compliance.
- The `bash-runner` rule landed 2026-10-05.
  114 of the 162 ran after it (review: 116 of 167, counting non-Opus).
  62 of those 114 used its redirect-to-file option (review's matcher: 72, 317 commands), and one implementer dispatched `bash-runner` twice.
- After the rule, 250 discovery searches of 2K+ tokens still ran inline, in 96 agents (review's narrower classifier: 209 in 88).
- Natural experiment: three weftwise implementers dispatched `Explore` on their own (8 dispatches; the review counts 4 agents and 9 dispatches).
  The two largest (peaks 739K and 999K) still read 42K and 67K of never-edited source, at and above the population's p75.
  This is a tiny sample, confounded by task size, but it is the only observed opus implementer using a searcher, and reads were not displaced.

**What a searcher costs** (secondary constraints):

| Agent | Base | Peak (median) | Cost median | Wall median | Returns |
|---|---|---|---|---|---|
| `Explore`, Sonnet 5 (19 runs) | 16K, no CLAUDE.md or rules | 63-69K | $0.31-0.43 | 100 s | about 1-8K tokens |
| `bash-runner`, Sonnet or Haiku (49 runs) | 11-12K, includes CLAUDE.md and rules | 13-15K | $0.02-0.05 | 7-26 s | at most about 600 words |

- Fixed overhead is 11-16K tokens per dispatch, and little of it is cached across dispatches (about 3K read, 9-12K written on the first request).
- Sonnet 5 is half Opus 5.5's price except on cache reads, which cost the same.
  Re-pricing the `Explore` runs at Opus 5.5 rates gives 1.63 times the Sonnet cost.
- A custom cdocs agent would carry CLAUDE.md and the rules (about 7K tokens).
  `Explore` skips them, and no frontmatter field lets a custom agent do the same ([sub-agents docs](https://code.claude.com/docs/en/sub-agents.md)).
- A searcher blocks its caller for about 100 s.
  In interactive sessions it also forces a turn boundary, because subagent dispatch is async there ([context preservation report](2026-10-08-subagent-context-preservation-options.md), findings 2 and 4).

**Accuracy.**
- Phase 4's sonnet arms found 74-79% of important items on discovery tasks, with 1-2 wrong and 1-3 misleading items over 8 tasks.
- Misses matter most for absence claims ("nothing else calls X").
- `review_proof` admits only artifacts the reviewer's own round produced, so a searcher summary is never evidence.
  A reviewer would have to open each `file:line` it relies on and grep for absence itself, which claws back much of the saving.

## Options

| Option | Ceiling on context saved | Costs and risks |
|---|---|---|
| a. `Explore` guideline for wide sweeps | Part of discovery plus exploratory reads | Uptake and displacement unshown; verification claws back savings |
| b. Dedicated `cdocs:searcher` | Same as (a) | A new agent file; about 7K more base than `Explore`; its only gain is a fixed format a prompt can request |
| c. Overseer prep brief before each dispatch | About 14% of median weftwise implementer growth (11% at top peaks); about 22-31% for clauthier, where peaks are not a problem | $0.31-0.43 and about 100 s per dispatch on the critical path; misses 21-26%; anchors reviewers, whose value is independence; does not touch needed reads |
| e. Guideline: read ranges of large files after locating them, and don't re-read files already in context | Whole-file large reads 12% plus re-reads 4% of weftwise implementer growth (6% and 5% at top peaks); the slices overlap | Guideline only; no new part |
| f. Shorter sessions: per-phase implementer dispatch, effort level | Own output is 35-43% of growth, and peak tracks request count | Already a workflow pattern ("CDocs Workflow Patterns › Loops and multi-phase plans"); effort affects quality |

How (c) differs from the graphify base query it would replace:
- The base query was one cheap call the agent ran itself.
- A brief is precomputed answers from another model, paid on every dispatch, with a known miss rate.
- The devlog's Changes Made table and Scratchpoint already seed a fresh reviewer at no cost.

## Recommendations

- **No searcher agent and no prep pass (b, c).**
  Confidence is high on cost and latency.
  It is medium on peak context, because the code-work sample is Opus 4.8, September, and unconditioned.
- **Overseer call: the `Explore` guideline (a) does not ship on this evidence**: at most a measured trial.
  Confidence that it would help is low: nothing observed shows displacement.
- **Overseer call: the leading context levers are session length and how files are read.**
  - Session length (f): own output is 43% of growth at the top peaks, and peak tracks request count.
  - Read discipline (e): whole-file reads of 300+ line files are 33K per weftwise implementer at the median.
    That exceeds discovery search (14K) and exploratory reads (25K) taken separately; the slices overlap.
- **Overseer call, next step**: measure a baseline before any context-bloat fix.
  Run current-rules `cdocs:implementer` on weftwise code (Opus 5.5).
  Report share of peak by own output, edited-file reads, re-reads, whole-file large reads, exploratory reads, and search.
  Then compare (e), (f), and effort level against that baseline.
- **Overseer call: graphify keep/drop is not this report's to make.**
  It is deferred to Phase 5 of the assessment (`cdocs/proposals/2026-10-08-graphify-weftwise-assessment.md`, "Phase 5 decides whether to keep graphify or drop it").
  Phase 5 should report share of peak by whole-file, exploratory, re-read, and search tokens, alongside reach.
- **Question for the maintainer**: which bloat matters: cost, context limits, or quality at depth?

### Reference: graphify removal pointers (no edits made)

- `plugins/cdocs/skills/graphify/`, `plugins/cdocs/bin/cdocs-graphify`, and its section in `plugins/cdocs/bin/README.md` (from line 67).
- `plugins/cdocs/hooks/tests/cdocs-graphify.test.sh` and its step in `.github/workflows/cdocs-hooks.yml` (lines 3, 64-65).
- `plugins/cdocs/rules/tool-use-safeguards.md:7-8` (`npm run test:rules` checks heading references).
- `plugins/cdocs/skills/iterate/SKILL.md` "Base query" (lines 37-42, including the `[base_query: ...]` row tag) and `iterate/template.md:8`.
- `plugins/cdocs/skills/devlog/SKILL.md:64-65` and `devlog/template.md:20` (`graphify_base_query`).
- `plugins/cdocs/skills/init/SKILL.md:97-100` (the `.graphifyignore` step).
- `plugins/cdocs/README.md:50,54`, and the skill list in `CLAUDE.md:50`.
- `.graphifyignore`, `.gitignore:18-19`, and `.lace/mount-assignments.json:75-77` (the lace feature source is outside this repo).
- `scripts/detect-usage.sh` and `scripts/detect-usage.test.sh` name graphify only as example fixtures: keep them.
- Graphify proposals to mark `archived` or `evolved`: `2026-10-08-graphify-fork-rfp.md`, `2026-10-08-graphify-overhaul.md`, `2026-09-17-graphify-cdocs-integration.md`, and `2026-09-17-graphify-lace-devcontainer-enablement.md`.

## Not Measured

- Any current-rules, Opus 5.5 code-work run (see Sample limits).
- Quality effects of a searcher, a brief, or the read guidelines; no A/B was run.
- Whether thinking tokens persist in context: own output is counted from `output_tokens`, so it includes thinking that may not persist.
  This makes the output share an upper bound.
- Token estimates: the char-ratio estimates were not validated against `count_tokens`.
  The discovery regex can also over-match: an `ls` in a setup command, or the word "find" in an echoed header.
- List prices are a proxy; subscription billing differs.
  Sonnet 5.5 pricing is assumed equal to Sonnet 5.
- `Explore`'s default model: Sonnet 5 was observed in all 19 runs, while the docs call it platform-dependent.
