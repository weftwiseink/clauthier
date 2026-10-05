---
review_of: cdocs/devlogs/2026-10-05-oversee-haiku-bash-wrapper.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T14:19:52-07:00
task_list: meta/token-spend-attribution
type: review
state: live
status: done
tags: [fresh_agent, verification, bash_runner, portability, mktemp, proposal_sync, small_fixes]
---

# Review: Bash Runner Small Fixes (`3b32ae4`, `0464785..734ef1f`)

> BLUF(opus-5-5/bash-runner-small-fixes-review): Every fix from review `299394a` is applied as asked, keeps the maintainer's wording, and leaves the runner loose.
> One defect remains: the `mktemp` template ends in `.log`, and BSD/macOS `mktemp` randomizes only trailing X's.
> On macOS, the first run creates a file literally named `bash-runner-XXXXXX.log`, and every later run fails with `File exists`.
> The fix is one line: `mktemp "/tmp/claude-$(id -u)/bash-runner.XXXXXX"`.
> Verdict: **Revise** (one-line fix plus the matching proposal line; no re-review needed).

## Summary Assessment

This round applies review `299394a` items 1 and 4-10 to the maintainer's loosened `bash-runner` rewrite (`6821b43`).
The changes are a fresh `mktemp` capture, typo fixes, renamed-heading pointers, a timeout hint, linear dedupe idioms, a caller-guidance clarification, a byte count in place of a word count, and a sync of the proposal.
The changes are small, accurate and faithful to the rewrite, the build passes, and the implementer's Linux canary shows the new capture working (17/17 exact, fresh file, `>`).
The one major finding is portability: the `.log` suffix after the X's defeats BSD `mkstemp`.
`-p` itself exists in current macOS `mktemp`.

## Findings

### 1. Fix fidelity (check 1)

- **OK.** `0464785`: all seven typos in item 4 are fixed (`cdcos:`, "You known", "if it more", the comma, "Alwyas", `"...">`, "anything unexpected"), and the trailing newline is added.
  The maintainer's "When dispatching commands" stays as written, which matches the brief.
- **OK.** `5637323`: `AGENTS.md:47` and `model-tiering.md:25` now name the current heading, and `grep` finds no "Bash Output Hygiene" or `cdcos` anywhere in `plugins/cdocs`.
- **OK.** `9e86779` adds one sub-line under step 1, and `59c08ac` makes the `Output:` field `bytes:`.
  Both are minimal changes.
- **OK.** `62c6c38` extends the maintainer's own sentences instead of restructuring them, and the three-case layout is intact.
- **Nit.** `62c6c38` reads "Similar patterns can also be used for interactive or tty-dependent commands, which are not dispatched".
  The parent's Bash tool has no TTY either, so "similar patterns" helps only for commands that have a non-interactive mode.
  This is maintainer wording and is left as is.

### 2. The `mktemp` line (check 2)

- **Major (blocking): the `.log` suffix breaks uniqueness on BSD/macOS.**
  Apple's `shell_cmds/mktemp/mktemp.c` creates the file with `mkstemp(name)`, not `mkstemps`.
  Libc's `find_temp_path` replaces only X's at the very end of the name (`while (trv >= path && *trv == 'X')`, with `slen = 0`).
  With `bash-runner-XXXXXX.log`, no X is replaced: the first run creates the literal `bash-runner-XXXXXX.log`.
  Each later run, and each concurrent run, then fails with `EEXIST`, so `out` is empty and `cmd > "$out"` fails.
  The runner model would probably improvise a filename, which brings back the unguided shared-name pattern that `3b32ae4` fixed.
  This was verified from source, not run, because no BSD host is available.
  GNU `mktemp` (coreutils 9.10) treats a trailing non-X part as an implied `--suffix`, so the Linux canary could not catch this.
  Fix: `out=$(mktemp "/tmp/claude-$(id -u)/bash-runner.XXXXXX")`.
  A full-path template with trailing X's and no `-p` works the same on GNU, on BSD/macOS of any release, and on busybox.
  Make the same change at proposal `:142`.
- **Non-blocking: `-p` on macOS.**
  Current Apple `shell_cmds` has `-p tmpdir`/`--tmpdir` (getopt `"dp:qt:u"`), and without `-t` it prepends tmpdir to the template (`"%s/%s"`).
  Older macOS releases did not have it ([ohmyzsh#7803](https://github.com/robbyrussell/oh-my-zsh/issues/7803)).
  The fix above avoids `-p` entirely.
- **OK: `id -u`** is POSIX and works on both platforms.
- **OK: missing directory.**
  GNU `mktemp -p <missing>` fails with "No such file or directory" (tested), so the "(create the directory if missing)" clause matters, and it is in place.
  Files that `mktemp` creates are mode 0600 whatever the directory's mode.

### 3. Dedupe idioms (check 3)

- **OK.** Both idioms are linear and correct.
  `awk '!seen[$0]++'` keeps the first occurrence of each line in order (`a b a c b` gives `a b c`), and the normalising pipeline ran on a 1,054-line sweep in 0.02s.
- **Nit.** `s/[0-9]+/N/g` also normalises digits in path prefixes.
  On a `grep -rn` sweep over dated files it merges different files into one shape, for example `cdocs/reviews/N-N-N-review-of-...-rN.md:N:type: review`.
  The idiom is offered for noise removal and the capture keeps the originals, so this is harmless.
  Optionally, normalise after `cut -d: -f3-` when per-file identity matters.

### 4. Proposal sync (check 4)

- **OK.** The BLUF, input and output contracts, workflow, capture edge case, test plan, Phases 1-2 and the capture-location decision all match the current agent and rules.
  No stale "Bash output hygiene", scratchpad, `${TMPDIR}`, 24h-prune or ~12K-allowance text remains, and the `impl-3` NOTE is a correctly dated history entry.
- **Non-blocking: dangling parenthetical at `:186`.**
  "(Self-bounding is refined by the completeness-first NOTE above: a known-need command is captured to a file ...)" points at item (3) of that NOTE's "Defaults chosen", which this sync removed.
  Drop the parenthetical, or point it at the rules "Bash" section, case 1.
- **Non-blocking: leftover fixture rationale at `:308`.**
  "The no-spec run uses a fixture whose failure list exceeds the ~4K default ... at 17 failures a no-spec regression is invisible."
  This justified the dropped no-spec complete-list rule, which went past ~4K.
  Under a names-only bar, 45 test names fit comfortably under 4K.
  Either keep the 45-failure fixture as a stress case and say so, or simplify the sentence.
- **Nit: "exactly the `BASH RUNNER REPORT` structure" at `:299`** sits awkwardly beside `:165` ("A requested list may go in a labelled section of its own").
  "contains the structure" or "at least these fields" would remove the tension.
- **Opinion on the names-only no-spec bar: consistent, keep it.**
  The rewrite moves locations and values onto the caller ("say 'every' if needed"), so the old name-plus-location bar would test a contract the agent no longer states.
  For a test run, naming the failing tests is the minimum reading of the agent's "flag critical info like errors".
  It is also the regression the quality canary caught: totals only, so the caller has to follow up to learn which tests failed.
  In the rewrite canary, C2 met this bar unprompted.
  The bar is slightly stricter than the literal agent text, so record it as an inferred expectation.
  If a future no-spec run returns totals only, the fix is to tighten "flag critical info", not to restore the old rules.

### 5. Build (check 5)

- **OK.** `npm run build:cdocs` exits 0 with `Agents converted: 7`, and the only warning is Node `DEP0205`.
  The OpenCode `description: |` is still empty, which is out of scope and covered by its own RFP.
  The plugin files at HEAD (`e086373`) are identical to `734ef1f` for the runner, and the intervening commits touch only chat-record.

### Not updated: `last_reviewed`

The subject is a commit range across plugin files and a devlog section, and the brief limits edits to this review file, so no document's `last_reviewed` was updated.

## Verdict

**Revise.**
Everything except the `mktemp` template is ready to accept.
The template change is one line in `bash-runner.md` plus proposal `:142`, and a confirming `grep` is enough to verify it, without another review round.

## Action Items

1. [blocking] `agents/bash-runner.md` step 1 and proposal `:142`: replace `mktemp -p "/tmp/claude-$(id -u)" bash-runner-XXXXXX.log` with `mktemp "/tmp/claude-$(id -u)/bash-runner.XXXXXX"`, keeping "(create the directory if missing)".
2. [non-blocking] Proposal `:186`: drop or re-point the "refined by the completeness-first NOTE" parenthetical.
3. [non-blocking] Proposal `:308`: reword the "exceeds the ~4K default" fixture rationale for the names-only bar.
4. [non-blocking] Proposal `:299`: soften "exactly the ... structure" to allow labelled list sections.
5. [non-blocking] Optional: note in the dedupe idiom that digit normalisation also merges path prefixes.
