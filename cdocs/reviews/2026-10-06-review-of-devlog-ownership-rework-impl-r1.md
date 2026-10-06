---
review_of: cdocs/proposals/2026-10-06-devlog-ownership-rework.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T12:11:47-07:00
task_list: cdocs/devlog-ownership-rework
type: review
state: live
status: done
tags: [fresh_agent, implementation_review, devlog, orchestration_discipline, evidence_checked, live_smoke]
---

# Review: Devlog Ownership Rework, Implementation (round 1)

> BLUF(@claude-opus-5-5/cdocs/devlog-ownership-rework): **Accept.** The change does what the proposal says: the lead's top-level devlog is the index and state record, sub-devlogs start forward at content seams, the split procedure is gone, and triage reads a family by highest iteration.
> I re-ran every mechanical gate and they pass. The smoke transcripts show one writer per devlog, with Bash writes counted, and triage finds the latest verdict.
> What remains is nits, plus one cheap adjacent fix (`implementation_wip` in the spec's status list) worth landing as its own commit.

## Summary Assessment

Implementation `9ee284d..320117e` covers 13 plugin files in nine commits, one commit per concern, with the evidence in [the implementation sub-devlog](../devlogs/2026-10-06-devlog-ownership-rework-full-send-implementation.md).
A cold read of the final devlog skill and orchestration rule is coherent and short. The rework adds no new field or procedure: it reuses `part_of`, and the old five-part split procedure becomes five short bullets.
The floor is met with evidence from the transcripts, not only from the files.
The gaps are small: the live restart path (a fresh implementer continuing the same concern) was not smoked, the sub-devlog naming convention was not followed in either smoke, and a few wording nits remain.

## Re-run gates

| gate | result |
|---|---|
| `npm run build:cdocs` | exit 0, 7 agents converted |
| `bash plugins/cdocs/hooks/tests/chat-record.test.sh --unit` | 95 passed, 0 failed |
| validator on the changed cdocs (implementation sub-devlog, top-level) | silent. Negative control (a `part_of` devlog missing fields) warns `missing required frontmatter fields: first_authored state status` |
| Test Plan stale-reference grep over `plugins/cdocs`, incl. `chunk` | 0 lines |
| same patterns over `README.md`, `CLAUDE.md`, `plugins/cdocs/README.md` | 0 lines |
| leftover `split` / `root devlog` / `section-level` / `own section` | only unrelated hits (nit-fix line splitting, ablate command splitting, README "root `CLAUDE.md`") |
| `wc -w rules/*.md` | 2,217 -> 2,199 |
| `wc -w skills/devlog/SKILL.md` | 1,108 -> 1,069 |

Inbound references: every `"Continuing in a new devlog"` and `Workstream Devlogs` reference resolves (`frontmatter-spec.md:89`, `implement/SKILL.md:88`, `iterate/SKILL.md:77,82-83`, `iterate/template.md:13`, `oversee/template.md:30`).
No reference to the old heading or `## Chunks` remains in plugins, README, or CLAUDE.md.

## Section-by-Section Findings

### Proposal conformance

- **Top-level as index and state record.** The devlog skill's "Top-level" bullet, iterate Turn 0 (continue the `task_list`-matching, proposal-citing devlog that has no `part_of`, else create `-iterate.md`), and the template's empty `## Workstream Devlogs` table with columns `devlog | concern | status | read this when` (r2's column change, as directed) all match.
  Oversee: the arc overseer owns each proposal's top-level, and the arc devlog holds narrative and links.
- **Seams are soft and depend on content.** "Size prompts the look, and the content chooses the cut", and "A restart, rotation, new turn, or full context is not a seam" separate the boundary from who the implementer is.
  "Stay thin" now says the fresh subagent "continue[s] that devlog".
- **One writer at a time.** The implementer agent writes the named sub-devlog and leaves the top-level alone. The implement skill's dispatched bullet does the same. Closing a finished concern is covered ("the leaving writer ... else the lead", plus iterate Checkpoint).
- **One live Scratchpoint per writer per workstream.** Durable state, the devlog skill's Scratchpoint bullet, and the implement skill all say it. The section-level clause is gone.
- **Retroactive splitting gone.** The closed-concern test, the cut, the merge floor, and rewording of moved text are all removed.
- **Triage family read.** Step 6.1 is the proposal's family sentence, and step 6.6 repeats "highest iteration number across the family" where the row is picked. Step 2 reports a nested `part_of` (r2 item 5).
- `skills/triage/SKILL.md` and `skills/full-send/SKILL.md` are unedited. I checked both: neither has stale text.

### Cold read: devlog skill and orchestration rule

- Coherent and light. A fresh agent can act on "Continuing in a new devlog" without the proposal, and the rule's Durable state paragraph is two sentences that point to it.
- **nit:** the "Who" bullet says the same thing twice. Its first sentence already has the leaving writer close its devlog, and its third repeats that before adding the only new part ("else the lead does").
  Tighter: "If the next concern goes to another writer and the finished devlog is still open, the lead marks it `done`."
- **nit:** `oversee/template.md`'s new `// the proposal's top-level devlog ...` comment repeats `oversee/SKILL.md:52`'s "devlog (the proposal's top-level devlog)". An agent writing the real `.json` may also copy the comment into it. The fence is `jsonc`, so the template itself is valid. Dropping the comment removes the duplication.
- **nit, judgment:** triage step 5 still skips the Verification completeness check for a closed sub-devlog.
  That made sense for cut chunks, which might lack Verification. A sub-devlog is now a normal devlog with its own Verification, so the skip hides a missing-evidence signal.
  Recommending `done` and still running the check costs nothing. This is optional.

### Smoke evidence

I checked `devown/smoke{1,2}/analysis.txt` and `triage_report.txt`, and grepped the subagent transcripts myself for any tool call naming the top-level.
- **Single writer per devlog.** In both smokes the top-level's only writer is `lead` (Write, a python heredoc, a redirect). Each sub-devlog has one implementer writer.
  In smoke2, `-phase1` is written by `ac2e0df9` at 19:04:57Z and `-phase2` by `ac4e5b5f` at 19:05:58Z, in sequence.
  Every implementer and reviewer Bash command that mentions `greet-iterate.md` is a read (`head -12`) or a `part_of:` line inside a heredoc body.
- **Bash writes counted.** `analyze.py` counts redirects, `tee`, `sed -i`/`perl -i`, and python opens or writes that bind the path, so r2 item 2 is met.
  The only extra writes on sub-devlogs are a reviewer stamping `last_reviewed` in frontmatter (the review skill's existing step, run after the implementer returned) and the lead's one `sed -i` closing both at loop end (the documented "else the lead does").
- **Triage after the smoke.** Both reports name the top-level and the latest row: `review_verdict=accept (iteration 2 ...)`, `[NONE]` (the proposal is already accepted).
  Fixture 1 covers the `[STATUS] implementation_accepted` transition, and the fixture reports (spot-checked `new/fx1-5`, `old/fx2`) match the devlog's table.
- **Adequate for the floor.** Yes: the floor asked for a lead-only top-level, an implementer-only sub-devlog with its own Scratchpoint, and triage finding the verdict, and the transcripts show all three.
- **non-blocking:** the main behavior change is that a restart or rotation continues the same sub-devlog, and no smoke exercises it with a fresh agent.
  smoke1's second write is the same implementer resumed via `SendMessage`. smoke2's new file follows a new phase, which the old and new text would both produce.
  So "a fresh implementer on an open concern continues it and replaces its Scratchpoint" rests on the wording alone. That is acceptable at this floor, and a good subject for the next loop that has a real restart.
- **nit:** neither smoke lead followed the naming `<top-level-slug>-<concern>`. smoke1 produced `2026-10-06-greet-impl.md` and smoke2 `-greet-phase1/2.md`, where the convention gives `greet-iterate-impl`.
  Lookup goes through `part_of`, so nothing broke. Since agents ignore the naming anyway, consider loosening it to "the top-level's date and a concern slug" rather than adding emphasis.
- **nit:** `analyze.py`'s "broad staging: none" missed smoke2's `git add cdocs/devlogs` (a directory) and `git add cdocs/_chat/*.md` (a glob). The implementer caught the first by hand.

### This workstream's own devlogs (dogfooding)

- The implementation sub-devlog follows the new shape: `part_of`, a backlink NOTE, its own Scratchpoint, and a handoff.
- **nit, overseer's:** the top-level's Scratchpoint is still `as_of: 2026-10-06T11:40`, `now: iterate impl-1`, while the Dispatch/Return rows run to rev-3.
  This is the lead's own upkeep, not the implementation's, but it is the first live example of the lead Scratchpoint the rework depends on.

## Implementer follow-ups: now or later

| item | call | why |
|---|---|---|
| `implementation_wip` missing from the spec's `status` list | **cheap fix now, own commit** | One line in `frontmatter-spec.md` (~12 words). It cost smoke1 a whole revise round, and fixture 3's triage called the status invalid. It sits next to this change but is not part of it, so commit it separately. |
| fixture 2 does not discriminate | follow-up, low value | The design requires the pointer line, and sonnet follows it under either text. A version without the pointer would test robustness, not this change. Record it and move on. |
| dispatch/return rows batched at loop end | follow-up (or none) | This predates the change: the rule already says "as it happens". Adding wording would be a formalism against a compliance lapse. Watch for it in the next real loop. |
| smoke2 lead's `git add cdocs/devlogs` | optional nit now | "stage by explicit path" could say "explicit file path" (+1 word in an always-loaded rule). It was harmless here because only the lead was live, so either way is fine. |
| stale `last_reviewed` on the haiku proposal | follow-up | It is real data on another proposal, and this proposal says not to edit other docs. Leave it to a triage pass on that proposal. |

## Verdict

**Accept.**
The rules, skills, and agents match the accepted proposal. The cold read is coherent and adds no new formalism, and every gate re-runs clean. The smoke evidence meets the floor with transcript-level authorship checks that include Bash writes.
Nothing blocks. The `implementation_wip` spec line is the one adjacent fix I would land now.

## Action Items

1. [non-blocking, cheap, separate commit] Add `implementation_wip` to `frontmatter-spec.md`'s `status` list (Proposals only, set by `/cdocs:implement` during implementation).
2. [nit] Tighten the devlog skill's "Who" bullet so its third sentence states only the lead's fallback.
3. [nit] Drop the `//` comment from `oversee/template.md`'s `devlog` field, since `oversee/SKILL.md` already says it.
4. [nit, optional] Triage step 5: run the Verification check on closed sub-devlogs as well, since they are normal devlogs now.
5. [nit, optional] Loosen sub-devlog naming to the top-level's date plus a concern slug, since neither smoke followed the slug prefix and lookup does not depend on it.
6. [nit, overseer] Refresh the top-level devlog's Scratchpoint, which is stale at `11:40 / iterate impl-1`.
7. [follow-up] Next loop with a real restart or rotation: confirm the fresh implementer continues the open sub-devlog and replaces its Scratchpoint.
8. [follow-up] Fixture 2 non-discrimination, batched dispatch rows, and the haiku proposal's stale `last_reviewed`: record them, no change now.

## Questions for the Maintainer

1. `implementation_wip` in the spec:
   a. overseer lands the one line now as its own commit (recommended), or
   b. file it as a follow-up.
2. Sub-devlog naming, given both smoke leads ignored the slug prefix:
   a. loosen to "the top-level's date and a concern slug" (recommended, fewer formalisms), or
   b. keep it as written.
