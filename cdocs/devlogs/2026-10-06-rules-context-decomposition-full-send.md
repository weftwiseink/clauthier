---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T09:50:00-07:00
task_list: cdocs/rules-context-decomposition
type: devlog
state: live
status: wip
tags: [rules, architecture, orchestration_discipline, init, full_send]
---

# Rules Context Decomposition: Full Send

> BLUF(opus-5-5/cdocs/rules-context-decomposition): Full-send loop (arc p2 of [the arc devlog](2026-10-05-oversee-haiku-bash-wrapper.md)) taking [the RFP](../proposals/2026-10-05-rules-context-decomposition-rfp.md) through propose-revise then iterate: compress the overseer rules, decompose the always-loaded rules context, delete non-Claude-Code blocks, and file the reintroduction RFP.

## Brief

Scope:
1. Compress the overseer rules per [the simplification review](../reviews/2026-10-06-review-of-overseer-rules-simplification.md) and the maintainer's 2026-10-06 steering (arc devlog "Steering (2026-10-06)"): `oversee-arc.md` guidance moves skill-side, loaded on demand by the oversight skills; delete the thinness signal; delete the claim registry; Steering Log becomes free text plus "a message arriving mid-dispatch is queued, never injected".
2. Decompose the rules context: compress first, then decide layout.
3. Delete non-Claude-Code (cross-target/OpenCode) blocks from rules, skills, agents; file a follow-up RFP on reintroducing target-specific guidance without bloating context.

Principles: lean on agent intuition, fewer formalisms; keep rules that encode an observed failure; sizes in lines/words.
Verification floor: after the change, `npm run build:cdocs` exits 0; the frontmatter validator and `plugins/cdocs/hooks/tests/chat-record.test.sh --unit` pass; a grep shows no remaining references to deleted constructs (thinness columns, claim registry, `oversee-arc.md` as a rule, Cross-Target sections); and a live smoke run (`claude -p --plugin-dir plugins/cdocs --model sonnet`) of a small `/cdocs:iterate` or propose-revise turn shows the compressed rules still produce delegation, a dispatch/return row, and explicit-path staging. Failure picture: a lead that does the work inline, leaves no dispatch rows, or `git add -A`s.

### Optional input: devlog-splitting friction (first real split, 2026-10-06)

Address only with minimal wording, if at all:
- A terminal loop's Iteration Log is all "finished rows", so the root's tables empty out and lose the at-a-glance verdict history.
- A single closed concern over the ~1,500-word trigger has no guidance (the splitter cut at a natural round boundary).
- Chunk frontmatter source (`first_authored`, `state`, `tags`) is unstated; the splitter copied the root's.
- Moved text like "this devlog" / "tables above" can read wrong after a move; inbound references from other docs are not mentioned.

## Scratchpoint

- as_of: 2026-10-06T09:50
- now: iterate impl-1, Phases 1-5
- open: none
- next: implementation review r1
- files: this devlog, the RFP

## Iteration Log

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | inline_work | notes |
|---|---|---|---|---|---|---|---|
| 1 (propose) | prop-1 (cdocs:proposer) | rev-1 (cdocs:reviewer) | revise | n/a | cdocs/reviews/2026-10-06-review-of-rules-context-decomposition-r1.md | no | 4 blocking: Phase 2 gate ambiguity (moot: maintainer approved), split-check clause dropped silently, smoke doesn't prove explicit-path staging, Phase 1 check vs init Pillar 2 line; 7 non-blocking; overseer defaults: keep split clause, merge Phases 4-6 |
| 2 (propose) | prop-1 (warm) | rev-2 (cdocs:reviewer) | accept | n/a | cdocs/reviews/2026-10-06-review-of-rules-context-decomposition-r2.md | no | proposal accepted; 3 nits folded into implementation (README Pillar 2 line in Phase 1, judge NOTE once in Phase 3, Scratchpoint `as_of`) |

## Dispatch/Return Events

| event | agent_handle | target_files | at | notes |
|---|---|---|---|---|
| dispatch | prop-1 (cdocs:proposer) | cdocs/proposals/2026-10-05-rules-context-decomposition-rfp.md | 2026-10-06T09:51 | elaborate RFP in place |
| return | prop-1 | same | 2026-10-06T10:10 | `1d0734f` review_ready; oversee-arc deleted (3 lessons to orchestration rule, arc-only to oversee skill); always-loaded ~797/8,054 -> ~296/2,120 lines/words; 7 phases; 3 maintainer questions (init steps 5/6, Phase 5 scope, CLAUDE.md edit) |
| dispatch | rev-1 (cdocs:reviewer) | cdocs/reviews/2026-10-06-review-of-rules-context-decomposition-r1.md | 2026-10-06T10:11 | proposal review r1 |
| return | rev-1 | same | 2026-10-06T10:20 | `bb26381` revise |
| dispatch | prop-1 (warm) | cdocs/proposals/2026-10-05-rules-context-decomposition-rfp.md | 2026-10-06T10:21 | revision r1 + maintainer answers |
| return | prop-1 | same | 2026-10-06T10:24 | `3f60b53` review_ready; all r1 items addressed; phases 4-6 merged (5 phases) |
| dispatch | rev-2 (cdocs:reviewer) | cdocs/reviews/2026-10-06-review-of-rules-context-decomposition-r2.md | 2026-10-06T10:25 | proposal review r2 |
| return | rev-2 | same | 2026-10-06T10:29 | `02a3db3` accept |
| dispatch | impl-1 (cdocs:implementer) | plugins/cdocs/rules/**, plugins/cdocs/skills/**, plugins/cdocs/agents/**, plugins/cdocs/scripts/postinstall.js, plugins/cdocs/README.md, plugins/cdocs/AGENTS.md, CLAUDE.md (approved edit only), new follow-up RFP, this devlog (notes) | 2026-10-06T10:30 | iterate: Phases 1-5 |

## Steering Log

| at | kind | target | content | applied_at_iteration |
|---|---|---|---|---|
| 2026-10-06T09:45 | steer-implementer | prop-1 | Maintainer answers on the simplification review (see Brief scope 1). | 1 |
| 2026-10-06T09:58 | steer-implementer | prop-1 | Maintainer: oversee-arc split by tacit use, not references. Generic lessons (verification floor depth, isolate fault before costly full-cycle retries, serialize when overlap unsure) compress into the always-loaded orchestration rule; arc-only material goes skill-side on demand. | 1 |
| 2026-10-06T10:14 | steer-implementer | prop-1 r1 revision | Maintainer: root CLAUDE.md edit approved as drafted (Phase 2 ungated); init steps 5-6 kept with stale-file cleanup fix, future left to the follow-up RFP; Phase 5 (model-tiering + workflow-patterns compression) included. | 1 |

## Implementation Notes (impl-1)

> BLUF(opus-5-5/cdocs/rules-context-decomposition): All five phases landed in 16 commits (`209ec08..a57c78e`); the always-loaded rules go from 797 lines / 8,054 words to 297 / 2,145, and every static check passes.
> The loop smoke passes on all three criteria.
> The `rules_check` resumption smoke fails 3 of 5 assertions, but it fails identically on the pre-change tree (0 of 6 runs pass across haiku and sonnet, baseline and new), so the failure predates this change and is not a regression.

### Commits

| commit | phase | unit |
|---|---|---|
| `209ec08` | 1 | orchestration rule rewrite plus every inbound "Pillar N" pointer (frontmatter-spec, devlog skill and template, implement, propose, full-send, propose-revise, reviewer, init step 3) |
| `fd428c6` | 1 | README: orchestration Rules-list entry (r2 N1), chat-record pointer, two Rules Integration rationale sentences |
| `3ff2310` | 2 | oversee skill and template rewrite |
| `5d0abae` | 2 | delete `oversee-arc.md` + init step 6 entry + root `CLAUDE.md` edit (single commit) |
| `aa1900e` | 2 | plugin `AGENTS.md` and README oversee entries |
| `dfbf5c0` | 3 | thinness signal out of iterate, template, and judge together |
| `4fe3718` | 3 | Steering section, free-text Steering Log |
| `665bdf5` | 3 | iterate and template compression (plus triage's column-count note) |
| `54160e7` | 3 | judge output contract; judge NOTE swapped for the plain sentence (r2 N2) |
| `34ef8d3` | 4 | other five agent NOTEs and the init step 6 NOTE |
| `57d782a` | 4 | `postinstall.js` clears `.opencode/rules/cdocs/`; init step 5 stale-file cleanup |
| `12aed82` | 4 | `model-tiering.md` replacement |
| `4c1087a` | 4 | `workflow-patterns.md` replacement (plus README Rules-list entry) |
| `02a0bb3` | 4 | follow-up RFP `cdocs/proposals/2026-10-06-target-specific-guidance-rfp.md` |
| `38f51ce` | 4 | root `CLAUDE.md` Cross-Target sentence pointing at the RFP |
| `a57c78e` | 4 | optional devlog-splitting clauses (four) |

### Phase checks

- Phase 1: unit suite 95/95; `grep -rn 'Pillar [0-9]' plugins/cdocs` hits only `oversee-arc.md`, `workflow-patterns.md`, and the `iterate` and `oversee` skills.
- Phase 2: unit suite 95/95 after the single deletion commit (init list matches `rules/`); `npm run build:cdocs` exit 0, `build/cdocs/opencode/rules/` lists the five files.
- Phase 3: unit suite 95/95 after each commit; dead-reference grep over iterate SKILL, template, and `judge.md` returns nothing.
- Phase 4: build exit 0; `wc -l -w plugins/cdocs/rules/*.md` = 297 / 2,145 (orchestration 64 / 683, workflow-patterns 21 / 191, model-tiering 9 / 136, writing-conventions 93 / 560, frontmatter-spec 110 / 575); the scratch postinstall run removed a planted `oversee-arc.md` (see Phase 5).

### Phase 5 verification

- `npm run build:cdocs`: exit 0; five rule files in the build output.
- Unit suite: `chat-record tests: 95 passed, 0 failed`.
- Validator: silent for the proposal, this devlog, and the new RFP.
- Dead-reference grep (Test Plan pattern over `plugins/cdocs CLAUDE.md`): one hit, `CLAUDE.md:54:### Cross-Target Rules Architecture`, the allowed one.
  A wider sweep (`Isolation-aware`, `Pillar`, `since_handoff`, `Injection points`, `durable specialist`, `Column Semantics`, `Commit protocol`, `escalations/`, `oversee/pause`, `verification-depth`) is also empty.
- Postinstall: the source-tree script cannot run directly (root `package.json` sets `"type": "module"` and the script uses `require`), so the check ran the built copy: `INIT_CWD=<scratch> node build/cdocs/opencode/scripts/postinstall.js` against a directory holding `.opencode/rules/cdocs/oversee-arc.md`.
  Before: `oversee-arc.md`; after: the five current rule files only.
- Resumption smoke (`chat-record.test.sh --headless --only rules_check`): `2 passed, 3 failed` (compaction happened, no additionalContext; missing `chat-record path` first, devlog read, record tail read).
  Kept sandbox: `/tmp/chat-record-test.JcgE0u`.
  First post-compaction calls go straight to the task (`Edit greeter.py`, `Edit` devlog, tests, commit, `chat-record note`).
  Baseline on `bc499de` (plugin tree via `git archive`): haiku 2 runs and sonnet 1 run fail the same three assertions; the new text with sonnet (`/tmp/chat-record-test.S2sxPO`) and a second haiku run also fail them.
  So 0 of 6 runs follow the post-compaction steps under either wording; the compressed text does not change the outcome, and the gap belongs to the post-compaction resumption RFP.
- Loop smoke (`claude -p --plugin-dir <abs plugins/cdocs> --model sonnet --permission-mode bypassPermissions '/cdocs:iterate ... --verification-floor ...'`, stream-json, sandboxed `CLAUDE_CONFIG_DIR`, git identity set, rules materialized with `init_rules`): exit 0, 7 turns, 65 s, Accept in round 1.
  - Delegation: the lead's tool calls are 4 `Bash` and 2 `Agent` (`cdocs:implementer`, `cdocs:reviewer`). It never created, ran, edited, or staged `greet.sh`; the implementer wrote and committed it (`9b26975`), the reviewer re-ran the floor.
    Literal caveat: the lead's devlog-writing heredocs contain the string `greet.sh` (a `target_files` cell and Scratchpoint `files:`), so a raw substring grep over lead calls would flag them.
  - Dispatch/return rows: the sandbox devlog has 4 rows (impl-1 dispatch and return, rev-1 dispatch and return).
    The dispatch row for impl-1 was written before dispatch; the other three were written together at the end, so "as it happens" held only for the first row.
  - Staging: explicit paths in every transcript (implementer `git add greet.sh`, reviewer `git add cdocs/reviews/2026-10-06-review-of-greet-r1.md`, lead `git add cdocs/devlogs/... cdocs/proposals/...`); no tool call in the lead or either subagent transcript uses `git add -A`, `git add .`, or `commit -a` (the only matches are the rule text itself in context).
  - Evidence: `scratchpad/loop_smoke/lead.jsonl` and `scratchpad/loop_smoke/cfg/projects/*/b3c16c5f-*/subagents/agent-{acf148be330fcbd50,a6bb2a7e9d9da5704}.jsonl`, sandbox repo `scratchpad/loop_smoke/proj` (scratchpad = `/tmp/claude-1000/-var-home-mjr-code-weft-clauthier-main/e3afd4a9-4352-482d-ad1a-444fa834254a/scratchpad`); driver script `scratchpad/loop_smoke.sh`.
  - Optional baseline on `bc499de` (`scratchpad/loop_smoke_base`): also passes (2 `Agent` dispatches, 4 rows, explicit staging, though its reviewer staged the broad `git add cdocs`).
    The smoke shows no regression; it does not discriminate between the two wordings on a task this small.

### Judgment calls

- `oversee` gains a short "Hard gates" section: the proposal keeps the hard-gate list but deletes the escalation marker files, so a hard gate now marks the proposal `blocked`, records the escalation in the arc file, and surfaces it.
  `--afk` keeps a one-line meaning (soft gates take the logged default; hard gates still stop).
- `oversee/template.md` keeps `arc_id`, `afk`, `position`, and per-proposal `path`, `status`, `arc_state`, `devlog`, `footprint`, `verification_floor`; `specialist`, `worktree`, `mode`, `created_at`, `claims`, and `budget` are gone, covered by "add whatever fields a cold resume needs".
- Iterate template: the copied `## Steering Log` heading is empty; the example bullet sits with the example rows below a `---` separator marked "do not copy", so no example row lands in a live devlog.
- `reviewer.md` drops the whole isolation sentence; its boundaries paragraph already says the constraints keep it from clobbering the workstream.
- `implement` keeps one clause: "a top-level invocation is never isolation-bound".
- `devlog` skill Scratchpoint bullet now names the five fields inline and points at "Durable state"; the old `files:` line shape (`<path> (r|w|rw): why`) is not carried anywhere, by design (fewer formalisms).
- `triage.md`'s "the current `template.md` carries eight" became "seven" in `665bdf5`, since the thinness column removal made it false.
- README's `workflow-patterns.md` Rules-list entry is re-described to match the new sections; root `CLAUDE.md`'s "Workflow patterns" description is left as is, since the approved `CLAUDE.md` edit named only the Orchestration and Overseer arc lines plus the RFP sentence.
- `fix(cdocs/opencode)` was chosen for the postinstall and init step 5 cleanup; both `oversee-arc` deletion and thinness removal carry `!` and a BREAKING CHANGE footer.

### Deviations and gaps

- Size targets missed for the secondary files (guidelines, not budgets): `iterate/SKILL.md` 157 / 1,644 (target ~120 / ~1,450; the unchanged Graphify section is about 20 lines / 400 words), `judge.md` 75 / 600 (~55 / ~450), `oversee/SKILL.md` 71 / 719 (~70 / ~850, under).
  The always-loaded set meets its budget.
- Resumption smoke assertions fail on both trees (above); not fixed here because the proposal makes no salience claim and the resumption RFP owns it.
- The source `postinstall.js` cannot be executed in-repo because of the root ESM `package.json`; it runs correctly as the published CJS package. Pre-existing, unchanged.
- The loop smoke reviewer ran `git commit` although `reviewer.md` forbids mutating VCS commands; the same constraint text exists on both trees, so this is an existing compliance gap, not caused here.
