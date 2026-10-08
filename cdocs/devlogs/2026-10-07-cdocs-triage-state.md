---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T18:25:15-07:00
task_list: cdocs/triage-state
type: devlog
state: live
status: wip
tags: [triage, oversight]
chat_record:
  - cdocs/_chat/2026-10-07-63ac45de-462d-4f43-ae1c-4ab6d59049b8.md
---

# CDocs Triage State: Devlog

> BLUF: Top-level overseer session: scaffold this repo's own cdocs dirs (incl. `_chat/`), audit dogfood setup against the simplified rules, triage outstanding proposals, and dispatch the follow-up workstreams the maintainer picked.

## Objective

Bring the source repo's own cdocs setup current, find outstanding proposals worth attending to now (perf and organization; converser/audio set aside), and route the chosen ones.

## Scratchpoint

- next_steps: await the two sub-overseers below; merge `opencode-build-fixes` into main with `--ff-only` once accepted (or relay its escalation); relay the browser-delegation verdict.
- important_files: `cdocs/proposals/2026-09-17-browser-delegation-plugin.md`, worktree `../opencode-build-fixes`
- callouts:
  - deferred: `2026-10-05-post-compaction-resumption-rfp.md` (maintainer); its BLUF still cites the removed `orchestration-discipline.md`.
  - decision: `/cdocs:init` here skips rules materialization: `CLAUDE.md` `@`-imports `plugins/cdocs/rules/` directly, and `4155496` removed a materialized copy on purpose.
  - decision: OpenCode support must stay minimally invasive; if it gets in the CC setup's way the maintainer may drop it entirely.
  - decision: canonical Codex support archived with its round-2 Revise unaddressed.

## Plan

1. `/cdocs:init` (partial) for missing scaffolding.
2. Sonnet audit of dogfood setup vs. simplified rules; triage agent over `cdocs/proposals/`.
3. Apply maintainer's picks: minor fixes (fork), `/cdocs:full-send` of the three `build-opencode.ts` bug RFPs in a worktree, browser-delegation staleness check then `/cdocs:propose-revise`.

## Implementation Notes

**Dogfood audit** (sonnet): rules, skills list, rules delivery, hooks all current. Gaps: `plugins/cdocs/AGENTS.md` Formal Agents missing `implementer`/`proposer`; no `Bash(chat-record:*)` allowlist; `cdocs/_chat/` absent until this session, so no prior devlog has a `chat_record:` (nothing to backfill).

**Proposal triage** (13 outstanding, non-converser):
- OpenCode build bugs, all `scripts/build-opencode.ts`: YAML block scalars dropped, `tools: "*"` maps to no tools, stale `MODEL_MAP`. Bundled into one full-send.
- `2026-09-17-browser-delegation-plugin.md`: accepted but unimplemented, invalid `status: accepted`.
- Unblocked by rules decomposition: `target-specific-guidance-rfp` (left live, out of OC full-send scope), `post-compaction-resumption-rfp` (deferred).
- `bash-output-cap-rfp`: prerequisite shipped; next step is usage data.
- Lower priority: `rules-hook-testing-methodology-v2`, `tiered-chat-records-rfp`, `chat-record-redaction-scanning-rfp`, `clauthier-improvement-verification`, `nest-overseers-rfp` (deferred).

**Browser-delegation staleness** (opus reviewer, read-only): revise. Blocking: the "MCP tools don't reach subagents" premise of D2 is contradicted by `2026-09-19-claude-code-subagents-feature-breakdown.md`; R1-R6 exists only as report recommendations, not code; verdict handoff conflicts with iterate's reviewer-produced-proof rule; delegate writing devlogs violates one-writer-per-file. Also: adopt bash-runner shape, plugin rules don't reach the lead, CC-only v1, dead rule-file references. Findings handed to the propose-revise sub-overseer as round-1 review input.

## Changes Made

| File | Description |
|------|-------------|
| `cdocs/{devlogs,proposals,reviews,reports}/README.md`, `cdocs/_chat/` | `/cdocs:init` scaffolding (`5bd3434`) |
| `plugins/cdocs/AGENTS.md` | Formal Agents adds `implementer`, `proposer` (`120fb53`) |
| `.claude/settings.json` | `Bash(chat-record:*)` allowlist (`ed5b5fe`) |
| Codex proposal, devlog, 2 reviews | `state: archived` (`64f0abf`) |
| `cdocs/proposals/2026-10-05-post-compaction-resumption-rfp.md` | `state: deferred` (`d038f40`) |

## Verification

Fork-reported: `.claude/settings.json` valid JSON; `chat-record note` succeeds in this session.
