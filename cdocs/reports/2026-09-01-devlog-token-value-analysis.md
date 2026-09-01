---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-01T08:38:27-07:00
task_list: cdocs/devlog-value-analysis
type: report
state: live
status: wip
tags: [devlog, token-cost, memory, compaction, cross-target, architecture]
---

# Devlog Token-Value Analysis

> BLUF: The devlog mechanism is not redundant with Claude's internal mechanisms: extended thinking, auto-compaction, and auto-memory are all ephemeral, per-session, and Claude-only, while a devlog is durable, git-versioned, and readable cold by a fresh agent or a non-Claude harness (OpenCode, Codex) without replaying any transcript.
> The real waste isn't the devlog concept, it's the blanket mandate: every one-shot task pays full devlog overhead (structured template, verification section, git file) whether or not anyone will ever re-read it.
> Recommended option: **(b) make devlogs conditional/lighter** — keep the artifact and its unique properties, but scope the mandate to work with a resumption, hand-off, or cross-session audience (matches cdocs's own cross-target design goal), and let one-shot/trivial tasks skip it or use a minimal form.

## Context / Background

The repo owner asked whether `cdocs`'s devlog mechanism (`plugins/cdocs/skills/devlog/SKILL.md`, mandated repo-wide by `CLAUDE.md`: "IMPORTANT: Always create a devlog") is still worth its token cost, given that Claude Code has since grown internal mechanisms (extended/interleaved thinking, auto-compaction, auto-memory) that seem to cover similar ground.
Their stated experience: they never read devlogs themselves, and suspect this is "2x-counting tokens" against something Claude already does internally.

This report inventories the overlapping mechanisms, evaluates the token-duplication claim, reframes the audience question, and recommends a concrete change.

54 devlogs exist under `cdocs/devlogs/`, averaging ~90 lines (4872 lines / 54 files), ranging 20-352 lines.
25 other cdocs documents (proposals, reviews, reports) cite a devlog by path, confirming devlogs are read by other *documents*, if not by the human owner directly.

## Key Findings

- **No internal Claude mechanism is durable across sessions or git-visible.** Extended thinking, auto-compaction summaries, and session transcripts all live inside one conversation's context window or the local `~/.claude/` session store; none of them are committed to the repo, none survive a `git clone`, and none are visible to a different tool.
- **Auto-memory is the closest overlap but is scoped and unpruned differently.** Per `cdocs/reports/2026-03-13-claude-code-features-catalog.md:174-192`: memory lives at `~/.claude/projects/<project>/memory/`, only the first 200 lines of `MEMORY.md` load each session, entries accumulate with "no curation," and there is "no cross-machine memory sync." It is designed for durable *facts* (build commands, style preferences), not for a chronological account of one work session's decisions, dead ends, and verification evidence.
- **Auto-compaction is designed to lose information, not preserve it.** Per the same report (lines 244-255): auto-compact "summarizes conversation history... clears older tool outputs" and "can lose nuanced instructions from early in the conversation." Compaction is lossy by design; a devlog is the opposite: an intentionally-curated, human/agent-authored record of what mattered.
- **cdocs already anticipates the compaction gap.** Today's own devlog (`cdocs/devlogs/2026-09-01-oversight-proposals-and-cc-features.md`) records a sonnet subagent's top recommendation from a parallel CC-features survey: add a `PreCompact` + `SessionEnd` hook to "auto-flush the active devlog" — i.e., the project's own research already treats compaction as a *reason to invest more* in the devlog (capture state before it's lost), not a reason to drop it.
- **25 of ~150+ non-devlog cdocs docs cite a devlog by path** (proposals, reviews, a report). This is the actual usage signal: devlogs are consumed by *other documents and agents*, not primarily by the human owner reading them in a browser. The owner's "I never look at devlogs" is accurate but describes the wrong audience.
- **Devlog sizes are modest.** Median devlog is well under 150 lines; only 3 of 54 exceed 200 lines. At typical token density (~0.75 tokens/word, ~8-10 words/line), a 90-line devlog costs roughly 600-900 tokens to write and a similar amount to re-read later — small relative to the thinking and tool-call tokens already spent doing the work it documents.
- **The mandate is unconditional, not the artifact.** `CLAUDE.md` says "Always create a devlog" with no carve-out for trivial or single-turn tasks; the SKILL.md itself already contains graduated guidance ("use your judgement," "a quick config change doesn't need a debugging process section") that the blanket CLAUDE.md line overrides in practice, since agents default to the letter of the IMPORTANT directive.

## Analysis

### 1. What a devlog provides that internal mechanisms do not

| Mechanism | Covers | Does NOT cover |
|---|---|---|
| Extended/interleaved thinking | In-the-moment reasoning trace for the current turn | Not persisted past the turn; not visible to any other session, agent, or tool; not git-versioned |
| Auto-compaction & summarization | Keeps a long session usable by summarizing/discarding older turns | Explicitly lossy ("can lose nuanced instructions"); no structured record of decisions/verification; nothing survives session end |
| Auto-memory (`~/.claude/.../memory/MEMORY.md`) | Durable, cross-session *facts*: build commands, style preferences, code patterns | Not git-versioned (lives outside the repo, no cross-machine sync per the CC features catalog); truncated to first 200 lines; unstructured/uncurated accumulation, not a chronological account of *this* session's plan, dead ends, and evidence |
| Harness file-edit tracking | Knows which files changed and roughly when | No "why" — no rationale, no rejected alternatives, no debugging narrative |
| Subagent handoff summaries | Passes a synthesized result to the dispatching agent | Ephemeral (exists only in that handoff's context); lost once the parent turn ends; not addressable by a later, unrelated session |
| Session transcripts | Complete raw record, in principle | Not human-skimmable, not structured, not portable outside the harness that produced it, and (per this project's own workaround docs) not reliably readable by other tools (OpenCode/Codex) |

The common thread: every internal mechanism is scoped to *one Claude session, on one machine, inside one harness*.
A devlog is the only mechanism here that is durable (git-committed), cross-session (readable cold weeks later), cross-tool (readable by OpenCode/Codex/a human on GitHub, none of which share Claude's internal memory or thinking trace), and structured for a specific purpose (resumability: "enough context for another agent to resume the work," per SKILL.md).

### 2. Is it "2x-counting" tokens?

Partially, and the split matters:

- **Genuinely redundant cost:** writing a devlog paragraph that just restates what the extended-thinking trace or a tool-call transcript already said, for a task that will never be resumed, reviewed, or handed off. For a one-shot fix in a single session with no other consumer, that devlog is close to pure overhead: nothing reads it, and the information it duplicates was already "spent" once in thinking/tool tokens.
- **Non-redundant cost:** the token spend that buys durability, git-diffability, cross-tool legibility, and survivability across compaction/session-end. Auto-compaction's own design goal is to discard exactly the kind of detail a devlog preserves; that's not double-spending, it's the *only* copy that survives. The 25-document cross-reference count above shows this isn't hypothetical: other cdocs documents actually pull specifics back out of devlogs during later work.

So the mandate isn't wasteful because devlogs duplicate internal state; it's wasteful in the marginal case of tasks that have no future reader at all, where any documentation cost is unrecovered overhead regardless of what mechanism produces it.

### 3. Reframing "I never look at devlogs"

The owner's experience is real but is evidence about the *human* audience, not the *only* audience. The actual consumers, per the evidence above, are:
- **Future/resumed agent sessions** — including sessions after a `/compact` or a new terminal, which have no access to the prior session's thinking trace or transcript.
- **Other cdocs documents** — 25 confirmed citations; proposals and reviews pull prior decisions and rationale from devlogs rather than re-deriving them.
- **Non-Claude harnesses** — cdocs is explicitly built cross-target (`plugins/cdocs/README.md` "OpenCode Installation"; `scripts/build-opencode.ts`; the OC/Codex parity reports under `cdocs/reports/2026-03-13-parity-*.md`). OpenCode and Codex have no access to Claude's auto-memory or thinking trace at all — for those targets, the devlog (or its AGENTS.md-delivered equivalent) is the *only* persistence layer cdocs can offer, not a duplicate of anything.

This means the value proposition is asymmetric across targets: for Claude Code alone, some of the devlog's value overlaps with auto-memory/compaction (though imperfectly, per section 1); for cdocs's cross-target mission, the devlog has no internal-mechanism substitute at all. Given cdocs is designed cross-target on purpose, this cuts toward keeping the mechanism, not dropping it.

### 4. Options

- **(a) Keep as-is.** Simplest, but leaves the blanket mandate unconditional, so trivial/one-shot work keeps paying full-template overhead for zero future readers, exactly the pattern the owner flagged.
- **(b) Make devlogs conditional/lighter.** Scope the CLAUDE.md mandate to work likely to be resumed, reviewed, or handed off (multi-session work, anything spawning subagents, anything another cdocs doc will reference) and let single-turn/trivial tasks skip it or use a 3-5 line minimal note instead of the full template. Preserves the unique durable/cross-target value where it's earned, cuts overhead where it isn't.
- **(c) Replace/merge with the persistent memory mechanism.** Rejected: auto-memory is Claude-only, not git-versioned, truncated to 200 lines, and uncurated — it cannot serve the cross-target audience (OpenCode/Codex) or the git-diffable/human-auditable properties that make devlogs useful to *other cdocs documents*, per the 25-citation cross-reference count.
- **(d) Keep the artifact, stop mandating it in CLAUDE.md.** Risks under-creation: SKILL.md already says "Model auto-invocation is the most common entry point," which depends on the CLAUDE.md-level trigger. Removing the mandate entirely likely regresses the mechanism below the point where cross-references and hand-offs still work, since agents won't reliably self-elect to write one.

## Recommendations

**Adopt option (b).** Concretely:
1. Reword the CLAUDE.md line from an unconditional "Always create a devlog" to a conditioned rule: create a devlog for multi-step, multi-session, or hand-off-relevant work (the SKILL.md's existing "use your judgement" language already models this; CLAUDE.md's IMPORTANT framing currently overrides it in practice).
2. For clearly one-shot, single-turn tasks (a config tweak, a one-line fix with no follow-on), permit a minimal inline note or no devlog at all, rather than the full Objective/Plan/Testing/Verification template.
3. Leave the SKILL.md template and cross-target delivery (AGENTS.md, rules layers) unchanged: they are what make the devlog useful to OpenCode/Codex sessions and to other cdocs documents, and that value is unaffected by the human owner's own reading habits.
4. Independently of this report: the `PreCompact`/`SessionEnd` auto-flush hook idea already surfaced in `cdocs/devlogs/2026-09-01-oversight-proposals-and-cc-features.md` is worth pursuing regardless of (b), since it directly shores up the one real gap identified here — a devlog started but not yet written to disk when compaction or session-end hits.
