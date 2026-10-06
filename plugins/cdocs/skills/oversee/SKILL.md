---
name: oversee
description: Drive an ARC of proposals through their full lifecycle as the arc overseer, composing /cdocs:full-send, /cdocs:iterate, and /cdocs:propose-revise per proposal, with a durable resumable arc-state file and AFK autonomous continuation
argument-hint: "chain [p1, p2, ...] | full <topic> | resume [arc-id] [--afk] [-m | --model \"<model_description>\"] [-f | --first-round [\"<model_description>\"]]"
---

# CDocs Oversee

`/oversee` is the arc layer above `/cdocs:full-send`: it takes several proposals through their full lifecycle by composing the existing loop skills per proposal, never reimplementing a loop.
Its unit of work is a proposal: it advances to the next one only when the current one reaches a terminal accepted state.

The arc overseer runs in *overseer mode* per [`orchestration-discipline.md`](../../rules/orchestration-discipline.md).
Inline floor: dispatch by default (each composed loop keeps its own carve-out); write the arc file and an arc devlog handoff at each proposal boundary; read each loop's durable results, never its raw turns.
The human user is the supervisor: they invoke the skill and receive escalations.

> NOTE: `/oversee` is TOP-LEVEL ONLY. Subagents cannot dispatch, so a dispatched `/oversee` declines or runs advisory only, and says so.

## Invocation

```
/oversee chain [p1, p2, ...]        # sequence an explicit list of proposals
/oversee full <topic>               # scope a proposal set for a topic, then chain it
/oversee resume [arc-id]            # resume an interrupted arc from its arc file
```

- `chain`: an ordered list of proposal paths, each routed per its readiness at its turn (see Composition).
- `full <topic>`: dispatch `/cdocs:propose` to scope the arc's proposal set, then treat the result as a `chain`.
- `resume`: see Resume.
- `--afk`: the user is away. Soft gates ("continue to the next proposal?", "which of two acceptable defaults?") take the logged default and proceed; hard gates still stop. Record it as `afk` in the arc file so a resumed arc knows.
- `-m | --model` and `-f | --first-round`: passed unchanged to each composed loop, per [`model-tiering.md`](../../rules/model-tiering.md).

Mint `arc_id` as `YYYY-MM-DD` plus a dash-cased slug of the topic (or of the first proposal's basename), state it in the Turn-0 brief, and reuse it on resume.

## Composition

Decide per proposal at its turn, since an earlier proposal may change a later one's readiness.
The arc overseer runs each composed loop as itself, so it is the only overseer in the arc and owns each proposal's top-level devlog.

| Per-proposal condition | Composition |
|---|---|
| `implementation_ready` | `/cdocs:iterate pN` |
| RFP stub or unauthored | `/cdocs:full-send pN` |
| `full <topic>` | scope first (`/cdocs:propose`), then treat the result as a `chain` |

## Composition contract

Down: the proposal path, a `--verification-floor` drawn from the proposal's own Verification Methodology (for a freshly authored `full` proposal, default to "the artifact starts and does its job"), model flags unchanged, and under AFK a brief line saying to run to accept-or-escalate without pausing.
Up: the proposal's frontmatter status, its loop's final handoff, and the arc file; never the loop's raw turns.

## Arc state

Keep `.claude/oversee/<arc-id>.json` current at each proposal start, end, and escalation (shape in [`./template.md`](./template.md)): per proposal its path, frontmatter status, arc_state (pending / in_progress / blocked / done), devlog (the proposal's top-level devlog), footprint globs, and verification floor; plus `position` and `afk`.
Add whatever fields a cold resume needs (scope, gates, notes).
Keep an arc devlog beside it for the arc narrative and links to each proposal's top-level devlog, with a handoff at each proposal boundary, while loop tables stay in the top-levels.

## Concurrency

Proposals with overlapping or unpredictable footprints run in order; disjoint ones may run in parallel under this one overseer.
Before starting a proposal, read the sibling arc files under `.claude/oversee/` for in-progress footprints that overlap it.

## Hard gates

These stop the arc even under `--afk`: a `reject` verdict, an unresolvable footprint conflict, and (for `full`) choosing the proposal set.
At a hard gate, mark the proposal `blocked`, record the escalation in the arc file, and surface it to the user.

## Resume

Trust disk over memory: each proposal's frontmatter status, its loop's last handoff, and the arc file.
Accepted but marked in_progress: mark done and advance. Ambiguous: re-run the loop (iterate re-reviews done work cheaply). Never re-run a done proposal.
With no arc-id, resume the single non-terminal arc file, or ask (under AFK, take the most recently written one and log the choice).

The arc ends when every proposal is done, a hard gate stops it, or the user interrupts.
