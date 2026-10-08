---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T21:40:37-07:00
task_list: cdocs/rules-references
type: devlog
state: live
status: wip
tags: [rules, rules_delivery, oversight]
chat_record:
  - cdocs/_chat/2026-10-07-63ac45de-462d-4f43-ae1c-4ab6d59049b8.md
---

# Rules References: Devlog

> BLUF: Top-level `/cdocs:propose-revise` loop on how shipped cdocs content (rules, skills, agents, templates) refers to rules so references resolve downstream, with a mechanical check, and whether rule concatenation should be reconsidered.

## Objective

Downstream, `/cdocs:init` concatenates `plugins/cdocs/rules/*.md` into one `.claude/rules/cdocs.md` (plus `AGENTS.md` / `.opencode/rules/` copies), so rule *filename* references are unresolvable there.
Decide a reference convention, a way to double-check it mechanically, and whether a newer delivery affordance makes concatenation unnecessary.

## Scratchpoint

- next_steps: await r1 revision; then fresh opus reviewer r2.
- important_files: `plugins/cdocs/rules/*.md`, `plugins/cdocs/skills/init/SKILL.md`, `plugins/cdocs/hooks/inject-rules.ts`, `plugins/cdocs/agents/*.md` Startup blocks, `plugins/cdocs/README.md:112-116`
- callouts:
  - decision: overseer is this top-level session (not nested), per `overseers.md`.
  - todo: maintainer has doubts about the "advisor subagent" wording in `overseers.md` "Stay thin"; out of this loop's scope.

## Workstream Devlogs

## Iteration Log

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | notes |
|---|---|---|---|---|---|---|
| r1 | proposer (opus) | reviewer (opus, fresh) | revise | n/a | `cdocs/reviews/2026-10-07-review-of-rules-references.md` | blocking: per-file delivery not worth migration (drop `@`-import instead); drop simulated init from check |

## Judge Log

## Dispatch/Return Events

- 2026-10-07T21:42 dispatch: opus `cdocs:proposer` (`/cdocs:propose --dispatched`) to author `cdocs/proposals/2026-10-07-rules-references.md`.

- 2026-10-07T21:55 return: proposal `e8faa7d`, `review_ready`. Recommends heading-name references, `scripts/check-rule-refs.ts` + `npm run test:rules` blocking CI job, per-file `.claude/rules/cdocs/<name>.md` delivery without `@`-import (docs + v2.1.293 probe; compaction re-injection docs-only). Adds `scripts/inject-rules.test.ts` (2 of 6 hook-testing RFP items). Found audit misses: `nit-fix.md` Startup variant, false rule-read claims at `nit_fix/SKILL.md:48`, `triage/SKILL.md:69`; skill links also broken in OC layout.
- 2026-10-07T21:57 dispatch: fresh opus `cdocs:reviewer`, round 1.
- 2026-10-07T22:05 return: r1 revise (`8753317`).
- 2026-10-07T22:06 dispatch: same warm proposer for r1 revision (findings moderate, context ~170K).

## Steering Log

- 2026-10-07: maintainer: advisor-subagent line removed from `overseers.md` (`20c83f3`); oversee concurrency defaults to parallel when practical (`c9e57f5`, `141049c`).
- 2026-10-07: maintainer: "Rules heading replacements work fine but we should have a way to 2x check it"; "Maybe we can reconsider the concatenation through some more recent affordance."
