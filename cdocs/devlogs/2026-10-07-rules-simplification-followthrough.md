---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T14:00:00-07:00
task_list: meta/rules-simplification
type: devlog
state: live
status: review_ready
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

- next_steps: maintainer review of the commits below; the open review items listed under Deferred.
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

- Wiring: `CLAUDE.md` and `plugins/cdocs/AGENTS.md` `@`-import `overseers.md` and `tool-use-safeguards.md`; the init AGENTS.md block names them (order: writing, workflow, overseers, tool-use, frontmatter), which also fixes the rule-order unit test.
- `init_real` assertions grep `` Top-level agents must use the `chat-record` command `` and `` **After a compaction** or when picking up a session, run `chat-record path` ``.
- Paraphrase sweep (coordinator's added scope): deleted the "Inline floor" lines in iterate, full-send, oversee, and the durable-state/resume clauses in propose-revise; deleted iterate's On-Resume Reconciliation section and the "rows are what on-resume reconciliation reads" sentence; replaced model-tier summaries with a pointer to `workflow-patterns.md` "Model Tiering".
  Kept: propose-revise's stricter "dispatch even trivial tasks" (loop-specific), ablate's inline floor (ablation-specific: arm contamination, run directory), iterate's Dispatch/Return Events and Steering Log tables (loop structure, not rule restatement).
- Handoffs: implement, oversee, judge now read the Scratchpoint plus any handoff present; iterate's Checkpoint defers to the devlog skill's Scratchpoint/Handoffs sections; the judge drops "forward continuation" (top-level devlogs are never split) and triage drops cross-family iteration numbering.
- Scratchpoint: iterate's template uses the devlog template's fields (`next_steps`, `graphify_query`, `important_files`, `callouts`); triage keys closure on `next_steps:`.

> NOTE(@claude-opus-5-5/meta/rules-simplification): Edits to the maintainer's new files, all minimal:
> `overseers.md`: "read the `## Scratchpoint` and latest handoff" became "and any handoff" (delete-on-pickup leaves at most one).
> `devlog/SKILL.md`: "above 300K" became "above ~400K"; "Heirarchies" became "Hierarchies"; chat-record link re-pointed; trailing newline.
> `workflow-patterns.md`: `# Model Tiering` became `##`; `orchestration-discipline.md` pointer became `overseers.md`.
> `tool-use-safeguards.md`: trailing newline only. `devlog/template.md`: chat-record comment re-pointed.

### Deferred (review items left alone per maintainer)

- `tool-use-safeguards.md` dropped "no directories, never `git add -A` or `commit -a`".
- `overseers.md` "Chat record" lacks the Claude-Code-only note (OpenCode has no `chat-record`).
- `graphify_query` in the Scratchpoint template is unexplained and graphify is opt-in (now also in iterate's template, for consistency).
- Other review nits not in scope: `overseers.md:9` dangling colon, `workflow-patterns.md` and `devlog/SKILL.md:42` missing periods, `devlog/SKILL.md:62` punctuation.

## Changes Made

| File | Description |
|------|-------------|
| `CLAUDE.md`, `plugins/cdocs/AGENTS.md`, `plugins/cdocs/README.md` | imports and rule list name the current rule files |
| `plugins/cdocs/skills/init/SKILL.md` | AGENTS.md block names overseers.md and tool-use-safeguards.md |
| `plugins/cdocs/hooks/tests/chat-record.test.sh` | `init_real` assertions re-pointed at overseers.md text |
| `plugins/cdocs/rules/*.md`, `skills/devlog/*` | re-pointed references, nits, 400K cap, "any handoff" |
| `skills/{iterate,full-send,propose-revise,oversee,implement,propose,ablate}` | re-pointed references, deleted restated discipline |
| `agents/{judge,triage,implementer}.md`, `skills/iterate/template.md` | Scratchpoint fields and handoff reads match the devlog skill |

## Verification

```
npm run build:cdocs                      exit=0
chat-record.test.sh --unit               chat-record tests: 95 passed, 0 failed
validate-cdocs-edit-path.test.sh         17 passed, 0 failed
grep -rnE 'orchestration-discipline|model-tiering|Resume from disk|Durable state|Pillar [0-9]|latest handoff|Heirarch' plugins CLAUDE.md scripts
                                         no matches (exit 1)
```

`init_real` (headless, needs live `claude`) was not run; its assertions were checked by hand against `overseers.md`.
Remaining "Stay thin" and "Chat record" references point at sections that exist in `overseers.md`.

## Verification pass

Independent sweep of `plugins/cdocs` (skills, templates, agents, hooks, injected text, READMEs), `CLAUDE.md`, and `scripts/` for broken references and stale paraphrases.
Every `rules/*.md` link and quoted section name resolves, except the fixes below.

| Finding | Fix |
|---|---|
| `chat-record.test.sh:820` `init_real` asserted "**After a compaction** or when picking up a session", which `overseers.md` no longer says (the Implementation Notes line above is wrong on this) | `d9aedec`: pattern anchored on `**After a compaction.* run \`chat-record path\`` |
| `agents/judge.md:33` expected loop tables to continue in a forward sub-devlog; top-level devlogs are never split | `2a0e316`: parenthetical dropped |
| `skills/iterate/SKILL.md:72` read "any handoff devlog"; handoffs are Scratchpoint subsections | `2a0e316`: read the top-level's Scratchpoint and any handoff |
| `skills/devlog/SKILL.md:118` pointed at a nonexistent "Issues Encountered and Solved" section (predates the simplification) | `9c06da8`: points at Debugging Process |

> WARN(@claude-opus-5-5/meta/rules-simplification): `816c387` changed more of `overseers.md:27` than the NOTE above records: it also dropped "or when picking up a session" and "before trusting the summary" (now "to get up to speed").
> Left as is for the maintainer to confirm or revert.

Not changed: `propose-revise/SKILL.md:26` "prior one's context is at 50%" is a reviser-freshness heuristic, not the ~400K handoff cap; `oversee` SKILL and template both describe the arc devlog (pre-existing duplication).

```
npm run build:cdocs                  exit=0
chat-record.test.sh --unit           95 passed, 0 failed
validate-cdocs-edit-path.test.sh     17 passed, 0 failed
```

`init_real` and `rules_check` (headless, live `claude`) not run.
