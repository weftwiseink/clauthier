---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-10-05T00:00:00-07:00
task_list: meta/chat-record-devlog-management
type: proposal
state: live
status: request_for_proposal
tags: [meta, tooling, context_persistence, hooks, chat-record, orchestration]
---

# Tiered / Per-Workstream Chat Records

> BLUF(sonnet-5/chat-record-devlog-management): The accepted chat-record proposal is top-level only (rule text, with a scoped `PreToolUse` fallback); this RFP scopes whether and how dispatched agents' activity — and optionally attributed subagent notes (e.g. `@sonnet-5 (reviewer)`) — should be recorded in, or linked from, the top-level record.
> Motivated By: `cdocs/proposals/2026-09-22-chat-record-devlog-management.md` ("Top-level only" section), `cdocs/reports/2026-09-22-chat-record-scratchpoint-design.md` (Question 1), `cdocs/reports/2026-10-05-chat-record-design-history.md` (rejected per-workstream directory layout).

## Objective

The chat record is deliberately scoped to the top-level session: `agent_id` guards hook mode, and rule text (plus a named `PreToolUse` fallback) tells dispatched agents and forks never to call `chat-record note`. This leaves dispatched agents' activity — implementer legs, reviewer passes, judge verdicts — visible only through dispatch briefs and Dispatch/Return Events tables the overseer already writes, not through the chat record itself. Determine whether a tiered or per-workstream extension is worth building, and if so, how it correlates subagent activity with the top-level record without reopening settled design decisions (the rejected per-workstream directory layout, the top-level-only Stop-check guard).

## Scope

A future proposal elaborating this RFP should explore:

- **Correlation mechanism.** `SubagentStart`/`SubagentStop` hooks (verified-not-relied-on today per the design-history report) vs. the scoped `PreToolUse` deny's existing `agent_id`/`agent_type` visibility — which gives the top-level record enough signal to link a subagent leg without the rejected `cdocs/_chat/<task_list>/` directory-per-workstream layout.
- **Sourcing content.** Whether a per-workstream pointer derives from the dispatch brief and return summary the overseer already produces (iterate's Dispatch/Return Events tables), or whether this would duplicate that existing bookkeeping — and if so, which one is kept.
- **Attributed subagent notes.** Whether a dispatched agent should write a note attributed to it (e.g. `@sonnet-5 (reviewer)`) for a higher-level agent to curate. The chat record is append-only and single-writer by design; a curation step that lets a higher-level agent edit or fold in subagent notes is in tension with that. Scope who (if anyone) curates, and whether curation is compatible with append-only.
- **Pointer vs. nested content.** Whether the top-level record gets an index/pointer entry per dispatched leg, or captures subagent content directly — the former preserves the existing single-writer/append-only shape more cleanly.
- **Must not reopen:** the top-level `Stop` check's false-pass risk (a subagent's note landing in the top-level record and satisfying the overseer's own per-turn check) is already guarded by rule text and the named `PreToolUse` fallback. Any tiered design must preserve that guard, not relax `agent_id` scoping in a way that reintroduces the false pass.

Suggest gathering usage evidence from the accepted proposal's Phase 1-2 rollout (actual overseer/subagent dispatch volume and friction) before elaborating this RFP into a full design.

## Open Questions

- Is `SubagentStart`/`SubagentStop` reliable enough to build on, given it was verified-not-relied-on in the current design (design-history report)?
- Does this need its own canary/proposal cycle? (It is a separate scope from chat-record.)
- If attributed notes are adopted, what is the minimal curation step that doesn't violate single-writer/append-only (a separate curated file? a compaction-time fold-in? no curation, pointer-only)?
