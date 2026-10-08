---
review_of: cdocs/proposals/2026-09-17-browser-delegation-plugin.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T18:38:42-07:00
task_list: cdocs/browser-delegation
type: review
state: live
status: done
tags: [fresh_agent, iterate_integration, evidence_independence, report_contract, test_plan]
---

# Review (round 4): Browser Delegation Plugin

> BLUF: Revise, narrowly.
> All 13 round-3 items are addressed, and the repo and `@playwright/cli` README claims check out.
> Two blockers remain, both in the session-state contract the r3 fix leans on: nothing carries the fresh-session rule to an iterate reviewer at runtime, and `reopened` is defined in a way a stateless delegate cannot detect across dispatches, which the Session-reuse section and the Re-open test both rely on.
> Each is a one- or two-sentence fix.

## Summary Assessment

The proposal specifies a minimal, Claude Code-only, agent-only plugin: one sonnet leaf that drives `@playwright/cli` named sessions and returns a fixed, verdict-free report, with iterate's reviewer dispatching it so the artifacts count as its own.
The r3 revision is clean and history-agnostic, and it implements every settled maintainer decision.
The most important finding is that the r3 F1 fix (reviewer runs on fresh sessions) lives only in the proposal and the plugin README, neither of which an iterate reviewer reads when it dispatches the delegate, and its suffix-only option is not fresh across rounds.
Verdict: **Revise**, two small blocking edits plus non-blocking precision fixes.

## Round-3 Item Resolution

Each item was checked against the repo or the [`@playwright/cli` README](https://github.com/microsoft/playwright-cli), not the proposal's own description.

| r3 item | Status | Evidence |
|---|---|---|
| 1. F1 reviewer reuses implementer session | Resolved in design, incomplete in delivery | "Iterate integration" requires fresh sessions and `opened`, and the Edge Case, Test Plan, and Phase 3 success criterion echo it. The rule has no runtime carrier, and the suffix option collides across rounds (B1). |
| 2. F2 `cdocs/_media/` durability | Resolved | Option A as settled: scratch path cited, `Facts` and `AE score` lines inlined, "`reviewer.md` needs no change". Matches `iterate/SKILL.md:91` ("inlining excerpts for ephemeral artifacts") and `reviewer.md:57-59`. |
| 3. F4 CLI working-tree writes | Resolved | `cd "$d"` for every CLI command, `--filename=$out/<name>`, a Worktree-hygiene test, and a Phase 1 workspace-scoping check. README confirms `.playwright-cli/page-*.yml` auto-snapshots and `.playwright/cli.config.json` cwd lookup. One side effect on project config (N3). |
| 4. F5 polling vs `maxTurns` | Resolved | One bounded Bash loop. Bash tool timeout not mentioned (N5). |
| 5. F6 ImageMagick and multi-artifact AE | Resolved | `compare` checked only with a baseline, size mismatch reported as a fact. Scoped to one baseline/candidate pair rather than one line per artifact, which is the simpler choice and is consistent across the description, workflow, report, example, and Test Plan. |
| 6. F7 depth overgeneralization | Resolved | "Under a nested overseer, any wrapper agent ... pushes the delegate past the limit". |
| 7. F8 spike gating language | Resolved | BLUF, D2 heading, D2 point 3, Phase 1/2 dependencies, and Assumptions all agree. Phase 1 heading omits CLI resolution (N6). |
| 8. F9 `--headless` flag | Resolved | `playwright-cli open <url>` (headless by default), per README "Headed operation". |
| 9. F10 project-local CLI | Resolved | Phase 1 item, absolute resolution before the `cd`, folded into the availability check. Missing-CLI test not updated to match (N2). |
| 10. F11 D2 point 2 nuance | Resolved | Led by "The lead is not invited to drive", with the deferred-tools caveat. |
| 11. F12 idle timeout | Resolved | In-memory profiles, one-hour headless idle shutdown, `--idle-timeout=<ms>`, `--persistent` excluded: all match the README "Sessions" section. Introduces the `reopened` ambiguity (B2). |
| 12. F13 missing tests | Resolved | Baseline-diff, Re-open-path, and fresh-session iterate tests added, and Phase 2 success includes an `AE score`. |
| 13. F3 Turn N.b placement (optional) | Resolved by rationale | `iterate/SKILL.md:92` says "This citation is what makes a `confirmed` row admissible", so the row (`:132`) is the right home and Turn N.b already points to it. |

## Section-by-Section Findings

### Iterate integration and the agent description

**B1 [blocking] The fresh-session rule has no runtime carrier, and the suffix option is not fresh across rounds.**
An iterate reviewer learns how to dispatch the delegate from the agent description in its Agent tool listing (D7 calls the description "a sufficient dispatch contract").
It does not read the plugin README or this proposal, and the Phase 3 `confirmed` clause only says a reviewer-dispatched subagent's artifact counts.
The description's only session guidance is "names default to `<sanitized-branch>-<role>`", which is exactly the default that lands the reviewer in the implementer's live browser.
So a reviewer following its contract gets `reused`, does not know that disqualifies the evidence, and the overseer (which also never sees the rule) records `confirmed`: r3 F1's harm, unchanged at runtime.
Separately, the first of the two offered remedies, naming sessions `<branch>-review-<role>`, is not fresh in round 2+: the previous round's reviewer session has that same name and survives up to an hour idle, so the report says `reused`.
Fix:
- Make freshness a dispatch option in the description's "Prompt with:" list (e.g. "Optional: fresh sessions (close any live session of that name before opening), for independent verification; the report then shows `opened`").
  The `opened` definition already anticipates this ("one the delegate closed first because the prompt asked"), but no prompt field exists to ask.
- In "Iterate integration", make close-then-open the rule (the suffix stays useful for not disturbing the implementer's session, but is not sufficient alone).

### Report format: session-state vocabulary

**B2 [blocking] `reopened` is not detectable across dispatches as used.**
The definition reads: `opened` is fresh, `reused` is a live session found, `reopened` is "one that died mid-flow and came back empty".
Two other sections expect `reopened` at a dispatch boundary:
- "Session reuse across turns": "a dispatch past that window gets a `reopened` session".
- Test Plan "Re-open path": "`playwright-cli -s=<name> close`, then re-dispatch on that name: the report lists the session as `reopened`".

A fresh delegate is stateless, so at dispatch start "this name existed before and died" and "this name never existed" look identical unless `playwright-cli list` reports closed in-memory sessions, which the README does not say and Phase 1 does not check.
The implementer cannot satisfy the definition, the Session-reuse sentence, and the Re-open test together, and the ambiguity sits next to the `opened` check that iterate's proof depends on.
Fix (pick one and apply it to the definition, Session reuse, Edge Cases, and the Re-open test):
- **Observable-state definition (minimal):** `opened` means no live session at dispatch start (or closed on request), `reused` means live at dispatch start, `reopened` means it died during this dispatch.
  A dispatcher that expected continuity reads `opened` as state loss.
  The Re-open test then either kills the session during a dispatch (e.g. `kill-all` from another shell during a `wait-for`) expecting `reopened`, or closes between dispatches expecting `opened`.
- **Expectation field:** the prompt may mark a session "resume", and the delegate reports `reopened` when a resume session is not live.
  This adds a field, so it is less minimal.

### The agent

**N1 [non-blocking] Prompt-supplied relative paths after `cd "$d"`.**
The example's baseline is repo-relative (`cdocs/_media/2026-09-10-settings-mock.png`), the report requires `<baseline abs path>`, and the workflow `cd`s away from the dispatcher's worktree.
Say: resolve the baseline (and any prompt-supplied path) to an absolute path against the starting cwd before the `cd`, alongside the CLI resolution.

**N2 [non-blocking] Missing-CLI test and edge case assume the global CLI.**
If Phase 1 prefers the project-local CLI, removing `playwright-cli` from `PATH` in weftwise would not produce `FAILED`.
Word the Test Plan item and the Edge Case as "neither the global nor the project-local CLI resolves".

**N3 [non-blocking] `cd "$d"` also drops the project's CLI config.**
Running from `$d` keeps `.playwright/cli.config.json` lookup out of the worktree, which is intended, but a project may rely on that config for its pinned browser (`channel`, `executablePath`), which is the point of Phase 1's CLI-resolution item.
Add to that Phase 1 item: whether the project config is needed, and if so pass it with `--config <abs path>`.

**N4 [non-blocking] `compare` exit codes.**
`compare -metric AE` exits 1 when images differ and 2 on error, and prints the metric to stderr.
One clause in the workflow ("exit 1 is a difference, not a failure") stops a sonnet delegate from reporting `FAILED` on a normal diff.

**N5 [non-blocking] Bash tool timeout for the poll loop.**
The Bash tool defaults to a 120s timeout (600s max), so a convergence timeout above that needs an explicit Bash `timeout`, as `bash-runner.md` already says for long commands.

### Phases and open questions

**N6 [non-blocking] Phase 1 heading omits CLI resolution.**
"Gate README guidance and session naming only" vs its own "Depends on" ("README pinning wording, CLI resolution, and (if isolation fails) session naming"), which is also the agent body.
Align the heading.

**N7 [non-blocking] "Committed evidence (maintainer)" is settled, not open.**
The maintainer chose option A, and the proposal implements it.
Move the `cdocs/_media/` + `reviewer.md` idea to Phase 5 (deferred) so Open Questions holds only open questions.

### Framing and conventions

History-agnostic throughout: no "previously/now/revised/no longer" in the body.
Sentence-per-line, Mermaid, linked external references, colon-over-em-dash, and NOTE/WARN callouts follow the conventions.
All relative links resolve.
The file table matches Phases 2 and 3.
BLUF matches the body.
Settled maintainer decisions are all implemented: minimal design, no R1-R6 dependency (Phase 5 only, independent), agent-only bash-runner shape with no skills or rules files, Claude Code-only, sonnet driving with the pluggable-model question open, one delegate driving N sessions, the one-clause iterate edit, and option A for durable screenshots.

## Verdict

**Revise.**
B1 and B2 are each a one- or two-sentence edit (B1: one description line plus the Iterate-integration remedy; B2: one definition plus aligning Session reuse and the Re-open test).
No r3 item regressed, and no design-level rework is needed.
A round 5 can be a targeted check of B1, B2, and the non-blocking list.

## Action Items

1. [blocking] B1: Add a fresh-sessions option to the agent description's "Prompt with:" list (close any live session of that name before opening, so the report shows `opened`), and make close-then-open the iterate reviewer's rule in "Iterate integration" (the `-review-` suffix alone is `reused` in round 2+).
2. [blocking] B2: Define `opened`/`reused`/`reopened` by state observable within one dispatch (or add a "resume" expectation field), then align "Session reuse across turns", the killed-session Edge Case, and the Test Plan "Re-open path" to it.
3. [non-blocking] N1: Resolve prompt-supplied paths (baseline) to absolute before `cd "$d"`.
4. [non-blocking] N2: Reword the Missing-CLI test and edge case as "neither global nor project-local CLI resolves".
5. [non-blocking] N3: Add to Phase 1's CLI-resolution item whether the project's `.playwright/cli.config.json` is needed, passed via `--config <abs path>` if so.
6. [non-blocking] N4: Note that `compare` exit 1 means "images differ", not failure.
7. [non-blocking] N5: Have the poll loop's Bash call set `timeout` above the convergence timeout.
8. [non-blocking] N6: Add CLI resolution to the Phase 1 heading's gating list.
9. [non-blocking] N7: Move "Committed evidence" from Open Questions to Phase 5.

## Questions for the Maintainer

**Q1. How should the report signal lost session state across dispatches?** (governs action item 2)
- **A (recommended):** Observable state only. `opened`/`reused` describe the session at dispatch start and `reopened` means it died during this dispatch; a dispatcher expecting continuity treats `opened` as state loss. No new prompt field.
- **B:** Add a per-session "resume" expectation to the prompt, and the delegate reports `reopened` when a resume session is not live. Clearer report, one more field.
