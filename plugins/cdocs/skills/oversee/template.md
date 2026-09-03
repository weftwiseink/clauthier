# Oversee Skill: Arc-State and Claim Templates

The `/oversee` skill owns three durable artifacts per arc: the arc-state JSON file, one claim file per acquired footprint, and a normal arc devlog for the human narrative.
This file is the source for those skeletons.
The normative field semantics live in [`../../rules/oversee-arc.md`](../../rules/oversee-arc.md); copy the shapes below and fill them in.

## Arc-State File

Write to `.claude/oversee/<arc-id>.json` on Turn 0, and rewrite at every arc-level transition BEFORE compacting.

```jsonc
{
  "arc_id": "2026-09-03-oversee-cdocs-hooks",
  "mode": "chain",
  "afk": false,
  "afk_policy": "hold",
  "created_at": "2026-09-03T11:30:00-08:00",
  "proposals": [
    {
      "path": "cdocs/proposals/2026-08-10-a.md",
      "status": "implementation_ready",
      "arc_state": "pending",
      "specialist": null,
      "devlog": null,
      "worktree": null,
      "required_rung": "smoke",
      "footprint": ["plugins/cdocs/**"],
      "full_cycle_retries": 0
    }
  ],
  "position": 0,
  "claims": [],
  "budget": { "full_cycle_retries_max": 2 }
}
```

- `arc_state`: `pending | in_progress | blocked | done`.
- `status`: mirrors the proposal's frontmatter at the last transition.
- `position`: index into `proposals` of the current proposal.
- `afk` / `afk_policy`: see the skill's AFK section; `afk_policy` is `hold | skip-blocked`.
- `full_cycle_retries` vs `budget.full_cycle_retries_max`: the arc-altitude troubleshooting budget.

## Claim File

Write to `.claude/oversee/claims/<arc-id>--<dash-slug-of-globs>.json` when acquiring a footprint claim; delete or mark `stale` on release.

```jsonc
{
  "arc_id": "2026-09-03-oversee-cdocs-hooks",
  "owner": "arc-impl-a",
  "globs": ["plugins/cdocs/rules/**"],
  "acquired_at": "2026-09-03T11:40:00-08:00",
  "liveness": "live"
}
```

- `owner`: the specialist / loop handle holding the claim.
- `liveness`: `live | stale`; reconciled to `stale` and released on resume when the owner is gone.

## Escalation Marker

Write to `.claude/oversee/escalations/<arc-id>--<proposal-slug>.json` at a hard gate (a `reject` verdict, an unresolvable footprint conflict) even under AFK.

```jsonc
{
  "arc_id": "2026-09-03-oversee-cdocs-hooks",
  "proposal": "cdocs/proposals/2026-08-10-b.md",
  "gate": "reject",                    // reject | footprint-conflict | scoping
  "raised_at": "2026-09-03T12:10:00-08:00",
  "detail": "reviewer returned reject on round 4; see cdocs/reviews/...-r4.md",
  "afk_policy_applied": "hold"         // hold | skip-blocked
}
```

## Pause Marker

An out-of-band STOP dropped by a user with no live session: an empty (or note-bearing) file at `.claude/oversee/pause`.
The overseer checks for it at each gate, escalates-and-holds at the next gate when present, and clears it on acknowledgement.

## Arc Devlog

Keep a normal cdocs devlog (`type: devlog`) beside the JSON for the human narrative.
It uses the same Completed / Decisions Made / Open Todos handoff sections as every overseer loop (see [`../../rules/orchestration-discipline.md`](../../rules/orchestration-discipline.md) Pillar 2); the JSON is the structured half of the same checkpoint, not a competing artifact.
