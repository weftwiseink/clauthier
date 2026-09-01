---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-01T12:00:00-07:00
task_list: cdocs/devlog-autoflush-hook
type: proposal
state: live
status: request_for_proposal
tags: [hooks, devlog, context_persistence, harness_enforcement]
---

# Devlog Auto-Flush Checkpoint Hook

> BLUF(claude-sonnet-5/devlog-autoflush-hook): Add a `PreCompact`/`SessionEnd` hook that checkpoints the active devlog to disk, so "always create a devlog" is harness-backed rather than model-obeyed.
> Motivated By: `cdocs/proposals/2026-08-28-overseer-alignment.md` (Pillar 2, context persistence and cleanliness).

## Objective

`CLAUDE.md` mandates "always create a devlog," and the devlog is meant to be the durable record of a session's work.
But a devlog written or updated mid-session lives only as much as the model chooses to write it: if the session compacts or ends before the model flushes its latest state, the devlog can be stale or never created at all, and the loss is silent.
This is an enforcement gap: the instruction is a convention the model follows voluntarily, not something the harness checks or backstops.
The objective is to close that gap using hook events that fire at the two moments a devlog is most at risk of going stale: compaction and session end.

## Scope

- Hook on `PreCompact`: fires before context is summarized/discarded, the natural point to ensure the devlog reflects the session's current state before it becomes harder to reconstruct.
- Hook on `SessionEnd`: fires at session termination, the last chance to catch a devlog that was started but never finalized.
- What "flush the active devlog" could mean, roughly in increasing order of intrusiveness:
  - Detect-only: locate the session's active devlog under `cdocs/devlogs/` and check whether it exists / was recently modified, surfacing a warning if not.
  - Nudge: emit an `additionalContext` directive (as `inject-rules.ts` already does for rule freshness) telling the model to update the devlog before proceeding, without the hook itself writing anything.
  - Assist: have the hook itself append a minimal checkpoint entry (timestamp, note that compaction/session-end occurred) to the active devlog, distinct from the model's own narrative updates.
- Relationship to the existing hook plumbing in `plugins/cdocs/hooks/` (`hooks.json`, `inject-rules.ts`, `cdocs-hooks.ts`, `cdocs-validate-frontmatter.sh`): whether this is a new script registered alongside the existing `SessionStart`/`PreToolUse`/`PostToolUse` entries, or folds into `cdocs-hooks.ts`.

## Open Questions

- How does the hook know which devlog is "active" for the current session? Candidates: a naming/date convention, a marker file, most-recently-modified file under `cdocs/devlogs/`, or something recorded at session start.
- Can a hook cause the model to write at all, or can it only emit an `additionalContext` directive that nudges the model (cf. the `SessionStart` freshness hook in `inject-rules.ts`, which only nudges, it doesn't edit files itself)? If a hook cannot force a write, does "auto-flush" reduce to "auto-nudge," and is that still worth shipping?
- Interaction with the compaction summary itself: does a `PreCompact`-triggered devlog update duplicate content the compaction summary already preserves, or does it capture something the summary would otherwise drop?
- Cross-target degradation: OpenCode and Codex lack Claude Code's `PreCompact`/`SessionEnd` hook events. What does this feature degrade to on those targets, silent no-op, a different mechanism, or is it CC-only?
- Does this belong as its own hook, or as an extension of the existing context-persistence work in `cdocs/proposals/2026-08-28-overseer-alignment.md` Pillar 2 (handoff format, compaction cadence, `CLAUDE.md` reseed verification)?
