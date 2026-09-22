---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-22T00:00:00-07:00
task_list: meta/agent-dispatch-labeling
type: devlog
state: live
status: wip
tags: [meta, tooling, cost, orchestration, agent-dispatch]
---

# Agent Dispatch Labeling: Full-Send Devlog

> BLUF(claude-sonnet-5/agent-dispatch-labeling): Running `/cdocs:full-send` end-to-end on the proposal to label implementer/proposer subagents at dispatch time (`cdocs:implementer`/`cdocs:proposer` instead of bare `general-purpose`), per action item #1 of `cdocs/reports/2026-09-20-token-spend-by-role.md`.

## Objective

Fix the labeling gap diagnosed in `cdocs/reports/2026-09-20-token-spend-by-role.md`: `/cdocs:iterate` and `/cdocs:propose-revise` dispatch their implementer/proposer/reviser roles with bare `subagent_type: "general-purpose"`, making them invisible to any `cdocs:*`-scoped usage-DB query. Add dedicated `cdocs:implementer` and `cdocs:proposer` agent types, same tool allowlist, update the two dispatch sites, and check `full-send`/`oversee` for their own direct dispatches that would also need the fix.

## Plan

1. `/cdocs:propose-revise` loop (this devlog's Turn 0-N): dispatch a fresh proposer to author `cdocs/proposals/2026-09-22-label-implementer-proposer-agents.md`, then run review/revise rounds to `review_ready` + accepted.
2. `/cdocs:iterate` loop: dispatch fresh implementer/reviewer (old `general-purpose`/`"reviewer"` types, since the new types don't exist until this proposal lands) to implement, review, and drive to accept-or-escalate.
3. Land the work with frequent conventional commits.

## Overseer Mode

This session runs both loops in overseer mode per `orchestration-discipline.md`: dispatch-by-default (propose-revise's stricter "even trivial ones" bar applies through the propose-revise phase), single-writer file ownership, fresh reviewer/judge each round, durable state in this devlog before compacting.

## Propose-Revise Phase

### Iteration Log (propose-revise)

| round | proposer/reviser | reviewer | verdict | notes |
|---|---|---|---|---|
| 1 | @claude-opus-4-8 (proposer) | n/a (self-review) | review_ready | Authored proposal; self-review added the path-restriction-hook trap (do not confine implementer/proposer) as an edge case + Phase 3 constraint. Reviser reuses `cdocs:proposer`; new agents use `model: inherit` (no pin); full-send/oversee confirmed to inherit the fix by composition (no own dispatch). |
| 2 | @claude-opus-4-8 (reviser) | n/a (nit-fold, accepted round 1) | accepted-with-nits-folded | Folded 4 non-blocking review nits: BLUF cost-role framing (proposer 7.4% is smaller of the two conflated roles, not 2nd overall); clarified only `iterate` line 74 is a literal `subagent_type`, `propose-revise` is prose; softened `model: inherit` "reproduces today" claim (omission is the exact no-pin match) and added the OC `MODEL_MAP` unmapped-`inherit` concern with A/B/C Phase 1 gate options. |

## Changes Made

| File | Description |
|---|---|
| `cdocs/proposals/2026-09-22-label-implementer-proposer-agents.md` | New proposal specifying the implementer/proposer dispatch-labeling fix (status: review_ready, accepted round 1). Round 2 folded 4 accepting-round review nits. |
| `plugins/cdocs/agents/implementer.md` | SPEC ONLY (not yet created): `tools: "*"`, `model: inherit`, preloads `cdocs:implement`, Startup rule-reading pattern. A later `/cdocs:iterate` loop creates it. |
| `plugins/cdocs/agents/proposer.md` | SPEC ONLY (not yet created): `tools: "*"`, `model: inherit`, preloads `cdocs:propose`, Startup rule-reading pattern; also serves the reviser role. A later `/cdocs:iterate` loop creates it. |
| `cdocs/proposals/2026-09-22-label-implementer-proposer-agents.md` | Iterate phase: status `implementation_ready` -> `implementation_wip`. |
| `plugins/cdocs/agents/implementer.md` | Iterate phase: CREATED. `tools: "*"`, no `model:` pin (see Implementer Notes A/B/C decision, supersedes the SPEC-ONLY `model: inherit` row above), preloads `cdocs:implement`, relative-then-fallback Startup pattern, dispatched-mode constraints. |
| `plugins/cdocs/agents/proposer.md` | Iterate phase: CREATED. `tools: "*"`, no `model:` pin (supersedes SPEC-ONLY row above), preloads `cdocs:propose`, Startup pattern; serves both proposer and reviser roles. |
| `plugins/cdocs/skills/iterate/SKILL.md` | Iterate phase: Turn N.a literal `subagent_type: "general-purpose"` -> `"cdocs:implementer"`; Roles Implementer prose relabeled. |
| `plugins/cdocs/skills/propose-revise/SKILL.md` | Iterate phase: Proposer/Reviser prose relabeled to `cdocs:proposer` (no literal existed); completed the truncated Reviser line with the reuse rationale. |
| `plugins/cdocs/rules/workflow-patterns.md` | Iterate phase: Iterative Implementation Loop Implementer role relabeled to `cdocs:implementer`. |
| `plugins/cdocs/skills/iterate/template.md` | Iterate phase: illustrative `impl-1 (general-purpose)` handles -> `impl-1 (cdocs:implementer)` (3 spots). |
| `plugins/cdocs/README.md` | Iterate phase: agent path-resolution list adds `implementer`, `proposer`; OC support table converted-agent count `4` -> `6`. |

## Propose-Revise Phase: Result

Proposal `cdocs/proposals/2026-09-22-label-implementer-proposer-agents.md` accepted round 1 (`cdocs/reviews/2026-09-22-review-of-label-implementer-proposer-agents.md`), 4 non-blocking nits folded round 2 (commit `333d8a8`).
Overseer transitioned proposal `status: review_ready` -> `implementation_ready` (trivial frontmatter edit, done inline per `/cdocs:iterate`'s dispatch-carve-out for single-line edits).
Proceeding to `/cdocs:iterate`.

## Iterate Phase

### Turn 0 (Brief)

Scope: full proposal (all 4 implementation phases: create `plugins/cdocs/agents/implementer.md` and `proposer.md`; relabel the two dispatch sites in `iterate/SKILL.md` and `propose-revise/SKILL.md`; update illustrative handles and prose in `iterate/template.md` and `workflow-patterns.md`; update `README.md`'s agent-list and OC-agent-count spots; verify `build-opencode.ts` OC output including the `model:` field per the proposal's A/B/C gate).
Verification floor: config/doc-only change with no runtime service to exercise; verification is static (grep-based confirmation that no remaining `subagent_type: "general-purpose"` literal or prose reference to the old implementer/proposer roles survives at the two dispatch sites, that the new agent files parse as valid frontmatter, and that `npm run build:cdocs` succeeds and the OC agent count/model-field behavior matches the proposal's Phase 4 criteria). Concrete failure-picture: a `grep -rn 'subagent_type: "general-purpose"' plugins/cdocs/skills/iterate/SKILL.md` or the `propose-revise` prose line still matching after the change, or `build:cdocs` erroring/warning unexpectedly, would mean the fix did not land.
`--judge-after` defaults to 3 (not overridden).

Implementer and reviewer this round use the OLD `general-purpose`/`"reviewer"` subagent types, since the new `cdocs:implementer`/`cdocs:proposer` types being created by this very loop do not exist yet (bootstrap constraint, per task instructions).

### Iteration Log

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | overseer_ctx_est | inline_work | notes |
|---|---|---|---|---|---|---|---|---|

### Judge Log

| judge_iteration | trigger | verdict | overseer_thinness | rationale | judge_path |
|---|---|---|---|---|---|

### Dispatch/Return Events

| event | agent_handle | target_files | at | notes |
|---|---|---|---|---|
| dispatch | impl-1 (general-purpose) | `plugins/cdocs/agents/implementer.md`, `plugins/cdocs/agents/proposer.md`, `plugins/cdocs/skills/iterate/SKILL.md`, `plugins/cdocs/skills/propose-revise/SKILL.md`, `plugins/cdocs/skills/iterate/template.md`, `plugins/cdocs/rules/workflow-patterns.md`, `plugins/cdocs/README.md`, `scripts/build-opencode.ts` (read/verify only unless proposal requires a change), this devlog's `## Changes Made` table and an `### Implementer Notes` subsection only (overseer owns Iteration/Judge/Dispatch/Steering tables) | 2026-09-22T10:50:00-07:00 | Turn 1.a: full-proposal implementation, all 4 phases |
| return | impl-1 (general-purpose) | n/a | 2026-09-22T11:05:00-07:00 | Implemented all 4 phases across 7 commits (`2987f74`, `21ea8cc`, `ae91a18`, `815655f`, `5cad16a`, `9ea3d77`, `1b070a3`). Chose model:-field option B (omit) per Phase-1 empirical gate: `inherit` broke the OC build (unmapped-alias warning + invalid emitted value), omission is OC-clean and the exact behavioral match for `general-purpose`'s no-pin state. `npm run build:cdocs` -> 6 agents, no warnings. Proposal left at `implementation_wip`. |
| dispatch | rev-1 (cdocs:reviewer) | none (read-only; may only Edit target proposal's `last_reviewed` field per reviewer constraints) | 2026-09-22T11:06:00-07:00 | Turn 1.b: review the implementation |

### Steering Log

| at | kind | target | content | applied_at_iteration |
|---|---|---|---|---|

### Implementer Notes

Turn 1 implementer (dispatched). Implemented all four phases of the proposal. Small focused commits, one logical change each.

**`model:` field A/B/C decision: chose (B) omit `model:` entirely.**

The proposal left this an empirical Phase 1 gate. The two decision inputs it names:

1. *Does a per-dispatch `-m`/`-f` override still win?* This input is only material to options that ship a pin (A `inherit`, C `inherit`+MODEL_MAP). Under (B) there is no agent-file pin at all, so the dispatch-time/floor model governs entirely: that is by definition identical to `general-purpose`'s current no-pin behavior, which is exactly what a labeling-only change must preserve. The `reviewer.md` precedent (pins `model: opus` yet is still subject to `iterate`'s `-m` for review rounds) confirms the Task/Agent dispatch contract the proposal states: a per-dispatch model override takes precedence over an agent file's `model:` default. With (B) there is simply nothing to override. I could not run a live `-m` dispatch to measure `turns.model` because a dispatched subagent cannot dispatch subagents (`Task` unavailable); that live model-DB check is `deferred-to-followup` per the proposal's Verification Methodology (self-referential change, runs as a separate top-level invocation).

2. *OpenCode build cleanliness (this I ran empirically).* Building with `model: inherit` produced, for BOTH new agents:
   ```
   Warning: Unknown model alias "inherit" — passing through as-is
   ```
   and emitted a literal `model: inherit` line into the OC agent (`build/cdocs/opencode/agents/implementer.md:4:model: inherit`), which is not a valid OC `provider/model` path. Switching to omission rebuilt with NO warning and NO model line (verified: `grep '^model:'` on both OC outputs returns nothing). Option (C) — ship `inherit` + extend `MODEL_MAP` — was rejected: `inherit` has no concrete OC model to map to (OC's "inherit" IS omission), so (C) would be a needless `build-opencode.ts` code change to reproduce what (B) gets for free, against the repo's deduplication/simplicity preference.

Decision: (B) omission is the exact behavioral match for `general-purpose`'s no-pin state AND the OC-clean outcome, with zero code change. To prevent the omission reading as an oversight (the proposal's stated worry, since all four existing named agents carry a `model:` field), I added a 3-line YAML comment above `description:` documenting the deliberate no-pin intent. The comment is inert to both parsers: CC/YAML treats `#` as a comment, and `build-opencode.ts`'s `parseFrontmatter` regex (`^(\w[\w-]*?):`) does not match a `#` line, so it neither sets `cc.model` nor emits an OC model line (confirmed by the clean build).

**Path-restriction-hook trap (respected).** Did NOT add `implementer`/`proposer` to `validate-cdocs-edit-path.sh`'s `CDOCS_AGENTS` allowlist (still `"triage nit-fix reviewer"`, file unmodified). Confining the implementer to `cdocs/` would break its repo-wide edit job; confining the proposer would be a new restriction `general-purpose` lacks today. Both out of this labeling scope.

**`tools: "*"` OC parity note (pre-existing, not a regression).** The `tools: "*"` frontmatter maps to `read/edit/write/bash: false` in the OC output and emits `Warning: Unknown CC tool ""*""`. This is pre-existing behavior shared by `reviewer.md` (which also uses `tools: "*"`); the new agents' OC frontmatter is byte-shape-identical to reviewer's apart from the (correctly absent) model line. Fixing the converter's `*`-handling is out of scope for this labeling change.

**No deviations from the proposal's spec** beyond the (B)-over-(A) model call the proposal explicitly delegated to this Phase 1 gate, and completing the truncated Reviser line in `propose-revise/SKILL.md` (it ended mid-sentence at "May be fresh" with no newline; I finished it with the reuse rationale from the proposal's Important Design Decisions).

## Verification

Static verification (config/doc-only change, no runtime service; live dispatch + `usage.db` model/agent_type check is `deferred-to-followup` as a separate top-level invocation per the proposal's Verification Methodology, since a dispatched subagent cannot dispatch a live `/cdocs:iterate` turn).

**1. Dispatch-site literals/prose no longer name `general-purpose` for these roles:**

```
$ grep -rn 'subagent_type: "general-purpose"' plugins/cdocs/skills/iterate/SKILL.md
$ echo "exit=$?"
exit=1        # no match

$ grep -n 'general-purpose' plugins/cdocs/skills/propose-revise/SKILL.md
$ echo "exit=$?"
exit=1        # no match

$ grep -n 'general-purpose' plugins/cdocs/skills/full-send/SKILL.md plugins/cdocs/skills/oversee/SKILL.md
$ echo "exit=$?"
exit=1        # no match — composition-check finding holds, no edits needed
```

Remaining `general-purpose` references across the plugin (audited, all intentional/unrelated): the new `implementer.md`/`proposer.md` prose documenting the catch-all they replace, and `ablate/SKILL.md` (an unrelated tool-gating discussion, not an implementer/proposer/reviser dispatch).

**2. New agent files exist with valid frontmatter and the Startup pattern:**

```
$ node -e "...frontmatter block match..." # implementer / proposer
implementer frontmatter block OK
proposer frontmatter block OK
```

Both mirror `reviewer.md`: `name`, no `model:` pin, `description`, `tools: "*"`, `skills:` (`cdocs:implement` / `cdocs:propose`), `color` (`blue` / `cyan`), and a `## Startup` section with the relative-then-`plugins/cdocs/rules/*.md`-fallback rule-reading plus the SessionStart-hook NOTE.

**3. OpenCode build picks up both agents cleanly (count 6, no model warning):**

```
$ npm run build:cdocs
  Converting 6 agents...
  Agents converted: 6
$ ls build/cdocs/opencode/agents/ | grep -E 'implementer|proposer'
implementer.md
proposer.md
$ grep -n '^model:' build/cdocs/opencode/agents/implementer.md build/cdocs/opencode/agents/proposer.md
(no output — OC-clean, no model line)
```

**4. Path-restriction hook untouched (trap respected):**

```
$ grep -n 'CDOCS_AGENTS=' plugins/cdocs/hooks/validate-cdocs-edit-path.sh
16:CDOCS_AGENTS="triage nit-fix reviewer"
$ git status --porcelain plugins/cdocs/hooks/validate-cdocs-edit-path.sh
(no output — unmodified)
```
