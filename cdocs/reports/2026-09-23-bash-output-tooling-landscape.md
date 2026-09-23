---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-23T11:15:00-07:00
task_list: meta/token-spend-attribution
type: report
state: live
status: review_ready
tags: [meta, tooling, cost, context-management, landscape, rtk, mcp]
---

# Bash Output Tooling Landscape: Does Anything Replace `cdocs:bash-runner`?

> BLUF(sonnet/bash-tooling-landscape): **Adopt-alongside for the deterministic-floor territory, build-is-still-right for the semantic core.**
> `rtk-ai/rtk` is real, large (81.5k stars, Apache 2.0, actively maintained), and directly relevant: a Rust CLI proxy that deterministically compresses 100+ known dev commands (including `git diff`, `grep`, `find`, `cat` sweeps, the same command shapes the round-1 review found dominate this repo's corpus) via a Claude Code `PreToolUse` hook, zero LLM cost.
> It is an alternative implementation of the proposal's already-deferred mechanism 3 (`PreToolUse` advisory/rewrite), not of mechanism 1 (`cdocs:bash-runner`): rtk is purely rule-based per known command type, has no caller-steerable salience spec, and passes unknown commands through unfiltered - it cannot do the "read the whole unfamiliar log once, return the buried needle per this caller's spec" job the haiku wrapper exists for.
> The broader landscape (token-saver, condense, tokf, headroom - all deterministic/heuristic compressors; daz-command-mcp, mcp-summarization-functions - small, stale, LLM-summarization MCP servers) confirms this split: the "known-command deterministic compression" niche is crowded and mature, the "general-purpose LLM-semantic-distillation-as-a-dispatched-subagent" niche that `cdocs:bash-runner` fills has no mature off-the-shelf competitor.
> **Recommendation: do not change mechanism 1's design; do not adopt rtk as a plugin dependency; optionally cite rtk in mechanism 3's Background as the reason it is fine to stay deferred rather than build a bespoke allowlist.**

## Context / Background

The maintainer asked for this report before round-2 review of [`cdocs/proposals/2026-09-22-haiku-bash-wrapper.md`](../proposals/2026-09-22-haiku-bash-wrapper.md), specifically naming `https://github.com/rtk-ai/rtk` as a lead to chase down, per the propose-revise devlog: "dispatch a sonnet `/cdocs:report` on related/existing tooling... to inform whether the round-2 reviewer should consider adopting/wrapping an existing tool instead of (or alongside) the bespoke `cdocs:bash-runner` build - 'or maybe even more'" ([`cdocs/devlogs/2026-09-22-haiku-bash-wrapper-propose.md`](../devlogs/2026-09-22-haiku-bash-wrapper-propose.md), Round 1 review verdict section).

The proposal being evaluated ships three mechanisms: (1) `cdocs:bash-runner`, a haiku-tier dispatched agent that runs one command, reads the full output in its own disposable context, and returns a fixed-format salient extract; (2) a tightened `bashOutputMaxChars` settings floor (always-on, zero LLM cost, blind); (3) an optional/deferred `PreToolUse` advisory nudge on a hand-picked allowlist of known-verbose command patterns. Round 1 review ([`cdocs/reviews/2026-09-23-review-of-haiku-bash-wrapper.md`](../reviews/2026-09-23-review-of-haiku-bash-wrapper.md)) already found mechanism 3's original allowlist target (`npm install`/`docker build`/`terraform`) misses the corpus's actual observed whales, which are `git diff`, `grep -rn` sweeps, `find`, and multi-file `cat` loops, and recommended keeping mechanism 3 deferred as redundant with 1+2 and mis-targeted. This report's task is to check whether an existing tool changes that calculus - either by making mechanism 3 worth un-deferring (because a maintained tool already does it right), or by making mechanism 1 unnecessary (because a maintained tool already does semantic distillation), or neither.

This report is upstream of round 2 review, not of the round-2 revision: it does not touch the proposal file. The revision (correctness fixes from round 1: B1-B3) proceeds in parallel regardless of what this report finds.

## Key Findings

### `rtk-ai/rtk`: what it actually is

Verified directly via `gh api` (not just README prose, to avoid citing an unverifiable star count) and two WebFetch passes over the README:

- **What it is.** "CLI proxy that reduces LLM token consumption by 60-90% on common dev commands. Single Rust binary, zero dependencies." A Claude Code (and 17 other AI-tool) `PreToolUse`-hook-based command rewriter: `git status` becomes `rtk git status` transparently, and `rtk`'s own subcommand applies a command-type-specific filter/group/truncate/dedup pipeline before the (already-run) output reaches the model.
- **Coverage.** 100+ commands across git (porcelain and plumbing, including `git diff`, `git log`), file/search tools (`ls`, `tree`, `cat`, `grep`, `rg`, `find`, `diff`), test runners (cargo, pytest, Jest, Vitest, Playwright, Go test, RSpec, phpt, plus a generic wrapper), build/lint (ESLint, Biome, tsc, Cargo, Clippy, ruff, golangci-lint, rubocop, Maven, SBT), package managers (npm/pnpm, pip, uv, bun, deno, bundle, prisma), infra/containers (Docker, kubectl, OpenShift, Pulumi, AWS, Azure), and utilities (curl, wget, log dedup, JSON structure analysis). Notably, this list includes `grep`/`rg`/`find`/`git diff`/`cat` - the exact command shapes round-1 review identified as this repo's actual top-15 whales, which the proposal's original mechanism-3 allowlist (npm/docker/terraform) missed.
- **Fallback for unmapped commands.** `rtk proxy <cmd>` gives raw passthrough plus usage tracking (i.e., commands outside the 100+ list are NOT filtered). Two generic modes exist for the general case: `rtk err <cmd>` (errors-only filter, any command) and `rtk summary <cmd>` ("heuristic summary," internal mechanism undocumented in the README).
- **Mechanism: purely deterministic, no LLM.** "Single Rust binary," "<10ms overhead," token estimation is "bytes / 4, no tokenizer." Confirmed: no model call anywhere in the compression path. This is the central architectural fact distinguishing it from `cdocs:bash-runner`.
- **Integration surface.** CLI-only. No MCP server mode, no library/API for programmatic embedding - the README's architecture section only documents hook-based rewriting (`rtk init -g` installs `rtk hook claude`, prefix-matching known command patterns) and explicit `rtk <subcommand>` invocation. A caveat in the README: Claude Code's built-in `Read`/`Grep`/`Glob` tools do not pass through the Bash hook and are not auto-rewritten - the mechanism is Bash-specific, matching this proposal's own scope.
- **License and maturity, verified via `gh api repos/rtk-ai/rtk`:** Apache License 2.0. Created 2026-01-22 (about 8 months old). 81,558 stars, 5,159 forks, 1,574 open issues, 30 contributors (top four: 629/340/218/179 commits respectively - a small core team, not a broad community-maintained project despite the star count). `pushed_at: 2026-09-21` (2 days before this report, actively maintained). Releases are still pre-1.0 and RC-heavy: latest tag `dev-0.50.0-rc.451`, i.e. 451 release candidates on a 0.x version as of this week - a real signal of both intense iteration and API/behavior instability risk for anything depending on it.

### The broader landscape: rtk is not alone in its niche

WebSearch for "CLI tool wrap command output truncate summarize AI agent" and "MCP server bash output summarization" surfaced a small ecosystem, split cleanly along the same axis as the proposal's own mechanism 1 vs. mechanism 2/3 split:

**Deterministic/rule-based compressors (rtk's direct competitors), verified via `gh api`:**

| Tool | Stars | License | Language | Last push | Notes |
|---|---:|---|---|---|---|
| [rtk-ai/rtk](https://github.com/rtk-ai/rtk) | 81,558 | Apache-2.0 | Rust | 2026-09-21 | Dominant by adoption; 100+ command filters |
| [headroomlabs-ai/headroom](https://github.com/headroomlabs-ai/headroom) | 73,623 | Apache-2.0 | Python | 2026-09-23 | Broader scope: logs/files/RAG chunks/JSON, not just Bash; library+proxy+MCP-server modes; uses a trained HF compression model (`Kompress-v2-base`) for code, so has a model-weight footprint rtk does not; claims only ~20% reduction for coding-agent tool output specifically (vs. rtk's 60-90%), consistent with being a generalist tool rather than a Bash-output specialist |
| [ppgranger/token-saver](https://github.com/ppgranger/token-saver) | 153 | Apache-2.0 | Python | 2026-09-19 | 36 processors, same command-family coverage as rtk (git/pytest/npm/terraform/kubectl/docker) |
| [mpecan/tokf](https://github.com/mpecan/tokf) | 199 | MIT | Rust | 2026-09-23 | Config-driven (TOML filter rules, no recompilation) - the only one of these built for user-extensibility rather than a maintainer-curated command list |
| [AryanKatwal06/condense](https://github.com/AryanKatwal06/condense) | 2 | Apache-2.0 | Java | 2026-09-22 | Same pitch as rtk, essentially unadopted |

**LLM-semantic-summarization tools (architecturally closest to `cdocs:bash-runner`), verified via `gh api`:**

| Tool | Stars | License | Last push | Notes |
|---|---:|---|---|---|
| [darrenoakey/daz-command-mcp](https://github.com/darrenoakey/daz-command-mcp) | 5 | none declared | 2026-03-26 | MCP server, session-based command execution with LLM-powered summarization - closest architectural match to the proposal's Workflow, but no license and 6 months stale as of this report |
| [Braffolk/mcp-summarization-functions](https://github.com/Braffolk/mcp-summarization-functions) | 37 | MIT | 2025-06-15 | General action-output summarization MCP server, 15 months stale; a WebSearch hit separately surfaced a third-party supply-chain risk score of "35/100 (Risky)" from agentseal.org for this server, which this report did not independently verify but flags as a reason not to recommend it even as a citation |

Two observations from this table shape the recommendation:
1. **The deterministic-compressor niche is crowded, mature, and dominated by rtk by a wide margin (81.5k vs. the next-largest specialist at 153 stars).** Nothing here beats rtk on the axis mechanism 3 would care about (Bash-specific, known-command coverage, Claude Code hook integration already built).
2. **The LLM-semantic-summarization niche - the one `cdocs:bash-runner` occupies - has no viable off-the-shelf competitor.** Both hits are small, and one is stale by 6 months and unlicensed, the other stale by 15 months and separately flagged as risky. This is not "the idea is unvalidated": it is "the idea is validated as worth building by prior art, but nothing existing is adoptable as-is." A dispatched, model-tiered, tool-restricted subagent (`model: haiku`, `tools: Bash`) is a Claude-Code-native primitive (the `Task` tool plus agent frontmatter) that none of these external tools replicate; the closest analog (`daz-command-mcp`) reimplements the same idea as a standalone MCP server rather than using the harness's own subagent dispatch, and does so with far less adoption/maintenance signal than the harness feature it re-invents.

### Does rtk's hook mechanism bear on the proposal's `PreToolUse` `updatedInput` findings?

Partially, and inconclusively. Round 1 review reproduced (2/2, headless, `claude 2.1.280`, Linux) that `PreToolUse` `updatedInput` DOES rewrite Bash commands on the installed environment, contradicting the proposal's original Finding 2. rtk's own README confirms it relies on exactly this class of mechanism ("The hook transparently intercepts Bash commands and rewrites them to rtk equivalents before execution," installed via `rtk init -g` / `rtk hook claude`), which is circumstantial corroboration that the rewrite channel works in current Claude Code versions widely enough for an 81.5k-star project to build its primary integration on it. The README does not document the exact hook JSON shape (`updatedInput` vs. some other mechanism, e.g. a wrapper script substitution at the PATH level) closely enough to serve as independent technical confirmation beyond what round 1 review already established directly. Not load-bearing for this report's recommendation either way; noted for completeness only.

## Analysis

### Does rtk (or anything found) let cdocs skip building `cdocs:bash-runner`?

No. Every deterministic/rule-based tool found, including rtk, shares the same structural limitation relative to mechanism 1's job:

- **No caller-steerable salience.** The proposal's Input contract lets the dispatching agent supply an explicit salience spec ("return matches per file, first 3 per file" for a sweep; "return the final summary line plus any non-zero exit" for a build). rtk's filters are fixed per command type by rtk's own maintainers; there is no per-call way for a cdocs agent to say "for this specific `grep -rn` invocation, what I actually need is X." `rtk summary`'s "heuristic summary" is the closest thing to a generic fallback, but it is undocumented, not steerable, and explicitly heuristic rather than semantic.
- **No coverage for unfamiliar or unanticipated commands.** rtk's own explicit behavior for anything outside its 100+ list is raw passthrough plus tracking - i.e., exactly the "unanticipated verbose" case that this proposal's mechanism 2 (the deterministic cap) already exists to catch, and that mechanism 1 exists to catch when the caller anticipates it despite the command being unfamiliar (an unfamiliar script, an unfamiliar repo's build tooling - the proposal's own Dispatch Scope language). rtk does not change that case's coverage story at all.
- **No semantic comprehension.** None of the deterministic tools read output and reason about what matters; they apply fixed rules (dedup, group by directory, truncate, extract known fields). The proposal's core justification for mechanism 1 - "a haiku agent reads the whole output once and returns the buried needle regardless of format" - is a capability none of these tools have by design; it is the entire reason they are fast and free (<10ms, zero LLM cost) rather than a dispatched-agent round trip.

So: build-is-still-right for mechanism 1. This is not weakened by anything found; if anything it is reinforced, since the one architecturally-similar prior art (`daz-command-mcp`) is unmaintained and unlicensed, meaning the closest existing analog to `cdocs:bash-runner` is not itself adoptable.

### Does rtk let cdocs skip or simplify mechanism 3?

This is the live question, since mechanism 3 (the `PreToolUse` advisory/rewrite nudge) is exactly rtk's territory and rtk covers it more completely than the proposal's own hand-picked allowlist did. Round 1 review already found the proposal's original mechanism-3 allowlist (npm install/docker build/terraform) misses this corpus's actual whales (grep/find/git-diff/cat sweeps) and recommended keeping mechanism 3 deferred on redundancy-with-1+2 grounds. rtk's coverage of exactly those whale command shapes (`grep`, `rg`, `find`, `git diff`, `cat`) strengthens rather than reverses that deferral: if a maintainer ever wants the deterministic-floor value mechanism 3 was reaching for, a maintained, widely-adopted, Apache-2.0-licensed tool already does it better than a bespoke allowlist would, for the exact command shapes this repo's data shows matter. That is a reason to keep not building it, not a reason to start building a wrapper around rtk.

**Building `cdocs:bash-runner` as a thin wrapper AROUND rtk is not recommended**, for reasons independent of rtk's quality:

1. **External binary dependency in a plugin.** rtk is a separate Rust binary (brew/curl-script/cargo install, no MCP/library mode), meaning `cdocs:bash-runner` would need to detect-or-require rtk's presence on PATH in every consuming environment. The proposal already has a live precedent for refusing exactly this shape of coupling: mechanism 2's `bashOutputMaxChars` cap is delivered as `/cdocs:init` *guidance*, not baked into the plugin, specifically because "a plugin cannot write a consumer's `settings.json`... an output cap is a consumer policy choice, not a plugin default" (proposal, mechanism 2). A hard rtk dependency is a strictly heavier version of the same problem: it is not settings the consumer can flip, it is a binary the plugin's own agent would silently fail without, in every install (CI runners, sandboxes, locked-down environments) that lacks it or lacks brew/cargo/curl-to-shell access.
2. **Supply-chain surface.** `cdocs:bash-runner` would be executing a third-party compiled binary as part of every dispatched Bash call - a materially different trust boundary than the plugin's current surface (its own bash scripts and TypeScript hooks, reviewed in-repo). Apache 2.0 licensing is not a blocker (permissive, compatible), but running unreviewed third-party binary output-interception code inside an agent's tool-use path is a new category of risk this plugin does not currently take on anywhere.
3. **Pre-1.0 stability.** `dev-0.50.0-rc.451`, 1,574 open issues, 8 months old. Fine for an end user to install voluntarily; risky as a load-bearing dependency of a shared plugin.
4. **It would not simplify mechanism 1's code anyway** (per the Analysis above), so the only thing wrapping rtk would buy is mechanism 2/3's territory, which is already deferred/optional and covered adequately by the existing settings-cap floor.

### What about Headroom, given its "library, proxy, MCP server" modes and broader scope?

Same verdict, for the same reasons, plus one more: Headroom's own claimed number for coding-agent tool output specifically is ~20% reduction, far below rtk's 60-90% and below what the proposal is targeting; its strength (RAG chunks, JSON, cross-format compression via a trained model) is orthogonal to this proposal's Bash-specific problem and would add a model-weight footprint on top of the binary-dependency concerns already raised for rtk. Not recommended for adoption or wrapping, for the same reasons as rtk, with a weaker case on effectiveness.

## Recommendations

**Addressed to the round-2 reviewer of `cdocs/proposals/2026-09-22-haiku-bash-wrapper.md`.**

1. **Do not require the proposal to adopt or wrap `rtk-ai/rtk` (or any tool found here) in place of `cdocs:bash-runner`.** Mechanism 1's core value proposition - semantic, caller-steerable extraction from arbitrary/unfamiliar command output inside a disposable dispatched context - has no adoptable off-the-shelf substitute. The one architecturally similar prior art (`daz-command-mcp`) is stale, unlicensed, and far less adopted than the Claude-Code-native subagent pattern it half-reimplements. **The existing bespoke design for mechanism 1 stands as reviewed; this finding does not reopen it.**
2. **This does not block round 2's revision**, which is scoped to the three empirical B1-B3 corrections from round 1 review (hook-channel behavior, cap-as-spill-not-truncation, runner capture-to-file workflow). None of those corrections interact with anything in this report.
3. **Optional, non-blocking suggestion for the proposal's mechanism 3 section (or a future follow-up, not this revision round):** cite `rtk-ai/rtk` in the Deferred/mechanism-3 rationale as evidentiary support for staying deferred - not "mechanism 3 is dead" but "if a maintainer ever wants this class of deterministic floor, a mature, actively-maintained, Apache-2.0 tool (81.5k stars, and its command coverage happens to include this corpus's actual observed whales: `git diff`, `grep`/`rg`, `find`, `cat` sweeps) already exists and would outperform a bespoke allowlist; recommend pointing consumers at it rather than building one." This strengthens, and does not contradict, round 1 review's existing "keep mechanism 3 deferred" verdict.
4. **Explicitly do not recommend making `rtk` a plugin dependency, a runtime requirement, or an `/cdocs:init`-delivered install step.** The reasoning mirrors the proposal's own existing rationale for keeping the settings-cap a documented-not-baked surface (mechanism 2): a plugin should not silently require, or fail without, a third-party compiled binary that the plugin cannot install, version-pin, or vet on the consumer's behalf. If this is ever revisited, treat it as a new, separately-reviewed proposal (optional `/cdocs:init` guidance pointing at rtk as a documented user choice, analogous to the `bashOutputMaxChars` guidance), not a change folded into this one.
5. **Verdict for the reviewer's own record: build-is-still-right for mechanism 1, adopt-alongside-as-a-documentation-citation-only (not a dependency) for mechanism 3, no change to mechanism 2.**
