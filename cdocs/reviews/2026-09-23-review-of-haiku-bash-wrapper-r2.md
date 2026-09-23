---
review_of: cdocs/proposals/2026-09-22-haiku-bash-wrapper.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-23T10:37:20-07:00
task_list: meta/token-spend-attribution
type: review
state: live
status: done
tags: [fresh_agent, rereview_agent, runtime_validated, architecture, verification, test_plan, tooling, context-management]
---

# Review: Haiku Bash-Output Wrapper: `cdocs:bash-runner` + Deterministic Floor (Round 2)

> BLUF(opus/haiku-bash-wrapper-r2): **Accept.**
> All three round-1 blocking items are resolved, and I verified the load-bearing one empirically: the capture-to-file-then-extract flow genuinely contains a 1.3MB `seq 1 200000` (capture-step tool result is `exit=0`, `tail -n 1` recovers `200000`), so the containment claim holds in fact, not just in prose.
> The hook facts, cap semantics, and runner design are now internally consistent across BLUF, Summary, Findings, Design Decisions, Edge Cases, Test Plan, and the division-of-labor table, and the three maintainer decisions are applied as firm choices.
> On the new tooling report: I independently concur that build-is-right for mechanism 1 and that rtk should not be a dependency, but I reach it by a sharper route than the report does (an rtk pre-filter is semantically incompatible with the caller-steerable-salience contract for exactly the whale traffic, which is a stronger reason than the report's supply-chain framing).
> Remaining items are non-blocking nits to fold in on this accepting round: `omitClaudeMd` is an unverified frontmatter field with no repo precedent; `maxTurns` is referenced but never given a value; one Design-Decisions sentence still says the runner "reads the whole output once," in mild tension with the corrected model; and the report's optional rtk citation in mechanism 3 is worth taking.

## Round-1 Blocking Items: Verification

I formed the assessment above before reading [`cdocs/reviews/2026-09-23-review-of-haiku-bash-wrapper.md`](2026-09-23-review-of-haiku-bash-wrapper.md), then read it only to confirm its three blocking items landed. They did.

### B1 (hook facts) - RESOLVED, consistent everywhere

The corrected fact (`PostToolUse` `updatedToolOutput` inert for built-in Bash; `PreToolUse` `updatedInput` works on 2.1.280 Linux headless, 2/2; rewrite hook deferred on redundancy/mis-targeting, not breakage) is now stated consistently in all five places round 1 flagged:

- BLUF (lines 21): both facts, deferral reason is "redundant with mechanisms 1+2 and mis-targets."
- Summary (lines 29, 37-38): matches.
- Verification section, Findings 1-4 (lines 64-82): Finding 1 inert `PostToolUse`, Finding 2 working `PreToolUse` with the 2/2 transcript detail and the environment-dependence caveat, Finding 3 version scope, Finding 4 residual working channels.
- Division-of-labor table (line 223): the `PreToolUse` row reads "Works here (2.1.280 Linux headless, 2/2); **deferred** - redundant with 1+2, allowlist misses observed whales."
- Mechanism 3 section (lines 190-206): deferred "on coverage grounds rather than breakage."

I grepped for residual stale phrasings (`both.*inert|dead|broken`, `head/tail cap`, `middle-truncat`). The only "both hook channels" hit (line 62) is the canary description, which is correct. No stale claim survives. The `not because it fails (it works here)` framing is present and correct in the Summary, mechanism 3, and Design Decisions. Nothing missed.

### B2 (cap semantics) - RESOLVED

Mechanism 2 (lines 156-163) now describes the spill-to-file cliff correctly: valid over-ceiling result collapses to file path plus a ~2,000-char preview; only a failure result gives a lossy head+tail excerpt with no path; `bashOutputMaxChars` sizes the inline ceiling and the read-back window together and makes Claude Code ignore `BASH_MAX_OUTPUT_LENGTH`.
The consequences propagated cleanly: the Design Decisions "not redundant" bullet (lines 240-242) states the two distinct loss modes, the Edge Cases add spill-then-read-back (lines 250-252), and the Test Plan "Deterministic cap shape" asserts preview+path (line 285), not truncation.
The Phase-2 verification flag (line 330) correctly carries the two open measurement questions (whether the setting also bounds the failure-path excerpt, and whether the ~2k preview is fixed or scales) forward as non-blocking checks.

### B3 (runner design) - RESOLVED, and I confirmed the fix actually works

The three sub-questions the task posed:

- **Workflow is capture-to-file-then-extract** (lines 118-125): `<cmd> > "$OUT" 2>&1; echo "exit=$?"` into the subagent scratchpad, then bounded `wc`/`grep ... | head`/`tail`/`head`/`cut` over the file. Not "run and read the whole output."
- **Output contract default reflects `saved to <path>`** (lines 136, 139): the `Full output: saved to <scratchpad-path> (<K> chars)` line is present and flagged load-bearing.
- **Constraints permit the bounded extraction commands**: the Phase-1 Constraints bullet (line 314) explicitly says bounded extraction over the capture file is expected and calls out that this is stated so "a literal-minded haiku agent does not refuse to `grep` its own capture file." Good, this is the exact literal-reading failure round 1 warned about.
- **Verification Methodology steps 2 and 5** (lines 297, 300) match the new flow: step 2 captures then `tail -n 1`; step 5's negative control describes the real direct-call outcome (preview+path for valid, head+tail excerpt for failure), not "raw output enters the parent."

**Does the fix actually work, not just read like it should?** I ran the canary directly:

```
seq 1 200000 > "$OUT" 2>&1; echo "exit=$?"   ->  exit=0     (this is the entire capture-step tool result)
wc -c "$OUT"                                  ->  1288895    (1.3MB on disk)
tail -n 1 "$OUT"                              ->  200000     (true last line recovered)
```

The capture step's tool result is `exit=0` (tiny), the 1.3MB is on disk, and `tail -n 1` recovers the true last line that a spilled ~2k preview could never have yielded.
So a `seq 1 200000` dispatched through this design stays contained: the parent sees only the fixed-format report, and the runner never has to ingest the 1.3MB into its own context either.
The subtlety that makes this hold is real and correctly stated in the proposal (lines 123, 234): because `echo "exit=$?"` is the last command, the overall Bash invocation exits 0 with tiny output regardless of `<cmd>`'s own exit status, so the platform sees a valid tiny result and the lossy failure-path excerpt never applies to the captured output. The fix works.

### Maintainer decisions - all three applied as firm choices

1. **Cap 6,000, band 4,000-8,000**, grounded in the measured distribution reproduced in mechanism 2 (lines 165-180): the p50/p75/p90/p95/p99/max table is present, 6,000 is correctly placed at p95 (spills 606 of 11,531, ~5.3%), and the spill-then-read-back cliff is cited as the reason for the upper-middle of the band rather than the aggressive end. This is no longer an unbacked number.
2. **Mechanism 3 deferred with the reasoning changed from "broken" to "redundant/mis-targeted"** (lines 190-206, Q3 at line 338): done, and the coverage table correctly identifies the failure-path non-zero-exit row as the only real gap and explains why a rewrite hook does not close it.
3. **Capture file in the subagent's own scratchpad directory** (lines 121, 140, 261-262): stated in Workflow, Output contract, and Edge Cases, with lifetime (session-scoped, disposable, no explicit teardown) noted.

## New for Round 2: The Tooling-Landscape Report

I read [`cdocs/reports/2026-09-23-bash-output-tooling-landscape.md`](../reports/2026-09-23-bash-output-tooling-landscape.md) in full and formed my own judgment rather than accepting its verdict.

### Does "build is still right" hold up? Yes, and the report's axis is correct.

The report's core distinction (rule-based/deterministic per known command type, no caller-steerable salience, unknown commands pass through unfiltered vs. semantic, caller-steerable, covers unfamiliar commands) is the right axis, and it is decisive.
`cdocs:bash-runner`'s value proposition is three capabilities rtk structurally lacks: (a) per-call caller-supplied salience specs, (b) coverage of unfamiliar/unanticipated commands that are not on any fixed allowlist, and (c) semantic "find the buried needle regardless of format." rtk has none by design, which is exactly why it is fast and free. So mechanism 1 has no adoptable off-the-shelf substitute, and the report's evidence (the one architecturally-similar prior art, `daz-command-mcp`, is unlicensed and 6 months stale) reinforces rather than weakens that. Build-is-right for mechanism 1 holds.

### The hybrid (bash-runner shells out to rtk as a pre-filter): considered, and I recommend against it.

The task asks me not to skip this, so explicitly: **I do not think the hybrid is worth adding to this proposal, and build-as-designed is correct without any rtk integration.**
My reasons go beyond the report's dependency-hygiene framing, and I think they are the load-bearing ones:

1. **Semantic incompatibility for exactly the whale traffic.** rtk's compression is fixed per command type, applied before output reaches the caller. If `bash-runner` captured `rtk grep -rn foo` instead of the raw command, its haiku extractor would be searching rtk's already-lossy, regrouped, deduped view, not the true output. For a caller whose salience spec is "matches per file, first 3 per file," rtk may have already dropped or reshaped precisely what the caller asked for. The pre-filter and the semantic extractor fight each other, and they fight hardest on the observed whales (`grep`/`find`/`git diff`/`cat` sweeps), where "the matches ARE the signal" and a fixed transform is most likely to be wrong for a given call. The pre-filter's cheap common case is the same case where deterministic pre-filtering is riskiest.
2. **It breaks the no-silent-loss property the B3 fix leans on.** The containment argument depends on the runner controlling the exact bytes on disk so "the full output is always on disk." Insert rtk and the on-disk artifact is rtk-transformed; recovering the raw output would require capturing twice. The clean guarantee degrades.
3. **Dependency and stability, as the report notes** (`dev-0.50.0-rc.451`, no library/MCP mode, must be on PATH in every consuming environment including CI and sandboxes the plugin cannot provision). Even an optional detect-on-PATH branch executes a third-party output-transforming binary inside the agent's tool path.

There is a narrower, free version worth one sentence in the proposal but no design change: because the runner runs whatever command it is given, a caller who wants rtk can already dispatch `rtk git diff` as the command. That capability falls out for free and needs no proposal surface.

### Is the report's supply-chain concern well-reasoned or overcautious?

The conclusion (do not make rtk a hard dependency) is correct, but it rests most weakly on the pure supply-chain/trust argument, which is somewhat overcautious taken alone: the plugin already runs arbitrary bash, and Apache-2.0, actively-maintained, adopted tools are routinely depended upon.
What actually carries the conclusion is (a) environment availability (rtk has no library/MCP mode, so it must be installed and PATH-resolvable everywhere, and the plugin cannot install or version-pin it) and (b) the architectural incompatibility above.
Credit where due: the report is honest about the 81.5k-stars vs. 30-contributors / next-largest-specialist-at-153-stars discrepancy and flags the small core team, so it does not oversell rtk's maturity. That honesty is the right posture; I would just re-weight the four stated reasons so architecture and environment-availability lead and pure supply-chain trust trails.

### The report's optional suggestion (cite rtk in mechanism 3's background)

Worth taking, non-blocking. A one-line pointer in mechanism 3 ("if a maintainer ever wants this deterministic-floor value, a mature Apache-2.0 tool whose coverage happens to include this corpus's observed whales already exists and would outperform a bespoke allowlist; point consumers at it rather than build one") strengthens the existing "keep deferred" verdict and gives a future maintainer a concrete lever. I recommend folding it in on this round (see Action Item 4).

## Section-by-Section Findings (new issues from the round-1-to-round-2 rewrite)

The rewrite was large (the devlog notes it was rewritten rather than patched). I checked for new issues introduced by it. None is blocking.

### Frontmatter of the runner: `omitClaudeMd` is unverified

**N1 [non-blocking]: `omitClaudeMd: true` has no precedent in this repo and may not be a recognized Claude Code subagent frontmatter field.**
`maxTurns` has repo precedent ([`judge.md`](../../plugins/cdocs/agents/judge.md) uses `maxTurns: 10`), but `grep -rn omitClaudeMd` across `plugins/` and `scripts/` returns nothing, and it is not a documented subagent frontmatter key I can confirm.
If it is not recognized, it is silently ignored (harmless), but then the stated rationale (saving 2-3k haiku input tokens per dispatch by skipping the consumer's `CLAUDE.md`, lines 98, 104) evaporates and the frontmatter carries a no-op.
This does not block acceptance, but Phase 1 should verify the field is real and honored before relying on it, and drop it (or substitute the actually-supported mechanism) if not. The OpenCode build is unaffected either way: [`scripts/build-opencode.ts`](../../scripts/build-opencode.ts) `generateOCFrontmatter` emits only description/mode/model/tools/permission, so both `maxTurns` and `omitClaudeMd` are dropped from the OC artifact regardless.

### Frontmatter of the runner: `maxTurns` value unspecified

**N2 [non-blocking]: `maxTurns` is referenced three times (lines 98, 269, 311) but never given a value.**
The implementer is left to guess. Name a concrete starting value (e.g. `maxTurns: 5`, or match `judge.md`'s 10) so Phase 1 is executable without a judgment call. The runner's flow is capture + a handful of bounded extractions + classify, so a small bound is appropriate; state it.

### Design Decisions: one sentence still implies the old read-once model

**N3 [non-blocking]: line 242 says "The runner reads the whole output (from its capture file) once, in disposable context," in mild tension with the corrected model on line 31 ("the runner cannot 'read the whole output once'").**
The intent is clear from context (the full output is on disk and greppable, so a buried needle is findable via a targeted extraction), but the phrasing re-implies that haiku ingests the whole output, which is precisely what B3 corrected: the runner does bounded extraction over the file and never loads the whole output into its own context.
Tighten to something like "the runner has the whole output on disk and extracts the buried needle from it" to remove the tension. Purely a precision nit.

### Workflow / extraction: bounded-grep spill is handled

Positive confirmation, not a finding: I checked whether the extraction step could itself spill (an unselective `grep` over a huge capture file producing >ceiling output). The Workflow (line 124) pipes `grep -nE '<pattern>' "$OUT" | head -n N`, so each extraction is bounded and cannot spill. This is correct and worth noting because it is the non-obvious second-order case.

### Test Plan and Verification Methodology: sound

The "Runner under a low cap" test (lines 280-281) is the right composition test and I confirmed its premise empirically. The containment canary (Verification Methodology steps 3-4) plus the low-cap test are correctly identified as the verification floor. Edge Cases cover interactivity/TTY, spill-then-read-back, binary/long-line output, salience misses, near-empty output, capture-file lifetime, and the no-init degradation path. Coverage is thorough; I found no missing edge case that would block.

### Frontmatter and writing conventions

Frontmatter is valid and complete against [`frontmatter-spec.md`](../../plugins/cdocs/rules/frontmatter-spec.md): `last_reviewed` will update to round 2 on acceptance.
Writing conventions are followed: sentence-per-line, spaced hyphens (no em-dashes), direct GitHub issue links on first mention, BLUF present.
One mild note, non-blocking: the BLUF is now three dense quote-lines. It is within bounds for a proposal of this technical load, but if a nit-fix pass runs, the third line could be tightened. Not a defect.

## Verdict

**Accept.**

All three round-1 blocking items (B1 hook facts, B2 cap semantics, B3 runner capture-to-file) are resolved and internally consistent across every section round 1 flagged, and I verified the load-bearing containment fix empirically rather than trusting the prose.
The three maintainer decisions are applied as firm choices with the measured distribution now cited.
The tooling report does not force any change to mechanism 1: I independently concur that build-is-right and that rtk should not be a dependency, and I add a sharper architectural reason against the pre-filter hybrid than the report gives.
The proposal is implementation-ready. The remaining items are non-blocking nits to fold in on this accepting round per the loop convention; none is a design question and none requires another review round.

## Action Items

1. [non-blocking] Verify `omitClaudeMd: true` is a recognized, honored Claude Code subagent frontmatter field before Phase 1 relies on it; drop it (or substitute the supported mechanism) if not, since an unrecognized field makes its stated token-saving rationale a no-op. (N1)
2. [non-blocking] Give `maxTurns` a concrete starting value in the runner frontmatter and Phase 1 (e.g. `maxTurns: 5`), so the phase is executable without a guess. (N2)
3. [non-blocking] Tighten the Design-Decisions sentence (line 242) so it no longer says the runner "reads the whole output once," which mildly re-implies the read-once model B3 corrected; state that the full output is on disk and extracted from. (N3)
4. [non-blocking] Fold the tooling report's optional suggestion into mechanism 3's Background: cite [`rtk-ai/rtk`](https://github.com/rtk-ai/rtk) as evidentiary support for staying deferred (a mature Apache-2.0 tool already covers this corpus's whale command shapes better than a bespoke allowlist), and optionally add one sentence that a caller can already dispatch `rtk <cmd>` as the runner's command with no design change. Keep the report's explicit "do not make rtk a plugin dependency" stance.

## Questions for the Maintainer

None blocking. Two optional confirmations, offered as multiple choice:

1. On the `maxTurns` value for `cdocs:bash-runner`:
   (a) `5` (capture + a few bounded extractions + classify is a short flow),
   (b) `10` (match `judge.md`),
   (c) leave to the implementer with a stated ceiling in Phase 1.
2. On the rtk citation in mechanism 3 (Action Item 4):
   (a) fold it in now on this accepting round (reviewer's lean),
   (b) defer it to the implement phase as a doc-only addition,
   (c) omit it (mechanism 3 is already adequately justified without it).
