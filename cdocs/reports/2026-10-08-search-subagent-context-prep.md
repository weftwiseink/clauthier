---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T16:49:00-07:00
task_list: cdocs/graphify-weftwise-assessment
type: report
state: live
status: done
last_reviewed:
  status: revision_requested
  by: "@claude-opus-5-5"
  at: 2026-10-08T17:10:00-07:00
  round: 2
tags: [analysis, subagents, context_bloat, graphify, performance]
---

# Search Subagent for Context Prep

> BLUF: Build no searcher agent and no prep pass.
> A searcher could target about a sixth of a typical weftwise implementer's growth to peak context: discovery search plus exploratory reads is a per-agent median of 17%, and 21% at p75.
> The case against it is cost, latency, miss rate, and reviewer anchoring, not a small ceiling.
> Session length is the one clearly leading lever.
> Overseer calls: graphify keep/drop belongs to the assessment's Phase 5, and no `Explore` guideline ships on this evidence.

## Context

The maintainer judged graphify not worth its upkeep after the weftwise assessment ([report](2026-10-08-graphify-weftwise-assessment.md), "Value Beyond Grep").
The original motivator was context bloat in the opus implement and review agents.
This report asks whether a sonnet search and context-prep subagent, along the lines of `cdocs:bash-runner`, would cut it.

The maintainer has not said which harm "bloat" means, so here is the conclusion for each meaning:

| Meaning | Conclusion |
|---|---|
| Cost per loop | One `Explore` dispatch ($0.31-0.43) costs about as much as the clauthier search output it would replace. For weftwise implementers it could pay, but only if it displaced reads, which is unshown. |
| Context limits | Only weftwise implementers come close (p90 739K, max 999K, 3 of 61 compacted), and their peaks grow with session length. |
| Quality at depth | Not measured. |

clauthier peaks (110K and 163K medians, 401K max, on 1M-context models) show no bloat to cut.
Search is clauthier's largest tool slice after reads (15-18% of growth), so its conclusion rests on there being little to save.

## Method

- **Transcripts**: every `cdocs:implementer` and `cdocs:reviewer` subagent since 2026-09-20 in this repo and weftwise, the `Explore` and `bash-runner` runs, and 61 weftwise implementers.
  The weftwise implementers are `general-purpose` dispatches described as "implement", since 2026-09-01.
- **Context and growth**: request context is `input + cache_read + cache_creation`.
  Growth runs from the last compaction to the peak request.
- **Tool-result tokens**: characters divided by a per-agent ratio calibrated from context deltas.
- **Classifier**: Bash commands are classified by any verb in a compound command:
  - test/build first;
  - then discovery: `grep|rg|find|fd|ls|tree`, plus the Grep and Glob tools;
  - then git history: `git log|show|diff|blame`;
  - then reads: Read, and `cat|sed|head|tail|awk|jq`.
- **Read slices**: these overlap.
  - Exploratory: a path never edited (full-path match), outside `cdocs/`.
  - Re-read: a path read earlier.
  - Whole-file large: a Read with no range, of a file of 300 or more lines.
- **Prices**: list API rates, as a proxy.
- **Scripts**: `v2.py` and `agg2.py` in the session scratchpad (ephemeral).
- **Independent checks**: two independent reviews re-ran them (`d581087`, `924a335`).

## Key Findings

**Sample limits.**
- All 61 weftwise implementers ran 2026-09-01 to 09-21, on Opus 4.8 or Fable.
  They were ad hoc `general-purpose` dispatches under weftwise rules v0.1.0: no `bash-runner`, no graphify, no tool-use guidance.
- No current-rules Opus 5.5 `cdocs:implementer` did code work in this sample.
- clauthier implementers do docs work: 46% of their reads are proposals, devlogs, and reviews.

**Where peak context goes** (pooled share of growth to peak):

| Population | n | Base | Peak median / p90 / max | Requests (median) | Own output | All reads | Whole-file large | Exploratory | Re-reads | Discovery | Git history | Attributed |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| clauthier implementers, Opus 5.5 | 29 | 39K | 163K / 332K / 401K | 52 | 43% | 27% | 9% | 5% | 4% | 15% | 2% | about 100% |
| clauthier reviewers, Opus 5.5 | 111 | 35K | 110K / 164K / 288K | 22 | 32% | 36% | 13% | 8% | 3% | 18% | 5% | about 100% |
| weftwise reviewers, Opus 4.8 or Fable 5.1 | 22 | 59K | 146K / 190K / 260K | 25 | 31% | 43% | 19% | 14% | 8% | 9% | 8% | about 100% |
| weftwise implementers, Opus 4.8 or Fable | 61 | 55K | 330K / 739K / 999K | 129 | 35%+ | 31% | 12% | 9% | 4% | 5% | 0% | 84% |
| top 10 of those, by peak | 10 | 55K | 823K / 999K / 999K | 460 | 43%+ | 22% | 6% | 6% | 5% | 5% | 0% | 82% |

Read slices overlap; "Attributed" also counts test, build, other-tool, and attachment tokens not shown.
- **Weftwise implementer totals do not close.** 16-18% of their growth is unattributed:
  - 36 of 61 hit the chars-per-token floor;
  - three under-record `output_tokens` (a median of 4-5 per request);
  - so own output is a lower bound there.
- **The 25 clean agents attribute 100%**: own output 50%, exploratory reads 10%, discovery 5%.
- **Pooled and per-agent shares differ.** Pooled discovery plus history plus exploratory reads is 14% of weftwise implementer growth, dominated by the top 10 (11%).
  Per agent, it is a median of 17%, p75 21%, and p90 25%.
- **Thinking persistence is a separate, opposite uncertainty.** Output counts thinking tokens that may not stay in context.

**Searcher guidance and its uptake.**
- **No `Explore` rule exists.** No rule tells implementers or reviewers to dispatch `Explore`; the model-tiering line picks models, not when to dispatch.
  Zero `Explore` dispatches by the 162 implementers and reviewers (140 Opus 5.5, 20 Opus 4.8, 2 Fable 5.1) says nothing about compliance.
- **The `bash-runner` rule** landed 2026-10-05, and 114 of the 162 ran after it.
  How many used its redirect-to-file option depends on the matcher:
  - this report's matcher, which requires the rule's literal pattern: 62 agents, 197 commands;
  - the round-1 review's matcher, which accepts any redirect: 72 agents, 317 commands.
  One implementer dispatched `bash-runner`, twice.
- **Inline searches persisted.** After the rule, 250 discovery searches of 2K+ tokens still ran inline, in 96 agents; a narrower classifier gives 209 in 88.
  All 250 were Bash calls.
- **The `Explore` natural experiment is inconclusive.**
  Three weftwise implementers dispatched `Explore` on their own (8 dispatches), mid-run rather than as prep.
  Per request, the two large ones read fewer exploratory tokens than the population median (77 and 94 against 214).
  As a share of growth they are near their top-10 peers (3.9% and 6.1% against 6.0%), and one is only 31% attributed.
  The data shows neither displacement nor its absence.

**What a searcher costs** (secondary constraints):

| Agent | Base | Peak (median) | Cost median | Wall median | Returns |
|---|---|---|---|---|---|
| `Explore`, Sonnet 5 (19 runs) | 16K, no CLAUDE.md or rules | 63-69K | $0.31-0.43 | 100 s | about 1-8K tokens |
| `bash-runner`, Sonnet or Haiku (49 runs) | 11-12K | 13-15K | $0.02-0.05 | 7-26 s | at most about 600 words |

- **Fixed overhead** is 11-16K tokens per dispatch, mostly re-written to cache on every dispatch.
- **Model price gap**: Sonnet 5 costs the same as Opus 5.5 on cache reads.
  At Opus 5.5 rates, the `Explore` runs would cost 1.63 times as much, not twice.
- **Custom-agent overhead**: a custom cdocs agent carries CLAUDE.md and the rules (about 7K tokens), which `Explore` skips; no frontmatter field omits them ([sub-agents docs](https://code.claude.com/docs/en/sub-agents.md)).
- **Latency**: a searcher blocks its caller for about 100 s.
  In interactive sessions it also forces a turn boundary ([context preservation report](2026-10-08-subagent-context-preservation-options.md), findings 2 and 4).

**Accuracy.**
- Phase 4's whole-task sonnet arms found 74-79% of important items, under a cap of about 40 calls.
  For a brief-writer, that is an analogy, not a measurement.
- Misses matter most for absence claims.
- `review_proof` admits only the reviewer's own artifacts.
  A reviewer must still open each `file:line` it relies on and grep for absence itself, which claws back much of the saving.

## Options

| Option | Ceiling (weftwise implementers) | Costs and risks |
|---|---|---|
| a. `Explore` guideline for wide sweeps | Part of discovery plus exploratory reads | Uptake and displacement unshown; verification claws back savings |
| b. Dedicated `cdocs:searcher` | Same as (a) | A new agent file; about 7K more base than `Explore`; its only gain is a fixed format a prompt can request |
| c. Overseer prep brief before each dispatch | Per-agent median 17%, p75 21% (discovery, history, exploratory reads) | $0.31-0.43 and about 100 s per dispatch on the critical path; misses; anchors reviewers; does not touch needed reads |
| d. Guideline: read ranges of large files once located, and don't re-read | Whole-file large 12% plus re-reads 4%, overlapping (6% + 5% at the top 10) | Guideline only; no verification step |
| e. Shorter sessions: per-phase dispatch, effort level | Own output 35-50%+; peaks grow with session length | Already a workflow pattern ("CDocs Workflow Patterns › Loops and multi-phase plans"); effort affects quality |

(c) and (d) target slices of similar size (9% + 5% against 12% + 4%, and 6% + 5% each at the top 10), and whole-file reads of never-edited files fall in both.
(d) wins on cost, latency, and needing no verification, not on ceiling.
Unlike the graphify base query, which was one cheap call the agent ran itself, a brief is another model's precomputed answers, paid on every dispatch.

## Recommendations

- **No searcher agent and no prep pass (b, c).**
  Confidence is high on cost and latency, and medium on peak context: the code-work sample is Opus 4.8, September, and unconditioned.
- **Overseer call: the `Explore` guideline (a) does not ship**; at most it becomes a measured trial.
  Confidence that it helps is low, because there is no evidence either way.
- **Overseer call: session length (e) is the leading context lever.**
  Read discipline (d) and a searcher target slices of similar size, and (d) is the cheaper of the two.
- **Overseer call, next step if context work continues**: baseline current-rules `cdocs:implementer` runs on weftwise code (Opus 5.5).
  Measure share of peak by own output, edited-file reads, re-reads, whole-file large reads, exploratory reads, and search.
- **Overseer call: graphify keep/drop is deferred** to Phase 5 of the assessment (`cdocs/proposals/2026-10-08-graphify-weftwise-assessment.md`).

## Not Measured

- Any current-rules, Opus 5.5 code-work run.
- Quality effects of a searcher, a brief, or the read guidelines.
- Token estimates: the char-ratio estimates are not validated against `count_tokens`.
  The discovery regex can over-match, for example an echoed "find".
- Prices: list prices are a proxy, and Sonnet 5.5 is assumed priced like Sonnet 5.
- The cost of clauthier search under the revised classifier, which was not re-priced.
  Round 1's $0.07-0.18 scales to roughly $0.11-0.32.
