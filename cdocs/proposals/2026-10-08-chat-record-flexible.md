---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T09:26:37-07:00
task_list: cdocs/chat-record-flexible
type: proposal
state: live
status: implementation_wip
last_reviewed:
  status: accepted
  by: "@claude-opus-5-5"
  at: 2026-10-08T09:31:05-07:00
  round: 1
tags: [chat_record, hooks, claude_skills]
---

# Flexible Chat Records: Free-Form Notes and Session-Named Files

> BLUF: Drop the `gist:`/`query:`/`read:`/`follow-up:` note types: each human-initiated turn ends with a free-form `chat-record note` of the most important things the agent is about to tell the user, at most 300 words in bullets of at most 100 words (guidance only, not checked).
> Put the session name (the transcript's last `custom-title`, from `/rename` or `--name`, slugged) in the record filename: `YYYY-MM-DD-<name>-<session_id>.md`, or `YYYY-MM-DD-<session_id>.md` unnamed.
> A record is looked up by session id *and* current name, so a rename starts a new record and the old one stays.
> Existing records stay valid; no migration.

## Summary

Two independent changes to `plugins/cdocs/bin/chat-record` and the text around it:

1. **Free-form notes.** The note "schema" is removed from the rule, the Stop hook's block reason, the READMEs, and the test fixtures.
   No code parses the types, so this is a text change.
2. **Session-named records.** One function, `session_name`, reads the last `custom-title` from the transcript and slugs it.
   The hooks find the transcript in their payload's `transcript_path`; `note` and `path`, which have no payload, glob `${CLAUDE_CONFIG_DIR:-~/.claude}/projects/*/<session_id>.jsonl`.
   `find_record` matches the exact name segment, so the record is a pure function of (session id, current name): no state file, as today.

Two live checks inform the design (scratch repo, `claude -p --model haiku`, 2026-10-08):
- `--name "First Name"` writes `{"type":"custom-title",...}` as the transcript's first line, before the first user message; `--resume <sid> --name "Second: Name!"` appends a new `custom-title` before that run's user message.
- `/rename Hook Check` sent as a stream-json user message renames the session, fires no `UserPromptSubmit` (no `@user` block for it), and is visible to the model on the next turn (its note said "User ran /rename to Hook Check").

## Objective

The maintainer's spec (`cdocs/devlogs/2026-10-08-chat-record-flexible.md`, Steering Log): "remove the 'schema' entirely in favor of flexible records: Before ending a turn that began with a human prompt, call chat-record briefly summarizing the most salient information from the turn. It should be the most important info you are about to share with the user, condensed to at most 300 words, with bullet points no more than 100 words long." "Session name should also be added to the file name, and a new session name should start a new chat record."

## Background

- [`cdocs/reviews/2026-10-08-review-of-chat-record-utility.md`](../reviews/2026-10-08-review-of-chat-record-utility.md): 36 of 42 bullets in a 15-hour session were `gist:`; `query:` only ever said an agent was running; the typing pushed notes toward activity narration and lost the *why* and what stays open.
- [`cdocs/proposals/2026-09-22-chat-record-devlog-management.md`](2026-09-22-chat-record-devlog-management.md): the accepted chat-record design (record grammar, hook contract, "no state beyond the record").
- `plugins/cdocs/bin/chat-record`: `session_token` already reads the last `custom-title` for the sign-off token; `find_record` globs `*-<sid>.md` and takes the earliest-dated match.
- Transcripts also carry `ai-title` lines (auto-generated, rewritten often): these are not the session name and must not split records.

## Proposed Solution

### 1. Free-form notes

Replacement for "CDocs Overseer Rules › Chat record" (heading unchanged, so `npm run test:rules` is unaffected):

````md
## Chat record

Top-level agents must use the `chat-record` command to maintain chat records (subagents should never).
Before ending a turn that began with a human prompt, briefly note the turn's most salient information: the most important things you are about to tell the user, in at most 300 words of bullets, each at most 100 words.
The quoted heredoc keeps the body byte-exact:

```bash
chat-record note --as opus-5-5 <<'EOF'
- Proposal ready for review: the session name goes in the record filename, so a rename starts a new record and the old one stays.
- Open: whether `note` should warn past 300 words; guidance only for now.
EOF
```

The first turn you work on a devlog, and after the session is renamed (each name gets its own record), add the output of `chat-record path` to its `chat_record:` frontmatter list.

**After a compaction:** run `chat-record path`, read the `## Scratchpoint` and any handoff of the devlogs that list it, then `tail -n 80` of the record to get up to speed.

Commit a devlog's records by explicit path with it; never edit files under `cdocs/_chat/`.
````

Edits against the current text: the typed-bullet sentence and example are replaced; the devlog paragraph gains "and after the session is renamed"; the commit paragraph becomes plural, because after a rename the old record's last sign-off lands after the agent's final commit to it and would otherwise never be committed.
The compaction paragraph is unchanged.

Stop block reason (`chat-record` lines 158-160), template line only:

```
No chat-record entry for this turn (record: <path>). Run, then finish:
chat-record note --as <your model id> <<'EOF'
- <the most important thing you are telling the user>
EOF
```

### 2. Session-named records

**Filename.**
`cdocs/_chat/YYYY-MM-DD-<name>-<session_id>.md` when the session has a name, `cdocs/_chat/YYYY-MM-DD-<session_id>.md` when it does not (today's format).
The date is the record's first write, as today.
Parsing stays unambiguous: the date is the first 10 characters and the UUID the last 36 before `.md`.

**Name and slug.**
The name is the `customTitle` of the transcript's last `"type":"custom-title"` line, written by `/rename` and `--name`; `ai-title` lines are ignored.
The slug: lowercase; every run of characters outside `[a-z0-9]` becomes one `-`; leading and trailing `-` trimmed; cut to 64 characters, then trailing `-` trimmed again.
An empty slug (no title, an empty title, or a title with no ASCII alphanumerics) means unnamed.

```bash
# session_name <transcript>: slug of the last custom-title (/rename, --name), or empty.
session_name() {
  [ -n "$1" ] && [ -r "$1" ] || return 0
  grep '"type":"custom-title"' "$1" 2>/dev/null | tail -n 1 | jq -r '.customTitle // ""' 2>/dev/null \
    | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed -E 's/^-+//; s/-+$//' | cut -c1-64 | sed -E 's/-+$//'
}
```

Prototype outputs: `my canary "v2"` to `my-canary-v2`, `Second: Name!` to `second-name`, `Café plan` to `caf-plan`, `!!!` to empty.

`session_token` (the sign-off token) becomes `session_name`, falling back to the 8-hex session-id prefix as today, so the sign-off and the filename always show the same name.

**Where the name comes from.**

| caller | transcript source |
|---|---|
| `UserPromptSubmit`, `Stop` hooks | payload `transcript_path` (both events carry it; the suite's `payload_shape` scenario asserts this) |
| `note`, `path` | `transcript_for "$SID"`: first match of `"${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/projects/*/"$SID".jsonl` |

`CLAUDE_CODE_SESSION_ID` is already how agent modes learn the session; the Bash tool inherits `CLAUDE_CONFIG_DIR` from the Claude Code process, so the glob finds the same file the hooks are handed.
No transcript found means unnamed, for hooks and agent modes alike.

> NOTE(opus-5-5/chat-record-flexible): A new session's first `UserPromptSubmit` fires before the transcript file exists (probed on claude 2.1.293), so a `--name` session's first `@user` went to the unnamed record.
> When the transcript file does not exist, `UserPromptSubmit` slugs the payload's `session_title` (present on that event only) instead; once it exists, the transcript alone decides.
> See `cdocs/devlogs/2026-10-08-chat-record-flexible-impl.md`.

**Lookup.**
`find_record <sid> <name>` and `record_for <sid> <name>` take the name and match only that name segment:

```bash
find_record() { # earliest-dated record for this session id and name, or empty
  local f d='[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
  for f in "$CHAT_DIR"/$d-"${2:+$2-}$1".md; do
    [ -f "$f" ] && { printf '%s' "$f"; return 0; }
  done
  return 0
}
```

`record_for` falls back to `$CHAT_DIR/$(date +%Y-%m-%d)-${2:+$2-}$1.md`.
Every caller (`hook_prompt`, `hook_stop`, `agent_note`, `agent_path`) computes the name once and passes it.

**Rename behavior.**
`/rename` fires no hook and happens between turns, so the next `UserPromptSubmit` computes the new name, finds no record for it, and starts one; the old record ends at its last sign-off and is never written again unless the session is renamed back to that name, in which case writes resume in it.
`chat-record path` prints the current name's record only (one line, as today).

After a compaction, `chat-record path` and `tail -n 80` read the current name's record; earlier names' records are reachable through the devlog's `chat_record:` list.

### Touch points

| file | change | part |
|---|---|---|
| `plugins/cdocs/rules/overseers.md` "Chat record" | replacement above | 1, 2 |
| `plugins/cdocs/bin/chat-record` | Stop reason template (l.160); `session_name`, `transcript_for`; `find_record`/`record_for` take a name; hooks pass `transcript_path`; header comment's `path` line | 1, 2 |
| `plugins/cdocs/bin/README.md` | BLUF filename (l.10); "What it does" gains a naming bullet; `note` example body (l.32, 36); `path` example (l.44-46) shows a named record; block JSON (l.58) | 1, 2 |
| `plugins/cdocs/README.md` | hooks bullet filename (l.148); "gist bullets" (l.153) and "gist bullet" (l.160) to "notes"/"note" | 1, 2 |
| `plugins/cdocs/skills/init/SKILL.md` `_chat/README.md` template (l.157) | filename pattern; "the agent's gist bullets" to "the agent's note of each turn"; one per session name | 1, 2 |
| `plugins/cdocs/rules/frontmatter-spec.md` | template path (l.29), `chat_record` definition "one entry appended per session" to "per record (one per session name)" (l.84), `_chat/` naming line (l.110) | 2 |
| `plugins/cdocs/skills/devlog/SKILL.md` (l.31) | "one appended per session" to "one per record" | 2 |
| `plugins/cdocs/hooks/tests/chat-record.test.sh` | see Test Plan; fixture bodies `- gist: x` become untyped (opaque to the script, renamed for consistency) | 1, 2 |
| `cdocs/proposals/2026-09-22-chat-record-devlog-management.md` | one `NOTE(...)` under the BLUF pointing here; no rewrite | 1, 2 |

## Important Design Decisions

- **Word limits are guidance only.** `note` does not count words.
  The maintainer prefers guidelines over bans; the utility review found the rule produced notes even with no enforcement running; a rejected note at turn end costs a retry and can lose the note.
  If records drift long, a one-line stderr warning past 300 words is a small follow-up.
- **The rule keeps the maintainer's framing** ("the most important things you are about to tell the user") and does not import the review's longer salience test or "skip devlog progress" clause.
  The maintainer's criterion already excludes dispatch narration that is not news to the user.
- **The transcript is the only name source.** It is what `session_token` already reads and what the hooks are handed.
  Rejected: the sessions registry (`~/.claude/sessions/<pid>.json`, used by `plugins/converser`), which is undocumented, per-process, and would give `note` a different source from the hooks; a state file written by the hooks, which breaks "no state beyond the record".
- **Exact name matching, not "latest record".** Choosing the most recently written record would need mtimes (reset by `git checkout`) or timestamp parsing; matching (session id, name) is stateless and makes renaming back resume the earlier record.
- **`path` stays one line.** Printing every record of the session would spare the agent noticing renames, but changes `path`'s contract, the compaction step, and the commit step.
  The rename is in the agent's context, so the rule sentence is enough.
- **Lowercased slug.** `Foo` and `foo` would be two records on Linux and one file on macOS; lowercasing makes the record set the same on both.
- **64-character cap.** A record name must fit `NAME_MAX` (255 bytes); after slugging under `LC_ALL=C`, characters are bytes, and 64 keeps the filename near 115 characters.
- **Unnamed keeps today's filename,** so existing records are found and appended to unchanged.

## Edge Cases / Challenging Scenarios

- **Session already named when the upgraded script first runs.** Its next hook computes the name and starts a named record; the unnamed record stops growing.
  A one-time split, listed by the rule's rename sentence; no migration.
- **Rename mid-turn** (if the TUI runs `/rename` while the agent works): `@user` lands in the old record; the note and sign-off land in the new one.
  If the note had not yet been written, `Stop` finds no new record and neither blocks nor signs off, and the old record keeps an unsigned `@user`.
  Accepted: rare, visible, and nothing is lost but the pairing.
- **`note` cannot find the transcript while the hooks can** (e.g. a config-dir mismatch): `note` writes the unnamed record, `Stop` still sees `@user` last in the named record and blocks once with that path, then signs off on the second `Stop`.
  The record splits, visibly; the headless rename scenario catches a systematic mismatch.
- **Two titles with the same slug** (`Foo Bar`, `foo-bar`): one record; same name for practical purposes.
- **Non-ASCII titles** lose those characters (`Café` to `caf`); a fully non-ASCII title is unnamed.
- **`/clear` and `--fork-session`** give a new session id, so a new record regardless of name, as today.
- **Several transcripts for one session id** (not observed): `transcript_for` takes the first match, degrading to the split above.
- **Large transcripts:** one `grep` per hook or agent call, as `Stop` already does.
- **Downstream `_chat/README.md`:** `/cdocs:init` never overwrites existing files, so projects already initialized keep the old README text until they edit it.
- **Rule hash change:** the SessionStart freshness hook prompts downstream projects to re-run `/cdocs:init`, as for any rule edit.

## Test Plan

Unit (`bash plugins/cdocs/hooks/tests/chat-record.test.sh --unit`; baseline 2026-10-08: 95 passed, 0 failed).
Agent-mode calls (`note`, `path`) run with a hermetic `CLAUDE_CONFIG_DIR="$U/cfg"`, so they never glob the real `~/.claude`; `ups` gains an optional transcript argument, as `stop` has.

- **Slug:** the prototype cases above, plus a 70-character title (cut at 64, no trailing `-`), an empty `customTitle`, a transcript whose last title line is `ai-title` (ignored; the earlier `custom-title` wins), and no transcript.
- **Filename:** a named turn writes `<date>-<slug>-<sid>.md`; an unnamed turn writes `<date>-<sid>.md` (existing assertion, l.140).
- **Rename:** turn 1 with title A (UPS, note, Stop) writes only A's record; append a `custom-title` B to the transcript; turn 2 writes only B's record (`U A:tester S:b`), A's markers unchanged; rename back to A; turn 3 appends to A.
- **Agent modes find the name:** with `$U/cfg/projects/p/$SID.jsonl` holding title A, `note` appends to A's record and `path` prints it; with no transcript, both use the unnamed record.
- **Name-exact lookup:** an unnamed and a named record for the same id coexist; each name's calls touch only its own (covers the `[0-9]...-<sid>.md` glob not matching named records).
- **Existing records:** the "multiple matches" and Stop decision-table cases still pass unchanged with no transcript (unnamed).
- **Sign-off token:** "last custom-title, mapped" (l.188) expects `-- my-canary-v2` (slug) instead of `-- my-canary--v2-`.
- **Block reason:** contains `- <the most important thing you are telling the user>`, contains no `gist:`, stays under 300 bytes (existing assertion).

Rules: `npm run test:rules` stays green (baseline 11 passed); the `init_real` assertion on `**After a compaction` ... `run \`chat-record path\`` still matches.

## Verification Methodology

1. **Headless scenario `rename_record`** (replacing the transcript-editing `rename` scenario at l.720): `drive rename_record "$P" "$(note_prompt 'Reply one.' '- turn one')" "/rename Second Name" "$(note_prompt 'Reply two.' '- turn two')"`, then assert two records, `<date>-<sid>.md` with `U A:haiku-4-5 S:<sid8>` and `<date>-second-name-<sid>.md` with `U A:haiku-4-5 S:second-name`, no `@user` block for `/rename`, and no Stop block.
   `drive` already sends slash commands turn by turn (`/clear`, `/compact` scenarios); `/rename` was confirmed to work this way.
   Run it once with `CHAT_RECORD_KEEP=1` as the real session check, and paste `ls cdocs/_chat` and both records into the overseer's devlog.
2. **`--name` variant** in the same scenario or a sibling: `claude_run ... -p --name "First Name"` then `--resume <sid> --name "Other"`, asserting the first turn's record is `first-name` (title written before the first prompt) and the resumed turn's is `other`.

## Implementation Phases

Each phase ends with the unit suite and `npm run test:rules` green and its own conventional commit(s) by explicit path.
Do not change the record grammar (`HEADER_RE`, `SIGNOFF_RE`), the Stop decision table, activation, or the `--as` speaker handling.

### Phase 1: Free-form notes

- Rule text (Proposed Solution 1, without the rename sentence, which Phase 3 adds).
- Stop reason template; its unit assertions.
- `bin/README.md` note example and block JSON; `plugins/cdocs/README.md` l.153, l.160; init `_chat/README.md` "gist bullets".
- Untyped fixture bodies in the unit and headless suites.
- Acceptance: ``grep -rnE 'gist:|follow-up:' plugins/cdocs`` returns nothing (the `read:` and `query:` types appear only in the replaced rule sentence).

### Phase 2: Session-named records (script and unit tests)

- `session_name`, `transcript_for`; `session_token` via `session_name`; `find_record`/`record_for` take a name; hooks pass `transcript_path` (add it to `hook_prompt`'s arguments); `agent_setup` sets the name.
- Unit tests from the Test Plan, written first and seen failing.
- Acceptance: unit suite green, including the new rename and agent-mode cases.

### Phase 3: Naming docs

- Rule: the rename sentence and plural commit paragraph.
- `frontmatter-spec.md` l.29, l.84, l.110; `devlog/SKILL.md` l.31; `bin/README.md` BLUF, naming bullet, `path` example; `plugins/cdocs/README.md` l.148; init `_chat/README.md` filename.
- NOTE under the 2026-09-22 proposal's BLUF: `> NOTE(opus-5-5/chat-record-flexible): Notes are free-form and records are named per session name; see [2026-10-08-chat-record-flexible.md](2026-10-08-chat-record-flexible.md).`
- Acceptance: every line ``grep -rn '<session_id>\.md' plugins/cdocs`` prints also gives the named form.

### Phase 4: Headless verification

- `rename_record` scenario (and the `--name` variant), replacing `rename`.
- Run `--headless --only 'rename_record|clear|resume|two_prompts'` plus the real session check; record results and the `ls cdocs/_chat` listing in the devlog.

## Open Questions

- Plugin version bump for the rule change: left to the repo's release practice, not this proposal.
