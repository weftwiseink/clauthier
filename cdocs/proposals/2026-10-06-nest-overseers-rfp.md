---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T18:40:00-07:00
task_list: cdocs/nest-overseers
type: proposal
state: deferred
status: request_for_proposal
tags: [orchestration_discipline, architecture, claude_skills, future_work]
---

# Nest Overseers: User-Invoked Sub-Overseer Dispatch

> BLUF(opus-5-5/cdocs/nest-overseers): A user-invoked `/nest-overseers` skill could run cdocs loops as dispatched sub-overseers under the top-level session, keeping the chat context to per-workstream summaries.
> Agents never decide on their own to nest an overseer.
> - **Motivated By:** [`2026-10-06-nested-subagent-workflows.md`](2026-10-06-nested-subagent-workflows.md) and its reviews ([r1](../reviews/2026-10-06-review-of-nested-subagent-workflows.md), [r2](../reviews/2026-10-06-review-of-nested-subagent-workflows-r2.md), [r3](../reviews/2026-10-06-review-of-nested-subagent-workflows-r3.md)), where this design was drafted and then scoped out.

> NOTE(opus-5-5/cdocs/nest-overseers): The maintainer has other ideas that may negate the need for this.
> This is a stub to keep the seed material, not a commitment to the design.

## Objective

Today every loop's rounds (`/cdocs:iterate`, `/cdocs:propose-revise`, `/cdocs:full-send`, `/cdocs:oversee`) land in the top-level context.
An arc run under `/oversee` accumulates every implementer, reviewer, and judge return in that one context.
Nested dispatch makes another shape possible: one dedicated overseer per workstream, which the user opts into explicitly.

## Scope

The full proposal should decide whether the seed design below earns a skill, and if it does, specify it.

Seed design, from rounds 1-3 of the motivating proposal:
- **Chat layer.** The top-level session owns human contact (`AskUserQuestion`, `chat-record`). A sub-overseer escalates by returning its question. Answers and steering reach it by `SendMessage`, and its resumes keep their spawn depth (CHANGELOG 2.1.187).
- **One sub-overseer per workstream.** It is a fresh `general-purpose` agent at the lead tier that runs the loop skill unchanged and owns the workstream's top-level devlog. Loop skills would need to be nest-safe: the "top-level agent" role lines and the `AskUserQuestion` sites in `iterate` and `propose-revise` would read "ask the user".
- **`/oversee` dispatching sub-overseers.** Its Composition contract becomes the dispatch prompt (Down: path, floor, model flags, AFK line) and the return (Up: status, final handoff, arc file). Disjoint proposals run as parallel sub-overseers, and `arc_state: in_progress` serves as the dispatch row.
- **`chat_record` pass-down.** The chat layer puts its `chat-record path` in the brief, and the devlog's owning overseer adds it to `chat_record`. That keeps one writer per file, and the post-compaction "read the devlogs that list it" step still finds every workstream.
- **Fail loudly.** A sub-overseer without `Agent` stops at once with an explicit error and does no work, because an overseer never plays its own implementer or reviewer. In `/oversee` that error is a hard gate: the proposal is marked `blocked`, never retried inline.
- **Depth budget.** At the default limit of three layers the budget fits exactly: chat layer, then sub-overseer (layer 1), then implementer, reviewer, or judge (layer 2), then a leaf helper (layer 3). With `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=2`, implementers become leaves. With `1`, the loop errors.
- **Candidate `/oversee` deletions** once sub-overseers run: the arc devlog duplicates the arc file's narrative and handoff role, and `position` can be derived from per-proposal `arc_state`.

Trade-offs, as drafted:
- Running a loop inline keeps every round visible to the human, and lets the chat layer connect it to other workstreams in the conversation.
- Dispatching gives each workstream a dedicated opus that can be queried by `SendMessage`, and a cleaner chat context.
- Dispatch costs a relay hop for escalations and steering, which also wait for the sub-overseer's live children.
- Round-level detail becomes visible only on disk.
- Dispatch spends the depth budget exactly.

Verification ideas:
- Use the `claude_run` setup from `hooks/tests/chat-record.test.sh`: a `git init` fixture outside any repo prepared by `init_rules`, a sandboxed `CLAUDE_CONFIG_DIR` with copied credentials, `env -i`, `--plugin-dir`, and `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` so every layer dispatches in the foreground.
- Run `/cdocs:oversee chain <fixture> --afk`.
- Read the layers from `subagents/*.meta.json` (`spawnDepth`, `agentType`, `parentAgentId`, `requestShape`). The depth-2 implementer and reviewer should share a depth-1 `general-purpose` parent, and no depth-1 loop role should appear.
- Re-run with `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1`. Expect the missing-`Agent` error, a `blocked` proposal, and no new commits.
- Escalation and steering need an interactive (tmux) run.

## Open Questions

- Do the maintainer's other ideas make this unnecessary?
- Which interface: a standalone `/nest-overseers` wrapping any loop skill, or a flag on the loop skills and `/oversee`?
- Should `/oversee` always dispatch sub-overseers once this exists, or only when invoked through the skill?
- How does the chat layer keep enough round-level visibility to steer: query by `SendMessage`, read devlogs, or nothing?
- Does the harness's foreground forcing distort what it measures, compared with interactive background dispatch?
