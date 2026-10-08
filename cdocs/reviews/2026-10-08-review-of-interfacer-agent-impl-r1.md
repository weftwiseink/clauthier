---
review_of: cdocs/proposals/2026-10-08-interfacer-agent.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T09:51:49-07:00
task_list: cdocs/interfacer-agent
type: review
state: live
status: done
tags: [fresh_agent, runtime_validated, ui_validated, implementation, subagents, interfacer]
---

# Review: Interfacer Agent Implementation (iterate round 1)

> BLUF: Accept.
> I re-ran the floor twice with my own fixtures, prompts, and config dirs: once in the `clauthier` devcontainer (claude 2.1.285, curl) and once on the host (claude 2.1.293, playwright-cli plus headless Chromium).
> Both runs pass every criterion: depth-2 dispatch, three `SendMessage`s to one `agentId`, the 404 probe reported `WARNINGS`, the same server PID across checks, clean tear down by PID, and a clean fixture `git status`.
> The in-turn-wait sentence is the right minimal fix, but on 2.1.293 it is too narrow: a first dispatch that omits `run_in_background` is async too, and the harness blocks `sleep 30`.
> Keep the three canary clauses: each prevents a failure the canary actually hit.
> The proposal needs NOTEs on D5 and its diagram, on the Edge Cases WARN, and on the reversed ordering. The devlog under-reports two host-run facts. All of these are non-blocking.
> review_proof: `confirmed` (the artifacts come from canaries this reviewer ran this round; paths and excerpts below).

## Summary Assessment

The work adds a 70-line sonnet `cdocs:interfacer` agent, wires one clause into each of five callers, and deletes `browser-delegate`, as the proposal specifies.
Static checks pass, and the deletion leaves no live reference.
I did not take the canary's claims on trust: I wrote my own fixtures, gave them leaner READMEs than the implementer's, and ran the nested canary in both environments.
The agent behaved as specified in both.
The main finding is about the documented dispatch mechanics, not the agent: on 2.1.293 a dispatcher waits in its turn for the first check too, not only for resumes.
The verdict is **Accept**, with non-blocking wording and documentation items.

## Reviewer's Own Floor Re-run

All artifacts below are ones I produced.
Container artifacts are ephemeral, so their excerpts are inlined.
Sandbox `CLAUDE_CONFIG_DIR`s (credential copies) were deleted after both runs: `/tmp/rvx-ccsb.CXoXMy` in the container, and `hccsb.tx3Nxu` under my scratchpad on the host.

### Static checks (worktree at `a277fa5`)

```
npm run test:rules     -> tests 11, pass 11, fail 0   (scratchpad rv/test-rules.txt)
npm run test:opencode  -> tests 9, pass 9, fail 0; "✔ OC agent interfacer.md"   (rv/test-opencode.txt)
build/cdocs/opencode/agents/interfacer.md frontmatter -> description only (no model/tools/permission)
wc -l plugins/cdocs/agents/interfacer.md -> 70   (bash-runner.md: 65)
jq -r '.plugins[].name' .claude-plugin/marketplace.json -> cdocs
grep -rn -i 'browser-delegate' --exclude-dir={cdocs,.git,build,node_modules} . -> no output, exit 1
plugins/cdocs/hooks/validate-cdocs-edit-path.sh CDOCS_AGENTS -> "triage nit-fix reviewer" (untouched, as the proposal requires)
```

### Devcontainer canary (claude 2.1.285, curl)

The fixture is `/tmp/rvx-fixture.6fZSWK`: a git repo with `site/{index,second,health}`, port 8812, and a README that names the serve command and says "drive the site over HTTP with `curl`".
Unlike the implementer's README, it gives no hint about 404s or curl exit codes.
The prompt has a `general-purpose` stand-in dispatch `cdocs:interfacer` ("Check that this project's home page loads and has a link to another page."), then send three `SendMessage`s: a follow-up, an error probe (`/nope.html` plus a missing `#delete`), and "tear down".
It says nothing about waiting.

Stream (`/tmp/rvx-canary.jsonl`, `task_*` events and the stand-in's tool calls):

```
task_started  af9a0014 depth 1 bg false general-purpose
task_started  aac285b0 depth 2 bg false cdocs:interfacer        (stand-in passed run_in_background:false)
task_notification aac285b0 "INTERFACER REPORT / Report: .../wioBe5/01-home/r..."
SendMessage to aac285b0ecf3b1d3f "Follow that link and capture the page it leads to."
task_started  aac285b0 depth 2 bg true ;  notification ".../wioBe5/02-follow..." ; Bash "sleep 15"
SendMessage to aac285b0ecf3b1d3f "Request /nope.html, and check whether ... `delete`." ; Bash "sleep 20"
task_started  aac285b0 depth 2 bg true ;  notification ".../wioBe5/03-nope-d..."
SendMessage to aac285b0ecf3b1d3f "tear down" ; Bash "sleep 20"
[interfacer] Bash: kill 549911; sleep 1; ps -p 549911 >/dev/null && echo alive || echo stopped
result: success, 105 s
```

The process monitor (`/tmp/rvx-psmon.log`, `uniq -c -f1`) shows one server PID from start to tear down; the first sample also catches the `setsid` wrapper:

```
     13 09:47:26 srv=[]
      1 09:47:39 srv=[549905<549684,549911<1,]
     61 09:47:40 srv=[549911<1,]
     31 09:48:42 srv=[]
```

`03-nope-delete/report.md` (excerpt):

```
Status: WARNINGS
Setup: same server as 01-home (PID 549911, port 8812), curl.
1. GET /nope.html -> 404 (expected; probing for it, but it is an error status).
2. GET /second.html, grep for id="delete" -> no match. Only id on the page is "save" (disabled button).
```

Check 01's `Setup:` cites the README ("README.md command `python3 -m http.server 8812 ...`, driven with curl (README says no browser available)").
After the run, the fixture's `git status --short --ignored` is empty, and no `http.server` process remains.
The interfacer made no `SendMessage` calls of its own.

### Host canary (claude 2.1.293, playwright-cli 0.1.22, headless Chromium 1208)

The fixture is `<scratchpad>/rv/hfx.Qqut5t`, with port 8813 and a project-local `@playwright/cli`.
Its README names `npx playwright-cli` with named sessions, the config pinning the local headless shell, and one fact: `outputDir` controls where playwright-cli writes, which otherwise is `.playwright-cli/` in the cwd.
It gives no recipe and no 404 hint.
The prompt matches the container's, with screenshots requested.

| Criterion | Result | Evidence |
|---|---|---|
| Depth 2, same `agentId` | Pass | `task_started` `spawn_depth: 2`, `cdocs:interfacer`; three `SendMessage` `to: aee3e2fc2debed33d` |
| One instance dir, per-check `report.md` + media | Pass | `/tmp/claude-1000/interfacer/pXaZWh/{01-home/{home,second}.png, 02-click-link/linked.png, 03-nope-delete/nope.png}`, each with `report.md`; the interfacer `Read` every PNG it described, and I viewed all four: each matches its description |
| `Setup:` cites the README | Pass | "README.md: python3 -m http.server 8813 ...; npx playwright-cli session "chk" (config via --config ...; outputDir set to .../pXaZWh/01-home/out)" |
| Reuse across checks | Pass | the monitor shows server PID 4001625 from 09:48:20 to 09:49:37 and one new headless-shell main PID (4006266, 09:48:29-09:49:34); the server log shows 304s on later checks (the same browser cache) |
| Error probe not `OK` | Pass | 03 `Status: WARNINGS` (404 plus a console error) |
| Tear down leaves nothing | Pass | `playwright-cli list` -> `(no browsers)`; no `http.server 8813`; the headless-shell PID set equals the 19-process pre-run baseline |
| Fixture `git status` clean | Pass | `!! node_modules/` only (my install). The interfacer copied the config into its instance dir with `outputDir` added rather than editing the project's config. |

![Second page after the interfacer clicked the home page link: "Second Page" heading, disabled Save button, Home link, lavender background](../_media/2026-10-08-review-of-interfacer-agent-impl-r1-second-page.png)

Source: `/tmp/claude-1000/interfacer/pXaZWh/02-click-link/linked.png` (`cp -n`, `cmp` identical).

![Error probe: the stock python http.server 404 page for /nope.html](../_media/2026-10-08-review-of-interfacer-agent-impl-r1-404-probe.png)

Source: `/tmp/claude-1000/interfacer/pXaZWh/03-nope-delete/nope.png` (`cp -n`, `cmp` identical).

Host-run facts that bear on the findings below:

- The stand-in's `Agent` call omitted `run_in_background`, and the result was `"Async agent launched successfully"` at depth 2 (`is_backgrounded: true` for the *first* dispatch). The depth-1 stand-in was async the same way.
- The stand-in's `sleep 30` was refused: `Blocked: standalone sleep 30. To wait for a condition, use Monitor with an until-loop ... Do not chain shorter sleeps to work around this block`. `sleep 10`, `15`, and `20` ran.
- The recorded `server.pid` (4001623) was the `setsid` wrapper. At tear down the interfacer found the wrapper gone, located its server by port with `ss`, and killed 4001625 by PID, saying so in its reply.
  Until then, its reports' `Left running` lines pointed at the wrong PID.

## Section-by-Section Findings

### The agent (`plugins/cdocs/agents/interfacer.md`)

- **Shape and length.** 70 lines, bash-runner style: a "Prompt with:" description, a two-step setup, a per-check loop, seven one-sentence rules, and a fixed report.
  It contains nothing project-specific (no tool names beyond the generic "a browser CLI"; no clauthier paths).
  `tools` is omitted per D3. Pass.
- **Canary clause 1, error status (line 46).** This prevents run 1's real failure (`Status: OK` with a 404 in the steps).
  Both of my runs reported `WARNINGS` for the probed 404 without a README hint, and the host run also flagged a tool-usage error a retry got past (`--config` rejected by non-`open` commands).
  That is the rule working as written. Keep it.
- **Canary clause 2, final message only (line 68).** This prevents a real failure: a backgrounded agent sees `SendMessage`'s own "Your plain text output is NOT visible to other agents ... you MUST call this tool" guidance, which is why run 1's interfacer sent headerless duplicate replies.
  In neither of my runs did the interfacer call `SendMessage`. Keep it.
- **Canary clause 3, tear down by recorded PID or session (line 48).** This prevents run 4's real failure: `pkill -f` matched the interfacer's own shell, and a pattern kill can also hit processes another agent started, which line 44 forbids.
  Both of my tear downs used a PID (the container's recorded PID was correct; the host's needed the `ss` fallback). Keep it.
  - non-blocking: the `setsid`-wrapper PID slip now has three sightings (implementer run 5 and host run, my host run), and each was caught at check time or tear down.
    I do not recommend a clause: it is shell knowledge, tear down self-corrects, and the only cost is a wrong PID in interim `Left running` lines.
- **Description, in-turn wait (line 14).** The sentence is the right minimal fix, and it matches SendMessage's documented semantics: messages "enqueue and drain at the receiver's next tool round", and the tool has no blocking option.
  In both of my runs the stand-in waited with short sleeps, and the prompt never mentioned waiting.
  Two inaccuracies on 2.1.293:
  - non-blocking: "A resumed check runs in the background" implies the first dispatch returns synchronously.
    On 2.1.293, an `Agent` call that omits `run_in_background` is async at every depth (my host run; the implementer's host stream shows the same at depth 1).
    The dispatcher coped from the harness's own async-agent result, but the description should not imply otherwise.
    Suggested wording, still one sentence: "Replies can arrive in the background (a resumed check's always does), at your next tool call: stay in your turn (e.g. a short Bash `sleep`) until each arrives."
  - non-blocking: the example `sleep 10` is fine, but 2.1.293 refuses `sleep 30` and discourages chained sleeps.
    "A short Bash `sleep`" avoids promising more than the harness allows. No other in-turn wait exists for a nested dispatcher, so I see no better mechanism.

### Callers

- **`reviewer.md`.** The new bullet (own interfacer, fresh sessions, never resume another agent's, always tear down) and the generalized `_media` clause (any subagent media, `.<ext>`, "look at it yourself") match the proposal word for word in substance.
  "Look at it yourself" closes the one gap D4 opens: it stops the sonnet's description from standing in for the reviewer's own look. Sound.
- **iterate Turn N.b and the `confirmed` row.** These keep the reviewer-produced-proof rule sound.
  The new parenthetical admits only an interfacer the reviewer dispatched this round, and it explicitly excludes one another agent started.
  Combined with reviewer.md's "never resume one another agent started" and the interfacer's "never reuse sessions or processes you did not start, unless the prompt names them", an implementer's warm interfacer or live server cannot launder into a `confirmed` row.
  One residual path: a reviewer that *names* an implementer's session in its prompt gets reuse. reviewer.md's "asking for fresh sessions" forbids that. Sound.
- **implement step 5 and the devlog Screenshots bullet.** One clause each, as specified.
  - non-blocking nit: the devlog bullet still says `.png`, while reviewer.md now says `.<ext>`. That is harmless for screenshots and needs no action.
- **Listings.** `AGENTS.md` sits under "Formal agents ... with explicit tool allowlists", and the interfacer has none. The bullet says "inherits all tools", which is accurate. Not worth a heading change.

### Removal

`plugins/browser-delegate/` is gone, along with its marketplace entry and the root README bullet.
The old proposal is `archived`/`evolved` with the NOTE under its H1, and its body is unchanged.
The repo grep is clean, and the hook allowlist is untouched. Pass.

### Proposal (`cdocs/proposals/2026-10-08-interfacer-agent.md`)

The implementation diverges from the proposal in three places, and only the devlog records them.
Per "CDocs Writing Conventions › Commentary Decoupling", each needs a NOTE in the proposal, not a rewrite:

- non-blocking: the "Durable by default" sequence diagram and D5 show follow-up replies returning like calls.
  A NOTE should say that replies (always for resumes; for the first dispatch unless `run_in_background: false`) arrive as notifications at the dispatcher's next tool call, so the dispatcher stays in its turn, and that the description says so.
- non-blocking: the Edge Cases WARN on foreground process lifetime is resolved for the gap it covers.
  My container run's foreground first dispatch (`run_in_background: false`) started a server that survived into checks 02-03 (61 monitor samples, one PID).
- non-blocking: "Implementation Phases" says the work serializes after graphify, but the overseer reversed that ordering.

The devlog defers all three to the overseer, which fits "the overseer holds the decisions", but they should land before the proposal reaches `implementation_accepted`.

### Sub-devlog (`cdocs/devlogs/2026-10-08-interfacer-agent-impl.md`)

The devlog is thorough and honest about the container's missing browser, the five runs, and the wrapper-PID slips.
Two host-run facts are under-reported (checked against the implementer's own `host-canary.jsonl`):

- non-blocking: the host table's "stand-in waited with `sleep 15`-`30`" omits that the harness *refused* `sleep 30` (`tool_use_error: Blocked: standalone sleep 30`).
- non-blocking: "Resume mechanics" states that the first dispatch runs in the foreground. That held because the stand-in passed `run_in_background: false`.
  The implementer's own host stream shows the depth-1 stand-in backgrounded, and my host run shows a backgrounded first interfacer dispatch.

Neither changes a pass/fail result, but a cold reader would carry the wrong model of the mechanics.

### Verification Methodology coverage

The proposal's one uncovered item stays uncovered: no real iterate round with a runtime floor has exercised the reviewer clauses.
This review is the closest proxy so far: a reviewer re-ran a floor and copied subagent-produced media into `_media`.
The media, though, came from an interfacer the canary stand-in dispatched under my `claude -p`, not from one this reviewer dispatched through its own `Agent` tool.
The overseer should still log the first real runtime-floor round as the end-to-end check, as the proposal says.

## Verdict

**Accept.**
Every item in the floor is re-run and met, in both environments, with artifacts I produced.
The agent matches the spec's shape and length, and its three canary clauses each answer an observed failure.
The remaining items are wording and documentation: the description's async sentence, the proposal NOTEs, and the devlog corrections.
The overseer can apply them without another review round.

review_proof: `confirmed`.

## Action Items

1. [non-blocking] `interfacer.md` line 14: broaden the sentence so it does not imply a synchronous first dispatch, and soften the sleep example, e.g. "Replies can arrive in the background (a resumed check's always does), at your next tool call: stay in your turn (e.g. a short Bash `sleep`) until each arrives."
2. [non-blocking] Proposal: add a NOTE under "Durable by default"/D5 on async replies and the in-turn wait. Add a NOTE on the Edge Cases foreground-lifetime WARN (resolved for the check-to-check gap). Add a NOTE on the reversed graphify ordering in "Implementation Phases".
3. [non-blocking] Sub-devlog: record the refused `sleep 30` and the backgrounded host stand-in, and qualify "first dispatch foreground" as depending on `run_in_background: false`.
4. [non-blocking] Overseer: log the first real iterate round with a runtime floor as the end-to-end check of the reviewer clauses.
5. [non-blocking, no action recommended] Watch the recurring `setsid`-wrapper PID slip. Add a clause only if a tear down actually fails from it.

## Questions for the Maintainer

1. Async replies in the description:
   (a) keep line 14 as is;
   (b) broaden it to "replies can arrive in the background", as in action item 1 (recommended);
   (c) also tell dispatchers to pass `run_in_background: false` on the first dispatch, making it synchronous.
   Option (c) is one more clause, but it ties the description to a CC parameter that OpenCode lacks.
2. `setsid`-wrapper PID:
   (a) leave it to projects and the tear-down self-check (recommended);
   (b) add "record the server's own PID, not a wrapper's" to the detach rule.
