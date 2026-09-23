---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-23T11:15:00-07:00
task_list: meta/token-spend-attribution
type: devlog
state: live
status: wip
tags: [meta, tooling, cost, context-management, landscape, rtk]
---

# Bash Output Tooling Landscape Research: Devlog

## Objective

Produce a `/cdocs:report` surveying existing/related tooling for the problem [`cdocs/proposals/2026-09-22-haiku-bash-wrapper.md`](../proposals/2026-09-22-haiku-bash-wrapper.md) solves: keeping verbose command output out of an LLM agent's main context by running the command elsewhere and returning only a salient extract.
Maintainer-specified starting point: investigate `https://github.com/rtk-ai/rtk` directly, then broaden the search.
Report-authoring only, per instructions: no edits to the proposal itself (a separate agent is revising it in parallel for the round-1 review's empirical corrections).
Feeds the round-2 reviewer, not the reviser.

## Plan

1. Read the proposal, the writing-conventions rule, the predecessor landscape report, the nit-fix agent template, and the round-1 review in full to understand the exact design being evaluated and what round 1 already found (especially: the observed whale command shapes are `grep`/`find`/`git diff`/multi-`cat` sweeps, not npm/docker/terraform).
2. Investigate `rtk-ai/rtk` directly: WebFetch the repo README (twice, targeted follow-ups) plus `gh api` for verified, non-hallucinatable metadata (stars, forks, license, contributors, push recency, release cadence).
3. Broaden via WebSearch for the general category ("CLI tool wrap/truncate/summarize command output for AI agents," "MCP server bash output summarization"), then verify each hit found via `gh api` rather than trusting search-summary prose.
4. Resolve the actual question: does anything found let cdocs skip building `cdocs:bash-runner`, does anything change the deferred-mechanism-3 calculus, and what's the concrete integration cost if any adoption is recommended.
5. Write the report via `/cdocs:report`, with an explicit recommendation section addressed to the round-2 reviewer.
6. Write this devlog and commit both with conventional-commit messages.

## Testing Approach

Research task, not a code change: "testing" here means verifying claims rather than trusting single sources.
Every quantitative claim about an external repo (stars, license, last-push date, contributor count) was cross-checked against `gh api repos/<owner>/<repo>` rather than taken from a WebFetch summary alone, after the first WebFetch pass returned an unverifiable "core team of five contributors" claim that `gh api repos/rtk-ai/rtk/contributors` did not corroborate (actual: 30 contributors, top four hold the overwhelming majority of commits) - that discrepancy is why the report cites `gh api`-sourced numbers only and drops the unverified "five contributors" claim entirely.

## Implementation Notes

**rtk-ai/rtk verified facts** (via `gh api repos/rtk-ai/rtk` and two WebFetch passes on the README): Apache-2.0, created 2026-01-22, 81,558 stars, 5,159 forks, pushed 2026-09-21, pre-1.0 (`dev-0.50.0-rc.451`), 30 contributors, 1,574 open issues, CLI-only (no MCP/library mode), purely deterministic (no LLM call), 100+ known-command filters including `grep`/`rg`/`find`/`git diff`/`cat` - which overlaps directly with round-1 review's observed corpus whales. Unknown commands pass through raw + tracked; the one generic fallback (`rtk summary`) is an undocumented heuristic, not caller-steerable.

**Landscape survey**, each entry verified via `gh api` for stars/license/language/push-date rather than trusted from search snippets: deterministic-compressor category (rtk, headroom, token-saver, tokf, condense - rtk dominant by adoption at 81.5k stars vs. the next specialist's 153); LLM-semantic-summarization category (daz-command-mcp, mcp-summarization-functions - both small, stale, one unlicensed, one separately flagged risky by a third-party scanner per a WebSearch hit not independently re-verified).

**Core conclusion.** The landscape splits cleanly along the same axis as the proposal's own mechanism 1 (semantic, caller-steerable, Bash-only dispatched agent) vs. mechanism 2/3 (deterministic, zero-LLM, blind-or-pattern-matched) split. rtk and its competitors occupy mechanism 2/3's territory and do it better than a bespoke allowlist would (mechanism-3 territory specifically), but structurally cannot do mechanism 1's job: no caller-steerable salience spec, no coverage for unanticipated/unfamiliar commands beyond raw passthrough, no semantic comprehension. The one architecturally similar prior art to `cdocs:bash-runner` itself (`daz-command-mcp`) is unmaintained and unlicensed, meaning nothing adoptable exists in that niche.

**Recommendation formed:** build-is-still-right for mechanism 1 (no revision needed); no change to mechanism 2; non-blocking optional suggestion to cite rtk in mechanism 3's Background as evidentiary support for staying deferred (not as a reason to un-defer or to adopt rtk as a dependency). Explicitly recommend against making rtk a plugin dependency: same reasoning the proposal already uses to justify keeping `bashOutputMaxChars` as `/cdocs:init` guidance rather than plugin-baked (a plugin cannot install, version-pin, or vet a third-party compiled binary on the consumer's behalf), plus a supply-chain concern specific to running third-party binary code inside an agent's Bash tool that the plugin doesn't currently take on anywhere else.

## Changes Made

| File | Description |
|------|-------------|
| `cdocs/reports/2026-09-23-bash-output-tooling-landscape.md` | New report: rtk-ai/rtk deep dive + broader landscape survey, verdict and recommendation for the round-2 reviewer |
| `cdocs/devlogs/2026-09-23-bash-tooling-landscape-research.md` | This devlog |

## Verification

- All external repo metadata cited in the report (stars, forks, license, contributor count, push/creation dates) is sourced from `gh api repos/<owner>/<repo>` calls run directly in this session, not from WebFetch/WebSearch summary prose alone; WebFetch was used only for qualitative README content (feature descriptions, command coverage, hook mechanism) and cross-checked against the `gh api` numbers where they overlapped (e.g. the WebFetch-reported "5 contributors" claim was checked against and superseded by `gh api`'s 30).
- No proposal file was edited; confirmed by not touching `cdocs/proposals/2026-09-22-haiku-bash-wrapper.md` at any point in this session.
- Report frontmatter matches the requested spec: `task_list: meta/token-spend-attribution`, `type: report`, `state: live`, `status: review_ready`.
