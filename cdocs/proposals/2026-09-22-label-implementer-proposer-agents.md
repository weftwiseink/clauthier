---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-22T10:36:34-07:00
task_list: meta/agent-dispatch-labeling
type: proposal
state: live
status: review_ready
tags: [meta, tooling, cost, orchestration, agent-dispatch]
---

# Label Implementer and Proposer Subagents at Dispatch

> BLUF(claude-opus-4-8/agent-dispatch-labeling): Add `plugins/cdocs/agents/implementer.md` and `proposer.md` (same `tools: "*"` allowlist as `general-purpose`, no model pin), then switch the two dispatch sites in `/cdocs:iterate` and `/cdocs:propose-revise` from `subagent_type: "general-purpose"` to `"cdocs:implementer"` / `"cdocs:proposer"`.
> This is a labeling-only change so the usage DB self-classifies the two highest-cost roles (48.3% and 7.4% of a measured week); it changes no capability, permission, or model policy.
> The reviser reuses `cdocs:proposer` (same skill, same work); `full-send`/`oversee` inherit the fix by composition and need no edits.

## Summary

The claude-usage plugin's `usage.db` populates `agents.agent_type` verbatim from the dispatch `subagent_type`.
Because `/cdocs:iterate` and `/cdocs:propose-revise` dispatch their implementer, proposer, and reviser roles as bare `general-purpose`, those roles are indistinguishable from every other ad-hoc `general-purpose` dispatch and invisible to any `cdocs:*`-scoped cost query.
The report [`cdocs/reports/2026-09-20-token-spend-by-role.md`](../reports/2026-09-20-token-spend-by-role.md) measured these two roles at 48.3% (implementer) and 7.4% (proposer) of a week's total token spend and names this its highest-value cheap fix (action item #1).

The fix mirrors the existing named agents (`reviewer`, `judge`, `nit-fix`, `triage`): give implementer and proposer their own agent files and dispatch them by their own `subagent_type`.
Two agent files, two one-line dispatch changes, plus doc-consistency touch-ups.
The one non-obvious design call is the `model:` field: the new agents deliberately do NOT pin a model, so dispatch-time model selection (`-m`/`-f`/consumer floor) keeps governing exactly as it does today.

## Objective

Make implementer and proposer work self-classifying in `usage.db` so a `cdocs:*`-scoped dashboard attributes their spend by named role instead of dropping it into the undifferentiated `general-purpose` bucket.
Do this without changing what those subagents can do or which model they run on.

## Background

Read [`cdocs/reports/2026-09-20-token-spend-by-role.md`](../reports/2026-09-20-token-spend-by-role.md), specifically:

- **Open follow-up #1** (resolved): pins the root cause. `/cdocs:iterate` (`SKILL.md` line 74) and `/cdocs:propose-revise` (`SKILL.md` line 46) dispatch implementer/proposer/reviser with bare `subagent_type: "general-purpose"`, whereas `cdocs:reviewer`/`nit-fix`/`judge`/`triage` already carry dedicated agent types. Since `agents.agent_type` is populated verbatim from `subagent_type`, the two roles are unattributable.
- **Action item #1**: the concrete fix. Add `implementer.md` and `proposer.md` with the same tool allowlist as the `general-purpose` catch-all, then change the two dispatch lines. "`full-send`/`oversee` inherit the fix by composition. Zero ongoing cost; does not retroactively fix history."
- The measured stakes: implementer is 48.3% of the week's spend, proposer 7.4%. A dashboard scoped to named `cdocs:*` agents captures only 16.5% of real spend today.

This proposal does not re-derive those numbers; it specifies the mechanical fix they call for.

### Reference points in the codebase

- Dispatch sites to change: `plugins/cdocs/skills/iterate/SKILL.md` line ~74 (Turn N.a Implement) and `plugins/cdocs/skills/propose-revise/SKILL.md` line ~46 (Proposer role).
- Role descriptions that also name `general-purpose` and need updating for consistency: `iterate/SKILL.md` line ~43 (Implementer role), `propose-revise/SKILL.md` lines ~46-48 (Proposer and Reviser roles), and `plugins/cdocs/rules/workflow-patterns.md` line ~32 (Implementer description).
- Agent-file convention to mirror: `plugins/cdocs/agents/{reviewer,judge,nit-fix,triage}.md` (frontmatter shape and "Startup" rule-reading pattern).
- Rules-delivery architecture the "Startup" pattern depends on: `plugins/cdocs/README.md` "Rules Integration" (lines ~57-138), the 3-layer `/cdocs:init`-first delivery with agent relative-path fallback.
- Model policy: `plugins/cdocs/rules/model-tiering.md`.

## Scope

**In scope:**

- Create `plugins/cdocs/agents/implementer.md` and `plugins/cdocs/agents/proposer.md`.
- Change the two dispatch lines to `subagent_type: "cdocs:implementer"` / `"cdocs:proposer"`.
- Update role descriptions and doc counts that name `general-purpose` or the agent count, for consistency.

**Out of scope (do NOT touch):**

- The `reviewer`, `nit-fix`, `triage`, and `judge` agent types. They are already correctly labeled.
- Any dispatch unrelated to the implementer/proposer/reviser roles (e.g. `Explore`, ad-hoc `general-purpose` spikes).
- `usage.db` and the claude-usage plugin itself. This change lets the DB self-classify going forward; it does not migrate history and does not modify the plugin.
- Tool permissions and model policy. The new agents keep `tools: "*"` (identical capability to `general-purpose`) and do not pin a model. This is a labeling change, not a capability or policy change.

> NOTE(claude-opus-4-8/agent-dispatch-labeling): This proposal is authoring only.
> It does not create the agent files or edit the dispatch lines.
> A later `/cdocs:iterate` loop executes the Implementation Phases below.

## Proposed Solution

Two new agent files plus two dispatch-line edits, following the established named-agent convention exactly.

### New agent files

Both files mirror `reviewer.md`: a short frontmatter block, a preloaded skill, and a "Startup" section with the relative-path-then-fallback rule-reading pattern and the SessionStart-hook NOTE.

`plugins/cdocs/agents/implementer.md`:

```yaml
---
name: implementer
model: inherit
description: Implement an accepted cdocs proposal with structured execution and frequent commits
tools: "*"
skills:
  - cdocs:implement
color: <unused-color>
---
```

`plugins/cdocs/agents/proposer.md`:

```yaml
---
name: proposer
model: inherit
description: Author or revise a cdocs design proposal with structured sections and implementation phases
tools: "*"
skills:
  - cdocs:propose
color: <unused-color>
---
```

Body of each: a one-paragraph role statement (analogous to reviewer.md's), then a "Startup" section copied from the existing agents' pattern:

```
## Startup

Before starting work, read these rule files for domain context:

    rules/writing-conventions.md
    rules/frontmatter-spec.md

If those paths yield no results, try `plugins/cdocs/rules/writing-conventions.md` and
`plugins/cdocs/rules/frontmatter-spec.md` as fallbacks for source-repo contexts.

> NOTE(...): If the files are not found via either path (e.g., in an external CC
> install), the rule content may still be available in session context via the
> SessionStart hook injection. Proceed with any rule content present in your context.
```

The preloaded skill (`cdocs:implement` / `cdocs:propose`) supplies the full workflow, exactly as `reviewer.md` preloads `cdocs:review`.
The agent body should NOT restate the skill's methodology; it points at the preloaded skill and adds only the startup rule-reading and any dispatched-mode constraints already implied by the skills (both skills support `--dispatched`).

### Dispatch-line changes

- `iterate/SKILL.md` line ~74: `subagent_type: "general-purpose"` becomes `subagent_type: "cdocs:implementer"`.
- `iterate/SKILL.md` line ~43 (Roles): "fresh `general-purpose` subagent" becomes "fresh `cdocs:implementer` subagent."
- `propose-revise/SKILL.md` line ~46 (Proposer role): "fresh initial `general-purpose` subagent dispatched with `/cdocs:propose`" becomes "fresh initial `cdocs:proposer` subagent dispatched with `/cdocs:propose`."
- `propose-revise/SKILL.md` line ~48 (Reviser role): note that the reviser also dispatches as `cdocs:proposer` (see Important Design Decisions).
- `workflow-patterns.md` line ~32: update the Implementer description from `general-purpose` to `cdocs:implementer` for consistency.

### Composition check: full-send and oversee

Verified by reading both skill files in full.
Neither `full-send/SKILL.md` nor `oversee/SKILL.md` contains its own literal `subagent_type: "general-purpose"` dispatch of an implementer, proposer, or reviser.

- `full-send/SKILL.md` is a pure composition: it oversees a `/cdocs:propose-revise` loop then a `/cdocs:iterate` loop, delegating every implementer/proposer/reviser dispatch to those composed skills. It inherits the fix with no edit.
- `oversee/SKILL.md` composes `/cdocs:full-send`, `/cdocs:iterate`, and `/cdocs:propose-revise` per proposal and "never reimplement[s] a loop." Its only mention of "implementers" (line ~105) describes the composed loops' concurrent dispatches, not a dispatch of its own. Its `full <topic>` mode dispatches `/cdocs:propose` for arc scoping, but names no `subagent_type` literal to change; once `proposer.md` exists that scoping dispatch naturally carries `cdocs:proposer` with no line edit.

Conclusion: the report's "inherit the fix by composition" claim holds.
No `full-send`/`oversee` edits are required for this fix to be complete.

## Important Design Decisions

### Reviser reuses `cdocs:proposer`, no separate `cdocs:reviser` type

`propose-revise/SKILL.md` defines the reviser as "subagents dispatched with `/cdocs:propose` to make requested revisions."
The reviser runs the same skill (`/cdocs:propose`), needs the same tools, and performs the same semantic activity (proposal authoring) as the initial proposer; the only difference is fresh-versus-warm context, which the overseer already decides per dispatch (`propose-revise/SKILL.md` "ON REVISION").
That is a context-freshness decision, orthogonal to the agent type.

A distinct `cdocs:reviser` type would add a byte-identical third agent file and split "proposal authoring" into two DB buckets that measure the same activity, fragmenting exactly the attribution this change exists to consolidate.
It would also violate the repo's deduplication preference (`CLAUDE.md`: "Deduplicating code and docs with the same semantic content is highly desirable").
Decision: both the initial proposer and any reviser dispatch with `subagent_type: "cdocs:proposer"`.
This also matches the report's action item #1, which names only two new files.

### The new agents do not pin a model (`model: inherit`)

Today implementer and proposer run at whatever model the invoking `-m`/`-f` flags or the consumer's `CLAUDE.md` floor specify, NOT a fixed agent-level model.
`general-purpose` carries no model pin, so under the weftwise Opus floor these roles ran on Opus (per the report's model mix).
Preserving that dispatch-time-governed behavior is a requirement of a labeling-only change: pinning a fixed tier (e.g. `model: opus`) would silently convert a dispatch-time choice into a policy pin, which is out of scope and would defeat the `-f` first-round and consumer-floor dynamics the loop skills' `-m`/`-f` flags exist to serve.

How the model resolves is governed by the Task dispatch contract: a per-dispatch `model` override takes precedence over an agent definition's `model:` frontmatter, which is only the DEFAULT used when no override is passed.
This is why `reviewer.md` can pin `model: opus` yet still be subject to `iterate`'s `-m` for review rounds: the pin is the default, the `-m` override wins.

Given that, the new agents should default to deferring rather than pinning.
`model: inherit` makes the default equal to the dispatching overseer's model, which under a consumer floor equals the floor: this reproduces today's observed behavior (implementers on the Opus floor) and, per `model-tiering.md`'s "consumer floor wins" precedence, lets the plugin ship without encoding a tier decision.
When the overseer passes `-m`/`-f`, that dispatch-time model overrides `inherit`.

An explicit `inherit` is preferred over omitting the field entirely: all four existing named agents carry an explicit `model:`, and `inherit` documents the intent ("deliberately not pinned; defer to floor/dispatch") rather than reading as an oversight.

> NOTE(claude-opus-4-8/agent-dispatch-labeling): Why not match `reviewer`/`judge` and pin `model: opus`?
> Because implementer/proposer sit under the loop skills' explicit `-m`/`-f` model-selection surface and have no fixed tier today.
> Per `model-tiering.md`, their work is neither the mechanical/deterministic tier (no clean pass/fail rubric) nor the lead/overseer/judgment adjudication tier (that tier is the overseer, reviewer, and judge, not the dispatched worker doing the open-ended build/write).
> The rule does not cleanly name a tier for "the dispatched worker executing open-ended implementation or authoring," so `inherit` (defer to floor/dispatch) is the honest default rather than a guessed pin.

The implementation phase must empirically confirm that `model: inherit` yields dispatch-governed selection in the target Claude Code version (see Verification Methodology); if it does not behave as expected, fall back to omitting the field.

### Same tool allowlist (`tools: "*"`)

The new agents use `tools: "*"`, identical to the `general-purpose` catch-all they replace for these roles.
This is a labeling change, not a capability change: narrowing the tool surface would break implementer and proposer work that legitimately needs the full toolset.

## Edge Cases / Challenging Scenarios

- **The path-restriction hook must NOT confine the new agents.** `plugins/cdocs/hooks/validate-cdocs-edit-path.sh` blocks edits outside `cdocs/(devlogs|proposals|reviews|reports)/` for any agent whose `agent_type` is in its `CDOCS_AGENTS="triage nit-fix reviewer"` allowlist, and its own comment (lines 8-9) instructs "When adding new cdocs agents ... also add their name to the CDOCS_AGENTS allowlist." Following that instruction here would be a bug: the implementer's entire job is editing source files repo-wide, so confining it to `cdocs/` breaks it. The proposer only writes under `cdocs/proposals/`, but confining it is a NEW restriction the current `general-purpose` proposer does not have, which is a capability change outside this labeling scope. Do NOT add `implementer` or `proposer` to `CDOCS_AGENTS`. This hook is CC-only (the README lists OC path-restriction as "Not available"), so it is the only file to consider.
- **`inherit` does not resolve to dispatch-time selection in the target CC version.** If empirically `model: inherit` pins to the overseer's model in a way that ignores an `-m` override, the loop skills' `-m`/`-f` for these roles would silently no-op. Mitigation: the model-interaction check is a gating step in Phase 1; fall back to omitting `model:` if `inherit` misbehaves.
- **In-flight and historical data.** The change is not retroactive: existing `usage.db` rows keep `agent_type: general-purpose`. Any dashboard must still handle the pre-change history (the report already reconstructs it heuristically). This is expected, not a regression.
- **OpenCode build.** `scripts/build-opencode.ts` reads agent files dynamically (`readdirSync(AGENTS_DIR)`, count via `agentFiles.length`); it has no hardcoded agent list or count, so the two new files are picked up automatically with no code change. The README's prose count ("4 agents converted to OC frontmatter format", line ~170) IS hardcoded and must be updated to 6.
- **`color` collisions.** Existing agents use purple/red/yellow/green. Pick two distinct unused colors for the new agents; a duplicate color is cosmetic only, not a failure.
- **Template example handles.** `iterate/template.md` shows illustrative handles like `impl-1 (general-purpose)`. These are examples, not dispatch code, but should be updated to `impl-1 (cdocs:implementer)` so the docs match the real dispatch type (template.md line ~33 explicitly says the parenthetical is "the subagent type").

## Test Plan

- **Agent files load.** After creating the files, `/cdocs:iterate` and `/cdocs:propose-revise` dispatch with the new `subagent_type` values without a "no such agent type" error.
- **DB self-classification.** After a real dispatch of each role, `usage.db.agents.agent_type` shows `cdocs:implementer` / `cdocs:proposer` for those agents (query the DB with Node `node:sqlite`, per the report's method, since there is no `sqlite3` CLI in the container).
- **Capability parity.** The dispatched implementer/proposer can use the same tools as before (spot-check a tool the role needs, e.g. `Bash`, `Write`, `Task`-not-applicable, is available).
- **Model behavior.** Confirm the dispatched role runs on the expected model: the floor when no `-m`, and the `-m`/`-f`-selected model when one is passed (see Verification Methodology).
- **No collateral change.** `reviewer`/`judge`/`nit-fix`/`triage` dispatches and their `agent_type` rows are unchanged; no unrelated `general-purpose` dispatch was relabeled.
- **Doc consistency.** No remaining stray `general-purpose` reference for the implementer/proposer/reviser roles except where illustrating history; the README agent count reads 6.

## Verification Methodology

This is a self-referential change to the cdocs skills themselves, so its runtime smoke test runs as a separate top-level invocation (a `deferred-to-followup` review-proof in iterate terms), not inside the same dispatched loop.

1. **Static check.** Grep confirms the two dispatch lines and the role descriptions now name `cdocs:implementer` / `cdocs:proposer`, and that no implementer/proposer/reviser dispatch still says `general-purpose`.
2. **Live dispatch + DB read.** Run a small real `/cdocs:iterate` (or `/cdocs:propose-revise`) turn, then query `usage.db` with `node:sqlite`:
   join `turns.agent_id` to `agents.agent_type` and confirm the new turns carry `cdocs:implementer` / `cdocs:proposer`.
   This is the ground-truth check that the label reaches the DB.
3. **Model-interaction check (gates the `model:` choice).** Dispatch the role twice: once with no `-m` (expect the consumer floor) and once with an explicit `-m "<cheaper model>"` (expect the override).
   Read `turns.model` for each dispatched agent in `usage.db` and confirm the resolved model matches the intent.
   If `model: inherit` does not honor the `-m` override, switch the agent files to omit `model:` and re-run.

> NOTE(claude-opus-4-8/agent-dispatch-labeling): `usage.db` is the authoritative verification surface here precisely because it is what the change targets.
> The report documents its quirks: use the `turns` columns (not `agents.total_tokens`), and query with Node `node:sqlite`.

## Implementation Phases

Small, mostly-independent phases. Phase 1 (agent files) has no dependency; Phase 2 (dispatch edits) can land alongside it; Phases 3-4 are doc consistency and verification.

### Phase 1: Create the two agent files

- Add `plugins/cdocs/agents/implementer.md` (preload `cdocs:implement`) and `proposer.md` (preload `cdocs:propose`), each with `tools: "*"`, `model: inherit`, a distinct unused `color`, the role-statement body, and the "Startup" relative-path-then-fallback rule-reading pattern plus the SessionStart-hook NOTE, mirroring `reviewer.md`.
- Gate: run the model-interaction check (Verification Methodology step 3) and confirm `model: inherit` honors an `-m` override; fall back to omitting `model:` if it does not.
- Success: both agents dispatch without error and pass the capability-parity spot check.

### Phase 2: Switch the two dispatch sites

- `iterate/SKILL.md` line ~74: `general-purpose` becomes `cdocs:implementer`.
- `propose-revise/SKILL.md` line ~46: `general-purpose` becomes `cdocs:proposer`.
- Success: static grep check passes; a live dispatch writes the new `agent_type` to `usage.db` (Verification step 2).

### Phase 3: Doc-consistency updates

- Role descriptions: `iterate/SKILL.md` line ~43, `propose-revise/SKILL.md` lines ~46-48 (including the Reviser note that it dispatches as `cdocs:proposer`), `workflow-patterns.md` line ~32.
- `README.md`: line ~104 (agent relative-path list currently "`nit-fix`, `triage`, `reviewer`, `judge`") adds `implementer` and `proposer`; line ~170 OC-support table count "4 agents" becomes 6.
- `iterate/template.md`: update illustrative handles from `general-purpose` to `cdocs:implementer` (lines ~33, ~52, ~72).
- `scripts/build-opencode.ts`: confirmed no hardcoded agent list or count; no code change needed (the dynamic `readdirSync` count picks up the new files). Included here only to record the confirmation.
- `validate-cdocs-edit-path.sh`: do NOT add `implementer` or `proposer` to `CDOCS_AGENTS` (see Edge Cases). The hook's maintenance comment invites it, but confining these roles is a capability change out of scope. No edit to this file.
- Success: no stray `general-purpose` reference for these roles remains except where illustrating history; the README count reads 6.

### Phase 4: Verification and OC build

- Run the Verification Methodology in full (static, live-dispatch + DB read, model-interaction).
- Run `npm run build:cdocs` and confirm the two new agents appear in `build/cdocs/opencode/agents/` and the converted-agent count is 6.
- Record the deferred smoke-test evidence (this change is self-referential; its runtime check runs as a separate top-level invocation).
- Success: `usage.db` self-classifies the two roles; OC build emits both agents; capability and model behavior match intent.
