---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-01 07:52:27 PDT
task_list: cdocs/oversight
type: devlog
state: live
status: wip
tags: [proposals, overseer, claude-code-features, research]
---

# Oversight: Proposal Survey + CC Feature Report: Devlog

## Objective

Session "oversight" — three parallel workstreams:
1. Collect and list all incomplete RFPs/proposals in the repo (haiku agent).
2. Expand the proposal focused on the cdocs "overseer" discipline (same haiku agent).
3. Report on new Claude Code features enabling better rules management / plugin
   improvement (named subagent roles, etc.), with an Artifact linking to an
   exemplary Claude plugin repo (sonnet agent).

## Plan

- Dispatch a haiku general-purpose agent for tasks 1+2 (survey + overseer expansion).
- Dispatch a sonnet general-purpose agent for task 3 (feature report + Artifact).
- Both run in background; integrate findings on completion.

## Testing Approach

Research/documentation task — no code under test. Verification is: (a) the
proposal survey is accurate against repo frontmatter, (b) the overseer proposal
edits preserve valid frontmatter and writing conventions, (c) the Artifact URL
and exemplary-repo URL resolve.

## Implementation Notes

- Delegated per user's explicit model choices: haiku for the survey/expansion,
  sonnet for the feature report. Kept them independent (no shared files) so they
  run concurrently.

## Changes Made

| File | Description |
|------|-------------|
| cdocs/devlogs/2026-09-01-oversight-proposals-and-cc-features.md | This devlog |
| cdocs/proposals/2026-08-28-overseer-alignment.md | Expanded by haiku agent (+99/−34): problem evidence metrics, 4 pillars fleshed out, edge cases 6→9, test plan + acceptance criteria, verification methodology, open questions 3→5 |

**Survey:** 22 incomplete proposals found (state `live`, non-terminal status). Overseer-relevant: `2026-08-28-overseer-alignment.md` (expanded), `2026-05-13-iterate-skill.md`, `2026-03-26-rfp-oversee-skill.md`.

## Feature Report (sonnet agent)

Artifact "CDocs Upgrade Radar": https://claude.ai/code/artifact/46f4d542-268b-460d-96d6-5b5730aea7f5

Exemplary repos (both WebFetch-verified live):
- anthropics/claude-plugins-official — immutable-name/`displayName`/`renames`, `strict: false` skill bundles.
- obra/superpowers — parallel committed per-tool manifests vs cdocs's gitignored build.

Top recs:
1. Type the implementer role (`agents/implementer.md`, `isolation: worktree`) so judge's `rotate-implementer` verdict has teeth.
2. `PreCompact` + `SessionEnd` hook to auto-flush the active devlog.
3. Keep rules-delivery workaround (no native `plugin.json` `rules` field shipped); cache freshness hash in `CLAUDE_PLUGIN_DATA`, pre-draft manifest cutover.
4. Adopt `color`/`maxTurns`/selective `memory: project` on agents — withhold `memory` from reviewer/judge (fresh-eyes invariant).
5. Marketplace `category`/`tags`; speculative `workflows/iterate.js`.

Finding: subagent frontmatter `hooks`/`mcpServers`/`permissionMode` ignored for plugin subagents → top-level `PreToolUse` hook is structural, not a workaround.

## Round 2 Workstreams (dispatched)

1. **worktree investigation** (sonnet/cc-guide) — does `isolation: worktree` work with bare-repo worktrees or only CC-internal? Read-only.
2. **devlog-value report** (sonnet) — is the devlog redundant vs internal thinking/compaction/memory? → `cdocs/reports/2026-09-01-devlog-token-value-analysis.md`.
3. **full-send** (opus) — implement agent frontmatter (`color`/`maxTurns`/selective `memory: project`, withhold from reviewer/judge) + marketplace `category`/`tags`. Own branch `cdocs/agent-frontmatter-marketplace`; verify fields are real before writing.
4. **triage** (sonnet) — archive shipped review/impl-ready proposals; EXCLUDES the 3 overseer docs, codex doc, and OpenCode/packaging docs (deferred). Stage only, no commit.
5. **overseer-consolidate** (sonnet) — reconcile the 3 overseer docs; memo at `cdocs/proposals/2026-09-01-overseer-consolidation.md` naming canonical doc. No restatus/archive yet.

Deferred by owner: codex support, non-CC/OpenCode packaging. Overseer work to be resumed later this session.

## Session-limit crash + recovery

Round-2 agents all died on "session limit · resets 12pm PT". State assessed on resume:
- Survived complete on disk: devlog-value report; round-1 overseer expansion; this devlog.
- Died before writing: full-send, triage, overseer-consolidate, worktree investigation.
- **Side effect:** the full-send subagent's `git checkout -b` moved the shared `main` worktree onto `cdocs/agent-frontmatter-marketplace` (no commits). Recovered: switched back to `main`, `git branch -d` the empty stray branch (safe — no unmerged commits). Working-tree changes preserved.
- Lesson applied on re-dispatch: full-send now runs with `isolation: worktree` so it cannot move the shared checkout; triage/consolidate told never to run git checkout/branch/commit.

## Worktree investigation — answered inline (no agent)

`isolation: worktree` uses real `git worktree add` (not a separate internal system); by convention under `.claude/worktrees/<name>/`. Empirically verified `git worktree add` works from this linked worktree of the bare repo: registers against common `.bare` dir, new `.git` → `.bare/worktrees/<name>`, `worktree remove --force` clean. **Safe** to add `isolation: worktree` to the cdocs implementer agent; only workflow consideration is merging the branch back. Shared stash stack caveat applies only if agents stash.

## devlog-value report — landed complete

`cdocs/reports/2026-09-01-devlog-token-value-analysis.md`. Recommends **option (b)**: keep the devlog artifact (durable, git-versioned, cold-readable by fresh agents / non-Claude harnesses — not redundant with ephemeral thinking/compaction/memory), but scope the CLAUDE.md mandate to multi-step/hand-off/cross-session work; permit one-shot tasks to skip or use a minimal form. Also endorses the PreCompact/SessionEnd auto-flush hook.

## overseer-consolidate — landed complete

Memo at `cdocs/proposals/2026-09-01-overseer-consolidation.md`.
No restatus/archive applied to the three overseer docs; recommendations only, per instruction.

**Canonical doc:** `2026-08-28-overseer-alignment.md` — the only one still under active review, and the only one addressing overseer resource discipline (context growth, model tiering) rather than the loop protocol.

**Per-doc status:**
- `2026-03-26-rfp-oversee-skill.md`: partially superseded. Its "Orchestration Rules" ask is largely absorbed by shipped `iterate` + in-review `overseer-alignment`, but its core `/oversee` multi-proposal-arc ask (chain invocation, AFK signal at the arc level, shared state/lock files, cross-agent coordination) is unbuilt and uncovered by either shipped doc — `overseer-alignment` explicitly punts multi-overseer coordination to "the `/oversee` skill's cross-agent coordination layer" (its own Edge Cases). Recommended: no state/status change (still a live, honest RFP for that remaining scope), add a second NOTE pointing at `overseer-alignment` and this memo.
- `2026-05-13-iterate-skill.md`: shipped and matches design (`plugins/cdocs/skills/iterate/`, `full-send/`, `agents/judge.md` all exist), plus undocumented-in-proposal extensions (`-m`/`-f` model flags, `--dispatched` mode, `review_proof` column). Frontmatter is stale (`status: review_ready`, accepted round 3). Recommended: `status: implementation_accepted`, matching the convention on the two other most-recently-shipped proposals (`2026-05-18-iterate-agent-capabilities.md`, `2026-05-12-cdocs-rule-delivery-materialization.md`).
- `2026-08-28-overseer-alignment.md`: no change recommended; correctly `live`/`review_ready`/`revision_requested` round 1, with two blocking review gaps (rule-delivery pipeline mischaracterized; judge context-bloat enforcement has no named logged signal) still pending author revision.

**Deduplicated open-questions list** (19 items, memo §"Deduplicated Open Questions"), grouped:
- (A) `/oversee` multi-proposal orchestration, unique to the RFP and fully unbuilt: invocation/chaining surface, arc-level AFK signal, cross-session progress file, shared-state/lock files, file-conflict-aware parallelization, troubleshooting budgets, a verification-depth ladder taxonomy.
- (B) `/cdocs:iterate` loop refinements raised in its proposal but not resolved by the shipped skill: judge trigger cadence, implementer return schema, triage awareness of the Iteration/Judge Logs, mid-loop user participation controls.
- (C) `overseer-alignment`'s own live open questions plus round-1 review gaps: rule-file granularity, soft loop-cap tuning, OpenCode capability parity, specialist naming, handoff-format enforcement, plus the two blocking revision items and the weftwise model-tiering-floor conflict.

## triage — landed complete

7 proposals archived (frontmatter-only, `state: archived` in place per repo precedent; +11/−11): plugin-architecture, marketplace-restructure, robust-frontmatter-stripping, cdocs-plugin-improvements, rule-delivery-materialization, rule-delivery-investigation, nit-fix-project-rules. Each with commit-SHA/artifact evidence.

Left open (verified genuinely unshipped): cdocs-cli, mermaid-plugin, cdocs-skill-ergonomics (RFPs), use-mermaid-diagrams (rule file absent), archive-formalism (Phase 1 undone).

Flagged for human review (no edits): rules-hook-testing-methodology (premise obsolete — tested a deleted script); iterate-agent-capabilities (already `implementation_accepted`, shares iterate task_list — left untouched); cross-target-rules-integration (invalid status `results_accepted`, OC-adjacent — left untouched).

## full-send salvage + concurrency reconciliation

The re-dispatched full-send orchestrator (`isolation: worktree`) THRASHED: it reported the identical mid-loop state twice ("proposer round-1 revision in flight") despite the harness notifying only when it had no live children. A blind third resume would have looped — this is precisely the stuck-overseer failure `overseer-alignment.md` targets. Overseer (me) stopped resuming, inspected the worktree, and found: good verified proposal + a thorough review (verdict Revise-light, all action items non-blocking), but ZERO implementation.

Salvage decision: don't re-run the loop. Dispatched a fresh implementer (`afb68889`) into the existing worktree/branch (`cdocs/agent-frontmatter-marketplace` at `.bare/.claude/worktrees/agent-ad4e508c2da65f781`) with the review's 5 action items spelled out.

Then a concurrency wrinkle: the orphaned proposer child (`a79c9b26`) — the one the dead orchestrator was "waiting on" — surfaced, having written a BETTER Q1 resolution to the same file (omit maxTurns from batch agents; principle: cap only intrinsically-bounded work; only `judge`=10). Reconciled by course-correcting `afb68889` to adopt that principled resolution rather than overwrite it with my earlier arbitrary `60`. Two concurrent writers on one file, steered to the better answer instead of a race.

Q2 resolved: accept CC/OC divergence (OC build drops the 3 fields by design) + add `npm run build:cdocs` check.

## Integration (landed on main)

All work committed to `main` (linear history, `54f7674`):
- 5 doc commits: overseer expansion; devlog-value report; overseer consolidation + restatus (iterate-skill→`implementation_accepted`, rfp-oversee cross-ref NOTE); 7 triage archives; this devlog.
- 6 frontmatter/marketplace commits cherry-picked from the isolated full-send branch (ff-equivalent; zero file overlap → no conflicts). Isolated worktree + redundant branches removed (stale lock unlocked first; tree confirmed clean, nothing lost).

Deferred (needs interactive CC session): `/plugin marketplace add . && /plugin install cdocs@clauthier` round-trip for the marketplace-metadata change.

Follow-up flagged for the overseer /review (running): reconsider `memory: project` on `triage`/`nit-fix` — mechanical enforcers risk stale-convention drift and non-determinism; the fresh-eyes argument may extend to them.

## Overseer-alignment phased implementation (full-send per phase)

Approach: each Implementation Phase run as its own isolated-worktree, liveness-aware full-send loop; merged ff into main sequentially (phases share `orchestration-discipline.md` + registration surfaces, so parallel would collide).

- **Phase 1** (merged `d64af78`): shared `orchestration-discipline.md` rule (thin overseer, inline floor, Pillar 1b liveness + single-writer ownership); registered at 3 surfaces; 3 skills → reference+floor; Iteration-Log thinness/liveness fields; judge `overseer_thinness`. Accept iter 1, no deadlock, dogfooded.
- **Phase 2** (merged `11b57fe`): Pillar 2 context persistence — handoff-before-compact (Completed/Decisions/Open Todos), soft context-budget as judge input, compaction cadence. Reseed mechanic CONFIRMED w/ caveat (root CLAUDE.md + unscoped `.claude/rules/*.md` reseed; path-scoped/nested don't — cdocs safe via `/cdocs:init` unscoped materialization; src: code.claude.com/docs/en/context-window.md). Accept iter 1.
- **Phase 3** (running): durable specialists (Pillar 3) — pattern in the rule, cross-refs from workflow-patterns.md.
- Phases 4 (model tiering), 5 (advisory hook) queued after.

Interactive-only checks deferred across phases: live `/cdocs:init` scratch materialization + hook stale/silent round-trip; live iterate behavioral probe (overseer writes handoff before compact, per-turn ctx <150K).

## Companion docs this session

- New proposal `2026-09-01-iterate-refinements.md` (triage log-awareness + mid-loop steering); predecessor `iterate-agent-capabilities.md` archived.
- New RFP `2026-09-01-devlog-autoflush-hook.md` (PreCompact/SessionEnd checkpoint).
- New RFP `2026-09-01-rules-hook-testing-methodology-v2.md`; obsolete v1 archived. `cross-target-rules-integration.md` archived + invalid status fixed.
- `CLAUDE.md` rules-delivery description corrected (hook is a freshness nudge, not a content channel).

## Verification

- Frontmatter fields verified on main: judge (`color: red`, `maxTurns: 10`, no memory), triage (`color: green`, `memory: project`, no maxTurns), reviewer (color only), nit-fix (color + memory, no maxTurns).
- Implementer validation (pasted in `2026-09-01-agent-frontmatter-marketplace.md`): `jq` parses both manifests; `npm run build:cdocs` clean (confirms OC build drops the 3 fields by design); CI OC-frontmatter check + `npm pack --dry-run` pass.
- Artifact + both exemplary repo URLs verified live via WebFetch.

