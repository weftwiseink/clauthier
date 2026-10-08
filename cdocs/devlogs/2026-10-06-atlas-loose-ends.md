---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-10-06T17:27:59-07:00
task_list: meta/atlas-loose-ends
type: devlog
state: archived
status: done
tags: [hooks, documentation, maintenance]
---

# Atlas Loose Ends

> BLUF(sonnet-5/meta-atlas-loose-ends): Fixed four small loose ends in the cdocs plugin: the edit-path guard's `agent_type` matching, a stale OC skill count and missing skill rows in the README, a missing `implementation_wip` status filter value, and bare (unprefixed) `subagent_type` dispatches in triage/nit_fix. All four were small enough to fix directly; none needed an RFP. The edit-path guard bug was confirmed empirically (not just inferred from docs): the guard currently never restricts a real dispatched cdocs subagent.

## Objective

Four independent, pre-scoped loose ends across the cdocs plugin, fixed directly and verified:

1. Edit-path guard's `agent_type` matching (bare vs. `cdocs:`-prefixed).
2. `plugins/cdocs/README.md` OpenCode skill count and skill-table omissions.
3. `/cdocs:status` filter list missing `implementation_wip`.
4. Bare `subagent_type` dispatches in the triage and nit_fix skills.

Out of scope: anything under `cdocs/devlogs/_judge/` or judge agent/skill text about `_judge/` (another agent's workstream).

## Plan

1. Read `plugins/cdocs/hooks/validate-cdocs-edit-path.sh` and confirm, via the Claude Code hooks docs and an empirical test, what `agent_type` a dispatched plugin subagent actually carries.
2. Fix the guard to match both forms; write a regression test; wire it into CI.
3. Fix the README count/omissions, the status filter list, and the bare `subagent_type` dispatches.
4. Check `scripts/build-opencode.ts` for any dependency on the bare agent-name form.
5. Run the build and both hook test suites; report pass counts.

## Implementation Notes

### 1. Edit-path guard `agent_type` matching

`plugins/cdocs/hooks/validate-cdocs-edit-path.sh` restricted Write/Edit to `cdocs/` paths for an allowlist of subagents (`CDOCS_AGENTS="triage nit-fix reviewer"`), matched against the hook payload's `agent_type` field verbatim.

**Docs (WebFetch of `code.claude.com/docs/en/hooks`):** for a plugin-registered agent, `agent_type` carries the plugin-scoped name (`plugin-name:agent-name`, e.g. `cdocs:triage`), not the bare agent name. The docs cite `SubagentStart`'s matcher examples (`general-purpose`, `Explore`, `Plan`, custom names, or plugin-scoped names like `^my-plugin:reviewer$`) as the basis for this.

**Empirical confirmation:** rather than trust the docs alone, I reproduced it live.
- Added a one-line debug tap to the hook (`echo "$INPUT" >> <scratch>/hook-debug.jsonl`), temporarily, keeping the rest of the script's behavior untouched.
- Wrote a throwaway devlog at `cdocs/devlogs/2026-10-06-DELETE-ME-hook-debug-scratch.md` with a deliberately missing `tags` field (so a triage pass would definitely call `Edit`), dispatched a real `cdocs:triage` subagent (via the `Agent` tool, `subagent_type: "cdocs:triage"`) to triage it, and inspected the captured payloads.
- Result: the dispatched subagent's `PreToolUse` payload carried `agent_type="cdocs:triage"` (plugin-prefixed), with an `agent_id` present. My own (dispatching) session's calls carried `agent_type="general-purpose"` — I am myself a dispatched subagent in this task, which incidentally reconfirms the main-session/no-`agent_type` case is orthogonal to this bug.
- Reverted the debug tap and deleted the throwaway devlog before committing anything.

This means the guard's `[ "$AGENT_TYPE" = "$agent" ]` bare-string match against `CDOCS_AGENTS="triage nit-fix reviewer"` never matched a real dispatched cdocs subagent. `IS_CDOCS_AGENT` was always `false` for them, so the guard fell through to "not a cdocs subagent: allow all operations" — **the path restriction was non-functional for every real cdocs subagent dispatch**, silently. This is the loose end's actual severity: not a cosmetic mismatch, but a dead guard.

**Fix:** strip an optional `cdocs:` prefix before comparing (`BARE_AGENT_TYPE="${AGENT_TYPE#cdocs:}"`), so both `triage` and `cdocs:triage` (etc.) match. Kept the bare-name branch for robustness (a non-plugin or locally-registered agent of the same name), per the task's "cheap and robust regardless" framing.

**Regression test:** no prior test existed for this hook (only `chat-record.test.sh` existed under `plugins/cdocs/hooks/tests/`). Added `plugins/cdocs/hooks/tests/validate-cdocs-edit-path.test.sh`: 17 cases covering the main-session no-`agent_type` path, unrestricted unknown agent types (including `cdocs:judge`, not in the allowlist), both bare and `cdocs:`-prefixed forms of all three allowlisted agents, and the no-`file_path` case. Verified the test actually catches the bug: run against a copy of the pre-fix script, it fails exactly the 3 `cdocs:`-prefixed/non-cdocs-path cases (14 passed, 3 failed) and passes all 17 against the fix. Wired into `.github/workflows/cdocs-hooks.yml` alongside the existing `chat-record.test.sh --unit` step.

**Left unverified:** I did not confirm the `agent_id`/`agent_type` shape for a *non*-plugin custom agent (one registered directly in a project, not via a plugin) — the docs suggest the bare form there, and the guard's bare-name branch exists for that case, but I did not reproduce it empirically. Also did not test `SubagentStart`-specific matcher syntax (`^my-plugin:reviewer$`) since this hook uses `PreToolUse`, not `SubagentStart`.

### 2. README skill count and omissions

`plugins/cdocs/README.md`'s OpenCode compatibility table said "All 11 skills work as-is"; 15 skills exist under `plugins/cdocs/skills/`. Dropped the number entirely ("All skills work as-is") rather than bumping it to 15, per the task's own suggested escape hatch, so it cannot drift again.

The top `## Skills` table only listed 8 of the 15 skills (`init`, `devlog`, `propose`, `review`, `report`, `status`, `iterate`, `oversee`), omitting `ablate`, `full-send`, `implement`, `nit_fix`, `propose-revise`, `rfp`, and `triage`. Added the missing rows, grouped near related existing rows (e.g. `propose-revise`/`rfp` near `propose`, `nit_fix`/`triage` near `review`, `implement` near `status`/`iterate`, `full-send` near `oversee`, `ablate` last).

Checked the README's other skill-adjacent lists for omissions:
- "Agent path resolution" section's agent list (`nit-fix`, `triage`, `reviewer`, `judge`, `implementer`, `proposer`) is complete against `plugins/cdocs/agents/`'s 7 files; `bash-runner`'s exclusion is explicit and intentional (next sentence: "`bash-runner` reads no rule files").
- The OC "Agents" row ("7 agents converted") matches the 7 files in `plugins/cdocs/agents/`.
- The "Rules" bullet list (5 rule files) matches `plugins/cdocs/rules/`'s 5 files.

### 3. `/cdocs:status` filter list

`plugins/cdocs/skills/status/SKILL.md`'s `--status` filter table omitted `implementation_wip`, present in `plugins/cdocs/rules/frontmatter-spec.md`'s status enum (set by `/cdocs:implement` during implementation). Added it in spec order, between `implementation_ready` and `evolved`.

### 4. Bare `subagent_type` dispatches

Grepped `subagent_type` across `plugins/cdocs/`. Two skills still dispatched with bare names:
- `plugins/cdocs/skills/triage/SKILL.md`: `subagent_type: "triage"` at two sites (the behavior-step prose and the "Dispatching the Triage Agent" section).
- `plugins/cdocs/skills/nit_fix/SKILL.md`: `subagent_type: "nit-fix"` at two sites (same pattern).

Every other skill (`iterate`, `propose-revise`, `full-send`, `implement`, `oversee`, `ablate`) already dispatches with the `cdocs:`-prefixed form (`cdocs:reviewer`, `cdocs:implementer`, `cdocs:proposer`). Specifically checked `iterate/SKILL.md`'s Turn N.b (Review) dispatch, flagged in the task as a possible straggler: it already reads `subagent_type: "cdocs:reviewer"` (line 92) — no fix needed there; the earlier fix mentioned in the task had already landed.

Fixed both bare dispatches in `triage/SKILL.md` and `nit_fix/SKILL.md` to the `cdocs:`-prefixed form, consistent with the rest of the plugin (and now consistent with the edit-path guard's actual matching behavior from fix #1, though the guard now tolerates both forms regardless).

**`scripts/build-opencode.ts` dependency check:** read `rewriteBodyPaths()` and `convertAgent()`. The build script only rewrites `plugins/cdocs/(rules|skills)/` *path* references in agent body content (e.g. `plugins/cdocs/rules/frontmatter-spec.md` → `../rules/frontmatter-spec.md`); it does not touch `subagent_type` strings anywhere, and skills are copied into the OC build output verbatim (not converted). No build-script change was needed. Ran `npm run build:cdocs` anyway (see Verification) to confirm the skill-content changes carry through to the build output without incident.

## Changes Made

| File | Change |
|---|---|
| `plugins/cdocs/hooks/validate-cdocs-edit-path.sh` | Strip optional `cdocs:` prefix before matching `agent_type` against the allowlist |
| `plugins/cdocs/hooks/tests/validate-cdocs-edit-path.test.sh` | New: 17-case regression suite for the guard |
| `.github/workflows/cdocs-hooks.yml` | Added a CI step running the new test suite |
| `plugins/cdocs/README.md` | Dropped the stale "11 skills" count; added 7 missing rows to the Skills table |
| `plugins/cdocs/skills/status/SKILL.md` | Added `implementation_wip` to the `--status` filter values |
| `plugins/cdocs/skills/triage/SKILL.md` | `subagent_type: "triage"` → `"cdocs:triage"` (two sites) |
| `plugins/cdocs/skills/nit_fix/SKILL.md` | `subagent_type: "nit-fix"` → `"cdocs:nit-fix"` (two sites) |

No RFP stubs were needed: all four loose ends were small, well-scoped fixes with no open design question.

## Verification

**New hook test suite**, run directly:
```
$ bash plugins/cdocs/hooks/tests/validate-cdocs-edit-path.test.sh
...
17 passed, 0 failed
```
Confirmed the suite is meaningful by also running it against a copy of the pre-fix script: 14 passed, 3 failed (the three `cdocs:`-prefixed/non-cdocs-path cases), proving it would have caught this exact bug.

**Existing chat-record unit suite** (unrelated to these changes, run to confirm nothing else broke):
```
$ bash plugins/cdocs/hooks/tests/chat-record.test.sh --unit
...
chat-record tests: 95 passed, 0 failed
```

**OpenCode build**:
```
$ npm run build:cdocs
...
  Converting 7 agents...
    bash-runner.md
    implementer.md
  Warning: Unknown CC tool ""*"" — skipping
    judge.md
    nit-fix.md
    proposer.md
  Warning: Unknown CC tool ""*"" — skipping
    reviewer.md
  Warning: Unknown CC tool ""*"" — skipping
    triage.md
  Copying skills...
  Copying rules...
  Copying hand-written OC files...
  Generating package.json...
build-opencode: Done.
  Agents converted: 7
```
Exit 0. The `Unknown CC tool "*"` warnings are pre-existing (unrelated to this work: they fire for any agent whose `tools:` frontmatter is `"*"`, e.g. `implementer.md`/`proposer.md`/`reviewer.md`) and unaffected by any change here.

**Not independently re-verified:** the OC build output's skill files were not diffed line-by-line against source beyond confirming the build exits 0 and reports "Copying skills..."; `build/cdocs/opencode/` is gitignored and not committed, so this is a smoke check, not a regression test.

## Scratchpoint

- as_of: 2026-10-06T17:27:59-07:00
- now: all four loose ends fixed, committed, build and both test suites green.
- next: none; task complete.
- open: none within scope. Out-of-scope note: the edit-path guard's `CDOCS_AGENTS` allowlist does not include `judge`, even though the judge agent has `Write` tool access per its definition; this predates and is unrelated to the `agent_type`-matching bug fixed here, and judge/`_judge/` work is explicitly another agent's workstream per the task's instructions, so left untouched.
- files touched: `plugins/cdocs/hooks/validate-cdocs-edit-path.sh`, `plugins/cdocs/hooks/tests/validate-cdocs-edit-path.test.sh`, `.github/workflows/cdocs-hooks.yml`, `plugins/cdocs/README.md`, `plugins/cdocs/skills/status/SKILL.md`, `plugins/cdocs/skills/triage/SKILL.md`, `plugins/cdocs/skills/nit_fix/SKILL.md`.
