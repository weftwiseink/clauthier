---
review_of: cdocs/proposals/2026-09-01-agent-frontmatter-marketplace-metadata.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-01T12:00:00-07:00
task_list: cdocs/agent-frontmatter-marketplace
type: review
state: live
status: done
tags: [fresh_agent, frontmatter, subagents, marketplace, schema_verified, missing_validation, multi_target]
---

# Review: Agent Frontmatter and Marketplace Discovery Metadata

## Summary Assessment

The proposal adopts three verified CC subagent frontmatter fields (`color`, `maxTurns`, `memory`) across the four cdocs agents and adds discovery metadata (`tags` on the marketplace entry, `keywords` on the plugin manifest).
Every load-bearing factual claim checks out against primary sources: the three subagent fields exist with exactly the claimed value domains, the marketplace-vs-manifest schema split is correct (`tags`/`category` are first-class on the per-plugin entry, `keywords` is the manifest's declared field), and the memory-withholding rationale is faithfully grounded in the iterate skill's freshness discipline.
The design is sound and well-argued; the verdict is **Revise (light)** for two unaddressed interactions, both cheap to fix: (1) `maxTurns: 20` on the batch-capable `nit-fix`/`triage` agents can trigger the same "partial truncation" failure the proposal rightly rejects for `reviewer`, and (2) the change edits canonical source that feeds the OpenCode build, which the Verification Methodology never mentions.

## Verification of Factual Claims

All external claims were checked against primary sources, not taken on faith.

| Claim | Source | Result |
|-------|--------|--------|
| `color` enum: `red\|blue\|green\|yellow\|purple\|orange\|pink\|cyan` | [sub-agents docs](https://code.claude.com/docs/en/sub-agents.md) | Confirmed exact |
| `maxTurns` camelCase, integer, hit -> output marked partial (resumable) | sub-agents docs | Confirmed. Partial-marking needs CC v2.1.246+ (see below) |
| `memory`: `user\|project\|local`, persistent cross-session scope | sub-agents docs | Confirmed exact. `project` -> `.claude/agent-memory/<name>/` |
| marketplace per-plugin entry supports `category` + `tags` (array, no enum); top-level/`metadata` do NOT | [claude-code-marketplace schema](https://www.schemastore.org/claude-code-marketplace.json) | Confirmed. `tags` is an explicitly declared property, not merely tolerated |
| plugin manifest supports `keywords` (array<string>); NOT `category`/`tags` at top level | [claude-code-plugin-manifest schema](https://www.schemastore.org/claude-code-plugin-manifest.json) | Confirmed. `keywords` declared; `category`/`tags` undeclared |
| Freshness quote: "Reviewers are fresh every iteration. The judge is fresh every invocation." | `skills/iterate/SKILL.md` L128-129 | Confirmed verbatim |
| Existing `category: "productivity"` on cdocs entry | `.claude-plugin/marketplace.json` L16 | Confirmed |

Current agent frontmatter confirms none of the target fields are yet present, so the edits are purely additive: `triage`/`nit-fix` (haiku, `Read,Glob,Grep,Edit`), `reviewer` (opus, `tools: "*"`, `skills: [cdocs:review]`), `judge` (opus, `Read,Glob,Grep,Write`).

## Section-by-Section Findings

### Objective and scope hygiene
No creep. Codex and non-CC/OpenCode packaging are explicitly deferred (L24), and the body holds to exactly the two stated parts. Clean.

### Part 1: Subagent frontmatter (field table)
The per-agent assignments are internally consistent and role-matched. Colors are distinct and within enum. `memory: project` on the two mechanical enforcers and its omission on the two loop agents is the right shape.

**Non-blocking (important) - `maxTurns: 20` collides with batch mode.**
`nit-fix`'s skill explicitly runs over the whole corpus: "Scan `cdocs/**/*.md` for all cdocs documents and run nit-fix on all of them (batch mode)" (`skills/nit_fix/SKILL.md` L26); `triage` similarly processes multiple documents.
The proposal's own load-bearing argument against capping `reviewer` - "A cap that bites produces a review marked *partial*, which is strictly worse than a complete review that took longer" (L73) - applies with equal force to a batch `nit-fix`/`triage` run over a large document set, where read+edit cycles across N docs can exceed 20 agentic turns.
The proposal asserts "The other three agents are legitimately bounded" (L77), but a batch run is bounded by corpus size, not by a fixed small constant.
This is a genuine internal inconsistency, not just a tuning nit. Mitigations to weigh: a batch run may parallelize tool calls within a turn (haiku can), and `maxTurns` output is resumable, so worst case is recoverable rather than lost. Resolve by either raising/removing the cap on the batch agents with the same reasoning used for `reviewer`, or adding one sentence establishing that batch runs stay within 20 turns (with the parallelism/resumability argument made explicit).

### Part 1: `maxTurns` on reviewer (omit rather than cap)
The argument is correct and well-reasoned: open-ended empirical review vs a bounded partial-verdict that the whole `/cdocs:iterate` loop keys off. The "wrong layer for that guard" framing (container isolation + overseer discard + loop termination) is sound. No issue.

### Part 2: Discovery metadata
Field split is correct and verified. Identical term lists across the two surfaces is well-justified (same plugin, divergent-discovery avoidance). Term selection is defensible and the exclusion rationale (`report`, `markdown`, `productivity`) is stated. No issue.

**Non-blocking (minor) - "additionalProperties-lenient" undersells the marketplace schema.**
The Background NOTE (L47) frames both schemas as merely lenient toward unsupported fields. For `marketplace.json` this understates the truth: `tags` is an *explicitly declared* property with a typed array schema, not a field that only survives on leniency. The field-split section (L129-132) gets this right; only the Background framing is loose. Tighten to distinguish "declared field" from "tolerated-via-leniency."

### Important Design Decisions: memory withholding
This is the strongest part of the proposal. The reasoning - persistent memory would leak prior-round commitments into an agent whose correctness depends on carrying none - is precise, correctly scoped to `reviewer`/`judge`, and cross-checks cleanly against the iterate freshness discipline. "Memory helps an agent that should accumulate; it harms an agent that should forget" is the right dividing line. Accept as-is.

### Verification Methodology
Concrete and observable for the CC surface: invalid YAML -> agent fails to register; invalid JSON -> plugin load breaks; `jq .` parse check; marketplace add/install round-trip. Good.

**Non-blocking (important) - missing OpenCode-build verification.**
The repo is explicitly multi-target (CLAUDE.md "Multi-Target Marketplace"): `scripts/build-opencode.ts` regenerates OC agent artifacts from these same canonical agent files.
I inspected the build script: `generateOCFrontmatter` (L167) emits only a fixed allowlist - `description`, `mode`, `model`, `tools`, `skills` - and `parseFrontmatter` (L130) stores unknown scalar keys but never re-emits them. So `color`, `maxTurns`, and `memory` are silently dropped in the OC build.
The good news, and it should be stated as a positive verification result: this means Part 1 does NOT break the OC build (unknown scalar keys parse without throwing), and the freshness invariant is trivially preserved on OC because `memory` is dropped there too.
The gaps the proposal should close: (a) add `npm run build:cdocs` to the verification steps and assert it still succeeds; (b) acknowledge that CC and OC agents intentionally diverge on these three fields (OC gets none of them), consistent with the out-of-scope line; optionally (c) note that if OC-side parity is ever wanted, the build allowlist must be extended - out of scope now, but a known follow-up.

**Non-blocking (minor) - no minimum-CC-version note.**
`maxTurns` partial-marking requires CC v2.1.246+ (per the docs), and `memory`/`maxTurns`/`color` are all recent additions. A one-line note that these fields require a recent CC and degrade harmlessly (ignored) on older versions would complete the failure picture.

### Edge Cases
Solid coverage: `maxTurns` casing (`max_turns` silently ignored), out-of-enum color severity, JSON validity as high-severity, reviewer-no-cap as intended. The camelCase warning is especially valuable. No issue.

### Writing conventions
Largely compliant: BLUF present, sentence-per-line, colons over em-dashes (none found), history-agnostic. Minor nits:
- The two `$schema` URLs are referenced by prose ("schemastore draft-07", L40) but not given as direct links, unlike the sub-agents docs link. Convention prefers direct HTTP links for external references.
- A few semicolons (L60, L73) where the convention asks for sparing use; not egregious.
- Frontmatter `first_authored.by: "@claude-opus-4-8"` is a short alias; the frontmatter spec calls for the full API-valid model name (e.g. `@claude-opus-4-5-20251101`). Minor.

## Verdict

**Revise (light).**
No claim is wrong and no field choice is unsafe; the core design (which fields, which values, the schema split, memory withholding) is correct and fully verified.
The revise verdict rests on two substantive, cheap-to-close gaps: the `maxTurns: 20` / batch-mode inconsistency that contradicts the proposal's own central argument, and the absent OpenCode-build verification in a repo that is explicitly multi-target.
Both are additive clarifications, not redesigns. With them addressed this is a clear Accept.

## Action Items

1. [non-blocking, important] Resolve the `maxTurns: 20` vs batch-mode tension for `nit-fix`/`triage`: either raise/remove the cap using the same reasoning applied to `reviewer`, or add a sentence establishing that batch runs over `cdocs/**/*.md` stay within 20 turns (make the parallelism + resumability argument explicit).
2. [non-blocking, important] Add OpenCode-build verification: run `npm run build:cdocs`, assert it succeeds, and state that the OC build drops `color`/`maxTurns`/`memory` by design (build allowlist in `generateOCFrontmatter`), so CC and OC agents intentionally diverge on these fields.
3. [non-blocking, minor] Add a note that these fields require a recent CC version (`maxTurns` partial-marking needs v2.1.246+) and degrade harmlessly on older versions.
4. [non-blocking, minor] Tighten the Background NOTE to distinguish `tags` as an explicitly declared marketplace-schema field from fields that survive only via `additionalProperties` leniency.
5. [non-blocking, minor] Convert the two `$schema` references to direct HTTP links; reduce incidental semicolons; use the full API-valid model name in `first_authored.by`.

## Questions for the Author (multiple choice)

**Q1 - the `maxTurns: 20` cap on batch-capable agents:**
- (a) Remove `maxTurns` from `nit-fix`/`triage` too, extending the reviewer argument (partial > worse than slow) to any batch-over-corpus agent.
- (b) Keep `20` but document that batch runs parallelize tool calls within a turn and that `maxTurns` output is resumable, so a hit cap is recoverable, not lost work.
- (c) Raise to a larger guard value (e.g. 60) that tolerates a realistic corpus while still catching pathology.
- (d) Keep `20` as-is; batch corpora are small enough in practice (state the assumed ceiling).

**Q2 - OpenCode divergence on the three new fields:**
- (a) Accept the divergence (OC gets none of `color`/`maxTurns`/`memory`); just add the build-success check and a one-line note. Recommended - matches the stated scope.
- (b) Extend the OC build allowlist so at least `memory`-withholding parity is preserved on OC. (Larger; likely a separate proposal.)
- (c) Leave entirely unmentioned. Not recommended - the repo is explicitly multi-target and Verification claims to be the concrete failure picture.
