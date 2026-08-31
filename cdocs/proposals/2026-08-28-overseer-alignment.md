---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-08-28T15:49:55-07:00
task_list: cdocs/overseer-alignment
type: proposal
state: live
status: review_ready
last_reviewed:
  status: revision_requested
  by: "@claude-opus-4-8"
  at: 2026-08-28T15:55:29-07:00
  round: 1
tags: [oversee, agent_orchestration, context_management, model_tiering, durable_specialists, iterate, full_send, claude_skills, workflow]
---

# Overseer Alignment: Thin Lead, Durable Memory, Tiered Models

> BLUF: The cdocs "overseer" is a written behavioral mode duplicated across three skills with no rule governing its own context hygiene, and long-lived overseer-style sessions measured on the maintainer's setup ballooned ~6.4x within a session (peaking near a 964K-token single-turn re-read).
> This proposal promotes overseer discipline to a single enforced rule, adds a context-cleanliness rule (checkpoint-to-durable-memory, compaction cadence, turn-size targets), formalizes the durable-specialist pattern, and codifies model tiering (strong lead, sonnet search/explore, cheap mechanical).
> It is almost entirely a rules/skills change, low code risk, delivered through the existing cross-target rule pipeline.

## Summary

Anthropic's orchestrator-worker pattern puts a strong model at the lead and delegates bulk execution to disposable-context workers, but its lead agent externalizes running state to memory precisely because a window that grows past ~200K tokens truncates and degrades.
The cdocs plugin encodes the orchestrator half (the "overseer mode" prose in `iterate`, `propose-revise`, `full-send`) but not the memory-and-thinness half.
There is no `rules/*.md` that mentions context cleanliness, overseer thinness, `/compact`, checkpointing, or durable memory: the concern lives only in historical proposal and report prose, so it carries no enforcement weight and is never delivered to consuming projects.

The measured consequence, from a live usage-forensics pass on the maintainer's own sessions, is expensive: overseer per-turn context climbed from ~125K to ~805K tokens (peak ~964K) before each reset, the overseer carried ~2.25x the per-turn context of its subagents, and ~59% of overseer context went to inline `Bash`/`Edit`/`Read` work it should have dispatched.
The fix is not to remove the overseer; it is to make it thin and give it durable external memory, which is what the reference architecture already does.

This proposal makes four coordinated changes and calls out the cdocs patterns that must change to support them.

## Objective

Align the cdocs multi-agent workflow with orchestrator-worker best practice so that a long-lived overseer session stays cheap and sharp:

1. A single, enforced definition of the overseer role (thin lead, dispatch-by-default), replacing duplicated and already-drifting per-skill prose.
2. A context-persistence-and-cleanliness discipline that keeps overarching state in durable files (devlog, `CLAUDE.md`, handoff) rather than in an ever-growing live window.
3. A formal durable-specialist pattern so deep per-workstream context is carried by a named, resumable subagent, not absorbed into the overseer.
4. A model-tiering convention: strong model for lead and judgment, sonnet for search/explore/research-aggregation, cheapest capable model for mechanical fan-out.

## Background

### Prior art and the pattern

- Anthropic's [Building Effective Agents](https://www.anthropic.com/engineering/building-effective-agents) names orchestrator-worker as a core pattern for tasks (coding among them) where subtasks cannot be predicted up front.
- Anthropic's [multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) is the production instance: an Opus lead orchestrating Sonnet subagents, beating single-agent Opus by 90.2% on their eval. It also reports the cost: multi-agent systems use ~15x the tokens of chat, and token usage explained ~80% of eval-score variance, so the pattern is gated to high-value tasks. Critically, the lead "saves its plan to Memory to persist context, since if the context window exceeds 200,000 tokens it will be truncated," and spawns fresh subagents "with clean contexts while maintaining continuity through careful handoffs." The lead treats a large window as a liability to manage, not a feature.
- The credible dissent, Cognition's [Don't Build Multi-Agents](https://cognition.com/blog/dont-build-multi-agents), argues against parallel peers editing shared work blind to each other's decisions, and for sharing full context. It is compatible with memory-offload; it does not license an unbounded single window either.
- [Context rot research](https://www.trychroma.com/research/context-rot) (Chroma, 18 models) shows reasoning quality degrades as input length grows, well before the window limit. A ~964K-token turn is far outside any regime these results call safe, independent of dollar cost.
- Claude Code's own mechanics assume thin-overseer + disposable-subagent: a subagent runs in its own context window and returns only a short summary; `/compact` is meant to run proactively after a meaningful chunk; and a repo-root `CLAUDE.md` is understood to be re-read from disk after compaction, which is the reseed mechanism this proposal leans on (a load-bearing assumption to verify at implementation).

### Current cdocs state (what exists, and the gap)

- The overseer is defined as a behavioral mode in three places: `plugins/cdocs/skills/iterate/SKILL.md`, `plugins/cdocs/skills/propose-revise/SKILL.md`, and `plugins/cdocs/skills/full-send/SKILL.md`. The definitions have already drifted: iterate says dispatch "for all tasks beyond trivial few-liners"; propose-revise says "even trivial ones."
- "Restricts itself to orchestration" is a written instruction with no backing: no tool allowlist constrains the top-level session agent (only dispatched subagents have allowlists).
- Four formal agents exist: `reviewer` (opus), `judge` (opus, no Edit/Bash/Task), `triage` (haiku), `nit-fix` (haiku). There is no formal implementer agent; the implementer is a `general-purpose` subagent.
- Three rule files exist: `workflow-patterns.md`, `writing-conventions.md`, `frontmatter-spec.md`. None mentions context cleanliness, overseer thinness, `/compact`, checkpointing, or durable memory. The only in-plugin occurrence of "compact" is a passing aside in `triage/SKILL.md`.
- Rule *content* is materialized into consuming projects by `/cdocs:init`, which writes `.claude/rules/cdocs.md`, `.opencode/rules/cdocs/`, and an inlined `AGENTS.md` section. The `SessionStart` hook (`hooks/inject-rules.ts`) does not inject content: it sha256-hashes `rules/*.md` and, on mismatch with the consumer's marker, emits a short directive to re-run `/cdocs:init`. In a source repo whose `CLAUDE.md` `@`-imports `plugins/cdocs/rules/`, the rules load directly via those imports and the hook stays silent. A new rule file is auto-covered by the hash and the `.opencode/` glob, but `/cdocs:init`'s AGENTS.md inlining hardcodes exactly three sections (`init/SKILL.md:73-81`), so a fourth rule is hashed-as-stale yet never inlined until that template is updated: a split-brain the phases must handle.
- `iterate` terminates on accept/reject/escalate/interrupt with no retry or context-budget cap. The Iteration Log is already positioned as "the durable resumption point": a fresh overseer reading only the devlog can reconstruct loop state. This is the seam the context discipline builds on.
- clauthier's root `CLAUDE.md` carries no model-default policy; consuming repos set their own (weftwise `main` sets a blanket Opus floor: "do not silently downgrade dispatched work"). This asymmetry is why model tiering belongs in a rule the plugin ships, not only in each consumer's `CLAUDE.md` - though a blanket floor can override the tiering shape (see Pillar 4).

> NOTE(claude-opus-4-8/overseer-alignment): The forensic figures (6.4x growth, ~964K peak, 2.25x overseer/subagent ratio, 59% inline work) come from a `~/.claude/usage.db` analysis of the maintainer's Aug 26-28 2026 sessions.
> They are motivating evidence, not a claim about the plugin in the abstract; the design stands on the prior art regardless.

## Proposed Solution

Four coordinated pieces, all delivered through the existing rule pipeline. The center of gravity is one new rule file that the three overseer-mode skills reference instead of duplicating.

```mermaid
flowchart TD
    R[new rule: orchestration-discipline.md] -->|referenced by| I[iterate]
    R -->|referenced by| PR[propose-revise]
    R -->|referenced by| FS[full-send]
    R -->|@-import| AG[AGENTS.md + SessionStart hook]
    R --> P1[Pillar 1: thin overseer]
    R --> P2[Pillar 2: context cleanliness]
    R --> P3[Pillar 3: durable specialists]
    MT[new rule: model-tiering.md] --> P4[Pillar 4: model tiering]
    MT --> AG
    J[judge remit extended] -->|escalates on| P1
    J -->|escalates on| P2
```

### Pillar 1: Overseer-role enforcement (single source of truth)

Create `plugins/cdocs/rules/orchestration-discipline.md` as the canonical definition of overseer mode, and reduce the per-skill prose to a one-line reference plus any skill-specific carve-out.
The rule states:

- The overseer plans, dispatches, interprets returned summaries, makes cross-cutting decisions, and maintains durable state. It is a router and judgment layer, not a workhorse.
- Dispatch-by-default: any bulk file read, exploratory search sweep, build/test run whose full output is not needed verbatim, or implementation slice goes to a subagent. The canonical carve-out is "trivial few-liners"; a skill may set a stricter bar (propose-revise's "even trivial ones") but never a looser one. This reconciles the existing drift by making iterate's wording the default and propose-revise's the documented exception.
- The overseer never absorbs a subagent's raw file reads into its own window when a returned summary would serve.

Enforcement method (the "Anthropic overseer-role enforcement" the maintainer asked for), in three graded layers:

1. Written rule + a self-check block the overseer is instructed to run at each dispatch decision ("could a subagent do this?").
2. Judge-remit extension (Pillar 2 supplies its signal): the `judge` agent, already fresh each invocation and already assessing loop health, gains an explicit check for overseer-as-workhorse and context bloat. The judge cannot observe the live session: its inputs are the Iteration Log and reviews, by design (no Bash, no `usage.db`). So this backing is only real once the overseer is *required to log* a thinness signal (Pillar 2 names the field); the judge then escalates off that logged field, and a missing field is itself a flagged violation. Absent the logged signal this layer reduces to self-policing, which is why the field is a blocking part of the design, not a nicety. This layer exists only inside `/cdocs:iterate`: `propose-revise` and `full-send` have no judge and fall back to the written self-check plus the optional Phase 6 hook, with no independent enforcer.
3. Optional `PreToolUse` advisory hook (future work, Phase 6): warn when the top-level session issues a run of inline `Edit`/`Write`/`Bash` calls past a threshold. Advisory only, since the hook cannot reliably know whether a session is in overseer mode.

### Pillar 2: Context persistence and cleanliness

The same new rule (or a sibling `context-discipline.md`; see Design Decisions) codifies:

- State lives in files, not the window. At each task-unit boundary (a `task_list` boundary, or an accepted iterate iteration), the overseer writes a handoff into the devlog before compacting: what is done, decisions made, open todos, files touched. The iterate Iteration Log already carries most of this; the change makes the pre-compaction handoff explicit and required, not incidental.
- Compaction cadence: run `/compact` (or `/clear` for a hard reset) proactively at task-unit boundaries, not reactively at the window limit. Target keeping overseer turns under ~150K tokens rather than letting them run to 800K+.
- Legible thinness signal: at each checkpoint the overseer appends to the Iteration Log an approximate current-context estimate and an "inline-work performed this turn" flag (additive columns, permitted by Phase 4's additive-fields constraint). This is the field the judge keys `escalate` off; without it the judge cannot see bloat and Pillar 1's judge layer is inert.
- Reseed via `CLAUDE.md`: rely on the repo-root re-read after compaction to restore overarching context, rather than holding it in live tokens. This reseed is load-bearing for the compaction-cadence guidance and must be verified against current Claude Code behavior (or cited) during implementation: if compaction does not re-read `CLAUDE.md` from disk, "compact aggressively, rely on reseed" loses its safety net.
- Hand-written handoffs are more complete than auto-compaction's lossy summary; the rule says so and the iterate loop enforces the write before the compact.

Wire-in: `iterate` gains an explicit "checkpoint" step at judge-assessment points and after each Accept, and a soft context-budget termination condition (Pillar-1 call-out below).

### Pillar 3: Durable specialists

Formalize the long-lived, named specialist subagent as the way to carry deep per-workstream context without inflating the overseer:

- One specialist per active workstream, resumed by name via `SendMessage`, so the specialist *is* the retained context, addressable rather than re-explained.
- A `fork` subagent is the tool for a side-investigation that needs full parent context without growing the parent thread.
- Keep it one-per-workstream: N parallel large-context specialists recreate the cost problem. The rule states this bound explicitly.

This generalizes a pattern iterate already half-encodes: the implementer is "fresh only when the judge says rotate-implementer" because "an implementer mid-task carries valuable context." That implementer is already a durable specialist; the rule names the pattern and extends it beyond the implement loop.

### Pillar 4: Model tiering

Create `plugins/cdocs/rules/model-tiering.md` codifying default model selection, which no rule currently states:

- Lead / overseer / judgment (reviewer, judge): strong model (opus-class). Orchestration and adjudication are reasoning-heavy; Anthropic deliberately did not cheapen its lead.
- Search, explore, straightforward research-aggregation: sonnet.
- Mechanical, deterministic fan-out (nit-fix, triage): cheapest capable model (haiku), as already assigned.

The tiering shape is advisory: a consumer's explicit model policy always wins. Where a consumer sets a blanket floor (weftwise's "do not silently downgrade dispatched work" forbids exactly the search/explore downgrade), the shape collapses toward that floor unless the consumer opts a tier back down. The intended adoption path is the consumer adding a named carve-out above its floor: weftwise's `CLAUDE.md` doing precisely this ("always use sonnet for search, explore, and research aggregation") is the model. The rule ships those carve-outs as ready-to-adopt guidance rather than as an automatic override, resolving the asymmetry where the tiering intent lived only in each consumer without clauthier dictating a downgrade a consumer's floor forbids.

### cdocs patterns that must change

- `iterate`, `propose-revise`, `full-send`: replace duplicated overseer-mode paragraphs with a reference to `orchestration-discipline.md`; keep only skill-specific carve-outs. Removes the drift vector at its source.
- `iterate` uncapped loop: add a soft cap and a context-budget-aware termination. The judge may `escalate` on excessive rounds or overseer context bloat. This directly targets the marathon-session cost, where a single session ran 68h / 10,600+ turns with no built-in reset pressure.
- `workflow-patterns.md` "Subagent-Driven Development" and "Dispatching Parallel Agents": add overseer-thinness and context-discipline cross-references so the tactics inherit the session-level discipline.
- `implement` (top-level mode) and `propose` (top-level mode): affirm they follow the same thinness rule, so the discipline is not iterate-only.
- Model guidance in skill frontmatter (`-m`/`-f` docs): cross-reference `model-tiering.md` so search/explore defaults resolve to sonnet.

## Important Design Decisions

- One new rule file for pillars 1-3 vs two. Pillars 1-3 are one coherent concern (how a long-lived lead behaves), so a single `orchestration-discipline.md` reduces cross-reference overhead and matches how skills consume rules. Model tiering is a separable concern with a different audience (it also governs non-overseer dispatch), so it is its own `model-tiering.md`. Splitting context-cleanliness into its own file is left as an open question if the combined file grows unwieldy.
- Enforcement is graded, not hard. A hard tool-allowlist on the top-level session is not available (it is the user's own session), and a hook cannot reliably detect overseer mode. The durable enforcement is the independent judge plus the written rule, which matches how the plugin already backs the reviewer's constraints ("written instructions backed by container isolation, freshness, and the overseer's freedom to discard").
- Build on the Iteration Log, do not replace it. The log is already the resumption point; making the handoff-before-compact explicit is a smaller, safer change than inventing a new state file.
- Ship through the existing rule-delivery surfaces, correctly identified. No new delivery mechanism, but registration is not "add to the hook": the surfaces a new rule must touch are `plugins/cdocs/AGENTS.md` `@rules/` lines, the source-repo `CLAUDE.md` `@plugins/cdocs/rules/` imports, and `/cdocs:init`'s hardcoded AGENTS.md section template (`init/SKILL.md:73-81`). The `SessionStart` hash and the `.opencode/` copy pick up a new `rules/*.md` file automatically; the manual work is the AGENTS.md inline template and the `@`-import lists.
- Tiering as shape, not hard pins. The plugin ships the tiering shape; consumers keep the right to pin a family. This avoids clauthier dictating a model to every consuming repo while still delivering the intent.

## Edge Cases / Challenging Scenarios

- Overseer legitimately needs to do inline work (a genuine one-liner, or reading a returned summary). The "trivial few-liners" carve-out covers this; the self-check is a prompt, not a prohibition.
- Compaction loses fidelity the handoff did not capture. Mitigated by requiring the hand-written handoff before the compact, and by `CLAUDE.md` reseed. The rule warns that auto-compaction alone is insufficient.
- Durable specialist proliferation. If a session spins up many specialists, cost regresses. The rule bounds it to one-per-workstream and the judge can flag violation.
- Cross-target degradation (OpenCode). Two different things degrade differently. Rule-*content* delivery degrades cleanly by construction: `/cdocs:init` already globs rules into `.opencode/rules/cdocs/`, so the two new rule files ship to OpenCode automatically. Only the *runtime* mechanics degrade: if a target lacks `SendMessage`/`fork`/`/compact` equivalents, the durable-specialist and compaction mechanics fall back to "start a fresh session with the handoff doc." The rule states both so neither is silently broken off-Claude-Code.
- Soft loop cap causing premature escalation. The cap is a judge input, not a hard kill; the judge weighs it against progress, preserving the existing accept-or-escalate contract.
- Enforcement hook false positives (Phase 6). Advisory-only output avoids blocking legitimate inline work.

## Test Plan

Mostly documentation and prompt-behavior changes, so verification is a mix of static checks and dispatched-agent behavioral probes.

- Rule delivery: confirm `/cdocs:init` materializes the two new rules into `.claude/rules/cdocs.md`, `.opencode/rules/cdocs/`, and the inlined `AGENTS.md` section (after its hardcoded template is extended), and that the `SessionStart` hook reports "stale" before re-init and stays silent after, using the existing rule-delivery regression approach (`cdocs/devlogs/2026-05-12-rule-delivery-regression-test.md`). Explicitly test the split-brain: a new rule hashed-but-not-inlined must be caught.
- Drift removal: grep the three skills to confirm no duplicated overseer-mode definition remains, only references plus carve-outs.
- Judge remit: dispatch the updated `judge` against a synthetic Iteration Log carrying the new thinness columns set to (a) an inline-work run and (b) a rising context estimate, and confirm it returns `escalate` with the right rationale; against a healthy log, confirm it does not; against a log missing the columns entirely, confirm the omission is flagged rather than silently passed.
- Model tiering: confirm search/explore dispatch guidance resolves to sonnet in the updated skill frontmatter and `model-tiering.md`.
- Behavioral probe: run an `iterate` loop on a small real proposal and confirm the overseer writes a handoff before compacting and keeps turns lean (inspect the devlog + a usage.db turn-size check).

## Verification Methodology

Reuse the plugin's own `iterate` loop as the harness: implement each phase, then dispatch a fresh `/cdocs:review` (the author-checklist step already requires this) and, for the judge and rule-delivery phases, a dispatched behavioral probe rather than a self-graded read.
For the context-discipline claim specifically, verify empirically: run one real overseer session under the new rule and confirm from `~/.claude/usage.db` that per-turn overseer cache-read stays bounded (target under ~150K) across the session, reproducing the forensic measurement method on the changed baseline.
A post-change measurement is only trusted if the pre-change baseline was shown to reproduce the bloat.

## Implementation Phases

Phases 1-5 are the core and are largely independent given Phase 1 lands first; Phase 6 is optional future work.

### Phase 1: Author `orchestration-discipline.md` and register it
- Write the rule (pillars 1-3) under `plugins/cdocs/rules/`.
- Register at the real surfaces: add `@rules/orchestration-discipline.md` to `plugins/cdocs/AGENTS.md`; add the `@plugins/cdocs/rules/orchestration-discipline.md` import to the source-repo `CLAUDE.md` (clauthier, and document the same for other source consumers); and extend `/cdocs:init`'s hardcoded AGENTS.md section template (`init/SKILL.md:73-81`) with a new `## CDocs Orchestration Discipline` section so the rule is actually inlined for marketplace installs.
- Close the split-brain: the `SessionStart` hash and `.opencode/` glob pick the file up automatically, so without the template edit the hook nags "stale" but the content never materializes.
- Success: `/cdocs:init` in a scratch project materializes the rule into all three targets; the hook reports stale before re-init and silent after; source-repo `@`-import resolves.
- Do NOT modify the three overseer skills yet (Phase 3 depends on the rule existing first).

### Phase 2: Author `model-tiering.md` and register it
- Write the tiering rule; register at the same real surfaces as Phase 1 (AGENTS.md `@rules/`, source-repo `CLAUDE.md` import, and a new `## CDocs Model Tiering` section in `/cdocs:init`'s AGENTS.md template).
- State precedence explicitly: a consumer's model policy wins; the shape is advisory and adopted via named carve-outs (Pillar 4).
- Cross-reference from skill `-m`/`-f` frontmatter docs.
- Success: `/cdocs:init` materializes the rule into all three targets; search/explore guidance resolves to sonnet where a consumer adopts the carve-out.

### Phase 3: Reduce skill prose to references (drift removal)
- Edit `iterate`, `propose-revise`, `full-send` to reference `orchestration-discipline.md`, retaining only skill-specific carve-outs.
- Success: no duplicated overseer-mode definition remains; the "trivial few-liners" vs "even trivial ones" drift is resolved to rule-default-plus-exception.
- Constraint: preserve each skill's existing role table and audit-trail semantics; this phase changes wording sourcing, not loop behavior.

### Phase 4: Wire context discipline into `iterate`
- Add the explicit handoff-before-compact checkpoint at judge-assessment points and after each Accept; add the soft context-budget termination as a judge input.
- Add the additive Iteration-Log columns that make thinness legible: an approximate current-context estimate and an "inline-work performed" flag, written by the overseer each checkpoint.
- Extend the `judge` agent's remit to key `escalate` off those columns (rising context trend, or a run of inline-work turns), and to flag their absence.
- Success: behavioral probe shows checkpoint writes, correct judge escalation on a synthetic log with the columns set to bloat, no escalation on a healthy log, and a flag when the columns are missing.
- Constraint: do not change the accept/reject/escalate/interrupt contract or the Iteration Log schema beyond these additive fields.

### Phase 5: Formalize durable specialists + cross-references
- Document the durable-specialist pattern in `orchestration-discipline.md` (resume-by-name, fork, one-per-workstream, degradation fallback).
- Add cross-references from `workflow-patterns.md` and affirm top-level `implement`/`propose` thinness.
- Success: the pattern is discoverable from the workflow rule and the implement/propose skills without re-explaining it.

### Phase 6 (optional / future work): Advisory enforcement hook
- Prototype a `PreToolUse` advisory that warns on long runs of inline `Edit`/`Write`/`Bash` from the top-level session.
- Success: fires on a synthetic workhorse run, stays silent on normal dispatch; advisory-only, never blocking.
- Flagged as future work: value depends on reliably approximating overseer mode, which is uncertain.

## Open Questions

- Should context-cleanliness be split from `orchestration-discipline.md` into its own `context-discipline.md`? Deferred until the combined file's size is known after Phase 1.
- What is the right default soft loop/round cap for `iterate`, and should it be turns, tokens, or iterations? Needs one empirical calibration pass against real loops before pinning a number.
- Does OpenCode expose adequate `fork`/resume/compaction equivalents, or does the durable-specialist pattern degrade to fresh-session-plus-handoff there? Requires a cross-target capability check (parity docs exist under `cdocs/devlogs/2026-03-13-parity-*`).

### Round-1 review clarifications, resolved with recommended defaults
These are the maintainer's calls; the proposal proceeds on the recommended default and flags them for confirmation.
- **Judge bloat signal (review A):** recommended a combined signal - the overseer logs both an approximate per-checkpoint context estimate and an inline-work flag, and the judge escalates on trend or a run. Rejected: giving the judge a read-only `usage.db` probe (breaks its no-verification remit for marginal gain).
- **Tiering vs consumer floor (review B):** recommended consumer-floor-always-wins with the shape advisory, adopted via named carve-outs. This matches weftwise having just added a sonnet-for-search carve-out above its Opus floor.
- **One rule file vs split (review C):** recommended one `orchestration-discipline.md` now, splitting `context-discipline.md` only if it grows unwieldy (tracked as the first Open Question above).
