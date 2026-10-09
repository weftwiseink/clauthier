---
review_of: cdocs/proposals/2026-10-08-remove-graphify.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T17:40:00-07:00
task_list: cdocs/remove-graphify
type: review
state: live
status: done
tags: [fresh_agent, inventory, devcontainer, verification, cleanup]
---

# Review: Remove Graphify from CDocs and Weftwise

## Summary Assessment

The proposal is a pure-deletion plan for graphify across clauthier and weftwise, plus frontmatter archival of the graphify records.
It is well scoped and proportionate to "fully yeet this misadventure": the shipped-file inventory is complete in both repos (independently re-grepped), and the riskiest call, dropping `claude-code:1` from both devcontainers, is safe.
However, the stated reason it is safe for clauthier is wrong: `lace-fundamentals` does not provide claude-code, the host's `~/.config/lace/user.json` does, in both repos.
Verification step 5 cannot pass as written, since its pathspec matches this proposal, the workstream devlog, and this review, and the weftwise code-graph RFP handling has to change to match the overseer's plan of record.
Verdict: **Revise**, with three small blocking edits.

## Section-by-Section Findings

### Clauthier inventory

Re-grepped at `761a407`: `git grep -il graphify -- ':!cdocs'` lists exactly the 18 files in the table, and `git grep -n base_query -- ':!cdocs'` hits only files already in the table (the iterate `[base_query: ...]` tag has no "graphify" text, and Verification step 2 covers it).
`git grep -i "base query\|code graph"` finds nothing further.
There are no false inclusions, and nothing is missed: no plugin.json, AGENTS.md, hook, OpenCode build, or `package.json` reference, and `scripts/build-opencode*.ts` has no hardcoded skill count or name, so deleting the skill directory is enough.
`init` step 7 is the last numbered step, so deleting it needs no renumbering.
Line references match the current HEAD, not just `d6813e8`.

- **non-blocking:** the `detect-usage.test.sh` rewording goes beyond tool names: comment prose also mentions graphify (lines 35-36, 42, 56, 62, 74, and the check labels at 47, 69, 79).
  The zero-hit grep forces the implementer to reword these anyway, so this only needs a phrase ("tool names and the comments describing them").

### Weftwise inventory

Re-grepped: the only shipped hit is `.devcontainer/devcontainer.json`, plus `.graphifyignore` by filename.
`git diff --stat 1caa585d^..2791713d -- ':!cdocs'` confirms the full-send touched exactly the three listed files.
The tracked `.devcontainer/devcontainer-lock.json` has no graphify or claude-code entry, `.lace/` is untracked, and `.claude/rules/cdocs.md` is clean.

- **non-blocking:** after `graphify-index` goes, `aws-config` becomes the last entry in `customizations.lace.mounts` and carries a trailing `},` (line 147).
  The table already mentions the `features` trailing comma, so name this one too; `lace validate` is the backstop either way.

### Important Design Decisions: dropping `claude-code:1`

This is safe in both repos, but the rationale needs correcting (**blocking**, one line).

Evidence:
- lace `devcontainers/features/src/lace-fundamentals/devcontainer-feature.json` depends only on `ghcr.io/devcontainers/features/git:1`; it neither depends on nor installs claude-code.
  The clauthier comment "expansion-provided by lace-fundamentals" (from `060e392`) was already inaccurate.
- `~/.config/lace/user.json` declares `ghcr.io/weftwiseink/devcontainer-features/claude-code:1` among its user `features`, and lace's `mergeUserFeatures` (`packages/lace/src/lib/user-config-merge.ts`) merges user features under project features for every lace project.
- Both repos ran without an explicit `claude-code:1` before graphify: clauthier at `041b1f6` and weftwise at `add5bd2b^`.
  Both already carried `CLAUDE_CONFIG_DIR: ${lace.mount(claude-code/config).target}`, which only resolves when the user-level feature is present.
  Removal restores that known-good state.
- The only declared reason for the explicit entry is graphify's `installsAfter` ordering for `installMcpServer`, which goes away with graphify.

The fix is to replace "Clauthier gets claude-code from `lace-fundamentals`, and weftwise had it from host user config before graphify" with "both get claude-code from the host's lace `user.json` features, as both did before graphify".

- **non-blocking:** both containers keep a pre-existing dependency on per-host user config for claude-code, and on a host without it `CLAUDE_CONFIG_DIR` fails to resolve.
  That is out of the maintainer's ask; at most it is worth a one-line mention in Edge Cases.

### Detect-usage reword vs keep

The reword is proportionate: it is one commit, behavior is unchanged, and it keeps the shipped-path gate a crisp zero.
One point does deserve a maintainer glance.
`delete-ablate-rfp.md` kept `detect-usage` "because the graphify-overhaul verification relies on it", and that consumer is now gone.
The maintainer's "keep around as a script for internal use" still stands, so the proposal is right not to delete it unilaterally (see the questions at the end).

### `.lace/mount-assignments.json`

Hand-deleting the `graphify/index` entry is right: the file is force-tracked despite `.lace/` being in `.gitignore`.
`lace validate` runs `runUp` with `validateOnly`, which goes through the mount resolver and may rewrite this file (and `port-assignments.json`) in the new worktree, for example as stale-path re-resolution under a different project ID.

- **non-blocking:** the edge case says "confirm ... nothing else changed unexpectedly" but not what to do if something did.
  State the rule: commit only the `graphify/index` removal, and `git checkout --` any other validate-induced rewrite of tracked `.lace/` files.

### Edge cases

- **non-blocking:** "Lingering MCP registration": the host `~/.claude.json` (bind-mounted as the container's `~/.claude/.claude.json`) has no `graphify` MCP server at user or project scope; its only graphify string is an `exampleFiles` entry.
  The edge case is likely moot, so trim it to one clause or keep it as is; either is fine.
- The stale `main/graphify-out/` and the ff-merge interaction are handled correctly: `git status --ignored` shows it as ignored today, and no tracked path collides.

### Docs disposition

The clauthier lists are complete: the 4 proposals, 5 reports, 7 devlogs, and 20 live reviews match `git ls-files 'cdocs/*'` filtered on graphify exactly.
"`state: archived`, leave `status`" plus `evolved` for the assessment proposal is proportionate and avoids a status-rewriting pass.

Under the overseer's plan of record for weftwise's code-graph RFPs (**blocking** for internal consistency):
- The closing NOTE ("left as is: ... a maintainer call") and Phase 2's "Do not touch: the 2026-09-14/15 code-graph research docs" contradict the plan of record.
  Replace them with: `2026-09-15-code-graph-review-plugin-rfp.md` gets `state: archived`, and `2026-09-15-code-graph-adapter-vellum-canvas-rfp.md` and `2026-09-15-code-understanding-graph-spike-comparison-rfp.md` get `state: deferred`, each with a one-line NOTE under the BLUF pointing at the clauthier assessment.
  The rest of the 09-14/15 chain stays untouched.

On the soundness of that call, judged from the RFPs' content:
- **review-plugin RFP, archived: sound.** Its consumer is exactly what clauthier built and measured: graphify-scoped context in the cdocs reviewer and dev loop, with an explicit token-efficiency thesis.
  The clauthier assessment measured that thesis and found no context saving, so the RFP is answered, not merely postponed.
- **spike-comparison RFP, deferred: sound.** It exists to feed #3 and #4.
  With #4 archived, its only remaining downstream is the long-horizon canvas, so it has no near-term purpose, but it is engine-agnostic and not refuted.
- **vellum-canvas adapter RFP, deferred: sound, with a wording caveat.** It is a product surface (an in-canvas "expert consultant"), already gated on three unbuilt dependencies, and engine-agnostic by design.
  The clauthier assessment measured agent context-load value, not canvas product value, so this RFP's NOTE should say graphify was dropped as an agent-tooling dependency, without implying the product thesis was refuted.
- Since these are cross-repo references, write the NOTE pointer as "clauthier `cdocs/reports/2026-10-08-graphify-weftwise-assessment.md`", matching the lace RFP's form, rather than a GitHub URL, because clauthier `main` is unpushed and the link would 404.
- **non-blocking:** `cdocs/devlogs/2026-09-15-code-graph-chain-checkpoint.md` (`live`, `done`) has a BLUF that says "graphify remains the default candidate".
  Once its forward RFPs are archived or deferred, `state: archived` is consistent, but leaving it is also fine.

### Verification Methodology

All floor commands are runnable.
At `761a407`, `npm run test:rules`, `chat-record.test.sh --unit` (98 passed), `validate-cdocs-edit-path.test.sh` (17 passed), and `scripts/detect-usage.test.sh` (11 passed) all pass.
`lace validate` exists with `--workspace-folder`.
I did not run `test:opencode` (it builds into `build/`) or `lace validate` (it may rewrite tracked `.lace/` state in `main`).
`test:rules` check 6 does catch a leftover `/cdocs:graphify` in its file set, which includes the plugin README, bin README, init SKILL, rules, and agents.

- **blocking:** clauthier step 5, `git grep -lE '^state: live' -- 'cdocs/*graphify*'`, can never return nothing.
  Run today, it matches `cdocs/proposals/2026-10-08-remove-graphify.md` and `cdocs/devlogs/2026-10-08-remove-graphify.md`, and after this commit it also matches `cdocs/reviews/2026-10-08-review-of-remove-graphify.md`, all of which are correctly live.
  An implementer chasing a zero result could wrongly archive this workstream's own docs.
  Add `':!cdocs/*remove-graphify*'` to the pathspec.
- **non-blocking:** clauthier step 1 uses an explicit pathspec list, while weftwise step 1 uses `':!cdocs'`.
  Use `git grep -il graphify -- ':!cdocs'` in clauthier too: it is the inventory's own command, and it also covers top-level files the list omits.
- **non-blocking:** step 4's "no `graphify/index` mount in its output" assumes `lace validate` prints mounts.
  If it does not, check `.lace/mount-assignments.json` and the generated `.lace/devcontainer.json` instead.

## Verdict

**Revise.**
The inventory and plan are sound and proportionate.
Three small blocking edits are needed: correct the claude-code rationale, fix the step 5 pathspec, and write the overseer's weftwise RFP disposition into Docs disposition and Phase 2.
After those edits, the proposal is ready to implement without another full review round.

## Action Items

1. [blocking] In Important Design Decisions, replace the claude-code rationale: both repos get claude-code from the host's lace `user.json` features (lace-fundamentals depends only on `git:1`), as both did before graphify.
2. [blocking] Clauthier Verification step 5: add `':!cdocs/*remove-graphify*'` so this workstream's live proposal, devlog, and review are excluded.
3. [blocking] Apply the plan of record for weftwise: archive `2026-09-15-code-graph-review-plugin-rfp.md` and defer the vellum-canvas and spike-comparison RFPs, each with a one-line NOTE pointing at clauthier `cdocs/reports/2026-10-08-graphify-weftwise-assessment.md`.
   Replace the closing Docs-disposition NOTE, and narrow Phase 2's "Do not touch" to the rest of the 09-14/15 chain.
   Word the canvas RFP's NOTE so it does not imply the product thesis was refuted.
4. [non-blocking] `.lace/` handling: commit only the `graphify/index` removal, and `git checkout --` any other `lace validate` rewrite of tracked `.lace/*.json`.
5. [non-blocking] Weftwise inventory: note the trailing comma on `aws-config` once `graphify-index` is deleted from `customizations.lace.mounts`.
6. [non-blocking] Clauthier Verification step 1: use `git grep -il graphify -- ':!cdocs'`, matching the inventory and weftwise.
7. [non-blocking] detect-usage row: say "tool names and the comments describing them".
8. [non-blocking] Trim the "Lingering MCP registration" edge case, since the host configs show no graphify server registered.
9. [non-blocking] Optionally archive weftwise `cdocs/devlogs/2026-09-15-code-graph-chain-checkpoint.md` alongside its RFPs.

## Questions for the Maintainer

1. `scripts/detect-usage.sh` was kept because the graphify-overhaul verification relied on it, and that consumer is now gone.
   - (a) Keep it with reworded fixtures, as proposed (default).
   - (b) Delete it and its test as part of this removal.
2. Should the weftwise code-graph chain checkpoint devlog be archived along with its RFPs?
   - (a) Leave it live (default; it is `done` and harmless).
   - (b) Archive it with the RFPs.
