---
review_of: cdocs/proposals/2026-10-08-delete-ablate-rfp.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T13:08:00-07:00
task_list: cdocs/delete-ablate
type: review
state: live
status: done
tags: [fresh_agent, runtime_validated, minimalism, ablation, error_handling]
---

# Review: Delete `/cdocs:ablate` implementation, round 1

> BLUF: Accept.
> `scripts/detect-usage.sh` keeps both jq filters byte-for-byte, and its output matches `ablate.sh detect-usage` on 24 real-transcript cases.
> No live `ablate` reference remains, and every floor check passes when I re-run it.
> The three findings are all non-blocking and each one removes lines.
> The most useful one is F1: drop `2>/dev/null` so that an invalid `cli:` regex or a malformed transcript shows an error and does not fail silently.

## Summary Assessment

The change deletes `/cdocs:ablate` (skill, script, untested-in-CI suite) and keeps `detect-usage` as a 60-line repo-internal script with its 11 checks, as the maintainer directed.
The implementation is faithful to the proposal: the jq filters are identical to `cmd_detect_usage`, the moved test body differs only in comments and one renamed section `echo`, and the reference edits are confined to the proposal's footprint.
All three reported deviations are justified.
I found no regression.
Every finding concerns behavior inherited from `ablate.sh`, or text that can be trimmed.
Verdict: **Accept**.

## Verification (re-run by this reviewer)

All runs used the `delete-ablate` worktree at `a9b0e57`.
Output is in `/tmp/claude-1000/-var-home-mjr-code-weft-clauthier-main/63ac45de-462d-4f43-ae1c-4ab6d59049b8/scratchpad/` (`du.txt`, `rules.txt`, `oc.txt`, `cr.txt`, `cg.txt`).

| check | result |
|---|---|
| `bash scripts/detect-usage.test.sh` | 11 passed, 0 failed, exit 0 |
| `npm run test:rules` | tests 18, pass 18, fail 0; `6. skill references` passes |
| `npm run build:cdocs && npm run test:opencode` | tests 9, pass 9, fail 0; `build/cdocs/opencode/skills/` lists 17 skills, none of them `ablate` |
| `chat-record.test.sh --unit` | 98 passed, 0 failed |
| `cdocs-graphify.test.sh` | 27 passed, 0 failed |
| `grep -rn ablate plugins scripts .github CLAUDE.md README.md` | empty (exit 1) |
| `git grep -n -i ablat -- ':!cdocs/'` | empty (exit 1); this covers tracked `.github/`, `package.json`, `plugins/cdocs/AGENTS.md`, both READMEs, `CLAUDE.md`, and the marketplace manifests |
| `grep -rni ablat build/` | empty |
| skill-count claims (`17`/`18 skills`) outside `cdocs/` | none to update |

**Ad hoc runs on real transcripts in `~/.claude/projects/`:**

- Positive, `-workspace-clauthier-main/4f66f771-.../subagents/agent-acf040b0af303b8b3.jsonl` (a Probe A arm with Bash `cd /tmp/ablate-e2e/probeA/arm-A && graphify explain ...`):
  - the graphify-overhaul signature `cli:(^|[ /])(cdocs-)?graphify (query|explain|path|affected|update) ` and `cli:^graphify ` each give `used`, so the caret anchor matches through the `cd` prefix;
  - `cli:^cdocs-graphify ` and `mcp__graphify__query` each give `unused`;
  - `Bash` gives `used`.
- Negative, `-var-home-mjr-code-weft-clauthier-main/63ac45de-.../subagents/agent-a77821f949bed4b47.jsonl` (a reviewer with 21 Bash `tool_use`s):
  - the transcript contains `cdocs-graphify` 8 times, in the user prompt, an attachment, assistant text, 4 tool results, and a `Write` input;
  - the graphify-overhaul signature gives `unused`, while `cli:^git ` and `Bash` each give `used`;
  - so prompt text, quoted reports, and non-Bash tool inputs are ignored, as the proposal requires.
- Parity: I ran `scripts/detect-usage.sh` and the base-commit `ablate.sh detect-usage` on 3 real transcripts (the two above plus the 3384-line top-level session) with 8 signatures (including `cli:(`, `Agent`, and the bare name `scope`).
  The two scripts give the same stdout and exit code in all 24 cases.
- Moved test body: I diffed lines 97-159 of `test-ablate.sh` (invocation normalized) against the new test.
  The only differences are the 6 comment hunks of deviation 1 and the section `echo`.
  The original `TEST 3` echo sat on line 96, outside the copied range.

## Section-by-Section Findings

### `scripts/detect-usage.sh`

The matching behavior is unchanged.
I confirmed this by reading the filters side by side against `ablate.sh` lines 143-176, by the 24-case real-transcript parity above, and by the implementer's 36-case fixture matrix.
The `case` loop that replaces the assoc-array `parse_args` is the right size.

**F1 (non-blocking, removes code): drop both `2>/dev/null` on the `jq` calls (lines 51 and 58).**
The suppression hides three failure modes that are inherited from `ablate.sh` (parity holds, so none of them is a regression):
- An invalid `cli:` regex (`cli:(`) prints `unused` and exits 0 with nothing on stderr.
  A typo in a signature therefore *passes* the graphify-overhaul "Overseer clean" check, which expects `unused`.
- A malformed or truncated last line exits 5 with no output and no message, even when an earlier line holds a matching call.
- A relative transcript path that starts with `-` exits 2 silently, because jq parses it as an option.
  Every directory under `~/.claude/projects/` starts with `-`, so this is easy to hit.
  My first survey loop hit it on all 33 files.

With the redirect removed, all three print the jq error on stderr.
The invalid-regex case still exits 0 with `unused`, but the error is now visible to the agent running the check.
I verified this on a scratch copy, and the 11 checks still pass.
Nothing on a valid-input path writes to jq's stderr, so the change adds no noise.

**F2 (non-blocking, removes text): drop the comments that restate the header.**
- Lines 47-48, inside the CLI filter, repeat header lines 16-18.
- The branch comments on lines 40 and 53 repeat header lines 13-15.

The header alone is enough.

**Deviation 2 (stricter argument errors, `detect-usage:` prefix): accept.**
The `$# -ge 2` guards are nearly redundant under `set -u`, which already exits 1 on an unbound `$2`, though with a less readable bash message.
They cost two short clauses, so keeping or dropping them is a matter of taste.
The new `[ -r "$t" ]` check and the dropped `ablate:` prefix are both correct.

> NOTE(claude-opus-5-5/cdocs/delete-ablate): `cli:` signatures also match text that is shell-quoted *inside* a Bash command, because the whole string is tested as a segment.
> For example, this round's implementer transcript (`agent-ac370311f4e370c33.jsonl`) reports `used` for the graphify-overhaul signature because a `printf` fixture contains `graphify update`.
> An overseer whose own Bash greps for that string would false-fail "Overseer clean".
> This is inherited, and the proposal fixes matching behavior as-is, so no change is requested.

### `scripts/detect-usage.test.sh`

The file is a faithful move: it locates itself, cleans up its scratch directory, and runs the 11 checks with assertions unchanged.
**Deviation 1 (8 reworded comment lines): accept.**
The rewording removes vocabulary that only made sense inside the deleted skill ("false VOID", "worktree-bound arms") without touching any assertion.
The rewording is history-agnostic, which is the right framing.

### Reference edits

- `oversee-workstream/SKILL.md`: the loop list reads ``(`/cdocs:iterate`, `propose-revise`, `full-send`, `oversee-many`)``.
  It reads cleanly, with no dangling comma and no orphaned conjunction.
- `CLAUDE.md` and `plugins/cdocs/README.md`: each is a one-entry removal, and the surrounding table and list are intact.
- `2026-09-27-clauthier-improvement-verification.md`: the NOTE sits directly under the BLUF.
  The BLUF bullet that names `/cdocs:ablate` as "the built efficacy harness" stays as written, which is correct: the history is NOTEd, not edited.

### `2026-10-08-graphify-overhaul.md` NOTE

**Deviation 3 (NOTE after step 5): accept.**
Putting a blockquote between list items 4 and 5 would split the numbered list.
After step 5 is the nearest point that keeps the list intact.
The NOTE also covers the stale `bash plugins/cdocs/skills/ablate/ablate.sh detect-usage` path in step 4.

**F3 (non-blocking, removes text): drop the NOTE's second line, "The step text above stays as written."**
A NOTE never rewrites the text it annotates, so the line states the convention rather than adding information.

The proposal's other `/cdocs:ablate` mentions (lines 43-44, 253, 382-397, 437) belong to the historical Ablation-run record and to the "Do not change" scope lines.
They stay as written, which matches the proposal's footprint.

### Devlog

`2026-10-08-delete-ablate-impl.md` is accurate.
I reproduced each of its floor claims.
The deviations are surfaced in the BLUF and in a NOTE, and the "not wired into CI" gap is called out as `unverified`.
I have no findings on the devlog.

## Verdict

**Accept.**
No action item is blocking.
F1 is the one I would apply before landing: it removes code and closes a silent false-pass path in the only check that consumes this script.

## Action Items

1. [non-blocking] `scripts/detect-usage.sh` lines 51 and 58: remove `2>/dev/null` from both `jq` calls, so that an invalid regex, a malformed line, or an option-like path reports on stderr.
2. [non-blocking] `scripts/detect-usage.sh`: delete the comment lines that restate the header (40, 47-48, 53).
3. [non-blocking] `cdocs/proposals/2026-10-08-graphify-overhaul.md`: delete the NOTE line "The step text above stays as written."

## Questions for the Maintainer

1. Apply F1-F3 before landing?
   - (a) Yes, all three: one small commit, which removes 5 lines and edits 2.
   - (b) F1 only: it is the only finding with behavioral value.
   - (c) None: land as is, since the inherited behavior is documented here.
