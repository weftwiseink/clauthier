---
review_of: cdocs/reports/2026-10-08-search-subagent-context-prep.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T17:10:00-07:00
task_list: cdocs/graphify-weftwise-assessment
type: review
state: live
status: done
tags: [fresh_agent, adversarial, measurement, context_bloat, transcript_validated]
---

# Review: Search Subagent for Context Prep (Round 2)

## Summary Assessment

The report asks whether a sonnet search or context-prep subagent would cut context bloat in opus implementers and reviewers, and concludes: build neither, defer graphify to Phase 5, and do not ship an `Explore` guideline.
All nine round-1 action items are addressed, and the author's scripts reproduce every table cell from the transcripts.
Four places still undersell the searcher case or overstate the evidence against it:
- The headline 14% is a pooled share, while the typical weftwise implementer's share is 17% and a quarter of them are above 21%.
- The weftwise implementer table accounts for only 84% of growth.
- The `Explore` natural experiment is inconclusive once normalised for session length, not "no displacement".
- Read discipline is called a "leading lever" over a searcher, but the two target slices of about the same size.

The recommendation stands, but the case for it rests on cost, latency, miss rate and reviewer anchoring, not on the ceiling being small.
Verdict: **Revise**, with small edits and no new measurement needed.

## Round-1 Resolution

| r1 item | Status | Note |
|---|---|---|
| 1. Compound search classifier, denominator | Resolved | Any-verb classifier; "tool results only (no attachments)" labelled |
| 2. BLUF leads with peak-context share | Resolved | Dollars moved to secondary constraints |
| 3. Sample limits in Key Findings | Resolved | "Sample limits" opens Key Findings |
| 4. Guidance uptake rewrite | Resolved | No `Explore` rule stated; bash-runner window, redirect use and the inline 2K+ count all given |
| 5. Defer graphify to Phase 5, hand over metrics | Resolved | Proposal line 32 quoted correctly; Phase 5 already measures "tokens entering context by source" (proposal line 582) |
| 6. Confidence by dimension | Resolved | (a) is low and needs a trial; (b) and (c) are rated per dimension |
| 7. Ranged-read option, output and effort lever | Resolved | Options (e) and (f) |
| 8. Full-path match, Fable 5 price, sample cleanup | Resolved | `os.path.normpath` match; $1 cache reads; 61 agents |
| 9. `detect-usage.test.sh` | Resolved | Listed as fixtures to keep, which is correct: it uses `mcp__graphify__scope` only as test data |

## Spot Checks and Count Reconciliation

**Reproduction.**
- Re-running `v2.py` on the 999K and 739K agents gives rows identical to `v2.tsv` in all 41 columns.
- `agg2.py` over `v2.tsv` reproduces:
  - every share in the peak table;
  - the ρ values;
  - exploratory p75 and p90 (42.0K and 60.2K);
  - 3 compacted agents;
  - 62 redirect users;
  - 250 inline 2K+ searches in 96 agents.
- Scripts and outputs are in the session scratchpad (`r2check.py`, `r2v2b.py`, `r2check.out`, `r2agg_b.out`, ephemeral).

**Transcript checks (sonnet bash-runner, aggregates only).**
- On the 999K and 739K agents, `output_tokens` is under-recorded:
  - The median is 4-5 output tokens per request, and 553 of 872 and 278 of 447 requests record 10 or fewer.
  - Visible text plus tool-use input alone is 766K and 368K characters.
  - Thinking is redacted to signatures of 1.7M and 0.8M characters.
  - A control Opus 5.5 reviewer records a median of 454 per request.
- Bash reads by relative path, which the exploratory-path regex skips, are 0.1-0.2% of growth, so exploratory reads are not understated by that route.
- All 250 post-rule inline 2K+ searches are Bash calls (none are Grep or Glob tool calls), so all of them fall under the `bash-runner` rule.

**Where the author and round 1 differ.**
- **`Explore` users, 3 vs 4: the author is right.**
  The fourth dispatcher is "Build implemented-so-far guide artifact" (one dispatch), which round 1 itself said to drop from the sample.
  3 agents and 8 dispatches is correct for the stated 61.
- **`bash-runner` coverage, 114 of 162 vs 116 of 167: both are defensible.**
  They use different populations: the author's 162 is 140 Opus 5.5, 20 Opus 4.8 and 2 Fable 5.1 agents, and round 1 included non-Opus agents.
  The author's "after the rule" test compares dates only.
  One of the 114 started on 10-05 UTC before the rule commit (`789fed8`, 16:06Z), so the strict count is 113, which is negligible.
- **Inline searches, 250 vs 209: both are defensible.**
  250 uses the broader verb set (`ls`, `tree`, `fd`, any verb in a compound command), which also over-matches an echoed "find".
  209 is the conservative floor.
  The report gives both, which is right.
- **Redirect users, 62 vs 72: both are defensible.**
  The author's regex requires the rule's literal pattern (`> f 2>&1 ... wc|tail`), while round 1 matched any redirect.
  The report gives round 1's command count (317) but not its own (197): give both or neither.

## Section-by-Section Findings

### BLUF and Context

1. **Blocking: "about 14% of growth to peak" and "at most about 14% of median weftwise implementer growth" mix pooled and median.**
   The 14% is pooled over all tokens, so it is dominated by the top agents (11%).
   Per agent, discovery plus history plus exploratory reads is a median of 17.1% of growth, 21.0% at p75 and 24.5% at p90.
   The Context bullet "Quality at depth" and Option (c) both label the pooled figure as the median.
   State the pooled figure as pooled and give the per-agent median and p75.
   For a typical implementer the searcher's ceiling is about a sixth to a fifth of growth, not a seventh.
2. **Non-blocking: "Search is the largest tool slice there (15-18% of growth)" is false as worded.**
   All reads are 27% and 36% for clauthier implementers and reviewers.
   Say "the largest after reads".
3. **Non-blocking: the cost claim behind "Cost per loop" was not re-run.**
   "One `Explore` dispatch ... costs more than the search output it would replace" rests on `cost.tsv`.
   That file was computed with the pre-revision classifier: `cost.py` maps `bash:search` and `bash:git-inspect` and ran at 16:47, before `v2.py` at 17:00.
   clauthier search is 1.6-1.8x larger after reclassification, so round 1's $0.07-0.18 scales to roughly $0.11-0.32, which overlaps `Explore`'s $0.31-0.43.
   Either re-price with the v2 classifier or soften to "about as much as".
4. **Non-blocking: BLUF length.**
   Five sentences is within "a few", but sentence 3 can fold into sentence 2.
   The `Explore` and graphify overseer calls are what the maintainer will act on, so keep them.

### Method

5. **Blocking: the weftwise implementer slices do not close, and the report implies they do.**
   - The slices sum to 84% of growth (82% for the top 10).
     The other three populations sum to 99-101%.
   - 36 of 61 weftwise implementers hit the 2.0 chars-per-token floor in `v2.py`.
     Three have under-recorded output (above), including both large `Explore` users, which are only 31% and 48% attributed.
   - The clean subset (25 agents with chars-per-token above 2.0 and normal output) is 100% attributed: own output 50%, exploratory reads 10%, discovery 5%.
   - So the direction holds, and the output lever is stronger than reported.
     But "The rest of growth is ... (7-14%)" reads as a closed budget: state that 16-18% of weftwise implementer growth is unattributed, and why.
   - Not Measured's "output share is an upper bound" is wrong for these transcripts.
     Where `output_tokens` is under-recorded, it is a floor.
     Say that output is a lower bound for weftwise implementers, with the thinking-persistence caveat as a separate and opposite uncertainty.

### Key Findings

6. **Blocking: the natural experiment does not show "reads were not displaced".**
   - The claim compares absolute exploratory tokens (42K and 67K) with population quantiles, unnormalised for session length.
     Yet the report itself argues that length drives everything.
   - Normalised per request, the two large `Explore` users read 77 and 94 exploratory tokens per request.
     The population median is 214, and their top-10 peers range from 6 to 297 (median about 125).
   - As a share of growth they are at 3.9% and 6.1%, against 6.0% pooled for the top 10.
     The 3.9% is unreliable, since that agent is only 31% attributed.
   - The dispatches came mid-run, not as prep: assistant messages 252, 744, 745 and 1708 of 1948, and 56, 361 and 720 of 971.
   - "At and above the population's p75" is also off.
     41.8K is just under p75 (42.0K), and 67K is above p90 (60.2K).
   - The honest reading is that the data shows neither displacement nor its absence.
     Restate it as inconclusive, and give "no evidence either way" as the reason (a) is low confidence.
     The (a) recommendation itself does not change.
7. **Non-blocking: the "What peak tracks" table cannot rank levers.**
   Total reads (0.85) correlates with peak as strongly as request count (0.84), and every cumulative quantity co-varies with length.
   The share-of-growth table is the evidence.
   Drop the ρ table, or add a line saying it shows co-variation with length and nothing more.
8. **Non-blocking: "162 Opus implementers and reviewers"** includes 2 Fable 5.1 reviewers.
9. **Non-blocking: Accuracy cites counts the source declines to tally.**
   "1-2 wrong and 1-3 misleading items" are counts the assessment report explicitly leaves untallied, because the misled flags swapped sides on re-judging (assessment report line 136).
   Drop those counts or carry the caveat.
   The 74-79% completeness also came from whole-task sonnet arms under a roughly 40-call cap, not from brief-writers, so "misses 21-26%" for (c) is an analogy, not a measurement.

### Options and Recommendations

10. **Blocking: read discipline (e) is not a larger lever than a searcher.**
    - The overseer call names "session length and how files are read" as the leading levers.
      It supports this by comparing whole-file reads (33K) with discovery (14K) and exploratory reads (25K) "taken separately".
    - In the report's own shares, the two slices are the same size:
      - (e): whole-file reads 12% plus re-reads 4% (overlapping);
      - searcher: exploratory reads 9% plus discovery 5%;
      - at the top 10, 6% + 5% against 6% + 5%.
    - Whole-file reads of never-edited files fall in both.
    - Session length (f) is the one clearly leading lever.
      (e) beats a searcher on cost, latency and needing no verification, not on ceiling.
    - Restate it so the comparison does not tilt toward the guideline.
11. **Non-blocking: option lettering skips (d).**
    It is left over from the removed graphify option; reletter the options (history-agnostic framing).
12. **Non-blocking: minimality.**
    The body grew from 1,974 to 2,270 words.
    Trim candidates:
    - The graphify removal pointers (about 150 words): keep/drop is deferred, so they belong with Phase 5 or a removal proposal.
    - The ρ table (finding 7).
    - The Context bullets that restate Recommendations.

## Does the Recommendation Stand?

- **No searcher agent and no prep pass:** stands.
  The ceiling is about 17% of growth for a typical weftwise implementer and 21% or more for a quarter of them.
  It is 11% at the peaks that approach context limits, and those peaks are driven by length and output.
  Given that ceiling, the decisive arguments are dispatch cost and latency on the critical path, the miss rate, the verification clawback, and reviewer anchoring, not that search is small.
- **No `Explore` guideline:** stands, with "inconclusive" rather than "no displacement" as the reason.
- **Graphify deferred to Phase 5:** correct.
  Phase 5's per-source context measurement covers the metrics this report hands over.

## Verdict

**Revise.**
Round 1 is fully resolved, and the numbers reproduce.
The four blocking items are wording and labelling corrections, each a sentence or two, using figures given above.
Each removes a place where the evidence against a searcher reads stronger than it is.

## Action Items

1. [blocking] Label 14% as pooled; add the per-agent median (17%) and p75 (21%) to the Context bullet "Quality at depth" and to Option (c).
2. [blocking] State that weftwise implementer slices attribute 84% (top 10: 82%) of growth, because of the 2.0 chars-per-token floor in 36 agents and under-recorded `output_tokens` in 3. Give the clean-subset shares (output 50%, exploratory 10%, discovery 5%). Change "output share is an upper bound" to a lower bound for weftwise implementers.
3. [blocking] Rewrite the natural experiment as inconclusive: give the per-request figures (77 and 94 against a median of 214), note the dispatches were mid-run, and fix "at and above p75". Restate the (a) confidence reason as "no evidence either way".
4. [blocking] Restate the levers recommendation: session length leads; read discipline and a searcher target comparably sized slices (about 11-16%), and (e) is preferred on cost, latency and verification.
5. [non-blocking] Fix "largest tool slice"; re-price or soften the clauthier `Explore`-vs-search cost claim; caveat or drop the ρ table; fix "162 Opus"; drop or caveat the wrong and misleading counts.
6. [non-blocking] Reletter the options; give both redirect command counts or neither; move the graphify removal pointers out, or justify keeping them now that keep/drop is deferred.

## Questions for the Maintainer

1. Where should the current-rules implementer baseline (the report's "next step") come from?
   - (a) Fold it into Phase 5: its grep-only opus arm under 0.2.0 conditioning already records peak context by source.
   - (b) Run it separately on real `cdocs:implementer` dispatches, which better match the population a guideline would reach.
2. Round 1's question of which bloat matters (cost, context limits, or quality at depth) is still open.
   The answer changes how much the 17-21% typical-agent ceiling matters: little for limits, more for cost or quality at depth.
