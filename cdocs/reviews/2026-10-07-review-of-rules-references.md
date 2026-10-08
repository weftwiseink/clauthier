---
review_of: cdocs/proposals/2026-10-07-rules-references.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T21:53:11-07:00
task_list: cdocs/rules-references
type: review
state: live
status: done
tags: [fresh_agent, architecture, rules_delivery, proportionality, test_plan]
---

# Review: Rules References

## Summary Assessment

The proposal replaces rule-filename references in shipped content with H1-based heading references, adds a `node:test` check for them, drops the agents' rule-file Startup reads, and moves `/cdocs:init` to per-file `.claude/rules/cdocs/<name>.md` delivery.
The audit is accurate, the heading convention is well motivated, and the agent change is correct, so phases 1 and 2 are close to ready.
The two problems are proportion.
Phase 3 picks per-file delivery over a much smaller option (keep `cdocs.md` and drop the `@`-import), and its comparison table charges the import's costs to concatenation.
The check also models init's output in TypeScript although the proposal admits that resolving against source headings gives the same answer.
Verdict: **Revise**: shrink phase 3 and the check's simulation; the reference convention and agent changes can stay as written.

## Codebase spot-checks

All claims checked against the working tree:

- **10 skill links in 8 skills:** confirmed, exactly `full-send:13`, `oversee:12`, `propose:144`, `ablate:20,290,291`, `iterate:34`, `propose-revise:45`, `implement:19`, `devlog/SKILL.md:31`.
- **Six agent Startup variants:** confirmed (`reviewer`, `proposer`, `implementer`, `judge`, `triage` use the two-path read; `nit-fix.md:19-20` uses the agent-relative Glob). `bash-runner` reads none.
- **`nit_fix/SKILL.md:48`, `triage/SKILL.md:69`, `judge.md:74`, `implement/SKILL.md:53`, `frontmatter-spec.md:85`, `devlog/template.md:10`:** all confirmed at the stated lines.
- **Completeness of the audit:** a grep of `rules/`, `skills/`, `agents/` (minus `init/SKILL.md`) for rule filenames, `rules/*`, and `plugins/cdocs/rules` returns exactly the audited sites, so the Test Plan row 2 expectation is achievable.
  No double-quoted `"CDocs ...` string exists today, so the extractor starts with no false positives.
- **`cdocs-hooks.yml` path filters:** confirmed as `plugins/cdocs/bin/**`, `plugins/cdocs/hooks/**`, and the workflow file.
  The "latent gap" claim also holds: `chat-record.test.sh:129-130` and `:792` read `rules/` and `skills/init/SKILL.md`, and neither path triggers the workflow.
- **README "Agent path resolution":** the claim that agents resolve `rules/*.md` from their own directory is wrong, as the proposal says.

## Section-by-Section Findings

### Summary and reference convention (section 1)

The heading convention is the right core idea: the H1 survives concatenation, per-file copies, and the `AGENTS.md` block, and models find in-context text by heading.
It is needed whatever the delivery layout, as the proposal says.

- **Non-blocking: the `›` (U+203A) separator.** Authors and models will usually type `>`, and the check fails that with a hint.
  That makes the separator a ban, which goes against "guidelines over bans" and against the proposal's own "bans nothing beyond unresolvable references".
  Accepting ASCII ` > ` as an equal separator removes the friction at no cost to resolution.
- **Non-blocking: `nit-fix` convention breadth.** "Every `##` section of the CDocs rules in its context" includes Model Tiering, Chat record, and the Bash safeguards, which are not document conventions.
  The current Glob has the same breadth, so this is not a regression, but the rewrite is a good moment to scope `nit-fix` to "CDocs Writing Conventions" plus "CDocs Frontmatter Specification", the two rules the other agents name.
  `nit-fix.md:82` ("Rule files loaded: F") and `:26` also need rewording in phase 2.

### Agents rely on context (section 1, Design Decisions)

The Startup replacement is correct.
Report section 3 ([subagents breakdown](../reports/2026-09-19-claude-code-subagents-feature-breakdown.md)) says non-fork subagents get "CLAUDE.md files at all levels (unless `omitClaudeMd`; Explore/Plan skip them)".
The sub-agents docs extend that to project rules, and the proposal's probe confirms it for `.claude/rules/` with a `general-purpose` subagent.
This review session adds one more data point: it runs as a `cdocs:reviewer` plugin agent, and its context already holds the CLAUDE.md hierarchy with all five source rules `@`-imported, so the Startup reads it was told to do were redundant.

- **Non-blocking: the probe did not cover a plugin agent under the `.claude/rules/` layout.** Verification step 3 (a dispatched `cdocs:reviewer` and `cdocs:nit-fix`) closes this, so it only needs a sentence linking the two.
- **Non-blocking: weak proof in Verification step 3.** "`nit-fix` must fix the em-dash" does not show where the convention came from, because many models remove em-dashes unprompted.
  Step 4's sentinel probe is the real evidence; either use a sentinel for step 3 too or say that step 4 carries the proof.
- **Non-blocking: dead rewrite.** `build-opencode.ts:199-204` rewrites `plugins/cdocs/rules/` in agent bodies.
  After phase 2 the rule branch of that regex matches nothing.
  That is harmless and the no-change constraint is reasonable, but a NOTE would stop a later reader from hunting for its purpose.
- **Non-blocking: stale report.** Report section 13 says the agents "rely on relative `rules/*.md` reads".
  A NOTE there, like the one already in section 3, keeps the report from contradicting this change.

### The check (section 2)

A mechanical check is the right answer to the maintainer's "2x check" request, and `node:test` plus `tsx` reuses existing setup.
Two parts are heavier than they need to be.

- **Blocking: drop the simulated materialization from the CI path.** `materialize` re-implements init's prose in TypeScript, and that copy can drift from the skill.
  Design Decisions admits that resolving against source headings "would give the same answer today".
  The only stated benefit, catching an `AGENTS.md` list that omits a rule, is already covered by assertion 2 (the init list names exactly the files in `rules/`).
  Parsing the `agents-md` target is also harder than parsing the sources: each rule body sits under a `## CDocs ...` wrapper, with the body's own `##` sections at the same level.
  The smaller version: assertions 1, 2, 4, and 5, and assertion 3 resolved against the source rule headings.
  Keep `--materialized` for real init output in `init_real`.
  That is the true "2x check" of what consumers receive, and it is the only form with no drift risk.
- **Non-blocking: CI shape.** A separate `rules` job (setup-node, `npm ci`, one script) is about eight lines of YAML and a reasonable cost.
  Widening `paths` to `plugins/cdocs/**` is a real fix.
  No smaller blocking home exists: `opencode-build.yml` already runs `npm ci` but is `continue-on-error`, deliberately so that OpenCode never gates Claude Code.
  Putting the check there would either leave it non-blocking or make an OpenCode workflow gate Claude Code changes.
  Keep the new job, and note in the proposal why it does not belong in `opencode-build.yml`.
- **Non-blocking: trim assertion 6.** Five extractor self-tests are more than a page of conventions needs.
  Typo, code fence, and curly quotes cover the parser.
  If ` > ` is accepted (above), the `>` test becomes a positive case.
- **Non-blocking: internal inconsistency.** "The check flags and explains; it bans nothing beyond unresolvable references" contradicts assertion 4, which fails CI on any filename reference.
  State plainly that filename references are rejected.

### Per-file delivery (section 3, "Per-file delivery over concatenation")

- **Blocking: per-file delivery is not worth its cost as argued, and the table misattributes the import's costs.** Two table rows, "Relies on undocumented import dedup" and "init edits `CLAUDE.md`", are costs of the `@`-import, not of concatenation.
  The rejected alternative (keep `.claude/rules/cdocs.md`, drop the import) removes both.
  It also needs no hook change, no legacy fallback branch, no new `inject-rules.test.ts`, and no rewrite of the `init_rules` fixtures beyond deleting the import line at `chat-record.test.sh:804`.
  That leaves per-file with three benefits:
  - `/context` lists each rule: cosmetic.
  - No ordering coupling: a one-word fix ("alphabetical order") would remove it.
  - "One routine, two targets": overstated, since step 5 prepends OpenCode frontmatter and step 3 strips frontmatter and adds a marker.
  Against those, per-file adds a permanent second hook path for the legacy layout and gives init a delete-files-in-a-directory step inside the consumer's `.claude/`.
  For a maintainer who wants fewer moving parts, the smaller variant is the better phase 3.
  Per-file can stay as a recorded follow-up if `/context` visibility ever matters.
- **Non-blocking: evidence.** The docs plus one headless probe are enough for either layout, because both rest on the same `.claude/rules/` auto-load that today's layout already uses.
  Post-compaction re-injection of unscoped rules is documented but not probed.
  Dropping the import (in either variant) moves the post-compaction guarantee from "project-root CLAUDE.md and its imports" to "unscoped rules", so `rules_check` must run with a fixture that has no import line before the import is removed.
  Verification step 5 runs it; the phase should state that order explicitly.
- **Non-blocking:** "Keep rules unscoped" is well reasoned and should survive the revision unchanged.

### Relation to the hook testing RFP

- **Non-blocking, contingent:** `inject-rules.test.ts` belongs here only if the hook changes.
  With the smaller phase 3 the hook is untouched and the test stays in the [RFP](../proposals/2026-09-01-rules-hook-testing-methodology-v2.md).
  If per-file is kept, test the changed marker-source branches here and leave full branch coverage and directive size to the RFP; "a few cases more" grows into owning RFP scope.
  The proposal should not settle the RFP's test-location open question by fiat either: "proposes" is fine, "answers" is not.

### Edge cases, Test Plan, Phases

The edge cases are thorough.
The OpenCode WARN is honest, and the stated constraints keep OpenCode delivery untouched, which meets the maintainer's "minimally invasive" requirement.
The phase order (check, then convert and wire CI, then delivery) is sound, and phase 3 really is separable.
After the blocking revisions, the Test Plan "Hook" row and phase 3's hook bullets shrink or move to the RFP.

## Verdict

**Revise.**
The reference convention, the audit, and the agent changes are sound and verified.
Two blocking items: replace phase 3's per-file migration with the smaller "keep `cdocs.md`, drop the import" design (or justify per-file with a benefit the smaller design lacks), and take the simulated materialization out of the CI check in favor of resolving against source headings plus `--materialized` on real init output.

## Action Items

1. [blocking] Rework "Per-file delivery over concatenation": move the import-dedup and `CLAUDE.md`-edit rows to the import column, adopt "keep `.claude/rules/cdocs.md`, drop the `@`-import" as phase 3 (hook unchanged), and record per-file as a possible follow-up. If per-file stays, name a benefit the smaller variant lacks.
2. [blocking] Remove `materialize`'s simulation from the CI check: resolve assertion 3 against source rule headings (assertion 2 already guarantees every rule is materialized), and keep `--materialized` for real init output in `init_real`.
3. [non-blocking] Accept ASCII ` > ` as a separator alongside ` › `, and reword "bans nothing beyond unresolvable references" so it matches assertion 4.
4. [non-blocking] Make `inject-rules.test.ts` contingent on a hook change; with the smaller phase 3 it stays in the hook testing RFP. Say "proposes" rather than "answers" for the RFP's test-location question.
5. [non-blocking] State that `rules_check` passes with a fixture that has no import line before the import is removed.
6. [non-blocking] Scope `nit-fix` to the Writing Conventions and Frontmatter Specification rules, and list `nit-fix.md:26,82` among the phase 2 rewrites.
7. [non-blocking] Use a sentinel (or defer to step 4) instead of the em-dash fix as the proof that `nit-fix` reads its conventions from context.
8. [non-blocking] Add NOTEs for the dead rule branch of `build-opencode.ts:199-204` and for the stale section 13 of the subagents report; trim assertion 6 to three fixtures.
9. [non-blocking] Say why the `rules` job lives in `cdocs-hooks.yml` and not in `opencode-build.yml` (that workflow is `continue-on-error` so OpenCode never gates Claude Code).

## Questions for the author

1. Phase 3 delivery:
   (a) keep `cdocs.md`, drop the import, hook unchanged (recommended);
   (b) per-file as proposed;
   (c) defer phase 3 entirely and ship phases 1-2 alone.
2. Where the check resolves headings:
   (a) source headings in CI plus `--materialized` on real init output (recommended);
   (b) simulated materialization as proposed.
3. Separator:
   (a) accept both ` › ` and ` > ` (recommended);
   (b) ` › ` only, with a hint on ` > `.
