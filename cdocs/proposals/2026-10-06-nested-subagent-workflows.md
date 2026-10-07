---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T17:35:00-07:00
task_list: cdocs/nested-subagent-workflows
type: proposal
state: live
status: review_ready
last_reviewed:
  status: revision_requested
  by: "@claude-opus-5-5"
  at: 2026-10-06T17:46:39-07:00
  round: 2
tags: [orchestration_discipline, architecture, claude_skills]
---

# Nested Subagent Workflows

> BLUF(opus-5-5/cdocs/nested-subagent-workflows): Claude Code subagents can dispatch subagents, three layers below the human session by default ([docs](https://code.claude.com/docs/en/sub-agents#let-subagents-spawn-their-own-subagents)); this was verified empirically here.
> This proposal deletes the `## Investigation Requested` handback and every "subagents cannot dispatch" workaround, and adds one short `Nesting` section to `orchestration-discipline.md` covering when to nest and what stays top-level.
> The one structural change: `/cdocs:oversee` runs each proposal's loop as a dispatched sub-overseer, and runs it itself when the sub-overseer cannot dispatch.

## Summary

Three things change:

| Change | Where | Words (estimate) |
|---|---|---|
| Delete dispatch suppression and the `## Investigation Requested` schema; dispatched agents dispatch their own helpers | `implement`, `propose`, `iterate`, `triage`, `ablate` skills; `implementer`, `reviewer`, `proposer` agents | about -250 (355 removed, ~100 of shorter replacement) |
| One `## Nesting` section stating when to nest, when not to, and what stays top-level | `rules/orchestration-discipline.md` | about +170 |
| `/oversee` dispatches each proposal's loop to a sub-overseer instead of running it as itself | `oversee` skill; overseer role lines in `iterate` and `propose-revise` | about +100 |

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
| Subagents can dispatch subagents, up to three layers below the main conversation by default; `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` sets the limit (`1` disables). | [docs](https://code.claude.com/docs/en/sub-agents#let-subagents-spawn-their-own-subagents); [CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md) 2.1.219: "Subagents can now spawn nested subagents up to depth 3 by default (was 1)"; 2.1.217 had turned nesting off by default, so older installs may lack it | Empirical: layer 1 (this agent) and layer 2 dispatched; the layer-3 probe had no `Agent` tool. |
| At the limit, `Agent` is withheld, so the agent does the work itself and returns one summary. Forks count toward the cap, and resumed subagents "restore their original spawn depth" (2.1.187). A fork at the limit keeps `Agent`, but the call errors. | docs; CHANGELOG 2.1.187 | Empirical (withholding at layer 3). |
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

`chat-record` already says never to run it "if the `Agent` tool dispatched you", which holds at any depth.
Under `/oversee`, the arc devlog carries `chat_record`: every human prompt lands at the top, and proposal devlogs written by sub-overseers have none.

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

Any agent with the `Agent` tool may dispatch from where the need arises.
A loop lead (any overseer, nested or not) takes this whole file; any other agent that dispatches takes one writer per file, durable state for writers it starts, and the Bash section, and stays the workhorse for its own task.
Don't nest work of a few lines, output you need verbatim anyway, or a task whose child would re-read most of what you hold: each layer costs a fresh context and hides its work from everyone above it.
Nesting stops three layers below the human session by default.
Without `Agent`, a leaf does the work itself and names in its return anything that deserves a fresh look; a loop lead returns at once and says so, never playing its children's roles.
Only the top level reaches the human: a nested lead escalates by returning, and forwards steering to a live child with `SendMessage` (by agent id).
```

"Resume from disk" gets one qualifier: log a child's dispatch and return when a resume would need it, meaning writers and long runners, not one-shot read-only helpers.
Under `/oversee`, a proposal's `arc_state: in_progress` is the sub-overseer's dispatch row.
For a loop lead, the rest of the file already reads correctly, including the ~400K warm-child handoff (`subagent_tokens` reaches subagent parents too).

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
| `skills/ablate/SKILL.md` | Four sites. The "CANNOT run from inside a subagent" NOTE becomes "run it from a lead with two dispatch layers below it". The "as far as is possible from inside a subagent" line and the "PARTIALLY CONFIRMED from inside a subagent" WARN become "not yet confirmed live". The final WARN and "Deferred to the top-level e2e test" give "not yet run live (needs a graphify container)" as the reason. The deferred items themselves stay. |

`--dispatched` stays because it still means something: write the named sub-devlog, work isolated, and leave the final review to the loop.
What goes is everything it suppressed.

### 3. `/oversee` runs each loop as a sub-overseer

The arc overseer dispatches one sub-overseer per proposal.
A sub-overseer is a fresh `general-purpose` agent at the lead tier, told to run `/cdocs:full-send` or `/cdocs:iterate` on that proposal under the existing Composition contract.
The contract is already written as a dispatch boundary: Down carries the path, verification floor, model flags, and AFK line; Up carries frontmatter status, the loop's final handoff, and the arc file, "never the loop's raw turns".
The sub-overseer owns the proposal's top-level devlog and its tables.
The arc overseer owns the arc file and arc devlog.
Disjoint proposals run as parallel sub-overseers.

At the default limit the depth budget fits exactly: arc overseer (top level), sub-overseer (layer 1), implementer, reviewer, or judge (layer 2), then `bash-runner`, `Explore`, or `fork` (layer 3, a leaf by the limit).
With less depth, the Nesting fallback applies: a sub-overseer without `Agent` returns at once, and the arc overseer runs that loop itself.

Human contact stays at the top.
The Composition contract's Down line gains: "you cannot reach the user: return any question, and the arc overseer resumes you with the answer."
The question arrives only after the sub-overseer's live children return (an interactive subagent waits for them), so a quiet sub-overseer is not a hung one.
The arc overseer asks the user, or applies the AFK default, then resumes the sub-overseer with `SendMessage`.
If the sub-overseer's last `subagent_tokens` is past ~400K, the arc overseer instead dispatches a fresh one that resumes from the proposal's devlog.
The arc overseer forwards human steering to a running sub-overseer with `SendMessage`.

Edits to `skills/oversee/SKILL.md`:
- Replace the TOP-LEVEL ONLY note with: "Run `/oversee` from the top-level session. Without `Agent`, decline and say so."
- Replace "runs each composed loop as itself..." with the sub-overseer sentence and its fallback (run the loop itself when a sub-overseer returns that it cannot dispatch).
- Add the Down line above to the Composition contract, and add to the arc file text that the arc devlog carries `chat_record`.

In `iterate` and `propose-revise`, the Overseer role line drops "top-level agent" ("the agent running the loop"), because that agent may now be a sub-overseer.
`full-send` is unchanged: its two loops are sequential on one proposal and share one devlog, so splitting them would buy nothing.

### 4. OpenCode

Section 1's wording is conditional on having a dispatch tool, so OpenCode needs no separate path or build change.
Where an OC subagent lacks `task`, a leaf works inline (what the deleted text demanded) and a loop lead returns, so the top-level runs the loop.

## Important Design Decisions

- **One rule section, not per-role mode text.** Nesting is a property of the runtime, not of a role, so it is stated once where every lead already looks. The deleted per-agent sentences existed only to repeat a prohibition.
- **No replacement schema for `## Investigation Requested`.** An agent that can dispatch investigates itself. An agent that cannot (layer 3, OpenCode) names the open question in plain text in its return. A fenced schema for that case would preserve machinery for the rarest path.
- **Sub-overseers under `/oversee` only.** Its contract already crosses a context boundary, and it is the one place where one context accumulates several loops. `full-send` and the loop skills stay as they are: their overseers are already thin, and adding a layer would spend depth the implementer needs.
- **Agent depth is not devlog depth.** Devlogs stay one level deep (`part_of` the top-level). An implementer that dispatches a writer names its sub-devlog and reports it upward, like any successor. The top-level's Workstream Devlogs index stays with whoever owns the top-level, which under `/oversee` is the sub-overseer.
- **Leaves stay leaves by `tools:`, not by prose.** `judge`, `bash-runner`, `nit-fix`, and `triage` omit `Agent`, which the docs name as the per-agent switch. That keeps the judge fresh and cheap and keeps mechanical agents mechanical.
- **Reviewers delegate reads, never writes.** The reviewer's boundary is mostly prose (it already has `Bash`). The edit-path hook binds only its own `Edit`/`Write` (`agent_type` match), and a `general-purpose` child would not inherit that.
- **A loop lead without `Agent` returns; it never runs the loop alone.** Implementing and reviewing in one context would void the fresh-reviewer invariant while still recording a clean accept.
- **Keep `--dispatched`.** It still selects the sub-devlog, isolation, and loop-owned review. Removing the flag in favor of "detect a parent prompt" would trade an explicit signal for inference.

## Stories

- **Implementer under `/cdocs:iterate`.** It needs a full test suite run and to know which callers use a function it changed. It dispatches `bash-runner` for the suite and `Explore` for the callers, then continues with both reports in hand. No round trip through the overseer and no lost iteration.
- **Reviewer verifying a floor.** It dispatches `bash-runner` to start the dev server and curl three endpoints. It cites the scratch file path in the review, keeping a ~2,000-line server log out of its own context.
- **Four-proposal arc.** The arc overseer's context holds four dispatches, four Up summaries, and the arc file, instead of every round of four loops. Two proposals with disjoint footprints run concurrently as two sub-overseers.
- **Sub-overseer escalation.** A reviewer returns `reject` on proposal 2. The sub-overseer marks the escalation in the proposal devlog and returns it. The arc overseer marks the proposal `blocked` in the arc file and asks the user.

## Edge Cases / Challenging Scenarios

- **Headless and SDK runs.** There, a lead does not wait for its background children, and a late grandchild reports to the main conversation, which breaks "if control has returned, it has ended". cdocs loops run interactively, so this affects headless smoke tests and any future CI driver. There, leads dispatch in the foreground (`run_in_background: false`, which headless `Agent` offers) or stay one lead deep. See the Background NOTE for the observed behavior.
- **Depth exhaustion.** At `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=2`, implementers lose their helper layer and work inline, which is harmless. At `=1`, or before 2.1.219, a sub-overseer has no `Agent`, returns, and the arc overseer runs the loop itself. A dispatched `/oversee` declines. An off-by-one in that variable is reported in [#84974](https://github.com/anthropics/claude-code/issues/84974) (unverified here).
- **Concurrent writers across subtrees.** Two sub-overseers' implementers could touch one file. Arc footprints already serialize overlapping proposals. Within a subtree, a lead only dispatches writers inside its own claim.
- **Lost visibility.** The human sees only top-level traffic, and the arc overseer sees only Up summaries. Durable state (sub-devlogs, Scratchpoints, handoffs, loop tables) is what keeps nested work inspectable. That state is unchanged and is now what makes nesting safe.
- **Cost.** Each child re-reads its own context. The Nesting section's "don't nest" clause is the guard. The verification below checks that agents use it rather than reflexively fanning out.
- **Permission prompts in nested agents.** [#83421](https://github.com/anthropics/claude-code/issues/83421) reports `bypassPermissions` not reaching Agent-tool children (unverified here: probes ran without prompts in a bypass session). An AFK arc that hits a prompt at layer 2 stalls like any other prompt. No cdocs change is needed, but the smoke would surface it.

## Test Plan

Static (Phase 1 and 2):
- `grep -rniE "Investigation Requested|subagent-from-subagent|cannot dispatch|cannot spawn|TOP-LEVEL ONLY|no \`Task\`|inside a subagent" plugins/cdocs` returns nothing.
- `wc -w` over the touched files is lower after the change than before.
- `npm run build:cdocs` succeeds, and the generated OC agents differ from the previous build only in body prose.
- Every `## Investigation Requested` reference left in `cdocs/` is in a historical devlog, review, or accepted proposal. These are not edited.

Live (Phase 3) uses the `hooks/tests/chat-record.test.sh` pattern, because the installed marketplace cache is stale and must not be what runs.
In a scratch worktree, run `claude -p --plugin-dir <repo>/plugins/cdocs --permission-mode bypassPermissions "/cdocs:oversee chain <fixture> --afk"`, with the prompt telling every lead to dispatch in the foreground (`run_in_background: false`).
The fixture is a trivial `implementation_ready` proposal whose phase and floor each require running a test command.
List each transcript's `Agent` calls with `jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Agent") | .input.subagent_type'`, over the session JSONL and the `subagents/` transcripts beside it:
1. The top-level transcript has exactly one `Agent` call (the sub-overseer).
2. A layer-1 transcript has the `cdocs:implementer` and `cdocs:reviewer` calls.
3. A layer-2 transcript has a `cdocs:bash-runner` (or `Explore`) call, which shows layer 3 is reached.
4. No transcript contains `## Investigation Requested`. The fixture's devlog has the sub-overseer's dispatch and return rows, and the arc file ends `done`.
5. Re-run with `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1`. The sub-overseer returns saying it cannot dispatch, and the loop's dispatches appear in the top-level transcript.

## Verification Methodology

The floor: an implementer dispatched by `/cdocs:iterate` dispatches its own helper, and `/oversee` completes a one-proposal arc through a sub-overseer whose children reach layer 3.

Failure looks like any of these:
- The implementer returns an `## Investigation Requested` block or says it cannot dispatch, meaning stale text survived somewhere it reads.
- The arc overseer's transcript contains implementer or reviewer dispatches, meaning it ran the loop itself.
- A sub-overseer stalls looking for `AskUserQuestion` instead of returning its question.
- The arc file shows `done` while the proposal devlog has a dispatch row with no return.
- With nesting disabled, the proposal devlog shows review output written by the agent that implemented.

The harness loads the repo's plugin, so the self-referential change is testable in-session.
Record Phase 3 as `deferred-to-followup` only for a stated blocker (no credentials, say), with an rfp filed.

## Implementation Phases

### Phase 1: Rule section and leaf workaround deletion

- Add `## Nesting` to `rules/orchestration-discipline.md`, and add the qualifier to "Resume from disk" (Proposed Solution 1).
- Apply the edit table in Proposed Solution 2.
- Re-run `/cdocs:init` materialization in this repo only if its marker check requires it. The SessionStart hook is silent in the source repo.
- File a `/cdocs:rfp` for the OC `tools: "*"` mapping (Summary NOTE).
- Verify: the static Test Plan items. Commit each file group separately (rule, implement/implementer, reviewer, propose/proposer, iterate, triage, ablate).

### Phase 2: `/oversee` sub-overseers

- Apply the `oversee` edits and the `iterate`/`propose-revise` role-line edits (Proposed Solution 3).
- Optionally add a NOTE in `cdocs/proposals/2026-09-03-overseer-arc.md` pointing here for the sub-overseer change; do not rewrite that proposal.
- Verify: re-run the static grep and `wc -w`. Read `oversee/SKILL.md` cold and check that Composition, Composition contract, Hard gates, and Resume say who owns which devlog and how a question reaches the user.

### Phase 3: Live smoke

- Run the Test Plan's live harness, both runs.
- Check that the OC build still succeeds and that the OC agents carry the edited prose.
- Verify: the floor above, with each failure picture checked explicitly in the devlog.

Constraints:
- Do not change hooks, `scripts/build-opencode.ts`, the devlog skill, or any leaf agent's `tools:` list.
- Do not edit historical devlogs, reviews, or accepted proposals beyond the optional NOTE.
- Do not add a schema, table, or state field to replace `## Investigation Requested`.

## Resolved Questions

- A sub-overseer that cannot dispatch returns, and the arc overseer runs the loop itself. This is the existing behavior, chosen over a hard-gate halt or an advisory-only run.
- `chat_record` lives only on the arc devlog under `/oversee`. The arc overseer does not stamp the proposal devlogs.
- The Phase 3 harness is headless `--plugin-dir` with foreground dispatch. An interactive tmux run, which would test the real waiting semantics, is optional follow-up.
