---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-22T10:39:14-07:00
task_list: meta/token-spend-attribution
type: devlog
state: live
status: wip
tags: [meta, tooling, cost, hooks, context-management, verification]
---

# Haiku Bash-Wrapper Proposal: Devlog

## Objective

Verify the landscape report's most load-bearing, least-verified claim (that `PostToolUse` `updatedToolOutput` no-ops for the built-in Bash tool), then author a proposal for the haiku bash-output wrapper on top of the verified facts.
Proposal-authoring only: no implementation.

## Plan

1. Read [`cdocs/reports/2026-09-22-haiku-bash-wrapper-landscape.md`](../reports/2026-09-22-haiku-bash-wrapper-landscape.md) in full plus the `nit-fix.md` template and README "Rules Integration".
2. Independently re-verify the [#68951](https://github.com/anthropics/claude-code/issues/68951) regression claim: fetch the issue, search release notes/changelog, check the installed Claude Code version.
3. Author `cdocs/proposals/2026-09-22-haiku-bash-wrapper.md` via `/cdocs:propose`, with a design correct under whichever verification answer lands.
4. Commit proposal and devlog with conventional-commit messages.

## Testing Approach

Verification was the "test": re-fetch the primary source, corroborate with search, and check the live version rather than trusting the prior subagent's citation.

## Implementation Notes

**Verification outcome - CONFIRMED-REGRESSED, and worse than the report assumed.**

- [#68951](https://github.com/anthropics/claude-code/issues/68951) is real and closed "not planned." `updatedToolOutput` works for MCP tools but is silently ignored for built-in Bash/WebFetch (confirmed 2.1.163/2.1.177). Prior dupes #65403/#67442/#54196 closed unresolved. No fix version.
- New finding not in the report: the report's proposed interim lever - a `PreToolUse` command-rewrite hook - is ALSO dead. [#79321](https://github.com/anthropics/claude-code/issues/79321) documents `PreToolUse` `updatedInput` being silently dropped for Bash (confirmed 2.1.215, closed "not planned"). Both hook-based rewrite channels for built-in Bash are inert.
- Installed version here is `2.1.280` (via `claude --version`), newer than every affected version cited and with no fix landed, so both regressions are presumed live.
- What still works (per #68951's own compatibility notes): `PreToolUse`/`PostToolUse` `additionalContext`, and `PreToolUse` block via exit 2. Feature request [#32105](https://github.com/anthropics/claude-code/issues/32105) confirms the desired use case is unshipped upstream.

**Design consequence.**
The report's fallback ("settings cap + `PreToolUse` rewrite, defer `PostToolUse` hook") is right on clauses 1 and 3, wrong on clause 2.
Proposal keeps the settings-level cap and the deferral, drops the rewrite lever, and replaces it with an optional advisory block-and-nudge that uses only confirmed-working channels.
The core (haiku `cdocs:bash-runner` agent) depends on neither broken mechanism, so it is robust either way.

**Authoring choices.**
- `cdocs:bash-runner`: `model: haiku`, `tools: Bash` only (follows `judge.md`'s deliberate-narrowing precedent). The `Bash`-only allowlist forces the extraction contract to be inlined rather than rule-read (unlike `nit-fix`); flagged in a NOTE for review.
- Settings cap (`bashOutputMaxChars` ~4-6k): delivered as `/cdocs:init` guidance, not plugin-baked, since a plugin cannot write a consumer `settings.json` and this repo's own `.claude/settings.json` sets no such cap.
- Dispatched mode (`--dispatched`): author-checklist review replaced with an `## Investigation Requested` block.

## Changes Made

| File | Description |
|------|-------------|
| `cdocs/proposals/2026-09-22-haiku-bash-wrapper.md` | New proposal: `cdocs:bash-runner` haiku agent + deterministic settings cap, `PostToolUse` hook deferred, `PreToolUse` rewrite dropped as broken |
| `cdocs/devlogs/2026-09-22-haiku-bash-wrapper-propose.md` | This devlog |

## Verification

- All internal paths cited by the proposal confirmed to exist on disk (reports, agents, rules, README, hooks.json, build script).
- External claims verified via WebFetch on the two GitHub issues plus WebSearch corroboration; installed CC version confirmed via `claude --version` (2.1.280).
- No code changed; proposal-authoring task only, per instructions.

## Propose-Revise Loop (started 2026-09-23, entering at review since proposal already exists at `review_ready`)

Maintainer invoked `/cdocs:propose-revise cdocs/proposals/2026-09-22-haiku-bash-wrapper.md --first-round fable`, starting at the reviewer rather than the proposer since round 0 (initial authoring) is already done. Round 1 reviewer dispatched on fable per `--first-round`; resolves the proposal's own two open Investigation Requested questions (Bash-only vs. Bash+Read tool allowlist; `/cdocs:init` write-vs-document for the settings cap) plus the standard review floor.

| Round | Model | Proposer/Reviser dispatch | Reviewer dispatch | Verdict |
|---|---|---|---|---|
| 1 | fable | n/a (proposal pre-existed, entering at review) | [`2026-09-23-review-of-haiku-bash-wrapper.md`](../reviews/2026-09-23-review-of-haiku-bash-wrapper.md) | **revise** (3 blocking, empirical) |

### Round 1 review log (2026-09-23, fable)

Resolved all four Investigation Requested items with explicit verdicts: `Bash`-only stays (Q1); init stays document-only with the carrier file to be named (Q2); mechanisms 1+2 suffice and 3 stays deferred, but for coverage reasons, not "broken" (Q3); cap range validated at p90-p95 of a measured distribution, start at 6,000 (Q4).

Three empirical findings drive the revise verdict, each verified rather than reasoned from issue text:

- **Hook canary on 2.1.280** (headless haiku, throwaway `--settings`, 2/2 runs): `PreToolUse` `updatedInput` DOES rewrite Bash commands here (transcript shows `tool_use.input.command = echo ORIGINAL_OUTPUT`, `toolUseResult.stdout = REWRITE_APPLIED`), contradicting the proposal's Finding 2 / [#79321](https://github.com/anthropics/claude-code/issues/79321) as applied to this environment; `PostToolUse` `updatedToolOutput` sentinel never reached the model, confirming Finding 1 / [#68951](https://github.com/anthropics/claude-code/issues/68951).
- **Cap semantics**: per the CC tools reference and observed inside the reviewer subagent (`seq 1 20000` -> "Output too large (106.3KB). Full output saved to: ... Preview (first 2KB)"), a valid over-ceiling result spills to a file with a ~2k preview; only failure results get the head+tail excerpt. The proposal models the cap as head/tail truncation.
- **Cap applies to the runner too**, so a `Bash`-only runner cannot "read the whole output once"; it must capture-to-file-then-extract. This changes the Workflow, Output contract, Constraints, and the containment canary (as written, `seq 1 200000` + "return the last line" would fail).
- **Per-call Bash size distribution** computed over the read-source corpus (11,531 results, weftwise, 2026-09-12 onward; mean 400 tok matches the report's 390): p50 655, p90 3,978, p95 6,228, p99 14,103 chars. Top-15 whales are all `grep`/`find`/`git diff`/multi-`cat` sweeps, not builds or installs.

Reviser instructions are the review's Action Items 1-3 (blocking) and 4-7 (fold-in); the review's Appendix carries the exact canary and measurement procedures so the reviser can cite them without re-deriving.

## Round 1 review verdict + maintainer decisions (2026-09-23)

Round 1 (fable reviewer): **Revise**, 3 blocking (Findings 2-3/BLUF/Summary/division-of-labor table wrong on installed-version hook behavior — `PreToolUse updatedInput` actually WORKS empirically, only `PostToolUse updatedToolOutput` is inert; `bashOutputMaxChars` is spill-to-file-with-preview not head/tail clipping; `cdocs:bash-runner` itself needs capture-to-file-then-extract since its own Bash call hits the same cliff). Review: `cdocs/reviews/2026-09-23-review-of-haiku-bash-wrapper.md`, commit `566941b`.

Maintainer decisions on the review's three questions:
1. **Cap value: 6,000 chars (p95, reviewer's recommendation).**
2. **Mechanism 3 (PreToolUse rewrite, now confirmed working): keep deferred** (reviewer's recommendation — the 15 heaviest observed Bash results are grep/find/git-diff/multi-cat sweeps, not the npm-install/docker-build/terraform pattern a rewrite hook would target; no real gap to close).
3. **Runner capture-file location: the subagent's own scratchpad directory.**

Additional maintainer request: dispatch a sonnet `/cdocs:report` on related/existing tooling (e.g. `rtk-ai/rtk`) BEFORE the next review round, to inform whether the round-2 reviewer should consider adopting/wrapping an existing tool instead of (or alongside) the bespoke `cdocs:bash-runner` build — "or maybe even more" (i.e. an existing tool might exceed what a bespoke build would achieve). Dispatched in parallel with the round-2 revision; feeds the round-2 REVIEWER, not the reviser (the concrete correctness fixes from round 1 apply regardless of the tooling question).

| Round | Model | Proposer/Reviser dispatch | Reviewer dispatch | Verdict |
|---|---|---|---|---|
| 1 | fable | n/a (proposal pre-existed, entering at review) | done: `cdocs/reviews/2026-09-23-review-of-haiku-bash-wrapper.md` | revise (3 blocking) |
| 2 (revision) | opus (warm, original proposer resumed) | done (this entry) | done: `cdocs/reviews/2026-09-23-review-of-haiku-bash-wrapper-r2.md` | **accept** (0 blocking, 4 non-blocking nits) |

### Round 2 revision (2026-09-23, opus)

Applied all 3 blocking action items and all 4 non-blocking items; folded the three maintainer decisions in as firm choices, not open questions. The proposal was rewritten rather than patched, since the three empirical corrections propagate through most sections.

Blocking fixes:

- **B1 (hook facts).** Rewrote the BLUF, Summary, the whole Verification section (Findings 1-4), and the division-of-labor table to state the canary-verified truth: `PostToolUse updatedToolOutput` is inert for built-in Bash ([#68951](https://github.com/anthropics/claude-code/issues/68951), Finding 1), but `PreToolUse updatedInput` DOES rewrite Bash commands on 2.1.280 Linux headless (2/2), so [#79321](https://github.com/anthropics/claude-code/issues/79321) does not reproduce here and the channel is environment-dependent. My round-1 Finding 2 ("also dead") was wrong: it reasoned from the GitHub issue text instead of testing, which the reviewer caught by running the canary. Corrected to present-tense verified facts; the "was re-run / tightens rather than loosens" narrative is dropped from the proposal (it lives here in the devlog). Mechanism 3 stays deferred but the reason flips from "broken" to "redundant with 1+2 and mis-targets the observed whales."
- **B2 (cap semantics).** Replaced the head/tail-clip model of `bashOutputMaxChars` with the documented spill-to-file cliff: a VALID over-ceiling result collapses to a file path + ~2k preview; only a FAILED command gets a lossy head+tail excerpt with no file. `bashOutputMaxChars` sizes the inline ceiling and read-back window together and makes CC ignore `BASH_MAX_OUTPUT_LENGTH`. Rewrote mechanism 2, Design Decisions, added the spill-then-read-back Edge Case, and fixed the "Deterministic cap shape" test to assert preview+path, not truncation.
- **B3 (runner hits the same cliff).** Redesigned the runner Workflow to capture-to-file-then-extract (`<cmd> > "$OUT" 2>&1; echo exit=$?`, then bounded `wc`/`grep`/`head`/`tail`/`cut` over `$OUT`), which also keeps the result "valid" so the failure-path excerpt never applies. Flipped the Output contract default to `saved to <path>`, loosened Constraints to explicitly permit bounded extraction over the capture file (a literal haiku agent would otherwise refuse to grep its own file), added the "runner under a low cap" test, and fixed Verification Methodology steps 2 and 5.

Maintainer decisions applied as firm choices: cap start **6,000** (band 4,000-8,000), citing the review Appendix distribution (p90 3,978, p95 6,228); mechanism 3 **deferred on redundancy**, not breakage; capture-file location **the subagent's own scratchpad directory**.

Non-blocking: Q1-Q4 resolutions recorded as a "Resolved Decisions" section (Bash-only stays, no Read; init document-only via a "Bash output hygiene" section in the existing `orchestration-discipline.md` so `/cdocs:init` needs no edit); added the hook-channel canary as the documented re-check in the Deferred section; reordered the dispatch-scope list to lead with sweeps (grep/find/git-diff/multi-cat) and added aggregate salience-spec examples; added `maxTurns` and `omitClaudeMd: true` to the runner frontmatter.

Not acted on (correctly, per coordinator): the parallel sonnet tooling report (`rtk-ai/rtk`) feeds the round-2 reviewer, not this revision. Flagged in a Background NOTE that the correctness fixes hold even for a wrapped external tool if it is Bash-only under the hood.

`status` returned to `review_ready`.

### Round 2 review: Accept + closing nits (2026-09-23, opus) — loop terminates

Round 2 reviewer (fresh opus, `cdocs/reviews/2026-09-23-review-of-haiku-bash-wrapper-r2.md`, commit `3bc3442`): **Accept**, no design changes needed; the reviewer ran the containment canary itself and confirmed the capture-to-file fix works. Four non-blocking nits folded in per the "resolve nits even on an accepting round" convention:

1. **`omitClaudeMd` dropped.** No precedent in any `plugins/cdocs/agents/*.md` and unverified against the agent-frontmatter schema, so it would risk silently no-opping. Removed from frontmatter, Phase 1, and the Test Plan. (`maxTurns` DOES have precedent: `judge.md` carries `maxTurns: 10`.)
2. **`maxTurns: 8`** — concrete value stated (capture + a handful of bounded extraction commands + report, with headroom; below `judge.md`'s 10 since the runner's loop is tighter).
3. **Stale "reads the whole output once" corrected** in Important Design Decisions to the actual capture-then-extract phrasing (captures to the scratch file, extracts with bounded shell; a `grep` finds a buried error wherever it fell).
4. **`rtk-ai/rtk` cited** in mechanism 3 (per `cdocs/reports/2026-09-23-bash-output-tooling-landscape.md`): a mature Apache-2.0 `PreToolUse` rewrite proxy already owns the grep/find/git-diff/cat-sweep territory a bespoke rewrite-hook allowlist would target, so staying deferred is further justified (report also recommends against adopting it as a plugin dependency: pre-1.0, RC-heavy, CLI-only).

`status` set to `implementation_ready`. **The propose-revise loop terminates here on Accept.**

| Round | Model | Proposer/Reviser dispatch | Reviewer dispatch | Verdict |
|---|---|---|---|---|
| 1 | fable | n/a (entering at review) | done | revise (3 blocking) |
| 2 | opus | done (revision) | done: `cdocs/reviews/2026-09-23-review-of-haiku-bash-wrapper-r2.md` | **accept** (4 nits folded in) |

### Round 2 review (2026-09-23, opus, fresh reviewer)

**Verdict: accept.** Review: [`cdocs/reviews/2026-09-23-review-of-haiku-bash-wrapper-r2.md`](../reviews/2026-09-23-review-of-haiku-bash-wrapper-r2.md).

Fresh reviewer, no round-1 priors; formed an independent assessment, then read round 1 only to confirm its three blocking items landed. They did, and the reviewer verified the load-bearing one empirically rather than trusting the prose: ran `seq 1 200000 > "$OUT" 2>&1; echo exit=$?` (capture-step result `exit=0`, 1.3MB on disk, `tail -n 1` recovers `200000`), confirming the capture-to-file-then-extract flow genuinely contains a whale. B1 (hook facts) is consistent across BLUF/Summary/Findings/division-of-labor table with no stale phrasing surviving a grep; B2 (spill-to-file cap) propagated to mechanism 2, Design Decisions, Edge Cases, and the cap-shape test; B3 (runner capture-to-file) is correct in Workflow, Output contract, Constraints, and Verification steps 2/5. All three maintainer decisions (cap 6,000/band 4,000-8,000 with the distribution cited; mechanism 3 deferred on redundancy not breakage; capture file in subagent scratchpad) are applied as firm choices.

On the tooling report: the reviewer independently concurred with build-is-right for mechanism 1 and no-rtk-dependency, but reached it by a sharper route - an rtk pre-filter is semantically incompatible with the caller-steerable-salience contract for exactly the whale traffic (it lossily transforms the very bytes the semantic extractor searches per the caller's spec) and breaks the no-silent-loss property the B3 fix leans on. Judged the report's pure supply-chain framing as the weakest of its reasons (somewhat overcautious given Apache-2.0 + adoption); the load-bearing reasons are environment availability (no library/MCP mode, cannot install/pin) and architecture. Endorsed the report's optional mechanism-3 rtk citation.

Four non-blocking nits to fold in on this accepting round (none reopens the design, none needs another round):
1. `omitClaudeMd: true` has no repo precedent and may not be a recognized CC subagent frontmatter field; verify it is honored before relying on it, else drop it (its token-saving rationale becomes a no-op if ignored). OC build drops it either way.
2. `maxTurns` is referenced but never given a value; name a concrete start (e.g. `5`).
3. Design-Decisions line 242 still says the runner "reads the whole output once," in mild tension with the corrected model; tighten to "full output on disk, extracted from."
4. Fold the report's optional rtk citation into mechanism 3's Background; note a caller can already dispatch `rtk <cmd>` as the runner's command with no design change.

| Round | Model | Proposer/Reviser dispatch | Reviewer dispatch | Verdict |
|---|---|---|---|---|
| 1 | fable | n/a (proposal pre-existed) | done: `cdocs/reviews/2026-09-23-review-of-haiku-bash-wrapper.md` | revise (3 blocking) |
| 2 | opus (revision) / opus (fresh review) | done | done: `cdocs/reviews/2026-09-23-review-of-haiku-bash-wrapper-r2.md` | **accept** (0 blocking, 4 nits) |

Next: fold the 4 nits (a nit-fix-scale pass, no re-review needed), then the proposal is implementation-ready for `/cdocs:iterate` or `/cdocs:implement`.
