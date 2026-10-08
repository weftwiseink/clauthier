---
review_of: cdocs/proposals/2026-10-07-rules-references.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T22:34:29-07:00
task_list: cdocs/rules-references
type: review
state: live
status: done
tags: [fresh_agent, runtime_validated, implementation_review, verification_gate, rules_delivery, test_plan]
---

# Review: Rules References Implementation (Round 1)

> BLUF: Accept, `review_proof: confirmed`.
> I re-ran Verification steps 1-5 independently and all pass, the Constraints hold, and the existing suites are green.
> No blocking items.
> Four small non-blocking items, the main one being that nit-fix step 3e is empirically unnecessary and should be dropped under the minimal-design preference.

## Summary Assessment

The implementation (commits `3fa8d3d..2457283` on `8843b2e`, branch `rules-references`) delivers all three phases.
It adds the `test:rules` check, rewrites shipped references to heading form, replaces the agent Startup reads with a Rules section, and drops the `CLAUDE.md` import behind the canary gate.
The code matches the proposal's design closely and the implementer's devlog is accurate: every claim I re-checked held.
I independently tested the four deviations I was asked to scrutinize.
None changes behavior in an unintended way, but step 3e and the path exemption add surface the evidence does not justify.

## Verification (re-run by this reviewer)

All runs used a fresh scratch dir under the session scratchpad: a tree copy from `git archive 2457283`, a sandboxed `CLAUDE_CONFIG_DIR`, `env -i`, `--model haiku`, and `--plugin-dir` the copy.
Every nested `claude` ran with cwd in a scratch git project, so no chat-record hook could write into the worktree.
`git status` in the worktree stayed clean throughout, and `cdocs/_chat/` holds only the record committed at `8843b2e`.

### Step 1: `npm run test:rules`, pre-change hit list, mutations

Green tree: `ℹ tests 11 / pass 11 / fail 0`, and the CLI prints `rule references OK`.
Running the new checker against a `git archive 8843b2e` copy prints `31 rule reference problem(s)`, at exactly the 31 `file:line` sites in the devlog's hit-list table.

My own mutations, each on a fresh copy:

| # | Mutation | Exit | Output (excerpt) |
|---|---|---|---|
| m1 | skill adds `"CDocs Writing Conventions > Sentence per line"` | 1 | `has no heading "Sentence per line"; its headings are: "BLUF (Bottom Line Up Front)", ... "Sentence-per-Lin...` |
| m2 | agent adds ``Read `.claude/rules/overseers.md` `` | 1 | `` `overseers.md` in: Read `.claude/rules/overseers.md` first. fix: use "CDocs Overseer Rules" `` |
| m3 | agent adds ``Glob `.claude/rules/*.md` `` | 0 | `rule references OK` (exempted; valid downstream) |
| m4 | agent adds ``Read `.claude/rules/chat-record.md` `` | 0 | `rule references OK` (exempted; dead downstream, see finding 3) |
| m5 | `## Model Tiering` renamed `## Model tiers` in the rule | 1 | `iterate/SKILL.md:34` and `propose-revise/SKILL.md:45`: `has no heading "Model Tiering"` |
| m6 | duplicate `## Chat record` in `overseers.md` | 1 | `heading "Chat record" is not unique within "CDocs Overseer Rules"` |
| m7 | skill adds `.opencode/rules/cdocs/overseers.md` | 1 | `` `overseers.md` in: ... fix: use "CDocs Overseer Rules" `` |
| m8 | valid `"CDocs Tool Use Safeguards › One writer per file"` and curly `“CDocs Overseer Rules > Stay thin”` | 0 | `rule references OK` |
| m9 | `<!-- see writing-conventions.md -->` in `propose/template.md` | 1 | `use "CDocs Writing Conventions" for writing-conventions.md` |
| m10 | `omitClaudeMd: true` in `reviewer.md` | 1 | `sets omitClaudeMd; cdocs agents rely on rules ...` |

Through the npm entry point, a `## Chat records` rename gives `ℹ pass 10 / ℹ fail 1`, which names `frontmatter-spec.md:85`, `devlog/SKILL.md:31`, and `devlog/template.md:10`.

### Step 2: canary gate and `rules_check` comparison

I wrote my own driver rather than reusing the removed `canary_check` extra.
It differs in three ways: the fixture is a copy of a real `/cdocs:init` output with no import line, the canary sentence sits mid-file (right after `# CDocs Overseer Rules`, line 128) instead of being appended, and the words are new (`periwinkle` on disk at launch, `quahog` swapped in by `sed` before `/compact`).
Two independent runs:

```
run 1: compact_boundary: 1
  > The cdocs canary word is **quahog**. It appears in the cdocs overseer rules in the project instructions.
  tool calls: Bash chat-record note (x2) only
  periwinkle mentions in stream: 0  quahog before boundary: 0
run 2: compact_boundary: 1
  > The cdocs canary word is `quahog`.
  tool calls: Bash chat-record note (x2) only
  periwinkle mentions in stream: 0  quahog before boundary: 0
```

The gate passes 2/2.
The answer correctly places the word in the Overseer Rules, which the mid-file placement makes a stronger locality check than the implementer's append.

`rules_check`: I made a scratch copy of the suite whose `init_rules` writes the import line, then ran both variants with `--headless --only rules_check`:

| Assertion | With import | Without |
|---|---|---|
| a compaction happened | PASS | PASS |
| first post-compaction call runs chat-record path | FAIL | FAIL |
| devlog read before acting | FAIL | FAIL |
| record tail read before acting | FAIL | FAIL |
| no hook emitted additionalContext | PASS | PASS |

Per-assertion results are identical, which matches the devlog and the known 3/5 baseline.

### Step 3: real init plus `/context`

I ran a real `/cdocs:init` (worktree-copy plugin, haiku) in a fresh git project whose `CLAUDE.md` was `# Project` plus `@.claude/rules/cdocs.md`.
Afterward `CLAUDE.md` is `# Project` (import removed), and the marker hash `a0917da7314a0139...` equals the sha256 of the source rules.
`check-rule-refs.ts --materialized` on it prints `rule references OK`.
`claude -p /context < /dev/null` on a copy lists, under Memory Files:

```
| Project | .../rv1/proj-ctx/CLAUDE.md | 11 |
| Project | .../rv1/proj-ctx/.claude/rules/cdocs.md | 5k |
```

`rules/cdocs.md` occurs once in the output.

### Step 4: sentinel through `cdocs:nit-fix` and `cdocs:reviewer`

The sentinel is a new section, `## Prefer Plain Verbs` ("Write *use* instead of *utilize* ..."), inserted at the end of the Writing Conventions part of the real-init `.claude/rules/cdocs.md`.
The fixture devlog has *utilize* twice in prose and once in a code fence.
The parent was told to dispatch with the prompt set to the bare path and nothing else.
I checked that the `Agent` inputs were exactly that, so the parent did not pass the rule along.

| Variant | nit-fix result | Subagent tool calls |
|---|---|---|
| hint (`This is a MECHANICAL convention.`), plus reviewer | both prose lines fixed, code fence untouched; `Rules used: CDocs Writing Conventions, CDocs Frontmatter Specification`; `[line 22] Prefer Plain Verbs: "utilize" changed to "use"` | nit-fix: `Read` fixture, `Edit` x2. reviewer: `Read`, `Bash` (git status, find, `cat a.txt AGENTS.md`, review template), `Write`, `Edit`, `Bash` commit |
| no hint | same two fixes, same section name | `Read`, `Edit` x2 |
| control (no sentinel) | `Mechanical fixes applied: 0`; *utilize* unchanged | `Read` only |

No subagent used `Read` or `Glob` on a rule path in any variant.
The reviewer's `cat a.txt AGENTS.md` came from a whole-project sweep of a four-file scratch repo ("Read remaining files, log, template").
It is a Bash `cat` of the cross-tool `AGENTS.md`, not a Read or Glob of a rule path.
`AGENTS.md` does not carry the sentinel, and the reviewer skipped `.claude/rules/cdocs.md` even though `find` had listed it.
This meets the criterion, and I disclose it because it is the nearest thing to a rule read in the transcripts.

### Step 5: `init_real`

`chat-record.test.sh --headless --only init_real`, run from the tree copy: `9 passed, 0 failed`, including `CLAUDE.md rules import line is gone` and `check-rule-refs --materialized passes`.

### Constraints and existing suites

- The `8843b2e..HEAD` diff of `hooks/inject-rules.ts`, `rules/overseers.md` ("Stay thin" included), and `scripts/postinstall.js` is empty.
- In `init/SKILL.md` the hunks are only step 3 (`@@ -25`) and the Read-after-write directive (`@@ -161`), so step 5, the step 6 block, and the hash one-liner are untouched.
- `build-opencode.ts` gains only the two comment lines.
- `chat-record.test.sh --unit` 95/0 (run in the worktree, since it checks the git index mode), `validate-cdocs-edit-path.test.sh` 17/0, `graphify-scope.test.sh` 51/0, and `npm run test:opencode` 8/0 (run in the tree copy, keeping build output out of the worktree).

## Findings on the scrutinized deviations

### 1. nit-fix step 3e ("Any other MECHANICAL convention"): unnecessary, harmless (non-blocking)

The devlog argues that without 3e a new mechanical rule section "had no instruction to be applied".
I A/B tested this against a plugin copy with 3e deleted (step f renamed e):

- **Necessity:** with no 3e and the no-hint sentinel, nit-fix still applied both fixes in 2/2 runs.
  Step 3's lead-in, "check each MECHANICAL convention", together with the Rules section's "A new `##` section ... extends your enforcement surface", is enough for haiku.
- **Side effects:** I used a fixture with candidates 3e might newly treat as mechanical: bare `CC #14200` / `issue 16538`, an indented ASCII diagram, "Previously ... but now", and an em-dash.
  It produced the same edit in all four runs (2 with 3e, 2 without): only the em-dash became a colon.
  Direct Links and History-Agnostic Framing were reported as JUDGMENT REQUIRED both ways, the diagram was left alone (indented-code protected zone), and no URL was invented.

So 3e is neither scope creep with visible effects nor needed.
Given the maintainer's minimal-design preference, drop it, or keep it with the devlog's rationale corrected to "clarifies, not required".
The sample is small (haiku, 2 runs per arm), so the conclusion is "no observed effect", not proof of none.

### 2. Sentinel "This is a MECHANICAL convention." does not weaken step 4 (no action)

The hint removes nit-fix's classification decision, not the delivery question.
The no-hint run applies the same fixes and names the same section.
The control (no sentinel) leaves *utilize* alone and reports `Mechanical fixes applied: 0`.
So the fix depends on the rule text being in the subagent's context, which is what step 4 has to show.
The devlog's NOTE on the hint is accurate.

### 3. `.claude/rules/` and `.opencode/rules/` exemption: pre-emptive, slightly wider than needed (non-blocking)

The exemption only skips the `rules/<name>.md` path pattern.
A rule *filename* after either prefix is still caught by the name match (m2, m7).
What it hides is a non-rule name under those prefixes: `.claude/rules/chat-record.md` passes (m4) and does not exist downstream.
The `.opencode/` half only ever applies to `.opencode/rules/<x>.md`, which is never a valid downstream path (OpenCode rules live under `.opencode/rules/cdocs/`), and `.opencode/rules/cdocs/<x>.md` never matched the pattern anyway.
No scanned file uses either prefix today, so the exemption is currently unused.
The comment in `findFilenameRefs` and the devlog NOTE both say these are "materialized paths that exist downstream", which is true only of `.claude/rules/cdocs.md`.
The minimal fix is to exempt only the literal `.claude/rules/cdocs.md`, or to drop the exemption until a scanned file needs it.

### 4. `init_real` uses `node --import tsx` (sound; extend it, non-blocking)

The workaround is correct, and `tsx` is a locked devDependency.
I reproduced the underlying failure in the other entry point: with `TMPDIR` set to my 107-character scratch path, `npm run test:rules` (the `tsx --test` CLI) fails with `EINVAL ... tsx-1000/<pid>.pipe`, while `node --import tsx --test scripts/check-rule-refs.test.ts` under the same `TMPDIR` passes 11/0.
CI and default sessions (no `TMPDIR`) are unaffected, but any harness with a long `TMPDIR` gets a false red unrelated to rules.
Changing the `test:rules` script to `node --import tsx --test scripts/check-rule-refs.test.ts` would make both entry points use the same robust form.

## Other findings

- **`triage/SKILL.md:52`** still says "The agent reads the frontmatter spec at runtime" (non-blocking).
  This is the same class of claim as the `nit_fix/SKILL.md:48` and `triage/SKILL.md:69` sites the implementation fixed; the proposal's audit missed it.
  Suggested: "The agent applies the frontmatter spec from its context, ...".
- **Release coupling** (non-blocking, overseer-owned): `plugin.json` is unbumped, and proposal section 3 requires phases 2 and 3 to reach `main` in one push.
  A single fast-forward of this branch satisfies that; a partial cherry-pick would not.
- **CI `rules` job** is unexercised until push (devlog todo).
  The `paths` widening and the header comment match the proposal.
- `/cdocs:init` leaves `CLAUDE.md` as `# Project` plus a trailing blank line where the import was.
  This is cosmetic; no action needed.

## Verdict

**Accept.**
The verification floor (steps 1-5) is re-confirmed by independent runs, the Constraints hold, and the suites are green.
The non-blocking items are small simplifications (3e, the exemption, the `test:rules` invocation) and one missed stale sentence.

`review_proof: confirmed`.
Steps 1, 2, 3, 4, and 5 were each re-run by this reviewer, with the artifacts excerpted inline above.

## Action Items

1. [non-blocking] Drop nit-fix step 3e (restore "e. Apply each fix via the Edit tool"), or keep it and reword the devlog NOTE to say it clarifies rather than enables: the A/B showed no difference.
2. [non-blocking] Narrow the `findFilenameRefs` exemption to the literal `.claude/rules/cdocs.md` (or remove it until a scanned file needs it), and fix its comment.
3. [non-blocking] Make `test:rules` run `node --import tsx --test scripts/check-rule-refs.test.ts`, matching `init_real` and avoiding the long-`TMPDIR` IPC failure.
4. [non-blocking] Fix the stale "reads the frontmatter spec at runtime" claim at `plugins/cdocs/skills/triage/SKILL.md:52`.
5. [non-blocking, overseer] Land phases 2 and 3 on `main` in one push with the `plugin.json` bump, and confirm the CI `rules` job goes green on the first push.

## Questions for the maintainer

- Step 3e: (a) drop it (minimal; no observed effect), (b) keep it as an explicit clarification, or (c) keep it and add a fixture-based nit-fix regression probe later.
- Exemption: (a) literal `.claude/rules/cdocs.md` only, (b) remove entirely until needed, or (c) keep as is.
