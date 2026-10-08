---
review_of: plugins/cdocs/rules/orchestration-discipline.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T09:07:56-07:00
task_list: cdocs/rules-context-decomposition
type: review
state: archived
status: done
tags: [fresh_agent, simplification, formalism_reduction, orchestration_discipline, oversee, context_budget, rules]
---

# Review: Overseer Rules Simplification

> BLUF(@claude-opus-5-5/cdocs/rules-context-decomposition): The two always-loaded overseer rules (403 lines / 5,039 words, excluding cross-target sections) can shrink to about 50 lines / 700 words without losing an empirically motivated lesson.
> The real goals fit in five short paragraphs: stay thin, resume from disk, one writer per file, write durable state, and the overseer is not isolation-bound.
> Most of the bulk is design rationale, schemas the model already extends on its own, and enforcement machinery that the logs show was almost never used: claim registry (0 claims ever written), thinness signal (2 judge rows ever), five-kind steering taxonomy (only `steer-implementer` ever used), troubleshooting-budget counter (never incremented).
> The biggest single cut: fold `oversee-arc.md` into the `oversee` skill and delete it as a rule; only that skill reads it.
> Verdict: **Revise**.

> NOTE(@claude-opus-5-5/cdocs/rules-context-decomposition): Scope is the primary pair (`orchestration-discipline.md`, `oversee-arc.md`) plus their restatements in `iterate`, `oversee`, `propose-revise`, `full-send`, both templates, and `agents/judge.md`.
> The rule files carry no cdocs frontmatter, so `last_reviewed` was not written (adding frontmatter would modify a rule file, which this review is read-only on).

## Summary Assessment

These files define how a lead session runs implement/review loops and multi-proposal arcs.
Calibrating against the maintainer's `bash-runner` rewrite ([6821b43](https://github.com/weftwiseink/clauthier/commit/6821b43481d0ba1bbb504f0cadf7dc70f3c5adae), 147 lines of capture template, excerpt rules, and status vocabulary down to a short "run, read, summarize" workflow), the overseer rules have the same shape: a handful of real lessons wrapped in schemas, vocabularies, numbered protocols, defensive NOTEs, and cross-references that restate each other.
The lessons themselves are sound and several come from real incidents, so they should stay.
Most of the rest is either something a capable lead model does without being told, or formal machinery that the devlogs show was almost never used.

## Method and Evidence

- Measured per-section line and word counts across all ten files (in-scope total: 1,164 lines / 13,188 words).
- Checked usage across `cdocs/devlogs/` and `.claude/oversee/`:
  - `.claude/oversee/claims/` and `.claude/oversee/escalations/` are both empty; the one escalation lived in the arc JSON's ad hoc `escalation` field.
  - The live arc file `.claude/oversee/2026-10-05-haiku-bash-wrapper.json` carries 9 fields the normative schema does not define (`note`, `scope`, `gate_before_start`, `prestep`, `post_accept_revision`, `composition`, `followups`, `escalation`, `escalation_resolved`). These are the fields that actually carried resume context. `full_cycle_retries` is 0 everywhere, and `specialist` is null everywhere.
  - Judge Log rows with an `overseer_thinness` value: 2 in all devlogs (one `bloat_detected` with `continue`). `inline_work: yes` rows: 3. `cdocs/devlogs/_judge/`: no files.
  - Steering Log data rows: about 10, every one `steer-implementer`. `override-judge` appears once in prose; `pause`, `resume`, and `steer-reviewer-floor` never appear as rows.
  - `skip-blocked`, footprint scout, `.claude/oversee/pause`: never used.
- Confirmed the incidents behind the load-bearing rules (see "Load-Bearing: Keep").

## Goals per File

### `orchestration-discipline.md` (270 lines / 3,531 words)

Without it, a capable lead model would:

1. **Do the work itself.** Read files, run tests, and edit inline, burning the lead's context until compaction loses the loop. This is the core goal. Models do this by default, so the rule earns its place.
2. **Trust its in-window belief after a resume.** It waits on a child that already ended, because the harness only notifies when *no* children are live. This has an incident behind it.
3. **Dispatch two writers at one file**, or `git add -A` other agents' work in a shared worktree. Both have incidents behind them.
4. **Skip writing durable state.** It relies on the compaction summary, so a resume starts from a lossy picture.
5. **Treat itself as worktree-isolated**, refusing to merge or land. This only happened because clauthier's own earlier text over-applied isolation (`cdocs/devlogs/2026-09-10-worktree-isolation-scope-to-dispatched-agents.md`). It is a one-sentence corrective, not a 15-line principle.

Everything else in the file is rationale for contributors, enforcement scaffolding, or format detail.

### `oversee-arc.md` (141 lines / 1,623 words; 133 / 1,508 excluding Cross-Target)

Without it, an arc overseer would:

1. **Keep no resumable record of which proposals are done**, and re-run or double-implement work after a session loss.
2. **Run two proposals that touch the same files in parallel.**
3. **Hand `iterate` a vague verification bar.**
4. **Burn repeated full rebuilds** instead of isolating a fault.

All four fit in about 15 lines.
None of them needs to be always loaded: the file opens by calling itself "the shared vocabulary any agent may cite without running `/oversee`", but the only consumer is `skills/oversee/` (verified by grep; the other hits are the init/AGENTS.md materialization and one cross-reference from `orchestration-discipline.md`).

## Section-by-Section Findings

Legend: **keep**, **compress**, **cut**. Counts are the current section size.

### `orchestration-discipline.md`

| Section | Size | Call | Reason |
|---|---|---|---|
| Preamble (overseer is "not an `agents/` entry because...") | 5L | compress | The design rationale for why the overseer is not an agent is for contributors. One sentence naming when the discipline applies is enough. |
| Pillar 1: Core responsibilities | 13L/83W | compress | The four-item "does NOT" list restates "delegate bulk work". |
| Dispatch-by-default | 9L/114W | compress | The numeric thresholds (">1KB or >20 lines", ">10 lines") are false precision that a model will not measure. The "a skill may be stricter, never looser" sentence is governance for skill authors. Keep only "anything beyond a trivial few-liner". |
| Summary absorption | 7L/69W | keep (1 line) | This is a real non-default behavior: models like to double-check. |
| Signaling self-check | 5L/29W | cut | It restates dispatch-by-default as a question. |
| Inline Discipline Floor | 12L/145W | cut from rule | This is authoring guidance about how skills must be written, loaded into every session. Keep the floors in the skills. Move the rationale (un-init'd installs get no rule content) to a one-line NOTE in each skill or to the clauthier `CLAUDE.md`. |
| Graded Enforcement | 12L/215W | cut | This is design rationale plus a spec for an unbuilt Phase 5 hook. Nothing in it changes runtime behavior. |
| Isolation is a dispatched-agent property | 15L/306W | compress to 2L | It is a corrective for clauthier's own earlier text. The "probe tests the wrong axis" argument and the "MUST NOT be softened" NOTE defend against an edit, not against model behavior. It is restated in 5 more files (see duplication below). |
| Pillar 1b: Liveness reconciliation | 11L/149W | keep, compress to 3L | Load-bearing (incident below). |
| Pillar 1b: Single-writer ownership | 10L/122W | keep, compress to 2L | Load-bearing. The duplicate "Pillar 1b" label is itself a sign the numbering scheme no longer pays. |
| Judge-Observable Thinness Signal | 15L/192W | cut | See finding T below. |
| Pillar 2 intro + Handoff format | 18L/202W | compress to 2L | Keep the three headings as a suggestion. Cut "exactly three subsections" and "under 30 seconds" as checklist formalism. |
| Scratchpoint | 28L/318W | compress to 2L | Field list, `r/w/rw` shape, size budget, a three-case writer taxonomy, and a "not a thinness input" note are all edge-case handling. A model keeps a "now / next / open" block without a schema. |
| Chat record + Resumption + Commit protocol | 42L/645W | compress to ~7L | The `Stop` hook already enforces the note, so its block message can teach the syntax. Keep the heredoc form, the successor test, the post-compaction read order, and explicit-path staging. Cut the speaker-id derivation rules, the prefix taxonomy detail, `.gitattributes` mechanics, and the clear-versus-fork id semantics. **Coordinate:** this content is under active iteration in arc p1 (chat-record proposal), whose footprint includes `plugins/cdocs/rules/**`. |
| CLAUDE.md reseed mechanism | 17L/221W | cut from rules | This verifies why `/cdocs:init` writes an unscoped rule, which is install design. It belongs in README "Rules Integration" as one line. No runtime decision depends on it. |
| Pillar 3 (4 subsections) | 31L/446W | compress to 2L | "Resume a named specialist via `SendMessage`; fork for a side question" is the useful pointer. The "one-per-workstream bound" ("ten workstreams spawns ten specialists maximum; escalate to a parent overseer") and "file ownership by construction" restate other sections or formalize the obvious. |
| Bash | 15L/167W | keep | The maintainer already rewrote it. Fix the typo-level wording only. |

### `oversee-arc.md`

| Section | Size | Call | Reason |
|---|---|---|---|
| Preamble ("BUILDS ON ... does not restate", "two altitudes, two substrates") | 9L | cut | It is meta-commentary about the file's relationship to other files. |
| Arc-State File (normative) | 46L/372W | compress to ~5L in the skill | The live arc file shows the model extending the schema with free-form fields that are what actually carried resume context. Describe what the file must let a cold reader answer. Do not fix a schema. The "reconciled TRIPLE" logic becomes one resume sentence. |
| Claim Registry | 28L/319W | cut | Never used (`claims/` empty across both arcs). Each arc file already records `footprint` and `arc_state: in_progress`, so a second session can read sibling arc files for the same information. The registry duplicates the arc file. |
| Footprint-Overlap heuristic | 11L/172W | compress to 1L | "Overlapping or unpredictable footprints run in order; disjoint ones may run in parallel." The 4-step glob-intersection protocol is what a model does on intuition. |
| Arc-Altitude Troubleshooting Budget | 14L/222W | compress to 2L | Keep "isolate first, full-cycle second" and "steer through the dispatch brief, escalate if it keeps stalling". Cut the counter (never incremented) and the black-box argument about the judge. |
| Verification-Depth Ladder | 24L/293W | compress to 2L | The rung names are a useful shorthand. The table's "typical evidence" column, the subsumption rule, and the 3-level precedence chain (which restates `iterate`'s own floor rule) are not needed. |
| Cross-Target Degradation | 8L/115W | out of scope | Already slated for deletion. |

### Secondary files: duplication and formalism

- **D1. Isolation restated 6 times.** The principle appears in `orchestration-discipline.md`, `oversee-arc.md` (Claim Registry), `iterate/SKILL.md` (lines 15, 116, 155, 216), `oversee/SKILL.md` (line 100), `implement/SKILL.md` (line 30), and `agents/reviewer.md`. It belongs in the rule once. Skills need at most a pointer, and most need nothing, since a model does not refuse to merge unless told to.
- **D2. Liveness reconciliation restated 5 times.** Restatements: `iterate` "On-Resume Reconciliation" (10L/208W), `full-send` (one 70-word line), `oversee` Cross-Session Resume step 2, `oversee-arc` Claim Registry, and the rule itself. Keep the rule's 3 lines and one pointer line in each skill.
- **D3. Handoff and Scratchpoint pointers.** Each loop skill carries a "keep the Scratchpoint current per Pillar 2" sentence, a "handoff format defined in Pillar 2; do not restate" sentence, and an inline floor that names the handoff format anyway. One floor line is enough.
- **T. Thinness signal apparatus** (rule 15L, Graded Enforcement 12L, `iterate` 4L, template ~8L, `judge.md` ~25L; about 65 lines total). The `inline_work` flag is written by the overseer about itself, so the judge "backstop" reads a self-report and is no stronger than the self-check it claims to back up. In practice it produced 2 judge rows. Cut the column, the `overseer_thinness` field, and `signal_missing`. Replace them with one judge line: "if the log or commits show the overseer doing the work itself without progress, say so and weigh it."
- **S. `iterate` Injection points** (18L/541W, the largest section in the skill) plus Steering Log kinds and `pause`/`resume`/`override-judge` semantics. Only `steer-implementer` was ever used. Keep the one non-obvious rule (a message arriving mid-dispatch is queued, never injected) and a free-text log.
- **M. `iterate` Mermaid state diagram** (18L) duplicates the Decide bullets. Keep one.
- **P. `review_proof` vocabulary** (10L in the skill, plus template). It is used (`deferred-to-followup` in 8 devlogs), so keep the column. Compress the definitions to the one real lesson: `confirmed` needs evidence this round's reviewer produced, not a prior round's artifact.
- **C. Template column semantics** (`iterate/template.md` about 55L). Definitions like "`judge_iteration`: the iteration number *before which* the judge ran ... records N+1" specify formatting a reader does not need. Self-describing headers plus an example row suffice.
- **J. `judge.md`** "Return EXACTLY this structure" output block and the thinness section. Keep the verdicts and "assess the loop, not the work". Return verdict, rationale, and a log row without a fixed banner format.
- **A. `oversee` AFK machinery.** Cut `skip-blocked` (never used), the `.claude/oversee/pause` marker (never used), and escalation marker files (escalations went into the arc JSON). Keep the `afk` flag, the hard-gate list (reject, unresolvable conflict, choosing the `full` proposal set), and "record the escalation in the arc file and stop".
- **I. `oversee` interleaving**: the `--max-parallel 3` cap and the "concurrency is interleaved turns under ONE overseer" explanation. Interleaving was never exercised (`specialist: null` everywhere). Keep one line: footprint-disjoint proposals may run in parallel, and the per-dispatch single-writer check stays the backstop.

## Proposed Compressed Wordings (Top Candidates)

### 1. `orchestration-discipline.md` core (replaces Pillars 1, 1b, 2-handoff/Scratchpoint, 3, Isolation, Inline Floor, Graded Enforcement, Thinness: ~190L / ~2,400W -> ~22L / ~330W)

```markdown
# CDocs Orchestration Discipline

When a session leads a loop (`/cdocs:iterate`, `propose-revise`, `full-send`, `oversee`) it is the *overseer*: a router and judgment layer, not a workhorse.

## Stay thin

Delegate anything beyond a trivial few-liner (bulk reads, sweeps, builds, tests, implementation) to subagents; you hold the plan and the decisions.
Trust returned summaries: re-reading a subagent's files to double-check it is the pattern this rule exists to prevent.
Keep deep per-workstream context in a named subagent resumed via `SendMessage`; send one-off side questions to a `fork`.

## Resume from disk, not memory

The harness notifies you only when *no* children remain live.
After any interruption, re-derive what is in flight from the devlog's dispatch/return rows and on-disk artifacts: if you believe a child is running but control has returned, it has ended, so read what it left and proceed.

## One writer per file

Never dispatch a writer against a path another live agent is writing; wait or re-scope.
Agents share worktrees and commit concurrently: stage by explicit path, never `git add -A` or `commit -a`.

## Durable state

At each task-unit boundary write a devlog handoff (Completed / Decisions Made / Open Todos) a cold reader can act on; compaction summaries are lossy.
Between handoffs keep a short `## Scratchpoint` (now, next, open, files touched) current in any devlog you own.

Isolation (worktrees, freshness) binds dispatched implementers and reviewers, not the overseer, which lands, merges, and forks worktrees as normal work.
```

### 2. Chat record + Resumption + Commit protocol (42L / 645W -> ~7L / ~120W; coordinate with arc p1)

```markdown
## Chat record (Claude Code top-level session only; dispatched agents never run it)

Before ending a turn that began with a human prompt, append 1-3 one-line bullets (`gist:`, `query:`, `read:`, `follow-up:`) via `chat-record note --as <model-id> <<'EOF' ... EOF` (quoted heredoc keeps it byte-exact).
Test: could a successor reading only the prompts and bullets tell where things stand?
After a compaction, read your devlog's Scratchpoint and latest handoff, then `tail -n 80` of `chat-record path`, before trusting the summary.
Commit the record by explicit path with its devlog; never edit files under `cdocs/_chat/`.
```

### 3. `oversee-arc.md` folded into `oversee/SKILL.md` (133L / 1,508W rule + ~60L of overlapping skill sections -> ~14L / ~230W in the skill; rule deleted)

```markdown
## Arc state

Keep `.claude/oversee/<arc-id>.json` current at each proposal start, end, and escalation: per proposal its path, frontmatter status, arc_state (pending / in_progress / blocked / done), devlog, footprint globs, and required verification depth; plus `position` and `afk`.
Add whatever fields a cold resume needs (scope, gates, notes); keep the narrative in an arc devlog.

## Concurrency

Proposals with overlapping or unpredictable footprints run in order; disjoint ones may run in parallel under this one overseer.
Before starting, check sibling arc files under `.claude/oversee/` for in-progress footprints that overlap yours.

## Verification depth

Set each proposal's required depth (compile < unit < integration < smoke < live) from its frontmatter or Verification Methodology, and pass it to `iterate` as a `--verification-floor` with a failure picture.
If a loop keeps paying for full rebuilds or integration runs, steer it via the brief to isolate the fault (repro, bisect, focused fork), and escalate if it stalls.

## Resume

Trust disk over memory: proposal status, the loop's last handoff, and the arc file.
Accepted but marked in_progress: mark done and advance. Ambiguous: re-run the loop (iterate re-reviews done work cheaply). Never re-run a `done` proposal.
```

### 4. `iterate` Injection points + On-Resume + Steering Log semantics (28L / 750W + template 12L -> ~5L / ~90W)

```markdown
## Steering

A human message that arrives while a subagent is in flight is queued, never injected; fold it into the next dispatch.
Log each directive in the Steering Log (when, target, content, applied-at) the moment you notice it, so a resumed overseer can recover pending ones.
On resume, follow the rule's "Resume from disk" and re-queue unapplied Steering Log rows.
```

### 5. `judge.md` thinness and output (about 45L -> ~8L)

```markdown
Return a verdict (`continue`, `rotate-implementer`, `escalate`), a short rationale (the verdict alone is not auditable), and a Judge Log row.
If the log or commits show the overseer doing the work itself while progress stalls, say so and weigh it.
```

## Load-Bearing: Keep

These have empirical motivation or encode non-default behavior. Compress the wording, keep the lesson.

- **Liveness reconciliation.** A re-dispatched full-send orchestrator reported the same "proposer in flight" state twice after the harness had already returned control. Its orphaned child then surfaced, having written to the same file (`cdocs/devlogs/2026-09-01-oversight-proposals-and-cc-features.md`, "full-send salvage").
- **Single-writer ownership.** A report went through "three uncoordinated full rewrites", and a still-running `nit-fix` pass nearly clobbered the latest content (`cdocs/devlogs/2026-09-18-delegate-model-benchmark-deepening.md`).
- **Explicit-path staging, never `-A` / `commit -a`.** Concurrent agents commit in the same worktree. This review's own dispatch had to restate it.
- **Dispatch/Return Events rows** (15 devlogs use them). They are the substrate the liveness check reads. The `target_files` column is the cheapest single-writer check available.
- **Fresh reviewer every round, fresh judge, and a warm implementer unless rotated.**
- **Handoff at task boundaries.** Compaction is lossy, and the post-compaction resumption RFP depends on it.
- **Skill inline floors** (2-3 lines each). The un-init'd delivery gap is real. Keep the floors and cut the rule section that legislates them.
- **`confirmed` needs this round's evidence.** This guards against reviewers re-citing stale artifacts.
- **Overseer is not isolation-bound** (1 sentence). Without it, older consumer-repo text can make a lead refuse to land.
- **"Uncertainty defaults to serialize"** and **"ambiguous arc state: re-run the loop, iterate re-accepts cheaply"**. Both are non-obvious one-liners.
- **`/oversee` is top-level only** (platform fact: subagents cannot dispatch).
- **Bash section.** Already at the maintainer's target altitude.

## Overall Estimate

| Surface | Before | After (est.) |
|---|---|---|
| `orchestration-discipline.md` | 270L / 3,531W | ~50L / ~650W (core 22L + chat record 7L + bash 15L + headings) |
| `oversee-arc.md` (excl. Cross-Target) | 133L / 1,508W | 0 (folded into skill) |
| **Always-loaded rule subtotal** | **403L / 5,039W** | **~50L / ~650W (about -87%)** |
| `iterate/SKILL.md` | 217L / 2,917W | ~125L / ~1,500W (graphify section untouched) |
| `iterate/template.md` | 96L / 806W | ~35L / ~250W |
| `oversee/SKILL.md` | 173L / 2,243W | ~75L / ~900W (includes folded arc content) |
| `oversee/template.md` | 83L / 373W | ~25L / ~110W (arc JSON only) |
| `agents/judge.md` | 114L / 922W | ~55L / ~450W |
| `propose-revise` + `full-send` | 70L / 773W | ~60L / ~620W |
| **In-scope total** | **1,164L / 13,188W** | **~425L / ~4,500W (about -65%)** |

## Effect on the Rules-Context-Decomposition RFP

`cdocs/proposals/2026-10-05-rules-context-decomposition-rfp.md` plans relocation. These findings change it to compress-then-relocate:

- **Scope item 1 (devlog formats to the devlog skill).** Compress first. The Scratchpoint becomes 1-2 lines, which also resolves the RFP's caveat about an overseer refreshing it without the skill loaded: two lines can stay in the rule.
- **Scope item 3 (split candidates).** The "CLAUDE.md reseed mechanism?" question answers itself: delete it from rules and keep one README line. Chat record, Resumption, and Commit protocol shrink to about 7 lines, small enough to stay in `orchestration-discipline.md` rather than becoming a separate rule (fewer files to register at every init surface, per scope item 7). The split leaves Pillars 1, 1b, and 3, but those are themselves 3-5x over budget.
- **Scope item 4 (always-loaded vs on-demand).** `oversee-arc.md` should move to on-demand: fold it into the `oversee` skill and delete the rule. This touches init step 3 and step 6, `plugins/cdocs/AGENTS.md:23`, README line 54, and the clauthier `CLAUDE.md` rule list.
- **Scope item 6 (budget).** About 650 words for orchestration is a realistic target.
- **Scope item 8 (dead references).** Dropping "Pillar N" numbering removes 18 cross-references outside the rules that currently point at numbered pillars. Prefer descriptive headings.
- **Sequencing.** Arc p1 (chat-record) is `in_progress` with a footprint covering `plugins/cdocs/rules/**` and every loop skill, so any edit here overlaps it. The RFP's "after chat-record settles" sequencing holds, and the chat-record compression (proposal 2) should go to the p1 owner rather than be done in parallel.

## Verdict

**Revise.**
The rules encode about five real lessons, and they are good ones.
They are buried under roughly 85% supporting formalism that the usage evidence says is unused or that a capable lead model would supply on its own.
Nothing here is wrong, so this is not a reject. The simplification is large enough that the current text should not be treated as settled.

## Action Items

1. [blocking] Fold `oversee-arc.md` into `oversee/SKILL.md` per proposed wording 3. Delete the rule and its materialization entries (init, AGENTS.md, README, `CLAUDE.md`).
2. [blocking] Rewrite the `orchestration-discipline.md` core per proposed wording 1. Drop Pillar numbering in favor of descriptive headings.
3. [blocking] Cut the thinness-signal apparatus (`inline_work`, `overseer_thinness`, `signal_missing`, Graded Enforcement) from the rule, `iterate`, the template, and `judge.md`. Replace it with the one-line judge instruction in wording 5.
4. [blocking] Cut the claim registry (rule, skill, template). Second sessions read sibling arc files instead.
5. [blocking] De-duplicate isolation (D1) and liveness (D2) restatements: one statement in the rule, pointer lines at most in the skills.
6. [non-blocking] Compress `iterate` Injection points and Steering Log to wording 4, and the template column semantics to headers plus one example row.
7. [non-blocking] Replace the arc-state normative schema with a "what a cold resume must answer" description. Let the model add fields, matching observed practice.
8. [non-blocking] Drop `skip-blocked`, the pause marker, escalation marker files, `--max-parallel`, and the troubleshooting counter from `oversee`.
9. [non-blocking] Move the CLAUDE.md reseed rationale and the Inline Discipline Floor rationale out of always-loaded rules (README, or a skill NOTE).
10. [non-blocking] Hand the chat-record compression (wording 2) to the arc p1 owner rather than editing concurrently.
11. [non-blocking] Fold these compressions into the rules-context-decomposition proposal's scope, since relocating uncompressed text moves the bulk without reducing it.

## Questions for the Maintainer

1. `oversee-arc.md` disposition:
   - (a) Fold into the `oversee` skill and delete the rule (recommended).
   - (b) Keep as a ~15-line rule.
   - (c) Keep as-is minus Cross-Target.
2. Thinness signal:
   - (a) Delete `inline_work` / `overseer_thinness` entirely; the judge comments in prose if it sees bloat (recommended).
   - (b) Keep `inline_work` as an optional `notes` tag only.
   - (c) Keep the current apparatus.
3. Claim registry:
   - (a) Delete; sibling arc files carry footprints and in-progress state (recommended).
   - (b) Keep as a one-sentence optional convention.
   - (c) Keep.
4. Steering Log:
   - (a) A free-text log plus the "queued, never injected" rule (recommended).
   - (b) Keep the five `kind` values.
5. Where the compression lands:
   - (a) Inside the rules-context-decomposition proposal, after chat-record p1 settles (recommended).
   - (b) A separate simplification proposal landed first.
   - (c) A direct maintainer edit pass, as with `bash-runner`.
