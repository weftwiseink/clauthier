---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T09:02:38-07:00
task_list: meta/token-spend-attribution
type: proposal
state: live
status: request_for_proposal
tags: [meta, tooling, cost, context-management, settings, bash]
---

# Settings-Level Bash Output Cap (`bashOutputMaxChars`)

> BLUF(opus-5-5/token-spend-attribution): Decide whether, and how, to bound unanticipated verbose Bash output with a tightened `bashOutputMaxChars` cap, given that the setting is global and would also cap the `cdocs:bash-runner` haiku agent's own Bash calls. Recommended first step: ship the runner, gather usage data, then decide.
> - **Motivated By:** `cdocs/proposals/2026-09-22-haiku-bash-wrapper.md` (cap deferred from shipped scope by maintainer directive 2026-10-05), `cdocs/reviews/2026-09-23-review-of-haiku-bash-wrapper.md` (canary verification and measured per-call distribution).

## Objective

`cdocs:bash-runner` contains Bash output only when an agent anticipates verbosity and dispatches it.
Undispatched verbose Bash falls back to the platform default ceiling: a valid result lands inline in full up to ~30,000 chars, and a failed one up to ~10,000.
Since the observed corpus max is 29,351 chars, nearly every observed whale lands inline in full when not dispatched.
A tighter settings-level ceiling is the zero-LLM-cost lever for that residual, but it was deferred because it is global (it also bounds the runner's own Bash) and because it is consumer settings policy a plugin cannot own.

## Context: Carried-Over Evidence

From the haiku-bash-wrapper proposal and its round-1 review (measured on Claude Code 2.1.280; not re-derived here):

- **Spill-cliff semantics.** Valid result: inline up to the ceiling; past it, a file path plus a ~2,000-char preview. Failure result: inline up to ~10,000; past it, a head+tail excerpt with no path. `bashOutputMaxChars` (v2.1.261+, up to 128,000) sizes the inline ceiling and the read-back window together and overrides `BASH_MAX_OUTPUT_LENGTH`.
- **Per-call distribution** (11,531 Bash results): p50 655, p90 3,978, p95 6,228, p99 14,103, max 29,351 chars. Candidate start 6,000 (~p95, spills ~5%), band 4,000-8,000.
- **Read-back re-ingestion cliff.** Every spilled valid result is a read-back candidate that re-ingests the whole output plus line-number overhead; a result just over the cap costs more than it saves if read back. This is why the candidate sat mid-band.
- **Unverified.** Whether the setting also bounds the failure-path head+tail excerpt (docs say it is cut from the read-back window, which the setting sizes), and whether the ~2,000-char valid-result preview is fixed or scales with the setting.

## Scope

A future proposal elaborating this RFP should explore:

- **Need.** Is a cap needed at all once the runner and its dispatch guidance ship? Gather post-ship usage data first: share of large Bash results that are undispatched, and how often agents read spilled files back.
- **Runner composition.** The cap is global, so it also bounds the runner's extraction outputs. How do the two compose? Does the runner's capture-to-file flow hold under a low cap (the "runner under a low cap" test: true last line of `seq 1 200000`), and do its extraction bounds need to be sized relative to the cap?
- **Value and tuning.** Confirm or revise the 6,000 / 4,000-8,000 candidate against post-ship data and the read-back cliff.
- **Delivery.** Consumer guidance via a rule section materialized by `/cdocs:init` (with an `update-config` snippet), a consent-gated `settings.json` write, or documentation only. The plugin must not silently mutate harness config.
- **Verification.** Resolve the two unverified semantics above with a canary, and test the cap shape directly (a >ceiling valid direct command yields preview+path; a failing one yields head+tail with no path).
- **Alternative levers.**
  - [`rtk-ai/rtk`](https://github.com/rtk-ai/rtk): consumer-adopted deterministic `PreToolUse` command-rewrite proxy covering the `git diff`/`grep`/`find`/`cat`-sweep shapes that dominate the corpus (see `cdocs/reports/2026-09-23-bash-output-tooling-landscape.md`; not recommended as a plugin dependency).
  - A content-aware `PostToolUse` `updatedToolOutput` hook, if [#68951](https://github.com/anthropics/claude-code/issues/68951) is resolved for built-in Bash: a better floor than a blind cliff, and possibly scopeable to the parent rather than global.

## Open Questions

- Can the cap be scoped so it does not apply inside the runner (per-agent settings, an env override in the runner's capture call), or is global the only option?
- What usage signal, at what threshold, justifies shipping the cap after the runner is live?
- If the `PostToolUse` channel is fixed upstream, does it supersede this RFP entirely?
