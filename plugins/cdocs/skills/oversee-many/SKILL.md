---
name: oversee-many
description: Drive an ARC of proposals through their full lifecycle as the arc overseer, composing /cdocs:full-send, /cdocs:iterate, and /cdocs:propose-revise per proposal, with a durable resumable arc-state file and AFK autonomous continuation
argument-hint: "chain [p1, p2, ...] | full <topic> | resume [arc-id] [--afk] [-m | --model \"<model_description>\"] [-f | --first-round [\"<model_description>\"]]"
---

# CDocs Oversee Many

`/cdocs:oversee-many` is the arc layer above `/cdocs:full-send`: it takes several proposals through their full lifecycle by running an existing loop skill per proposal.
Loops should be run concurrently when practical unless otherwise specified (see Concurrency).

The arc overseer runs in *overseer mode*.
Before dispatching, invoke `/cdocs:oversee-workstream` with the Skill tool (skip if its text is already in context).

> NOTE: `/cdocs:oversee-many` is TOP-LEVEL ONLY. It needs the human for hard gates and escalations, whom only the top-level session reaches, so a dispatched `/cdocs:oversee-many` declines or runs advisory only, and says so.

## Invocation

```
/cdocs:oversee-many chain [p1, p2, ...]   # run an explicit list of proposals
/cdocs:oversee-many full <topic>          # scope a proposal set for a topic, then chain it
/cdocs:oversee-many resume [arc-id]       # resume an interrupted arc from its arc file
```

- `chain`: a list of proposal paths, ordered where one depends on another, each routed per its readiness when it starts (see Composition).
- `full <topic>`: dispatch `/cdocs:propose` to scope the arc's proposal set, then treat the result as a `chain`.
- `resume`: see Resume.
- `--afk`: the user is away. Soft gates ("continue to the next proposal?", "which of two acceptable defaults?") take the logged default and proceed; hard gates still stop. Record it as `afk` in the arc file so a resumed arc knows.
- `-m | --model` and `-f | --first-round`: passed unchanged to each composed loop.

Mint `arc_id` as `YYYY-MM-DD` plus a dash-cased slug of the topic (or of the first proposal's basename), state it in the Turn-0 brief, and reuse it on resume.

## Composition

Decide per proposal when it starts, since an earlier proposal may change a later one's readiness.
The arc overseer runs each composed loop as itself, so it is the only overseer in the arc and owns each proposal's top-level devlog.

| Per-proposal condition | Composition |
|---|---|
| `implementation_ready` | `/cdocs:iterate pN` |
| RFP stub or unauthored | `/cdocs:full-send pN` |
| `full <topic>` | scope first (`/cdocs:propose`), then treat the result as a `chain` |

## Composition contract

Down: the proposal path, a `--verification-floor` drawn from the proposal's own Verification Methodology (for a freshly authored `full` proposal, default to "the artifact starts and does its job"), model flags unchanged, and under AFK a brief line saying to run to accept-or-escalate without pausing.
Up: the proposal's frontmatter status, its top-level devlog's Scratchpoint, and the arc file; never the loop's raw turns.

## Arc state

Keep `.claude/oversee/<arc-id>.json` current at each proposal start, end, and escalation (shape in [`./template.md`](./template.md)): per proposal its path, frontmatter status, arc_state (pending / in_progress / blocked / done), devlog (the proposal's top-level devlog), footprint globs, and verification floor; plus `position` and `afk`.
Add whatever fields a cold resume needs (scope, gates, notes).
Keep an arc devlog beside it for the arc narrative and links to each proposal's top-level devlog, with a handoff at each proposal boundary, while loop tables stay in the top-levels.

## Concurrency

Proposals with disjoint footprints run in parallel under this one overseer (implementations in separate worktrees); overlapping or unpredictable footprints, and a proposal that depends on another's outcome, run in order.
Before starting a proposal, read the sibling arc files under `.claude/oversee/` for in-progress footprints that overlap it.

## Hard gates

These stop the arc even under `--afk`: a `reject` verdict, an unresolvable footprint conflict, and (for `full`) choosing the proposal set.
At a hard gate, mark the proposal `blocked`, record the escalation in the arc file, and surface it to the user.

## Resume

Trust disk over memory: each proposal's frontmatter status, its top-level devlog's Scratchpoint (and handoff, if present), and the arc file.
Accepted but marked in_progress: mark done and advance. Ambiguous: re-run the loop (iterate re-reviews done work cheaply). Never re-run a done proposal.
With no arc-id, resume the single non-terminal arc file, or ask (under AFK, take the most recently written one and log the choice).

The arc ends when every proposal is done, a hard gate stops it, or the user interrupts.
