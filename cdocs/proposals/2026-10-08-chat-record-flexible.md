---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T09:26:37-07:00
task_list: cdocs/chat-record-flexible
type: proposal
state: live
status: implementation_accepted
last_reviewed:
  status: accepted
  by: "@claude-opus-5-5"
  at: 2026-10-08T10:15:00-07:00
  round: 3
tags: [chat_record, hooks, claude_skills]
---

# Flexible Chat Records: Free-Form Notes

> BLUF: Drop the `gist:`/`query:`/`read:`/`follow-up:` note types: each human-initiated turn ends with a free-form `chat-record note` of the most important things the agent is about to tell the user, at most 300 words in bullets of at most 100 words (guidance only, not checked).
> No code parses the types, so this is a text change to the rule, the Stop hook's block reason, the READMEs, and the test fixtures; the record grammar, filenames, and hook contract are unchanged.

> NOTE(opus-5-5/chat-record-flexible): A second change, putting the slugged session name (`/rename`, `--name`) in the record filename so a rename starts a new record, was implemented and accepted in review, then dropped by the maintainer ("Retrieval/interpretability can be handled later").
> Nearly all of its machinery (a slugger, a transcript search for `note` and `path`, name-aware lookup, a `session_title` fallback because a new session's first `UserPromptSubmit` fires before its transcript exists) existed only to name the file, while the sign-off line already carries the session name.
> Records stay `YYYY-MM-DD-<session_id>.md`; the implementation and revert are in `cdocs/devlogs/2026-10-08-chat-record-flexible-impl.md`.

## Objective

The maintainer's spec (`cdocs/devlogs/2026-10-08-chat-record-flexible.md`, Steering Log): "remove the 'schema' entirely in favor of flexible records: Before ending a turn that began with a human prompt, call chat-record briefly summarizing the most salient information from the turn. It should be the most important info you are about to share with the user, condensed to at most 300 words, with bullet points no more than 100 words long."

## Background

- [`cdocs/reviews/2026-10-08-review-of-chat-record-utility.md`](../reviews/2026-10-08-review-of-chat-record-utility.md): 36 of 42 bullets in a 15-hour session were `gist:`; `query:` only ever said an agent was running; the typing pushed notes toward activity narration and lost the *why* and what stays open.
- [`cdocs/proposals/2026-09-22-chat-record-devlog-management.md`](2026-09-22-chat-record-devlog-management.md): the accepted chat-record design (record grammar, hook contract, "no state beyond the record").

## Proposed Solution

Replacement for "CDocs Overseer Rules › Chat record" (heading unchanged, so `npm run test:rules` is unaffected); only the note sentence and example change:

````md
## Chat record

Top-level agents must use the `chat-record` command to maintain chat records (subagents should never).
Before ending a turn that began with a human prompt, note the most important things you are about to tell the user, in at most 300 words of bullets, each at most 100 words.
The quoted heredoc keeps the body byte-exact:

```bash
chat-record note --as opus-5-5 <<'EOF'
- Reviewer r5 returned revise on two blockers; the retry cap is yours to decide.
EOF
```

The first turn you work on a devlog, add the output of `chat-record path` to its `chat_record:` frontmatter list.

**After a compaction:** run `chat-record path`, read the `## Scratchpoint` and any handoff of the devlogs that list it, then `tail -n 80` of the record to get up to speed.

Commit the record by explicit path with its devlog; never edit files under `cdocs/_chat/`.
````

Stop block reason (`chat-record`, template line only):

```
No chat-record entry for this turn (record: <path>). Run, then finish:
chat-record note --as <your model id> <<'EOF'
- <the most important thing you are telling the user>
EOF
```

### Touch points

| file | change |
|---|---|
| `plugins/cdocs/rules/overseers.md` "Chat record" | replacement above |
| `plugins/cdocs/bin/chat-record` | Stop reason template line |
| `plugins/cdocs/bin/README.md` | `note` example body; block JSON |
| `plugins/cdocs/README.md` | "gist bullets" and "gist bullet" to "note of each turn" and "note" |
| `plugins/cdocs/skills/init/SKILL.md` `_chat/README.md` template | "the agent's gist bullets" to "the agent's note of each turn" |
| `plugins/cdocs/hooks/tests/chat-record.test.sh` | fixture bodies `- gist: x` become untyped (opaque to the script); block-reason assertions |
| `cdocs/proposals/2026-09-22-chat-record-devlog-management.md` | one `NOTE(...)` under the BLUF pointing here; no rewrite |

## Important Design Decisions

- **Word limits are guidance only.** `note` does not count words.
  The maintainer prefers guidelines over bans; the utility review found the rule produced notes even with no enforcement running; a rejected note at turn end costs a retry and can lose the note.
  If records drift long, a one-line stderr warning past 300 words is a small follow-up.
- **The rule keeps the maintainer's framing** ("the most important things you are about to tell the user") and does not import the review's longer salience test or "skip devlog progress" clause.
  The maintainer's criterion already excludes dispatch narration that is not news to the user.

## Edge Cases / Challenging Scenarios

- **Existing records** keep their typed bullets; nothing reads the types, so no migration.
- **Downstream `_chat/README.md`:** `/cdocs:init` never overwrites existing files, so projects already initialized keep the old README text until they edit it.
- **Rule hash change:** the SessionStart freshness hook prompts downstream projects to re-run `/cdocs:init`, as for any rule edit.

## Test Plan

- Unit (`bash plugins/cdocs/hooks/tests/chat-record.test.sh --unit`): untyped fixtures pass unchanged; the block reason contains `- <the most important thing you are telling the user>`, matches no note type, and stays under 300 bytes.
- Rules: `npm run test:rules` stays green; the `init_real` assertions on the rule's scope sentence and compaction step still match.
- Headless: `two_prompts`, `clear`, `resume` with untyped note bodies.

## Implementation Phases

### Phase 1: Free-form notes

- Every touch point above, in conventional commits by explicit path.
- Acceptance: ``grep -rnE 'gist:|follow-up:' plugins/cdocs`` returns nothing; `git diff main -- plugins/cdocs/bin/chat-record` is the template line only; unit, rules, `--only init_real`, and the headless runs above green.

## Open Questions

- Plugin version bump for the rule change: left to the repo's release practice, not this proposal.
- Session-named records, or another retrieval aid for long sessions: deferred by the maintainer (see the NOTE under the BLUF).
