---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T16:49:00-07:00
task_list: cdocs/graphify-weftwise-assessment
type: report
state: live
status: review_ready
tags: [analysis, subagents, context_bloat, graphify, performance]
---

# Search Subagent for Context Prep

> BLUF: Don't build it: a dedicated sonnet searcher or a prep pass would save little, because search is a small part of where implementer and reviewer context goes.
> Grep, find, and git-log output is 4-14% of their tool-result tokens and 1.6-5.6% of their cost, while one sonnet `Explore` dispatch costs $0.31-0.43 and about 100 s, more than an opus agent's whole median search spend ($0.07-0.18).
> Recommended: drop graphify, add no new agent or prep pass, and add one guideline line pointing wide discovery sweeps at the built-in `Explore`, with the reader verifying what it relies on (confidence: high on the token case, medium that the guideline helps on large code repos).

## Context

The maintainer judged graphify not worth its upkeep, given the weftwise assessment ([report](2026-10-08-graphify-weftwise-assessment.md), "Value Beyond Grep").
The original motivator was context bloat in the opus implement and review agents.
This report asks whether a sonnet search and context-prep subagent, along the lines of `cdocs:bash-runner`, would cut that bloat.

## Method

- Transcripts: every `cdocs:implementer`, `cdocs:reviewer`, `Explore`, and `cdocs:bash-runner` subagent since 2026-09-20 under `~/.claude/projects/-var-home-mjr-code-weft-clauthier-main` and `-workspaces-weftwise-main`, plus 62 weftwise opus implementers (`general-purpose` dispatches whose description says "implement", since 2026-09-01; weftwise has no `cdocs:implementer` runs).
  That is 297 agents.
- Context size per request is `input + cache_read + cache_creation` from `usage`, deduplicated by `requestId`.
  Tool-result tokens are estimated as characters divided by a per-agent chars-per-token ratio, calibrated from context deltas between requests (median 2.4-2.6).
- Kinds: search = Grep, Glob, and Bash `grep|rg|find|ls|wc|git grep|git log|show|diff`; reads = Read plus Bash `cat|sed|head|tail|jq|awk`.
- Cost is at list API prices: Opus 5.5 $4 / $20 per MTok input / output, cache reads $0.20 and 5-minute cache writes $5.
  Sonnet 5 is $2 / $10, with cache reads $0.20 and writes $2.50.
  Opus 4.8 is $5 / $25 with $0.50 reads, and Fable at its own rates.
  Each tool result's cost is one cache write plus a cache read on every later request.
- Scripts and TSVs live in the session scratchpad (`.../scratchpad/ctxsearch/`, ephemeral): `analyze.py`, `extra.py`, `cost.py`, `percall.py`, `readattr.py`.

## Key Findings

**Where context goes.**

| Population | n | Base | Peak median / p90 / max | Requests (median) | Cost median | Search tokens/agent | Search share of cost | Read share of cost |
|---|---|---|---|---|---|---|---|---|
| Implementer, Opus 5.5, clauthier | 29 | 39K | 163K / 329K / 401K | 52 | $3.72 | 13K | 3.7% | 15.5% |
| Reviewer, Opus 5.5, clauthier | 109 | 35K | 107K / 164K / 288K | 21 | $1.31 | 9K | 5.6% | 19.6% |
| Reviewer, Opus 4.8 or Fable, weftwise | 22 | 59K | 146K | 26 | $3.01 | 9K | 5.0% | 19.1% |
| Implementer, Opus 4.8 or Fable, weftwise | 62 | 55K | 330K / 695K / 999K | 129 | $18.30 | 4.5K | 1.6% | 24.6% |

- Growth from base to peak splits roughly evenly between tool results and the agent's own output (thinking, text, tool inputs):
  - clauthier implementers: 129K median growth = about 63K tool results + 55K output + 11K attachments.
  - weftwise implementers: about 120K tool results + 71K output.
- Cost splits about a third each across cache reads, cache writes, and output (138 Opus 5.5 implementers and reviewers: 35 / 35 / 30%).
- Search calls are small: the median is 265-593 tokens per call.
  Calls of 2K tokens or more are 17% of clauthier search calls (60% of search tokens) and 4% of weftwise implementer search calls (28%).
- Reads dominate, and most of what is read is needed:

  | Population | Read tokens/agent | Files the agent edited | cdocs proposal, devlog, or review | Never-edited source (exploratory) |
  |---|---|---|---|---|
  | clauthier implementers | 47K | 16% | 46% (+21% other cdocs) | 11% (5K) |
  | clauthier reviewers | 34K | 38% (target and own review) | 25% (+12% other cdocs) | 16% (5K) |
  | weftwise implementers | 104K | 53% | 16% | 28% (30K) |

- The search guidance is not followed today.
  Across 167 cdocs implementers and reviewers in this window, there were 0 `Explore` dispatches and 2 `bash-runner` dispatches (from one implementer), against 1,400+ search calls the agents ran themselves.
  All 19 `Explore` runs came from overseers or top-level sessions (task sampling, surveys).

**What a searcher costs.**

| Agent | Model (observed) | Base | Peak (median) | Cost median | Wall median | Returns |
|---|---|---|---|---|---|---|
| `Explore` (19 runs) | Sonnet 5 | 16K, no CLAUDE.md or rules | 63-69K | $0.31 clauthier, $0.43 weftwise | 100 s | 3-20K chars (about 1-8K tokens) |
| `bash-runner` (49 runs) | Sonnet 5 / 5.5, Haiku 4.5 | 11-12K, includes CLAUDE.md and rules | 13-15K | $0.02-0.05 | 7-26 s | at most about 600 words |
| Phase 4 grep arm (8 tasks) | Sonnet 5 | n/a | 61-107K | n/a | 73-240 s | 84/106 important items (79%) |

- Fixed overhead per dispatch is 11-16K tokens.
  Little of it is cached across dispatches: on the first request, searchers read about 3K from cache and write 9-12K, and reviewers read 16K and write 25K.
  That overhead is 20-50 times a median search result, so a dispatch pays only for a multi-step sweep whose intermediate output is far larger than its answer.
- The cheaper-model lever is weak on Opus 5.5.
  Sonnet 5 is half price on input, output, and cache writes, but cache reads cost the same ($0.20).
  Re-pricing the 19 `Explore` runs' exact token counts at Opus 5.5 rates gives 1.63 times the Sonnet cost, not 2 times.
- A custom cdocs agent would carry CLAUDE.md and the cdocs rules (about 7K tokens, seen in `bash-runner`'s base).
  `Explore` skips them, and no frontmatter field lets a custom agent do the same ([sub-agents docs](https://code.claude.com/docs/en/sub-agents.md), via `claude-code-guide`).
- Latency is serial: a searcher dispatched mid-task blocks the implementer or reviewer for about 100 s.
  In interactive sessions it also forces a turn boundary, because subagent dispatch is async there and the caller is woken by the child's notification ([context preservation report](2026-10-08-subagent-context-preservation-options.md), findings 2 and 4).

**Accuracy.**
- Sonnet discovery is incomplete: Phase 4's sonnet arms found 74-79% of important items (graph arm 78/106, grep arm 84/106), with 1-2 wrong items and 1-3 "would mislead" items over 8 tasks.
- The risk lands on absence claims ("nothing else calls X"), which are the claims a reviewer most needs to be right.
- `review_proof` counts only runtime artifacts the reviewer's own round produced, so a searcher's summary is never admissible evidence.
  A reviewer who leans on a delegated "no other callers" claim has a gap the Iteration Log cannot see.
  The rule that matches `reviewer.md`'s media rule: a searcher's findings are leads.
  The reviewer opens each `file:line` it relies on, and runs its own grep for any claim that something is absent.

## Options

| Option | Saves (per agent, best case) | Costs | Fit with maintainer preferences |
|---|---|---|---|
| a. Status quo plus guidance: `Explore` for wide discovery sweeps, `bash-runner` for verbose commands (already a rule) | Large-repo implementers only: some of the 30K exploratory read tokens | One guideline line; no new parts | Best: a guideline, nothing to maintain |
| b. Dedicated `cdocs:searcher` (sonnet, fixed `file:line` report like `bash-runner`) | Same as (a) | An agent file and its upkeep; about 7K more base than `Explore` (CLAUDE.md and rules); same completeness risk | Adds a part whose only gain over `Explore` is a fixed format, which a prompt can ask for |
| c. Overseer-side prep brief before each implementer or reviewer dispatch | clauthier: 5K exploratory reads + 13K search, about $0.3-0.5 at most. weftwise implementers: about 35K tokens, about $1.3 net if it halves exploration (about 7% of $18.30) | $0.31-0.43 and about 100 s on the critical path every dispatch; it does not cover proposal, devlog, or edited-file reads; 21-26% misses; anchors the reviewer, whose value is independence | A new mechanism in the loop; break-even or worse on clauthier-scale work |
| d. Drop graphify | Its runs cost about 400-480 tokens per graph call (graphify-workstream agents only, not representative); no measured context saving to lose (Phase 4: neither arm cheaper) | Deletions below | Fewer moving parts, one less dependency |

How (c) differs from the graphify base query it would replace:
- The base query was one cheap call the agent ran itself, returning structure it then explored.
- A prep brief is precomputed answers from another model, paid on every dispatch, with a known miss rate and no way for the reader to tell what it missed.
- The devlog's Changes Made table and Scratchpoint already give a fresh reviewer its starting files at no cost.

## Recommendations

Adopt (a) with (d).
Confidence: high that (b) and (c) do not pay on tokens, cost, or wall time for this repo's loops; medium that the (a) guideline measurably helps weftwise-scale implementers (not measured).

- Replace the graphify bullet in "CDocs Tool Use Guidance › Tools and Skills" with one line, roughly:
  "For a discovery sweep whose raw output you won't need (who uses X across packages, orienting in an unfamiliar package), dispatch `Explore` and ask for `file:line` findings; open each line you rely on, and grep yourself before claiming something is absent."
- Add no agent and no prep pass.
- The bigger levers sit outside search, are not measured here, and are listed only as pointers:
  - Per-phase implementer dispatch, already in "CDocs Workflow Patterns › Loops and multi-phase plans": weftwise peaks track request count, with a median of 129 requests and a 999K max.
  - Narrow reads of long cdocs: implementers read 31K tokens per agent of proposals, devlogs, reviews, and reports.
  - The fixed base: about half of the 35-55K is tool schemas.

### If graphify goes (pointers only, no edits made)

- `plugins/cdocs/skills/graphify/` (skill), `plugins/cdocs/bin/cdocs-graphify`, and its section in `plugins/cdocs/bin/README.md` (from line 67).
- `plugins/cdocs/hooks/tests/cdocs-graphify.test.sh` and its step in `.github/workflows/cdocs-hooks.yml` (lines 3, 64-65).
- `plugins/cdocs/rules/tool-use-safeguards.md:7-8` (the graphify bullet; `npm run test:rules` checks heading references).
- `plugins/cdocs/skills/iterate/SKILL.md` "Base query" section (lines 37-42, including the `[base_query: ...]` row tag) and `iterate/template.md:8`.
- `plugins/cdocs/skills/devlog/SKILL.md:64-65` and `devlog/template.md:20` (`graphify_base_query`).
- `plugins/cdocs/skills/init/SKILL.md:97-100` (the `.graphifyignore` step).
- `plugins/cdocs/README.md:50,54`, and the skill list in `CLAUDE.md:50`.
- Repo files: `.graphifyignore`, the `graphify-out/` lines in `.gitignore:18-19`, and the `graphify/index` mount in `.lace/mount-assignments.json:75-77` (its lace feature source is outside this repo).
- Keep `scripts/detect-usage.sh`: graphify appears there only as an example.
- Proposals to mark `archived` or `evolved`: `cdocs/proposals/2026-10-08-graphify-fork-rfp.md`, `2026-10-08-graphify-overhaul.md`, `2026-09-17-graphify-cdocs-integration.md`, and `2026-09-17-graphify-lace-devcontainer-enablement.md`.
- In weftwise, the `"source"` export conditions are worth keeping on their own merits; its `.graphifyignore` can go.

## Not Measured

- Quality: whether a brief or `Explore` changes the correctness of an implementation or the recall of a review.
  No A/B was run; the accuracy figures are Phase 4's discovery tasks, not loop work.
- Thinking tokens: whether they persist in context is inferred from growth arithmetic, not read from the API.
- Tokens: per-result counts are char-ratio estimates (about ±15%).
  The weftwise implementer sample is `general-purpose` dispatches matched by description, mostly Opus 4.8 at different prices, and includes sessions that hit compaction.
- Cost: list API prices are a proxy; subscription billing differs.
  Sonnet 5.5 pricing (some `bash-runner` runs) was not in the pricing reference and is assumed equal to Sonnet 5.
- `Explore`'s default model: Sonnet 5 was observed in all 19 runs, while the docs describe it as platform-dependent.
  Its thoroughness levels are undocumented.
- Whether `Explore` guidance would actually be followed: the existing `bash-runner` rule mostly is not (2 dispatches).
