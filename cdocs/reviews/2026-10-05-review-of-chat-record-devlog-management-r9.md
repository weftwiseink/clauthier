---
review_of: cdocs/proposals/2026-09-22-chat-record-devlog-management.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T11:10:57-07:00
task_list: meta/chat-record-devlog-management
type: review
state: live
status: done
tags: [fresh_agent, directive_compliance, top_level_scoping, minimal_design, test_plan]
---

# Review: Chat Record, Scratchpoint, and Semantic Devlog Splitting (round 9)

> BLUF(opus-5-5/chat-record-devlog-management): Six of the seven maintainer directives are applied cleanly, with no residue in the proposal.
> Directive 5 has one leak: Phase-1 deliverable 6 puts the `note` heredoc form (and `chat-record path`) into the devlog skill, which dispatched implementers follow, so a copy of the instruction ends up away from its scope sentence and Decision 16's premise fails.
> The fix is to delete words, not add a guard.
> All three flagged tensions are acceptable.
> **Verdict: Revise** (one small blocking edit; everything else is a nit).

## Summary Assessment

Round 9 applies seven simplification directives to a design accepted at r8: a frontmatter pointer, marker-order turns, no `@harness`, no init settings edits, a single guard sentence, no agent-side compaction management, and soft Scratchpoint limits.
The result is smaller and more coherent: the `Stop` decision now reads one marker line, and the layer map, `Stop` table, Edge Cases, and Decisions agree with each other.
The one blocking finding: the devlog-skill deliverable carries `chat-record` usage outside the per-turn rule, which contradicts directive 5 and Decision 16.
With that removed, Phases 1-2 can be built from the document alone.

## Directive Verification

Method: I read the full text, grepped for residue (`p=`, `--p`, `.prompt`, `@harness`, `## Chat Record`, `ctx`, `compact`, `permission`, `settings`, `guard`, `agents/`), and reviewed the `7b2633a` diff of the history report.

| # | Directive | Status | Evidence |
|---|---|---|---|
| 1 | `chat_record:` frontmatter, no `## Chat Record` section | applied | Location "Devlog link", Decision 7, resumption steps 1 and 3, deliverables 4 and 6, root-index and chunk rules. `cdocs-validate-frontmatter.sh` only checks required keys, so the new field passes unchanged. |
| 2 | No prompt ids; `Stop` is position-based | applied | No `p=`/`--p`/`.prompt` anywhere. `Stop` table keyed on last marker; Decision 4; mid-turn edge case restated in marker-order terms. |
| 3 | No `@harness`; note required only for human-initiated turns | applied | Speaker table has only `@user` and `@<model-short>`; harness envelopes skipped (Edge Cases); per-turn rule's third sentence; `Stop` row 4. |
| 4 | No init permission/settings edits; README note at most | applied | Non-Goals, "Permissions" paragraph, Decision 11, deliverable 4, Phase-1 constraint. Default-mode tests are marked optional. |
| 5 | Guard only beside the per-turn instruction | **partly**: see Finding 1 | The rule paragraph and Decision 16 are correct, and `agents/*.md` are barred from carrying `chat-record` text. But deliverable 6 adds `chat-record` usage to the devlog skill. |
| 6 | No agent-side compaction asks or context tracking | applied | Non-Goals, Resumption guidance opening, Decision 10, Phase-1 constraint. The only `ctx` hit is the pre-existing `overseer_ctx_est` column, which is preserved, not added. See tension (b) for Phase 3. |
| 7 | Scratchpoint limits are "aim for at most" | applied | Scratchpoint intro, Decision 8, Phase 2 item 1 ("soft size"). |

## Section-by-Section Findings

### 1. Phase 1 deliverable 6 and Decision 16: `chat-record` usage outside the scope sentence. **Blocking.**

Deliverable 6 has `plugins/cdocs/skills/devlog/SKILL.md` gain "the `chat_record:` field and how to fill it (`chat-record path`), the heredoc `note` form, the four categories".
The devlog skill is the one place in cdocs that dispatched agents routinely follow (the implementer agent does "devlog tracking").
The result is a second copy of the per-turn mechanics with no scope sentence next to it, which is the leak directive 5 accepts only because "the sentence sits beside the per-turn instruction, so every reader of the instruction reads the scope" (Decision 16).
A subagent that reads the skill and not Pillar 2 would run `note`. Per the Top-level-only section, that note lands in the top-level record and satisfies its `Stop` check.
`path` is read-only and harmless, but it still contradicts the guard's "never run `chat-record`".

The minimal fix removes text:
- Have the devlog skill state only that `chat_record:` exists and is maintained per Pillar 2.
- Keep the heredoc form, the categories, and `chat-record path` in the Pillar 2 paragraph and steps, which carry the scope sentence.

Adding a guard copy to the skill would break directive 5 the other way.
Optionally, extend the Phase-1 constraint "`plugins/cdocs/agents/*.md` gain no `chat-record` text" to cover `skills/*/SKILL.md` and `template.md`.

### 2. Summary: "so the record carries no correlation tokens". Non-blocking.

This line answers a question that only a reader of earlier rounds would ask, and Decision 4 already says it.
Drop the clause from the Summary (one place per fact; the history report holds the `p=` rejection).

### 3. Non-Goals vs Phase 3 on "tracks context usage". Non-blocking.

Non-Goals says "nothing here ... tracks context usage", while Phase 3 caps on the specialist's harness-reported usage.
Narrow the non-goal to the agent's *own* context usage, or add "(Phase 3's dispatch-level cap reads a specialist's reported usage)", so the two do not read as contradictory.

### 4. Gist count wording. Non-blocking.

"One to three bullets per turn" reads as a cap, which sits awkwardly beside the rule's "at least one" and the maintainer's guidelines-over-caps preference.
"Aim for one to three" matches the directive-7 phrasing.

### 5. Block text "real values substituted". Non-blocking.

The hook knows the record path but not the model ("no hook payload carries a model"), so `<your model>` stays literal.
Say which values are substituted (the path) and that `<your model>` and `<what a successor...>` are left for the agent.

### 6. Harness turn after an unsigned human turn. Non-blocking.

If a human turn ends without a `Stop` (interrupted, if check (b) shows `Stop` does not fire), its `@user` stays the last marker.
The next harness-initiated turn's `Stop` then blocks, asking the agent to note a turn it did not start.
This is benign, since the note covers the abandoned turn, and it never loops.
One sentence in the Interrupted-turn edge case would spare the implementer from rediscovering it.

### 7. History report stale row. Non-blocking (report, not proposal).

In Rejected Approaches, the `n=` row's rationale still reads "the devlog's `## Chat Record` pointer records the last handoff time instead", but that section is now itself rejected.
Reword the row to something like "turn order is positional; no ordinal is needed".

## Flagged Tensions

- **(a) Default-mode `note` denial documented only in the README: acceptable.**
  The failure is visible and bounded: interactively it prompts, and the user can always-allow. Headless, the one-shot block plus `stop_hook_active` gives `@user` then sign-off, with no loop.
  The design does not depend on default mode, the README line is the minimal remedy directive 4 permits, and the optional default-mode tests document it.
- **(b) Phase-3 cap on harness-reported specialist usage: acceptable, consistent with directive 6.**
  Directive 6 forbids an agent asking the user to compact, or tracking and reporting *its own* context.
  Phase 3 has the overseer read a *dispatched* specialist's usage from the harness and reseed by dispatch, with no compaction involved and no self-report.
  It is also gated on the Phase-2 A/B. Only the Non-Goals wording needs narrowing (Finding 3).
- **(c) One `Stop` per top-level turn; mid-turn prompts unverified: acceptable.**
  One `Stop` per turn is Phase-0 evidence.
  Under the position-based check, either outcome of interactive check (d) produces a well-formed record: two `@user` blocks followed by a note and a sign-off, or two ordinary turns.
  Neither outcome can loop or produce a wrong block.
  It is correctly listed as owned by Phase 1.

## Implementability (Phases 1-2)

An implementer can build Phase 1 from the document:
- **Script modes:** the four modes, their invocations, and their behavior.
- **Grammar and parsing:** the two regexes, the escape and parse-order rules, and the session-token derivation.
- **`Stop` decision table:** four rows, with the guards and silent-exit conditions listed separately.
- **Errors and appends:** the exit-code contract and the append invariant.
- **Tests:** a headless scenario list with concrete assertions, plus unit tests that check the `Stop` table row by row.

The only open item is the interrupt signal, which is explicitly deferred to check (b) with a candidate.
Phase 2 is likewise specified: Scratchpoint fields and writers, the staleness rule mapped to the existing `overseer_thinness: signal_missing`, split trigger, closure test, cut and merge rules, naming, the Chunks table, `part_of`, and an A/B with a pass bar.

## Verdict

**Revise.** One blocking edit (Finding 1): remove the `chat-record` mechanics from the devlog-skill deliverable so the scope sentence is the only reader-facing home of the instruction.
The edit is subtractive and needs no re-review of the rest.
After it, the proposal is acceptable.

## Action Items

1. [blocking] Phase 1 deliverable 6: drop "how to fill it (`chat-record path`), the heredoc `note` form, the four categories" from the devlog skill; the skill names `chat_record:` and defers to Pillar 2. Optionally extend the Phase-1 "no `chat-record` text" constraint to skills and templates.
2. [non-blocking] Summary: delete "so the record carries no correlation tokens" (Decision 4 covers it).
3. [non-blocking] Non-Goals: scope "tracks context usage" to the agent's own context, so it does not contradict Phase 3's cap.
4. [non-blocking] Gist entries: "aim for one to three bullets".
5. [non-blocking] Block text: state that only the record path is substituted; `<your model>` stays for the agent.
6. [non-blocking] Interrupted-turn edge case: note that an unsigned `@user` makes the next harness turn's `Stop` block once.
7. [non-blocking] History report: fix the `n=` row's rationale, which still cites the rejected `## Chat Record` section.
