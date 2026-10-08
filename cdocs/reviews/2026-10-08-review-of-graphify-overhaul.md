---
review_of: cdocs/proposals/2026-10-08-graphify-overhaul.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T09:01:00-07:00
task_list: cdocs/graphify-overhaul
type: review
state: live
status: done
tags: [fresh_agent, architecture, history_check, shared_state, test_plan, recall_parity]
---

# Review: Graphify overhaul (seed query run by fresh contexts)

> BLUF: Revise.
> The history supports the premise: the shipped brief bleeds into the overseer, reduces the graph to a file union, and in its target environment skips every round as a stale index.
> Two problems block acceptance.
> D6 has every fresh agent run `graphify update .` against an index that all worktrees share, which breaks one-writer-per-file, the reviewer's read-only Bash boundary, and the premise the lace proposal used to accept a shared index.
> The proposal also says the old CRDT guard "survives", but what it keeps is the bare caveat that the guard was built to replace.
> The verification marker check can also pass without testing anything, because it reads the wrong transcript.

## Summary Assessment

The proposal removes `graphify-scope` and the reviewer brief.
In their place, the overseer writes a natural-language `graphify_query`, and each fresh implementer or reviewer runs it through a thin `/cdocs:code-query` skill.
It is well organized and honest that neither design has been measured, and its deletion list matches the repo exactly (checked by grep).
A sonnet sweep of the graphify cdocs history confirms the maintainer's premise and adds one stronger point the proposal understates (F1).
It also shows two real things the old design did that this one drops: one place that checks index freshness without writing to it, and a structural runtime-coupling guard that a prior review asked for (F2, F3).
Verdict: **Revise**. The fixes are small, guideline-sized edits that fit the maintainer's preference for minimal designs.

## Premise check against history

> NOTE(claude-opus-5-5/cdocs/graphify-overhaul/review): History sources are `cdocs/proposals/2026-09-17-graphify-cdocs-integration.md`, its four reviews, `cdocs/devlogs/2026-09-23-graphify-cdocs-integration-full-send.md`, the MCP-vs-CLI report, the lace proposal, and `plugins/cdocs/bin/graphify-scope`.

- **"Bleeds into the overseer": confirmed.** Iterate says the overseer "pastes the brief VERBATIM" (`iterate/SKILL.md:52`), so the overseer holds the script's full stdout in its own context.
- **"Flattens subtlety": confirmed.** The pipeline is `explain` per file, then `affected` per symbol, then a union of paths, with `explain` cut off at about 20 connections (`graphify-scope:119`).
  The design text listed `query`/`path` as part of the surface (full-send devlog:113), but the shipped script never calls them.
- **Why it was built that way.** The maintainer asked for "prime-context + instruct-agents" (full-send devlog:111), and the design read "prime" as the overseer priming the reviewer.
  It was limited to reviewers as a deliberate first increment ("implementer and judge are out of scope for this increment"), not because implementers were judged a poor fit.
  The `explain`+`affected` pipeline was not chosen over `query`.
  It came from reconciling the CLI contract after the first `--json` assumption failed against real 0.9.61 (full-send devlog:140-151).
  No design alternative was weighed against it.
- **Evidence.** No efficiency or recall A/B was ever run for either design (full-send devlog:210-218).
  The only ablate data point is Probe A (`context_gap 0`, single file).
  The proposal's NOTE describes this correctly.

## Section-by-Section Findings

### F1 [non-blocking] Background / D6: the old design was a no-op every round, not just "after the first commit"

`graphify-scope:251-254` skips with `stale-index` when **any changed file** is newer than the index.
A review round's changed files were edited during that round, and nothing rebuilds the index (lace D5: no hook).
So the brief skips scope on every round in the lace container unless someone rebuilt the index by hand after the implementer finished.
This is the strongest point for the overhaul and belongs in the Summary, stated precisely: the shipped feature has never been able to produce a scoped brief on its own in the one environment that has graphify.

### F2 [blocking] D6 / Freshness: every fresh agent writes to a shared index

The skill tells every consumer (reviewers included) to run `graphify update .` when the index predates `HEAD`.
That conflicts with four established constraints:

1. **"CDocs Tool Use Guidance › One writer per file".** Under iterate, the implementer and reviewer (and under `oversee`, several workstreams) can write the same `/var/cache/graphify/graph.json` at once.
   The proposal's WARN leaves it to the overseer to say "do not refresh" under parallel dispatch, which means the overseer has to remember to switch it off.
2. **Lace D3's premise.** Lace accepted one shared index across worktrees *because* "the loop-layer proposal already mandates skip-scope on a stale index", and it notes that "`graphify update` overwrites rather than namespaces."
   D6 reverses that premise: an agent in worktree A rebuilds the shared index from A's tree.
   An agent in worktree B then sees an index newer than its own `HEAD`, takes it as fresh, and queries A's branch.
   Phase 4's one-line NOTE on lace D3 understates this. D6 removes the reason lace accepted the risk.
3. **Reviewer boundary.** `reviewer.md:51` allows Bash only for "read-only inspection and empirical verification."
   Rewriting a shared cache is a mutation, close to codegen, and a fresh reviewer has no business doing it.
4. **Cost/scope.** The graphify README says docs and markdown are extracted by an LLM, and only code is AST-only.
   Every cdocs round changes markdown (devlogs, reviews), so the mtime-vs-`HEAD` test fires at nearly every startup.
   Whether `update .` then calls an LLM, fails, or skips the markdown is unverified.
   The test can also re-fire every time if `update` leaves `graph.json` untouched when no code changed.

The fix stays minimal and keeps D6's own reasoning that a stale index still orients:
- Fresh agents never run `update`; they query whatever index exists and check specific edges against the code (D6's own fallback).
- Exactly one actor refreshes, and only when the overseer's prompt allows it.
  The cleanest option is the overseer running `graphify update <code-paths> >/dev/null 2>&1` once at Turn 0 (and optionally before each review).
  That is a write with no graph output in it, so it does not contradict D1.
  Alternatively, only the single-agent `/cdocs:implement` refreshes.
- Restrict the refresh to code paths, or confirm in Phase 1 that `update` never calls an LLM.
- Replace Phase 4's lace NOTE with an accurate one: who refreshes, and why the shared-index risk is still acceptable.

### F3 [blocking] D5 / Phase 4: the CRDT guard does not "survive"; it reverts to the weakest form

The 2026-09-17 review's F4 called the caveat-only CRDT guard "the weakest possible enforcement."
The prior proposal's D3 then made it structural: the brief always showed nearby `.observe`/`.subscribe` sites, and a near-empty set on such files forced an unscoped sweep (`graphify-scope:290-299`).
That is a real reason the old design existed.
This proposal's skill line ("its silence never proves nothing depends on a thing") is exactly the bare caveat F4 rejected.
Phase 4 then describes it as the guard surviving.

The overhaul does not need the machinery back. It needs the caveat turned into an action, which is still a guideline:
- In the skill's "By role" reviewer bullet, or right after the static-structure sentence, add something like: "Before concluding a change is contained, grep the changed code for the project's runtime-coupling idioms (observers, subscriptions, event emitters, registries); the graph cannot see them."
- Reword Phase 4's NOTE to say what is kept (an instruction to grep for runtime coupling) and what is dropped (the forced fallback when a near-empty set touches observer sites), so weftwise readers can see the tradeoff.

### F4 [blocking] Verification step 4: the overseer-cleanliness check can pass without testing anything

Step 3 has the Phase 5 executor "as overseer" dispatch a reviewer.
Inside an iterate loop that executor is the implementer *subagent*.
Its transcript is `~/.claude/projects/<slug>/<session_id>/subagents/agent-<id>.jsonl`.
It is not the top-level `<session_id>.jsonl` named in step 4 (this host stores subagent transcripts separately; the top-level file has no sidechain entries).
Grepping the top-level file returns `GFY-MARKER` = 0 and `unused` whether or not anything bled.
Fixes:
- Name the transcript as "the transcript of the agent that issued the `Agent` dispatch" and say how to find it: the newest `subagents/agent-*.jsonl` whose Agent `tool_use` prompt contains the seed query.
- Add a positive control: that transcript must contain the reviewer's returned report (the Agent `tool_result`).
  Without that, a zero marker count proves nothing.
- Have the stub put the marker inside **every** output line, node labels included.
  The skill allows "file paths" in reports, so a pasted node line would otherwise get through without the marker.

### F5 [non-blocking] Verification covers one reviewer dispatch, not the loop

The host run never exercises how an overseer writes the Turn-0 query from a proposal, an implementer's refinement, or the overseer adopting it.
That is acceptable for the host stub.
The devcontainer live run should be a small real `/cdocs:iterate` (one round) rather than a repeat of steps 3-4, so the refinement path and the overseer-transcript check are tested on the actual loop.
Two minor points:
- `detect-usage`'s `cli:^graphify (query|explain|path)` misses env-prefixed calls (`GRAPHIFY_OUT=… graphify query`). The stub argv log should be the primary signal and `detect-usage` the secondary one.
- A stub in `~/.local/bin` is visible to every concurrent session on the host. Time-box it and remove it on exit (a `trap`), and say so.

### F6 [non-blocking] Seed query lifecycle: "the overseer already reads the Scratchpoint" is not true

The iterate overseer reads its **own** Scratchpoint (`iterate/SKILL.md:74,111`), not implementers' sub-devlog Scratchpoints.
The simpler channel is for the implementer to put its refined `graphify_query` in its return report (one line), which the overseer already reads.
Keeping it in the sub-devlog Scratchpoint as well is fine for resumes.

### F7 [non-blocking] D2: the skill earns its place, but it repeats the role duties three times

Skill versus rule line alone: the skill is justified.
Availability/no-op handling, the static-structure action (F3), and "no raw output in reports" are procedure.
In the rule file, that procedure would load into every consuming project, including those without graphify.
A skill costs one description line.
But the overseer duty ("only write the query") appears in the rule line, in the skill's "By role", and in iterate's "Seed query".
The proposal's own D5 rejects a third copy for agent files.
Drop the skill's overseer bullet, since overseers never load the skill under D1.
Also consider moving "overseers pass `graphify_query` in dispatch prompts to agents that read code" into the rule line.
That covers propose-revise, full-send, and oversee as well as iterate, and settles Open Question 1 with no extra skill text.
The iterate section would then shrink to the Turn-0 write and the adopt step.

### F8 [non-blocking] CLI surface claims

Checked against [graphify CLI reference](https://graphify.net/graphify-cli-commands.html), the [v8 README](https://github.com/Graphify-Labs/graphify/blob/v8/README.md), and the [v8 `skill.md`](https://github.com/Graphify-Labs/graphify/blob/v8/graphify/skill.md):
- `query --budget/--dfs/--graph`, `explain`, and `path` are confirmed.
- `affected` is absent from the public docs, as the proposal says.
- `graphify update <path>` is in the README ("re-extract only changed files"). The CLI page shows only `/graphify --update`, so Phase 1 should confirm the CLI form on 0.9.61.
- The README says rebuilds are serialized against concurrent writes. Cite that in the Edge Cases WARN instead of calling it unverified (it does not fix F2's cross-worktree overwrite).
- `skill.md` is 723 lines, and its query fast path is a short block ("Run `graphify query` immediately…"). D3's characterization holds.
- `graphify claude install` installs PreToolUse hooks that steer toward `graphify query` before file reads, which supports D3's concern about overseer reach.
- D3's claim that the lace feature installs neither the skill nor the hook is stated, not verified. Fold it into Phase 1's checks.

### F9 [non-blocking] Auditability lost

The old `SCOPE-STATUS` labels in the Iteration Log let anyone tell scoped rounds from fallback rounds.
The new design records nothing, which weakens the follow-up ablate in Open Question 2.
A cheap replacement is an Iteration Log `notes` tag `[seed: <set|empty>]`, written by the overseer from what it already knows.

### Test Plan

- `npm run test:rules` passes on the current tree (11/11).
- The proposed rule line, skill draft, and devlog paragraph contain no rule-file names or `›` references, so they cannot break `check-rule-refs`.
- `build:cdocs` copies `skills/` wholesale, and the OpenCode test enumerates no skill list, so the `code-query/SKILL.md` existence check is sound.
- The removal grep scope (`plugins/ .github/ CLAUDE.md scripts/`) correctly excludes `cdocs/` history.

## Verdict

**Revise.**
Resolve F2 (a single actor refreshes the shared index, and reviewers stay read-only), F3 (turn the static-structure caveat into a runtime-coupling grep instruction, and describe the Phase 4 change accurately), and F4 (point the transcript check at the right file and add a positive control).
The rest of the design (delete outright, the overseer holds only a string, fresh contexts query, a thin skill, no use of graphify's own skill) holds up and should not be reopened.

## Action Items

1. [blocking] D6, skill "Freshness", Edge Cases: remove `graphify update` from fresh agents. Name one refresher (preferably the overseer, once at Turn 0, output discarded, code paths only), and have consumers query the existing index and check specific edges.
2. [blocking] Phase 4: replace the lace D3 NOTE with an accurate statement of who writes the shared index and why cross-worktree staleness is still acceptable.
3. [blocking] Skill draft: add a one-line instruction to grep changed code for runtime-coupling idioms before concluding a change is contained. Reword Phase 4's NOTE to name what is kept and what is dropped from the old D3 guard.
4. [blocking] Verification step 4: check the transcript of the dispatching agent (`subagents/agent-<id>.jsonl` under iterate), add a positive control that the reviewer's report is present, and put the marker on every stub output line.
5. [non-blocking] Summary/D6: say that the shipped brief skips every round as `stale-index` in the lace container (`graphify-scope:251-254`).
6. [non-blocking] Lifecycle: the implementer returns its refined `graphify_query` in its report; drop the "already reads the Scratchpoint" claim.
7. [non-blocking] Skill: drop the overseer "By role" bullet. Consider moving "pass `graphify_query` in code-reading dispatches" into the rule line so it covers all overseer skills, which answers Open Question 1.
8. [non-blocking] Devcontainer live run: make it a one-round `/cdocs:iterate`. Use the stub argv log as the primary signal, and trap-remove the host stub.
9. [non-blocking] Phase 1: confirm `graphify update` CLI form and its LLM behavior on markdown, and whether the lace feature installs `/graphify` or the hook-guard. Cite the README's serialized-rebuild claim in Edge Cases.
10. [non-blocking] Add an Iteration Log `[seed: set|empty]` tag to keep round-level auditability.

## Questions for the maintainer

1. Who refreshes the shared index?
   (a) the overseer, once per round, output discarded (recommended);
   (b) the implementer only, never reviewers;
   (c) nobody: operators run `graphify update` by hand, and agents treat the index as orientation only.
2. How far back should the runtime-coupling guard come?
   (a) a one-line grep instruction in the skill (recommended);
   (b) that line plus a reviewer-only "list the observer sites you checked" line in the review;
   (c) caveat only, accepting the weftwise recall risk explicitly in a WARN.
3. How far should seed-query passing reach?
   (a) every overseer passes it to any agent that reads code, via the rule line (recommended);
   (b) iterate implementers and reviewers only, as proposed.
