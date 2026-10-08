---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T10:40:00-07:00
task_list: cdocs/rules-delivery/skill-load-by-reference
type: report
state: live
status: wip
tags: [analysis, architecture, claude_skills, rules_delivery]
---

# Skill Load-by-Reference for Non-Universal Guidance

> BLUF: Adapt.
> Loading a skill from another skill works on Claude Code 2.1.293: an "invoke `/cdocs:oversee-workstream` with the Skill tool" line was followed, and the invoked text is re-attached after compaction.
> Moving `overseers.md` into an `oversee-workstream` skill suits only its intro and "Stay thin" (16 lines, 140 words).
> "Chat record" applies to every top-level session, because the Stop hook enforces it on each human turn, so it stays universal.
> The move alone does not fix the trigger: a nested full-send still loads the skill.
> The fix is a PreToolUse hook that denies `chat-record note|path` when the payload carries `agent_id`, which is the only signal that marks a subagent's Bash call.

Labels: **[verified]** = probed on 2.1.293 or read from code/binary; **[docs]** = code.claude.com docs; **[inferred]** = reasoning, not tested.
Each probe ran headless with a temp `CLAUDE_CONFIG_DIR`, `--plugin-dir`, haiku or sonnet, n=1 per variant.
The credential copy has been deleted.

## Context

The trigger: a subagent running `/cdocs:full-send` called `chat-record note`.
`CLAUDE_CODE_SESSION_ID` is the parent's, so the note landed in the parent's record.
The maintainer's plan is to rename `oversee` to `oversee-many` and to replace the always-loaded `rules/overseers.md` with an `oversee-workstream` skill that the loop skills load by reference.

Prior art: the rules-context decomposition already moved arc-only material into `skills/oversee/SKILL.md` and set a "compress before relocating, no shared reference file" principle (`cdocs/proposals/2026-10-05-rules-context-decomposition-rfp.md:332-335`).
A fallback that had agents read rule files from the plugin was rejected (`cdocs/proposals/2026-10-07-rules-references.md:243-247`).
The compaction canary changed `.claude/rules/cdocs.md` on disk before `/compact` and saw the new text afterwards.
A no-compaction control did not resend the file (`cdocs/reviews/2026-10-07-review-of-rules-references-r4.md:48-65`).
The prior work never tested whether skills survive compaction, and never proposed a mechanical way to detect subagents: "subagents should never" exists only as rule text.

## Key Findings

### 1. Mechanics

- **Skill tool instruction** [verified]: the outer skill says "invoke `/probe:inner` with the Skill tool and follow it".
  Haiku called `Skill(probe:inner)` first and followed it (canary emitted).
- **Relative markdown link** [verified]: `[guidance](../inner/SKILL.md)` also worked.
  Haiku resolved it against the "Base directory for this skill" header and `Read` it.
- **Supporting files** [docs]: the documented pattern is `SKILL.md` linking to files in its own directory.
  A cross-skill `../` link only works because of the base-dir header.
- **Most reliable: the Skill tool.**
  It addresses the skill by name, needs no path, and is the only variant that compaction re-attaches as a skill (see 3).
  Content loaded by `Read` falls into the generic post-compact "recent files" restore, which is capped and ordered by recency [verified, binary].
  Repeat invocations (full-send composes propose-revise, then iterate) duplicate about 400 tokens before compaction.
  After compaction, only the most recent invocation of each skill is re-attached [docs].

### 2. Reach

- **Skill tool in subagents** [verified]: a `general-purpose` subagent saw the plugin's skills in its listing and invoked `probe:inner`.
  An agent with `tools: Bash, Read` had no Skill tool and could not invoke it.
  An agent with `tools: Bash, Read, Skill` could.
- **cdocs agents** [verified, code read]: `implementer`, `proposer` and `reviewer` have `tools: "*"`, so they have Skill [inferred from the probe above].
  `bash-runner` (`Bash`), `judge` (`Read, Glob, Grep`), `nit-fix` and `triage` (`Read, Glob, Grep, Edit`) cannot load skills.
  None of these four lead loops, so this costs nothing.
- **Hiding chat-record instructions from non-overseer subagents** [inferred]: yes for the skill's body, since only a Skill call loads it.
  The skill *description* is in every subagent's listing [verified], so it must name no instructions.
- **Does it fix the trigger?** No.
  A subagent that runs full-send loads `oversee-workstream` and sees whatever it says about chat-record.
  The current rule already says "subagents should never", and that did not stop it.
- **Subagent signals** [verified]:

  | Signal | Main session | Subagent |
  |---|---|---|
  | Bash env (`CLAUDE_CODE_SESSION_ID`, `CLAUDE_CODE_CHILD_SESSION`, `AI_AGENT`, `CLAUDE_PID`, ...) | set | **byte-identical** |
  | PreToolUse payload `agent_id`, `agent_type` | absent | present (`a44331de...`, `general-purpose`) |
  | PreToolUse `transcript_path` | parent `.jsonl` | **parent `.jsonl`** (not under `subagents/`) |

  The binary builds the Bash env in `Gze({sessionId: K(), source: "agent"})`, which has no agent identity.
  `agent_transcript_path` exists only on SubagentStop.
  So the `chat-record` script cannot tell a subagent from the main session; a hook can.
  `chat-record`'s hook modes already ignore payloads that carry `agent_id`.
- **The fix**: add a `PreToolUse` `Bash` hook, either a `chat-record PreToolUse` mode or a small script.
  When `agent_id` is set and the command runs `chat-record note` or `chat-record path`, it returns `permissionDecision: "deny"` with the reason "top-level only; put this in your report or devlog" [docs: deny JSON, `if` filter].
  An `"if": "Bash(chat-record *)"` filter can skip spawning the hook on other commands, but it misses absolute-path invocations [docs, inferred].
  This adds one hook, which cuts against the maintainer's minimal-hooks preference, but it is the only mechanism that works.

### 3. Durability across compaction

- **Skills** [verified]: an in-process probe (stream-json driver) invoked `/probe:outer` with canary `ALPHA`, changed the file on disk to `BRAVO`, then ran `/compact`.
  A `Skills restored (probe:inner, probe:outer)` attachment returned the **ALPHA** text.
  Skills are re-attached as a snapshot taken at invocation, not re-read from disk.
- **Limits** [verified, binary; docs agree]: each skill keeps its first 5,000 tokens, then the marker `[... skill content truncated for compaction; use Read on the skill path ...]`.
  All skills share a 25,000-token budget, filled most-recent-first, and older skills are dropped once it runs out.
  The overseer skills are well below these limits (iterate is about 2.1k tokens; oversee-workstream would be about 0.2k).
- **Resume gap** [verified]: running `claude -p --resume <id> "/compact"` in a *new process* re-attached no skills.
  The invoked-skill registry is in memory and is rebuilt only from earlier `invoked_skills` attachments.
  The same gap is [inferred] for an interactive `--resume`.
- **Rules** re-inject from disk on every compaction, with no budget [verified by the prior canary].
- Net: skill text is durable inside one process and fails silently after a resume followed by compaction.
  Guidance that must survive compaction needs a one-line universal pointer that says to re-invoke the skill.

### 4. Cost and drift

- **Context saved** [verified, `wc`]: `overseers.md` has 33 lines and 285 words, out of 293 lines and 1,942 words of rules.
  Its sections: intro 7 lines / 46 words, Stay thin 9 / 94, Chat record 17 / 145.
  Moving the intro and Stay thin saves about 140 words, roughly 200 tokens, per session and subagent.
  That is small; the case rests on scoping behavior, not tokens.
- **Chat record is not overseer-specific** [verified, code]: `hook_stop` blocks any top-level turn that has `@user` with no agent note, overseer or not.
  Moving Chat record into an overseer skill would make every non-overseer session pay the one-turn block on each human turn.
- **Duplication**: low if loop skills only point at the skill, high if they restate it.
  `ablate/SKILL.md:20` already keeps an "inline floor" copy, so watch that one.
- **`npm run test:rules`** [verified, code]: `scripts/check-rule-refs.ts` resolves only quoted `"CDocs ..."` refs and forbids rule filenames.
  Today 10 refs point at "CDocs Overseer Rules": full-send, propose-revise, oversee, ablate (x2), implement, propose, devlog SKILL and template, and frontmatter-spec.
  They would fail as "unknown rule".
  Skill refs (`/cdocs:x`) are not checked at all, so a stale `/cdocs:oversee` after the rename would pass.
- **`/cdocs:init`** [verified, code]: `.claude/rules/cdocs.md` and `.opencode/rules/cdocs/` are glob-driven.
  The OpenCode copy deletes orphaned rules.
  The `AGENTS.md` block (step 6) and the concat order are hard-coded and must be edited.
- **`inject-rules.ts`** [verified, code]: it hashes the globbed `rules/*.md`, so it needs no change.
  Consumers get a one-time "re-run `/cdocs:init`" directive.
- **OpenCode** [verified, code]: `build-opencode.ts` copies skills verbatim; only agent bodies are rewritten.
  `postinstall.js` copies skills flat to `.opencode/skills/<name>/`.
  It does **not** remove stale skill dirs, so a consumer keeps `.opencode/skills/oversee/` after the rename.
  The text "invoke `/cdocs:oversee-workstream` with the Skill tool" ships unchanged.
  In OpenCode the skill is named `oversee-workstream`, so whether its skill tool resolves the `cdocs:` form is [inferred] to be the same gap every existing `/cdocs:x` cross-reference already has.
  The deny hook is Claude Code-only, but so is `chat-record`.

### 5. Generalization: rule content section by section

| Rule › section | Verdict |
|---|---|
| Overseer › intro, Stay thin | **Move** to `oversee-workstream`; only loop leads need it, and in other subagents it can push toward over-delegation |
| Overseer › Chat record (incl. after compaction) | **Universal for top-level sessions** (Stop hook enforces it); keep it in a rule; a hook enforces the subagent ban |
| Writing Conventions › all | Universal: every agent that writes docs or messages needs it |
| Workflow Patterns › Model tiering, Parallel investigation | Universal: any session may dispatch |
| Workflow Patterns › Loops, Before review, Completeness | Universal: the decision to enter a loop comes before any skill is loaded; add the pointer line here |
| Tool Use › Tools and Skills, One writer per file, Bash | Universal |
| Frontmatter Spec (110 lines / 584 words, the largest) | Candidate for later: only doc writers need the field definitions; doc skills carry templates and the PostToolUse validator gives feedback. Moving it is a separate decision, since nearly every subagent writes cdocs docs |

## Recommendations

**Adapt.**
Load `oversee-workstream` by reference through the Skill tool for loop-only discipline.
Keep Chat record universal.
Close the trigger with a hook, not with text placement.

Outline for the two planned changes:

1. **Rename** `git mv plugins/cdocs/skills/oversee plugins/cdocs/skills/oversee-many` and set `name: oversee-many`.
   Update the `/cdocs:oversee` refs in `CLAUDE.md:51`, `plugins/cdocs/AGENTS.md:32-33`, `plugins/cdocs/README.md` (skills table), and any other skill that mentions it.
   `.gitignore`'s `.claude/oversee/` is the arc-state dir and can stay.
   Note in the changelog or README that OpenCode consumers should delete `.opencode/skills/oversee/`, or have `postinstall.js` prune skill dirs that no longer exist in the source.
2. **New `plugins/cdocs/skills/oversee-workstream/SKILL.md`** holds the overseer definition, "not nested", the `oversee-many` pointer, and Stay thin, plus one line: "If the Agent tool dispatched you, your dispatcher owns the chat record and the top-level devlog."
   Write the description as a role ("discipline for a session leading a loop"), not as instructions.
3. **Loop skills reference it** with one first-step line: "Before dispatching, invoke `/cdocs:oversee-workstream` with the Skill tool (skip if its text is already in context)."
   Apply this to `iterate:10`, `propose-revise:14`, `full-send:13`, `oversee-many:12` and `ablate:20,290`; drop ablate's inline copy.
   `implement:19` and `propose:144` ("thin lead per … Stay thin") get the same line in their top-level dispatch mode.
4. **Rule files**: delete `rules/overseers.md`.
   Move "Chat record" (with "After a compaction") to `tool-use-safeguards.md` as `## Chat record`, stating that it is top-level only and that a hook blocks subagents.
   Add to Workflow Patterns › Loops: "Leading a loop makes you the overseer: invoke `/cdocs:oversee-workstream`, and again after a compaction or resume if its text is not in context."
   Repoint `frontmatter-spec.md:85`, `devlog/SKILL.md:31` and `devlog/template.md:10` to "CDocs Tool Use Guidance › Chat record".
   Edit the hard-coded `## CDocs Overseer Rules` block in `init/SKILL.md` steps 3 and 6, `plugins/cdocs/AGENTS.md:13-15`, `CLAUDE.md:48,61`, and `README.md:123,153`.
5. **Hook**: add a `PreToolUse` `Bash` entry in `hooks.json` and a `chat-record PreToolUse` mode that denies `note|path` when `agent_id` is set.
6. **Tests**: extend `check-rule-refs.ts` so every `/cdocs:<name>` in the scanned content must match `plugins/cdocs/skills/<name>/SKILL.md`; this catches stale `/cdocs:oversee`.
   Add `chat-record.test.sh --unit` cases: deny with `agent_id` set, silent without it, silent for other commands.
   As a one-off acceptance probe, rerun this report's subagent probe against the real plugin: a `general-purpose` subagent running `chat-record note` should be denied.

WARN(opus/skill-load-by-reference): probes were n=1 on haiku and sonnet with toy skills.
That Opus follows a "load this skill first" line inside a long loop skill is [inferred].
Check it in the first real `/cdocs:iterate` run after the change by looking for a `Skill(cdocs:oversee-workstream)` call in the transcript.
