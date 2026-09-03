---
review_of: cdocs/proposals/2026-09-03-overseer-arc.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-03T14:30:00-08:00
task_list: cdocs/oversee-skill
type: review
state: live
status: done
round: 1
tags: [fresh_agent, implementation_review, agent_orchestration, composition, cdocs_meta, verification]
---

# Review: `/oversee` Multi-Proposal-Arc Implementation

Reviews the IMPLEMENTATION of the accepted proposal (commits `13dd049..b2b8789` on branch `overseer-arc`), not the proposal design.

## Verdict: revision_requested

One blocking defect (a stray `</content>` closing tag at the tail of all three newly authored files) fails floor item (e). It is a trivial one-line-per-file deletion, but it ships verbatim into every `/cdocs:init` materialization target, so it must be removed before merge. Every other floor item passes and the implementation is faithful and well-written across all six phases; this is a near-miss, not a structural problem.

## Floor items

**(a) No dangling references — PASS.** Cross-checked every `arc_state` value (`pending | in_progress | blocked | done`), `afk_policy` value (`hold | skip-blocked`), ladder rung (`compile | unit | integration | smoke | live`), and invocation mode (`chain | full | resume`) the SKILL references against `oversee-arc.md`: all are defined in the rule. The only skill token absent from the rule is `--max-parallel`, which is a tuning flag (invocation-parsing / control-flow, correctly the skill's domain), not an arc-state field, ladder rung, or mode; the rule carries the underlying one-specialist-per-workstream bound it tunes. Nothing the skill references is undefined; the rule's full ladder taxonomy is consumed by pointer (by design — it is the shared vocabulary), not silently orphaned.

**(b) No reach-in / arc-altitude only — PASS.** `oversee-arc.md:99-106` scopes troubleshooting to "the ARC altitude ONLY," tracks retry count in the arc-state file (`full_cycle_retries` / `budget.full_cycle_retries_max`), escalates over-budget proposals as `blocked`, and carries an explicit non-reach-in guard: "It does NOT reach into the composed loop's judge ... injecting into it would break the black box or require a new `iterate` parameter, both forbidden." Any judge-directed signal travels "only through the down-channel it already controls, the dispatch brief and `--verification-floor` prose." The autonomy signal is likewise brief prose, not a flag (`SKILL.md:53`: "conveyed as dispatch-BRIEF PROSE, not a flag ... adding one would modify a composed skill (forbidden)"). No new composed-skill flags are introduced.

**(c) Spanning constraint — PASS.** `git diff --name-only main...overseer-arc` shows only: `CLAUDE.md`, `plugins/cdocs/AGENTS.md`, `plugins/cdocs/README.md`, `plugins/cdocs/rules/oversee-arc.md`, `plugins/cdocs/skills/{init,oversee}/...`, and one devlog. NONE of `orchestration-discipline.md`, `model-tiering.md`, `skills/iterate/**`, `skills/full-send/**`, `skills/propose-revise/**` is modified. `oversee-arc.md` references the pillars by link (`./orchestration-discipline.md` Pillar 1b/2/3) rather than restating them; new content is confined to the arc-level delta (arc-state schema, claim registry extending Pillar 1b, footprint heuristic, arc-altitude budget, verification ladder, cross-target degradation).

**(d) Registration — PASS.** The `oversee` skill exists at `plugins/cdocs/skills/oversee/SKILL.md` with `name: oversee` frontmatter, and `oversee-arc` is registered everywhere existing rules/skills are, matching the `orchestration-discipline`/`model-tiering` precedent exactly: README skill table + Rules list; `AGENTS.md` `## Overseer Arc` / `@rules/oversee-arc.md` import + the `/cdocs:oversee` agent-listing bullet; `CLAUDE.md` rules bullet + the skills-glob list (`{...,iterate,oversee}`); and the `/cdocs:init` AGENTS.md inline-rules template (`## CDocs Overseer Arc` + "[Full content of oversee-arc.md, frontmatter stripped]"), slotted in the same model-tiering→frontmatter position as the materialized AGENTS.md.

**(e) Well-formed — FAIL (blocking item 1).** No em-dashes in any newly authored content (rule, skill, template) or in the README/AGENTS/CLAUDE/init additions or the devlog. All JSONC skeletons parse after string-aware comment stripping: both blocks in `oversee-arc.md` and all three in `template.md` (arc-state, claim, escalation) validate as JSON. History-agnostic framing is clean. The single failure: every one of the three authored files ends with a stray literal `</content>` line (no opening `<content>` tag) — `oversee-arc.md:141`, `SKILL.md:171`, `template.md:84` — an authoring-wrapper leak. It is malformed trailing content that `/cdocs:init` will copy verbatim into `.claude/rules/cdocs.md`, `.opencode/rules/cdocs/*`, and the AGENTS.md inline block.

## Phase faithfulness

All six phases land and match the proposal's per-phase deliverables:

- **Phase 1 (rule + schema):** `oversee-arc.md` carries the normative arc-state schema, claim-registry format/protocol, footprint-overlap heuristic, arc-altitude troubleshooting budget, and verification ladder; `template.md` holds the copyable arc-state/claim/escalation/pause/arc-devlog skeletons. Readable standalone.
- **Phase 2 (sequential chain):** invocation parsing (`chain`/`full`/`resume`), arc-state lifecycle (create + transition-write-before-compact), per-proposal composition mapping (`implementation_ready`→`iterate`, stub→`full-send`, `full`→scope-then-chain, decided per element at its turn), frontmatter-`status` progression, and the Pillar 2 boundary checkpoint.
- **Phase 3 (resume):** reconstruct `position`/`arc_state`, Pillar 1b liveness reconciliation at arc altitude, both-direction drift repair including the terminal-write race, no re-run of a done proposal, and arc disambiguation.
- **Phase 4 (AFK):** `afk`/`afk_policy` fields, `--afk[=skip-blocked]` setter, `.claude/oversee/pause` out-of-band stop, soft/hard gate distinction, escalation to state-file + `.claude/oversee/escalations/`; explicitly separate from `iterate`'s per-loop floor fallback.
- **Phase 5 (footprint/interleave/claims):** footprint declaration + sonnet-tier scout, overlap test, serialize-on-uncertainty default, repo-global claim registry (acquire/release/stale-reconcile), single-overseer interleaving with the `--max-parallel 3` cap, and the preserved per-dispatch Pillar 1b backstop.
- **Phase 6 (materialization):** cross-target degradation documented in the rule and the init glob registration confirmed.

Key design decisions are all honored: one-overseer interleaving (never nested overseers), the reconciled up-contract TRIPLE (frontmatter `status` + devlog handoff + `arc_state`, no single trusted field), `--max-parallel 3` default, and cross-session resume + liveness reconciliation. Nothing is over-implemented (no loop internals reimplemented; the skill composes and reads back durable signals only) or under-implemented against the spec. The prose is clear and usable as an actual skill/rule: pointer-not-restate discipline is consistently applied and the mermaid flow matches the sequential control path.

## Blocking items

1. **[blocking]** Remove the stray final `</content>` line from each of the three authored files: `plugins/cdocs/rules/oversee-arc.md` (line 141), `plugins/cdocs/skills/oversee/SKILL.md` (line 171), and `plugins/cdocs/skills/oversee/template.md` (line 84). No opening tag exists; delete the trailing tag so the files end on their last content line.

## Non-blocking nits

1. **[non-blocking]** `oversee-arc.md` "Cross-Target Degradation" duplicates the SKILL's shorter version nearly verbatim. This is acceptable (rule = normative source, skill = pointer + one-line summary that already links back), but confirm the SKILL paragraph reads as a summary-plus-pointer rather than a second authority; it currently does, so this is informational only.
2. **[non-blocking]** The rule's arc-state schema block and `template.md`'s arc-state block are intentionally two views (annotated-normative vs. copyable-skeleton) with slightly different sample values; that is fine and matches the proposal, but a one-line cross-note already present in `template.md` ("normative field semantics live in oversee-arc.md") keeps them from drifting — no action needed.
