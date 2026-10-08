---
review_of: cdocs/proposals/2026-09-17-browser-delegation-plugin.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T18:42:06-07:00
task_list: cdocs/browser-delegation
type: review
state: live
status: done
tags: [fresh_agent, session_state_contract, iterate_integration, evidence_independence, test_plan]
---

# Review (round 5): Browser Delegation Plugin

> BLUF: Accept.
> Both r4 blockers are resolved: the fresh-sessions option sits in the agent description that every dispatcher sees, and `opened`/`reused`/`reopened` are now defined by what one dispatch can observe, consistently across all eight places that use them.
> All seven r4 non-blocking items are addressed, and the repo and `@playwright/cli` README claims check out.
> Six non-blocking precision nits remain, and none of them can produce a false `confirmed`.

## Summary Assessment

The proposal specifies a minimal, Claude Code-only, agent-only plugin: one sonnet leaf that drives `@playwright/cli` named sessions and returns a fixed report with no verdict, and iterate's reviewer dispatches it so its artifacts count as the reviewer's own.
The r4 revision (b26403b) is narrow and clean.
The fresh-session rule now reaches the reviewer at runtime through the description line, and the session-state vocabulary is something a stateless delegate can actually implement.
The remaining findings are wording and spike-scope refinements: the main ones are making the `Sessions` line part of the inlined evidence and adding a Phase 1 check on how the CLI behaves against a non-live session name.
Verdict: **Accept**.

## Round-4 Item Resolution

Each item was checked against the revised text, the repo, and the [`@playwright/cli` README](https://github.com/microsoft/playwright-cli).

| r4 item | Status | Evidence |
|---|---|---|
| 1. B1: no runtime carrier for fresh sessions | Resolved | The description's "Prompt with:" list has "Optional: fresh sessions (close any live session of that name, then open), required for independent verification such as an iterate review" (line 124). "Iterate integration" makes close-then-open the reviewer's rule (line 183) and names the description as the runtime carrier (line 187). The round-2+ collision of a reviewer-suffixed name is called out (line 186). |
| 2. B2: `reopened` not detectable across dispatches | Resolved (option A, observable state) | The definition is scoped to one dispatch (line 173). Session naming (143), Session reuse (224), the Edge Case (313-314), and the Test Plan "Session states" item (328-330) all agree: death between dispatches gives `opened`, and death during a dispatch gives `reopened`. |
| 3. N1: relative paths after `cd` | Resolved | Line 134. |
| 4. N2: Missing-CLI wording | Resolved | Edge Case (310) and Test Plan (334). |
| 5. N3: project CLI config | Resolved | Phase 1 CLI-resolution item (353), `--config <abs path>`, matching the README ("`playwright-cli --config path/to/config.json`"). |
| 6. N4: `compare` exit 1 | Resolved | Line 138. |
| 7. N5: Bash timeout for the poll loop | Resolved | Line 147, consistent with `bash-runner.md:29`. A cap case remains (N4 below). |
| 8. N6: Phase 1 heading | Resolved | Line 347 matches the "Depends on" at 359. |
| 9. N7: "Committed evidence" | Resolved | Moved to Phase 5 (390), removed from Open Questions. |

## Repo and Upstream Fact Check

- `iterate/SKILL.md:91-92`: Turn N.b requires the reviewer to re-run the floor and cite an artifact path, "inlining excerpts for ephemeral artifacts", and says "This citation is what makes a `confirmed` row admissible." `:132` defines `confirmed` as "cited an artifact it produced". The proposal's Phase 3 clause targets the right row.
- `iterate/SKILL.md` Turn N.a precedes N.b sequentially, and a Revise resumes "the same implementer" at (N+1).a. This supports "The implementer has reported done before Turn N.b", but see N2 below on round N+1.
- `bash-runner.md`: the `${TMPDIR:-/tmp}/claude-$(id -u)` scratch path, `tools: Bash`, the "Prompt with:" description, "Don't read rules files", and "set the Bash tool `timeout` up to 600000" all match what the proposal claims to mirror.
- `reviewer.md`: `tools: "*"`, so the reviewer can dispatch the delegate with no change, as Phase 3's constraint states.
- `@playwright/cli` README: `-s=<name>`, `PLAYWRIGHT_CLI_SESSION`, `list` ("shows all active sessions"), `-s=name close`, `close-all`, `kill-all` ("forcefully terminates all browser processes"), in-memory profiles, `--persistent`, the one-hour headless idle shutdown, `open --idle-timeout=<ms>`, headless-by-default `open`, `--filename`, `eval`, `.playwright-cli/` auto-snapshots, `.playwright/cli.config.json` lookup with `--config`, and the `show` dashboard all match.
  The README says sessions are "managed at the user level across the system", which supports Phase 1's scoping check.
  The README does not say what a command does when it targets a session name that is not live (see N1).
- All relative links resolve.

## Section-by-Section Findings

### Session-state contract (consistency sweep)

Eight places use the states: the description (124), Workflow (138), Session naming (143), the Report definition (173-174), Iterate integration (183-187), Session reuse (224), Edge Cases (313-317), and Test Plan / Phases (328-332, 364-373).
They agree, and the fresh-sessions option is named the same way in every one.
`opened` covering both "nothing live at start" and "closed first on request" is coherent, because both mean empty state at the moment the actions begin.

**N1 [non-blocking] Detecting liveness and mid-dispatch death is unspecified, and the README is silent on it.**
The workflow says "Open or reuse each named session" but does not say how the delegate decides between `opened` and `reused` (presumably `playwright-cli list` at dispatch start, which the README says shows active sessions).
`reopened` depends on noticing that a session died mid-dispatch.
If a CLI command against a dead name silently auto-opens a new browser rather than erroring, the delegate cannot see the death and reports `opened`/`reused` for a session that lost its state partway through.
This cannot produce a false `confirmed`, because a reviewer's sessions start empty anyway and a mid-flow death would surface as failed actions, but it can mislead a dispatcher that relies on `reused` meaning continuity.
Fix: add one Phase 1 spike line ("record whether a command against a non-live session name errors or auto-opens, and how `list` reports it"), and state in the Workflow that liveness at dispatch start comes from `playwright-cli list`.

### Iterate integration

**N2 [non-blocking] "Closing its session disturbs nothing" understates the effect on round N+1.**
With default names, the reviewer's delegate closes `<branch>-<role>` and opens its own under the same name, and that session stays live.
After a Revise, the resumed implementer's next delegate dispatch (without the option) gets `reused` and lands in the reviewer's browser state, believing it is its own continued session.
This does not affect `confirmed`, since the next reviewer closes it again and implementer artifacts never count, but it does undercut the implementer's self-verification.
Fix (one clause): have the reviewer also use a review role suffix (`<branch>-review-<role>`) together with the fresh-sessions option, so the two roles never share a name in either direction.
Alternatively, reword the sentence to "closing its session costs the implementer only continuity, which its next report shows".

**N3 [non-blocking] The `Sessions` line is not part of the inlined evidence, so the `opened` requirement cannot be audited.**
Line 189 has the reviewer inline "the report's `Facts` and `AE score` lines".
The requirement "Its report must list each session as `opened`" (185) is then visible only to the reviewer, and the overseer recording `confirmed`, or a later reader, cannot check it once the scratch file is gone.
Fix: inline the `Sessions`, `Facts`, and `AE score` lines.
This stays within the settled "scratch path plus quoted report facts" decision and needs no `reviewer.md` change.

### The agent

**N4 [non-blocking] A convergence timeout above the Bash tool maximum has no defined behavior.**
Line 147 has the poll's Bash call set `timeout` above the convergence timeout, but the tool caps at 600000 ms.
A dispatcher asking for a 15-minute convergence would get a killed Bash call, not a divergence report.
Fix: "cap the convergence timeout below 600s, and report the cap as a fact if the prompt asked for more".
While there, write both limits in one unit ("120s default, 600s maximum").

**N5 [non-blocking] "Fresh delegate" collides with the "fresh sessions" option.**
Session reuse says "a fresh delegate dispatch resumes the same browser by name" (221) and "dispatches a fresh delegate on the same session names" (223).
Here "fresh" means a new agent instance that deliberately does *not* use the fresh-sessions option, which is the opposite of what the term means on line 124.
A sonnet implementer drafting the README could conflate the two.
Fix: say "a new delegate" in both places.

### Test Plan

**N6 [non-blocking] `kill-all` in the Session-states test is system-wide.**
The README describes `kill-all` as forcefully terminating "all browser processes", with sessions managed "at the user level across the system".
Running it from another shell kills every agent's sessions on the host, including other worktrees' sessions.
Fix: use `playwright-cli -s=<name> close` from another shell during the `wait-for`, or note that the test runs on an otherwise idle host.

### Internal consistency and framing

- The BLUF matches the body, and the summary's five commitments match the design sections.
- The file table matches Phases 2 and 3 (the README row and the Phase 2 README bullet both name the fresh-sessions option).
- The Phase 1 heading, its "Depends on", and Phase 2's "Depends on" agree.
- The framing is history-agnostic: there are no "previously/now/no longer/revised" phrasings, and the only `--` occurrences are Mermaid edge syntax.
- Sentence-per-line formatting, Mermaid diagrams, linked external references, and the NOTE/WARN callouts follow the conventions.
- The settled maintainer decisions are all implemented:
  - a minimal design;
  - no R1-R6 dependency (Phase 5, independent);
  - an agent-only plugin in the bash-runner shape, with no skills or rules files;
  - Claude Code-only, with no OpenCode dependency (Phase 2 constraint);
  - sonnet driving, with the pluggable-model question left open;
  - one delegate driving N sessions by default;
  - the one-clause iterate `confirmed` edit;
  - scratch path plus quoted facts, with no `reviewer.md` change;
  - observable-only session states, with no resume field.
- The revision introduced no regressions.

## Verdict

**Accept.**
The two r4 blockers are fixed at the right layer, and the contract is consistent everywhere it appears.
N1-N6 are one-clause precision edits that the overseer can apply without another review round.

## Action Items

1. [non-blocking] N1: Add a Phase 1 spike line recording whether a CLI command against a non-live session name errors or auto-opens, and how `list` reports it. State in the Workflow that liveness at dispatch start comes from `playwright-cli list`.
2. [non-blocking] N2: In "Iterate integration", pair the fresh-sessions option with a reviewer role suffix (`<branch>-review-<role>`) so implementer and reviewer never share a name, or reword "disturbs nothing" to admit the implementer loses continuity.
3. [non-blocking] N3: Have the reviewer inline the report's `Sessions` line along with `Facts` and `AE score` (line 189), so the `opened` requirement can be audited.
4. [non-blocking] N4: Cap the convergence timeout below the 600s Bash maximum and report the cap as a fact; state both limits in one unit.
5. [non-blocking] N5: Replace "fresh delegate" with "new delegate" in Session reuse (lines 221, 223).
6. [non-blocking] N6: In the Session-states test, replace `kill-all` with `-s=<name> close` from another shell, or note that the host must otherwise be idle.

## Questions for the Maintainer

None of the items above needs a maintainer decision.
N2 has two acceptable fixes, and the overseer can choose:

**Q1. How should the reviewer's sessions be kept apart from the implementer's?** (action item 2)
- **A (recommended):** Fresh-sessions option plus a `review` role suffix: the roles stay isolated in both directions, at the cost of one more naming convention in the README.
- **B:** Fresh-sessions option alone, with the wording changed to say the implementer's next dispatch may land in the reviewer's leftover browser and see `reused`.
