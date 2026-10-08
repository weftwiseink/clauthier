---
review_of: cdocs/reports/2026-10-08-search-subagent-context-prep.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T17:20:00-07:00
task_list: cdocs/graphify-weftwise-assessment
type: review
state: live
status: done
tags: [fresh_agent, adversarial, measurement, context_bloat, sample_validity, cost_vs_context]
---

# Review: Search Subagent for Context Prep

## Summary Assessment

The report asks whether a sonnet search or context-prep subagent would cut context bloat in opus implementers and reviewers, and recommends no new agent, one `Explore` guideline line, and dropping graphify.
The headline direction survives re-measurement: discovery search plus exploratory reads is at most about 10-15% of growth to peak for weftwise implementers, and the 999K-peak agents are driven by length and accumulated output, not discovery.
But the evidence under that direction is weaker than presented: the search classifier misses compound commands (search is 1.6-4x larger than reported), the "4-14% of tool-result tokens" denominator silently includes attachments, the BLUF argues in dollars when the question is main-context size, "guidance is not followed" rests on guidance that does not exist (`Explore`) or is followed in its other form (redirect-to-file), and the drop-graphify recommendation is neither evidenced here nor in step with Phase 5, which the proposal now names as the keep/drop decision.
Verdict: **Revise**.

## Re-measurement

I re-ran the report's own scripts' logic over the same 298 transcripts (paths in the report's `ctxsearch/` TSVs) with three changes: compound Bash commands containing `grep|rg|find|git log/show/diff` count as search; edited-file attribution matches full paths, not basenames; and context is attributed at each agent's peak request, after its last compaction.
Scripts were run inline; outputs are in `scratchpad/rv-ctx/` (`rv.agents.tsv`, `sample.tsv`, ephemeral).

**Search tokens are undercounted.**
Weftwise implementers mostly search with `cd <wt> && echo "=== header ===" && grep -rn ...`, which the first-command classifier files under `bash:other` (589 such calls, about 465K tokens, about 7.5K per agent).

| Population | Report: search tokens/agent | Re-measured, median / mean | Search share of tool results (report classifier) | Re-measured share |
|---|---|---|---|---|
| clauthier implementers (Opus 5.5, 29) | 13K | 23K / 21K | 16.8% | 27.8% |
| clauthier reviewers (Opus 5.5, 109) | 9K | 15K / 17K | 20.3% | 32.9% |
| weftwise implementers (62) | 4.5K | 13K / 18K | 4.2% | 11.7% |

The report's "4-14% of tool-result tokens" reproduces only with attachments (base CLAUDE.md, skill listings) in the denominator: search / (tool + attach) is 14.0% for clauthier reviewers, 3.1% for weftwise implementers.
Splitting out git history, pure discovery (`grep`/`find`/`Grep`/`Glob`) is 14K median for clauthier implementers, 10K for reviewers, and 12K for weftwise implementers.

**Where peak context goes (weftwise implementers).**
Shares of growth from base to peak, counting only content added since the last compaction:

| Slice | All 62 (peak median 328K) | Top 10 by peak (mean 819K, 502 requests) |
|---|---|---|
| Agent output (thinking, text, tool inputs) | 35% | 43% |
| Reads, all | 30% | 21% |
| of which exploratory (never-edited, non-cdocs) | 8% | 5% |
| of which re-reads of an already-read path | 3% | 5% (42K/agent) |
| Search (report classifier; roughly double with compounds) | 2% | 2% |
| Other tool output and attachments (tests, builds, Playwright, compound commands) | 17% | 16% |

Peak correlates with request count (Spearman 0.84) and total reads (0.81), far more than with exploratory reads (0.47) or search (0.55).
Whole-file reads (no `offset`/`limit`) of files of 300+ lines are 32K median per weftwise implementer; ranged reads are 13K.

**Natural experiment the report missed.**
Four weftwise implementers dispatched `Explore` themselves (9 dispatches, no guidance told them to).
The two largest (peaks 739K and 999K) still read 46-48K tokens of never-edited source, in the population's top quarter (13 of 62 read 46K or more; p90 is 57K).
This is n=4 and confounded by task size, but it is the only observed case of an opus implementer using a searcher, and it shows no displacement of exploratory reads.

## Section-by-Section Findings

### BLUF

1. **Blocking: figures.** "4-14% of their tool-result tokens and 1.6-5.6% of their cost" undercounts search by 1.6-4x and mislabels the denominator (see Re-measurement).
   The direction holds; the numbers must be corrected or the claim restated on a measure that is defined.
2. **Blocking: cost frame stands in for context.** The decisive comparison ("one `Explore` dispatch costs $0.31-0.43 ... more than an opus agent's whole median search spend ($0.07-0.18)") is in dollars, uses clauthier medians, and compares one dispatch to search alone.
   The maintainer's question is main-context size.
   A searcher moves tokens out of the main context even when it costs more in total; for weftwise implementers, exploratory reads alone cost about $1.8 median per agent at Opus 4.8 rates (28% of $6.54 median read spend), about four `Explore` dispatches.
   Lead with share of peak context; keep dollars and wall time as secondary constraints.

### Context

3. **Non-blocking: define "bloat".** The report never says what bloat harms: cost, compaction, or quality degradation at depth.
   clauthier peaks (107K / 163K medians, 401K max on 1M-context models) do not show a bloat problem at all; weftwise implementers (328K median, 999K max) do.
   The conclusion for clauthier holds because there is little to save, not because search is cheap; say so.

### Method

4. **Blocking: classifier.** Classify Bash by any search verb in the command (excluding test/build pipelines), or report the `bash:other` residue; it is 8% of weftwise tool output and mostly search.
5. **Non-blocking: edited-file attribution by basename** (`readattr.py`) inflates "files the agent edited" in a TypeScript monorepo of `index.ts`/`types.ts`: 44K vs 38K median for weftwise implementers, so "exploratory" is somewhat understated.
6. **Non-blocking: pricing.** Fable 5 cache reads are $1/MTok, not $0.25 (3 agents); "Opus 4.8 or Fable" weftwise implementers include two non-implementers ("Build implemented-so-far guide artifact", and a Sonnet "Find arrow anchoring implementation" in the source TSV).
   The char-ratio estimates (cpt 2.4-2.6) are per-agent constants, so they do not distort shares among tool kinds, only the tool-versus-output split; "±15%" is asserted, not measured.

### Key Findings: sample validity

7. **Blocking: the code-work population is stale and differently conditioned, and the report under-states it.**
   All 62 weftwise implementers ran 2026-09-01 to 09-21, on Opus 4.8 (55) or Fable, as `general-purpose` dispatches with ad hoc prompts, under weftwise cdocs rules v0.1.0 (no `bash-runner`, no graphify, no Tool use guidance).
   No `cdocs:implementer` on current rules and Opus 5.5 has done code work in this sample.
   clauthier implementers read 46% proposals/devlogs/reviews plus 21% other cdocs: docs work, not code.
   So every code-work number is from a population the recommended guideline would never reach.
   State this in Key Findings, not only under Not Measured, and lower confidence accordingly.

### Key Findings: "The search guidance is not followed today"

8. **Blocking: the evidence does not support the claim as worded.**
   - No rule or agent tells implementers or reviewers to dispatch `Explore`: `implementer.md` and `reviewer.md` say nothing about search delegation, and the only mention is the model-tiering line "`sonnet` for search, explore", which governs model choice for subagents, not when to dispatch one. Zero `Explore` dispatches is therefore uninformative about compliance.
   - The `bash-runner` rule landed 2026-10-05; only 116 of the 167 agents ran after it (none of the 22 weftwise reviewers, whose rules lack it).
   - The rule's option 1 is self-run redirect-to-file. 72 of those 116 agents used it (317 commands). Counting only `bash-runner` dispatches scores option-1 compliance as non-compliance.
   - What the data does support: after the rule, 113 opus agents ran 1,444 discovery searches inline, 209 of them 2K+ tokens (88 agents, about 6.9K tokens per agent). That is the right evidence for "large searches still run inline".
   - "All 19 `Explore` runs came from overseers or top-level sessions" is true for the window, but weftwise implementers did dispatch `Explore` (9 times, before the window). Mention it, with the result above.

### Options

9. **Non-blocking: option (c)'s "about 35K tokens" for weftwise** is search + exploratory reads; with compound search it is about 32-44K, about 12-16% of median growth. The "halves exploration" assumption is contradicted by the natural experiment; present it as a ceiling.
10. **Non-blocking: missing option.** The largest read-shaped lever in the weftwise data is whole-file reads of large files (32K median) and re-reads (42K mean in the top 10), not discovery. A guideline to read ranges of large files after locating them, and to avoid re-reading files already in context, needs no new part and fits the maintainer's preference for guidelines. It is also exactly what a symbol graph would make cheap, which bears on (d).

### Recommendations

11. **Blocking: (d) drop graphify is not evidenced by this report, and conflicts with the proposal's current plan.**
    The report measures nothing about graphify's effect on implementer context ("no measured context saving to lose" is absence of measurement: Phase 4 arms were sonnet subagents with an ad hoc card over `podman exec`, not conditioned opus implementers).
    The assessment proposal (`4f4f7b3`) now says "Phase 5 decides whether to keep graphify or drop it", under cdocs 0.2.0 conditioning, measuring context.
    The report should defer (d) to Phase 5 or present it explicitly as a maintenance judgment independent of this analysis, and hand Phase 5 the metrics that matter here: whole-file and exploratory read tokens and share of peak, not only reach.
12. **Blocking: confidence levels.**
    - "High that (b) and (c) do not pay on tokens": supported on dollars and wall time for clauthier; on main-context tokens it is supported only after the re-measurement above (discovery is at most about 10-15% of weftwise growth to peak), and for a different reason than given. Restate it as "high on cost and latency; medium on peak context (code-work sample is Opus 4.8, September, unconditioned)".
    - "Medium that the (a) guideline helps weftwise-scale implementers": nothing supports medium. The only observation (four implementers that used `Explore`) shows no reduction in exploratory reads, and the guideline's own verification clause ("open each line you rely on, grep yourself before claiming absence") claws back much of the saving. Low, or "unknown, trial with measurement".
13. **Non-blocking: "bigger levers" omit agent output.** Output is the largest single slice at peak (35% median, 43% in the top 10). Effort level is a lever worth naming, with the thinking-persistence caveat from Not Measured.
14. **Non-blocking: removal pointers** check out against the tree; `scripts/detect-usage.test.sh` also mentions graphify and is not listed.

### Not Measured

15. **Non-blocking:** add "the code-work sample predates current rules and models" (finding 7) and "compound Bash commands were not classified" (finding 4) if not fixed.

## Does the Recommendation Stand?

- **No searcher agent, no prep pass:** stands. Even counting compound search and every exploratory read, discovery is a minority of peak context, the worst peaks track session length, and the only observed `Explore` use did not displace reads.
- **Add the `Explore` guideline line:** not supported as written. Skip it, or adopt it as an explicit trial with a measurement.
- **Drop graphify:** not supported by this report. Defer to Phase 5, or record it as a maintenance-cost decision.

Before acting on a context-bloat fix, measure on the population that matters: current-rules `cdocs:implementer` runs on weftwise code (Opus 5.5), reporting share of peak by output, edited-file reads, re-reads, whole-file large reads, exploratory reads, and search, then compare per-phase dispatch, ranged-read guidance, and effort level against that baseline.

## Verdict

**Revise.**
The "build nothing" conclusion is right, but its evidence must be corrected (classifier, denominator), restated in context terms, and its sample limits moved up front; the guideline's confidence must drop; and (d) must be deferred to Phase 5 or separated from the analysis.

## Action Items

1. [blocking] Reclassify compound Bash search commands; correct the BLUF and Key Findings search tokens and shares, and label the denominator (tool results only, or tool results plus attachments).
2. [blocking] Lead the BLUF with share of peak context (main-context tokens); keep dollars and wall time as secondary, and give the weftwise numbers alongside clauthier's.
3. [blocking] Move the sample limits into Key Findings: weftwise implementers are Opus 4.8 / Fable, 2026-09-01 to 09-21, `general-purpose`, rules v0.1.0; clauthier implementers are docs work.
4. [blocking] Rewrite "The search guidance is not followed today": no `Explore` guidance exists; `bash-runner` rule covered 116 of 167; 72 of 116 used the redirect pattern; 209 inline 2K+ searches after the rule; weftwise implementers did dispatch `Explore` 9 times without reads dropping.
5. [blocking] Defer (d) to Phase 5 (or mark it a maintenance judgment), and pass Phase 5 the read and peak-share metrics.
6. [blocking] Lower the (a) confidence to low or "trial with measurement"; restate the (b)/(c) confidence by dimension.
7. [non-blocking] Add the ranged-read and no-re-read guideline as an option, and agent output / effort level to the bigger levers.
8. [non-blocking] Match edited files by full path; fix Fable 5 cache-read pricing; drop the two non-implementers from the weftwise sample.
9. [non-blocking] Add `scripts/detect-usage.test.sh` to the graphify pointers.

## Questions for the Maintainer

1. What does "context bloat" mean for the decision?
   - (a) Cost per loop.
   - (b) Compaction and context limits (weftwise implementers reach 999K).
   - (c) Quality degradation at depth, even well below limits.
2. How should graphify's fate be decided?
   - (a) Wait for Phase 5's conditioned opus re-measurement, which should report context share as well as reach.
   - (b) Drop now on maintenance cost alone, accepting that context value is unmeasured.
3. Should the `Explore` guideline line ship?
   - (a) No; ship only the graphify-bullet removal when (2) resolves.
   - (b) Yes, as a trial, re-measuring exploratory reads on the next few weftwise implementer runs.
   - (c) Replace it with a ranged-read and no-re-read guideline, which targets a larger measured slice.
