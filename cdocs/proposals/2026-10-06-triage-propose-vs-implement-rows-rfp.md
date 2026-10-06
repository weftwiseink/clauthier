---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T12:25:00-07:00
task_list: cdocs/triage-loop-lookup
type: proposal
state: live
status: request_for_proposal
tags: [triage, iterate, full_send, devlog]
---

# Triage: Propose-Loop Rows vs Implementation Rows

> BLUF(opus-5-5/cdocs/triage-loop-lookup): When propose-revise and iterate share one top-level devlog (as `/cdocs:full-send` does), triage can read a propose-revise `accept` row as the implementation loop's accept; decide the lightest way to tell them apart.
>
> - **Motivated By:** [`2026-10-06-review-of-devlog-ownership-rework-r2.md`](../reviews/2026-10-06-review-of-devlog-ownership-rework-r2.md)

## Objective

Triage reads a proposal's latest loop verdict from the Iteration Log of its top-level devlog.
A full-send logs its proposal-review rounds and its implementation rounds in the same table, so a proposal-review `accept` can look like an implementation accept and push a `[STATUS] implementation_accepted` recommendation too early.

## Scope

- Whether triage can rely on the proposal's own `status` (an `implementation_ready` proposal cannot have an accepted implementation from proposal-review rows alone) instead of any new row marker.
- Otherwise the lightest distinction: a row label convention, a separate table, or the review path (`review-of-<proposal>` vs `-impl-` reviews).

## Open Questions

- Is this observed in practice, or only possible? Check triage runs on existing full-send devlogs.
