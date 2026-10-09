---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T17:29:01-07:00
task_list: cdocs/remove-graphify
type: proposal
state: live
status: review_ready
last_reviewed:
  status: revision_requested
  by: "@claude-opus-5-5"
  at: 2026-10-08T17:40:00-07:00
  round: 1
tags: [graphify, cleanup, devcontainer]
---

# Remove Graphify from CDocs and Weftwise

> BLUF: Pure deletion, nothing replaces it: remove every graphify surface from clauthier (`/cdocs:graphify`, `cdocs-graphify` with its test and CI step, `graphify_base_query`, the init `.graphifyignore` step, the devcontainer feature, ignore files) and from weftwise (devcontainer feature, mount, `GRAPHIFY_OUT`, `.graphifyignore`), then archive the graphify cdocs records.
> Done when `git grep -i graphify` over shipped paths returns nothing, the test suites and `build:cdocs` pass, and `lace validate` passes in both repos.

## Summary

Three phases: clauthier removal on a worktree branch, weftwise removal on a throwaway worktree branch, and frontmatter archival of the graphify records.
Phases 1 and 2 touch different repos and can run in parallel.
Phase 3 follows Phase 1 on the same clauthier branch.
The overseer lands each branch by `git merge --ff-only`.

Out of scope: lace's graphify devcontainer feature (its own RFP, lace `cdocs/proposals/2026-10-08-delete-graphify-feature-rfp.md`), container rebuilds (config only, the maintainer rebuilds at their convenience), and the plugin version (stays 0.2.0, untagged).

## Objective

The weftwise assessment found graphify not worth its upkeep: no measured context saving, a per-call index rebuild, and a dependency on a pinned third-party CLI.
The maintainer's direction is to remove it entirely and pursue context-load reduction later through better factoring.

## Background

- `cdocs/proposals/2026-10-08-graphify-weftwise-assessment.md` and `cdocs/reports/2026-10-08-graphify-weftwise-assessment.md`: the measurement that motivates removal.
- `cdocs/reports/2026-10-08-search-subagent-context-prep.md`: recommends dropping graphify, and an earlier version (`git show 7060568:<path>`, "If graphify goes") listed the deletion pointers this inventory starts from.
- `cdocs/proposals/2026-10-08-graphify-overhaul.md`: the design of the surfaces being removed.
- `cdocs/proposals/2026-10-08-delete-ablate-rfp.md`: maintainer direction that `scripts/detect-usage.sh` stays as an internal script.

## Proposed Solution

### Clauthier inventory

`git grep -il graphify -- ':!cdocs'` lists 18 tracked files.

| Path | Action |
|---|---|
| `plugins/cdocs/skills/graphify/` | Delete the directory. |
| `plugins/cdocs/bin/cdocs-graphify` | Delete. |
| `plugins/cdocs/hooks/tests/cdocs-graphify.test.sh` | Delete. |
| `plugins/cdocs/bin/README.md` | Delete the `## cdocs-graphify` section (line 67 to end); the BLUF's "OpenCode ships neither" becomes "OpenCode does not ship it". |
| `.github/workflows/cdocs-hooks.yml` | Delete the `cdocs-graphify unit suite` step (lines 64-65) and reword the header comment (lines 2-4) to name only the two remaining suites. |
| `plugins/cdocs/rules/tool-use-safeguards.md` | Delete the `/cdocs:graphify` bullet and its continuation (lines 7-8). |
| `plugins/cdocs/skills/iterate/SKILL.md` | Delete the `## Base query` section (lines 37-42), including the `[base_query: ...]` Iteration Log tag. |
| `plugins/cdocs/skills/iterate/template.md` | Delete `- graphify_base_query:` (line 8). |
| `plugins/cdocs/skills/devlog/SKILL.md` | Delete the `graphify_base_query` paragraph (lines 64-65). |
| `plugins/cdocs/skills/devlog/template.md` | Delete `- graphify_base_query:` (line 20). |
| `plugins/cdocs/skills/init/SKILL.md` | Delete step 7, "graphify exclusion" (lines 97-104). |
| `plugins/cdocs/README.md` | Delete the `/cdocs:graphify` table row (line 50); line 54 becomes "bundles one command, `chat-record`". |
| `CLAUDE.md` | Drop `graphify` from the skills list (line 50). |
| `.devcontainer/devcontainer.json` | Delete the graphify feature block and the `claude-code:1` declaration whose comment justifies it only by graphify (lines 24-34), and the now-trailing comma after the `opencode:0` entry. |
| `.lace/mount-assignments.json` | Delete the `graphify/index` entry (tracked lace state). |
| `.graphifyignore` | Delete. |
| `.gitignore` | Delete the `graphify-out/` comment and line (lines 18-19). |
| `scripts/detect-usage.sh`, `scripts/detect-usage.test.sh` | Reword the example tool names: `mcp__graphify__scope` to `mcp__example__scope`, `graphify` as a CLI to `sometool`. Behavior unchanged. |

Line numbers are as of commit `d6813e8`: match on content.
`plugins/cdocs/agents/` already carries no graphify text.

### Weftwise inventory

The graphify full-send (weftwise `1caa585d..99475534`, `5e446a84`, and the unpushed `2791713d`) touched these shipped files.

| Path | Action |
|---|---|
| `.devcontainer/devcontainer.json` | Delete the `claude-code:1` and `graphify:1` feature entries with their comments, the `graphify-index` project mount, both `graphify/index ... (unused; see graphify-index)` comment lines, and `containerEnv.GRAPHIFY_OUT` with its comment, leaving the `portless:1` entry last in `features` with no trailing comma. |
| `.graphifyignore` | Delete. |
| `.devcontainer/Dockerfile` | Keep: the `.pnpmfile.cjs` copy fix (`a61e8e6a`) is unrelated. |

Weftwise `.claude/rules/cdocs.md` (v0.1.0) and `CLAUDE.md` carry no graphify text, and weftwise's `.lace/` is untracked and regenerated by lace.

### Docs disposition

Records stay; only frontmatter changes.
Rule: set `state: archived` and leave `status` unchanged, with one exception.

Clauthier:
- Proposals: `2026-09-17-graphify-lace-devcontainer-enablement.md`, `2026-10-08-graphify-fork-rfp.md`, `2026-10-08-graphify-overhaul.md`.
- `2026-10-08-graphify-weftwise-assessment.md` (proposal): `state: archived`, `status: evolved` (this proposal is its follow-up), plus a NOTE under its BLUF: Phases 1-4 done, Phase 5 abandoned at maintainer direction, superseded by `2026-10-08-remove-graphify.md`.
- Reports: `2026-09-17-graphify-mcp-vs-cli-value-add.md`, `2026-10-08-graphify-exploration.md`, `2026-10-08-graphify-update-performance-audit.md`, `2026-10-08-graphify-upstream-health.md`, `2026-10-08-graphify-weftwise-assessment.md`.
- Devlogs: `2026-09-17-graphify-cdocs-integration-propose-revise.md`, `2026-09-17-graphify-lace-devcontainer-enablement.md`, `2026-09-22-graphify-cdocs-integration-scoping-revision.md`, `2026-09-23-graphify-cdocs-integration-full-send.md`, and the sub-devlogs `2026-10-08-graphify-overhaul-impl.md`, `2026-10-08-graphify-value-beyond-grep.md`, `2026-10-08-graphify-weftwise-assessment-impl.md`.
- Reviews: every live `cdocs/reviews/*graphify*.md` (20 files).
- Already archived, untouched: `2026-09-17-graphify-cdocs-integration.md`.
- Overseer-owned, listed only (already archived): the top-level devlogs `2026-10-08-graphify-overhaul.md` and `2026-10-08-graphify-weftwise-assessment.md`.

Weftwise:
- `cdocs/proposals/2026-10-08-graphify-devcontainer-feature.md`, `cdocs/devlogs/2026-10-08-graphify-devcontainer-feature.md`, `cdocs/devlogs/2026-10-08-graphify-devcontainer-feature-impl.md`, and the three `cdocs/reviews/2026-10-08-review-of-graphify-devcontainer-feature*.md`.

Documents that only mention graphify in passing (the ablation, chat-record, rules, and interfacer records) are untouched.

> NOTE(claude-opus-5-5/cdocs/remove-graphify): weftwise's 2026-09-14/15 code-graph research chain (archived reports plus three live RFPs, including `2026-09-15-code-graph-review-plugin-rfp.md`, "a graphify-or-equivalent plugin" for the cdocs review loop) is engine-agnostic product research, not the integration being removed.
> It is left as is: whether to defer it is a maintainer call.

## Important Design Decisions

- **Delete, do not stub.** No deprecation shim for `/cdocs:graphify` or `cdocs-graphify`: the plugin is unreleased at 0.2.0 and its only consumers are the maintainer's repos.
- **Drop the `claude-code:1` declarations in both devcontainers.** Each was added with graphify, and each comment justifies it only as graphify's MCP-registration prerequisite.
  Clauthier gets claude-code from `lace-fundamentals`, and weftwise had it from host user config before graphify.
- **Reword `detect-usage` rather than keep graphify examples.** The script stays (maintainer direction), but its fixtures' tool names are arbitrary, and a zero-hit grep is a crisper gate than an allowlist of residue.
- **Archive, do not delete, records.** cdocs records are the history.
  The shipped text is what goes, framed history-agnostically (no "graphify was removed" notes in shipped files).
- **Docs archival on the same clauthier branch** as Phase 1, so one ff-merge lands the whole clauthier change.

## Edge Cases / Challenging Scenarios

- **Stale local index.** `main/graphify-out/` exists untracked with no inner `.gitignore`; once `.gitignore` drops `graphify-out/`, it shows as untracked in `main`.
  The overseer deletes it after landing (it does not block the ff-merge, since no tracked path collides).
  Host caches `~/.cache/graphify` and `~/.cache/graphify-weftwise` are the maintainer's to delete.
- **Lingering MCP registration.** The feature registered a `graphify` MCP server into the container's Claude config, which is host-mounted.
  If it survives the next rebuild, `claude mcp remove graphify` in each container clears it.
  Until then it only fails to start: noise, not breakage.
- **Concurrent commits on clauthier `main`.** Other sessions commit there, so the worktree branch may need a rebase onto `main` before the ff-merge.
  The frontmatter-only archival edits are unlikely to conflict.
- **Unpushed weftwise `main`.** Weftwise `main` is ahead of origin (including `2791713d`); branch from local `main`, not `origin/main`.
- **Materialized rules in consumers.** A project whose `.claude/rules/cdocs.md` was generated with the graphify bullet gets the SessionStart freshness directive on the next session and re-runs `/cdocs:init`; weftwise (v0.1.0) never had it.
- **`.lace/mount-assignments.json`.** `lace validate` may rewrite it; after the run, confirm `graphify/index` stays absent and nothing else changed unexpectedly.
- **Arc state.** `.claude/oversee/2026-10-08-graphify-interfacer.json` is gitignored runtime state that the overseer may delete.

## Test Plan

No new tests: the existing suites guard the edits.
- `npm run test:rules`: every `/cdocs:<name>` still resolves (catches a leftover `/cdocs:graphify`), and rule-heading references still resolve after the safeguards bullet goes.
- `npm run test:opencode` (runs `build:cdocs`): the OpenCode build emits no graphify skill and passes.
- `bash plugins/cdocs/hooks/tests/chat-record.test.sh --unit` and `bash plugins/cdocs/hooks/tests/validate-cdocs-edit-path.test.sh`: the remaining hook suites still pass.
- `bash scripts/detect-usage.test.sh`: all checks pass after the rewording.

## Verification Methodology

Run in the clauthier worktree after Phases 1 and 3, capturing output per "CDocs Tool Use Guidance › Bash":
1. `git grep -il graphify -- plugins scripts .github .devcontainer .lace CLAUDE.md README.md .gitignore` returns nothing, and `git ls-files | grep -i graphify` lists only paths under `cdocs/`.
2. `git grep -n base_query -- plugins` returns nothing.
3. The test plan commands above all pass.
4. `lace validate` reports "Validation passed." with no `graphify/index` mount in its output.
5. `git grep -lE '^state: live' -- 'cdocs/*graphify*'` returns nothing (the two overseer-owned top-level devlogs are already archived).

Run in the weftwise worktree after Phase 2:
1. `git grep -il graphify -- ':!cdocs'` returns nothing, and `git ls-files | grep -i graphify` lists only paths under `cdocs/`.
2. `lace validate --workspace-folder <worktree>` reports "Validation passed." with no graphify feature or mount.
3. `git diff main -- .devcontainer/Dockerfile` is empty (the pnpmfile fix survives).

## Implementation Phases

### Phase 1: Clauthier removal

On a worktree branch `remove-graphify` off clauthier `main`.
Apply the clauthier inventory, one conventional commit per logical unit (skill and wrapper with its test and CI step; rules and skill text; devcontainer and lace state; ignore files; detect-usage rewording), each by explicit path.
Success: clauthier verification steps 1-4 pass.
Do not touch: `cdocs/` (Phase 3), `plugins/cdocs/.claude-plugin/plugin.json` (version stays), lace or weftwise.

### Phase 2: Weftwise removal

On a throwaway worktree branch `remove-graphify` off weftwise local `main`, as a sibling worktree at `/var/home/mjr/code/weft/weftwise/remove-graphify/`.
Apply the weftwise inventory and archive the weftwise docs listed under Docs disposition.
Success: weftwise verification steps 1-3 pass.
Do not touch: `.devcontainer/Dockerfile`, the 2026-09-14/15 code-graph research docs, `.claude/rules/cdocs.md`.
Independent of Phases 1 and 3.

### Phase 3: Clauthier docs archival

On the Phase 1 branch, after Phase 1.
Apply the clauthier Docs disposition: frontmatter `state` edits, plus the `status: evolved` and NOTE on the weftwise-assessment proposal.
Success: clauthier verification step 5 passes, and no body text outside that NOTE changes (`git diff --stat` shows only frontmatter-sized edits).
Do not touch: the overseer-owned top-level devlogs, this proposal, documents that only mention graphify in passing.

### Landing (overseer)

Rebase the clauthier branch onto `main` if needed, then `git merge --ff-only remove-graphify` in each repo's `main`.
Then delete `main/graphify-out/` in clauthier and the weftwise throwaway worktree.
