---
review_of: plugins/cdocs/rules/overseers.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T12:33:54-07:00
task_list: cdocs/rules-context-decomposition
type: review
state: live
status: done
tags: [fresh_agent, rules, simplification, formalism_reduction, dead_references, test_failure, devlog_skill, context_budget]
---

# Review: Rules and Devlog Skill Simplification

> BLUF(@claude-opus-5-5/cdocs/rules-context-decomposition): The direction is sound and the new files are clearer, but the change ships broken wiring.
> `orchestration-discipline.md` and `model-tiering.md` are deleted while 20+ live references still point at them, including this repo's `CLAUDE.md` `@`-imports (so source-repo sessions load neither the old nor the new rules), `/cdocs:init`'s AGENTS.md block that fixes materialization order (so consumers re-running init get an undefined rule set), and the chat-record unit suite, which now fails (94 passed, 1 failed).
> Two load-bearing, incident-backed lessons left the rules with no new home: "Resume from disk, not memory" (iterate, full-send still route their resume procedure to it) and the handoff-at-task-boundary half of "Durable state".
> The new devlog handoff lifecycle ("delete it before beginning new work") contradicts iterate, oversee, judge, and `overseers.md`, which all read the latest handoff on resume.
> Verdict: **Revise**.

> NOTE(@claude-opus-5-5/cdocs/rules-context-decomposition): Subject is the set landed in `bbc5cba` (rules) and `58bb5fa` (devlog skill): `overseers.md`, `tool-use-safeguards.md`, `workflow-patterns.md`, deleted `orchestration-discipline.md` and `model-tiering.md`, and `skills/devlog/{SKILL,template}.md`.
> Rule files carry no cdocs frontmatter, so `last_reviewed` was not written to the target.
> Line numbers below are at `58bb5fa`.

## Summary Assessment

The change folds model tiering into `workflow-patterns.md`, splits the overseer rule into `overseers.md` (stay thin, chat record) and `tool-use-safeguards.md` (one writer per file, Bash output), and replaces the devlog skill's Scratchpoint schema, handoff, and chunking guidance with shorter judgment-based text.
Each new file reads well on its own and the cuts mostly remove formalism a capable model supplies anyway, which matches the maintainer's stated preference.
The blocking problems are integration, not prose: the deletion was not propagated to the ~20 references, the init materialization contract, `CLAUDE.md`, `AGENTS.md`, README, or the test fixture, and two lessons the 2026-10-06 overseer-rules review classed as "Load-Bearing: Keep" were dropped rather than compressed.
Verdict: **Revise**: fix wiring, restore two compressed lessons, and reconcile the handoff lifecycle with the loop skills.

## Evidence

| check | result |
|---|---|
| `npm run build:cdocs` | exit 0 (copies `rules/` wholesale, so it does not notice deletions) |
| `chat-record.test.sh --unit` | exit 1: 94 passed, 1 failed: `init's rule order names every rule file once` (got `... model-tiering.md orchestration-discipline.md ...`, want `... overseers.md tool-use-safeguards.md ...`) |
| `validate-cdocs-edit-path.test.sh` | exit 0, 17 passed |
| always-loaded `rules/*.md` | 299L / 2,215W before, 283L / 1,858W after (-16% words) |
| `skills/devlog/SKILL.md` | 148L / 1,084W before, 157L / 1,068W after |
| `skills/devlog/template.md` | 36L / 65W before, 39L / 71W after |

The headless `init_real` case (not run: it needs a live `claude`) would also fail: it asserts the strings ``Claude Code top-level session only: `chat-record` exists nowhere else`` and ``**After a compaction:** run `chat-record path` `` (`hooks/tests/chat-record.test.sh:818-820`), and neither survives in `overseers.md`.

## Section-by-Section Findings

### Dangling references (blocking)

Deleted paths are still referenced as the canonical home of live procedure.
The ones that change behavior, not just a broken link:

- `CLAUDE.md:48-49` `@`-import the deleted files, and nothing imports `overseers.md` or `tool-use-safeguards.md`.
  Missing `@`-imports are silent, so every session in this repo now runs without one-writer, explicit-path staging, chat-record, and Bash discipline.
  This review session's own loaded context confirms it: neither old nor new files were present.
- `skills/init/SKILL.md:84-90` (AGENTS.md block) names the deleted files, and step 3 (`:25`) orders `.claude/rules/cdocs.md` by that block.
  The content hash changed, so `inject-rules.ts` tells every consuming project to re-run `/cdocs:init`, which then has no ordering slot for the two new files and two slots for missing ones.
- `hooks/tests/chat-record.test.sh:791` derives `init_rule_order` from that block (the failing unit test); `init_rules` would `awk` two missing files.
- `plugins/cdocs/AGENTS.md:13-19` `@`-imports the deleted files.
- Procedure pointers with no target: `skills/iterate/SKILL.md:13,37,114,129`, `skills/full-send/SKILL.md:13,15,16`, `skills/implement/SKILL.md:19,81`, `skills/propose/SKILL.md:144`, `skills/propose-revise/SKILL.md:17,42`, `skills/oversee/SKILL.md:12,30`, `skills/ablate/SKILL.md:20,290,291`, `rules/workflow-patterns.md:18`, `rules/frontmatter-spec.md:85`, `skills/devlog/SKILL.md:31`, `skills/devlog/template.md:10`.
  Section names "Durable state", "Resume from disk, not memory", and "Chat record" are cited by name in iterate's Checkpoint and On-Resume Reconciliation and full-send's resume step.
- `README.md:59-60,140` describe the deleted files.
- `.claude/oversee/2026-10-05-haiku-bash-wrapper.json:21-22` lists them as touched files; historical arc state, harmless, no fix needed.

### Lost guidance

Classified against the 2026-10-06 overseer-rules review ("Load-Bearing: Keep") and `cdocs/reports/2026-10-06-durable-specialists-and-removed-guidance.md`.

| removed passage | origin | verdict |
|---|---|---|
| Resume from disk: log dispatch/return; harness notifies only when *no* children are live; "control returned means the child ended" | incident: full-send orchestrator reported "proposer in flight" twice after control returned; orphan then wrote the same devlog (`cdocs/devlogs/2026-09-01-oversight-proposals-and-cc-features.md`) | **load-bearing, blocking.** The harness fact is not intuitable, and iterate/full-send still route resume to it. |
| Durable state: handoff at each task-unit boundary; Scratchpoint kept current | design-time (`a2ebbd7`), no incident; the 2026-10-06 review lists it under "Load-Bearing: Keep" because post-compaction resumption depends on it | **partly kept**: devlog SKILL now says "updated at the end of each turn" and lists handoff triggers. Acceptable home, but the rule-level "compaction summaries are lossy" reason is gone from always-loaded context. Non-blocking. |
| "stage by explicit file path (no directories), never `git add -A` or `commit -a`" | incident: Smoke2's lead ran `git add cdocs/devlogs` (a directory), fixed in `71182d0`; `commit -a` ban from `51873d1` | **weakened.** "by exact paths" (`tool-use-safeguards.md:8`) keeps the core but drops "no directories", the exact clause the Smoke2 incident needed. Non-blocking, one clause to restore. |
| "Trust returned summaries" | design-time (anti-workhorse) | fine to drop; "Stay thin" carries it. |
| Verification floor; isolate faults over rebuilds | design-time, residue of the cut verification-ladder/troubleshooting-budget apparatus the 2026-10-06 review found unused | fine to drop from rules; iterate (`:74,92`) and `agents/implementer.md:33` still carry "verification floor". |
| `subagent_tokens` as the context signal (cap kept) | cost data: `cdocs/reports/2026-09-20-token-spend-by-role.md` (a warm implementer reached 966K tokens); cap set ~250K in `ec690e6`, raised to ~400K in `2965c6a` without rationale | `overseers.md:9` ends in a colon with nothing observable after it; name the signal or drop the colon. Non-blocking. |
| Chat record: "Claude Code top-level session only: `chat-record` exists nowhere else" | design-time, encodes a platform fact | **matters for OpenCode**: rules ship to `.opencode/rules/` and AGENTS.md, but `cdocs-hooks.ts:13-15` says OC has no chat record, so `overseers.md:16` now tells OC agents they "must" run a missing command. Non-blocking. |
| Chat record "Test for a bullet" | design-time | fine to drop. |
| Model tiering: "Do not downgrade" judge/review; consumer-floor carve-out | design-time (`110f8cc`), no downgrade incident found | "unless overridden" (`workflow-patterns.md:5`) preserves consumer precedence; the carve-out prose is fine to drop. |
| Devlog: "a restart, rotation, new turn, or full context is not a seam" | design-time guard against devlog sprawl | weakened by "Often a context handoff coincides with such points" (`devlog/SKILL.md:141`). Non-blocking. |
| Devlog: who closes a devlog at a seam (`status: done`, `next:` naming successor) | design-time, no incident; encodes real ownership logic with no replacement | `agents/triage.md:52` and `skills/iterate/SKILL.md:115` still assume it; see Consistency. |
| Devlog: sub-devlog first-line NOTE; tables continuation; iteration numbers increase across workstream | design-time | NOTE and numbering fine to drop. Tables continuation is now forbidden ("never be split", `:143`) while `agents/judge.md:42` still reads "any forward continuation". |

### `overseers.md`

- Scope reads clearly for "Stay thin".
- "Chat record" is not overseer-specific: the Stop hook demands a note from every top-level session (a plain `/cdocs:devlog` session included).
  Placing it under "CDocs Overseer Rules" makes a non-overseer reader likely to skip it; the Stop hook blocks once, so the failure is self-correcting but costs a turn. Non-blocking.
- `:10` says ~400K; `devlog/SKILL.md:70` says 300K. Pick one. Non-blocking.
- `:20` hardcodes `--as opus-5-5`; harmless as an example, but a non-opus session may copy it verbatim. Non-blocking.

### `tool-use-safeguards.md`

- Clear scope, and the Bash section is verbatim from the reviewed-good text.
- "One writer per file" is about dispatch, not tool use; it fits `overseers.md` at least as well. Taste, non-blocking.

### `workflow-patterns.md`

- `:3` `# Model Tiering` is an H1 inside an H1 document; should be `##`.
- `:8` missing terminal period.
- `:18` dangling `orchestration-discipline.md` reference.

### Devlog skill and template

- **Handoff lifecycle (blocking).** `devlog/SKILL.md:72` "delete it before beginning new work" conflicts with:
  `overseers.md:27` (read "the latest handoff" after compaction), `skills/implement/SKILL.md:49` (continue "from its Scratchpoint and latest handoff"), `skills/oversee/SKILL.md:48,68` (trust "its loop's last handoff"), `skills/iterate/SKILL.md:114` (handoff at every judge assessment, which the overseer itself then deletes on its next pickup), and `agents/judge.md:53` (fresh implementer "onboards from the open sub-devlog's handoff").
  If a pickup deletes the handoff and then compacts or crashes before the Scratchpoint is rewritten, the resumption context is gone (git still has it, but nothing tells the reader to look).
  Suggest: "replace it when you write the next one", or delete only after folding it into the Scratchpoint.
- **Schema drift (blocking for consistency).** The template's Scratchpoint (`template.md:19-26`: `next_steps`, `graphify_query`, `important_files`, `callouts`) is not the iterate template's (`skills/iterate/template.md:5-11`: `as_of`, `now`, `next`, `open`, `files`), and `agents/triage.md:52` keys closure on `next:`.
  Top-level loop devlogs and sub-devlogs will now carry two schemas.
- `graphify_query` is unexplained in the SKILL, and graphify is opt-in in this repo (iterate's `--graphify-scope`, default off) and absent in most consumer projects; the default template asks every devlog for it.
- `:42` missing terminal period; `:62` "append only logs.)" period inside the parenthetical, and "they" for a singular subject.
- `:143` "Top-level overseer devlogs should never be split" contradicts the removed tables-continuation mechanism still read by `agents/judge.md:42`; either is fine, but pick one.
- `:145` "Heirarchies" typo.
- `:157` mandates `<top-level-slug>-<concern-slug>` filenames, which existing sub-devlogs do not follow (lookup is by `part_of`, so harmless; but triage may start flagging them if it ever checks names).
- `:158` file has no trailing newline.
- The Scratchpoint/Handoffs subsections are a clear improvement: typed open-set callouts and "forward-looking, not append-only" state the intent better than the five-field list did.

### Duplication

- Bash discipline lives only in `tool-use-safeguards.md`; good.
- Handoff content criteria (Completed / Decisions Made / Open Todos) now live in `devlog/SKILL.md:66`, `skills/iterate/SKILL.md:14`, and `skills/oversee/template.md:29`. Acceptable as inline floors.
- Context-cap handoff trigger is stated twice with different numbers (above).

## Verdict

**Revise.**
The simplification itself is a reasonable trade, and most cuts are of the "a capable model does this anyway" kind.
It cannot land as-is because the source repo loads none of the new rules, init materialization is undefined for consumers who get the freshness nudge, the unit suite is red, and the resume procedure the loop skills delegate to no longer exists.

## Action Items

1. [blocking] `CLAUDE.md:48-49`: replace the two `@`-imports with `@plugins/cdocs/rules/overseers.md` and `@plugins/cdocs/rules/tool-use-safeguards.md`, with one-line scope summaries.
2. [blocking] `skills/init/SKILL.md:84-90`: replace the two AGENTS.md block sections with `## CDocs Overseer Rules` / `overseers.md` and `## CDocs Tool Use Safeguards` / `tool-use-safeguards.md`; this also fixes the unit test (`chat-record.test.sh:791`).
3. [blocking] `hooks/tests/chat-record.test.sh:818-820`: update the `init_real` assertions to strings present in `overseers.md` (or restore the scope sentence; see 7).
4. [blocking] Restore "Resume from disk" in two or three lines in `overseers.md`: log dispatch/return rows; the harness notifies only when no children remain live; if control returned, the child ended, so read what it left.
5. [blocking] Repoint every procedure reference to its new home: `iterate/SKILL.md:13,37,114,129`, `full-send/SKILL.md:13,15,16`, `implement/SKILL.md:19,81`, `propose/SKILL.md:144`, `propose-revise/SKILL.md:17,42`, `oversee/SKILL.md:12,30`, `ablate/SKILL.md:20,290,291`, `rules/workflow-patterns.md:18`, `rules/frontmatter-spec.md:85`, `devlog/SKILL.md:31`, `devlog/template.md:10` ("Durable state" now maps to the devlog skill's Scratchpoint/Handoffs; model tiering to `workflow-patterns.md` "Model Tiering").
6. [blocking] `devlog/SKILL.md:72`: change "delete it before beginning new work" to replace-on-next-write (or delete only after folding into the Scratchpoint), so it agrees with `overseers.md:27`, `implement/SKILL.md:49`, `oversee/SKILL.md:48,68`, `iterate/SKILL.md:114`, `agents/judge.md:53`.
7. [blocking] Align Scratchpoint schemas: update `skills/iterate/template.md:5-11` to the devlog template's fields, and `agents/triage.md:52` from `next:` to `next_steps:`.
8. [non-blocking] `plugins/cdocs/AGENTS.md:13-19` and `README.md:59-60,140`: list the new files.
9. [non-blocking] `overseers.md:16`: restore "Claude Code only" so OC agents do not try a missing `chat-record`; consider moving "Chat record" to a scope that covers every top-level session.
10. [non-blocking] `tool-use-safeguards.md:8`: add "no directories, never `git add -A` or `commit -a`".
11. [non-blocking] Reconcile the context-cap number (`overseers.md:10` ~400K vs `devlog/SKILL.md:70` 300K) and finish the dangling colon at `overseers.md:9`.
12. [non-blocking] `devlog/SKILL.md:143` vs `agents/judge.md:42`: decide whether loop tables can continue forward and make both agree.
13. [non-blocking] `devlog/template.md:20`/`SKILL.md:56-62`: explain `graphify_query` in one line and mark it optional ("when graphify is available").
14. [non-blocking] Nits: `workflow-patterns.md:3` H1 to H2, `:8` period; `devlog/SKILL.md:42` period, `:62` punctuation, `:145` "Hierarchies", `:158` trailing newline.

## Open Questions

1. Where should "Resume from disk" live?
   (a) `overseers.md`, three lines (recommended: every loop skill already points there);
   (b) inline in each loop skill's resume step;
   (c) drop it and accept the orphan-child risk.
2. Chat record placement:
   (a) keep in `overseers.md` with a "every top-level session, not just overseers" lead sentence;
   (b) move to its own short rule;
   (c) move to `tool-use-safeguards.md`.
3. Handoff lifecycle on pickup:
   (a) replace on next write (keeps the latest for crash recovery);
   (b) fold into the Scratchpoint, then delete;
   (c) keep as written and update every reader to look in git history.
