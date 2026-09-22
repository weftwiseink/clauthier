---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-22T10:34:02-07:00
task_list: meta/chat-record-scratchpoint-design
type: devlog
state: live
status: wip
tags: [meta, tooling, agent-memory, orchestration, context_persistence]
---

# Chat Record and Scratchpoint Design: Devlog

## Objective

Produce `cdocs/reports/2026-09-22-chat-record-scratchpoint-design.md`, a structured cdocs report resolving (not merely surveying) whether a "chat record" plus "scratchpoint" mechanism should be built to durably preserve execution context, with the goal of negating the utility of Claude Code's native `/compact` entirely.
The report had to answer four specific questions the maintainer posed: organization/scoping, prior art beyond what an earlier devlog-value report already cited, a duplication check against existing harness/repo mechanisms, and a concrete phased design.

## Plan

1. Read the three evidentiary reports named in the task: `2026-09-20-token-spend-by-role.md`, `2026-09-20-read-source-attribution.md`, `2026-09-19-devlog-methodology-value.md`.
2. Read the existing orchestration precedent: `plugins/cdocs/rules/orchestration-discipline.md` and `plugins/cdocs/rules/oversee-arc.md`, plus `plugins/cdocs/skills/devlog/SKILL.md` and `plugins/cdocs/rules/writing-conventions.md`.
3. Grep the repo for existing hook plumbing (`plugins/cdocs/hooks/`) and any prior in-repo proposal on this exact topic (found `cdocs/proposals/2026-09-01-devlog-autoflush-hook.md`, an open, un-implemented proposal directly relevant to whether a hook can force a devlog/scratchpoint write).
4. Run two targeted web searches for prior art specifically on checkpoint/scratchpad patterns as compaction alternatives (not general agent-memory taxonomies, which the devlog-value report already covers).
5. Load the `cdocs:report` skill and its template, and `plugins/cdocs/rules/frontmatter-spec.md`, to get frontmatter and structure right.
6. Write the report with a BLUF, resolve each of the four questions explicitly, and run `cdocs:nit-fix` on it before committing.
7. Commit the report and this devlog as separate conventional commits.

## Research Notes

- The evidentiary reports already named the two mechanisms in different words: the token-spend report's workstream 1 ("Execution-context preservation") proposes "auto-append every user message on send" (the chat record) and "dense per-turn agent summary... distinct from the decision-focused devlog" (the scratchpoint), plus "chapter turning / conscious compaction" (the compact-wrap idea). Making this mapping explicit up front let the report ground the topic in already-existing repo work rather than treating it as novel.
- Found a real, narrow precedent for scratchpoint already shipped in this repo: `orchestration-discipline.md`'s "Judge-Observable Thinness Signal" has the overseer append a per-turn context-estimate and inline-work flag to the Iteration Log every turn. This let the report frame the proposed scratchpoint as a generalization of an existing mechanism (same additive-append-per-turn shape) rather than a new artifact category, which was the sharpest resolution to the "is this a generalization of the Dispatch/Return Events table" sub-question the maintainer asked. The actual answer ended up being: generalization of the *pattern*, applied to a *different layer* (working-context vs. orchestration bookkeeping), not a generalization of either existing artifact.
- Web search 1 ("scratchpad" checkpoint compaction alternative) surfaced concrete, non-redundant precedent: a dev.to piece explicitly stating scratchpad and checkpoints are "complementary: use the scratchpad for intra-session coordination, checkpoints for cross-session persistence," and an arXiv paper "Self-Compacting Language Model Agents" (2606.23525) specifically about agent-directed compaction rather than generic memory.
- Web search 2 (PreCompact hook + devlog checkpoint) surfaced a shipped open-source implementation of candidate (b), `mvara-ai/precompact-hook`, described as firing "at the death boundary" and interpreting what is about to be lost. Also surfaced three GitHub issues load-bearing for the design: `#13572` (PreCompact not reliably firing on manual `/compact`, a reliability caveat that argues for `/compact [instructions]` as primary and a `PreCompact` hook as secondary), `#71803` (agent-invokable compaction is a requested but unshipped feature), and `#14258` (a `PostCompact` hook is requested but unshipped). These bound what Phase 3 of the design can assume.
- The hardest part of the report to resolve honestly was Q3 (is wrap-`/compact` alone sufficient, making scratchpoints redundant). Resolved by grounding it in this repo's own numbers: `orchestration-discipline.md`'s devlog-handoff cadence is "every 3 to 5 iterations... OR whenever a judge invocation completes," which means a `/compact`-wrap pointed only at the devlog is only ever as fresh as the last such boundary. A compaction event firing mid-boundary still loses up to a task unit's worth of work. That is the concrete, cited reason the two mechanisms are not redundant: compact-wrap is the delivery mechanism, chat record/scratchpoint are the capture mechanisms, and the devlog alone is too coarse a capture source to make wrap-`/compact` sufficient by itself.
- Cross-checked that this doesn't duplicate the memory tool or CLAUDE.md reinjection: grepped the whole repo for "memory tool" / `memory_20250818` / `clear_tool_uses` and confirmed the memory tool is referenced only in passing (a Gemini CLI parity note, the read-source report's own caveat) and is not wired into any hook/agent/skill in this repo. CLAUDE.md reinjection restores static discipline, not dynamic session state, so it is orthogonal rather than duplicative.

## Changes Made

| File | Description |
|------|-------------|
| `cdocs/reports/2026-09-22-chat-record-scratchpoint-design.md` | New report: resolves organization/scoping, prior art, duplication check, and a phased minimal-mechanism design for chat record + scratchpoint as a `/compact`-negating durable-checkpoint mechanism |
| `cdocs/devlogs/2026-09-22-chat-record-scratchpoint-research.md` | This devlog |

## Verification

- Report written to the exact path specified, using the `cdocs:report` skill's template and `frontmatter-spec.md` conventions (verified frontmatter fields: `first_authored`, `task_list`, `type: report`, `state: live`, `status`, `tags`).
- Ran a `cdocs:nit-fix` pass on the report for writing-convention compliance (em-dash usage, sentence-per-line, direct links, BLUF format) before committing; its findings were folded in prior to the commit below.
- No code was written or tested; this is a research/report task. Verification is limited to confirming the report answers all four posed questions with a stated position (not a survey), cites the three named source reports without re-deriving their numbers, and that all four external precedent links resolve to real, distinct sources found via the two web searches (not fabricated).
