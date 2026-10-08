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

- next_steps: iterate round 1: implementer on phases 1-3 in worktree `../rules-references` (branch `rules-references`), then fresh reviewer.
- important_files: `plugins/cdocs/rules/*.md`, `plugins/cdocs/skills/init/SKILL.md`, `plugins/cdocs/hooks/inject-rules.ts`, `plugins/cdocs/agents/*.md` Startup blocks, `plugins/cdocs/README.md:112-116`
- callouts:
  - decision: overseer is this top-level session (not nested), per `overseers.md`.
  - todo: maintainer has doubts about the "advisor subagent" wording in `overseers.md` "Stay thin"; out of this loop's scope.

## Workstream Devlogs

| devlog | concern | writer | status |
|---|---|---|---|
| `cdocs/devlogs/2026-10-07-rules-references-impl.md` (branch `rules-references`) | phases 1-3 implementation | implementer (opus) | wip |

## Iterate Brief (Turn 0)

`/cdocs:iterate cdocs/proposals/2026-10-07-rules-references.md` (proposal `implementation_ready`, nits `6be476b`), overseer: this top-level session.
Scope: full proposal, phases 1-3, in worktree `../rules-references` on branch `rules-references`; the overseer lands it.
Verification floor: the proposal's Verification Methodology steps 1-5: `npm run test:rules` green and red on mutations; phase 3 canary gate passes on the swapped word and `rules_check` matches its with-import baseline per assertion (re-run once on mismatch); a scratch project from the changed init shows `.claude/rules/cdocs.md` once in `/context` with no import; plugin `cdocs:nit-fix` applies a sentinel convention with no rule-file Read/Glob in either agent transcript; `chat-record.test.sh --only init_real` passes.
Failure picture: a canary reply with only `heliotrope`, a `nit-fix` transcript that Reads a rule path or misses the sentinel, or `test:rules` passing on a mutated filename reference.
If the phase 3 gate fails, phase 3 stops and phases 1-2 land alone (an accepted outcome, not a Revise).

## Iteration Log

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | notes |
|---|---|---|---|---|---|---|
| r1 | proposer (opus) | reviewer (opus, fresh) | revise | n/a | `cdocs/reviews/2026-10-07-review-of-rules-references.md` | blocking: per-file delivery not worth migration (drop `@`-import instead); drop simulated init from check |
| r2 | proposer (opus, warm) | reviewer (opus, fresh) | revise | n/a | `cdocs/reviews/2026-10-07-review-of-rules-references-r2.md` | blocking: phase 3 `rules_check` gate can never pass (fails 3/5 with import); use canary compaction probe |
| r3 | proposer (opus, warm) | reviewer (opus, fresh) | revise | n/a | `cdocs/reviews/2026-10-07-review-of-rules-references-r3.md` | blocking (empirical, 2/2 runs): compaction summary carries canary; fix = swap canary A->B on disk after turn 1, pass only on B |
| r4 | proposer (opus, warm) | reviewer (opus, fresh) | proposal_accepted | n/a | `cdocs/reviews/2026-10-07-review-of-rules-references-r4.md` | swap probe re-run passed; no-compact control returned A, so re-injection is compaction-triggered and reads disk; 3 nits |

## Judge Log

## Dispatch/Return Events

- 2026-10-07T21:42 dispatch: opus `cdocs:proposer` (`/cdocs:propose --dispatched`) to author `cdocs/proposals/2026-10-07-rules-references.md`.

- 2026-10-07T21:55 return: proposal `e8faa7d`, `review_ready`. Recommends heading-name references, `scripts/check-rule-refs.ts` + `npm run test:rules` blocking CI job, per-file `.claude/rules/cdocs/<name>.md` delivery without `@`-import (docs + v2.1.293 probe; compaction re-injection docs-only). Adds `scripts/inject-rules.test.ts` (2 of 6 hook-testing RFP items). Found audit misses: `nit-fix.md` Startup variant, false rule-read claims at `nit_fix/SKILL.md:48`, `triage/SKILL.md:69`; skill links also broken in OC layout.
- 2026-10-07T21:57 dispatch: fresh opus `cdocs:reviewer`, round 1.
- 2026-10-07T22:05 return: r1 revise (`8753317`).
- 2026-10-07T22:06 dispatch: same warm proposer for r1 revision (findings moderate, context ~170K).
- 2026-10-07T22:12 return: r1 revision `1add187`: keep `cdocs.md`, drop `@`-import gated on `rules_check` without import (phase 3 step 1, revert on fail); alphabetical concat; no hook changes; check against source headings + `--materialized` in `init_real`. Unrequested: removed TS init-list assertion (bash `chat-record.test.sh --unit` already covers it).
- 2026-10-07T22:13 dispatch: fresh opus `cdocs:reviewer`, round 2.
- 2026-10-07T22:20 return: r2 revise (`cabe8f9`).
- 2026-10-07T22:31 dispatch: warm proposer for r2 revision.
- 2026-10-07T22:36 return: r2 revision `5db40f8`: canary compaction probe replaces `rules_check` gate (kept as no-regression comparison); alphabetical-order change and `${CLAUDE_PLUGIN_ROOT}` exception dropped; nits fixed.
- 2026-10-07T22:37 dispatch: fresh opus `cdocs:reviewer`, round 3.
- 2026-10-07T22:42 return: r3 revise (`e64eac7`); reviewer ran the probe on v2.1.293 haiku: summary carried canary in 2/2; A->B swap variant passed 1/1.
- 2026-10-07T22:43 dispatch: warm proposer for r3 revision.
- 2026-10-07T22:50 return: r3 revision `7bd91b1`: heliotrope->marzipan on-disk swap after turn 1, temporary `--only canary_check` scenario, match all post-`compact_boundary` assistant blocks, with-import `rules_check` baseline before editing `init_rules`, release = one `plugin.json` bump and one push.
- 2026-10-07T22:51 dispatch: fresh opus `cdocs:reviewer`, round 4.
- 2026-10-07T22:58 return: r4 accept (`c6fd58d`), proposal `implementation_ready`.
- 2026-10-07T22:59 dispatch: warm proposer for r4 accept-round nits (nit 3 resolved as: re-run once on mismatch, only a repeated difference counts).
- 2026-10-07T23:03 return: accept-round nits `6be476b`.
- 2026-10-07T23:05 dispatch: opus `cdocs:implementer` (iterate round 1), worktree `../rules-references`; may claim files on branch `rules-references` only.

## Steering Log

- 2026-10-07: maintainer: advisor-subagent line removed from `overseers.md` (`20c83f3`); oversee concurrency defaults to parallel when practical (`c9e57f5`, `141049c`).
- 2026-10-07: maintainer: "Rules heading replacements work fine but we should have a way to 2x check it"; "Maybe we can reconsider the concatenation through some more recent affordance."
- 2026-10-07T22:30: maintainer considered path-style refs (`cdocs/rules/overseers.md#Stay thin`); rejected as awkward (collides with consumer `cdocs/` docs dir, internal rule files). Decision: heading references, keep concatenated `cdocs.md`, drop `@`-import. `/cdocs:full-send` the remainder: finish propose-revise, then `/cdocs:iterate` with this session as overseer.
