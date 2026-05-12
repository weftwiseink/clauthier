---
first_authored:
  by: "@Claude Opus 4.7 (1M context)"
  at: 2026-05-12T13:30:00-07:00
task_list: clauthier/cdocs-skill-ergonomics
type: proposal
state: live
status: request_for_proposal
tags: [cdocs, skills, ergonomics, claude_effort, slash_commands]
---

# CDocs Skill Ergonomics

> BLUF(opus/cdocs-skill-ergonomics): Adapt cdocs skill verbosity to user-selected effort level via `${CLAUDE_EFFORT}`, and audit `cdocs:*` slash command names against the broader plugin ecosystem to avoid collisions.
> **Motivated By:** [cdocs/proposals/2026-05-08-cdocs-plugin-improvements.md](2026-05-08-cdocs-plugin-improvements.md), [cdocs/reports/2026-05-06-cc-plugin-api-updates.md](../reports/2026-05-06-cc-plugin-api-updates.md).

## Objective

Two small UX gaps in cdocs skills, neither blocking but both worth closing once higher-priority work lands:

1. Skills currently produce the same template regardless of user-selected effort level.
   A user invoking `/cdocs:propose` at `low` effort gets the same multi-section template as a user at `high` effort, which wastes time and context for quick captures.
2. `cdocs:*` slash command names are unique to cdocs today, but the plugin ecosystem is expanding.
   A collision with another commonly-installed plugin would degrade discoverability without warning.

## Scope

The full proposal should explore:

- **Adaptive verbosity via `${CLAUDE_EFFORT}`.**
  CC 2026-04-ish introduced `${CLAUDE_EFFORT}` substitution in skill prompts.
  Which cdocs skills benefit most from effort-adaptive behavior?
  Primary candidates: `/cdocs:propose`, `/cdocs:report`.
  Secondary candidates: `/cdocs:devlog`, `/cdocs:review`.
  Out of scope candidates: `/cdocs:init` (one-shot setup), `/cdocs:triage` (mechanical).

- **Verbosity scaling design.**
  What does each effort level produce?
  Sketch:
  - `low`: minimal frontmatter + BLUF + 2-3 section stubs.
  - `medium`: current behavior (default sections).
  - `high`/`xhigh`/`max`: current behavior plus all optional sections (Stories, Edge Cases, Verification Methodology, etc.).

- **Slash command collision audit.**
  Survey the marketplaces currently shipped under `anthropics/claude-plugins-official` and the public clauthier marketplace for any `propose`, `report`, `review`, `devlog`, `implement`, `oversee`, `triage`, `nit_fix`, `rfp`, `status`, `init` command name overlaps.
  CC's slash-command resolution disambiguates via the `plugin:` prefix, but bare invocations may surprise users.

- **Backwards compatibility.**
  Existing invocations that do not consume `${CLAUDE_EFFORT}` must continue to work identically.
  Test against an unset variable (`${CLAUDE_EFFORT:-medium}`-style fallback).

## Known Requirements

- No regression in default behavior when `${CLAUDE_EFFORT}` is unset.
- Effort-adaptive logic lives in the SKILL.md prompt body, not in hook scripts.
- Collision audit is informational; renaming `cdocs:*` commands is out of scope (breaking change).

## Prior Art

- May 2026 CC plugin API report identifies `${CLAUDE_EFFORT}` as a skill-prompt variable: [cdocs/reports/2026-05-06-cc-plugin-api-updates.md](../reports/2026-05-06-cc-plugin-api-updates.md).
- Existing skill templates in `plugins/cdocs/skills/*/SKILL.md` and `plugins/cdocs/skills/*/template.md`.
- CC slash-command resolution behavior (per the same May 2026 report): plugins now resolve correctly when multiple share a name, but the user-facing experience for bare invocations is unclear.

## Open Questions

1. **Effort-level granularity.**
   Three buckets (`low`, `medium`, `high`) or finer (mapping all five: `low`, `medium`, `high`, `xhigh`, `max`)?
2. **Per-skill opt-in.**
   Should adaptive verbosity be opt-in per skill (each SKILL.md decides) or opt-out (default behavior with override)?
3. **Collision response policy.**
   If a `cdocs:*` command collides with a popular plugin, do we (a) accept and document, (b) suggest the user prefer `cdocs:command-name` invocation form, or (c) take the breaking-change hit and rename?
4. **Surfaced demand signal.**
   This RFP is deferred until a user requests it.
   What constitutes "a user requesting it"? An issue? A casual ask in chat? A second user encountering the same pain?

## Trigger to Elaborate

This RFP remains a stub until one of:

- A user explicitly asks for adaptive skill verbosity.
- A real slash-command collision is reported (cdocs command shadows or is shadowed by another plugin).
- Phase 1 of [the May 2026 improvements proposal](2026-05-08-cdocs-plugin-improvements.md) ships and demand surfaces during use.
