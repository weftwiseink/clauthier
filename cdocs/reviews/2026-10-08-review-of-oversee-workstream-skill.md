---
review_of: cdocs/proposals/2026-10-08-oversee-workstream-skill.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T10:51:53-07:00
task_list: cdocs/rules-delivery/oversee-workstream-skill
type: review
state: live
status: done
tags: [fresh_agent, architecture, runtime_validated, claude_skills, rules_delivery, minimalism]
---

# Review: Oversee-Workstream Skill and Oversee-Many Rename

## Summary Assessment

The proposal renames `oversee` to `oversee-many` and moves overseer-only rule text into an `oversee-workstream` skill.
It also keeps "Chat record" as a universal rule, adds a `PreToolUse` deny hook, and adds a `/cdocs:` skill-reference CI check.
The reference sweep is close to complete, and the probe confirms the hook claims on Claude Code 2.1.294.
The maintainer has since overridden open questions 1 and 2: chat-record becomes a `cdocs:chat-record` skill, one universal rule line says to load it only in the top-level session, and the hook is dropped.
That removes about a third of the proposal (§6, the hook design decisions and edge cases, its tests, Phase 4).
The new design has one gap to close: a fork inherits its parent's invoked skill text.
Two mechanical defects stand as well: Phase 2 cannot go green as written, and Verification step 1's grep cannot return nothing.
**Verdict: Revise.**

## Maintainer Direction (supersedes OQ1 and OQ2)

> "Make chat-record a skill and make the rule to load the skill iff the agent is top-level. It's about avoiding confusion for sub agents like what we saw here, not a strict security boundary."

The minimal design that follows from this:

- **`skills/chat-record/SKILL.md`** holds today's "Chat record" section unchanged: the per-turn note, the devlog `chat_record:` step, "After a compaction", and the commit line.
  Its first line is the guard: "Top-level session only. If the Agent tool started you, or you are a fork, stop: your dispatcher owns the record."
- **One universal line**, as a bullet in "CDocs Tool Use Guidance › Tools and Skills" (no new heading, no new rule file):
  "Top-level session only (not started by the Agent tool, and not a fork): invoke `/cdocs:chat-record` with the Skill tool, plus `/cdocs:oversee-workstream` when leading a loop, and again after a compaction when their text is not in context."
- **Delete `rules/overseers.md` outright.** All of it leaves: the intro and Stay thin go to `oversee-workstream`, and Chat record goes to `chat-record`.
  About 285 words leave the always-loaded rules and about 40 are added, against the proposal's net saving of about 100.
- **No hook.** §6, the "Deny with exit 2" and "fails open" design decisions, the absolute-path, compound-command, fork and legitimate-`path` edge cases, the hook unit cases, the `subagent_denied` scenario, Phase 4, and the README Hooks bullet all go.

## Recommendations per Open Question

1. **OQ1 (chat record stays a rule):** superseded.
   The proposal's argument (the `Stop` hook blocks every top-level human turn that has no note) does not weigh against a skill.
   The `Stop` hook ignores `agent_id` payloads, so its block reason only ever reaches the top-level session.
   If that reason names `/cdocs:chat-record`, it loads the skill at the right moment on its own, at a cost of at most one block per session.
2. **OQ2 (deny hook):** superseded, drop it.
   The probe evidence is below in case enforcement is wanted later; the proposal needs at most a one-line NOTE pointing at this review.
3. **OQ3 (pointer line):** keep it, but merge it into the top-level-only line above and drop the separate "CDocs Workflow Patterns › Loops" line.
   The gap it covers (no skills re-attached after resume plus compaction) only arises when a new process resumes a session, which only happens to a top-level session.
   In-process compaction re-attaches invoked skills, including inside a dispatched overseer.
   So "top-level only" is the correct scope for the `oversee-workstream` pointer too, and one line does both jobs.
4. **OQ4 (`postinstall.js` prune):** prefer the README or changelog note.
   OpenCode is a secondary target, and a `RETIRED_SKILLS` list plus an H1 guard is code kept forever for a one-time rename.
   This fits the maintainer's minimal-design preference.

## Runtime Verification (hook claims)

The proposal's §6 is now moot, but its claims were in the review focus, and the evidence is useful if enforcement comes back.
Probe: headless `claude -p`, haiku, a temp `CLAUDE_CONFIG_DIR`, `--plugin-dir` canary, `--permission-mode bypassPermissions`, `CLAUDE_CODE_FORK_SUBAGENT=1`.
The installed CLI is **2.1.294**, not 2.1.293 (stream-json `init` reports `claude_code_version: 2.1.294`).
The credential copy was deleted after each run; logs are in the session scratchpad (`probe/log.jsonl`, `probe/run.jsonl`, `probe/run2.jsonl`).

- **`agent_id` in subagent `PreToolUse` payloads: verified.**
  A `general-purpose` subagent sent `agent_id: "ac6a10d8e5cc99e86"` and `agent_type: "general-purpose"`, and a fork sent `agent_type: "fork"`.
  Top-level payloads had neither.
- **`"if": "Bash(chat-record:*)"`: valid, and it behaves the same as `Bash(chat-record *)`.**
  Both fired for `chat-record path`, `cd /tmp && chat-record path` and `echo hi; chat-record note`.
  Neither fired for the absolute path, `echo "chat-record note"`, `git log --grep='chat-record path'`, a heredoc body line `chat-record note`, `echo ok -m "deny chat-record note to subagents"`, or `bash -c 'chat-record path'`.
- **An exit-2 deny holds under `bypassPermissions`: verified** for both the `general-purpose` subagent and the fork.
  The tool result was `PreToolUse:Bash hook error: [...]: PROBE-DENY: ...`, the fake `chat-record` never ran, and the subagent reported the reason verbatim.
- **Consequence for the dropped design:** the `if` filter already matches command position, so the script-level regex in `hook_pretool` was redundant.
  Taken alone, that regex had false positives (a `-m "... chat-record note ..."` argument, or a heredoc line).
  If enforcement returns, the minimal hook denies any subagent payload that reaches it and has no regex.
- The fork was announced as "processing in background" even with `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`.
  This may matter for the existing `top_level_only` scenario's "both dispatches ran in the foreground" assertion.

## Section-by-Section Findings

### BLUF and Summary

- **Non-blocking.** The BLUF, Summary, Important Design Decisions and Open Questions each restate the chat-record rationale.
  After the restructure, keep one statement (in Design Decisions) and cut the rest.
  The NOTE about `graphify-overhaul` and Phase 0 also say the same thing: keep the NOTE and cut Phase 0 to one line, or merge them.

### §1 `oversee-workstream` skill

- **Non-blocking.** The `description` lists its loaders ("loaded by iterate, propose-revise, full-send, oversee-many and ablate").
  The list already omits `implement` and `propose`, which §2 also wires up, and it will drift.
  A role-only description is shorter and is all that §1's own rationale asks for: "Discipline for a session leading a cdocs loop as its overseer".
- **Non-blocking.** The new `chat-record` skill's description is shown in every subagent's skill listing.
  That makes it a second, free place to carry the condition: "Chat record upkeep for the top-level session only".

### §2 Loop skills load it by reference

- Anchors checked: `iterate:10`, `propose-revise:14`, `full-send:13`, `oversee:12`, `ablate:20,290`, `implement:19` and `propose:144` all match the tree.
- No other finding; the "skip if already in context" clause earns its place.

### §3 Rule changes

- **Blocking (direction).** Replace this section with the Maintainer Direction design above: delete the rule, add one bullet, and add no `## Chat record` section to "CDocs Tool Use Guidance".
- **Blocking (fork confusion).** This is the one route by which the new design can reproduce the original leak.
  A fork inherits the parent's context, so the parent's invoked `chat-record` skill text is already in the fork's history.
  "Load iff top-level" does not prevent a fork from following text it already has.
  Two guards are needed: the rule line must define top-level as "not started by the Agent tool, and not a fork", and the skill's first line must tell a fork or dispatched agent to stop.
  Add a headless assertion for it (see Test Plan).

### §4 Rename

- **Blocking.** Phase 2 cannot go green as written.
  `rules/overseers.md:6` ("load `/cdocs:oversee`") is in a scanned directory, and the Phase 1 check will flag it once the skill directory is renamed.
  §5's rows assigned to Phase 2 (`AGENTS.md:33`, `CLAUDE.md:51`, `README.md:47`) do not include it, and the file is not deleted until Phase 3.
  Fix: either edit `overseers.md:6` in Phase 2, or land Phases 2 and 3 as one commit.
- **Non-blocking.** `.gitignore:16`'s comment ("# /oversee arc state ...") names the old command.
  Repoint the comment, and make the "do not touch its `.gitignore` entry" constraint say it means the entry line.

### §5 Reference sweep

Grep check over `plugins/`, `scripts/`, `.github/`, `CLAUDE.md`, `README.md` and `.gitignore`:
every `CDocs Overseer Rules`, `overseers.md` and `/cdocs:oversee` hit outside `cdocs/` is in the table or in the §4 rename.
The exceptions are `.gitignore:16` (above) and the test fixtures and line-145 comment in `scripts/check-rule-refs*.ts`, which can stay.
`.github/`, `scripts/build-opencode*.ts`, `inject-rules.ts` and `cdocs-hooks.ts` have no references.

Under the new direction, these rows change:

- **Non-blocking.** `frontmatter-spec.md:85` becomes "The top-level session fills it (`/cdocs:chat-record`)."
  For `devlog/SKILL.md:31` and `devlog/template.md:10`, drop the cross-reference rather than repoint it.
  Subagents (implementers) use the devlog skill, and a `/cdocs:chat-record` pointer there invites the confusion the maintainer wants to avoid.
  The frontmatter spec is the single home ("say it once").
- **Non-blocking.** `README.md:123`, `CLAUDE.md:61` and `check-rule-refs.ts:5` need an example rule section that still exists, such as `"CDocs Workflow Patterns › Completeness"`, since "Chat record" leaves the rules entirely.
- **Non-blocking.** Add `chat-record` next to `oversee-workstream` in `CLAUDE.md:51`, the `plugins/cdocs/AGENTS.md` skill bullets and the README skills table.
  `README.md:153` becomes "per `/cdocs:chat-record`", and `bin/README.md:64` points at `../skills/chat-record/SKILL.md`.
- **Non-blocking.** The `_chat/README.md` template in `init/SKILL.md` describes the record, not agent duty, so it needs no change.
  `init` step 4's `--minimal` rationale ("never run in a project without the rule text") still holds, because the top-level line is rule text.

### §6 Subagent deny hook

- **Blocking (direction).** Remove it, with the related design decisions, edge cases, tests, Phase 4 and README Hooks bullet.
  At most, keep a one-line NOTE that enforcement was probed and works (this review).
- **Replacement.** "Do not change the ... `Stop` hook modes" must be relaxed for one edit.
  The `hook_stop` block reason should name the skill and still carry the command, for example: `No chat-record entry for this turn (record: X; see /cdocs:chat-record). Run, then finish: ...`.
  `chat-record.test.sh:217` asserts the reason stays under 300 bytes, and the addition of about 25 bytes fits.
  Add a unit assertion that the reason names `/cdocs:chat-record`.

### §7 Skill-reference check

- **Verified.** It passes on today's tree: every `/cdocs:<name>` in rules, skills, agents, both plugin READMEs, `AGENTS.md`, `CLAUDE.md` and the root README resolves to a skill or an agent.
  The only non-matching forms are the `/cdocs:<type>` and `/cdocs:*` placeholders.
  The "10 references go red" claim is also accurate: there are exactly 10 quoted `"CDocs Overseer Rules"` references in the scanned files.
- **Non-blocking.** "The existing scan directories ... including `init/SKILL.md`" glosses over the fact that `SCAN_EXCLUDE` removes `init/SKILL.md` from today's scan.
  The skill check needs its own file list; say so, so the implementer does not change `SCAN_EXCLUDE` and break the filename check.
- **Non-blocking.** This check was not in the request, and the Open Questions do not mark it as an addition.
  It is worth keeping: under the new direction a rule (`frontmatter-spec.md`) refers to a skill, so `/cdocs:` references become load-bearing, and the check is cheap.
  Say in one line that it is an addition.

### §8 Materialization and OpenCode

- Claims checked: `init` step 3 follows step 6's order, step 5c prunes orphaned OpenCode rules, `postinstall.js` `copySkillsFlat` never prunes, and `build-opencode.ts` has no skill exclude list.
- **Non-blocking.** `chat-record` will ship to OpenCode, which keeps no chat record.
  Today's rule text already ships the same instructions there, so this is not a regression, and it needs no text.

### Edge Cases

- **Non-blocking.** Remove the hook cases (absolute path, compound commands, forks, legitimate `path`) and the deny clause of the nest-overseers RFP case.
  Replace them with the fork-inherits-skill-text case under §3.
- The "Opus skips the Skill line" case still holds, and the merged top-level line remains its second path.

### Test Plan and Verification

- **Blocking.** Verification step 1 cannot "return nothing".
  In ERE, `/oversee\b` matches `/oversee-many` because `-` is a word boundary, so it hits every `skills/oversee-many/...` path and every `/oversee-many chain` usage line.
  The grep also omits `scripts/`, even though it names exceptions inside `scripts/`.
  Fix: use `/oversee([^-a-z]|$)` and search `plugins scripts .github CLAUDE.md README.md .gitignore`.
- **Blocking (direction).** Replace the `subagent_denied` scenario with an extension of the existing `top_level_only` scenario.
  The parent invokes `/cdocs:chat-record` first, then dispatches a `general-purpose` agent and a fork.
  Assert that the canary logs no chat-record `PreToolUse` with `agent_id` (the canary's `if` filter is now verified to match compound commands).
  This is the regression test for "avoid confusion", and it covers the fork route.
- **Non-blocking.** Verification step 5 should also show `Skill(cdocs:chat-record)` in the top-level transcript, from either the rule line or the `Stop` reason.
- **Non-blocking.** Phase 4's "update `.github/workflows/cdocs-hooks.yml`'s header comment if it lists the hook modes" can go: the header lists suites, not hook modes.

## Verdict

**Revise.**
Restructure to the maintainer's direction: a `chat-record` skill, one top-level-only rule line that also carries the `oversee-workstream` pointer, and no hook.
Close the fork-inheritance gap, fix the Phase 2 ordering defect, and fix the Verification step 1 grep.
Most of the remaining work is deletion.

## Action Items

1. [blocking] Add `skills/chat-record/SKILL.md` with today's "Chat record" content, including the "After a compaction" steps, led by a top-level-only guard line that also names forks; delete `rules/overseers.md` entirely, with no `## Chat record` section in "CDocs Tool Use Guidance".
2. [blocking] Add one bullet to "CDocs Tool Use Guidance › Tools and Skills": top-level only (not Agent-started, not a fork), invoke `/cdocs:chat-record`, plus `/cdocs:oversee-workstream` when leading a loop, again after a compaction when their text is gone; drop the separate "CDocs Workflow Patterns › Loops" line.
3. [blocking] Remove the deny hook: §6, the "Deny with exit 2" and "fails open" decisions, the hook edge cases, the hook unit cases, `subagent_denied`, Phase 4 and the README Hooks bullet; rewrite OQ1-3 as resolved, or drop them.
4. [blocking] Make the `hook_stop` block reason name `/cdocs:chat-record` (under the 300-byte assertion), add a unit assertion for it, and relax the "do not change `Stop` hook modes" constraint for this edit.
5. [blocking] Extend the `top_level_only` headless scenario: the parent loads `/cdocs:chat-record`, then dispatches a `general-purpose` agent and a fork; assert no chat-record `PreToolUse` carries `agent_id`.
6. [blocking] Fix Phase 2: edit `rules/overseers.md:6` in Phase 2, or land Phases 2 and 3 in one commit, so the skill-reference check is green.
7. [blocking] Fix the Verification step 1 grep: `/oversee([^-a-z]|$)` over `plugins scripts .github CLAUDE.md README.md .gitignore`.
8. [non-blocking] Sweep updates: point `frontmatter-spec.md:85` at `/cdocs:chat-record`; drop the cross-reference from `devlog/SKILL.md:31` and `template.md:10`; switch the `README.md:123`, `CLAUDE.md:61` and `check-rule-refs.ts:5` examples to a surviving section; list `chat-record` in `CLAUDE.md:51`, `AGENTS.md` and the README table; repoint `README.md:153`, `bin/README.md:64` and the `.gitignore:16` comment.
9. [non-blocking] OQ4: replace the `postinstall.js` prune with a README or changelog note.
10. [non-blocking] Give both new skills role-only descriptions (no loader list); make `chat-record`'s description say "top-level session only".
11. [non-blocking] §7: state that the skill check uses its own file list (`init/SKILL.md` stays in `SCAN_EXCLUDE` for the filename check), and mark the check as an addition to the request.
12. [non-blocking] Deduplicate the chat-record rationale across the BLUF, Summary, Design Decisions and Open Questions; fold Phase 0 into the NOTE; drop the `cdocs-hooks.yml` header bullet.
13. [non-blocking] Verification step 5: also expect `Skill(cdocs:chat-record)` in the top-level transcript.

## Questions for the Maintainer

1. Where should the top-level-only line live?
   - (a) A bullet in "CDocs Tool Use Guidance › Tools and Skills" (recommended: no new heading, next to the other "use this skill" bullets).
   - (b) A sentence in "CDocs Workflow Patterns › Loops and multi-phase plans".
   - (c) Omit it: the `Stop` block reason already loads the skill, top-level only, on the first unnoted human turn, at a cost of one block per session.
2. Should the `oversee-workstream` pointer share the top-level-only line?
   - (a) Yes, one line names both skills (recommended: the resume gap only arises in top-level sessions).
   - (b) Chain it: the `chat-record` skill's "After a compaction" step re-invokes `oversee-workstream` when leading a loop.
   - (c) Keep it as a separate Workflow Patterns line, as the proposal has it.
3. How should OpenCode consumers drop the stale `.opencode/skills/oversee/`?
   - (a) A README or changelog note (recommended).
   - (b) The guarded `RETIRED_SKILLS` prune in `postinstall.js`.
