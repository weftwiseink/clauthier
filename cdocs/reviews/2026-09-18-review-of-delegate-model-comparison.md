---
review_of: cdocs/reports/2026-09-17-delegate-model-comparison.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-18T08:22:50-07:00
task_list: cdocs/browser-delegation
type: review
state: live
status: done
tags: [fresh_agent, benchmarks, citation_integrity, model_tiering, browser, delegation, decision_support]
---

# Review: Model options for the browser-delegate's driving, visual-verdict, and CSS-fix legs

> BLUF: Revise, close to accept.
> The deepened report is genuinely rigorous where it counts: every high-fabrication-risk citation I independently spot-checked (MT-Web2Code, 1D-Bench, DiffSpot, UI-Vision, Design2Code) is a real paper matching its described methodology, DiffSpot's headline 40.7% reproduces exactly, source tiering is disciplined, unverifiable model names are flagged consistently, and the Qwen3.8 self-report discrepancy is handled honestly.
> Three load-bearing precision defects block acceptance as a decision basis, and all three are fixable without new research: (1) the "Opus has the field's best specificity (99.6%)" claim is contradicted by the report's own DiffSpot table (two models at 100.0%, one tied at 99.6%), and it underpins recommendation 4; (2) the 1D-Bench table muddles "final score" against "raw similarity" so its own numbers do not cleanly support "Claude beats every Gemini tier," which underpins the dimension-C counterweight; (3) the report repeatedly attributes the decision-relevant Gemini win to the "current flash tier," but no benchmark tested the current 3.8 Flash - the wins belong to 3.5 Flash / 3 Flash / 3.1 Flash-Lite.
> Fix those three and correctly caveat the volatility of the ScreenSpot-Pro snapshot, and this report is a sound basis for the "pilot dimension C first" decision it argues for.

## Verification Performed

Independent web verification of a representative high-risk sample (not carried over from the report's own claims):

- **MT-Web2Code** ([arXiv:2608.03474](https://arxiv.org/abs/2608.03474)): CONFIRMED real. Title, "Reverse-Corruption Trajectory Engine," and the macro-reconstruction / micro-localized-modification task split all match. Abstract states 102 tasks across 16 domains. Per-model scores are in the paper body, not the abstract page, so the specific 65.5 / 63.0 / 80.5 / 77.3 figures were not independently re-derived, only the benchmark's existence and shape.
- **1D-Bench** ([arXiv:2602.18548](https://arxiv.org/abs/2602.18548)): CONFIRMED real. Title "A Benchmark for Iterative UI Code Generation with Visual Feedback" and the iterative-editing-with-visual-feedback methodology match. Per-model scores not extractable from the abstract page.
- **DiffSpot** ([arXiv:2605.29615](https://arxiv.org/abs/2605.29615)): CONFIRMED real and strongly corroborated. 4,400 pairs (3,900 with diffs across 13 CSS operators over 3 tiers, 500 no-diff), and the headline "even the best model identifies only 40.7% of true changes" reproduces the report's Gemini 3.1 Pro 40.7% exactly. Note: the paper evaluates 13 VLMs; the report's table shows 10, so it is a subset (the "ten tested" framing is a subset, not the full field).
- **UI-Vision** ([arXiv:2503.15661](https://arxiv.org/abs/2503.15661)): CONFIRMED real. Title and the Element Grounding / Layout Grounding / Action Prediction task structure match; UI-TARS-72B named as evaluated.
- **Design2Code** ([arXiv:2403.03163](https://arxiv.org/abs/2403.03163)): CONFIRMED real (control). Title and GPT-4V / Gemini / Claude evaluation match.
- **ScreenSpot-Pro primary leaderboard** (`gui-agent.github.io/grounding-leaderboard`, raw JSON at `raw.githubusercontent.com/GUI-Agent/grounding-leaderboard/main/results/screenspot_pro.json`): the leaderboard and raw JSON exist, but a direct fetch today returns a COMPLETELY DIFFERENT model set than the report cites (Indeed-UI-8B/32B, HuzzleWorld-2B, Duvo Eye-1, KV-Ground, AdaZoom-GUI-4B, UI-Venus-1.5, Holo2-4B/8B). None of the report's cited rows (Claude Computer Use 17.1%, GTA1-32B 63.6%, Holo2-235B 70.6%, UI-TARS-1.5, Aguvis, OS-Atlas, ShowUI) survive in the current JSON. See finding B1 below.

Net: no fabrication found in the spot-check. The report's central integrity claim, that the benchmark evidence is real and mostly primary-sourced, holds. The unverifiable model names (Claude 4.7 Opus, Gemini 3.5/3.8 Flash, GPT-5.4, GPT-6 Astra) are consistently and honestly flagged with the knowledge-cutoff caveat throughout, which is the correct handling for a trust-but-verify reader.

## Section-by-Section Findings

### BLUF and headline framing

**Blocking - "current flash tier" conflation.**
The BLUF leads with "Gemini 3.5 Flash outscores Claude 4.7 Opus" (correct, that is what MT-Web2Code tested), but recommendation 2, option 3's synthesis row, and several prose passages then generalize this to "Gemini's *current* flash tier beating Claude's Opus."
The "Current Verified Model Versions" section establishes the current flash tier is **Gemini 3.8 Flash** (GA 2026-09-02), yet no benchmark in the report tests 3.8 Flash.
The dimension-C win belongs to 3.5 Flash (MT-Web2Code), and the other flash datapoints are 3 Flash (DiffSpot), 3.1 Flash-Lite (MT-Web2Code), 2.0 Flash (HAL/TheAgentCompany).
This matters for the decision: the report's strongest single argument for piloting a non-Claude model rests on a flash version one to three generations behind the one an implementer would actually wire up.
Fix: say "a recent Gemini flash version (3.5 Flash)" and add an explicit note that the current 3.8 Flash is untested on every task-matched benchmark here, so the pilot must run the actual current SKU.

### Current Verified Model Versions

**Non-blocking - Qwen3.8 self-report discrepancy is handled well.**
The specific concern flagged for scrutiny is addressed honestly: the report cites Qwen3.8's card claiming "Opus 4.6 Max" at 72.7% on OSWorld-Verified, notes this conflicts with an independently-cross-checked Sonnet 4.6 figure of 78.5% (a lower tier should not outscore a higher tier apples-to-apples), and concludes the self-reported competitor numbers are "directional marketing, not a verified cross-vendor comparison." That is the correct treatment.
One soft caveat: the smell-test compares two different model names (Opus 4.6 Max vs Sonnet 4.6) from two different sources, so the anomaly could also be a naming or eval-condition mismatch rather than marketing inflation. The conclusion (do not cite it as verified) is right regardless; the reasoning could name that alternative explanation in one clause.

**Non-blocking - Qwen naming self-contradiction.**
This section describes `Qwen3.5-397B-A17B` as a "non-VL-branded" successor, but the DiffSpot table lists `Qwen3.5-VL-397B` as a VL model. Is the 397B model VL-branded or not? The report acknowledges Qwen naming chaos generally, but this specific internal contradiction should be reconciled or footnoted.

### Dimension A: Visual Reasoning / Quality Judgment

**Blocking - "field's best specificity" contradicts the report's own DiffSpot table.**
The prose (line ~94), the option-1 synthesis row, and recommendation 4 all assert Claude Opus 4.7 has "the field's best specificity (99.6% no-diff)," and the table marks Opus's 99.6% with "(best)."
The same table shows **Qwen3-VL-235B-Instruct at 100.0% and InternVL3.5-30B at 100.0%** (both higher) and **GPT-5.4 at 99.6%** (tied).
So 99.6% is not the field's best, and the "(best)" annotation is wrong.
This is load-bearing: recommendation 4's case for keeping Opus on the verdict leg leans substantially on this "least likely to hallucinate a defect" precision claim.
The defensible version is available from the same data: the two 100.0% models have trivial recall (5.1% and 4.2%, i.e. they almost never flag anything, so their perfect specificity is degenerate), so Opus is best specificity *among models with non-trivial recall*. State it that way; do not claim field-best.
The pairwise "99.6% vs Gemini 3 Flash's 91.4%" comparison elsewhere is fine and should stay.

**Non-blocking - DiffSpot table row ordering is non-monotonic.**
Rows run 40.7, 36.4, 34.4, 30.1 (Qwen3.5-VL-397B), 31.2 (Claude Opus 4.7), 30.5 - the Opus row (31.2) sits below a lower-scoring row (30.1). In a hand-reconciled doc, an out-of-order row is a small signal worth a second look; re-sort or confirm the numbers.

**Non-blocking - honest and useful.** The "no model catches half of true diffs, hard-tier recall under 23% for every tier" framing, the pixel-magnitude/detection near-zero-correlation caution, and the mllm-ui-judge informal reliability caveat (clearly labeled non-benchmark) are exactly the right skeptical notes. The general-reasoning-proxy vs task-matched distinction is drawn cleanly.

### Dimension B1: GUI Grounding

**Blocking-adjacent (state the shelf-life) - the ScreenSpot-Pro snapshot is already fully stale.**
A direct fetch of the same raw JSON the report cites now returns an entirely different, churned-over model set; none of the report's cited rows (Claude Computer Use 17.1%, GTA1-32B, Holo2-235B, UI-TARS-1.5, UGround, Aguvis, OS-Atlas, ShowUI) appear today.
This does not make the report dishonest - it explicitly flags the board's volatility (open question 3, "today's numbers may already be stale") and re-confirmed the snapshot twice at fetch time.
But it does mean the load-bearing "Correction" and the specific B1 numbers are a single-day snapshot of a source volatile enough to be unrecognizable within days, which undercuts the "trust the primary leaderboard going forward" thesis: the primary source is too churny to anchor a durable decision, and the aggregator-vs-primary disagreement cannot now be re-adjudicated against the same rows.
Fix: keep the correction (the aggregator numbers were rightly retracted), but explicitly downgrade the specific ScreenSpot-Pro scores to "snapshot, expired on refresh" and lean the B1 conclusion on the *structural* finding (GUI specialists beat generalists by wide margins) rather than any specific row, which is the durable and defensible read anyway.

**Non-blocking - the structural conclusion is sound.** "GUI-grounding specialists on cheap open backbones dominate every generalist tier" is corroborated across ScreenSpot-Pro/v2, UI-Vision, and OSWorld-G, and the report correctly separates grounding from autonomous driving (Qwen3-VL grounds well but trails Sonnet as a full agent on OSWorld-MCP). That nuance is the report at its best.

### Dimension B2: Web / Computer Agent Tasks

**Non-blocking - strong section.** The raw-grounding vs full-scaffold methodological split is the right lens, the HAL Online-Mind2Web cost/quality figures (180x cost for 1.4x quality, arithmetic checks: 1577.26/8.83 = 179, 40/29 = 1.38) are the cleanest tradeoff in the report, and absences are stated honestly and specifically (OSWorld curated-primary vs contradictory aggregators; WebBench "planned, not yet run"; raw-grounding papers predate the models). This directly answers task concern 2: cross-tier coverage is genuinely delivered here, not papered over.
One caveat to carry forward: the cost/quality datapoints are Gemini 2.0 Flash and Claude Sonnet 4 (leaderboard-bound old models), not the current tiers, which the report notes but the synthesis table could restate.

### Dimension C: Visual CSS/Layout Correction

**Blocking - 1D-Bench table conflates "final" and "raw similarity," undercutting the counterweight claim.**
The report's dimension-C conclusion (benchmarks disagree, run a pilot) rests on 1D-Bench being a clean Claude-favoring counterweight to MT-Web2Code. But the 1D-Bench table columns are "Single-round final | Multi-round final | Render success," and it lists **Gemini 3 Pro single-round at 79.6, above Claude Sonnet 4.5's 74.0**, annotating Gemini's 79.6 as "(best raw similarity single-round)."
If the column is final score, Gemini wins single-round and "Claude Sonnet 4.5 is the best single-round performer" / "beats every Gemini tier tested" is not supported by the table as printed.
If Gemini's 79.6 is actually a raw-similarity number (a different metric) mixed into the final-score column, the table is presenting two metrics in one column without saying so.
Either way the counterweight is muddier than the prose claims. Fix: split the columns explicitly (raw-similarity vs final = similarity x render-success) so the reader can see that Claude wins on the *final* composite while Gemini 3 Pro leads on *raw* similarity single-round. The "disagreement" conclusion likely survives (multi-round final does favor Claude 80.4 vs 79.5), but the single-round claim as written overstates it.

**Non-blocking - the synthesis is the honest read.** "Three of four closest-matched benchmarks (1D-Bench, DesignBench, Figma2Code) favor Claude, one (MT-Web2Code) favors Gemini's flash tier by a wide margin and too directly on-task to dismiss, therefore pilot dimension C first" is not dodging - it is the correct epistemic conclusion when on-task primary benchmarks contradict each other. This directly answers task concern 3: the "run a pilot" verdict is defensible, not an evasion, provided the two blocking table issues above are fixed so the "disagreement" is real rather than partly an artifact of presentation.

### Cost / Speed / Synthesis / Recommendations

**Non-blocking - well-scoped.** The Option x Dimension synthesis table is the usable per-option x per-dimension matrix the decision needs, with cost/speed/harness-fit columns and honest "n/e" markers for missing task-matched evidence. Cost is correctly demoted as a weak discriminator for single-call judgments and correctly elevated for multi-turn driving. The harness-integration section (Anthropic-locked `model:` field, path-3 direct-API-from-tool-code as the lightest viable pilot mechanism) is the durable architectural constraint and is unchanged, appropriately.

**Non-blocking - recommendations are appropriately hedged** ("reference for a possible amendment, not a decision"), and the option-4 reframe (GUI specialists as a grounding *helper* research spike, not a drop-in driver, because they ship open-weight without hosted APIs) is a genuinely useful escalation of the option space beyond the four the maintainer named.

### Frontmatter and Writing Conventions

**Non-blocking.**
- No em-dashes and no ` -- ` sequences (convention-compliant on the dash rule).
- 55 semicolons across the document is heavy against "use semicolons sparingly"; several could become periods or spaced hyphens.
- `benlm.ai` (line 219) vs `benchlm.ai` (lines 204, 546) is the same aggregator spelled two ways; unify.
- `first_authored.by: "@claude-sonnet-5"` is a shortname, not the full dated API model ID the frontmatter spec asks for (e.g. `@claude-sonnet-5-YYYYMMDD`); minor, and consistent with the sibling proposal.
- `last_edited` is not a field in the frontmatter spec; harmless but non-standard.
- `status: wip` is defensible, though `review_ready` would better match the fact that it was handed to an Opus reviewer; the spec permits `review_ready` for reports.

## Verdict

**Revise.**
The report is fundamentally sound and the research is rigorous: benchmark existence and methodology verify, source discipline is real, absences are stated honestly rather than papered over, cross-tier coverage is genuinely delivered, and the "pilot dimension C first" conclusion is the correct read of contradictory on-task evidence.
It is not yet Accept because three load-bearing precision defects each prop up a specific recommendation, and two of them are internal contradictions with the report's own tables (specificity, 1D-Bench columns) rather than external-source problems.
It is nowhere near Reject: none of the fixes require new research, only correction and re-qualification of claims the report already has the data to state accurately.

## Action Items

1. [blocking] Dimension A + recommendation 4 + option-1 synthesis: replace "the field's best specificity (99.6%)" and the "(best)" table marker with "best specificity among models with non-trivial recall" (the two 100.0% models have ~4-5% recall and are degenerate). Preserve the valid pairwise "99.6% vs 91.4%" comparison.
2. [blocking] Dimension C: split the 1D-Bench table into distinct "raw similarity" and "final score (similarity x render success)" columns so the numbers support the text; soften "best single-round performer / beats every Gemini tier" to reflect that Gemini 3 Pro leads single-round raw similarity while Claude leads the multi-round final composite.
3. [blocking] BLUF + recommendation 2 + option-3 synthesis: stop attributing the win to the "current flash tier." Name the tested version (3.5 Flash) and add an explicit note that the current 3.8 Flash is untested on every task-matched benchmark, so any pilot must run the current SKU, not infer from 3.5/3.x results.
4. [blocking] Dimension B1: downgrade the specific ScreenSpot-Pro scores to an expired single-day snapshot (a direct re-fetch today returns a fully churned model set with none of the cited rows) and re-anchor the B1 conclusion on the durable structural finding (specialists beat generalists) rather than any specific row. Keep the aggregator-number retraction.
5. [non-blocking] Reconcile the Qwen naming contradiction: `Qwen3.5-VL-397B` (DiffSpot table) vs `Qwen3.5-397B-A17B` described as non-VL-branded.
6. [non-blocking] Re-sort or re-check the DiffSpot table (Claude Opus 4.7 at 31.2 currently sits below Qwen3.5-VL-397B at 30.1).
7. [non-blocking] Note that HAL/TheAgentCompany cost-quality datapoints are old leaderboard tiers (Gemini 2.0 Flash, Claude Sonnet 4), not current, in the synthesis table.
8. [non-blocking] Add one clause to the Qwen3.8 discrepancy note acknowledging the Opus-4.6-Max-vs-Sonnet-4.6 comparison spans two model names and sources (naming/eval mismatch is an alternative to marketing inflation); conclusion unchanged.
9. [non-blocking] Unify `benlm.ai` / `benchlm.ai`; trim semicolon density; consider `status: review_ready`.

## Clarifications for the Maintainer (multiple choice)

These are decisions the reviewer cannot make for you; each affects how the report should be finalized.

1. **On the dimension-C pilot scope**, given MT-Web2Code (favors 3.5 Flash) tested a non-current flash version:
   a. Scope the pilot to the *current* Gemini 3.8 Flash on the actual "recenter a div" workload, treating all benchmark numbers as directional only.
   b. Scope it to reproduce MT-Web2Code's task on the exact tested SKUs first (to confirm the benchmark transfers) before testing current SKUs.
   c. Skip the flash pilot and spike a GUI-grounding-specialist helper instead (the option-4 reframe), where the structural evidence is strongest and least version-sensitive.

2. **On ScreenSpot-Pro's volatility**, now that the cited snapshot has fully expired:
   a. Drop specific GUI-grounding leaderboard numbers from the report entirely and cite only the structural specialist-dominance finding.
   b. Keep a dated, explicitly-expiring snapshot with a "re-verify before use" banner.
   c. Assign an owner (open question 3) to re-pull on a cadence and treat the number as live infrastructure, not a report fact.

3. **On whether this report should amend `model-tiering.md`** with a provider axis (its own open question):
   a. Yes - add a provider axis now, since MT-Web2Code is a real primary-sourced non-Claude win on a task-matched benchmark.
   b. Not yet - wait for the dimension-C pilot to resolve the benchmark disagreement empirically before touching the tiering rule.
   c. No - the harness-integration cost (Anthropic-locked `model:` field) means the tiering rule's Claude-centric shape is correct for the default path regardless of raw benchmark wins.
</content>
</invoke>
