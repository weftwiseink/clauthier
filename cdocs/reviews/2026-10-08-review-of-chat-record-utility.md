---
review_of: cdocs/_chat/2026-10-07-63ac45de-462d-4f43-ae1c-4ab6d59049b8.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T09:01:02-07:00
task_list: cdocs/triage-state
type: review
state: live
status: done
tags: [self, chat_record, methodology]
---

# Review: Chat Record Utility (session 63ac45de)

> BLUF: Revise the methodology, not the mechanism.
> The record covers this session's landings and the biggest decisions, but about a quarter of its 42 agent bullets are loop-progress narration that the rules-references devlog already logs nearly word for word.
> It drops the *why* behind decisions and most open or unverified items.
> The `gist:`/`query:`/`read:`/`follow-up:` typing adds nothing: 36 of 42 bullets are `gist:`, and all three `query:` lines only say an agent is running.
> Replace the types with untyped bullets under a salience test that excludes what a devlog already holds.
> Changing it costs one rule section, one Stop-hook reason string and the `bin/README.md` examples; no code parses the types.

Reviewed as a fork with this session's full context, so the check below is against what actually happened, not what the record claims.
Scope: the 42 agent bullets (16 human prompts were backfilled from the transcript in `091bd1f`; the `UserPromptSubmit`/`Stop` hooks never loaded in this process).

## Coverage: what mattered vs what the record holds

| # | Fact a cold successor needs | Record |
|---|---|---|
| 1 | Nested-overseer mistake: loops dispatched as sub-overseers; root cause `workflow-patterns.md:18` / "Stay thin" read as whole-loop delegation, plus dispatch-all vs owns-devlog tension | captured (18:25, 20:41, 21:28) |
| 2 | Heading references chosen over `cdocs/rules/overseers.md#Stay thin` path refs, *because* internal rule paths are awkward downstream and collide with the consumer's `cdocs/` | partial: the choice is recorded (22:01), the reason only in the backfilled prompt |
| 3 | Canary result: the compaction summary carries the canary word, so only an on-disk A->B swap discriminates; it showed compaction re-injects `.claude/rules/` from disk, which justifies dropping the `@`-import | captured (22:04, 22:08), but the link to "therefore the import is dropped" is implicit |
| 4 | Landings: `1372ce3` opencode, `691ae6c` browser-delegate, `e0d9ec9` rules-references | captured |
| 5 | Hooks not loaded: process predates `e9a6e12`; plugin hooks snapshot at launch, `/reload-skills` doesn't reload them | captured (08:18) |
| 6 | OpenCode constraint: maintainer may drop OC entirely if it intrudes on the Claude Code setup; `model:` dropped and accepted | partial: `model:` drop recorded; the drop-OC threshold appears only in a prompt |
| 7 | Release debt: `plugin.json` unbumped, CI `rules` job never run on GitHub, published `@weftwise/cdocs-opencode` 0.1.0 stale | partial: only the `plugin.json` bump |
| 8 | Browser-delegate gaps: convergence untested against weftwise, SIGTRAP in the live devcontainer, dispatch from an installed plugin, reviewers ran the old installed `reviewer.md` | missing |
| 9 | Ceremony lesson: every review round only adds text (agent ~4x `bash-runner`, 17 of 23 post-launch lines went to the convergence script) | partial: the numbers are there, the lesson isn't |
| 10 | Graphify: overseer ingests the brief; maintainer wants fresh contexts to self-query; proposer's caveats (nothing measured, `/graphify` skill absent in lace, shared stale index) | captured (08:18, 09:00) |
| 11 | Commit-trailer slip (trailers in the subject line with no blank line; fixed with `reset --soft`) and the `tsx` EINVAL under a long TMPDIR leading to `node --import tsx` | missing (the second is in the devlog, the first nowhere) |
| 12 | Subagents get the rules through the CLAUDE.md hierarchy, so the agents' Startup rule-file reads were dead and removed | partial: "Startup rule reads never resolve downstream" (21:29); the fix isn't recorded |

Tally: 5 captured, 5 partial, 2 missing.
The record is reliable for *what landed* and weak on *why* and *what's still open*, which is what a successor acts on.

## Bullet quality

- **Narration share.** About 10 of 42 bullets are progress narration:
  - "r1 opus review dispatched", "r2 opus review dispatched", "warm proposer revising"
  - "fresh reviewer re-running floor", "implementer on phases 1-3"
  - all three `query:` lines ("fork committing...", "opus agent building...")

  For rules-references, 21:54 through 23:04 is a line-for-line shadow of that devlog's Dispatch/Return Events.
- **The best entries carry a reason or a surprise.** The self-diagnosis (21:28), the skill-tension trace (20:41), the canary finding (22:04) and the hooks-not-loaded cause (08:18) each change what a successor would do.
  None of them needed a type tag to be useful.
- **The typing adds nothing.**
  - `gist:` is the catch-all: 36 of 42.
  - `query:` only ever says an agent is running.
  - `read:` was used once ("read proposal for overview"); its intended job was file awareness (`2026-09-22-chat-record-devlog-management.md` line 54), and it gave none.
  - `follow-up:` was used twice. The 21:29 follow-up is useful, but a plain bullet starting "open:" would do the same.

  Picking a type pushes toward logging *activity* ("I queried / read / dispatched") rather than *conclusions*.

## Overlap with devlogs

- **Only the record has:**
  - verbatim human prompts, which carry the maintainer's intent and reasons (items 2 and 6), but only when the hook runs
  - a single timeline across five workstreams and four devlogs
  - turns with no devlog home: Q&A answers, the hooks-not-loaded diagnosis, the artifact URL
- **Only the devlogs have:** verification, deviations, non-done items, iteration tables.
- **Both have:** loop progress whenever a top-level devlog exists.

Worth the cost? Yes for the prompts, and for agent notes on turns with no devlog home.
Agent notes that restate devlog progress are pure cost: one tool call per turn, plus diluting the record's signal.

## Recommended rule text

Replacement for the body of "CDocs Overseer Rules › Chat record" (the last three paragraphs stay as they are):

````md
Top-level agents keep the session's chat record with `chat-record` (subagents never do); hooks add the human prompts.
Before ending a turn that began with a human prompt, append one to three bullets a cold successor would act differently for knowing: decisions and their reason, surprises, what landed (commit), what is still open.
Skip progress the devlog already logs (dispatches, review rounds, "agent running"); if that is all the turn did, one bullet naming the devlog is enough.
The quoted heredoc keeps the body byte-exact:

```bash
chat-record note --as opus-5-5 <<'EOF'
- heading refs, not path refs: maintainer finds internal rule paths awkward downstream; npm run test:rules checks them
EOF
```
````

## Change cost

No code parses the bullet types: `chat-record note` appends stdin opaquely.
- `plugins/cdocs/bin/chat-record:160`: the Stop block's reason template `- gist: <what a successor should know from this turn>`; change it to `- <what a successor would act differently for knowing>`.
- `plugins/cdocs/bin/README.md:32,36,58`: example bodies.
- `plugins/cdocs/hooks/tests/chat-record.test.sh`: `- gist: x` style fixtures are opaque bodies, and line 514 asserts its own fixture verbatim. No change needed, though renaming them for consistency is free.
- `cdocs/proposals/2026-09-22-chat-record-devlog-management.md` (BLUF, line 54 `read:` file awareness): add a NOTE, don't rewrite. `tiered-chat-records-rfp` doesn't mention the types.

## Non-blocking

- **No detection when the hooks are missing.** This session ran ~15 hours with no prompts recorded and nothing flagged it.
  A one-line stderr warning from `chat-record note` when the record has no `@user:` header would have surfaced it on the first note.
- **The Stop-hook block also never ran here.** The notes were written from the rule alone, so this session is also evidence that the rule works without enforcement.

## Verdict

**Revise** (the methodology).
Adopt the untyped, salience-tested rule above and the Stop-reason string change.
The mechanism (hook-written prompts, `chat-record note`, the commit-with-devlog rule) is sound.
