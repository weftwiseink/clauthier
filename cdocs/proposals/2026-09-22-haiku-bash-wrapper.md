---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-22T10:39:14-07:00
task_list: meta/token-spend-attribution
type: proposal
state: live
status: review_ready
tags: [meta, tooling, cost, hooks, context-management, agents, haiku]
---

# Haiku Bash-Output Wrapper: `cdocs:bash-runner` + Deterministic Floor

> BLUF(meta/token-spend-attribution): Ship a haiku-tier `cdocs:bash-runner` agent (`Bash`-only, modeled on `nit-fix.md`) that agents opt into for expected-verbose commands and that returns a fixed-format salient extract, keeping the raw dump inside its disposable context.
> Pair it with a deterministic settings-level output cap (`bashOutputMaxChars` ~4,000-6,000 chars), delivered as `/cdocs:init` consuming-project guidance rather than baked into the plugin.
> Verification finding: the custom `PostToolUse` truncation hook stays DEFERRED - the `updatedToolOutput` regression is confirmed and closed won't-fix ([#68951](https://github.com/anthropics/claude-code/issues/68951)), and the report's proposed `PreToolUse` command-rewrite interim lever is ALSO dead ([#79321](https://github.com/anthropics/claude-code/issues/79321), `updatedInput` silently dropped for Bash), so the only viable hook lever is an advisory block-and-nudge.

## Summary

This proposal operationalizes [`cdocs/reports/2026-09-22-haiku-bash-wrapper-landscape.md`](../reports/2026-09-22-haiku-bash-wrapper-landscape.md), which resolved the maintainer's "why both a hook and a wrapper?" question: they cover different failure modes (a universal deterministic floor for unanticipated verbosity, opt-in semantic distillation for anticipated verbose-and-important calls) and should ship together.

Before building on the report's most load-bearing claim, its verification was re-run against the installed Claude Code version (2.1.280).
The result tightens the design rather than loosening it: not only is the `PostToolUse` `updatedToolOutput` Bash regression real and closed as won't-fix, but the report's own proposed fallback - a `PreToolUse` command-rewrite hook - relies on a second mechanism (`updatedInput`) that is independently broken for Bash in the same way.
Both hook-based rewrite channels for the built-in Bash tool are inert.
The design therefore leans on the two mechanisms that provably work today: a dispatched haiku agent and a settings-level output cap.
See [Verification of the Load-Bearing Hook Claim](#verification-of-the-load-bearing-hook-claim) for the evidence.

The shape:

- `cdocs:bash-runner` (new `plugins/cdocs/agents/bash-runner.md`, `model: haiku`, `tools: Bash`) is the primary, buildable-now mechanism.
- A tightened `bashOutputMaxChars` cap is the always-on floor, shipped as `/cdocs:init`-delivered guidance because a plugin cannot write a consumer's `settings.json`.
- The custom content-aware `PostToolUse` hook is explicitly DEFERRED, gated on upstream reopening the won't-fixed regression.
- The interim `PreToolUse` lever is downgraded from the report's "command rewrite" to an advisory "block-and-nudge," because rewrite is confirmed broken. This lever is optional and low-priority.

## Objective

Bash command output is 28.5% of read intake per [`cdocs/reports/2026-09-20-read-source-attribution.md`](../reports/2026-09-20-read-source-attribution.md) (3.76M of 13.17M approx-tokens, 9,581 results, mean 390 tok/result): "death by a thousand cuts" from many medium-sized results, amplified by the report's separately-measured per-turn re-send factor.
The goal is to keep verbose Bash output out of the parent (Opus) context: distilled to a salient extract when an agent anticipates verbosity, and deterministically capped when it does not.

## Background

- The landscape report [`cdocs/reports/2026-09-22-haiku-bash-wrapper-landscape.md`](../reports/2026-09-22-haiku-bash-wrapper-landscape.md) is the direct predecessor and settles the design questions this proposal builds on.
  Read its "Concrete Design" and "Division-of-labor summary" sections first.
- The two source reports that raised the problem: [`2026-09-20-read-source-attribution.md`](../reports/2026-09-20-read-source-attribution.md) (Recommendation 3) and [`2026-09-20-token-spend-by-role.md`](../reports/2026-09-20-token-spend-by-role.md) (action item #5).
- Existing agent template: [`plugins/cdocs/agents/nit-fix.md`](../../plugins/cdocs/agents/nit-fix.md) (haiku, narrow tool allowlist, rule-reading Startup, fixed-format report, explicit Constraints).
- Precedent for deliberately omitting `Task` from a dispatched agent's surface: `plugins/cdocs/agents/judge.md`.
- Rule-reading path convention (relative `rules/*.md` first, `plugins/cdocs/rules/*.md` fallback): [`plugins/cdocs/README.md`](../../plugins/cdocs/README.md) "Agent path resolution".
- Model-tiering carve-out mechanics (consumer floor wins; adopt via named carve-out): [`plugins/cdocs/rules/model-tiering.md`](../../plugins/cdocs/rules/model-tiering.md).
- Existing hook registration shape: [`plugins/cdocs/hooks/hooks.json`](../../plugins/cdocs/hooks/hooks.json) (SessionStart, `PreToolUse`/`PostToolUse` on matcher `Write|Edit`; no `Bash`-matcher hook exists yet).

## Verification of the Load-Bearing Hook Claim

The report flagged one fact as its most load-bearing and least-verified: that `PostToolUse` `updatedToolOutput` silently no-ops for the built-in Bash tool since Claude Code v2.1.163+, per [#68951](https://github.com/anthropics/claude-code/issues/68951), cited by a prior subagent but not independently re-fetched.
That claim was re-verified for this proposal.

**Finding 1 - CONFIRMED-REGRESSED, and closed won't-fix.**
[#68951](https://github.com/anthropics/claude-code/issues/68951) is real.
Title: "PostToolUse `updatedToolOutput` silently ignored for built-in Bash tool (2.1.163/2.1.177) - regression; prior reports #65403/#67442/#54196 closed as duplicate, never fixed."
The hook runs (exit 0, valid envelope) but the model still receives the original, unmodified Bash output.
`updatedToolOutput` works for MCP tools, not for built-in Bash/WebFetch.
The issue is closed as "not planned," and its cited predecessors were closed as duplicate and never fixed.
There is no fix version.

**Finding 2 (new, not in the report) - the report's proposed interim lever is ALSO dead.**
The report recommended a `PreToolUse` command-rewrite hook as "the interim deterministic lever that is not blocked," on the theory that `PreToolUse` sidesteps the `PostToolUse` bug.
That theory does not hold.
[#79321](https://github.com/anthropics/claude-code/issues/79321), "[BUG] PreToolUse hook `updatedInput` is silently ignored for the Bash tool" (confirmed 2.1.215, closed "not planned"), documents the same silent-drop failure for the `PreToolUse` rewrite channel: a hook returning `permissionDecision: "allow"` with `updatedInput` to rewrite the command runs, but the original command executes unchanged.
So both hook-based rewrite mechanisms for the built-in Bash tool - post-output and pre-command - are inert.

**Finding 3 - installed version.**
`claude --version` reports `2.1.280` in this environment.
That is newer than every affected version cited (2.1.163, 2.1.177, 2.1.215) and no fix has landed for either issue, so both regressions are presumed live here.
No positive evidence of a fix on 2.1.280 was found.

**Finding 4 - what the hook surface CAN still do for Bash.**
Per [#68951](https://github.com/anthropics/claude-code/issues/68951)'s own compatibility notes, these channels work: `PreToolUse` `additionalContext`, `PostToolUse` `additionalContext`, and `PreToolUse` block via stderr + exit 2 (a deny with a reason string).
The feature request [#32105](https://github.com/anthropics/claude-code/issues/32105) ("allow `updatedToolOutput` for built-in tools for context budget recovery") confirms the exact use case this proposal wants is desired upstream but not shipped.

**Consequence for the design.**
The report's fallback plan - "settings-level cap + `PreToolUse` rewrite, defer the custom `PostToolUse` hook" - is correct in its first and third clauses and wrong in its second: the `PreToolUse` rewrite is not a working lever.
This proposal keeps the settings-level cap and the deferral, drops the rewrite lever, and replaces it with an advisory block-and-nudge (which uses only the confirmed-working `PreToolUse` block/`additionalContext` channels).
Nothing in the core design (the haiku wrapper) depends on either broken mechanism, so the design is correct under the confirmed-broken answer.

## Proposed Solution

Three mechanisms with a precise division of labor, mirroring the report's "Division-of-labor summary" table with the corrections above.

### 1. `cdocs:bash-runner` haiku agent (primary, works now)

A new dispatched agent at `plugins/cdocs/agents/bash-runner.md`, modeled structurally on `nit-fix.md`: frontmatter, Startup, Input, Workflow, Output Format, Constraints.

**Frontmatter.**
`model: haiku`, `tools: Bash` only.
No `Read`/`Edit`/`Write`/`Task`: this agent runs exactly one command and reports, following `judge.md`'s precedent of deliberately narrowing the surface.
Omitting `Task` prevents onward dispatch; omitting `Write`/`Edit` keeps it inert on the filesystem beyond the command it runs.

**Startup.**
Follow the repo's rule-reading convention only insofar as it is cheap and relevant: this agent's job is mechanical, so it needs the writing conventions far less than `nit-fix` does.
Use the same relative-then-plugins-fallback path pattern (`rules/*.md` relative to the agent file, else `plugins/cdocs/rules/*.md`) if any rule is read at all - but because `tools: Bash` excludes `Glob`/`Read`, this agent cannot read rule files the way `nit-fix` does.
The agent therefore carries its extraction contract inline in its own prompt rather than reading it from `rules/`.
> NOTE(meta/token-spend-attribution): This is a deliberate divergence from the `nit-fix` rule-reading pattern, forced by the `Bash`-only allowlist. Flagged for reviewer scrutiny: an alternative is to grant `Read` so the agent can honor the SessionStart-injected rules path, at the cost of a wider surface. The recommendation is to keep `Bash`-only and inline the tiny contract, since the agent enforces no writing conventions.

**Input contract.**
The dispatching agent's Task prompt supplies:
1. the exact command to run, and
2. optionally, what "salient" means for this call (for example: "return the exit code and any line matching `error`/`fail`/`FAIL`"; or "return the final summary line plus any non-zero exit"; or "return the file list, not per-file progress noise").
Absent an explicit salience spec, the agent applies a default heuristic (exit code, status classification, and any error-matching lines plus a bounded head/tail).
This mirrors how `nit-fix` is scoped only to the files named in its prompt.

**Workflow.**
Run the single command.
Capture exit code, stdout, stderr.
Extract the salient lines per the caller's spec or the default heuristic.
Classify status as `OK`/`FAILED`/`WARNINGS`.
Return the fixed-format report.
Do not re-run, do not run additional commands beyond what is needed to execute the one requested command, do not dispatch.

**Output contract (fixed-format, cheap for the parent to parse).**

```
BASH RUNNER REPORT
Command: <exact command run>
Exit code: <n>
Status: OK | FAILED | WARNINGS
Salient output (<=N lines):
<extracted lines, verbatim>
Full output: discarded (~<K> chars, lives only in this subagent transcript) | saved to <scratchpad-path>
```

The "discarded vs. saved" line is load-bearing: per the report's Key Finding 5, the raw output still exists in the wrapper's own subagent transcript even when the report discards it, so nothing is silently destroyed.
Default to NOT re-saving a second copy unless the caller asked for the artifact.
State discard explicitly rather than implying deletion.

**Dispatch scope: opt-in, documented convention, not a hard rule.**
Do not route every Bash call through this agent: a subagent round-trip is not worth it for `git status`, a one-line `ls`, or any command the caller already expects to be short.
Dispatch when a command is expected to be verbose-and-important, and especially when a blind cutoff would plausibly cut the signal:
build logs, test suites, package installs (`npm install`), linters, `terraform plan`/`apply`, container builds, wide recursive `find`/`grep` sweeps, `git log -p`, and any command whose output the caller cannot bound in advance (an unfamiliar script, an unfamiliar repo).
This is guidance for an agent's dispatch decision, not something tooling enforces; enforcement of the unanticipated case is the deterministic floor's job (mechanism 2).

**Model-tiering framing.**
Add `cdocs:bash-runner` as a named example in [`model-tiering.md`](../../plugins/cdocs/rules/model-tiering.md)'s "Mechanical / Deterministic Fan-Out Tier (haiku)" alongside `nit-fix`.
Frame it as a named carve-out a consumer must bless, not an automatic override: a consumer with a blanket opus floor still needs to explicitly opt this dispatch down to haiku, per the rule's Precedence language.
The dispatch-decision convention (the "when to dispatch" list above) belongs in the same tier note or in [`orchestration-discipline.md`](../../plugins/cdocs/rules/orchestration-discipline.md) alongside the existing fork-vs-specialist disposability guidance, since a bash-runner dispatch is the same disposable-context shape applied to a single command.

### 2. Deterministic floor: settings-level cap (always on, zero LLM cost)

Set the built-in Bash output cap well below the 30,000-char platform default, via `bashOutputMaxChars` (settings, v2.1.261+) or `BASH_MAX_OUTPUT_LENGTH` (env var, older versions).
Both narrow the existing head/tail cap; neither is content-aware.

**Starting value: 4,000-6,000 characters** (roughly 1,000-1,500 tokens).
Rationale from the report: the corpus mean is 390 tok (~1,560 chars) per result, so this range is generous enough not to clip ordinary multi-line output but tight enough to bound the rare outlier that would otherwise dump thousands of lines into context.
Treat it as a tunable starting value, not a derived optimum: the corpus has no per-call Bash size distribution, so revisit once that data exists.

**Delivery: consuming-project guidance, NOT baked into the plugin.**
A Claude Code plugin cannot write a consumer's `settings.json`, and even if it could, an output cap is a consumer policy choice, not a plugin default.
This repo's own `.claude/settings.json` contains only `enabledPlugins` and sets no such cap, confirming the plugin does not own this surface.
Ship the recommendation as `/cdocs:init`-delivered guidance: `/cdocs:init` writes a short note into the materialized rules (or an adjacent setup note) telling the consuming project how and why to set `bashOutputMaxChars`, with the suggested range and the tuning caveat.
This keeps the plugin from silently mutating a consumer's harness config while still delivering the floor's value.
The harness's `update-config` skill territory (settings.json editing) is the mechanism a consumer would use to apply it; the proposal recommends documenting the setting, not auto-applying it.
> NOTE(meta/token-spend-attribution): Whether `/cdocs:init` should go further and offer to apply the setting (with consent) is an open question for the reviewer. The default recommendation is document-only, to preserve the "cdocs never silently mutates harness config" invariant.

### 3. Interim `PreToolUse` advisory block-and-nudge (optional, low-priority)

The report's "command-rewrite" interim lever is dropped per Finding 2 (`updatedInput` is inert for Bash).
What remains available is a `PreToolUse` hook on matcher `Bash` that, on a short allowlist of known-verbose command patterns (`npm install`, `docker build`, `terraform (plan|apply)`, common linter invocations), emits an advisory `additionalContext` note (or, more aggressively, a block via exit 2 with a reason) telling the agent to either add a quieting suffix itself (`--quiet`, `| tail -n N`, structured-output flags) or dispatch the command through `cdocs:bash-runner`.
This uses only the confirmed-working `PreToolUse` channels (Finding 4).
It is strictly weaker than a silent rewrite (it depends on the agent obeying the nudge) and adds friction to the main session, so it is proposed as OPTIONAL and defaulted OFF.
Recommendation: defer this to a follow-up unless review judges the nudge worth the friction, since mechanisms 1 and 2 already cover both the anticipated and unanticipated cases.

### Deferred: custom content-aware `PostToolUse` hook

A `PostToolUse` hook on matcher `Bash` using `hookSpecificOutput.updatedToolOutput` to do content-aware truncation - preserve head/tail K lines AND pull forward any error-matching line regardless of position, with `[... N lines elided ...]` markers - is the ideal deterministic mechanism.
It is DEFERRED because `updatedToolOutput` is inert for built-in Bash (Finding 1) and closed won't-fix.

**Trigger to pick it back up:** [#68951](https://github.com/anthropics/claude-code/issues/68951) or [#32105](https://github.com/anthropics/claude-code/issues/32105) is reopened and a release ships `updatedToolOutput` support for the built-in Bash tool, verified by a canary hook that returns a sentinel replacement and confirming the model sees the sentinel (the exact repro in #68951).
Until then, track as blocked/future work; do not implement.

### Division-of-labor summary

| Mechanism | Fires on | Technique | Cost | Status |
|---|---|---|---|---|
| Platform default (30k char, head+tail) | Every Bash call | Blind, wide | Zero | Already shipped upstream |
| `bashOutputMaxChars` tightened (~4-6k) | Every Bash call | Blind, tunable | Zero | **Adopt** (mechanism 2, via `/cdocs:init` guidance) |
| `cdocs:bash-runner` (haiku wrapper) | Deliberately dispatched calls | Semantic (full comprehension) | Small (haiku tokens + round-trip) | **Adopt** (mechanism 1, primary) |
| `PreToolUse` advisory block-and-nudge | Matched known-verbose commands | Advisory (agent must obey) | Zero | Optional, defaulted off (mechanism 3) |
| `PreToolUse` command-rewrite (`updatedInput`) | - | - | - | **Dead** ([#79321](https://github.com/anthropics/claude-code/issues/79321), inert for Bash) |
| `PostToolUse` content-aware truncation (`updatedToolOutput`) | - | - | - | **Deferred/blocked** ([#68951](https://github.com/anthropics/claude-code/issues/68951), won't-fix) |

## Important Design Decisions

- **`Bash`-only allowlist over `Bash`+`Read`.**
  Narrowest surface that does the job; matches `judge.md`'s deliberate-omission precedent.
  Cost: the agent cannot read `rules/*.md`, so its extraction contract is inlined rather than rule-loaded (flagged above for review).
- **Opt-in dispatch, not universal routing.**
  Round-trip overhead makes universal routing a net loss; the deterministic floor covers the unanticipated case that opt-in dispatch misses.
  This is the report's core answer to "why both": neither mechanism alone covers both the anticipated-verbose and unanticipated-verbose cases.
- **Settings cap as guidance, not plugin-baked.**
  Preserves the "cdocs never silently mutates harness config" invariant; a plugin cannot write a consumer's `settings.json` anyway.
- **Semantic distillation is not redundant with a blind cap.**
  A blind cap (platform default or tightened) uses middle-truncation and drops an error line buried in the middle of a long log - exactly the build-log-with-a-buried-error case that motivated the wrapper.
  The haiku agent reads the whole output once in disposable context and returns the buried needle.
- **Both broken hook channels are avoided entirely.**
  The design has zero dependency on `updatedInput` or `updatedToolOutput` for Bash, so it is robust to the confirmed regressions.

## Edge Cases / Challenging Scenarios

- **The command itself needs interactivity or a TTY.**
  `cdocs:bash-runner` runs one non-interactive command; interactive commands are out of scope and should not be dispatched.
- **The caller genuinely needs the full raw output later.**
  The agent notes the raw output lives in its subagent transcript and offers a `saved to <scratchpad-path>` mode when the caller asks; default is discard-with-note, not silent loss.
- **Salient extraction misses the real signal.**
  Haiku misjudging "salient" is a real failure mode; mitigate by having the caller pass an explicit salience spec for high-stakes calls, and by the default heuristic always including exit code and status so a `FAILED` is never hidden even if the specific error line is missed.
- **A command produces almost no output.**
  Dispatch overhead is wasted; the "when to dispatch" convention explicitly excludes short-output commands.
- **The deterministic cap clips a legitimately large single result the agent needed whole.**
  This is why the cap is a floor (tunable, generous-ish) and the wrapper (which preserves the salient signal semantically) exists alongside it; a consumer who finds 4-6k too tight raises it.
- **Consumer never runs `/cdocs:init`.**
  Then the settings-cap guidance is never delivered and the floor is absent; the wrapper still works (it is a plugin agent, not a settings dependency). Documented degradation, consistent with cdocs being opt-in per project.

## Test Plan

- **Agent definition parses and loads.**
  `cdocs:bash-runner` appears as a dispatchable agent; frontmatter (`model: haiku`, `tools: Bash`) is well-formed.
- **Tool restriction holds.**
  The agent cannot call `Read`/`Write`/`Edit`/`Task` (infrastructure-enforced allowlist).
- **Fixed-format report.**
  A dispatched command returns exactly the `BASH RUNNER REPORT` structure with all fields populated.
- **Salience: explicit spec honored.**
  Given "return any line matching `error`," a command whose error line is in the middle of long output has that line surfaced in the report.
- **Salience: default heuristic.**
  With no spec, a `FAILED` command still yields a non-`OK` status and its exit code, even if the specific error line is not extracted.
- **Containment (the core claim).**
  See Verification Methodology.
- **Deterministic cap.**
  With `bashOutputMaxChars` set low in a test settings file, a direct (non-wrapped) command producing >cap output is truncated to the cap before reaching the model.
- **`/cdocs:init` guidance delivery.**
  A test init writes the settings-cap recommendation into the materialized output; the guidance text is present and names the range and caveat.
- **Cross-target.**
  The new agent is picked up by `scripts/build-opencode.ts` (which auto-discovers `agents/*.md`); the built OC agent has valid OC frontmatter.

## Verification Methodology

The load-bearing claim is that the wrapper keeps verbose output out of the PARENT context.
Verify it directly with a canary:

1. Pick a command with deterministic, large, countable output, for example `seq 1 200000` (~1.2MB, far above any cap) or `yes CANARY_LINE | head -n 100000`.
2. Dispatch it through `cdocs:bash-runner` with a salience spec like "return the exit code and the last line."
3. Confirm the parent transcript contains only the fixed-format `BASH RUNNER REPORT` (a few lines: command, exit code, status, the last line, and the discard note) - NOT the 100k-200k lines of raw output.
4. Confirm the report's byte size is on the order of the extract (hundreds of chars), not the raw output (~MB).
5. As a negative control, run the same command as a direct `Bash` call in the parent and confirm the raw output (subject only to the platform/settings cap) does enter the parent transcript - demonstrating the wrapper is what achieves containment, not the cap alone.
6. For the cap: set `bashOutputMaxChars` low, run a >cap direct command, and confirm truncation to the cap in the parent transcript.

The containment check (steps 3-4) is the verification floor: if the parent transcript holds the raw dump, the wrapper has failed its one job regardless of report formatting.

## Implementation Phases

Phases 1-2 are the adopt-now core and are largely independent; phase 3 is optional; the deferred hook is not implemented.

### Phase 1: `cdocs:bash-runner` agent (primary)

- Author `plugins/cdocs/agents/bash-runner.md` modeled on `nit-fix.md` (frontmatter -> Startup -> Input -> Workflow -> Output Format -> Constraints), `model: haiku`, `tools: Bash`.
- Inline the salience/extraction contract and the fixed-format report in the agent prompt (no rule-file read, per the `Bash`-only decision).
- Constraints section: run exactly the one requested command, no onward dispatch, discard-with-note by default, explicit no-deletion language for the raw output.
- Success criteria: Test Plan items "Agent definition parses," "Tool restriction holds," "Fixed-format report," both salience tests, and the Verification Methodology canary (containment) pass.
- Do NOT modify existing agents, `hooks.json`, or the platform default.

### Phase 2: Dispatch convention + model-tiering carve-out + init guidance

- Add the "when to dispatch" convention and the `cdocs:bash-runner` named haiku carve-out to `model-tiering.md` (and/or the disposability note in `orchestration-discipline.md`).
- Add the `bashOutputMaxChars` recommendation (range, rationale, tuning caveat, "consumer applies it, plugin does not") to `/cdocs:init`'s delivered guidance.
- Success criteria: rule text present and consistent with the frontmatter/writing conventions; `/cdocs:init` guidance-delivery test passes.
- Dependency: independent of Phase 1's code but should cite the agent by name, so land after or with Phase 1.
- Do NOT auto-write any consumer `settings.json` value.

### Phase 3 (optional, defaulted off): `PreToolUse` advisory block-and-nudge

- Only if review judges the friction worthwhile.
- A `Bash`-matcher `PreToolUse` hook that, on an allowlist of known-verbose patterns, emits `additionalContext` (default) or blocks with exit 2 (aggressive), advising a quieter re-issue or a `cdocs:bash-runner` dispatch.
- Uses only confirmed-working `PreToolUse` channels; must NOT rely on `updatedInput`.
- Success criteria: the nudge fires on matched patterns and is silent otherwise; main-session friction is acceptable to the maintainer.
- Recommendation: defer to a follow-up.

### Deferred (not a phase): content-aware `PostToolUse` hook

- Blocked on upstream per Finding 1. Do not implement. Re-open per the trigger in the Deferred section above.

## Investigation Requested

Per `--dispatched` mode, in lieu of dispatching `/cdocs:review` directly, the following review is requested from the caller before this proposal advances to implementation:

- Sanity-check the two open design questions flagged in NOTE callouts: (a) `Bash`-only vs. `Bash`+`Read` for the agent's rule-reading, and (b) whether `/cdocs:init` should offer to apply the `bashOutputMaxChars` setting with consent vs. document-only.
- Confirm the verification finding's consequence: that dropping the report's `PreToolUse` rewrite lever (per [#79321](https://github.com/anthropics/claude-code/issues/79321)) is correct, and that mechanisms 1+2 suffice without mechanism 3.
- Validate the deterministic-cap starting range (4,000-6,000 chars) against any newer per-call Bash size data, if it exists.
