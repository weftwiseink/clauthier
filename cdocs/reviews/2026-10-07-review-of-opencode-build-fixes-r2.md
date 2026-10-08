---
review_of: cdocs/proposals/2026-10-07-opencode-build-fixes.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T18:37:12-07:00
task_list: build/opencode-build-fixes
type: review
state: live
status: done
tags: [fresh_agent, runtime_validated, minimal_invasiveness, models, test_plan, verification]
---

# Review (Round 2): OpenCode Build Fixes

> BLUF: Accept.
> Both r1 blockers are resolved soundly, all seven r1 non-blocking items are addressed, and the design stays entirely inside the OC build path.
> A local OpenCode 1.17.5 run confirms that the proposed output loads all seven agents, and that wildcard agents get OC's full default permission set.
> Five non-blocking items remain, all small text edits that an implementer can absorb.

## Summary Assessment

The proposal fixes three `scripts/build-opencode.ts` bugs (empty block-scalar `bash-runner` description, `tools: "*"` disabling every tool, unknown model ids) by parsing and emitting with `yaml`, omitting `tools`/`permission` for wildcard agents, and omitting `model:`.
The revision makes parse errors per-agent warn-and-skip, adds the Decision 3 NOTE amending the brief's "current model ids" floor, and folds in every r1 suggestion without growing the design.
I re-ran the full proposed conversion and test assertions over the real agents and loaded the output into a local OpenCode install: everything behaves as the proposal predicts.
The remaining findings are gaps in verification detail (no baseline capture, an under-specified recipe for testing warn-and-skip) and minor wording, so the verdict is **Accept**.

## Verification Performed

- **Revision diff** (`git show be140f5`): a proposal-only commit, with no code or `plugins/` paths touched.
- **Conversion and assertions, re-run fresh.** A scratch script (`yaml` 2.9.1, outside the repo) applied Solutions 1-3 to every `plugins/cdocs/agents/*.md` and then evaluated test assertions 2-5 against the output.
  All seven pass.
  `bash-runner` emits `description: |` followed by its seven body lines.
  `implementer`/`proposer`/`reviewer` emit only `description` and `mode`.
  `triage`/`nit-fix` keep `read: true, edit: true` plus `permission.edit: ask`.
- **OpenCode runtime check (new evidence).** I put the generated files in a scratch `.opencode/agent/` and ran `opencode agent list --pure` (OpenCode 1.17.5).
  All seven agents load as `(subagent)` with no errors.
  Wildcard agents (`reviewer`, `implementer`) resolve to the same rule set as the built-in `general` subagent (`* * allow`, read `*.env` ask, and so on), which confirms Decision 2.
  `bash-runner` resolves to `read * deny`, `edit * deny`, and `bash * allow`, which confirms the deprecated `tools` key still works (Decision 4).
  The check does not show the effective model, so the inheritance claim rests on the quoted docs.
- **`tsx --test`.** A scratch `node:test` file in `.ts` runs under `tsx --test` (tsx 4.21.0, the repo's installed version), so the `test:opencode` script is viable.
- **CI.** I compared the current `.github/workflows/opencode-build.yml` with Solution 4: replacing the build and bash-validation steps with one `npm run test:opencode` step, keeping `npm pack --dry-run`, and keeping job-level `continue-on-error: true` is consistent.
  The one other workflow (`cdocs-hooks.yml`) does not run `npm ci` and is unaffected by the new devDependency.
- **Hard Requirement 1 sweep.** Nothing in the design edits `plugins/`.
  The new devDependency lives in a private root `package.json` that the CC plugin install never reads.
  The test only reads CC agents, and its failures surface only in non-blocking CI.

## Prior Action Items

| r1 item | Status |
|---|---|
| 1 [blocking] parse error warn-and-skip | Resolved. Solution 1 bullet 3, Edge Cases bullet 1, Test assertion 1, Reviewer Checklist HR2. The unverified "CC would mis-load" claim is gone (see N4 for its replacement). |
| 2 [blocking] Decision 3 NOTE on the floor | Resolved. The NOTE names the floor, its replacement (Verification step 4), the rationale, and the pinned map as the maintainer alternative. Verification step 4 cross-references it. |
| 3 provider-id evidence | Resolved. Background, plus the first Decision 3 alternative. |
| 4 stale `permission.write` | Resolved. Background ("There is no `write` key") and Deferred. |
| 5 soften the `task` claim | Resolved. Edge Cases and RFP rows now defer to documented defaults. Empirically, `task` falls under `* allow` for wildcard agents. |
| 6 double build | Resolved. `test:opencode` builds, the test reads existing output, and CI has one step. |
| 7 line count | Resolved ("seven body lines"). |
| 8 republish row | Resolved. |
| 9 `String(...)` guard and lockfile | Resolved. Solution 1, Phase 1. |

## Section-by-Section Findings

### Hard Requirements and minimal invasiveness

**F1 (non-blocking, positive). The design is the smallest reasonable fix and does not touch the CC setup.**
Every change falls within the allowed set: the script, a test beside it, the OC workflow, and root `package.json`/lockfile.
Two of the three fixes delete code (`MODEL_MAP` and the line scanner).
The one addition with an obvious cheaper alternative is the test file, and it is justified: dropping `model` from the bash grep would turn CI green, but `description: |` passes a grep, so the empty-description failure would stay invisible.
The proposal leaves the CC-side drift (README "model mapping") deferred instead of fixing it under `plugins/`, and the header comment's "optionally publishes" drift is left alone as well.
That deference is correct under HR1.
Question 1 below asks the maintainer whether they want the README phrase fixed.

**F2 (non-blocking, positive). The model policy is soundly argued and clearly flagged.**
The provider-specific-id argument (an `anthropic/` pin fails for Copilot, OpenRouter, Bedrock, Vertex, and Zen users) is now the lead reason, and it outweighs tier fidelity: a wrong tier costs money, while an unknown id breaks the agent.
The cost side is stated plainly (Summary, Decision 3, and the Cost bullet in Edge Cases).
The policy is flagged as the maintainer's call in the BLUF, the Summary, and the Decision 3 NOTE.

### Proposed Solution

**N1 (non-blocking). "Reverting to a pinned map is a one-line change" overstates.**
Restoring the map means the map itself plus a conditional emission (about six lines) and a flipped assertion 4.
Say "a small change" so a maintainer who chooses option B does not expect a one-liner.

**N2 (non-blocking). One RFP Resolution row has a factual slip.**
In the "shape regression in working fields" row, "every emitted field parses to a string" is wrong: `tools` is a mapping of booleans and `permission` is a mapping.
Say "every emitted field parses to the same type and value as before".

### Test Plan and Verification Methodology

**N3 (non-blocking). The baseline for "unchanged" is never captured.**
Phase 1 "done when" ("other agents' frontmatter is unchanged in value") and Verification step 3 ("same `tools`/`permission` values as before") both need a pre-change build to compare against.
A fresh implementer starting at Phase 1 overwrites `build/` with the first build.
Add a step 0: before Phase 1, run `npm run build:cdocs` and copy `build/cdocs/opencode/agents/` to a scratch directory.

**N4 (non-blocking). Nothing concrete exercises the warn-and-skip path (HR2).**
The Test Plan's "adding an unparseable line to a scratch copy" does not say how: `REPO_ROOT` resolves from the script's own location, and the build only reads `plugins/<name>/agents/`.
A copied agent file elsewhere is therefore never built.
A concrete recipe follows.

1. Copy `scripts/`, `plugins/cdocs/`, and `package.json` into a scratch root, symlinking `node_modules`.
2. Append `description: Use when: x` as a second `description` key to one scratch agent.
3. Run `npx tsx <scratch>/scripts/build-opencode.ts`.
4. Expect exit 0, one warning that names the file, and six generated agents.

Add this recipe as a Verification step so that the Reviewer Checklist HR2 item has evidence behind it.
Relatedly, Solution 1's "Strict YAML can reject frontmatter that CC itself accepts" is as unverified as the claim it replaced.
Hedge it as "may reject frontmatter CC tolerates": the warn-and-skip design is right either way.

**N5 (non-blocking). Verification step 7's allowed set omits `cdocs/`.**
The branch also changes the proposal, devlog, and reviews under `cdocs/`, so "every changed path is in the allowed set" fails as literally written.
Say "every changed path outside `cdocs/` is in the allowed set".

The three failure pictures are covered.
- An empty `bash-runner` description fails assertion 3.
- `implementer`/`proposer`/`reviewer` with tools disabled fail assertion 5.
- Stale or unknown ids fail assertion 4, and Verification step 4 checks the same thing with `grep`.
Reverting each fix produces the matching failure by construction, as I confirmed in the scratch run.

### Writing conventions

The BLUF is accurate and leaves no surprises, there are no em-dashes or semicolons, and external references are linked.
A few prose lines carry two sentences (for example "Absent `tools` already emits no block today. Only `*` changes behavior."), which a `nit_fix` pass can split.
Table cells are exempt.
At about 280 lines, the length is proportionate to three RFPs' worth of resolution rows.

## Verdict

**Accept.**
The blockers are resolved, the design honors the hard requirements, and both the build output and the OC runtime behave as specified.
Set the proposal to `implementation_ready`.
The implementer should apply N3 and N4 during implementation (they are verification steps, not design changes), and N1, N2, and N5 are wording fixes.

## Action Items

1. [non-blocking] Add a Verification step 0: before Phase 1, build and copy `build/cdocs/opencode/agents/` to scratch as the baseline for Phase 1's "unchanged in value" and Verification step 3.
2. [non-blocking] Replace the Test Plan's "scratch copy" with the concrete warn-and-skip recipe in N4 (copy `scripts/` + `plugins/cdocs/` + `package.json`, symlink `node_modules`, break one agent, expect exit 0, one warning, six agents), and add it to Verification.
3. [non-blocking] Hedge Solution 1's "Strict YAML can reject frontmatter that CC itself accepts" to "may reject frontmatter CC tolerates".
4. [non-blocking] Decision 3: change "Reverting to a pinned map is a one-line change" to "a small change".
5. [non-blocking] RFP row "shape regression in working fields": replace "every emitted field parses to a string" with "every emitted field parses to the same type and value as before".
6. [non-blocking] Verification step 7: "every changed path outside `cdocs/` is in the allowed set".
7. [non-blocking] Split the multi-sentence prose lines (sentence-per-line) during the next `nit_fix` pass.

## Questions for the Maintainer

1. **README drift** (`plugins/cdocs/README.md` says the build does "model mapping").
   - A. Leave it, per HR1 (proposal default).
   - B. Allow the one-phrase README fix in this branch as a documented HR1 exception.
   - C. Fix it in a separate CC-side docs pass.
2. **OC agent model policy** (carried from r1; proposal default: A).
   - A. Omit `model:`, so OC subagents inherit the caller's model.
   - B. Pin current `anthropic/` ids per tier, accepting provider lock-in and routine bumps.
