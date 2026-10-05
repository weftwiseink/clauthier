---
first_authored:
  by: "@claude-fable-5-1"
  at: 2026-10-05T09:28:09-07:00
task_list: meta/chat-record-devlog-management
part_of: cdocs/devlogs/2026-09-22-chat-record-devlog-management-propose-revise.md
type: devlog
state: live
status: review_ready
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
| 6 | revision (fable-5-1, warm context) | r5 blockers plus four new directives applied; hooks reduced to `UserPromptSubmit` + `Stop`; `status: review_ready` |

## Changes Made

| File | Description |
|------|-------------|
| `cdocs/proposals/2026-09-22-chat-record-devlog-management.md` | round-5 redesign: hook surface reduced to five events (three load-bearing), per-turn gist rule with one-shot `Stop` block, compaction guidance moved to rules, `files=`/`@compact`/devlog-tracking removed throughout; BLUF, Summary, diagram, hook table, decisions, edge cases, test plan, phases updated |
| `cdocs/devlogs/2026-10-05-chat-record-devlog-management-revise-r5.md` | this devlog |

## Verification

Document-level only (no hooks were built): `grep -n 'PostToolUse\|PostCompact\|files=\|\.quiet\|\.acted\|\.turn\|\.devlog' cdocs/proposals/2026-09-22-chat-record-devlog-management.md` after the rewrite should hit only the Phase-0 evidence table, the history NOTEs, and the Phase-3 sketch's explicit "not in Phase 1" statements.
Result: 17 hits, all in the Summary revision-history NOTE, the `PostCompact` upstream-status NOTE, the Non-Goals "not registered" bullets, Decisions 7, 10, and 11 (dated rationale for what was removed), the Phase-0 "also verified but not relied on" line, the Phase-1 "do not register" constraint, and the Phase-3 sketch.
No design-body sentence still describes `files=`, a turn buffer, the quiet counter, the three-tier devlog resolution, or an `@compact` block as current.
A second scan for round-4 framing (`seven`, `second duty`, `primary delivery`, `secondary`, `defense-in-depth`, `advisory`, `placeholder`, `nudge`) hit only the history NOTEs and the `inject-rules.ts` "nudge pattern" citation in Background.
BLUF tightened from 1750 to about 950 characters.

## Commits

| sha | subject |
|---|---|
| `6c757a3` | docs(devlogs): open round-5 revision devlog for chat-record proposal |
| `74169c1` | docs(chat-record-devlog-mgmt): round-5 redesign: per-turn gist with Stop block, drop PostToolUse/PostCompact, rules-driven compaction |
| `cfbb241` | docs(devlogs): record round-5 verification scan and commit table |
| `6548206` | docs(chat-record-devlog-mgmt): round-6 redesign: two hooks, bin/chat-record, per-turn timestamps, no compaction awareness |

## Round 6

Inputs: the r5 review ([`2026-10-05-review-of-chat-record-devlog-management-r5.md`](../reviews/2026-10-05-review-of-chat-record-devlog-management-r5.md), verdict revise: script invocation path and permission story blocking) and four new maintainer directives (2026-10-05) that take precedence: the record is not compaction-aware; drop `SessionEnd` and the session marker lines, and `SessionStart` unless proven necessary; timestamps per turn (submission on `@user`, end on `Stop`) with session name, model, and prompt id on agent turns; guideline instead of never-list.
Net target: hooks = `UserPromptSubmit` + `Stop`, one `bin/chat-record`, rules text, init permission rule.

### Facts verified in this session (Claude Code 2.1.289, before changing the design)

- Bash environment: `CLAUDE_CODE_SESSION_ID=e3afd4a9-...` is set and matches this session's transcript filename; `CLAUDE_PLUGIN_ROOT` is absent; `PATH` already contains `.../clauthier/main/plugins/cdocs/bin` even though that directory does not exist yet, so the platform adds a plugin's `bin/` to PATH unconditionally while the plugin is enabled.
  No session-name variable exists in the environment.
- Hooks reference (fetched): common input fields are `session_id`, `transcript_path`, `cwd`, `hook_event_name`, `permission_mode`, plus `prompt_id`, `agent_id`, `agent_type` where applicable; no common field carries a session name; `SessionStart` alone has an optional `session_title` (custom title only, not the generated one); no mention of `CLAUDE_CODE_SESSION_ID` (undocumented, as the r5 review said) and nothing on `Stop` firing on interrupt.
- Transcript: `~/.claude/projects/<slug>/<session_id>.jsonl` carries `{"type":"custom-title","customTitle":"clauth-opt-context","sessionId":"<id>"}` lines, 27 of them in this session (rewritten over time; the last one wins).
  Since `transcript_path` is a common hook field, the `Stop` hook can read the session name without a third hook.
- `/cdocs:init` SKILL has no settings-file handling today; the permission rule is a new deliverable, not an extension.
- Canary run 2 timestamps: the second prompt arrived at 18:21:05, so the illustrative agent stamps in the example had to fall between 18:20:54 and 18:21:05 to keep the file's timestamps non-decreasing (a property the new test plan asserts).

### Design choices

- **`SessionStart` dropped.** Its only remaining job was announcing the record path, and `chat-record path` answers that on demand from the environment; the r5 review showed the "only the hook knows the session id" claim was false.
  File creation is lazy: the first `UserPromptSubmit` or the first `note`, whichever comes first.
  Degraded path when the variable is absent: the `Stop` block reason names the real path and `--record` accepts it; a Phase-1 test asserts the variable equals the hook's `session_id` so a rename is caught early.
- **Full session id in the filename.** `cdocs/_chat/YYYY-MM-DD-<session_id>.md`; deletes the sid8 collision check, the `sid=` first line, and the fallback-name mismatch the r5 review found (nit 9).
- **End stamp as a separate `@end` block, not a header completion.** `Stop` appends `@end: <ts> p=<pid8> session=<title|sid8>` whenever it does not block (including the silent second `Stop` after an ignored block, so gaps are visible).
  Chosen over "complete the note header at Stop" because it is append-only with zero state; chosen over "Stop writes the whole agent block from a staging file" because staging adds a runtime file, a crash-loss case, and an orphan-flush case keyed by prompt id.
  The agent's header carries model (`--as`) and `p=`; the `@end` line carries end time and session name; together they are the directive's per-turn annotation.
- **Zero runtime-directory state.** `note` takes `p=` from the record's last `@user`/`@harness` header; the block reason passes `--p <pid8>` explicitly, which also covers the r5 "Stop with no `.prompt` file" item (8) without a file.
- **`n=` ordinal dropped**; the devlog's `## Chat Record` pointer records the last handoff's timestamp instead.
- **Session name from the transcript at `Stop` time**, not from `SessionStart`'s `session_title`, because that is the only way to get it with two hooks; unnamed sessions fall back to sid8.
- **`bin/chat-record`** per r5 blocker 1, with the claude.ai/Cowork non-installability trade-off stated in Decision 8 and the init-shim alternative rejected (version-specific cache path goes stale).
- **Permission rule** `Bash(chat-record:*)` (one rule covers `note` and `path`) merged by `/cdocs:init`, documented in both `settings.json` and `--allowedTools` forms; run 8's `bypassPermissions` caveat stated; default-mode scenarios in the test plan, including a denial-without-rule scenario that documents the failure the rule prevents.
- **Guideline replaces the never-list** (directive 4): do not note every commit, test run, or tool output; note the one that matters; the shape to avoid is the enumerated log.
- **Interrupt**: both branches stated; if `Stop` fires on interrupt the block must be suppressed (resurrecting the agent after Escape is the opposite of what the user asked), `@end` still written; signal and decision deferred to interactive check (c) and recorded by the implementer.
- **Folded r5 non-blocking items**: 4 (interrupt), 5 (per-turn cost and batching `note` with the last tool call), 6 (usefulness sample, 20 entries, 80% bar), 7 (harness, headless `--resume`, stream-json `/clear`, Pillar-2-text assertion in the rules check), 9 (lookup order, resolved by the full-id filename), 10 (history sentence removed).
  Item 3's "keep the announcement" is overtaken by directive 1; the variable became primary, not fallback, because the announcement no longer exists.
  Item 7's sid-collision test is gone with the collision case; the `custom_instructions` softening is moot with `PreCompact` unregistered.

### Pushed back or in tension

- None of the maintainer directives was pushed back on.
- The r5 review recommended keeping the `SessionStart(compact)` announcement with the variable as fallback; the maintainer's directive 1 inverts that, and the proposal follows the directive, recording the variable's undocumented status and the equality test as the mitigation.
- The r5 review's blocker 2 proposed `Bash(chat-record note:*)`; the proposal uses `Bash(chat-record:*)` so `path` is covered by the same rule.

### Verification

Stale-term scan (`SessionStart|PreCompact|PostCompact|SessionEnd|compact-begin|@session|announce|sid8|\.prompt|runtime.dir|never-list|n=<|chat-record\.sh`) over the rewritten proposal: every hit is in the Summary history NOTE, Decisions 7, 8, 10, and 12 (dated rationale), the Phase-0 table and its "also verified but not relied on" line, the Phase-1 "do not register" constraint, the example's own `query:` text, the Scratchpoint example's description of today's `hooks.json`, or the Phase-3 sketch.
Frontmatter: `status: review_ready`; `last_reviewed` left exactly as the r5 reviewer set it (`revision_requested`, round 5).
Proposal size 86KB; BLUF about 1000 characters.
