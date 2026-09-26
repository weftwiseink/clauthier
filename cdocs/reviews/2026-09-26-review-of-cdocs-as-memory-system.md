---
review_of: cdocs/reports/2026-09-26-cdocs-as-memory-system.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-26T12:00:00-07:00
task_list: cdocs/connectome-research
type: review
state: live
status: done
tags: [fresh_agent, factual_accuracy, source_verified, corpus_numbers, comparison_fairness, internal_consistency, rereview_agent]
---

# Review: CDocs as a Memory System

## Summary Assessment

The report characterizes cdocs as an agent-memory substrate (units, write/read paths, consolidation, identity, coordination) so a later artifact can compare it against Letta/Zep/mem0 and Anima's connectome.
Most source claims check out: quoted rule text, hook behavior for `inject-rules.ts` and the PostToolUse validator, the `/cdocs:status` "~100 documents" ceiling, triage's iterate-devlog step, the claim-registry schema, and the cited report figures all match.
The corpus counts are accurate, but the headline directory sizes are inflated by binary media.
The larger problems are about fairness for the comparison: the report says cold-start cost grows linearly with the corpus, which contradicts its own statement that nothing is loaded at session start. It also treats agent-authored consolidation as absent, and it overstates the PreToolUse hook.
Verdict: **Revise**. The fixes are small and local.

## Verification Log

Everything below was re-derived from the source on 2026-09-26.

| Claim | Result |
|---|---|
| Doc counts: 251 / 740 / 1,979, with per-type splits | Match. This repo now reads 87 devlogs and 45 reports, because this report and its arc devlog were added after the count. Label the counts as a snapshot. |
| ~481K words | 484,418 now. Consistent. |
| Dir sizes: 4.2M / 12M / 200M | Raw `du` matches, but weftwise's `cdocs/_media` is **159M** and its markdown dirs total about 44M. lace `_media` is 552K. |
| `/cdocs:status` "practical up to ~100 documents", with `.index.json` and MCP as future work | Match (`skills/status/SKILL.md:75-78`). |
| Triage reads the last row of the iterate Iteration Log and Judge Log | Match (`skills/triage/SKILL.md:37`). |
| `inject-rules.ts`: sha256, a directive under 500 bytes, silent when uninitialized or fresh | Match. It is also silent in the source repo when `CLAUDE.md` `@`-imports `plugins/cdocs/rules/`. |
| PostToolUse validator is warning-only and limited to the four cdocs dirs | Match. |
| PreToolUse hook "restricts *which* subagents may write to *which* `cdocs/` subdirectories" | **Inaccurate.** See F2. |
| Reviews have "No `status` lifecycle of its own" | **Inaccurate.** See F3. |
| Quotes: "graded, not hard", "PROGRAMMATICALLY", "atomically at the terminal moment", 3-5 iteration cadence, one specialist per workstream, "empirically high" compliance | All present. The last one paraphrases `README.md:84` ("Compliance is high in practice"). |
| 8→4 re-reads and 334K→173K tokens; 13-46KB devlogs; scratchpoint not built | Match. Nothing under `plugins/` mentions scratchpoint. |
| Human authorship is "rare" | It is effectively **zero**: every `first_authored.by` in this repo is a model, apart from the `@MODEL_NAME` template placeholder and `@test`. |

## Section-by-Section Findings

### BLUF

- **F1 [blocking] The read path is described three different ways.** The BLUF says there are "three layered mechanisms". Read/Retrieval opens with "four independent, layered mechanisms" and then numbers five items. Pick one count. Five is defensible, or four if handoff/arc-state is treated as a separate compaction concern.
- **F4 [blocking] The cold-start claim contradicts the body.** The BLUF says "cold-start cost grows roughly linearly with corpus size", and Weaknesses repeats it. Units of Memory says "None of this is loaded at session start by default". The session-start cost is roughly constant: materialized rules plus a hook that is usually silent. The O(N) cost applies only when `/cdocs:status` or `/cdocs:triage` runs a full-scan query, or when an agent greps widely. The report should split these cleanly as "constant cold-start, O(N) enumerative query". For a Letta/Zep comparison this distinction matters: those systems pay a per-turn retrieval cost, while cdocs pays nothing until someone queries.
- **F5 [blocking] The headline sizes count images as memory.** 200M for weftwise is mostly `_media` (159M). Report markdown-only sizes, or state that `_media` is included, in the BLUF, the corpus table, and Weaknesses. Otherwise a comparison diagram will overstate the corpus by roughly 4.5x.

### Units of Memory

- **F3 [blocking] Reviews do have a lifecycle.** The review skill instantiates reviews at `status: wip` and sets them to `done` on completion (`skills/review/SKILL.md`, "Template"). `frontmatter-spec.md` also lists `wip` and `done` as "All types". The accurate distinction is that reviews carry no `last_reviewed` and their verdict propagates to the subject. Fix the table row, because it will feed the diagram.
- [non-blocking] The corpus table is a point-in-time snapshot. Add "as of 2026-09-26, before this report".

### Who Writes, and Write Triggers

- **F2 [blocking] The PreToolUse hook is overstated.** `validate-cdocs-edit-path.sh` confines three subagent types (`triage nit-fix reviewer`) to the union of `cdocs/{devlogs,proposals,reviews,reports}/`. It does not scope per subdirectory, so a reviewer may write a proposal. The main session, `implementer`, and `proposer` are unrestricted. The accurate framing is: "a coarse sandbox keeping doc-maintenance agents out of source code, not role-to-directory write ACLs".
  Carry the same correction into Auditability, which calls this "path-scoped write restriction ... enforced at write time".
  An open question the report could flag: the guard matches bare names (`reviewer`), while plugin agents dispatch as `cdocs:reviewer`. If `agent_type` arrives namespaced, the guard never fires. This review did not verify the runtime value, but it bears directly on the "enforcement vs. compliance" weakness.
- [non-blocking] "Human authorship is possible ... but rare" should be "absent at the `first_authored` level in this corpus". The more interesting point for the connectome comparison is that human steering (prompts, the user's direction) is real but invisible in provenance. The memory records the agent that typed the document, not whoever caused it. That makes the "no human/agent trust tier" observation stronger, not weaker.

### Read / Retrieval Path

- [non-blocking, fairness] "No backlink index" and "cross-document linking is manual" undersell cdocs slightly. `review_of`, `last_reviewed`, and a shared `task_list` are typed, machine-parseable edges, so the corpus is an implicit typed graph. Nothing materializes it, but it can be recovered with one grep. Say this directly, because it is the natural point of contact with connectome/Zep-style graph memory.
- [non-blocking, fairness] "Never ranked" is true of the substrate, but the actual retriever is an LLM running agentic grep/glob. That is the same design Claude Code chose over vector RAG. Compared with embedding retrieval, its failure mode is recall limited by the query vocabulary, not the absence of relevance judgment. One sentence making that distinction would prevent the comparison from reading as "cdocs = no retrieval".
- [non-blocking] Item 1 is correct for consumer repos. In this source repo, root `CLAUDE.md` `@`-imports `plugins/cdocs/rules/*` directly, and the hook skips itself (`inject-rules.ts:35`). Worth a clause, since the report counts this repo's corpus.

### Consolidation and Forgetting

- **F6 [blocking, fairness] Consolidation exists; it is just not automatic.** The section and its Weaknesses bullet say there is no consolidation. But reports are, by definition, agent-authored consolidations of devlogs and reviews: this report, `devlog-methodology-value.md`, and `devlog-token-value-analysis.md` are all examples. Devlog handoffs are mandated consolidation, and an `evolved` proposal plus its successor is supersession. The accurate claim is: "consolidation is explicit, agent-triggered, and additive (new synthesis documents plus soft invalidation via `archived`/`evolved`), never automatic or in-place". That maps cleanly onto the comparison: Letta's sleep-time or background memory rewriting is automatic and in-place, and Zep's temporal edge invalidation is automatic soft-invalidation. As written, the report undersells cdocs on exactly the axis the arc is comparing.

### Identity Model

- [non-blocking] This section is fair and well sourced. Two additions would sharpen it.
  (a) `agents/*.md` are persistent, versioned role definitions: a stable persona and tool policy that is read-only to the agent. That is analogous to a Letta persona block the agent cannot self-edit. It is procedural identity, not autobiographical identity, and saying so is more precise than "costumes".
  (b) Cross-project and personal memory does exist in the host harness (user-level `~/.claude/CLAUDE.md`, auto-memory, `memory/MEMORY.md` referenced by the user's dotfiles `CLAUDE.md`), just outside cdocs' scope. The "No cross-project personal memory" weakness should say "cdocs delegates this to the harness" so the comparison does not attribute a harness gap to cdocs, or the reverse.

### Multi-Agent Coordination, Auditability, Strengths

- Accurate against `oversee-arc.md` and `orchestration-discipline.md`.
- [non-blocking] "Tamper-evident" is too strong for a repo whose history can be rewritten. Use "diffable and attributable".
- [non-blocking] Auditability should note that the audit covers the documents, not the reasoning. Chat transcripts are not in git, which is the gap the scratchpoint design targets.

### Frontmatter

- [non-blocking] `first_authored.at: 2026-09-26T00:00:00-07:00` looks like a placeholder time.

## Verdict

**Revise.** The factual base is strong and most quotes verify. Before this feeds a comparison diagram, fix the three internal inconsistencies (mechanism count, cold-start vs. "nothing loaded", media-inflated sizes), the two source inaccuracies (the PreToolUse hook's scope and review status), and the consolidation framing.

## Action Items

1. [blocking] Reconcile the read-path mechanism count (three in the BLUF, "four" in the body, five listed).
2. [blocking] Replace "cold-start cost grows linearly" with "constant session-start cost; O(N) enumerative query cost" in the BLUF and Weaknesses.
3. [blocking] Report markdown-only directory sizes, or annotate that `_media` is included (weftwise: 159M of 200M), in the BLUF, the table, and Weaknesses.
4. [blocking] Correct the PreToolUse description in Write Triggers and Auditability: three doc-maintenance subagents are confined to the four cdocs dirs collectively; there is no per-subdirectory scoping, and implementer, proposer, and the main session are unrestricted.
5. [blocking] Fix the review row: reviews have `status: wip -> done`; they lack `last_reviewed`.
6. [blocking] Reframe consolidation as "explicit, agent-authored, additive (reports, handoffs, `evolved`), not automatic or in-place", in both the section and Weaknesses.
7. [non-blocking] Change "human authorship rare" to "absent in `first_authored`", and note that human steering is invisible in provenance.
8. [non-blocking] Describe `review_of`/`task_list`/`last_reviewed` as implicit typed edges, and describe the retriever as agentic LLM search rather than "no retrieval".
9. [non-blocking] Scope cross-project memory as delegated to the harness; describe `agents/*.md` as persistent, read-only procedural identity.
10. [non-blocking] Mark the corpus counts as a snapshot; soften "tamper-evident"; fix the placeholder timestamp.

## Questions for the Author

1. Should the `cdocs:`-namespaced `agent_type` possibly bypassing the PreToolUse guard be:
   (a) flagged in this report as an unverified enforcement gap,
   (b) split into a separate investigation, or
   (c) left out as out of scope for a characterization?
2. For the comparison diagram, should sizes be:
   (a) markdown-only,
   (b) markdown plus media shown as separate bars, or
   (c) word/token counts only (the most comparable to memory-system token budgets)?

## Round 2 (2026-09-26)

Reviewed commit `2d4448b` against this document's six blocking findings and against plugin source directly (re-read `validate-cdocs-edit-path.sh` and `frontmatter-spec.md` fresh rather than trusting the round-1 log).

| Finding | Status | Verification |
|---|---|---|
| F1 (mechanism count) | **Resolved** | BLUF now says "five layered mechanisms"; Read/Retrieval header says "five independent, layered mechanisms" and numbers exactly five items. No remaining count mismatch. |
| F4 (cold-start vs. O(N)) | **Resolved** | BLUF splits "session-start cost is roughly constant" from "the cost that scales with corpus size is the O(N) full-directory scan"; Units of Memory and Weaknesses restate the same split with no contradiction. |
| F5 (media-inflated sizes) | **Resolved** | BLUF, corpus table, and Weaknesses all now report weftwise as "200M (`_media` ~159M; markdown ~44M)" and use the ~44M figure in prose comparisons (e.g., Weaknesses: "weftwise (1,979 docs, ~44M markdown)"). A footnote after the table states later comparisons use markdown-only unless stated otherwise. |
| F2 (PreToolUse hook scope) | **Resolved** | Re-read `plugins/cdocs/hooks/validate-cdocs-edit-path.sh` directly: `CDOCS_AGENTS="triage nit-fix reviewer"`, matched by exact string against `agent_type`, path check is a single regex over the union `cdocs/(devlogs|proposals|reviews|reports)/` with no per-subdirectory mapping, and a missing `agent_type` (main session) exits 0 unconditionally. The revised Write Triggers and Auditability text ("coarse sandbox... not a per-subdirectory write ACL", "main session, implementer, and proposer are unrestricted") matches the script exactly. |
| F3 (review lifecycle) | **Resolved** | Re-read `frontmatter-spec.md`: `status` starts at `wip` and `done` is listed as valid for "All types"; `last_reviewed` section header is explicit "(optional, not on reviews)". The revised table row ("`status`: wip -> done; no `last_reviewed` of its own, but its verdict propagates to the subject's `last_reviewed`") matches both clauses precisely. |
| F6 (consolidation framing) | **Resolved** | Consolidation section and Weaknesses now lead with "explicit, agent-triggered, and additive - never automatic or in-place," give the same three examples (reports, devlog handoffs, `evolved` supersession) as this review suggested, and explicitly contrast with Letta sleep-time consolidation and Zep's automatic edge invalidation. |

Non-blocking items also landed: typed-edge framing for `review_of`/`last_reviewed`/`task_list` (Read/Retrieval item 4), agentic-search framing distinguishing recall-limited-by-vocabulary from "no retrieval," harness-delegated cross-project memory (BLUF, Weaknesses), `agents/*.md` as persistent read-only procedural identity (Identity Model), "tamper-evident" softened to "diffable and attributable" (Strengths), snapshot dating on the corpus table, and the placeholder `first_authored.at` timestamp corrected to a plausible time (`09:14:00`).

No new internal inconsistencies were introduced by the revision: the mechanism count, size figures, and consolidation language are each now used consistently across the BLUF, body sections, and Weaknesses (checked by grep for "linear", "four mechanisms", "200M", and "no consolidation" — none of the retracted phrasings remain). The revision note added under the BLUF correctly attributes the changes to the round-1 review and lists them accurately.

One residual, non-blocking observation: the round-1 open question about `agent_type` namespacing (`cdocs:reviewer` vs. bare `reviewer`) was left unresolved in the document, as this review's option (c) permitted; it remains a fair thing to flag as an unverified enforcement gap in a future audit of the hook itself, but it does not block this characterization report.

### Round 2 Verdict

**Accept.** All six round-1 blocking findings are resolved and verified directly against `validate-cdocs-edit-path.sh` and `frontmatter-spec.md`, not merely against the round-1 review's claims. The non-blocking suggestions were folded in as well. No new errors or internal inconsistencies were introduced by the revision.
