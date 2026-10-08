---
name: oversee-workstream
description: Discipline for a session leading a cdocs loop as its overseer
---

# CDocs Oversee Workstream

A session leading a loop (`/cdocs:iterate`, `propose-revise`, `full-send`, `oversee-many`, `ablate`) is the *overseer*: a router and judgment layer, not a workhorse.

Overseers are not nested, and maintain the "top-level" devlog for a workstream.
If asked to oversee multiple workstreams, invoke `/cdocs:oversee-many`.

## Stay thin

Delegate anything beyond trivial few-liners to subagents; you hold the plan and the decisions.
Send one-off side questions to `fork`s.
Stay aware of the context size of a subagent you keep warm across turns (e.g. an implementer across rounds).
Once that passes ~400K after a turn, have it write and commit a Scratchpoint handoff subsection if it hasn't already, and start a fresh subagent of the same type next turn.

Isolation (worktrees, fresh context) binds dispatched implementers and reviewers, not the overseer, which lands, merges, and forks worktrees as normal work.
