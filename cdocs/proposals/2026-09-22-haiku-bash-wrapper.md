---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-22T10:39:14-07:00
task_list: meta/token-spend-attribution
type: proposal
state: live
status: implementation_ready
last_reviewed:
  status: accepted
  by: "@claude-opus-4-8"
  at: 2026-09-23T10:37:20-07:00
  round: 2
tags: [meta, tooling, cost, hooks, context-management, agents, haiku]
---

# Haiku Bash-Output Wrapper: `cdocs:bash-runner` + Deterministic Floor

> BLUF(meta/token-spend-attribution): Ship a haiku-tier `cdocs:bash-runner` agent (`Bash`-only, modeled on `nit-fix.md`) that agents opt into for expected-verbose commands; it captures the command's output to a file in its own scratchpad and returns a fixed-format salient extract, keeping the raw dump out of the parent context.
> Pair it with a deterministic settings-level output cap (`bashOutputMaxChars`, recommended start 6,000 chars, tunable band 4,000-8,000), delivered as `/cdocs:init` consuming-project guidance rather than baked into the plugin.
> Hook finding (canary-verified on Claude Code 2.1.280): `PostToolUse` `updatedToolOutput` is inert for the built-in Bash tool ([#68951](https://github.com/anthropics/claude-code/issues/68951)), so the custom content-aware hook stays DEFERRED; `PreToolUse` `updatedInput` DOES rewrite Bash commands here, but a rewrite hook stays deferred anyway because it is redundant with mechanisms 1+2 and mis-targets the observed traffic.

## Summary

This proposal operationalizes [`cdocs/reports/2026-09-22-haiku-bash-wrapper-landscape.md`](../reports/2026-09-22-haiku-bash-wrapper-landscape.md), which resolved the maintainer's "why both a hook and a wrapper?" question: they cover different failure modes (a universal deterministic floor for unanticipated verbosity, opt-in semantic distillation for anticipated verbose-and-important calls) and should ship together.

The design rests on three canary-verified platform facts on Claude Code 2.1.280 (see [Verification of the Load-Bearing Hook Claim](#verification-of-the-load-bearing-hook-claim)):

- `PostToolUse` `updatedToolOutput` is inert for the built-in Bash tool, so a custom content-aware truncation hook is not buildable and stays deferred.
- `bashOutputMaxChars` is a spill-to-file cliff, not a head/tail clip: a valid over-ceiling result collapses to a file path plus a ~2,000-char preview, and only a failed command yields a lossy head+tail excerpt. This shapes both the cap's cost model and the runner's own design.
- That same ceiling applies to the runner's own Bash call, so the runner cannot "read the whole output once." It captures the command's output to a file, then extracts with bounded shell commands over that file.

The shape:

- `cdocs:bash-runner` (new `plugins/cdocs/agents/bash-runner.md`, `model: haiku`, `tools: Bash`) is the primary, buildable-now mechanism. It captures-to-file-then-extracts.
- A tightened `bashOutputMaxChars` cap is the always-on floor, shipped as `/cdocs:init`-delivered guidance because a plugin cannot write a consumer's `settings.json`.
- The custom content-aware `PostToolUse` hook is DEFERRED, gated on the `updatedToolOutput` regression being fixed for built-in Bash.
- A `PreToolUse` command-rewrite hook is also DEFERRED, not because it fails (it works on this version) but because it is redundant with mechanisms 1+2 and mis-targets the observed heavy traffic.

## Objective

Bash command output is 28.5% of read intake per [`cdocs/reports/2026-09-20-read-source-attribution.md`](../reports/2026-09-20-read-source-attribution.md) (3.76M of 13.17M approx-tokens, 9,581 results, mean 390 tok/result): "death by a thousand cuts" from many medium-sized results, amplified by the report's separately-measured per-turn re-send factor.
The goal is to keep verbose Bash output out of the parent (Opus) context: distilled to a salient extract when an agent anticipates verbosity, and deterministically bounded when it does not.

## Background

- The landscape report [`cdocs/reports/2026-09-22-haiku-bash-wrapper-landscape.md`](../reports/2026-09-22-haiku-bash-wrapper-landscape.md) is the direct predecessor and settles the design questions this proposal builds on.
  Read its "Concrete Design" and "Division-of-labor summary" sections first.
- The two source reports that raised the problem: [`2026-09-20-read-source-attribution.md`](../reports/2026-09-20-read-source-attribution.md) (Recommendation 3) and [`2026-09-20-token-spend-by-role.md`](../reports/2026-09-20-token-spend-by-role.md) (action item #5).
- The round-1 review [`cdocs/reviews/2026-09-23-review-of-haiku-bash-wrapper.md`](../reviews/2026-09-23-review-of-haiku-bash-wrapper.md) supplies the canary verification, the measured per-call Bash size distribution (its Appendix), and the four resolved design questions folded into this revision.
- Existing agent template: [`plugins/cdocs/agents/nit-fix.md`](../../plugins/cdocs/agents/nit-fix.md) (haiku, narrow tool allowlist, fixed-format report, explicit Constraints).
- Precedent for deliberately omitting `Task` and for a `maxTurns` bound on a dispatched agent: `plugins/cdocs/agents/judge.md`.
- Model-tiering carve-out mechanics (consumer floor wins; adopt via named carve-out): [`plugins/cdocs/rules/model-tiering.md`](../../plugins/cdocs/rules/model-tiering.md).
- Existing hook registration shape: [`plugins/cdocs/hooks/hooks.json`](../../plugins/cdocs/hooks/hooks.json) (SessionStart, `PreToolUse`/`PostToolUse` on matcher `Write|Edit`; no `Bash`-matcher hook exists yet).

> NOTE(meta/token-spend-attribution): A parallel sonnet report on whether existing tooling (for example `rtk-ai/rtk`) could replace or complement a bespoke `cdocs:bash-runner` is pending; it feeds the round-2 reviewer, not this revision. The correctness fixes here apply regardless: even a wrapped external tool, if it is Bash-only under the hood, hits the same spill ceiling and needs the same capture-to-file-then-extract flow.

## Verification of the Load-Bearing Hook Claim

The landscape report flagged one fact as its most load-bearing and least-verified: that `PostToolUse` `updatedToolOutput` silently no-ops for the built-in Bash tool.
This section records the canary-verified state on the installed version rather than reasoning from issue text.
The exact canary (both hook channels, one call, about $0.01 on haiku) is in the round-1 review's Appendix and is the documented re-check procedure.

**Finding 1 - `PostToolUse` `updatedToolOutput` is inert for built-in Bash.**
A `PostToolUse` Bash hook returning `hookSpecificOutput.updatedToolOutput: "SENTINEL_REPLACED_OUTPUT"` fires (logged) but the sentinel never reaches the model; the model receives the original output.
This reproduces the regression in [#68951](https://github.com/anthropics/claude-code/issues/68951) ("PostToolUse `updatedToolOutput` silently ignored for built-in Bash tool", closed "not planned").
`updatedToolOutput` works for MCP tools, not for built-in Bash.
The content-aware truncation hook cannot be built on this channel and is deferred.

**Finding 2 - `PreToolUse` `updatedInput` DOES rewrite Bash commands on this version.**
A `PreToolUse` Bash hook returning `permissionDecision: "allow"` with `updatedInput: {command: "echo REWRITE_APPLIED"}` executes the rewritten command: 2/2 headless haiku runs on `claude 2.1.280` (Linux, `claude -p`), transcript `tool_use.input.command` shows the original request while `toolUseResult.stdout` shows `REWRITE_APPLIED`.
[#79321](https://github.com/anthropics/claude-code/issues/79321) ("PreToolUse hook `updatedInput` is silently ignored for the Bash tool", reported on 2.1.215 Windows desktop, closed "not planned") does NOT reproduce here.
The rewrite channel is environment-dependent: broken as reported on 2.1.215 Windows desktop, working on 2.1.280 Linux headless; gate any use on the canary.

**Finding 3 - installed version and scope.**
`claude --version` reports `2.1.280`.
The findings above are from headless (`claude -p`) Linux runs; interactive mode was not separately tested.
Because the channel behavior is environment-dependent (Finding 2), the design deliberately avoids depending on either rewrite channel rather than assuming any given environment.

**Finding 4 - what the hook surface can still do for Bash.**
Per [#68951](https://github.com/anthropics/claude-code/issues/68951)'s compatibility notes, these channels work for Bash: `PreToolUse` `additionalContext`, `PostToolUse` `additionalContext`, and `PreToolUse` block via stderr + exit 2 (a deny with a reason string).
The feature request [#32105](https://github.com/anthropics/claude-code/issues/32105) ("allow `updatedToolOutput` for built-in tools for context budget recovery") confirms the exact use case this proposal wants is desired upstream but not shipped.

**Consequence for the design.**
The core design (the haiku wrapper, mechanism 1) and the deterministic floor (mechanism 2) depend on neither rewrite channel, so they are robust to the environment-dependent hook behavior.
The custom `PostToolUse` content-aware hook is deferred on Finding 1 (genuinely inert).
A `PreToolUse` rewrite hook is deferred on redundancy and mis-targeting grounds (see mechanism 3), not on breakage.

## Proposed Solution

Three mechanisms with a precise division of labor, mirroring the landscape report's "Division-of-labor summary" table with the corrections above.

### 1. `cdocs:bash-runner` haiku agent (primary, works now)

A new dispatched agent at `plugins/cdocs/agents/bash-runner.md`, modeled structurally on `nit-fix.md`: frontmatter, Input, Workflow, Output Format, Constraints.

**Frontmatter.**
`model: haiku`, `tools: Bash` only, plus `maxTurns: 8` (bounding a haiku runner that could loop on extraction, following `judge.md`'s `maxTurns: 10` precedent; 8 covers capture plus a handful of bounded extraction commands plus the report, with headroom).
No `Read`/`Edit`/`Write`/`Task`: this agent runs one requested command plus bounded extraction over its capture file, and reports.
Omitting `Task` prevents onward dispatch; omitting `Write`/`Edit` keeps it inert on the filesystem beyond its scratch capture file.
The `Bash`-only allowlist survives the OpenCode build: `scripts/build-opencode.ts` `mapTools` turns `tools: Bash` into `bash: true` with `read`/`edit`/`write: false`.

**No rule-reading Startup.**
Unlike `nit-fix`, this agent reads no rule files: it emits a fixed-format block and enforces no writing convention, so loading `writing-conventions.md`/`frontmatter-spec.md` would cost 2-3k haiku input tokens per dispatch for zero output effect.
`nit-fix` reads rules because rules ARE its rubric; that does not transfer here.
The extraction contract is inlined in the agent prompt.

**Input contract.**
The dispatching agent's Task prompt supplies:
1. the exact command to run, and
2. optionally, what "salient" means for this call.
Salience specs come in two shapes:
- line-oriented, for pass/fail commands: "return the exit code and any line matching `error`/`fail`/`FAIL`"; "return the final summary line plus any non-zero exit".
- aggregate, for sweeps where the matches ARE the signal: "matches per file, first 3 per file"; "the changed-file list plus per-file hunk counts"; "the file list, not per-file progress noise".
Absent an explicit salience spec, the agent applies a default heuristic (exit code, status classification, error-matching lines, plus a bounded head and tail).
This mirrors how `nit-fix` is scoped only to the files named in its prompt.

**Workflow: capture-to-file-then-extract.**
The Bash output ceiling applies to the runner's own Bash tool call, so the runner must not let a command's output flow to stdout directly (it would spill to a preview the runner cannot fully read).
Instead:
1. Run the requested command with capture into the runner's own scratchpad directory:
   `OUT="<scratchpad>/bash-runner-<ts>.log"; <cmd> > "$OUT" 2>&1; echo "exit=$?"`.
   The runner's tool result is then tiny (`exit=<n>`), and the full output is always on disk regardless of the command's exit status - which also means the platform's lossy failure-path excerpt never applies to this output.
2. Extract with bounded shell over the capture file, each command sized so its own output stays small: `wc -c "$OUT"`, `grep -nE '<salience pattern>' "$OUT" | head -n N`, `tail -n N "$OUT"`, `head -n N "$OUT"`, and for binary or very-long-line output `grep -a` and `cut -c1-N`.
3. Classify status as `OK`/`FAILED`/`WARNINGS` and return the fixed-format report.

**Output contract (fixed-format, cheap for the parent to parse).**

```
BASH RUNNER REPORT
Command: <exact command run>
Exit code: <n>
Status: OK | FAILED | WARNINGS
Salient output (<=N lines):
<extracted lines, verbatim>
Full output: saved to <scratchpad-path> (<K> chars)
```

The `saved to` line is the default and is load-bearing: the capture file is the primary artifact, not a copy, so nothing is silently destroyed.
State the path and its lifetime (the subagent's scratchpad directory, which is session-scoped and disposable).
The parent receives only the report; the raw output lives in the capture file (and the runner's own transcript holds only the bounded excerpts), so it never enters the parent context.

**Dispatch scope: opt-in, documented convention, not a hard rule.**
Do not route every Bash call through this agent: a subagent round-trip is not worth it for `git status`, a one-line `ls`, or any command the caller already expects to be short.
Dispatch when a command is expected to be verbose-and-important, ordered by the observed heavy traffic (the 15 largest Bash results in the corpus, all 22k-29k chars, are sweeps, not builds):
- wide recursive searches and diffs: `grep -rn` sweeps, `find`, `git diff`, multi-file `cat` loops (`for f in ...; do cat "$f"; done`).
- build logs, test suites, package installs (`npm install`), linters, `terraform plan`/`apply`, container builds, `git log -p`.
- any command whose output the caller cannot bound in advance (an unfamiliar script, an unfamiliar repo).
This is guidance for an agent's dispatch decision, not something tooling enforces; the unanticipated case is the deterministic floor's job (mechanism 2).

**Model-tiering framing.**
Add `cdocs:bash-runner` as a named example in [`model-tiering.md`](../../plugins/cdocs/rules/model-tiering.md)'s "Mechanical / Deterministic Fan-Out Tier (haiku)" alongside `nit-fix`.
Frame it as a named carve-out a consumer must bless, not an automatic override: a consumer with a blanket opus floor still needs to explicitly opt this dispatch down to haiku, per the rule's Precedence language.
The dispatch-decision convention (the "when to dispatch" list above) belongs in a new "Bash output hygiene" section in [`orchestration-discipline.md`](../../plugins/cdocs/rules/orchestration-discipline.md), alongside the existing fork-vs-specialist disposability guidance, since a bash-runner dispatch is the same disposable-context shape applied to a single command.

### 2. Deterministic floor: settings-level cap (always on, zero LLM cost)

Set the built-in Bash output ceiling below the ~30,000-char platform default via `bashOutputMaxChars` (settings, v2.1.261+, up to 128,000).
This is not a head/tail clip; it is a spill-to-file cliff:

- **Valid result (exit 0):** inline up to the ceiling; past it, the model gets a file path plus a preview of up to the first ~2,000 chars, and reads or searches the file if it needs more.
- **Failure result:** inline up to ~10,000; past it, a head-and-tail excerpt cut from the read-back window, with no file path.
- `bashOutputMaxChars` sizes the inline ceiling and the read-back window together, and it makes Claude Code ignore `BASH_MAX_OUTPUT_LENGTH`; the env var only enlarges the read-back window and does not raise the inline ceiling, so it is not the lever to reach for.

**Starting value: 6,000 characters** (tunable band 4,000-8,000).
This is grounded in the measured per-call Bash distribution over the read-source corpus (11,531 real Bash results, weftwise transcripts 2026-09-12 onward; mean 1,602 chars / ~400 tok, matching the read-source report's 390 tok and validating the join; full method in the round-1 review's Appendix):

| Stat | Chars |
|---|---:|
| p50 | 655 |
| p75 | 1,841 |
| p90 | 3,978 |
| p95 | 6,228 |
| p99 | 14,103 |
| max | 29,351 |

6,000 sits at p95: it spills the top ~5% of results (606 of 11,531), a defensible outlier boundary that leaves ordinary multi-line output untouched.
4,000 (p90) spills the top ~10% and cuts more but risks more read-backs; 8,000 (~p97) is the conservative end.
Because a spilled valid result collapses to a ~2,000-char preview, the realized inline saving per spilled result is `n - ~2,100`, larger than the raw "chars above cap" would suggest (at 4,000, roughly 36% of all Bash chars rather than 24.5%) - but every spilled result is a candidate for a read-back that re-ingests it whole.
That cliff is why the recommended start is the upper-middle of the band (6,000) rather than the aggressive end, and why the guidance must say: if agents are frequently reading spilled files back, raise the cap.

**Delivery: consuming-project guidance, NOT baked into the plugin.**
A Claude Code plugin cannot write a consumer's `settings.json`, and even if it could, an output cap is a consumer policy choice, not a plugin default.
This repo's own `.claude/settings.json` contains only `enabledPlugins` and sets no such cap, confirming the plugin does not own this surface.
Ship the recommendation as a "Bash output hygiene" section in [`orchestration-discipline.md`](../../plugins/cdocs/rules/orchestration-discipline.md).
That carrier is deliberate: `/cdocs:init` enumerates rule files by name for its `AGENTS.md` block, so a NEW `rules/*.md` file would require editing the init skill, whereas a new section in an existing rule file rides the existing materialization pipeline and hash marker with zero init changes.
The section explains how and why to set `bashOutputMaxChars`, gives the recommended value and band, states the spill-then-read-back tuning caveat, and points at the harness's `update-config` skill (with a copy-pasteable `settings.json` snippet) as the mechanism the consumer uses to apply it.
The proposal documents the setting; it does not auto-apply it.

### 3. Deferred: `PreToolUse` command-rewrite hook (works here, not adopted)

A `PreToolUse` Bash hook using `updatedInput` to append a quieting suffix (`--quiet`, `| tail -n N`, structured-output flags) to a matched command works on this version (Finding 2).
It is nonetheless deferred, on coverage grounds rather than breakage:

- Mechanisms 1 and 2 already cover the space. The coverage table (using the real spill-to-file semantics):

  | Case | Covered by | Outcome |
  |---|---|---|
  | Anticipated verbose, dispatched | 1 (runner) | Parent sees the fixed-format report only |
  | Unanticipated verbose, exit 0 | 2 (cap) | Parent sees ~2k preview + file path; bounded, recoverable via read-back |
  | Unanticipated verbose, non-zero exit | 2 (cap) | Parent sees a head+tail excerpt, no file path; a mid-log error CAN be lost; recovery is a re-run through 1 |

  The third row is the only real gap, and a rewrite hook does not close it: it fires only on a fixed pattern allowlist, and the observed whales are not on any plausible allowlist.
- It mis-targets the traffic. The 15 heaviest Bash results are `git diff`, `grep -rn` sweeps, `find`, and multi-`cat` loops - not `npm install`, `docker build`, or `terraform`. A blind `| tail` on a `grep` sweep destroys the signal (the matches ARE the output), so even a working rewrite is a poor fit for what actually dominates.
- A mature off-the-shelf tool already owns this niche better than a bespoke allowlist would. The tooling landscape report [`cdocs/reports/2026-09-23-bash-output-tooling-landscape.md`](../reports/2026-09-23-bash-output-tooling-landscape.md) found [`rtk-ai/rtk`](https://github.com/rtk-ai/rtk) (Apache-2.0, a Rust `PreToolUse` command-rewrite proxy) deterministically compresses 100+ known dev commands - including exactly the `git diff`/`grep`/`find`/`cat`-sweep shapes that dominate this corpus - with per-command filter/group/dedup pipelines a hand-written allowlist cannot match. A consumer who wants the deterministic-rewrite lever is better served pointing at rtk than by cdocs shipping a bespoke hook; that report recommends against adopting rtk as a plugin dependency (pre-1.0, RC-heavy, CLI-only) but confirms building a competing allowlist is not worth it.

If a future need arises (a specific known-verbose command a team runs constantly, or a consumer opting into rtk-style rewriting), this hook is the lever; re-verify the channel with the canary first, since its behavior is environment-dependent.

### Deferred: custom content-aware `PostToolUse` hook

A `PostToolUse` hook on matcher `Bash` using `hookSpecificOutput.updatedToolOutput` to do content-aware truncation - preserve head/tail K lines AND pull forward any error-matching line regardless of position, with `[... N lines elided ...]` markers - is the ideal deterministic mechanism.
It is DEFERRED because `updatedToolOutput` is inert for built-in Bash (Finding 1).

**Trigger to pick it back up:** re-run the hook-channel canary (round-1 review Appendix; returns a sentinel replacement and checks whether the model sees the sentinel). When a Claude Code release makes `updatedToolOutput` apply to the built-in Bash tool - watch [#68951](https://github.com/anthropics/claude-code/issues/68951) and [#32105](https://github.com/anthropics/claude-code/issues/32105) - this hook becomes buildable and upgrades the deterministic floor from a blind spill-cliff to content-aware truncation, without displacing the wrapper (which still owns the "find the buried needle" job).
Until then, track as blocked/future work; do not implement.

### Division-of-labor summary

| Mechanism | Fires on | Technique | Cost | Status |
|---|---|---|---|---|
| Platform default (~30k valid / ~10k failure ceiling) | Every Bash call | Blind spill-to-file (valid) / head+tail excerpt (failure) | Zero | Already shipped upstream |
| `bashOutputMaxChars` tightened (start 6,000) | Every Bash call | Blind, tunable spill cliff | Zero | **Adopt** (mechanism 2, via `orchestration-discipline.md` guidance) |
| `cdocs:bash-runner` (haiku wrapper) | Deliberately dispatched calls | Semantic (capture-to-file, then bounded extraction) | Small (haiku tokens + round-trip) | **Adopt** (mechanism 1, primary) |
| `PreToolUse` command-rewrite (`updatedInput`) | Matched known-verbose commands | Blind, pattern-scoped rewrite | Zero | Works here (2.1.280 Linux headless, 2/2); **deferred** - redundant with 1+2, allowlist misses observed whales |
| `PostToolUse` content-aware truncation (`updatedToolOutput`) | Every Bash call (or matched) | Heuristic (error-line-preserving) | Zero | **Deferred/blocked** ([#68951](https://github.com/anthropics/claude-code/issues/68951), inert for built-in Bash) |

## Important Design Decisions

- **`Bash`-only allowlist over `Bash`+`Read` (resolved Q1).**
  Narrowest surface that does the job; matches `judge.md`'s deliberate-omission precedent.
  Once the runner captures to a file itself, the one thing `Read` would buy (reading a spilled file) is unnecessary: every extraction it needs is shell.
  `Read` would also be a worse fit (line-number prefixes, a 2,000-line default window) and rule-loading has no consumer here, so it is excluded.
- **Capture-to-file-then-extract, not read-once.**
  The output ceiling applies to the runner's own Bash call, so a runner that let a command dump to stdout would itself only see a preview.
  Capturing to a file keeps the tool result tiny and the full output on disk (and "valid" from the platform's view regardless of exit status), which is what makes the containment claim actually hold.
- **Opt-in dispatch, not universal routing.**
  Round-trip overhead makes universal routing a net loss; the deterministic floor covers the unanticipated case that opt-in dispatch misses.
  This is the answer to "why both": neither mechanism alone covers both the anticipated-verbose and unanticipated-verbose cases.
- **Settings cap as guidance in an existing rule file, not plugin-baked, not a new rule file (resolved Q2).**
  Preserves the "cdocs never silently mutates harness config" invariant, and riding an existing rule file's materialization pipeline avoids editing `/cdocs:init`.
- **Semantic distillation is not redundant with a blind cap.**
  The blind cap loses signal in two ways the wrapper does not: a failed verbose command yields a lossy head+tail excerpt with no file (the middle is unrecoverable without a re-run), and a valid one puts the middle on disk at the cost of a read-back that re-ingests it whole.
  The runner captures the whole output to its scratch file and extracts from it with bounded shell (a `grep` over the file finds a buried error wherever it fell, and per-file aggregation is available for a sweep where a head/tail excerpt is the wrong default), so the salient signal reaches the parent without the raw dump - all in disposable context.
- **No dependency on either rewrite hook channel.**
  The design does not use `updatedInput` or `updatedToolOutput` for Bash, so it is robust to their environment-dependent and regressed behavior respectively.

## Edge Cases / Challenging Scenarios

- **The command needs interactivity or a TTY.**
  `cdocs:bash-runner` runs one non-interactive command; interactive commands are out of scope and should not be dispatched.
- **Spill-then-read-back can cost more than the uncapped result.**
  A 6,100-char valid result under a 6,000 cap becomes ~2,000 chars + path; an agent that then `Read`s the file re-ingests it whole plus line-number overhead, a net loss versus the 6,100 inline.
  Mitigation is in the guidance: if this pattern shows up, raise the cap. This is the core reason the recommended start is 6,000, not 4,000.
- **The caller genuinely needs the full raw output later.**
  The runner's report always names the capture file path; the caller reads or greps that file rather than re-running.
- **Binary or very-long-line output.**
  The runner's extraction uses `grep -a` and `cut -c1-N` so a single multi-megabyte line or binary blob does not defeat the bounded extraction.
- **Salient extraction misses the real signal.**
  Haiku misjudging "salient" is a real failure mode; mitigate by having the caller pass an explicit salience spec for high-stakes calls, and by the default heuristic always including exit code and status so a `FAILED` is never hidden even if the specific error line is missed.
- **A command produces almost no output.**
  Dispatch overhead is wasted; the "when to dispatch" convention explicitly excludes short-output commands.
- **Capture file location and lifetime.**
  The capture file lives in the subagent's own scratchpad directory (session-scoped, disposable); it is not a `mktemp` file and not a caller-supplied path, so it is cleaned with the session and needs no explicit teardown.
- **Consumer never runs `/cdocs:init`.**
  Then the settings-cap guidance is never delivered and the floor is absent; the wrapper still works (it is a plugin agent, not a settings dependency). Documented degradation, consistent with cdocs being opt-in per project.

## Test Plan

- **Agent definition parses and loads.**
  `cdocs:bash-runner` appears as a dispatchable agent; frontmatter (`model: haiku`, `tools: Bash`, `maxTurns: 8`) is well-formed.
- **Tool restriction holds.**
  The agent cannot call `Read`/`Write`/`Edit`/`Task` (infrastructure-enforced allowlist).
- **Fixed-format report.**
  A dispatched command returns exactly the `BASH RUNNER REPORT` structure with all fields populated, including the `saved to <path>` line.
- **Salience: explicit spec, line-oriented.**
  Given "return any line matching `error`," a command whose error line is in the middle of long output has that line surfaced (the capture-file `grep` finds it wherever it fell).
- **Salience: explicit spec, aggregate.**
  Given "matches per file, first 3 per file" over a `grep -rn` sweep, the report shows per-file grouping, not a flat head/tail.
- **Salience: default heuristic.**
  With no spec, a `FAILED` command still yields a non-`OK` status and its exit code, even if the specific error line is not extracted.
- **Runner under a low cap (robustness to mechanism 2).**
  With `bashOutputMaxChars` set low, the runner still returns the true last line of `seq 1 200000` - proving the capture-to-file flow is not itself defeated by the ceiling. This is the key test that the two mechanisms compose.
- **Containment (the core claim).**
  See Verification Methodology.
- **Deterministic cap shape.**
  With `bashOutputMaxChars` set low in a test settings file, a direct (non-wrapped) valid command producing >ceiling output yields a `~2,000-char preview + file path` in the model-facing result (not a head/tail clip, and not the full output). A failing >ceiling command yields the head+tail excerpt with no path.
- **`/cdocs:init` guidance delivery.**
  The "Bash output hygiene" section exists in `orchestration-discipline.md`; a test init materializes it (the section text, the recommended value and band, and the tuning caveat are present in the output).
- **Cross-target.**
  The new agent is picked up by `scripts/build-opencode.ts` (which auto-discovers `agents/*.md`); the built OC agent has `bash: true` with `read`/`edit`/`write: false`.

## Verification Methodology

The load-bearing claim is that the wrapper keeps verbose output out of the PARENT context.
Verify it directly with a canary:

1. Pick a command with deterministic, large, countable output, for example `seq 1 200000` (~1.2MB, far above any ceiling) or `yes CANARY_LINE | head -n 100000`.
2. Dispatch it through `cdocs:bash-runner` with a salience spec like "return the exit code and the last line." The runner captures to `<scratchpad>/bash-runner-<ts>.log`, then `tail -n 1` over that file yields the true last line - which it could not have gotten from a spilled preview had it let the command dump to stdout.
3. Confirm the parent transcript contains only the fixed-format `BASH RUNNER REPORT` (command, exit code, status, the last line, and the `saved to <path>` line) - NOT the 100k-200k lines of raw output.
4. Confirm the report's byte size is on the order of the extract (hundreds of chars), not the raw output (~MB).
5. As a negative control, run the same command as a direct `Bash` call in the parent. For a valid command the parent gets a ~2,000-char preview plus a file path (the spill cliff), not the full raw output; what the wrapper saves versus this is the read-back of that file plus the semantic extraction. For a failing command the parent gets the lossy head+tail excerpt with no file - the case the wrapper's capture-with-`2>&1` avoids entirely.
6. For the cap shape: set `bashOutputMaxChars` low, run a >ceiling direct valid command, and confirm the preview+path spill shape (per the Deterministic cap shape test).

The containment check (steps 3-4) plus the runner-under-a-low-cap test are the verification floor: if the parent transcript holds the raw dump, or the runner cannot recover the true last line under a low cap, the wrapper has failed its one job.

## Implementation Phases

Phases 1-2 are the adopt-now core and are largely independent; the two hook mechanisms are deferred, not implemented.

### Phase 1: `cdocs:bash-runner` agent (primary)

- Author `plugins/cdocs/agents/bash-runner.md` modeled on `nit-fix.md` (frontmatter -> Input -> Workflow -> Output Format -> Constraints), `model: haiku`, `tools: Bash`, plus `maxTurns: 8`.
- Implement the capture-to-file-then-extract Workflow (capture into the subagent scratchpad with `> "$OUT" 2>&1; echo "exit=$?"`, then bounded `wc`/`grep`/`head`/`tail`/`cut` over the file).
- Inline the salience/extraction contract (line-oriented and aggregate shapes) and the fixed-format report; no rule-file read.
- Constraints section: run the requested command exactly once; bounded extraction commands over the capture file are expected; no other commands, no re-runs, no onward dispatch. (State this explicitly so a literal-minded haiku agent does not refuse to `grep` its own capture file.)
- Success criteria: Test Plan items "Agent definition parses," "Tool restriction holds," "Fixed-format report," all three salience tests, "Runner under a low cap," and the Verification Methodology containment canary pass.
- Do NOT modify existing agents, `hooks.json`, or the platform default.

### Phase 2: Dispatch convention + model-tiering carve-out + init guidance

- Add the `cdocs:bash-runner` named haiku carve-out to `model-tiering.md` alongside `nit-fix`.
- Add a "Bash output hygiene" section to `orchestration-discipline.md` carrying both the "when to dispatch" convention (sweeps first) and the `bashOutputMaxChars` recommendation (value 6,000, band 4,000-8,000, spill-cliff rationale, read-back tuning caveat, `update-config` snippet, "consumer applies it, plugin does not").
- Success criteria: rule text present and consistent with the frontmatter/writing conventions; the `/cdocs:init` guidance-delivery test passes (the section materializes with no init-skill edit).
- Dependency: independent of Phase 1's code but cites the agent by name, so land after or with Phase 1.
- Do NOT auto-write any consumer `settings.json` value, and do NOT add a new `rules/*.md` file (which would force an init-skill edit).

### Deferred (not phases): the two hook mechanisms

- `PreToolUse` command-rewrite: works on this version but deferred on redundancy/mis-targeting grounds (mechanism 3). Do not implement now.
- `PostToolUse` content-aware truncation: blocked on the `updatedToolOutput` regression (Finding 1). Do not implement. Re-open per the canary trigger in the Deferred section above.
- Phase 2 verification flag: confirm whether `bashOutputMaxChars` also bounds the failure-path head+tail excerpt (the docs say the excerpt is cut from the read-back window, which the setting sizes) and whether the ~2,000-char valid-result preview is fixed or scales with the setting. These do not block Phase 2 but should be checked before the guidance value is finalized.

## Resolved Decisions (round-1 review, 2026-09-23)

The proposal's original open questions are resolved and folded in above; recorded here for traceability against [`cdocs/reviews/2026-09-23-review-of-haiku-bash-wrapper.md`](../reviews/2026-09-23-review-of-haiku-bash-wrapper.md):

- **Q1 tool allowlist:** `Bash`-only stays; `Read` is unnecessary once the runner captures to a file, and rule-loading has no consumer.
- **Q2 init delivery:** document-only, via a section in the existing `orchestration-discipline.md` rather than a new rule file; a consent-gated `settings.json` write is a separate proposal's surface.
- **Q3 mechanism 3:** mechanisms 1+2 suffice; the `PreToolUse` rewrite is deferred because it is redundant and mis-targets the observed whales, not because it is broken (it works here).
- **Q4 cap value:** 6,000 chars (p95 of the measured distribution), tunable band 4,000-8,000.
- **Maintainer decision - capture-file location:** the subagent's own scratchpad directory.
