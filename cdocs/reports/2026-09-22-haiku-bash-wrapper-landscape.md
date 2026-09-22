---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-22T10:30:00-07:00
task_list: meta/token-spend-attribution
type: report
state: live
status: review_ready
tags: [meta, tooling, cost, hooks, context-management]
---

# Haiku Bash-Output Wrapper: Landscape and Design Resolution

> BLUF(sonnet/haiku-bash-wrapper): The PostToolUse truncation hook and the haiku-dispatch wrapper are **not redundant**: they solve different failure modes (deterministic floor on every call vs. opt-in semantic distillation for calls an agent flags as verbose-and-important) and should ship together.
> But the concrete hook design in the prior reports needs revision: Claude Code already truncates Bash output by default (30,000 chars, head+tail preserved), which is far looser than the ~390-tok/result mean driving the 28.5%-of-intake problem, so a useful hook is a *tighter, content-aware* cap, not the mere existence of truncation.
> More importantly, `PostToolUse` `updatedToolOutput` is reported broken for the built-in Bash tool since Claude Code v2.1.163+ ([#68951](https://github.com/anthropics/claude-code/issues/68951), unverified beyond the agent's citation) — the hook fires but the model still sees the original output. This blocks the literal "PostToolUse truncation hook" design as written in the two source reports and must be re-verified before implementation.
> **Recommended shape:** ship the haiku wrapper (`cdocs:bash-runner`, a narrow haiku-tier dispatched agent, modeled on `nit-fix.md`) as the primary mechanism now, paired with a deterministic settings-level floor (`bashOutputMaxChars`/`BASH_MAX_OUTPUT_LENGTH`, tightened well below the 30k default) as the always-on safety net; treat a custom PostToolUse truncation hook as blocked/deferred pending upstream confirmation that `updatedToolOutput` works for Bash again, with a PreToolUse command-rewrite hook as a working interim deterministic lever for known-verbose commands.

## Context / Background

Two prior reports flagged the same problem from different angles:

- [`2026-09-20-read-source-attribution.md`](2026-09-20-read-source-attribution.md) Recommendation 3: Bash command output is 28.5% of read intake (3.76M of 13.17M approx-tokens, 9,581 results, mean 390 tok/result) — "death by a thousand cuts" from many medium-sized results, not a few whales. It proposes routing verbose Bash through a haiku subagent so the raw dump "never enters the parent (Opus) context at all," bounded to the disposable subagent's lifetime rather than resident for the ~299x per-turn re-send amplification the report separately measures.
- [`2026-09-20-token-spend-by-role.md`](2026-09-20-token-spend-by-role.md) action item #5 restates the same proposal and adds: "a PostToolUse hook can additionally do deterministic truncation of Bash output at zero LLM cost as a complement."

Both reports already note, under "Context-management primitives available": "No PreToolUse setting substitutes a subagent's result for a Bash call... A PostToolUse hook can deterministically rewrite or truncate Bash output before the agent reads it (`updatedToolOutput`, Claude Code v2.1.121+), a zero-LLM-cost partial win, but LLM distillation of logspam must be a manual haiku dispatch."

The maintainer's pushback is direct: **if haiku is already going to read and distill the output, why also truncate it via a hook?** This report resolves that question with current platform facts, then gives a concrete, buildable shape for whichever pieces survive.

## Key Findings

### What Claude Code already does, deterministically, today

Findings below come from a dedicated research pass (see Method); items marked *(reported, not independently re-verified in this pass)* rely on that pass's own citations rather than a second fetch.

1. **Claude Code already truncates large Bash output by default.** A hard-coded 30,000-character cap applies before output reaches the model, using **middle-truncation** (head and tail preserved, middle removed), not a dumb head-only cutoff. This is a built-in, zero-configuration floor that already exists — it is not something a hook needs to add from scratch. *(reported, citing [#19901](https://github.com/anthropics/claude-code/issues/19901))*
2. **That default is far too loose to touch the actual problem.** 30,000 chars is roughly 7,500 tokens, ~19x the corpus mean of 390 tok/result. The read-source report's own caveat confirms this empirically: "the raw `stdout`+`stderr` payload... was only ~5% larger than the inline content, so truncation-to-disk is not materially hiding volume in this corpus." In other words, almost nothing in the 3.76M-token Bash bucket is currently being truncated by the platform default — the bucket is dominated by many un-truncated, individually-small-but-collectively-large results, not truncatable giants. A meaningful deterministic lever therefore has to set a *much tighter* cap than the platform default, not merely rely on the default existing.
3. **The cap is configurable via two supported, working mechanisms**, neither of which requires writing a hook: the `BASH_MAX_OUTPUT_LENGTH` env var (up to ~150k char cap on the read-back window), and, as of v2.1.261+, `bashOutputMaxChars` / `taskOutputMaxChars` settings in `settings.json` (up to 128k inline, with excess spilled to a file rather than lost). Both only widen or narrow the existing head/tail cap; neither does content-aware (e.g. preserve-error-line) truncation. *(reported)*
4. **`PostToolUse` `updatedToolOutput` (introduced v2.1.121) is real but reportedly broken for Bash right now.** Schema is `hookSpecificOutput.updatedToolOutput` on the hook's JSON response; documented scope is Bash, Read, Edit, Write, Glob, Grep, and MCP tools, and it is conditionable per-command via the hook's `if`/matcher field. However, [GitHub #68951](https://github.com/anthropics/claude-code/issues/68951) reportedly documents a regression from v2.1.163+ where the hook executes cleanly (exit 0) but the built-in Bash tool's output reaching the model is unchanged — i.e. the exact mechanism the source reports proposed as "a zero-LLM-cost partial win" may not currently work for the one tool this report cares about. **This is unverified beyond the research agent's own citation and must be re-checked against the installed Claude Code version before any implementation depends on it.**
5. **The raw output is not deleted when a hook rewrites it, only the model-facing copy.** Consistent with the read-source report's separate finding that subagent tool results still exist somewhere (subagent transcripts carry ~95% of measured intake) — a hook's rewrite is a visibility change, not a deletion, matching how a haiku wrapper's own subagent transcript still holds the raw dump after the wrapper returns only a summary.
6. **`PreToolUse` hooks are unaffected by the `updatedToolOutput` regression and offer a different, currently-viable lever**: rewriting the *command itself* before execution (e.g. append `| tail -n 50` to a matched command pattern), conditionable via the same `if` matcher syntax. This changes what runs rather than post-processing what ran, so it sidesteps the Bash `updatedToolOutput` bug entirely. *(reported)*
7. **Standard deterministic CLI-shrinking techniques exist and are orthogonal to any hook**: `--quiet`/`-q`, `| tail -n N` / `| head -n N`, structured/summary modes (`--json`, `--porcelain`, `-q` build-tool summaries), `grep -c` for count-only, `2>/dev/null` to drop stderr noise. These are things any command invoker (haiku wrapper or not) should just apply directly; no platform feature is needed for a caller to choose a quieter invocation.

### What this repo already has to build on

8. **`nit-fix.md`** (`plugins/cdocs/agents/nit-fix.md`) is the closest existing template for a narrow, cheap, single-purpose dispatched agent: `model: haiku`, `tools: Read, Glob, Grep, Edit`, a self-loaded rubric, a fixed-format report block, and an explicit "do NOT" constraints section. `judge.md` separately establishes precedent for deliberately omitting the `Task` tool from a dispatched agent's surface ("Do not dispatch subagents. Your toolset omits Task by design"). Both are directly reusable patterns for a bash-wrapper agent definition.
9. **`model-tiering.md`**'s haiku tier is explicitly framed around `nit-fix` as "the canonical case: it is `model: haiku`... These tasks fan out mechanically against a deterministic rubric, so a stronger model buys nothing," under a precedence rule that a consumer's own model floor always wins unless the consumer writes a named carve-out (citing weftwise's `CLAUDE.md` as the model to follow). A bash-wrapper agent should be proposed as exactly that kind of named carve-out, not assumed to override an opus-floor consumer automatically.
10. **The plugin already ships hooks in a known shape**: `plugins/cdocs/hooks/hooks.json` registers a `SessionStart` hook (`npx tsx .../inject-rules.ts`, TypeScript), a `PreToolUse` hook on matcher `"Write|Edit"` (bash script, path-restriction), and a `PostToolUse` hook on matcher `"Write|Edit"` (bash script, frontmatter validation, non-blocking). There is no existing `Bash`-matcher hook; a new one (Pre- or Post-) would be the first of its kind in this plugin but follows an established registration pattern (`${CLAUDE_PLUGIN_ROOT}/hooks/...`, pipe-separated matcher, runtime is either plain bash or `npx tsx`).
11. **`orchestration-discipline.md`**'s fork-vs-specialist distinction is directly citable for the wrapper's disposability contract: "A `fork` subagent is the tool for a side-investigation that needs full parent context WITHOUT growing the parent thread... the fork's context is disposable and ends when the fork completes... distinct from a named specialist... carried across turns." A bash-wrapper dispatch is the same disposability shape applied to a single verbose command rather than a side-investigation.
12. **No standalone proposal or RFP exists yet.** The idea is named as roadmap item "I3: Haiku Bash wrapper + PostToolUse truncate," feeding "RFP-6: Tool-output hygiene and cheap-tier routing" inside `cdocs/reports/2026-09-21-cdocs-context-roadmap-assets/index.html`, but no `cdocs/proposals/*rfp*` or `*bash*` file exists on disk yet. This report is upstream of that gap, not duplicative of it.

## Analysis

### Are the hook and the wrapper solving the same problem?

No. They differ on two independent axes, and each axis leaves a gap the other mechanism does not cover.

**Coverage axis: universal vs. opt-in.**
The hook (or a tightened deterministic cap) fires on every Bash call, regardless of whether the dispatching agent anticipated verbosity. The wrapper only helps when an agent recognizes, *before* running a command, that it is likely to be log-spammy, and deliberately routes it through `cdocs:bash-runner` instead of a direct `Bash` call. Many verbose commands are not anticipated: a first-time invocation of an unfamiliar build script, a `find`/`grep` that turns out to match far more than expected, a linter that unexpectedly emits thousands of warnings, a routine `git log` against a repo with more history than assumed. In all of these the agent reaches for direct `Bash` because it did not know better, and only a universal, zero-decision mechanism (a lower default cap, or a hook) touches that traffic. **This is the core answer to the maintainer's pushback: a hook-only world still needs the wrapper for cases the agent chose correctly to dispatch, and a wrapper-only world still needs a hook (or a tighter default cap) for the cases the agent didn't know to dispatch.**

**Technique axis: blind truncation vs. semantic distillation.**
A deterministic mechanism, however configured, has no understanding of content: it can only apply a byte/line cutoff, optionally content-aware via a fixed pattern (e.g. "always keep lines matching `error|fail|exception`"), but it cannot reliably find "the one line that matters" in an unfamiliar tool's output format. The platform's own default (middle-truncation) is a concrete illustration of the failure mode: an error line that appears in the *middle* of a long build log — neither in the preserved head nor the preserved tail — is exactly the content a naive truncator drops. A haiku dispatch reads the whole raw output once (inside its own disposable context, which is fine: that's where the "death by a thousand cuts" tonnage is supposed to live and die) and can return the one line that actually matters regardless of where in the output it fell. This is the concrete, non-hypothetical case for the wrapper's value even in the presence of a hook: **raw truncation would lose the signal in exactly the build-log-with-a-buried-error scenario that motivated recommendation 3 in the first place.**

**Given the corpus data, does a hook-only approach cover "most of the win"?**
Partially, and cheaply, but it is a floor, not a fix. Since the read-source report's own caveat shows the existing 30k-char default rarely engages (raw payload only ~5% larger than what's already delivered), essentially none of the current 3.76M-token Bash bucket is being shrunk by anything today. A materially tighter default cap (see Concrete Design below) would shrink a real fraction of that 3.76M for zero LLM cost and zero dispatch decisions, which is a legitimate, high-value, low-effort win independent of the wrapper. But it cannot perform the "find the one error line in 400 lines of npm install noise" job a wrapper does, and the corpus gives no per-command size distribution for Bash (unlike the itemized Read-heaviest-sources table), so this report cannot quantify what share of the 28.5% is "genuinely undifferentiated noise, safely cut by any truncation" versus "noise with a needle buried past a naive cutoff." That is a genuine data gap; the recommendation below hedges it by keeping both mechanisms rather than betting on the untested claim that raw truncation alone is sufficient.

**Does a wrapper-only approach leave a gap a hook would catch?**
Yes, and it is the more consequential gap of the two, because it is a behavioral-compliance problem rather than a signal-loss problem. Convention-only dispatch depends on every agent, every time, correctly predicting verbosity before running a command — a prediction that is often wrong precisely in the cases that matter most (the first time a build breaks in an unfamiliar way). A universal deterministic floor does not depend on any agent's judgment being correct in the moment.

### Recommendation: both, with a precise division of labor

- **Deterministic floor (always on, zero LLM cost, catches what the wrapper convention misses):** a tightened Bash output cap, applied via the already-working `bashOutputMaxChars`/`BASH_MAX_OUTPUT_LENGTH` settings rather than a custom `PostToolUse` hook, given the reported Bash-specific `updatedToolOutput` regression. This is the safety net for commands nobody thought to route through the wrapper.
- **Opt-in semantic distillation (deliberate dispatch, for commands an agent expects to be verbose-and-important):** the haiku bash-wrapper (`cdocs:bash-runner`), for cases where a blind cutoff would plausibly cut the signal — build logs, test suites, package installs, linters, `terraform plan/apply`, container builds, wide `find`/`grep` sweeps, `git log -p`.
- **A custom `PostToolUse` truncation hook is deferred, not adopted as written**, pending re-verification that `updatedToolOutput` works for the built-in Bash tool on the Claude Code version actually in use. If a fix lands, the hook upgrades from a blunt cap to content-aware truncation (see policy below) without displacing the wrapper, since the wrapper still owns the "find the buried needle" job a hook cannot do.
- **A `PreToolUse` command-rewrite hook is the interim deterministic lever that is not blocked**, for a short list of known-verbose commands (pattern-matched), appending a `--quiet`/`tail -n`-style suffix before execution. This is strictly weaker than the wrapper (still blind to content, still can lose a mid-output error) but strictly stronger than doing nothing, and it is available today.

## Concrete Design

### The haiku wrapper: `cdocs:bash-runner`

- **New agent file**: `plugins/cdocs/agents/bash-runner.md`, modeled directly on `nit-fix.md`'s shape (frontmatter → Startup → Input → Workflow → Output Format → Constraints).
- **Frontmatter**: `model: haiku`, `tools: Bash` only (no `Read`/`Edit`/`Write`/`Task`, following `judge.md`'s precedent of deliberately narrowing the toolset — this agent runs exactly one command and reports, it does not need to read other files or dispatch further).
- **Input contract**: the dispatching agent's Task prompt supplies the exact command to run, plus (optionally) what "salient" means for this call — e.g. "return the exit code and any line containing `error`/`fail`/`FAIL`," or "return the final summary line and any non-zero exit," or "return the file list, not per-file noise." This mirrors how `nit-fix` is scoped to only the files listed in its prompt.
- **Output contract (fixed-format report, cheap for the parent to parse)**:
  ```
  BASH RUNNER REPORT
  Command: <exact command run>
  Exit code: <n>
  Status: OK | FAILED | WARNINGS
  Salient output (<=N lines):
  <extracted lines, verbatim>
  Full output: <discarded, ~<K> chars> | <saved to <scratchpad-path>, if the parent may need it>
  ```
  The "discarded vs. saved" line matters: per Key Finding 5, the raw output still exists in the wrapper's own subagent transcript even when discarded from the report, so nothing is silently destroyed; the report should say so explicitly rather than imply deletion, and should default to *not* re-saving a second copy unless the caller asked for the artifact.
- **Dispatch scope: opt-in, not general-purpose.** Do not route every Bash call through this agent — dispatch overhead (a subagent round-trip) is not worth it for `git status`, a one-line `ls`, or any command the caller already expects to be short. Document the convention as a short "when to dispatch" list, either as a new short section in `orchestration-discipline.md` (alongside the existing fork-vs-specialist guidance) or as a addition to `model-tiering.md`'s haiku tier examples: build/test/install/lint/plan/apply commands, wide recursive searches, and any command the caller cannot bound in advance (unfamiliar script, unfamiliar repo). This should be written as guidance for agents deciding whether to dispatch, not as a hard rule enforceable by tooling — enforcement is the deterministic floor's job, not the wrapper's.
- **Model-tiering framing**: propose this as a named carve-out in `model-tiering.md` alongside `nit-fix`, not an automatic override — a consumer with a blanket opus floor still needs to explicitly bless the haiku dispatch, per the tiering rule's own precedence language.

### The deterministic floor: settings-level cap, hook deferred

- **Primary mechanism now**: set `bashOutputMaxChars` (or `BASH_MAX_OUTPUT_LENGTH` on older Claude Code versions) well below the 30,000-char platform default. Given the corpus mean of 390 tok (~1,560 chars) per result, a cap in the **4,000-6,000 character range (roughly 1,000-1,500 tokens)** is a reasonable starting point: generous enough not to clip ordinary multi-line output, tight enough to bound the rare outlier that would otherwise dump thousands of lines directly into context. Treat this as a tunable starting value, not a derived optimum — the corpus has no per-call Bash size distribution (unlike the itemized Read-heaviest-sources table), so this number should be revisited once that data exists.
- **Deferred mechanism**: a custom `PostToolUse` hook on matcher `"Bash"` using `hookSpecificOutput.updatedToolOutput`, implementing content-aware truncation rather than a blind cutoff: preserve the first K and last K lines (matching the platform's own head+tail instinct), but *also* pull forward any line matching an error heuristic (`(?i)error|fail(ed)?|exception|traceback|panic|✗`) regardless of where it falls, deduplicated against the head/tail set, with an explicit `[... N lines elided ...]` marker at each cut. This is strictly better than the platform default's plain middle-truncation because it targets the exact "buried error" failure mode identified above. **Gate this on re-verifying [#68951](https://github.com/anthropics/claude-code/issues/68951) is fixed** for the Claude Code version this ships against; if unresolved, ship only the settings-level cap and the `PreToolUse` rewrite hook below, and track the content-aware hook as blocked/future work.
- **Working interim lever**: a `PreToolUse` hook on matcher `"Bash"` with an `if` condition on a short allowlist of known-verbose command patterns (`npm install`, `docker build`, `terraform (plan|apply)`, common linter invocations), appending a quieting suffix (`--quiet`, `| tail -n 100`, or tool-specific structured-output flags) before execution. This is available today, unaffected by the `updatedToolOutput` regression, and requires no new settings.

### Division-of-labor summary

| Mechanism | Fires on | Technique | Cost | Status |
|---|---|---|---|---|
| Platform default (30k char, head+tail) | Every Bash call | Blind, wide | Zero | Already shipped |
| `bashOutputMaxChars`/`BASH_MAX_OUTPUT_LENGTH` tightened | Every Bash call | Blind, tunable | Zero | Working now; recommended near-term floor |
| `PreToolUse` command-rewrite hook | Matched known-verbose commands | Blind, pattern-scoped | Zero | Working now; interim lever |
| `PostToolUse` content-aware truncation hook | Every Bash call (or matched) | Heuristic (error-line-preserving) | Zero | **Blocked** pending [#68951](https://github.com/anthropics/claude-code/issues/68951) re-verification |
| `cdocs:bash-runner` (haiku wrapper) | Deliberately dispatched calls | Semantic (full comprehension) | Small (haiku tokens + round-trip latency) | Buildable now; primary recommendation |

## Method

- Read both source reports in full: [`2026-09-20-read-source-attribution.md`](2026-09-20-read-source-attribution.md) (Recommendation 3, Context-management primitives section) and [`2026-09-20-token-spend-by-role.md`](2026-09-20-token-spend-by-role.md) (action item #5).
- Dispatched two parallel research subagents:
  1. A `claude-code-guide` agent to establish current facts about Claude Code's built-in Bash output handling, the `PostToolUse` `updatedToolOutput` mechanism's exact schema/scope/limitations, and standard deterministic CLI-shrinking techniques. Its findings (default 30k-char cap with middle-truncation, `bashOutputMaxChars`/`BASH_MAX_OUTPUT_LENGTH` settings, the `updatedToolOutput` schema and its reported Bash-specific regression at v2.1.163+) are cited above as **reported**, meaning: the subagent claims to have fetched the cited URLs, but this report's author did not independently re-fetch them in this pass. Treat the regression claim especially as needing re-verification before an implementation depends on it.
  2. An `Explore` agent to survey this repo's existing conventions: `plugins/cdocs/agents/*.md` (agent-definition template), `model-tiering.md`'s haiku tier, the plugin's existing hook registrations (`plugins/cdocs/hooks/hooks.json`), `orchestration-discipline.md`'s fork-vs-specialist language, and a check for any prior report/proposal that already specced this design (found: named as roadmap item I3/RFP-6, not yet a standalone proposal).

## Caveats

- The `PostToolUse`-Bash `updatedToolOutput` regression claim ([#68951](https://github.com/anthropics/claude-code/issues/68951)) is the single most load-bearing fact in this report's recommendation to defer the hook, and it rests on one subagent's citation, not a second independent fetch. **Re-verify this before writing the proposal's implementation plan**, since if it is already fixed, the content-aware `PostToolUse` hook moves from "blocked" to "buildable now" and should be promoted in the proposal.
- This report has no per-call size distribution for the Bash bucket (unlike the Read bucket's itemized heaviest-sources table in the source report), so the tightened-cap starting value (4,000-6,000 chars) and the claim that "most of the 3.76M is many medium calls, not a few whales" rest on the corpus mean (390 tok/result) and the raw-vs-inline-size caveat, not a verified histogram. A future drill (same methodology as the read-source report's reread-waste drill) could tighten this.
- "Standard deterministic CLI-shrinking techniques" (Key Finding 7) are general knowledge, not something either research pass specifically verified against Claude Code's environment; they are included as guidance for what the wrapper's own tool use (and the `PreToolUse` rewrite hook's suffix choices) should apply, not as new platform facts.
