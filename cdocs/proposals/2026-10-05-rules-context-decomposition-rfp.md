---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-10-05T13:56:48-07:00
task_list: cdocs/rules-context-decomposition
type: proposal
state: live
status: request_for_proposal
tags: [rules, architecture, orchestration_discipline, future_work, init]
---

# Rules Context Decomposition

> BLUF(@claude-sonnet-5/cdocs/rules-context-decomposition): `/cdocs:init` inlines all six plugin rule files (~55KB total) into `.claude/rules/cdocs.md`, which every session and subagent loads via the CLAUDE.md `@`-import. `orchestration-discipline.md` alone is 23KB/270 lines and has accreted devlog-section formats, duplicated Cross-Target Degradation notes, and generic Bash guidance since it began as the canonical overseer-mode rule on 2026-09-01. Decompose: move devlog-section formats to the devlog skill/template, consolidate the Cross-Target notes, and trim `orchestration-discipline.md` back to orchestration (Pillars 1, 1b, 3).
> Motivated By: `cdocs/devlogs/2026-10-05-oversee-haiku-bash-wrapper.md`, `cdocs/proposals/2026-09-22-chat-record-devlog-management.md`, `cdocs/proposals/2026-10-05-post-compaction-resumption-rfp.md`

## Objective

Shrink and declutter the always-loaded rules context so that:
- devlog-section formats (handoff, Scratchpoint) live with the devlog skill/template rather than in an always-loaded rule,
- Cross-Target Degradation guidance is not duplicated across multiple always-loaded surfaces,
- `orchestration-discipline.md` holds only orchestration discipline, with chat-record/commit-protocol and generic Bash guidance split elsewhere,
- the combined always-loaded rules footprint has a defined token/byte budget.

## Context

- `plugins/cdocs/rules/` has six files, 56280 bytes combined: `frontmatter-spec.md` (4.3KB), `model-tiering.md` (4.8KB), `orchestration-discipline.md` (23.6KB), `oversee-arc.md` (12.0KB), `workflow-patterns.md` (7.7KB), `writing-conventions.md` (3.8KB).
  `/cdocs:init` (`plugins/cdocs/skills/init/SKILL.md` step 3) concatenates all six, frontmatter stripped, into `.claude/rules/cdocs.md`, which the source repo's `CLAUDE.md` `@`-imports. Per `cdocs/devlogs/2026-01-29-agent-affordance-research.md`, every dispatched subagent inherits this too.
- `orchestration-discipline.md` was added in [33722fa](https://github.com/weftwiseink/clauthier/commit/33722fab0ae549c5e5950c79c6b127adf0411c48) (2026-09-01) as the canonical "overseer mode" rule, 109 lines at the time. It is now 270 lines / 23.6KB, having accreted:
  - `### Handoff format`, `## Scratchpoint`, `### Chat record`, `### Resumption`, `### Commit protocol`, `### CLAUDE.md reseed mechanism` (all under `## Pillar 2: Context Persistence and Cleanliness`),
  - `## Bash: Avoid context bloat from careless bash commands`.
  A prior Cross-Target Degradation subsection was already removed from this file by [6821b43](https://github.com/weftwiseink/clauthier/commit/6821b43481d0ba1bbb504f0cadf7dc70f3c5adae) (2026-10-05), which also condensed the bash-runner caller guidance; the maintainer's complaint is about what that commit did not reach.
- Cross-Target Degradation sections (how rules/behavior change on targets lacking fork/SendMessage/compact/hooks, e.g. OpenCode or AGENTS.md-only tools) remain in `plugins/cdocs/rules/model-tiering.md` (`## Cross-Target Degradation`) and `plugins/cdocs/rules/oversee-arc.md` (`## Cross-Target Degradation`, cross-referenced from `plugins/cdocs/skills/oversee/SKILL.md`).
- Three agent files carry a `NOTE(claude-opus-4-6/cross-target-rules)` fallback comment about rule content surviving via SessionStart hook injection when file paths don't resolve: `plugins/cdocs/agents/triage.md`, `plugins/cdocs/agents/nit-fix.md`, `plugins/cdocs/agents/reviewer.md`.

## Scope

The full proposal should explore, per maintainer direction (2026-10-05):

1. **Devlog-section formats out of always-loaded rules.** Move the handoff format (Completed/Decisions Made/Open Todos) and Scratchpoint section format to the devlog skill/template. Keep only one-line ownership pointers in orchestration rules (overseer owns the Scratchpoint in a loop; a durable specialist keeps one only in its own devlog). Caveat to resolve: an overseer refreshes its Scratchpoint without re-invoking the devlog skill, so the template's section skeleton needs to be self-describing enough to use without the skill loaded.
2. **Cross-Target Degradation consolidation.** Decide whether the `model-tiering.md` and `oversee-arc.md` copies (and the `oversee/SKILL.md` cross-reference) move to the README/docs, or whether the OpenCode build (`scripts/build-opencode.ts`) injects genuinely-needed target notes at build time instead of carrying them in always-loaded rules. Also review whether the three agents' `NOTE(.../cross-target-rules)` fallback comments should be consolidated or kept as per-agent duplication.
3. **Candidate split of `orchestration-discipline.md`** (evaluate, not a decision):
   - `### Chat record`, `### Resumption`, `### Commit protocol` (and `### CLAUDE.md reseed mechanism`?) to their own small rule;
   - `## Bash: Avoid context bloat from careless bash commands` to its own small rule, or folded into `workflow-patterns.md`;
   - `orchestration-discipline.md` keeps only `## Pillar 1`, `## Pillar 1b` (both variants), and `## Pillar 3`.
4. Which rules must stay always-loaded versus which can live in skills that load on demand.
5. Whether `/cdocs:init` should stay all-or-nothing across the six files, or let a project select a subset.
6. A concrete token/byte budget target for the always-loaded rules context.
7. How to keep the source repo's `CLAUDE.md`, `AGENTS.md`, and the init materialization in sync after any split (new file(s) need registration at every surface `/cdocs:init` step 6 and the AGENTS.md inline template touch).
8. Dead-reference checks after moving sections: cross-links between rules and skills (e.g. `frontmatter-spec.md`'s reference to `orchestration-discipline.md` Pillar 2 "Resumption" for `chat_record` field semantics) must be updated to point at wherever content lands.

## Open Questions

- Sequencing: this is directed to land after the chat-record Phase 1b/2 work (`cdocs/proposals/2026-09-22-chat-record-devlog-management.md`) settles, and is itself a prerequisite for `cdocs/proposals/2026-10-05-post-compaction-resumption-rfp.md`'s re-test (which is already blocked pending this). Should this proposal be scoped now or wait for Phase 2 to land first?
- Does splitting `orchestration-discipline.md` change the post-compaction salience result independent of a resumption-specific fix, or is placement/wording the dominant factor regardless of file size?
- Is a single shared small rule for chat-record/resumption/commit-protocol content sufficient, or does it want to stay adjacent to Pillar 2's remaining "Context Persistence and Cleanliness" framing?
