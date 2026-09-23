---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-22T11:20:00-07:00
task_list: meta/token-spend-attribution
type: report
state: live
status: review_ready
tags: [meta, tooling, cost, retrieval, agent-memory, rfp-4]
---

# Shared Retrieval Cache (RFP-4): Prior Art and Redundancy Check

> BLUF(sonnet/shared-cache-redundancy-check): The maintainer's skepticism holds up on both counts.
> (1) **Prior art for the specific mechanism is thin to nonexistent.** No production multi-agent coding system implements "agent B reuses agent A's already-read raw file content across a context-window boundary." What production systems actually ship under names like "shared memory" or "shared context" (MetaGPT's message pool, OpenHands' file-based notes, Aider's repo-map cache, Devin's subagent context) is curated artifact sharing, a cheaper and already-covered lever, not raw-content dedup. The one concrete open-source attempt at the literal mechanism inside Claude Code itself (`lean-ctx`, cross-agent cache stubs) is currently broken by a filed bug rooted in Claude Code's own subagent isolation: sub-agents cannot resolve a stub into content because they run in a separate context window from the agent that produced it. That is not "unbuilt," it is "tried and structurally blocked."
> (2) **The redundancy hypothesis is half right.** Chat-record/devlog orientation (RFP-2) solves the *awareness* problem ("was this file already read, and what's the gist") for free, as a documented convention. It does **not** solve the *token-cost* problem the 97.4% cross-agent finding is actually about: a summary re-orients agent B but does not put agent A's file bytes into agent B's context, so agent B still pays full price the moment its job requires inspecting real content rather than trusting a paraphrase.
> **Verdict:** drop RFP-4 as a standalone shared-cache mechanism (no proof it can work today, and the platform actively resists it); fold the cheap half (files-read-in-full annotation) into RFP-2 as a documented convention with no new mechanism; leave true cross-agent content reuse on a watch-list pending a platform primitive Claude Code does not currently expose.

## Context / Background

RFP-4 ("shared retrieval cache") was first named, without a design, as workstream 3 in [`2026-09-20-token-spend-by-role.md`](2026-09-20-token-spend-by-role.md): a response to the finding in [`2026-09-20-read-source-attribution.md`](2026-09-20-read-source-attribution.md), "Reread waste and the logs/devlogs drill," that ~4.7-5.0M of the week's whole-file `Read` tokens are redundant re-reads of a file already read whole, and that 97.4% of that redundancy is a *fresh subagent or a later session reading the file cold in its own context* (only 2.2% is one context re-reading itself, 0.33% compaction-eviction, 0.05% edit-then-verify). That report frames the implication explicitly: "this is not a 'don't re-read' discipline problem (different agents cannot share a context window) but a missing shared retrieval cache across agents and sessions; graphify symbol-scoped retrieval is complementary (it cheapens each cold read, it does not dedupe them)."

The maintainer's stated skepticism: *"I'm super skeptical of a shared cache being anything - have a /report done on if anything similar has worked out elsewhere. Like, agents working on the same SoW will likely read the same files, and a 'gist log' seems redundant with the other SoW context tracking we are working on."* This report tests that skepticism against (1) external prior art and (2) the sibling chat-record/scratchpoint design in [`2026-09-22-chat-record-scratchpoint-design.md`](2026-09-22-chat-record-scratchpoint-design.md), which is the "other SoW context tracking" the maintainer is pointing at.

Graphify status, for precision: the accepted graphify integration ([`2026-09-17-graphify-mcp-vs-cli-value-add.md`](2026-09-17-graphify-mcp-vs-cli-value-add.md)) is "a stateless graph-scoping surface": given changed symbols, it resolves a dependent set and hands back a compact brief. It is a per-call, symbol-scoped retrieval tool. It cheapens a single cold read; it has no notion of "another agent already asked this," and its `graph.json` artifact is a structural index (symbols and edges), not a cache of file content. This is a genuinely different mechanism from a shared retrieval cache, and neither subsumes the other.

## Question 1: Has a Cross-Agent Raw-Content Read Cache Worked Out Anywhere?

Searched specifically for: multi-agent coding frameworks (OpenHands, Aider, SWE-agent, Devin, MetaGPT, AutoGPT-style systems, Claude Code itself) implementing "if another agent already read this file, reuse that," versus systems that only do scoped/smaller retrieval (a different, already-covered lever via graphify).

### What exists and what it actually is

| System | What it calls "shared"/"cache" | What it actually shares | Raw file content reuse across agents? |
|---|---|---|---|
| **MetaGPT** | Shared message pool (pub/sub) | Structured messages (PRD, design docs, code diffs) agents publish and subscribe to | No: agents read curated artifacts other agents *produced*, not raw source files other agents *read* |
| **OpenHands** | Persistent memory, file-based shared notes | Markdown notes/skills agents write to a shared, symlinked directory | No: explicitly "never injected automatically," read on demand as curated notes, not file content caching |
| **Aider** | Repo-map cache (`TAGS_CACHE`, `map_cache`), provider-side prompt caching | A ranked, tree-sitter-derived skeleton of the repo, cached to disk; single-user tool, not multi-agent | No: this is graphify's category (scoped structural retrieval), and it is single-session, not cross-agent |
| **Devin** | Subagents "share tools and codebase context with the parent" | Marketing language with no published mechanism for how a sibling subagent's already-read file content is retrieved without re-reading | Unverifiable from public docs; no described dedup mechanism |
| **Claude Code (native)** | Prompt/tool-result caching | Within one session only. Explicitly documented as *not* crossing the subagent boundary: "Each subagent runs in its own session with its own cache. Tool results cached in the parent session do not transfer to the subagent, and vice versa." ([jsmanifest.com](https://jsmanifest.com/claude-code-tool-result-caching-2026)) | **No, by design.** This is the single clearest piece of evidence: the platform we are actually building on has subagent context isolation as an architectural choice, not an oversight. |

### The one real attempt at the literal mechanism, and it is currently broken

[`lean-ctx`](https://github.com/yvgude/lean-ctx) (a real, adopted project, ~3.8k GitHub stars) implements exactly the mechanism the maintainer is skeptical of: when a parent session materializes content, sibling agents get back a stub like `"[cross-agent cache · directory tree · produced by 1 · 492 tokens avoided]"` instead of a second full read. [Issue #1801](https://github.com/yvgude/lean-ctx/issues/1801) reports that this is currently **broken in Claude Code specifically**: the isolation/addressing scheme assumes each subagent gets its own OS process, but Claude Code subagents reuse the parent's connection without spawning a separate process, so the scope key collides and sub-agents receive a stub they have no way to resolve, "because they operate in separate context windows." The documented workaround is subagents falling back to native tools (i.e., re-reading anyway), "defeating the original token-saving purpose."

This is direct, concrete evidence, not an absence of evidence: someone built the thing the maintainer is skeptical of, on the exact platform this repo runs on, and it does not currently work, for a structural reason (context-window isolation) rather than an incidental bug. A fix is conceivable (a per-subagent discriminator), but the failure mode shows the mechanism fights the platform's isolation model rather than working with it.

[Headroom](https://github.com/DegenStar/headroom) advertises "cross-agent memory with shared store and auto-dedup" and "SharedContext," but the documentation gives no detection mechanism, no worked example of "agent B reused agent A's read," and no case study or adoption evidence beyond commit activity; it reads as an early-stage OSS project with a commercial upsell, not a proven pattern. [Hindsight](https://hindsight.vectorize.io/blog/2026/05/06/claude-code-subagents-shared-memory) is explicitly framed around the same Claude-Code-subagent-isolation gap this report independently found, but its proposed fix is a "shared memory bank" of retained *session transcripts/insights* (architectural conventions, dead ends, decisions), pulled by an orchestrator before each turn: curated, not raw content, and the fetch found it to be vendor-pitch content ("no user testimonials, adoption metrics, or production case studies") rather than documentation of something running in the field.

### The adjacent academic literature is a different problem, not evidence for this one

A large body of 2026 arXiv work on "cache sharing across agents" (ForkKV, KVComm, TokenDance, DroidSpeak, Ramp Labs' Latent Briefing) is real and active, but it operates at the **inference-serving / KV-cache layer**: sharing transformer attention-cache tensors between agent processes on the same serving cluster. That requires operating the inference stack (or a proxy in front of it) and is orthogonal to anything a Claude Code plugin, hook, or convention can do; we are an API consumer, not an inference-server operator. Citing this literature as support for a "shared retrieval cache" RFP would be a category error: it answers "how do we avoid recomputing attention over identical prefixes at the GPU level," not "how does agent B avoid re-reading a file agent A already read." Filtering these out, the *application-layer* multi-agent-coding evidence for the maintainer's specific mechanism is thin: one broken OSS attempt, one marketing-stage OSS project, one vendor pitch, and zero examples in the frameworks most comparable to this repo's own setup (OpenHands, MetaGPT, Aider).

### Answer

**Mostly aspirational, not proven.** The idea "worked out" only in the weak sense that curated-artifact sharing (message pools, notes, repo maps) is well-established and valuable, which this repo already has via the devlog/chat-record. The specific claim, that raw file content read by one agent's context window becomes available to another agent's context window without a fresh read, has exactly one concrete implementation attempt found in the search, on this repo's own platform, and it is currently defeated by that platform's isolation model. That is itself the finding: treat this as evidence the idea is harder than it looks, not merely undone.

## Question 2: Is a Dedicated Shared-Cache Mechanism Redundant With Chat-Record/Scratchpoint?

The maintainer's hypothesis needs to be split into two distinct claims before it can be evaluated, because the read-source report's own language already draws this line: *"a summary re-orients an agent, but a reviewer that must actually inspect a file needs its real content."*

| | (a) Orientation: knowing THAT a file was read | (b) Token cost: not re-paying to read it |
|---|---|---|
| **What it requires** | Agent B learns, cheaply, "file X matters, here is what A found" | Agent X's actual bytes are present in agent B's context without agent B issuing its own `Read` |
| **Does chat-record/devlog solve it?** | **Yes, close to for free.** The existing convention (append to the devlog/chat-record for the matching `task_list`) already puts a prose account of what was read and found in front of the next agent that opens that devlog. Adding "which files were read in full" as an explicit field is a one-line convention change, not a new mechanism. | **No.** A devlog entry is prose the *next agent's model* reads and reasons over; it is not a copy of the file's bytes. Trusting the summary and skipping the read is a judgment call agent B makes, and it is often the *wrong* call, per case below. |
| **Does a shared-cache mechanism solve it?** | Yes, incidentally (a cache hit implies awareness) | Yes, if it worked (per Q1, it does not currently work on this platform) |
| **Marginal cost to add** | ~Zero: a documented convention | High: a new mechanism, fighting the platform's own subagent isolation (Q1) |

### Where orientation is enough

If agent B's job is *routing* or *deciding what to look at next* ("has anyone already characterized `loro_repo.ts`? what did they find?"), a devlog/chat-record entry that says "read `loro_repo.ts` in full; key structure is X, gotcha is Y" is sufficient. This is the majority case for an overseer, a proposer scoping a design, or a sibling agent deciding where to start. This is exactly the case the maintainer's "agents working on the same SoW will likely read the same devlog" intuition covers correctly, and it costs nothing beyond a documented convention.

### Where it genuinely falls short

The read-source report's own framing is precise here and this report's job is to take it at face value rather than paper over it: a **reviewer, or an implementer that must verify or reproduce something exactly**, cannot substitute a paraphrase for content. Concrete cases:

- A `cdocs:reviewer` checking whether an implementer's diff actually matches what a proposal specified must read the diff and the surrounding file; "agent A already read this file and said it's a stateless graph surface" does not let the reviewer confirm line-level correctness.
- An implementer that needs an exact function signature, import path, or exact existing indentation/formatting to make a byte-correct edit cannot work from a summary; `Edit`'s exact-string-match requirement (as used by this very tool) is the sharpest illustration of why paraphrase is not a substitute for content.
- Any multi-hop reasoning over a file's actual structure (which graphify targets directly) needs the graph/symbols, not someone else's prose gist of them.
- A judge or verifier role, by construction, exists to independently confirm a claim rather than trust the claimant's account of it; feeding it the claimant's own summary defeats the point of having a judge.

In every one of these cases, agent B ends up issuing its own `Read` regardless of how good agent A's devlog entry was, because the job requires content, not orientation. This is precisely the 97.4% cross-agent cost the original report measured: a fresh subagent reading a file cold **is exactly what happens even when the devlog already told it the file mattered**, because devlog awareness answers "should I look?" not "here is what you'd see if you did."

### Precise answer

The maintainer's hypothesis, "does chat-record/devlog already give agent B enough to skip re-reading," is **true for orientation and false for the actual token-cost problem the 97.4% figure is about**. Chat-record/devlog (RFP-2) is not redundant with a shared-cache idea in the sense of "doing the same job" (they solve different halves of the same intake-waste symptom); it is redundant only in the narrower sense that **the cheap half of what a shared cache would provide (awareness) is already covered**, so a dedicated mechanism's marginal value is confined to the harder, unproven, token-cost half.

## Verdict

Combining Q1 (no working prior art for the token-cost half; the one concrete attempt is platform-blocked) and Q2 (RFP-2 already covers the awareness half for free; the remaining half is exactly the half nobody has shown how to build on this platform):

1. **Do not open RFP-4 as a standalone shared-cache mechanism.** There is no evidence it can be built to work on Claude Code today (subagent context-window isolation is confirmed architectural, not incidental, and the one OSS project that tried the literal mechanism is broken by that isolation), and "design cross-agent/cross-session read dedup from scratch" (the roadmap's current P2 scope for RFP-4) would be spending L-effort chasing a mechanism the strongest available prior art says fights the platform rather than a genuine engineering gap this repo alone hasn't closed yet.
2. **Fold the free, proven-valuable half into RFP-2**, as a documented convention rather than a new mechanism: an agent's devlog/chat-record entry should name which files it read in full (not just what it concluded), so a sibling agent can decide, with real information, whether to trust the gist or open the file itself. This costs a line of prose per read and needs no hook, no cache, no platform primitive. Concretely: extend the devlog template's per-turn / handoff sections with a "Files read in full" note, or fold it into the scratchpoint's "key facts" field from the chat-record/scratchpoint design.
3. **Do not claim step 2 resolves the token-cost problem.** It resolves awareness. The 97.4% cross-agent reread-waste figure will not measurably drop from a devlog convention change alone, because the cases that actually drive re-reads (review, verification, exact-content edits, judge roles) are exactly the cases where awareness is not a substitute for content. Graphify remains the correct lever for the token-cost half insofar as it cheapens each individual cold read (recommendation 1 in the read-source report); nothing found here changes that ranking.
4. **Leave true cross-agent content reuse on a watch-list, not the active roadmap.** If Claude Code or the Anthropic API later exposes a primitive that lets a subagent's tool result be addressed by a sibling (the gap `lean-ctx`'s bug report identifies precisely: subagents need a way to resolve a produced-by-another-context reference into content), revisit this as a real proposal at that point. Building around the platform's current isolation model, as `lean-ctx` shows, produces broken behavior, not savings.

**Recommendation for the roadmap:** demote RFP-4 out of the active P2 phase. Downgrade to a watch-list item pending a platform primitive it does not currently have any means to be built on, with a one-line note that its cheap, already-provably-valuable subset is being delivered inside RFP-2 instead.

## Caveats

- This report evaluates production/OSS multi-agent coding systems and the platform this repo runs on (Claude Code); it does not evaluate research-only agent-simulation frameworks with no coding focus, which is a narrower scope than "anything similar" but matches the maintainer's explicit list of comparison points (OpenHands, Aider, Devin-style systems, SWE-agent, AutoGPT-style systems).
- `lean-ctx`'s star count and issue content were retrieved via `WebFetch` and not independently re-verified against a second source; the specific mechanism and bug description are taken as given from that fetch.
- Headroom and Hindsight are both active, evolving OSS/vendor projects; their described capabilities could change or mature after this report is written. The finding is about their state as searched on 2026-09-22, not a permanent verdict on the category.
- No experiment was run in this repo; this is a desk-research verdict, consistent with the report type. If the maintainer wants empirical confirmation, the read-source report's methodology (transcript-granularity reread classification) is already the right instrument to re-measure after the RFP-2 convention change lands, to see whether the awareness-only fix moves the 97.4% figure at all (this report predicts it will not, materially).
