---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-26T00:00:00-07:00
task_list: cdocs/connectome-research
type: report
state: live
status: review_ready
tags: [meta, tooling, agent-memory, connectome, comparison]
---

# CDocs as a Memory System

> BLUF(sonnet/connectome-research): cdocs is a git-native, filesystem-of-markdown memory substrate, not a retrieval-indexed memory service: every unit is a dated, frontmatter-tagged `.md` file under `cdocs/{devlogs,proposals,reviews,reports}/`, written almost entirely by agents (rarely humans directly), read back at session start via three layered mechanisms (`CLAUDE.md` `@`-imports, a hash-gated `SessionStart` freshness hook, and ad-hoc grep/glob/`/cdocs:status`), and coordinated across concurrent agents via plain-file claim registries and arc-state JSON rather than a shared database.
> It is strong on audit (full git history, frontmatter status lifecycle, structured handoffs) and human legibility, and weak on the things Letta/Zep/mem0-style systems specialize in: there is no salience ranking, no vector/semantic retrieval, no automatic consolidation or forgetting, no cross-project personal memory, and no agent-held persistent "self" (roles are worn per-session, not stored as identity).
> This repo alone has 251 cdocs documents (4.2M); sibling repos scale to 740 (12M, lace) and 1,979 (200M, weftwise), and the read path scales by convention (`/cdocs:status`'s own doc says "practical up to ~100 documents") not by index, so cold-start cost grows roughly linearly with corpus size and is currently unmeasured beyond that self-reported ceiling.

## Context / Background

This report supports a research arc comparing cdocs, Anima Labs' connectome, and retrieval-oriented agent-memory systems (Letta, Zep, mem0).
It characterizes cdocs concretely enough that a later artifact can diagram it: units of memory, write/read paths, coordination primitives, identity model, and a strengths/weaknesses read against memory-system criteria.
Grounded in `plugins/cdocs/rules/*.md`, `plugins/cdocs/skills/{status,triage,report,devlog,oversee}/SKILL.md`, `plugins/cdocs/hooks/{hooks.json,inject-rules.ts,cdocs-hooks.ts}`, this repo's `cdocs/` corpus, and cross-repo counts from `/var/home/mjr/code/weft/{weftwise,lace}/main/cdocs`.

## Units of Memory

Four document types, one frontmatter schema (`plugins/cdocs/rules/frontmatter-spec.md`), one naming convention (`cdocs/<type>s/YYYY-MM-DD-dash-case.md`):

| Type | Directory | Answers | Written by | Lifecycle field |
|---|---|---|---|---|
| **devlog** | `cdocs/devlogs/` | "how did we do the work?" - chronological, stream-of-consciousness during a task | Agent, always (mandated: "Always create a devlog when starting substantive work") | `status`: wip -> review_ready -> done |
| **proposal** | `cdocs/proposals/` | Design decision to be made, with implementation phases | Agent, via `/cdocs:propose`; occasionally a human `@username` | `status`: request_for_proposal -> wip -> review_ready -> implementation_ready -> implementation_accepted \| evolved |
| **review** | `cdocs/reviews/` | Structured verdict on another doc, via `review_of` field pointing back at the subject | Agent, via `/cdocs:review` (opus-tier reviewer) | No `status` lifecycle of its own; carries the verdict that updates the *subject's* `last_reviewed` |
| **report** | `cdocs/reports/` | "what did we learn/accomplish?" - audience-facing, BLUF-led, archived as reference | Agent, via `/cdocs:report`, after research/analysis | `status`: wip -> review_ready -> done |

Every document's frontmatter is a fixed, machine-parseable key set: `first_authored.{by,at}`, `task_list` (a `/`-namespaced workstream id), `type`, `state` (`live | deferred | archived`), `status` (per-type enum above), optional `last_reviewed.{status,by,at,round}`, `tags`.
This is the entire "schema" of the memory system: no separate metadata store, the frontmatter block *is* the index, parsed by re-reading each file (see Read/Retrieval below).

A fifth informal unit sits above these: the **arc-state file** (`.claude/oversee/<arc-id>.json`, normative in `plugins/cdocs/rules/oversee-arc.md`), a plain JSON file (not a `cdocs/` markdown doc) tracking which proposals in a multi-proposal arc are done, who owns them, and their required verification rung. This is the closest thing cdocs has to session/task *state* as opposed to narrative content, and it is explicitly not prose: "read and reconciled PROGRAMMATICALLY by a possibly-concurrent second session, so it is structured fields, not the free prose of a devlog."

Corpus scale (this repo, `cdocs/`, 4.2M total):

| Type | Count (this repo) | Count (lace) | Count (weftwise) |
|---|---|---|---|
| devlogs | 86 | 128 | 496 |
| proposals | 45 | 171 | 437 |
| reviews | 76 | 276 | 798 |
| reports | 44 | 165 | 248 |
| **Total** | **251** | **740** | **1,979** |
| **Dir size** | **4.2M** | **12M** | **200M** |

Word count across this repo's four directories: ~481,000 words (roughly 640K-720K tokens at typical markdown token density), for 251 documents, i.e. an average document is ~1,900 words (~2,500-2,900 tokens). None of this is loaded at session start by default (see below); it is loaded on demand by grep/glob/explicit Read.

## Who Writes, and Write Triggers

Writing is agent-dominated by construction, not merely by convention:

- **Devlog**: triggered at the start of "substantive work" (`writing-conventions.md` "Devlog Convention"); the acting agent authors it and keeps it current, "not at the end." A `PreToolUse` hook (`validate-cdocs-edit-path.sh`) additionally restricts *which* subagents (triage, nit-fix, reviewer) may write to which `cdocs/` subdirectories, so write access is agent-role-scoped, not just convention-scoped.
- **Proposal**: triggered by `/cdocs:propose` (human- or agent-invoked), authored by the `proposer` agent or the top-level session.
- **Review**: triggered by `/cdocs:triage`'s `[REVIEW]` recommendation or direct `/cdocs:review` invocation; always the `reviewer` agent (opus-tier per `model-tiering.md`), never the document's own author (separation of authorship and verdict is structural, enforced by which agent is dispatched, not by a lock).
- **Report**: triggered ad hoc after research/analysis work, or by a `/cdocs:report` invocation; typically the agent that did the investigation.
- **Frontmatter mutation**: `/cdocs:status --update` (direct field edit, usually human- or overseer-invoked) and `/cdocs:triage` (mechanical fixes plus `[STATUS]` recommendations the calling agent applies via `Edit`). A `PostToolUse` hook (`cdocs-validate-frontmatter.sh` / the OC `cdocs-hooks.ts` equivalent) validates required-field presence after every `Write`/`Edit` on a `cdocs/**/*.md` path, non-blocking (warning only).
- **Human authorship** is possible (`first_authored.by: "@username"`) but rare in the sampled corpus; the schema treats human and agent authors identically (same `@`-prefixed field), which is itself a design signal: cdocs does not model "agent-authored" vs. "human-authored" as a distinct trust tier.

## Read / Retrieval Path

There is no single retrieval call; a fresh agent session accumulates context through four independent, layered mechanisms, none of which do semantic search:

1. **`CLAUDE.md` `@`-imports (static, always-on).** The project's root `CLAUDE.md` `@`-imports `.claude/rules/cdocs.md`, which is materialized rule *content* (workflow discipline, frontmatter spec, orchestration rules), not corpus *content*. This is the only thing guaranteed present in every session's initial context, and it never changes per-task: it is procedural memory (how to work), not episodic memory (what happened).
2. **`SessionStart` hash-gated freshness hook (`inject-rules.ts`).** Computes a sha256 over the plugin's current `rules/*.md` bodies, compares it to a marker hash embedded in `.claude/rules/cdocs.md`, and on mismatch emits a <500-byte `additionalContext` directive telling the agent to re-run `/cdocs:init` and `Read` the result. Silent (zero tokens) when hashes match or cdocs is uninitialized. This is a staleness detector for the rule layer only; it injects no document content and performs no retrieval over `cdocs/` documents themselves.
3. **Query tools, invoked, not automatic.** `/cdocs:status` globs `cdocs/**/*.md`, reads every file's frontmatter, and renders a filterable table (`--type`, `--state`, `--status`, `--tag`); its own doc flags this as "practical up to ~100 documents" and suggests (unbuilt) alternatives - a `cdocs/.index.json` maintained by hooks, or an MCP server - for larger corpora. `/cdocs:triage` does the same read-every-file scan but adds a semantic layer for proposals: it locates the paired `/cdocs:iterate` devlog for a proposal's `task_list` and reads its last Iteration Log/Judge Log row to override the blind status heuristic. Both are O(corpus size) full scans, not indexed lookups.
4. **Ad hoc grep/glob and human-directed pointers.** In practice, most retrieval is an agent (or the user) grepping `cdocs/` for a keyword, or a document explicitly linking another (`review_of`, inline markdown links, `task_list` shared across a workstream's devlog/proposal/report set). Cross-document linking is manual and citation-based, not automatic; there is no backlink index.
5. **Handoffs and arc-state as compaction-time retrieval.** `orchestration-discipline.md` Pillar 2 defines a devlog handoff (Completed / Decisions Made / Open Todos) written *before* `/compact`; project-root `CLAUDE.md` and unscoped rules re-inject automatically on compaction (verified against CC's documented "what survives compaction" behavior), while the handoff itself is retrieved only if the next agent is told to `Read` it or resumes the same session. The `.claude/oversee/<arc-id>.json` arc-state file plays the same role at cross-proposal granularity, reconciled programmatically on resume against the proposal's own frontmatter `status` and its devlog's last handoff (a three-way reconciliation, since "no single field is trusted to have been written atomically at the terminal moment").

Net: retrieval is pull-based and enumerative (full directory scan + frontmatter filter, or manual grep), never push-based or ranked. A 2026-09-19 report (`devlog-methodology-value.md`) independently measured that Anthropic's own structured-note-taking pattern cut a follow-on session's re-reads from 8 files to 4 and peak context from ~334K to ~173K tokens when the notes were current - the same mechanism cdocs' devlog handoff targets, but cdocs has no built-in enforcement that the *next* session actually reads the handoff versus re-deriving it from scratch.

## Consolidation and Forgetting

There is no automatic consolidation or forgetting; state transitions are agent- or human-driven frontmatter edits, and the underlying file is never deleted:

- **`state: archived`** marks a document inactive; the file remains on disk and in git history, fully greppable, just excluded from an agent's default mental model of "current."
- **`status: evolved`** (proposals only) marks superseded-by-a-follow-up, again without deletion; the superseding document is expected to link back.
- **No compaction of the corpus itself.** Unlike a devlog's *content* (which orchestration-discipline recommends collapsing into a handoff before context-window compaction), the *document set* is never merged, summarized, or pruned - a proposal from March 2026 and one from September 2026 are equally present, equally findable by grep, and equally counted by `/cdocs:status`. The 2026-09-01 `devlog-token-value-analysis.md` and 2026-09-19 `devlog-methodology-value.md` reports both flag long-running "iterate" devlogs (13-46KB observed) as drifting toward append-only chronologies that fail the "30-second orientation" bar - a legibility failure mode with no corpus-level forgetting mechanism to counteract it.
- **Compaction-adjacent design work is proposed, not shipped.** The 2026-09-22 `chat-record-scratchpoint-design.md` report proposes a hook-written verbatim "chat record" and an agent-authored "scratchpoint" (finer-grained than the devlog handoff) specifically to close the granularity gap between per-turn work and the every-3-5-iteration handoff cadence; as of this report, that is a design, not a built mechanism.

## Identity Model

cdocs has **no persistent agent identity or cross-session self-model**. Roles (overseer, implementer, reviewer, judge, triage) are behavioral disciplines a session or subagent *wears for the duration of a dispatch*, defined entirely in `orchestration-discipline.md` and per-agent frontmatter (`agents/*.md` tool allowlists), not stored state about a continuing entity:

- **"Overseer" names a discipline, not an artifact type**: "it is not an `agents/` entry, because the overseer is almost always the top-level session... and a dispatched subagent cannot dispatch its own workers." There is no file that says "I am the overseer and I remember X about this project across arcs" beyond the arc-state JSON's bookkeeping of *task* state, not agent *identity*.
- **Durable specialists (Pillar 3) are the closest analogue to persistent identity**: a named, resumable subagent (e.g. `arc-impl-a`) addressed by name via `SendMessage`, carrying a workstream's accumulated context across turns. This is scoped to one workstream's lifetime, bounded "one specialist per active workstream," and disposed of when the workstream ends - not a persistent personality or long-lived preference store.
- **Attribution is by model name/version, not by continuing agent.** Frontmatter `first_authored.by: "@claude-sonnet-5"` and NOTE/TODO/WARN callouts (`NOTE(opus/triage-subagent): ...`) attribute *content* to a model-and-workstream pair, which is provenance, not identity: two `@claude-sonnet-5` entries in different documents share no memory of each other beyond what's re-read from disk.
- **No agent-held preferences or relationships.** Nothing in cdocs stores "this reviewer tends to flag X" or "this user prefers Y" as agent-side state; any such pattern would have to be re-derived by reading past reviews/devlogs each time, i.e. it is corpus content, not agent memory.

## Multi-Agent Coordination Primitives

Coordination is cooperative and file-based, never a lock service:

- **Single-writer file ownership** (`orchestration-discipline.md` Pillar 1b): before dispatching a writer, the overseer checks whether another live agent already claims that path, via the Iteration Log or devlog, and serializes or re-scopes if so.
- **Cross-arc claim registry** (`.claude/oversee/claims/*.json`, one file per claim, repo-global, outside any single devlog): extends single-writer ownership across concurrent `/oversee` sessions/worktrees. Each claim file records `arc_id`, `owner`, claimed `globs`, `acquired_at`, and a `liveness` field (`live | stale`) reconciled on resume - a stale claim whose owner has no live children left is released rather than deadlocking the arc.
- **Footprint-overlap serialization heuristic**: two proposals whose declared/predicted path globs intersect must serialize; disjoint footprints may interleave, subject to the one-specialist-per-workstream bound. Uncertain footprints default to serialize ("a false conflict costs only latency, a missed conflict costs a clobber").
- **On-resume liveness reconciliation** (Pillar 1b): the harness notifies the overseer only when no live children remain, so a resumed session must re-derive dispatch/return state from the Iteration Log's event rows rather than trusting in-window recollection - documented against a real deadlock incident where a full-send session re-reported "child in flight" after the harness had already returned control.
- **Verification-depth ladder** (`compile | unit | integration | smoke | live`): a shared vocabulary for how much proof a proposal's implementation must show before acceptance, letting the overseer set a `--verification-floor` per proposal rather than negotiating proof standards ad hoc.

None of this is a database transaction or a mutex; every primitive above degrades to "a plain JSON or markdown file another session can read," which is also why it degrades gracefully cross-tool (OpenCode gets the same claim/arc-state files, only losing the `SendMessage`/`fork`/`compact` runtime conveniences, per both rules' "Cross-Target Degradation" sections).

## Auditability via Git

Every unit of memory is a git-tracked file, so the entire memory system inherits git's audit properties for free: full History (`git log`), diff-based review of any edit including frontmatter status transitions, blame-level authorship (though `first_authored.by` is more precise than git blame for agent attribution), and no privileged read path - anyone with repo access sees exactly what any agent saw. The `PreToolUse`/`PostToolUse` hooks add a second audit layer (path-scoped write restriction, frontmatter-completeness warnings) enforced at write time rather than after the fact. This is the single clearest strength relative to a database-backed memory service: there is no opaque store to trust, and reconstructing "what did the system believe on date X" is a `git checkout` away.

## Strengths

- **Audit and provenance**: git history plus `first_authored`/`last_reviewed` frontmatter gives exact, cheap, tamper-evident answers to "who wrote/reviewed this and when," with no separate audit log to maintain.
- **Human legibility**: every unit is markdown, readable in any editor or GitHub, with a fixed BLUF-first structure (`writing-conventions.md`) optimized for a human or fresh agent to orient in under 30 seconds - a design goal actually referenced by name in the orchestration rules.
- **Determinism and inspectability**: no embeddings, no black-box ranking; retrieval failures are explainable ("the grep didn't match" or "the file wasn't read"), not "the vector search missed it."
- **Structured review as first-class memory**: reviews are typed documents with their own lifecycle (`review_of`, verdict, round count), not just chat feedback lost after the session - making "was this ever reviewed, and what was found" a queryable fact.
- **Cheap, tool-agnostic durability**: the entire substrate is files a shell, any editor, or any other agent framework can read; cross-target degradation (OpenCode, generic AGENTS.md) is designed in, not bolted on.
- **Cooperative multi-agent safety without infrastructure**: claim files and footprint-overlap serialization give real (if soft) clobber protection with zero external services.

## Weaknesses

- **No salience or ranked retrieval.** Every read path (status, triage, grep) is either a full corpus scan or a manual keyword search; there is no notion of "the most relevant memory for this task," no embeddings, no recency-weighted ranking. `/cdocs:status`'s own doc admits this: "practical up to ~100 documents," with an index file or MCP server named as unbuilt future work.
- **Cold-start cost scales with corpus size, unmeasured past ~100 docs.** This repo (251 docs, 4.2M) is inside the stated ceiling; lace (740 docs, 12M) and weftwise (1,979 docs, 200M) are well past it, and no report in this arc's source set benchmarks actual token cost or agent latency for `/cdocs:status`/`/cdocs:triage` at that scale.
- **No cross-project personal memory.** Nothing in cdocs carries a fact, preference, or relationship from one repo to another, or across a `--type` boundary the frontmatter doesn't index; a user's stated preference in one repo's devlog is invisible to an agent in a sibling repo (weftwise, lace) unless a human copies it over.
- **No agent-held identity, preferences, or relationships.** As covered above, "overseer"/"reviewer"/etc. are per-dispatch costumes, not continuing entities; a system like Letta's persistent agent-with-memory-blocks or mem0's per-user preference graph has no analogue here - every fact about "how this reviewer tends to judge things" must be re-derived from reading past review documents, not retrieved from an agent-side memory store.
- **No automatic consolidation or forgetting.** `archived`/`evolved` states hide a document from an agent's working mental model but never merge, summarize, or prune it; the corpus is monotonically growing (1,979 docs in weftwise) with no compaction mechanism for the document set itself, only for a single session's context window.
- **Reliance on agent compliance, not enforcement.** Several mechanisms are explicitly non-binding: the `SessionStart` freshness hook's effect "depends on the agent honoring an injected directive" (documented as empirically high but not guaranteed); frontmatter validation hooks warn, never block; the orchestration discipline itself has "graded, not hard" enforcement because "a hard tool-allowlist on the top-level session is not available." A memory system whose write discipline is advisory is weaker than one enforced by schema or transaction.
- **Doc sprawl and legibility drift at scale.** Multiple internal reports (`devlog-token-value-analysis.md`, `devlog-methodology-value.md`) flag specific 13-46KB devlogs that fail their own "30-second orientation" bar; the mechanism that produces memory (mandatory devlogs on all substantive work) has no built-in pressure toward brevity beyond a style guideline, so quality is uneven across the corpus by the project's own admission.
- **Granularity gap between turn and handoff.** The devlog handoff cadence is "every 3-5 iterations," which the 2026-09-22 `chat-record-scratchpoint-design.md` report identifies as coarser than a single compaction boundary - meaning a mid-cadence compaction can still lose a window's worth of work; the proposed fix (chat record + scratchpoint) is designed but not built as of this report.

## Recommendations

None specific to this report; it is a characterization for the connectome-comparison arc, not a design proposal. The clearest open threads for a follow-on proposal, based on the gaps above: (1) build the unbuilt `cdocs/.index.json` or MCP query layer `/cdocs:status` already names as its own scaling escape hatch; (2) decide whether cross-project memory (a fact or preference surviving from lace to weftwise to this repo) is in scope for cdocs at all, or is deliberately out of scope as a human-mediated boundary; (3) evaluate the chat-record/scratchpoint proposal's cost against the granularity gap it targets before building it.
