---
first_authored:
  by: "@claude-opus-4-6"
  at: 2026-03-19T15:30:00-07:00
task_list: ad-hoc/investigation
type: report
state: live
status: complete
tags: [investigation, claude-code, resume, bare-worktree, fedora-silverblue]
---

# Claude Code `/resume` "No conversations found" on Bare Worktree Repos

> BLUF: The `/resume` command fails with "No conversations found" because `git worktree list --porcelain` reported the worktree path as `.bare/main` instead of `./main` (a stale/corrupted worktree registration). Claude Code's session discovery uses worktree paths to locate project directories, and the wrong path produced a directory name that didn't match any existing session storage. The fix is `git worktree repair` -- the `/home` vs `/var/home` symlink was a red herring.

## Context / Background

On Fedora Silverblue, `/home` is a symlink to `var/home`. The user's repo at `/var/home/mjr/code/weft/clauthier/main` uses a "bare worktree" layout (bare repo at `.bare/`, worktree checkout at `./main/`). Claude Code 2.1.47 wrote session JSONL files to the correct project directory (`~/.claude/projects/-var-home-mjr-code-weft-clauthier-main/`) but `/resume` consistently reported "No conversations found to resume."

The user created `sessions-index.json` files in both the `-var-home-mjr-...` and `-home-mjr-...` path variants, but neither helped. This investigation traced the exact code path to identify the root cause.

## Key Findings

### 1. The `/home` vs `/var/home` symlink is NOT the problem

Claude Code initializes `originalCwd` via `fs.realpathSync(process.cwd())`, which consistently resolves through the `/home -> var/home` symlink. Both session file writes and session discovery use the same resolved path. The `-home-mjr-` project directory variant was unnecessary.

### 2. `sessions-index.json` is NOT used by `/resume`

The `/resume` slash command does **not** read `sessions-index.json`. It discovers sessions by scanning project directories for `.jsonl` files using `readdirSync`. The `sessions-index.json` file is written as a separate concern (possibly for the `--resume` CLI flag or other features), so manually creating it has no effect on the `/resume` slash command.

### 3. The root cause is a stale git worktree registration

The bare worktree layout had a corrupted worktree path. `git worktree list --porcelain` reported:

```
worktree /var/home/mjr/code/weft/clauthier/.bare        (bare)
worktree /var/home/mjr/code/weft/clauthier/.bare/main    (prunable)
```

The second path is wrong -- the actual checkout is at `./main`, not `.bare/main`. The `prunable gitdir file points to non-existent location` warning was the clue. The gitdir file at `.bare/worktrees/main/gitdir` contained `../../main` (relative to `.bare/worktrees/main/`), which resolves to `.bare/main` -- but the checkout files are at `clauthier/main/`.

### 4. How Claude Code's `/resume` discovers sessions (traced from source)

The complete code path, deobfuscated from the bundled `cli.js` (12,183 lines of minified JS):

```
/resume command
  -> hsY component (React)
    -> Yl(CA())           # Get worktree list for current directory
    -> aV1(worktrees)     # Load sessions for those worktrees
      -> OOq(worktrees)   # Core session discovery
```

**`CA()`** returns `originalCwd`, set at startup via `realpathSync(process.cwd())`.

**`Yl(cwd)`** runs `git worktree list --porcelain`, extracts worktree paths, identifies which one matches the current directory, and returns the list (current first, then others sorted).

**`OOq(worktrees)`** has two branches:
- **Single project** (`worktrees.length <= 1`): Uses `cwd` directly to construct the project directory path. Simple and reliable.
- **Multi-worktree** (`worktrees.length >= 2`): Converts each worktree path to a project directory name via `Jx()` (replaces non-alphanumeric chars with `-`), then scans `~/.claude/projects/` for matching directories.

The multi-worktree matching uses: `dirName === pattern || dirName.startsWith(pattern + "-")`

### 5. The mismatch that caused the failure

With the stale worktree registration:

| Component | Value |
|-----------|-------|
| `CA()` (current dir) | `/var/home/mjr/code/weft/clauthier/main` |
| Worktree path from git | `/var/home/mjr/code/weft/clauthier/.bare/main` |
| Jx(worktree path) | `-var-home-mjr-code-weft-clauthier--bare-main` |
| Actual project dir | `-var-home-mjr-code-weft-clauthier-main` |

The pattern `-var-home-mjr-code-weft-clauthier--bare-main` does not match the actual directory `-var-home-mjr-code-weft-clauthier-main` (note the `--bare` in the wrong one). Result: zero sessions found.

### 6. The fix: `git worktree repair`

Running `git worktree repair` from the worktree directory corrected the gitdir file:

- **Before:** `.bare/worktrees/main/gitdir` contained `../../main` (resolves to `.bare/main`)
- **After:** `.bare/worktrees/main/gitdir` contains `../../../main/.git` (resolves to `clauthier/main/.git`)

Post-repair, `git worktree list` reports the correct path:

```
worktree /var/home/mjr/code/weft/clauthier/.bare         (bare)
worktree /var/home/mjr/code/weft/clauthier/main           [main]
```

Now `Jx("/var/home/mjr/code/weft/clauthier/main")` produces `-var-home-mjr-code-weft-clauthier-main`, which matches the existing project directory exactly.

## Detailed Analysis

### Session File Write Path (works correctly)

When Claude Code starts a session, it computes the project directory from `CA()`:
1. `CA()` = `realpathSync(process.cwd())` = `/var/home/mjr/code/weft/clauthier/main`
2. `Jx(CA())` = `-var-home-mjr-code-weft-clauthier-main`
3. Session file written to `~/.claude/projects/-var-home-mjr-code-weft-clauthier-main/<uuid>.jsonl`

This path does NOT involve `git worktree list`, so sessions are always written to the correct directory regardless of worktree state.

### Session File Read Path (was broken)

When `/resume` runs, the path diverges:
1. `Yl(CA())` runs `git worktree list --porcelain` and parses the output
2. Two worktrees found (bare + main) -> multi-worktree code path
3. Each worktree path is converted to a project directory pattern via `Jx()`
4. `~/.claude/projects/` is scanned for matching directories
5. With the wrong worktree path, no directory matches -> "No conversations found"

### Why the old clauthier dir appeared to work

The user reported that sessions from `-var-home-mjr-code-weft-clauthier/` showed up for `/resume`. This is likely a pre-worktree-setup memory: the `sessions-index.json` in that directory was last modified on Jan 30, 2026, while the bare worktree setup was created on Mar 18, 2026. Before the worktree conversion, the repo was a normal git repo and `/resume` would have used the single-project code path (no worktrees -> `length <= 1`), which works correctly.

### Source code locations (for future reference)

All in `/var/home/linuxbrew/.linuxbrew/lib/node_modules/@anthropic-ai/claude-code/cli.js`:

| Function | Offset | Purpose |
|----------|--------|---------|
| `_l8()` | ~30304 | Initializes `originalCwd` via `realpathSync(cwd())` |
| `CA()` | ~32426 | Returns `originalCwd` |
| `Jx()` | ~614992 | Converts path to project directory name |
| `Yl()` | ~9734864 | Runs `git worktree list`, returns worktree paths |
| `OOq()` | ~10512657 | Core session discovery (single vs multi-worktree) |
| `Cc6()` | ~10519485 | Reads session entries from a project directory |
| `Dc6()` | ~10515082 | Scans directory for `.jsonl` files |
| `hsY()` | ~9813687 | React component for `/resume` UI |

## Recommendations

### Immediate (done)

1. **`git worktree repair` has been run** and the worktree now reports the correct path. `/resume` should work on the next invocation.

### Cleanup

2. **Delete the unnecessary `-home-mjr-` directory:** `rm -rf ~/.claude/projects/-home-mjr-code-weft-clauthier-main/`. This directory was created as a debugging attempt and contains only a `sessions-index.json` copy. The JSONL files live in the `-var-home-` variant.

### Preventive

3. **Add `git worktree repair` to the bare worktree setup script.** The bare worktree layout (popularized by [nikitabobko's blog post](https://nikitabobko.github.io/blog/git-worktree)) can produce stale gitdir references if the worktree directory is moved or if the initial setup doesn't follow git's expected conventions. Running `git worktree repair` after setup or after moving directories is a good practice.

4. **Consider filing a Claude Code issue** about the asymmetry between session write path (uses `cwd` directly) and session read path (uses `git worktree list`). When worktree metadata is stale, writes succeed but reads fail silently. A fallback to the `cwd`-based directory when the worktree-based scan finds nothing would make this more robust.

5. **The `sessions-index.json` red herring is worth noting.** The file exists in every project directory but is not used by `/resume`. If Claude Code documented what it's used for, debugging would be faster. Its `originalPath` field suggests it was designed for cross-project resume scenarios, but the actual `/resume` code doesn't reference it.
