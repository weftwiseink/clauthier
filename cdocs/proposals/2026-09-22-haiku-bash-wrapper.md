---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-22T10:39:14-07:00
task_list: meta/token-spend-attribution
type: proposal
state: live
status: implementation_accepted
last_reviewed:
  status: accepted
  by: "@claude-opus-5-5"
  at: 2026-10-05T10:00:31-07:00
  round: 10
tags: [meta, tooling, cost, hooks, context-management, agents, haiku, sonnet]
---

# Bash-Output Wrapper: `cdocs:bash-runner`

> BLUF(meta/token-spend-attribution): Ship a sonnet-tier `cdocs:bash-runner` agent (`Bash`-only, modeled on `nit-fix.md`) that agents opt into for expected-verbose commands; it captures the command's output to a file in its own scratchpad and returns a fixed-format salient extract, keeping the raw dump out of the parent context.
> Ship it with "when to dispatch" guidance in `orchestration-discipline.md`; unanticipated verbose Bash falls back to the platform default ceiling (~30K chars), an accepted residual risk.
> A settings-level cap (`bashOutputMaxChars`) is DEFERRED to [`2026-10-05-bash-output-cap-rfp.md`](2026-10-05-bash-output-cap-rfp.md); both output-rewriting hooks stay deferred (`updatedToolOutput` is inert for built-in Bash, [#68951](https://github.com/anthropics/claude-code/issues/68951)).

> NOTE(opus-5-5/oversee): Maintainer directive 2026-10-05 removed the `bashOutputMaxChars` settings cap (formerly mechanism 2, "Adopt", delivered as `/cdocs:init` guidance) from shipped scope.
> Rationale: the setting is global, so it also constrains `cdocs:bash-runner`'s own Bash calls (interfering with the mechanism this proposal ships), and it reaches into consumer settings policy.
> The maintainer expects the runner plus its dispatch guidance to be adequate on its own; the cap's measured evidence is retained under [Deferred: settings-level output cap](#deferred-settings-level-output-cap-bashoutputmaxchars) and carried into the follow-up RFP.

> NOTE(opus-5-5/oversee): Maintainer decision 2026-10-05: the runner moves from haiku to `model: sonnet`.
> Rationale: any runner unreliability can negate the savings, through task degradation or fiddly UX for the opus parent; the true cost saving comes from avoiding long-term parent context bloat, not from the cheapest runner model.
> Evidence: the live canaries behind implementation reviews r3-r5 ([`_verify/...-r3.md`](../devlogs/_verify/2026-10-05-bash-runner-live-canary-r3.md), [`-r4.md`](../devlogs/_verify/2026-10-05-bash-runner-live-canary-r4.md), [`-r5.md`](../devlogs/_verify/2026-10-05-bash-runner-live-canary-r5.md)).
> On "summarize" specs, haiku drifted from the fixed report format, echoed prompt example lines as capture output, and fabricated file attributions in a self-composed count line, each surviving a prompt fix aimed at the previous shape.
> The filename and the "haiku" references in history (landscape report, canary procedure, earlier NOTEs) are kept for link stability and traceability.

## Summary

This proposal operationalizes [`cdocs/reports/2026-09-22-haiku-bash-wrapper-landscape.md`](../reports/2026-09-22-haiku-bash-wrapper-landscape.md), which framed the "hook vs. wrapper" question as two failure modes: a universal deterministic floor for unanticipated verbosity, and opt-in semantic distillation for anticipated verbose-and-important calls.
This proposal ships the second; the platform's built-in output ceiling is the only floor for the first, and a tighter settings-level floor is scoped separately by the follow-up RFP.

The design rests on three canary-verified platform facts on Claude Code 2.1.280 (see [Verification of the Load-Bearing Hook Claim](#verification-of-the-load-bearing-hook-claim)):

- `PostToolUse` `updatedToolOutput` is inert for the built-in Bash tool, so a custom content-aware truncation hook is not buildable and stays deferred.
- The Bash output ceiling (platform default ~30,000 chars, configurable via `bashOutputMaxChars`) is a spill-to-file cliff, not a head/tail clip: a valid over-ceiling result collapses to a file path plus a ~2,000-char preview, and only a failed command yields a lossy head+tail excerpt.
- That ceiling applies to the runner's own Bash call, so the runner cannot "read the whole output once." It captures the command's output to a file, then reads from that file in pieces that each stay under the ceiling.

The shape:

- `cdocs:bash-runner` (new `plugins/cdocs/agents/bash-runner.md`, `model: sonnet`, `tools: Bash`) is the primary, buildable-now mechanism. It captures-to-file-then-extracts.
- A "Bash output hygiene" section in `orchestration-discipline.md` carries the when-to-dispatch convention (sweeps first) and ships to consumers via `/cdocs:init`.
- A tightened `bashOutputMaxChars` cap is DEFERRED to the follow-up RFP: it is global (it would also cap the runner's own Bash) and is consumer settings policy.
- The custom content-aware `PostToolUse` hook is DEFERRED, gated on the `updatedToolOutput` regression being fixed for built-in Bash.
- A `PreToolUse` command-rewrite hook is also DEFERRED, not because it fails (it works on this version) but because its pattern allowlist mis-targets the observed heavy traffic and a mature external tool (rtk) owns that niche.

## Objective

Bash command output is 28.5% of read intake per [`cdocs/reports/2026-09-20-read-source-attribution.md`](../reports/2026-09-20-read-source-attribution.md) (3.76M of 13.17M approx-tokens, 9,581 results, mean 390 tok/result): "death by a thousand cuts" from many medium-sized results, amplified by the report's separately-measured per-turn re-send factor.
The goal is to keep verbose Bash output out of the parent (Opus) context: distilled to a salient extract when an agent anticipates verbosity.
Unanticipated verbosity stays bounded only by the platform default ceiling; tightening that bound is out of scope here (see the follow-up RFP).

## Background

- The landscape report [`cdocs/reports/2026-09-22-haiku-bash-wrapper-landscape.md`](../reports/2026-09-22-haiku-bash-wrapper-landscape.md) is the direct predecessor and settles the design questions this proposal builds on.
  Read its "Concrete Design" and "Division-of-labor summary" sections first.
- The two source reports that raised the problem: [`2026-09-20-read-source-attribution.md`](../reports/2026-09-20-read-source-attribution.md) (Recommendation 3) and [`2026-09-20-token-spend-by-role.md`](../reports/2026-09-20-token-spend-by-role.md) (action item #5).
- The round-1 review [`cdocs/reviews/2026-09-23-review-of-haiku-bash-wrapper.md`](../reviews/2026-09-23-review-of-haiku-bash-wrapper.md) supplies the canary verification, the measured per-call Bash size distribution (its Appendix), and the four resolved design questions folded into this revision.
- Existing agent template: [`plugins/cdocs/agents/nit-fix.md`](../../plugins/cdocs/agents/nit-fix.md) (haiku, narrow tool allowlist, fixed-format report, explicit Constraints).
- Precedent for deliberately omitting `Task` and for a `maxTurns` bound on a dispatched agent: `plugins/cdocs/agents/judge.md`.
- Model-tiering carve-out mechanics (consumer floor wins; adopt via named carve-out): [`plugins/cdocs/rules/model-tiering.md`](../../plugins/cdocs/rules/model-tiering.md).
- Existing hook registration shape: [`plugins/cdocs/hooks/hooks.json`](../../plugins/cdocs/hooks/hooks.json) (SessionStart, `PreToolUse`/`PostToolUse` on matcher `Write|Edit`; no `Bash`-matcher hook exists yet).

> NOTE(meta/token-spend-attribution): A parallel sonnet report on whether existing tooling (for example `rtk-ai/rtk`) could replace or complement a bespoke `cdocs:bash-runner` landed as [`cdocs/reports/2026-09-23-bash-output-tooling-landscape.md`](../reports/2026-09-23-bash-output-tooling-landscape.md) and was folded into round 2. The correctness fixes here apply regardless: even a wrapped external tool, if it is Bash-only under the hood, hits the same spill ceiling and needs the same capture-to-file-then-extract flow.

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
The core design (the runner wrapper) depends on neither rewrite channel, so it is robust to the environment-dependent hook behavior.
The custom `PostToolUse` content-aware hook is deferred on Finding 1 (genuinely inert).
A `PreToolUse` rewrite hook is deferred on mis-targeting grounds (see its Deferred section), not on breakage.

## Proposed Solution

One adopted mechanism (the sonnet runner plus its dispatch convention) and three deferred ones, mirroring the landscape report's "Division-of-labor summary" table with the corrections above.

### 1. `cdocs:bash-runner` sonnet agent (primary, works now)

A new dispatched agent at `plugins/cdocs/agents/bash-runner.md`, modeled structurally on `nit-fix.md`: frontmatter, Input, Workflow, Output Format, Constraints.

**Frontmatter.**
`model: sonnet`, `tools: Bash` only, plus `maxTurns: 12` (bounding a runner that could loop on extraction, following `judge.md`'s `maxTurns: 10` precedent; 12 covers capture plus several iterative targeted reads plus the report, with headroom).
No `Read`/`Edit`/`Write`/`Task`: this agent runs one requested command plus read-only extraction over its capture file, and reports.
Omitting `Task` prevents onward dispatch; omitting `Write`/`Edit` keeps it inert on the filesystem beyond its scratch capture file.
The `Bash`-only allowlist survives the OpenCode build: `scripts/build-opencode.ts` `mapTools` turns `tools: Bash` into `bash: true` with `read`/`edit`/`write: false`.

**No rule-reading Startup.**
Unlike `nit-fix`, this agent reads no rule files: it emits a fixed-format block and enforces no writing convention, so loading `writing-conventions.md`/`frontmatter-spec.md` would cost 2-3k runner input tokens per dispatch for zero output effect.
`nit-fix` reads rules because rules ARE its rubric; that does not transfer here.
The extraction contract is inlined in the agent prompt.

**Input contract.**
The dispatching agent's Task prompt supplies:
1. the exact command to run, and
2. optionally, what "salient" means for this call.
Salience specs come in two shapes:
- line-oriented, for pass/fail commands: "return the exit code and any line matching `error`/`fail`/`FAIL`"; "return the final summary line plus any non-zero exit".
- aggregate, for sweeps where the matches ARE the signal: "matches per file, first 3 per file"; "the changed-file list plus per-file hunk counts"; "the file list, not per-file progress noise".
Absent an explicit salience spec, the agent applies a default heuristic (exit code, status classification, error-matching lines, plus the tail and head).
This mirrors how `nit-fix` is scoped only to the files named in its prompt.

**Workflow: capture-to-file-then-extract.**
The Bash output ceiling applies to the runner's own Bash tool call, so the runner must not let a command's output flow to stdout directly (it would spill to a preview the runner cannot fully read).
Instead:
1. Run the requested command with capture into the runner's own scratchpad directory:
   `OUT="<scratchpad>/bash-runner-<ts>.log"; <cmd> > "$OUT" 2>&1; echo "exit=$?"`.
   The runner's tool result is then tiny (`exit=<n>`), and the full output is always on disk regardless of the command's exit status - which also means the platform's lossy failure-path excerpt never applies to this output.
2. Read the capture file with judgment, sized by the Step 1 byte and line counts: a small capture (about what a direct Bash call would have shown) may be read whole; a larger one is read in targeted, iterative steps (`grep -a` with context, `sed -n` ranges, `head`/`tail`, `awk` aggregation), each kept under the ceiling, with `cut -c1-N` guarding very long lines.
3. Classify status as `OK`/`FAILED`/`WARNINGS` and return the fixed-format report.

**Output contract (fixed-format, cheap for the parent to parse).**

```
BASH RUNNER REPORT
Command: <exact command run>
Exit code: <n>
Status: OK | FAILED | WARNINGS
Summary:
<1-3 lines, the runner's interpretation; names and numbers grounded in the capture>
Excerpt:
<a few short verbatim lines, cut by a command and copied from its output>
Truncated: none | <what was omitted>; see: <follow-up command over the capture file>
Full output: saved to <scratchpad-path> (<K> chars)
```

The whole report stays under about 4,000 characters.
`Summary:` gives the runner a sanctioned place for interpretation, so it does not leak prose elsewhere; `Excerpt:` stays few and short so verbatim copying stays accurate.
For aggregate specs, `Excerpt:` is the whole output of two bounded commands, pasted unedited: one counting command (at most 20 lines) and one sampling command (at most 12 lines of at most 120 chars). Composed or heading lines go in `Summary:`, any total there comes from a command, and the report stays under ~4K by construction. `Truncated: none` is used only when everything the spec asked for is present.

The `saved to` line is the default and is load-bearing: the capture file is the primary artifact, not a copy, so nothing is silently destroyed.
State the path and its lifetime (the subagent's scratchpad directory, which is session-scoped and disposable).
The parent receives only the report; the raw output lives in the capture file and, at most, in the runner's own disposable context, so it never enters the parent context.

> NOTE(opus-5-5/oversee): Maintainer steer 2026-10-05: the runner's methodology should be no more constrained than the parent running Bash directly, since the cheaper model is the main saving.
> Runner-internal results cost only haiku context, never the parent's, and the cap that would have motivated tight internal bounds is deferred to the RFP.
> So internal reads are judgment-driven (small captures read whole, larger ones read iteratively), while capture-first, the one-line `exit/out/bytes/lines/warn` summary, and the concise fixed-format report stay mandatory.
> (The "cheaper model is the main saving" premise is superseded by the 2026-10-05 sonnet NOTE above; the relaxed-reading conclusion stands.)

> NOTE(opus-5-5/oversee): Maintainer-approved report contract v2, 2026-10-05: `Summary:` (interpretation) plus `Excerpt:` (few short verbatim lines) replace a single verbatim `Salient output:` block.
> Evidence: the r6 live canaries ([`_verify/...-r6.md`](../devlogs/_verify/2026-10-05-bash-runner-live-canary-r6.md)): sonnet kept adding prose despite a ban, and retyping ~50 long lines in 8.6-10KB sweep reports drifted the content of a few. v2 sanctions the prose and keeps the verbatim part small enough to copy accurately.

**Dispatch scope: opt-in, documented convention, not a hard rule.**
Do not route every Bash call through this agent: a subagent round-trip is not worth it for `git status`, a one-line `ls`, or any command the caller already expects to be short.
Dispatch when a command is expected to be verbose-and-important, ordered by the observed heavy traffic (the 15 largest Bash results in the corpus, all 22k-29k chars, are sweeps, not builds):
- wide recursive searches and diffs: `grep -rn` sweeps, `find`, `git diff`, multi-file `cat` loops (`for f in ...; do cat "$f"; done`).
- build logs, test suites, package installs (`npm install`), linters, `terraform plan`/`apply`, container builds, `git log -p`.
- any command whose output the caller cannot bound in advance (an unfamiliar script, an unfamiliar repo).
This is guidance for an agent's dispatch decision, not something tooling enforces; the unanticipated case falls to the platform default ceiling, an accepted residual risk (see the coverage table under the `PreToolUse` deferral).

**Model-tiering framing.**
Add `cdocs:bash-runner` as a named example in [`model-tiering.md`](../../plugins/cdocs/rules/model-tiering.md)'s "Search / Explore / Research-Aggregation Tier (sonnet)", with the rationale that verbatim-extraction fidelity matters more than the runner's own price.
Frame it as a carve-out a consumer must bless, not an automatic override: a consumer with a blanket opus floor still needs to explicitly opt this dispatch down to sonnet, per the rule's Precedence language.
The dispatch-decision convention (the "when to dispatch" list above) belongs in a new "Bash output hygiene" section in [`orchestration-discipline.md`](../../plugins/cdocs/rules/orchestration-discipline.md), alongside the existing fork-vs-specialist disposability guidance, since a bash-runner dispatch is the same disposable-context shape applied to a single command.

### Deferred: settings-level output cap (`bashOutputMaxChars`)

Tightening the built-in Bash output ceiling below the ~30,000-char platform default via `bashOutputMaxChars` (settings, v2.1.261+, up to 128,000) is the zero-LLM-cost floor for unanticipated verbosity.
It is DEFERRED to [`2026-10-05-bash-output-cap-rfp.md`](2026-10-05-bash-output-cap-rfp.md) (maintainer, 2026-10-05) on two grounds:

- **Runner interference.** The setting is global: it bounds `cdocs:bash-runner`'s own Bash calls as well as the parent's. The runner's capture-to-file design keeps its capture call tiny, but its extraction outputs sit under the same ceiling, so a tight cap constrains the very mechanism this proposal ships. How the two compose is the RFP's central question.
- **Invasiveness.** A plugin cannot write a consumer's `settings.json`, and an output cap is consumer settings policy, not a plugin default. The runner plus dispatch guidance may be adequate alone; post-ship usage data should decide.

Evidence carried into the RFP (measured, not re-derived there):

- **Spill-cliff semantics.** Valid result: inline up to the ceiling, past it a file path plus a ~2,000-char preview. Failure result: inline up to ~10,000, past it a head+tail excerpt with no path. `bashOutputMaxChars` sizes the inline ceiling and the read-back window together and overrides `BASH_MAX_OUTPUT_LENGTH`.
- **Per-call distribution** (11,531 Bash results, weftwise transcripts 2026-09-12 onward; method in the round-1 review's Appendix): p50 655, p90 3,978, p95 6,228, p99 14,103, max 29,351 chars. The candidate value was 6,000 (~p95, spilling 606 results), band 4,000-8,000.
- **Read-back cliff.** A spilled valid result is a read-back candidate that re-ingests the whole output plus line-number overhead; a 6,100-char result under a 6,000 cap costs more than it saved if read back. This is why the candidate sat mid-band, not at 4,000.
- **Unverified.** Whether the setting also bounds the failure-path head+tail excerpt, and whether the ~2,000-char preview is fixed or scales with the setting.

### Deferred: `PreToolUse` command-rewrite hook (works here, not adopted)

A `PreToolUse` Bash hook using `updatedInput` to append a quieting suffix (`--quiet`, `| tail -n N`, structured-output flags) to a matched command works on this version (Finding 2).
It is nonetheless deferred, on coverage grounds rather than breakage:

- It does not close the residual gap. The coverage table (using the real spill-to-file semantics):

  | Case | Covered by | Outcome |
  |---|---|---|
  | Anticipated verbose, dispatched | Runner | Parent sees the fixed-format report only |
  | Unanticipated verbose, exit 0 | Platform default (~30K ceiling) | Inline up to ~30K chars; past it, ~2k preview + file path, recoverable via read-back |
  | Unanticipated verbose, non-zero exit | Platform default (~10K failure ceiling) | Inline up to ~10K; past it, a head+tail excerpt with no path; a mid-log error CAN be lost; recovery is a re-run through the runner |

  Rows 2-3 are the accepted residual risk: an undispatched verbose call can still land up to ~30K chars in the parent (the corpus max is 29,351, so in practice nearly every observed whale lands inline in full). The deferred cap RFP is the lever for tightening that bound; a rewrite hook is not, since it fires only on a fixed pattern allowlist and the observed whales are not on any plausible allowlist.
- It mis-targets the traffic. The 15 heaviest Bash results are `git diff`, `grep -rn` sweeps, `find`, and multi-`cat` loops - not `npm install`, `docker build`, or `terraform`. A blind `| tail` on a `grep` sweep destroys the signal (the matches ARE the output), so even a working rewrite is a poor fit for what actually dominates.
- A mature off-the-shelf tool already owns this niche better than a bespoke allowlist would. The tooling landscape report [`cdocs/reports/2026-09-23-bash-output-tooling-landscape.md`](../reports/2026-09-23-bash-output-tooling-landscape.md) found [`rtk-ai/rtk`](https://github.com/rtk-ai/rtk) (Apache-2.0, a Rust `PreToolUse` command-rewrite proxy) deterministically compresses 100+ known dev commands - including exactly the `git diff`/`grep`/`find`/`cat`-sweep shapes that dominate this corpus - with per-command filter/group/dedup pipelines a hand-written allowlist cannot match. A consumer who wants the deterministic-rewrite lever is better served pointing at rtk than by cdocs shipping a bespoke hook; that report recommends against adopting rtk as a plugin dependency (pre-1.0, RC-heavy, CLI-only) but confirms building a competing allowlist is not worth it.

If a future need arises (a specific known-verbose command a team runs constantly, or a consumer opting into rtk-style rewriting), this hook is the lever; re-verify the channel with the canary first, since its behavior is environment-dependent.

### Deferred: custom content-aware `PostToolUse` hook

A `PostToolUse` hook on matcher `Bash` using `hookSpecificOutput.updatedToolOutput` to do content-aware truncation - preserve head/tail K lines AND pull forward any error-matching line regardless of position, with `[... N lines elided ...]` markers - is the ideal deterministic mechanism.
It is DEFERRED because `updatedToolOutput` is inert for built-in Bash (Finding 1).

**Trigger to pick it back up:** re-run the hook-channel canary (round-1 review Appendix; returns a sentinel replacement and checks whether the model sees the sentinel). When a Claude Code release makes `updatedToolOutput` apply to the built-in Bash tool - watch [#68951](https://github.com/anthropics/claude-code/issues/68951) and [#32105](https://github.com/anthropics/claude-code/issues/32105) - this hook becomes buildable and upgrades the platform-default ceiling from a blind spill-cliff to content-aware truncation, without displacing the wrapper (which still owns the "find the buried needle" job).
Until then, track as blocked/future work; do not implement.

### Division-of-labor summary

| Mechanism | Fires on | Technique | Cost | Status |
|---|---|---|---|---|
| Platform default (~30k valid / ~10k failure ceiling) | Every Bash call | Blind spill-to-file (valid) / head+tail excerpt (failure) | Zero | Already shipped upstream |
| `cdocs:bash-runner` (sonnet wrapper) | Deliberately dispatched calls | Semantic (capture-to-file, then judgment-driven extraction) | Small (sonnet tokens + round-trip) | **Adopt** (primary, with dispatch guidance) |
| `bashOutputMaxChars` tightened | Every Bash call (including the runner's own) | Blind, tunable spill cliff | Zero | **Deferred** to [the cap RFP](2026-10-05-bash-output-cap-rfp.md) - global (interferes with the runner), consumer settings policy |
| `PreToolUse` command-rewrite (`updatedInput`) | Matched known-verbose commands | Blind, pattern-scoped rewrite | Zero | Works here (2.1.280 Linux headless, 2/2); **deferred** - allowlist misses observed whales; rtk owns the niche |
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
  Round-trip overhead makes universal routing a net loss; the unanticipated case opt-in dispatch misses is left to the platform default ceiling as an accepted residual risk.
- **Settings-level cap deferred, not shipped (maintainer, 2026-10-05).**
  The cap is global, so it would also bound the runner's own extraction calls; it is consumer settings policy; and the runner plus dispatch guidance is expected to suffice. Shipping it would pre-empt the usage data that should decide whether it is needed. See the follow-up RFP.
- **Dispatch guidance in an existing rule file, not a new rule file.**
  `/cdocs:init` enumerates rule files by name for its `AGENTS.md` block, so a new section in `orchestration-discipline.md` rides the existing materialization pipeline and hash marker with zero init changes.
- **Semantic distillation is not redundant with a blind ceiling.**
  The platform's blind ceiling loses signal in two ways the wrapper does not: a failed verbose command yields a lossy head+tail excerpt with no file (the middle is unrecoverable without a re-run), and a valid one puts the middle on disk at the cost of a read-back that re-ingests it whole.
  The runner captures the whole output to its scratch file and reads it with targeted shell (a `grep` over the file finds a buried error wherever it fell, and per-file aggregation is available for a sweep where a head/tail excerpt is the wrong default), so the salient signal reaches the parent without the raw dump - all in disposable context.
- **No dependency on either rewrite hook channel.**
  The design does not use `updatedInput` or `updatedToolOutput` for Bash, so it is robust to their environment-dependent and regressed behavior respectively.

## Edge Cases / Challenging Scenarios

- **The command needs interactivity or a TTY.**
  `cdocs:bash-runner` runs one non-interactive command; interactive commands are out of scope and should not be dispatched.
- **Unanticipated verbose output in the parent.**
  An agent that does not dispatch a verbose command gets up to ~30K chars inline (or a lossy head+tail excerpt past ~10K on failure). Accepted residual risk; the deferred cap RFP is the remedy if post-ship data shows it matters.
- **Consumer has set `bashOutputMaxChars` themselves.**
  The runner's capture call returns only a one-line summary, and its reads are sized to stay under the ceiling and narrowed when one spills, so it should tolerate a tightened ceiling at the cost of more read turns; a very low cap would force many small reads. Not tested in this scope; the composition question belongs to the cap RFP.
- **The caller genuinely needs the full raw output later.**
  The runner's report always names the capture file path; the caller reads or greps that file rather than re-running.
- **Binary or very-long-line output.**
  The runner's extraction uses `grep -a` and `cut -c1-N` so a single multi-megabyte line or binary blob does not fill a read result.
- **Salient extraction misses the real signal.**
  The runner misjudging "salient" is a real failure mode; mitigate by having the caller pass an explicit salience spec for high-stakes calls, and by the default heuristic always including exit code and status so a `FAILED` is never hidden even if the specific error line is missed.
- **A command produces almost no output.**
  Dispatch overhead is wasted; the "when to dispatch" convention explicitly excludes short-output commands.
- **Capture file location and lifetime.**
  The capture file lives in the subagent's own scratchpad directory when its environment lists one (session-scoped, disposable); it is not a `mktemp` file and not a caller-supplied path.
  When no scratchpad is listed, the runner falls back to `${TMPDIR:-/tmp}`, where the file persists until reboot; the report's lifetime phrase says which applies, and the caller may delete a `/tmp` capture.

  > NOTE(opus-5-5/impl-1): Deviation recorded during implementation: under headless `claude -p`, no scratchpad appears in the runner's environment, so every live canary run wrote to `/tmp` via the fallback.
  > Interactive sessions do list a subagent scratchpad. `/tmp` accumulation is accepted for now (tmpfs clears on reboot); automatic cleanup is out of scope.
- **Consumer never runs `/cdocs:init`.**
  Then the "Bash output hygiene" dispatch guidance is never materialized, so agents dispatch the runner only when explicitly prompted to; the runner itself still works (it is a plugin agent, not a settings or rule dependency). Documented degradation, consistent with cdocs being opt-in per project.

## Test Plan

- **Agent definition parses and loads.**
  `cdocs:bash-runner` appears as a dispatchable agent; frontmatter (`model: sonnet`, `tools: Bash`, `maxTurns: 12`) is well-formed.
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
- **Runner above the platform ceiling.**
  The runner returns the true last line of `seq 1 200000` (~1.2MB, far above the ~30K default ceiling), proving the capture-to-file flow is not itself defeated by the ceiling on its own Bash call. Covered by the Verification Methodology canary.
- **Containment (the core claim).**
  See Verification Methodology.
- **`/cdocs:init` guidance delivery.**
  The "Bash output hygiene" section exists in `orchestration-discipline.md`; a test init materializes it (the when-to-dispatch convention, sweeps first, is present in the output) and it contains no `bashOutputMaxChars` recommendation.
- **Cross-target.**
  The new agent is picked up by `scripts/build-opencode.ts` (which auto-discovers `agents/*.md`); the built OC agent has `bash: true` with `read`/`edit`/`write: false`.

## Verification Methodology

The load-bearing claim is that the wrapper keeps verbose output out of the PARENT context.
Verify it directly with a canary:

1. Pick a command with deterministic, large, countable output, for example `seq 1 200000` (~1.2MB, far above any ceiling) or `yes CANARY_LINE | head -n 100000`.
2. Dispatch it through `cdocs:bash-runner` with a salience spec like "return the exit code and the last line." The runner captures to `<scratchpad>/bash-runner-<ts>.log`, then `tail -n 1` over that file yields the true last line - which it could not have gotten from the platform's spilled preview had it let the command dump to stdout.
3. Confirm the parent transcript contains only the fixed-format `BASH RUNNER REPORT` (command, exit code, status, the last line, and the `saved to <path>` line) - NOT the 100k-200k lines of raw output.
4. Confirm the report's byte size is on the order of the extract (hundreds of chars), not the raw output (~MB).
5. As a negative control, run the same command as a direct `Bash` call in the parent. For a valid command the parent gets a ~2,000-char preview plus a file path (the platform-default spill cliff), not the full raw output; what the wrapper saves versus this is the read-back of that file plus the semantic extraction. For a failing command the parent gets the lossy head+tail excerpt with no file - the case the wrapper's capture-with-`2>&1` avoids entirely.
The containment check (steps 2-4) is the verification floor: if the parent transcript holds the raw dump, or the runner does not return the true last line, the wrapper has failed its one job.

## Implementation Phases

Phases 1-2 are the adopt-now core and are largely independent; the settings cap and the two hook mechanisms are deferred, not implemented.

### Phase 1: `cdocs:bash-runner` agent (primary)

- Author `plugins/cdocs/agents/bash-runner.md` modeled on `nit-fix.md` (frontmatter -> Input -> Workflow -> Output Format -> Constraints), `model: sonnet`, `tools: Bash`, plus `maxTurns: 12`.
- Implement the capture-to-file-then-extract Workflow (capture into the subagent scratchpad with `> "$OUT" 2>&1; echo "exit=$?"`, then judgment-driven `grep`/`sed`/`head`/`tail`/`awk`/`cut` reads over the file).
- Inline the salience/extraction contract (line-oriented and aggregate shapes) and the fixed-format report; no rule-file read.
- Constraints section: run the requested command exactly once; read-only extraction commands over the capture file are expected; no other commands, no re-runs, no onward dispatch. (State this explicitly so a literal-minded agent does not refuse to `grep` its own capture file.)
- Success criteria: Test Plan items "Agent definition parses," "Tool restriction holds," "Fixed-format report," all three salience tests, "Runner above the platform ceiling," and the Verification Methodology containment canary pass.
- Do NOT modify existing agents, `hooks.json`, or the platform default.

### Phase 2: Dispatch convention + model-tiering carve-out

- Add `cdocs:bash-runner` to `model-tiering.md`'s sonnet tier as a named carve-out.
- Add a "Bash output hygiene" section to `orchestration-discipline.md` carrying the "when to dispatch" convention (sweeps first, then builds/tests/installs, then unboundable commands; skip short-output commands), framed as the same disposable-context shape as the fork-vs-specialist guidance.
- Success criteria: rule text present and consistent with the frontmatter/writing conventions; the `/cdocs:init` guidance-delivery test passes (the section materializes with no init-skill edit).
- Dependency: independent of Phase 1's code but cites the agent by name, so land after or with Phase 1.
- Do NOT add any `bashOutputMaxChars` recommendation or `settings.json` snippet (deferred to the cap RFP), and do NOT add a new `rules/*.md` file (which would force an init-skill edit).

### Deferred (not phases)

- Settings-level cap (`bashOutputMaxChars`): deferred to [`2026-10-05-bash-output-cap-rfp.md`](2026-10-05-bash-output-cap-rfp.md), which also carries the open verification questions (failure-excerpt bounding, preview scaling). Do not implement.
- `PreToolUse` command-rewrite: works on this version but deferred on mis-targeting grounds. Do not implement now.
- `PostToolUse` content-aware truncation: blocked on the `updatedToolOutput` regression (Finding 1). Do not implement. Re-open per the canary trigger in the Deferred section above.

## Resolved Decisions (round-1 review, 2026-09-23)

The proposal's original open questions are resolved and folded in above; recorded here for traceability against [`cdocs/reviews/2026-09-23-review-of-haiku-bash-wrapper.md`](../reviews/2026-09-23-review-of-haiku-bash-wrapper.md):

- **Q1 tool allowlist:** `Bash`-only stays; `Read` is unnecessary once the runner captures to a file, and rule-loading has no consumer.
- **Q2 init delivery:** document-only, via a section in the existing `orchestration-discipline.md` rather than a new rule file; a consent-gated `settings.json` write is a separate proposal's surface.
- **Q3 mechanism 3:** the `PreToolUse` rewrite is deferred because it mis-targets the observed whales, not because it is broken (it works here).
- **Q4 cap value (carried to the RFP, not shipped):** 6,000 chars (p95 of the measured distribution), tunable band 4,000-8,000, as the RFP's starting point.
- **Maintainer decision - capture-file location:** the subagent's own scratchpad directory, with a `${TMPDIR:-/tmp}` fallback when none is listed (see the "Capture file location and lifetime" edge case).
- **Maintainer decision (2026-10-05) - settings cap deferred:** the `bashOutputMaxChars` cap leaves shipped scope for [`2026-10-05-bash-output-cap-rfp.md`](2026-10-05-bash-output-cap-rfp.md). Q2 governs only the dispatch-guidance carrier; Q4's value is carried into the RFP as a starting point, not a shipped recommendation.
