---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T14:00:00-07:00
task_list: meta/rules-simplification
type: devlog
state: live
status: wip
tags: [rules, simplification, dead_references, devlog_skill]
---

# Rules Simplification Follow-Through: Devlog

## Objective

Carry the maintainer's rules simplification (`bbc5cba`, `58bb5fa`) through the rest of the cdocs plugin so every reference agrees with it.
The maintainer's new text in `rules/overseers.md`, `rules/tool-use-safeguards.md`, `rules/workflow-patterns.md`, and `skills/devlog/` is authoritative; the review `cdocs/reviews/2026-10-07-review-of-rules-simplification.md` supplies the reference inventory.

Maintainer decisions applied:
- "Resume from disk" is dropped deliberately: references to it are deleted, not restored.
- Handoffs are transient (delete on pickup, per the devlog skill): readers are aligned to that model.
- Context cap is ~400K everywhere.

## Scratchpoint

- next_steps: re-point references, fix init/CLAUDE.md/tests, align Scratchpoint format, verify.
- important_files: `plugins/cdocs/skills/*/SKILL.md`, `plugins/cdocs/agents/*.md`, `plugins/cdocs/skills/init/SKILL.md`, `plugins/cdocs/hooks/tests/chat-record.test.sh`, `CLAUDE.md`
- callouts:
  - decision: deleted sections with no new home ("Resume from disk", "Durable state") lose their pointers; content still present elsewhere is re-pointed (Stay thin and Chat record to `overseers.md`, handoffs/Scratchpoint to the devlog skill, model tiering to `workflow-patterns.md` "Model Tiering").

## Plan

1. Mechanical wiring: `CLAUDE.md` `@`-imports, `plugins/cdocs/AGENTS.md`, init AGENTS.md block, README, test assertions.
2. Re-point or delete procedure references in skills, agents, rules.
3. Handoff lifecycle and Scratchpoint format alignment.
4. Review nits (H2 heading, "Hierarchies", trailing newline) and the 300K to 400K cap.
5. Verify: build, unit tests, final grep.

## Testing Approach

Existing suites: `npm run build:cdocs`, `chat-record.test.sh --unit`, `validate-cdocs-edit-path.test.sh`, plus a grep for the deleted names over `plugins/`, `CLAUDE.md`, `scripts/`.

## Implementation Notes

## Changes Made

| File | Description |
|------|-------------|

## Verification
