---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-20T09:40:00-07:00
task_list: meta/token-spend-attribution
type: report
state: live
status: review_ready
tags: [meta, tooling, cost, retrieval]
---

# Read-Source Attribution: Where Context Intake Comes From

> BLUF(opus/read-source-attribution): Over the last 7 days of weftwise work, one-time context intake (tool-result bytes read into agent context) totals ~13.2M approx-tokens, and **codebase file reads are the single largest source at 54.7%** (7.20M tok), ahead of Bash command output (28.5%, 3.76M tok) and logs/devlogs (9.3%, 1.23M tok).
> Playwright DOM (3.5%), tool scaffolding (3.3%), and web fetch/search (0.7%) are minor.
> Intake is not the bill: the bill is cache-read (3.94B tok this week, per the by-role report), and intake is the principal that gets re-sent ~299x across a session's turns.
> The highest-savings lever is therefore graphify-scoped codebase retrieval: replacing whole-file `Read` (mean 2,066 tok/result, heaviest 15-18K each) with symbol/span retrieval attacks the largest and most-amplified intake bucket at its source.
> Cross-reference the sibling spend-by-role breakdown: [`cdocs/reports/2026-09-20-token-spend-by-role.md`](2026-09-20-token-spend-by-role.md).

## Method

- Source: Claude Code session transcripts (JSONL) under `~/.claude/projects/<encoded-path>/`, both the container layout (`-workspaces-weftwise-*`) and the host layout (`-var-home-mjr-code-weft-weftwise-*`).
- Read volume is measured as the character length of each `tool_result`'s **inline** content (the text actually delivered into model context: `message.content[]` where `type=="tool_result"`), approx-tokens = chars / 4.
- Each `tool_result` was joined within its own file to its originating `tool_use` (by `tool_use_id`) to recover the tool name and, for `Read`/`Bash`, the file path / command, which drives source categorization.
- Subagent tool activity lives in separate files (`<session-uuid>/subagents/agent-*.jsonl`), not inline in the main session file, so the scan walks both. This matters: subagent transcripts carry ~95% of all read volume.
- Scope: weftwise only (`cwd` contains "weftwise") and last 7 days (`timestamp >= 2026-09-12T00:00:00Z`), filtered per line. This matches the sibling report's scope.
- Coverage: 2,943 files scanned (195 main-session, 2,748 subagent), 603,075 lines, 20,688 in-scope tool_results. The tool_use/tool_result join was clean: 0 unmatched, 0 chars of leakage, 0 skipped files.
- No raw transcript content was loaded into any LLM context. All tallying is done by a Node 24 streaming script (`node:readline` + `node:sqlite`); agents read only aggregated numbers.
- The usage-DB cross-check queries the `turns` table of the plugin snapshot for cache/output token totals over the same scope.

### Caveats

- **Approximation.** Tokens ≈ chars / 4. Code and markdown tokenize differently from prose, so absolute token counts are approximate; the ranking and the percentage shares are robust to this.
- **Intake is the principal, not the amplified bill.** This report measures one-time intake (bytes read once). The actual spend driver is cache-read (each intake byte re-sent on every subsequent turn it stays resident). The measured amplification this week is intake 13.2M vs cache-read 3.94B, ≈ **1 : 299**.
- **Per-source amplification is not measured, and is not uniform.** A read pulled into a long-running overseer or iterate-loop context is re-sent across far more turns than a one-off subagent read that is discarded when the subagent ends. Applying the intake shares directly to the cache-read total (the projection below) assumes source-independent amplification, which is an approximation, not a measurement. Treat the projection as illustrative.
- **Categorization is heuristic at the margin.** `Read` is split codebase-vs-logs by path (`/cdocs/devlogs/`, `*.log`, `*.output` count as logs/devlogs; everything else, including `cdocs/proposals/*.md`, counts as codebase). `Bash` is split by command regex (a `cat`/`tail`/`head` of a log/devlog/output file counts as logs/devlogs, else command output). A `Bash cat` of a `.ts` file therefore counts as command output, not codebase; some boundary misclassification is expected but does not move the top-line ranking.
- **Truncation is negligible here.** Inline content is what enters context; for Bash the raw `stdout`+`stderr` payload (`toolUseResult`) was only ~5% larger than the inline content, so truncation-to-disk is not materially hiding volume in this corpus.

## Read volume by source

| Source | Approx tokens | % of intake | Tool-results | Main | Subagent |
|---|---:|---:|---:|---:|---:|
| **Codebase reads** (`Read`/`Grep`/`Glob` of repo files) | **7,200,990** | **54.68%** | 3,670 | 220,225 | 6,980,766 |
| Command output (`Bash` stdout/stderr) | 3,756,782 | 28.53% | 9,581 | 169,054 | 3,587,728 |
| Logs/devlogs (`Read`/`Bash cat` of `*.log`, `cdocs/devlogs/*`, `*.output`) | 1,226,555 | 9.31% | 717 | 118,755 | 1,107,800 |
| Playwright DOM (`browser_*` results) | 457,773 | 3.48% | 1,308 | 747 | 457,026 |
| Other/tool scaffolding (`Edit`/`Write`/`Agent`/`Artifact`/`SendMessage`/...) | 433,715 | 3.29% | 5,253 | 173,898 | 259,817 |
| Web (`WebFetch`/`WebSearch`) | 93,808 | 0.71% | 159 | 0 | 93,808 |
| **Total** | **13,169,623** | 100% | 20,688 | 682,679 | 12,486,945 |

Subagents account for 12.49M of 13.17M intake tokens (~95%): the top-level session reads little; the dispatched fleet does the reading.

## Tool distribution weighted by result size (cross-check)

Call count is a poor proxy for read volume.
`Read` is 63% of intake volume from 4,022 results, while `Bash` has 2.5x the call count (9,928) but a mean payload 5.3x smaller.

| Tool | Approx tokens | % of intake | Calls | Mean tok/result |
|---|---:|---:|---:|---:|
| `Read` | 8,310,946 | 63.11% | 4,022 | 2,066 |
| `Bash` | 3,870,731 | 29.39% | 9,928 | 390 |
| `browser_snapshot` | 237,270 | 1.80% | 101 | 2,349 |
| `Edit` | 186,230 | 1.41% | 3,763 | 49 |
| `Agent` | 101,159 | 0.77% | 385 | 263 |
| `browser_evaluate` | 99,379 | 0.75% | 403 | 247 |
| `Artifact` | 96,378 | 0.73% | 45 | 2,142 |
| `WebSearch` | 48,062 | 0.36% | 69 | 697 |
| `browser_console_messages` | 47,579 | 0.36% | 55 | 865 |
| `WebFetch` | 45,746 | 0.35% | 90 | 508 |
| `Write` | 29,761 | 0.23% | 628 | 47 |

The heaviest per-result tools are `Read` (2,066), `browser_snapshot` (2,349), and `Artifact` (2,142).
Of these only `Read` is also high-volume; `browser_snapshot` and `Artifact` are large-but-rare.

## Heaviest individual sources

- The top 15 single tool-results are all whole-file `Read` results in the codebase bucket, 15,070-17,745 approx-tokens each.
- **Repeat re-reads of the same file across sessions are a distinct waste pattern**, separate from the per-turn re-send. Observed repeats: a loro-fork-lineage proposal read 6x (~16.0K tok each), a command-deer adoption devlog read 4x (~16.1K tok each), plus a branchabledoc frontier-model proposal and a `document_store.ts` in the 15-16K range. Each such re-read is a fresh whole-file intake that then amplifies independently.
- Read volume is highly concentrated by session: the top 2 of ~40 in-scope sessions account for ~75% of all intake (5.13M and 4.78M approx-tokens), consistent with a small number of long-running iterate/oversee loops dominating the corpus.

| Session (short) | Approx tokens | Tool-results |
|---|---:|---:|
| 8b00eeaa… | 5,132,660 | 8,729 |
| ef808534… | 4,780,095 | 6,785 |
| c636fc88… | 1,289,972 | 1,931 |
| c970ef59… | 650,899 | 901 |
| f66b3d45… | 645,884 | 1,469 |

## Reread waste and the logs/devlogs drill

Two follow-on drills (full tables in the methodology handoff, [`2026-09-20-claude-usage-attribution-handoff.md`](2026-09-20-claude-usage-attribution-handoff.md)):

- **Reread waste is the largest single lever, and it is invisible in `usage.db`.** About 4.7 to 5.0M whole-file `Read` tokens (~70% of whole-file-read volume) are redundant re-reads of a file already read whole. A root-cause reclassification at transcript granularity (one `.jsonl` is one context window; the earlier session-granularity figure conflated a parent with its subagents, which share one `session_id`) shows the redundancy is almost entirely CROSS-AGENT, not within-agent thrash: 97.4% is a fresh subagent or a later session reading the file cold in its own context, only 2.2% is one context re-reading itself, compaction-eviction is 0.33%, and edit-then-verify is negligible (0.05%). The worst offender, `packages/loro-repo/src/repo/loro_repo.ts` (45 whole-file reads across 3 sessions), is ~97% cross-agent. The implication: this is not a "don't re-read" discipline problem (different agents cannot share a context window) but a missing SHARED RETRIEVAL CACHE across agents and sessions; graphify symbol-scoped retrieval is complementary (it cheapens each cold read, it does not dedupe them). Distinct from, and additive to, the per-turn cache re-send.
- **The logs/devlogs bucket is devlogs, not `.log` slurping.** `cdocs/devlogs/*` is 89.3% of the bucket (8.2% of intake); literal `*.log` files are only 5.5% of the bucket (0.51% of intake) and `*.output` task transcripts 1.7% (0.16%). So the 9.3% is overwhelmingly devlog re-reading. Devlog whole-file reads span min 22, median 3,385, max 14,860 approx-tokens; two devlogs are read whole 10 and 21 times. This is the retrieval-side case for the wiki-like devlog RFP in recommendation 4.

## Amplification and the projected cache-read attribution

The usage-DB snapshot over the same scope reports cache-read of **3,942,012,148 tok** (subagent 85.1%, top-level 14.9%), cache-creation 113M, output 21.6M.
Intake (13.17M) to cache-read (3.94B) is ≈ 1 : 299: every intake byte is re-sent, on average, across ~299 subsequent turns.

Applying the intake source-shares to the cache-read total (illustrative only, assuming source-independent amplification, see caveats) projects roughly:

| Source | Intake share | Projected cache-read (tok) |
|---|---:|---:|
| Codebase reads | 54.68% | ~2.16B |
| Command output | 28.53% | ~1.12B |
| Logs/devlogs | 9.31% | ~367M |
| Playwright DOM | 3.48% | ~137M |
| Other/tool scaffolding | 3.29% | ~130M |
| Web | 0.71% | ~28M |

If anything this understates codebase dominance: whole-file codebase reads tend to be loaded early and held resident through an implement/review loop, so their real amplification is likely above the corpus average, while a verbose one-off Bash dump is often superseded quickly.

## Recommendations, ranked by savings potential

1. **Graphify-scoped codebase retrieval (highest savings).** Codebase reads are 54.7% of intake and the most-amplified bucket; whole-file `Read` averages 2,066 tok and the heaviest are 15-18K each. Replacing "read the whole file" with symbol/span/definition retrieval (the graphify integration already in progress) attacks the largest line item at its source. A conservative 50% reduction of the codebase bucket removes ~3.6M intake tok/week, projecting to ~1.1B cache-read tok at the corpus amplification factor: larger than the entire non-codebase intake combined.
2. **Prompt-cache reuse across a loop's turns, plus de-duplicating cross-session re-reads.** The 1:299 amplification, not intake size, is the true multiplier. Two distinct wins: (a) ensure the iterate/oversee loop reuses the prompt cache across implementer turns rather than re-establishing context, so resident intake is charged at cache-read not cache-write and is not re-fetched; (b) a shared retrieval cache so the same proposal/devlog is not independently whole-file-read 4-6x across sibling sessions. Both reduce the amplified footprint without changing what any single agent sees.
3. **Result-scoping and truncation for Bash command output.** Command output is 28.5% of intake from 9,581 results (mean 390 tok). It is death-by-a-thousand-cuts rather than a few whales: the lever is prompting agents to scope commands (targeted queries, `--quiet`, head-limited output, no full-tree dumps) and enforcing a tighter default truncation on verbose stdout. Lower per-result ceiling, high aggregate payoff. A stronger version of this lever: route verbose or log-spammy Bash through a dedicated haiku subagent that runs the command and returns only the salient extract. The logspam then never enters the parent (Opus) context at all, and its lifetime is bounded to the disposable subagent rather than resident for the rest of the session, so it also escapes the ~299x re-send amplification. This trades a small haiku dispatch cost for removing both the intake and its amplification on the parent.
4. **Section-scoped reads of logs/devlogs (9.3%).** Devlogs and proposals are read wholesale (this bucket overlaps recommendation 1's retrieval mechanism). Retrieving the relevant section rather than the whole document, and pointing agents at a handoff summary rather than the full chronological devlog, cuts this bucket. Same tool as graphify retrieval, applied to `cdocs/`. Beyond retrieval, cdocs should RFP a granular, wiki-like devlog structure: today a devlog is one growing chronological file read whole, so a sectioned and cross-linked layout (one file per phase or concern, linked from an index) would let an agent pinpoint the relevant slice, reduce whole-file re-reads, and give subagents clearer agency over their own devlog files. This is the retrieval-side complement to the by-role report's finding that 13-46KB devlogs drift into transcript-shaped chronologies.
5. **Deprioritize Playwright DOM and Web.** Playwright DOM (3.5%) has large per-result snapshots but a small aggregate; scoping snapshots (element-scoped over full-page) is a real but minor win. Web (0.7%) is negligible and not a cost center despite the intuition that fetches are large. Tool scaffolding (3.3%) is largely irreducible echo (`Edit`/`Write`/`Agent` acks) and not worth targeting.

## Context-management primitives available (verified 2026-09-20)

What the platform currently allows for shrinking or evicting resident context, which bounds the recommendations above:

- **Agent-initiated eviction of a specific read: not available in Claude Code.** The Anthropic API has server-side context editing (`clear_tool_uses_20250919`) that drops stale tool results once a token or tool-use threshold is crossed, but it is developer-configured, applied automatically server-side, and not exposed to the running agent (which sees only placeholders); it is API-only and not surfaced in Claude Code. See [context editing](https://platform.claude.com/docs/en/build-with-claude/context-editing.md). The only agent-controllable eviction boundary today is subagent return: a subagent's tool results vanish when it returns, leaving only its summary. This is why the haiku-bash-wrapper (recommendation 3) is the practical eviction mechanism, not a nicety. The memory tool is cross-session storage, not mid-session eviction.
- **`/compact` is steerable but does not preserve full user history.** `/compact [instructions]` accepts custom guidance (interactive only); project-root `CLAUDE.md` and unscoped rules re-inject on compaction, and the most recent user turns survive verbatim, but the middle of the conversation (including earlier human turns) is summarized, not preserved. See [compaction explained](https://okhlopkov.com/claude-code-compaction-explained/). A persistent compaction-instructions setting was requested ([claude-code #14160](https://github.com/anthropics/claude-code/issues/14160)) but is not standard; a `SessionStart`/`PreCompact` hook with a `compact` matcher can re-inject critical context after a compaction.
- **Auto-wrapping Bash through a subagent: convention-only.** No PreToolUse setting substitutes a subagent's result for a Bash call (hooks allow/deny/annotate only). A PostToolUse hook can deterministically rewrite or truncate Bash output before the agent reads it (`updatedToolOutput`, Claude Code v2.1.121+), a zero-LLM-cost partial win, but LLM distillation of logspam must be a manual haiku dispatch.

## Bottom line

Retrieval cost is dominated by reading source files whole and re-sending them across long loops.
The by-role report shows retrieval is 96% of the bill; this report localizes that retrieval: over half of it is codebase file intake, and it is concentrated in a few long-running subagent-driven loops.
Graphify-scoped retrieval plus loop-level cache reuse target the two multiplicative factors (intake size and re-send amplification) that together produce the spend.
