---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-22T11:20:00-07:00
task_list: meta/token-spend-attribution
type: devlog
state: live
status: wip
tags: [meta, tooling, cost, retrieval, agent-memory, rfp-4]
---

# Shared Cache Redundancy Research: Devlog

## Objective

Test the maintainer's stated skepticism about RFP-4 ("shared retrieval cache across agents and sessions"), first named without a design in the token-spend-by-role report's workstream 3.
Two questions to resolve: (1) has anything like a cross-agent read-dedup mechanism actually worked in production multi-agent coding systems, or is it paper-only; (2) is a dedicated shared-cache mechanism actually redundant with the chat-record/scratchpoint system (RFP-2) being designed in parallel this session.
Produce a report with a clear verdict/recommendation, not just a survey.
Explicitly out of scope: writing a proposal, touching RFP-2's proposal work (a separate agent is doing that in parallel).

## Plan

1. Read background: the read-source-attribution report's "reread waste" section (origin of the 97.4% cross-agent figure), the token-spend-by-role report's workstream 3 (where RFP-4 was first named), the chat-record-scratchpoint-design report (the sibling RFP-2 the maintainer thinks might make this redundant), and the writing-conventions rule.
2. Confirm the graphify-status framing (stateless, per-call, symbol-scoped; does not dedupe reads) against the accepted graphify report, since the task description leans on it.
3. Web-search prior art in two passes: first broad ("shared cache multi-agent"), then narrowed once the first pass revealed the KV-cache-serving-layer literature was a different problem than the application-layer one being asked about.
4. Follow up on the most concrete leads with `WebFetch` for detail: Headroom (OSS project claiming cross-agent dedup), Hindsight (vendor blog on Claude Code subagent memory), `lean-ctx` (OSS project that implements the literal mechanism inside Claude Code, and has a filed bug about it).
5. Reason precisely through the orientation-vs-token-cost distinction the maintainer's hypothesis conflates, using the read-source report's own "summary re-orients, reviewer needs real content" language as the anchor.
6. Write the report with a clear verdict, write this devlog, commit both.

## Testing Approach

This is a research/report task, not a code change. "Testing" here means evidentiary rigor: every prior-art claim in the report is backed by a fetched source (not just a search-snippet summary), and the redundancy reasoning is grounded in concrete cases (reviewer, exact-edit, judge) rather than asserted abstractly.

## Implementation Notes

- First search pass surfaced a large body of 2026 arXiv papers on "cache sharing across agents" (ForkKV, KVComm, TokenDance, DroidSpeak, Ramp Labs' Latent Briefing). Caught myself before citing these as prior art: they operate at the inference-serving / KV-cache-tensor layer, which requires operating the inference stack. Irrelevant to a Claude Code plugin/convention question; explicitly called out in the report as a category error to avoid, since the vocabulary overlap ("shared cache," "multi-agent") makes it an easy one to make.
- The most valuable single finding came from `WebFetch`ing a GitHub issue, not a blog post: [`lean-ctx` issue #1801](https://github.com/yvgude/lean-ctx/issues/1801). This is a real OSS project (~3.8k stars) that built the literal mechanism (cross-agent cache stubs like `"[cross-agent cache · directory tree · produced by 1 · 492 tokens avoided]"`) and has a live bug report showing it breaks specifically on Claude Code because subagents share the parent's process scope but cannot resolve a stub into content across the context-window boundary. This is strictly better evidence than "nothing exists" (which would leave room for "nobody's tried"): it is "somebody tried the exact thing, on the exact platform, and hit a structural wall."
- Cross-checked Claude Code's own documented behavior (`jsmanifest.com` tool-result-caching article): explicitly states subagent tool-result caches do not cross the subagent boundary. This independently corroborates the `lean-ctx` bug's root cause and is the strongest "the platform itself resists this" evidence.
- Headroom and Hindsight both read as early-stage/marketing-stage on inspection (no adoption evidence, no concrete detection mechanism described), which matters for an honest "is this proven or aspirational" answer, distinct from "does something like it exist in a GitHub repo somewhere" (it does, but existing is not the same as working).
- For the redundancy question, the load-bearing move was refusing to treat "does chat-record/devlog help" as a single yes/no and instead splitting it into the orientation/token-cost table. The read-source report already handed this distinction over almost verbatim ("a summary re-orients an agent, but a reviewer that must actually inspect a file needs its real content"), so the job was applying it precisely rather than discovering it fresh.

## Changes Made

| File | Description |
|------|-------------|
| `cdocs/reports/2026-09-22-shared-retrieval-cache-redundancy-check.md` | New report: prior-art survey and redundancy verdict for RFP-4 |
| `cdocs/devlogs/2026-09-22-shared-cache-redundancy-research.md` | This devlog |

## Verification

Report and devlog written and reviewed for internal consistency against the three background documents and the writing-conventions rule (BLUF format, direct HTTP links for external references, history-agnostic framing, sentence-per-line). No code changes, no build/test suite applicable. The report's verdict (drop RFP-4 as a standalone mechanism, fold the awareness-only subset into RFP-2, watch-list the rest) is a recommendation for the maintainer to act on, not a completed implementation; that is the correct terminal state for a report-only task.
