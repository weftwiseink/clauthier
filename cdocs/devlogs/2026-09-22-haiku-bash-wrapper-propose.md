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
| 2 (revision) | opus (warm, original proposer resumed) | pending | pending (fresh; will incorporate the tooling report below) | pending |
