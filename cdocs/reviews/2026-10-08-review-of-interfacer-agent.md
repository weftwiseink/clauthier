---
review_of: cdocs/proposals/2026-10-08-interfacer-agent.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T09:30:00-07:00
task_list: cdocs/interfacer-agent
type: review
state: live
status: done
tags: [fresh_agent, architecture, subagents, over_specification, test_plan]
---

# Review: Interfacer Agent

## Summary Assessment

The proposal replaces the 184-line `browser-delegate` plugin with one 78-line sonnet agent, `cdocs:interfacer`, plus one-clause edits to the reviewer, iterate, implement, and devlog surfaces.
It matches the maintainer's brief well: no project tooling in clauthier, media and `report.md` in a known tmp dir, a `bash-runner`-shaped body, and a complete deletion list.
Two things should change before it ships, and both fixes delete text: the `name` handle may not exist in the dispatchers' Agent tool and can turn a dispatch into a teammate spawn, and tooling left running across a dispatcher's return collides with the reviewer's fresh run under iterate.
Verdict: **Revise**.

## Verified

- **OpenCode.** With the drafted agent copied into a scratch copy of the repo, `npm run test:opencode` passes 9/9, including `OC agent interfacer.md`. The emitted file has no `model`, `tools`, or `permission` key, and the description round-trips. The "no change to `build-opencode.ts`" claim holds.
- **Rules.** `npm run test:rules` passes 11/11 with the draft in place. None of the proposed shipped text quotes a rule heading.
- **Deletion list.** `grep -rn -i 'browser-delegate' --exclude-dir={cdocs,.git,build,node_modules} .` hits only `plugins/browser-delegate/`, `.claude-plugin/marketplace.json:20-21`, and `README.md:7`. These are exactly the proposal's rows.
  The one other hit is `.claude/oversee/2026-10-08-graphify-interfacer.json`, which is overseer state and not a live reference.
  `plugins/converser/` is not in the marketplace, so "`jq` lists only `cdocs`" is correct.
- **Iterate soundness.** The `confirmed` row already admits "an artifact produced by a subagent the reviewer dispatched this round". The added clause ("one from an interfacer another agent started does not") closes the only new loophole, which is resuming the implementer's warm interfacer.
  The reviewer.md sentence ("never resume one another agent started") matters because named agents appear in the `SendMessage` roster that other agents see (subagents report §5).
  Generalizing the `_media` clause from the `BROWSER DELEGATE REPORT` `Artifacts` line and `.png` to "media a subagent produced" and `<ext>` is correct and needed.
- **Length and tone.** The body is close to `bash-runner`: same "Don't read rules files.", the same `${TMPDIR:-/tmp}/claude-$(id -u)` idiom, a fixed report, and "never delete" as the closing line. At 78 lines against 65, it uses almost all of the Test Plan's "under ~80" budget, so the implementer has no room left to polish. The trims below bring it to about 65.

## Section-by-Section Findings

### The agent: description and "Durable by default" (`name` handle)

**[blocking] Make `agentId` the handle and drop `name`.**
The design keys durability on dispatching "with a `name`". The dispatchers that matter most are the implementer and the reviewer, and both are themselves subagents.
- This reviewer runs at depth 1, and its own Agent tool schema lists only `description`, `isolation`, `model`, `prompt`, and `subagent_type`. It has no `name` parameter.
  The subagents report records the same gap (line 132: `name` and `run_in_background` are "not listed" in the nested schema, UNVERIFIED by depth or version).
- With agent teams enabled, "an Agent call with a `name` launches a teammate (not a subagent)" (report line 249). Teammates do not get the definition's `skills`, cannot be `/resume`d in-process, and route permissions differently, so the interfacer would silently not be an interfacer.
- Names also place the agent in the `SendMessage` roster that other agents see. That is the cross-agent reuse risk the reviewer clause then has to forbid.

The proposal already says the `agentId` "survives a name collision". Use it as the only handle.
Description: "Durable by default: keep the returned `agentId`, resume it with `SendMessage` for follow-up checks, and say "tear down" when done."
This deletes the role-plus-`-interfacer` naming convention, the "Name collision" edge case, and `name` from the canary step 2.

### Durable by default: "Ending" (tooling lifetime across a return)

**[blocking] Tear down before every return. The agent stays warm, but its tooling does not outlive the dispatcher's turn.**
"A dispatcher that expects to be resumed (an iterate implementer between rounds) keeps its interfacer and tooling up" means that during Turn N.b the implementer's server, app, or simulator install is still running while the reviewer's fresh interfacer starts its own.
For single-instance targets this collides, which makes it a likely failure in the interfacer's main use case:
- fixed-port servers (`python3 -m http.server 8000`, compose stacks);
- one app per bundle ID on a simulator or device (`flutter run`);
- desktop apps.

The reviewer's interfacer can then only report `FAILED` or break its own rule against killing processes it did not start.
Kept-up tooling also goes stale across the implementer's edits when the server does not hot-reload.
The fix removes text. Replace the "Ending" bullet's two exceptions (hand-off to its own dispatcher, keep-up-when-resumable) with: "A dispatcher sends "tear down" before it returns; a warm implementer resumes the same interfacer next round, which restarts what it needs."
Warmth that holds the briefing, the setup discovery, and the cache is most of the value. A cold app start once per round is cheap next to a review round.
This also settles Open Question 3.

### The agent body: over-specification (remove text)

**[non-blocking] Collapse the two templates into one.**
`report.md` has a 13-line template and the final message has a 7-line template that repeats `Status`, `Summary`, and `Left running`.
Keep the `report.md` template and replace the second block with one sentence: "Your final message is only `INTERFACER REPORT`, then the report path and its `Status:` and `Left running:` lines, then a two-to-five-line summary."
This saves about 6 lines.

**[non-blocking] Say the verdict boundary once.**
The intro's "You are the dispatcher's hands and eyes, and it decides whether the result is acceptable." restates the sixth rule ("leave whether the change is correct or acceptable to the dispatcher").
Keep the rule, since it carries the useful "point at the media" example, and cut the intro sentence.

**[non-blocking] Trim Setup step 2's file list.**
Subagents already receive the CLAUDE.md hierarchy, and sonnet knows where projects document things.
"the prompt first, then the project's own docs and scripts" is enough. Drop the parenthetical.

**[non-blocking] Drop the `"fresh"` option from the description.**
Fresh is already the default, because the rule never reuses what the interfacer did not start "unless the prompt names them".
The option line becomes "Optional: sessions or processes to reuse, by name".
The reviewer.md sentence can keep "asking for fresh sessions" as cheap insurance on the one guarantee iterate depends on.

All other rules map to a failure seen in practice or to a mechanic durability needs:
- no installs or tool swaps;
- the write boundary, given CLIs that write into the cwd;
- not touching sessions it did not start (r3-r7);
- outliving the Bash call;
- errors are never a pass, and a piped exit status is never read as the tool's (impl r1, r2);
- looking at every capture.

The "reuse the printed path as a literal" clause prevents a real failure (shell state does not persist). Keep it.

### Callers

**[non-blocking] Implement skill bullet: "prefer", not a mandate.**
"For checks against a running app or interface, dispatch a `cdocs:interfacer` … rather than driving the tool yourself" also covers a single `curl`, where delegating is pure overhead.
Suggested wording: "prefer dispatching a `cdocs:interfacer` (kept warm) over driving the tool yourself."

**[non-blocking] Edit-path hook allowlist.**
`plugins/cdocs/hooks/validate-cdocs-edit-path.sh:8-9` says "When adding new cdocs agents … also add their bare name to the CDOCS_AGENTS allowlist".
Following that comment would block the interfacer's `Write` of `report.md` under `/tmp`, because the hook allows only `cdocs/(devlogs|proposals|reviews|reports)/` paths.
An implementer updating "listings" could plausibly follow it. Add "or the edit-path hook allowlist" to Implementation Phases' "Do not touch" sentence.

### Proposal body

**[non-blocking] Drop the "Context limit" bullet.**
None of it ships: it reaches no agent, skill, or rule text.
It also borrows the overseer's ~400K threshold for a sonnet agent, whose context window may sit below that and would auto-compact first.

**[non-blocking]** The old proposal gets `status: evolved` but keeps `state: live`. Since the plugin is deleted, `state: archived` fits better. `/cdocs:triage` would also catch this.

### Verification Methodology

The plan proves the three things it needs to prove:
- a nested dispatch at depth 2 through a `general-purpose` stand-in;
- media plus `report.md` in one instance directory with `01-*/` and `02-*/`;
- a `SendMessage` follow-up to the same `agentId`, with PID-level reuse and teardown checks and an error probe.

**[non-blocking] Record whether the interfacer ran in the foreground or the background.**
Per the subagents report §4, `-p` mode runs subagents in the background by default unless the model needs the result.
A background run would pass the canary but leave the foreground process-lifetime WARN unresolved. A background subagent also has a restricted tool set without `Agent`.
One pass-criterion clause is enough: "the stream shows the interfacer ran in the foreground (or the devlog flags the foreground lifetime as still unverified)".
After the second blocking fix, this lifetime only has to cover the gap between the interfacer's first return and the stand-in's `SendMessage`, which is exactly what the canary exercises.

## Open Questions: Recommendations

1. **"Durable by default".** Keep the warm-agent reading, scoped as in the second blocking finding: the agent stays warm across the dispatcher's whole engagement, and its tooling lives within one dispatcher turn.
   Reject (a): it writes to the project tree and duplicates the `_media` decision.
   Reject (b): retries hide errors, and the dispatcher already decides.
   Reject (c): `background: true` would force every caller to go async for a result it usually needs next. It would also strip `Agent` from the interfacer's tool set and change the process-lifetime semantics without anyone choosing that.
2. **Tools.** Inherit everything. Narrowing to `Bash, Read, Write` would rule out MCP-driven projects (browser or mobile MCP servers) and the `bash-runner` hand-off, and it contradicts the maintainer's preference for guidelines over bans.
   The write boundary as a rule matches `proposer` and `implementer`.
3. **Reviewer teardown.** Always tear down, with no hand-off.
   The report's `Setup:` line and its media let a human reproduce the state. A reviewer's app left running collides with the next round's fresh run, which is the same failure as the second blocking finding.

## Verdict

**Revise.**
Both blocking items are small deletions: `name` becomes `agentId`, and the "Ending" exceptions collapse into "tear down before you return".
The non-blocking trims bring the agent to about `bash-runner`'s 65 lines.
The deletion list, the OpenCode and rules claims, and the iterate edits are sound as written.

## Action Items

1. [blocking] Replace the `name` handle with the returned `agentId` in the agent description, "Durable by default", the reviewer/implementer guidance, and canary step 2. Delete the naming convention and the "Name collision" edge case.
2. [blocking] Replace "Ending"'s two exceptions with one rule: a dispatcher sends "tear down" before it returns, and a resumed interfacer restarts what it needs. Mark Open Question 3 resolved (always tear down).
3. [non-blocking] Collapse the final-message template into one sentence that reuses `report.md`'s fields.
4. [non-blocking] Cut the intro sentence that duplicates the observations-versus-verdict rule.
5. [non-blocking] Drop Setup step 2's parenthetical file list and the description's `"fresh"` option.
6. [non-blocking] Implement skill bullet: change "dispatch … rather than" to "prefer dispatching … over".
7. [non-blocking] Add "or the edit-path hook allowlist" to Implementation Phases' "Do not touch" sentence.
8. [non-blocking] Canary pass criteria: record foreground versus background run mode. A background run leaves the foreground-lifetime WARN open.
9. [non-blocking] Drop the "Context limit" bullet, and consider `state: archived` for the old proposal.

## Questions for the Maintainer

- **Q1. Tooling lifetime between iterate rounds.** (a) Tear down at every dispatcher return, keeping the agent warm (this review's recommendation). (b) Keep the implementer's tooling up across rounds and accept collisions with the reviewer's fresh run. (c) Keep it up, but make the reviewer reuse the implementer's server, which weakens reviewer independence.
- **Q2. "Durable by default".** (a) Warm agent, with tooling scoped to the dispatcher's turn (recommended). (b) Warm agent plus tooling that persists until an explicit teardown (as drafted). (c) `background: true`.
