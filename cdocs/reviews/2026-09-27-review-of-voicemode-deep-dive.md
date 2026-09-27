---
review_of: cdocs/reports/2026-09-27-voicemode-deep-dive.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-27T09:48:25-07:00
task_list: cdocs/audio-interaction
type: review
state: live
status: done
tags: [fresh_agent, source_verification, setup_checklist, permission_classes, incrementalism, cost]
---

# Review: VoiceMode deep dive

## Summary Assessment

The report reads VoiceMode's source to decide whether a dedicated Claude Code "conversationalist" session running VoiceMode can bridge the user to their overseers via native `SendMessage`.
The source reading is strong. Every file:line citation checked against the clone (`126d15e`, 2026-09-15) is accurate:

- `converse.py:4308`, `:1335` and `:2883`
- `control_channel.py:44`
- `config.py:777-778` and `:945-978`
- the `conch_notify.py` `session send` nudge and the `_remote_marker` no-op

The recommendation, option (A) then (B), honors the user's incremental, low-dev-time constraint.

Two problems remain:

- **The setup checklist was broken in ways that would not have worked as written** (now fixed inline):
  - A user-scope plugin install would have put VoiceMode's MCP server and six earcon hooks into every `/oversee` session.
  - The permission-mode advice pointed the wrong way: bypass mode *causes* holds from prompting senders; it doesn't sidestep them.
- **The recommended always-listening `converse()` loop has an unaddressed cost** (blocking): a model call every 10-20 seconds of silence.

Verdict: **Revise**.

## Verification of the five focus areas

### (1) Blocking `converse` and queued `SendMessage` delivery

- **The core reasoning is sound.** A session awaiting an MCP result is mid-turn, and per the cross-session docs a message "reads ... between tool calls during an active turn". It therefore queues until `converse()` returns.
- **The auto-backgrounding question is answerable from the docs, and I resolved it inline.** Per the [MCP docs](https://code.claude.com/docs/en/mcp#automatic-backgrounding-of-long-tool-calls), a main-conversation MCP call still running after two minutes "moves to a background task": Claude gets a task ID immediately, keeps working, and gets the result later as a task notification.
- **This interacts badly with the defaults.** A default `converse()` is TTS playback, plus up to 120s of listening, plus STT, which can exceed two minutes. At defaults, the call can be backgrounded mid-listen:
  - the turn continues and queued messages deliver,
  - but the backgrounded call still holds the microphone, and a new `converse()` issued in the meantime overlaps it.
- The report's short-window recommendation avoids this. The report now says so, and names `CLAUDE_CODE_MCP_AUTO_BACKGROUND_MS=0` as a backstop. Only the precise delivery timing still needs an empirical check.

### (2) The conch and `_remote_marker`

- **Accurate:**
  - `conch.py`, `conch_queue.py` and `tools/conch.py` exist.
  - `NUDGE_TEXT` and `session send` match the report, and the tmux nudge comes from "skillbox".
  - `_remote_marker` is a documented no-op.
- **One overreach, fixed:** the report called this "the exact seam our bridge design needs".
  - The seam is reserved for VM-970, which `tools/conch.py` describes as "MCP channel notifications" to remote *VoiceMode* grantees.
  - An MCP server cannot call Claude Code's `SendMessage`, so option (D) "fill the seam to push a `SendMessage`" was not possible as written. Reworded.
- **Also fixed:** (D) claimed the recording loop "has no cancellation hook at all".
  - `converse.py:1977-1983` (VM-2015) wires a `stop_event` that is set when the awaiting coroutine is cancelled (for example ESC), and the VAD loop polls it every 0.1s.
  - An external cancel needs a new path to set that event; it does not need a new hook.
- The conch is irrelevant to option (A) with a single voice agent. It is worth keeping only as precedent.

### (3) LiveKit removal

- **Confirmed:** `CHANGELOG.md` records removal of the LiveKit feature and the `livekit` CLI group under 8.0.0 (2026-01-25, VM-353). No `livekit` module or command exists.
- **Corrected:** "the only surviving references are three files under `docs/.archive/`" was wrong. Vestigial strings remain in source:
  - a `voice_mode/__init__.py` docstring,
  - a `livekit` choice in `cli_commands/exchanges.py`,
  - diagnostic suggestions in `tools/dependencies.py` and `utils/audio_diagnostics.py`,
  - plus `docs/web/`, troubleshooting docs, and a `pyproject.toml` keyword.

### (4) Setup checklist

As originally written it would not have worked. Fixed inline:

- **Step 1, scope:** the plugin (`.claude-plugin/plugin.json`) ships a root `.mcp.json` server *and* six hooks, with soundfonts on by default.
  A user-scope install puts both into every session, so `/oversee` sessions would have gained VoiceMode tools and earcons on every tool call. That contradicts "keep `/oversee` as-is".
  `--strict-mcp-config` on the conversationalist cannot undo this: it governs only that session's MCP servers, never other sessions, and never hooks.
  Now: install at local scope from the conversationalist's directory, or skip the plugin and use `uvx voice-mode-install` plus an MCP entry.
- **Step 2, services:** the unverified service manager is resolved. `whisper`/`kokoro enable` use systemd *user* units (`voice_mode/templates/systemd/`, `systemctl --user`).
- **Step 3, config:**
  - `~/.voicemode/voicemode.env` is global, not per-project. Moved to the MCP entry's `env` block.
  - The MCP launch command now uses the README's `voicemode-mcp-launcher`.
  - Added `--name conversationalist`, without which overseers have no stable address.
  - Added `--tools`, because the report's "no `Bash`/`Edit`/`Write`" surface was asserted but nothing in the checklist enforced it.
- **Step 4, permission classes (substantive, fixed):** the report said running the conversationalist in `bypassPermissions` "sidesteps the inbound-hold dance". Per the cross-session docs it does the opposite for prompting-mode senders: a bypass-mode receiver holds everything except messages from other bypass-mode senders.
  The step also ignored the more important direction, conversationalist → overseer.
  The correct rule is **match the overseers' permission class**:
  - If overseers run `--dangerously-skip-permissions`, run the conversationalist in bypass mode, and messages flow both ways with no change to `/oversee`.
  - Otherwise leave it prompting.

  In both cases, add `crossSessionInbound: "accept"` via `--settings` on the conversationalist only. User settings would also apply to every overseer.

### (5) The incremental / low-dev-time constraint

**Honored.** (A) needs one skill file plus launch config, (B) is configuration only, and (C)/(D) are explicitly deferred. The hours-scale estimate for (A) is plausible once the checklist is right.

## Other fixes applied inline

- The ledger path moved from `.claude/oversee/conversationalist-ledger.json` to `.claude/conversationalist/ledger.json`. `/oversee resume` disambiguates "among the arcs under `.claude/oversee/`", so a stray JSON file there risks being taken for an arc file.
- "What the overseer side needs: currently nothing" said an inbound message has "no signal" of its origin. That was wrong: Claude Code tells the receiving Claude the message came from another session, with the sender's name and a reply address, so overseers can already reply via `SendMessage`. The proposed `oversee/SKILL.md` addendum is reframed as a voice-aware reply convention, not a prerequisite.
- The latency-statistics claim now notes that the `statistics` tools are not in the default `converse,service` tool set.
- Unverified list: the service manager and auto-backgrounding items are resolved; the `--strict-mcp-config` item is restated precisely.

The report was 3422 words and is now about 3640.

## Section-by-Section Findings

### Blocking

**B1. The recommended always-listening loop has an unaddressed cost; the report's own prior findings offer a better idle design.**

- Option (A)/(B) keeps the conversationalist re-issuing `converse()` with 10-20s windows "when nothing was said". Each loop iteration is a full model call on the subscription, and each adds to context:
  - roughly 180-360 calls per hour of silence,
  - steady context growth toward compaction,
  - and at default model settings, a large-model conversationalist.
- The idle-wake rule from the inter-session report gives a cheaper shape. The conversationalist listens in a loop only while a conversation is active, then ends its turn when the user signs off.
- An overseer's `SendMessage` then wakes it as a fresh turn. It speaks the message and listens for a reply.
- To re-engage from idle, the user needs a wake path. Options:
  - typing in its terminal,
  - a desktop hotkey that posts a line to its inbox socket (the inter-session report's direct-socket path),
  - a spoken keyword via VoiceMode's control channel (needs an external hotword trigger).
- The report should define these active and idle states, estimate the per-hour cost of each, and recommend `--model` (Sonnet- or Haiku-class) for the conversationalist.
- A smaller model also narrows the "same slow agent talks" gap from the architecture report. This design does achieve the talker/thinker split in its cheapest form, because the overseer is not the talker. The report should say so.

### Non-blocking

- **N1:** option (C)'s "drive `SendMessage`/`ListAgents` from a plain process via `claude -p`/CLI" should cite the inter-session report's direct inbox-socket posting, which is the lighter write path for a non-Claude front end.
- **N2:** the `converse` parameter count ("~25") is closer to 29 in the signature; trivial.
- **N3:** the outbound message contract's `Intent` field could add `reply-to: <message id from ledger>`, so multi-turn exchanges with one overseer stay threaded across conversationalist restarts.

## Verdict

**Revise.**
Source accuracy is high, the checklist is now correct, and the plan fits the user's incremental constraint.
One blocking design gap remains: the always-listening loop's cost, and the idle-wake alternative.
That is a short addition, after which this should be acceptable.

## Action Items

1. [blocking] Define the conversationalist's active and idle states, drawing on B1:
   - listen only during an active exchange,
   - rely on idle-wake for overseer messages,
   - specify a wake path for the user,
   - estimate per-hour cost,
   - recommend a smaller `--model`.
2. [non-blocking] In option (C), cite direct inbox-socket posting as the non-Claude write path.
3. [non-blocking] Add a `reply-to` field to the outbound message contract.
4. [non-blocking] Empirically check delivery timing around `converse()` returns (already listed as unverified).

## Questions for the user

1. How should you wake an idle conversationalist?
   - (A) Type in its terminal.
   - (B) A GNOME hotkey that posts to its inbox socket.
   - (C) A spoken hotword through VoiceMode's control channel, which needs an always-listening trigger.
2. Do your `/oversee` sessions normally run with `--dangerously-skip-permissions`? This decides the conversationalist's permission mode.
   - (A) Yes: run the conversationalist in bypass mode.
   - (B) No: leave it prompting.
   - (C) Mixed: use `crossSessionInbound: "accept"` via `--settings` on the conversationalist, and accept that overseer-side holds may need approval.
