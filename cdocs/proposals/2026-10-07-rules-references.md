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
  at: 2026-10-07T22:03:47-07:00
  round: 3
tags: [rules, rules_delivery, init, testing, architecture]
---

# Rules References

> BLUF: Shipped cdocs content refers to rules by heading, never by filename: `"CDocs Overseer Rules › Chat record"`, which resolves wherever the rules are delivered.
> A `node:test` check (`npm run test:rules`, blocking in CI) resolves every such reference against the rule headings and rejects rule-filename references; `--materialized` runs it on real `/cdocs:init` output.
> Agents drop their rule-file reads, since the rules already reach every subagent's context.
> `/cdocs:init` keeps `.claude/rules/cdocs.md`, which Claude Code auto-loads, and stops adding a `CLAUDE.md` `@`-import, once a post-compaction canary probe shows unscoped rules are re-injected.

## Summary

Downstream, `/cdocs:init` concatenates the rule files into `.claude/rules/cdocs.md` and inlines them into `AGENTS.md`, so a rule's filename names nothing a consuming session can see.
Three reference kinds are affected:

| Kind | Sites | Downstream effect | Convention |
|---|---|---|---|
| Rule and template text | `frontmatter-spec.md:85`, `skills/devlog/template.md:10` | Dead name; the template copies it into every devlog | Heading reference |
| Agent Startup reads | `reviewer`, `proposer`, `implementer`, `judge`, `triage`, `nit-fix`; plus `judge.md:74`, `implement/SKILL.md:53`, `nit_fix/SKILL.md:48`, `triage/SKILL.md:69` | Failed Reads on every dispatch; redundant reads in this repo | "The rules are already in your context" plus heading references |
| Skill relative links (`../../rules/x.md`) | 10 links in 8 skills | Resolve in the Claude Code plugin cache, dead in the OpenCode layout, redundant everywhere | Heading reference, no link |

The check is the requested double check: CI resolves references against the source rule headings, and `--materialized` resolves them against what a real `/cdocs:init` run wrote.

Delivery stays one concatenated file.
Claude Code auto-loads every unscoped `.md` under `.claude/rules/`, gives it to subagents, and re-injects it after compaction, so the `CLAUDE.md` `@`-import is redundant.
Init stops writing the import and removes an existing one.
The hook and the marker are unchanged.

> NOTE(@claude-opus-5-5/cdocs/rules-references): There is no plugin-native rules field.
> [#14200](https://github.com/anthropics/claude-code/issues/14200) is open with no maintainer response as of Claude Code v2.1.293, and the plugins reference states a plugin-root `CLAUDE.md` is not loaded.

## Objective

1. Every rule reference in shipped content (rules, skills, skill templates, agents) resolves in every delivery form.
2. A mechanical check proves (1) on every change, using the existing `tsx` and `node:test` setup.
3. Agents stop spending tool calls on rule-file paths that do not exist downstream.
4. Rule delivery uses only the Claude Code mechanism it needs.

Out of scope: the "advisor subagent" wording in `overseers.md` "Stay thin"; target-specific guidance ([RFP](2026-10-06-target-specific-guidance-rfp.md)); references between skills (for example the devlog skill's "Handoffs"), which resolve inside the plugin; the hook and its tests ([hook testing RFP](2026-09-01-rules-hook-testing-methodology-v2.md)).

## Background

### Delivery

- `/cdocs:init` ([SKILL.md](../../plugins/cdocs/skills/init/SKILL.md)) step 3 concatenates every `${CLAUDE_PLUGIN_ROOT}/rules/*.md`, frontmatter stripped, into `.claude/rules/cdocs.md` behind a `<!-- cdocs rules vX.Y.Z hash=<sha256> ... -->` marker, ordered by its step 6 list, and adds `@.claude/rules/cdocs.md` to `CLAUDE.md`.
  Step 5 copies each rule to `.opencode/rules/cdocs/<name>.md` when OpenCode is detected; step 6 inlines all rules into an `AGENTS.md` block, each under a `## CDocs ...` heading.
- [`inject-rules.ts`](../../plugins/cdocs/hooks/inject-rules.ts) (SessionStart) hashes the plugin's alphabetically sorted rule bodies and nudges a re-run of `/cdocs:init` when the marker in `.claude/rules/cdocs.md` differs.
- In this source repo, `CLAUDE.md` `@`-imports `plugins/cdocs/rules/*.md` directly, so filename references appear to work while authoring.
  That is why they keep being written.
- Every rule file has a unique H1 beginning `CDocs ` (`CDocs Overseer Rules`, `CDocs Frontmatter Specification`, ...).
  The H1 survives every delivery form: concatenation and per-file copies keep the body; the `AGENTS.md` block keeps the body under its own wrapper heading.
- [`chat-record.test.sh`](../../plugins/cdocs/hooks/tests/chat-record.test.sh) `--unit` asserts that init's step 6 list names exactly the files in `rules/`.
  Its `init_rules` helper writes the same layout for the headless `rules_check` and `multi_turn` scenarios, and `init_real` runs the real `/cdocs:init`.

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

> NOTE(@claude-opus-5-5/cdocs/rules-references): Headless probes on v2.1.293 in a scratch git project confirmed rows one and four: `.claude/rules/top.md` and `.claude/rules/cdocs/nested.md` loaded with no import, a `paths:`-scoped sibling did not, and a dispatched `general-purpose` subagent saw both loaded sentinels.
> With `CLAUDE.md` also `@`-importing `.claude/rules/top.md`, `claude -p /context` listed the file once; the docs promise that deduplication only for `AGENTS.md`.
> Row three (post-compaction re-injection of unscoped rules) is documented but not probed; phase 3 is gated on a canary probe of it.

### Related documents

- [Rules hook testing methodology v2 (RFP)](2026-09-01-rules-hook-testing-methodology-v2.md): hook branch tests, marker generation, round trip, directive size. This proposal leaves all of it there.
- [Rule delivery materialization](2026-05-12-cdocs-rule-delivery-materialization.md): the accepted design of the marker, hook, and Read-after-write directive.
- [Subagents feature breakdown](../reports/2026-09-19-claude-code-subagents-feature-breakdown.md) section 3: subagent context contents.

## Proposed Solution

### 1. Reference convention

A rule reference is a double-quoted heading path:

- Whole rule: `"CDocs Overseer Rules"`.
- Section: `"CDocs Overseer Rules › Chat record"`: the rule's H1, a separator, then any heading in that rule.
  The separator is ` › ` (U+203A) or ` > `; both are accepted.
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

  Reviewer, proposer, implementer, and judge name those two rules; triage names the frontmatter specification.
  Workflow steps that say "Read the rule files listed above" are removed.
  `nit-fix` enforces the `##` sections of the same two rules from its context, and stops with a report when they are absent, since it has nothing to enforce.
  Its rewrite covers the Startup block, `nit-fix.md:26` ("Adding a new rule file to `rules/` extends your enforcement surface"), `:37` ("across all rule files"), and the report line `:82` (`Rule files loaded: F` becomes `Rules used: <titles>`).

### 2. The check

`scripts/check-rule-refs.ts` exports pure functions; `scripts/check-rule-refs.test.ts` runs them under `node:test`; `package.json` gains `"test:rules": "tsx --test scripts/check-rule-refs.test.ts"`.

```ts
// Sketch of the module surface, not the implementation.
export interface RuleDoc { title: string; headings: string[] }                      // fenced code skipped
export function parseRules(text: string): RuleDoc[];                                 // split at `# CDocs ` H1s
export function findReferences(path: string, text: string): Ref[];                   // quoted "CDocs ..." strings
export function findFilenameRefs(path: string, text: string, ruleFiles: string[]): Hit[];
export function resolve(ref: Ref, rules: RuleDoc[]): string | null;                  // null, or an error message
```

`parseRules` splits any text at `# CDocs ` H1 lines and ignores `## CDocs ` wrapper lines, so the same function reads a source rule file, the concatenated `.claude/rules/cdocs.md`, and the `AGENTS.md` block.

The test file asserts, over the source rules in `plugins/cdocs/rules/`:

1. **Rule invariants:** each rule has exactly one H1 outside code fences, H1s are unique and begin `CDocs `, and heading texts are unique within a rule (so the short section form is unambiguous).
2. **Resolution:** every reference in scanned content resolves against the source rule headings.
   Materialization keeps rule bodies verbatim, and the existing `chat-record.test.sh --unit` guard keeps init's rule list equal to `rules/`, so source headings are the materialized headings.
3. **No filename references:** scanned content contains no `<rule-file>.md` for any file in `rules/`, no `rules/<name>.md` path for any name or glob (catches deleted rules and `rules/*.md`), and no `plugins/cdocs/rules` path.
   These are rejected outright: they never resolve in a consuming project.
4. **No `omitClaudeMd`:** no cdocs agent sets it, since the agents rely on rules arriving with the CLAUDE.md hierarchy.
5. **Extractor fixtures:** a misspelled title fails; a heading inside a code fence is not indexed; curly quotes and the ` > ` separator are recognized.

Scanned content is `plugins/cdocs/{rules,skills,agents}/**/*.md`, minus `skills/init/SKILL.md`, which is the materializer and must name source files.
Failures print `file:line`, the offending text, and a fix: for a filename hit, the mapped title (`overseers.md` → `"CDocs Overseer Rules"`); for an unresolved section, the rule's headings.

`tsx scripts/check-rule-refs.ts --materialized <project>` runs assertion 2 against a real project's `.claude/rules/cdocs.md` and its `AGENTS.md` block.
The `init_real` headless scenario calls it after running the real `/cdocs:init`: that is the check of what consumers actually receive.

CI: `.github/workflows/cdocs-hooks.yml` gains a `rules` job (ubuntu, `actions/setup-node` 22, `npm ci`, `npm run test:rules`), and its `paths` filters widen to `plugins/cdocs/**`, `scripts/check-rule-refs*.ts`, `package.json`, and `package-lock.json`.
The workflow's header comment, which lists the suites it runs, gains the `rules` job.
The widening also makes the existing bash suites run when `rules/` or `skills/init/` change, which they read but did not trigger on.
The job does not go in `opencode-build.yml`: that workflow is `continue-on-error` so OpenCode never gates Claude Code, which would make this check either non-blocking or an OpenCode gate on Claude Code changes.

### 3. Delivery: keep the file, drop the import

`/cdocs:init` step 3 changes in two places:

- Do not add `@.claude/rules/cdocs.md` to `CLAUDE.md`: Claude Code auto-loads the file.
- If `CLAUDE.md` contains that exact line, remove it.

The Read-after-write directive drops "@-imported" ("The version loaded at session start is stale").
The concatenation order, hook, marker, hash, step 5, and step 6 are unchanged.

A project that already has the import keeps it until its next `/cdocs:init`, and the file loads once meanwhile (the probe above).
The rule edits in this proposal change the hash, so every initialized project is nudged to run `/cdocs:init` once, which removes the line.
That holds only if phase 3 ships in the same plugin release as phase 2's rule edits: phase 3 changes no rule body, so released alone it triggers no nudge.
Ship phases 2 and 3 together when the gate passes; otherwise consumers keep a harmless import line until the next rule edit.

Removing the import moves the post-compaction guarantee from "project-root CLAUDE.md and its imports" to "unscoped rules", which the docs state but no probe has shown.
So phase 3 starts with a one-off canary probe, run through the existing `drive` helper on haiku and recorded in the devlog:

1. A fixture project from `init_rules` with no import line, whose `.claude/rules/cdocs.md` gains one line: "The cdocs canary word is `<random word>`."
2. Three turns: a trivial task that never mentions the canary; `/compact`; "Without tools, what is the cdocs canary word? Say UNKNOWN if it is not in your context."
3. Pass if the reply contains the word. The compaction summary cannot carry a word the conversation never used, so a pass shows the rule file was re-injected.

If it fails, init keeps writing the import and phase 3 ends there.
An optional control run with the import line rules out a broken probe.
`rules_check` is not the gate: it measures resumption behavior, not rule presence, and it fails on the current baseline.
It runs only as a no-regression comparison: its results without the import match its results with it.

> NOTE(@claude-opus-5-5/cdocs/rules-references): The hook's directive text says "The current session's @-imported rules are stale until you do".
> Without the import the wording is inexact, but the instruction (run `/cdocs:init`, then Read) is unchanged, so the hook is left alone.

### 4. Documentation

- `plugins/cdocs/README.md`: "Rules Integration" says `.claude/rules/cdocs.md` is auto-loaded with no `@`-import; "Agent path resolution" becomes "Agents and rules" (rules arrive with the CLAUDE.md hierarchy; agents read no rule files); a new "Referencing rules" subsection states the convention and `npm run test:rules`.
- Root `CLAUDE.md` "Rules Delivery": item 1 drops "loaded by a CLAUDE.md `@`-import"; item 3 (agent fallback) is replaced by "agents read rules from context".
- `init/SKILL.md`: step 3 and the Read-after-write directive as above.
- [Subagents feature breakdown](../reports/2026-09-19-claude-code-subagents-feature-breakdown.md) section 13 gains a NOTE: cdocs agents read rules from context, not relative `rules/*.md`.
- `scripts/build-opencode.ts:199`: a one-line comment that the `rules` branch of the rewrite matches nothing in shipped agents and is kept for safety (comment only).

## Important Design Decisions

### Heading references, not filenames

Filenames only resolve where rules are delivered as files: OpenCode and this repo.
The H1 is present in every form, including the concatenated Claude Code file and the `AGENTS.md` block that Codex, Cursor, and others read.
Heading references also read naturally to a model, which locates in-context text by its heading, not by path.

### Mechanical check over review discipline

Section names drift when rules are edited, and filename references look correct in this repo.
Only a check run on every change catches both; a reviewer guideline would not.
It rejects only what cannot resolve downstream: unresolved headings and filename references.

### Source headings in CI, real output in `init_real`

Materialization copies rule bodies verbatim, so the source headings are the materialized headings.
Re-implementing init's prose in TypeScript would add a second copy of init that can drift from the skill, to check something the source already answers.
The real-output check runs where real output exists: `--materialized` after `init_real`.

### Separator: ` › ` or ` > `

Authors and models type `>` more readily; accepting both keeps the check about resolution, not typography.

### Agents rely on context, with no fallback read

Every non-fork subagent receives project rules (documented and probed).
`${CLAUDE_PLUGIN_ROOT}/rules/<name>.md` would resolve in agent bodies and could serve projects that never ran `/cdocs:init`, but such projects intentionally have no cdocs rules, and the loop skills keep their inline floors.
A fallback read would also re-add the in-repo duplicate read.

### Keep the concatenated file; drop the import

| | `cdocs.md` plus import | `cdocs.md`, no import (chosen) | Per-file `cdocs/<name>.md` |
|---|---|---|---|
| Launch, subagents | Yes | Yes (auto-load) | Yes (auto-load) |
| Post-compaction | Via root CLAUDE.md | Via unscoped rules (gated probe) | Via unscoped rules |
| Relies on undocumented import dedup | Yes | No | No |
| init edits `CLAUDE.md` | Adds a line | Removes a legacy line once | Removes a legacy line once |
| Hook change | None | None | Marker source, legacy branch |
| `/context` lists each rule | No | No | Yes |
| Filename references safe | No | No | No (`AGENTS.md` still inlines) |

Import deduplication and editing `CLAUDE.md` are costs of the import, not of concatenation.
Without it, per-file's remaining benefit is per-rule `/context` listing, which does not pay for a hook change and a permanent legacy branch.
Per-file stays a possible follow-up if that visibility comes to matter.

Rejected: a symlink `.claude/rules/cdocs` into the plugin cache.
It would remove the freshness hook, but the cache path is per machine and per version, so it cannot be committed and dangles on upgrade; out-of-tree symlinks also need a one-time approval.

### Keep rules unscoped

`frontmatter-spec.md`'s `paths: cdocs/**/*.md` stays stripped: scoped rules do not survive compaction, and a scoped spec loads only after a Write has already created the file whose frontmatter it governs.

## Stories

- **A rule heading is renamed.** A contributor renames "Chat record" to "Chat records". `npm run test:rules` fails with each `file:line` that uses the old name and the rule's current headings.
- **A filename reference is authored in this repo.** A skill edit adds `` see `workflow-patterns.md` ``. It reads fine here, since `CLAUDE.md` imports the source rules. CI fails with `use "CDocs Workflow Patterns"`.
- **A consumer upgrades the plugin.** The rule edits change the hash; the SessionStart hook nudges; `/cdocs:init` rewrites `.claude/rules/cdocs.md` and removes the import line.
- **A reviewer is dispatched downstream.** It starts with the rules in context and spends no tool calls on rule files.

## Edge Cases / Challenging Scenarios

- **Uninitialized or `--minimal` projects:** no rules in context, and no rule-file read could find any either. Agents say so; `nit-fix` stops.
- **Explore, Plan, or `omitClaudeMd` agents:** they get no rules. cdocs dispatches its own agents or `general-purpose`, and assertion 4 keeps `omitClaudeMd` out of cdocs agents.
- **OpenCode subagents:** OpenCode reads `AGENTS.md`, which carries every rule with its H1, so heading references hold. Whether OpenCode subagents receive conditional `.opencode/rules/` content is unverified and unchanged here.
- **A reference split across lines:** the extractor works per line and misses it. Sentence-per-line makes this rare; a quoted heading path stays on one line.
- **A quoted `CDocs ...` string that is not a rule reference:** the check fails it; rephrase or name the skill by command.
- **The import line edited by hand** (other text on the line, a different path): init removes only the exact line, and the file still loads once by auto-load.
- **A consumer `CLAUDE.md` that `@`-imports `AGENTS.md`:** rules load twice (the block plus `.claude/rules/`). This is independent of this proposal and out of scope.

> WARN(@claude-opus-5-5/cdocs/rules-references): The plugin README's claim that OpenCode "reads `.claude/rules/` natively" is unverified.
> If it holds, OpenCode projects load `.claude/rules/cdocs.md` beside `.opencode/rules/cdocs/*.md`; this proposal neither adds nor removes that exposure.

## Test Plan

| Area | Test | Where |
|---|---|---|
| Rule invariants, resolution, filename refs, `omitClaudeMd`, extractor | Assertions 1-5 | `scripts/check-rule-refs.test.ts`, CI |
| The check catches today's refs | Run on the pre-change tree: expect every filename and path site in Audit verification, and no others; `triage/SKILL.md:69` is prose with no path and is fixed by hand | Phase 1, manual |
| Mutation | Rename a heading, add `overseers.md` to a skill, misspell a title: each fails with a fix hint | Phase 1, manual |
| Post-compaction without the import (gate) | Canary probe (section 3) | One-off `drive` run, recorded in the devlog |
| No regression | `rules_check` results without the import match those with it | `chat-record.test.sh --only rules_check` (headless) |
| Real init | `init_real` seeds `CLAUDE.md` with the import line; its "CLAUDE.md imports the rules" assertion is inverted to assert the line is gone; it also asserts `--materialized` passes | `chat-record.test.sh --only init_real` (headless) |
| Existing suites | `chat-record.test.sh --unit`, `npm run test:opencode` | CI |

## Verification Methodology

1. `npm run test:rules` green, and red on the mutations above; record the pre-change hit list in the devlog.
2. The phase 3 gate: the canary probe reports the word after `/compact` with no import line; `rules_check` matches its with-import results.
3. In a scratch git project initialized by the changed `/cdocs:init`, `claude -p /context < /dev/null` lists `.claude/rules/cdocs.md` once and `CLAUDE.md` has no import line.
4. In that project, add a sentinel convention under the "CDocs Writing Conventions" part of `.claude/rules/cdocs.md` (for example "Replace the word *utilize* with *use*"), then dispatch `cdocs:nit-fix` on a fixture devlog using *utilize* and `cdocs:reviewer` on the same devlog.
   `nit-fix` must apply the sentinel fix and name the rule in its report, and neither transcript may Read or Glob a rule path.
   This is the proof that plugin agents get rules from `.claude/rules/` with no import, which the earlier probe showed only for `general-purpose`.
5. `chat-record.test.sh --only init_real` passes.

## Implementation Phases

Phases 1 and 2 are the core and land together.
Phase 3 can be deferred without affecting them, but should ship in the same plugin release as phase 2 so the rule-hash nudge removes legacy import lines (section 3).

### Phase 1: The check

- Add `scripts/check-rule-refs.ts`, `scripts/check-rule-refs.test.ts`, and the `test:rules` npm script.
- Run it on the current tree; confirm it reports exactly the audited sites and fails on the mutations.
- Do not wire CI yet: the tree is red until phase 2.
- Success: the hit list matches the audit; the extractor fixtures pass.

### Phase 2: Convert references and agents

- Rewrite the rule, template, skill, and agent sites in the Summary table to the section 1 convention, including `nit_fix/SKILL.md:48` and `triage/SKILL.md:69`.
- Replace the six agent Startup blocks; rewrite `nit-fix.md:26,37,82`; remove "Read the rule files" workflow steps and renumber.
- Add the `rules` CI job and widen the workflow `paths`.
- Documentation items of section 4 except the delivery ones: README "Agents and rules" and "Referencing rules", root `CLAUDE.md` item 3, the report NOTE, the `build-opencode.ts` comment.
- Success: `npm run test:rules` and the existing suites pass; Verification step 4 (with the import still present).

### Phase 3: Drop the import

1. Gate: run the canary probe (section 3) and record it in the devlog. If it fails, stop.
2. Change `init_rules` (`chat-record.test.sh:804`) to write no import line, and run `rules_check` as the no-regression comparison.
3. `init/SKILL.md` step 3 (no import, remove the legacy line) and the Read-after-write directive.
4. `init_real` (`chat-record.test.sh:~821`): seed the import line, invert "CLAUDE.md imports the rules" to assert the line is gone, and call `--materialized`.
5. README "Rules Integration" and root `CLAUDE.md` item 1.
- Success: Verification steps 2, 3, and 5.

### Constraints

- Do not change `inject-rules.ts`, the hash computation, or the marker shape.
- Do not change `postinstall.js`, init step 5, or the shape of the step 6 `AGENTS.md` block; `build-opencode.ts` gets only the comment above.
- Do not edit `overseers.md` "Stay thin".
- `plugins/cdocs/README.md`, `bin/README.md`, and `plugins/cdocs/AGENTS.md` may keep filename references: they describe the source tree.

## Open Questions

- Should the check also scan skill shell scripts (for example `ablate.sh`) for rule references in emitted text? None exist today; adding `.sh` costs one glob entry.
- `ablate/SKILL.md:79` sets `ABLATE=plugins/cdocs/skills/ablate/ablate.sh`, a source-repo path that is dead downstream (`${CLAUDE_SKILL_DIR}` would resolve).
  It is a skill-path issue, not a rule reference, so it is outside this check; does it warrant its own fix?
