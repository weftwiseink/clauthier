---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T17:35:00-07:00
task_list: cdocs/nested-subagent-workflows
type: proposal
state: live
status: review_ready
last_reviewed:
  status: accepted
  by: "@claude-opus-5-5"
  at: 2026-10-06T18:36:06-07:00
  round: 4
tags: [orchestration_discipline, architecture, claude_skills]
---

# Nested Subagent Workflows

> BLUF(opus-5-5/cdocs/nested-subagent-workflows): Claude Code subagents can dispatch subagents, three layers below the human session by default ([docs](https://code.claude.com/docs/en/sub-agents#let-subagents-spawn-their-own-subagents)), which was verified empirically here.
> cdocs deletes its "subagents cannot dispatch" workarounds, including the `## Investigation Requested` handback, and lets subagents dispatch freely within the platform limit.
> Leaves stay leaves through their `tools:` lists.
> Overseer mechanics are unchanged; nested overseers are deferred to [`2026-10-06-nest-overseers-rfp.md`](2026-10-06-nest-overseers-rfp.md).

## Summary

The change is deletion plus a few factual corrections.
Models already delegate sensibly: the `Agent` tool description that guides the top-level session is the same one every subagent sees.
So cdocs adds no nesting guidance and imposes no limit beyond the platform's own.
The invariants that still hold stay as they are:
- Only the top-level session reaches the human, because `AskUserQuestion` is absent from subagents.
- `chat-record` runs only at the top level.

Leaves (`judge`, `bash-runner`, `nit-fix`, `triage`) are leaves because their `tools:` lists omit `Agent`, so they need no prose.
The loop skills (`iterate`, `propose-revise`, `full-send`, `oversee`) stay top-level-run.
Their text changes only where it states something now false.

> NOTE(opus-5-5/cdocs/nested-subagent-workflows): Two adjacent problems are out of scope.
> First, `scripts/build-opencode.ts` `mapTools` maps `tools: "*"` to `read/edit/write/bash: false`, because `*` falls through to the unknown-tool branch, so the generated OC `implementer`, `reviewer`, and `proposer` have every mapped tool disabled. Phase 1 files an rfp for it.
> Second, `ablate`'s deferred live run is blocked by its graphify container, not by nesting.

## Objective

Let dispatched cdocs agents dispatch their own helpers, delete the machinery built around their inability to do so, and add no formalism in its place.

## Background

These findings are for Claude Code 2.1.292.
"Empirical" means observed in this authoring session, which is itself a dispatched `cdocs:proposer` at layer 1 running probes, plus one scratch `claude -p` run.

| Finding | Source | Established |
|---|---|---|
| Subagents dispatch subagents up to three layers below the main conversation. `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` sets the limit, and `1` disables nesting. | [docs](https://code.claude.com/docs/en/sub-agents#let-subagents-spawn-their-own-subagents); [CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md) 2.1.219 ("up to depth 3 by default (was 1)"); 2.1.217 had turned nesting off by default | Empirical: layers 1 and 2 dispatched; layer 3 had no `Agent` |
| At the limit `Agent` is withheld, and the agent works inline. Forks count toward the cap (2.1.187). | docs; CHANGELOG 2.1.187 | Empirical (layer 3) |
| A `tools:` list without `Agent` cannot nest. `Agent(type)` allowlists are ignored in subagent definitions. | [docs](https://code.claude.com/docs/en/sub-agents#restrict-which-subagents-can-be-spawned) | Empirical: a dispatched `cdocs:nit-fix` lacked `Agent`; `tools: "*"` agents have it |
| Dispatch from a subagent returns an agent id, and a task notification later carries the result and `<usage><subagent_tokens>`. `SendMessage` and `fork` work from a subagent. | notification text; [docs](https://code.claude.com/docs/en/sub-agents#resume-subagents) | Empirical |
| An interactive subagent waits for its background children before finishing. A headless or SDK one does not. | docs | Interactive: empirical. Headless: one scratch run |
| `AskUserQuestion` is absent from subagents at every layer. | [#34592](https://github.com/anthropics/claude-code/issues/34592) | Empirical: layers 1-3 |
| `PreToolUse` hooks fire for nested agents, with the nested agent's own `agent_type`. | hook payload | Empirical: a layer-2 `cdocs:nit-fix` was blocked by `validate-cdocs-edit-path.sh` |
| OpenCode: `permission.task` globs control which subagents an agent may invoke. Subagent access to `task` and any depth limit are undocumented. | [OC agents docs](https://opencode.ai/docs/agents/) | Docs only |

## Proposed Solution

### 1. Delete the leaf workarounds

| File | Edit |
|---|---|
| `skills/implement/SKILL.md` | The Dispatched bullet keeps its signal (flag or parent prompt), the named sub-devlog, and isolation. It replaces the "platform forbids" clause, the fenced schema, and the "caller decides" paragraph with "Questions for the user go in your return." Step 5's dispatched line becomes "the loop's reviewer reviews". Delete the Dispatched line under "Use cdocs skills". |
| `agents/implementer.md`, `agents/proposer.md` | Delete the "cannot dispatch" sentence. |
| `agents/reviewer.md` | Replace the "cannot dispatch" bullet with "Children you dispatch inherit these boundaries." The edit-path hook binds the reviewer's own `Edit`/`Write` only, not its children. |
| `skills/propose/SKILL.md` | The checklist's dispatched line becomes "dispatched by a `/cdocs:propose-revise` loop, skip this item: the loop's reviewer is that review". |
| `skills/iterate/SKILL.md` | Delete the "`--dispatched` mode suppresses subagent dispatch" paragraph. |
| `skills/triage/SKILL.md` | Delete "(the main agent dispatches this since agents cannot spawn subagents)". |
| `skills/ablate/SKILL.md` | At its four sites, replace the "from inside a subagent" reasoning with "not yet run live (needs a graphify container)". The NOTE at line 28 becomes "run it from a lead with two dispatch layers below it". The deferred items stay. |

`--dispatched` stays: it still selects the named sub-devlog, isolation, and loop-owned review.

### 2. Correct `/oversee`'s reason, keep its behavior

`/oversee` keeps its TOP-LEVEL ONLY note and its declines-or-advisory behavior.
Only the reason changes, from "Subagents cannot dispatch" to "it needs the human (gates, `AskUserQuestion`), whom only the top-level session reaches".
No other loop skill states that subagents cannot dispatch, so `iterate`, `propose-revise`, and `full-send` keep their overseer text unchanged.

### 3. OpenCode

There is no build or path change.
An OC subagent without `task` works inline, which is what the deleted text demanded anyway.

## Important Design Decisions

- **No nesting guidance and no cdocs limit.** The runtime's own `Agent` description already guides delegation at every depth, and the platform enforces depth. cdocs text would duplicate both, and would drift as they change.
- **No replacement for `## Investigation Requested`.** An agent that can dispatch investigates itself. One that cannot names the open question in its return in plain text.
- **Leaves by `tools:`, not prose.** The docs name `tools:` as the per-agent switch, and the hook payloads confirm it holds at depth.
- **Overseer mechanics are out of scope.** Whether to nest an overseer is a user decision, not one an agent makes for itself. The seed design (chat layer, sub-overseers, `chat_record` pass-down, fail-loud gate) lives in the RFP.
- **Keep `--dispatched`.** It is an explicit signal for sub-devlog, isolation, and loop-owned review. Inferring these from the prompt would be weaker.

## Edge Cases / Challenging Scenarios

- **Headless and SDK leads do not wait for background children.** cdocs loops run interactively, and the live check forces foreground with `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`.
- **Depth exhaustion.** An implementer at layer 3, or one running under a lowered `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`, has no `Agent` and works inline. This is harmless.
- **Permission prompts at depth.** [#83421](https://github.com/anthropics/claude-code/issues/83421) reports `bypassPermissions` not reaching Agent-tool children. This is unverified here: the probes ran without prompts.
- **Depth variable off-by-one.** Reported in [#84974](https://github.com/anthropics/claude-code/issues/84974); unverified here.

## Test Plan

Static checks:

```sh
grep -rniE 'Investigation Requested|subagent-from-subagent|cannot dispatch|cannot spawn|no `Task`|inside a subagent' plugins/cdocs
```

- The grep returns nothing.
- `wc -w` over `plugins/cdocs` drops. Note the before and after counts in the devlog.
- `npm run build:cdocs` succeeds, and the OC agents differ from the previous build only in body prose.

The live check uses the `claude_run` setup from `hooks/tests/chat-record.test.sh`:
- a `git init` fixture outside any repo with no remote, prepared by `init_rules`;
- a sandboxed `CLAUDE_CONFIG_DIR` holding only copied credentials, deleted afterwards;
- `env -i`;
- `--plugin-dir` at the repo's `plugins/cdocs`;
- `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`.

The fixture is a one-phase `implementation_ready` proposal whose Verification Methodology says to run its test command (a few thousand lines of output) through `cdocs:bash-runner`.
The top-level prompt dispatches `cdocs:implementer` with `/cdocs:implement --dispatched <fixture>`.
Read the layers from the metadata files:

```sh
jq -r '[.spawnDepth, .agentType, (.parentAgentId // "-")] | @tsv' "$CFG"/projects/*/*/subagents/*.meta.json
```

1. A depth-1 `cdocs:implementer` and a depth-2 `cdocs:bash-runner` whose parent is that implementer.
2. The implementer's return has no `## Investigation Requested` block.

## Verification Methodology

The floor: a dispatched implementer dispatches its own helper in the confined harness, and the static grep is clean.

Failure looks like any of these:
- There is no depth-2 `bash-runner`, and the implementer says it cannot dispatch, or returns an `## Investigation Requested` block: stale text survived somewhere it reads.
- The grep matches: a prohibition was missed.

Defer the live check (`deferred-to-followup`) only for a stated blocker, such as missing credentials, and file an rfp when doing so.

## Implementation Phases

### Phase 1: Deletions and corrections

- Apply the section 1 table and the section 2 `/oversee` reason change.
- File a `/cdocs:rfp` for the OC `tools: "*"` mapping.
- Verify: the static checks. Commit per file group (implement/implementer, reviewer, propose/proposer, iterate, triage, ablate, oversee).

### Phase 2: Live check

- Run the live check and record each failure picture explicitly in the devlog.

Constraints:
- Do not change overseer mechanics (`iterate`, `propose-revise`, `full-send`, `oversee` behavior), hooks, `scripts/build-opencode.ts`, the devlog skill, `rules/`, or any leaf's `tools:` list.
- Do not edit historical devlogs, reviews, or accepted proposals.
- Do not add a schema, section, or state field in place of the deleted text.
