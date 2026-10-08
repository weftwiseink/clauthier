---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T22:09:57-07:00
task_list: cdocs/rules-references
type: devlog
state: live
status: done
part_of: cdocs/devlogs/2026-10-07-rules-references.md
tags: [rules, rules_delivery, init, testing]
---

# Rules References Implementation: Devlog

> BLUF: Iterate round 1 implementation of phases 1-3 of the rules-references proposal, in worktree `../rules-references` (branch `rules-references`).

## Objective

Implement [`cdocs/proposals/2026-10-07-rules-references.md`](../proposals/2026-10-07-rules-references.md) phases 1-3: the `test:rules` check, heading-reference conversion of rules/skills/agents, and dropping the `CLAUDE.md` `@`-import behind the canary gate.

## Scratchpoint

- next_steps: none; round 1 accepted (`cdocs/reviews/2026-10-07-review-of-rules-references-impl-r1.md`) and its non-blocking items applied; the overseer lands the branch. Release note: phases 2 and 3 must ship in one `plugin.json` bump and one push to `main` (proposal section 3).
- important_files: `scripts/check-rule-refs.ts`, `scripts/check-rule-refs.test.ts`, `plugins/cdocs/agents/*.md`, `plugins/cdocs/skills/init/SKILL.md`, `plugins/cdocs/hooks/tests/chat-record.test.sh`, `.github/workflows/cdocs-hooks.yml`
- callouts:
  - decision: headless runs use scratch projects under the session scratchpad with a sandboxed `CLAUDE_CONFIG_DIR`; no `cdocs/_chat/` files were written into the worktree.
  - decision: canary gate passed 2/2, so phase 3 shipped (import dropped).
  - todo: the CI `rules` job is unexercised until the branch is pushed; `npm ci` + `npm run test:rules` pass locally.
  - todo: the plugin version is not bumped here; the overseer owns the release.

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

> NOTE(@claude-opus-5-5/cdocs/rules-references): Step 3e was dropped after review r1 (see Review r1 follow-ups).
> Deviation, as first implemented: `nit-fix.md` Processing step 3 gains "e. **Any other MECHANICAL convention** in your working set: apply its fix."
> Step 3 enumerated only four hardcoded mechanical conventions (sentence-per-line, callouts, punctuation, emoji), so a new mechanical rule section, such as Verification step 4's sentinel, had no instruction to be applied, contradicting "A new `##` section ... extends your enforcement surface".

### Phase 3: drop the import

1. Gate: temporary `canary_check` extra (`ef32858`), run twice, then removed (`07f7e14`). Passed 2/2 (Verification step 2).
2. `rules_check` with the import (baseline), then `init_rules` writes `# Project` only (`7962291`), then without: identical per-assertion pass/fail.
3. `init/SKILL.md` step 3: no import; remove an exact legacy line. Read-after-write directive and its two explanatory paragraphs drop "@-imported" (`c2cf4ef`).
4. `init_real`: seeds the import line, asserts it is gone, runs `check-rule-refs.ts --materialized` (`8a6b781`).
5. README "Rules Integration" (plus two Known Limitations lines that said "@-imported") and root `CLAUDE.md` item 1.

> NOTE(@claude-opus-5-5/cdocs/rules-references): `init_real` invokes the check as `node --import tsx scripts/check-rule-refs.ts`, not the `tsx` CLI (`7a2b348`).
> The first `init_real` run failed that one assertion: the `tsx` CLI opens an IPC socket under `TMPDIR`, and the suite's scratch path under a long `TMPDIR` exceeded the unix socket path limit (`address: '.../h/tsx-1000/3304585.pipe'`).
> The check itself passed on that run's kept project; the re-run is green (step 5).

> NOTE(@claude-opus-5-5/cdocs/rules-references): Not done: the hook's directive text ("@-imported rules are stale") is left as the proposal directs; `inject-rules.ts`, the hash, the marker, `postinstall.js`, init step 5, and the step 6 block shape are unchanged.

### Review r1 follow-ups

Review: `cdocs/reviews/2026-10-07-review-of-rules-references-impl-r1.md` (accept). Non-blocking items, all applied:

| Item | Disposition | Commit |
|---|---|---|
| 1. Drop `nit-fix` step 3e | Removed; the reviewer showed the sentinel is applied without it (2/2), with the same edits | `45635a7` |
| 2. Narrow the `.claude/rules/` / `.opencode/rules/` exemption | Narrowed to the literal `.claude/rules/cdocs.md` (kept, not removed: it is a real downstream path an author may name). Fixture 5g asserts `.claude/rules/other.md` and `.opencode/rules/cdocs.md` are now flagged | `6e0b4b4` |
| 3. `test:rules` via `node --import tsx --test` | Changed; the README and the script's usage comment use `node --import tsx` too. Reproduced: `TMPDIR=$S/h npx tsx --test ...` exits 1 with `EINVAL`; the new script passes under the same `TMPDIR` | `6828720` |
| 4. `triage/SKILL.md:52` "reads the frontmatter spec at runtime" | Now "follows "CDocs Frontmatter Specification" from the rules already in its context" | `eac928a` |

Re-runs on `eac928a`: `npm run test:rules` (under the long `TMPDIR`) 11/0; `chat-record.test.sh --unit` 95/0; `--only init_real` 9/0, including `check-rule-refs --materialized passes` (`$S/fu-init_real.log`).

## Changes Made

| File | Description |
|------|-------------|
| `scripts/check-rule-refs.ts` | Checker module and CLI (`--materialized <project>`) |
| `scripts/check-rule-refs.test.ts` | `node:test` assertions 1-5 (11 tests) |
| `package.json` | `test:rules` script |
| `.github/workflows/cdocs-hooks.yml` | Blocking `rules` job; `paths` widened; header comment |
| `plugins/cdocs/agents/{reviewer,proposer,implementer,judge,triage,nit-fix}.md` | Startup blocks become Rules sections; rule-read steps removed; nit-fix report and step 3e |
| `plugins/cdocs/rules/frontmatter-spec.md` | `:85` heading reference (changes the rule hash) |
| `plugins/cdocs/skills/{ablate,devlog,full-send,implement,iterate,oversee,propose,propose-revise}/SKILL.md`, `skills/devlog/template.md` | Heading references replace filename links |
| `plugins/cdocs/skills/{nit_fix,triage}/SKILL.md` | "Reads rules at runtime" claims corrected |
| `plugins/cdocs/skills/init/SKILL.md` | Step 3: no import, remove legacy line; directive wording |
| `plugins/cdocs/hooks/tests/chat-record.test.sh` | `init_rules` writes no import; `init_real` inverted assertion and `--materialized`; temporary `canary_check` added and removed |
| `plugins/cdocs/README.md` | Rules Integration, Agents and rules, Referencing rules |
| `CLAUDE.md` | Rules Delivery items 1 and 3 |
| `cdocs/reports/2026-09-19-claude-code-subagents-feature-breakdown.md` | Section 13 NOTE |
| `scripts/build-opencode.ts` | Comment on the `rules` rewrite branch |

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

### Step 2: canary gate and `rules_check` comparison

Gate: `chat-record.test.sh --headless --only canary_check` (fixture per proposal section 3: `init_rules`, `CLAUDE.md` = `# Project`, `heliotrope` appended, swapped to `marzipan` on disk before `/compact`).
**Verdict: pass, 2/2.**
Run 1 (`$S/h/chat-record-test.3Vo0WR/headless/canary_check.jsonl`):

```
  info: on-disk canary line: The cdocs canary word is `marzipan`.
  PASS: a compaction happened
  info: post-compaction assistant text blocks:
    The cdocs canary word is `marzipan`. It appears in the CDocs Frontmatter Specification in the project rules loaded into this session.
    The chat-record note for this turn is written. The cdocs canary word is still `marzipan`.
  PASS: a post-compaction assistant text block contains marzipan
compact_boundary: {"trigger":"manual","pre_tokens":26787,"post_tokens":2434}
results: turn 1 "... 2 + 2 = 4."; turn 3 "... The cdocs canary word is still `marzipan`."
```

Run 2 (`$S/h/chat-record-test.SmjGPu/headless/canary_check.jsonl`):

```
  info: on-disk canary line: The cdocs canary word is `marzipan`.
  PASS: a compaction happened
  info: post-compaction assistant text blocks:
    The cdocs canary word is **marzipan**. It appears in the CDocs Frontmatter Specification in the project's CDocs rules.
    The chat-record note for this turn is appended (exit 0). The canary word is still marzipan.
  PASS: a post-compaction assistant text block contains marzipan
```

In both runs the only tool calls are the two `chat-record note` Bash calls (turns 1 and 3); no Read of the rules file, so `marzipan` came from re-injection, not a tool.
`heliotrope` never appears in either stream (the rule text is in the system prompt, not the stream), and `marzipan` appears only after the boundary.
"Frontmatter Specification" is correct placement: the line was appended after the last rule in the concatenated file.

`rules_check` per-assertion comparison (`--only rules_check`; with import at `ef32858`'s tree, without at `7962291`):

| Assertion | With import (`$S/rc-import1.log`) | Without (`$S/rc-noimport1.log`) |
|---|---|---|
| a compaction happened | PASS | PASS |
| first post-compaction call runs chat-record path | FAIL | FAIL |
| devlog (Scratchpoint, handoff) read before acting | FAIL | FAIL |
| record tail read before acting | FAIL | FAIL |
| no hook emitted additionalContext | PASS | PASS |

Identical (2 pass, 3 fail each, the 3/5 failure the r2 review reported with the import), so no re-run was needed.
In both, haiku's first post-compaction call edits `greeter.py` directly.

### Step 3: `/context` in a real-init project

`$S/v/v3.sh`: fresh git project, `CLAUDE.md` seeded with `# Project` + `@.claude/rules/cdocs.md`, real `/cdocs:init` (worktree plugin, haiku, sandboxed config), then `claude -p /context < /dev/null`.
`CLAUDE.md` after init is `# Project` (import removed). `/context` Memory Files:

```
| Project | .../v/proj-real/CLAUDE.md | 11 |
| Project | .../v/proj-real/.claude/rules/cdocs.md | 5k |
```

`rules/cdocs.md` occurs once in the `/context` output.

### Step 4 without the import (real-init project)

`$S/v/v4.sh real $S/v/proj-real` (same sentinel and fixture as above; artifacts `$S/v/out-real/`).
`nit-fix` replaced both *utilize* occurrences and reported `Rules used: CDocs Writing Conventions, CDocs Frontmatter Specification`, `[line 18] Prefer Use Over Utilize: "utilize" changed to "use"`.
Subagent tool calls: nit-fix `Read` (fixture), `Edit` x2; reviewer `Bash` (`cat` fixture, `ls -R cdocs`, `ls` and `cat` of the plugin's `skills/review/template.md`), `Write`, `Edit`, `Bash` (commit).
No subagent tool input names a `rules/` path; the one `rules/` string in either stream's tool inputs is haiku's top-level dispatch prompt ("per the cdocs writing conventions rule in .claude/rules/cdocs.md").
Also run as a regression check of the `init_rules` change: `--only top_level_only` 8/0 (the dispatched `cdocs:proposer` read only `skills/propose/template.md` and its own files).

### Step 5: `init_real`

`chat-record.test.sh --headless --only init_real` on the final tree (`$S/init_real2.log`): 9 passed, 0 failed, including `CLAUDE.md rules import line is gone` and `check-rule-refs --materialized passes`.
The materialized marker hash `a0917da7...` equals the hash of the worktree's rules.

### Final tree

`npm run test:rules` 11/0, `chat-record.test.sh --unit` 95/0, `npm run test:opencode` 8/0; `git status` clean, no `cdocs/_chat/` files from headless runs in the worktree.
