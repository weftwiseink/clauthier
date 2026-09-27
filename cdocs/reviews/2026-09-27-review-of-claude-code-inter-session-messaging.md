---
review_of: cdocs/reports/2026-09-27-claude-code-inter-session-messaging.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-27T09:21:52-07:00
task_list: cdocs/audio-interaction
type: review
state: live
status: done
tags: [fresh_agent, factual_accuracy, auth_policy, cross_session_messaging, bridge_design, brevity]
---

# Review: Native session-to-session messaging in Claude Code

## Summary Assessment

The report answers the user's question ("is there a native session-to-session interface, and does it work on a subscription?") correctly at the top level.
The native interface is cross-session messaging (`ListAgents`/`SendMessage`), and it is subscription-compatible.
The report's claims about the [cross-session messaging page](https://code.claude.com/docs/en/cross-session-messaging) are almost all accurate.
The overseer's own session corroborates them: `ListAgents` reaches 8 local tmux sessions and 5 Remote Control sessions under subscription auth.

The report's "bigger correction", however, is overstated. It says the Agent SDK "is not usable on a claude.ai subscription at all", and that premise drives the redesign.
The doc language restricts *third-party developers offering* claude.ai login to their users, and it explicitly permits an end user running the unmodified Claude Code binary on their own subscription. `claude -p` uses the subscription login unless started with `--bare`.
The report also misses a documented path that simplifies its recommended design: a non-Claude process can post directly into a session's inbox socket.
I corrected the factual claims in place. The design section needs reworking by the author.
Verdict: **Revise**.

## Fact-check results

### (1) Cross-session messaging page

- **Page exists; content matches the report:** confirmed.
- **"GA": not stated by the docs.** The page says messaging is "on with nothing to enable" from v2.1.224 and carries no research-preview note. "GA" is an inference, so I reworded it to "on by default, no preview label".
- **Unix sockets: confirmed.** Same-machine delivery uses a per-session Unix domain socket (a named pipe on native Windows) and never goes through Anthropic servers.
- **Idle wake: confirmed verbatim.** "When the receiving session is idle, Claude Code starts a new turn with the message."
- **`crossSessionInbound`: confirmed.** The values are `accept`, `hold` and `refuse`. The report missed one nuance (fixed): per the settings reference, a *project or local* value applies only when it is stricter. A `.claude/settings.json` `accept` in the repo therefore does nothing; `accept` must come from `--settings`, user settings or managed settings.
- **Bypass-mode hold: confirmed.** A receiver that bypasses permission prompts holds each message "for your approval", and delivers only when the sender also bypasses. Nuances the report missed (fixed or noted):
  - In a background session with no terminal attached, the approval dialog stays open past `dialogExpiry`.
  - At most 100 held messages are kept.
  - A companion that itself runs in bypass mode gets delivered without any setting change.
- **Other claims confirmed:** the 1M-character cap, the 50-message queue, `isolatePeerMachines`, the one-way reply-address rule, `notify_when_idle` (main conversation only, same machine only, one notice, 12h expiry), and `-p` sessions binding a socket unless `--bare`.
- **Contradiction (fixed):** the table and "Answering directly" item 4 said the docs *confirm* that cloud sessions cannot reply. The docs say no such thing; that comes from the overseer's tool description. It also contradicted the report's own Key Finding and Unverified list. It is now marked unverified.

### (2) Agent SDK and subscription OAuth

- **The quote is exact** ([agent-sdk/overview](https://code.claude.com/docs/en/agent-sdk/overview)): "Unless previously approved, Anthropic does not allow third party developers to offer claude.ai login or rate limits for their products, including agents built on the Claude Agent SDK. Use the API key authentication methods described in the Quickstart instead."
- **Its scope is narrower than the report claimed.** The [legal and compliance page](https://code.claude.com/docs/en/legal-and-compliance) says:
  - Developers building products "should use API key authentication".
  - "Anthropic does not permit third-party developers to offer Claude.ai login into their own applications, or to route requests through Free, Pro, or Max plan credentials on behalf of their users."
  - It does not "prevent an end user from signing in to the unmodified Claude Code binary with their own Claude subscription".
  - "Advertised usage limits for Pro and Max plans assume ordinary, individual usage of Claude Code **and the Agent SDK**."
- **`claude -p` is not restricted.** The headless page documents `claude -p` as "the Agent SDK via the CLI". Only `--bare` "doesn't use your subscription login" and requires `ANTHROPIC_API_KEY`. Plain `claude -p` uses the user's own subscription login.
- **Conclusion:** personal use of the Python/TypeScript SDK packages on one's own subscription is ambiguous, not "not usable at all". Driving the unmodified CLI (including `claude -p --input-format stream-json`) on one's own subscription is permitted.
- The report was internally inconsistent here: its SDK table row said "No" while its top-ranked design 1 relies on `claude -p` being "subscription-native, no ToS risk". Fixed in the BLUF, Key Findings, the table row, the section-(ii) bullet and revision #1.

### (3) The six revisions to the voice-companion report

1. **Wrong as written (fixed).** Hosting the overseer is not removed. On a subscription it should drive the unmodified CLI in stream-json mode rather than the SDK packages.
   The CLI form gets permission requests through `--permission-prompt-tool` rather than the SDK's `canUseTool`; the author should say so.
2. **Correct**, with two additions: the bypass-mode hold caveat, and the rule that a project-scope `accept` does not apply.
3. **Correct.** It should also name direct socket posting (finding B2).
4. **Correct.** The channels docs say "Pro and Max users without an organization skip these checks entirely".
5. **Correct.**
6. **Correct**, but it only works if the companion is itself a Claude Code session: a main conversation on the same machine. The notice fires once, so the companion must re-subscribe after every notice.

### (4) The subscription-compatibility column

| Row | Verdict |
|---|---|
| Cross-session messaging | Correct (same-machine: any provider; beyond: claude.ai sign-in via Remote Control) |
| `notify_when_idle` | Correct |
| Agent teams | Correct. Experimental, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`; teammates not spawned under `-p`/SDK |
| Channels | Correct. The "undocumented flag" wording was wrong: the flag is documented but hidden from `--help` (fixed) |
| Remote Control | Correct. "Pro, Max, Team, and Enterprise ... API keys are not supported". The `FetchInboxMessage`/`rc_owner`/`session-inbox` details come from tool descriptions, not docs; label the source |
| `claude agents --json` | Correct |
| Cloud sessions | Correct on auth; the reply claim is fixed as above |
| Routines | Correct on plans. Maturity was wrong: the routines docs say research preview, with the `/fire` API behind a beta header (fixed). The claim that a routine can post into an existing session appears nowhere in the routines page; drop it rather than keep it in the Unverified list |
| Hooks | Correct. The `agent_needs_input`/`agent_completed` notification types fire only while agent view is open in a terminal (fixed) |
| SDK / `claude -p` | Was wrong; fixed as above |
| MCP bus, files + Monitor | Correct |

## Minor fixes applied directly

- **BLUF:**
  - "GA" became "on-by-default (not labeled preview)".
  - The `crossSessionInbound: accept` scope is now stated (`--settings` or user settings; a project file does not apply), and a bypass-mode sender is given as an alternative.
  - The SDK "not usable at all" claim is rewritten to its documented scope.
- **Key Findings:**
  - The SDK bullet is retitled and the legal-page scope quotes added.
  - The subscription bullet's "SDK gated away from subscriptions everywhere" is corrected.
  - The `-p` bullet's leftover self-correction ("... actually the hold direction to check is symmetric") is rewritten as a single accurate statement.
- **"The native interface, in full":**
  - The address-syntax sentence now mentions the disambiguating identifier.
  - The held-dialog bullet now covers background sessions and the 100-message cap.
  - The trust-model sentence now separates what the harness enforces (prompts, commands) from what is instruction-level (config changes).
  - The maturity line no longer says "GA".
- **Inventory table:**
  - Cross-session maturity.
  - Channels flag wording.
  - Cloud-session discovery and reply rows.
  - Routines maturity.
  - Hooks notification types.
  - SDK / `claude -p` subscription cell.
- **Section (ii)** launch-flag bullet, "Answering directly" item 4, and revision #1.

The word count grew from 3846 to about 4130 as a result. See N1 for cuts.

## Section-by-Section Findings

### Blocking

**B1. The companion designs and the Recommended combination were ranked on the wrong premise about SDK auth.**
The facts are corrected, but the design section still treats "companion hosts the overseer" as off the table.
The CLI-hosted form, `claude -p --input-format stream-json --output-format stream-json` with `--permission-prompt-tool`, runs the unmodified binary on the user's own subscription. It is the one option in which the companion sees *every* permission request and question natively.
Re-rank it against designs 1-4, weighing its cost: `/oversee` is no longer launched from an ordinary terminal.

**B2. Missed: a non-Claude process can post straight into a session's inbox socket.**
The docs' "session's inbox socket" section is explicitly for when "you want a script or hook to post into a session".
- The socket is a per-user Unix socket. Its path is exported to the session's hooks and Bash commands as `CLAUDE_CODE_MESSAGING_SOCKET`, so an overseer `SessionStart` hook can publish the path to a known file.
- On Linux the auth line is optional.
- A message from a process that is not the session's own child "asserts no permission class". It is delivered to a prompting-mode overseer and held by a bypass-mode one, which the `--settings` `accept` resolves.
- For write-back, this can remove design 2's "small dedicated Claude Code proxy session": the Pipecat process posts the condensed answer itself.
- The *reverse* direction (overseer to companion) still needs the companion to be a Claude session (`SendMessage`, `notify_when_idle`) or to poll `claude agents --json`, so a hybrid is likely best.
- The message-line wire format after the auth line is not spelled out on that page. Verify it empirically (for example with `socat` against a scratch session) before relying on it, and list it as unverified until then.

### Non-blocking

- **N1 (brevity):** idle wake is stated four times and the bypass-mode hold four times, across the BLUF, Key Findings, "The native interface, in full" and "Answering the user's question directly".
  Fold "Answering directly" into a two-line answer plus a pointer to Key Findings, and keep delivery semantics in one place. This should recover about 600 words.
- **N2:** the report does not cite the overseer's own empirical evidence (subscription-auth `ListAgents` reaching 8 local tmux sessions and 5 Remote Control sessions). That is the strongest primary evidence that cross-session messaging works on a subscription today. Add it to Context or Key Findings.
- **N3:** design 1 should note that a companion Claude session in bypass mode gets messages delivered to a bypass-mode overseer with no settings change. It is a trade-off: the companion then acts without prompts.
- **N4:** design 1's "`CLAUDE_CODE_SUBAGENT_MODEL`-style overrides" is irrelevant. `--model` on the companion session is enough.
- **N5:** drop the routines "post into an existing session" claim, which has no support in the routines docs. The Unverified list can shrink accordingly.
- **N6:** the `notify_when_idle` design should state that the notice fires once and that `/oversee` idles after nearly every turn. The companion has to re-subscribe after each notice, which is fine but should be stated.

## Verdict

**Revise.**
The inventory and the cross-session messaging facts are sound after the in-place fixes.
The author must re-rank the companion designs now that the CLI-hosted overseer is back on the table (B1), and must evaluate direct socket posting as the thinnest write-back path (B2).

## Action Items

1. [blocking] Re-rank the companion designs and the Recommended combination. Include the CLI-hosted overseer (`claude -p` stream-json + `--permission-prompt-tool`) with its trade-offs; do not treat hosting as excluded.
2. [blocking] Add direct inbox-socket posting from a non-Claude process as a write-back option: path discovery via a `SessionStart` hook, and delivery or hold behavior by permission class. Verify the message-line format empirically or mark it unverified.
3. [non-blocking] Deduplicate the idle-wake and bypass-hold explanations; merge "Answering directly" into Key Findings.
4. [non-blocking] Cite the overseer's observed `ListAgents` reach as primary evidence.
5. [non-blocking] Note the bypass-mode companion alternative, drop the `CLAUDE_CODE_SUBAGENT_MODEL` aside, and drop the routines existing-session claim.
6. [non-blocking] State that `notify_when_idle` must be re-subscribed after every notice.
7. [non-blocking] Label the `FetchInboxMessage`/`rc_owner`/`session-inbox` details as sourced from tool descriptions.

## Questions for the user

1. Is hosting the overseer from the companion acceptable, which means `/oversee` runs under a companion-launched `claude -p` rather than your terminal?
   - (A) Yes, if it gets full permission-prompt visibility.
   - (B) No, keep launching `/oversee` yourself; use a sidecar only.
   - (C) Decide after the voice experiment.
2. For a bypass-mode overseer, how should the companion's messages be accepted?
   - (A) `crossSessionInbound: "accept"` via `--settings` at overseer launch.
   - (B) `accept` in user settings, which applies to every session.
   - (C) Run the companion in bypass mode too.

## Round 2

> BLUF: Both blocking items are resolved.
> The new specifics are mostly accurate, with three corrections applied inline: the `--permission-prompt-tool` argument, the `AskUserQuestion` routing claim, and the advice to publish the messaging token. `/oversee`-under-`-p` behavior is now scoped as documented or untested.
> Verdict: **Accept**.

### Round-1 items

- **B1 (re-rank with CLI hosting): resolved.**
  Design 0 ranks the CLI-hosted overseer first, conditional on the user accepting the companion as launcher, and states that cost plainly.
  The Recommended combination branches on that condition. The SDK-package gray area is stated with correct scope.
- **B2 (direct socket posting): resolved.**
  Design 2 drops the proxy session for both the read and write legs. It correctly notes that a non-Claude process cannot *receive* overseer-initiated pushes, and it flags the wire format for empirical verification.
- **Non-blocking items 3-7: all addressed.**
  - Idle wake and bypass hold are now stated once each.
  - The overseer's `ListAgents` reach is cited as primary evidence.
  - The bypass-mode companion trade-off is named.
  - The `CLAUDE_CODE_SUBAGENT_MODEL` aside and the routines existing-session claim are gone.
  - `notify_when_idle` re-subscription is stated.
  - The tool-description sourcing is labeled.

  The report is 3366 words, now 3506 after the fixes below.

### Verification of new specifics

- **`CLAUDE_CODE_MESSAGING_SOCKET` / `CLAUDE_CODE_MESSAGING_TOKEN`: names correct.**
  Per the cross-session docs, the socket path is exported to hooks and Bash commands "before any hook runs, including `SessionStart`", so publishing it from a `SessionStart` hook works.
  **Corrected:** the report suggested publishing the token too.
  - The auth line is optional on Linux, so the token is unnecessary.
  - The docs use the token as own-child evidence on macOS, in PID-1 containers and on native Windows. A poster verified as the session's own child is delivered even to a bypass-mode session when no `crossSessionInbound` value applies.
  - Publishing the token therefore risks letting any same-user process skip the default hold. The report now advises against it.
- **`--permission-prompt-tool`: partly corrected.**
  The CLI reference defines it as "an MCP tool to handle permission prompts in non-interactive mode". The report's `<mcp-tool-or-stdio>` argument is not documented; `stdio` is the SDK's internal control path. It is now `<mcp_tool_name>`.
  Two related facts the report leaves out but that are worth knowing:
  - `--permission-prompts host` (the default) sends prompts to that tool.
  - The tool cannot approve MCP tools marked as requiring user interaction.
- **"Every `AskUserQuestion` natively": softened.**
  Docs confirm `AskUserQuestion` reaches the SDK's `canUseTool` callback. Nothing documents it reaching a CLI `--permission-prompt-tool` MCP tool. The tools reference lists `AskUserQuestion` as not requiring permission, so it may not route there at all.
  This matters, because `/oversee` asks via `AskUserQuestion`. It is now marked as needing verification in design 0, the table row, and the Unverified list.
- **`/oversee` subagent dispatch under `-p` stream-json: not addressed by the report; now scoped inline.** Per the headless docs:
  - User-invoked skills expand in `-p`.
  - Background subagents keep a `-p` run open until they finish, with a 10-minute idle ceiling once stdin closes (`CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS`).
  - Subagent messages are tagged in the stream with `parent_tool_use_id`.
  - Terminal-only built-ins are unavailable.
  - Agent teams never spawn under `-p`, which does not affect `/oversee`'s subagent dispatch.

  A full arc (background dispatch, `SendMessage` to subagents, proactive `/compact`) under `-p` stream-json is untested. That is added to the Unverified list.

### Minor fixes applied directly (round 2)

1. `notify_when_idle` maturity: "GA" became "On by default", for consistency.
2. Design 0: the `--permission-prompt-tool` argument, the `AskUserQuestion` hedge, and the `-p` behavior scoping.
3. Inventory table: the CLI-hosting delivery cell now hedges on `AskUserQuestion`; the direct-socket cell advises against publishing the token.
4. Unverified list: added the design 0 specifics.

### Remaining non-blocking

1. Before building design 0, run a scratch arc under `claude -p --input-format stream-json` with a stub MCP prompt tool. That settles both the `AskUserQuestion` routing and `/oversee`'s behavior in one step.
2. Before building design 2, do the `socat` wire-format test. Also confirm that a published socket-path file is readable only by the user; the socket itself is already user-restricted.

### Round-2 verdict

**Accept.**
The report answers the native-interface and subscription questions accurately, and it ranks designs on correct premises.
It honestly scopes the two design-specific unknowns as pre-build verification steps.
