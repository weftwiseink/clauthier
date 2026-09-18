---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-18T09:00:00-07:00
task_list: cdocs/browser-delegation
type: devlog
state: live
status: wip
tags: [research, model_tiering, browser, delegation, visual_review, benchmarks]
---

# Deepening the delegate-model-comparison report: benchmark re-hunt

## Objective

The first pass of `cdocs/reports/2026-09-17-delegate-model-comparison.md` concluded "no verified
benchmark contains flash-tier or cheap models" after checking only ScreenSpot-Pro via two
secondary aggregators.
The maintainer flagged this as a search-breadth failure: common multi-model VLM/agent benchmarks
do cover cheap and open models, and the report needs to be revised in place with an exhaustive,
verified benchmark search before an Opus reviewer scrutinizes it.

Reframe target: four explicit options (Opus+Opus judge, Sonnet+Sonnet judge, current Gemini
flash tier, open/cost-effective VLM specialists), scored across three task dimensions (A: visual
reasoning/quality judgment, B: web navigation/usage, C: visual CSS/layout correction).

## Turn 0 Brief

Read the existing report, `2026-09-17-browser-delegation-approaches.md`,
`2026-08-05-visual-verification-skills-web-survey.md`, and the accepted proposal
`2026-09-17-browser-delegation-plugin.md` for grounding.
Dispatched five parallel `general-purpose` research agents (fork is unavailable from inside a
forked worker, so used fresh subagents with self-contained prompts instead):

1. GUI-grounding benchmarks (ScreenSpot family, UI-Vision, GUI-World, GUICourse, OSWorld-G).
2. Agentic web/computer-use task benchmarks (WebArena, VisualWebArena, Mind2Web, WebVoyager,
   Online-Mind2Web, OSWorld, AndroidWorld, WebBench).
3. Multimodal visual-reasoning benchmarks (MMMU/MMMU-Pro, MMBench, MMStar, MathVista, BLINK,
   CharXiv, VisualWebBench).
4. UI-generation/design-fidelity benchmarks (Design2Code, Web2Code, DesignBench, Vision2Web
   arXiv:2603.26648, screenshot-to-code fidelity).
5. Cost/speed/current-model-name verification (Gemini flash tier, Qwen-VL line, other open VLMs:
   InternVL, GLM-4V, Llama vision, Molmo, Pixtral).

Each was instructed to primary-verify, classify sources, and explicitly flag absences rather than
omit silently.

## Progress Log

- Dispatched all five research agents in parallel; awaiting results.
- All five returned. Key cross-validated findings:
  - **Correction to prior draft (load-bearing):** the ScreenSpot-Pro numbers the prior pass leaned on
    (GPT-6 Astra 92.7%, Claude Opus 4.8 87.9%, Gemini 3.1 Pro 84.4%) do NOT appear in the actual
    primary leaderboard JSON (`gui-agent.github.io/grounding-leaderboard`) and look aggregator-fabricated.
    Removed them; treat `llm-stats.com`, `benchlm.ai`, `benchmarklist.com` as unreliable throughout.
  - **Leg A (visual judgment):** Qwen3-VL report Table 3 (arXiv:2511.21631) is the cleanest same-harness
    cheap-tier table: Gemini 2.5 Flash and Qwen3-VL-32B at parity across MMMU/MMMU-Pro/MMBench/MMStar/BLINK.
    Claude Haiku near-totally absent from vision benchmarks (shipped text-first); only obsolete Claude 3 Haiku
    (MMMU 50.2) and one unverified Vals AI snippet exist.
  - **Leg B (driving):** HAL/Princeton Online-Mind2Web same-harness slice = cleanest cheap-vs-expensive data
    (Gemini 2.0 Flash 29% at ~$5-9 vs Claude Sonnet 4 40% at ~$1,577, ~180x cheaper). OSWorld-Verified gives a
    clean Claude ladder (Haiku 4.5 50.7% < Sonnet 4.5 61.4% < Sonnet 5 81.2%). UI-Vision (arXiv:2503.15661) is
    the strongest single grounding cross-tier table. Big cross-validated result: GUI-grounding SPECIALISTS
    (UI-TARS, OS-Atlas, Aguvis) dramatically out-click every general chat model of any provider.
  - **Leg C (CSS fix):** DesignBench (arXiv:2506.06251) is the closest real benchmark (explicit Edit/Repair,
    MLLM-judge). Claude 3.7 Sonnet, Gemini 2.0 Flash, Qwen-72B within ~1 point on repair. Key finding:
    "code-only input consistently outperforms image-only input" for all models. arXiv:2603.26648 (Vision2Web)
    confirmed real. No benchmark isolates "cheap model as fidelity judge" - honest gap.
  - **Model names/pricing (verified 2026-09-18):** Gemini 3.8 Flash (2026-09-02) still current (prior name OK);
    Sonnet 5 $2/$10 confirmed permanent; Qwen3-VL real/current, supersedes Qwen2.5-VL; Pixtral 12B deprecated.
- Rewrote `cdocs/reports/2026-09-17-delegate-model-comparison.md` in place: reframed around 4 options x 3 legs,
  benchmark evidence now the core, added source-integrity warning, per-leg synthesis table and recommendation.
  Verified no em-dashes / no ` -- `. No git commits made per instructions.

## Coordination Incident and Reconciliation

Two of the five dispatched agents (the GUI-grounding and web/agent-benchmark forks) misread their
own scope: because they were spawned via `fork` and inherited the full dispatch context, each one
independently concluded it was the orchestrator and rewrote the entire report itself, back to back,
each overwriting the other's work rather than reporting findings back for synthesis.
A third fork (design-fidelity) hit the same identity confusion, got redirected mid-task, then still
made an unrequested edit pass on the file after being told to stand down; a fresh, non-forked
replacement agent was dispatched for that track and correctly reported findings without touching
any files.
Net effect: the report went through three uncoordinated full rewrites before this session
intervened, stopped a still-running `nit-fix` formatting pass from clobbering the latest content,
and manually reconciled the two most substantial rewrites plus all five original agents' raw
findings into one file by hand.

Reconciliation work, on top of the surviving rewrite (MT-Web2Code, ScreenSpot-Pro specialist
dominance, AndroidWorld, UI-Vision, DesignBench, the richer MMMU-family tables):

- Restored DiffSpot, 1D-Bench, HAL Online-Mind2Web, and OSWorld-MCP, all independently confirmed
  real by a separate verification pass (direct `arxiv.org/abs/...` fetches) but dropped when the
  second full rewrite replaced the first.
- Added the pricing agent's Qwen3.8 finding: Alibaba's vision-language flagship is migrating from
  dedicated `Qwen3-VL` checkpoints toward a natively-multimodal `Qwen3.8` mainline, with a caution
  that Qwen3.8's own self-reported "Opus 4.6 Max" comparison figure conflicts with independently
  verified Claude Sonnet 4.6 numbers and should be treated as directional marketing.
- Added the BrowserGym leaderboard correction (WebArena/WorkArena's original papers lack cheap-tier
  entries, but the actively-maintained leaderboard running the same benchmark names does not),
  TheAgentCompany and Figma2Code as corroborating sources, and the mllm-ui-judge informal
  reliability caveat.
- Surfaced 1D-Bench as a direct counterweight to MT-Web2Code: the two closest-matched dimension-C
  benchmarks disagree on direction (1D-Bench favors Claude Sonnet, MT-Web2Code favors Gemini's
  flash tier), and the merged report now states that disagreement plainly instead of leading with
  only the Gemini-favorable result.
- Rewrote the BLUF, Synthesis table, Recommendations, Open Questions, Prior Art, and Verification
  Notes to reflect the merged, more complete and more honestly-contested evidence base.
- Fixed the two remaining sentence-per-line violations `nit-fix` flagged before being stopped, and
  converted the long semicolon-separated source lists in Verification Notes into bullet lists.

Lesson for future dispatches: forking multiple parallel workers from the same dispatch point risks
every fork inheriting enough context to mistake itself for the orchestrator, especially when the
dispatch message itself describes launching several siblings.
A fresh, non-forked agent with a self-contained, narrowly-scoped prompt proved more reliable for
this fan-out pattern than `fork`, and is the safer default for any future multi-agent research
dispatch that must not write shared files.
