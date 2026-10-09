---
review_of: cdocs/devlogs/2026-10-08-remove-graphify-impl.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T17:47:42-07:00
task_list: cdocs/remove-graphify
type: review
state: live
status: done
tags: [fresh_agent, implementation, floor_rerun, devcontainer, cleanup, archival]
---

# Review: Remove Graphify Implementation (iterate round 1)

> BLUF: Accept.
> I re-ran the full floor in both worktrees (clauthier `4d261d3`, weftwise `e4d54915`) and every step passes, matching the devlog's numbers.
> Both `devcontainer.json` files are byte-identical to their pre-graphify commits, and each removal commit is the exact inverse of the single graphify commit since, so nothing unrelated was reverted.
> Nothing outside the inventory changed, the archived set matches the Docs disposition exactly, and the implementer's two lace findings need no action in this workstream.
> Non-blocking: one miscount in the devlog, two NOTEs that slightly overstate, a plural/singular mismatch in `bin/README.md`, and clauthier `main` has moved one commit (conflict-free rebase needed before the ff-merge).

## Summary Assessment

The work removes every graphify surface from clauthier and weftwise per `cdocs/proposals/2026-10-08-remove-graphify.md` and archives the graphify records.
The implementation is tight: 5 clauthier code commits plus 2 archival commits, 4 weftwise commits, each scoped by explicit path to one logical unit, and the devlog is accurate except for one count.
The most important findings are positive: the devcontainer restorations are provably exact, and the implementer's "stale lace mount assignments are listed but not rendered" claim, which had no saved artifact, holds when I reproduce it.
Verdict: **Accept**.

## Floor Re-run

All commands run by me this round; outputs in `/tmp/claude-1000/-var-home-mjr-code-weft-clauthier-main/63ac45de-462d-4f43-ae1c-4ab6d59049b8/scratchpad/rev/` (`c-greps.txt`, `w-greps.txt`, `c-lace.txt`, `w-lace.txt`, `w-lace-stale.txt`, per-suite `*.log`).

Clauthier, at `4d261d3`:

| Step | Result |
|---|---|
| 1. `git grep -il graphify -- ':!cdocs'`; `git ls-files \| grep -i graphify` outside `cdocs/` | both empty (rc=1) |
| 2. `git grep -n base_query -- plugins` (also repo-wide outside `cdocs/`) | empty |
| 3. `npm run test:rules` | 18 pass, 0 fail |
| 3. `npm run test:opencode` (runs `build:cdocs`) | 9 pass, 0 fail |
| 3. `npm run build:cdocs` standalone | exit 0; zero `graphify` files or text under `build/cdocs/opencode/` |
| 3. `chat-record.test.sh --unit` | 98 passed, 0 failed |
| 3. `validate-cdocs-edit-path.test.sh` | 17 passed, 0 failed |
| 3. `detect-usage.test.sh` | 11 passed, 0 failed |
| 4. `lace validate --workspace-folder <worktree>` | "Validation passed."; only graphify text is the worktree name; `.lace/mount-assignments.json` has 0 graphify lines; claude-code mounts still injected (host `user.json`) |
| 5. `git grep -lE '^state: live' -- 'cdocs/*graphify*' ':!cdocs/*remove-graphify*'` | empty |
| extra: `.github/workflows/cdocs-hooks.yml` parses (node `yaml`); `.lace/mount-assignments.json` parses (`jq`) | ok |

`lace validate` rewrote tracked `.lace/port-assignments.json` (sshPort 22431 to 22435) as the devlog warns; I restored it with `git checkout --`, and the worktree is clean apart from the untracked `node_modules` symlink.

Weftwise, at `e4d54915`:

| Step | Result |
|---|---|
| 1. shipped-path grep and `ls-files` (and `base_query`) | empty |
| 2. `lace validate --workspace-folder <worktree>` | "Validation passed."; only graphify text is the worktree name (stale-worktree and `relativeworktrees` warnings are pre-existing and unrelated) |
| 3. `git diff main -- .devcontainer/Dockerfile` | 0 lines |
| archival self-check (r2 review grep) | empty |
| `cdocs/*graphify*` live anywhere | empty |
| spike-comparison and vellum-canvas RFPs | `state: deferred` |

Host: `~/.claude.json` registers no graphify MCP server (its one mention is a `projects[...].exampleFiles` entry).

## Section-by-Section Findings

### Devcontainer restorations

- **Clauthier.** `cmp` of `git show 041b1f6:.devcontainer/devcontainer.json` against HEAD is identical.
  `git log 041b1f6^..HEAD` on the file lists only `041b1f6`, `060e392` (graphify), and `7795db9` (removal), and `diff` of `git diff 041b1f6 060e392` against `git diff 7795db9 7795db9^` is empty: the removal is the exact inverse, so no unrelated change was reverted.
  Non-blocking context: `041b1f6` is itself a substantive commit (prebuildFeatures migration), but restoring to it is correct because it is the base, not something undone.
- **Weftwise.** Identical to `add5bd2b^`; `add5bd2b` is the only commit on any ref touching the file after `add5bd2b^`, it adds only graphify, claude-code, the `graphify-index` mount, the two comment lines, and `GRAPHIFY_OUT`, and `726e07f5` is its exact inverse.
  The Dockerfile is untouched (`a61e8e6a` pnpmfile fix survives).

### Clauthier inventory (Phase 1)

- The 19 changed non-`cdocs/` paths are exactly the 18 inventory rows (detect-usage covers two files); no other path changed.
- `detect-usage.sh` changes are comment-only; the test's changes are fixture strings and labels, and 11/11 checks pass, including the bare-name `--tool scope` match against `mcp__example__scope`.
  Behavior is unchanged.
- No dangling references: no "Base query" heading, `[base_query:` tag, or init "step 7" reference remains in `plugins/`; init's numbered steps now end at 6.
- **Non-blocking:** `plugins/cdocs/bin/README.md` BLUF reads "Runtime commands Claude Code puts on the Bash tool's `PATH` ... OpenCode does not ship it."
  The plural subject and singular "it" disagree now that one command remains.
  The proposal dictated "OpenCode does not ship it", and the devlog flags this, so it is not an implementation deviation; a follow-up could read "The runtime command Claude Code puts on the Bash tool's `PATH` ...".

### Weftwise inventory (Phase 2)

- Changed paths: `devcontainer.json`, `.graphifyignore`, and 10 `cdocs/` records; nothing else.
- Archived: the six graphify-devcontainer-feature records, the review-plugin RFP, and the checkpoint devlog (8); deferred: the spike-comparison and vellum-canvas RFPs (2).
  Each edit is the one-line `state` change plus, for the three RFPs, a NOTE under the BLUF.

### Clauthier archival (Phase 3)

- Excluding the impl devlog and this workstream's proposal (its `implementation_ready` to `implementation_wip`), the `cdocs/` diff is exactly 35 `-state: live`/`+state: archived` pairs plus the assessment proposal.
- Every `cdocs/*graphify*` record that was `live` at `0853e2f` changed, and every one not changed was already archived (`2026-09-17-graphify-cdocs-integration.md`, the two overseer-owned top-level devlogs) or is `_media/` without frontmatter.
  `status` is untouched everywhere except the assessment proposal (`evolved`).

### NOTE wording

- **Assessment proposal NOTE (non-blocking).** "Phases 1-4 are done" slightly overstates Phase 4: the assessment's top-level devlog records Phase 4's fixes as `review_ready` with "Phase 4 re-review folded into Phase 5", which was then abandoned.
  Suggest "Phases 1-4 are implemented (Phase 4's re-review was folded into Phase 5)".
- **Review-plugin RFP NOTE (non-blocking).** It says clauthier "removed it after its assessment ... found graph-assisted agents did not reliably beat grep-only agents and came no cheaper."
  The quoted finding is accurate to the report's BLUF, but the sentence reads as if the finding caused removal, while the same BLUF recommends "Startup and reviewers: use now", reviewers being this RFP's exact consumer.
  The devlog's own NOTE says removal was the maintainer's upkeep call; the RFP NOTE would be fairer naming that, e.g. "... and removed it at maintainer direction on upkeep cost; its assessment (...) found ...".
- **Spike-comparison NOTE:** accurate; the RFP's BLUF names the build targets #3 (adapter) and #4 (review plugin), and with #4 archived only #3 remains.
- **Canvas NOTE:** scoped to agent-context value, as r1/r2 required.

### Impl devlog

- Accurate in substance: every claim in Verification reproduces, and the Phase 3 numstat (+39 -37 over 36 files) checks out.
- **Non-blocking:** Changes Made says weftwise "10 records | 7 archived, 2 deferred"; it is 8 archived (6 feature records + review-plugin RFP + checkpoint devlog), consistent with the Phase 2 commit notes.
- **Non-blocking:** Scratchpoint's "Clauthier `main` was still at `0853e2f` ... so no rebase was needed" is now stale: `main` has `0c7c4e7` (overseer devlog only).
  `git merge-tree --write-tree main HEAD` reports no conflicts, so the overseer's planned rebase is trivial.

### Implementer findings: action needed?

- **Weftwise `main/.lace/mount-assignments.json` stale entries.** I confirmed read-only that weftwise `main/.lace/mount-assignments.json` (gitignored) holds `project/graphify-index` and `graphify/index`.
  To test the "listed but not rendered" claim, I injected those two entries into the throwaway worktree's gitignored `.lace/` state (backed up first) and re-ran `lace validate`: the entries appear under resolved sources ("using default path ..."), persist (lace does not prune them), and the generated `.lace/devcontainer.json` and `resolved-mounts.json` contain no graphify mount.
  I then restored the backup; the worktree is clean.
  So the entries are cosmetic noise in `lace validate` output and need no action in this workstream.
  Weftwise `main/.lace/devcontainer.json` still has graphify lines only because `main` is still pre-merge; the first `lace up` after landing regenerates it.
- **Clauthier `lace validate` rewriting tracked `.lace/port-assignments.json`.** Cause: the running `clauthier` container holds host port 22431 (`podman ps`: `clauthier 0.0.0.0:22431->22431/tcp`), so `lace validate` in a sibling worktree finds the port busy and reassigns `lace-fundamentals/sshPort`.
  This predates graphify and is unrelated to it; the restore-after-validate rule handles it, and nothing graphify-related was committed to that file.
  No action here; it is a candidate lace issue (validate should not persist a reassignment of a port held by the same project's own container, or the file should not be tracked).

## Verdict

**Accept.**
The implementation meets every success criterion in Phases 1-3, the floor reproduces, and no blocking issue was found.

review_proof: `confirmed`. I re-ran the whole floor in both worktrees this round and cite the outputs I produced under `/tmp/claude-1000/-var-home-mjr-code-weft-clauthier-main/63ac45de-462d-4f43-ae1c-4ab6d59049b8/scratchpad/rev/`.

## Action Items

1. [non-blocking] Impl devlog Changes Made: weftwise `cdocs/` row should read "8 archived, 2 deferred".
2. [non-blocking] Overseer: rebase `remove-graphify` onto `main` (`0c7c4e7`, conflict-free) before `git merge --ff-only`; the Scratchpoint "no rebase was needed" note is stale.
3. [non-blocking] Assessment proposal NOTE: qualify "Phases 1-4 are done" with Phase 4's re-review being folded into the abandoned Phase 5.
4. [non-blocking] Weftwise review-plugin RFP NOTE: name the maintainer's upkeep call as the reason for removal (see question 1).
5. [non-blocking] `plugins/cdocs/bin/README.md` BLUF: make subject and pronoun agree ("The runtime command ... OpenCode does not ship it").
6. [non-blocking] Maintainer, after landing: optionally delete the two graphify entries from weftwise `main/.lace/mount-assignments.json`; they are cosmetic.

## Questions for the Maintainer

1. Review-plugin RFP NOTE wording:
   - (a) Keep as is (the quoted finding is accurate).
   - (b) Reword to lead with the maintainer's upkeep decision, citing the finding as context. (Recommended.)
2. lace does not prune mount assignments whose declaration is gone, so every project that drops the graphify feature keeps stale `graphify/index` lines in `lace validate` output:
   - (a) Add it as an edge case to lace `cdocs/proposals/2026-10-08-delete-graphify-feature-rfp.md`. (Recommended: that RFP's consumers all hit it.)
   - (b) File a separate lace RFP for assignment pruning generally.
   - (c) Ignore; delete entries by hand when noticed.
3. Clauthier's tracked `.lace/port-assignments.json` is rewritten by `lace validate` in any sibling worktree while the main container runs:
   - (a) Leave as is; restore after each validate.
   - (b) Raise a lace issue so validate does not persist reassignment of a port held by the project's own container.
   - (c) Untrack the file in clauthier.
