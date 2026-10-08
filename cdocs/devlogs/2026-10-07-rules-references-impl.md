---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T22:09:57-07:00
task_list: cdocs/rules-references
type: devlog
state: live
status: wip
part_of: cdocs/devlogs/2026-10-07-rules-references.md
tags: [rules, rules_delivery, init, testing]
---

# Rules References Implementation: Devlog

> BLUF: Iterate round 1 implementation of phases 1-3 of the rules-references proposal, in worktree `../rules-references` (branch `rules-references`).

## Objective

Implement [`cdocs/proposals/2026-10-07-rules-references.md`](../proposals/2026-10-07-rules-references.md) phases 1-3: the `test:rules` check, heading-reference conversion of rules/skills/agents, and dropping the `CLAUDE.md` `@`-import behind the canary gate.

## Scratchpoint

- next_steps: phase 2, convert references and agents.
- important_files: `scripts/check-rule-refs.ts`, `scripts/check-rule-refs.test.ts`, `plugins/cdocs/agents/*.md`, `plugins/cdocs/skills/init/SKILL.md`, `plugins/cdocs/hooks/tests/chat-record.test.sh`
- callouts:
  - decision: headless runs use scratch projects outside the worktree.

## Plan

1. Phase 1: `scripts/check-rule-refs.ts` + test + `test:rules`; run on the pre-change tree; mutations.
2. Phase 2: convert references and agents; CI job; docs.
3. Phase 3: canary gate; `rules_check` comparison; init step 3; `init_real`; delivery docs.

## Testing Approach

`node:test` for the check, run on the pre-change tree first (expected red with exactly the audited hits), then green after phase 2.
Headless `chat-record.test.sh` scenarios for the gate, `rules_check`, and `init_real`; manual headless dispatch for Verification step 4.

## Implementation Notes

### Phase 1: the check

`scripts/check-rule-refs.ts` (pure functions plus a CLI) and `scripts/check-rule-refs.test.ts` (`node:test`, assertions 1-5 as 11 tests); `npm run test:rules`.

> NOTE(@claude-opus-5-5/cdocs/rules-references): Two clarifications beyond the proposal's sketch.
> `Hit` carries `matches: string[]` and `files: string[]` (one hit per line, all offending substrings, every named rule's title in the fix) rather than one match.
> `rules/<name>.md` matches preceded by `.claude/` or `.opencode/` are not flagged: those are materialized paths that exist downstream (`.claude/rules/cdocs.md`), not source rule-file references.

**Pre-change hit list** (tree at `3fa8d3d`, `npx tsx scripts/check-rule-refs.ts`): 31 hits, all in assertion 3; assertions 1, 2, 4 and the fixtures pass.

| Kind | Hits |
|---|---|
| Rule and template text | `rules/frontmatter-spec.md:85`, `skills/devlog/template.md:10` |
| Agent Startup reads (16) | `implementer.md:23,24,27`, `judge.md:21,22,25`, `nit-fix.md:19,20`, `proposer.md:24,25,28`, `reviewer.md:21,22,25`, `triage.md:19,22` |
| Other agent/skill prose | `judge.md:74`, `implement/SKILL.md:53`, `nit_fix/SKILL.md:48` |
| Skill relative links (10) | `ablate/SKILL.md:20,290,291`, `devlog/SKILL.md:31`, `full-send/SKILL.md:13`, `implement/SKILL.md:19`, `iterate/SKILL.md:34`, `oversee/SKILL.md:12`, `propose-revise/SKILL.md:45`, `propose/SKILL.md:144` |

This is exactly the audited set (2 + 16 + 3 + 10 = 31) and no others.
`triage/SKILL.md:69` is path-free prose, not detected, as the proposal expects; fixed by hand in phase 2.
The mutation runs (renamed heading, added filename, misspelled title) need converted references to bite, so they run on the green phase 2 tree (see Verification).

### Phase 2: convert references and agents

- Agents: the six Startup blocks become a `## Rules` section (proposal section 1 wording); reviewer and judge lose "Read the rule files listed above" and renumber; judge's closing constraint names "CDocs Writing Conventions".
- `nit-fix`: Rules section per the proposal (enforce the `##` sections of the two rules, stop when absent), `:26` becomes "A new `##` section in those rules extends your enforcement surface", `:37` "across those rules", report line `Rules used: <titles>`.
- Rules, template, and skills: 13 sites to quoted heading references; `implement/SKILL.md:53` names "CDocs Workflow Patterns › Loops and multi-phase plans" (the section about dispatching phases).
- `nit_fix/SKILL.md:48` and `triage/SKILL.md:69`: the "reads rules at runtime" claims now say the agent has the rules in context.
- CI `rules` job and widened `paths`; README "Agents and rules" and "Referencing rules"; root `CLAUDE.md` item 3; report section 13 NOTE; `build-opencode.ts` comment.

> NOTE(@claude-opus-5-5/cdocs/rules-references): Deviation: `nit-fix.md` Processing step 3 gains "e. **Any other MECHANICAL convention** in your working set: apply its fix."
> Step 3 enumerated only four hardcoded mechanical conventions (sentence-per-line, callouts, punctuation, emoji), so a new mechanical rule section, such as Verification step 4's sentinel, had no instruction to be applied, contradicting "A new `##` section ... extends your enforcement surface".

## Changes Made

| File | Description |
|------|-------------|

## Verification

Scratch artifacts live under the session scratchpad `/tmp/claude-1000/-var-home-mjr-code-weft-clauthier-main/63ac45de-462d-4f43-ae1c-4ab6d59049b8/scratchpad/` (below: `$S`), outside the worktree; they are not durable.

### Step 1: `npm run test:rules` and mutations

Green on the phase 2 tree (`d93dc03`): `ℹ pass 11`, `ℹ fail 0`; `npx tsx scripts/check-rule-refs.ts` prints `rule references OK` with 27 references extracted.
Each mutation applied alone to the green tree, then reverted with `git checkout -- <file>`:

```
[rename]   overseers.md "## Chat record" -> "## Chat records": test:rules exit=1
plugins/cdocs/rules/frontmatter-spec.md:85: "CDocs Overseer Rules › Chat record": "CDocs Overseer Rules" has no heading "Chat record"; its headings are: "Stay thin", "Chat records"
  (same for skills/devlog/SKILL.md:31, skills/devlog/template.md:10)
[filename] status/SKILL.md += "See `workflow-patterns.md` for tiers.": test:rules exit=1
plugins/cdocs/skills/status/SKILL.md:80: `workflow-patterns.md` in: See `workflow-patterns.md` for tiers.
    fix: use "CDocs Workflow Patterns" for workflow-patterns.md
[misspell] iterate/SKILL.md "CDocs Workflow Patterns" -> "CDocs Workflow Pattern": test:rules exit=1
plugins/cdocs/skills/iterate/SKILL.md:34: "CDocs Workflow Pattern › Model Tiering": unknown rule "CDocs Workflow Pattern"; rules are: "CDocs Frontmatter Specification", ...
[deleted]  judge.md += "Read rules/deleted-rule.md first.": test:rules exit=1
plugins/cdocs/agents/judge.md:67: `rules/deleted-rule.md` in: Read rules/deleted-rule.md first.
    fix: name the rule by its H1, one of: ...
[final]    test:rules exit=0
```

Existing suites on the phase 2 tree: `npm run test:opencode` 8/8, `chat-record.test.sh --unit` 95/0, `validate-cdocs-edit-path.test.sh` 17/0, `graphify-scope.test.sh` 51/0.

### Step 4 with the import (phase 2 success criterion)

Driver: `$S/v/v4.sh` (sandboxed `CLAUDE_CONFIG_DIR` with copied credentials, `env -i`, `--plugin-dir` the worktree plugin, `--model haiku`, cwd a scratch git project).
Project `$S/v/proj-import`: `init_rules`-equivalent materialization (marker plus the five rule bodies in init order) and `CLAUDE.md` = `# Project` + `@.claude/rules/cdocs.md`.
The sentinel section is inserted at the end of the "CDocs Writing Conventions" part of `.claude/rules/cdocs.md`:

```
## Prefer Use Over Utilize

Replace the word *utilize* with *use* (any inflection: utilizes, utilized, utilizing).
This is a MECHANICAL convention.
```

> NOTE(@claude-opus-5-5/cdocs/rules-references): The sentinel's last line pre-classifies it, so the probe tests rule delivery, not nit-fix's mechanical/judgment classification.

Result (`$S/v/out-import/`): `nit-fix` replaced both *utilize* occurrences (fixture lines 18, 22) and reported `Rules used: CDocs Writing Conventions, CDocs Frontmatter Specification` and `[line 18] Prefer Use Over Utilize: replaced "utilize" with "use"`.
Subagent tool calls: nit-fix `Read` (the fixture), `Edit` x2; reviewer `Bash` (`cat` the fixture, `ls -R cdocs`, `git log --stat`, `cat` the plugin's `skills/review/template.md`), `Write` (review), `Read`, `Edit`, `Bash` (commit).
Neither subagent Read, Globbed, or catted a rule path; the only `rules/cdocs.md` strings in either stream are the haiku parent's dispatch prompt text.
Reviewer verdict: Revise (on the fixture's content; irrelevant to the probe).
