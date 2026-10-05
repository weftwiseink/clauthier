---
review_of: cdocs/proposals/2026-09-22-chat-record-devlog-management.md
first_authored:
  by: "@claude-fable-5-1"
  at: 2026-10-05T09:44:05-07:00
task_list: meta/chat-record-devlog-management
type: review
state: live
status: done
tags: [fresh_agent, architecture, hooks, chat_record, stop_block, permissions, test_plan, runtime_validated]
---

# Review: Chat Record, Scratchpoint, and Semantic Devlog Splitting (round 5)

> BLUF(fable-5-1/chat-record-devlog-management): The round-5 redesign executes all four maintainer directives cleanly and the document is internally consistent: the stale-reference sweep hits only history NOTEs, Non-Goals, dated decisions, the Phase-0 table, and the Phase-3 sketch, exactly as the revision devlog claims.
> Two implementability gaps block: (1) the agent has no specified way to invoke `chat-record.sh` (`CLAUDE_PLUGIN_ROOT` is not in the Bash tool's environment; the fix is the plugin `bin/` directory, which Claude Code puts on the Bash tool's PATH), and (2) the per-turn `note` call is a Bash command that default permission mode prompts for interactively and denies headless (verified: a sandboxed default-mode `-p` run returned `DENIED This command requires approval`), so without an allow rule the `Stop` block fires and is wasted on every turn.
> Run 8, the only evidence that the block is honored, ran under `bypassPermissions`.
> Also: the `SessionStart(compact)` justification rests on "only the hook has `session_id`", which is false on 2.1.289 (`CLAUDE_CODE_SESSION_ID` is exported to the Bash tool and equals the hook's `session_id`, verified headless); keep the announcement, fix the claim, and use the variable as the fallback the unverified interactive `/compact` path needs.
> **Verdict: Revise.** Both blockers are small, contained additions to Phase 1; the design itself is sound.

## Summary Assessment

Round 5 collapses the hook surface to five events (three load-bearing) and moves every judgment-bearing behavior to the agent and the rules: one gist bullet per top-level turn enforced by a one-shot `Stop` block, compaction guided by re-injected Pillar 2 text, markers only for `PreCompact` and `SessionEnd`.
The rewrite is coherent rather than patched: the diagram, speaker table, hook table, invariants, decisions, edge cases, test plan, phases, and Phase-3 sketch all describe the same five-event design, and the `files=`/`.turn`/`.acted`/`.quiet`/`.devlog`/`@compact` vocabulary survives only in dated rationale.
The `Stop`-block design matches the canary (prompt-id correlation, run 6; block honored and bounded, run 8) and the edge-case treatment of harness, dispatch-only, pure-chat, and headless turns is right in principle.
What the proposal omits is the agent's side of the write path: how the agent finds the script, and whether the harness lets it run the command without a prompt.
Both are answerable from current Claude Code behavior and I verified the answers below; they must be in the spec before an implementer starts, because they decide whether the per-turn rule works at all outside `bypassPermissions`.

## Verification performed

- Stale-reference sweep: `grep -nE 'PostToolUse|PostCompact|files=|\.quiet|\.acted|\.turn\b|\.devlog\b|\.model\b|@compact|quiet|advisory|nudge|placeholder|three-tier'` over the proposal.
  Every hit is in the Summary history NOTE, the upstream-status NOTE, Non-Goals, Decisions 7/10/11, the Phase-0 "also verified but not relied on" line, the Phase-1 "do not register" constraint, the Phase-3 sketch, or the `inject-rules.ts` citation; one body sentence is history-framed (Finding 8).
  The devlog's "17 hits" claim is accurate in substance.
- Path-regex claim (proposal line 137): both `validate-cdocs-edit-path.sh` and `cdocs-validate-frontmatter.sh` match `cdocs/(devlogs|proposals|reviews|reports)/`, so `_chat/` is excluded as stated.
- Agent Bash environment, from this session (Claude Code 2.1.289): `CLAUDE_CODE_SESSION_ID` is set and names the top-level session's transcript (`~/.claude/projects/<proj>/<that id>.jsonl` exists); `CLAUDE_PLUGIN_ROOT` is absent; PATH contains `<plugin root>/bin` for each enabled plugin.
- Plugin reference (https://code.claude.com/docs/en/plugins-reference.md): "Executables | `bin/` | Files here are on the Bash tool's `PATH` while the plugin is enabled, so Claude runs them as bare commands. claude.ai and Cowork don't install a plugin that has this directory"; and "The variables aren't present in the environment of commands Claude runs through the Bash tool, in the main session or in a subagent."
- Three sandboxed headless runs (README recipe: fresh `CLAUDE_CONFIG_DIR`, copied credentials, empty out-of-repo cwd, `--model haiku`, 2.1.289):
  - Run A (`bypassPermissions`): `echo $CLAUDE_CODE_SESSION_ID` printed `2d0988e7-...`, equal to the run's `session_id` in the JSON result; `CLAUDE_PLUGIN_ROOT` printed empty.
  - Run B (default mode): `echo hello-perm` ran without denial (auto-allowed safe command; not representative).
  - Run C (default mode): a local `./note.sh "- gist: canary"` that appends to a file: result `DENIED This command requires approval`, `permission_denials` lists the Bash call, file not written.
    This is the shape of the real `note` call.
- Hooks reference (https://code.claude.com/docs/en/hooks.md): `Stop` is described only as "When Claude finishes responding"; nothing on interrupt behavior; `prompt_id` is a common input field ("Absent until the first user input", v2.1.196+).

## Section-by-Section Findings

### 1. Internal consistency (focus a): clean. Non-blocking nits only.

The design body nowhere describes a removed mechanism as current.
The diagram's event list, the speakers table (`@session` on `SessionStart`/`PreCompact`/`SessionEnd`), the hook table (five rows), the invariants (one runtime file), Phase 1 deliverable 1, and the Phase-1 constraints all agree.
Phase 3 was correctly re-based: the per-agent `PostToolUse` buffer is gone, gating item (a) now names the `## Chat Record` pointer instead of active-devlog tracking, and "no per-leg file list is captured (Decision 11 applies to legs)" closes the gap the removal opened.

Nits:
- Line 215 lists the header metadata keys but omits `sid=` and `cwd=`, which line 130 puts on the first `@session` line.
- Line 130's collision fallback (`YYYY-MM-DD-<session_id>.md`) does not match the primary glob `*-<sid8>.md` (a full UUID does not end in its first eight characters), so every later event re-hits the stranger's file, re-detects the mismatch, and must re-derive the fallback name without recomputing the date.
  State the lookup order explicitly: glob `*-<full session_id>.md` first, then `*-<sid8>.md` with the `sid=` check.
- Line 299 says `custom_instructions` "arrives in the `PreCompact` payload (verified, Phase 0)".
  Run 2 verified the field is present with value `null`; a non-null value has not been observed.
  The test plan's `/compact Keep X` scenario covers it; the prose should say "field present; non-null value is a Phase-1 test".

### 2. Agent invocation path for `chat-record.sh` is unspecified. Blocking.

The proposal says the agent calls `chat-record.sh note ...` from `Bash` (lines 36, 246, 261, 568) and that it knows the record path from the announcement (line 248), but never says how it finds the script.
In a consumer install the plugin lives in `~/.claude/plugins/cache/<marketplace>/cdocs/<version>/hooks/`, a path the agent does not know, and the plugin reference is explicit that `CLAUDE_PLUGIN_ROOT` is not exported to Bash-tool commands (confirmed empirically, run A).
The `Stop` block reason (line 261) tells the agent to run `chat-record.sh note --as <model> <record path> ...` with a bare script name and placeholder path, so an agent that forgot would be told to run a command it cannot locate.

Fix, which the platform already supports: ship the script as `plugins/cdocs/bin/chat-record` (hooks.json entries still reference it by `${CLAUDE_PLUGIN_ROOT}/bin/chat-record <Event>`), so the agent runs `chat-record note ...` as a bare command.
This also gives the permission rule in Finding 3 a stable prefix.
Trade-off to state: a plugin with a `bin/` directory is not installable through claude.ai or Cowork; cdocs is a CLI-and-OpenCode plugin so this is acceptable, but Decision 8 or a new decision should say so.
Alternative if `bin/` is rejected: the `SessionStart` announcement carries the absolute script path as well as the record path (fits in 200 bytes only barely), and the block reason substitutes both real paths rather than placeholders.
Either way, the block reason must carry the actual record path, not `<record path>`: the hook has it at `Stop` time, and the post-compaction window is exactly where the agent may have lost the announcement.

### 3. Permission mode: the `note` call prompts interactively and is denied headless. Blocking.

Every compliant turn ends with a Bash call.
In default permission mode an unallowlisted command prompts the user on every turn, which makes the rule unusable interactively without an allow rule; in headless `-p` default mode the call is denied outright (run C).
Run 8, the proposal's evidence that "the block is honored under `-p`" (Edge Cases, headless bullet; Phase-0 table), used `--permission-mode bypassPermissions`, so the honored path has not been shown under default permissions.
Under default permissions the sequence per turn is: agent stops without entry, hook blocks, agent tries `note`, call denied, agent stops, `stop_hook_active=true`, hook silent.
That is one wasted round-trip on every turn and a record with zero agent entries, the precise failure the block exists to prevent.

Fix: Phase 1 deliverable 3 (`/cdocs:init`) also writes `permissions.allow: ["Bash(chat-record note:*)"]` (pattern to match the final invocation shape from Finding 2) into the project's `.claude/settings.json`, and the README documents it for installs that skip init; the Edge Cases headless bullet states the run-8 caveat and the allow-rule dependency; the Test Plan gains a default-permission-mode scenario (no `bypassPermissions`) asserting that `note` runs without a `permission_denials` entry and that the block-and-recover path completes.
Also list `--allowedTools "Bash(chat-record note:*)"` as the per-invocation form for ad-hoc `-p` runs.

### 4. `Stop`-block design against the canary (focus b): sound, with three additions.

Correlation and bounding hold: run 6 shows `Stop.prompt_id` equals the turn's `UserPromptSubmit.prompt_id`, run 8 shows a block honored once and the second `Stop` arriving with `stop_hook_active=true`, and the suppression list (off switch, no `jq`, no `cdocs/`, no record, no `prompt_id`) makes the block unreachable whenever the hook cannot do its job.
The agent-ignores-the-block case degrades to a visible gap, not a loop.
Harness, dispatch-only, and pure-chat turns are handled consistently ("owes a bullet like any other") and the examples given for each are honest minimal bullets.

Additions, non-blocking:
- **Interrupted turns.** The docs say nothing about `Stop` on interrupt (only "when Claude finishes responding").
  The proposal covers the "does not fire" branch; it should also state the "does fire" branch: the block would resurrect the agent for one short turn after the user pressed Escape, which is user-hostile, and whether that is acceptable or needs a guard is a decision to record.
  Add "interrupt a turn mid-tool-call" to interactive check (c).
- **Per-turn cost is understated.** The proposal names the forgotten-turn cost (one extra short turn) but not the compliant-path cost: one Bash tool call per turn is one extra model inference per turn, on every turn including one-line answers.
  State it, and have the rule text suggest issuing `note` in the same parallel tool batch as the turn's last action where the outcome is already known, so the common case costs no extra round-trip.
- **`Stop` with no `.prompt` file.** The `Stop` payload carries `prompt_id`; before blocking, the hook can write `<session_id>.prompt` itself when it is missing (hook enabled mid-session, resume replay), so the agent's `note` correlates instead of omitting `p=`.

### 5. Filler risk and the `gist:` guidance (focus b): adequate, with one measurement gap.

The guidance is better than a bare "write something": the never-list bans a shape (enumerated actions, hashes, reply text) rather than subjects, the minimal honest bullet is shown for each turn type, and the bounds (one to three bullets, ~120 characters) cap the damage a filler bullet can do.
A hook that checks presence only cannot coerce content, which is the right division.
Residual risk is "gist: no state change" on every routine turn, which is permitted and sometimes correct.
The Phase-1 success criterion checks shape (categories, no reply text, no hashes, no action lists) but not usefulness.
Add a usefulness sample to the real-session criterion: a fresh reviewer scores twenty random `@<model>` entries on "would a successor reading only the `@user` blocks and this bullet know where things stand", with a pass bar (say 80%), so the directive-2 premise ("every turn has a gist") is tested empirically rather than assumed.

### 6. `SessionStart(compact)` announcement justification (focus c): decision right, stated reason wrong.

The proposal keeps the announcement because "rules cannot carry the chat-record path: it derives from `session_id`, which only the hook has" (line 304), and Decision 7 says of the unverified interactive `/compact` path that "the only hook that observes it is the marker".
Both claims are inaccurate:
- `CLAUDE_CODE_SESSION_ID` is exported to the Bash tool and equals the hook's `session_id` (runs A and this session).
  It is undocumented (the hooks reference mentions only `CLAUDE_CODE_BRIDGE_SESSION_ID`), so it should not replace the announcement, but it is exactly the fallback the design lacks: `chat-record path` (or `note` with no record argument) can resolve `cdocs/_chat/*-<sid8>.md` from the environment when the announcement is missing from the post-compaction window.
- `SessionStart(compact)` observes interactive `/compact` as much as `PreCompact` does, and it carries the announcement; if it did not fire interactively, the loss would be the path, not an audit line.
  The interactive check (a) already covers this; Decision 7's sentence should match it.

The surviving argument for the announcement is the right one: same code path, under 200 bytes, no per-source logic, verified visible post-compaction (run 4).
Keep it, fix the two sentences, add the environment-variable fallback to `note`, and add a one-line Phase-1 assertion that the variable equals the hook's `session_id` so a future rename fails loudly.

### 7. Implementability and test plan (focus d): concrete, with coverage gaps.

Phase 1 deliverables are specific enough to implement once Findings 2 and 3 land.
The test plan is well-shaped (artifact assertions plus stream assertions, never-loops scenario, opt-out and no-`cdocs/` scenarios, payload-shape guard).
Gaps, non-blocking:
- No `@harness` scenario: a background `Agent` dispatch (run 5's shape) asserting the second `UserPromptSubmit` is classified `@harness` with its own `p=` and that the harness turn's entry satisfies its `Stop`.
- `--resume` and `/clear` are deferred to the manual check, but `claude -p --resume <session_id> "<prompt>"` runs headless and `/clear` can be sent as a stream-json user line exactly as `/compact` was in run 2; move both into the automated tests and keep only the TUI `/compact` and the interrupt case manual.
- No unit test for the sid-collision fallback (pre-create `*-<sid8>.md` with a foreign `sid=`).
- The Phase-1 rules check runs "with the rules materialized by `/cdocs:init`"; that is the right shape, because the reseed premise of directive 3 holds in consumer repos only if Pillar 2 is in the unscoped `.claude/rules/cdocs.md` that init writes (the init skill's step 3 says "core CDocs writing conventions"; the AGENTS.md block is where the full `orchestration-discipline.md` is named).
  Make the rules check assert, from the stream, that the post-compaction turn's context contains the Pillar 2 boundary text, not only that the re-reads happened.
- Default-permission-mode scenario per Finding 3.

### 8. Writing conventions (focus e): compliant, one history-framed sentence.

No em-dashes; sentence-per-line throughout; direct links on first mention; no emojis; BLUF leads and matches the body.
Line 307 ("What was dropped and why: the three-tier active-devlog resolution ...") is history framing in the design body; conventions put prior approaches in a NOTE callout for proposals.
Decision 10's dated "Reverses round 4's ..." parenthetical is the established pattern in this document's decisions and is acceptable.
The document is 82KB; no action, but the implementer's devlog should not quote it.

### 9. Revision devlog: accurate.

The devlog's evidence list, design-choice list, and verification scan match what the diff shows.
Its "Tension with prior rulings" section correctly records that round 4's graceful-degradation argument is kept as the floor and that r4 S1-S3 are moot or folded.

## Verdict

**Revise.**
The redesign satisfies all four directives and is internally consistent; nothing in the design needs rethinking.
Two Phase-1 specification gaps block because they determine whether the per-turn rule works outside `bypassPermissions`: the agent's invocation path for the script (ship it in the plugin's `bin/`), and the permission allow rule the `note` call needs (write it from `/cdocs:init`, test it in default mode).
The `SessionStart(compact)` justification needs its factual claim corrected and gains a fallback for free.
Everything else is additive.

## Action Items

1. [blocking] Specify how the agent invokes the script: move it to `plugins/cdocs/bin/chat-record` (on the Bash tool's PATH while enabled; hooks reference it via `${CLAUDE_PLUGIN_ROOT}/bin/chat-record <Event>`), update lines 36, 246, 261, 568, and Phase 1 deliverable 1 to the bare command, state the claude.ai/Cowork non-installability trade-off, and make the `Stop` block reason carry the actual record path.
2. [blocking] Add the permission story: `/cdocs:init` writes `permissions.allow` for the `note` invocation into `.claude/settings.json` (README documents the manual and `--allowedTools` forms); correct the headless edge case and Phase-0 table to say run 8 ran under `bypassPermissions`; add a default-permission-mode block-and-recover scenario to the Phase-1 hook tests.
3. [non-blocking] Fix the `SessionStart(compact)` justification (line 304) and Decision 7's "only hook that observes it" sentence; add `CLAUDE_CODE_SESSION_ID` as `note`'s record-path fallback (undocumented, so fallback not primary) with a Phase-1 assertion that it equals the hook's `session_id`.
4. [non-blocking] Interrupted turns: state both branches (fires / does not fire) and the desired behavior if it fires; add the case to interactive check (c).
5. [non-blocking] State the compliant-path cost (one Bash call per turn) and have the rule suggest batching `note` with the turn's last tool call.
6. [non-blocking] Add a fresh-reviewer usefulness sample (twenty entries, pass bar) to the Phase-1 real-session success criterion.
7. [non-blocking] Test plan: add `@harness` (background dispatch), headless `--resume` and stream-json `/clear`, sid-collision fallback, and a Pillar-2-text-present assertion in the rules check; soften line 299 to "field present; non-null value is a Phase-1 test".
8. [non-blocking] `Stop` writes `<session_id>.prompt` from its own `prompt_id` when the file is missing, before blocking.
9. [non-blocking] Line 215: list `sid=` and `cwd=`; line 130: state the lookup order (`*-<full id>.md` first, then `*-<sid8>.md` with `sid=` check).
10. [non-blocking] Move line 307's "What was dropped and why" into a NOTE callout.

## Questions / Options for the Maintainer

- **Script location.** (a) `plugins/cdocs/bin/chat-record`, bare command on PATH, forfeits claude.ai/Cowork installability (recommended: cdocs is CLI/OpenCode-targeted and the hook is Claude-Code-only anyway); (b) keep it under `hooks/` and carry the absolute script path in the `SessionStart` announcement and block reason (fragile, path changes on every plugin update); (c) `/cdocs:init` materializes a project-local shim that `exec`s the cached script (works everywhere, but the shim embeds a version-specific cache path and goes stale on update).
- **Environment-variable fallback.** (a) `note` resolves the record from `CLAUDE_CODE_SESSION_ID` when no path is given and the announcement is the documented primary (recommended); (b) announcement only, as written; (c) env var primary and drop the announcement (not recommended: undocumented variable).
- **Interrupt behavior if `Stop` fires on interrupt.** (a) accept the one-turn resurrection as the cost of a complete record; (b) suppress the block when `last_assistant_message` is empty, treating it as an abandoned turn (heuristic, untested); (c) decide after interactive check (c) shows whether it fires at all (recommended).
