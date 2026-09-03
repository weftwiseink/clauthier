# CDocs Overseer Arc

The reusable, tool-agnostic primitives of the arc layer: the layer ABOVE a single `/cdocs:full-send`, which sequences MULTIPLE proposals through their lifecycle.
This rule is the shared vocabulary any agent may cite without running `/oversee`: the arc-state-file schema, the claim-registry protocol, the footprint-overlap serialization heuristic, the arc-altitude troubleshooting budget, and the verification-depth ladder.
The active driver that applies these is the [`oversee`](../skills/oversee/SKILL.md) skill.

This rule BUILDS ON [`orchestration-discipline.md`](./orchestration-discipline.md) and does not restate it.
Every claim of thinness, single-writer safety, or liveness reconciliation below is INHERITED from that rule; this file adds only the cross-proposal / cross-arc delta.
Two altitudes, two durable substrates: `iterate`'s per-loop Iteration Log tracks turns WITHIN one proposal's loop; the arc-state file here tracks WHICH proposals in a chain are done and their ownership.

## Arc-State File (normative)

One JSON file per arc at `.claude/oversee/<arc-id>.json` is the durable resumption point.
It is read and reconciled PROGRAMMATICALLY by a possibly-concurrent second session, so it is structured fields, not the free prose of a devlog.
The human-readable arc narrative still lives in a normal arc devlog kept beside it (Completed / Decisions Made / Open Todos per [`orchestration-discipline.md`](./orchestration-discipline.md) Pillar 2); this JSON is the machine substrate, not a replacement for that handoff.

`arc_id` is minted from the invocation: `YYYY-MM-DD` plus a dash-cased slug of the `full <topic>` topic, or of the first proposal's basename for a `chain`.

Normative schema (copyable skeleton in [`../skills/oversee/template.md`](../skills/oversee/template.md)):

```jsonc
{
  "arc_id": "2026-09-03-oversee-cdocs-hooks",  // YYYY-MM-DD + dash-slug
  "mode": "chain",                    // chain | full
  "afk": false,                        // arc AFK field (see Troubleshooting/AFK below and the skill)
  "afk_policy": "hold",                // hold | skip-blocked
  "created_at": "2026-09-03T11:30:00-08:00",   // ISO 8601 with TZ
  "proposals": [
    {
      "path": "cdocs/proposals/2026-08-10-a.md",
      "status": "implementation_accepted", // mirrors the proposal's frontmatter at the last transition
      "arc_state": "done",             // pending | in_progress | blocked | done
      "specialist": "arc-impl-a",      // durable-specialist handle if interleaved, else null
      "devlog": "cdocs/devlogs/2026-09-03-a.md",
      "worktree": ".claude/worktrees/arc-a",  // or null for in-place
      "required_rung": "integration",  // verification-depth ladder rung (see below)
      "footprint": ["plugins/cdocs/rules/**", "cdocs/**"],  // path globs; may be scout-derived
      "full_cycle_retries": 0          // arc-altitude troubleshooting-budget counter
    }
  ],
  "position": 1,                       // index into proposals of the current proposal
  "claims": [ /* live claim handles this arc holds; see Claim Registry */ ],
  "budget": { "full_cycle_retries_max": 2 }
}
```

Field semantics that carry the reconciliation logic:

- `arc_state` is the arc overseer's OWN bookkeeping (`pending | in_progress | blocked | done`).
- `status` MIRRORS the proposal's frontmatter (`implementation_ready`, `implementation_accepted`, ...) at the last transition, so a resumed overseer can detect drift against `arc_state`.
- The reconciled TRIPLE (proposal frontmatter `status`, the proposal's final devlog handoff, and `arc_state`), not any single field, is the durable decision basis for advance-vs-escalate.
  No single field is trusted to have been written atomically at the terminal moment.

The overseer writes this file at EVERY arc-level transition (proposal start, proposal terminal, escalation, claim acquire/release), BEFORE compacting.
This is the arc-altitude analogue of Pillar 2's handoff-before-compact applied to the machine substrate; the prose half of the same checkpoint still goes to the arc devlog.

## Claim Registry (extends Pillar 1b to cross-arc altitude)

[`orchestration-discipline.md`](./orchestration-discipline.md) Pillar 1b guarantees single-writer ownership WITHIN one overseer's loop, checked against that loop's Iteration Log.
That check is invisible to a SECOND top-level `/oversee` in another worktree or a concurrent arc, which has no visibility into the first overseer's private log.
The claim registry is the cross-arc / cross-session extension of that same guarantee, and nothing more: it does not restate Pillar 1b, it relocates the claim to a shared location.

The registry is a repo-global directory `.claude/oversee/claims/`, one file per claim, OUTSIDE any single devlog so every session in the repo can see it:

```jsonc
// .claude/oversee/claims/arc-a--plugins-cdocs-rules.json
{
  "arc_id": "2026-09-03-oversee-cdocs-hooks",
  "owner": "arc-impl-a",               // specialist / loop handle holding the claim
  "globs": ["plugins/cdocs/rules/**"], // the claimed footprint
  "acquired_at": "2026-09-03T11:40:00-08:00",
  "liveness": "live"                    // live | stale (reconciled on resume)
}
```

Protocol:

- Before starting or interleaving a proposal whose footprint intersects an EXISTING live claim owned by a different arc/owner, the overseer SERIALIZES (waits or defers that proposal) or re-scopes, exactly as Pillar 1b does within a loop, now across arcs.
- A durable specialist that owns its own files satisfies its claim BY CONSTRUCTION (Pillar 3 "file ownership by construction"); the registry matters at the moment a SECOND arc's agent is dispatched against an already-claimed path.
- On resume, a claim marked `live` whose owner is gone (no live children remain) is reconciled to `stale` and released, so the arc does not deadlock on a claim no one holds.
  This is Pillar 1b liveness reconciliation applied to the registry.

## Footprint-Overlap Serialization Heuristic

The decisive signal for serialize-vs-interleave is footprint overlap: do two proposals' agents touch overlapping files?

1. **Footprint declaration.** Each proposal declares a `footprint:` (a set of path globs its implementation will touch), read from a proposal frontmatter field or derived by a cheap footprint scout (sonnet tier per [`model-tiering.md`](./model-tiering.md)) that reads the proposals' Implementation Phases and predicts the touched paths.
2. **Overlap test.** Intersect the two footprints' glob sets. A non-empty intersection means the proposals CONFLICT.
3. **Decision.** Conflicting proposals SERIALIZE (run in arc order, one terminal before the next starts). Disjoint proposals are eligible to INTERLEAVE under the single overseer, subject to the one-specialist-per-workstream bound (Pillar 3) and the overseer's own context budget.
4. **Uncertainty defaults to serialize.** If footprints cannot be predicted with confidence (low scout confidence, or broad globs like `**/*`), serialize: a false conflict costs only latency, a missed conflict costs a clobber.

This adds the missing WHETHER-two-streams-may-run-at-all piece decided by real footprint intersection; the one-specialist-per-workstream bound from Pillar 3 remains the adjacent constraint that caps HOW MANY interleaved streams.

## Arc-Altitude Troubleshooting Budget

Rule: **isolate first, full-cycle second.**
When a proposal's loop is stuck debugging, cap expensive full-cycle retries (container rebuild, full integration run) at a small N (default 2, `budget.full_cycle_retries_max`) before the overseer requires a switch to an isolation strategy: a minimal repro, a bisect, or a dispatched focused-diagnostic `fork` (Pillar 3, disposable side-context).

Enforcement is at the ARC altitude ONLY, to stay inside the composed loop's black-box return contract:

- The overseer tracks full-cycle-retry count per proposal in the arc-state file, INFERRING it from what the composed loop reports UP (its devlog handoff and iteration count).
- When a proposal trends past the budget, the overseer escalates that proposal as `blocked`.
- It does NOT reach into the composed loop's judge: that channel is internal to `iterate`, and injecting into it would break the black box or require a new `iterate` parameter, both forbidden.
- Any budget signal the overseer WANTS a composed loop's judge to see travels only through the down-channel it already controls, the dispatch brief and `--verification-floor` prose (for example: "prefer isolating the fault over another full rebuild; you have one full-cycle retry left").

It is a budget the overseer WATCHES from the outside and enforces by escalation, not a hard kill or a reach-in, preserving both the loop's accept/reject/escalate contract and the arc's black-box boundary.

## Verification-Depth Ladder

A reusable rung taxonomy, broader than `iterate`'s per-loop `review_proof` marker (which only distinguishes confirmed / n-a / deferred / skipped for one loop).
The ladder is the arc-level shared vocabulary; the per-loop `review_proof` column remains the per-round audit field inside the loop, and the two compose rather than overlap.

| Rung | Meaning | Typical evidence |
|---|---|---|
| `compile` | It builds / type-checks / lints clean | build or `tsc`/lint exit 0 |
| `unit` | Unit tests pass | test-runner summary |
| `integration` | Components work together against real dependencies | integration-suite output |
| `smoke` | The actual artifact starts and does its basic job | "the container starts and serves"; a CLI produces expected output |
| `live` | Validated against live / production-shaped state | real request/response, real data, cited artifact |

Each rung SUBSUMES the ones above it: a `live` requirement implies `compile`..`smoke` all pass.

The overseer selects the required rung per proposal and generates the `--verification-floor` sentence it passes into that proposal's `iterate` composition, including at least one failure-picture as `iterate` requires.
Rung selection for an existing (chain) proposal, in precedence order:

1. the proposal's `required_rung` frontmatter field, if present;
2. else read the proposal's own `## Verification Methodology` section and derive the floor from it, exactly as `iterate` already does when no `--verification-floor` is passed;
3. else fall back to `iterate`'s existing floor rule: `AskUserQuestion` for a floor, or under AFK write a placeholder floor and tag the affected rows, per `iterate`'s documented AFK fallback.

For `full <topic>`, where proposals are freshly authored rather than read, the overseer sets a default rung (`smoke` unless the topic implies otherwise) at authoring time, before the precedence chain applies to any later re-run.

## Cross-Target Degradation

Consistent with how [`orchestration-discipline.md`](./orchestration-discipline.md) handles it: rule CONTENT here (schema, ladder, heuristics) delivers to OpenCode cleanly via `/cdocs:init` globbing, with no runtime dependency.
Only the RUNTIME mechanics degrade where a target lacks Claude-Code-only primitives:

- Where `fork` / `SendMessage` are absent, interleaved durable specialists degrade to fresh sessions restarted from the arc-state file plus each proposal's devlog handoff, the same fallback Pillar 1b / Pillar 3 name.
  Practically, absent these primitives the arc runs SEQUENTIAL only (no interleaving), since one session cannot hold multiple warm specialists.
- Where `/compact` is absent, the proposal-boundary checkpoint degrades to "start a fresh session from the arc-state file and the last handoff," Pillar 2's stated fallback.
- The arc-state file and the claim registry are plain files and are the durable substrate that makes every one of these fallbacks faithful; they carry no Claude-Code dependency.
</content>
