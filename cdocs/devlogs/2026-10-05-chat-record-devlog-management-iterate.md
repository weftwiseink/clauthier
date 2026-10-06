---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T12:17:00-07:00
task_list: cdocs/chat-record-devlog-management
type: devlog
state: live
status: wip
tags: [chat-record, hooks, devlog, orchestration, iterate]
---

# Chat-Record Devlog Management: Iterate Loop

> BLUF(opus-5-5/cdocs/chat-record-devlog-management): Implement-review loop for [`2026-09-22-chat-record-devlog-management.md`](../proposals/2026-09-22-chat-record-devlog-management.md) Phases 1a, 1b, 2 in order (Phase 3 out of scope), composed under the `/oversee` arc [`2026-10-05-oversee-haiku-bash-wrapper.md`](2026-10-05-oversee-haiku-bash-wrapper.md).

## Brief

- **Scope:** Phase 1a (text-only removal of agent-side compaction instructions, Scratchpoint definition, judge thinness via `inline_work`), then Phase 1b (capture: `bin/chat-record`, hooks, tests, CI, init, per-turn rule, resumption steps), then Phase 2. One accept per phase before the next starts.
- **Verification floor:** Phase 1a: both scoped greps in the proposal's 1a success criteria give exactly the specified results, and a fresh consistency read of rules/skills/agents finds no dangling reference to the removed cadence, ctx_est column or compact instructions (failure picture: judge.md or iterate/template.md still references overseer_ctx_est or a Scratchpoint-staleness check). Phase 1b: the `--unit` suite passes locally, every non-optional headless scenario passes, and a real multi-turn headless session in a scratch repo with `cdocs/_chat/` produces a record where every `@user` is followed by an agent entry and exactly one sign-off (failure picture: Stop blocks twice, loops, or blocks in an uninitialized project or plan mode; a subagent note lands in the top-level record). Phase 2 per the proposal's success criteria.
- **Go-ahead:** maintainer, 2026-10-05, conditional on no critical review findings (met at r12, proposal `implementation_ready` at `0b051f6`).
- **Note:** this loop's own Iteration Log omits `overseer_ctx_est` per the maintainer directive that Phase 1a implements.

## Iteration Log

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | inline_work | notes |
|---|---|---|---|---|---|---|---|
| 1 (1a) | impl-1 (cdocs:implementer) | rev-1 (cdocs:reviewer) | accept | n/a | cdocs/reviews/2026-10-05-review-of-chat-record-impl-1a-r1.md | no | Phase 1a accepted; greps re-run by reviewer; 6 non-blocking wording nits batched into Phase 1b; overseer default: iterate/template.md gains `## Scratchpoint` in 1b |
| 2 (1b) | impl-2 (cdocs:implementer) | rev-2 (cdocs:reviewer) | revise | confirmed | cdocs/reviews/2026-10-05-review-of-chat-record-impl-1b-r1.md | no | blocking: macOS sed `\r` in escape_body; rules check fails post-compaction (reviewer A/B: 3-line CLAUDE.md block beside import line 2/3 haiku); 7 non-blocking; maintainer interactive checks listed |
| 3 (1b) | impl-3 (cdocs:implementer) | rev-3 (cdocs:reviewer) | accept | confirmed | cdocs/reviews/2026-10-05-review-of-chat-record-impl-1b-r2.md | no | 94/94 unit (incl. bash 3.2, BSD-sed sim), 25/25 non-optional headless; rules_check deferred to RFP; maintainer checklist (CI push, interactive a-d, 20-turn opus session, 16/20 sample) pending; minors: speaker regex gap, proposal sync lines |
| 4 (2) | impl-4 (cdocs:implementer) | rev-4 (cdocs:reviewer) | revise | n/a | cdocs/reviews/2026-10-06-review-of-chat-record-impl-2-r1.md | no | major: triage step 6.1 skips chunks when locating the iterate devlog, so a split loop devlog (table in a chunk) loses loop state and can regress `implementation_accepted`; minor: RFP A/B pass bar contradicts its Test protocol/Acceptance bar; nits: hook-output byte budgets kept (platform cap), dry-run copy dangling ref (uncommitted), lone small closed concern stays in root |
| 5 (2) | impl-5 (cdocs:implementer) + overseer inline | rev-5 (cdocs:reviewer) | revise | n/a | cdocs/reviews/2026-10-06-review-of-chat-record-impl-2-r2.md | yes | blocking: triage chunk rule named steps 2-4/6 only, so step 6.5 still read an empty root table (mid-loop guard lost); overseer applied rev-5's exact one-sentence wording inline (`8db23fa`, steps 2-6, latest row across chunks) and answered its question by default: moved-rows pointer is a line below the live table, not a row (`650e936`) |
| 6 (2) | overseer inline (`8db23fa`, `650e936`) | rev-6 (cdocs:reviewer) | accept | n/a | cdocs/reviews/2026-10-06-review-of-chat-record-impl-2-r3.md | no | Phase 2 accepted: three triage scenarios walked (finished loop in chunk, mid-loop empty root, unsplit); build OK. Loop terminal: Phases 1a-2 `implementation_accepted` |

## Judge Log

| judge_iteration | trigger | verdict | overseer_thinness | rationale | judge_path |
|---|---|---|---|---|---|

## Dispatch/Return Events

| event | agent_handle | target_files | at | notes |
|---|---|---|---|---|
| dispatch | impl-1 (cdocs:implementer) | plugins/cdocs/rules/**, plugins/cdocs/skills/**, plugins/cdocs/agents/** (Phase 1a scope), proposal frontmatter, this devlog (Implementation Notes) | 2026-10-05T12:17:00-07:00 | Phase 1a |
| return | impl-1 (cdocs:implementer) | same | 2026-10-05T12:53 | Phase 1a: `ed35dc9`..`757028b`, notes `111c2be`; grep1 empty, grep2 reseed line only; build OK; 7 judgment calls flagged |
| dispatch | rev-1 (cdocs:reviewer) | cdocs/reviews/2026-10-05-review-of-chat-record-impl-1a-r1.md | 2026-10-05T12:54 | Phase 1a review |
| return | rev-1 (cdocs:reviewer) | same | 2026-10-05T12:59 | `5b65842` accept |
| dispatch | impl-2 (cdocs:implementer, fresh: new phase, impl-1 context ~150K) | plugins/cdocs/bin/**, plugins/cdocs/hooks/**, plugins/cdocs/rules/**, plugins/cdocs/skills/**, plugins/cdocs/README.md, scripts/cdocs-hooks.ts, .github/workflows/cdocs-hooks.yml, cdocs/_chat/**, this devlog (notes) | 2026-10-05T13:00 | Phase 1b + 1a nits |
| return | impl-2 (cdocs:implementer) | same | 2026-10-05T13:47 | Phase 1b: `f3b4806`..`42e0b93` (17); 132/132 tests (75 unit, 57 headless); 20-turn headless record well-formed; FAILS rules check (post-compaction step 3 not followed by haiku/sonnet/opus); interactive checks + usefulness sample not run |
| dispatch | rev-2 (cdocs:reviewer) | cdocs/reviews/2026-10-05-review-of-chat-record-impl-1b-r1.md | 2026-10-05T13:48 | Phase 1b review |
| return | rev-2 (cdocs:reviewer) | same | 2026-10-05T14:01 | `d208e0b` revise; awaiting maintainer decision on post-compaction placement |
| dispatch | impl-3 (cdocs:implementer, fresh: impl-2 ~284K) | plugins/cdocs/bin/chat-record, plugins/cdocs/hooks/**, .github/workflows/cdocs-hooks.yml, proposal (1 success-criterion line), this devlog (notes) | 2026-10-05T14:10 | Phase 1b fixes; NOT orchestration-discipline.md / bash-runner.md |
| return | impl-3 (cdocs:implementer) | same | 2026-10-05T14:33 | `4963600`..`5bc490b`; 94/94 unit; headless 25/27 (2 = deferred rules_check); --as normalisation deviates from proposal Script examples |
| dispatch | rev-3 (cdocs:reviewer) | cdocs/reviews/2026-10-05-review-of-chat-record-impl-1b-r2.md | 2026-10-05T14:34 | verify 1b fixes |
| return | rev-3 (cdocs:reviewer) | same | 2026-10-05T15:02 | `fac1568` accept |
| dispatch | impl-3 (warm, SendMessage) | plugins/cdocs/bin/chat-record, plugins/cdocs/hooks/tests/chat-record.test.sh, proposal (sync lines) | 2026-10-05T15:03 | 1b minors (speaker regex, proposal sync) |
| return | impl-3 | same | 2026-10-05T15:10 | `8707a4f` speaker regex, `418326c` proposal sync; 95/95 unit. Phase 1b done pending maintainer checklist; Phase 2 awaiting maintainer scope decision (A/B -> post-compaction RFP?) |
| dispatch | impl-4 (cdocs:implementer, fresh) | plugins/cdocs/skills/devlog/**, plugins/cdocs/rules/frontmatter-spec.md, plugins/cdocs/rules/orchestration-discipline.md (Pillar 2 handoff size check only), plugins/cdocs/skills/{triage,status}/**, plugins/cdocs/agents/triage.md, scripts/plugin hooks validate-frontmatter (if needed), proposal + post-compaction RFP (A/B move, line/word thresholds), this devlog (notes) | 2026-10-06T09:01 | Phase 2 (splitting, part_of, dry-run) |
| return | impl-4 | same | 2026-10-06T09:12 | Phase 2: `cc7b808`..`6b63aaf`; A/B moved to RFP; thresholds ~1,500/~400 words (7.86 B/word over 101 devlogs); dry-run split on scratch copies; validator/build/unit/greps OK |
| dispatch | dryrun-1 (general-purpose, sonnet, fresh) | n/a (read-only, scratchpad dryrun/) | 2026-10-06T09:13 | split dry-run; answer key in impl-4 notes |
| return | dryrun-1 | n/a | 2026-10-06T09:15 | PASS: 6/6 answers match key; Reads = 2 roots + 4 chunks (one per question for A1,A2,B1,B2); A3,B3 root only |
| dispatch | rev-4 (cdocs:reviewer) | cdocs/reviews/2026-10-06-review-of-chat-record-impl-2-r1.md | 2026-10-06T09:16 | Phase 2 review |
| return | rev-4 (cdocs:reviewer) | same | 2026-10-06T09:21 | `89991d9` revise (1 major: triage chunk skip in 6.1) |
| dispatch | impl-5 (cdocs:implementer, fresh) | plugins/cdocs/agents/triage.md, cdocs/proposals/2026-10-05-post-compaction-resumption-rfp.md, this devlog (notes) | 2026-10-06T09:22 | Phase 2 fixes (rev-4 major + minor) |
| return | impl-5 | same | 2026-10-06T09:24 | `6d54540` triage chunk-as-root (Iteration + Judge Log fallback), `b4c519b` RFP pass bar as starting point, notes `3b7683d`; build OK |
| dispatch | rev-5 (cdocs:reviewer) | cdocs/reviews/2026-10-06-review-of-chat-record-impl-2-r2.md | 2026-10-06T09:25 | verify Phase 2 fixes |
| return | rev-5 (cdocs:reviewer) | same | 2026-10-06T09:30 | `0f0a691` revise (step 6.5 gap); inline fix `8db23fa`, `650e936` |
| dispatch | rev-6 (cdocs:reviewer) | cdocs/reviews/2026-10-06-review-of-chat-record-impl-2-r3.md | 2026-10-06T09:32 | verify inline fix |
| return | rev-6 (cdocs:reviewer) | same | 2026-10-06T09:35 | `9562179` accept |

## Steering Log

| at | kind | target | content | applied_at_iteration |
|---|---|---|---|---|
| 2026-10-05T14:08 | steer-implementer | impl-3 | Maintainer: post-compaction rules check deferred to RFP (haiku results unrealistic; re-test with realistic lead models after base rules cleanup); no placement change, no SessionStart hook. After chat-record wraps, decompose the bloated rules file. | 3 |
| 2026-10-06T09:00 | steer-implementer | impl-4 | Maintainer: do Phase 2 splitting + part_of now (flesh out in current paradigm, reorganize later); resumption A/B moves to the post-compaction RFP; use line and/or word counts rather than data sizes (KB) for thresholds. | 4 |

## Implementation Notes (impl-1, Phase 1a)

> NOTE(opus-5-5/cdocs/chat-record-devlog-management): Dispatched mode; no separate implementer devlog. This devlog has no `## Changes Made` table, so the change list lives here.

### Commits

| commit | scope |
|---|---|
| `ed35dc9` | `rules/orchestration-discipline.md`: cadence subsection deleted, Pillar 2 lead reworded, "Handoff format" at task-unit boundaries (Completed gains `files:` gists), Scratchpoint subsection with the one reader line, thinness signal on `inline_work` alone, Pillar 3 Scratchpoint scope line, Cross-Target Degradation reworded |
| `259b425` | `rules/oversee-arc.md`: no "BEFORE compacting", "handoff" analogue, no context budget in Decision step, absent-`/compact` bullet deleted |
| `6c1576a` | `agents/judge.md`, `skills/iterate/template.md`: `overseer_ctx_est` removed; thinness keyed on `inline_work` |
| `ca1a047` | `skills/iterate/SKILL.md`: inline floor, "Checkpoint (handoff)" plus Scratchpoint line, soft thinness signal, one thinness column |
| `b73a9cb` | `skills/oversee/SKILL.md`, `skills/oversee/template.md`: inline floor, "Transition-write", Checkpoint plus Scratchpoint line, concurrency cap, Cross-Target Degradation |
| `07c5ee3` | `skills/propose-revise/SKILL.md`, `skills/full-send/SKILL.md`, `skills/ablate/SKILL.md`, `skills/implement/SKILL.md`: "at task-unit boundaries"; one Scratchpoint line each in propose-revise, full-send, implement (top-level only) |
| `9db6708` | `agents/triage.md`: schema-drift note gives eight columns and an unnamed extra context-estimate column |
| `757028b` | `skills/devlog/template.md` gains `## Scratchpoint` (six empty fields); `skills/devlog/SKILL.md` names it and makes `## Verification` the raw-evidence home |

### Judgment calls

- The Scratchpoint example in Pillar 2 uses neutral iterate-loop content rather than the proposal's example, which mentions a record and `Stop`; 1a text names no chat record.
- Pillar 2's Scratchpoint subsection carries the proposal's "Not a thinness input" bullet, so the judge-side definition stays single (`inline_work` alone) and no staleness check exists anywhere.
- `propose-revise` and `full-send` define no devlog of their own, so their Scratchpoint lines say "If the overseer keeps a devlog" / "each devlog it owns".
- `oversee-arc.md` Cross-Target Degradation: "every one of these fallbacks" became "these fallbacks" after the bullet deletion left one fallback bullet.
- Left as descriptive: the reseed subsection's "the compact would otherwise drop", the `/compact` reseed line, `triage/SKILL.md` "Context Management", `ablate` "compact result payload", `iterate` `--graphify-scope` "compact", `bash-runner.md` (untouched), and "Bash Output Hygiene" (untouched).
- No materialized rule copies exist in this repo (no `.claude/rules/`, `AGENTS.md` block, or `.opencode/rules/`; root `CLAUDE.md` `@`-imports `plugins/cdocs/rules/*` directly), so nothing was regenerated.

### Verification

First success grep (`grep -rniE 'ctx_est|150K|context.budget|rising.context|steady context|soft.budget|before compact|then compact|handoff-before-compact|compaction cadence|compacting (anyway|without|deliberately)|.compact. equivalent' plugins/cdocs/rules plugins/cdocs/skills plugins/cdocs/agents`): empty output, exit 1.

Second success grep (`grep -rn '/compact\|/clear' plugins/cdocs/rules plugins/cdocs/skills plugins/cdocs/agents`):

```
plugins/cdocs/rules/orchestration-discipline.md:169:Project-root `CLAUDE.md` and *unscoped* rules (`.claude/rules/*.md` with no `paths:` frontmatter) are re-injected from disk on both auto-compaction and manual `/compact`.
```

Consistency sweep: `grep -rniE 'overseer_ctx_est|handoff-before-compact|Proactive compaction|compaction cadence|Transition-write BEFORE'` outside `cdocs/` finds no plugin, script, test, or `.ts` hit (only the untracked `.claude/oversee/` arc-state prose); `cdocs/` hits are historical documents, out of scope.
No `staleness` text exists in rules, skills, or agents.

Build: `npm run build:cdocs` exit 0, "Agents converted: 7"; its only warnings are the existing `Unknown CC tool "*"` lines and a Node `DEP0205` deprecation. `build/cdocs/opencode/rules/orchestration-discipline.md` carries 8 `Scratchpoint` mentions.

## Implementation Notes (impl-2, Phase 1b)

> NOTE(opus-5-5/cdocs/chat-record-devlog-management): Dispatched mode, Phase 1b plus the 1a review nits; Phase 2 not touched; proposal status left alone.
> All scenario runs used sandboxed `CLAUDE_CONFIG_DIR`s and `git init`ed projects under the session scratchpad; no hook or test wrote into this repo, and this repo has no `cdocs/_chat/`.

### Commits

| commit | scope |
|---|---|
| `f3b4806` | `plugins/cdocs/bin/chat-record` (mode 100755): hook modes `UserPromptSubmit`/`Stop`, agent modes `note`/`path`, per the proposal's Script section |
| `e9a6e12` | `hooks/hooks.json`: `UserPromptSubmit` and `Stop` entries (timeout 5); description names the chat record |
| `98ebf64` | fix: hook mode drains stdin before any guard exit (SIGPIPE to the writer otherwise; found by the `--unit` no-jq case under `env -i`) |
| `d3e48c7` | `rules/frontmatter-spec.md`: `_chat/` line, optional devlog `chat_record:` field |
| `1e7224a` | 1a nits: Graded Enforcement says "runs of inline work", not "context bloat"; Handoff format says "A task-unit boundary is not closed until its handoff is written"; Scratchpoint writers bullet settles one-shot owners |
| `51873d1` | Pillar 2: `### Chat record` (scope sentence first, then the per-turn rule, heredoc example, speaker/body/bullet/reading guidance), `### Resumption` (steps 1-3; step 3 replaces the 1a reader line), `### Commit protocol` (explicit-path staging, Pillar 1 carve-out, union merge); Pillar 1's commit bullet points at the carve-out; Cross-Target Degradation drops "Likewise"/"Only" and says there is no record off Claude Code |
| `f000ac4` | `skills/init/SKILL.md`: scaffolds `cdocs/_chat/README.md` and `.gitattributes`; `--minimal` creates no `cdocs/_chat/`; step 3 says the rules file carries every rule file, Pillar 2 included |
| `5ea28e0` | `skills/devlog/SKILL.md`, `template.md`: optional `chat_record:` (template as a YAML comment), records quoted only in fences; no command text |
| `fa6e5e2` | 1a nit: `skills/iterate/template.md` gains a `## Scratchpoint` skeleton; Turn 0 copies it unless the devlog has one |
| `8caa220` | `plugins/cdocs/hooks/cdocs-hooks.ts` header: chat-record not ported to OpenCode |
| `adbf5ab` | `plugins/cdocs/README.md`: Hooks list, `### Chat record` (block semantics, activation, allow rule, opt-outs plus the commit-by-default leak, `bin/` installability, doubled hooks), test-suite pointer in Sandbox notes |
| `ae21396` | `cdocs/proposals/2026-09-01-devlog-autoflush-hook.md`: `status: evolved` with a pointer (deliverable 8) |
| `2fc2821`, `b055124`, `7b058b1` | `plugins/cdocs/hooks/tests/chat-record.test.sh` (mode 100755): `--unit`, `--headless`, `--optional`, extras via `--only` |
| `855fb04` | `.github/workflows/cdocs-hooks.yml`: `--unit` on `ubuntu-latest`, path-filtered to `bin/**`, `hooks/**`, the workflow |

### Judgment calls and deviations

- **Header file path.** The dispatch named `scripts/cdocs-hooks.ts`; the file and the proposal's path are `plugins/cdocs/hooks/cdocs-hooks.ts` (no `scripts/` copy exists).
- **`note` rejects an empty or whitespace-only body** (non-zero exit, nothing written), and a TTY stdin. Not in the proposal; it keeps an empty note from silently satisfying `Stop`.
- **Hook stdin drained first**, before the `CDOCS_CHAT_RECORD`/`jq`/`git` guards (see `98ebf64`).
- **`--as` default `assistant`**, sanitized by the session-token mapping, rejected when empty, starting with `.`/`-`/`_`, or equal to `user` in any case: as specified.
- **Init README template carries no `chat-record` text** (the constraint bars command text from skills); it says "appended by the cdocs hooks and the top-level agent".
- **Pillar 2 step 3 adds one fallback line**: "Without a record (a dispatched agent, or a project without `cdocs/_chat/`), read your devlog's `## Scratchpoint` and latest handoff alone." It is a fallback, not a second scope guard; the only "Claude Code top-level session only" sentence is the one opening `### Chat record`.
- **Pillar 2 bullet guidance** (categories, ~120 chars, successor test, enumerated-log anti-pattern) lives in `### Chat record`, since only Pillar 2 may carry command text.
- **Harness tags**: only `<task-notification` was observed across every captured `UserPromptSubmit` payload (5 occurrences); the skip list stays `<task-notification`, `<system-reminder`.
- **Union-merge caveat (new fact):** `merge=union` keeps one copy of a line both sides added identically, so two checkouts appending turns in the same second (identical `@user: <ts>` and sign-off lines) collapse those lines. With distinct timestamps every block survives (git 2.54.0). The unit test spaces its merge turns by one second; real-world exposure is negligible.
- **Forks need `CLAUDE_CODE_FORK_SUBAGENT=1`** in 2.1.289 (without it: "Agent type 'fork' not found", as R8 saw). The `top_level_only` scenario sets it, so the fork case is now actually exercised.
- **No `PreToolUse` fallback**: no scenario showed a subagent or fork `chat-record` call, so the named fallback does not ship.

### Verification

`--unit` (local, also under `env -i PATH=/usr/bin:/bin`, three consecutive runs): `chat-record tests: 75 passed, 0 failed`.

Final full run from `HEAD`'s test file (`chat-record.test.sh`, unit plus every non-optional headless scenario, haiku, 2.1.289): `chat-record tests: 132 passed, 0 failed`, exit 0 (75 unit, 57 headless assertions).

| scenario | result | key evidence |
|---|---|---|
| `cmdv` | pass | `command -v` prints `<worktree>/plugins/cdocs/bin/chat-record` (calling session's plugin bins stripped from `PATH`) |
| `read_note` | pass | `U A:haiku-4-5 S:<sid8>`; body `- read: a.txt: canary fixture`; 1 Stop, 0 decisions |
| `byte_exact` | pass | backticks, `$HOME`, `$(date)`, apostrophe, quotes, backslashes byte-exact |
| `block_recover` | pass | 2 Stops, 1 block; reason names `cdocs/_chat/<date>-<sid>.md` and the heredoc command; model noted; `U A S` |
| `no_tools` (`--tools ""`) | pass | 2 Stops, 1 block, no third; `U S` |
| `minimal` | pass | `U A S`, 1 Stop, no block |
| `two_prompts` (turn-by-turn stream-json driver) | pass | `U A S U A S`, timestamps non-decreasing |
| `note_twice` | pass | `U A A S`, 1 Stop, no block |
| `no_as` | pass | speaker `assistant` |
| `session_env` | pass | Bash `CLAUDE_CODE_SESSION_ID` = stream `session_id` = filename suffix |
| `path_mode` | pass | prints the record path; one record |
| `background` | pass | envelope delivered to `UserPromptSubmit` (canary) but absent from the record; 2 Stops, 0 decisions |
| `background_note` | pass | `U A S A S` |
| `foreground_agent` | pass | `U A S`; no `UserPromptSubmit`/`Stop` payload carries `agent_id` |
| `top_level_only` | pass | rules materialized; `cdocs:proposer` and a real `fork` dispatched; `PreToolUse` canary logged only the top-level `chat-record` call (`agent_id: null`); first Stop blocked |
| `slash_command` | pass | `@user` body `/echo hello-world` |
| `compact` | pass | `U A S U A S`, no line mentions compaction, `compact_boundary` present |
| `clear` | pass | second record named by the new id; Bash id after the clear is new; first record ends at its sign-off |
| `resume` | pass | `--resume`, `--continue` append (3 `@user`, 1 file); `--fork-session` makes a second file |
| `rename` (injected `custom-title`) | pass | `U A S:<sid8> U A S:my-canary U A S:my-canary` |
| `plan_mode` | pass | 1 Stop, no decision, `U S` |
| `cd_sibling` | pass | original record holds the unsigned `U`; sibling holds `A S`; 1 Stop, no decision |
| `off` | pass | no file; 1 Stop, no decision |
| `uninitialized` | pass | `cdocs/` without `_chat/`: no file, 1 Stop, no decision; outside git: same |
| `payload_shape` | pass | UPS has `prompt`, `session_id`, `cwd`, `transcript_path`; Stop has `stop_hook_active`, `session_id`, `cwd`, `transcript_path`, `permission_mode` |
| `default_allowed` (optional) | 2 of 3 pass | one run's Bash `PATH` lacked the plugin `bin/` (`command not found: chat-record`, exit 127); two reruns passed with `permission_denials: []`; see Open items |
| `default_denied` (optional) | pass | `note` in `permission_denials`; 2 Stops, 1 block; `U S` |
| `init_real` (extra, real `/cdocs:init`, haiku, 900s) | pass | `.gitattributes` = `*.md merge=union`; `_chat/README.md`; rules file carries the scope sentence and step 3; `CLAUDE.md` import; no record for the init turn; `--minimal` makes doc dirs and no `cdocs/_chat/` (the first attempt timed out at 300s before AGENTS.md) |

**Failure picture, tested explicitly:** a double block or loop (`block_recover`, `no_tools`, and 20 multi-turn turns, each `U S` or `U S S*`, never more); blocks in uninitialized projects (`uninitialized`: no `_chat/`, and outside git), in plan mode (`plan_mode`), or with `CDOCS_CHAT_RECORD=off` (`off`): none; a subagent note in the top-level record (`foreground_agent`, `top_level_only` with proposer and fork): none.

**Multi-turn session (approximates the 20-turn criterion).** `--only multi_turn`: a sandbox project with `/cdocs:init`-equivalent rules (marker plus every rule body, `CLAUDE.md` import), then 20 realistic prompts (devlog, a small Python CLI, tests, two commits, Scratchpoint and Verification updates) as one `claude -p` and 19 `claude -p --resume <id>` turns, haiku, never told how to note.
Result: `every @user followed by >=1 entry and exactly one sign-off` PASS (20 times `U A:haiku-4-5 S:9466a9c8`, `--as` chosen by the model from the rule); each turn's Stops were `S` or `S S*` (7 of 20 turns needed the one-shot block, all recovered in one turn); one `gist:` bullet per turn, gist-shaped, 11 of 20 over ~120 characters, no `query:`/`read:`/`follow-up:` used.
This is not the proposal's real in-repo session (it needs a human-driven top-level session committing a record in this repo).

```
@user: 2026-10-05T12:58:07-07:00
Create a devlog for adding a tiny Python CLI to this project at cdocs/devlogs/2026-10-05-tiny-cli.md with frontmatter per the cdocs frontmatter spec, Objective and Plan sections.

@haiku-4-5: 2026-10-05T12:58:29-07:00
- gist: created devlog at cdocs/devlogs/2026-10-05-tiny-cli.md with frontmatter, Objective, Plan (3 phases), and Scratchpoint per CDocs spec

-- 9466a9c8 at 2026-10-05T12:58:30-07:00
```

**Rules check (deliverable 7): FAILS for haiku and sonnet, partial for opus.** `--only rules_check`: rules materialized, turn 1 starts a devlog and writes `greeter.py`, stream-json `/compact`, turn 2 "continue with the next step".
No hook emitted `additionalContext` in any run, and every model kept the per-turn rule after the compaction.

| model | step 1 (`chat_record:` filled) | first post-compaction calls | step 3 |
|---|---|---|---|
| haiku | no (`chat_record: []`) | `Read greeter.py`, `Edit greeter.py` | not followed |
| sonnet | yes | `Write greeter.py`, then devlog `Edit` | not followed |
| opus | yes | `p=$(chat-record path); echo "$p"; tail -n 80 "$p"`, then `Write greeter.py` | path and record tail yes; Scratchpoint/handoff not re-read before acting |

The test's first version passed opus's devlog check spuriously on a later `Edit`; `b055124` counts reads only before the first non-devlog write, and the table reflects that.

**Phase 1a greps (scoped to rules, skills, agents):** grep 1 empty (exit 1); grep 2 exactly `orchestration-discipline.md:211`, the reseed line (the line number moved from 169 because of the new Pillar 2 text).
`grep -rn chat-record plugins/cdocs/skills plugins/cdocs/agents`: empty.
`inject-rules.ts`, `validate-cdocs-edit-path.sh`, and `cdocs-validate-frontmatter.sh` are unchanged; neither path regex mentions `_chat/`.

**Build:** `npm run build:cdocs` exit 0, "Agents converted: 7", warnings only the existing `Unknown CC tool "*"` lines and `DEP0205`; no `bin/` in the OC output.

### Open items

- **Rules check (success criterion) not met:** post-compaction step 3 is not reliably followed (table above). Phase 2's A/B measures exactly this, but Phase 1b's criterion says the rules check passes; an overseer or maintainer call is needed (accept with a Phase 2 pointer, or revise the step-3 wording or placement, e.g. lead `### Resumption` with the after-compaction step).
- **Interactive check (a)-(d) not run:** a dispatched agent cannot press Escape, `/rename` interactively, or type mid-turn. (a) is covered headlessly by `block_recover` and 7 recoveries in `multi_turn`; (b) interrupt, (c) interactive `/rename`, and (d) interactive mid-turn prompts remain for the maintainer, so the interrupt and mid-turn decisions stay as the proposal's defaults.
- **Usefulness sample not run:** needs a fresh reviewer scoring 20 entries of a real-session record; the multi-turn record above is a haiku sandbox, not a real session.
- **Plugin `bin/` missing from `PATH` once** (1 of about 35 sandbox sessions, first session in a fresh `CLAUDE_CONFIG_DIR`, default permission mode): `command not found: chat-record`. Not reproduced in 3 targeted reruns. If it recurs, `Stop`'s block still bounds the cost to one extra turn and the record keeps the prompt and sign-off.
- `plugins/cdocs/agents/bash-runner.md` shows uncommitted modifications in this worktree that are not impl-2's; left untouched.
- The shared scratchpad holds `r7canary/cfg` and `r8canary/cfg` credential copies from the earlier R7/R8 runs (not impl-2's); impl-2's own sandboxes are deleted.

## Implementation Notes (impl-3, Phase 1b fixes)

> NOTE(opus-5-5/cdocs/chat-record-devlog-management): Dispatched mode, fix round for [`2026-10-05-review-of-chat-record-impl-1b-r1.md`](../reviews/2026-10-05-review-of-chat-record-impl-1b-r1.md).
> `orchestration-discipline.md` and `bash-runner.md` untouched; no rules placement change, no SessionStart hook; interactive checks and the usefulness sample left for the maintainer.

### Commits

| commit | item | scope |
|---|---|---|
| `4963600` | 1 (blocking) | `bin/chat-record` `escape_body` strips CR with `$'s/\r$//'` (literal byte); round-trip test computes expected bodies without sed and adds lines ending in `r`, with and without CRLF, plus an explicit "keeps its r" check |
| `b1e5175` | 1 | `.github/workflows/cdocs-hooks.yml`: matrix `ubuntu-latest`, `macos-latest`, `fail-fast: false` |
| `680d91b` | 2 | hook mode returns 0 (stderr line) when `jq` yields nothing; unit section feeds both hooks `''`, `' '`, non-JSON, `[1]`, `"s"`, `null`, `{}` |
| `fa4d93a` | 3 | test: `rules_check` devlog-read regex, `init_rules` order, `top_level_only` and `foreground_agent` foreground plus positive controls |
| `955d350` | 4 | `note` normalizes `--as` to a short id; block text says `--as <your model id>` |
| `d1d5e64` | 5 | proposal: Phase 1b success criterion and Phase 2 A/B point at [`2026-10-05-post-compaction-resumption-rfp.md`](../proposals/2026-10-05-post-compaction-resumption-rfp.md) |

### Judgment calls and deviations

- **Speaker normalization deviates from the proposal's Script examples.** `note` lowercases `--as`, drops a `claude-` prefix, a `[...]` suffix, and a `-YYYYMMDD` date, and maps dots to dashes, before the existing sanitize and validation: `Opus 5.5` -> `opus-5-5` (proposal: `Opus-5.5`), `opus-4-6[1m]` -> `opus-4-6` (proposal: `opus-4-6-1m-`).
  It matches Pillar 2's speaker rule ("model id without `claude-` and any `-YYYYMMDD` suffix"), so the rule text needed no edit.
  A bare family name (`haiku`) still cannot be mapped; the block text's "model id" targets that case.
- **Foreground dispatch.** In 2.1.289 an `Agent` call runs async unless `run_in_background` is `false` or background tasks are disabled (binary: `shouldRunAsync` is true when `wantsBackground !== false`), so prompt wording alone cannot force foreground.
  Both agent scenarios set `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`, which also drops `run_in_background` from the tool schema; `foreground_agent` had the same defect and got the same fix.
- **`init_rules` order** is read from init's own AGENTS.md block (`[Full content of <file>, frontmatter stripped]` lines), not hard-coded; the hash stays alphabetical as init specifies.
- **Devlog-read gate** accepts `Read` of a devlog file, or `cat`/`sed`/`head`/`tail`/`awk` on a devlog path within one pipeline segment; `grep` in any form does not count, so a `grep -A` section print is a false negative (accepted for simplicity).
- **Cross-Target Degradation (6821b43):** none of impl-3's files references the deleted section.
  `plugins/cdocs/hooks/cdocs-hooks.ts`'s header still says chat-record is Claude-Code-only on its own terms, and `model-tiering.md` keeps its own unrelated "Cross-Target Degradation" section.

### Verification

**Unit:** `chat-record.test.sh --unit`: `94 passed, 0 failed`, also under `env -i HOME=<empty> PATH=/usr/bin:/bin`.
**BSD-sed mutation:** a scratch copy with `escape_body` reading `\r` as `r` (`s/r$//`) fails the round trip, "no CR survives", and "keeps its r" (want 6, got 0).
**macOS CI:** the matrix parses (PyYAML); it has not run, since the workflow is not on the remote default branch, so BSD `awk`/`tr` and the macOS toolchain stay unverified until the first push.

**Headless** (haiku, 2.1.289, sandbox under the session scratchpad, `CHAT_RECORD_KEEP=1`, sandbox and credential copies deleted afterwards; `find` finds no `.credentials.json` or `.claude.json` under the scratchpad): `25 passed, 2 failed`.

| scenario | result | key evidence |
|---|---|---|
| `read_note`, `byte_exact`, `no_as` | pass | speaker `haiku-4-5`; bytes exact; `assistant` default |
| `block_recover` | pass | block carries `--as <your model id>`; model ran `--as claude-haiku-4-5-20251001`, header written `@haiku-4-5` |
| `foreground_agent` | pass | Agent result is not "Async agent launched" and contains `canary fixture` |
| `top_level_only` | pass | `cdocs:proposer,fork` in the foreground; fork reported `canary fixture`; proposal file written; subagent calls `Bash=1,Edit=1,Read=3,Write=1`; no `chat-record` call with an `agent_id`; first Stop blocked; rules file in init order (writing-conventions first, frontmatter-spec last) |
| `rules_check` | 2 gates fail (deferred criterion) | post-compaction calls: `Read greeter.py`, `Read cdocs/devlogs/...greeter.md`, `Edit greeter.py`; the devlog gate passes on a real `Read`; `chat-record path` and record tail absent |

An offline probe of the devlog-read regex: `grep -l "$p" cdocs/devlogs/*.md` (alone or followed by `tail -n 80 "$p"`) and `ls cdocs/devlogs/` do not count; `Read <devlog>.md`, `cat`, `sed -n '/## Scratchpoint/,...'`, `head -50`, and `cat "$(grep -l ...)"` do.

**Phase 1a greps:** grep 1 empty (exit 1); grep 2 exactly `orchestration-discipline.md:211`, the reseed line. `grep -rn chat-record plugins/cdocs/skills plugins/cdocs/agents`: empty.
**Build:** `npm run build:cdocs` exit 0, "Agents converted: 7", warnings only the existing `Unknown CC tool "*"` lines.

### Open items

- macOS leg unverified until the workflow runs on GitHub (reviewer question 2, permanent or one-off, is the overseer's call; it is permanent as committed).
- Rules check deferred per the maintainer; `rules_check` still fails on haiku, as expected.
- Interactive checks (a)-(d), the 20-turn real session, and the usefulness sample remain maintainer-run.

## Implementation Notes (impl-4, Phase 2)

> NOTE(opus-5-5/cdocs/chat-record-devlog-management): Dispatched mode, Phase 2 minus the resumption A/B (moved to the post-compaction RFP per the 2026-10-06 steer).
> Proposal status left alone; tables above not edited.

### Commits

| commit | scope |
|---|---|
| `cc7b808` | proposal: Phase 2 heading, dependency line, deliverable 3, success criteria, Test Plan bullet, and Verification Methodology drop the A/B; a NOTE points at the RFP; Phase 3 gated on the RFP's A/B. RFP: the stale "Relationship to Phase 2 A/B" scope bullet becomes "Resumption A/B" (arms, scoring, pass bar) |
| `0630cc6` | proposal: split thresholds in words (trigger, merge floor, Edge Cases' 20KB case, Objective's 40KB example) |
| `f5d6264` | `skills/devlog/SKILL.md`: "Splitting a devlog" (trigger, closed concern, cut and merge, naming, Chunks table, chunk frontmatter and backlink) |
| `e5d0f91` | `rules/orchestration-discipline.md`: Resumption step 2 ("At each handoff") checks the split trigger; the only line touched |
| `c65a92c` | `rules/frontmatter-spec.md`: `part_of?` in the template, field definition (repo-root path, no `chat_record:` on chunks, grouped by status/triage) |
| `00fa786` | `agents/triage.md`: `part_of` field check (report unresolved, never edit), chunks skip the verification completeness check, step 6.1 skips chunks when locating the iterate devlog, report groups chunks under their root |
| `2fe3136` | `skills/status/SKILL.md`: Query step 6 groups chunks under their root after filtering (`↳ ` prefix; `(part_of <root>)` when the root is filtered out) |

### Threshold conversion

Measured with `wc -c`/`wc -l`/`wc -w` over all 101 files in `cdocs/devlogs/`: 7.86 bytes/word overall and 7.2-9.2 per file in the 2-4KB and 10-14KB bands, against 42-190 bytes/line (tables and verbatim output make line length swing about 4x; the 12KB band spans 70-277 lines).
Words are the stable proxy, so the thresholds are words alone, measured with `wc -w`:

| was | is | arithmetic |
|---|---|---|
| ~12KB split trigger | ~1,500 words | 12,288 / 7.86 = 1,563 |
| ~3KB merge floor | ~400 words | 3,072 / 7.86 = 391 |
| 20KB edge case (proposal) | ~2,500 words | 20,480 / 7.86 = 2,606 |
| 40KB example (proposal Objective) | 5,000 words | 40,960 / 7.86 = 5,211 |

Both dry-run subjects sit past the trigger (`2026-09-22-agent-dispatch-labeling.md` 2,352 words, `2026-05-12-rule-delivery-regression-test.md` 2,354).

### Judgment calls

- **Pillar 2 edit location.** "Pillar 2's handoff step" is read as `### Resumption` step 2 ("At each handoff"), the one step that runs per handoff; `### Handoff format` is untouched.
  The threshold itself lives only in the devlog skill; Pillar 2 points at it.
- **Edge Cases folded into the skill.** "No closed concern means no split: tighten prose instead" and "a live table whose finished rows moved points to their chunk" carry the proposal's two splitting edge cases, without the 2,500-word number (a landed verification campaign is already a closed concern).
- **Triage beyond grouping.** Grouping alone would let step 6 pick a chunk carrying a finished `## Iteration Log` as "the iterate devlog"; step 6.1 now skips chunks so the root's live table is read. Chunks also skip the devlog verification-section check, since a loop-record chunk has no `## Verification`.
- **RFP bullet replaced, not added.** The RFP's "Relationship to the chat-record proposal's Phase 2 A/B" question is answered by the move, so the A/B bullet takes its place.
- **Not converted:** proposal Background item 3 ("split past ~10-15KB or ~5 rounds") quotes the methodology report's recommendation; the 1b block-text bound ("under 300 bytes") and the RFP's "300-ish-byte budget" are Phase-1b/RFP text this phase does not touch, and the RFP's ~27KB/~60KB are measurements, not thresholds.
- **Dry-run on copies.** The proposal calls it a dry-run and puts "results in the devlog", so the split was performed on copies; the originals are unchanged and nothing from it is committed.
  The copies are under `/tmp/claude-1000/-var-home-mjr-code-weft-clauthier-main/e3afd4a9-4352-482d-ad1a-444fa834254a/scratchpad/dryrun/cdocs/devlogs/` (a `cdocs/devlogs/` path so the validator's regex applies); every non-blank original line survives in the root or one chunk except the two renamed headings (`## Changes Made` split by row into each chunk, `### Implementer Notes` promoted to H2).
  If the overseer wants them as a committed worked example, copying the six files over the two originals is the whole change.

### Dry-run split layout

| file | words | holds |
|---|---|---|
| `2026-09-22-agent-dispatch-labeling.md` (root) | 655 | frontmatter, BLUF, Objective, Plan, Overseer Mode, Chunks, Loop Verdict and follow-ups, deferred usage-DB verification (open) |
| `...-loops.md` | 909 | propose-revise log and result (~250 words, under the floor, so merged into the adjacent iterate loop record), Turn 0, Iteration/Judge/Dispatch/Steering tables, proposal and spec-only Changes rows |
| `...-implementation.md` | 1,051 | Implementer Notes, file Changes rows, static Verification (~260 words, merged) |
| `2026-05-12-rule-delivery-regression-test.md` (root) | 777 | frontmatter, BLUF, Objective, Plan, Testing Approach, Chunks, Verdict, Changes Made, Deviations (spans both chunks), Notes for the QA Reviewer |
| `...-runs.md` | 920 | pre-flight and auth anomaly, marker, bundle size, runs 1-4, in-repo run, spillover file, Cleanup (sandbox setup ~270 words, merged) |
| `...-analysis.md` | 899 | Root Cause Analysis, Implications, Independent QA Confirmation (~280 words, merged) |

### Dry-run setup for the overseer

Dispatch one FRESH agent (`general-purpose`, sonnet tier; not this implementer, not the reviewer) with exactly this prompt:

```
Answer six questions about two devlogs, each split into a root file and chunk files.
Roots:
  A: /tmp/claude-1000/-var-home-mjr-code-weft-clauthier-main/e3afd4a9-4352-482d-ad1a-444fa834254a/scratchpad/dryrun/cdocs/devlogs/2026-09-22-agent-dispatch-labeling.md
  B: /tmp/claude-1000/-var-home-mjr-code-weft-clauthier-main/e3afd4a9-4352-482d-ad1a-444fa834254a/scratchpad/dryrun/cdocs/devlogs/2026-05-12-rule-delivery-regression-test.md
Rules:
- Use the Read tool only (no Grep, Glob, Bash, or search), and read only files under /tmp/claude-1000/-var-home-mjr-code-weft-clauthier-main/e3afd4a9-4352-482d-ad1a-444fa834254a/scratchpad/dryrun/cdocs/devlogs/.
  Do not open anything under /var/home/mjr/code/weft/clauthier: it holds unsplit originals.
- Read both roots first. For each question you may open at most ONE other file, chosen from that root's "## Chunks" table, or answer from the root alone.
- Per question, report: the answer; the one file opened for it, or "root only"; one quoted supporting line.
A1. Which model: option was chosen for the new implementer.md/proposer.md agent files, and what OpenCode build evidence ruled out "model: inherit"?
A2. How many review nits were folded in propose-revise round 2, and in which commit?
A3. Which commit blurred an overseer-owned table row, and what process fix was noted?
B1. What size notice and preview label did the model quote for the SessionStart hook output in Run 3, and how many bytes was the spillover file on disk?
B2. Which candidate next direction does the devlog call the lowest-cost next investigation?
B3. What did the sandbox need beyond the proposal's recipe to get claude -p past auth?
```

Answer key (overseer only; do not pass to the agent):

| q | answer | expected file |
|---|---|---|
| A1 | option (B), omit `model:`; `inherit` printed `Unknown model alias "inherit"` and emitted an invalid `model: inherit` line into the OC agent | `-implementation` |
| A2 | 4 nits, `333d8a8` | `-loops` |
| A3 | `1b070a3`; the overseer commits its own table-row edits in its own commits | root only (also in `-loops`) |
| B1 | "Output too large (13.1KB). Full output saved to: ..." and "Preview (first 2KB):"; 13383 bytes | `-runs` |
| B2 | option 1: find whether the 2KB inline cap is configurable | `-analysis` |
| B3 | copy `.credentials.json` and `.claude.json` from `~/.claude/` into the sandbox | root only (Deviations; also in `-runs`) |

Pass (the proposal's one-chunk bar): every answer matches the key and the transcript's `Read` calls are the two roots plus at most one chunk per question (at most six chunk opens, none outside `/tmp/claude-1000/-var-home-mjr-code-weft-clauthier-main/e3afd4a9-4352-482d-ad1a-444fa834254a/scratchpad/dryrun`).
A3 and B3 test that the root alone suffices when it should; opening a chunk for them is within the bar but worth noting.
If `/tmp/claude-1000/-var-home-mjr-code-weft-clauthier-main/e3afd4a9-4352-482d-ad1a-444fa834254a/scratchpad/dryrun` has been cleaned up, the layout table above and the original line ranges in each chunk's sections are enough to regenerate it.

### Verification

- **Validator accepts chunks unchanged.** `plugins/cdocs/hooks/cdocs-validate-frontmatter.sh` fed `{"tool_input":{"file_path":<f>}}` for each of the six dry-run files: empty stdout, exit 0 for all six.
  Negative control: a chunk copy with its `status:` line removed yields `missing required frontmatter fields: status`. The script has no unknown-field check, so `part_of` needs no change; `git status plugins/cdocs/hooks/` is clean.
- **Phase 1a greps unchanged.** grep 1 empty (exit 1); grep 2 exactly `orchestration-discipline.md:211`, the reseed line. `grep -rn chat-record plugins/cdocs/skills plugins/cdocs/agents` empty. No `KB` or `bytes` in the four touched plugin files.
- **Build.** `npm run build:cdocs` exit 0, "Agents converted: 7"; warnings only the existing `Unknown CC tool "*"` (x3) and Node `DEP0205`. "Splitting a devlog" appears in the built `skills/devlog/SKILL.md`, `rules/orchestration-discipline.md`, and `rules/frontmatter-spec.md`.
- **Unit suite.** `chat-record.test.sh --unit`: `95 passed, 0 failed`, exit 0.
- **Grouping coherence (read-through).** Status groups after filtering, so "root not in the results" is well defined; triage groups in its report, checks `part_of` resolution read-only (it edits frontmatter only and never `part_of`), and step 6 reads the root's live tables. Neither has been exercised on a real corpus with chunks, since none is committed.

### Open items

- The dry-run's fresh-agent run (above) is the overseer's; its result decides the one-chunk success criterion.
- The `Agent` tool was callable in this dispatched session (used only for two `cdocs:bash-runner` runs); the dry-run was left to the overseer per the brief, since its scorer must not be the author.

## Split Dry-Run Result (overseer)

A fresh `general-purpose` sonnet agent ran the impl-4 prompt (Read-only, scratchpad `dryrun/` copies) on 2026-10-06.
All six answers match the answer key; its Read calls were the two roots, then one chunk each for A1 (`-implementation`), A2 (`-loops`), B1 (`-runs`), B2 (`-analysis`); A3 and B3 were answered from the root alone, as intended.
The proposal's one-chunk bar passes.

## Implementation Notes (impl-5, Phase 2 fixes)

Fixes for `cdocs/reviews/2026-10-06-review-of-chat-record-impl-2-r1.md` action items 1 and 2; items 3 and 4 stay as-is per the brief.

### Commits

| sha | change |
|---|---|
| `6d54540` | `fix(triage)`: step 6.1 treats a chunk as part of its root instead of skipping it; an empty root table reads its last row from the newest chunk that has one. Step 5's chunk skip is unchanged. |
| `b4c519b` | `docs(rfp)`: the resumption A/B pass bar is a starting point, scored as majority rates under "Test protocol" and open to "Acceptance bar". |

### Judgment calls

- The chunk fallback covers any table step 6 reads, not just the Iteration Log: a finished `## Judge Log` moves into the same chunk, and step 6.6 reads both tables.
- "Steps 2-4 match the root together with its chunks" covers a root that has lost its `## Iteration Log` heading (dry-run root A), which step 6.2's heading filter would otherwise drop; it also makes step 6.4's tie-break apply to distinct roots only.
- `skills/triage/SKILL.md` and `skills/status/SKILL.md` say nothing about chunk skipping in step 6, so neither changed.
  The impl-4 Verification bullet above ("step 6 reads the root's live tables") is a historical record and is left as written.

### Verification

`npm run build:cdocs` exit 0, "Agents converted: 7". No script changes, so the unit suite was not re-run.

## Handoff (loop close, 2026-10-06)

### Completed

- Phases 1a, 1b, 2 accepted (rows 1-6); proposal `status: implementation_accepted` for that scope. Phase 3 stays gated on the resumption A/B in [the post-compaction RFP](../proposals/2026-10-05-post-compaction-resumption-rfp.md).
- files: `plugins/cdocs/bin/chat-record`, `plugins/cdocs/hooks/hooks.json`, `plugins/cdocs/hooks/tests/chat-record.test.sh`, `.github/workflows/cdocs-hooks.yml`, `plugins/cdocs/rules/{orchestration-discipline,frontmatter-spec}.md`, `plugins/cdocs/skills/devlog/SKILL.md`, `plugins/cdocs/agents/triage.md`, `plugins/cdocs/skills/status/SKILL.md`.

### Decisions Made

- No agent-side compaction cadence or context self-estimates; `/clear` is a new session with nothing to hand off.
- Split thresholds in words (~1,500 trigger, ~400 merge); a split devlog's root and chunks read as one for triage; a moved-rows pointer is a line below the live table.
- Post-compaction rules check deferred to the RFP (to be re-tested with realistic lead models after the rules cleanup).

### Open Todos

- Maintainer 1b checklist: CI after push (ubuntu + macos), interactive checks (a)-(d), a 20-turn opus session after `/cdocs:init` in this repo, 16/20 usefulness sample.
- This devlog exceeds the split trigger; split it at closed-concern boundaries (first real use of the Phase 2 rule).

