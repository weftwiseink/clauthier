---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-10-05T13:56:48-07:00
task_list: cdocs/rules-context-decomposition
type: proposal
state: live
status: review_ready
last_reviewed:
  status: revision_requested
  by: "@claude-opus-5-5"
  at: 2026-10-06T09:31:19-07:00
  round: 1
tags: [rules, architecture, orchestration_discipline, oversee, init, context_budget, formalism_reduction]
---

# Rules Context Decomposition

> BLUF(@claude-opus-5-5/cdocs/rules-context-decomposition): Compress the always-loaded cdocs rules from 797 lines / 8,054 words to about 300 lines / 2,100 words, then lay them out.
> `orchestration-discipline.md` becomes about 60 lines of observed-failure lessons under descriptive headings.
> `oversee-arc.md` is deleted: its generic lessons become three lines in that rule, and its arc-only material moves into the `oversee` skill.
> The thinness signal, claim registry, Steering Log kinds, and every Cross-Target block are deleted, not relocated, and a follow-up RFP covers target-specific guidance.
> Per-section reasoning lives in [the simplification review](../reviews/2026-10-06-review-of-overseer-rules-simplification.md).

## Summary

The always-loaded rules teach a lead session about five real lessons, buried under schemas, vocabularies, and enforcement machinery that the devlogs show went mostly unused.
This proposal compresses first and then decides layout:

- **Always-loaded (five files):** `writing-conventions.md` and `frontmatter-spec.md` stay as they are.
  `orchestration-discipline.md`, `model-tiering.md`, and `workflow-patterns.md` are rewritten to the wording below.
- **Deleted:** `oversee-arc.md` and all Cross-Target Degradation text.
  The overseer thinness signal (`inline_work`, `overseer_thinness`, `signal_missing`, Graded Enforcement) goes.
  So does the claim registry, along with the `oversee` AFK and interleaving machinery nobody used, the five Steering Log kinds, and the CLAUDE.md reseed and Inline Discipline Floor rationale sections.
- **On demand:** arc state, proposal sequencing, the proposal-level return contract, and arc resume live in `skills/oversee/SKILL.md`.
  Loop mechanics stay in `iterate`, compressed.
- **Delivery:** `/cdocs:init` and the OpenCode build glob `rules/*.md`, so a smaller set needs only small fixes: one init list entry, a stale-file cleanup on the OpenCode path, and one sentence of wording.

> NOTE(@claude-opus-5-5/cdocs/rules-context-decomposition): Design stance, from the maintainer: lean on agent intuition, keep only guidance that encodes an observed failure, prefer guidelines over bans, and size things in lines and words.
> The reference altitude is the maintainer's `bash-runner` rewrite ([6821b43](https://github.com/weftwiseink/clauthier/commit/6821b43481d0ba1bbb504f0cadf7dc70f3c5adae)).

## Objective

Shrink and declutter the rules context that every session and dispatched subagent loads, so that:
- what is always loaded is the short set of lessons a lead or worker actually needs,
- arc-only and loop-only mechanics load only with the skill that uses them,
- no target-specific (non-Claude-Code) guidance sits in rules, skills, or agents,
- the always-loaded footprint has a stated budget that can be checked with `wc -l -w`.

## Background

- [Simplification review](../reviews/2026-10-06-review-of-overseer-rules-simplification.md): per-file goals, the keep/compress/cut table, usage evidence, and draft wordings.
  It is the primary design input, and this proposal does not restate its reasoning.
- [Loop devlog Brief](../devlogs/2026-10-06-rules-context-decomposition-full-send.md): scope, maintainer steering, verification floor, and optional devlog-splitting input.
- Delivery: `/cdocs:init` step 3 concatenates every `rules/*.md` (frontmatter stripped) into `.claude/rules/cdocs.md`, which `CLAUDE.md` `@`-imports.
  Step 5 copies the files to `.opencode/rules/cdocs/` and step 6 inlines them into `AGENTS.md`.
  `scripts/build-opencode.ts` and `plugins/cdocs/scripts/postinstall.js` copy the whole `rules/` directory.
  `hooks/inject-rules.ts` hashes the sorted bodies of `rules/*.md`.
  None of these name individual rule files, except init step 6's section list.
- Sync guard: `plugins/cdocs/hooks/tests/chat-record.test.sh --unit` asserts that init step 6's `[Full content of X.md ...]` list names exactly the files in `rules/`.
  The `init_real` and `rules_check` extras assert two literal chat-record phrases in the materialized rules.
- `triage` keys on the `## Iteration Log` heading and on the `review_verdict` and Judge Log `verdict` column headers.
- The chat-record proposal is `implementation_accepted`, so its rule text can be compressed here without colliding with an in-flight loop.

## Proposed Solution

### Target layout and budget

| File | Loaded | Before (lines / words) | After (approx.) |
|---|---|---|---|
| `rules/orchestration-discipline.md` | always | 270 / 3,531 | 63 / 660 |
| `rules/oversee-arc.md` | always | 141 / 1,623 | deleted |
| `rules/workflow-patterns.md` | always | 132 / 1,020 | 21 / 190 |
| `rules/model-tiering.md` | always | 51 / 744 | 9 / 140 |
| `rules/writing-conventions.md` | always | 93 / 560 | unchanged |
| `rules/frontmatter-spec.md` | always (inlined by init) | 110 / 576 | unchanged except one pointer |
| **Always-loaded total** | | **797 / 8,054** | **~300 / ~2,100** |
| `skills/iterate/SKILL.md` | with `/iterate` | 217 / 2,917 | ~120 / ~1,450 |
| `skills/iterate/template.md` | with `/iterate` | 96 / 806 | ~35 / ~250 |
| `skills/oversee/SKILL.md` | with `/oversee` | 173 / 2,243 | ~70 / ~850 |
| `skills/oversee/template.md` | with `/oversee` | 83 / 373 | ~25 / ~100 |
| `agents/judge.md` | judge dispatch | 114 / 922 | ~55 / ~450 |

Budget guideline: the always-loaded set stays at about 300 lines / 2,200 words, and `orchestration-discipline.md` at about 70 lines / 700 words.
The guideline is checked with `wc -l -w plugins/cdocs/rules/*.md`, not enforced by a hook.

### `orchestration-discipline.md` (full replacement)

The text below replaces everything above the `## Bash: Avoid context bloat from careless bash commands` section.
The Bash section is maintainer-authored and stays verbatim.

````markdown
# CDocs Orchestration Discipline

A session leading a loop (`/cdocs:iterate`, `propose-revise`, `full-send`, `oversee`) is the *overseer*: a router and judgment layer, not a workhorse.

## Stay thin

Delegate anything beyond a trivial few-liner (bulk reads, sweeps, builds, tests, implementation) to subagents; you hold the plan and the decisions.
Trust returned summaries: re-reading a subagent's files to double-check it is the pattern this rule exists to prevent.
Keep a workstream's deep context in a named subagent resumed with `SendMessage`, and send one-off side questions to a `fork`.

## Resume from disk, not memory

The harness notifies you only when *no* children remain live.
After any interruption, re-derive what is in flight from the devlog's dispatch/return rows and on-disk artifacts: if you believe a child is running but control has returned, it has ended, so read what it left and proceed.

## One writer per file

Never dispatch a writer against a path another live agent is writing; wait or re-scope.
Before running writers in parallel, predict the files each will touch; when unsure whether the sets overlap, serialize.
Agents share worktrees and commit concurrently: stage by explicit path, never `git add -A` or `commit -a`.

## Verification and stuck loops

Give every implementation loop a concrete verification floor at the depth the change needs (it compiles, unit tests pass, the artifact starts and does its job, components work together, it behaves against live state), with at least one picture of what failure looks like.
When a loop is stuck debugging, isolate the fault (minimal repro, bisect, a focused diagnostic `fork`) instead of paying for more full rebuilds or integration runs.

## Durable state

At each task-unit boundary write a devlog handoff (Completed / Decisions Made / Open Todos) a cold reader can act on; compaction summaries are lossy.
Between handoffs keep a short `## Scratchpoint` (now, next, open, files touched) current in any devlog you own; an agent writing into another agent's devlog keeps none.

Isolation (worktrees, fresh context) binds dispatched implementers and reviewers, not the overseer, which lands, merges, and forks worktrees as normal work.

## Chat record

Claude Code top-level session only: `chat-record` exists nowhere else, so never run it if the `Agent` tool dispatched you.
Before ending a turn that began with a human prompt, append one to three one-line bullets (`gist:`, `query:`, `read:`, `follow-up:`); the quoted heredoc keeps the body byte-exact:

```bash
chat-record note --as opus-4-8 <<'EOF'
- gist: reviewer r5 returned revise on two blockers
EOF
```

Test for a bullet: could a successor reading only the prompts and bullets tell where things stand?
The first turn you work on a devlog, add the output of `chat-record path` to its `chat_record:` frontmatter list.
**After a compaction:** run `chat-record path`, read the `## Scratchpoint` and latest handoff of the devlogs that list it, then `tail -n 80` of the record, before trusting the summary.
Commit the record by explicit path with its devlog; never edit files under `cdocs/_chat/`.
````

The text keeps the two phrases the chat-record test extras assert ("Claude Code top-level session only: `chat-record` exists nowhere else" and "**After a compaction:** run `chat-record path`").
If an implementer rewords either phrase, it updates `chat-record.test.sh` in the same commit.

### `oversee-arc.md`: split by what a single-loop overseer tacitly uses

Every section was tested against one question: does a session running `full-send`, `iterate`, or `propose-revise` rely on this because it is always in context?

| Content | Disposition |
|---|---|
| Verification-depth ladder | Generic: becomes the verification-floor line in the rule, as plain prose (no rung table, no precedence chain). |
| Troubleshooting budget | Generic: becomes the isolate-first line in the rule (no retry counter). |
| Footprint "uncertainty defaults to serialize" | Generic: becomes the parallel-writers line in "One writer per file". |
| Arc-state file, reconciled triple, arc resume, proposal sequencing, return contract, default floor for a `full` topic | Arc-only: moves to `skills/oversee/SKILL.md`. |
| Claim registry | Deleted. |
| Preamble, Cross-Target Degradation | Deleted. |

No other section carries a lesson that a single-loop overseer uses.

### `model-tiering.md` (full replacement)

```markdown
# CDocs Model Tiering

Advisory default model tiers for dispatched work, chosen by reasoning load; a consumer's own model policy always wins.

- **Lead, overseer, and judgment (opus-class):** orchestration, review, and the `judge`, whose job is spotting meta-patterns such as a stuck implementer or a reviewer and implementer talking past each other. Do not downgrade these.
- **Search, explore, and research aggregation (sonnet):** find-and-summarize work the lead validates, including `bash-runner`, whose saving is the raw output kept out of the lead's context.
- **Mechanical fan-out (haiku):** work with a clear pass/fail signal against a fixed rubric, such as `nit-fix`.

A consumer with a blanket floor (for example "do not silently downgrade dispatched work") keeps it until it adds a named carve-out above it, as weftwise does with "always use sonnet for search, explore, and research aggregation".
```

The cost arithmetic and the explanation of why `triage` runs on sonnet are contributor rationale, so they are cut.

### `workflow-patterns.md` (full replacement)

```markdown
# CDocs Workflow Patterns

## Parallel investigation

When several failures look independent (different subsystems, no shared state, no shared files), investigate them with parallel agents; when they may share a root cause, debug one first.
Synthesize the agents' findings into the devlog.

## Loops and multi-phase plans

For work whose verification depends on real-world state (UI, integration, end-to-end behavior), run `/cdocs:iterate`.
For a plan with several independent, well-specified phases, dispatch per phase and keep each workstream's context in one named subagent (see `orchestration-discipline.md`).

## Before review

Pipeline: author, then `/cdocs:nit_fix` (mechanical convention fixes, so the reviewer focuses on substance), then `/cdocs:triage`, then review.
After substantive cdocs edits (a new document, a significant edit, a finished revision cycle), run `/cdocs:triage` to fix frontmatter and act on its workflow recommendations; skip it for trivial edits or mid-authoring.

## Completeness

Before completing a task, run the relevant checklist (the `/cdocs:propose` author checklist; a devlog a cold reader could resume from), check BLUF, brevity, and critical analysis, and surface every deviation and complication up front.
It is far worse to gloss over a problem and present it as a success than to acknowledge an issue.
```

Several parts are cut because they live elsewhere: the four-role restatement of `iterate`, the triage "How it works" routing (`skills/triage/SKILL.md` carries the full table), and the agent Architecture list (each agent describes itself).
The "verify via dev server" requirement is project-specific and is cut.

### `oversee` skill (arc-only material, on demand)

`skills/oversee/SKILL.md` keeps:
- its purpose,
- the TOP-LEVEL ONLY note,
- the `chain` / `full` / `resume` invocations with `--afk`, `-m`, and `-f`,
- the composition table,
- the hard-gate list (reject, unresolvable footprint conflict, choosing the `full` proposal set).

It gains these arc sections, adapted from the review's wording 3 with verification and troubleshooting removed (they are now in the rule):

```markdown
## Composition contract

Down: the proposal path, a `--verification-floor` drawn from the proposal's own Verification Methodology (for a freshly authored `full` proposal, default to "the artifact starts and does its job"), model flags unchanged, and under AFK a brief line saying to run to accept-or-escalate without pausing.
Up: the proposal's frontmatter status, its loop's final handoff, and the arc file; never the loop's raw turns.

## Arc state

Keep `.claude/oversee/<arc-id>.json` current at each proposal start, end, and escalation (shape in `./template.md`): per proposal its path, frontmatter status, arc_state (pending / in_progress / blocked / done), devlog, footprint globs, and verification floor; plus `position` and `afk`.
Add whatever fields a cold resume needs (scope, gates, notes), and keep the narrative in an arc devlog beside it with a handoff at each proposal boundary.

## Concurrency

Proposals with overlapping or unpredictable footprints run in order; disjoint ones may run in parallel under this one overseer.
Before starting a proposal, read the sibling arc files under `.claude/oversee/` for in-progress footprints that overlap it.

## Resume

Trust disk over memory: each proposal's frontmatter status, its loop's last handoff, and the arc file.
Accepted but marked in_progress: mark done and advance. Ambiguous: re-run the loop (iterate re-reviews done work cheaply). Never re-run a done proposal.
With no arc-id, resume the single non-terminal arc file, or ask (under AFK, take the most recently written one and log the choice).
```

It drops:
- the claim registry and the `claims` field,
- `skip-blocked` and `afk_policy`,
- the `.claude/oversee/pause` marker and the escalation marker files (escalations go into the arc file),
- `--max-parallel` and the interleaving explanation,
- the footprint-scout role (deriving footprints from Implementation Phases becomes one clause of the Concurrency section),
- the troubleshooting counter and `budget`,
- `required_rung` (replaced by a `verification_floor` prose field),
- the Mermaid flowchart (the numbered steps remain),
- the isolation-routing paragraph,
- the Cross-Target section.

`skills/oversee/template.md` keeps only the arc-state JSON example with the fields named above and the arc-devlog note.
The `description` and `argument-hint` frontmatter drop "claim registry", "verification-depth ladder", `=skip-blocked`, and `--max-parallel`.

### `iterate` skill, template, and `judge`

`skills/iterate/SKILL.md`:
- **Keep unchanged:** Invocation, Graphify scoping, Roles, Turns 0 through N.d, freshness disciplines, and the dispatch/return-row instruction.
- **Header:** keep the 2-3 line inline floor and delete the isolation sentence.
- **Loop protocol:** delete the Mermaid diagram, because the Decide bullets carry the same logic plus "Reject pre-empts judge".
- **Decide:** delete the Accept branch's isolation-routing paragraph.
- **Checkpoint:** one line, "write the handoff per the rule's Durable state; keep the Scratchpoint current between handoffs".
- **Termination:** delete the `pause` and soft-thinness paragraphs.
- **Injection points:** replace the section with the review's wording 4:

  ```markdown
  ## Steering

  A human message that arrives while a subagent is in flight is queued, never injected: fold it into the next dispatch.
  Note each directive in the devlog's `## Steering Log` (free text: when, for whom, what, where applied) as soon as you see it, so a resumed overseer can pick up any not yet applied.
  ```
- **On-Resume Reconciliation:** one line pointing at the rule's "Resume from disk, not memory", plus "re-queue any Steering Log directive not yet applied".
- **Iteration Log:** delete the thinness paragraph.
  Keep the `review_proof` values at one line each, with the one real lesson: `confirmed` needs evidence this round's reviewer produced.
- **Sandboxed-runtime trust posture:** reduce to a pointer to `reviewer.md`.

`skills/iterate/template.md`:
- Scratchpoint fields become `as_of`, `now`, `next`, `open`, `files`.
- Delete the Iteration Log `inline_work` column and the Judge Log `overseer_thinness` column.
- Keep the other column names, since `triage` keys on `review_verdict` and `verdict`.
- The Steering Log becomes a free-text bullet list under its heading.
- Replace the Column Semantics prose with one example row per table.

`agents/judge.md`:
- Delete workflow steps 4 and 7, the "Overseer thinness" section, the inline-work sentences under `escalate`, and the stale startup NOTE.
- Replace the "Return EXACTLY" block with the review's wording 5: return a verdict, the trigger, a short rationale (or a `cdocs/devlogs/_judge/` path), and a Judge Log row matching the template's columns.
  If the log or commits show the overseer doing the work itself while progress stalls, say so and weigh it.

### Cross-Target deletions

Deleted outright, with no relocation:
- `model-tiering.md` `## Cross-Target Degradation`: removed by the full replacement above.
- `oversee-arc.md` `## Cross-Target Degradation`: removed by the file deletion.
- `skills/oversee/SKILL.md` `## Cross-Target Degradation`.
- `skills/init/SKILL.md` step 6 `NOTE(claude-opus-4-6/cross-target-rules)`.
- The fallback NOTE in each of `agents/implementer.md`, `proposer.md`, `nit-fix.md`, `reviewer.md`, `judge.md`, and `triage.md`.
  The NOTE claims the rule content arrives "via the SessionStart hook injection", which is no longer true, because the hook only nudges.
  It is replaced by one plain sentence: "If neither path resolves, use the rule content already in your context."

Init steps 5 (OpenCode copy) and 6 (`AGENTS.md` inline) are delivery mechanics, not guidance, so they stay; see Open Questions.

### Inbound references to update

Dropping "Pillar N" removes every numbered cross-reference.
Point each one at the new descriptive heading, or delete it where a skill only restated the rule:
- `rules/frontmatter-spec.md` (`chat_record`): "Pillar 2 Resumption" becomes `orchestration-discipline.md` "Chat record".
- `skills/devlog/SKILL.md` (lines 31 and 42) and `skills/devlog/template.md`: update the pointers, and use the same five Scratchpoint fields as the iterate template.
- `skills/implement/SKILL.md`: update the thin-lead and Scratchpoint pointers, and cut the isolation restatement to one clause.
- `skills/propose/SKILL.md` (author checklist): update the pointer.
- `skills/full-send/SKILL.md`: update the Scratchpoint pointer, and replace the liveness restatement with a pointer.
- `skills/propose-revise/SKILL.md`: update the Scratchpoint pointer.
- `agents/reviewer.md`: cut the isolation cross-reference and keep the constraints.
- `rules/workflow-patterns.md`: covered by the full replacement.
- `plugins/cdocs/README.md`:
  - Rules list: drop `oversee-arc.md` and re-describe `orchestration-discipline.md`.
  - Line 41: update the `oversee` row.
  - Line 131: update the "Pillar 2" pointer.
  - "Rules Integration": add two sentences that hold the deleted rationale.
    One says loop skills keep a 2-3 line inline floor because an un-init'd install loads no rule text.
    The other says `/cdocs:init` writes unscoped rules because Claude Code re-injects unscoped rules and root `CLAUDE.md` after compaction, while path-scoped rules may not be re-injected.
- `plugins/cdocs/AGENTS.md`: drop `@rules/oversee-arc.md` and its heading, and update the `oversee` line.
- `skills/init/SKILL.md`:
  - Step 3: "must carry every rule file in full".
  - Step 5: delete files in `.opencode/rules/cdocs/` that have no source rule.
  - Step 6: drop the Overseer Arc entry.
- `plugins/cdocs/scripts/postinstall.js` `copyRules`: clear the namespaced destination before copying, so a removed rule does not linger.

The root `CLAUDE.md` is maintainer-owned.
The proposed edit is below, and it lands only with maintainer approval:

```markdown
- **Orchestration discipline** (stay thin, resume from disk, one writer per file, verification floor, durable state, chat record): `@plugins/cdocs/rules/orchestration-discipline.md`
```

The edit replaces the existing Orchestration line and deletes the "Overseer arc" line, which `@`-imports the deleted file.
In "Cross-Target Rules Architecture", add one sentence after item 1: "Rule files carry Claude Code guidance only; target-specific guidance is tracked in `<follow-up RFP path>`."

### Follow-up RFP

File it with `/cdocs:rfp`: "Target-specific guidance without bloating always-loaded context".
Scope:
- which runtime differences actually need guidance (for example, arcs run sequentially without `fork` or `SendMessage`, and OpenCode model mapping),
- build-time injection by `build-opencode.ts` versus per-target materialization in init steps 5 and 6,
- whether `AGENTS.md` inlining should carry the full rule set at all.

## Important Design Decisions

- **Compress before relocating.** Relocating uncompressed text moves the bulk without reducing it.
  After compression, chat record, resumption, and the Scratchpoint are a few lines, small enough to stay in the one orchestration rule.
  That keeps the file count down, and with it the init surfaces that need registering.
- **No new rule files and no shared reference file.** Once the maintainer's tacit-use split was applied, everything left in `oversee-arc.md` was arc-only, and `/oversee` already loads its own skill on demand.
- **Delete enforcement machinery instead of softening it.** The thinness column is a self-report, so the judge "backstop" is no stronger than the self-check.
  The claim registry was never written.
  The judge keeps one prose line about an overseer doing the work itself.
- **Descriptive headings, not "Pillar N".** Headings survive edits, and numbered references across many files did not.
- **Init stays all-or-nothing.** Five short files do not justify a subset selector.
  The unit test that ties init's list to `rules/` is the sync guard.
- **Keep the inline floors in the skills.** A 2-3 line floor in each loop skill is what an un-init'd install has.
  The rationale for keeping them moves to the README, and the floors stay.

## Edge Cases

- **Consumer projects with materialized rules.** The rules hash changes, so the freshness hook nudges users to re-run `/cdocs:init`.
  `.claude/rules/cdocs.md` and the `AGENTS.md` block are rewritten whole.
  Without the init step-5 cleanup and the postinstall fix, `.opencode/rules/cdocs/oversee-arc.md` would linger.
- **Existing devlogs and arc files.** They carry `inline_work` and `overseer_thinness` columns, kind-based Steering Logs, or `required_rung`, `claims`, and `budget` fields.
  They are history and are not rewritten.
  `triage` keys on headers, so extra columns do no harm, and "add whatever fields" covers older arc files.
- **The loop that implements this proposal runs under the rules it edits.** Its own devlog keeps its current table shape; the implementer does not rewrite live tables in an in-flight devlog.
  The live smoke runs as a separate top-level `claude -p`, so it tests the new text and not the loop's in-window copy.
- **Dangling import in the source repo.** If `oversee-arc.md` is deleted before the `CLAUDE.md` edit is approved, root `CLAUDE.md` keeps an `@`-import of a missing file.
  Phase 2 is therefore gated on that approval (see Implementation Phases).
- **`nit-fix` reads every `rules/*.md`.** A smaller set removes nothing it enforces, because the writing conventions are unchanged.

## Test Plan

- `npm run build:cdocs` exits 0, and `build/cdocs/opencode/rules/` lists the five rule files.
- `plugins/cdocs/hooks/tests/chat-record.test.sh --unit` passes, including the check that init's rule list matches `rules/`.
- The frontmatter validator reports no missing fields for each touched cdocs file (this proposal, the devlog, the follow-up RFP):
  `echo '{"tool_input":{"file_path":"<abs path>"}}' | plugins/cdocs/hooks/cdocs-validate-frontmatter.sh` prints no warning.
- The dead-reference grep returns no hits:

  ```sh
  grep -rnE 'inline_work|overseer_thinness|signal_missing|[Cc]laim [Rr]egistry|oversee/claims|skip-blocked|max-parallel|afk_policy|full_cycle_retries|required_rung|steer-reviewer-floor|override-judge|oversee-arc|Cross-Target|cross-target-rules|SessionStart hook injection|Pillar [0-9]|Graded Enforcement|reseed' plugins/cdocs AGENTS.md CLAUDE.md
  ```

  Two hits in root `CLAUDE.md` are allowed.
  One is its user-owned "Cross-Target Rules Architecture" heading.
  The other is its "Overseer arc" line, which stays until the maintainer approves the edit.
- `wc -l -w plugins/cdocs/rules/*.md` comes within the budget guideline.

## Verification Methodology

The verification floor comes from the loop devlog.
The failure picture is a lead that does the work inline, leaves no dispatch rows, or runs `git add -A`.

1. **Static:** every check in the Test Plan.
2. **Resumption smoke:** `plugins/cdocs/hooks/tests/chat-record.test.sh --headless --only rules_check` exercises the compressed chat-record and resumption text through a real compaction.
   Its first post-compaction call should be `chat-record path`, followed by reads of the devlog and the record tail before any action.
3. **Loop smoke:** set up a throwaway sandbox following README "Sandbox testing notes":
   - `git init`,
   - the `cdocs/` directories,
   - `.claude/rules/cdocs.md` materialized the way the test's `init_rules` helper does it,
   - a `CLAUDE.md` with the import,
   - a tiny `implementation_ready` proposal (for example, "add `greet.sh`; `./greet.sh bob` prints `hello bob`").

   Then run `claude -p --plugin-dir plugins/cdocs --model sonnet --permission-mode bypassPermissions '/cdocs:iterate <proposal> --verification-floor "./greet.sh bob prints hello bob; failure: missing file, wrong output, or non-zero exit"'` with stream-json output.
   Pass when all of the following hold:
   - the transcript shows the lead dispatching an implementer and a reviewer, and the lead makes no `Write` or `Edit` to `greet.sh`,
   - the devlog has dispatch and return rows,
   - no transcript the run left (lead or subagent) contains `git add -A`, `git add .`, or `commit -a`.

   An optional baseline run on the pre-change commit shows whether the check discriminates.

The implementer runs steps 2 and 3; the reviewer re-runs them and cites the transcript paths.

## Implementation Phases

Run one commit per logical unit, staging with `git add <explicit paths>`.
Each phase leaves the tree buildable, and the unit suite passes after every phase.

**Do not change:**
- the Bash section of `orchestration-discipline.md`,
- `writing-conventions.md`, and `frontmatter-spec.md` beyond its one pointer,
- the `iterate` Graphify section,
- `bin/chat-record`, the hooks, `inject-rules.ts`, and `build-opencode.ts`,
- the `## Iteration Log` and `## Judge Log` headings and the `review_verdict` and `verdict` columns,
- historical devlogs, reviews, and `.claude/oversee/*.json`.

### Phase 1: Orchestration rule

1. Replace `orchestration-discipline.md` above the Bash section with the wording above.
2. Update every inbound pointer listed under "Inbound references to update" that targets this rule.
   This covers frontmatter-spec, devlog, implement, propose, full-send, propose-revise, reviewer, and README line 131.
   In the same pass, cut the isolation and liveness restatements in those files.
3. Add the two rationale sentences to README "Rules Integration".

Check: the unit suite passes, and `grep -rn 'Pillar [0-9]' plugins/cdocs` returns no hits outside the files later phases rewrite.
Those files are `oversee-arc.md`, `workflow-patterns.md`, and the `iterate` and `oversee` skills.

### Phase 2: Fold `oversee-arc.md` into `oversee`; delete the claim registry

Gate: surface the root `CLAUDE.md` edit to the maintainer (the overseer asks) before deleting the rule.

1. Rewrite `skills/oversee/SKILL.md` and `template.md` per the oversee spec above.
2. Delete `rules/oversee-arc.md`.
3. Update init step 6, `plugins/cdocs/AGENTS.md`, and the README rules list and `oversee` row.
4. Apply the approved `CLAUDE.md` edit.

Check: the unit suite passes (the init list must match `rules/`), and `npm run build:cdocs` exits 0.

### Phase 3: `iterate` loop surfaces

1. Delete the thinness signal from `iterate/SKILL.md`, `iterate/template.md`, and `agents/judge.md` in one commit, so the columns and their readers leave together.
2. Make the Steering change, which is free text plus the queued-never-injected rule.
3. Apply the rest of the `iterate` compression: Mermaid, Termination, On-Resume, `review_proof`, conventions, and the template's example rows.
4. Compress the `judge` output section.

Check: the unit suite passes, and the dead-reference grep is clean for `iterate`, `judge`, and the template.

### Phase 4: Cross-Target deletions and delivery fixes

1. Delete the Cross-Target blocks and the six agent NOTEs listed above.
2. Make the init step 3 and step 5 edits, and the `postinstall.js` cleanup.

Check: `npm run build:cdocs` exits 0, and a scratch run of `postinstall.js` against a directory holding a stale rule file removes that file.

### Phase 5: Compress `model-tiering.md` and `workflow-patterns.md`

Replace both files with the wording above, then update any pointer to their removed sections (`implement` line 57 cites `workflow-patterns.md` generally and stays valid).
Check: the budget `wc` is within the guideline.

### Phase 6: Follow-up RFP and devlog-splitting wording

1. File the follow-up RFP, and put its path into the `CLAUDE.md` sentence if that edit was approved.
2. Optionally, add minimal wording to `skills/devlog/SKILL.md` "Splitting a devlog" from the loop devlog's friction notes.
   Keep it to four clauses:
   - a single oversized closed concern may be cut at a natural round or phase boundary,
   - chunk frontmatter fields not otherwise stated copy the root's,
   - reword relative phrases ("this devlog", "the table above") in moved text,
   - when every row of a live table moves, leave a one-line summary (for example, the verdict sequence) beside the pointer.

### Phase 7: Verification

Run the Verification Methodology in full and record the evidence in the devlog's Verification section.

## Open Questions

- **Init steps 5 and 6.** Proposed: the OpenCode copy and the `AGENTS.md` inline stay as delivery mechanics, and only guidance is deleted.
  The alternative is to delete them too and fold them into the follow-up RFP.
  Maintainer: confirm.
- **Scope beyond the review.** Phase 5 compresses `model-tiering.md` and `workflow-patterns.md` by the same observed-failure test, although the review covered only the overseer rules.
  It is independent and can be dropped.
- **Root `CLAUDE.md` edit.** The text proposed above needs maintainer approval, and it gates Phase 2.

> NOTE(@claude-opus-5-5/cdocs/rules-context-decomposition): The RFP's original questions resolve as follows.
> Sequencing: the chat-record proposal is `implementation_accepted`, so this proceeds now, and the post-compaction resumption re-test follows it.
> Salience: this proposal makes no claim that a smaller file improves post-compaction behavior; the `rules_check` run gives one data point, and the resumption RFP owns the question.
> Chat record adjacency: it stays in `orchestration-discipline.md` beside Durable state, so no separate rule is needed.
