---
review_of: cdocs/proposals/2026-08-28-overseer-alignment.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-08-28T15:55:29-07:00
task_list: cdocs/overseer-alignment
type: review
state: archived
status: done
tags: [fresh_agent, architecture, agent_orchestration, rule_delivery, enforcement_design, model_tiering]
---

# Review: Overseer Alignment - Thin Lead, Durable Memory, Tiered Models

## Summary Assessment

The proposal aligns the cdocs multi-agent workflow with Anthropic's orchestrator-worker pattern by promoting duplicated per-skill "overseer mode" prose to one enforced rule, adding a context-cleanliness rule, formalizing a durable-specialist pattern, and codifying model tiering.
The motivation is well-grounded in prior art, the forensic figures are honestly scoped as evidence rather than proof (the NOTE at lines 58-59 is exemplary), and most claims about current plugin state are accurate.

The verdict is **Revise**. Two blocking issues undercut implementability: (1) the described rule-delivery pipeline is factually wrong in a way that makes Phase 1's success criterion unachievable as written - the `SessionStart` hook does not inject rule content, it is a staleness nudge, and the actual materialization engine (`/cdocs:init`) is omitted entirely from the delivery model; (2) the judge-based enforcement of context-bloat (Pillar 2) is unsound as specified - the judge is barred from the inputs that would let it observe overseer bloat, so it cannot back the very discipline it is assigned, absent a logged signal the proposal never defines.
A cross-consumer model-tiering conflict with weftwise's blanket no-downgrade policy is a third, non-blocking, gap.

## Section-by-Section Findings

### Background / "Current cdocs state" - factual accuracy (mostly accurate, one load-bearing error)

Verified accurate:
- Overseer defined in three skills with drift: `iterate/SKILL.md:13` says dispatch "for all tasks beyond trivial few-liners"; `propose-revise/SKILL.md:17` says "even trivial ones" (stricter). The proposal characterizes the direction of drift correctly (line 86: iterate as default, propose-revise as the stricter documented exception).
- Four formal agents, no formal implementer: confirmed (`agents/` has reviewer/judge/triage/nit-fix; `iterate/SKILL.md:74` dispatches implementer as `general-purpose`).
- Judge toolset: `judge.md` frontmatter is `Read, Glob, Grep, Write` - the "no Edit/Bash/Task" claim holds (Write is present but the exclusion claim is correct).
- Three rule files, none mentioning context cleanliness / thinness / `/compact` / checkpointing / durable memory: confirmed by reading all three.
- "Only in-plugin occurrence of 'compact' is a passing aside in `triage/SKILL.md`": confirmed by grep.
- `iterate` has no retry/context cap: confirmed (`iterate/SKILL.md:104-105`).
- clauthier's root `CLAUDE.md` carries no model-default policy: confirmed (grep returns nothing).

**Blocking - the rule-delivery pipeline is mischaracterized (line 54, Phase 1, Test Plan).**
The proposal states rules are delivered "via three layers: a `SessionStart` hook injecting rule content, agent relative-path lookups, and `plugins/cdocs/AGENTS.md` `@`-imports."
Reading `hooks/inject-rules.ts`: the SessionStart hook does **not** inject rule content.
It computes a sha256 over `rules/*.md`, compares it to a marker hash in the consumer's `.claude/rules/cdocs.md`, and on mismatch emits a <500-byte *directive telling the user to re-run `/cdocs:init`*.
The actual content-materialization engine is `/cdocs:init` (`skills/init/SKILL.md`), which writes `.claude/rules/cdocs.md`, `.opencode/rules/cdocs/`, and an inlined `AGENTS.md` section - and the proposal never mentions `/cdocs:init` at all.
Consequences for the implementer:
- Phase 1 success criterion "rule content appears in a fresh session's context via the hook" (line 174) and the Test-Plan item "confirm the two new rules are injected by the `SessionStart` hook" (line 155) describe a mechanism that does not exist; a literal implementer will chase an unachievable check.
- Phase 1's registration list "AGENTS.md `@`-imports, the `SessionStart` hook manifest, and confirm agent relative-path fallback" (line 173) is wrong on two points: there is nothing per-rule to register in `hooks.json` (`inject-rules.ts` globs the directory, so a new rule is auto-hashed); and it omits the real registration surfaces.
- The real registration surfaces a new rule must touch: `plugins/cdocs/AGENTS.md` (`@rules/...` lines, three today at lines 7/11/15); the source-repo `CLAUDE.md` `@plugins/cdocs/rules/...` imports (clauthier lines 45-47, and each source-consuming repo); and, critically, `/cdocs:init`'s AGENTS.md inlining template, which **hardcodes exactly three sections** ("CDocs Writing Conventions / Workflow Patterns / Frontmatter Specification", `init/SKILL.md:73-81`). A fourth rule not added there is hashed (so the hook nags "stale") but never materialized into the consumer's inlined `AGENTS.md` - a latent split-brain the proposal should call out and Phase 1/2 must handle.
The good news the proposal should lean into: because both the hash and the `.opencode/` copy glob `rules/*.md`, dropping a new rule file is *partially* auto-delivered; the manual work is the hardcoded AGENTS.md template and the `@`-import lists. State this correctly so the implementer edits the right files.

> NOTE(claude-opus-4-8/overseer-alignment-review): The plugin's own agent files perpetuate the same imprecise phrase ("rule content may still be available ... via the SessionStart hook injection", e.g. `judge.md:25`, `reviewer.md:26`). The proposal inherited the mischaracterization rather than inventing it, which mitigates blame but not the implementer-facing consequence. Correcting the proposal's model is worthwhile precisely because the codebase is already loose here.

### Pillar 1 - Overseer-role enforcement (sound, with one scope gap)

The single-source-of-truth consolidation and the "trivial few-liners" default-plus-exception reconciliation are the right call and correctly targeted at the drift vector.
The graded-enforcement framing (written self-check; judge remit; optional advisory hook) is appropriately honest that a hard tool-allowlist on the top-level session is unavailable, and the analogy to how the reviewer's constraints are backed (line 137) is apt.

**Non-blocking - the judge backstop is iterate-only, but Pillar 1 applies the rule to all three overseer skills.**
The judge exists only inside `/cdocs:iterate`, and only from the Nth Revise verdict onward (`--judge-after`, default 3). `propose-revise` and `full-send`'s propose phase have no judge. So for two of the three skills the proposal targets, enforcement collapses to the written self-check alone - there is no independent backstop. The proposal presents graded enforcement as if uniformly available; it should acknowledge that the judge layer covers only the iterate loop and that propose-revise/full-send rely on prose plus the optional future hook.

### Pillar 2 - Context persistence and cleanliness (blocking soundness gap)

The file-over-window discipline, pre-compaction handoff, and building on the existing Iteration Log resumption seam are all sound and low-risk.

**Blocking - the judge cannot observe overseer context bloat from its permitted inputs.**
Line 92 claims the judge "gains an explicit check for overseer-as-workhorse and context bloat, and may return `escalate` ... This is real backing because the judge is independent."
But `judge.md:44-46` and its Constraints bar the judge from reading source, running verification, or opening the live system; its inputs are the Iteration Log and the review documents.
Overseer per-turn context size and inline-vs-dispatch ratio are not recorded anywhere the judge can see them - there is no `usage.db` access (no Bash, correctly) and the iteration log carries no such field today.
So the judge can only detect bloat if the overseer *self-reports* it into the log - which is exactly the behavior a bloated, workhorse-drifting overseer is least likely to perform faithfully. The enforcement reduces to self-policing, not independent backing, contradicting the "real backing because the judge is independent" claim.
Phase 4's synthetic-log test (line 157, "an iteration log showing ... context bloat") quietly assumes the signal is already legible in the log, papering over the gap.
Resolution: specify the additive Iteration-Log field(s) the overseer must write each turn that make thinness legible to the judge (e.g. per-turn approximate context size, dispatch ratio, or a boolean "inline-work performed"), and state that the judge keys `escalate` off that field. Phase 4's "additive fields" constraint (line 191) already permits this; the proposal just never names the field, so the enforcement chain has a missing link. Until named, Pillar 2's independent enforcement is aspirational.

**Non-blocking - the CLAUDE.md-reseed-after-compaction claim is load-bearing and asserted, not verified.**
Lines 46 and 101 lean on "a repo-root `CLAUDE.md` is re-read from disk after compaction" as the reseed mechanism.
This is a plausible Claude Code mechanic but it is stated as fact without a citation or a probe, and the whole compaction-cadence pillar rests on it. Add a verification step (or cite where the behavior is documented), since if reseed does not actually re-read from disk the "compact aggressively, rely on reseed" guidance loses its safety net.

### Pillar 3 - Durable specialists (sound)

Resume-by-name via `SendMessage`, `fork` for side-investigation, and the one-per-workstream bound are all coherent and map to real harness capabilities. Generalizing from the implementer's existing "fresh only on rotate" durability (line 114) is a fair reading of `iterate/SKILL.md:130`. No blocking issues.

### Pillar 4 - Model tiering (sound design, one unaddressed consumer conflict)

The tiering shape (strong lead/judge, sonnet search/explore, haiku mechanical) is reasonable and "ship the shape, let consumers pin a family" is the right layering.

**Non-blocking but should be reconciled - the named example consumer contradicts the tiering shape.**
The proposal cites weftwise as the consumer that "pins its own" model (line 56) and as the model for "pin a family while inheriting the tiering shape" (line 124).
But weftwise's `CLAUDE.md` policy is a blanket floor, not a family pin: "Default all dispatched/subagent work to Opus 4.8 ... Do not silently downgrade dispatched work to a weaker or cheaper model."
That directly nullifies Pillar 4's "sonnet for search/explore, haiku for mechanical" - weftwise forbids exactly that downgrade. "Inherit the shape, pin the family" does not describe "pin a floor across all tiers." The proposal should either (a) state that a consumer floor overrides the tiering shape (and that the shape is therefore advisory, degrading to a single tier under a blanket pin), or (b) pick a cleaner example. As written it uses a counterexample as its supporting example.

### Cross-target (OpenCode) degradation (adequately scoped)

The degradation story for `SendMessage`/`fork`/`/compact` to "fresh session plus handoff doc" (line 147) is the right fallback and is correctly flagged as an Open Question requiring a capability check.
One addition: `/cdocs:init` already special-cases OpenCode by globbing rules into `.opencode/rules/cdocs/` (`init/SKILL.md:40-59`), so the *rule-content* delivery of the two new files degrades gracefully by construction; only the runtime mechanics (compaction, specialist resume) degrade. Distinguishing "rule delivery degrades cleanly" from "runtime mechanics degrade to fresh-session" would sharpen the section.

### Forensics scoping (well handled, one minor over-attribution)

The NOTE at lines 58-59 is a model of honest scoping: figures framed as motivating evidence, design resting on prior art regardless.
Minor: the BLUF (line 14) attributes the ~6.4x balloon and ~964K peak to "the cdocs overseer" specifically, whereas the NOTE says only that they come from the maintainer's Aug 26-28 sessions. If those sessions were not verifiably running cdocs overseer skills, "the cdocs overseer ... balloons" slightly over-attributes a general-session measurement to this specific pattern. Soften the BLUF to match the NOTE's scoping, or confirm the measured sessions were cdocs-iterate sessions.

### Test Plan / Verification Methodology

The empirical discipline (baseline-must-reproduce-before-post-change-is-trusted, line 165) is exactly right and consistent with the repo's spike discipline.
The two defects above surface here: the "injected by the SessionStart hook" test (line 155) tests a non-existent mechanism, and the judge-escalation test (line 157) assumes a log signal that does not yet exist. Both test items need rewording once Pillars 1/2 are corrected.

### Phasing

Phase ordering (rule first, skills reference it later) is sound and the independence claim is fair.
Phase 1 and Phase 4 success criteria must be rewritten per the blocking findings. Phase 3's "preserve role table and audit-trail semantics" constraint is good discipline. Phase 6 is correctly fenced as optional/uncertain.

## Verdict

**Revise.**
The design is well-motivated, mostly accurate about current state, and low-risk in the sense that it is a rules/skills change.
Two blocking issues must be resolved before implementation: the rule-delivery pipeline must be described correctly (hook is a staleness nudge, `/cdocs:init` is the materialization engine, AGENTS.md template hardcodes its section list), and Pillar 2's judge-enforcement must be made real by specifying the logged signal the judge reads (or the claim of "independent backing" must be dropped in favor of honest self-policing-plus-advisory).
The model-tiering / weftwise conflict and the CLAUDE.md-reseed assumption should be reconciled but do not block.

## Action Items

1. [blocking] Correct the rule-delivery model throughout (line 54, Design Decisions, Phase 1, Test Plan): the `SessionStart` hook is a hash-based staleness nudge that emits a re-run-`/cdocs:init` directive, not a content injector. Name `/cdocs:init` as the materialization engine.
2. [blocking] Rewrite Phase 1's registration steps and success criterion to the actual surfaces: `plugins/cdocs/AGENTS.md` `@rules/` lines, source-repo `CLAUDE.md` `@`-imports, and `/cdocs:init`'s hardcoded AGENTS.md section template (`init/SKILL.md:73-81`). Call out the hash-vs-materialization split-brain risk (a new rule is auto-hashed but not auto-inlined into AGENTS.md).
3. [blocking] Specify the additive Iteration-Log field(s) that make overseer thinness/context-size legible to the judge (per-turn context estimate, dispatch ratio, or inline-work flag), and state that the judge escalates off that field. Reword line 92's "real backing because the judge is independent" to reflect that independence is only meaningful once the signal is logged.
4. [blocking] Rewrite the two affected Test-Plan items (lines 155, 157) so they test real mechanisms: `/cdocs:init` materialization of the new rules and hook staleness-detection; judge escalation off the newly-specified logged signal.
5. [non-blocking] Acknowledge in Pillar 1 that the judge backstop is iterate-only; `propose-revise` and `full-send` rely on the written self-check plus the optional future hook, with no independent enforcer.
6. [non-blocking] Reconcile Pillar 4 with weftwise's blanket "do not downgrade dispatched work" floor: state that a consumer floor overrides the tiering shape (shape is advisory), or replace the example. weftwise is currently cited as both the supporting example and a live counterexample.
7. [non-blocking] Add a verification step (or citation) for the "repo-root `CLAUDE.md` re-read from disk after compaction" reseed claim (lines 46, 101), since the compaction-cadence pillar depends on it.
8. [non-blocking] Soften the BLUF's attribution of the balloon figures to "the cdocs overseer" to match the NOTE's session-scoped framing, or confirm the measured sessions were cdocs-iterate overseer sessions.

## Clarifications Requested (multiple choice)

The following are underspecified points where the author's intent would change the implementation. Each is offered as options for the author/maintainer to pick.

**A. How should the judge observe overseer context bloat (Action Item 3)?**
1. Overseer writes a per-turn approximate context size + dispatch ratio into an additive Iteration-Log column; judge escalates on trend.
2. Overseer writes only a boolean "performed non-trivial inline work this turn" flag; judge escalates on a run of them.
3. Drop judge-enforcement of Pillar 2 entirely; rely on the written self-check plus the Phase 6 advisory hook, and stop claiming independent backing.
4. Give the judge a narrow read-only `usage.db` probe (a real deviation from its current no-verification remit; higher blast radius).

**B. How should model tiering resolve against a consumer's blanket model floor (weftwise)?**
1. Consumer floor always wins; tiering shape is advisory and collapses to the floor where the floor is stronger.
2. Tiering shape wins for search/explore/mechanical unless the consumer explicitly opts each tier back up.
3. Ship tiering only as documentation of intent with no default dispatch resolution, leaving every consumer to encode it in their own `CLAUDE.md`.

**C. One combined rule file for Pillars 1-3, or split context-discipline out now?**
1. One `orchestration-discipline.md` now; split only if it grows unwieldy (proposal's current lean).
2. Split `context-discipline.md` from the outset, since Pillar 2 is the part with the enforcement gap and may need to grow.
