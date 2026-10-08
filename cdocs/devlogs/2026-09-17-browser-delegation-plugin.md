---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-17T00:00:00-07:00
task_list: cdocs/browser-delegation
type: devlog
state: live
status: wip
tags: [research, browser, delegation, mcp, a2a, visual_review, isolation, plugin]
---

# Devlog: browser-delegation plugin (reports + propose-revise)

> BLUF: New clauthier plugin to let high-judgment models (opus, fable) delegate browser work, UI verification, and minor tweaks to a cheaper/specialized delegate agent/harness/process (MCP or A2A), plus streamlined skills/MCPs to reduce friction vs the raw playwright MCP used in weftwise. Two Sonnet `/report`s first (delegation approaches; isolation/parallelization sidecar), then `/propose-revise` the plugin.

## Scratchpoint

- next_steps: re-review loop on the proposal (see "Re-review loop"); r3 = proposer revision addressing all r2 items, then fresh opus reviewer rounds to `proposal_accepted`.
- important_files: `cdocs/proposals/2026-09-17-browser-delegation-plugin.md`, `cdocs/reviews/2026-10-07-review-of-browser-delegation-plugin-r2.md`
- callouts:
  - decision: maintainer defaults applied to r2 choices: drop R1-R6 claims (plain reviewer + iterate `review_proof`); bash-runner shape, no `drive` skill or plugin rules files; v1 Claude Code-only, no OpenCode dependency; driving stays Claude/sonnet, pluggable model left open; one delegate drives N named sessions by default.
  - todo: original proposal `status: accepted` is invalid; set `implementation_ready` on re-accept.

## Plan / arc

1. **Report A — delegation approaches** (Sonnet): architectures for delegating browser/UI work off the lead model (subagent, MCP, A2A, separate harness), and streamlined skills/MCPs vs the current playwright MCP. Builds on the 2026-08 visual-verification prior art.
2. **Report B — isolation & parallelization sidecar** (Sonnet): affordances so multiple browser instances/contexts can run concurrently, unblocking sync/collab testing and letting the delegate agent be parallelized.
3. **`/propose-revise`** (overseer): design the plugin, informed by both reports.

## Context / ground truth

- weftwise browser stack: single playwright MCP server via `scripts/playwright-mcp-launch.sh`, version-pinned (`@playwright/mcp@0.0.78`) in lockstep with the devcontainer Chromium revision; `.mcp.json` wires one server. Artifacts land in `.playwright-mcp/`. Single-instance pinning is itself a friction/isolation signal.
- weftwise sync stack: loro/bocsync collab — multi-client testing is the stated pain point (report B).
- `.lace/` port + mount assignment machinery exists (worktree isolation) — relevant to per-agent browser isolation.
- Prior art to extend, not re-derive:
  - `cdocs/reports/2026-08-04-visual-review-gaps-and-pixel-grounding-handoff.md`
  - `cdocs/reports/2026-08-05-visual-verification-skills-web-survey.md` (+ its devlog)
  - weftwise `cdocs/reports/2026-07-25-dev-environment-and-test-debt.md`, `cdocs/proposals/2026-07-25-dev-environment-fixes.md`

## Work log

- Dispatched two Sonnet report subagents in parallel; will run `/propose-revise` once both land.
- **Report A landed** → `cdocs/reports/2026-09-17-browser-delegation-approaches.md`. Headline: delegation is compositional; the real axis is "who holds the tool-call loop" — an MCP server alone doesn't move it off the lead. Default to an in-harness sonnet-tier subagent driving the browser (opus/fable never drive directly), reuse the cdocs R1-R6 visual-review discipline verbatim as the verdict layer, treat A2A as documented future escalation. Flags: weftwise's pinned `@playwright/mcp@0.0.78` has regressed 3× in 2026 and is stale (npm current `0.0.81`); Anthropic first-party browser-use tool sidesteps the version-pin failure class; Playwright Planner/Generator/Healer agents (v1.56+) fit "minor tweaking" (search-verified only, needs confirmation). Open Qs carried into proposal.
- **Report B landed** → `cdocs/reports/2026-09-17-browser-isolation-parallelization.md`. Headline: adopt `@playwright/cli` (native named/isolated sessions, works inside subagents which don't inherit MCP tools — a wall weftwise already hit) as the delegate's primary interface over `@playwright/mcp`; for multi-client sync, cheapest correct unit is one script driving N `browser.newContext()`s (weftwise's `e2e/livesharing/helpers.ts` already nearly does this). Findings: Playwright maintainers closed multi-session-per-server with "run multiple servers or use playwright-cli"; `e2e/playwright.config.ts` is `workers:1` due to shared server-side state, not browser cost; `.lace/` assigns ports per-container not per-worktree (per-worktree is `portless`+`worktree.sh` branch routing — the template for a session-naming scheme); existing `pnpm qa`/`PW_CLIENT_ACTION` two-client infra lacks an agent-drivable browser counterpart.
- Both reports in. Started `/cdocs:propose-revise` (overseer = opus; proposer/reviewers = sonnet).

## Propose-revise loop

- **Round 1 proposal** drafted → `cdocs/proposals/2026-09-17-browser-delegation-plugin.md` (committed `d6ee73a`). Positions: new `browser-delegate` sonnet agent (drives/captures only, never judges — verdicts stay with R1–R6/`reviewer`); `@playwright/cli` as default tool (justified by subagent tool-inheritance, version-pin avoidance corroborating; SIGTRAP risk gated behind a Phase-1 spike); session isolation mirrors `portless`/`worktree.sh` branch routing (not `.lace/`); multi-client sync via 2+ named sessions with role→session registry; lean v1 non-goals (no fixer persona, no A2A, no `workers:1` change, no browser-use-as-default). Surface: `agents/browser-delegate.md`, skills `drive`+`sync`, rules `session-isolation.md`+`toolset-selection.md`, no hooks v1.
- Round 1 review dispatched (fresh sonnet `cdocs:reviewer`).
- **Round 1 verdict: ACCEPT** (no blocking issues; review `cdocs/reviews/2026-09-17-review-of-browser-delegation-plugin.md`, committed `b16d361`). Reviewer independently verified the `.lace/` container-feature scoping against the real assignment files and took positions on all five of the proposal's open questions.
- **Accepting-round nits resolved** by resuming the original proposer: carried Report A's round-trip-budget open question into the proposal; reworded Assumptions item 4 + Phase 1 to state exactly what the CLI spike tests (SIGTRAP/channel-pin exposure vs. whether named sessions alone isolate); noted branch-name `/` → CLI-safe session-name transform as a Phase 2 detail; sentence-per-line + em-dash convention fixes; dropped the imprecise `future_work` tag.
- Overseer finalized `status: accepted`. **Loop closed at round 1.**

## Outcome

Proposal `cdocs/proposals/2026-09-17-browser-delegation-plugin.md` accepted round 1. Next step (not started): `/cdocs:implement` (or `/cdocs:full-send` end-to-end) when the maintainer greenlights build — Phase 1 spikes (`@playwright/cli` SIGTRAP/isolation, browser-use GA, Playwright Healer `claude` integration) should run first since later phases gate on them.

## Follow-up (maintainer questions)

- **Stagehand/agent-native tools vs Playwright**: answered from Report A — Stagehand/browser-use are AI-driving *layers on top of* Playwright (CDP), not replacements; they add NL driving at the cost of a second LLM-in-the-loop and less determinism, and neither judges correctness. Maintainer's lean toward Playwright for smoke→validator→test continuity is well-founded and matches the `@playwright/cli` pick. NL drivers stay an optional fuzzy-driving complement, not default.
- **Non-Claude delegate (Gemini flash tier) for the visual leg**: dispatched supplemental sonnet report `cdocs/reports/2026-09-17-delegate-model-comparison.md`. Key framing carried in: CC subagents run Claude only, so a non-Claude delegate can't be a plain in-harness subagent (forces BYO-key browser-use/Stagehand, direct API, or A2A — the deferred path); the visual-verdict leg (not the driving leg) is where a stronger visual model would pay off; report to verify benchmarks (no memory) and recommend keep-sonnet vs pluggable-visual-model vs multi-provider, feeding a possible proposal amendment.
- Round 1 of that report (committed `0718a48`) under-searched (stopped at ScreenSpot-Pro, which lists only flagships) and wrongly concluded no cheap-tier benchmark data exists. Verified good bits retained: Gemini flash-tier current name is Gemini 3.8 Flash (2026-09-02); CC `model:` is Anthropic-locked so non-Claude needs a session gateway or in-tool-code direct API.
- **Deepening pass dispatched** (fresh sonnet, revise-in-place): rigorous multi-benchmark hunt reframed around the maintainer's 4 options (Opus/Opus, Sonnet/Sonnet, current Gemini Flash, open visual-specialists e.g. Qwen-VL) x 3 task dimensions (visual quality judgment, web navigation/usage, CSS/layout correction). Prescriptive benchmark list given (ScreenSpot family, WebArena/VisualWebArena, Mind2Web, MMMU/MMBench/VisualWebBench, Design2Code/Web2Code, etc.) to fix the breadth failure. **Gated behind an opus `/review` on completion** (maintainer's instruction).
- Deepening pass delivered real cross-tier coverage (563 lines) but hit a coordination incident: dispatched `fork` research agents inherited full context, mistook themselves for orchestrator, and clobbered each other's edits; agent reconciled by hand and logged it in `cdocs/devlogs/2026-09-18-delegate-model-benchmark-deepening.md`. Lesson: use fresh non-forked agents for research fan-out. Committed `66d61e1`.
- **Opus review: REVISE, close to accept** (`cdocs/reviews/2026-09-18-review-of-delegate-model-comparison.md`, committed `d09542b`). Opus independently re-fetched high-risk citations (MT-Web2Code, 1D-Bench, DiffSpot, UI-Vision, Design2Code) - all real, no fabrication; cross-tier coverage genuine. Three load-bearing defects were prose-outruns-tables overclaims, not missing evidence: DiffSpot "field's best specificity", 1D-Bench final-vs-raw muddle behind "beats every Gemini tier", and generalizing a Gemini 3.5-Flash win to the untested current 3.8-Flash; plus ScreenSpot-Pro snapshot expired (Opus re-fetch showed full roster churn).
- **Fixes applied** (fresh sonnet reviser, no new research) and **overseer-verified** (opus spot-checked all three corrections present/consistent, old overclaims gone, 0 em-dashes/semicolons, non-spec `last_edited` removed). Finalized: `status: final`, `last_reviewed: accepted` round 2.

## Outcome (model comparison)

Central conclusion (rigorous, honest): **Claude is the safer default across all three legs**, but the on-task CSS-fix (dimension C) result for Gemini flash is too large and too benchmark-contradictory to settle from literature (MT-Web2Code favors 3.5 Flash; 1D-Bench splits by round), and **no benchmark tests the current Gemini 3.8 Flash on a task-matched workload**. Pure GUI-grounding is dominated by specialist models (UI-TARS/GTA1/Holo2), not any generalist tier. Decision-closing move: a small in-house "recenter a div" pilot on current SKUs (Sonnet vs Gemini 3.8 Flash vs a Qwen-VL). Report is the reference input for a possible pluggable-model amendment to the accepted plugin proposal; no amendment drafted yet (awaiting maintainer).

## Follow-on artifacts and reports

- **Animation/video web-testing report** (sonnet) → `cdocs/reports/2026-09-18-animation-video-web-testing.md` (committed `ce7a156`). Good-to-know, infrequent-use survey. Headline: reach for deterministic introspection first (`getAnimations()`/`playState` + `transition*`/`animation*` events); escalate to frame capture (`page.clock`-sampled or interval screenshots) for a specific intermediate state; use VLM/video-model judgment (Gemini native video with `fps` raised above its 1fps default, or ordered labeled stills for Claude/GPT) only for genuinely perceptual questions. Gotchas: `animations:'disabled'` is the opposite of motion testing (guarantees false pass); `mouse.move()` defaults `steps:1` so native `dragover` never fires without ≥2 moves. Gap: no benchmark tests "did this animate correctly"; motion judgment is cdocs' own to own.
- **Model-comparison artifact** (sonnet-prepared, opus-reviewed source, published by overseer): sortable table of 19 non-specialist models (Size/Cost/Speed/Visual-judgment A/Driving B/Coding-perf estimate), per-model detail cards, and a `claude → gemini_subagent_tool` SVG with 7 challenge cards. Source HTML in scratchpad (`model-comparison-artifact.html`); published at https://claude.ai/artifact/8CdrbiWVYHrksbwU88TMD7 . Every figure traced to the accepted model-comparison report; coding-perf column flagged as pure estimate; N/A never fabricated. Maintainer's current lean: Gemini Pro vs Sonnet (opus→sonnet/pro efficiency worth it, not down to flash); binding constraint corrected to recall (Pro surfaces ~41% of visual diffs), not the ~1% precision gap.
- **Artifact v2** (same URL, sonnet-reworked per maintainer): collapsed to 8 current SKUs (Opus 5, Sonnet 5, GPT-5.4, Gemini 3.1 Pro, Gemini 3.8 Flash, Qwen3.5-397B-A17B, GLM-4.6V, Kimi K2.5); deleted Haiku/GPT-4o/Pixtral/InternVL/older Gemini tiers; earlier-version scores carried forward with † (tested version named in card); Recall %/Precision % promoted to sortable columns; all pricing searched+cited (no cost N/A); closed-model size/speed as flagged ordinal estimates. Two flags: † = measured-on-earlier-version, * = estimate.
- **Artifact v3** (same URL): replaced Size with capability-class **Model tier** (Frontier: Opus 5; Balanced: Sonnet 5 / Gemini 3.1 Pro / GPT-5.4 / Qwen / Kimi; Efficient: Flash / GLM) per maintainer (Pro≈Sonnet, Opus above, Flash below); **Speed** → qualitative Instant/Fast/Good/Slow buckets (raw TTFT demoted to sub-note); added a **Medium/High reasoning-effort toggle** recomputing Recall/Precision/A/Driving/Coding + Speed (High=measured anchor; Medium=modeled penalty −10 reasoning-heavy, −6 recall, −3 precision, −5 driving, always flagged; Gemini Flash flips Slow→Fast at Medium since 15.7s is thinking-mode). Motivates the effort-curve question for the delegate: does cheap/low-effort stay good enough.

## Re-review loop (2026-10-07)

A fresh opus staleness assessment found the round-1 (sonnet) acceptance stale: D2's MCP-inheritance premise is contradicted by later subagent evidence, the R1-R6 verdict layer is not in code, the verdict handoff conflicts with `/cdocs:iterate`'s proof rule, and the delegate-writes-devlog design violates one-writer-per-file.
Recorded as review r2; overseer (opus-5-5, subagent of the top-level session) runs `/cdocs:propose-revise` from there.

### Iteration Log

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | notes |
|---|---|---|---|---|---|---|
| 1 | proposer (sonnet) | sonnet cdocs:reviewer | proposal_accepted | n/a | cdocs/reviews/2026-09-17-review-of-browser-delegation-plugin.md | original loop; superseded by r2 staleness |
| 2 | - | opus cdocs:reviewer (staleness, read-only) | revise | n/a | cdocs/reviews/2026-10-07-review-of-browser-delegation-plugin-r2.md | 4 blocking, 3 high, 3 medium, 1 low |

| 3 | proposer r3 (opus, `7d89533`) | fresh opus cdocs:reviewer | revise | n/a | cdocs/reviews/2026-10-07-review-of-browser-delegation-plugin-r3.md | all 11 r2 items resolved; 2 new blocking (reviewer delegate reuses implementer session; `cdocs/_media/` durability conflicts with reviewer.md); 11 non-blocking. Reviser deviations (drop `sync`, one-clause iterate `confirmed` edit) judged sound |

- r3 overseer decision: durable-screenshot question resolved as option A (scratch path + quoted report facts, no `reviewer.md` change) per minimal-design default; maintainer can override.
| 4 | proposer r4 (opus, warm, `ebb6e7a`) | fresh opus cdocs:reviewer | revise | n/a | cdocs/reviews/2026-10-07-review-of-browser-delegation-plugin-r4.md | all 13 r3 items resolved; 2 new blocking in session-state contract (fresh-session rule not delivered via agent description/prompt; `reopened` unobservable across dispatches); 7 non-blocking |

- r4 overseer decision: `reopened` semantics resolved as option A (report only what one dispatch observes; no `resume` prompt field) per minimal-design default.
