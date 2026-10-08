---
review_of: cdocs/proposals/2026-10-06-devlog-ownership-rework.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T11:58:00-07:00
task_list: cdocs/devlog-ownership-rework
type: review
state: archived
status: done
tags: [fresh_agent, architecture, devlog, orchestration_discipline, formalism_reduction, evidence_checked]
---

# Review: Devlog Ownership Rework (round 1)

> BLUF(@claude-opus-5-5/cdocs/devlog-ownership-rework): Design A (lead's top-level devlog as index, sub-devlogs started forward) is the right base, and the real devlog families support it more strongly than the proposal argues: the retroactive splitter rediscovered implementer and phase seams by hand, and the split roots it produced are already A's top-level.
> But "one sub-devlog per implementer, a new file per fresh agent" is wrong, and the 11:55 maintainer steer (content-driven boundaries, decoupled from implementer, restart, or context) is the correct fix: it matches both real histories better.
> Verdict: **Revise**: fold in the steer, make the seam check fire at every return (not only phase ends), and settle where a writer's one live Scratchpoint lives when the same writer has two open devlogs.

## Summary Assessment

The proposal fixes the shared loop devlog (overseer tables and implementer notes in one file, piled-up section Scratchpoints, two writers) by making the workstream's top-level devlog the lead's index and state record, putting implementers in `part_of` sub-devlogs, and replacing the retroactive split with forward continuation.
It is well grounded: its evidence citations check out (word counts, the two triage review rounds, chunks copying the root's `first_authored`), its change table covers the right files, and its verification floor is concrete with transcript-level checks.
The most important findings are that its sub-devlog unit (one per implementer, new file on every restart) does not match how real work segmented, that its continuation trigger misses the warm-implementer case that produced the largest real devlog, and that "every devlog has exactly one Scratchpoint" contradicts its own rule that the top-level is never closed while its tables continue forward.
All three are small textual fixes; the architecture stands.

## Primary Question: Design A vs Design B

**Recommendation: A, as a hybrid with B's succession inside a sub-devlog, which is what the 11:55 steer already asks for.**
Concretely: the lead's top-level is the index and state record (A); sub-devlogs are cut forward at content seams (A); whoever is implementing that concern writes the current sub-devlog, and a fresh or restarted implementer continues it when the concern is still open (B's succession, single writer at a time).

### Testing both designs against real history

The chat-record iterate family (653-word root, chunks of 731 to 2,500 words) segmented as:

| chunk | implementer(s) | overseer table words | other words |
|---|---|---|---|
| -phase1a | impl-1 | 157 | 574 |
| -phase1b | impl-2 | 188 | 2,069 |
| -phase1b-fixes | impl-3 | 286 | 891 |
| -phase2 | impl-4, impl-5 | 564 | 1,936 |

The haiku bash-wrapper arc family segmented as `-p0-haiku-r1-r5` and `-p0-sonnet-r6-r8` (both impl-1, warm across eight iterations of one phase, cut at the judge escalation and model switch), `-p0-completeness` (impl-2), `-p0-rewrite-fixes` (impl-3), and `-p1-propose-revise` (overseer only, 1,349 table words, 102 other).

What this shows:
- **The split roots are A's top-level.** Both roots after splitting hold exactly the Brief/Objective, an index, the live tables, and loop handoffs. A does not invent a shape; it produces the shape the splitter converged on, without the split.
- **Seams are content, not agents.** Phase 2 shares one chunk across impl-4 and impl-5; impl-1's work splits in two at a content seam inside one agent's life. "One sub-devlog per implementer" would have produced a 4,300-word impl-1 file (no phase end ever fired) and two small files for Phase 2. The steer's "soft and content-driven" boundary reproduces the hand-made cuts; the proposal's per-implementer rule does not.
- **B's implementer devlog would have needed splitting anyway.** The implementer prose alone is ~5,500 words (chat-record) and ~6,400 words (haiku p0). Under B both files grow past the trigger and keep the retroactive split, its moved-rows lines, and triage's empty-root-table clause.

### The maintainer's sub-questions

- **What an agent does by default when told "write a devlog".** It creates a new file named for its work and writes its own Objective, Plan, notes, and Scratchpoint. A's top-level for the lead is exactly that default for the overseer. For implementers, "write in the devlog your Task names (create it if absent)" is the natural form of both A and B; continuing an open concern's devlog is the same move as resuming one's own devlog after compaction (read Scratchpoint and latest handoff, replace the Scratchpoint), so B-style succession costs no new intuition. B's unnatural part is the overseer's devlog being labeled a "sub" while it exists first (propose-revise has no implementer) and holds the Brief.
- **What a fresh or restarted implementer reads.** Proposal, latest review, and the current concern's Scratchpoint plus latest handoff. Under the hybrid that is one file, already open on the concern. The top-level's `## Devlogs` "read this when" column is the cure for decisions lost across a chain; name the top-level in the restart dispatch so the fresh agent can consult it (the proposal's step 2 omits it).
- **How triage and status find state.** A keeps triage's filters and replaces the chunk sentence with a family sentence of the same size; status is a rename. B leaves triage unchanged but keeps the chunk clause forever, since its files split retroactively. Neither design deletes the family read: legacy split devlogs need it (fixture 4), so the honest claim is "the chunk sentence is reworded", not deleted.
- **Single writer.** Both designs satisfy "never dispatch a writer against a path another live agent is writing". A's "one writer ever" is stronger than the rule needs; succession under the steer is fine.
- **~400K restart and handoffs.** Under the hybrid the outgoing agent writes its handoff beside the Scratchpoint and commits; the fresh agent continues the same sub-devlog if the concern is open, or starts the next one at a seam. No file is created just because a context ended.
- **Rule text.** A deletes the split *procedure* (closed-concern test, cut, merge floor, rewording moved text, ~330 words in the devlog skill) and keeps the data model (`part_of`, the index table, family reads). B deletes nothing. A's "Continuing in a new devlog" bullets plus the steer's softness come out shorter than the current split section. A wins on fewer formalisms, modestly.
- **Does A let the split machinery go?** The retroactive cut: yes. Triage's chunk logic: reworded, not removed. The moved-rows pointer line: only if forward table continuation is rare (see Open Question 1); under the proposal's counting both real histories would trip it, so the pointer line would be routine.

## Section-by-Section Findings

### BLUF and Summary

- **non-blocking:** "Each dispatched implementer writes its own sub-devlog" and the Summary table's "fresh implementer starts a new sub-devlog" row encode the per-implementer unit the steer withdraws; rewrite both around content seams.
- **non-blocking:** "triage's chunk special case becomes one family rule" is accurate; keep that phrasing and avoid implying the family read is deleted.

### Background

- **non-blocking:** "every root table empty with a 'Finished rows moved' line" is not quite true of the arc root: its Dispatch/Return table keeps one row and its Steering Log four (rows spanning two concerns or feeding p2). The point stands; the wording should match.

### Roles and files

- **blocking (with the steer):** the sub-devlog naming example (`-impl-1`), the mermaid diagram (`-impl-1`, `-impl-2`, "seeded from handoff"), and "a dispatched implementer's sub-devlog" tie the unit to agent identity. Name sub-devlogs by concern (`-phase1b`, `-phase2-fixes`, `-canary`), drawn as concern files with "writer: current implementer".
- **non-blocking:** "An `/oversee` arc devlog links its workstreams' top-level devlogs in its body and arc file, as today" is inaccurate: in the haiku arc, p0's iterate tables and p1's propose-revise rows lived in the arc devlog itself. Say the arc overseer starts a top-level per workstream (which is what the maintainer's "state per workstream" asks), so the change is visible to the implementer of `oversee/SKILL.md`.

### Who writes what

- **blocking:** "Every devlog has exactly one `## Scratchpoint`" conflicts with "Top-level: never closed while the workstream is live" plus "continues its tables in a forward sub-devlog": the lead then has two open devlogs, and the post-compaction rule ("the `wip` one's Scratchpoint is current") picks ambiguously. The same holds for a solo `/cdocs:implement` session continuing forward. One sentence fixes it: a writer keeps one live Scratchpoint per workstream; the lead's stays in the top-level, and a writer closes (or never opens a Scratchpoint in) any other devlog it continues forward.

### Continuing forward instead of splitting

- **blocking:** "When" lists phase end, restart, and rotation. A warm implementer looping on revise verdicts (iterate's "loop to Turn (N+1).a with the same implementer") hits none of these; haiku impl-1 ran eight iterations in one phase. The seam check must run at every return or handoff.
- **blocking (with the steer):** "and always when a fresh agent takes over a dispatched agent's work" is the clause the steer withdraws. Replace with content: start a new devlog when a new concern begins (a phase, a fix round, a verification campaign big enough to stand alone) or when the current one is past ~1,500 words at a seam; short concerns share a devlog.
- **non-blocking:** consider stating the trigger as "a seam plus size" in one sentence, as the old split rule did ("size prompts the look, never chooses the cut"). That phrase was the best part of the old rule and carries over intact.

### Restart and rotation

- **blocking (with the steer):** steps 2-3 ("a new sub-devlog path ... then starts its own sub-devlog") become: the overseer names the sub-devlog to continue (or a new one if the concern changed), the predecessor's handoff, the top-level path, the latest review, scope and floor; the fresh implementer reads the Scratchpoint and handoff and replaces the Scratchpoint.

### Lookup

- Sound. The highest-iteration rule handles both legacy chunks and any forward table continuation; Decision 6's justification (chunks copied the root's `first_authored`, verified in the chat-record family) is correct.
- **non-blocking:** iterate Turn 0 currently says "Prefer appending to the most recent devlog whose `task_list` matches"; under A that can select a sub-devlog. Phase 3 should say "the workstream's top-level (no `part_of`)".

### Changes by file

- Coverage is complete against my sweep of `plugins/cdocs` (rules, devlog, implement, implementer, iterate and template, full-send, propose-revise, oversee and template, judge, triage agent and skill, status).
- **non-blocking:** `skills/full-send/SKILL.md` line 15 ("each devlog it owns") already fits; it needs no edit, so the row can be narrowed to propose-revise if nothing else changes there.

### Important Design Decisions

- **blocking (with the steer):** Decision 2 ("One writer per devlog, ever ... a fresh file per fresh agent") must become "one writer at a time; a devlog's unit is a concern, not an agent". Decisions 1, 3-7 stand.

### Alternative Considered

- Fair, and its "Against" list holds up against the evidence. Its last bullet ("forward continuation ... needs an index, and the natural home for that index is the lead's devlog") is the decisive argument and is correct. Add one line noting the hybrid keeps B's strength (continuity of an open concern across implementers) inside A's structure.

### Edge Cases

- **non-blocking:** "the overseer marks the predecessor `done` in its Devlogs row and asks no edit of the dead file" leaves a `wip` file forever, which status and triage then report. A dead writer is not a live writer, so the successor (continuing the file) or the overseer may set its status; under the steer the successor usually just continues it.
- **non-blocking:** "Parallel implementers on disjoint footprints: one sub-devlog each" stays correct under the steer (parallel concerns are different content).

### Test Plan and Verification

- The floor matches the Brief's floor adapted to A, with transcript-level authorship checks: good.
- **non-blocking:** the stale-reference grep misses `skills/implement/SKILL.md:85` ("keeps one at the top of its own notes section"); add `top of its own` and `notes section` to the pattern list.
- **non-blocking:** fixture 4 names the real proposal but the fixtures run in a scratch repo, and the triage agent edits frontmatter; say "on copies of the chat-record proposal and devlog family in the scratch repo". Consider a fifth fixture from the haiku arc family (Iteration Log rows split 1-5 and 6-8 across two chunks, Judge Log escalate at 5 then a later row at 8), which exercises "highest iteration across the family" on real data.
- **non-blocking:** fixture 2 (forward tables) and the optional two-phase smoke ("checks that the second implementer starts `-impl-2` ... and that `-impl-1` is `done`") assume the per-implementer unit; under the steer the smoke should check one Scratchpoint per devlog and one writer at a time from transcripts, not a file count.

### Implementation Phases

- Executable and checkable as written, with explicit file lists and success criteria per phase.
- **non-blocking:** Phase 2 success "`grep -rni chunk plugins/cdocs` is empty" is right today (all hits are the split section, triage, status, frontmatter-spec), so it is a sound check.
- **non-blocking:** consuming projects' materialized rules (`.claude/rules/cdocs.md`, `AGENTS.md`) refresh through `/cdocs:init` and the freshness hook; one line in Phase 4 noting that `/cdocs:init` output changes would help the implementer avoid surprise.

### Note for the overseer (not the proposal)

The loop devlog's BLUF and Brief floor describe design B ("the workstream devlog becomes the implementers' devlog again", "a workstream devlog written by the implementer"). If A-hybrid is accepted, restate both so the implement loop's reviewers check against the chosen design.

## Open Questions: Recommended Answers

1. **Tables in the top-level or a `-loop` sub-devlog?** Top-level, no `-loop` file.
   Add one refinement: table rows do not count toward the top-level's ~1,500-word check (agents read their last rows, not the whole table), and continuing tables forward is a judgment call at a loop or phase boundary.
   Reason: counted the proposal's way, both real histories cross the trigger on tables alone (chat-record's tables total ~1,450 words for six iterations plus ~650 words of Brief and handoff), so table continuation and its pointer lines would be routine rather than rare.
2. **`## Devlogs` or `## Chunks`?** `## Devlogs`. The entries are live documents with their own writers, not pieces cut from the root; lookups key off `part_of`, so legacy `## Chunks` headings keep working.
3. **Reviewer devlog ownership?** No. A review document is already a single-writer artifact with a verdict, linked from the Iteration Log, and iterate requires empirical evidence to be cited in it. A reviewer devlog would duplicate it. The maintainer's "co-owner" intent is met by the review being the per-round record.
4. **Who starts the next sub-devlog?** Whoever is writing when the seam arrives. An implementer mid-dispatch closes and starts the successor itself and reports the path in its return; the overseer names a new one when it dispatches a new concern. The lead adds the `## Devlogs` row in both cases. This is a guideline, so no waiting round-trip is needed.

## Verdict

**Revise.**
The architecture is right and the evidence supports it; the per-implementer sub-devlog unit, the incomplete seam trigger, and the Scratchpoint contradiction must be fixed, and the 11:55 steer resolves the first.

## Action Items

1. [blocking] Fold in the 11:55 steer: sub-devlogs are content units (concern-named), short concerns share one, a large self-contained concern gets its own; a fresh or restarted implementer continues an open concern's devlog (one writer at a time). Update BLUF, Summary table, Roles naming and diagram, Who-writes-what, Decision 2, Restart steps 2-3, and Edge Cases.
2. [blocking] Make the seam and size check run at every return or handoff, not only phase ends, restarts, and rotations (warm implementer across revise iterations).
3. [blocking] Resolve "every devlog has exactly one Scratchpoint" against the never-closed top-level and forward continuation: one live Scratchpoint per writer per workstream, the lead's in the top-level.
4. [non-blocking] Adopt the Open Question 1 refinement: tables do not count toward the top-level check; table continuation is a loop- or phase-boundary judgment call.
5. [non-blocking] Iterate Turn 0: continue the workstream's top-level (no `part_of`), not "the most recent devlog whose `task_list` matches".
6. [non-blocking] Restart dispatch includes the top-level path, so a fresh implementer can use the `## Devlogs` "read this when" column.
7. [non-blocking] Add `top of its own` and `notes section` to the stale-reference grep.
8. [non-blocking] Run fixture 4 on copies in the scratch repo; consider a haiku-arc fixture; reshape fixture 2 and the two-phase smoke to check writer and Scratchpoint properties instead of a per-implementer file count.
9. [non-blocking] Correct the arc-devlog "as today" claim and the "every root table empty" Background line.
10. [non-blocking] Let a successor or the overseer set a dead writer's devlog to `done`.
11. [non-blocking] Resolve the four Open Questions in the body per the answers above and remove the section.

## Questions for the Maintainer

1. When a fresh implementer takes over an open concern, should it:
   a. continue the predecessor's sub-devlog, replacing its Scratchpoint (recommended; matches the steer and real history), or
   b. always start a new sub-devlog?
2. Should overseer tables count toward the top-level's ~1,500-word check?
   a. No: rows are scanned, not read; continuation is a judgment call at loop or phase boundaries (recommended).
   b. Yes, as proposed: tables continue forward in a sub-devlog whenever the top-level passes the trigger at a checkpoint.
3. For an `/oversee` arc, should each proposal's loop always get its own top-level devlog?
   a. Yes: the arc devlog holds only arc narrative and links (recommended; state per workstream).
   b. No: a single-proposal arc may run its loop in the arc devlog.
