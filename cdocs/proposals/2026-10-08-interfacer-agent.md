---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T09:06:30-07:00
task_list: cdocs/interfacer-agent
type: proposal
state: live
status: implementation_wip
last_reviewed:
  status: accepted
  by: "@claude-opus-5-5"
  at: 2026-10-08T09:51:49-07:00
  round: 3
tags: [architecture, claude_skills, interfacer, browser_delegation, testing, subagents]
---

# Interfacer Agent: a general sonnet testing assistant replacing `browser-delegate`

> BLUF: Delete the `browser-delegate` plugin and add one ~70-line sonnet agent, `cdocs:interfacer`, shaped like `bash-runner`.
> Any agent dispatches it as a testing assistant: it learns how to drive the target from the dispatch prompt and the project's own docs and scripts, writes media and a brief `report.md` under `${TMPDIR:-/tmp}/claude-<uid>/interfacer/<instance>/NN-<check>/`, and replies with the path and a short summary.
> Durable by default: the dispatcher keeps the returned `agentId` and resumes it with `SendMessage` for follow-up checks, and tells it to tear down its tooling before the dispatcher itself returns.

## Summary

The agent is a leaf-shaped helper with a short body: a two-step setup, a per-check loop, seven one-sentence rules, and a fixed report.
It reports observations ("the Save button rendered, disabled") and leaves acceptability to the dispatcher.
Inside `/cdocs:iterate` the reviewer dispatches its own fresh interfacer, so that output is reviewer-produced proof for the `confirmed` row; the reviewer looks at any media its verdict relies on and copies it into `cdocs/_media/`.

Changes outside the new agent are one clause each: `reviewer.md`, iterate's Turn N.b and `confirmed` row, the implement skill's verification bullet, the devlog skill's Screenshots bullet, and the agent listings.
The OpenCode build needs no change: it auto-discovers agents, and `scripts/build-opencode.test.ts` covers the new file.

> NOTE(opus-5-5/cdocs/interfacer-agent): The old agent is 184 lines because every review finding was answered with more text (explainer: https://claude.ai/artifact/UGak8RdKKZoTXWX9nAExKR).
> This design keeps only rules that prevent a failure seen in practice, and pushes all tool knowledge to the calling project.

## Objective

Give implementers, reviewers, and any other agent a cheap "hey sonnet, please test this for me" assistant for whatever interface the project exposes (a web app, a flutter app, a simulator, an HTTP API), without the caller holding the tool-call loop and without clauthier encoding any project's tooling.
Remove the separate, playwright-specific `browser-delegate` plugin it supersedes.

## Background

- [`cdocs/proposals/2026-09-17-browser-delegation-plugin.md`](2026-09-17-browser-delegation-plugin.md): the superseded design.
  Its maintainer decisions carry over: the dispatcher owns durable state, and cited screenshots are copied into `cdocs/_media/` by the doc that cites them.
  Its other decisions (`@playwright/cli` only, session naming by branch, no observations at all, baseline diffs, convergence polling) do not.
- `plugins/browser-delegate/agents/browser-delegate.md` and its reviews (`cdocs/reviews/*browser-delegation*`): real failures they found, which the new rules cover in one sentence each:
  matching eval errors counted as convergence (impl r1, blocking), a piped command's exit status read as the tool's (impl r2), and session reuse across agents breaking reviewer independence (r3-r7).
- [`plugins/cdocs/agents/bash-runner.md`](../../plugins/cdocs/agents/bash-runner.md): the style target (65 lines, "Prompt with:" description, `${TMPDIR:-/tmp}/claude-$(id -u)` scratch, fixed brief report, capture left in place).
- [`cdocs/reports/2026-09-19-claude-code-subagents-feature-breakdown.md`](../reports/2026-09-19-claude-code-subagents-feature-breakdown.md) §4-5, 8, 10: the mechanics "durable" rests on.
  `SendMessage(to: <id or name>)` resumes an agent with full history, tool results, and tool set, cache-warm; the Agent tool result carries `agentId` (nested dispatchers' Agent tool has no `name` parameter, report line 132); long-running commands started by a background subagent can outlive it; subagents inherit MCP tools unless `tools` narrows them; nesting is three layers by default.
- "CDocs Overseer Rules › Stay thin": warm subagents are expected, with a fresh one of the same type past ~400K context after a handoff.
- `plugins/cdocs/skills/iterate/SKILL.md`: Turn N.b requires the reviewer to re-run empirical floors and cite an artifact; the `confirmed` row already counts "an artifact produced by a subagent the reviewer dispatched this round" as the reviewer's own.
- `plugins/cdocs/agents/reviewer.md` line 50: the `_media` copy clause, keyed to a subagent report's `Artifacts` line (the `BROWSER DELEGATE REPORT` field) and to `.png`.

## Proposed Solution

### Removal

| Path | Change |
|---|---|
| `plugins/browser-delegate/` (agent, README, `.claude-plugin/plugin.json`) | Delete. |
| `.claude-plugin/marketplace.json` | Delete the `browser-delegate` entry. |
| `README.md:7` | Delete the `browser-delegate` bullet. |
| `cdocs/proposals/2026-09-17-browser-delegation-plugin.md` | `status: evolved`, `state: archived`, plus a NOTE under the H1 pointing here. Body unchanged. |

A repo grep outside `cdocs/` finds no other live reference.
Historical cdocs (devlogs, reviews, reports, chat records) stay as written.

### The agent: `plugins/cdocs/agents/interfacer.md`

The implementer may polish wording, but the shape, the rule set, and the length (~70 lines) are the spec.

````markdown
---
name: interfacer
model: sonnet
effort: medium
description: |
  Testing assistant: drive the app or interface under test with the tooling the project already has (a browser CLI, flutter, a simulator, an HTTP client, an MCP server), capture screenshots and other media, and write a brief markdown report.
  Prompt with:
  - What to check, and where (URL, screen, endpoint, command)
  - How the project drives it, if you know (a script, doc, or command), else it reads the project's docs and scripts
  - Optional: sessions or processes to reuse, by name
  - Optional: which states to capture, and any logs wanted

  Durable by default: keep the returned `agentId`, resume it with `SendMessage` for follow-up checks, and say "tear down" before you return.
  Responds with its report path, a short summary, and what it left running.
color: cyan
maxTurns: 40
---

# CDocs Interfacer Agent

Drive the interface a dispatching agent wants checked, capture media, and report what happened.

Don't read rules files.

## Setup (first dispatch only)

1. Make your instance directory, `d="${TMPDIR:-/tmp}/claude-$(id -u)/interfacer"; mkdir -p "$d"; mktemp -d "$d/XXXXXX"`, and reuse its printed path as a literal for every later call and follow-up.
2. Learn how this project drives the target: the prompt first, then the project's own docs and scripts.
   If you find no working way to drive it, stop and report `FAILED` with what you looked for.

## Each check

The first dispatch and each follow-up message is one check, in `<instance>/NN-<slug>/` (`NN` counts up from `01`).

1. Start or reuse what the check needs, run its steps, and capture media into the check directory.
2. Look at every capture you describe (`Read` shows images).
3. Write `report.md` in the check directory, then reply.

## Rules

- Use the project's setup as documented: don't install tools, change config, or swap in a different tool when it fails, but report what is missing.
- Write only under your instance directory, by absolute path, and never create or edit files in the project tree (if a tool writes into its cwd anyway, say so in the report).
- Never close, kill, restart, or reuse sessions and processes you did not start, unless the prompt names them.
- Start long-lived things (servers, apps, browser sessions) detached (the tool's own daemon, or `setsid`/`nohup`) so they outlive the Bash call, and leave them running until told to tear down.
- An error is never a pass: report every failed command, timeout, missing element, or blank capture, including ones a retry got past, and never read a piped command's exit status as the tool's.
- Describe what you observed and point at the media that shows it ("the Save button rendered, disabled"), but leave whether the change is correct or acceptable to the dispatcher.
- On "tear down", stop everything you started and list what you stopped.

## Report

`report.md`, usually under ~300 words:

```
# <check slug>
Status: OK | WARNINGS | FAILED
Setup: <how you drove it: commands or scripts, versions, and the doc or script that said so>
## Steps
1. <action> -> <what happened>
## Media
- <abs path>: <what it shows>
## Left running
- <session or process>: <how to stop it> | none
## Notes
<errors, surprises, anything the dispatcher should know>
```

Your final message is only `INTERFACER REPORT`, then the report path and its `Status:` and `Left running:` lines, then a two-to-five-line summary.

The instance directory is what the dispatcher cites: never delete it.
````

Output layout:

```
${TMPDIR:-/tmp}/claude-<uid>/interfacer/
  <XXXXXX>/              one per interfacer instance, made on its first dispatch
    01-<slug>/           one per check (dispatch or follow-up)
      report.md
      <step>.png, <step>.log, ...
    02-<slug>/
```

### Durable by default

The agent stays warm across the dispatcher's whole engagement; its tooling lives within one dispatcher turn.

> NOTE(opus-5-5/cdocs/interfacer-agent): Replies are asynchronous, not returned like a call (claude 2.1.285 and 2.1.293, Phase 4 canary).
> A resumed check always runs in the background, and a first dispatch does too unless the dispatcher passes `run_in_background: false`; the reply arrives as a notification at the dispatcher's next tool call.
> A dispatcher that ends its turn never receives it, so the dispatcher stays in its turn (short Bash `sleep`s; the harness refuses long ones) until each reply arrives, and the agent's description says so.
> The diagram's reply arrows show content, not a synchronous return.

```mermaid
sequenceDiagram
  participant D as Dispatcher (implementer, reviewer, any agent)
  participant I as interfacer (sonnet)
  participant T as Project tooling (server, app, browser session)
  D->>I: Agent(subagent_type cdocs:interfacer, prompt), keeps agentId
  I->>T: start (outlives the Bash call)
  I-->>D: report path 01-..., Left running
  D->>I: SendMessage(to agentId): follow-up check
  I->>T: reuse
  I-->>D: report path 02-...
  D->>I: SendMessage: tear down (before D returns)
  I->>T: stop
  I-->>D: stopped list
  Note over D,I: next round, D resumes the same agentId, which restarts what it needs
```

- **Warm agent.** The dispatcher keeps the `agentId` from the Agent tool result; it passes no `name`, which nested Agent tools lack and which, with agent teams enabled, spawns a teammate instead of a subagent.
  A resume keeps the agent's history, so a follow-up is one sentence ("now submit the form and screenshot the result"), and it hits the prompt cache.
- **Live tooling.** The interfacer starts servers and apps so they outlive its Bash calls: detached (the tool's own daemon, such as a browser CLI's session, or `setsid`/`nohup`), not Bash `run_in_background`, which nested callers lack.
  Its `Left running` line is the dispatcher's inventory of what to tear down.
- **Ending.** A dispatcher sends "tear down" before it returns; a warm implementer resumes the same interfacer next round, which restarts what it needs.
  This keeps single-instance targets (fixed ports, one app per simulator, desktop apps) free for the reviewer's fresh run and avoids stale servers across the implementer's edits.

### Callers

Any agent dispatches it directly, with no skill and no wrapper.

- **Implementer.** `plugins/cdocs/skills/implement/SKILL.md` step 5's verification bullet gains: "for checks against a running app or interface, prefer dispatching a `cdocs:interfacer` (kept warm) over driving the tool yourself."
  A warm implementer under iterate resumes its interfacer across rounds, since its history holds the `agentId`.
- **Reviewer.** `reviewer.md` gains one sentence and the `_media` clause is generalized:
  - New: "For a runtime check, dispatch your own `cdocs:interfacer` asking for fresh sessions, never resume one another agent started, and tear it down before you return."
  - Generalized line 50: "When your verdict relies on media a subagent produced (such as your interfacer's), look at it yourself, `cp -n` it to `cdocs/_media/YYYY-MM-DD-<review-doc-name>-<description>.<ext>` ..." (the rest of the clause unchanged).
- **Iterate.** Turn N.b: "the reviewer empirically re-runs the floor, itself or through its own `cdocs:interfacer`, and cites at least one artifact path".
  `confirmed` row: "(an artifact produced by a subagent the reviewer dispatched this round, such as its `cdocs:interfacer`, counts as its own; one from an interfacer another agent started does not)".
- **Devlogs.** The devlog skill's Screenshots bullet gains: "copy from an interfacer's report directory (tmp paths do not persist)."

The interfacer never writes `cdocs/_media/`: the dispatcher copies only what its doc cites, per the old proposal's maintainer decision.

### Listings and OpenCode

| File | Change |
|---|---|
| `plugins/cdocs/AGENTS.md` "Formal Agents" | Add `interfacer` (sonnet; inherits all tools, including the project's MCP servers). |
| `plugins/cdocs/README.md` | "7 agents converted" becomes 8; "`bash-runner` follows no rules" names `interfacer` too. |
| `CLAUDE.md` | No change: it lists skills, not agents. |
| `scripts/build-opencode.ts`, its test | No change. With `tools` omitted the build emits no `tools`/`permission` block (OpenCode: all tools), drops `model`, and round-trips the description; the test loops over every agent file. |

The CC-specific word in the description (`SendMessage`) passes through to OpenCode as text; an OpenCode caller resumes subagents its own way.

## Important Design Decisions

### D1: One agent in `cdocs`, no plugin, no skill

A separate plugin cost a marketplace entry, an install step, and a README for one file.
`bash-runner` already lives in `cdocs` as a generic helper; the interfacer is the same kind of thing.
A skill would add ceremony the "Prompt with:" description already covers.

### D2: Tool knowledge comes from the calling project

Clauthier cannot track every project's tooling, and the old agent's CLI resolution, config lookup, and session-naming sections all rotted into tool trivia.
The interfacer reads the prompt and the project's docs and scripts, and its report says which source it used, so a project that wants reliable tests documents its setup once (which helps humans too).

### D3: `tools` omitted (inherit everything)

The project's interfacing tool may be an MCP server (a browser or mobile MCP); narrowing `tools` would bake a "CLI tools only" assumption into clauthier.
The write boundary is a rule, not a tool ban (the maintainer prefers guidelines over bans), matching `proposer` and `implementer`.
It keeps `Agent`, so it can hand a verbose build log to a `bash-runner` (depth stays within three layers under iterate: overseer, reviewer, interfacer, runner).

### D4: Observations allowed, verdicts kept by the dispatcher

The old "mechanical facts only" rule made the dispatcher re-open every screenshot to learn anything, which defeats delegation.
A sonnet describing a screenshot it looked at is reliable and checkable, since each observation points at its media.
Acceptability ("the fix works", "matches the design") needs the proposal's criteria and, under iterate, belongs to the reviewer, who looks at any media its verdict relies on.

### D5: Durable by default means warm agent plus live tooling

> NOTE(opus-5-5/cdocs/interfacer-agent): "Keeping an `agentId`" also means waiting in-turn for each asynchronous reply; see the NOTE under "Durable by default".

Re-dispatching for each follow-up pays a fresh briefing, a fresh setup discovery, and a cold app start.
`SendMessage` resume and long-lived processes are native mechanics, so durability costs keeping an `agentId` and a "tear down" before each return, with no state file.

### D6: Fresh per reviewer, warm per implementer

Reviewer independence needs its own sessions and its own agent, so a reviewer never resumes or reuses the implementer's, and always tears down (no hand-off to the overseer: the report's `Setup:` line and media let a human reproduce the state).
The implementer benefits most from warmth (many small checks while fixing).

### D7: Report file plus short final message

The dispatcher gets a few lines in context and reads `report.md` or the media only when it needs them; the file also survives for a later reader of the instance directory.

## Edge Cases / Challenging Scenarios

- **No documented setup.** The interfacer reports `FAILED` with what it searched; the dispatcher either names the command or fixes the project's docs.
- **A tool writes into its cwd** (some browser CLIs write a state dir there). The interfacer notes it in the report, and if the project's docs give a cwd or output flag, it uses that.
- **Two agents told to reuse the same named session.** Not prevented: the rule against touching unnamed sessions covers the default case, and naming a shared session is the dispatcher's explicit choice.
- **A dispatcher returns without tearing down.** `Left running` in the last report names what is up; processes started under Claude Code's Bash may die with the session, and daemons idle out on the tool's own timeout.
- **Process lifetime after a foreground interfacer returns.** Documented for background subagents only. WARN(opus-5-5/cdocs/interfacer-agent): unverified for foreground, though it only has to span the gap between a check's return and the dispatcher's next `SendMessage`, which Phase 4 tests; starting processes detached is what makes it hold.
  > NOTE(opus-5-5/cdocs/interfacer-agent): Resolved for the gap it covers: in the devcontainer canary a foreground first dispatch (`run_in_background: false`) started a detached server that survived into checks 02-03 (one PID across 61 one-second samples).
- **`maxTurns` across resumes.** Whether the 40-turn cap is per resume or cumulative is unverified; a capped result is marked partial and resumable, so the dispatcher can continue it either way.

## Test Plan

- `npm run test:rules`: the new agent quotes no rule heading, and the edited skills and agents still resolve.
- `npm run test:opencode`: `interfacer.md` builds, its description round-trips, it has no `model`, `tools`, or `permission` key.
- `jq . .claude-plugin/marketplace.json` parses and lists only `cdocs`.
- `grep -rn -i 'browser-delegate' --exclude-dir=cdocs --exclude-dir=.git --exclude-dir=build --exclude-dir=node_modules .` returns nothing.
- `wc -l plugins/cdocs/agents/interfacer.md` is ~70 lines.

## Verification Methodology

A live canary, in the style of `cdocs/devlogs/_verify/2026-10-05-bash-runner-live-canary.md`, recorded in the implementer's sub-devlog:

1. **Fixture project.** A `mktemp -d` git repo with a two-page static site, a `health.json`, and a README stating how to serve it (`python3 -m http.server`) and drive it.
   The verifier, not the interfacer, installs the browser tooling into the fixture (playwright-cli is not on this host's `PATH`; `~/.cache/ms-playwright/` holds `chromium_headless_shell-1208`, so a project-local `@playwright/cli` plus a config pinning that `executablePath` is the likely setup).
   If no browser launches, the canary still runs with `curl` as the tool, and the devlog flags the browser path as unverified.
2. **Nested dispatch.** `claude -p --plugin-dir <repo>/plugins/cdocs --output-format stream-json --verbose` from the fixture; the top-level agent dispatches a `general-purpose` stand-in, which dispatches `cdocs:interfacer` with a prompt naming only what to check ("check the home page renders and its link reaches page two"), not how.
3. **Follow-up.** The stand-in resumes the same agent with `SendMessage` ("click the link and screenshot page two"), then sends "tear down".
4. **Error probe.** One check targets a missing element or a 404 route; its report must not say `OK` for that step.

Pass criteria, from the stream and the filesystem:

- The stream shows `Agent` with `subagent_type: cdocs:interfacer` at depth 2, and `SendMessage` to the same `agentId`.
- The stream shows whether the interfacer ran in the foreground or the background; a background run leaves the foreground-lifetime WARN open, and the devlog says so.
- One instance directory holds `01-*/` and `02-*/`, each with `report.md` and at least one screenshot whose description matches the image (the verifier looks).
- Check 1's report's `Setup:` cites the fixture README; check 2 reused check 1's server and session (same PID, no second `open`) rather than restarting them.
- After tear down, the server PID and the browser session are gone.
- `git status` in the fixture shows nothing the interfacer created.
- One screenshot is copied to `cdocs/_media/2026-10-08-interfacer-canary-<description>.png` and embedded in the sub-devlog, exercising the `_media` convention.

Not covered: a real iterate round with a runtime floor.
The first such round after landing is the end-to-end check of the reviewer clauses, and the overseer should log it as such.

## Implementation Phases

Implementation serializes after the graphify overhaul, which also edits `reviewer.md` and `iterate/SKILL.md`; rebase onto it and keep each edit to the clause named here.

> NOTE(opus-5-5/cdocs/interfacer-agent): The overseer reversed this ordering: the interfacer landed before the graphify overhaul, which rebases onto it.
Do not touch `scripts/build-opencode.ts`, the rules files, the edit-path hook allowlist (`CDOCS_AGENTS` in `plugins/cdocs/hooks/validate-cdocs-edit-path.sh`, which would block the interfacer's `report.md` writes under tmp), or historical cdocs documents beyond the old proposal's frontmatter and NOTE.

### Phase 1: The agent and its listings

- Write `plugins/cdocs/agents/interfacer.md` per "The agent".
- Update `plugins/cdocs/AGENTS.md` and `plugins/cdocs/README.md` per "Listings and OpenCode".
- Success: `npm run test:rules` and `npm run test:opencode` pass; the file is ~70 lines.

### Phase 2: Callers

- `reviewer.md` (new sentence, generalized `_media` clause), iterate Turn N.b and `confirmed` row, implement skill step 5, devlog skill Screenshots bullet, per "Callers".
- Success: `npm run test:rules` passes; each diff hunk is one clause or sentence.

### Phase 3: Remove `browser-delegate`

- Delete `plugins/browser-delegate/`, its marketplace entry, and `README.md:7`.
- Old proposal: `status: evolved`, `state: archived`, and a NOTE under the H1 (`> NOTE(opus-5-5/cdocs/interfacer-agent): Superseded by [the interfacer agent](2026-10-08-interfacer-agent.md); the plugin is removed.`).
- Success: the Test Plan's `jq` and `grep` checks pass.

### Phase 4: Live canary

- Run the Verification Methodology and record stream excerpts, report paths, and pass/fail per criterion in the sub-devlog.
- If a process does not survive between checks, fix how the agent detaches it and re-run.
- Success: every pass criterion met, or each miss flagged with its cause.

## Maintainer Overrides

> NOTE(opus-5-5/cdocs/interfacer-agent): These are settled as decisions (D3, D5, D6) but the maintainer has not answered them yet, so the maintainer may override any of them.
> 1. "Durable by default" means a warm agent resumed by `agentId`, with tooling scoped to one dispatcher turn.
>    Rejected readings: (a) media persisted to a project path (writes into the project tree, duplicates the `_media` decision); (b) re-opening and retrying (retries hide errors); (c) `background: true` (forces every caller async, strips `Agent`, and changes process lifetime unasked).
> 2. All tools are inherited (D3), and reviewers always tear down (D6).
