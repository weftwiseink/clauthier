---
first_authored:
  by: "@claude-fable-5-1"
  at: 2026-10-05T09:28:09-07:00
task_list: meta/chat-record-devlog-management
part_of: cdocs/devlogs/2026-09-22-chat-record-devlog-management-propose-revise.md
type: devlog
state: live
status: wip
tags: [meta, tooling, context_persistence, hooks, chat_record, propose_revise]
---

# Chat-Record Proposal, Round 5 Revision: Devlog

> NOTE(fable-5-1/chat-record-devlog-management): Continuation of [`2026-09-22-chat-record-devlog-management-propose-revise.md`](2026-09-22-chat-record-devlog-management-propose-revise.md), which passed the split threshold (42KB) after round 4; this file holds round 5 onward.

> BLUF(fable-5-1/chat-record-devlog-management): Round-5 revision of the accepted proposal on four maintainer directives (2026-10-05): drop the `PostToolUse` hook and everything downstream of it, make every top-level turn write one gist bullet enforced by a one-shot `Stop` block, move compaction guidance out of hooks into rules, reduce `SessionEnd` to a bookend.
> Net hook surface: `SessionStart` (file plus path announcement), `UserPromptSubmit` (`@user`), `Stop` (per-turn check), `PreCompact` and `SessionEnd` (marker lines only).
> Proposal returned to `status: review_ready` for a fresh review.

## Objective

Implement the maintainer's 2026-10-05 directives as a coherent redesign of [`2026-09-22-chat-record-devlog-management.md`](../proposals/2026-09-22-chat-record-devlog-management.md) (accepted round 4, `implementation_ready`), not as patches on the round-4 text.
Scope: Phases 1-2; Phase 3 stays a gated sketch, updated only where it leaned on removed hooks.

## Directives (verbatim intent, condensed)

1. Drop `PostToolUse` entirely: the `files=` turn buffer, the `<sid>.devlog` active-devlog tracking, the `acted` mark, and every downstream dependency (devlog resolution tiers, `files=` header metadata, the `NotebookEdit` assumption).
   Agent notes name salient files themselves.
2. Every top-level agent turn writes at least one chat-record gist bullet; still a gist, never an action log ("bullet point is directional, not a per-action mandate", "absolutely no commit records").
   Replace the five-quiet-turn advisory with a rule plus a `Stop` hook that blocks once when the current turn (by prompt id) has no `@<model>` entry, guarded by `stop_hook_active` (mechanism verified in Phase-0 run 8).
   Revisit categories and the never-list so a minimal-but-useful bullet is always possible.
   Address pure-chat turns, harness turns, dispatch-only turns, headless `-p`, `CDOCS_CHAT_RECORD=off`.
3. Disentangle compaction from hooks: rules (re-injected after compaction) carry the task-unit-boundary handoff and the post-compaction re-read; drop `PostCompact` capture and the `PreCompact` nudge; keep at most a `compact-begin` marker; `SessionStart(compact)` pointer optional, keep only with an argument.
4. `SessionEnd` is a bookend only; keep or drop and say which.

## Evidence consulted before changing anything

- Canary run 8 (`-canary` chunk): `Stop` returning `decision: block` while `stop_hook_active=false` is honored headless under `-p`; the second `Stop` arrives with `stop_hook_active=true`; cost is one extra short turn.
- Canary run 6: `Stop.prompt_id` (`88b8e7d3`) equals the turn's `UserPromptSubmit.prompt_id`, so "current turn by prompt id" is a mechanical check against the `p=` the hook wrote on the `@user` header.
- Canary run 5: `Stop` fires for a turn that only launched a background subagent, and the subagent's completion notification arrives as a second `UserPromptSubmit` (the `@harness` case), each with its own `prompt_id`.
- Canary run 1: `SessionStart(source=startup)` payload has no `model` field; only `source=compact` carries one.
  Consequence: the agent passes `note --as <speaker>`; the fallback is `assistant`, no transcript scraping.
- Canary run 2: the `/compact` line itself consumes a `prompt_id` (`407cc386`) without firing `UserPromptSubmit`; the round-4 example reused that id on a `@user` block by accident.
  Fixed in the example.
- Pillar 2 of `orchestration-discipline.md`: project-root `CLAUDE.md` and unscoped rules re-inject on both auto and manual compaction (source: context-window docs); `/cdocs:init` materializes cdocs rules unscoped.
  This is the basis for moving compaction guidance into rules.

## Design choices made in this revision

- **`SessionStart(compact)` announcement kept, reseed prose dropped.** The chat-record path derives from `session_id`, which only the hook has; post-compaction the agent cannot recover it mechanically from a summary it is told not to trust.
  So `SessionStart` announces the path on every source (one code path, under 200 bytes) and rules say what to read.
  The devlog is recovered from the announced path: `grep -l '<record path>' cdocs/devlogs/*.md` finds the devlog whose `## Chat Record` section names it.
  This replaces the three-tier devlog resolution without any hook state.
- **Categories:** `gist:` (default, what this turn concluded or changed in the state of play), `query:`, `read:`, `follow-up:`.
  A bullet with no prefix is a `gist:`.
  The never-list now bans the action-log shape (enumerating commits, edits, test runs, tool calls, reply text), not the one-line state-of-play.
- **Harness turns owe a bullet too**, because a subagent's return is usually the most gist-worthy moment of the turn; no special case in the hook.
- **One runtime-dir file survives:** `<session_id>.prompt`, written by `UserPromptSubmit`, read by `note` for `p=`.
  `.turn`, `.acted`, `.quiet`, `.devlog`, `.model` are gone.
- **`SessionEnd` kept** as a bookend (`reason=`); dropping it loses only the ability to tell a clean exit from a crash in the record.
- **`PreCompact` kept as a marker only** (`compact-begin trigger= instructions=`), because `custom_instructions` makes steering discipline auditable at zero cost; no `additionalContext`.
- **Leak channels drop from three to two** (`@compact` bodies are no longer written).

## Tension with prior rulings (flagged, not pushed back)

- Round 4 (maintainer, 2026-09-23) dropped the `Stop` block because "silence is usually correct" under the gist model.
  Directive 2 reinstates it on the strength of a changed premise: every turn has at least one gist (what a successor should know from that turn), so silence is no longer a valid output and the block no longer coerces non-gists.
  Recorded as Decision 10's dated reversal; the round-4 reviewer's graceful-degradation argument (user turns survive with zero agent entries) still holds and is kept as the floor.
- The reviewer's r4 non-blocking S3 (confirm `Bash`/`Agent` `PostToolUse` firing) is moot: no `PostToolUse` registration remains.
  S1 (a contrasting negative example) is reframed: there is no "writes nothing" case any more; the example now shows a minimal `gist:` bullet for a routine turn.
  S2 (state graceful degradation explicitly) is folded into Decision 10.

## Round log

| round | step | result |
|---|---|---|
| 5 | revision (fable-5-1, fresh context) | proposal rewritten per directives 1-4; `status: review_ready` |

## Changes Made

| File | Description |
|------|-------------|
| `cdocs/proposals/2026-09-22-chat-record-devlog-management.md` | round-5 redesign: hook surface reduced to five events (three load-bearing), per-turn gist rule with one-shot `Stop` block, compaction guidance moved to rules, `files=`/`@compact`/devlog-tracking removed throughout; BLUF, Summary, diagram, hook table, decisions, edge cases, test plan, phases updated |
| `cdocs/devlogs/2026-10-05-chat-record-devlog-management-revise-r5.md` | this devlog |

## Verification

Document-level only (no hooks were built): `grep -n 'PostToolUse\|PostCompact\|files=\|\.quiet\|\.acted\|\.turn\|\.devlog' cdocs/proposals/2026-09-22-chat-record-devlog-management.md` after the rewrite should hit only the Phase-0 evidence table, the history NOTEs, and the Phase-3 sketch's explicit "not in Phase 1" statements.
Result recorded below once the rewrite lands.
