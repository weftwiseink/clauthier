---
review_of: cdocs/proposals/2026-09-22-chat-record-devlog-management.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T09:58:30-07:00
task_list: meta/chat-record-devlog-management
type: review
state: live
status: done
tags: [fresh_agent, architecture, hooks, chat_record, subagent_scoping, shell_quoting, simplification, runtime_validated]
---

# Review: Chat Record, Scratchpoint, and Semantic Devlog Splitting (round 6)

> BLUF(opus-5-5/chat-record-devlog-management): Both r5 blockers are resolved and the round-6 simplification is executed cleanly: two hooks, one `bin/` script, no runtime state, no compaction markers, and only illustrative-example and one history-framed sentence left as stale references.
> Two new blockers, both on the agent's write path: (1) a dispatched subagent's Bash has the *parent's* `CLAUDE_CODE_SESSION_ID` (verified from inside this reviewer, a subagent), so any subagent that follows the per-turn rule writes into the top-level record and can satisfy the top-level `Stop` check with the overseer's `p=`; (2) bullets passed as a double-quoted argument go through shell expansion, and the proposal's own example bullets contain backticks, which execute as command substitution and likely defeat the `Bash(chat-record:*)` allow rule.
> Several pieces of complexity remain that do not earn their keep (quoted-value grammar, the `--record` degraded path, the Phase-3 sketch's length); the `@end` third block is defensible but has a simpler two-block alternative the maintainer should choose between.
> **Verdict: Revise.**

## Summary Assessment

Round 6 implements the maintainer's simplification directives: the record is not compaction-aware, timestamps are per turn, agent blocks carry model and prompt id, `@end` carries the session name, and the never-list is a guideline.
The r5 blockers (script location, permissions) are fixed with exactly the shapes r5 proposed, and the document is internally consistent across diagram, tables, invariants, decisions, test plan, and phases.
The most important new finding is that `CLAUDE_CODE_SESSION_ID` does not distinguish a subagent from its parent, so the "top-level only" property, which rests on the `agent_id` guard for hooks, has no guard at all on the `note` path that the per-turn rule tells every reader to use.
The second is a shell-quoting hazard in the per-turn command itself.
Both are small to fix; the verdict is Revise.

## Verification performed

All from this reviewer's own session (Claude Code 2.1.289), which is a subagent dispatched by the overseer:

- `echo $CLAUDE_CODE_SESSION_ID` printed `e3afd4a9-4352-482d-ad1a-444fa834254a`, which is the **overseer's** session: `~/.claude/projects/-var-home-mjr-code-weft-clauthier-main/e3afd4a9-....jsonl` is the top-level transcript (its `custom-title` is `clauth-opt-context`) and its sibling directory `e3afd4a9-.../subagents/` holds the dispatched agents' transcripts.
  No environment variable observed here identifies the caller as a subagent with documented semantics (`CLAUDE_CODE_CHILD_SESSION=1` is present but undocumented and not checked at top level).
- `PATH` contains `/var/home/mjr/code/weft/clauthier/main/plugins/cdocs/bin` and that directory does not exist: confirms the revision's claim that an enabled plugin's `bin/` is put on PATH unconditionally (for a marketplace install; `--plugin-dir`, which the sandbox tests use, was not checked).
- Transcript: 31 `{"type":"custom-title","customTitle":"clauth-opt-context",...}` lines (re-emitted roughly per turn, alongside `agent-name` and `ai-title` lines); the session directory also holds `custom-title.json` (`{"customTitle":"clauth-opt-context"}`), a single-object sidecar.
  The transcript is 1.5MB at about 30 turns.
- `bash -c 'printf "%s\n" "- query: \`echo RAN\`"'` prints `- query: RAN`: a backtick span inside a double-quoted argument executes.
- `plugins/cdocs/skills/init/SKILL.md` step 3 writes `.claude/rules/cdocs.md` "with core CDocs writing conventions"; only the `AGENTS.md` block (step 6) is specified to inline `orchestration-discipline.md`.
- Stale-term grep (`SessionStart|PreCompact|PostCompact|SessionEnd|@session|announce|sid8|\.prompt|runtime|never-list|chat-record\.sh|PostToolUse|advisory`): hits are in the history NOTE, Non-Goals, dated Decisions 7/10/11/12, the Phase-0 table, Phase-1 constraints, the Phase-3 sketch, and the illustrative examples listed in Finding 4.

## Section-by-Section Findings

### 1. r5 blockers: resolved.

- **Script location.** `plugins/cdocs/bin/chat-record`, bare command on PATH, hooks reference `${CLAUDE_PLUGIN_ROOT}/bin/chat-record <Event>`; the claude.ai/Cowork trade-off is stated in Decision 8; the shim alternative is recorded as rejected with a reason.
  PATH behavior verified above.
- **Permissions.** `/cdocs:init` merges `Bash(chat-record:*)` (Phase 1 deliverable 3, idempotent, never removes entries); README documents both forms; run 8's `bypassPermissions` caveat is stated in Edge Cases and the Phase-0 table; the test plan runs in default mode and includes a denial-without-rule scenario.
- **Real path in the block reason.** Line 257 substitutes the real record path and `--p <pid8>`.
  Good: `--p` also removes the r5 `.prompt`-file item without any state.

### 2. Subagents write into the top-level record. Blocking.

`note` and `path` resolve the record from `CLAUDE_CODE_SESSION_ID`, which inside a dispatched subagent is the parent's id (verified).
The `agent_id` guard protects only hook mode; `note` is invoked by the agent and sees no payload.
The per-turn rule (Phase 1 deliverable 5) is written as "before ending any turn, append at least one bullet", and it ships in `orchestration-discipline.md`, which reaches subagents through the same project rules the top-level agent reads.
Consequences:

- Every reviewer, implementer, proposer, and judge leg that obeys the rule appends `@<model>` entries to the overseer's record, defeating "top-level only" (Non-Goals) and the gist discipline.
- Worse, `note` defaults `p=` to the last `@user`/`@harness` header, which is the overseer's in-flight turn, so a foreground leg's note satisfies the overseer's `Stop` check and the overseer's own lapse is never blocked.
- The only stated guard is "their briefs say so" (line 276), which contradicts the unconditional rule text the same legs will read.

Fix, smallest first: scope the rule text itself ("top-level session only; if you were dispatched by the `Agent` tool, never run `chat-record`"), add the same one line to each `agents/*.md` definition, and add a Phase-1 scenario: a foreground subagent with the materialized rules loaded and a task long enough to end several of its own turns, asserting no entry by the subagent and that the overseer's `Stop` still blocks when the overseer itself did not note.
If a reliable subagent signal is found (a documented env var, or a cheap check against the session's `subagents/` directory), `note` can refuse mechanically; do not build that without a canary.

### 3. Shell expansion of the bullet argument. Blocking.

The documented invocation is `chat-record note --as <model> "- gist: ..."`.
Inside double quotes, backticks and `$(...)` execute and `$VAR` expands.
The proposal's own example bullets (line 221: `` - query: `strings claude.exe | grep -E "PreCompact|PostCompact"` ``; line 203 and the Scratchpoint example use backticked paths) are exactly the shape agents write in markdown-heavy repos, so the per-turn command will routinely run arbitrary embedded commands and record their output instead of the text.
Claude Code's permission check also treats command substitution as a separate command, so a bullet containing backticks very likely prompts or is denied despite `Bash(chat-record:*)`, which recreates the r5 blocker-2 failure on exactly the turns that quote code.
An apostrophe ("didn't") breaks the obvious single-quote workaround.

Fix: `note` reads the body from stdin when no positional body is given, and the rule text, the `Stop` block reason, and the devlog skill show the quoted-heredoc form (`chat-record note --as <model> <<'EOF'` ... `EOF`), which performs no expansion; keep the positional form only for plain text.
Add a default-mode test whose bullet contains a backtick span, `$HOME`, `$(date)`, and an apostrophe, asserting the body round-trips byte-exact and `permission_denials` is empty.
If the heredoc form turns out not to match the allow rule, that test is where it shows, and the fallback is the single-quoted form with the rule saying to avoid apostrophes.

### 4. Stale references (focus b): nearly clean.

No design-body sentence describes a removed hook, marker, or state file as current.
Residue, all non-blocking:

- Line 203, `read:` example: "`inject-rules.ts`: the additionalContext emit shape every new hook copies".
  No round-6 hook emits `additionalContext`; the example now teaches the wrong template.
- Lines 340-341, Scratchpoint example: "SessionStart entry is the template for the new ones" and "`inject-rules.ts` (r): the silent-exit guards to copy".
  The new entries are shell commands like the two existing `.sh` hooks; point the example at `validate-cdocs-edit-path.sh`.
- Line 309: "the claim that only a hook knows the session id was false (round-5 review)" is history framing in the design body; drop the clause or move it into the Summary NOTE.

### 5. Soundness of the round-6 mechanisms (focus c).

- **`CLAUDE_CODE_SESSION_ID` derivation.** Sound for the top level (r5 run A, this session); see Finding 2 for subagents.
  The `--record` override and the "variable absent" degraded path (Edge Cases line 452, Invariants) exist only for a hypothetical rename that the Phase-1 equality test already catches.
  Non-blocking simplification: drop `--record`; when the variable is absent, `note` and `path` print one stderr line and exit non-zero.
- **Exit codes for agent-invoked modes.** "Always exit 0" is right for hook mode and wrong for `note`/`path`: a `note` that silently wrote nothing reports success to the agent, which then gets blocked by `Stop` with no idea why.
  Non-blocking: `note` and `path` exit non-zero with a one-line reason on any failure; `CDOCS_CHAT_RECORD=off` can stay exit 0.
- **Session name from `custom-title`.** Sound and verified.
  Two refinements, non-blocking: read the last match from the end (`tac "$transcript" | grep -m1 '"type":"custom-title"'`), since transcripts reach tens of MB and `Stop` runs every turn; or read the `<session_id>/custom-title.json` sidecar next to the transcript (one small file, equally undocumented).
  For unnamed sessions, the transcript's `ai-title` is a more readable fallback than sid8, if the maintainer wants a name on every `@end`.
- **The separate `@end` stamp.** The directive wants an end time and the session name per turn; a true end time can only come from `Stop`, and an append-only file cannot amend the agent's header, so the third block is the honest shape for that directive.
  A simpler shape exists if "end time" may mean "time of the turn's note": put `session=` on the `@user` header (`UserPromptSubmit` has `transcript_path` too), take the agent entry's timestamp as the turn end (the rule already says to note with the turn's last action), and `Stop` becomes a pure check that writes nothing.
  That gives two blocks per turn, one fewer write path, and loses only the final-reply inference time and the explicit marker on ignored-block turns (still visible as a `@user` with no entry).
  Not blocking; see Questions.
- **Lazy creation.** Sound.
  Unspecified: what `note` writes for `p=` when it creates the file (no prior header); say it omits `p=` and that the subsequent `Stop` block supplies `--p`.
  And whether `path` creates the file (the test at line 491 implies not); say "prints, never creates".
- **Interrupted turns.** Both branches are stated and the suppression decision is deferred to interactive check (c) with a named candidate signal.
  Adequate for a proposal.
- **cdocs root resolution.** Walking up from `$PWD` means a session that changes directory into another worktree (`EnterWorktree`, or a `cd` into `.claude/worktrees/<name>/`, which has its own `cdocs/`) starts a second record with the same filename in a different root.
  Non-blocking: state it as an accepted edge case, or pin the root to the first record found by glob.
- **Queued mid-turn prompts.** This session's transcript has 50 `queue-operation` lines; whether a message typed during a turn fires `UserPromptSubmit` mid-turn (and so moves `note`'s default `p=`) is unverified.
  Non-blocking: add it to the interactive check or the not-verified list.

### 6. Rule delivery to the top-level agent. Non-blocking, but make it explicit.

Background item 4 rests on "`/cdocs:init` materializes cdocs rules unscoped", and the whole per-turn and post-compaction behavior lives in `orchestration-discipline.md` Pillar 2.
The init skill as written puts only "core CDocs writing conventions" into `.claude/rules/cdocs.md`, the file Claude Code loads; the full `orchestration-discipline.md` is specified only for `AGENTS.md`, which Claude Code does not read.
The Phase-1 rules check would catch this, but late.
Phase 1 deliverable 3 should state that `.claude/rules/cdocs.md` carries Pillar 2 (or the per-turn and post-compaction steps verbatim), with a test asserting the marker string is present in the materialized file.

### 7. Implementability and test plan (focus d): concrete.

Phase 1 deliverables map one-to-one to the contract, and the scenario list covers block-and-recover, never-loops, denial-without-rule, harness, dispatch, slash commands, resume, `/clear`, rename, opt-out, and the env-var equality.
Gaps, non-blocking beyond the two blockers' scenarios:

- The Verification Methodology command omits `--plugin-dir <worktree>/plugins/cdocs`, without which a sandboxed config has no plugin and no `chat-record` on PATH; and when developing in a sibling worktree, the installed plugin's PATH entry points at `main/`, so tests could exercise the wrong script.
  Make the first assertion "`command -v chat-record` resolves into the worktree under test".
- Phase 2 and the A/B are unchanged from r5 and remain adequate.

### 8. Remaining complexity that does not earn its keep (maintainer's request).

- **Quoted metadata values.** The `qchar` grammar with four escapes, the "session title with `\"` and a newline" fixture, and the "metadata lives on the header line only" defense exist for one value, `session=`.
  Sanitize the title to a bare token (map anything outside `[A-Za-z0-9._-]` to `-`) and delete the quoting rules.
  The body escape for header-shaped lines does earn its keep, because bodies are verbatim prompts.
- **`--record` and the absent-variable degraded path.** See Finding 5.
- **Phase-3 per-workstream sketch.** About 25 lines of design for something explicitly not built, with four gating canaries.
  Replace with a three-line pointer (scope: per `task_list`; mechanism: `SubagentStart`/`SubagentStop` with the guard relaxed; gating canaries listed) or move it to an RFP stub.
- **Document size.** 86KB for a two-hook script plus rule text.
  The history NOTE, dated decision parentheticals, and Phase-0 table are earned; much of the Scratchpoint and splitting prose repeats itself across the section, Decision 5, and Phase 2.
  Not an action item for this round beyond the Phase-3 trim.

### 9. Writing conventions (focus e): compliant.

No em-dashes, sentence-per-line, direct links, mermaid diagram, BLUF matches the body.
One history-framed sentence (Finding 4, line 309).

## Verdict

**Revise.**
The r5 blockers are fixed and the simplification is clean.
Two write-path gaps block, because each makes the per-turn rule produce wrong records under normal use: subagents writing into (and satisfying the `Stop` check of) the top-level record, and shell expansion of the bullet argument.
Both are rule-text plus test-scenario fixes, with one small script addition (stdin body).

## Action Items

1. [blocking] Scope the per-turn rule to the top-level session in the rule text and in each `agents/*.md`; state in the script contract that `CLAUDE_CODE_SESSION_ID` is the parent's id inside subagents (verified 2.1.289), so `note` has no mechanical top-level guard; add a Phase-1 scenario with a multi-turn foreground subagent asserting no subagent entry and that the overseer's own `Stop` still blocks.
2. [blocking] Make `note` read its body from stdin when no positional body is given; show the quoted-heredoc form in the rule text, the `Stop` block reason, and the devlog skill; add a default-mode test with backticks, `$HOME`, `$(date)`, and an apostrophe asserting byte-exact round-trip and no `permission_denials`.
3. [non-blocking] Fix stale examples at lines 203 and 340-341 and the history-framed clause at line 309.
4. [non-blocking] `note`/`path` exit non-zero with a reason on failure; drop `--record` and the absent-variable degraded path, relying on the equality test.
5. [non-blocking] Sanitize `session=` to a bare token and remove the quoted-value grammar and its fixtures.
6. [non-blocking] Read the session title from the end of the transcript (`tac | grep -m1`) or the `custom-title.json` sidecar; optionally fall back to `ai-title`.
7. [non-blocking] Specify `note`'s `p=` when it creates the file, and that `path` never creates.
8. [non-blocking] State the cwd-change (second cdocs root) edge case; add queued mid-turn prompts to the interactive check or the not-verified list.
9. [non-blocking] Phase 1 deliverable 3: `.claude/rules/cdocs.md` must carry the Pillar 2 per-turn and post-compaction steps, with a presence test.
10. [non-blocking] Test harness: add `--plugin-dir` to the methodology command and assert `command -v chat-record` resolves into the worktree under test.
11. [non-blocking] Trim the Phase-3 per-workstream sketch to a short pointer or an RFP stub.

## Questions / Options for the Maintainer

- **Turn shape.** (a) Three blocks per turn as written: `@user`, `@<model>`, `@end` with true end time and session name (Stop writes); (b) two blocks: `session=` on `@user`, the agent entry's timestamp stands in for turn end, `Stop` only checks and blocks (simpler, loses final-reply latency and the explicit ignored-block stamp); (c) as (a) but `@end` written only when no entry exists, as a gap marker (recommended against: makes the end time inconsistent across turns).
- **Subagent guard.** (a) Rule text and agent definitions only (recommended now); (b) also canary an environment or filesystem signal for "running inside a subagent" and make `note` refuse; (c) let legs note into the parent record with an `agent=` key, which is the Phase-3 sketch's territory and should not arrive by accident.
- **Unnamed-session fallback.** (a) sid8 as written; (b) the transcript's `ai-title`, sanitized (more readable, changes over the session); (c) omit `session=` when unnamed.
