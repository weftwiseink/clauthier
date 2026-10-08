---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T18:26:37-07:00
task_list: build/opencode-build-fixes
type: proposal
state: live
status: implementation_wip
last_reviewed:
  status: accepted
  by: "@claude-opus-5-5"
  at: 2026-10-07T18:37:12-07:00
  round: 2
tags: [build, opencode, yaml, frontmatter, models, multi-target]
---

# OpenCode Build Fixes: YAML Frontmatter, Wildcard Tools, Model Ids

> BLUF(opus-5-5/build/opencode-build-fixes): Fix three `scripts/build-opencode.ts` bugs inside the OC build path only.
> Parse and emit agent frontmatter with the zero-dependency `yaml` package (fixes the empty `bash-runner` description), skipping with a warning any agent whose frontmatter fails to parse.
> Map CC `tools: "*"` to no `tools:`/`permission:` block, which OpenCode documents as "all tools enabled".
> Stop emitting `model:`, so OC subagents inherit the invoking agent's model: no id to go stale, no provider lock-in, at the cost of per-agent tiers.
> One `node:test` file replaces the CI grep check, and CI stays `continue-on-error`.
> No CC file changes.
>
> - **Subsumes:** [`2026-10-05-opencode-build-yaml-parser-rfp.md`](2026-10-05-opencode-build-yaml-parser-rfp.md), [`2026-10-06-opencode-wildcard-tools-mapping-rfp.md`](2026-10-06-opencode-wildcard-tools-mapping-rfp.md), [`2026-10-05-opencode-model-mapping-rfp.md`](2026-10-05-opencode-model-mapping-rfp.md)
> - **Devlog:** [`2026-10-07-opencode-build-fixes.md`](../devlogs/2026-10-07-opencode-build-fixes.md)

## Summary

All three bugs are local to the converter's frontmatter handling (`parseFrontmatter`, `mapTools`, `MODEL_MAP`/`generateOCFrontmatter`), so one proposal, one file, and one test cover them.
Each fix is the smallest change OpenCode's documented defaults allow: the parser and model fixes are net deletions.
The cost of the model fix is tier fidelity: OC `nit-fix`/`triage`/`bash-runner` no longer run on a cheaper tier, and `judge`/`reviewer` no longer force an opus-class model.
Design Decision 3 weighs that against the alternatives and is the one maintainer judgment call here.

> NOTE(opus-5-5/build/opencode-build-fixes): Target-specific guidance (`2026-10-06-target-specific-guidance-rfp.md`) is out of scope and untouched.

## Objective

Make `npm run build:cdocs` produce OC agents that match their CC definitions on the three fields that are broken today, without touching the Claude Code setup.

Observed output at `a88ffda` (`build/cdocs/opencode/agents/`):

| Agent | Field | CC source | Generated OC |
|---|---|---|---|
| `bash-runner` | `description` | `\|` block scalar, seven body lines | `description: \|` then nothing (parses to `""`) |
| `implementer`, `proposer`, `reviewer` | `tools` | `"*"` | `read`/`edit`/`write`/`bash` all `false`, warning `Unknown CC tool ""*""` |
| all pinned agents | `model` | `haiku`/`sonnet`/`opus` | `anthropic/claude-3-5-haiku-20241022`, `anthropic/claude-sonnet-4-20250514`, `anthropic/claude-opus-4-20250514` |

None of the three pinned ids appears in the [models.dev](https://models.dev/api.json) `anthropic` provider (fetched 2026-10-07, 17 models), which OpenCode uses as its model catalog.
They are not just stale: they are unknown to OC's catalog.

The CI validation step is also red today, masked by `continue-on-error`: it requires a `model:` line, which `implementer` and `proposer` deliberately omit.

## Background

- `scripts/build-opencode.ts`: `MODEL_MAP` (L57), `mapTools` (L79), `parseFrontmatter` (L130, a per-line regex scanner), `generateOCFrontmatter` (L167, `lines.push` string assembly).
- `.github/workflows/opencode-build.yml`: Node 22, `npm ci`, build, a bash `grep` field check, `npm pack --dry-run`, all under job-level `continue-on-error: true`.
- Root `package.json`: private, devDependencies `tsx`, `typescript`, `@types/node`.
- CC agent frontmatter (`plugins/cdocs/agents/*.md`) uses a block literal (`bash-runner`), a quoted scalar (`tools: "*"`), a block sequence (`skills:`), and `#` comments (`implementer`, `proposer`).
  Skills and rules are copied verbatim (`copyDir`), never parsed.

OpenCode facts (fetched 2026-10-07):

- [Agents](https://opencode.ai/docs/agents/): "If you don't specify a model, primary agents use the model globally configured while subagents will use the model of the primary agent that invoked the subagent."
- [Agents](https://opencode.ai/docs/agents/): "`tools` is deprecated. Prefer the agent's permission field for new configs".
  `description` is required, and `mode: subagent` is valid.
- [Tools](https://opencode.ai/docs/tools/): "By default, all tools are enabled and don't need permission to run."
- [Permissions](https://opencode.ai/docs/permissions/): keys include `read`, `edit` (covering edit, write, and patch), `bash`, `task` (subagent launch), and `webfetch`, with values `allow`/`ask`/`deny`.
  Most default to `allow`.
  There is no `write` key.
- [Models](https://opencode.ai/docs/models/): ids are `provider_id/model_id` from models.dev.
  The catalog carries undated ids (`claude-opus-5-5`) but no cross-generation `-latest` alias.
  Its newest Anthropic ids are `claude-haiku-5-5` (2026-10-07), `claude-sonnet-5-5` (2026-09-28), `claude-opus-5-5` (2026-09-22), and `claude-fable-5-1` (2026-09-01).
- Model ids are provider-specific.
  The same Opus 5.5 is `anthropic/claude-opus-5-5`, `github-copilot/claude-opus-5.5`, `openrouter/anthropic/claude-opus-5.5`, `amazon-bedrock/anthropic.claude-opus-5-5`, `google-vertex-anthropic/claude-opus-5-5@default`, and `opencode/claude-opus-5-5` (OpenCode Zen), among about 40 provider entries.

YAML libraries (npm registry, 2026-10-07): [`yaml`](https://www.npmjs.com/package/yaml) 2.9.1 has zero dependencies and bundled types.
[`js-yaml`](https://www.npmjs.com/package/js-yaml) 5.4.3 has one dependency (`argparse`) and bundled types.
Node (22 in CI, 26 locally) has no built-in YAML module.

Published package: [`@weftwise/cdocs-opencode`](https://www.npmjs.com/package/@weftwise/cdocs-opencode) has a single version, 0.1.0 (2026-03-19), containing only `nit-fix`, `reviewer`, and `triage`.
It predates the block-scalar and wildcard triggers, so of the three bugs it carries only the unknown model ids.
`plugin.json` is still at 0.1.0, and the workflow has no publish step.

## Hard Requirements

1. **OpenCode support is minimally invasive, and Claude Code is never burdened.**
   Changes stay within the OC build path: `scripts/build-opencode.ts`, its test, `.github/workflows/opencode-build.yml`, build output, and root `package.json`/`package-lock.json` devDependencies and scripts.
   Nothing under `plugins/cdocs/` changes: not the authoring format, rules, skills, agents, hooks, README, `plugin.json` version, or the CC install.
   No new frontmatter conventions, no authoring rules for CC agents "so the OC build works", and no CI gate that blocks CC-only PRs: the workflow keeps job-level `continue-on-error: true`.
   Prefer the smallest fix.
   If a fix cannot be made without getting in the CC setup's way, stop and escalate with a recommendation.
   The maintainer may drop OC support rather than compromise CC.
   This proposal needs no such escalation: every fix below satisfies it.
2. **The build never fails on CC content it does not understand.** It warns, degrades, and keeps building the rest.

## Proposed Solution

### 1. Parse and emit with `yaml`

- Add `yaml` (^2) as a root devDependency.
- `parseFrontmatter` keeps its delimiter regex and replaces the line scanner with `YAML.parse(fmRaw)`.
- The agent loop in `main` catches a parse error per agent, warns with the filename and the parser's message, skips that agent, and continues (Hard Requirement 2).
  Strict YAML may reject frontmatter CC tolerates (e.g. `description: Use when: ...`), so a parse failure must cost OC that one agent, not the whole build.
- `generateOCFrontmatter` builds a plain object in the current key order (`description`, `mode`, then optional `tools`, `permission`) and returns `"---\n" + YAML.stringify(obj, { lineWidth: 0 }) + "---"`.
  `lineWidth: 0` disables folding, so single-line descriptions stay on one line as they do today, and multi-line strings come out as `|` block scalars.
  Stringify also quotes values that would otherwise be invalid YAML (e.g. a description containing `: `), which the string assembly does not.
- Set `description` with `String(...)` only when present: `String(undefined)` would emit a literal `undefined` and hide a missing description.

### 2. Wildcard and absent `tools`

Normalize `cc.tools` to a list of names: a string splits on commas, a YAML sequence is used as-is, and `null`/absent is absent.

- Absent, empty, or containing `*`: emit neither `tools:` nor `permission:`.
  OpenCode then applies its defaults (all tools enabled) and the consumer's own permission config governs.
  That is the OC analogue of CC's "deliberately not narrowed".
- Otherwise: the existing explicit-list mapping, unchanged (four booleans, `edit`/`write` -> `ask`).

Absent `tools` already emits no block today.
Only `*` changes behavior.

### 3. Model: omit

Delete `MODEL_MAP` and the `model:` emission.
Every generated OC agent omits `model`, so it inherits the invoking primary agent's model per the OC docs quoted above.
CC `inherit`, `fable`, and any future alias need no handling.

### 4. Regression test and CI

Add `scripts/build-opencode.test.ts` (`node:test`) and a root script `"test:opencode": "npm run build:cdocs && tsx --test scripts/build-opencode.test.ts"`.
The test reads the existing build output.
For every `plugins/cdocs/agents/*.md`:

1. A generated OC file exists.
   This catches an agent the build skipped on a parse error.
2. The OC frontmatter parses with `yaml`, and `mode === "subagent"`.
3. `description` is a non-empty string equal to the parsed CC `description`.
4. No `model` key.
5. If CC `tools` is absent or contains `*`, OC has no `tools` and no `permission` key.
   Otherwise each of `read`/`edit`/`write`/`bash` is `true` iff the CC list names `Read`/`Edit`/`Write`/`Bash`.

The workflow replaces both the "Build OC artifacts" step and the bash "Validate generated agent frontmatter" step with one `npm run test:opencode` step, so the build runs once and CI matches the local command.
It adds `scripts/build-opencode.test.ts` and `package*.json` to the path triggers, and keeps `npm pack --dry-run` and job-level `continue-on-error: true`.

## Important Design Decisions

1. **`yaml` over `js-yaml`.**
   Both parse correctly and ship types.
   `yaml` has zero runtime dependencies and a stringifier that emits block scalars and quotes unsafe values, which fixes the emitter as well as the parser.
   It is a devDependency of a private root `package.json`: it never reaches the CC plugin or the published OC package.
   A bespoke parser fix was rejected: the RFP's point is that patching the scanner for one YAML feature leaves the next one broken.
2. **Wildcard maps to omission, not four `true` keys.**
   CC `*` means every tool, including `Agent`.
   OC's default is every tool, including `task`, `webfetch`, and MCP tools.
   Emitting four `true` keys would enable only the four tools the build knows about and still route through the deprecated `tools` key.
   Omission is fewer lines of output and code, and is exact.
3. **Omit `model` (inherit) over pinning current ids.**
   - *Pin current ids* (`haiku -> anthropic/claude-haiku-5-5`, etc.): keeps tiers, but resolves only for consumers on the direct `anthropic` provider.
     Copilot, OpenRouter, Bedrock, Vertex, and Zen users get an id their provider does not know (Background).
     It also needs a bump every generation: the catalog shows two new Anthropic releases (`claude-sonnet-5-5`, `claude-haiku-5-5`) in the 10 days before this proposal.
   - *Pin plus a non-blocking CI staleness warning*: makes staleness visible but keeps provider lock-in and adds a models.dev fetch to CI.
   - *Resolve newest-per-family from models.dev at build time*: no bumps, but adds network to the build, a naming heuristic, and still provider lock-in.
   - *Omit*: zero maintenance and provider-agnostic, and it matches the documented OC default.
     The cost: haiku/sonnet-tier agents run on the (usually larger) primary model, which costs more but still works.
     `judge`/`reviewer` lose their opus-class floor only when the consumer picked a cheaper primary, which is the consumer's call in OC.
   The CC-side tiers are cost optimizations, while an id the provider does not know breaks the agent, so correctness wins.
   Reverting to a pinned map is a small change, and test assertion 4 would change with it.

   > NOTE(opus-5-5/build/opencode-build-fixes): This decision supersedes the brief's "current model ids" verification floor (devlog Objective).
   > The floor becomes "no `model:` line in any generated agent" (Verification step 4).
   > Rationale: provider-specific ids (models.dev) make any pin non-portable, and omission needs no routine bumps.
   > Omit-model is the overseer-confirmed default.
   > It goes to the maintainer as a judgment call, with the pinned `anthropic/` map as the documented alternative.
4. **Keep the deprecated `tools` key for explicit lists.**
   Explicit-list agents (`bash-runner`, `judge`, `nit-fix`, `triage`) produce working output today, and deprecated is not removed.
   Migrating them to `permission` is deferred (see Deferred).
5. **No build-time guard. The test is the guard.**
   A build error on "all tools disabled" or "unknown tool" would fail OC packaging over CC content that may be legitimate: a `Glob, Grep`-only agent maps to four `false` keys correctly.
   The test asserts the specific shapes instead, and its failures surface in non-blocking CI.

## RFP Resolution

| RFP item | Resolution |
|---|---|
| YAML: parser choice | `yaml`, Decision 1. |
| YAML: round-tripping | Emit via `YAML.stringify` too. Transformed fields: `model` dropped, `tools` per Solution 2, `skills`/`name`/other CC-only keys dropped (unchanged). Descriptions round-trip exactly (test assertion 3). |
| YAML: audit of other hand-rolled parsing | Only `parseFrontmatter` parses YAML. `mapTools` is a domain transform and stays. Quote stripping is subsumed by the parser. `rewriteBodyPaths` is untouched. |
| YAML: regression coverage, agents/skills/rules | Agents only: skills and rules are copied verbatim, so there is nothing to round-trip. The test lives beside the script and CI runs it. |
| YAML: sequencing with model RFP | Moot: one proposal. The parser lands first (Phase 1) since it changes how `tools`/`model` are read. |
| YAML/model: republish | Out of scope. Publishing is a manual step: the workflow has no publish step, and `plugin.json` is still at the published 0.1.0. Until someone bumps and publishes by hand, 0.1.0 keeps its unknown model ids. |
| YAML OQ: shape regression in working fields | No: every emitted field parses to the same type and value as before, and `lineWidth: 0` keeps single-line output identical in shape. Test assertions 2-5 guard it. |
| YAML OQ: blocking CI gate? | No, non-blocking (Hard Requirement 1). |
| YAML OQ: other YAML features as fixtures | Current agents use block literal, quoted scalar, block sequence, and comments, all exercised by the real-agent test. Flow sequences, `>`, and anchors are the library's responsibility. No synthetic fixtures. |
| Tools: quote stripping | Subsumed by `YAML.parse` (`"*"` -> `*`). |
| Tools: OC "all tools" form | Omit `tools`/`permission` (Decision 2). OC `tools` supports wildcard keys (`"mymcp_*": false`), but a positive "everything" key is unnecessary given the default. |
| Tools: `permission` for all-tools agents | None emitted. OC defaults plus consumer config govern. |
| Tools: `task` | Governed by OC's documented permission defaults for wildcard agents. No explicit mapping added for CC `Agent`, since no explicit-list agent uses it. |
| Tools: build-time guard | Rejected in favor of the test (Decision 5). |
| Tools OQ: absent block = all tools, stable? | Documented today ([Tools](https://opencode.ai/docs/tools/)). Stability across versions is not promised, and the test cannot detect an upstream change. Accepted risk. |
| Tools OQ: `task` nesting depth | Deferred to [`2026-10-06-nested-subagent-workflows.md`](2026-10-06-nested-subagent-workflows.md). Not a build concern. |
| Tools OQ: unknown CC tool, warn or error? | Stays a warning (Hard Requirement 2). In explicit-list mode an unmapped OC tool stays at its OC default (enabled), so the warning flags lost restriction, not lost capability. |
| Model: aliases or latest ids | Undated ids exist, but no cross-generation alias does. Moot under omission. |
| Model: source of truth and freshness | None needed under omission. |
| Model: consumer override | OC-native: the consumer's primary model governs. Per-agent override via `opencode.json` `agent.<name>.model` is not verified against markdown agents, so the design does not rely on it. |
| Model: `fable`, `inherit` | Handled by omission. |
| Model: CI stale-mapping check | Not needed under omission. |
| Model OQ: stale-but-valid vs drifting alias | Neither: inherit. |

## Edge Cases / Challenging Scenarios

- **CC frontmatter that strict YAML rejects** (e.g. an unquoted `description: Use when: ...`, duplicate keys).
  The build warns naming the file and the parser error, skips that agent, and finishes the rest.
  Test assertion 1 reports the missing agent in non-blocking CI.
- **`tools:` with no value.** Parses to `null` and is treated as absent (all tools).
- **Description containing YAML-significant characters** (`: `, leading `"`, `#`).
  Stringify quotes or block-scalars it, and assertion 3 checks the value round-trips.
- **CC agent without a description.** OC requires one.
  The build emits none (unchanged), and assertion 3 flags it in non-blocking CI.
- **Explicit-list agents keep OC-default tools** (`webfetch`, `task`, `glob`, ...) enabled, because only four keys are set.
  This gap predates this work and belongs to the deferred `permission` migration.
- **Wildcard agents and subagent launch.** `task` follows OC's documented permission defaults, as for any agent without a `permission` block.
  Nesting behavior is deferred to the nested-subagent proposal.
- **Cost on OC.** `bash-runner`, `nit-fix`, and `triage` run on the primary model.
  Acceptable for correctness, and noted for OC consumers who care about cost.
- **OC removes `tools`.** Explicit-list agents would lose their restrictions.
  The deferred migration covers it.
  Wildcard agents are unaffected.

## Test Plan

`scripts/build-opencode.test.ts` runs assertions 1-5 from Proposed Solution 4 over all seven current agents.
Named failure pictures it must catch, checked by temporarily reverting each fix:

- `bash-runner` OC `description` empty or missing (fails assertion 3).
- `implementer`/`proposer`/`reviewer` OC `tools.edit === false` (fails assertion 5).
- Any OC `model:` line (fails assertion 4).
- An agent skipped on a parse error (fails assertion 1).
  Exercise the build side with the scratch-root recipe in Verification step 8, never by editing a CC agent.

No unit tests on internal functions: the real agents cover every YAML feature in use, and exporting internals for tests adds surface for no extra coverage.

## Verification Methodology

From the worktree root:

0. Before Phase 1, run `npm run build:cdocs` and copy `build/cdocs/opencode/agents/` to a scratch directory as the baseline.
   Phase 1's "unchanged in value" check and step 3 compare against it.
1. `npm ci && npm run build:cdocs`: exit 0, no `Unknown CC tool` and no skipped-agent warning.
2. `build/cdocs/opencode/agents/bash-runner.md`: `description: |` followed by the seven body lines, from `Run one expected-verbose` through `Responds with a report...`.
3. `implementer.md`, `proposer.md`, `reviewer.md`: no `tools:` or `permission:` block.
   `judge.md`, `nit-fix.md`, `triage.md`, `bash-runner.md`: same `tools`/`permission` values as the step 0 baseline.
4. `grep -l '^model:' build/cdocs/opencode/agents/*.md` prints nothing (this replaces the brief's "current model ids" floor, per the Decision 3 NOTE).
5. `npm run test:opencode`: all pass.
   Then revert each fix in turn and confirm the matching assertion fails.
6. The CI steps locally: `npm run test:opencode`, then `(cd build/cdocs/opencode && npm pack --dry-run)`, both exit 0.
   `grep -n continue-on-error .github/workflows/opencode-build.yml` still shows the job-level setting.
7. Hard Requirement 1: `git diff --stat main...HEAD -- plugins/` is empty, and every changed path outside `cdocs/` is in the allowed set.
8. Hard Requirement 2 (warn-and-skip): the build resolves `REPO_ROOT` from the script's own location, so test it in a scratch root.
   Copy `scripts/`, `plugins/cdocs/`, and `package.json` into a scratch directory and symlink `node_modules`.
   Append `description: Use when: x` as a second `description` key to one scratch agent.
   Run `npx tsx <scratch>/scripts/build-opencode.ts`.
   Expect exit 0, one warning naming that file, and six generated agents.

## Implementation Phases

The phases are sequential and touch the same file, so one implementer runs them.
Commit each phase separately.

**Do not change:** anything under `plugins/cdocs/` (including README and `plugin.json`), `continue-on-error`, the explicit-list `tools`/`permission` mapping, `rewriteBodyPaths`, skills/rules copying, package generation.

### Phase 1: YAML parse and emit

- `npm i -D yaml@^2`, committing `package.json` and `package-lock.json` (CI uses `npm ci`).
- Replace the scanner in `parseFrontmatter` with `YAML.parse`, with per-agent warn-and-skip on parse errors in `main`.
- Rewrite `generateOCFrontmatter` as an object plus `YAML.stringify(..., { lineWidth: 0 })`, setting `description` only when present.
- Update the stale "no YAML library needed" section comment.
- Done when: the build passes and `bash-runner.md` has its full description.
  The other agents' frontmatter is unchanged in value against the Verification step 0 baseline.

### Phase 2: Tools and model mapping

- Normalize `tools`, and omit `tools`/`permission` for absent or `*`.
- Delete `MODEL_MAP` and the `model:` emission.
- Done when: Verification steps 1-4 hold.

### Phase 3: Regression test and CI

- Add `scripts/build-opencode.test.ts` and the `test:opencode` script.
- Replace the workflow's build and bash validation steps with `npm run test:opencode`, extend path triggers, and keep `continue-on-error: true`.
- Done when: Verification steps 5-8 hold.

## Reviewer Checklist

- [ ] **Hard Requirement 1:** no path under `plugins/` changes.
  No CC authoring rule, frontmatter convention, or blocking CI gate is introduced.
  `continue-on-error: true` remains.
  Every change is in the allowed OC build path.
- [ ] **Hard Requirement 2:** an unparseable agent is warned about and skipped, never fatal to the build.
- [ ] Each of the three RFPs' Scope items and Open Questions is answered or deferred with rationale (RFP Resolution).
- [ ] The Decision 3 NOTE states that omit-model supersedes the "current model ids" floor.

## Deferred

- Migrating explicit-list agents from the deprecated OC `tools` key to `permission`, including denying unlisted OC tools for fidelity.
  The current mapping's `permission.write: ask` targets a key OC does not define (`edit` covers writes).
  No current agent lists `Write`, so no output is affected today.
  Deferred because it is not one of the three bugs, current output works, and it changes four working agents.
- `plugins/cdocs/README.md` "Building OC artifacts from source" still says the build does "model mapping".
  Correcting it would touch `plugins/cdocs/`, which Hard Requirement 1 excludes.
  The maintainer can fix that phrase in a CC-side docs pass.
- The workflow header and `CLAUDE.md` say CI "optionally publishes", but the workflow has no publish step.
  Left as-is.
