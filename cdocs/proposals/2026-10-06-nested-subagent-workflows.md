---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T17:35:00-07:00
task_list: cdocs/nested-subagent-workflows
type: proposal
state: live
status: review_ready
tags: [orchestration_discipline, architecture, claude_skills]
---

# Nested Subagent Workflows

> BLUF(opus-5-5/cdocs/nested-subagent-workflows): Claude Code subagents can dispatch subagents, three layers below the human session by default ([docs](https://code.claude.com/docs/en/sub-agents#let-subagents-spawn-their-own-subagents)); this was verified empirically here.
> This proposal deletes the `## Investigation Requested` handback and every "subagents cannot dispatch" workaround, and adds one short `Nesting` section to `orchestration-discipline.md` covering when to nest and what stays top-level.
> The one structural change: `/cdocs:oversee` runs each proposal's loop as a dispatched sub-overseer.

## Summary

Three things change:

| Change | Where | Words (estimate) |
|---|---|---|
| Delete dispatch suppression and the `## Investigation Requested` schema; dispatched agents dispatch their own helpers | `implement`, `propose`, `iterate`, `triage`, `ablate` skills; `implementer`, `reviewer`, `proposer` agents | about -250 (355 removed, ~100 of shorter replacement) |
| One `## Nesting` section stating when to nest, when not to, and what stays top-level | `rules/orchestration-discipline.md` | about +170 |
| `/oversee` dispatches each proposal's loop to a sub-overseer instead of running it as itself | `oversee` skill; overseer role lines in `iterate` and `propose-revise` | about +70 |

The size change is close to neutral, not a large cut.
The gain is that one rule section replaces seven scattered prohibitions.
The Test Plan's `wc -w` check holds the implementer to a net reduction.

Nothing is added to hooks, the OpenCode build, the devlog model, or the leaf agents (`judge`, `bash-runner`, `nit-fix`, `triage`), which stay leaves because their explicit `tools:` lists omit `Agent`.

> NOTE(opus-5-5/cdocs/nested-subagent-workflows): Two adjacent problems surfaced while researching this proposal and are out of scope.
> First, the OpenCode build maps `tools: "*"` to `read/edit/write/bash: false`: in `scripts/build-opencode.ts` `mapTools`, `*` falls through to the unknown-tool branch, so the generated OC `implementer`, `reviewer`, and `proposer` have every mapped tool disabled.
> Second, `ablate`'s deferred live run is blocked by its graphify container, not by nesting.
> Each warrants its own fix or `/cdocs:rfp`.

## Objective

Make cdocs workflows use nested dispatch where it saves context or wall time, and remove the machinery built around its absence, without adding new formalisms.

## Background

### Capability findings

Version is Claude Code 2.1.292.
"Empirical" means it was observed in this authoring session, which is itself a dispatched `cdocs:proposer` (layer 1) running probe subagents, plus one headless `claude -p` run in a scratch directory.

| Finding | Source | How established |
|---|---|---|
| Subagents can dispatch subagents, up to three layers below the main conversation by default; `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` sets the limit (`1` disables). | [docs](https://code.claude.com/docs/en/sub-agents#let-subagents-spawn-their-own-subagents); [CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md) 2.1.219: "Subagents can now spawn nested subagents up to depth 3 by default (was 1)" | Empirical: layer 1 (this agent) and layer 2 dispatched; the layer-3 probe had no `Agent` tool. |
| At the limit, `Agent` is withheld, so the agent does the work itself and returns one summary. Forks count toward the cap (2.1.187), and a fork at the limit keeps `Agent`, but the call errors. | docs; CHANGELOG 2.1.187 | Empirical (withholding at layer 3). |
| An explicit `tools:` list without `Agent` cannot nest. `Agent(type, ...)` allowlists are ignored in subagent definitions (main-thread `--agent` only). | [docs](https://code.claude.com/docs/en/sub-agents#restrict-which-subagents-can-be-spawned) | Empirical: a dispatched `cdocs:nit-fix` (`tools: Read, Glob, Grep, Edit`) had no `Agent`. `tools: "*"` agents (`cdocs:proposer`) do. |
| Dispatch from a subagent is asynchronous: the call returns an agent id, and a task notification carries the result plus `<usage><subagent_tokens>`. The notification "fires each time this agent stops with no live background children of its own". | Notification text, observed verbatim | Empirical. |
| In interactive sessions, a subagent waits for its background children before finishing. In headless mode (`claude -p`) and the Agent SDK it does not wait, and a late grandchild reports to the main conversation instead. | [docs](https://code.claude.com/docs/en/sub-agents#let-subagents-spawn-their-own-subagents) | Interactive: empirical. Headless: partly empirical (see the NOTE below). |
| `SendMessage` works from a subagent. It resumes a finished child (with the result reported back to that subagent), and it delivers a message to a running child at its next tool round, which makes it usable for mid-flight steering. Children are addressed by agent id: an Agent-call `description` is not a routable name. | [docs](https://code.claude.com/docs/en/sub-agents#resume-subagents) | Empirical: resumed a finished `nit-fix`; steered a running probe; a send by description failed. |
| `fork` works from a subagent. | docs | Empirical. |
| `AskUserQuestion` is absent from subagents at every layer. | [#34592](https://github.com/anthropics/claude-code/issues/34592) | Empirical: absent at layers 1-3. |
| `PreToolUse` hooks fire for nested agents, and `agent_type` is set to the nested agent's own type. | Hook payload | Empirical: a layer-2 `cdocs:nit-fix` was blocked by `validate-cdocs-edit-path.sh`. |
| OpenCode: `permission.task` globs control which subagents an agent may invoke. Whether OC *subagents* get the `task` tool, and any OC depth limit, are not documented. | [OC agents docs](https://opencode.ai/docs/agents/) | Docs only, and those claims are unverified. |

> NOTE(opus-5-5/cdocs/nested-subagent-workflows): Headless was checked with one scratch `claude -p --model haiku` run (main, then child, then grandchild).
> Nesting worked.
> The child's `Agent` call offered `run_in_background: false`, and the child used it, blocking until the grandchild returned.
> The interactive `Agent` tool in this session has no such parameter: every dispatch was background, and the parent waited.
> The grandchild ended while its own background Bash task was still running, and that task was reported `stopped`.
> So in headless runs, work a lead leaves in the background does not outlive it.

`chat-record` is unaffected: it already says never to run it "if the `Agent` tool dispatched you", which holds at any depth.

### What cdocs assumes today

Every dispatched role is written as a leaf.
`/cdocs:implement --dispatched` "self-investigates inline and surfaces investigation requests to its caller" via a fenced `## Investigation Requested` block, and `iterate` restates this rule.
The `implementer`, `reviewer`, and `proposer` agents each repeat "the platform forbids subagent-from-subagent dispatch".
The `propose` checklist routes its sanity review through the same block.
`triage` explains a dispatch with "since agents cannot spawn subagents".
`ablate` defers its live run because "the full three-subagent dispatch cannot run from inside a subagent".
`/oversee` is marked "TOP-LEVEL ONLY", and the arc overseer "runs each composed loop as itself, so it is the only overseer in the arc".
That last line is the costly one: every implementer, reviewer, and judge return across every proposal in an arc lands in one context.

## Proposed Solution

### 1. One `Nesting` section in `orchestration-discipline.md`

This text replaces every per-file workaround.
The draft below is final in substance, and the implementer may tighten it:

```markdown
## Nesting

Any agent with the `Agent` tool leads its own children, and this file applies to it as it does to a top-level overseer.
Dispatch from where the need arises: an implementer sends a test run to `bash-runner` and a side question to a `fork`; a reviewer sends a verification run to `bash-runner`.
Don't nest work of a few lines, output you need verbatim anyway, or a task whose child would re-read most of what you hold: each layer costs a fresh context and hides its work from everyone above it.
Nesting stops three layers below the human session by default; an agent without `Agent` does the work itself and names in its return anything that deserves a fresh look.
Only the top level reaches the human: a nested lead escalates by returning, and forwards steering to a live child with `SendMessage` (by agent id).
```

"Resume from disk" gets one qualifier: log a child's dispatch and return when a resume would need it, meaning writers and long runners, not one-shot read-only helpers.
Everything else in the rule file already reads correctly for a nested lead.
That includes "Stay thin", the ~400K warm-child handoff (`subagent_tokens` reaches subagent parents too), one writer per file, committing by explicit path, and the chat record.

### 2. Delete the leaf-role workarounds

| File | Edit |
|---|---|
| `skills/implement/SKILL.md` | In Invocation Modes, the Dispatched bullet keeps its signal (flag or parent prompt), the named sub-devlog, and isolation. It drops the "platform forbids" clause, the fenced schema, and the "caller decides" paragraph. Behavior step 5's dispatched line becomes "the loop's reviewer reviews; dispatch research and verification helpers as needed". Delete the Dispatched line under "Use cdocs skills". |
| `agents/implementer.md` | Delete the `--dispatched` constraint sentence; the intro line already names the mode. |
| `agents/proposer.md` | Delete the "cannot dispatch subagents via `Task`" sentence. |
| `agents/reviewer.md` | Replace the "cannot dispatch" bullet with: dispatch read-only helpers (`cdocs:bash-runner`, `Explore`) for verification runs and wide searches, and never delegate a write. |
| `skills/propose/SKILL.md` | The checklist's dispatched-mode line becomes: dispatched by a `/cdocs:propose-revise` loop, skip this item, since the loop's reviewer is that review. |
| `skills/iterate/SKILL.md` | Delete the "`--dispatched` mode suppresses subagent dispatch" paragraph. |
| `skills/triage/SKILL.md` | Delete "(the main agent dispatches this since agents cannot spawn subagents)". |
| `skills/ablate/SKILL.md` | The WARN and "Deferred to the top-level e2e test" give "not yet run live (needs a graphify container)" as the reason, not "out of reach from inside a subagent". The deferred items themselves stay. |

`--dispatched` stays because it still means something: write the named sub-devlog, work isolated, and leave the final review to the loop.
What goes is everything it suppressed.

### 3. `/oversee` runs each loop as a sub-overseer

The arc overseer dispatches one sub-overseer per proposal.
A sub-overseer is a fresh `general-purpose` agent at the lead tier, told to run `/cdocs:full-send` or `/cdocs:iterate` on that proposal under the existing Composition contract.
The contract is already written as a dispatch boundary: Down carries the path, verification floor, model flags, and AFK line; Up carries frontmatter status, the loop's final handoff, and the arc file, "never the loop's raw turns".
The sub-overseer owns the proposal's top-level devlog and its tables.
The arc overseer owns the arc file and arc devlog.
Disjoint proposals run as parallel sub-overseers.

The depth budget fits exactly: arc overseer (top level), sub-overseer (layer 1), implementer, reviewer, or judge (layer 2), then `bash-runner`, `Explore`, or `fork` (layer 3, a leaf by the limit).

Human contact stays at the top.
A sub-overseer cannot `AskUserQuestion`, so a gate it cannot default (a hard gate, or a soft gate outside AFK) ends its turn with the question as its return.
The arc overseer asks the user, or applies the AFK default, then resumes the sub-overseer with `SendMessage`.
If the sub-overseer's last `subagent_tokens` is past ~400K, the arc overseer instead dispatches a fresh one that resumes from the proposal's devlog.
The arc overseer forwards human steering to a running sub-overseer with `SendMessage`.

Edits to `skills/oversee/SKILL.md`:
- Replace the TOP-LEVEL ONLY note with one line: run `/oversee` from the top-level session, because nested deeper its implementers lose their dispatch layer.
- Replace "runs each composed loop as itself..." with the sub-overseer sentence.
- Add the escalation and steering sentences above to Hard gates.

In `iterate` and `propose-revise`, the Overseer role line drops "top-level agent" ("the agent running the loop"), because that agent may now be a sub-overseer.
`full-send` is unchanged: its two loops are sequential on one proposal and share one devlog, so splitting them would buy nothing.

### 4. OpenCode

Section 1's wording is conditional on having a dispatch tool ("an agent without `Agent` does the work itself"), so OpenCode needs no separate path or build change.
Where an OC subagent lacks `task`, it degrades to inline work.
That is the same behavior as the CC depth limit, and the same behavior the deleted text demanded.

## Important Design Decisions

- **One rule section, not per-role mode text.** Nesting is a property of the runtime, not of a role, so it is stated once where every lead already looks. The deleted per-agent sentences existed only to repeat a prohibition.
- **No replacement schema for `## Investigation Requested`.** An agent that can dispatch investigates itself. An agent that cannot (layer 3, OpenCode) names the open question in plain text in its return. A fenced schema for that case would preserve machinery for the rarest path.
- **Sub-overseers under `/oversee` only.** Its contract already crosses a context boundary, and it is the one place where one context accumulates several loops. `full-send` and the loop skills stay as they are: their overseers are already thin, and adding a layer would spend depth the implementer needs.
- **Agent depth is not devlog depth.** Devlogs stay one level deep (`part_of` the top-level). An implementer that dispatches a writer names its sub-devlog and reports it upward, like any successor. The top-level's Workstream Devlogs index stays with whoever owns the top-level, which under `/oversee` is the sub-overseer.
- **Leaves stay leaves by `tools:`, not by prose.** `judge`, `bash-runner`, `nit-fix`, and `triage` omit `Agent`, which the docs name as the per-agent switch. That keeps the judge fresh and cheap and keeps mechanical agents mechanical.
- **Reviewers delegate reads, never writes.** The edit-path hook binds the reviewer's own `agent_type`. A `general-purpose` child would not inherit it, so the reviewer's write boundary would leak through delegation.
- **Keep `--dispatched`.** It still selects the sub-devlog, isolation, and loop-owned review. Removing the flag in favor of "detect a parent prompt" would trade an explicit signal for inference.

## Stories

- **Implementer under `/cdocs:iterate`.** It needs a full test suite run and to know which callers use a function it changed. It dispatches `bash-runner` for the suite and `Explore` for the callers, then continues with both reports in hand. No round trip through the overseer and no lost iteration.
- **Reviewer verifying a floor.** It dispatches `bash-runner` to start the dev server and curl three endpoints. It cites the scratch file path in the review, keeping a ~2,000-line server log out of its own context.
- **Four-proposal arc.** The arc overseer's context holds four dispatches, four Up summaries, and the arc file, instead of every round of four loops. Two proposals with disjoint footprints run concurrently as two sub-overseers.
- **Sub-overseer escalation.** A reviewer returns `reject` on proposal 2. The sub-overseer marks the escalation in the proposal devlog and returns it. The arc overseer marks the proposal `blocked` in the arc file and asks the user.

## Edge Cases / Challenging Scenarios

- **Headless and SDK runs.** There, a lead does not wait for its background children, and a late grandchild reports to the main conversation, which breaks "if control has returned, it has ended". cdocs loops run interactively, so this affects headless smoke tests and any future CI driver. There, leads dispatch in the foreground (`run_in_background: false`, which headless `Agent` offers) or stay one lead deep. See the Background NOTE for the observed behavior.
- **Depth exhaustion.** `/oversee` dispatched by another agent pushes implementers to layer 3, which has no `Agent`. Behavior degrades to inline work rather than failing, and the one-line oversee note says why to avoid it. A user-lowered `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` degrades the same way. An off-by-one in that variable is reported in [#84974](https://github.com/anthropics/claude-code/issues/84974) (unverified here).
- **Concurrent writers across subtrees.** Two sub-overseers' implementers could touch one file. Arc footprints already serialize overlapping proposals. Within a subtree, a lead only dispatches writers inside its own claim.
- **Lost visibility.** The human sees only top-level traffic, and the arc overseer sees only Up summaries. Durable state (sub-devlogs, Scratchpoints, handoffs, loop tables) is what keeps nested work inspectable. That state is unchanged and is now what makes nesting safe.
- **Cost.** Each child re-reads its own context. The Nesting section's "don't nest" clause is the guard. The verification below checks that agents use it rather than reflexively fanning out.
- **Permission prompts in nested agents.** [#83421](https://github.com/anthropics/claude-code/issues/83421) reports `bypassPermissions` not reaching Agent-tool children (unverified here: probes ran without prompts in a bypass session). An AFK arc that hits a prompt at layer 2 stalls like any other prompt. No cdocs change is needed, but the smoke would surface it.

## Test Plan

Static (Phase 1 and 2):
- `grep -rnE "Investigation Requested|subagent-from-subagent|cannot dispatch|cannot spawn|TOP-LEVEL ONLY|no \`Task\`" plugins/cdocs` returns nothing.
- `wc -w` over the touched files is lower after the change than before.
- `npm run build:cdocs` succeeds, and the generated OC agents differ from the previous build only in body prose.
- Every `## Investigation Requested` reference left in `cdocs/` is in a historical devlog, review, or accepted proposal. These are not edited.

Live (Phase 3) runs in a fresh session that loads the edited plugin (after landing, or via `--plugin-dir`), against a trivial fixture proposal in a scratch worktree:
1. Dispatch `cdocs:implementer` with `--dispatched` on a fixture whose phase requires running a test command. It dispatches `cdocs:bash-runner` and returns without an `## Investigation Requested` block.
2. Dispatch `cdocs:reviewer` on the result with a floor requiring a command run. It dispatches a read-only helper and cites the artifact path.
3. `/cdocs:oversee chain [fixture]` under `--afk`. The arc overseer's own transcript shows one sub-overseer dispatch and no implementer, reviewer, or judge dispatches. The fixture's top-level devlog has dispatch and return rows written by the sub-overseer, and the arc file ends `done`.

## Verification Methodology

The floor: an implementer dispatched by `/cdocs:iterate` dispatches its own helper, and `/oversee` completes a one-proposal arc through a sub-overseer whose children reach layer 3.

Failure looks like any of these:
- The implementer returns an `## Investigation Requested` block or says it cannot dispatch, meaning stale text survived somewhere it reads.
- The arc overseer's transcript contains implementer or reviewer dispatches, meaning it ran the loop itself.
- A sub-overseer stalls looking for `AskUserQuestion` instead of returning its question.
- The arc file shows `done` while the proposal devlog has a dispatch row with no return.

This change is self-referential: the plugin under edit is the one the iterate loop runs on.
Record Phase 3 as `deferred-to-followup` in the loop's Iteration Log if its smoke cannot load the edited plugin in-session.

## Implementation Phases

### Phase 1: Rule section and leaf workaround deletion

- Add `## Nesting` to `rules/orchestration-discipline.md`, and add the qualifier to "Resume from disk" (Proposed Solution 1).
- Apply the edit table in Proposed Solution 2.
- Re-run `/cdocs:init` materialization in this repo only if its marker check requires it. The SessionStart hook is silent in the source repo.
- Verify: the static Test Plan items. Commit each file group separately (rule, implement/implementer, reviewer, propose/proposer, iterate, triage, ablate).

### Phase 2: `/oversee` sub-overseers

- Apply the `oversee` edits and the `iterate`/`propose-revise` role-line edits (Proposed Solution 3).
- Optionally add a NOTE in `cdocs/proposals/2026-09-03-overseer-arc.md` pointing here for the sub-overseer change; do not rewrite that proposal.
- Verify: re-run the static grep and `wc -w`. Read `oversee/SKILL.md` cold and check that Composition, Composition contract, Hard gates, and Resume say who owns which devlog and how a question reaches the user.

### Phase 3: Live smoke

- Run the three live checks in the Test Plan against a scratch-worktree fixture.
- Check that the OC build still succeeds and that the OC agents carry the edited prose.
- File a `/cdocs:rfp` for the OC `tools: "*"` mapping (Summary NOTE) if no fix has landed.
- Verify: the floor above, with each failure picture checked explicitly in the devlog.

Constraints:
- Do not change hooks, `scripts/build-opencode.ts`, the devlog skill, or any leaf agent's `tools:` list.
- Do not edit historical devlogs, reviews, or accepted proposals beyond the optional NOTE.
- Do not add a schema, table, or state field to replace `## Investigation Requested`.
