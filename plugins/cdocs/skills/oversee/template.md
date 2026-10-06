# Oversee Skill: Arc-State Template

Write the arc file to `.claude/oversee/<arc-id>.json` on Turn 0 and rewrite it at each proposal start, end, and escalation.
Add whatever fields a cold resume needs (scope, gates, notes).

```jsonc
{
  "arc_id": "2026-09-03-oversee-cdocs-hooks",
  "afk": false,
  "position": 0,
  "proposals": [
    {
      "path": "cdocs/proposals/2026-08-10-a.md",
      "status": "implementation_ready",
      "arc_state": "pending",
      "devlog": null,
      "footprint": ["plugins/cdocs/**"],
      "verification_floor": "the artifact starts and does its job; failure: it exits non-zero"
    }
  ]
}
```

- `status` mirrors the proposal's frontmatter at the last write; `arc_state` is `pending | in_progress | blocked | done`.
- `position` indexes the current proposal.

## Arc Devlog

Keep a normal cdocs devlog beside the JSON for the arc narrative and links to each proposal's top-level devlog, with a Completed / Decisions Made / Open Todos handoff at each proposal boundary.
Each proposal's loop tables and Workstream Devlogs index live in its top-level, not here.
