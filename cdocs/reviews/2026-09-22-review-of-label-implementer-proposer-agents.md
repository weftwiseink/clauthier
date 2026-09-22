---
review_of: cdocs/proposals/2026-09-22-label-implementer-proposer-agents.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-22T10:43:26-07:00
task_list: meta/agent-dispatch-labeling
type: review
state: live
status: done
tags: [fresh_agent, architecture, orchestration, agent-dispatch, cost, model-tiering, oc-build]
---

# Review: Label Implementer and Proposer Subagents at Dispatch

## Summary Assessment

The proposal specifies a labeling-only fix: add `implementer.md` / `proposer.md` agent files (both `tools: "*"`, `model: inherit`) and switch two dispatch references in `/cdocs:iterate` and `/cdocs:propose-revise` from bare `general-purpose` to `cdocs:implementer` / `cdocs:proposer`, so `usage.db` self-classifies the two highest-cost unattributed roles.
The design is sound, the evidence is real, and nearly every verifiable claim checks out against the live files: the tool-allowlist claim, the reviser-reuse decision, the full-send/oversee composition check, and the path-restriction-hook constraint are all correct and well-supported.
The one genuine gap is that the recorded `scripts/build-opencode.ts` confirmation ("no code change needed") is scoped only to the agent list/count and misses that `model: inherit` is an unmapped alias the OC converter passes through with a build warning, of unverified OC-side validity.
Verdict: **Accept** with non-blocking corrections, chiefly folding the OC-build × `model: inherit` interaction into Phase 4 verification and correcting a couple of framing imprecisions.

## Section-by-Section Findings

### Tool allowlist (`tools: "*"`) - correct and unambiguous [non-blocking: none]

The claim that the new agents use the SAME allowlist as `general-purpose` with no capability narrowing is correct and stated unambiguously in three consistent places: the BLUF, Scope "Out of scope" (line 64), and the dedicated "Same tool allowlist" section (lines 181-184).
Verified against `reviewer.md` (`tools: "*"`, line 5) and the `general-purpose` agent-type definition (`Tools: *`).
The rationale (narrowing would break repo-wide implementer work) is correct.
No issue.

### `model: inherit` decision and the Phase 1 gate - well-reasoned, one hypothesis overstated [non-blocking]

The decision to default to `model: inherit` rather than a fixed pin, with a Phase 1 empirical gate falling back to omitting `model:` if `inherit` does not honor `-m`/`-f`, is well-reasoned and correctly grounded.
The `model-tiering.md` citations are accurate: `reviewer`/`judge` are `model: opus` (rule line 14, verified in the agent files), `nit-fix` is `model: haiku` (line 28), and "consumer floor wins" is the Precedence section (lines 36-43).
The argument that the rule "does not cleanly name a tier for the dispatched worker executing open-ended implementation or authoring" is a fair reading: the three named tiers are lead/judgment (opus), search/explore (sonnet), and mechanical (haiku), and an open-ended build/write turn fits none cleanly.
The dispatch-contract reasoning (agent `model:` is the default, a per-dispatch `-m` override wins, which is why `reviewer.md` can pin `opus` yet still obey `iterate`'s `-m`) is correct.

One overstatement: "`model: inherit` ... reproduces today's observed behavior" (line 169) holds only under a consumer floor and only for the no-`-m` case.
`inherit` (defer to overseer's model) and omission (no pin, `general-purpose`'s actual state today) are semantically distinct; they coincide under a floor but may diverge in a floorless install with no override.
The proposal's own gate covers the `-m`-override risk but not this no-override/no-floor divergence.
This is minor because the fallback (omit `model:`) is available and is the exact behavioral match for `general-purpose`.

### Reviser reuses `cdocs:proposer` - justified with real evidence [non-blocking: none]

The decision to reuse `cdocs:proposer` and not mint a `cdocs:reviser` type is justified with accurate evidence from `propose-revise/SKILL.md`.
The reviser is defined there (line 48) as "subagents dispatched with `/cdocs:propose` to make requested revisions," and the fresh-versus-warm context call is the overseer's per-dispatch "ON REVISION" decision (lines 22-26), which is indeed orthogonal to agent type.
The dedup argument (a byte-identical third file would split one activity into two DB buckets, defeating the consolidation this change exists for, and violating `CLAUDE.md`'s dedup preference) is sound and matches the report's two-file action item.
No issue.

### Composition check (full-send / oversee) - claim holds, independently verified [non-blocking: none]

Independently verified against the live files, not taken on the proposal's word.
A repo-wide grep for `general-purpose` across `plugins/cdocs/` returns zero hits in `full-send/SKILL.md` (21 lines total) and `oversee/SKILL.md`.
`full-send` is a pure composition of `/cdocs:propose-revise` then `/cdocs:iterate` and dispatches no implementer/proposer/reviser of its own.
`oversee` "never reimplement[s] a loop" (line 9); its only "implementers" mention (line 105) describes the composed loops' concurrent dispatches, and its `full <topic>` scoping dispatches `/cdocs:propose` with no `subagent_type` literal to edit, so it inherits `cdocs:proposer` once that file exists.
The proposal's "inherit the fix by composition, no edits required" conclusion is correct.

### Path-restriction hook constraint - correct, hook exists as described [non-blocking: none]

Verified: `plugins/cdocs/hooks/validate-cdocs-edit-path.sh` exists, its allowlist is `CDOCS_AGENTS="triage nit-fix reviewer"` (line 16), and its maintenance comment (lines 8-9) does instruct adding new cdocs agents to that allowlist.
The proposal's constraint - do NOT add `implementer` or `proposer` - is technically correct.
For `implementer` it is essential: the hook confines edits to `cdocs/(devlogs|proposals|reviews|reports)/`, and the implementer edits source repo-wide.
For `proposer` the principled framing is right: even though the proposer's normal writes land in `cdocs/proposals/` (which the pattern permits), adding it would impose a NEW restriction the current `general-purpose` proposer lacks, i.e. a capability change outside labeling scope.
The CC-only scoping is also correct: the README lists "Hooks (path restriction) | Not available" for OC (line 172).

### Implementation phases and the two README spots - concrete, with one incomplete confirmation [non-blocking]

The phases are concrete and largely executable without further design decisions, and every referenced line was verified:
- `iterate/SKILL.md` line 74 is the real `subagent_type: "general-purpose"` dispatch literal; line 43 is the Implementer role prose. Both confirmed.
- `workflow-patterns.md` line 32 (Implementer description) confirmed.
- `iterate/template.md` lines 33, 52, 72 carry the illustrative `(general-purpose)` handles, confirmed by grep.
- README line 105 (`Agents (nit-fix, triage, reviewer, judge)` path-resolution list; proposal says ~104) and line 171 ("4 agents converted to OC frontmatter format"; proposal says ~170) are both captured as Phase 3 tasks. Both spots confirmed present and correctly identified.
- `scripts/build-opencode.ts` dynamism is confirmed: `readdirSync(AGENTS_DIR)` (line 339) and `agentFiles.length` (lines 340, 368), no hardcoded list or count.

The gap: the recorded confirmation "`scripts/build-opencode.ts`: confirmed no hardcoded agent list or count; no code change needed" is true only for the list/count dimension.
It does not account for the model-field transform.
`MODEL_MAP` (lines 57-60) maps only `haiku`/`sonnet`/`opus`; for `model: inherit`, `MODEL_MAP["inherit"]` is undefined, so the converter takes the `|| cc.model` branch (line 180), prints `Warning: Unknown model alias "inherit" — passing through as-is` (lines 181-183), and emits a literal `model: inherit` into the OC agent (line 184).
Consequences the proposal does not surface:
1. Phase 4's success criterion ("two new agents appear ... count is 6") is satisfiable even while the build prints a warning and ships a possibly-invalid OC `model:` value.
2. The Phase 1 fallback (omit `model:`) is actually CLEANER for OC than `inherit`: line 179 guards `if (cc.model)`, so omission emits no model line at all and no warning.
This does not threaten the core objective (CC-side DB self-classification), and the design's own fallback resolves it, but Phase 4 should explicitly verify OC-side validity of whatever `model:` value ships and the recorded build confirmation should be corrected to name this interaction.

### Writing-convention and frontmatter compliance [non-blocking]

Frontmatter is spec-compliant: `first_authored`, `task_list`, `type: proposal`, `state: live`, `status: review_ready`, and a focused `tags` set are all present; `last_reviewed` is correctly absent pre-review (added by this review).
BLUF is present and attributed. NOTE callouts are used per the history-agnostic exception for proposals. Punctuation prefers colons/spaced-hyphens over em-dashes. Sentence-per-line is honored.
Two minor framing imprecisions:
- The BLUF's "the two highest-cost roles (48.3% and 7.4%)" reads as highest-cost overall, but the report puts reviewer (~16%, ~3x proposer per line 62) and overseer (15.2%, line 86) above proposer's 7.4%. Proposer is the second-highest of the two roles conflated into `general-purpose`, not the second-highest role overall. The Summary (line 22) states this more carefully; the BLUF should match.
- `first_authored.by: "@claude-opus-4-8"` is a short handle rather than the dated API-valid name the frontmatter spec's examples show; acceptable given repo precedent (e.g. `reviewer.md`'s `claude-opus-4-6` NOTE), noted only for consistency.

### Dispatch-site asymmetry (concreteness nit) [non-blocking]

The Reference-points and Phase 2 sections present the two edits as symmetric "dispatch-line changes," but they are structurally different.
`iterate/SKILL.md` line 74 is a literal `subagent_type: "general-purpose"`.
`propose-revise/SKILL.md` has NO `subagent_type` literal anywhere (verified by grep); its only `general-purpose` reference is the prose Proposer-role description at line 46.
The fix (edit the prose) is still correct and complete because there is nothing else to change, but an implementer executing Phase 2 who expects a `subagent_type` literal at propose-revise line 46 (by analogy to iterate line 74) will not find one.
A one-line clarification that the propose-revise change is a prose/role-description edit, not a literal-dispatch edit, would remove the ambiguity.

## Verdict

**Accept.**
The design is correct, the evidence is real and accurately cited, the composition and hook claims independently verify, and the phases are executable.
No blocking issues.
The non-blocking corrections below (chiefly the OC-build × `model: inherit` interaction) improve accuracy and should be folded in during the `/cdocs:iterate` loop rather than gating acceptance.

## Action Items

1. [non-blocking] Amend Phase 4 to explicitly verify OC-side validity of whatever `model:` value ships: `model: inherit` is an unmapped alias that `build-opencode.ts` passes through with a `Warning: Unknown model alias` and emits verbatim into the OC agent. Correct the recorded "no code change needed" confirmation to scope it to list/count and to name this model-field interaction. Note that the Phase 1 fallback (omit `model:`) is the OC-clean outcome (no warning, no model line).
2. [non-blocking] In the `model: inherit` rationale, soften "reproduces today's observed behavior" to hold only under a consumer floor with no `-m` override; note that omission, not `inherit`, is the exact behavioral match for `general-purpose`'s current no-pin state in a floorless install.
3. [non-blocking] Clarify in Reference points / Phase 2 that the `propose-revise/SKILL.md` line ~46 change is a prose role-description edit (there is no `subagent_type` literal in that file), distinct from the literal-dispatch edit at `iterate/SKILL.md` line 74.
4. [non-blocking] Align the BLUF's "two highest-cost roles" with the Summary: implementer is the single highest-cost role; proposer (7.4%) is the second-highest of the two roles conflated into `general-purpose`, below reviewer and overseer overall.

## Open Questions / Clarifications

The one genuine design fork is the `model:` field, which the proposal itself gates empirically in Phase 1. Surfacing it as a choice for the overseer/user:

- **A. Ship `model: inherit`, fall back to omission only if the Phase 1 `-m`-override check fails.** The proposal's current plan. Documents intent explicitly and matches the "all four existing agents carry an explicit `model:`" convention, at the cost of a benign OC build warning and an OC `model: inherit` value of unverified validity.
- **B. Omit the `model:` field outright.** Exact behavioral match for `general-purpose`'s current no-pin state, OC-clean (no warning, no emitted model line), and still floor/`-m`-governed. Loses the explicit "deliberately not pinned" documentation signal (recoverable via a frontmatter comment or body NOTE).
- **C. Ship `inherit` but add `inherit` to `build-opencode.ts`'s `MODEL_MAP`** (mapping it to an OC-valid "inherit"/omit behavior). Keeps the documentation intent AND makes the OC build clean, at the cost of a one-line code change the proposal currently scopes out.

Recommendation: decide A-vs-B-vs-C at the Phase 1 gate using the empirical `-m`-override result plus a quick OC-build check, rather than committing to A blind. If the Phase 1 check passes for CC but the OC `model: inherit` value proves invalid, B or C is preferable to A.
