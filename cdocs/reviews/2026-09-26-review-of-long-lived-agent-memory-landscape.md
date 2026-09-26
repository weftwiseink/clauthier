---
review_of: cdocs/reports/2026-09-26-long-lived-agent-memory-landscape.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-26T13:30:00-07:00
task_list: cdocs/connectome-research
type: review
state: live
status: done
tags: [fresh_agent, source_verified, citation_integrity, motivated_reasoning, identity_fairness, internal_consistency, rereview_agent]
---

# Review: Long-Lived Agent Memory Landscape

## Summary Assessment

The report surveys roughly 25 long-lived memory systems along eight axes, weighs the (thin) coding-agent evidence, and pulls out patterns that transfer to cdocs.
It is well sourced, honest about vendor numbers in most places, and the eight transferable patterns are concrete and useful.
Seven of the eight load-bearing claims I spot-checked hold up against their sources.
One citation does not support its claim (Cursor), the headline "convergence" thesis is framed more strongly than the report's own evidence allows, and the "identity is a niche" framing conflicts with the report's own star counts.
Verdict: **Revise**. The fixes are to framing and citations, not to the research.

## Source Verification

Checked with WebFetch/WebSearch/`gh api` on 2026-09-26.

| Claim | Source | Result |
|---|---|---|
| Letta: "memory moves from specialized memory tools ... into git-backed files" (2026-03-16) | letta.com/blog/our-next-phase | **Verified** verbatim. "Server-side sleep-time agents will be replaced by a client-side subagent system"; `core_memory_replace` and similar legacy tools removed. "Sunset" is fair for the *server-side* variants. |
| Cursor removed Memories in 2.1; users told to convert to Rules | forum thread `/143744` | **Cited source does not support it.** That thread's staff reply covers only Custom Modes ("Custom Modes were intentionally removed in Cursor 2.1"). The removal itself looks real from other threads (e.g. `forum.cursor.com/t/are-my-memories-gone/144057`, `/agents-have-lost-access-to-memory-capability/143310`), but "users were told to convert them to Rules" needs a source that actually says so. |
| Devin Knowledge "is being phased out in favor of Skills within Plugins" | docs.devin.ai/product-guides/knowledge | **Substance verified, quote not verbatim.** The page says "Knowledge is deprecated and will be removed in a future update. Existing Knowledge is being migrated to Skills in Plugins automatically." "when relevant, not all at once" is verbatim. |
| ETH (Gloaguen et al.): no general success gain, >20% cost, dev-written +2.4pp n.s., LLM-generated slightly negative, dev-vs-LLM p=3.8% | arXiv:2602.11988 | **Verified** (ETH Zurich + LogicStar.ai). Two nuances the report drops: the >20% figure is mainly for LLM-generated files (developer files cost up to ~19%), and the study also uses **CTXbench** (138 instances, niche repos with developer-committed context files), not only SWE-bench Lite. |
| Letta grep/filesystem agent 74.0% on LoCoMo (GPT-4o mini) vs Mem0 graph variant 68.5% | letta.com/blog/benchmarking-ai-agent-memory | **Verified.** Note: this puts Letta's self-run number next to Mem0's self-reported one, not a shared-harness head-to-head. |
| Anthropic memory tool `memory_20250818`, client-side, `/memories`, six commands, injected "ALWAYS VIEW YOUR MEMORY DIRECTORY ... ASSUME INTERRUPTION" | platform.claude.com memory-tool docs | **Verified** verbatim, including the multisession software pattern. |
| Dreams: research preview; memory store + 1-100 sessions; new output store; "input store is never modified" | platform.claude.com managed-agents/dreams | **Verified** verbatim. The "May 2026" date isn't on the page: the beta header is `dreaming-2026-04-21` and the example timestamp is 2026-04-29. |
| OpenClaw 390k stars; letta 24.9k; mem0 66.0k; graphiti 31.2k | `gh api` | **Verified.** |

## Section-by-Section Findings

### BLUF and Key Findings: the convergence thesis

**Blocking: the thesis is overstated and conflicts with the report's own evidence.**
The BLUF says the field "has converged ... on **agent-edited plain files**".
But Key Finding 4 says "Agent-written auto-memory in coding tools is being demoted, not promoted", and the Net assessment infers that vendors "are steering users back to explicit, human-owned files."
Both can be true only if "convergence" is split into two claims:
(a) the *substrate* is converging on plain files, which is well supported (Letta MemFS, Anthropic memory tool, Claude Code, Codex, OpenClaw);
(b) the *writer* is not converging on the agent, at least in coding tools, where the trend runs toward human-owned rules plus a reviewed consolidation pass.
As written, the BLUF merges these and reads as endorsing cdocs' exact shape.
The dedicated memory-layer projects with the most adoption (mem0 66k, Graphiti 31k, cognee 31k) are not files-first, and Letta, the report's anchor example, is a 25k-star project whose MemFS shift was six months old at writing time and has no published evaluation (as the report itself notes).
"Converged" should be "is shifting toward" or be scoped to coding/agent-harness products.

**Blocking: the grep-beats-Mem0 result is used inconsistently.**
The report says leaderboard numbers are "marketing unless the protocol is published" and that LoCoMo "fits in context" and is saturated.
It then calls Letta's 74.0% "the single most decision-relevant result for a markdown-files system".
Letta compares its own run against Mem0's self-reported number, on the same benchmark where a full-context baseline (~73%) also beats Mem0.
So the only safe reading is "on LoCoMo, almost anything that sees enough of the conversation beats Mem0's graph variant", which says little about files over graphs.
The result also appears in the BLUF as a pillar of the convergence thesis.
Either downgrade it to the same "vendor, saturated benchmark" standard the report applies everywhere else, or explain why it deserves an exception.
This is the clearest place where motivated reasoning shows through, given that the report is written for the cdocs team.

### Key Findings: identity persistence

**Blocking: "Identity persistence is a niche" is contradicted by the report's own data.**
OpenClaw, at 390k stars, is by far the most-adopted system in the table, and it ships `SOUL.md`/`IDENTITY.md` as injected, agent-editable persona files.
Hermes Agent plugs into Honcho, and Letta's lineage began with persona blocks.
The accurate claim is narrower: identity is a niche *among coding tools and memory-layer SaaS*, while it is mainstream in personal/companion agent harnesses.

Pattern 7 ("Keep identity out unless it is the product") argues that persona files add pinned tokens "without evidence of task benefit".
But no study cited here measures identity persistence on task outcomes at all, so this is an absence of evidence, not evidence of absence.
The recommendation may well be right for cdocs.
It should say "unmeasured" rather than imply a negative result, and it should name what identity systems are optimized for (behavioral consistency, relationship continuity, self-model coherence), so the connectome synthesis does not judge connectome purely on coding-task metrics.

### Key Findings / Coding-tool memory: Cursor and Devin citations

**Blocking (citation integrity):** replace or add to the Cursor forum citation so it supports "Memories removed in 2.1" and "advised to export to Rules".
If no source says "without a stated rationale", soften that to "no rationale found".

**Non-blocking:** the Devin phrase in quotation marks is a paraphrase.
Use the verbatim "Existing Knowledge is being migrated to Skills in Plugins automatically", or drop the quote marks.

### Evidence: Coding-specific

**Non-blocking.** The ETH caveat ("SWE-bench Lite tasks are single-shot issue fixes") leaves out CTXbench, the niche-repo subset with developer-committed files.
That subset is the setting closest to cdocs and still showed no significant gain, so omitting it makes the caveat look more exculpatory than it is.
Also split the cost figure: ~20-23% for LLM-generated files, up to ~19% for developer-written ones.

The DreamBench-SWE reading ("*having* a written record matters far more than *how* it is indexed") is fair and clearly hedged as single-author and recent.

### Taxonomy and Comparison Table

**Non-blocking: the codes are inconsistent.**
The Retrieval legend defines P/K/E/G/Ag, but the rows also use `entity`, `recency + importance + E`, `trigger-Ag`, `dialectic query`, `pinned folds + adaptive resolution`, and `G rank under token budget`.
The Structure values (`log/doc/graph/vector/tiered`) are likewise stretched into `doc store`, `vector + reasoning store`, and `branchable log + folds`.
Either widen the legend or add a footnote saying free text marks a hybrid.

**Non-blocking:** Generative Agents gets Audit=1 ("API/UI inspectable"), but it is research code with a JSON memory stream, so 2 is arguably closer.
The Anthropic Dreams row puts Writer=S, which is correct, but it would help to note the review gate (human chooses the output store), because that gate is exactly the pattern 4 argument.

**Non-blocking:** the mermaid `Substrate` subgraph draws `Log --> Docs --> Graph` arrows, which suggests a progression or pipeline the text never claims.
Use undirected links, or drop the arrows.

**Non-blocking:** in the cdocs row, Identity=none is correct, but Retrieval `P (rules)` is worth checking against the sibling cdocs-as-memory-system report so the two positioning rows agree.

### Patterns That Transfer to cdocs / Recommendations

These are the strongest part of the report.
Each pattern names its external precedent, and the inferences are labelled.
The opening line "cdocs already sits at the ... corner that the field is converging toward" repeats the overstatement and should follow whatever wording the BLUF lands on.
Recommendation 1 ("confirming cdocs' substrate choice") is supportable if scoped to *substrate*.
It should not be read as confirming cdocs' *writer* model, which the evidence here does not test.

### Closing NOTE

This is good practice: it discloses abstract-level reading and 403'd pages.
Add the Letta-vs-Mem0 cross-harness caveat and the Cursor sourcing gap here.

## Verdict

**Revise.**
The research is solid and most citations check out, but three framing and citation problems need fixing before this feeds the connectome synthesis: the convergence thesis, the grep-beats-Mem0 weighting, and the identity "niche" claim together tilt the report toward the cdocs team's priors.

## Action Items

1. [blocking] Split the BLUF/Key Finding "convergence" into substrate (files: supported) and writer (agent-written memory: demoted in coding tools), and soften "has converged" to "is shifting toward" or scope it to agent harnesses/coding tools. Propagate to the "Patterns" intro line and Recommendation 1.
2. [blocking] Hold the Letta 74.0% LoCoMo result to the report's own vendor-benchmark standard: note it is a self-run vs self-reported, cross-harness comparison on a saturated benchmark where full-context also beats Mem0. Drop "single most decision-relevant", or justify the exception. Consider removing it from the BLUF.
3. [blocking] Rescope "Identity persistence is a niche" to coding tools and memory-layer products, and acknowledge OpenClaw (390k stars) as mass-market identity-first. Reword Pattern 7's "without evidence of task benefit" as "unmeasured", and state what identity systems optimize for.
4. [blocking] Replace or add to the Cursor citation with a source that supports "Memories removed in 2.1" and "export to Rules". Soften "without a stated rationale" if it cannot be sourced.
5. [non-blocking] Make the Devin quote verbatim ("Existing Knowledge is being migrated to Skills in Plugins automatically") or remove the quote marks.
6. [non-blocking] In the ETH caveat, mention CTXbench (niche repos, developer-committed files, still no significant gain) and split the cost figure by file origin.
7. [non-blocking] Reconcile the Retrieval/Structure codes with the table's free-text cells, or footnote the hybrids. Revisit Generative Agents Audit=1.
8. [non-blocking] Change the Dreams "May 2026" date to match the source (the beta header is dated 2026-04-21), or cite where May comes from.
9. [non-blocking] Replace the directed arrows in the mermaid Substrate subgraph with undirected links.

## Questions for the Author

1. What is this report's intended role in the connectome synthesis?
   - (a) A neutral landscape: then items 1-3 matter most, and the cdocs-favorable framing should be pulled into the Patterns section only.
   - (b) An explicitly cdocs-advocacy input: then say so in Context/Background, and the synthesis should weight it accordingly.
2. Should identity-first systems (OpenClaw, Honcho, Letta persona, connectome) get their own short evaluation axis for behavioral consistency or continuity, so connectome isn't scored only on coding-task criteria?
   - (a) Yes, add it here.
   - (b) Defer it to the connectome sibling report.
   - (c) Out of scope.

## Round 2 (2026-09-26)

Reviewed commit 59c7cf3 ("docs(connectome): revise memory landscape per review"), which addresses this review's round-1 findings.
Method: re-read the full revised document, and independently re-fetched the new Cursor source (`forum.cursor.com/t/are-my-memories-gone/144057`) via WebFetch rather than trusting the citation on its face.

### Blocking findings, re-checked

1. **Convergence thesis (was blocking): resolved.** The BLUF now opens "Two trends that are easy to conflate should be kept apart" and gives separate **Substrate** ("shifting toward... plain files") and **Authorship** ("this is *not* converging on the agent as writer") paragraphs. Key Finding 1 says "'Shifting toward' is the defensible wording, not 'converged'." Key Finding 4 states authorship is demoted in coding tools. The Patterns intro (`## Patterns That Transfer to cdocs`) now states the substrate/authorship split explicitly ("On *authorship*, it does not [converge]... which is the pattern coding-tool vendors are retreating from") rather than the old single-line overstatement. Recommendation 1 is scoped to substrate and explicitly declines to confirm the writer model. No residual "converged" language found via grep.
2. **Letta-vs-Mem0 weighting (was blocking): resolved.** The BLUF still surfaces the result (reasonable, since it is discussed either way) but now frames it as a caveat rather than a pillar: "That includes the result most flattering to file-based designs..., which is a cross-harness comparison where a full-context baseline also beats Mem0." The Benchmark section (line ~232-235) drops "single most decision-relevant" and instead concludes "It is weak evidence that a file-based agent is *not worse*... and no evidence about files versus graphs for coding." The closing NOTE repeats the self-run-vs-self-reported caveat. Consistent treatment throughout; no remaining place asserts it as a positive result for files.
3. **Identity "niche" claim (was blocking): resolved.** BLUF: "Identity persistence is mainstream in personal-agent harnesses (OpenClaw...) but unmeasured on task outcomes; it is rare only among coding tools and memory-layer SaaS." Key Findings and the Net Assessment echo this. Pattern 7 is rewritten to "Treat identity as an open question with an unmeasured payoff, not a settled 'no'" and explicitly states what identity systems optimize for (behavioral consistency, relationship continuity, self-model coherence), matching the action item.
4. **Cursor citation (was blocking): resolved and independently verified.** I re-fetched `forum.cursor.com/t/are-my-memories-gone/144057` directly. The report now quotes the staff reply verbatim: "The Memories feature was intentionally removed starting from version 2.1.x," correctly attributes it to a named staff member's 2025-11-25 reply, and accurately describes the export-to-Rules guidance and the "no rationale found" framing. The report's added detail that a user called the exported files "almost no different than .mdc files" also checks out verbatim against the source. This is now a fully supported citation.

### Non-blocking items, spot-checked

5. Devin quote is now verbatim ("Existing Knowledge is being migrated to Skills in Plugins automatically"). Resolved.
6. ETH caveat now names CTXbench and splits the cost figure ("+20-23% for LLM-generated files and up to ~19% for developer-written ones"). Resolved.
7. Table gets a legend footnote for free-text hybrid cells; Generative Agents Audit changed to 2. Resolved.
8. No "May 2026" language remains for Dreams; the beta header date (`dreaming-2026-04-21`) is used consistently. Resolved.
9. Mermaid Substrate subgraph now uses undirected `---` links. Resolved.

### New issues found this round

None blocking. Two small observations, both non-blocking:
- The BLUF and closing NOTE each carry a caveat about the Letta/Mem0 result; this is intentional redundancy given how load-bearing the original miscitation was, and is acceptable, but a future pass could consolidate to one place per the "say it once" convention.
- The two `NOTE(opus/connectome-research)` callouts at the end (verification caveats, then the round-1 revision log) are good practice and consistent with the writing conventions' allowance for chronological framing in exceptional cases; no change needed.

No new citation, consistency, or framing errors were found. The revision is a faithful, complete resolution of every blocking and non-blocking action item from round 1.

### Round 2 Verdict

**Accept.**
All four round-1 blocking findings are resolved, including independent re-verification of the previously-uncited Cursor claim against its source.
All five non-blocking suggestions were also addressed.
No new pro-cdocs tilt, citation gap, or internal inconsistency was introduced in the revision.
