---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T17:35:00-07:00
task_list: cdocs/nested-subagent-workflows
type: proposal
state: live
status: implementation_ready
last_reviewed:
  status: accepted
  by: "@claude-opus-5-5"
  at: 2026-10-06T18:23:28-07:00
  round: 3
tags: [orchestration_discipline, architecture, claude_skills]
---

# Nested Subagent Workflows

> BLUF(opus-5-5/cdocs/nested-subagent-workflows): Claude Code subagents can dispatch subagents, three layers below the human session by default ([docs](https://code.claude.com/docs/en/sub-agents#let-subagents-spawn-their-own-subagents)), which was verified empirically here.
> cdocs deletes its "subagents cannot dispatch" workarounds, including the `## Investigation Requested` handback, and adds no general nesting guidance.
> Every loop skill becomes nest-safe: it runs the same at the top level or dispatched as a sub-overseer. An overseer without `Agent` fails loudly.
> `/oversee` dispatches each proposal's loop as a sub-overseer.

## Summary

The change is mostly deletion.
Models already delegate sensibly: the `Agent` tool description that guides the top-level session is the same one every subagent sees.
So cdocs states only what a model cannot infer:

- An overseer never plays its own implementer or reviewer. Without `Agent`, it stops at once with an explicit error and does no work.
- Only the top-level session, the *chat layer*, reaches the human through `AskUserQuestion` and `chat-record`. A dispatched overseer escalates by returning, and receives answers and steering by `SendMessage`.
- Leaves (`judge`, `bash-runner`, `nit-fix`, `triage`) are leaves because their `tools:` lists omit `Agent`. No prose is needed.

These land as a few sentences in `orchestration-discipline.md`, plus one-line role edits in the loop skills.
Whether a single loop runs inline or as a sub-overseer is the chat layer's judgment.
`/oversee` always dispatches, and it shrinks as a result.
The expected net effect is fewer words across `plugins/cdocs`.

> NOTE(opus-5-5/cdocs/nested-subagent-workflows): Two adjacent problems surfaced during research and are out of scope.
> First, `scripts/build-opencode.ts` `mapTools` maps `tools: "*"` to `read/edit/write/bash: false`, because `*` falls through to the unknown-tool branch, so the generated OC `implementer`, `reviewer`, and `proposer` have every mapped tool disabled. Phase 1 files an rfp for it.
> Second, `ablate`'s deferred live run is blocked by its graphify container, not by nesting.

## Objective

Let cdocs workflows use nested dispatch where it saves context, delete the machinery built around its absence, and add no formalism in its place.

## Background

### Capability findings

These findings are for Claude Code 2.1.292.
"Empirical" means observed in this authoring session, which is itself a dispatched `cdocs:proposer` at layer 1 running probes, plus one scratch `claude -p` run.

| Finding | Source | Established |
|---|---|---|
| Subagents dispatch subagents up to three layers below the main conversation. `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` sets the limit, and `1` disables nesting. | [docs](https://code.claude.com/docs/en/sub-agents#let-subagents-spawn-their-own-subagents); [CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md) 2.1.219 ("up to depth 3 by default (was 1)"); 2.1.217 had turned nesting off by default | Empirical: layers 1 and 2 dispatched; layer 3 had no `Agent` |
| At the limit `Agent` is withheld. Forks count toward the cap, and resumed subagents "restore their original spawn depth" (2.1.187). | docs; CHANGELOG 2.1.187 | Empirical (layer 3) |
| A `tools:` list without `Agent` cannot nest. `Agent(type)` allowlists are ignored in subagent definitions. | [docs](https://code.claude.com/docs/en/sub-agents#restrict-which-subagents-can-be-spawned) | Empirical: a dispatched `cdocs:nit-fix` lacked `Agent`; `tools: "*"` agents have it |
| Dispatch from a subagent returns an agent id, and a task notification later carries the result and `<usage><subagent_tokens>`. | notification text | Empirical |
| An interactive subagent waits for its background children before finishing. A headless or SDK one does not, so background work does not outlive a headless lead. | docs | Interactive: empirical. Headless: one scratch run, which saw a finishing agent's background task `stopped` |
| `SendMessage` from a subagent resumes a finished child, or reaches a running child at its next tool round. It addresses children by agent id, not by description. | [docs](https://code.claude.com/docs/en/sub-agents#resume-subagents) | Empirical |
| `AskUserQuestion` is absent from subagents at every layer. | [#34592](https://github.com/anthropics/claude-code/issues/34592) | Empirical: layers 1-3 |
| `PreToolUse` hooks fire for nested agents, with the nested agent's own `agent_type`. | hook payload | Empirical: a layer-2 `cdocs:nit-fix` was blocked by `validate-cdocs-edit-path.sh` |
| `subagents/*.meta.json` records `spawnDepth`, `agentType`, and `requestShape` (`background` or `foreground`) per dispatch. | transcript files | Empirical |
| OpenCode: `permission.task` globs control which subagents an agent may invoke. Subagent access to `task` and any depth limit are undocumented. | [OC agents docs](https://opencode.ai/docs/agents/) | Docs only |

### The cost today

`/oversee` is marked "TOP-LEVEL ONLY", and its arc overseer "runs each composed loop as itself", so every implementer, reviewer, and judge return across an arc lands in one context.
Every dispatched role is also written as a leaf: seven sentences across skills and agents restate a prohibition the runtime no longer has.

## Proposed Solution

### 1. Rule text in `orchestration-discipline.md`

Add to the opening paragraph, which defines the overseer:

```markdown
The overseer may be the top-level session or a sub-overseer it dispatched, and the loop skills read the same either way.
Without the `Agent` tool, stop at once with an explicit error and do no work: an overseer never plays its own implementer or reviewer.
```

Replace the first line of "Chat record" with:

```markdown
The top-level Claude Code session is the chat layer: only it reaches the human (`AskUserQuestion`, `chat-record`), so never run `chat-record` if the `Agent` tool dispatched you.
A sub-overseer escalates by returning its question. Answers and steering reach it by `SendMessage`.
Running a loop inline or as a sub-overseer is the chat layer's call.
The chat layer passes its `chat-record path` in a sub-overseer's brief, and the overseer that owns the workstream's top-level devlog adds it to `chat_record`.
```

That devlog's `chat_record` then lists the chat layer's record whether the loop ran inline or nested, so the existing post-compaction step ("read the devlogs that list it") finds every workstream the chat layer drives.
The sub-overseer writes a given string and runs nothing, so "never run `chat-record`" holds.

Nothing else in the rule file changes.
"Stay thin", "Resume from disk", and the ~400K warm-child handoff already address whoever leads the loop, and `subagent_tokens` reaches subagent parents too.

### 2. Delete the leaf workarounds

| File | Edit |
|---|---|
| `skills/implement/SKILL.md` | The Dispatched bullet keeps its signal (flag or parent prompt), the named sub-devlog, and isolation. It drops the "platform forbids" clause, the fenced schema, and the "caller decides" paragraph. Step 5's dispatched line becomes "the loop's reviewer reviews". Delete the Dispatched line under "Use cdocs skills". |
| `agents/implementer.md`, `agents/proposer.md` | Delete the "cannot dispatch" sentence. |
| `agents/reviewer.md` | Replace the "cannot dispatch" bullet with "Children you dispatch inherit these boundaries." The edit-path hook binds the reviewer's own `Edit`/`Write` only, not its children. |
| `skills/propose/SKILL.md` | The checklist's dispatched line becomes: dispatched by a `/cdocs:propose-revise` loop, skip this item; the loop's reviewer is that review. |
| `skills/iterate/SKILL.md` | Delete the "`--dispatched` mode suppresses subagent dispatch" paragraph. |
| `skills/triage/SKILL.md` | Delete "(the main agent dispatches this since agents cannot spawn subagents)". |
| `skills/ablate/SKILL.md` | At its four sites, replace "from inside a subagent" reasoning with "not yet run live (needs a graphify container)". The NOTE at line 28 becomes "run it from a lead with two dispatch layers below it". The deferred items stay. |

`--dispatched` stays: it still selects the named sub-devlog, isolation, and loop-owned review.

### 3. Nest-safe loop skills

`iterate` and `propose-revise` change in two ways (`full-send` has neither a role line nor an `AskUserQuestion`, so it needs no edit):
- The "Overseer: top-level agent" role line becomes "Overseer: the agent running the loop, top-level or dispatched (see `orchestration-discipline.md`)".
- Each "AskUserQuestion" instruction becomes "ask the user", and section 1 says how a sub-overseer does that.

There are three such sites: iterate line 29, and propose-revise lines 15 and 20.
No other loop text assumes the top level.

### 4. `/oversee` dispatches sub-overseers

The arc overseer dispatches one fresh `general-purpose` sub-overseer per proposal, at the lead tier, to run `/cdocs:full-send` or `/cdocs:iterate`.
The Composition contract becomes the dispatch prompt and its return:
- Down: path, floor, model flags, AFK line, and the chat layer's `chat-record path`.
- Up: frontmatter status, final handoff, and the arc file.

The sub-overseer owns the proposal's top-level devlog and adds the passed record path to its `chat_record`.
The arc overseer owns the arc file and the arc devlog.
Disjoint proposals run as parallel sub-overseers.
A proposal's `arc_state: in_progress` is the sub-overseer's dispatch row.
The default depth budget fits exactly: arc overseer, then sub-overseer (layer 1), then implementer, reviewer, or judge (layer 2), then a helper (layer 3, a leaf by the limit).

Edits to `skills/oversee/SKILL.md`:
- Delete the TOP-LEVEL ONLY note. Section 1's loud-failure rule covers an `/oversee` without `Agent`.
- Replace "runs each composed loop as itself, so it is the only overseer..." with the dispatch sentence.
- Concurrency's "may run in parallel under this one overseer" becomes "as parallel sub-overseers".
- Hard gates: add "a sub-overseer's missing-`Agent` error", so the arc never retries or runs that loop inline. A sub-overseer's escalation arrives as its return. The arc overseer marks the proposal `blocked`, surfaces the escalation, and resumes the sub-overseer by `SendMessage` with the answer.

> NOTE(opus-5-5/cdocs/nested-subagent-workflows): Candidate `/oversee` deletions are left out of scope because they are not directly simplified by nesting: the arc devlog duplicates the arc file's narrative and handoff role, and `position` is derivable from per-proposal `arc_state`.
> They are worth a follow-up rfp once sub-overseers have run.

### Inline or nested: trade-offs

Running a loop inline keeps every round in the chat layer's context.
The human can see each round, and the chat layer can connect it to other workstreams in the same conversation.
Dispatching gives each workstream a dedicated opus that the chat layer can query by `SendMessage`, and it keeps the chat context to summaries.
Dispatch has three costs:
- Escalations and steering pay a relay hop and wait for the sub-overseer's live children.
- Round-level detail is visible only on disk.
- The default depth budget is spent exactly, so a lowered `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` turns implementers into leaves (at `2`) or stops the loop with its error (at `1`).

### 5. OpenCode

No build or path change.
An OC subagent without `task` behaves like any agent without `Agent`: a leaf works inline, and an overseer errors.

## Important Design Decisions

- **No general nesting guidance.** The runtime's own `Agent` description already guides delegation at every depth. cdocs-specific text would duplicate it, and would drift as it changes.
- **Fail loudly, with no fallback.** An overseer that implements and reviews in one context would void the fresh-reviewer invariant and still record a clean accept. A parent-runs-it-instead fallback adds a path no default configuration exercises.
- **No replacement for `## Investigation Requested`.** An agent that can dispatch investigates itself. One that cannot names the open question in its return in plain text.
- **Leaves by `tools:`, not prose.** The docs name `tools:` as the per-agent switch, and the hook payloads confirm it holds at depth.
- **The chat layer passes its record path down, and the devlog's owner writes it.** Every human prompt lands at the top. Linking the record from each workstream top-level devlog keeps post-compaction recovery unchanged whether the loop ran inline or nested. Having the owner write the path keeps one writer per file, and it works for devlogs created after dispatch.
- **Keep `--dispatched`.** It is an explicit signal for sub-devlog, isolation, and loop-owned review. Inferring these from the prompt would be weaker.

## Edge Cases / Challenging Scenarios

- **Headless and SDK leads do not wait for background children.** cdocs loops run interactively. The Phase 3 harness forces foreground with `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`.
- **Dispatched `/oversee`.** At layer 1, its sub-overseers sit at layer 2 and their implementers at layer 3 as leaves. This works, with no helper layer.
- **Concurrent writers across subtrees.** Arc footprints already serialize overlapping proposals.
- **Permission prompts at depth.** [#83421](https://github.com/anthropics/claude-code/issues/83421) reports `bypassPermissions` not reaching Agent-tool children. This is unverified here: the probes ran without prompts. An AFK arc stalled at layer 2 is the symptom.
- **Depth variable off-by-one.** Reported in [#84974](https://github.com/anthropics/claude-code/issues/84974); unverified here.

## Test Plan

Static checks (Phases 1 and 2):

```sh
grep -rniE 'Investigation Requested|subagent-from-subagent|cannot dispatch|cannot spawn|TOP-LEVEL ONLY|no `Task`|inside a subagent' plugins/cdocs
```

- The grep returns nothing.
- `wc -w` over `plugins/cdocs` is expected to drop. Note the before and after counts in the devlog.
- `npm run build:cdocs` succeeds, and the OC agents differ from the previous build only in body prose.

Live check (Phase 3) uses the `claude_run` setup from `hooks/tests/chat-record.test.sh`:
- a `git init` fixture project outside any repo, with no remote, prepared by `init_rules` so that the rules, the `CLAUDE.md` import, and the `_chat` scaffold load;
- a sandboxed `CLAUDE_CONFIG_DIR` holding only copied credentials, deleted afterwards;
- `env -i`;
- `--plugin-dir` at the repo's `plugins/cdocs`;
- `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`, which is process-wide, so every layer dispatches in the foreground;
- optionally `--disallowedTools "Bash(git push:*)" "Bash(gh:*)"`.

The fixture is a trivial `implementation_ready` proposal and its source.
Its test command prints a few thousand lines, so handing it to `bash-runner` is the natural move.
Run `claude -p --permission-mode bypassPermissions "/cdocs:oversee chain <fixture> --afk"`, then read the layers:

```sh
jq -r '[.spawnDepth, .agentType, (.parentAgentId // "-"), .requestShape] | @tsv' "$CFG"/projects/*/*/subagents/*.meta.json
```

1. The depth-2 `cdocs:implementer` and `cdocs:reviewer` share one `parentAgentId`, and that agent is a depth-1 `general-purpose` sub-overseer. No depth-1 `cdocs:implementer`, `cdocs:reviewer`, or `cdocs:judge` exists.
2. Every `requestShape` is `foreground`.
3. The fixture devlog has the loop's implementer and reviewer rows, its `chat_record` lists the run's record, and the arc file ends `done`.
4. Re-run with `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1`. The sub-overseer returns an explicit missing-`Agent` error, there are no depth-2 agents, the arc file marks the proposal `blocked`, and the fixture has no commits beyond its baseline.

Log as an observation, not a floor item: whether a depth-3 `cdocs:bash-runner` or `Explore` appears.
Inline `cmd > file; tail` is an equally valid choice for the implementer.

Escalation, `SendMessage` resume, and steering cannot occur in an `--afk` headless run.
They belong to an optional interactive (tmux) follow-up and are not covered by this floor.

## Verification Methodology

The floor: `/oversee` completes a one-proposal arc in the confined harness through a sub-overseer, and with nesting disabled the loop errors without doing work and the arc blocks.

Failure looks like any of these:
- A depth-1 implementer, reviewer, or judge appears: the arc overseer ran the loop itself.
- An implementer's return contains `## Investigation Requested` or says it cannot dispatch: stale text survived.
- At depth `1`, the fixture has new commits or review output: an overseer played its own children, or the arc ran the loop inline instead of blocking.
- A `background` `requestShape` appears: the run was not confined to foreground, and its results are unreliable.

Defer Phase 3 (`deferred-to-followup`) only for a stated blocker, such as missing credentials, and file an rfp when doing so.

## Implementation Phases

### Phase 1: Rule text and leaf workaround deletion

- Apply section 1 to `rules/orchestration-discipline.md`, and apply the section 2 table.
- Re-run `/cdocs:init` materialization only if its marker check requires it.
- File a `/cdocs:rfp` for the OC `tools: "*"` mapping.
- Verify: the static checks. Commit per file group (rule, implement/implementer, reviewer, propose/proposer, iterate, triage, ablate).

### Phase 2: Nest-safe loops and `/oversee`

- Apply sections 3 and 4.
- Verify: the static checks again. Read `oversee/SKILL.md` cold and confirm it says who owns which devlog and how an escalation reaches the user.

### Phase 3: Live check

- Run both live runs and check each failure picture explicitly in the devlog.

Constraints:
- Do not change hooks, `scripts/build-opencode.ts`, the devlog skill, or any leaf's `tools:` list.
- Do not edit historical devlogs, reviews, or accepted proposals.
- Do not add a schema, section, or state field in place of the deleted text.
