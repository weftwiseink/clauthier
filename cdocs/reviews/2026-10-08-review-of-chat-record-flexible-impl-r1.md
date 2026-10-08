---
review_of: cdocs/proposals/2026-10-08-chat-record-flexible.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T09:55:00-07:00
task_list: cdocs/chat-record-flexible
type: review
state: live
status: done
tags: [fresh_agent, runtime_validated, implementation_review, chat_record, hooks, test_plan]
---

# Review: Flexible Chat Records Implementation (Round 1)

> BLUF: Accept, `review_proof: confirmed`.
> I re-ran the floor myself at `fa9523e`: unit 126/0, `--only init_real` 135/0, rules 11/0, headless `rename_record|path_mode|payload_shape` 12/0, plus two headless runs of my own (a `--name` session that calls `chat-record path`, and a stream-json `/rename` with `path` in both turns).
> The `session_title` deviation is correct and minimal.
> In claude 2.1.293, `session_title` is the in-memory custom title, set only where `custom-title` is written, and never an `ai-title`.
> Accepting a split first turn would orphan an unsigned `@user` in every `--name` session.
> No blocking items.
> Five non-blocking items, four of which remove text.

## Summary Assessment

The work (commits `c5fe184..fa9523e` on `13edf08`, branch `chat-record-flexible`) implements both halves of the proposal: free-form notes, and records named by the slugged session name, where a rename starts a new record.
The script changes are small and match the proposal's code almost verbatim.
`slug` is factored out, `session_token` reuses the computed name, and `hook_prompt` falls back to `session_title` in one line.
The implementer's devlog is accurate: every count and behavior I re-checked held.
The `init_real` count differs only because I ran it at a later commit (135 = 126 unit + 9, against their 132 = 123 + 9 at `da96bea`).
The rule text matches the maintainer's spec.
The test suite grew by 31 assertions for roughly six behaviors, with about three duplicates: not materially padded.

## Evidence (reviewer-produced)

All files are under the scratchpad `/tmp/claude-1000/-var-home-mjr-code-weft-clauthier-main/63ac45de-462d-4f43-ae1c-4ab6d59049b8/scratchpad/`.
HEAD is `fa9523e`, claude is 2.1.293.

| check | result | artifact |
|---|---|---|
| `chat-record.test.sh --unit` | 126 passed, 0 failed | `unit.txt` |
| `chat-record.test.sh --only init_real` | 135 passed, 0 failed | `init_real.txt` |
| `npm run test:rules` | 11 pass, 0 fail | `rules.txt` |
| headless `--only 'rename_record\|path_mode\|payload_shape'`, `CHAT_RECORD_KEEP=1` | 12 passed, 0 failed | `headless.txt`, sandbox `chat-record-test.tIGJL9/` |
| own `--name "Review Check: R1"` run, `path` then a multi-line prose note; then `--resume --fork-session` | one record `…-review-check-r1-<sid>.md` holding the whole first turn; `path` printed that exact file mid-turn; body byte-exact (`True`); the fork carries the `custom-title` and writes `…-review-check-r1-<fork-sid>.md`, fully signed | `own_check.sh`, `own_check.txt`, `own/` |
| own stream-json run: turn 1, `/rename Renamed Later`, turn 2, each turn running `path` | `path` printed `<date>-<sid>.md` in turn 1 and `<date>-renamed-later-<sid>.md` in turn 2, matching where the hooks wrote; old record untouched after the rename; prose notes unchanged | `own_rename.sh`, `own_rename.txt` |

Canary payloads from the kept sandbox show `session_title` on `UserPromptSubmit` only, on every prompt of a named session (`"First Name"`, `"Other"`, `"Second Name"`), and absent while the session is unnamed.

These runs cover each check the overseer asked for:
- A rename starts a new session-named record, and the old one is untouched.
- The first turn of a `--name` session lands entirely in the named record.
- `chat-record path` agrees with where the hooks write.
- Free-form notes are accepted unchanged.

## Section-by-Section Findings

### The `session_title` deviation (`a8c33ba`)

**Correct.**
The implementer's probe holds up: in my runs, the first `UserPromptSubmit` of a `-p --name` session reaches the hook before the transcript exists, and `session_title` carries the `--name` value.

**Can `session_title` carry an auto-generated title?**
No, not in 2.1.293.
I read the bundled CLI to check:
- The `UserPromptSubmit` input is built as `session_title: cm(session.id)`.
- `cm` returns `currentSessionTitle`.
- That field is assigned only by `saveCustomTitle`, which appends a `custom-title` line, and by restore from `customTitle`.
- `saveAiGeneratedTitle`, including the bridge's `"auto"` naming source, writes an `ai-title` line and sets a separate `currentSessionAiTitle`.

The fallback also applies only while no transcript exists, so it could not pick up a later rename that diverges from the transcript.

One residual path exists: a hook that returns `sessionTitle` is cached into `currentSessionTitle` (`"Hook sessionTitle cached"`) before it is applied as a `custom-title`.
For that one first prompt, `session_title` could get ahead of the transcript.
No cdocs hook returns `sessionTitle`, so this is a note only, with no action.

**Minimal?**
Yes.
The fallback costs one jq field and one `if` line in `hook_prompt`, plus a three-line comment.
`slug` was factored out, which the fallback needs anyway.
Making `UserPromptSubmit` always prefer `session_title` would cost the same and would make one hook's name source differ from the others (`Stop`, `note`, `path`) after the first prompt.
The implementer's choice keeps the transcript authoritative.

**Better than accepting a split first turn?**
Yes.
A split leaves an orphaned `@user` with no sign-off in the unnamed record of every `--name` session, while `Stop` signs off the named record.
It also fails the proposal's own Verification step 2.
The fallback is cheaper than documenting that defect.

**Non-blocking (doc placement):** the proposal's NOTE sits under "Where the name comes from", while the "Important Design Decisions" bullet "The transcript is the only name source" still reads as unqualified.
Under commentary decoupling, one NOTE should sit at the decision it qualifies.
Move the NOTE there instead of adding a second one.
Its parenthetical "(present on that event only)" is also imprecise: the CLI schema also gives `SessionStart` a `session_title`.
"`Stop` does not carry it" is what matters.

### Script (`plugins/cdocs/bin/chat-record`)

The script matches the proposal.
`find_record`'s date-anchored glob correctly keeps the unnamed lookup from matching named records, which a `*-<sid>.md` glob would.
`LC_ALL=C` is exported at the top, so `tr` and `cut` slug by bytes as the 64-character rationale assumes.
No missing-`@user` warning or other new stderr output was added, as the spec asks.
The `${HOME:-}` fix (`e2283a1`) is correct under `set -u`.
No findings.

### Rule text (`plugins/cdocs/rules/overseers.md` "Chat record")

The rule matches the Steering Log on every point:
- Free-form notes.
- "Briefly".
- The turn's most important things you are about to tell the user.
- At most 300 words, with bullets of at most 100 words.
- A new name gets its own record.
- No user-header warning.

The heading is unchanged, and `test:rules` is green.

**Non-blocking:** the example's second bullet ("Open: whether `note` should warn past 300 words; guidance only for now.") is this proposal's own open question, shipped as permanent rule text to every downstream project.
Drop it.
One bullet is enough to show the format, and the rule already says "bullets".

### No note typing left in shipped text

`git grep` finds no `gist:`, `query:`, `read:`, or `follow-up:` in `plugins/` except the test's own negative assertion.

**Non-blocking:** the one remaining stale copy is this repo's own `cdocs/_chat/README.md` ("the agent's gist bullets", unnamed filename only), which the implementer flagged.
It is overseer-owned, so regenerate it from the new init template on `main` after the merge.

### `plugins/cdocs/bin/README.md`

**Non-blocking (remove text):** the new "What it does" bullet carries two implementation details that this user-facing page does not need:
- The `session_title` sentence, which the script comment and the proposal NOTE already document.
- The slug recipe with "`ai-title` lines are ignored".

Suggested text: "`<name>` is the slug of the session's `/rename` or `--name` title; a rename starts a new record, and renaming back resumes the old one."

### Test suite (`plugins/cdocs/hooks/tests/chat-record.test.sh`)

The suite grew by 31 unit assertions (95 to 126) covering these behaviors:
- Slugging.
- The first-prompt fallback.
- Rename and rename-back.
- Agent modes finding the name.
- Name-exact lookup.
- The free-form block reason.

Each of these is a real failure picture, and the hermetic `CLAUDE_CONFIG_DIR` keeps the agent-mode tests off the real `~/.claude`.
The headless `rename_record` and `rename_record_name` scenarios replace the transcript-editing `rename` scenario rather than adding to it.
The suite is not materially padded.

**Non-blocking (remove assertions):** three slug checks duplicate assertions in the sign-off section, which now read explicit record paths:
- "slug: empty customTitle -> unnamed" duplicates "empty title -> sid8", which reads `$D-$SID.md`.
- "slug: last custom-title wins" duplicates "last custom-title, slugged", which has two titles and reads the named path.
- "no transcript: unnamed record" duplicates "unreadable transcript -> sid8".

Drop them.

### Other docs

The edits to the frontmatter spec, the devlog skill, the plugin README, the init `_chat/README.md` template, and the NOTE on the 2026-09-22 proposal are all correct.
Every line that gives `<session_id>.md` also gives the named form.
No findings.

### Not verified

- Interactive TUI `/rename` and `claude --name`: this review used headless stream-json and `-p` only, as the implementer did.
  The code reading above suggests the TUI behaves the same, but I did not exercise it.
- The full headless suite (`background`, `cd_sibling`, and the rest).
  I re-ran `path_mode` and `payload_shape` in addition to the rename scenarios.

## Verdict

**Accept.**
`review_proof: confirmed`: I re-ran the floor myself, and every artifact is listed under Evidence.
No blocking issues.

## Action Items

1. [non-blocking] Move the proposal's `session_title` NOTE to the "The transcript is the only name source" decision bullet, and change "(present on that event only)" to "(`Stop` does not carry it)".
2. [non-blocking] Drop the rule example's second bullet ("Open: whether `note` should warn past 300 words; …").
3. [non-blocking] Trim the `bin/README.md` naming bullet to the suggested one-line form, which drops the `session_title` sentence and the `ai-title` clause.
4. [non-blocking] Drop the three duplicate unit assertions: "slug: empty customTitle -> unnamed", "slug: last custom-title wins", and "no transcript: unnamed record <date>-<sid>.md".
5. [non-blocking, overseer, on `main` after merge] Regenerate this repo's `cdocs/_chat/README.md` from the new init template.
