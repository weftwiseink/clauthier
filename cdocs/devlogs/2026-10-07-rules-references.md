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

- next_steps: dispatch proposer (`/cdocs:propose`), then fresh opus reviewer rounds.
- important_files: `plugins/cdocs/rules/*.md`, `plugins/cdocs/skills/init/SKILL.md`, `plugins/cdocs/hooks/inject-rules.ts`, `plugins/cdocs/agents/*.md` Startup blocks, `plugins/cdocs/README.md:112-116`
- callouts:
  - decision: overseer is this top-level session (not nested), per `overseers.md`.
  - todo: maintainer has doubts about the "advisor subagent" wording in `overseers.md` "Stay thin"; out of this loop's scope.

## Workstream Devlogs

## Iteration Log

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | notes |
|---|---|---|---|---|---|---|

## Judge Log

## Dispatch/Return Events

- 2026-10-07T21:42 dispatch: opus `cdocs:proposer` (`/cdocs:propose --dispatched`) to author `cdocs/proposals/2026-10-07-rules-references.md`.

## Steering Log

- 2026-10-07: maintainer: "Rules heading replacements work fine but we should have a way to 2x check it"; "Maybe we can reconsider the concatenation through some more recent affordance."
