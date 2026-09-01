---
review_of: cdocs/proposals/2026-08-28-overseer-alignment.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-01T11:20:00-07:00
task_list: cdocs/overseer-alignment
type: review
state: live
status: done
tags: [fresh_agent, model_tiering, cross_target, registration_mirror, additive_only, architecture]
---

# Review: Overseer Alignment Phase 4 (Model Tiering / Pillar 4)

## Summary Assessment

Phase 4 adds a new `plugins/cdocs/rules/model-tiering.md` rule codifying three advisory model tiers (opus lead/judgment, sonnet search/explore, haiku mechanical fan-out) and registers it at the same three surfaces Phase 1 used: `AGENTS.md` `@rules/` section, the source-repo `CLAUDE.md` `@`-import bullet, and `/cdocs:init`'s hardcoded `AGENTS.md` template inside the `cdocs-rules-start/end` delimiters.
The work is verified against disk: the diff is strictly additive (15 insertions, 0 deletions across tracked files; the new rule is untracked), the OpenCode build passes (exit 0) and materializes the rule with full content, and the precedence semantics (consumer floor wins, adoption via named carve-outs, no automatic override) match the proposal's resolution exactly.
Tier agent examples are ground-truth-correct: reviewer=opus, judge=opus, triage=haiku, nit-fix=haiku, verified against `plugins/cdocs/agents/` frontmatters.
All seven acceptance criteria pass with zero blocking findings. Verdict: **Accept**.

## Acceptance Criteria Results

| # | Criterion | Result | Evidence |
|---|---|---|---|
| A | Rule exists, correct shape, tiers match ground truth | PASS | `model-tiering.md:1` starts `# CDocs Model Tiering`, no YAML frontmatter (mirrors `orchestration-discipline.md:1`). Three tiers at lines 11, 19, 25. Claims `reviewer`/`judge` = opus (line 14) and `nit-fix`/`triage` = haiku (line 28); ground truth from agent frontmatters: reviewer `model: opus`, judge `model: opus`, triage `model: haiku`, nit-fix `model: haiku`. All match. |
| B | Precedence unambiguous, no invented policy | PASS | `model-tiering.md:31-40`: shape "ADVISORY" and consumer policy "ALWAYS WINS" (line 33); blanket floor collapses shape toward floor (line 34); weftwise "do not silently downgrade dispatched work" named (line 35); adoption via named carve-out above floor (line 37-38); ships carve-outs as ready-to-adopt guidance "NOT as an automatic override" (line 39). Nothing beyond the proposal's resolution (proposal lines 167, 326). |
| C | Registration mirrors Phase 1 at all three surfaces | PASS | AGENTS.md: `## Model Tiering` + `@rules/model-tiering.md` (lines 17-19), same format/placement as `## Orchestration Discipline` (13-15), after it and before Frontmatter. CLAUDE.md: bullet at line 48 after Orchestration Discipline bullet (47), before Frontmatter (49), correct `@plugins/cdocs/rules/model-tiering.md` path. init/SKILL.md: `## CDocs Model Tiering` (line 83) INSIDE the `cdocs-rules-start` (70) / `cdocs-rules-end` (90) delimiters, after Orchestration Discipline (79), before Frontmatter (87). |
| D | Skill cross-references concise (~1 line), near -f docs | PASS | iterate/SKILL.md:38 one-line ref to `model-tiering.md` immediately after the `-f | --first-round` doc (line 35). propose-revise/SKILL.md:41 same, after its `-f` doc (line 38). Not a duplicated table. full-send defers to propose-revise for model semantics (full-send lines 18, 22) - acceptable per criterion. |
| E | Additive-only, no Phase 1-3 content modified | PASS | `git diff --stat`: CLAUDE.md +1, AGENTS.md +4, init/SKILL.md +4, iterate +1, propose-revise +1, devlog +4 = 15 insertions, 0 deletions. `git diff -U1` shows only `+` lines; no orchestration-discipline.md change, no reworded existing registrations or rule sections. New rule is untracked (`?? model-tiering.md`). |
| F | Build passes; OC rule materialized with content | PASS | `npm run build:cdocs` -> `BUILD_EXIT=0`. `build/cdocs/opencode/rules/model-tiering.md` exists (3532 bytes), head shows full tiering content; tier/precedence keyword count = 11. |
| G | Zero em-dashes; sentence-per-line prose | PASS | `grep '—' model-tiering.md` -> exit 1 (no matches). Em-dashes in added lines across all edited files: none (`git diff | grep '^+' | grep '—'` -> exit 1). New rule prose is one-sentence-per-line throughout. |

## Empirical Anchors

- **Build exit code:** `BUILD_EXIT=0`; OpenCode agents converted: 4; output rule `model-tiering.md` = 3532 bytes.
- **Em-dash grep (new rule):** `grep -n '—' plugins/cdocs/rules/model-tiering.md` returned no matches (exit 1).
- **Em-dash grep (added lines, all edited files):** `git diff | grep '^+' | grep '—'` returned no matches (exit 1).
  Pre-existing em-dashes DO exist in `CLAUDE.md` (lines 41, 57, 58, 59) and `init/SKILL.md` (lines 122, 123, 162), but every one sits on an unchanged line outside Phase 4's additions. They are Phase 1-or-earlier content and out of scope for this additive phase (touching them would violate criterion E). Noted, not charged against Phase 4.
- **Diff totals:** 15 insertions, 0 deletions (tracked); new rule untracked.
- **Ground-truth agent models:** reviewer=opus, judge=opus, triage=haiku, nit-fix=haiku (read directly from `plugins/cdocs/agents/*.md` frontmatters).

## Section-by-Section Findings

No blocking findings.

Non-blocking observations:

1. **[non-blocking] Cost-quality prose placement.** The proposal's Pillar 4 "Cost-quality trade-off" paragraph (proposal line 169) is folded into the rule's opening (`model-tiering.md:7-9`) rather than a dedicated subsection. This is a reasonable brevity choice and loses no substance; noted only for traceability.
2. **[non-blocking] full-send has no direct `model-tiering.md` link.** full-send legitimately defers its model semantics to propose-revise (full-send/SKILL.md:22 "Same as `/cdocs:propose-revise`"), which now carries the cross-reference. The proposal's `-m`/`-f` cross-reference bullet (line 179) is satisfied at the two skills that document those flags with their own prose. Acceptable per criterion D; no action needed.
3. **[non-blocking] Stale unrelated reference observed.** The devlog's explore pass flagged `triage/SKILL.md:56` describing a reviewer as sonnet, out of scope for Phase 4. Not touched here (correctly, per additive-only), but worth a separate cleanup pass since `model-tiering.md` now makes reviewer=opus canonical.

## Verdict

**Accept.**

Phase 4 is complete, faithful to the proposal's Pillar 4 and Phase 4 spec, strictly additive, and empirically verified (build green, OC rule present, zero em-dashes in new content). Registration mirrors Phase 1 at all three surfaces with correct placement and paths. Precedence semantics are unambiguous and invent no policy beyond the proposal's resolution.

## Action Items

None blocking.

1. [non-blocking] In a future unrelated pass, reconcile `plugins/cdocs/skills/triage/SKILL.md:56` (reviewer described as sonnet) against the now-canonical `model-tiering.md` reviewer=opus tier.

## Clarifications for the Maintainer

The implementation resolved the one judgment call cleanly, but confirm the intended default:

1. Should full-send eventually carry its own one-line `model-tiering.md` cross-reference for discoverability, or is deferral to propose-revise the intended permanent shape?
   - (a) Keep deferral (current state); model guidance lives with the flags that use it. [recommended]
   - (b) Add a parallel one-line cross-reference to full-send for symmetry.
