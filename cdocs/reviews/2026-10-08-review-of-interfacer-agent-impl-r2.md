---
review_of: cdocs/proposals/2026-10-08-interfacer-agent.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T10:33:55-07:00
task_list: cdocs/interfacer-agent
type: review
state: live
status: done
tags: [fresh_agent, runtime_validated, ui_validated, implementation, subagents, interfacer, brevity]
---

# Review: Interfacer Agent Implementation (iterate round 2: fresh dispatch per check)

> BLUF: Accept.
> The revision is the minimal design the report recommends: no warm agent, no `SendMessage`, no sleeps; each check, tear down included, is a fresh dispatch naming the instance directory, and `notes.md` carries state.
> I re-ran the floor with my own fixtures and prompts: headless in the `clauthier` container (curl) and headless on the host (playwright-cli, screenshots I viewed).
> Both pass every criterion: three foreground depth-2 dispatches, `notes.md` read and reused, one server PID across checks, a 404 probe reported `WARNINGS`, a clean tear down, and a clean fixture.
> No warm, `SendMessage`, `agentId`, or sleep wording about the interfacer remains, except the agent's justified "never `SendMessage`".
> Findings are non-blocking and mostly remove text; the one that adds a word is the `notes.md` state-vs-log variance, which matters because host PIDs wrap (my host server was PID 693).
> review_proof: `confirmed` (artifacts below are from canaries this reviewer ran this round).

## Summary Assessment

The round replaces the warm-agent design (resume with `SendMessage`, caller sleep-polls) with fresh dispatches that resume from the instance directory, per the context preservation report's option E.
The agent stays 70 lines, the five caller clauses each changed by a phrase, and the proposal reads as the current design.
The contract (name the instance directory; the agent reads `notes.md`, confirms liveness, takes the next free `NN`) is clear and sufficient: both of my canaries carried state and reused the live server and browser session with no help beyond the path.
The verdict is **Accept**, with four non-blocking items.

## Reviewer's Own Floor Re-run

All artifacts are mine, from fixtures and prompts I wrote (an "Orchard" two-page site, port 8823/8824, a `/orchard-map.html` 404 probe and a missing `#remove`, unlike the implementer's).
Each run used a top-level `claude -p --plugin-dir <worktree>/plugins/cdocs --model sonnet --output-format stream-json --verbose` that dispatches a `general-purpose` stand-in (`run_in_background: false`), told only the three checks and to "follow that agent's description for how to dispatch it and how to wait for its report".
Sandbox `CLAUDE_CONFIG_DIR`s with credential copies were deleted after each run (`/tmp/r2-ccsb.PyHsVF` in the container, `scratchpad/r2/hccsb.AlHX9o` on the host); no servers or browsers remain.

### Static checks (worktree at `15eabe6`)

```
npm run test:rules     -> tests 11, pass 11, fail 0
npm run test:opencode  -> tests 9, pass 9, fail 0; "✔ OC agent interfacer.md"; built description carries the run_in_background line
wc -l interfacer.md    -> 70 (bash-runner.md: 65)
```

### Container canary (claude 2.1.285, curl; 80 s)

Fixture `/tmp/r2fx.DIXNH7` (README: serve command, "check pages over HTTP with `curl`"); stream `/tmp/r2-canary.jsonl`.

```
task_started  a655a83a depth 1 bg false general-purpose
task_started  a7fd0ea7 depth 2 bg false cdocs:interfacer   -> .../wiyCwy/01-home/report.md      Status: OK
task_started  a6762763 depth 2 bg false cdocs:interfacer   -> .../wiyCwy/02-trees/report.md     Status: WARNINGS
task_started  a81c970b depth 2 bg false cdocs:interfacer   -> .../wiyCwy/03-teardown/report.md  Status: OK, Left running: none
stand-in tool calls: Bash (find the agent file, ls fixture), Read interfacer.md, Bash (cat README), Agent x3 (all run_in_background:false); no SendMessage, no sleep
```

| Criterion | Result | Evidence |
|---|---|---|
| Three fresh foreground dispatches, depth 2 | Pass | three task ids, all `bg:false`, `spawn_depth: 2` |
| `notes.md` carried over | Pass | 02 `Setup:` "curl against running http.server pid 555950, port 8823 (per notes.md)"; 03 `Setup:` "notes.md" |
| `01-*`, `02-*` reports land | Pass | `wiyCwy/{01-home,02-trees,03-teardown}/report.md` plus saved curl bodies |
| Error probe not `OK` | Pass | 02 `Status: WARNINGS`: "GET /orchard-map.html -> 404 File not found"; `id="remove"` 0 matches |
| One server across checks; tear down leaves nothing | Pass | monitor: `555950` (plus wrapper `555944` for one sample) 10:30:46-10:31:26, then empty; no `http.server` after the run |
| Fixture clean | Pass | `git status --short --ignored` empty |

### Host canary (claude 2.1.293, playwright-cli 0.1.22, headless Chromium 1208; 109 s)

Fixture `scratchpad/r2/hfx.Vv0ecY` (README: serve command, project-local `npx playwright-cli -s=<name>`, the config pinning the local headless shell, and that snapshots land in `.playwright-cli/` in the cwd); stream `scratchpad/r2/hcanary.jsonl`.

| Criterion | Result | Evidence |
|---|---|---|
| Three fresh foreground dispatches, depth 2 | Pass | `aeed186c`, `aa39bf53`, `af12f255`, all `bg:false`, `spawn_depth: 2`; no `SendMessage`, no `sleep` |
| `notes.md` carried over; session reused | Pass | 02 `Setup:` "playwright-cli session orch per notes.md; server PID 693"; check 02 used `goto`, never `open`; monitor shows one server PID (693) and one new headless-shell PID (1083) from check 01 to tear down |
| Reports and screenshots land | Pass | `hNUJa3/01-home/home.png`, `02-trees/{trees,map}.png`; I viewed all three and each matches its report line |
| Error probe not `OK` | Pass | 02 `Status: WARNINGS`: 404 on `/orchard-map.html`, `#remove` absent |
| Tear down leaves nothing | Pass | 03: `kill 693` -> gone; `playwright-cli -s=orch close`; `playwright-cli list` -> `(no browsers)`; headless-shell PID set after the run equals the 19-process baseline |
| Fixture clean | Pass | `!! node_modules/` only (my copy); the interfacer ran playwright-cli from the check dir, so `.playwright-cli/` landed under the instance |

![Trees page after the interfacer clicked "See the trees": heading, Apple and Pear, disabled Plant button, Back link, cream background](../_media/2026-10-08-review-of-interfacer-agent-impl-r2-trees-page.png)

Source: `/tmp/claude-1000/interfacer/hNUJa3/02-trees/trees.png` (`cp -n`, `cmp` identical).

Run notes:

- Both stand-ins pasted the PID and session name into the follow-up and tear-down prompts, beyond the instance directory; the interfacers still read `notes.md`. Harmless redundancy, no action.
- Both interfacers recorded the server's real PID, not the `setsid` wrapper's; the "real PID ..., not a wrapper's" clause fixed the slip r1 saw three times.
- The container `notes.md` is an append log; the host one is sectioned current state. See the first agent finding below.

## Section-by-Section Findings

### Prior round (r1) action items

1. Async-reply sentence: superseded; the line is gone.
2. Proposal NOTEs: superseded; D5, the diagram, and the edge cases are rewritten for fresh dispatch, and the ordering NOTE was added (see the rendering nit below).
3. Devlog host facts: addressed (the refused `sleep 30` and the backgrounded stand-in are recorded).
4. First real iterate round with a runtime floor: still open, for the overseer.
5. `setsid` wrapper PID: addressed by `notes.md`'s "real PID ..., not a wrapper's"; held in all four fresh-dispatch runs.

### Residual warm-agent wording (focus 1)

A sweep of `plugins/`, `CLAUDE.md`, `README.md`, and the proposal for `SendMessage|agentId|warm|sleep|resum` finds none about the interfacer except:

- `interfacer.md:68` "never `SendMessage`": keep; a fresh interfacer can still `SendMessage` its parent (run 1 did).
- Proposal pass criteria "no `SendMessage` and no stand-in `sleep`": keep; they are regression assertions.
- Proposal D5 and Maintainer Overrides (d) compare against the warm alternative: fine in decision sections.
- The others (`proposer.md`, `iterate` implementer "kept warm", `overseers.md`, `ablate`, `converser`) are about other agents.

### The agent (`plugins/cdocs/agents/interfacer.md`)

- **Design.** Minimal and sufficient: one conditional line in Setup, "next free number", tear down as a check, and `notes.md` in step 2. The description's waiting line leads with the parameter, which run 6 showed matters; it held in run 7 and both of my runs.
- non-blocking: **`notes.md` state vs log.** Step 2 says "Update `<instance>/notes.md`", and sonnet reads that either way: my container run appended "Teardown: pid 555950 stopped." below a still-present "Running: http.server pid 555950" line, while my host run rewrote "Running: nothing (torn down)".
  It matters for a reused instance: after a restart, an append log lists a dead PID as "Running", and tear down "stop everything `notes.md` lists as running" can `kill` it; host PIDs wrap (my host server got PID 693), so that PID may belong to someone else.
  A one-word fix: "Rewrite `<instance>/notes.md`" (or "Keep ... current"), which makes it a state file and keeps the line count.
- Otherwise tight; I found nothing else worth cutting. The three canary clauses still each answer an observed failure.

### Callers and listings

`reviewer.md`, iterate's `confirmed` row, implement step 5, and `AGENTS.md` each change by a phrase and read correctly. "Never name an instance directory another agent started" closes the reuse path the old "never resume" wording closed. `README.md` and the devlog skill needed no change. Sound.

### Proposal (`cdocs/proposals/2026-10-08-interfacer-agent.md`)

It reads as the current design: the BLUF, the spec block (verbatim the shipped agent), "Durable by default", D5, D6, and the edge cases all describe fresh dispatch, and history stays in NOTEs and D5's comparison. Text to remove:

- non-blocking: line 187 "No sleeping or polling." only makes sense against the removed design; the bullet before it already says how to wait. Delete.
- non-blocking: line 160's NOTE ("Why fresh dispatches rather than one warm agent ...") restates D5, and Background already links the report. Delete it.
- non-blocking: line 303's ordering NOTE has no blank line after it, so "Do not touch `scripts/build-opencode.ts` ..." renders inside the blockquote by lazy continuation. Add a blank line. (Pre-dates this range.)
- non-blocking: the report link (Background, line 160) targets `cdocs/reports/2026-10-08-subagent-context-preservation-options.md`, which is on `main` (`2136ce9`) but not this branch; it resolves only once the branch lands on top of it.

### Sub-devlog

The revision section is honest: run 6's wording failure, the container's missing browser, and the "not run" list (no browser path under the revised agent, no real `cdocs:interfacer` type in the interactive check). My host canary now covers the first gap; the interactive gap remains, and the report's verified parking behavior makes it low risk.

## Verdict

**Accept.**
Every floor item was re-run and met in both environments with artifacts I produced, including the browser path the devlog left unverified.
The design is the minimal one, and the warm-agent wording is gone.
The items below are wording and can land without another review round.

review_proof: `confirmed`.

## Action Items

1. [non-blocking] `interfacer.md` Each check step 2 (and the proposal's spec block): "Update `<instance>/notes.md`" -> "Rewrite `<instance>/notes.md`", so it is a current-state file and tear down never kills a stale PID.
2. [non-blocking] Proposal line 187: delete "No sleeping or polling."
3. [non-blocking] Proposal line 160: delete the NOTE that duplicates D5 and Background.
4. [non-blocking] Proposal line 303: add a blank line after the ordering NOTE.
5. [non-blocking] Overseer: land the branch on top of `main`'s `2136ce9` so the report link resolves, and log the first real iterate round with a runtime floor as the end-to-end check of the reviewer clauses.

## Questions for the Maintainer

1. `notes.md` shape:
   (a) "Rewrite" (one word; a current-state file) (recommended);
   (b) leave "Update" (append logs work while liveness is checked, but tear down can hit a recycled PID);
   (c) prescribe sections (Drive, Running, Gotchas); more text than the problem needs.
