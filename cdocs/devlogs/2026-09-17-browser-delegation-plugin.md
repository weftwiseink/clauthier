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
