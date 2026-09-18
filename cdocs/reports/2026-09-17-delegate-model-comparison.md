---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-17T16:30:00-07:00
task_list: cdocs/browser-delegation
type: report
state: live
status: final
last_reviewed:
  status: accepted
  by: "@claude-opus-4-8"
  at: 2026-09-18T09:30:00-07:00
  round: 2
tags: [research, model_tiering, browser, delegation, visual_review, benchmarks]
---

# Model options for the browser-delegate's driving, visual-verdict, and CSS-fix legs: a benchmark-grounded comparison

> BLUF: The first pass of this report concluded "no verified benchmark contains flash-tier or cheap models" after checking one benchmark (ScreenSpot-Pro) via two secondary aggregators.
> That conclusion was wrong, and it was a search-breadth failure, not a real absence.
> A wider, mostly primary-sourced search across GUI-grounding, web-agent, general multimodal, and design-fidelity/repair benchmark families finds substantial cross-model evidence including flash and open tiers, and in several cases a corrected reading changes the recommendation, not just the evidence base.
> The single most decision-relevant finding: on **MT-Web2Code** ([arXiv:2608.03474](https://arxiv.org/abs/2608.03474), primary, 2026-08-04), a benchmark that injects a defect into a rendered page and scores an agent's localized fix against a reference, **Gemini 3.5 Flash outscores Claude 4.7 Opus on both the macro-reconstruction task (65.5 vs. 63.0) and the micro-localized-modification task (80.5 vs. 77.3)**, the task shape closest to this proposal's dimension C ("recenter a div").
> This is a **3.5 Flash** result specifically, not a "current flash tier" result: the current Gemini flash tier is **3.8 Flash** (GA 2026-09-02, see "Current Verified Model Versions" below), and no benchmark in this report tests 3.8 Flash on any task-matched dimension, so any pilot must run the actual current SKU rather than infer its performance from 3.5 Flash's win here.
> That finding needs an immediate counterweight from **1D-Bench** ([arXiv:2602.18548](https://arxiv.org/abs/2602.18548), primary, another iterative visual-feedback UI-fix benchmark): there, the result is split rather than a clean Claude win. **Claude Sonnet 4.5 leads the multi-round final composite (80.4 vs. Gemini 3 Pro's 79.5)**, but **Gemini 3 Pro leads single-round (79.6 vs. Claude's 74.0)**, both well ahead of Qwen3-VL-235B (59.0-61.9), so dimension C's two closest-matched benchmarks disagree on direction, and even the counterweight benchmark disagrees with itself by round, so neither should be treated as the settled answer.
> On GUI grounding, the **primary, actively-maintained ScreenSpot-Pro/v2 leaderboard** ([gui-agent.github.io/grounding-leaderboard](https://gui-agent.github.io/grounding-leaderboard/), fetched 2026-09-18) directly contradicts the numbers the first pass cited from secondary aggregators: it shows no Gemini, GLM, or InternVL entries at all, a generic "Claude (Computer Use)" row at 17.1%, GPT-4o at 0.8%, and dozens of cheap/open GUI-grounding *specialist* models (UI-TARS, GTA1, Holo2, UGround, Jedi, OS-Atlas) scoring 2 to 4x higher than either.
> That specific snapshot itself expired within a day of being fetched (a re-fetch of the identical source returned a fully different model roster), so the durable finding is the structural one: GUI-grounding specialists dominate both Claude's and Gemini's generalist tiers, not any specific row's score.
> The prior claim of "Claude Opus 4.8 at 87.9%, GPT-6 Astra at 92.7%" on ScreenSpot-Pro could not be corroborated against this primary source and should be treated as unverified aggregator noise, not fact.
> See "A Correction" below.
> On the visual-judgment leg itself, **DiffSpot** ([arXiv:2605.29615](https://arxiv.org/abs/2605.29615), primary) is the closest match to "does this render look janky," and its headline finding matters more than any single model's rank on it: the best model of ten tested catches only 40.7% of true visual defects overall and under 23% of hard-tier defects, so the capability is low-ceiling for every tier, cheap or expensive, Claude or not.
> On driving, **HAL's Online-Mind2Web leaderboard** ([arXiv:2510.11977](https://arxiv.org/abs/2510.11977), primary infrastructure paper, with per-model numbers living on HAL's own leaderboard site rather than the paper's abstract) gives the cleanest same-scaffold cost/quality tradeoff found anywhere in this report: Claude Sonnet 4 scores 40.0% for a ~$1,577 eval run versus Gemini 2.0 Flash's 29.0% for ~$8.83, a roughly 180x cost gap for a 1.4x quality gap.
> The decisive architectural fact from the first pass still stands unchanged: Claude Code's `model:` field is Anthropic-locked, so any non-Claude model requires a gateway or a direct API call from inside the delegate's own tool code, not a plain subagent swap.
> Recommendation (reference, not decision): the evidence base has moved from "nothing to compare" to "real, benchmark-backed tradeoffs that cut in different directions depending on the exact task," which argues for a narrowly-scoped pilot (dimension C, where the two closest benchmarks disagree, is the one most worth spiking first) rather than either keeping the status quo or switching wholesale, while the harness-integration cost of any non-Claude option is unchanged and still real.

## Context / Background

This report supplements the accepted proposal `cdocs/proposals/2026-09-17-browser-delegation-plugin.md`, which hardcodes a sonnet-tier `browser-delegate` agent for both driving/capture and (via handoff) visual verdicts, reusing cdocs's existing R1-R6 discipline verbatim.
The maintainer asked whether a non-Claude model is worth using for the delegate, and directed this revision at four explicit options and three task dimensions, because the first pass's benchmark search was too narrow to answer that question honestly.

**The four options**, on a cost/speed/quality tradeoff:

1. **Opus driver + Opus judge**: current approach, costly, slow, the quality ceiling.
2. **Sonnet driver + Sonnet judge**: cheaper, in-Claude-family, a plain CC subagent, no external integration.
3. **Current Gemini flash tier**: cheapest, requires external tool/integration (non-Claude, not a CC subagent per the harness-integration finding below).
4. **Open / cost-effective visual-specialist models**: Qwen-VL line, GUI-grounding specialists (UI-TARS, GTA1, Holo2, UGround, Aguvis, OS-Atlas, Jedi), and other cheap VLMs (InternVL, GLM-4.6V, Llama vision, Molmo, Pixtral).

**The three task dimensions**, each benchmarked separately below because they are genuinely different skills:

- **A. Visual reasoning / quality judgment**: "does this render look janky or wrong versus a design," the verdict leg.
- **B. Website navigation & usage**: agentic web tasks, find and click the right element, complete a flow, the driving leg.
- **C. Visual-oriented CSS/layout correction**: given a screenshot and a reference, make the small fix, the eventual rapid review/tweak/review inner loop.

Grounding read before this revision: Report A's ("who holds the loop") thesis and A2A deferral (`2026-09-17-browser-delegation-approaches.md`), the visual-verification tool survey (`2026-08-05-visual-verification-skills-web-survey.md`), the accepted proposal's sonnet-tier default and D1-D6 design decisions, and `plugins/cdocs/rules/model-tiering.md`'s Claude-centric tiering shape.

## Current Verified Model Versions (as of 2026-09-18)

Independently re-verified in this revision, not carried over unchecked:

- **Gemini flash tier**: still **Gemini 3.8 Flash** (GA 2026-09-02), confirmed via Google's own live changelog (`ai.google.dev/gemini-api/docs/changelog`, primary, fetched 2026-09-18): no newer Flash release has shipped in the 16 days since.
  Pricing independently re-verified against `ai.google.dev/gemini-api/docs/pricing` (primary): input $0.75/M, output $3.75/M (including thinking tokens) through 2026-12-31, then $1.50/M input and $7.50/M output.
  A cheaper **Gemini 3.5 Flash-Lite** variant exists at $0.30/M input, $2.50/M output (same primary page).
  Images are not separately itemized.
  They are billed as standard input/output tokens.
- **Qwen-VL line**: **Qwen3-VL** is current (waves shipped 2025-10-15 through 2025-10-21, technical report [arXiv:2511.21631](https://arxiv.org/abs/2511.21631) dated 2025-11-27, official GitHub `QwenLM/Qwen3-VL`, primary).
  Sizes: 2B, 4B, 8B, 30B-A3B (MoE), 32B, 235B-A22B (MoE), plus hosted `Qwen3-VL-Plus` and `Qwen3-VL-Flash` SKUs on Alibaba's own DashScope API.
  NOTE(sonnet/delegate-model-comparison): Artificial Analysis (secondary, fetched 2026-09-18) reports Alibaba has flagged `Qwen3-VL-235B-A22B-Instruct` as deprecated on its own API in favor of a non-VL-branded `Qwen3.5-397B-A17B` that also accepts image/video input, suggesting Alibaba is folding vision into its mainline line rather than keeping a permanent separate flagship VL SKU. Dedicated Qwen3-VL checkpoints remain live and priced today regardless.
  The DiffSpot table below tests this same non-VL-branded checkpoint under the name `Qwen3.5-397B-A17B`, not a `Qwen3.5-VL`-branded variant, since dedicated Qwen-VL sizes stop at 235B-A22B and no VL-branded 397B checkpoint exists.
  This report uses `Qwen3.5-397B-A17B` consistently for that size everywhere it appears.
  This migration goes further than one deprecated SKU: a direct fetch of `huggingface.co/Qwen/Qwen3.8-27B` (primary, confirmed real, Aug 2026) shows a natively-multimodal, non-VL-branded successor generation already exists, alongside a `Qwen3.8-Flash-Next` variant separately confirmed on an OSWorld 2.0 benchmark card (52.3% partial success, primary).
  So as of 2026-09-18 there are two live, current answers to "what is the current Qwen-VL line": the dedicated `Qwen3-VL` checkpoints (Nov 2025, what nearly every third-party benchmark in this report actually tests, because they predate Qwen3.8) and the newer, natively-multimodal `Qwen3.8` mainline (Aug 2026, what Alibaba's own docs increasingly point new integrations toward).
  A caution on Qwen3.8's own self-reported comparison table: its model card cites an "Opus 4.6 Max" scoring 72.7% on OSWorld-Verified, which conflicts with Claude's own independently-verified Sonnet 4.6 OSWorld-Verified figure of 78.5% (cross-validated between a secondary aggregator, vellum.ai, and Anthropic's own Sonnet 5 announcement blog).
  A lower Claude tier should not plausibly outscore a higher tier on the same eval if both figures are apples-to-apples, so Qwen's self-reported competitor numbers on its own model card should be treated as directional marketing, not cited as a verified cross-vendor comparison.
- **GLM/Zhipu vision line**: the task framing's assumption of "GLM-4V/GLM-4.x-V" needs a correction: the current flagship as of today is **GLM-4.6V**, which has superseded GLM-4.5V, confirmed directly on Z.ai's own live pricing page (`docs.z.ai/guides/overview/pricing`, primary, fetched 2026-09-18). GLM-4.5V remains live at a higher price.
- **Pixtral (Mistral)**: fully retired. Pixtral 12B retired 2025-12-31, Pixtral Large retired 2026-05-31, confirmed on Mistral's own live model-overview docs (primary, fetched 2026-09-18), with zero mentions of "Pixtral" anywhere on Mistral's current pricing page. Current vision-capable Mistral replacements are Mistral Medium 3.5, Mistral Large 3, and the budget-tier Ministral 3 series. Historical Pixtral benchmark numbers below (from a 2025-era paper) describe a model line that no longer exists as a purchasable option.
- **Molmo (Ai2)**: current version is **Molmo 2**, released 2025-12-11 (Ai2's own blog, primary), open-weight (8B and 4B Qwen3-based variants, plus a 7B Olmo-based "Molmo 2-O"). Ai2's own blog promises OpenRouter hosting "soon".
  As of 2026-09-18, OpenRouter's live catalog has zero Molmo listings. Fireworks AI's model catalog does list Molmo2-4B/8B live, but exact per-token pricing could not be extracted (JS-rendered pricing table) and image-input behavior on that specific endpoint is unconfirmed.
- **InternVL**: current is **InternVL3.5** (announced 2025-08-26, primary: `github.com/OpenGVLab/InternVL`, [arXiv:2508.18265](https://arxiv.org/abs/2508.18265)), but the only confirmed hosted endpoint found (Fireworks AI) serves the older InternVL3 generation (8B/38B/78B), not 3.5. Zero InternVL listings on OpenRouter or Together AI as of 2026-09-18.
- **Llama vision**: a real integration trap exists here. Groq's own vision documentation (`console.groq.com/docs/vision`, primary, fetched 2026-09-18) lists only **`qwen/qwen3.6-27b` and `qwen/qwen3.8-27b`** as vision-capable on Groq, not Llama 4 Scout or Maverick, even though Llama 4's base weights support image input elsewhere (OpenRouter, Together, Fireworks). Anyone assuming "fast Llama vision via Groq" would silently get a text-only endpoint. Llama 3.2 Vision (11B/90B), still cited by some stale pricing aggregators, appears to have been delisted from both Groq's and OpenRouter's live catalogs in favor of Llama 4.

## Dimension A: Visual Reasoning / Quality Judgment

This dimension has no UI-specific benchmark that judges "does this render look janky."
The closest proxies are general multimodal visual-reasoning leaderboards, plus one benchmark, DiffSpot, that comes close to the actual task.
A second, independent research pass on this dimension found that most of these benchmarks publish their model tables as **images**, not machine-readable HTML, which is why an earlier text-only fetch pass under-reported coverage.
Reading the images directly (a second model call over the image bytes) recovered substantially more cheap-tier data than the first extraction attempt.
Both extraction passes are reported below since they used different techniques and corroborate each other where they overlap.

**DiffSpot** ([arXiv:2605.29615](https://arxiv.org/abs/2605.29615), primary, May 2026, independently confirmed real and matching its described methodology by a second, separate verification pass) is the closest match to the actual dimension-A task: it shows models before/after web-interface screenshots and asks them to identify observable CSS-driven differences across 13 properties and 3 difficulty tiers, with 500 no-diff pairs as a hallucination control.

| Model | Overall recall | Hard-tier recall | No-diff (specificity) | Accuracy |
|---|---|---|---|---|
| Gemini 3.1 Pro | 40.7% (best) | 22.7% | 98.4% | 47.2% (best) |
| Kimi K2.5 | 36.4% | 18.6% | 87.2% | 42.2% |
| Gemini 3 Flash | 34.4% | 18.2% | 91.4% | 40.9% |
| Claude Opus 4.7 | 31.2% | 21.8% | 99.6% (tied-best among non-trivial-recall models, see note) | 38.9% |
| GPT-5.4 | 30.5% | 12.2% | 99.6% (tied with Opus) | 38.3% |
| Qwen3.5-397B-A17B | 30.1% | 13.7% | 96.6% | 37.6% |
| Qwen3-VL-235B-Thinking | 19.3% | 10.5% | 98.8% | 28.3% |
| GLM-4.6V | 11.2% | 5.5% | 99.6% | 21.2% |
| Qwen3-VL-235B-Instruct | 5.1% | 2.6% | 100.0% (degenerate, see note) | 15.9% |
| InternVL3.5-30B-A3B | 4.2% | 3.8% | 100.0% (degenerate, see note) | 15.0% |

This finding matters more than any single model's rank on it: no model of the ten tested catches even half of true visual diffs, and hard-tier recall stays below 23% for every model.
Gemini 3 Flash edges Claude Opus 4.7 on raw recall (34.4% vs. 31.2%), but Opus is far more conservative (99.6% no-diff vs. 91.4%), meaning Opus rarely flags a defect that is not there.
Opus is not the field's outright best on the no-diff column: Qwen3-VL-235B-Instruct and InternVL3.5-30B-A3B both score 100.0%, and GPT-5.4 ties Opus exactly at 99.6%.
The two 100.0% models are degenerate on this metric, though: their overall recall is 5.1% and 4.2%, meaning they almost never flag anything at all, so a perfect no-diff score there reflects near-total silence, not judgment.
Restricted to models with non-trivial recall (roughly 30% or higher), Opus ties GPT-5.4 for the best specificity in the field at 99.6%, and that is the precise, defensible claim this report makes going forward, not "the field's best specificity" outright.
For a verdict leg whose false-positive rate matters (a hallucinated defect sends the fix loop chasing nothing), that tied-best precision profile among non-degenerate detectors is the more relevant advantage over Opus's raw recall.
No Claude Sonnet, Haiku, or the current Opus 5 was tested, so this leg's closest task-matched benchmark has no verified datapoint at the tier the accepted proposal would actually use.
The paper also finds near-zero correlation between pixel-distance magnitude and detection, a direct caution against assuming any VLM-judge will reliably flag glaring breaks just because they look visually large to a human.

Beyond DiffSpot, general multimodal visual-reasoning benchmarks are the fallback proxy, and coverage varies sharply by extraction method.
**A first-order finding**: several of these benchmarks' *primary leaderboard pages* are abandoned at their 2024 publication-era model roster when fetched as plain HTML, but the same benchmarks have current cheap-tier data when read from vendors' own recent model-card images (Gemini's, Qwen's, and Zhipu/GLM's own release tables).

| Benchmark | Primary page (HTML fetch) | Vendor model-card tables (image-read) |
|---|---|---|
| MMStar | `mmstar-benchmark.github.io`, stale at 2024-09-26, 18 models, zero current cheap-tier coverage | Current: see table below, sourced from Qwen's and GLM's own release cards |
| BLINK | `zeyofu.github.io/blink`, stale at 2024-era paper roster | Current: see table below |
| CharXiv | `princeton-nlp.github.io/CharXiv`, last updated 2024-12-25, states GPT-4.1/Qwen2.5-VL/InternVL2.5/Llama-vision/Molmo/Pixtral were "upcoming" at that time | Current: see table below |
| VisualWebBench | `visualwebbench.github.io` + GitHub, 2024-era. Detailed table is an embedded image the HTML fetch could not read | **Confirmed genuinely stale by two independent passes**, not a coverage gap: no Qwen2.5/3-VL, no GLM-4.x-V, no InternVL2.5/3, no current Gemini Flash, no current Claude, no GPT-5, no Pixtral/Molmo/Llama-vision anywhere. This is the one benchmark in this whole report where the first pass's "no cheap models" conclusion holds specifically. |
| MathVista (mini) | `mathvista.github.io`, JS-rendered sortable table, only a 10-row fragment extractable | Current: see table below |
| MMBench-EN (v1.1) | OpenCompass Open VLM Leaderboard, JS-rendered Gradio app, not extractable | Current: see table below |

MMMU (val), merging a secondary llm-stats.com snapshot (2026-09-18) with primary vendor-card figures (Google's Gemini 2.5 report, Qwen's own HF cards, GLM-V's own GitHub table):

| Model | Score | Source |
|---|---|---|
| Gemini 2.5 Pro | 82.0% | primary, Google's Gemini 2.5 report |
| Gemini 2.5 Flash | 79.7% | primary, same report (cross-validates exactly against the secondary llm-stats.com figure) |
| Claude 4 Opus | 76.5% | secondary, Google-reported in the same report |
| Claude 3.7 Sonnet | 75.0% | secondary, llm-stats.com |
| Claude 4 Sonnet | 74.4% | secondary, Google-reported |
| Qwen3-VL-235B-A22B-Instruct | 78.7% | primary, Qwen's own HF card |
| Qwen3-VL-32B / 30B-A3B / 8B | 76.0% / 74.2% / 69.6% | primary, Qwen3-VL GitHub |
| GLM-4.6V / GLM-4.5V | 76.0% / 75.4% | primary, GLM-V GitHub |
| Qwen2.5-VL 72B / 7B | 70.2% / 58.6% | primary, Qwen2.5-VL report |
| GPT-4o | 72.2% (secondary) / 69.1% (Qwen-reported) | mixed |
| Gemini 2.0 Flash | 69.3% | primary |
| Pixtral-12B (CoT) | 52.5% | primary, Mistral's own card |

Claude Haiku, Claude Sonnet 4.5+/Opus 4.5+, InternVL, and Molmo are absent from every MMMU row found by either extraction method.

MMMU-Pro, merging the same two extraction methods:

| Model | Score | Source |
|---|---|---|
| Gemini 3.5 Flash | 83.6% (rank 1 among tracked) | secondary, llm-stats.com |
| Gemini 3 Flash | 81.2% | secondary |
| Qwen3-VL-235B-Thinking | 69.3% | **cross-validated exactly**, appears independently in both a secondary llm-stats.com snapshot and a primary GLM-V GitHub comparison table |
| Qwen3-VL-235B-Instruct | 68.1% | primary, Qwen HF |
| GLM-4.6V / GLM-4.5V | 66.0% / 65.2% | primary, GLM-V GitHub |
| Claude Opus 4.6 | 77.3% | secondary, cross-validates against Anthropic's own Opus 4.6 system card (73.9% no tools, 77.3% with an image-cropping tool) |
| Claude Sonnet 4.6 | 75.6% | secondary |
| Claude Opus 4.1 | 60.7% | secondary, Qwen-reported |
| Claude 4 Sonnet | 56.1% | secondary, Qwen-reported |
| Qwen2.5-VL 72B / 7B | 51.1% / 38.3% | primary |

MathVista (mini):

| Model | Score | Source |
|---|---|---|
| GLM-4.6V / GLM-4.5V | 85.2% / 84.6% | primary, GLM-V GitHub |
| Qwen3-VL-235B-Instruct / 32B / 30B-A3B | 84.9% / 83.8% / 80.1% | primary, Qwen |
| Gemini 2.5 Pro | 77.7% | secondary, Qwen-reported |
| Claude Opus 4.1 | 74.5% | secondary |
| Claude 4 Sonnet | 72.4% | secondary |
| Qwen2.5-VL 72B | 74.8% | primary |
| Claude 3.5 Sonnet | 67.7% | secondary |
| Pixtral-12B (CoT) | 58.0% | primary, Mistral |

MMBench-EN (v1.1):

| Model | Score | Source |
|---|---|---|
| Qwen3-VL-235B-Thinking | 90.6% | secondary, Qwen-reported |
| Qwen3-VL 32B / 30B-A3B / 8B | 88.9% / 87.0% / 85.0% | primary |
| GLM-4.6V / GLM-4.5V | 88.8% / 88.2% | primary |
| Qwen2.5-VL-72B | 88.6% | secondary |
| GPT-4o | 83.4% | secondary |
| Claude 3.5 Sonnet | 82.6% | secondary |
| Claude 4 Sonnet | 82.4% | secondary |

MMStar:

| Model | Score | Source |
|---|---|---|
| Qwen3-VL-235B-Instruct / 32B | 78.4% / 77.7% | primary |
| Gemini 2.5 Pro | 78.5% | secondary |
| GLM-4.6V / GLM-4.5V | 75.9% / 75.3% | primary |
| Claude Opus 4.1 | 71.0% | secondary |
| Qwen2.5-VL-72B | 70.8% | primary |
| Claude 4 Sonnet | 67.4% | secondary |

BLINK (val):

| Model | Score | Source |
|---|---|---|
| Qwen3-VL-235B-Instruct | 70.7% | primary |
| Gemini 2.5 Pro | 70.0% | secondary |
| GPT-4o | 68.0% | secondary |
| GLM-4.6V | 65.5% | primary |
| Qwen2.5-VL-72B | 64.4% | primary |
| Claude Opus 4.1 | 62.9% | secondary |
| Claude 4 Sonnet | 59.9% | secondary |

CharXiv (RQ = reasoning, DQ = descriptive):

| Model | RQ | DQ | Source |
|---|---|---|---|
| Qwen3-VL-235B-Thinking | 66.1% | - | secondary |
| Gemini 2.5 Pro | 62.9% | - | secondary |
| GLM-4.6V | 63.2% | - | primary |
| Qwen3-VL-235B-Instruct | 62.1% | - | primary |
| Claude 4 Sonnet | 60.9% | 87.8% | secondary |
| Claude Opus 4.1 | 60.2% | - | secondary |
| Qwen2.5-VL-72B | 49.7% | 87.4% | primary |

> NOTE(sonnet/delegate-model-comparison): "Claude Opus 4.6," "Claude Sonnet 4.6," and several GPT-5.x sub-variant names on these tables are past this session's knowledge cutoff (January 2026) and could not be independently confirmed to exist beyond the aggregators/vendor cards citing them.
The Opus 4.6 MMMU-Pro figure's cross-validation against Anthropic's own system card is the strongest evidence any of these newer names are being used consistently, not fabricated by one source. A separate aggregator (benchlm.ai, its own "AA-MMMU-Pro" re-run) additionally listed "GPT-6 Astra" (86.9%) and "Claude Mythos" variants that could **not** be verified anywhere else and are treated as likely unreliable content on a low-quality aggregator, not fact. Any figure carrying an unfamiliar model name in this report is flagged this way rather than silently included.

**Reading dimension A plainly**: on general visual reasoning, cheap-tier models are not absent, they are heavily benchmarked and roughly at parity with each other across MMMU/MMMU-Pro/MMBench/MMStar/BLINK/CharXiv: Gemini's flash tier, Qwen3-VL at the 30B-A3B/32B sizes, and GLM-4.5V/4.6V all land within a few points of one another and of GPT-5-mini-class models.
Claude's generalist line appears in these tables mostly at Opus/Sonnet tier.
Claude Haiku is near-totally absent from every general multimodal-reasoning leaderboard checked, because it shipped text-first, so "cheap Claude for the verdict leg" has almost no published visual-reasoning evidence at all, while "cheap non-Claude for the verdict leg" is comparatively well-evidenced on this general-reasoning proxy.
The caveat that matters most, though, is DiffSpot's: MMMU-family benchmarks are academic exam-style visual reasoning, not "does this UI look broken," and DiffSpot's low ceiling for every tier is the more honest signal for the actual verdict task this dimension is meant to stand in for.

**An informal but relevant reliability caveat on using any single cheap model as the fidelity judge**: an informal, non-peer-reviewed project (`github.com/CAPTH69/mllm-ui-judge`, explicitly self-described as informal, not a benchmark) reports that Claude 4.5 Sonnet used as a visual-UI judge correlates with human raters on average (3.65 vs. 3.82 on its own scale) but shows measurable position bias in roughly two of three pairwise comparisons and run-to-run instability.
This is directional, not a rigorous benchmark result, but it reinforces DiffSpot's finding from a different angle: even a capable generalist model is not a reliable single-pass fidelity judge, which argues for keeping an ensemble-looker or Opus-tier judge per the existing R1-R6 discipline rather than routing the verdict leg through one cheap-tier call regardless of provider.

## Dimension B: Website Navigation & Usage

### B1. GUI Grounding / Element-Clicking

This is where the first pass's search-breadth failure was most consequential, and where this revision found the clearest primary-sourced correction.

**A Correction to the first pass's ScreenSpot-Pro claim.** The first pass cited "Claude Opus 4.8 at 87.9%, GPT-6 Astra at 92.7%, Gemini 3.1 Pro at 84.4%, Gemini 3 Pro at 72.7%" from two secondary aggregators (benchlm.ai, llm-stats.com).
This revision fetched the **primary, actively-maintained ScreenSpot-Pro leaderboard directly** (`gui-agent.github.io/grounding-leaderboard`, backed by `raw.githubusercontent.com/GUI-Agent/grounding-leaderboard/main/results/screenspot_pro.json`, last commit 2026-09-18, the same day as this fetch).
That primary JSON contains **none of those four model names or scores**.
It shows instead: a single generic "Claude (Computer Use)" row at 17.1%, GPT-4o at 0.8%, GPT5-minimal at 18.5%, and no Gemini, GLM, or InternVL entries of any kind.
The board is instead dominated by GUI-grounding specialist models: Holo2-235B-A22B (70.6%), GTA1-32B (63.6%), UI-TARS-1.5 (61.6%), GTA1-Qwen2.5VL-72B (58.4%).
This is a direct, dated conflict between the primary maintained leaderboard and the secondary aggregators the first pass relied on exclusively.
The prior report's specific numbers should be treated as unverifiable against the primary source and not repeated as fact.
This revision could not determine which source is stale or mistaken, only that they disagree substantially, and the primary GitHub-hosted leaderboard is the more authoritative source of record in principle.

**A further downgrade on this correction's own shelf-life.** The primary leaderboard is itself too volatile to anchor a durable decision on specific rows: an independent re-fetch of the identical raw JSON URL, performed one day after this revision's research pass, returned an entirely different model roster (Indeed-UI-8B/32B, HuzzleWorld-2B, Duvo Eye-1, KV-Ground, AdaZoom-GUI-4B, UI-Venus-1.5, Holo2-4B/8B), and none of the specific rows tabulated below (Claude Computer Use 17.1%, Holo2-235B-A22B 70.6%, GTA1-32B, UI-TARS-1.5, UGround, Aguvis, OS-Atlas, ShowUI) survived.
The table below should therefore be read as an **expired, single-day snapshot (fetched 2026-09-18)**, not a stable reference point, and the primary-vs-secondary-aggregator disagreement documented above cannot now be re-adjudicated against the same rows.
The durable takeaway from this dimension is not any specific row's score but the structural finding, corroborated independently across ScreenSpot-Pro, ScreenSpot-v2, UI-Vision, and OSWorld-G below: GUI-grounding specialist models (UI-TARS, GTA1, Holo2, UGround, and similar) consistently dominate both Claude's and Gemini's generalist tiers on pure element-grounding tasks, often by 2-4x, regardless of which specific specialist or which day's leaderboard snapshot is checked.
That structural claim, not the specific percentages, is what this report's B1 conclusion rests on.

ScreenSpot-Pro, primary leaderboard, expired single-day snapshot (overall accuracy, fetched 2026-09-18, confirmed superseded by a re-fetch one day later, see caveat above):

| Model | Score | Family |
|---|---|---|
| Claude (Computer Use), version unspecified in the leaderboard's own metadata | 17.1% | Claude |
| GPT-4o | 0.8% | GPT |
| GPT5-minimal (resized) | 18.5% | GPT |
| Qwen2.5-VL-3B-Instruct | 16.1% | Qwen |
| Qwen2.5-VL-7B-Instruct | 26.8% | Qwen |
| Qwen2.5-VL-32B-Instruct | 48.0% | Qwen |
| Qwen2.5-VL-72B-Instruct | 53.3% | Qwen |
| UI-TARS-1.5 | 61.6% | specialist |
| GTA1-32B | 63.6% | specialist |
| Holo2-235B-A22B (Agentic) | 70.6% | specialist, top of board |
| UGround-v1-72B | 34.5% | specialist |
| Aguvis-7B | 22.9% | specialist |
| OS-Atlas-7B | 18.9% | specialist |
| ShowUI-2B | 7.7% | specialist |

Gemini (any tier), GLM, InternVL, Llama vision, Molmo, and Pixtral are confirmed absent by direct substring search of every key in the raw JSON.

**ScreenSpot-v2** (same primary repo, `results/screenspot_v2.json`, subject to the same expired-snapshot caveat as ScreenSpot-Pro above) tells the same story more starkly: GPT-4o scores 20.1%, Qwen2.5-VL-7B-Instruct scores 86.5%, and open GUI-grounding specialists dominate the top of the board (UI-Venus-72B 95.3%, Holo2-30B-A3B 94.9%, Holo1.5-72B 94.4%). Claude and Gemini are entirely absent from this leaderboard's keys.

**UI-Vision** ([arXiv:2503.15661](https://arxiv.org/abs/2503.15661), primary, revised 2025-05-06) is the single strongest counter-example to "no flash-tier coverage exists," because it directly names and scores Gemini's flash tier:

| Model | Element Grounding (Basic) | Layout Grounding IoU |
|---|---|---|
| Gemini-Flash-2.0 | 0.45% | 28.3 |
| Gemini-1.5-Pro | 0.79% | 30.8 |
| GPT-4o | 1.58% | 20.0 |
| Claude-3.5-Sonnet | 5.08% | 22.4 |
| Claude-3.7-Sonnet | 9.48% | 17.6 |
| UI-TARS-72B | 31.4% (best on Basic) | not reported |

Gemini's flash tier is near the bottom on click-level element grounding but is the second-best model tested on layout-region grounding (28.3 IoU, close behind its own Pro tier's 30.8 and ahead of GPT-4o's 20.0). Claude's generalist models improve version over version (3.5 to 3.7 Sonnet roughly doubles on element grounding) but remain dramatically outclassed by open specialist models built on cheap backbones.

**OSWorld-G** ([arXiv:2505.13227](https://arxiv.org/abs/2505.13227), primary, v3 2025-10-24) tests Gemini-2.5-Pro (45.2%) but has **no Flash-tier Gemini row at all** in its own Table 5, confirmed by direct fetch of the full table twice. Qwen2.5-VL is tested across 3B/7B/32B (27.3% to 46.5%), and the benchmark's own specialist model, Jedi (built on a UI-TARS/Qwen backbone), scores 50.9% (3B) to 54.1% (7B), beating every generalist model tested at a fraction of the parameter count.

**The throughline across all four GUI-grounding benchmarks checked:**
GUI-grounding specialist models, most built on cheap open (often Qwen-VL) backbones in the 2B-72B range, are the actual strongest candidates for option 4's "cost-effective visual specialist," not Qwen-VL, InternVL, or GLM used generically.
They consistently beat both Claude's and Gemini's generalist tiers, cheap or expensive, by wide margins on the specific "click the right pixel" task, and this structural pattern holds independently of which day's ScreenSpot-Pro snapshot is checked, unlike any specific row's score.

### B2. Web / Computer Agent Tasks

This benchmark family splits cleanly along a methodological line that matters for a fair comparison: **raw grounding/action accuracy** (a single-step classification, closer to isolating the base model) versus **full agent-scaffold success rate** (a multi-step tool-call loop, where the harness quality can dominate the underlying model's contribution).

**Raw-grounding benchmarks** (Mind2Web, Multimodal-Mind2Web/SeeAct, VisualWebArena) predate current cheap-tier models entirely.
Their primary papers (2023-2024) test only GPT-4/GPT-3.5/Gemini-Pro-1.0 and contain zero Claude, zero Flash-tier, zero Qwen-VL entries. This is a genuine, confirmed absence, not a search failure, because the benchmarks are simply older than the models in question.

**Full-scaffold benchmarks** show a much more mixed and interesting picture:

| Benchmark | Primary/official source | Flash/cheap-tier finding |
|---|---|---|
| **AndroidWorld** | Official Google Sheets leaderboard linked from `github.com/google-research/android_world`, table content cross-checked via a secondary mirror (benchmarklist.com) since the live Sheet could not be rendered directly | **Gemini 3 Flash and Gemini 3 Flash-Lite are tied for #1 at 97.4%** on the mirrored table (dated 2026-05-27), ahead of Claude+Gemini-Pro combos at 94.8%. Qwen3.8-27B (81.9%) and Qwen2.5-VL-72B (76.7%) also appear. This is the strongest single counter-example found to "no benchmark contains flash-tier models," though the exact primary Sheet numbers need a direct re-check since WebFetch could not render the live Google Sheet itself. |
| **WebArena / WorkArena** | The original WebArena paper's own Google Sheets leaderboard has none, but a second, independently-checked source corrects this: the actively-maintained **ServiceNow BrowserGym leaderboard** (`huggingface.co/spaces/ServiceNow/browsergym-leaderboard`, primary raw per-run JSON) runs the same benchmark names with current models | The original paper is Pro-tier/frontier-only, as the first pass found. But BrowserGym's live leaderboard has real cross-tier entries: WebArena's GenericAgent-Claude-3.7-Sonnet scores 44.6%, Claude-3.5-Sonnet 36.2%, GPT-4o 31.4%, and an open combo (A3-Qwen3.5-9B) 42.1%. WorkArena-L1 shows IpaziaHPA-Gemini-3-flash-preview at 90.3% (a rare primary Gemini-flash web-agent datapoint, though on a custom AXTree agent rather than the GenericAgent scaffold, so not harness-matched with the other rows), GenericAgent-GPT-5 79.1%, Claude-4-Sonnet 63.3%, Claude-3.5-Sonnet 56.4%. **The conclusion "this benchmark family lacks Claude/Gemini-Flash/Qwen entries" is true only of the original 2023-era papers, not of the actively-maintained leaderboard running the same benchmark name today**, an important distinction for any future search in this family. |
| **OSWorld** | Primary paper ([arXiv:2404.07972](https://arxiv.org/abs/2404.07972)) and XLang Lab's own "OSWorld-Verified" blog snapshot | The curated, officially-verified snapshot does not include Flash/Haiku/mini-tier scores (Claude 4 Sonnet 43.9%, UI-TARS 40.0%, o3 9-23%). Two different secondary aggregators (steel.dev, llm-stats.com) both claim to show Flash/Haiku/mini-tier scores, but they **disagree with each other** on which models are even present, and llm-stats.com explicitly labels its own OSWorld-Verified table "Unverified, 24 self-reported, 0 verified." This is the clearest case in this whole research pass where "no verified benchmark contains flash-tier models" is defensible for the *curated primary* leaderboard specifically, while being false for the wider, self-reported aggregator ecosystem around the same benchmark name. |
| **OSWorld-MCP** | [arXiv:2510.24563](https://arxiv.org/abs/2510.24563), primary, Oct 2025, independently confirmed real and topic-matching by a separate verification pass | This is the best primary source pairing Claude Sonnet directly against Qwen-VL on the same computer-use task set (15 steps, GUI-only vs. GUI + MCP tools): see table below. |
| **WebVoyager** | Original paper ([arXiv:2401.13919](https://arxiv.org/abs/2401.13919)) plus a secondary aggregator (steel.dev) | No Flash/Haiku/mini tier anywhere. Notably, the paper itself documents a strong judge-bias effect: a model's own score jumps 8+ points when it grades its own trajectories, a real methodological confound worth flagging for any future in-house VLM-judge comparison. |
| **Online-Mind2Web** | Official OSU NLP HuggingFace Space, raw CSV fetched directly (primary) | No Flash/Haiku/mini/Qwen-VL tier in the official CSV. Best tracked entry is "Gemini 2.5 Computer Use" (a Pro-class agent) at 69.0% average success. |
| **HAL Online-Mind2Web** | Princeton's Holistic Agent Leaderboard ([arXiv:2510.11977](https://arxiv.org/abs/2510.11977) for the general HAL infrastructure, independently confirmed real. The per-model Online-Mind2Web numbers themselves live on HAL's own leaderboard site rather than being restated in the paper's abstract text) | The single cleanest same-scaffold cost/quality tradeoff found in this whole report: see table below. |
| **TheAgentCompany** | [arXiv:2412.14161](https://arxiv.org/abs/2412.14161), primary, Table 1 | Gemini-2.0-Flash 11.4% task success at $0.6/task, Claude-3.7-Sonnet 26.3% at $4.1/task, Gemini-2.5-Pro 30.3% at $4.2/task, Qwen-2.5-72B 5.7% at $1.5/task. Independent corroboration, from a fully primary source, of the same cheap-but-weaker tradeoff HAL's numbers show below. |
| **WebBench (Halluminate)** | Official leaderboard (`webbench.ai`), fetched directly | Only 5 entries total, all frontier-tier. The project's own GitHub README explicitly lists Claude 4, Operator O3, UI-TARS, and Mariner as "planned" future evaluations, meaning cheap-tier coverage is not merely unreported, it has not been run yet. |

**HAL Online-Mind2Web**, same two agent scaffolds (Browser-Use, SeeAct) applied to the same live-web task set, with total eval-run cost reported:

| Scaffold | Model | Accuracy | Run cost |
|---|---|---|---|
| SeeAct | GPT-5 Medium | 42.33% | $171.07 |
| Browser-Use | Claude Sonnet 4 | 40.00% | $1,577.26 |
| Browser-Use | Claude-3.7 Sonnet High | 39.33% | $1,151.88 |
| Browser-Use | Claude-3.7 Sonnet | 38.33% | $926.48 |
| Browser-Use | GPT-4.1 | 36.33% | $236.62 |
| Browser-Use | DeepSeek V3 | 32.33% | $214.74 |
| Browser-Use | Gemini 2.0 Flash | 29.00% | $8.83 |
| SeeAct | Gemini 2.0 Flash | 26.67% | $5.03 |

Gemini Flash buys roughly 70-75% of Claude Sonnet's task success at well under 1% of the run cost on this eval, the clearest statement of the cost/quality tradeoff found anywhere in this report.
No Claude Haiku and no Qwen-VL entry exists on this leaderboard.

**OSWorld-MCP**, computer-use tasks at 15 steps, GUI-only versus GUI plus MCP tools:

| Model | GUI-only | + MCP tools |
|---|---|---|
| Agent-S2.5 (framework) | 36.7% | 42.1% |
| Claude 4 Sonnet | 30.2% | 35.3% |
| Seed1.5-VL | 27.9% | 32.0% |
| Qwen3-VL | 25.4% | 31.3% |
| Gemini-2.5-Pro | 7.4% | 20.5% |
| OpenAI o3 | 8.3% | 20.4% |
| Qwen2.5-VL | 11.4% | 13.1% |

At 50 steps Claude 4 Sonnet reaches 40.1% -> 43.3%.
Claude Sonnet leads the single models here, Qwen3-VL is a real step up from Qwen2.5-VL and lands just behind Sonnet, and the Gemini entry tested is the Pro tier (no Flash tested in this paper) and underperforms both.

**Reading dimension B2 plainly**: the maintainer's instinct that common benchmarks cover cheap tiers is correct for AndroidWorld, for WebArena/WorkArena once the actively-maintained BrowserGym leaderboard is checked instead of just the original papers, and for HAL's Online-Mind2Web and OSWorld-MCP specifically.
The first pass's caution was closer to right for VisualWebArena, WebVoyager, the official Online-Mind2Web CSV, and WebBench specifically.
OSWorld sits in between: real cheap-tier data exists but only in self-reported, mutually-contradicting aggregator form, not in the curated primary leaderboard.
Across every full-scaffold benchmark with real cheap-tier data (HAL, OSWorld-MCP, TheAgentCompany), the same pattern holds: Claude leads on raw quality, Gemini Flash trails by a modest margin at a dramatically lower cost, and Qwen-VL sits behind both as an autonomous driver even though it grounds well (see B1).

## Dimension C: Visual-Oriented CSS/Layout Correction

This is the dimension the first pass never searched at all, and it turned up the single most decision-relevant data point in this whole revision.

| Benchmark | Source (primary, fetched directly) | Task shape | Cheap/flash-tier finding |
|---|---|---|---|
| **Design2Code** | [arXiv:2403.03163](https://arxiv.org/abs/2403.03163), 2024-03 | Whole-page generation from a design image, not a targeted fix | Predates current cheap tiers entirely: GPT-4o (Block-Match 93.0, CLIP 90.4), Claude 3 Opus (90.2 / 87.0), Gemini 1.0 Pro (80.2 / 84.4). No Flash tier, no Sonnet/Haiku, no Qwen-VL. Useful only as a historical whole-page baseline, not for the narrow fix task. |
| **Vision2Web** | [arXiv:2603.26648](https://arxiv.org/abs/2603.26648), primary, 2026-07-20, Tsinghua/Zhipu AI | Hierarchical: static page, interactive frontend, and full-stack generation from a design prototype, scored via Visual Score + Functional Score under two coding-agent frameworks (Claude Code, OpenHands) | **Gemini-3-Flash-Preview is directly named and scored**: Static avg 47.8, Frontend VS/FS 25.9/38.4, Full-Stack VS/FS 7.7/17.2, consistently behind Claude-Opus-4.5 (Static 53.4, Frontend 46.5/66.7, Full-Stack 38.4/57.6) and Claude-Sonnet-4.5 on the harder interactive/full-stack levels. This is whole-application generation, not a targeted CSS fix, so it is a partial proxy for dimension C at best. |
| **DesignBench** | [arXiv:2506.06251](https://arxiv.org/abs/2506.06251), primary, revised 2026-03-15 | Explicitly includes a **repair** task category alongside generation and edit, across React/Vue/Angular/vanilla, 900 samples, 6 issue categories: this is the closest primary match to "given a screenshot and a reference, make the small fix" | On the repair task's MLLM Score (0-10): Claude-3.7 leads (6.79-7.18 across frameworks), GPT-4o and Gemini-2.0 close behind (~5.9-7.3), **Pixtral-124B is competitive with frontier models (6.46-6.96)** despite being a since-retired mid-size model, Qwen-72B is reasonable (5.64-6.89), while cheap/small variants collapse: Qwen-7B scores 0.0-3.86, Llama-11B scores 2.75-5.79. Compilation success rate tells a similar story: frontier and mid-size models compile reliably (0.93-1.0 except on vanilla HTML/CSS), the smallest models are not separately reported at this stage. |
| **1D-Bench** | [arXiv:2602.18548](https://arxiv.org/abs/2602.18548), primary, July 2026, independently confirmed real and matching its described "iterative UI code generation with visual feedback" methodology by a second verification pass | An agent iterates on UI code using visual feedback to converge on a target render. Final Score = visual similarity x render success rate, across single- and multi-round attempts | The direct counterweight to MT-Web2Code below: see table below. |
| **MT-Web2Code** | [arXiv:2608.03474](https://arxiv.org/abs/2608.03474), primary, 2026-08-04 | The most direct match found for dimension C: a "Reverse-Corruption Trajectory Engine" injects a defect into a rendered page, then scores an agent's macro-level regional reconstruction and micro-level localized modification against the original, on layout/element/text/color/spacing sub-scores plus a target-region-fidelity-vs.-collateral-damage composite (`S_inbox`/`S_outbox`) | The most Gemini-favorable result of this whole report. See table below. |
| **Figma2Code** | [arXiv:2604.13648](https://arxiv.org/abs/2604.13648), ICLR 2026, primary | Design-fidelity Visual Evaluation Score (VES) for a design-to-code task | GPT-5 0.8405, Gemini 2.5 Pro 0.8110, Grok4 0.7997, Claude Opus 4.1 0.7761, GPT-4o 0.7405, **Qwen2.5-VL 0.6516 (near bottom)**. This corroborates DesignBench's ordering: Qwen-VL underperforms Claude/GPT/Gemini specifically on design fidelity, even though it grounds GUI elements well (see B1). |

**1D-Bench full results.** 1D-Bench's own metric is Final Score = visual similarity x render success rate.
Where render success is exactly 100% (Gemini 3 Pro's single round), the raw-similarity figure and the final-score figure are numerically identical, since multiplying by 1.0 changes nothing.
That is stated explicitly per-row below rather than left as an ambiguous column label, because an earlier version of this table conflated the two metrics in one column:

| Model | Single-round score | Multi-round final score | Render success |
|---|---|---|---|
| Claude Sonnet 4.5 | 74.0 (render success 90.9%, so this is below Claude's unreported raw similarity) | 80.4 (best multi-round final) | 90.9% -> 97.7% |
| Gemini 3 Pro | 79.6 (best single-round: render success is 100% here, so this figure is simultaneously the raw similarity and the final score) | 79.5 | 100% -> 97.7% |
| GPT-5.2 | 49.8 | 79.1 | 63.6% -> 93.2% |
| Qwen3-VL-235B | 59.0 | 61.9 | 94.7% -> 97.4% |
| GLM-4.6V | 3.7 | 5.2 | 6.8% -> 6.8% |

Claude Sonnet 4.5 leads the multi-round final composite (80.4 vs. Gemini 3 Pro's 79.5, a margin under one point), but Gemini 3 Pro leads single-round (79.6 vs. Claude's 74.0).
So "Claude is the best performer across both rounds" overstates Claude's position: the two models split single-round and multi-round, and Gemini's single-round lead is not a metric-conflation artifact, since its render success was already 100% there.
Qwen3-VL-235B is reliable at rendering (94.7% success) but visually mediocre (59.0 single-round, 61.9 multi-round final), and GLM-4.6V illustrates the open-model failure mode of "looks plausible when it renders but almost never builds" (6.8% render success).
No Opus and no Gemini Flash tier were tested on 1D-Bench, a real gap for options 1 and 3 on this specific leg.
This still contradicts, though less cleanly than a first read suggests, MT-Web2Code's headline direction: on 1D-Bench, Claude Sonnet wins the multi-round final composite while Gemini 3 Pro wins single-round.
On MT-Web2Code, Gemini 3.5 Flash beats Claude's Opus tier on both task shapes tested (no current-tier 3.8 Flash was tested on either benchmark).
Both are primary.
Both are recent (2026).
Both are structurally close to the "recenter a div" task.
The honest reading is that dimension C's outcome is benchmark-dependent, and now mixed even within 1D-Bench itself, not settled in either direction, and a real pilot (not another literature search) is the only way to resolve which one better predicts this proposal's actual workload.

**MT-Web2Code full results** (13 frontier coding agents, primary source, 2026-08-04):

Macro-level regional reconstruction (rebuild a larger region from scratch):

| Model | Score |
|---|---|
| **Gemini-3.5-Flash** | **65.5** (best of all 13) |
| Kimi-K2.6 | 63.7 |
| Claude-4.7-Opus | 63.0 |
| Qwen3.5-Plus | 62.8 |
| Gemini-3.1-Flash-Lite | 58.8 |
| GPT-5.4 | 57.3 |
| GLM-5V-Turbo | 54.6 |
| Gemini-3.1-Pro-Preview | 50.3 |
| Qwen3-VL-Plus | 37.3 |
| GLM-4.6V | 35.9 |
| Qwen3-VL-Flash | 10.0 (worst) |

Micro-level localized modification (the "recenter a div"-shaped task):

| Model | Score |
|---|---|
| Doubao-Seed-2.0-Pro | 83.5 (best) |
| Qwen3.5-Plus | 83.3 |
| GPT-5.4 | 82.1 |
| Gemini-3.1-Pro-Preview | 82.1 |
| GLM-5V-Turbo | 80.6 |
| **Gemini-3.5-Flash** | **80.5** |
| Gemini-3.1-Flash-Lite | 78.9 |
| **Claude-4.7-Opus** | **77.3** |
| Qwen3-VL-Plus | 75.8 |
| Kimi-K2.6 | 75.3 |
| Qwen3-VL-Flash | 35.6 (worst) |

The paper's own stated finding corroborates this reading directly: "lightweight models in the Gemini series outperform some larger models, such as Claude-4.7-Opus and Gemini-3.1-Pro-Preview" on the macro task.
**Gemini 3.5 Flash beats an unconfirmed "Claude-4.7-Opus" name on both sub-tasks of the one benchmark that most directly matches this proposal's dimension C.**
This is a 3.5 Flash result, not a current-tier result: the current Gemini flash tier is 3.8 Flash, and it was not tested on this or any other task-matched benchmark in this report.
This is otherwise a primary-sourced, dated, specific result, not an inference from a general-reasoning proxy.

Two important qualifiers on this finding:

- "Claude-4.7-Opus" and "GPT-5.4" are model names this session could not independently confirm exist beyond this paper's own usage (knowledge cutoff January 2026). The paper itself is the only source for these names in this report, and it is the most directly-relevant primary source available, so it is used as-is with this caveat stated rather than discarded.
- `Qwen3-VL-Flash`, the cheapest Qwen entry, is the single worst performer on both tasks (10.0 and 35.6), a sharp contrast to Gemini's flash tier leading or near-leading.
  "Flash-tier" is not a uniform quality class across providers.
  Gemini's flash tier and Qwen's flash tier land at opposite ends of this specific benchmark.

Two additional design-fidelity benchmarks exist (**WebCode2M**, [arXiv:2404.06369](https://arxiv.org/abs/2404.06369), a 2.56M-instance training dataset with a `WebCoder` baseline and `TreeBLEU` metric, and **Interaction2Code**, [arXiv:2411.03292](https://arxiv.org/abs/2411.03292), ASE 2025, 127 pages/374 interactions focused on a ten-category interaction-failure taxonomy) but neither publishes a broad, current cross-model leaderboard suitable for this comparison.
They are noted for completeness and as candidates for a future, deeper pass if dimension C evidence needs to be extended further.

**Reading dimension C plainly**: this dimension now has two benchmarks built almost exactly for the proposal's own "recenter a div" framing, and they disagree, including within 1D-Bench itself once its single-round and multi-round metrics are read correctly rather than conflated.
MT-Web2Code shows Gemini 3.5 Flash beating an unconfirmed "Claude-4.7-Opus" name on both task shapes tested.
The current Gemini 3.8 Flash was not tested here or anywhere else in this report.
1D-Bench shows a split result on the same iterative-visual-fix task shape: Claude Sonnet 4.5 leads the multi-round final composite (80.4 vs. Gemini 3 Pro's 79.5) but Gemini 3 Pro leads single-round (79.6 vs. Claude's 74.0).
DesignBench's narrower repair task and Figma2Code's design-fidelity score both land closer to 1D-Bench's multi-round ordering (Claude ahead, Qwen-VL behind, small open models collapsing).
Taken together, DesignBench and Figma2Code favor Claude cleanly, 1D-Bench splits by round, and MT-Web2Code favors Gemini's flash tier by a wide margin on both task shapes.
The honest synthesis is that Claude is a marginally safer default on current evidence, but the margin is thinner than a clean majority count implies, and MT-Web2Code's result is too large and too directly on-task to dismiss, which is the strongest single reason in this whole report to run a real pilot rather than settle the question from benchmarks alone.

## Cost

Verified 2026-09-18 unless noted, all figures per million tokens, input/output:

| Model | Input | Output | Image handling | Source |
|---|---|---|---|---|
| Claude Sonnet 5 | $2 | $10 | Standard token formula (`platform.claude.com`) | primary, carried from first pass, spot-checked stable |
| Claude Haiku 4.5 | $1 | $5 | Same formula | primary, carried from first pass |
| Claude Opus (current judge tier) | higher, ~$5/M+ range, not separately re-verified this pass | n/a | Same formula | primary (first pass), not re-checked |
| Gemini 3.8 Flash | $0.75 (through 2026-12-31, then $1.50) | $3.75 (through 2026-12-31, then $7.50) | Billed as standard tokens, no separate image line item | primary, `ai.google.dev/gemini-api/docs/pricing`, re-verified this pass |
| Gemini 3.5 Flash-Lite | $0.30 | $2.50 | Same | primary, same page |
| Qwen3-VL-Flash (DashScope, 0-32K context) | $0.05 | $0.40 | Tile-based, not independently re-derived this pass | primary, Alibaba Cloud Model Studio pricing page |
| Qwen3-VL-Plus (DashScope, 0-32K context) | $0.20 | $1.60 | Same | primary, same page |
| Qwen3-VL-235B-A22B-Instruct (via OpenRouter) | $0.21 | $1.90 | Confirmed image input | secondary marketplace, corroborates DashScope order-of-magnitude |
| GLM-4.6V | $0.30 | $0.90 | Confirmed image input | primary, `docs.z.ai/guides/overview/pricing`, cross-checked exactly against OpenRouter's mirror |
| GLM-4.6V-FlashX | $0.04 | $0.40 | Confirmed image input | primary, same page |
| Llama 4 Scout (OpenRouter, not Groq) | $0.10 | $0.30 | Confirmed image input on OpenRouter/Together/Fireworks | secondary marketplace, **not available with vision on Groq specifically**, see Llama vision trap above |
| Pixtral | retired, no longer purchasable | n/a | n/a | primary, Mistral's own docs |
| InternVL3 (Fireworks) | not found (JS-rendered pricing page) | n/a | image support on this endpoint unconfirmed | gap, flagged explicitly rather than guessed |
| Molmo2 (Fireworks) | not found (JS-rendered pricing page) | n/a | image support on this endpoint unconfirmed | gap, flagged explicitly rather than guessed |
| GUI-grounding specialists (UI-TARS, GTA1, Holo2, UGround, Jedi) | no standardized hosted pricing found, these are largely open-weight models evaluated in their own papers, not consistently offered as metered APIs | n/a | N/A | gap: strongest dimension-B performers have the weakest verified cost data |

**Reading cost plainly**: every option here is a fraction of a cent per screenshot at typical resolutions.
The spread between cheapest (Qwen3-VL-Flash or GLM-4.6V-FlashX, both under $0.10/M input) and most expensive (Claude Opus) is roughly 50-100x on paper, but at realistic per-call token volumes (a few thousand tokens per screenshot judgment) this is still fractions of a cent versus a few cents, not a cost that should dominate the decision on its own.
Cost is a much weaker discriminator than the benchmark evidence above for a single-screenshot verdict or fix call.
The HAL Online-Mind2Web run-cost figures in dimension B2 show the lever can matter far more once a workload involves many agentic turns rather than one judgment call.

## Speed / Latency

Figures below are secondary (Artificial Analysis, via search/fetch, not independently re-derived) except where marked.
Treat as directional, not exact:

| Model | Output tok/s | Time-to-first-token | Source |
|---|---|---|---|
| Claude Haiku 4.5 | not re-checked this pass | sub-600ms (first pass finding) | secondary, carried over |
| Claude Sonnet 5 | not re-checked this pass | ~0.97s (first pass finding) | secondary, carried over |
| Gemini 3.8 Flash ("high" reasoning variant) | ~305-345 | ~15.7s | secondary, carried over from first pass, not re-verified this revision |
| Qwen3-VL-235B-A22B-Instruct (Alibaba's own API) | 49.9 | ~2.61s | secondary, Artificial Analysis, fetched this pass |
| Qwen3.5-397B-A17B (Alibaba's vision-capable successor line) | 80.9 | ~2.10s | secondary, same source |
| Groq-hosted text models (context only, not vision-capable on Groq) | 286-944 | 0.75-0.83s | secondary, Artificial Analysis, included only to show Groq's hardware speed ceiling, since no vision model on Groq is confirmed this fast |

**Reading speed plainly**: Gemini's flash tier's long TTFT (when its "high" reasoning/thinking mode is engaged) is a genuine latency concern for a single-verdict-per-screenshot workload, as the first pass found.
Qwen3-VL's Alibaba-hosted TTFT (~2.6s) sits between Claude Sonnet's ~1s and Gemini Flash's ~15.7s.
No fast, confirmed-vision-capable, sub-second-TTFT open/cheap option was found in this pass.
The closest candidate (Groq) does not host a confirmed vision-capable model as of 2026-09-18.

## Synthesis: Option x Dimension

Quality read is a synthesis of the tables above, not a new score.
"n/e" means no task-matched evidence was found in this pass.

| Option | A. Visual judgment | B. Web navigation | C. CSS/layout fix | Cost | Speed | Harness fit |
|---|---|---|---|---|---|---|
| **1. Opus driver + Opus judge** | Best precision among non-degenerate detectors on the closest task-matched benchmark: DiffSpot's Claude Opus 4.7 ties GPT-5.4 for the field's best specificity among models with non-trivial recall (99.6% no-diff). Two higher-scoring models (100.0%) have 4-5% recall and are degenerate. Opus rarely hallucinates a defect, even though its raw recall (31.2%) trails Gemini's flash tier slightly. Strongest verified generalist reasoning otherwise | Not separately isolated in the grounding or full-scaffold benchmarks checked (Claude entries are mostly Sonnet-tier). Presumed strong by extension of general capability, unverified directly | No confirmed-current-Opus datapoint on 1D-Bench or MT-Web2Code (both test Sonnet or an unconfirmed "Claude-4.7-Opus" name). Opus leads Vision2Web's whole-application generation task, a weaker C proxy | Highest of all options | Not latency-optimized, irrelevant for a judgment-only call | Native, zero integration cost |
| **2. Sonnet driver + Sonnet judge** | No DiffSpot datapoint at all for any Sonnet version, a real gap. Present on MMMU-Pro (secondary) in the 75-77% range, mid-pack. The mllm-ui-judge informal check found even Sonnet-tier single-pass judging is run-to-run unstable | Best or near-best single generalist model on every full-scaffold benchmark with real cheap-tier data: HAL Online-Mind2Web (40.0% at ~$1,577/run, an older Claude Sonnet 4 / Gemini 2.0 Flash pricing tier, see B2 caveat), OSWorld-MCP (30.2%->35.3%), BrowserGym WebArena (44.6%). Scores 17.1% on primary ScreenSpot-Pro (expired snapshot, see B1) grounding specifically, near the bottom among all models tested there, far behind GUI-grounding specialists | **Claude Sonnet 4.5 leads 1D-Bench's multi-round final composite (80.4 vs. Gemini 3 Pro's 79.5)** but trails Gemini 3 Pro's single-round score (74.0 vs. 79.6), a split rather than a clean win. Loses to Gemini 3.5 Flash on MT-Web2Code's two tasks (tested against an unconfirmed "Claude-4.7-Opus" name, not Sonnet, on that specific benchmark) | Cheap, in-family | ~1s TTFT, adequate | Native, zero integration cost, the only option requiring no gateway or direct-API work |
| **3. Current Gemini flash tier (3.8 Flash / 3.5 Flash)** | Tops the MMMU-Pro aggregator among tracked models and edges Claude Opus on DiffSpot's raw recall (34.4% vs. 31.2%, tested version: Gemini 3 Flash), but with much worse specificity (91.4% vs. 99.6% no-diff), a worse false-positive profile for a verdict leg | Present and scored on UI-Vision (competitive on layout grounding, weak on element grounding), AndroidWorld (tied #1 on one aggregator-mirrored snapshot), and BrowserGym's WorkArena-L1 (90.3%, though on a non-harness-matched custom agent). Trails Claude by a modest margin at dramatically lower cost on HAL Online-Mind2Web (29.0% at ~$8.83/run, Gemini 2.0 Flash, an older pricing tier) and TheAgentCompany. Absent from ScreenSpot-Pro/v2 and OSWorld-G entirely, and only Pro-tier (no Flash) was tested on OSWorld-MCP | **Gemini 3.5 Flash (not the current 3.8 Flash, untested on any task-matched benchmark) wins outright over an unconfirmed "Claude-4.7-Opus" name on MT-Web2Code's macro and micro tasks**, but **splits with Claude Sonnet 4.5 on 1D-Bench** (Gemini 3 Pro leads single-round, Claude leads multi-round final by under a point), a genuinely mixed result on an equally close task shape | Cheapest generalist option, ~$0.75-3.75/M, ~180x cheaper than Claude Sonnet per HAL's run-cost figures (HAL's own figures use an older Gemini 2.0 Flash / Claude Sonnet 4 pricing tier, not current prices) | Long TTFT (~15.7s) in its reasoning-heavy mode is a real per-call latency cost | Not native, requires a gateway or direct API call from the delegate's own tool code |
| **4. Open/specialist models (Qwen-VL, Qwen3.8, UI-TARS/GTA1/Holo2/Jedi, GLM-4.6V, others)** | Qwen2.5/3-VL present on MMMU/MMMU-Pro/MMBench/MMStar/BLINK/CharXiv, roughly at parity with Gemini's flash tier and GLM-4.5V/4.6V at the 30B-A3B/32B sizes. DiffSpot places Qwen3-VL-235B-Thinking and InternVL3.5 near the bottom of the field | **Dominant on pure grounding**: GUI-grounding specialists (UI-TARS-1.5, GTA1-32B, Holo2-235B, Jedi) beat every generalist model, cheap or expensive, Claude or Gemini, on every GUI-grounding benchmark checked, often by 2-4x, but Qwen3-VL itself trails Claude Sonnet as an autonomous multi-step driver on OSWorld-MCP (31.3% vs. 35.3%) | Mixed and generally weak: Qwen3-VL-Flash is the *worst* performer on MT-Web2Code (both tasks) and Qwen3-VL-235B is mediocre on 1D-Bench (59.0). Figma2Code and DesignBench both independently confirm Qwen-VL underperforms Claude/GPT/Gemini on design fidelity specifically, even though it grounds elements well | Cheapest by far for the GUI-grounding specialists (small open models, though hosted metered pricing is largely unverified). Qwen3-VL and GLM-4.6V are verified cheap | Alibaba's own Qwen3-VL-Plus API reports ~2.6s TTFT, specialist-model latency not separately benchmarked in this pass | Not native for any of these, same gateway/direct-API requirement as option 3, and GUI specialists in particular have no standardized hosted API found |

## Recommendations (reference for a possible proposal amendment, not a decision)

1. **Do not treat "no evidence exists" as the reason to keep the status quo any longer.**
   The evidence base changed materially in this revision.
   Retire that framing from any future amendment.

2. **Dimension C (the CSS-fix leg) has the largest single benchmark-backed argument in this whole report for piloting a non-Claude model, but it is not a settled recommendation:**
   MT-Web2Code shows Gemini 3.5 Flash beating an unconfirmed "Claude-4.7-Opus" name on both of its task shapes, one of which (localized modification) is a close structural match to "recenter a div."
   The current Gemini 3.8 Flash was not tested on this or any other task-matched benchmark in this report, so any pilot must run the actual current SKU rather than infer its performance from this 3.5 Flash result.
   1D-Bench, an equally close task shape, shows a split result rather than a clean opposite: Claude Sonnet 4.5 leads the multi-round final composite (80.4 vs. Gemini 3 Pro's 79.5, under a point apart) but Gemini 3 Pro leads single-round (79.6 vs. Claude's 74.0).
   DesignBench and Figma2Code both lean toward 1D-Bench's multi-round ordering.
   Given the evidence favors Claude on balance but by a thinner margin than a clean majority count implies, and one benchmark (MT-Web2Code) favors Gemini's flash tier by a wide margin, this is the leg most worth a real, narrowly-scoped pilot to resolve empirically, not a benchmark-settled case for switching, and not a benchmark-settled case for staying either.

3. **Dimension B (driving/navigation) now has a stronger, more specific recommendation than "keep sonnet":**
   The actual highest-value cheap-tier candidate for pure grounding is not a generalist model at all, it is a GUI-grounding specialist (UI-TARS, GTA1, Holo2, Jedi, UGround), which dominates every grounding benchmark checked by a wide margin over both Claude's and Gemini's generalist tiers, a structural finding that holds regardless of ScreenSpot-Pro's snapshot volatility (see B1).
   But grounding is not the same as autonomous multi-step driving: on OSWorld-MCP, Qwen3-VL (the best-grounding open generalist) still trails Claude Sonnet as a full agent (31.3% vs. 35.3%), and HAL's Online-Mind2Web and TheAgentCompany both show Claude Sonnet leading Gemini's flash tier on full-scaffold task success, just at a much higher cost (roughly 180x on HAL's specific run).
   Note that HAL's and TheAgentCompany's dollar-cost figures reflect those evals' own run-time pricing (Gemini 2.0 Flash, Claude Sonnet 4 / Claude-3.7 Sonnet), an older, now-superseded pricing tier for both providers, not the current prices in the Cost section below.
   The cost ratio is likely still directionally similar, but the absolute dollar figures are stale.
   None of the GUI-grounding specialists were part of the accepted proposal's option space.
   Adding one as a grounding *helper* alongside a generalist driver, rather than as a drop-in autonomous driver replacement, is the shape this evidence actually supports, and is a bigger architectural change than a model swap (most ship as open weights without standardized hosted APIs), so this is flagged as a research item, not a drop-in recommendation.

4. **Dimension A (the general verdict/judgment leg) has a real task-matched benchmark now (DiffSpot), and its headline finding is that the whole capability is low-ceiling for every tier:**
   No model of ten tested catches even half of true visual defects, and hard-tier recall stays below 23% universally, so no cheap model is a safe upgrade on raw capability.
   Claude Opus's advantage on DiffSpot is precision, tied for best among models with non-trivial recall at 99.6% no-diff (two higher-scoring models are degenerate near-zero-recall detectors), not recall, meaning it is among the least likely to send a fix loop chasing a hallucinated defect, which matters more for an automated loop than raw catch-rate.
   MMMU-Pro, the general-reasoning proxy, favors Gemini's flash tier among tracked models, but DiffSpot is the more direct evidence and it does not support downgrading the verdict leg to any flash-tier model, Claude or otherwise.
   An informal reliability check (mllm-ui-judge) additionally found even Sonnet-tier single-pass judging to be run-to-run unstable, reinforcing DiffSpot's caution and arguing for an ensemble-looker or Opus-tier judge over any single cheap-tier call.
   This remains the leg where Claude Opus's harness-native, zero-integration-cost position is hardest to displace on current evidence.

5. **The harness-integration barrier (Report's decisive section, unchanged) still gates all of this.**
   Every option 3 or 4 candidate requires the same non-native integration path described below: a session-wide gateway or a direct API call from the delegate's own tool code.
   That cost does not disappear because the benchmark evidence improved.
   It is now a cost worth paying for dimension C specifically, on current evidence, more clearly than it was when the first pass found no evidence at all.

6. **Correct any prior citation of "Claude Opus 4.8 at 87.9%, GPT-6 Astra at 92.7%" on ScreenSpot-Pro.**
   This revision could not corroborate those figures against the primary, actively-maintained leaderboard, which contains neither model name.
   Cite the primary leaderboard ([gui-agent.github.io/grounding-leaderboard](https://gui-agent.github.io/grounding-leaderboard/)) as the source of record going forward, but do not treat this report's own specific ScreenSpot-Pro rows (Claude Computer Use 17.1%, Holo2-235B-A22B 70.6%, and the rest of the table above) as durable either.
   An independent re-fetch of the same JSON one day later already returned a fully different model roster, so those specific numbers are an expired snapshot, not a citable fact, and any future use should re-pull the leaderboard live rather than reuse the table above.

7. **If a pilot ships, scope it to dimension C first** (the strongest evidence), gate it behind the same fallback discipline the first pass already recommended (env-var override, explicit key management, silent-fallback-never on failure), and treat dimensions A and B as follow-on spikes rather than bundling all three into one amendment.

## Harness Integration Reality (decisive section, unchanged from the first pass, re-affirmed)

This section's substance is unchanged.
It is reproduced here because it still gates every recommendation above.

1. **Claude Sonnet/Haiku/Opus as a CC subagent (`model:` frontmatter field).** Native, zero additional infrastructure. Primary-verified: the `model:` field's documented values (`sonnet`/`opus`/`haiku`/`fable`/full Claude model ID/`inherit`) all resolve to Claude weights, per [the Claude Code sub-agents documentation](https://code.claude.com/docs/en/sub-agents).
2. **A non-Claude model via a session-wide gateway** (LiteLLM, OpenRouter, Portkey, etc.). Technically possible but load-bearing on the entire session's `ANTHROPIC_BASE_URL`, not scoped to one subagent. Not verified as an off-the-shelf per-model-ID routing capability.
3. **A direct API call from inside the delegate's own tool code.** The lightest-weight path that works today. The delegate already has `Bash`/`Read`/`Write` tools. Nothing prevents a skill or script from shelling out to a Gemini, Qwen, or GLM API call with a user-supplied key, entirely independent of the CC session's own model.
4. **Via a browser-automation tool's own BYO-key path** (browser-use, Stagehand). Only relevant if the driving tool itself changes, a bigger architecture change than a model swap.
5. **A2A / separate process.** Report A's existing analysis stands. A single per-screenshot or per-fix judgment call is much lighter-weight than what A2A is designed for.

Path 3 remains the lightest-weight, most concretely actionable mechanism for any option-3 or option-4 pilot, exactly as the first pass found.

## Open Questions a Proposal Amendment Must Resolve

- MT-Web2Code and 1D-Bench disagree on dimension C's headline direction. Is it worth commissioning a small in-house probe (a handful of real "recenter a div"-shaped tasks, scored the way this proposal actually cares about) rather than trying to resolve the disagreement from more literature?
- Is a GUI-grounding specialist model (UI-TARS, GTA1, Holo2, Jedi, UGround) worth a standalone research spike as a grounding *helper* for the driving leg (not a drop-in autonomous-driver replacement, since Qwen3-VL itself still trails Claude Sonnet on OSWorld-MCP's full-agent task), given how decisively specialists outperform every generalist tier on pure grounding? Most ship open-weight without a standardized metered API. What would self-hosting or a third-party hosting arrangement cost and add operationally?
- Who owns re-verifying the primary ScreenSpot-Pro leaderboard on an ongoing basis, given the leaderboard churns fast enough that an independent re-fetch of the same JSON one day after this report's research pass already returned a fully different model roster than the one tabulated above? This is confirmed stale, not hypothetical, and any future citation of this leaderboard should re-pull live rather than reuse this report's table.
- Does `plugins/cdocs/rules/model-tiering.md` need a "provider" axis now, given this report found genuine, primary-sourced quality wins for a non-Claude model on at least one task-matched benchmark (MT-Web2Code), even though a comparably-matched benchmark (1D-Bench) shows a split result that leans the other way?
- What is the actual cost and latency of self-hosting or third-party-hosting a GUI-grounding specialist model, since none of the strongest dimension-B grounding performers have verified hosted pricing in this report?
- No benchmark checked isolates "a cheap model used specifically as the fidelity judge against a design reference" as its own task. DiffSpot is the closest proxy but was not run against any current Claude Sonnet, Claude Haiku, or Opus 5. Is a small in-house DiffSpot-style probe against the tiers this proposal would actually use worth commissioning to close this gap directly?
- Alibaba's vision-language flagship is migrating from dedicated `Qwen3-VL` checkpoints toward a natively-multimodal `Qwen3.8` mainline. If a Qwen-based option is ever piloted, which generation should it target, given third-party benchmarks in this report almost entirely test the older, still-live `Qwen3-VL` line?

## Prior Art in This Corpus

- [Delegation architectures report](2026-09-17-browser-delegation-approaches.md): the "who holds the loop" thesis this report's harness-integration section extends, and the A2A-deferral reasoning it reuses.
- [Isolation and parallelization report](2026-09-17-browser-isolation-parallelization.md): not directly load-bearing here, cited for completeness of the arc.
- [`cdocs/proposals/2026-09-17-browser-delegation-plugin.md`](../proposals/2026-09-17-browser-delegation-plugin.md): the accepted proposal this report may amend. Its sonnet-tier default (D2) and verdict-handoff design (D6) are the baseline this report evaluates against.
- `plugins/cdocs/rules/model-tiering.md`: the Claude-centric tiering shape this report finds may need a provider axis, not just a tier axis, given the dimension-C finding above.

## Verification Notes

**Primary, fetched directly in this revision:**
- Google's Gemini API changelog and pricing pages (`ai.google.dev`), and Google's Gemini 2.5 report for MMMU/MMMU-Pro figures.
- Mistral's model-overview docs confirming Pixtral's retirement (`docs.mistral.ai`).
- Z.ai's pricing page confirming GLM-4.6V is current (`docs.z.ai`), plus GLM-V's own GitHub comparison tables.
- Alibaba Cloud Model Studio's DashScope pricing page for Qwen3-VL, Qwen's own HF cards and GitHub for Qwen3-VL and Qwen2.5-VL benchmark tables, and a direct fetch of `huggingface.co/Qwen/Qwen3.8-27B` confirming the natively-multimodal Qwen3.8 successor generation.
- Groq's own vision documentation confirming the Llama-vision integration trap (`console.groq.com/docs/vision`).
- Ai2's Molmo 2 announcement (`allenai.org/blog/molmo2`).
- The official, actively-maintained ScreenSpot-Pro/v2 leaderboard and its raw GitHub JSON (`gui-agent.github.io`, `raw.githubusercontent.com/GUI-Agent/grounding-leaderboard`), independently re-fetched and cross-validated exactly against a second pull.
- The original ScreenSpot/SeeClick paper ([arXiv:2401.10935](https://arxiv.org/abs/2401.10935)), the UI-Vision paper ([arXiv:2503.15661](https://arxiv.org/abs/2503.15661)), and the OSWorld-G paper and project page ([arXiv:2505.13227](https://arxiv.org/abs/2505.13227), `osworld-grounding.github.io`).
- OSWorld-MCP ([arXiv:2510.24563](https://arxiv.org/abs/2510.24563)) and the ServiceNow BrowserGym leaderboard's raw JSON (`huggingface.co/spaces/ServiceNow/browsergym-leaderboard`).
- TheAgentCompany ([arXiv:2412.14161](https://arxiv.org/abs/2412.14161)), the GUI-World and GUICourse papers, and the WebArena, VisualWebArena, Mind2Web, SeeAct, WebVoyager, and AndroidWorld original papers.
- The official Online-Mind2Web HuggingFace Space CSV, and HAL's general infrastructure paper ([arXiv:2510.11977](https://arxiv.org/abs/2510.11977)) plus its own leaderboard site for the per-model Online-Mind2Web figures.
- XLang Lab's OSWorld-Verified blog snapshot, and the official WebBench leaderboard (`webbench.ai`).
- MMStar's, BLINK's, and CharXiv's official leaderboard pages.
- DiffSpot ([arXiv:2605.29615](https://arxiv.org/abs/2605.29615)), 1D-Bench ([arXiv:2602.18548](https://arxiv.org/abs/2602.18548)), and Figma2Code ([arXiv:2604.13648](https://arxiv.org/abs/2604.13648)).
- The Design2Code, Vision2Web, DesignBench, and MT-Web2Code papers on arXiv, all fetched via their HTML rendering directly.

Seven of the report's more exotic arXiv IDs (DiffSpot, 1D-Bench, HAL, OSWorld-MCP, DesignBench, UI-Vision, and the Qwen3-VL technical report) were independently spot-checked for authenticity by a separate verification pass that fetched each paper's own `arxiv.org/abs/...` page directly.
All seven matched their described content, with two minor citation-precision notes rather than any fabrication finding: HAL's abstract does not itself name "Online-Mind2Web," and UI-Vision's abstract alone does not confirm the specific Claude/Gemini row numbers, which come from the paper's full tables.

**Secondary/aggregator, flagged inline throughout and not treated as sole evidence for any headline claim:**
- llm-stats.com's MMMU, MMMU-Pro, and OSWorld-Verified tables.
- benchlm.ai's "AA-MMMU-Pro" re-run, flagged for containing unverifiable model names.
- Artificial Analysis latency/throughput figures for Qwen3-VL and Gemini Flash.
- steel.dev's mirrors of the WebVoyager and OSWorld leaderboards.
- A benchmarklist.com mirror of AndroidWorld's official Google Sheet, used because the live Sheet itself could not be rendered.
- vellum.ai's independently-tracked Claude Sonnet 4.6 OSWorld-Verified figure, used to cross-check and flag Qwen3.8's self-reported "Opus 4.6 Max" comparison number as unreliable.
- `github.com/CAPTH69/mllm-ui-judge`, explicitly self-described as an informal, non-peer-reviewed project, cited only as a directional reliability caveat, not as benchmark evidence.

**Explicitly retracted from the first pass:**
The claim that ScreenSpot-Pro shows "Claude Opus 4.8 at 87.9%, GPT-6 Astra at 92.7%, Gemini 3.1 Pro at 84.4%, Gemini 3 Pro at 72.7%."
This revision's direct fetch of the primary, actively-maintained leaderboard, independently re-confirmed twice, contains none of these model names or scores.
Note, though, that the correcting snapshot has itself since expired: a re-fetch of the same JSON one day later returned a fully different model roster, so this report's own specific ScreenSpot-Pro rows are no more durable than the claim they retracted.
Only the structural specialist-dominance finding is durable.
See "A Correction" under Dimension B1.

**Known gaps, stated rather than papered over:**
- The corrected ScreenSpot-Pro snapshot cited under Dimension B1 has itself already expired: a same-JSON re-fetch one day later returned a fully different model roster, so only the cross-benchmark structural finding (specialists dominate generalists) should be treated as durable, not any specific row.
- VisualWebBench's primary page embeds its detailed table as an image and is confirmed genuinely stale by two independent passes, the one benchmark in this report where that is true.
- InternVL3.5's and Molmo 2's only confirmed hosted endpoint (Fireworks AI) has unconfirmed image-input behavior and no extractable per-token pricing.
- No GUI-grounding specialist model (UI-TARS, GTA1, Holo2, UGround, Jedi) has verified standardized hosted pricing despite being the strongest performers found on dimension B1.
- No DiffSpot or comparably task-matched dimension-A benchmark has been run against any current Claude Sonnet, Claude Haiku, or Opus 5.
- Dimension C's two closest-matched benchmarks (MT-Web2Code, 1D-Bench) disagree on direction, and this report could not resolve which one better predicts the proposal's actual workload from literature alone.
