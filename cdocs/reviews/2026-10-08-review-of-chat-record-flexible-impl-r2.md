---
review_of: cdocs/proposals/2026-10-08-chat-record-flexible.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T10:15:00-07:00
task_list: cdocs/chat-record-flexible
type: review
state: live
status: done
tags: [fresh_agent, runtime_validated, implementation_review, chat_record, consistency]
---

# Review: Flexible Chat Records Implementation (Round 2)

> BLUF: Accept, `review_proof: confirmed`.
> After the revert, `plugins/` differs from main only in free-form wording.
> `bin/chat-record` differs by its Stop template line alone.
> No naming code, tests, or docs remain anywhere in `plugins/`, `scripts/`, or `CLAUDE.md`.
> I re-ran the floor at `aee946a`: unit 97/0, rules 11/0, and headless 22/0 across seven scenarios, including `init_real` and `rename`.
> No blocking items.
> Four non-blocking items, three of which remove text; the stale Changes Made table in the impl devlog is the one most worth fixing before landing.

## Summary Assessment

Branch `chat-record-flexible` (base `13edf08`; main has no `plugins/` changes since, and `git merge-tree` merges cleanly) replaces the typed `gist:`/`query:`/`read:`/`follow-up:` notes with free-form notes.
Each note is "the most important things you are about to tell the user", at most 300 words of bullets with each bullet at most 100 words.
The session-named filename work is fully reverted (`39478f7..aee946a`).
Across the plugin, every place that describes chat-record notes says the same thing, and none still describes typed notes.
The proposal reads as a free-form-only design, and the naming history is confined to one NOTE under the BLUF.
The remaining issues are wording and bookkeeping, not behavior.

## Evidence (reviewer-produced)

The scratchpad is `/tmp/claude-1000/-var-home-mjr-code-weft-clauthier-main/63ac45de-462d-4f43-ae1c-4ab6d59049b8/scratchpad/`, shared with the r1 reviewer.
My runs overwrote r1's `unit.txt`, `rules.txt`, and `headless.txt` there; r1's other artifacts are untouched.
HEAD is `aee946a`, claude is 2.1.293.

| check | result | artifact |
|---|---|---|
| `chat-record.test.sh --unit` | 97 passed, 0 failed | `unit.txt` |
| `npm run test:rules` | 11 pass, 0 fail | `rules.txt` |
| headless `--only '^(init_real\|two_prompts\|clear\|resume\|rename\|read_note\|minimal)$'` | 22 passed, 0 failed (7 scenarios; `rename` markers `U A S:f8bf739d U A S:my-canary U A S:my-canary`) | `headless.txt` |
| acceptance `grep -rnE 'gist:\|follow-up:' plugins/cdocs` | no matches (exit 1) | |
| `git diff main...chat-record-flexible -- plugins/cdocs/bin/chat-record` | one changed line (the Stop template) | |
| naming-residue grep (`slug`, `session_title`, `custom-title`, `transcript`, `session name`) over `plugins/`, `scripts/`, `CLAUDE.md` | only main's own code: `session_token` reads `custom-title` for the sign-off, and the `rename` scenario tests it; other hits are unrelated `ablate`/`browser-delegate`/`oversee` text | |

## Section-by-Section Findings

### Focus 1: the `plugins/` diff is free-form wording only

**Confirmed.**
Six files change in `plugins/`: the rule, the Stop template line, both READMEs, the init `_chat/README.md` template, and test fixtures plus two block-reason assertions.
`frontmatter-spec.md`, `devlog/SKILL.md`, and `hooks.json` are identical to main.
The test file is main's file with untyped fixture bodies (`- gist: x` to `- x`) and two added assertions: the block reason carries the free-form template, and it matches no `(gist|query|read|follow-up):`.
Main's `rename` scenario, which checks that the sign-off carries the `custom-title`, is back and passes.
So the proposal's NOTE is right that "the sign-off line already carries the session name".

### Focus 2: consistency across the plugin

**Consistent; no typed leftovers.**
Every place that describes the note uses the same wording:
- the rule, in `overseers.md` "Chat record";
- the Stop block reason, and its copy in `bin/README.md`;
- the `bin/README.md` `note` example;
- `plugins/cdocs/README.md` ("its note of each turn", "echoed into a note");
- the init `_chat/README.md` template ("the agent's note of each turn").

`frontmatter-spec.md`, `devlog/SKILL.md`, and `devlog/template.md` describe the record path, not the note, so they need no change.
The iterate, full-send, and oversee skills and the agents do not describe notes at all.
They reach the rule only by heading, which `test:rules` checks.
`CLAUDE.md` names the section "(stay thin, chat record)" only.
The OpenCode build copies `rules/` verbatim, so it carries the same rule text and nothing separate to drift.
It also ships a rule about a command it lacks, but that predates this branch and is out of scope.

**Non-blocking: the rule sentence says "salient" twice in different words.**
"briefly note the turn's most salient information: the most important things you are about to tell the user" gives the same criterion twice.
The second phrase is the maintainer's wording and the one that matters.
Suggested rule sentence, which also reads more like the terse imperatives in "Stay thin":

> Before ending a turn that began with a human prompt, note the most important things you are about to tell the user, in at most 300 words of bullets, each at most 100 words.

**Non-blocking: the rule example is about this proposal.**
"Proposal ready for review: notes are free-form, so the record carries why decisions were made and what stays open." describes the feature instead of showing a typical note.
A downstream reader, who has never seen typed notes, gets nothing from "notes are free-form".
A shorter example works better.
One option extends main's bullet ("reviewer r5 returned revise on two blockers") with an open item: "- Reviewer r5 returned revise on two blockers; the retry cap is yours to decide."
That shows a result and an open item in one bullet, which is the point of the change.
Whichever example is chosen, the proposal's copy of the rule must match.

Minor, no action needed: `bin/README.md` line 17 still says the note is a `@<model>: <time>` "bullet" (it is a header plus bullets), while the Stop reason calls it an "entry".
Both are pre-existing, and neither contradicts the rule.

### Focus 3: the proposal

**Reads as the free-form-only design.**
The BLUF, Objective, Proposed Solution, Touch points, Design Decisions, Edge Cases, Test Plan, and Phase 1 all describe only free-form notes.
The naming history appears in the NOTE under the BLUF, which records what was built, why it was dropped, and where the record of it lives, plus one deferral pointer under Open Questions.
The Proposed Solution block matches `overseers.md` byte for byte.
The Stop reason block matches the script.
`status: implementation_wip` is correct for a maintainer-gated acceptance.

**Non-blocking: the edge case "Downstream `_chat/README.md`" conflicts with the rule.**
It says projects "keep the old README text until they edit it".
The rule says "never edit files under `cdocs/_chat/`", which covers `README.md` literally.
An agent will therefore never update it, and a human has to.
This repo's own `cdocs/_chat/README.md` still says "the agent's gist bullets" (r1 item 5, still open).
The lightest fix is to leave the rule alone and have the maintainer hand-edit this repo's README on main, which is one word.
Narrowing the rule to "never edit chat records" is the alternative, but it changes rule text outside this proposal's scope.

### Implementation devlog (`cdocs/devlogs/2026-10-08-chat-record-flexible-impl.md`)

**Non-blocking, worth fixing before landing: the Changes Made table describes the reverted state.**
It still lists `session_name`, `transcript_for`, name-aware lookup, "slug, rename, agent-mode, name-exact tests", and "session-named filenames".
It also lists `frontmatter-spec.md` and `devlog/SKILL.md` as changed, and "NOTE on the `session_title` fallback" in the proposal.
None of these is on the branch.
Its Verification section is correct: it heads with the post-revert numbers and labels the pre-revert table.
The chronological sections are fine, since devlogs may be chronological.
The Changes Made table, however, is where a cold reader looks for what landed.
Cut it to the six `plugins/` files in the post-revert `--stat`, plus the two proposal rows ("one NOTE under the BLUF" and the narrowed proposal).
The Objective line "and session-named record files" should become "(session-named files were later reverted)", or be dropped.

## Prior Action Items (r1)

1. `session_title` NOTE placement: moot; the NOTE was removed with the revert.
2. Single-bullet rule example: kept (but see the example finding above).
3. `bin/README.md` naming bullet: moot; reverted.
4. Duplicate naming unit assertions: moot; reverted.
5. Regenerate this repo's `cdocs/_chat/README.md`: **still open**, an overseer or maintainer task on main.

## Verdict

**Accept.**
The branch does what the maintainer asked and nothing else, the revert is clean, and the floor is green under my own runs.
The findings below are text cleanup the maintainer can take or leave at landing.

## Action Items

1. [non-blocking] In the impl devlog, cut the Changes Made table to the post-revert files, and drop or qualify "and session-named record files" in its Objective.
2. [non-blocking] In the rule and the proposal's copy of it, drop "briefly note the turn's most salient information:" so the sentence reads "note the most important things you are about to tell the user, in at most 300 words of bullets, each at most 100 words."
3. [non-blocking] Replace the self-referential rule example with a typical note, for example "- Reviewer r5 returned revise on two blockers; the retry cap is yours to decide.", in both the rule and the proposal.
4. [non-blocking, maintainer, on main] Hand-edit this repo's `cdocs/_chat/README.md` "gist bullets" to "note of each turn" (r1 item 5).

## Questions for the Maintainer

- `cdocs/_chat/README.md` versus the rule "never edit files under `cdocs/_chat/`":
  (a) hand-edit this repo's copy and leave the rule (recommended);
  (b) narrow the rule to "never edit chat records";
  (c) leave the stale README.
