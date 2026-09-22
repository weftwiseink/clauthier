---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-22T10:30:00-07:00
task_list: meta/token-spend-attribution
type: devlog
state: live
status: review_ready
tags: [meta, tooling, cost, hooks, context-management]
---

# Haiku Bash-Wrapper Landscape Research

## Objective

Resolve the maintainer's pushback on the haiku-bash-wrapper idea from
[`2026-09-20-read-source-attribution.md`](../reports/2026-09-20-read-source-attribution.md) Recommendation 3
and [`2026-09-20-token-spend-by-role.md`](../reports/2026-09-20-token-spend-by-role.md) action item #5:
"why truncate bash output via a separate PostToolUse hook if we're already having haiku deal with it?"
Produce a `cdocs:report` landscape survey that either shows the hook is redundant, or gives a precise division
of labor, and end with a concrete recommended shape a later `/cdocs:propose` round can build from directly.
Explicitly out of scope: writing the proposal itself.

## Plan

1. Read the two source reports in full, focused on Recommendation 3 and the "Context-management primitives
   available" section (which already states the hook is `updatedToolOutput`, v2.1.121+, and that LLM
   distillation must be manual dispatch).
2. Load the `cdocs:report` skill and `writing-conventions.md` for template/BLUF conventions.
3. Dispatch two parallel background research agents rather than doing sequential lookups myself:
   - `claude-code-guide`: authoritative facts on Claude Code's built-in Bash truncation, the exact
     `updatedToolOutput` schema/scope/limitations, and standard deterministic CLI-shrinking techniques.
   - `Explore`: this repo's existing conventions to model the wrapper on: `plugins/cdocs/agents/*.md`
     patterns, `model-tiering.md`'s haiku tier, existing hook registrations in
     `plugins/cdocs/hooks/hooks.json`, `orchestration-discipline.md`'s fork-vs-specialist language, and a
     check for prior art (is this already specced somewhere on disk?).
4. Synthesize both into a resolution: are the hook and wrapper the same problem or different ones, and if
   both survive, what exactly does each own.
5. Write the report to `cdocs/reports/2026-09-22-haiku-bash-wrapper-landscape.md`, commit, then this devlog,
   commit separately.

## Testing Approach

This is a research/writing task, not code. "Verification" here means: source-report claims are traced back to
their origin (both prior reports' relevant sections were read directly, not paraphrased from memory), and new
platform-fact claims (the Bash `updatedToolOutput` regression, the 30k-char default cap) are explicitly labeled
in the report as agent-reported rather than independently re-fetched by me in this pass, with a caveat telling
the eventual proposal author to re-verify the regression claim before depending on it. No completion claim is
made beyond what the two subagents actually returned.

## Research Notes

- The `claude-code-guide` agent reported (citing GitHub issues/release notes it says it fetched, not
  independently re-verified by me): Claude Code already applies a hard-coded 30,000-char Bash output cap with
  middle-truncation (head+tail preserved) by default; this is configurable via `BASH_MAX_OUTPUT_LENGTH` (env
  var) and, as of v2.1.261+, `bashOutputMaxChars`/`taskOutputMaxChars` settings. It also reported that
  `PostToolUse` `updatedToolOutput` (schema: `hookSpecificOutput.updatedToolOutput`, introduced v2.1.121,
  scoped to Bash/Read/Edit/Write/Glob/Grep/MCP, conditionable via an `if` matcher) has a reported regression
  since v2.1.163+ ([#68951](https://github.com/anthropics/claude-code/issues/68951)) where it silently no-ops
  for the built-in Bash tool specifically. This is the single most load-bearing and least-verified fact in the
  resulting report: it directly determines whether the literal "PostToolUse truncation hook" design from the
  source reports is buildable today.
- The `Explore` agent confirmed: `plugins/cdocs/agents/nit-fix.md` is the best existing template for a narrow
  haiku-tier dispatched agent (minimal tool list, fixed-format report, explicit "do NOT" constraints);
  `judge.md` establishes precedent for omitting `Task` from a dispatched agent's toolset; the plugin's hooks
  (`plugins/cdocs/hooks/hooks.json`) currently only match `"Write|Edit"`, so a `Bash`-matcher hook would be new
  but follows an established registration shape; and the idea is already named as roadmap item "I3" feeding
  "RFP-6" in `cdocs/reports/2026-09-21-cdocs-context-roadmap-assets/index.html`, but no standalone proposal or
  RFP file exists on disk yet, so this report is not duplicative.

## Implementation Notes

Key resolution reached (full reasoning in the report itself, not duplicated here per the writing-conventions
dedup rule): the hook and the wrapper are not redundant because they differ on two independent axes, coverage
(universal safety net vs. opt-in dispatch that depends on an agent correctly predicting verbosity in advance)
and technique (blind byte/line truncation, which can lose a signal buried outside a head+tail window, vs.
semantic distillation, which reads the whole thing once inside a disposable context and returns only what
matters). Recommendation is both, with a precise division of labor table in the report, plus a load-bearing
caveat: the literal PostToolUse-hook design from the source reports may currently be non-functional for Bash
specifically, so the concrete design section recommends the already-working `bashOutputMaxChars` setting as
the near-term deterministic floor and defers the content-aware hook pending re-verification of the regression.

## Changes Made

| File | Change |
|---|---|
| `cdocs/reports/2026-09-22-haiku-bash-wrapper-landscape.md` | New report resolving the hook-vs-wrapper question, with a concrete recommended shape for a follow-on proposal |
| `cdocs/devlogs/2026-09-22-haiku-bash-wrapper-research.md` | This devlog |

## Verification

- Report file written and reviewed for adherence to `writing-conventions.md` (BLUF present, sentence-per-line,
  direct links for external references, history-agnostic framing, no em-dashes).
- Both background research agents completed successfully (task-notification `status: completed` for both
  `a2288131d567b9375` and `ab33b4c224416952c`); their full findings are reflected in the report's Key Findings
  and Method sections rather than only summarized here.
- No code changes, no build/test suite applicable to this task.

## Deferred / Not Done

- The regression claim on `PostToolUse` `updatedToolOutput` for Bash ([#68951](https://github.com/anthropics/claude-code/issues/68951))
  is not independently re-verified against the currently-installed Claude Code version; flagged as a caveat
  in the report and must be checked before the proposal round commits to a specific hook design.
- No per-call size distribution exists for the Bash intake bucket (only a corpus mean), so the tightened-cap
  starting value in the report (4,000-6,000 chars) is a reasoned starting point, not a derived optimum.
- The proposal itself (`/cdocs:propose`) is explicitly out of scope for this task and was not started.
