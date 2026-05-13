---
review_of: cdocs/proposals/2026-05-13-iterate-skill.md
first_authored:
  by: "@claude-opus-4-7"
  at: 2026-05-13T14:15:00-07:00
task_list: cdocs/iterate-skill
type: review
state: live
status: done
tags: [fresh_agent, rereview_agent, iterate_skill, round_3, judge_role, design_revision, consistency_check]
---

# Review (Round 3): Proposal for `/cdocs:iterate` Skill

## Summary Assessment

Round 3 evaluates a non-trivial design revision: the heuristic `blocking_count` machinery (flat/decreasing/oscillating predicates plus `--max-flat-iterations`) is replaced by a Judge subagent that periodically assesses loop meta-health and returns `{continue, rotate-implementer, escalate}` with a written rationale.
The revision is internally consistent, the Judge role is well-specified, and the round-2 accepted-parts remain intact.
The new formal `plugins/cdocs/agents/judge.md` agent is a defensible scope addition (analogous tool-safety concerns to `reviewer.md`), and overhead is bounded by `--judge-after` plus overseer discretion without hard caps - matching the user's "note but don't over-engineer" preference.
**Verdict: Accept.**

## Section-by-Section Findings (Revision Delta)

### Role Taxonomy and Judge Definition

The fourth role is added cleanly alongside the existing three.
The Judge's one-liner ("reads iteration log entries and recent review documents; does not read source code") is load-bearing and is restated at the agent-toolset level (`Read, Glob, Grep, Write`; no `Edit`, `Bash`, or `Task`).
This separation - reviewer judges the work, judge judges the loop - is sharp and avoids overlap.
**No issues.**

### Loop Protocol and Mermaid Diagram

The mermaid diagram now has an explicit `Decide` state with three branches into Judge (continue, rotate-implementer, escalate).
The Turn N.c prose distinguishes "Revise, review count < `--judge-after`" (loop directly) from "Revise, review count >= `--judge-after`" (dispatch judge).
The diagram and prose are mutually consistent.
The state diagram's `Judge --> Implement: continue` and `Judge --> Implement: rotate-implementer (fresh implementer)` are two edges between the same nodes - same minor visual concern raised in round 2 about `Review --> Implement` double-edges, but the labels disambiguate.
**[non-blocking]** Optional: the round-2 suggestion to introduce a `Decide` state to disambiguate parallel edges is now partially honored by the explicit `Decide`; same treatment for the Judge branches could collapse the two `Judge --> Implement` edges. Not worth blocking on.

### Trigger Rule (`--judge-after`, default 3)

The default is justified in "Important Design Decisions" with explicit cost-framing: a judge call is a fresh opus subagent reading reviews and writing a rationale, so the default plus overseer discretion bounds overhead without an explicit `--max-judges` cap.
The discretionary early-invocation path is described and recorded in the Judge Log's `trigger` column.
The "Asymmetric second-order subagent dispatch" decision now reads consistently: the judge has no `Task` tool, so it cannot dispatch.
The user's specific guidance ("note overhead but don't over-engineer with hard limits") is handled proportionately.
**No issues.**

### Termination Conditions

The four termination conditions (Accept, Reject, judge `escalate`, user interrupt) are complete with the revised model.
The judge's `escalate` verdict is the load-bearing replacement for the prior count-based escalation, and Reject is preserved as a separate pre-empting condition with clear rationale ("the reviewer is already asserting 'the approach is wrong' at the work level, which the judge cannot adjudicate from the loop level").
Story 4 walks the Reject pre-emption cleanly.
**No issues.**

### Audit Trail: Iteration Log + Judge Log

Two-table structure is clean.
The Judge Log's columns (`judge_iteration`, `trigger`, `verdict`, `rationale`, `judge_path`) capture the audit signal the round-2 review's `blocking_count` provided implicitly.
The "rationale inline vs. saved to file" handling is sensible: short rationales fit inline, longer ones get a `judge_path` pointer.
Resumability from the two tables alone is preserved (Edge Cases section restates this).
**[non-blocking]** The Judge Log's `judge_path` directory hint (`cdocs/devlogs/_judge/`) is a new path convention; consider adding it to `frontmatter-spec.md`'s "Media" section in a follow-up if it survives Phase 4 dogfood, or just inline rationales for v1 and defer the directory until needed.

### Formal `judge.md` Agent Addition (Phase 1 Scope)

The author added `plugins/cdocs/agents/judge.md` as a formal agent modeled on `reviewer.md`.
The scope expansion is justified for two reasons:
1. **Tool-allowlist safety**: the judge must not edit code or dispatch subagents. `reviewer.md` exists as a formal agent precisely because the reviewer needs an enforced allowlist (`Read, Glob, Grep, Edit, Write` only, where the `Edit` is the safety-constrained `last_reviewed` frontmatter exception). The judge's constraints are tighter (no `Edit` at all, no `Task`, no `Bash`), and a formal agent file is the existing mechanism for enforcing them.
2. **Model defaulting**: the judge's job (synthesizing across reviews, returning a structured verdict) benefits from opus, the same reason `reviewer.md` declares `model: opus`. A formal agent makes that default explicit and overridable.
The asymmetry with the Implementer (which remains `general-purpose` plus a prompt-level directive) is justified inline: `/cdocs:implement` already encodes the implementer's desired behavior; only the no-double-review constraint is new, and a prompt-level override suffices.
**No issues.** The scope addition is proportionate and parallels existing infrastructure.

### Internal Consistency Pass

- `blocking_count` is fully removed: no matches in the proposal body.
- `--max-flat-iterations`, `flat`, `decreasing`, `oscillating` predicates are fully removed; only one acceptable mention of `--max-judges` exists as an explicit example of over-engineering to avoid.
- Stories 1-6 all align with the new design: Story 1 notes the judge was not yet invoked (review count just reached `--judge-after` but Accept beat it); Story 2 walks the `rotate-implementer` verdict cleanly; Story 3 walks `escalate`; Story 4 preserves Reject pre-emption; Stories 5-6 are unchanged from round 2 and remain consistent.
- Open Questions are in sync: the prior `blocking_count` / oscillation questions are gone; the new Q3 ("judge trigger mode: every-review-after-N vs. once-then-overseer-discretion") is genuinely open and surfaced for dogfood resolution.
- The trailing NOTE retiring the round-2-resolved questions remains correct.
- The "Asymmetric second-order subagent dispatch" decision explicitly lists the judge's no-`Task` toolset, matching `judge.md`'s declared tools.

### Tone Replacement ("hostile" -> "critical")

Grep confirms zero occurrences of `hostile` / `hostility` in the proposal body.
The judge's role description uses "critical mindset" consistently with the user's tonal direction.
The companion report at `cdocs/reports/2026-05-13-agent-roles-and-iterative-loop.md` still contains the older `hostile` phrasing (line 115, "hostile mindset"; line 123 NOTE), but the report predates this proposal and the proposal explicitly extends rather than supersedes it.
**[non-blocking]** Optional cleanup: replace `hostile` -> `critical` in the report during Phase 1 or Phase 2 to keep cross-document tone consistent. Not a blocker because the report is a research artifact, not the user-facing skill.

### Form / Writing Conventions

- BLUF includes the Judge role addition cleanly and the "peer to `/oversee`" framing remains.
- Sentence-per-line: holds throughout the revision.
- Em-dash avoidance: two unspaced em-dashes appear on lines 435-436 in the Phase 4 candidate-target bullets (`— preferred, because...` and `— fallback if...`). Per `writing-conventions.md`, prefer colons or spaced hyphens.
- History-agnostic framing: the proposal reads as if always-Judge; no "we previously had blocking_count" leakage. The one `previously` match is in the trailing NOTE that correctly retires earlier open questions.
- NOTE callout attribution: all NOTEs use `opus/cdocs/iterate-skill` consistently.
- Mermaid: correct.
- Direct links: present and clickable.

**[non-blocking]** Replace the two em-dashes on lines 435-436 with colons or commas.

## Verdict

**Accept.**

The revision is internally consistent, the Judge role is well-specified at both the design and agent-file level, all round-2 accepted parts survive intact, and the user's tonal and overhead-bounding preferences are honored.
The remaining items are minor polish (two em-dashes, optional report-tone sync, optional mermaid edge-collapse).
The proposal is ready to transition to `implementation_ready`.

## Action Items

1. **[non-blocking]** Replace the two em-dashes on lines 435-436 (Phase 4 candidate-target bullets) with colons.
2. **[non-blocking]** Optional: replace `hostile` -> `critical` in `cdocs/reports/2026-05-13-agent-roles-and-iterative-loop.md` to keep cross-document tone consistent.
3. **[non-blocking]** Optional: collapse the two `Judge --> Implement` edges in the mermaid diagram via an intermediate node, mirroring the `Decide` cleanup already applied.
4. **[non-blocking]** Defer the `cdocs/devlogs/_judge/` directory convention until Phase 4 dogfood demonstrates need; for v1, prefer inline rationales.

## Questions for the Author (Multiple Choice)

A. For Open Question 3 (judge trigger cadence after the Nth Revise), which mode should Phase 1 ship with as the default?
   1. Every Revise after the Nth (current spec): conservative, more cost, simpler rule.
   2. Once at the Nth, then overseer discretion: leaner, trusts overseer judgment.
   3. `--judge-after=N --judge-cadence=M` with `M=1` default (equivalent to mode 1): preserves dial for later tuning.

B. For Action Item 2 (report tone sync), preferred path?
   1. Update the report inline during Phase 1.
   2. Add a NOTE callout to the report pointing at this proposal as the canonical tonal source.
   3. Leave the report as-is; the proposal supersedes its tonal choices.
