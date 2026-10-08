---
review_of: cdocs/proposals/2026-10-08-chat-record-flexible.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T09:31:05-07:00
task_list: cdocs/chat-record-flexible
type: review
state: live
status: done
tags: [fresh_agent, runtime_validated, chat_record, hooks, minimal_design]
---

# Review: Flexible Chat Records: Free-Form Notes and Session-Named Files

## Summary Assessment

The proposal drops the typed-bullet note schema for a free-form per-turn note, and keys each chat record on (session id, slugged session name) so a rename starts a new record.
It matches the maintainer's spec on every point (no schema, the 300/100-word limits as guidance, name in the filename, new name means new record, no missing-`@user` warning), and the naming mechanics hold up against the real script and real transcripts.
The design is stateless and small: one `session_name` function, one `transcript_for` glob, and a name argument on `find_record`/`record_for`.
Verdict: **Accept**, with a few non-blocking nits, most of which remove text.

## Verification Performed

- `bash plugins/cdocs/hooks/tests/chat-record.test.sh --unit`: 95 passed, 0 failed (matches the stated baseline).
- `npm run test:rules`: green, 0 failed.
- **Name source.** Real transcripts in `~/.claude` and `~/.claude-rose` carry `{"type":"custom-title","customTitle":...}` as compact JSON; `ai-title` is a separate line type with `aiTitle`, so the `grep '"type":"custom-title"'` filter excludes it.
  Claude Code re-appends the current `custom-title` about every 20 lines (90 times in this session's 1745-line transcript), so "last line wins" tracks the current name exactly; the `<sid>/custom-title.json` sidecar agrees with the last line.
  JSON-escaped occurrences inside tool output (`\"type\":\"custom-title\"`) do not match the grep, so a transcript that discusses the format cannot spoof the name.
- **Transcript lookup without a payload.** A headless `CLAUDE_CONFIG_DIR=$HOME/.claude claude -p --model haiku` run's Bash tool printed `CLAUDE_CONFIG_DIR=/home/mjr/.claude`, and the transcript landed under that dir's `projects/`, so the Bash tool inherits the variable and the glob finds the hook's file.
  `~/.claude-rose` style config dirs are covered by the same inheritance.
  No session id appears twice across project dirs within `~/.claude` (735 transcripts) or `~/.claude-rose` (600); many ids appear in both config dirs (copies), which is irrelevant because the glob is scoped to one config dir.
- **Slug prototype.** Ran under `LC_ALL=C`: the stated outputs reproduce; a 67-character title cuts at 64 with no trailing `-`; an embedded newline becomes `-`; `market_model` becomes `market-model`.
- **Lookup.** The fixed-width date class makes `<date>-<sid>.md` and `<date>-<name>-<sid>.md` disjoint, and `<date>-foo-<sid>.md` cannot match `foo-bar`; slugs contain no glob metacharacters.
  Existing unnamed records are found unchanged, and rename-back resumes the earlier record by exact match.
- **Touch points.** A grep of `plugins/`, `scripts/`, and `.github/` for `_chat/`, `<session_id>.md`, `chat_record`, and `gist` finds nothing outside the proposal's table; no validator or triage code parses record filenames.
- **Payload claims.** The headless `payload_shape` scenario asserts `transcript_path` on both `UserPromptSubmit` and `Stop` (test l.777-780).

## Section-by-Section Findings

### BLUF, Summary, Objective

Accurate and complete; no surprises in the body.
The two live checks are the right evidence for the name source.

### Proposed Solution 1: Free-form notes

- **Non-blocking: say "brief".**
  The maintainer's words are "briefly summarizing" and "condensed to at most 300 words"; the rule text keeps the caps but drops the brevity cue, so an agent can read 300 words as a target.
  One word fixes it, e.g. "note briefly the turn's most salient information".
  This is the only addition this review asks for: long notes every turn are the likely failure of a cap with no enforcement.
- The example bullets are good: they show *why* and what stays open without implying a new type vocabulary.
- The plural commit paragraph is justified: an old name's record gets its final sign-off after the last commit that touches it.

### Proposed Solution 2: Session-named records

- Sound and minimal. Transcript-only name source, exact-name matching, and `path` staying one line are the right calls; the rejected alternatives (sessions registry, state file, latest-record by mtime) are correctly rejected.
- **Non-blocking:** the `find_record` snippet drops the current trailing `return 0`.
  Callers use command substitution without `set -e`, so nothing breaks, but keeping it preserves the current contract; the implementer can keep it without a proposal edit.
- **Non-blocking: trim "Effect on readers".** Its first bullet restates the rule sentence and its second restates the compaction paragraph plus the `chat_record:` list.
  One line ("earlier names' records are reachable through the devlog's `chat_record:` list") is enough.

### Important Design Decisions

All decisions are justified and match the maintainer's minimal-design preference.
The word-limit decision duplicates Open Question 1 (see below).

### Edge Cases

Thorough and accurate.
- **Non-blocking:** "Several transcripts for one session id" can be cut or cut to a clause: zero duplicates exist within either config dir on this host (see Verification), and the stated degradation is the same as the config-dir mismatch case above it.
- "Session already named when the upgraded script first runs" applies to this very workstream: the overseer's session is named (`cdocs-triage-state`) and its devlog lists `2026-10-07-63ac45de-....md`; the first post-upgrade turn will start `<date>-cdocs-triage-state-63ac45de-....md`, and the rule's rename sentence covers adding it.
  No change needed; noting it so the overseer expects the split.

### Test Plan

Complete and proportionate; the hermetic `CLAUDE_CONFIG_DIR` for agent-mode unit tests is the right detail.

### Verification Methodology

- **Non-blocking: collapse item 3 into item 1.** Item 3 already says it is item 1 run with `CHAT_RECORD_KEEP=1`; one sentence ("run `rename_record` with `CHAT_RECORD_KEEP=1` and paste the `ls cdocs/_chat` listing into the devlog") replaces it.
  Phase 4's last bullet already says the same.
- Item 2 (`--name` variant) earns its place: it is the only check that a title written before the first prompt names the first turn's record, which depends on Claude Code writing the title before `UserPromptSubmit` fires.

### Implementation Phases

Clear, ordered, and each has a mechanical acceptance check.
The Phase 1 acceptance grep is correctly scoped: today `gist:` occurs in `plugins/cdocs` only in the rule, the Stop reason, `bin/README.md`, and the test fixtures, all of which Phase 1 edits.

### Open Questions

- **Non-blocking: remove Open Question 1.** The design decisions already answer it ("guidance only"; a warning is "a small follow-up" if records drift), so it repeats a settled decision.
- Open Question 2 (version bump) is fine to keep or drop; it is outside this design.

## Verdict

**Accept.**
The proposal is implementable as written, matches the maintainer's spec, and its naming mechanics are confirmed against the real script, real transcripts, and a live headless `CLAUDE_CONFIG_DIR` check.
The nits below are optional and mostly delete text.

## Action Items

1. [non-blocking] Rule text: add "briefly" (or "brief") to the note sentence so the 300-word cap does not read as a target.
2. [non-blocking] Remove Open Question 1; Design Decisions already settles it.
3. [non-blocking] Collapse Verification Methodology item 3 into item 1 (`CHAT_RECORD_KEEP=1` plus the `ls` listing).
4. [non-blocking] Trim "Effect on readers" to its one non-redundant line.
5. [non-blocking] Cut the "Several transcripts for one session id" edge case to a clause or drop it; no duplicates exist within a config dir on this host.
6. [non-blocking] Implementer: keep `find_record`'s trailing `return 0`.
