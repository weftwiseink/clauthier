---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-23T08:34:54-07:00
task_list: meta/chat-record-redaction
type: proposal
state: live
status: request_for_proposal
tags: [meta, tooling, security, chat-record, context-management]
---

# General Redaction / Secret-Scanning for Committed cdocs Artifacts

> BLUF(sonnet-5/chat-record-redaction): Decouple general redaction/secret-scanning from the chat-record proposal — chat-record ships commit-by-default with no redaction pass, and this RFP scopes a separate, general mechanism to catch credentials/secrets before they land in git, applicable to chat-record and any other cdocs artifact that captures agent/tool output verbatim.
> Motivated By: `cdocs/proposals/2026-09-22-chat-record-devlog-management.md` (decided commit-by-default, no redaction, per maintainer 2026-09-23), `cdocs/reviews/2026-09-22-review-of-chat-record-devlog-management.md` (flagged the leak-channel risk: assistant bodies and compaction summaries can carry pasted secrets/credentials).

## Objective

The chat-record system (and potentially other cdocs artifacts that capture verbatim tool/agent output — Bash results, pasted logs, `compact_summary` text) commits to git by default. Verbatim capture means anything pasted or produced mid-session — a credential in a config dump, an API key in an error message, a token in a URL — can land in a committed file. The maintainer explicitly deferred redaction from the chat-record proposal itself (accepted the exposure for now) and asked for this to be scoped as its own general mechanism rather than a one-off regex bolted onto one hook.

## Scope

A future proposal elaborating this RFP should explore:
- Whether scanning belongs at capture time (in the writing hook, before a line ever reaches disk) or at commit time (a pre-commit-style scan over staged `cdocs/` changes), or both.
- What "general" means in practice: a shared secret-pattern library (reusable across chat-record, devlog capture, any future verbatim-capture surface) vs. a chat-record-specific pass.
- False-positive/false-negative tolerance: a scanner that's too aggressive corrupts legitimate content (a devlog quoting an API response shape); too permissive defeats the purpose.
- Whether this should reuse an existing open-source secret-scanning tool (e.g. gitleaks-style pattern sets) rather than hand-rolling regexes, and how that dependency fits the plugin's existing tooling posture.
- Remediation UX when something is caught: block the write/commit with a clear message, or flag-and-continue with a follow-up task?
- Retroactive scanning: does this also need to sweep already-committed chat-record/devlog history, or is it forward-only from adoption?

## Open Questions

- Is this a cdocs-plugin-owned mechanism (ships as part of cdocs) or a `update-config`/harness-level concern (a general Claude-Code-wide safeguard, not specific to this plugin)?
- Does the chat-record proposal's own capture hooks need a scan *hook point* reserved now (even if unimplemented), so this RFP's eventual mechanism doesn't require reopening the chat-record hook contract later?
- Should this block on, or run independent of, the chat-record system's own Phase 1/2/3 rollout?
