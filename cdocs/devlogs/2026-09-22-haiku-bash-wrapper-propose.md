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
