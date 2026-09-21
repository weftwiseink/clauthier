---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-20T07:55:27-07:00
task_list: meta/token-spend-attribution
type: report
state: live
status: review_ready
last_reviewed:
  status: accepted
  by: "@claude-opus-4-8"
  at: 2026-09-20T09:58:00-07:00
  round: 1
tags: [meta, tooling, cost, orchestration, agent-memory]
---

# Token Spend by Role: Attribution and Direction

> BLUF(opus/token-spend-attribution): Over the last 7 days of weftwise work, dispatched `general-purpose` subagents (implementer plus proposer work, conflated) are 64.9% of USD spend ($2,045 of $3,152); reviewer is 16.4% ($518), top-level/overseer is 15.2% ($480).
> About 96% of all tokens are cache-read (re-sent context), so retrieval, not generation, is the bill: this is the empirical case for the graphify retrieval integration and for prompt-cache reuse across a loop's turns.
> The usage DB attributes by dispatch `agent_type`, not semantic role, so implementer and proposer are indistinguishable and a `cdocs:*`-only dashboard shows just 16.5% of real spend.
> Near-term fix: label implementer/proposer at dispatch so the DB self-classifies.
> Directional idea under evaluation: a Sonnet-high overseer with an on-call Opus advisor subagent, to cut overseer latency and low-signal Opus context cost.

## Method (how these numbers were derived)

- Source: a point-in-time snapshot of `~/.claude/usage.db` (the claude-usage plugin's store), queried with Node 24 `node:sqlite` (there is no `sqlite3` CLI in the container).
- The `turns` table is authoritative for per-turn tokens (`input`, `output`, `cache_read`, `cache_creation`, `model`, `is_subagent`, `agent_id`). The `agents.total_tokens` column is unreliable (one-to-three orders of magnitude lower than the summed `turns` columns for the same agent, measured 210x to 1045x low among the heaviest agents, and frequently NULL: 4,277 of 5,647 rows) and must not be used for spend. This is a likely upstream bug in the plugin worth reporting.
- Roles are derived by joining `turns.agent_id` to `agents.agent_type`; `is_subagent = 0` turns have no agent row and are the top-level/overseer bucket.
- Scope: weftwise only (`turns.cwd LIKE '%weftwise%'`), last 7 days (`timestamp >= '2026-09-12T00:00:00Z'`; timestamps are ISO-8601 UTC text). Weftwise is 97.9% of all-up USD this week; the 2.1% excluded is genuine other-project work (`lace`, `clauthier`), not mistagged.
- USD uses current per-model pricing from the `claude-api` skill, applied per model to each token class. Two independent agents (a haiku raw `GROUP BY` tally and a sonnet analysis) were cross-checked and matched to the token on every `agent_type` row.

## Spend by role: weftwise, last 7 days

| Role | Agents | Output tok | Cache-read tok | Est. USD | % spend |
|---|---:|---:|---:|---:|---:|
| **Implementer/Proposer** (`general-purpose`, conflated) | 170 | 11.2M | 2.69B | **$2,045** | **64.9%** |
| **Reviewer** (`cdocs:reviewer`) | 150 | 4.6M | 502M | $518 | 16.4% |
| **Overseer / top-level** (`is_subagent=0`) | 14 sess | 4.7M | 586M | $480 | 15.2% |
| Orphaned agent-id (unresolvable) | 11 | 0.6M | 133M | $83 | 2.6% |
| Search/Explore (`Explore`) | 35 | 0.4M | 23M | $25 | 0.8% |
| cdocs mechanical (`cdocs:nit-fix`) | 3 | 0.05M | 2.8M | $0.79 | 0.03% |
| misc (`statusline-setup`, `claude-code-guide`) | 2 | ~0.01M | ~0.4M | $0.34 | 0.01% |
| **Total** | | **21.6M** | **3.94B** | **$3,152** | 100% |

`cdocs:triage`, `cdocs:judge`, `Plan`, and the `claude`/`fork` subagent types had zero activity this week (confirmed present-at-zero in the 14-day window, not silently dropped).

### Implementer vs proposer split (follow-up #1, resolved at 100% coverage)

The `general-purpose` bucket above is not one role but seven. Recovered by extracting each of the 170 agents' initial dispatch prompts from their per-agent transcript files (`~/.claude/projects/<proj>/<session>/subagents/agent-<id>.jsonl`, which are compaction-immune, unlike the parent-session `Task` events, 8 of which had already been evicted by compaction) and classifying each with a haiku fan-out. Coverage: 170/170 agents, 100% of the $2,044.55, 166/170 at high confidence.

| Sub-role | Agents | Est. USD | % of general-purpose | % of total spend |
|---|---:|---:|---:|---:|
| **implementer** | 46 | **$1,522** | 74.4% | **48.3%** |
| **proposer** | 46 | $234 | 11.4% | 7.4% |
| debugging/spike | 14 | $151 | 7.4% | 4.8% |
| docs/report-authoring | 35 | $67 | 3.3% | 2.1% |
| reviewer-like | 4 | $40 | 1.9% | 1.3% |
| research/explore | 21 | $29 | 1.4% | 0.9% |
| other | 4 | $2 | 0.1% | 0.1% |

In this window, the single largest role is the **implementer at 48.3% of total weekly spend**, roughly 3x the reviewer and 3x the overseer (see Caveats on window representativeness). Proposer work, despite equal agent count, is a fifth of implementer cost: proposals are think-and-write, implementers are read-heavy loops that re-send large context every turn (the cache-read pattern). This is where retrieval reduction pays off most.

By raw token count the overseer bucket (604M tokens) outranks reviewer (527M), but by USD reviewer edges it out: reviewer's mix carries more (pricier) Fable-5.1 output and cache-write tokens, while the overseer total is dominated by cheap Opus cache-reads. Dollar ranking, not token count, is the real spend signal because output runs ~5x input and cache-read is priced at a small fraction of input.

## Model mix: weftwise, last 7 days

| Model | Turns | Est. USD | % of USD |
|---|---:|---:|---:|
| claude-opus-4-8 | 15,761 | $2,827 | 89.7% |
| claude-fable-5-1 | 661 | $229 | 7.3% |
| claude-sonnet-5 | 1,981 | $88 | 2.8% |
| claude-opus-5 | 44 | $7 | 0.2% |
| claude-haiku-4-5 | 57 | $0.89 | 0.03% |

> NOTE(mjr/token-spend-attribution): The 7.3% Fable-5.1 share is expected, not a floor violation.
> The maintainer has been explicitly requesting Fable rounds for dense technical work during this period.
> Do not "correct" it back to the default Opus floor without asking.

Opus-tier is 89.9% of spend, consistent with the `CLAUDE.md` floor. Sonnet's share is concentrated in `general-purpose` and `Explore` turns (the sanctioned search/explore carve-out). Haiku is negligible, which is itself a signal: the cheap mechanical tier is barely used relative to what could be pushed down to it.

## Key insights

1. **Retrieval is the bill, not generation.** Cache-read is 3.94B tokens versus 21.6M output for the entire week across all roles, roughly 180x larger. For the general-purpose bucket specifically, cache-read (~$1,347) is about two-thirds of its $2,045. This empirically reproduces, in our own data, the industry finding that the large majority of agentic spend is re-sent context rather than newly generated text. The graphify retrieval integration targets exactly this dominant line item; pairing it with prompt-cache reuse across an iterate loop's implementer turns would compound the saving.
2. **Devlog authoring is a rounding error.** The entire week's output across every role is 21.6M tokens. Devlog prose is a sub-sliver of that, which settles the earlier methodology question empirically: the devlog mandate is not a meaningful token cost. The cost that matters is reading, not writing. See [`cdocs/reports/2026-09-19-devlog-methodology-value.md`](2026-09-19-devlog-methodology-value.md).
3. **The dashboard-omits-implementers hypothesis is confirmed, and it is the largest hidden chunk.** A dashboard scoped to named `cdocs:*` agents captures only 16.5% of real spend and silently drops the 64.9% implementer/proposer bucket, the 15.2% overseer bucket, and Explore. This is a bucketing gap, not a data gap: the tokens are all in `turns`.

## Granularity gaps and how to fix them

- **No semantic role in the schema.** Implementer and proposer both dispatch as `general-purpose`, so they cannot be separated from `agent_type` alone. The fix is a dispatch-time label: `/cdocs:implement`, `/cdocs:propose`, and `/cdocs:iterate`'s implementer should pass a distinct `label` or `subagent_type` so `usage.db.agent_type` becomes self-classifying and the dashboard works without heuristics. This should already have been done; it is the highest-value cheap fix and is action item #1 below. The in-flight classification follow-up (see Open Follow-ups) is a stopgap to recover the split retroactively for the current week.
- **`agents.total_tokens` is unreliable (~200x low).** Any consumer summing that column understates spend by two orders of magnitude. Use the `turns` columns. Worth filing upstream against the claude-usage plugin.
- **Orphaned agent-ids.** 642 subagent turns ($83, 2.6%) carry an `agent_id` with no matching `agents` row. A naive `agent_type IS NULL -> TOP_LEVEL` fallback misattributes these to the overseer, inflating it. Root cause (a still-in-flight agent at snapshot time versus a write-path gap in the plugin) is unresolved and is action item #3 below.

## Directional proposal: thinner, faster overseers

An idea worth turning into a proposal: run overseers on **Sonnet-high** (Sonnet 5 at high reasoning) rather than Opus, and give each overseer an **on-call Opus advisor subagent** it consults only for sensitive, tricky, or high-stakes decisions.

Rationale:
- Overseer latency matters; the overseer is on the interactive critical path in a way a dispatched implementer is not, and Sonnet is faster.
- The overseer is exposed to a large volume of context from underlying work that is low-signal for oversight decisions. Paying Opus rates to keep that firehose in an Opus context window is poor value when most overseer turns are routing, not deep reasoning.
- The data supports it: the overseer bucket is 586M cache-read tokens (mostly re-sent context) at Opus rates. A Sonnet-high overseer cuts the per-token cost of that context roughly 2.5x (the Opus-4.8-to-Sonnet-5 price ratio on every token class) and reduces latency, while Opus reasoning is spent only where it changes an outcome.

Shape:
- The Opus advisor is a `fork`-style consult for a one-off hard call (inherits the overseer's context, returns a judgment, disposable), distinct from a named durable specialist that carries a workstream across turns. See `orchestration-discipline.md` Pillar 3.
- Tension to resolve: `model-tiering.md` currently pins the Lead/Overseer/Judgment tier to opus-class, and the `judge` backstop is `model: opus`. This is a proposed, evidence-backed revision to that tier, not a silent downgrade. It needs a proposal plus validation that Sonnet-high holds routing and dispatch-decision quality (the judge and the Opus advisor stay Opus, preserving the judgment backstop). The verification question is whether a Sonnet-high overseer's escalation instinct (knowing when to consult the advisor) is reliable enough; that is what a spike should measure before adopting, along with routing and dispatch-quality regression, not only escalation reliability and the (corrected ~2.5x) cost delta.

## Proposed cdocs workstreams (handoff for a future round)

These are workstreams to be carried out in the cdocs project itself, not in this repo.
They are collected here so a future cdocs round has the full context and rationale in one place.

Unifying design: move long-session context out of ever-growing agent context windows and into a structured set of durable documents, so agents are not forced to build up and re-send large context. The workstreams compose toward that goal: execution-context preservation (1) is the durable substrate; a shared retrieval cache (3) stops every agent rebuilding the same file context from scratch; cap-and-reseed (4) bounds any single agent's carried context; and the model-tier moves (the Sonnet-high-overseer proposal above, plus Sonnet-run Playwright (2)) keep the expensive tier off low-signal context. Together they trade a monolithic, re-sent context window for structured documents plus cheap, cached, scoped retrieval.

### 1. Execution-context preservation: a durable complement to the devlog

The devlog is a curated decision record, authored deliberately. It does not durably preserve two things a resumed or post-compaction instance needs for orientation: the verbatim history of user input, and a running high-level summary of what each agent turn actually did. Propose a tool or automation that maintains both automatically:

- **Auto-append every user message on send.** A durable, append-only record of all user input, captured at send time, independent of compaction (which summarizes the middle of the conversation and loses earlier human turns, verified above under context-management primitives). This directly answers the "preserve my message history so the post-compact instance is not disoriented" need that `/compact` alone does not meet.
- **Dense per-turn agent summary.** After each agent turn, compactly summarize the high-level work and the most important points into a running, dense reference for future instances to orient against. This is distinct from the decision-focused devlog: its job is fast execution-context orientation, not the why-behind-decisions record.
- **Chapter turning / conscious compaction.** An affordance to "turn the page": deliberately seed a new page with the carried-forward context from the prior one, rather than letting auto-compaction do it lossily. This reframes the earlier wiki-like-devlog-breakdown recommendation: the win is less a static section hierarchy and more ad-hoc, agent-driven pagination that performs conscious compaction at chosen boundaries.

Goal: execution-context preservation that survives compaction and instance handoff, cheaply, without re-reading transcripts. It is the durable substrate the overseer handoff (Pillar 2) and on-resume liveness reconciliation (Pillar 1b) currently approximate by hand, and it is the mechanism-level answer to the compaction-loses-the-middle limitation. It also underpins workstream-question 4 below: a fresh implementer leg can only get up to speed cheaply if this dense, durable context exists to seed it.

### 2. Route Playwright testing and troubleshooting rounds through Sonnet

Playwright DOM intake is a modest 3.4% of read volume, but individual snapshots are among the heaviest per-result payloads (mean ~2,349 tokens, and full browser trees can be far larger), and DOM-driven troubleshooting is iterative and light on deep reasoning. This reinforces an already-considered move: dispatch Playwright test and troubleshooting rounds to Sonnet rather than Opus. It fits the search/explore/tedium tier, keeps large DOM snapshots out of the Opus context entirely (they live and die in the Sonnet subagent, per the subagent-return eviction boundary), and cuts both cost and latency. Consistent with the model-tiering carve-out and the haiku-bash-wrapper rationale.

### 3. Shared retrieval cache across agents and sessions

Redundant re-reads are ~70% of whole-file-read volume, and a transcript-granularity root-cause classification (one `.jsonl` is one context window) shows the redundancy is structural, not behavioral: 97.4% of the reread waste is a fresh subagent (implement/review/judge fan-out) or a later session reading a file cold in its OWN context, only 2.2% is one context re-reading itself, compaction-eviction is 0.33%, and edit-then-verify is negligible (0.05%). The earlier "within-session waste" framing overstated within-agent thrash because a parent session and its subagents share one `session_id`; at true context granularity it is cross-agent.

Implication: the lever is a shared retrieval cache across agents and sessions, not a "don't re-read after editing" discipline (which would address under 0.4% here) and not solvable by any single agent (different agents cannot share a context window). When agent A has read `loro_repo.ts`, agent B (a sibling reviewer, a later leg, a fresh session) should reuse that content instead of paying the cold read again. Graphify symbol-scoped retrieval is complementary: it cheapens each cold read but does not remove the cross-agent redundancy. This is the single largest concentrated retrieval lever found, and it subsumes the earlier wiki-devlog and section-scoped-read recommendations as instances of the same shared-retrieval need.

This workstream is NOT subsumed by workstream 1. Only 0.33% of the reread waste is compaction-eviction; the 97.4% cross-agent share is a fresh context that was never populated, not one that lost the content. A dense summary (workstream 1) re-orients an agent, but a reviewer or implementer that must actually inspect a file needs its real content, which a summary cannot supply. So workstream 1 (summaries and pagination, for orientation and implementer reseed) and workstream 3 (shared cache and graphify, for actual file content reuse) are complementary axes of the same "stop rebuilding context from scratch" goal, not the same fix.

### 4. Cap-and-reseed the warm implementer (do not carry indefinitely)

The durable-specialist pattern keeps the iterate-loop implementer warm across rounds, so its whole transcript is re-sent as cache-read every turn and climbs toward the ~1M window ceiling, where auto-compaction reseeds it lossily (the sawtooth in the dataviz; the top implementer reached 966k and re-billed 445M cache-read = 11.3% of the week). This is a distinct axis from workstream 3: it is per-turn re-send WITHIN one long-lived agent, not cross-agent duplication.

Neither extreme is right. Fresh-every-round over-pays re-briefing while carried context is still small; indefinite carry pays the full sawtooth and ends in a lossy auto-compaction. Propose cap-and-reseed: when an implementer's resident context crosses a cutoff (proposed starting value ~0.2M tokens, well below the ~1M lossy-auto-compaction ceiling; TENTATIVE, to be tuned), checkpoint into the execution-context summary (workstream 1) and dispatch a fresh implementer leg that gets up to speed from that summary plus graphify queries, rather than from the accumulated transcript.

Hard dependency: workstream 4 is only safe once workstream 1 (dense durable summaries) and graphify exist, because a fresh leg with neither is amnesiac and re-reads everything, which is exactly workstream 3's cross-agent waste. Sequencing: build 1 plus graphify, then cap the implementer. One caution on the starting value: observed per-round context peaks run 150k to 966k (the top implementer's first-round peak is already 155k), so a 0.2M cap would reseed roughly every 1 to 2 rounds, close to the fresh-every-round extreme this workstream warns against; a first cut nearer ~0.4 to 0.6M may better balance carry value against re-brief cost. The right cutoff is measurable once workstream 1 makes re-briefing cheap enough to A/B carry-cost against re-brief-cost.

## Open follow-ups (in progress)

1. **General-purpose role classification (resolved).** Done at 100% coverage; see "Implementer vs proposer split" above. It also pinned the labeling root cause: `/cdocs:iterate` (`SKILL.md` line 74) and `/cdocs:propose-revise` (line 46) dispatch their implementer/proposer/reviser roles with bare `subagent_type: "general-purpose"`, whereas `cdocs:reviewer`/`nit-fix`/`judge`/`triage` already have dedicated agent types. Since `usage.db.agents.agent_type` is populated verbatim from `subagent_type`, those roles are invisible. See action item #1 for the fix.
2. **Read-source attribution report (resolved).** See [`cdocs/reports/2026-09-20-read-source-attribution.md`](2026-09-20-read-source-attribution.md). Headline: one-time intake is ~13.2M tokens, of which codebase file reads are 54.7% (Bash output 28.5%, logs/devlogs 9.3%); intake re-amplifies to the 3.94B cache-read total at roughly 1:299 (every read byte re-sent across ~299 later turns). Subagents carry ~95% of intake and the top 2 of ~40 sessions are ~75% of it. The ranked #1 lever is graphify-scoped codebase retrieval (whole-file `Read` averages 2,066 tokens, heaviest 15-18K), which confirms action item #2.
3. **Iterate-loop context-carry dataviz (resolved).** Confirms that a durable resumed implementer accumulates context monotonically across rounds (same `agent_id` re-billed as cache-read every turn), resetting only when it saturates the ~1M window (a sawtooth). Top implementer: 924 turns, 18 rounds, per-round peak context grew 155k to 966k, alone = 11.3% of the week's cache-read; the 46 implementers = 54.8%; corr(rounds, carried context) = 0.89. This is the implementer-side counterpart to the Sonnet-overseer question: long loops may want to checkpoint-and-reset the implementer rather than carry indefinitely. Visualization: https://claude.ai/artifact/UnKXZizrHtgkLTkrNcVrus

## Action items

1. **Label implementer/proposer at dispatch** so the usage DB self-classifies. Concrete fix (from follow-up #1): add `plugins/cdocs/agents/implementer.md` and `proposer.md` (same tool allowlist as the general-purpose catch-all), then change the two dispatch lines to `subagent_type: "cdocs:implementer"` / `"cdocs:proposer"` in `/cdocs:iterate` (`SKILL.md` line 74) and `/cdocs:propose-revise` (line 46). `full-send`/`oversee` inherit the fix by composition. Zero ongoing cost; does not retroactively fix history. Highest-value cheap fix.
2. **Prototype graphify-scoped retrieval for review and implementation**, and enable prompt-cache reuse across loop turns, to attack the ~96%-cache-read cost center.
3. **Investigate the orphaned agent-ids and the `agents.total_tokens` discrepancy** and file upstream against the claude-usage plugin. The handoff report [`2026-09-20-claude-usage-attribution-handoff.md`](2026-09-20-claude-usage-attribution-handoff.md) packages these gotchas and both reconstruction methodologies for the plugin maintainers.
4. **Author a proposal** for the Sonnet-high-overseer-plus-Opus-advisor model, gated on a spike that measures escalation reliability.
5. **Route verbose or log-spammy Bash through a haiku subagent.** Heavy command output is 28.5% of read intake and, once read, pollutes the parent context for the rest of the session. Wrapping such calls in a haiku runner that executes the command and returns only the salient extract keeps logspam out of the Opus context entirely and bounds its lifetime to the subagent. See [`2026-09-20-read-source-attribution.md`](2026-09-20-read-source-attribution.md) recommendation 3. Verified 2026-09-20: the haiku-distill form must be a dispatch convention (Claude Code has no native auto-routing of a Bash call to a subagent); a PostToolUse hook can additionally do deterministic truncation of Bash output at zero LLM cost as a complement.
6. **RFP a granular, wiki-like devlog structure.** Devlogs are read whole-file and re-read across sessions; a sectioned, cross-linked layout (one file per phase or concern, linked from an index) would let agents pinpoint the relevant slice and give subagents agency over their own devlog files. See read-source recommendation 4.

## Caveats

- This is one 7-day window (2026-09-12 to 09-20), dominated by loro-repo propose/implement loops (top 2 of ~40 sessions are ~75% of intake). The role distribution is workload-dependent: implementer-dominance (48.3%) is a hypothesis about this implement-heavy window, not certified structural. A proposal-heavy or debug-heavy week would shift the mix, so a future round should not over-index priorities on this single window.
- Proposer and implementer are now separated (follow-up #1, 100% coverage); the `general-purpose` headline row stays labeled conflated only because it is the raw `agent_type` bucket, with the real split in the sub-role table.
- The overseer bucket is all top-level-session spend, including the lead's own inline edits and reads, not pure orchestration overhead.
- Fable-5.1's cache-write rate is an estimate (its cache-read rate is a documented override); Fable is 7.3% of spend, so the blast radius is limited.
- Weftwise cwd-scoping is reliable here (the excluded 2.1% is genuine other-project work), verified against null/empty cwd checks.
