---
review_of: cdocs/proposals/2026-10-07-opencode-build-fixes.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T18:31:16-07:00
task_list: build/opencode-build-fixes
type: review
state: live
status: done
tags: [fresh_agent, runtime_validated, architecture, minimal_invasiveness, models, test_plan]
---

# Review: OpenCode Build Fixes (YAML Frontmatter, Wildcard Tools, Model Ids)

## Summary Assessment

The proposal folds three `scripts/build-opencode.ts` bugs (empty block-scalar description, `tools: "*"` disabling everything, unknown model ids) into one OC-build-only change: parse and emit with `yaml`, omit `tools`/`permission` for wildcards, and omit `model:` entirely.
It is tight, well evidenced, and honors the maintainer's minimal-invasiveness constraint: nothing under `plugins/` changes, CI stays `continue-on-error`, and the parser and model fixes are net deletions.
I verified the OC doc quotes, the models.dev catalog, the npm registry facts, and ran the proposed parse/stringify pipeline over all seven real agents: every description round-trips and the output is exactly what the proposal predicts.
Two blocking issues remain, both small: the parse-error path contradicts Hard Requirement 2 (one CC file OC's parser rejects would fail the whole OC build), and Decision 3 departs from the brief's "current model ids" verification floor without saying so.
Verdict: **Revise**.

## Verification Performed

- **OC docs (WebFetch, 2026-10-07).**
  [Agents](https://opencode.ai/docs/agents/): subagent model inheritance, "`tools` is **deprecated**", and `description` required are all quoted accurately.
  [Tools](https://opencode.ai/docs/tools/): "By default, all tools are **enabled** and don't need permission to run" is accurate.
  [Permissions](https://opencode.ai/docs/permissions/): keys and "most default to `allow`" are accurate; the page also says `edit` "covers `edit`, `write`, `patch`" and lists no `write` key (see finding H5).
  [Models](https://opencode.ai/docs/models/): `provider_id/model_id` from models.dev is accurate; the page documents no alias or `-latest` form.
  Neither the Agents page nor the Permissions page says whether `opencode.json` `agent.<name>.model` overrides a markdown agent, so the proposal is right to treat that as unverified.
- **models.dev (`curl https://models.dev/api.json`).**
  `anthropic` has exactly 17 models; none of the three current pins exist; the newest ids and dates match Background.
  The only "(latest)" entries are per-minor undated ids (`claude-sonnet-4-5`, `claude-haiku-4-5`, `claude-opus-4-5`); there is no cross-generation alias.
  The same model has different ids per provider: `github-copilot/claude-opus-5.5`, `openrouter/anthropic/claude-opus-5.5`, `amazon-bedrock/anthropic.claude-opus-5-5`, `google-vertex-anthropic/claude-opus-5-5@default`, `opencode/claude-opus-5-5`.
- **npm registry.** `yaml` 2.9.1 has no dependencies; `js-yaml` 5.4.3 depends on `argparse`; `@weftwise/cdocs-opencode` has only 0.1.0 (2026-03-19). All match the proposal.
- **Round trip.** A scratch script (outside the repo, using an existing `yaml` 2.9.0 install) applied Solutions 1-3 to every `plugins/cdocs/agents/*.md`.
  All seven descriptions round-trip; `bash-runner` emits a `|` block scalar; `implementer`/`proposer`/`reviewer` emit only `description` and `mode`; `judge`/`nit-fix`/`triage`/`bash-runner` emit their current `tools`/`permission` values; single-line descriptions stay unquoted on one line.
  Edge strings (`a: b # c`, leading `"`, `- dash`, `yes`, `""`, trailing-newline variants) are quoted or block-scalared and round-trip.
  `YAML.parse` throws on `description: Use when: the user asks` ("Nested mappings are not allowed in compact mappings") and on duplicate keys.

## Section-by-Section Findings

### Hard Requirements

**H1 (non-blocking, positive). Minimal invasiveness is stated as a hard requirement and the design satisfies it.**
HR1 names the allowed path set, forbids changes under `plugins/cdocs/`, forbids new CC frontmatter conventions and CC authoring rules, keeps job-level `continue-on-error: true`, and includes the escalation clause.
I found no part of the design that violates it: no plugin file is edited, the README "model mapping" drift is deliberately deferred rather than fixed under `plugins/`, and the test only reads CC agents.
The `plugin.json` dependency for publishing is read-only.

**H2 (blocking). Parse errors contradict Hard Requirement 2 and create soft pressure on CC authoring.**
HR2 says the build "never fails on CC content it does not understand; it warns and degrades".
Solution 1 says "On a parse error, throw with the agent filename", and Edge Cases confirms "the build fails naming the file".
One agent the strict YAML parser rejects therefore fails the whole OC build, including the six valid agents and the package step.
The Edge Cases justification ("CC would mis-load the same file") is unverified: a description like `Use when: ...` is a plausible CC authoring pattern that `yaml` rejects, and whether CC's own loader tolerates it is not checked.
If CC accepts it and the OC build hard-fails, the de facto message to CC authors is "write strict YAML so the OC build works", which is the burden HR1 forbids.
Fix: catch the parse error per agent, warn naming the file, skip that agent, and continue; the test then flags the missing OC agent in non-blocking CI.
Update the Edge Cases bullet to match and drop the unverified CC claim (or verify it).

### Proposed Solution 1 (YAML)

**H3 (non-blocking, positive). `yaml` with stringify is the smallest correct fix, not over-built.**
Parse-only would leave `generateOCFrontmatter`'s `description: ${...}` interpolation unable to emit a multi-line value, so the emitter would need a hand-rolled block-scalar writer: exactly the bespoke YAML the RFP wants gone.
`yaml` is zero-dependency, a devDependency of a private root package, and never shipped.
`js-yaml` would also work; the one-dependency difference is marginal, and `yaml`'s choice is reasonable.

**H4 (non-blocking). `String(cc.description)` must stay guarded.**
The text says "when present", which is correct; `String(undefined)` would emit the literal `"undefined"` and defeat assertion 2's missing-description signal.
Worth one explicit word in Phase 1 so the implementer does not coerce unconditionally.

### Proposed Solution 2 (Tools)

**H5 (non-blocking). Wildcard-to-omission is verified; note the stale `write` permission key.**
The Tools page backs "absent = all tools enabled", and quote stripping is subsumed: `YAML.parse` yields `tools: "*"` as `*` and `Read, Glob, Grep` as a plain string, which the normalize step splits.
YAML sequences are also handled.
Separately, the explicit-list mapping emits `permission.write: ask`, but OC's Permissions page lists no `write` key (`edit` covers writes).
No current agent lists `Write`, so no output is affected; add this to the Deferred `permission` migration bullet so it is not lost.

**H6 (non-blocking). "Wildcard agents can launch subagents via OC's default `task: allow`" is stronger than the docs.**
The Permissions page says most keys default to `allow`, but neither it nor the Agents page states the `task` default or whether subagents can nest.
Soften to "per OC's documented permission defaults; nesting behavior is deferred to the nested-subagent proposal", consistent with the RFP Resolution row.

### Proposed Solution 3 / Decision 3 (Model)

**H7 (blocking). Decision 3 departs from the brief's verification floor and must say so.**
The invoking brief's floor (devlog Objective) requires generated output to show "current model ids"; Verification step 4 asserts the opposite (no `model:` line at all).
The proposal frames this as a design choice and a Reviewer Checklist item, but never states that it amends the brief's floor.
Downstream implementation reviewers check against the floor, so an unacknowledged amendment will resurface as a false failure.
Fix: add a NOTE in Decision 3 (or Verification) stating that omission replaces the "current model ids" floor item, with the maintainer as the decider, and name the pinned-map fallback as the alternative should the maintainer reject it.

**H8 (non-blocking, recommendation). Omission is the right default; it is still a maintainer judgment call.**
The proposal's strongest argument is underused: OC ids are provider-specific.
A pinned `anthropic/claude-opus-5-5` resolves only for consumers with the direct `anthropic` provider; GitHub Copilot (`claude-opus-5.5`), OpenRouter, Bedrock (`anthropic.claude-opus-5-5`), Vertex (`...@default`), and OpenCode Zen users all get an id their provider does not know.
Pinning therefore trades a cost/quality optimization for a hard failure on a large share of OC setups, and that is before staleness (two Anthropic releases in the last 10 days).
Alternatives considered:
- *Undated family ids* (`claude-opus-5-5`): still generation-bound, so they need the same bumps, and still provider-locked. Not a solution.
- *Per-minor "(latest)" ids*: models.dev has them only for 4.5-era models; current generations have undated ids only. Not a solution.
- *Pinned map plus non-blocking CI staleness warning*: fixes staleness visibility, but not provider lock-in, and adds a models.dev fetch to CI. Defensible only if the maintainer values tiers over portability.
- *Omit (proposed)*: zero maintenance, portable, documented OC default, consistent with the brief's "prefer a model map that does not need routine bumps" and with cdocs' "consumer floor wins" posture.
The tier-fidelity loss is real but asymmetric: downward tiers (`nit-fix`, `triage`, `bash-runner`) cost more but still work, while `judge`/`reviewer` lose their opus floor only when the consumer chose a cheap primary, which is the consumer's call in OC.
Recommendation: keep omission as the default, add the provider-id evidence to Decision 3, and surface the choice to the maintainer as Question 1 below.

### Proposed Solution 4 / Test Plan (Regression test and CI)

**H9 (non-blocking). Test scope is proportionate.**
One `node:test` file over the real agents, with four assertions, is the smallest check that can parse YAML reliably; the bash grep it replaces cannot.
It catches all three failure pictures: an empty `bash-runner` description fails assertion 2, `edit: false` on wildcard agents fails assertion 4 (any `tools` key on a wildcard agent fails it), and any `model:` line fails assertion 3.
Skipping unit tests on internals is the right call.

**H10 (non-blocking). The build runs twice in CI.**
The workflow keeps its "Build OC artifacts" step and the test's `before` hook rebuilds.
Harmless, but either drop the workflow build step (the test builds) or make the script `"test:opencode": "npm run build:cdocs && tsx --test ..."` and have the test read existing output.
Pick one so the CI and local paths agree.

**H11 (non-blocking). CI change is consistent.**
Replacing the bash check removes the `model` requirement that is red today, path triggers gain the test file and `package*.json`, `npm pack --dry-run` stays, and `continue-on-error: true` stays.
`package-lock.json` is committed, so `npm ci` will pick up the new devDependency once the lockfile is updated in Phase 1; say "commit the lockfile" explicitly.

### Verification Methodology

**H12 (non-blocking). Concrete and covers the failure pictures; one count is off.**
Step 2 says "the eight body lines", but `bash-runner`'s description has seven body lines (six text lines and one blank); the Objective's "8-line" counts the `description: |` header.
Say "seven body lines" or "the full body ending in `Responds with a report...`".
Step 5 ("revert each fix in turn") is the right falsification check for the test.
Step 7 (`git diff --stat main...HEAD -- plugins/` empty) is a good mechanical guard for HR1.

### RFP Resolution

**H13 (non-blocking). Every scope item and open question is answered or deferred; the republish row is inaccurate.**
I checked all six YAML scope items, three YAML open questions, six tools scope items, three tools open questions, five model scope items, and three model open questions: each has a row.
The "YAML/model: republish" row says the fixes "ship with the next ordinary plugin version bump; no extra release step", but the workflow has no publish step (the Deferred section says so), and `plugin.json` is still at 0.1.0, the published version.
Nothing ships until someone bumps the version and runs `npm publish` by hand.
Reword to: "Republishing is a manual step outside this proposal; 0.1.0 keeps its unknown model ids until then."

### Writing Conventions

**H14 (non-blocking). Conventions are followed.**
BLUF is accurate and produces no surprises, sentence-per-line holds, there are no em-dashes, and external references are linked.
Semicolons are somewhat frequent (e.g. "They are not just stale; they are unknown to OC's catalog."); a few could be periods.
Describing today's broken output at `a88ffda` is appropriate for a bug-fix proposal, not a history-agnostic violation.

## Verdict

**Revise.**
The design is sound, minimal, and verified; the two blocking items are text-level fixes that do not change the architecture.

## Action Items

1. [blocking] Make YAML parse errors per-agent warn-and-skip instead of build-failing, to match Hard Requirement 2; update Solution 1, the Edge Cases bullet, and remove or verify the "CC would mis-load the same file" claim.
2. [blocking] In Decision 3, add a NOTE that omitting `model:` replaces the brief's "current model ids" verification floor, pending maintainer confirmation, with the pinned map named as the fallback.
3. [non-blocking] Add the provider-specific id evidence (Copilot, OpenRouter, Bedrock, Vertex, Zen ids differ from `anthropic/...`) to Decision 3 as the main portability argument.
4. [non-blocking] Add the stale `permission.write` key (OC has no `write` permission) to the Deferred `permission` migration bullet.
5. [non-blocking] Soften the "Wildcard agents can launch subagents via OC's default `task: allow`" edge case to what the docs actually state.
6. [non-blocking] Resolve the double build in CI (drop the workflow build step, or have `test:opencode` build first and the test read existing output).
7. [non-blocking] Fix Verification step 2's line count ("seven body lines").
8. [non-blocking] Reword the republish RFP row: publishing is manual and outside this proposal.
9. [non-blocking] Phase 1: state explicitly that `String(...)` applies only when `description` is present, and that `package-lock.json` is committed.

## Questions for the Maintainer

1. **OC agent model policy** (proposal default: A).
   - A. Omit `model:`; OC subagents inherit the caller's model (portable, zero maintenance, loses per-agent tiers).
   - B. Pin current `anthropic/` ids per tier, with a non-blocking CI staleness warning (keeps tiers, needs bumps, breaks non-`anthropic` providers).
   - C. Omit by default, and document an opt-in consumer override once `opencode.json` `agent.<name>.model` is verified to apply to markdown agents (follow-up, not this proposal).
2. **Unparseable CC agent frontmatter in the OC build** (review recommends: A).
   - A. Warn and skip that agent; the rest of the build continues.
   - B. Fail the build naming the file (as currently proposed).
