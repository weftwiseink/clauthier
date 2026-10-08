---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T21:47:43-07:00
task_list: cdocs/rules-references
type: proposal
state: live
status: review_ready
last_reviewed:
  status: revision_requested
  by: "@claude-opus-5-5"
  at: 2026-10-07T21:53:11-07:00
  round: 1
tags: [rules, rules_delivery, init, testing, architecture]
---

# Rules References

> BLUF: Shipped cdocs content refers to rules by heading, never by filename: `"CDocs Overseer Rules › Chat record"`, which resolves in every delivery form (Claude Code, `AGENTS.md`, OpenCode, this source repo).
> A `node:test` check (`npm run test:rules`, blocking in CI) resolves every such reference against the headings of the materialized rules and flags bare rule-filename references.
> Agents drop their rule-file reads: rules already reach every subagent's context.
> `/cdocs:init` delivers rules per file as unscoped `.claude/rules/cdocs/<name>.md`, auto-loaded with no `CLAUDE.md` `@`-import; the freshness hook stays.

## Summary

Downstream, `/cdocs:init` concatenates the rule files into `.claude/rules/cdocs.md` and inlines them into `AGENTS.md`, so a rule's filename names nothing a consuming session can see.
Three reference kinds are affected:

| Kind | Sites | Downstream effect | Convention |
|---|---|---|---|
| Rule and template text | `frontmatter-spec.md:85`, `skills/devlog/template.md:10` | Dead name; the template copies it into every devlog | Heading reference |
| Agent Startup reads | `reviewer`, `proposer`, `implementer`, `judge`, `triage`, `nit-fix`; plus `judge.md:74`, `implement/SKILL.md:53`, `nit_fix/SKILL.md:48`, `triage/SKILL.md:69` | Failed Reads on every dispatch; redundant reads in this repo | "The rules are already in your context" plus heading references |
| Skill relative links (`../../rules/x.md`) | 10 links in 8 skills | Resolve in the Claude Code plugin cache, dead in the OpenCode layout, redundant everywhere | Heading reference, no link |

The check is the "2x check" the maintainer asked for: it parses the materialized rule text, not the source filenames, and fails CI on an unresolved heading or a filename reference.

The delivery change is separable.
Claude Code auto-loads every `.md` under `.claude/rules/` recursively, re-injects unscoped rules after compaction, and gives them to subagents, so the single concatenated file and its `@`-import buy nothing the per-file layout lacks.
Per-file delivery makes init's Claude Code and OpenCode steps the same shape, stops init from editing `CLAUDE.md`, and lists each rule in `/context`.
It does not make filename references safe, because `AGENTS.md` still inlines the rules: the heading convention holds either way.
Its hook tests cover two bullets of the [hook testing RFP](2026-09-01-rules-hook-testing-methodology-v2.md); the reference check covers none.

> NOTE(@claude-opus-5-5/cdocs/rules-references): There is no plugin-native rules field.
> [#14200](https://github.com/anthropics/claude-code/issues/14200) is open with no maintainer response as of Claude Code v2.1.293, and the plugins reference states a plugin-root `CLAUDE.md` is not loaded.

## Objective

1. Every rule reference in shipped content (rules, skills, skill templates, agents) resolves in every delivery form.
2. A mechanical check proves (1) on every change, using the existing `tsx` and `node:test` setup.
3. Agents stop spending tool calls on rule-file paths that do not exist downstream.
4. Rule delivery uses the simplest Claude Code affordance that keeps launch loading, subagent loading, and post-compaction re-injection.

Out of scope: the "advisor subagent" wording in `overseers.md` "Stay thin"; target-specific guidance ([RFP](2026-10-06-target-specific-guidance-rfp.md)); references between skills (for example the devlog skill's "Handoffs"), which resolve inside the plugin.

## Background

### Delivery today

- `/cdocs:init` ([SKILL.md](../../plugins/cdocs/skills/init/SKILL.md)) step 3 concatenates every `${CLAUDE_PLUGIN_ROOT}/rules/*.md`, frontmatter stripped, into `.claude/rules/cdocs.md` in the order of its step 6 list, prepends a `<!-- cdocs rules vX.Y.Z hash=<sha256> ... -->` marker, and adds `@.claude/rules/cdocs.md` to `CLAUDE.md`.
  Step 5 copies each rule to `.opencode/rules/cdocs/<name>.md` when OpenCode is detected; step 6 inlines all rules into an `AGENTS.md` block, each under a `## CDocs ...` heading.
- [`inject-rules.ts`](../../plugins/cdocs/hooks/inject-rules.ts) (SessionStart) hashes the plugin's sorted rule bodies and nudges a re-run of `/cdocs:init` when the marker in `.claude/rules/cdocs.md` differs.
- In this source repo, `CLAUDE.md` `@`-imports `plugins/cdocs/rules/*.md` directly, so filename references appear to work while authoring.
  That is why they keep being written.
- Every rule file has a unique H1 beginning `CDocs ` (`CDocs Overseer Rules`, `CDocs Frontmatter Specification`, ...).
  The H1 survives every delivery form: concatenation and per-file copies keep the body; the `AGENTS.md` block keeps the body under its own wrapper heading.
- [`chat-record.test.sh`](../../plugins/cdocs/hooks/tests/chat-record.test.sh) `--unit` already asserts that init's step 6 list names exactly the files in `rules/`, and its `init_rules` helper re-implements the concatenation for headless fixtures.

### Audit verification

Each audit claim was checked against the tree at `7cad508`:

- `frontmatter-spec.md:85` and `skills/devlog/template.md:10` reference `overseers.md` "Chat record": confirmed.
- Startup blocks in `reviewer.md:18-27`, `proposer.md`, `implementer.md`, `judge.md`, `triage.md` read `rules/<file>.md` then `plugins/cdocs/rules/<file>.md`: confirmed.
  `nit-fix.md:17-28` is a sixth variant (Glob `rules/*.md` "relative to this agent file's directory", which an agent cannot locate).
  The Read tool resolves paths against the session, not the agent file, so README "Agent path resolution" (`README.md:112-116`) is wrong; in a consuming repo neither path exists, and in this repo the reads duplicate content already loaded.
- `implement/SKILL.md:53` and `judge.md:74`: confirmed; also `nit_fix/SKILL.md:48` ("reads all rule files from `plugins/cdocs/rules/`") and `triage/SKILL.md:69` ("reads rules at runtime"), not in the audit.
- Skill relative links: exactly 10 (`full-send:13`, `oversee:12`, `propose:144`, `ablate:20,290,291`, `iterate:34`, `propose-revise:45`, `implement:19`, `devlog/SKILL.md:31`).
  The audit's "resolve inside the installed plugin dir" holds for Claude Code only: the OpenCode `postinstall.js` copies skills to `.opencode/skills/<name>/` and rules to `.opencode/rules/cdocs/`, so `../../rules/overseers.md` points at a nonexistent `.opencode/rules/overseers.md`.
- Out of check scope by design: `plugins/cdocs/README.md`, `plugins/cdocs/bin/README.md:64`, and `plugins/cdocs/AGENTS.md:45` describe the plugin source tree, where their relative paths resolve.

### Claude Code rule loading (v2.1.293)

| Question | Answer | Source |
|---|---|---|
| Does `.claude/rules/` load without an `@`-import, recursively? | Yes: "All `.md` files are discovered recursively" | [memory](https://code.claude.com/docs/en/memory#organize-rules-with-claude/rules/) |
| Unscoped vs `paths:` rules | Unscoped load at launch "with the same priority as `.claude/CLAUDE.md`"; `paths:` rules load when Read, Write, or Edit touches a match | [memory](https://code.claude.com/docs/en/memory#path-specific-rules) |
| After compaction | "Project-root CLAUDE.md and unscoped rules: Re-injected from disk"; `paths:` rules reload on demand only | [context-window](https://code.claude.com/docs/en/context-window#what-survives-compaction) |
| Subagents | Non-fork subagents get "every level of the CLAUDE.md hierarchy ... including ... project rules"; Explore, Plan, and `omitClaudeMd: true` agents skip it | [sub-agents](https://code.claude.com/docs/en/sub-agents#what-loads-at-startup) |
| `/memory` | Does not list rules; `/context` does | [memory](https://code.claude.com/docs/en/memory#view-and-edit-with-/memory) |
| Plugin-native rules | None; a plugin-root `CLAUDE.md` "isn't loaded as context" | [plugins-reference](https://code.claude.com/docs/en/plugins-reference#standard-layout) |
| `${CLAUDE_PLUGIN_ROOT}` in agent bodies | Substituted inline in "skill, command, and agent content" | [plugins-reference](https://code.claude.com/docs/en/plugins-reference#where-each-variable-resolves) |

> NOTE(@claude-opus-5-5/cdocs/rules-references): Headless probes on v2.1.293 in a scratch git project confirmed the first and fourth rows: `.claude/rules/top.md` and `.claude/rules/cdocs/nested.md` loaded with no import, a `paths:`-scoped sibling did not, and a dispatched `general-purpose` subagent saw both loaded sentinels.
> With `CLAUDE.md` also `@`-importing `.claude/rules/top.md`, `claude -p /context` listed the file once, so the current redundant import does not double-load.
> The docs promise that deduplication only for `AGENTS.md`, so the current layout relies on undocumented behavior.

### Related documents

- [Rules hook testing methodology v2 (RFP)](2026-09-01-rules-hook-testing-methodology-v2.md): hook branch tests, marker generation, round trip, directive size.
  See "Relation to the hook testing RFP" below.
- [Rule delivery materialization](2026-05-12-cdocs-rule-delivery-materialization.md): the accepted design of the marker, hook, and Read-after-write directive.
- [Subagents feature breakdown](../reports/2026-09-19-claude-code-subagents-feature-breakdown.md) section 3: subagent context contents.

## Proposed Solution

### 1. Reference convention

A rule reference is a double-quoted heading path:

- Whole rule: `"CDocs Overseer Rules"`.
- Section: `"CDocs Overseer Rules › Chat record"`: the rule's H1, ` › ` (U+203A with single spaces), then any heading in that rule.
  The section is named by its own text, not its full path, so `"CDocs Frontmatter Specification › chat_record (optional, devlogs only)"` works without naming "Field Definitions".

Comparison ignores backticks and `*` and collapses whitespace; it is otherwise exact, so a typo fails.
Any double-quoted string in scanned content that begins `CDocs ` is treated as a rule reference.
Skills are named by command (`/cdocs:propose`), never by quoted H1, so the prefix does not collide in practice.

Applied to the three kinds:

- **Rules and templates:** `frontmatter-spec.md:85` reads `How it is filled is in "CDocs Overseer Rules › Chat record".`; the devlog template comment reads `see "CDocs Overseer Rules › Chat record"`.
- **Skills:** each relative link becomes the quoted heading reference with no link, for example `per "CDocs Overseer Rules › Stay thin"` and `see "CDocs Workflow Patterns › Model Tiering"`.
- **Agents:** each Startup block becomes a short Rules section:

  ```markdown
  ## Rules

  The cdocs rules are already in your context: follow "CDocs Writing Conventions" and "CDocs Frontmatter Specification".
  If no CDocs rules are in your context, the project has not run `/cdocs:init`: say so in your final message and proceed.
  ```

  Each agent names the rules it leans on (reviewer, proposer, implementer, judge: those two; triage: the frontmatter specification).
  Workflow steps that say "Read the rule files listed above" are removed.
  `nit-fix` takes its convention set from every `##` section of the CDocs rules in its context, and stops with a report instead of proceeding when none are present, since it has nothing to enforce.

### 2. The check

`scripts/check-rule-refs.ts` exports pure functions; `scripts/check-rule-refs.test.ts` runs them under `node:test`; `package.json` gains `"test:rules": "tsx --test scripts/check-rule-refs.test.ts"`.

```ts
// Sketch of the module surface, not the implementation.
export interface RuleDoc { file: string; title: string; headings: string[] }      // fenced code skipped
export function parseRules(texts: Map<string, string>): RuleDoc[];                  // by H1 and headings
export function materialize(pluginRoot: string): Map<string, Map<string, string>>;  // target -> path -> text
export function findReferences(path: string, text: string): Ref[];                  // quoted "CDocs ..." strings
export function findFilenameRefs(path: string, text: string, ruleFiles: string[]): Hit[];
export function resolve(ref: Ref, rules: RuleDoc[]): string | null;                 // null, or an error message
```

`materialize` mirrors init: target `claude` is the per-file `.claude/rules/cdocs/<name>.md` set, frontmatter stripped, with markers; target `agents-md` is the step 6 block, built from init's `[Full content of X.md, frontmatter stripped]` list.
Headings are parsed from these generated texts, not from the source files.

The test file asserts:

1. **Rule invariants:** each rule has exactly one H1 outside code fences, H1s are unique and begin `CDocs `, and heading texts are unique within a rule (so the short section form is unambiguous).
2. **Init list:** init's step 6 list names exactly the files in `rules/` (this replaces the bash guard in `chat-record.test.sh`).
3. **Resolution:** every reference in scanned content resolves in every target's generated text.
4. **No filename references:** scanned content contains no `<rule-file>.md` for any file in `rules/`, no `rules/<name>.md` path for any name or glob (catches deleted rules and `rules/*.md`), and no `plugins/cdocs/rules` path.
   `${CLAUDE_PLUGIN_ROOT}/rules/...` is allowed, since Claude Code substitutes it in skill and agent bodies.
5. **No `omitClaudeMd`:** no cdocs agent sets it, since the agents rely on rules arriving with the CLAUDE.md hierarchy.
6. **Extractor self-tests** on inline fixtures: a typo'd title fails, a heading inside a code fence is not indexed, a backticked heading resolves, `>` in place of `›` fails with a hint, curly quotes are recognized.

Scanned content is `plugins/cdocs/{rules,skills,agents}/**/*.md`, minus `skills/init/SKILL.md`, which is the materializer and must name source files.

Failures print `file:line`, the offending text, and a fix: for a filename hit, the mapped title (`overseers.md` → `"CDocs Overseer Rules"`); for an unresolved section, the rule's headings.

A CLI mode, `tsx scripts/check-rule-refs.ts --materialized <project>`, runs assertion 3 against a real project's `.claude/rules/cdocs/*.md` and `AGENTS.md` block instead of the simulation.
The `init_real` headless extra in `chat-record.test.sh` calls it after running the real `/cdocs:init`, which closes the gap between init's prose and the simulation.

CI: `.github/workflows/cdocs-hooks.yml` gains a `rules` job (ubuntu, `actions/setup-node` 22, `npm ci`, `npm run test:rules`), and its `paths` filters widen to `plugins/cdocs/**`, `scripts/check-rule-refs*.ts`, `scripts/inject-rules.test.ts`, `package.json`, and `package-lock.json`.
The widening also fixes a latent gap: the existing bash suites already depend on `rules/` and `skills/init/` but did not trigger on them.

### 3. Per-file delivery

`/cdocs:init` step 3 becomes the same routine as step 5, targeting `.claude/rules/cdocs/`:

- Copy each `${CLAUDE_PLUGIN_ROOT}/rules/<name>.md` to `.claude/rules/cdocs/<name>.md`, frontmatter stripped, with the existing marker line first.
- Delete any file in `.claude/rules/cdocs/` with no source rule.
- Migrate: delete a legacy `.claude/rules/cdocs.md`, and remove an exact `@.claude/rules/cdocs.md` line from `CLAUDE.md`.
- Add nothing to `CLAUDE.md`.

`inject-rules.ts` reads markers from `.claude/rules/cdocs/*.md` when that directory exists, else from the legacy `.claude/rules/cdocs.md`, else exits silently.
Every marker must equal the plugin hash; otherwise it emits the existing directive, reworded to name the directory.
The hash computation, marker shape, regex, and source-repo skip are unchanged.
A legacy project is not nagged for its layout: it keeps working (the legacy file is auto-loaded) until the next rule change, when the nudge's `/cdocs:init` run migrates it.
The rule edits in this proposal are such a change.

The Read-after-write directive names the rewritten files under `.claude/rules/cdocs/`.
`AGENTS.md` (step 6) and OpenCode delivery (step 5, `postinstall.js`, `build-opencode.ts`) are unchanged.

### 4. Documentation

- `plugins/cdocs/README.md`: "Rules Integration" describes per-file auto-loading (no `@`-import); "Agent path resolution" becomes "Agents and rules" (rules arrive with the CLAUDE.md hierarchy; no reads); a new "Referencing rules" subsection states the convention and `npm run test:rules`; "When CC #14200 Lands" records the issue's state and replaces "`/memory` visibility" with `/context`.
- Root `CLAUDE.md` "Rules Delivery": items 1 and 3 updated to match.
- `init/SKILL.md`: step 3 as above, and the Read-after-write directive text.
- The hook testing RFP gains a NOTE pointing at this proposal (see below).

### Relation to the hook testing RFP

The reference check subsumes none of the [RFP](2026-09-01-rules-hook-testing-methodology-v2.md)'s scope; phase 3 subsumes two of its six bullets.

- **Subsumed by phase 3:** hook unit tests and the directive size bullet.
  Phase 3 changes the hook's marker source, so it adds `scripts/inject-rules.test.ts`, which runs the hook against fixture projects for every branch and asserts the directive stays under 500 bytes.
  Once a fixture harness exists, covering every branch costs a few cases more than covering the changed one.
- **Overlapping:** the init-list sync guard moves from bash into `check-rule-refs.test.ts`; `--materialized` is the natural home for the "marker generation" bullet (each materialized marker equals an independently computed hash).
- **Left to the RFP:** the round trip across sessions and the Read-after-write directive's in-session effect.
- It answers the RFP's open question on test location: `scripts/*.test.ts` under `tsx --test`.

The RFP's objective text should name `.claude/rules/cdocs/*.md` as the marker source.

## Important Design Decisions

### Heading references, not filenames, regardless of delivery

Filenames only resolve where rules are delivered as files: Claude Code per-file, OpenCode, this repo.
The H1 is present in all forms, including the `AGENTS.md` inline block that Codex, Cursor, and others read.
Heading references also read naturally to a model, which locates in-context text by its heading, not by path.

### Mechanical check over review discipline

Section names drift when rules are edited, and filename references look correct in this repo.
Only a check run on every change catches both; a reviewer guideline would not.
The check flags and explains; it bans nothing beyond unresolvable references.

### Resolve against generated text, not source filenames

The maintainer asked for verification against the materialized output.
In CI the generated text is a simulation of init's prose; resolving against source headings would give the same answer today, because materialization keeps rule bodies verbatim.
The simulation earns its place in two ways: an `AGENTS.md` list that omits a rule shows up as unresolved references, and the same resolver runs on real init output through `--materialized`.

### Agents rely on context, with no fallback read

Every non-fork subagent receives project rules (documented and probed).
`${CLAUDE_PLUGIN_ROOT}/rules/<name>.md` would resolve in agent bodies and could serve projects that never ran `/cdocs:init`, but such projects intentionally have no cdocs rules, and the loop skills keep their inline floors.
A fallback read would also re-add the in-repo duplicate read, so it is left out.

### Per-file delivery over concatenation

| | Concatenated `cdocs.md` | Per-file `cdocs/<name>.md` |
|---|---|---|
| Launch, subagents, post-compaction | Yes (auto-load; import redundant) | Yes (auto-load) |
| Relies on undocumented import dedup | Yes, while init adds the import | No |
| init edits `CLAUDE.md` | Yes | No (removes the legacy line once) |
| Claude Code and OpenCode init steps | Two shapes | One routine, two targets |
| Ordering coupled to the `AGENTS.md` list | Yes | No |
| `/context` shows each rule | No | Yes |
| Filename references safe | No | Still no (`AGENTS.md`) |
| Migration cost | None | One init run, a hook branch, fixture updates |
| Files in a consumer repo | 1 | One per rule |

Per-file wins on fewer couplings and less editing of consumer files, and it uses the documented mechanism instead of the import plus undocumented deduplication.
Its cost is one-time.
It does not reduce hooks: the freshness hook stays until [#14200](https://github.com/anthropics/claude-code/issues/14200), with or without this change.

Rejected: a symlink `.claude/rules/cdocs` into the plugin cache.
It would remove the freshness hook, but the cache path is per machine and per version, so it cannot be committed and dangles on upgrade; out-of-tree symlinks also need a one-time approval.

Rejected: keeping concatenation and only dropping the import.
It is smaller, but it keeps the ordering coupling and the two init shapes, and the delivery decision is the moment to remove them.

### Keep rules unscoped

Per-file delivery would allow keeping `frontmatter-spec.md`'s `paths: cdocs/**/*.md`.
It stays stripped: scoped rules do not survive compaction, and a scoped spec loads only after a Write has already created the file whose frontmatter it governs.

## Stories

- **A rule heading is renamed.** A contributor renames "Chat record" to "Chat records". `npm run test:rules` fails with each `file:line` that uses the old name and the rule's current headings.
- **A filename reference is authored in this repo.** A skill edit adds `` see `workflow-patterns.md` ``. It reads fine here, since `CLAUDE.md` imports the source rules. CI fails with `use "CDocs Workflow Patterns"`.
- **A consumer upgrades the plugin.** The rule edits change the hash; the SessionStart hook nudges; `/cdocs:init` writes `.claude/rules/cdocs/*.md`, deletes the legacy file and import line, and tells the agent to Read the new files.
- **A reviewer is dispatched downstream.** It starts with the rules in context and spends no tool calls on rule files.

## Edge Cases / Challenging Scenarios

- **Uninitialized or `--minimal` projects:** no rules in context, as today (the old fallback reads failed there too). Agents say so; `nit-fix` stops.
- **Explore, Plan, or `omitClaudeMd` agents:** they get no rules. cdocs dispatches its own agents or `general-purpose`, and assertion 5 keeps `omitClaudeMd` out of cdocs agents.
- **OpenCode subagents:** OpenCode reads `AGENTS.md`, which carries every rule with its H1, so heading references hold. Whether OpenCode subagents receive conditional `.opencode/rules/` content is unverified and unchanged by this proposal.
- **A reference split across lines:** the extractor works per line and misses it. Sentence-per-line makes this rare; a quoted heading path should stay on one line.
- **A quoted `CDocs ...` string that is not a rule reference:** the check fails it; rephrase or name the skill by command.
- **A partially migrated consumer** (both layouts present): the hook prefers the directory; init deletes the legacy file.
- **A consumer `CLAUDE.md` that `@`-imports `AGENTS.md`:** rules load twice (the block plus `.claude/rules/`). This exists today and is out of scope.
- **Two cdocs installs** (`--plugin-dir` beside the marketplace install): unchanged by this proposal.

> WARN(@claude-opus-5-5/cdocs/rules-references): The plugin README's claim that OpenCode "reads `.claude/rules/` natively" is unverified.
> If it holds recursively, OpenCode projects would load `.claude/rules/cdocs/*.md` beside `.opencode/rules/cdocs/*.md`; today's `cdocs.md` has the same exposure, so the change neither adds nor removes the risk.

## Test Plan

| Area | Test | Where |
|---|---|---|
| Rule invariants, init list, resolution, filename refs, `omitClaudeMd`, extractor | Assertions 1-6 | `scripts/check-rule-refs.test.ts`, CI |
| The check catches today's refs | Run the check on the pre-change tree: expect every filename and path site in the Audit verification list, and no others; `triage/SKILL.md:69` is prose with no path and is fixed by hand | Phase 1, manual |
| Mutation | Rename a heading, add `overseers.md` to a skill, misspell a title, use `>`: each fails with a fix hint | Phase 1, manual |
| Hook | Fixture projects: dir markers match (silent); one mismatched (directive names the dir); legacy file only (old behavior); neither (silent); source repo (silent); no `CLAUDE_PLUGIN_ROOT` or unreadable manifest (silent); malformed marker (directive, `unknown`); directive under 500 bytes | `scripts/inject-rules.test.ts` (phase 3), CI via `test:rules` |
| Real init | `init_real`: `.claude/rules/cdocs/*.md` written, no `cdocs.md`, no import line, `--materialized` passes, legacy file and import removed when seeded | `chat-record.test.sh --only init_real` (headless, credentials) |
| Post-compaction | `rules_check` under the per-file fixture | `chat-record.test.sh --only rules_check` |
| Existing suites | `chat-record.test.sh --unit`, `npm run test:opencode` | CI |

## Verification Methodology

1. `npm run test:rules` green, and red on deliberate mutations (Test Plan rows 2-3); record the pre-change hit list in the devlog.
2. In a scratch git project with a legacy layout (`.claude/rules/cdocs.md` plus the import line), run the real `/cdocs:init` headless; then `claude -p /context < /dev/null` must list each `.claude/rules/cdocs/<name>.md` once and no `cdocs.md`.
3. In an initialized scratch project (the step 2 project once phase 3 lands), dispatch a `cdocs:reviewer` and a `cdocs:nit-fix` on a fixture devlog containing an em-dash.
   The transcripts must show no Read or Glob of a rule path, and `nit-fix` must fix the em-dash, which proves it took conventions from context.
4. Headless sentinel probe: a subagent dispatched in that project lists a phrase unique to one rule file.
5. `chat-record.test.sh --only rules_check` and `--only init_real` pass.

## Implementation Phases

Phases 1 and 2 are the core and land together; phase 3 is independent and can be deferred without affecting them.

### Phase 1: The check

- Add `scripts/check-rule-refs.ts`, `scripts/check-rule-refs.test.ts`, and the `test:rules` npm script, with `materialize` producing the per-file layout of section 3.
  If phase 3 is deferred, `materialize` models the concatenated file instead; resolution is unaffected.
- Run it on the current tree; confirm it reports exactly the audited sites (Test Plan row 2) and fails on mutations.
- Do not wire CI yet: the tree is red until phase 2.
- Success: the hit list matches the audit; the extractor self-tests pass.

### Phase 2: Convert references and agents

- Rewrite the rule, template, skill, and agent sites in the Summary table to the section 1 convention, including `nit_fix/SKILL.md:48` and `triage/SKILL.md:69`.
- Replace the six agent Startup blocks; remove "Read the rule files" workflow steps and renumber.
- Remove `init_rule_order`'s sync assertion from `chat-record.test.sh --unit` (assertion 2 owns it); keep the helper while `init_rules` uses it.
- Add the `rules` CI job and widen the workflow `paths`.
- README "Agent path resolution" → "Agents and rules"; add "Referencing rules"; root `CLAUDE.md` Rules Delivery item 3.
- Success: `npm run test:rules` and the existing suites pass; Verification step 3.

### Phase 3: Per-file delivery

- `init/SKILL.md` step 3 and the Read-after-write directive per section 3.
- `inject-rules.ts`: directory markers, legacy fallback, reworded directive.
- `scripts/inject-rules.test.ts` covering every hook branch (Test Plan "Hook" row), appended to the `test:rules` script.
- `chat-record.test.sh`: `init_rules` writes the per-file layout (dropping `init_rule_order`), `init_real` asserts the new layout and calls `--materialized`.
- README "Rules Integration" and "When CC #14200 Lands"; root `CLAUDE.md` Rules Delivery item 1; the hook testing RFP NOTE.
- Success: Verification steps 2, 4, and 5.

### Constraints

- Do not change `scripts/build-opencode.ts`, `plugins/cdocs/scripts/postinstall.js`, init step 5, or the shape of the step 6 `AGENTS.md` block.
  OpenCode keeps its per-file `.opencode/rules/cdocs/` delivery, which needs nothing from this proposal.
- Do not change the hash computation, the marker shape, or the hook's source-repo skip.
- Do not edit `overseers.md` "Stay thin".
- `plugins/cdocs/README.md`, `bin/README.md`, and `plugins/cdocs/AGENTS.md` may keep filename references: they describe the source tree.

## Open Questions

- Should the check also scan skill shell scripts (for example `ablate.sh`) for rule references in emitted text? None exist today; adding `.sh` costs one glob entry.
- Should `--materialized` assert marker hashes now (the RFP's marker-generation bullet), or leave that to the RFP's proposal?
- `ablate/SKILL.md:79` sets `ABLATE=plugins/cdocs/skills/ablate/ablate.sh`, a source-repo path that is dead downstream (`${CLAUDE_SKILL_DIR}` would resolve).
  It is a skill-path issue, not a rule reference, so it is outside this check; does it warrant its own fix?
