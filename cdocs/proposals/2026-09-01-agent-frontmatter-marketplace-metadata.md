---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-01T00:00:00-07:00
task_list: cdocs/agent-frontmatter-marketplace
type: proposal
state: live
status: review_ready
last_reviewed:
  status: revision_requested
  by: "@claude-opus-4-8"
  at: 2026-09-01T12:00:00-07:00
  round: 1
tags: [subagents, marketplace, frontmatter, discovery, architecture]
---

# Agent Frontmatter and Marketplace Discovery Metadata

> BLUF: Adopt verified subagent frontmatter (`color`, `maxTurns`, and selectively `memory: project`) on the four cdocs agents, and add discovery metadata (`tags` in `marketplace.json`, `keywords` in `plugin.json`).
> `memory` is deliberately WITHHELD from `reviewer` and `judge` to preserve their "fresh eyes, no prior commitment" invariant.

## Objective

Two small, independent enhancements to cdocs packaging:

1. Enrich the four cdocs subagent definitions with supported CC frontmatter fields that improve visual identification (`color`), guard runaway loops (`maxTurns`), and grant persistent per-project memory (`memory`) where it helps and no invariant forbids it.
2. Add plugin-discovery metadata to the marketplace entry and plugin manifest so the cdocs plugin surfaces under sensible search and category terms.

Codex support and non-Claude-Code/OpenCode packaging are out of scope and deferred.

## Background

Two authoritative sources ground the field choices below.
No field is proposed that is not verified against one of them.

### Subagent frontmatter fields (source: [sub-agents docs](https://code.claude.com/docs/en/sub-agents.md))

All three fields are real and supported:

- `color`: string, one of `red | blue | green | yellow | purple | orange | pink | cyan`. Cosmetic; drives the agent's display color.
- `maxTurns`: integer, camelCase (NOT `max_turns`). When the cap is hit, the agent's output is marked partial (resumable). Partial-marking requires CC v2.1.246+.
- `memory`: string, one of `user | project | local`. Grants a persistent memory scope across invocations. `project` resolves to `.claude/agent-memory/<name>/`.

> NOTE(claude-opus-4-8/cdocs/agent-frontmatter-marketplace): All three fields are recent CC additions.
> They degrade harmlessly on older CC versions (an unrecognized field is ignored, not an error), so the change is safe to ship ahead of a version floor.

### Manifest schemas (schemastore draft-07)

The fields used below are each an *explicitly declared* property in its schema, with a typed array definition: they are first-class, not merely tolerated by lenient `additionalProperties`.

- [`marketplace.json`](https://www.schemastore.org/claude-code-marketplace.json) per-plugin entry declares both `category` (string) and `tags` (array&lt;string&gt;), with no enum constraint on values.
  The top-level object and the `metadata` object do NOT declare `tags`.
  The cdocs entry already carries `category: "productivity"`.
- [`plugin.json`](https://www.schemastore.org/claude-code-plugin-manifest.json) (plugin-manifest) top-level declares `keywords` (array&lt;string&gt;) but NOT `category` or `tags`.
  So the manifest uses `keywords`, and `category`/`tags` are dropped there as undeclared.

> NOTE(claude-opus-4-8/cdocs/agent-frontmatter-marketplace): Both schemas are `additionalProperties`-lenient, so an undeclared field would survive validation rather than fail outright.
> The split above does not rely on that leniency: each field is a declared property in the schema it lands in, which is what keeps the manifests portable to tooling that enforces the schema strictly.

## Proposed Solution

### Part 1: Subagent frontmatter

Assign fields per agent by matching each field's semantics to the agent's role.

| Agent | model | color | maxTurns | memory | Rationale |
|-------|-------|-------|----------|--------|-----------|
| triage | haiku | green | (omitted) | project | Mechanical frontmatter fixer, but runs in BATCH mode over many docs; turn count scales with corpus size, so no fixed cap (same reasoning as reviewer). A per-project memory scope lets it accumulate the project's frontmatter conventions (tag vocabulary, status norms) across sessions. |
| nit-fix | haiku | yellow | (omitted) | project | Writing-convention enforcer that BATCH-scans `cdocs/**/*.md`; turn count scales with corpus size, so no fixed cap. Per-project memory lets it retain learned conventions and edge-case classifications across runs. |
| reviewer | opus | purple | (omitted) | WITHHELD | Live-system review is legitimately open-ended; a low cap would truncate reviews to "partial". `memory` withheld to preserve freshness (see below). |
| judge | opus | red | 10 | WITHHELD | Reads the iteration log plus recent reviews and returns one bounded decision; no source, no verification, no corpus scaling. 10 turns is ample. `memory` withheld to preserve freshness. |

#### `maxTurns` principle: cap only intrinsically-bounded, non-corpus-scaled work

The governing rule: apply `maxTurns` ONLY where an agent's work is intrinsically bounded and does NOT scale with input or corpus size.
A cap on input-scaled work bites on large inputs and produces a *partial* output, which is strictly worse than a complete result that took longer.
By this rule, only `judge` gets a cap (`10`); `triage`, `nit-fix`, and `reviewer` are all left uncapped.

`reviewer` is the clearest uncapped case.
Its charter is empirical self-investigation of a live system: reading referenced files, running tests, starting a dev server, `curl`-ing endpoints (see `reviewer.md` Constraints).
Turn count for a thorough review is genuinely data-dependent and unbounded in principle.
A cap that bites produces a review marked *partial*: an unreliable verdict, and the whole `/cdocs:iterate` loop keys off reviewer verdicts.

`triage` and `nit-fix` are uncapped for the same structural reason, one turn removed.
Both run in BATCH mode over the document corpus: `nit-fix`'s skill scans `cdocs/**/*.md` and runs on every match, and `triage` processes an arbitrary list of documents.
Their turn count is a function of corpus size, not a fixed small constant, so a `maxTurns: 20` would bite exactly on a large corpus and truncate a batch run to *partial*: the same failure mode the reviewer argument rejects.
Leaving them uncapped keeps the design internally consistent.

The runaway risk a cap would otherwise guard against is already covered structurally for all three: agents run inside container isolation, the overseer is free to discard bad output, and the loop terminates on accept-or-escalate.
A turn cap is the wrong layer for that guard.

`judge` is the one agent whose work is genuinely bounded and corpus-independent: it reads the iteration log plus a couple of recent reviews, makes one decision, and does no batch or source scan.
`10` turns comfortably covers that, so the cap guards against pathology without any risk of truncating correct work.

### Part 2: Discovery metadata

Add `tags` to the cdocs entry in `marketplace.json` (keeping the existing `category`):

```json
"tags": ["documentation", "devlog", "proposal", "review", "workflow", "subagents"]
```

Add `keywords` to `plugin.json`:

```json
"keywords": ["documentation", "devlog", "proposal", "review", "workflow", "subagents"]
```

The two lists are intentionally identical in value: they describe the same plugin, differ only in the field name each schema mandates, and keeping them in sync avoids divergent discovery behavior between the marketplace listing and the installed manifest.

Term selection (tight set, discovery-oriented):

- `documentation`: the plugin's domain.
- `devlog`, `proposal`, `review`: the three primary document types users search for.
- `workflow`: captures the propose/implement/iterate/review arc.
- `subagents`: the plugin ships four subagents; a discriminating term for users seeking agent-based tooling.

Deliberately excluded: `report` (fourth doc type, but lower search salience than the primary three; kept the set tight), and generic terms like `markdown` or `productivity` (`productivity` is already the `category`).

## Important Design Decisions

### `memory` is withheld from `reviewer` and `judge` (freshness invariant)

This is the load-bearing decision of Part 1.

The `/cdocs:iterate` loop depends on a freshness discipline (`skills/iterate/SKILL.md`, "Freshness disciplines"):

> Reviewers are fresh every iteration.
> The judge is fresh every invocation.

Both agents are dispatched fresh precisely so they carry NO anchoring from prior rounds.
The reviewer must read each iteration's output with fresh context and no prior commitment to the implementation (`reviewer.md` Constraints leans on exactly this freedom).
The judge is a fresh meta-reviewer whose whole value is an uncommitted read of loop health (`judge.md`).

A persistent `memory` scope directly defeats this: it would leak prior-round commitments, verdicts, and impressions into the next dispatch, re-anchoring an agent whose correctness depends on having none.
Granting `memory` to these two would silently convert "fresh every round" into "cumulatively biased," undermining the loop's core discipline while leaving no visible trace in the loop mechanics.

`triage` and `nit-fix` have no such invariant.
They are mechanical enforcers whose quality *improves* with accumulated knowledge of the project's conventions, so `memory: project` is a net benefit there.

The dividing line is precise: memory helps an agent that should accumulate; it harms an agent that should forget.

### marketplace-entry vs manifest field split

`tags` and `keywords` are not interchangeable across the two files.
The marketplace per-plugin entry schema declares `tags`; the plugin-manifest schema declares `keywords` and rejects `tags`/`category`.
Using the field each schema declares keeps both files portable to strict-schema tooling.
The values are kept identical so discovery is consistent regardless of which surface a user searches.

## Edge Cases / Challenging Scenarios

- **`maxTurns` casing**: the field is camelCase. `max_turns` would be silently ignored (snake_case is not the schema key), leaving no cap and no error. Author the exact key `maxTurns`.
- **`color` value typo**: an out-of-enum color is cosmetic-only and low-severity, but should still match the documented enum to avoid a fallback/default color.
- **JSON validity**: adding an array field to either manifest must preserve valid JSON (comma placement, no trailing comma). A malformed manifest breaks plugin load entirely, which is high-severity.
- **Reviewer with no cap**: intended. If a reviewer ever genuinely runs away, that is a container/overseer concern, not a frontmatter concern.

## Verification Methodology

The failure picture is concrete and observable:

- **Agent frontmatter**: invalid YAML in an agent file, or an unsupported/misspelled field, surfaces as the plugin failing to load or the affected agent failing to register.
  After editing, confirm each of the four agents still registers (e.g. the agent list resolves the four cdocs agents) and that YAML parses.
  `color` should render as the assigned color; the only `maxTurns` is on `judge` (`10`), whose bounded workload should never hit it.
- **JSON manifests**: both `marketplace.json` and `plugin.json` must remain valid JSON and schema-conformant.
  Verify with a JSON parser (e.g. `jq . <file>`) that each file parses, and confirm the new arrays sit on the correct object (the per-plugin entry for `tags`; the top-level for `keywords`).
- **OpenCode build**: the four agent files are canonical source for the multi-target build (`scripts/build-opencode.ts`), so run `npm run build:cdocs` and confirm it still builds clean.
  The intended result is CC/OC divergence, not parity: `generateOCFrontmatter` emits a fixed allowlist (`description`, `mode`, `model`, `tools`, `skills`) and drops unknown keys, so `color`/`maxTurns`/`memory` are silently omitted on the OC target.
  This is expected and in fact desirable: because OC emits no `memory` field, the freshness invariant is trivially preserved there too.
  These three fields are CC-only by design; their absence on OC is not a regression.
  > NOTE(claude-opus-4-8/cdocs/agent-frontmatter-marketplace): If OC-side parity is ever wanted (e.g. `memory`-withholding expressed explicitly on OC), the build allowlist in `generateOCFrontmatter` must be extended. Out of scope here; noted as a known follow-up.
- **Marketplace round-trip**: `/plugin marketplace add .` then `/plugin install cdocs@clauthier` should still succeed, confirming neither manifest change broke discovery or install.

## Implementation Phases

Two small, independent phases. Either may land first; no ordering dependency.

### Phase 1: Agent frontmatter

Edit the frontmatter blocks of the four agents per the field table above.
Do NOT modify agent body content.
Do NOT add `memory` to `reviewer.md` or `judge.md`.
Do NOT add `maxTurns` to `reviewer.md`, `triage.md`, or `nit-fix.md` (batch/open-ended work; `maxTurns` lands only on `judge`).

- `plugins/cdocs/agents/triage.md`: add `color: green`, `memory: project`.
- `plugins/cdocs/agents/nit-fix.md`: add `color: yellow`, `memory: project`.
- `plugins/cdocs/agents/reviewer.md`: add `color: purple`.
- `plugins/cdocs/agents/judge.md`: add `color: red`, `maxTurns: 10`.

Verify: all four agents register; YAML parses; `npm run build:cdocs` builds clean (the three CC-only fields are expected to be dropped on the OC target).

### Phase 2: Discovery metadata

- `.claude-plugin/marketplace.json`: add the `tags` array to the cdocs per-plugin entry, alongside the existing `category`.
- `plugins/cdocs/.claude-plugin/plugin.json`: add the `keywords` array at top level.

Verify: `jq .` parses both files; marketplace add/install round-trip succeeds.
