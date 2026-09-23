---
first_authored:
  by: "@claude-fable-5-1"
  at: 2026-09-23T09:05:00-07:00
task_list: meta/chat-record-devlog-management
type: devlog
state: live
status: done
tags: [verification, hooks, chat_record, runtime_validated]
---

# Verification Artifact: Chat-Record Hook Canary (Claude Code 2.1.280)

> BLUF(fable-5-1/chat-record-devlog-management): Seven sandboxed headless runs on 2026-09-22 (Claude Code 2.1.280, `--model haiku`) show every hook the chat-record proposal depends on firing with the payload fields it relies on: `SessionStart` (startup and compact), `UserPromptSubmit`, `Stop`, `SubagentStart`/`SubagentStop`, `PostToolUse` on Read/Edit, `PreCompact` and `PostCompact` on both manual and auto compaction, and `SessionEnd`.
> This file is the reproducible record behind Phase 0 of [`2026-09-22-chat-record-devlog-management.md`](../../proposals/2026-09-22-chat-record-devlog-management.md): per run, the `settings.json`, the exact command, the stream-json input where used, the canary-log lines, and the model's printed result.
> Paths are elided: `<SANDBOX>` is a session scratchpad directory; `transcript_path` values are dropped.

## Common setup

- Sandbox per `plugins/cdocs/README.md` "Sandbox testing notes": a fresh `CLAUDE_CONFIG_DIR` (`<SANDBOX>/cfgN/`) holding only `settings.json` plus copies of `~/.claude/.credentials.json` and `~/.claude/.claude.json`; an empty out-of-repo `cwd` (`<SANDBOX>/projN/`); never `--bare`.
- `claude --version`: `2.1.280 (Claude Code)`.
- Every run's `cwd` was reset with `cd <SANDBOX>/projN` before invoking `claude`; the per-event logs below are exactly what the recorder appended, with `transcript_path` removed and `<SANDBOX>` substituted.
- All recorders exit 0 and never emit `decision: block`.

### Recorder: `canary.sh` (runs 1, 2, 3, 6)

```bash
#!/usr/bin/env bash
# Canary: record that a hook event fired, with its stdin payload (compacted), one JSON line per event.
EV="$1"; LOG="${CANARY_LOG:-$(dirname "$0")/canary.log}"
IN="$(cat)"
printf '{"event":"%s","at":"%s","stdin":%s}\n' "$EV" "$(date -Is)" "$(printf '%s' "$IN" | jq -c . 2>/dev/null || printf '"%s"' "unparsable")" >> "$LOG"
# UserPromptSubmit: also prove additionalContext delivery is possible (not needed for capture, but informative).
if [ "$EV" = "UserPromptSubmit" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"CANARY_UPS_MARKER_7731"}}\n'
fi
exit 0
```

### Recorder: `canary4.sh` (run 4, one marker per compaction-adjacent channel)

```bash
#!/usr/bin/env bash
EV="$1"; LOG="${CANARY_LOG}"; IN="$(cat)"
SRC=$(printf '%s' "$IN" | jq -r '.source // .trigger // ""')
printf '{"event":"%s","src":"%s","at":"%s"}\n' "$EV" "$SRC" "$(date -Is)" >> "$LOG"
case "$EV" in
  PreCompact)   printf '{"hookSpecificOutput":{"hookEventName":"PreCompact","additionalContext":"MARKER_PRECOMPACT_1111"}}\n' ;;
  PostCompact)  printf '{"hookSpecificOutput":{"hookEventName":"PostCompact","additionalContext":"MARKER_POSTCOMPACT_2222"}}\n' ;;
  SessionStart) if [ "$SRC" = "compact" ]; then printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"MARKER_SESSIONSTART_COMPACT_3333"}}\n'; fi ;;
esac
exit 0
```

### Recorder: `canary5.sh` (run 5, payload keys plus transcript extraction)

```bash
#!/usr/bin/env bash
# Records event + payload keys; on Stop, mechanically extracts the last assistant text turn from the transcript.
EV="$1"; LOG="${CANARY_LOG}"; IN="$(cat)"
KEYS=$(printf '%s' "$IN" | jq -c 'del(.transcript_path) | keys')
EXTRA=""
if [ "$EV" = "Stop" ] || [ "$EV" = "SubagentStop" ]; then
  TP=$(printf '%s' "$IN" | jq -r '.transcript_path')
  EXTRA=$(jq -c 'select(.type=="assistant") | {model: .message.model, text: ([.message.content[]? | select(.type=="text") | .text] | join("\n"))} | select(.text != "")' "$TP" 2>/dev/null | tail -n 1)
fi
printf '{"event":"%s","keys":%s,"agent_id":%s,"extract":%s}\n' "$EV" "$KEYS" "$(printf '%s' "$IN" | jq -c '.agent_id // .agent_type // null')" "${EXTRA:-null}" >> "$LOG"
exit 0
```

### Recorder: `canary7.sh` (run 7, tool name and path)

```bash
#!/usr/bin/env bash
EV="$1"; IN="$(cat)"
printf '{"event":"%s","tool":%s,"path":%s,"at":"%s"}\n' "$EV" "$(printf '%s' "$IN" | jq -c '.tool_name')" "$(printf '%s' "$IN" | jq -c '.tool_input.file_path // .tool_input.pattern // null')" "$(date -Is)" >> "$CANARY_LOG"
exit 0
```

## Run 1: `SessionStart`, `UserPromptSubmit`, `SessionEnd`; `additionalContext` delivery

`settings.json`:

```json
{
  "hooks": {
    "SessionStart":     [{"hooks":[{"type":"command","command":"<SANDBOX>/canary.sh SessionStart","timeout":5}]}],
    "UserPromptSubmit": [{"hooks":[{"type":"command","command":"<SANDBOX>/canary.sh UserPromptSubmit","timeout":5}]}],
    "PreCompact":       [{"hooks":[{"type":"command","command":"<SANDBOX>/canary.sh PreCompact","timeout":5}]}],
    "PostCompact":      [{"hooks":[{"type":"command","command":"<SANDBOX>/canary.sh PostCompact","timeout":5}]}],
    "SessionEnd":       [{"hooks":[{"type":"command","command":"<SANDBOX>/canary.sh SessionEnd","timeout":5}]}]
  }
}
```

Command:

```bash
CLAUDE_CONFIG_DIR=<SANDBOX>/cfg claude -p "Reply with exactly the word: ok. Then, on a second line, state whether the string CANARY_UPS_MARKER_7731 appears anywhere in your context (YES or NO)." \
  --model haiku --output-format stream-json --verbose --include-hook-events
```

Canary log:

```
{"event":"SessionStart","at":"2026-09-22T18:20:14-07:00","stdin":{"session_id":"13ee1efb-7fe3-4d17-a9e3-568a074495c1","cwd":"<SANDBOX>/proj","hook_event_name":"SessionStart","source":"startup"}}
{"event":"UserPromptSubmit","at":"2026-09-22T18:20:16-07:00","stdin":{"session_id":"13ee1efb-7fe3-4d17-a9e3-568a074495c1","cwd":"<SANDBOX>/proj","prompt_id":"561681ac-5a5f-43af-b4c7-d168b386327d","permission_mode":"default","hook_event_name":"UserPromptSubmit","prompt":"Reply with exactly the word: ok. Then, on a second line, state whether the string CANARY_UPS_MARKER_7731 appears anywhere in your context (YES or NO)."}}
{"event":"SessionEnd","at":"2026-09-22T18:20:17-07:00","stdin":{"session_id":"13ee1efb-7fe3-4d17-a9e3-568a074495c1","cwd":"<SANDBOX>/proj","prompt_id":"561681ac-5a5f-43af-b4c7-d168b386327d","hook_event_name":"SessionEnd","reason":"other"}}
```

Model result (`result` field): `ok` / `YES`.
The `--include-hook-events` stream carried `hook_started`/`hook_response` pairs for `SessionStart:startup` and `UserPromptSubmit`, the latter's `output` containing the marker JSON.

## Run 2: manual `/compact` via stream-json input

`settings.json`: as run 1 with `CANARY_LOG=<SANDBOX>/canary2.log` prefixed to each command.

Input (`run2.in`):

```json
{"type":"user","message":{"role":"user","content":"Reply with exactly the word: alpha"}}
{"type":"user","message":{"role":"user","content":"/compact"}}
{"type":"user","message":{"role":"user","content":"Reply with exactly the word: beta. Then on a second line say whether you remember an earlier word you replied with, and what it was."}}
```

Command:

```bash
CLAUDE_CONFIG_DIR=<SANDBOX>/cfg2 claude -p --model haiku --input-format stream-json --output-format stream-json --verbose --include-hook-events < run2.in
```

Canary log (`compact_summary` truncated to its first line; full length 2,782 chars):

```
{"event":"SessionStart","at":"2026-09-22T18:20:54-07:00","stdin":{"session_id":"9b824e82-4f57-44b8-8668-d0852f2f5f63","cwd":"<SANDBOX>/proj2","hook_event_name":"SessionStart","source":"startup"}}
{"event":"UserPromptSubmit","at":"2026-09-22T18:20:54-07:00","stdin":{"session_id":"9b824e82-...","cwd":"<SANDBOX>/proj2","prompt_id":"c76c22bb-b5d8-4427-ba8a-cc4433f967a3","permission_mode":"default","hook_event_name":"UserPromptSubmit","prompt":"Reply with exactly the word: alpha"}}
{"event":"PreCompact","at":"2026-09-22T18:20:55-07:00","stdin":{"session_id":"9b824e82-...","cwd":"<SANDBOX>/proj2","prompt_id":"407cc386-3846-403f-8504-82ffcce01ff2","hook_event_name":"PreCompact","trigger":"manual","custom_instructions":null}}
{"event":"SessionStart","at":"2026-09-22T18:21:05-07:00","stdin":{"session_id":"9b824e82-...","cwd":"<SANDBOX>/proj2","prompt_id":"407cc386-...","hook_event_name":"SessionStart","source":"compact","model":"claude-haiku-4-5-20251001"}}
{"event":"PostCompact","at":"2026-09-22T18:21:05-07:00","stdin":{"session_id":"9b824e82-...","cwd":"<SANDBOX>/proj2","prompt_id":"407cc386-...","hook_event_name":"PostCompact","trigger":"manual","compact_summary":"<analysis>\nThis conversation is extremely brief. ..."}}
{"event":"UserPromptSubmit","at":"2026-09-22T18:21:05-07:00","stdin":{"session_id":"9b824e82-...","cwd":"<SANDBOX>/proj2","prompt_id":"ab2a3ea6-2ec1-44ff-b990-31ada52db7d7","permission_mode":"default","hook_event_name":"UserPromptSubmit","prompt":"Reply with exactly the word: beta. Then on a second line say whether you remember an earlier word you replied with, and what it was."}}
{"event":"SessionEnd","at":"2026-09-22T18:21:07-07:00","stdin":{"session_id":"9b824e82-...","cwd":"<SANDBOX>/proj2","prompt_id":"ab2a3ea6-...","hook_event_name":"SessionEnd","reason":"other"}}
```

Model results: `alpha`; then `beta` / `Yes, I remember. The earlier word was "alpha".`
Stream `compact_boundary`: `{"trigger":"manual","pre_tokens":21259,"post_tokens":1293,"cumulative_dropped_tokens":19966,"duration_ms":10350}`.
Observations: the `/compact` line fired **no** `UserPromptSubmit` (two `UserPromptSubmit` events for three input lines); `--include-hook-events` emitted no `hook_started`/`hook_response` for `PreCompact` or `PostCompact` although both ran.

## Run 3: auto compaction under `--autocompact 100000`

`settings.json`: as run 1 with `CANARY_LOG=<SANDBOX>/canary3.log`.
Fixture: 14 files `data/note-00.txt` to `note-13.txt`, 420 lines of pseudo-words each (32,004 bytes per file, 448KB total), generated with a seeded Python snippet.

Command:

```bash
CLAUDE_CONFIG_DIR=<SANDBOX>/cfg3 claude -p "Using the Read tool, read EVERY file under ./data/ in full, one file per tool call, sequentially (do not batch). After all 14 are read, reply with exactly the word: done." \
  --model haiku --autocompact 100000 --permission-mode bypassPermissions --output-format stream-json --verbose --include-hook-events
```

Canary log, event sequence (all `session_id` `4985c62c-d71a-4a24-823c-e5345ca4812c`, `prompt_id` `b5e709af-...`):

```
18:21:13 SessionStart source=startup
18:21:14 UserPromptSubmit permission_mode=bypassPermissions
18:21:31 PreCompact trigger=auto custom_instructions=null
18:22:03 SessionStart source=compact model=claude-haiku-4-5-20251001
18:22:03 PostCompact trigger=auto compact_summary=<6,910 chars>
18:22:13 PreCompact trigger=auto
18:22:44 SessionStart source=compact model=claude-haiku-4-5-20251001
18:22:44 PostCompact trigger=auto compact_summary=<8,823 chars>
18:22:47 PreCompact trigger=auto
18:23:19 SessionStart source=compact model=claude-haiku-4-5-20251001
18:23:19 PostCompact trigger=auto compact_summary=<8,102 chars>
18:23:28 PreCompact trigger=auto
18:24:03 SessionStart source=compact model=claude-haiku-4-5-20251001
18:24:03 PostCompact trigger=auto compact_summary=<9,300 chars>
18:24:08 SessionEnd reason=other
```

Stream `compact_boundary` metadata, in order:

```
{"trigger":"auto","pre_tokens":72373,"post_tokens":11556,"duration_ms":31695}
{"trigger":"auto","pre_tokens":88147,"post_tokens":28914,"duration_ms":30397}
{"trigger":"auto","pre_tokens":71462,"post_tokens":12034,"duration_ms":31163}
{"trigger":"auto","pre_tokens":71461,"post_tokens":12081,"duration_ms":34297}
```

Model result: `{"result":"done","num_turns":21,"cache_read_input_tokens":446331}`.

## Run 4: which compaction-adjacent channel delivers `additionalContext`

`settings.json`:

```json
{"hooks":{
 "SessionStart":[{"hooks":[{"type":"command","command":"CANARY_LOG=<SANDBOX>/canary4.log <SANDBOX>/canary4.sh SessionStart","timeout":5}]}],
 "PreCompact":[{"hooks":[{"type":"command","command":"CANARY_LOG=<SANDBOX>/canary4.log <SANDBOX>/canary4.sh PreCompact","timeout":5}]}],
 "PostCompact":[{"hooks":[{"type":"command","command":"CANARY_LOG=<SANDBOX>/canary4.log <SANDBOX>/canary4.sh PostCompact","timeout":5}]}]
}}
```

Input (`run4.in`):

```json
{"type":"user","message":{"role":"user","content":"Reply with exactly the word: alpha"}}
{"type":"user","message":{"role":"user","content":"/compact"}}
{"type":"user","message":{"role":"user","content":"WITHOUT using any tools: list every string of the form MARKER_<WORD>_<DIGITS> that appears anywhere in your current context, verbatim, one per line. If none, reply NONE."}}
```

Command:

```bash
CLAUDE_CONFIG_DIR=<SANDBOX>/cfg4 claude -p --model haiku --input-format stream-json --output-format stream-json --verbose --include-hook-events < run4.in
```

Canary log:

```
{"event":"SessionStart","src":"startup","at":"2026-09-22T18:24:38-07:00"}
{"event":"PreCompact","src":"manual","at":"2026-09-22T18:24:40-07:00"}
{"event":"SessionStart","src":"compact","at":"2026-09-22T18:24:52-07:00"}
{"event":"PostCompact","src":"manual","at":"2026-09-22T18:24:52-07:00"}
```

Model result, post-compaction turn:

```
MARKER_SESSIONSTART_COMPACT_3333
MARKER_PRECOMPACT_1111
MARKER_POSTCOMPACT_2222
```

All three channels reached the model.
Whether `MARKER_PRECOMPACT_1111` arrived through the summarizer's input or by direct injection is not distinguished by this run.

## Run 5: `Stop`, `SubagentStart`/`SubagentStop`, and `UserPromptSubmit` scoping with a background subagent

`settings.json`:

```json
{"hooks":{
 "UserPromptSubmit":[{"hooks":[{"type":"command","command":"CANARY_LOG=<SANDBOX>/canary5.log <SANDBOX>/canary5.sh UserPromptSubmit","timeout":5}]}],
 "Stop":[{"hooks":[{"type":"command","command":"CANARY_LOG=<SANDBOX>/canary5.log <SANDBOX>/canary5.sh Stop","timeout":10}]}],
 "SubagentStop":[{"hooks":[{"type":"command","command":"CANARY_LOG=<SANDBOX>/canary5.log <SANDBOX>/canary5.sh SubagentStop","timeout":10}]}],
 "SubagentStart":[{"hooks":[{"type":"command","command":"CANARY_LOG=<SANDBOX>/canary5.log <SANDBOX>/canary5.sh SubagentStart","timeout":5}]}]
}}
```

Command:

```bash
CLAUDE_CONFIG_DIR=<SANDBOX>/cfg5 claude -p "Use the Agent tool to dispatch one general-purpose subagent with the prompt 'Reply with exactly the word: sub-ok'. After it returns, reply with exactly two lines: the first line 'parent-ok', the second line the subagent's reply verbatim." \
  --model haiku --permission-mode bypassPermissions --output-format stream-json --verbose --include-hook-events
```

Canary log (payload keys only, by design of this recorder):

```
{"event":"UserPromptSubmit","keys":["cwd","hook_event_name","permission_mode","prompt","prompt_id","session_id"],"agent_id":null,"extract":null}
{"event":"SubagentStart","keys":["agent_id","agent_type","cwd","hook_event_name","prompt_id","session_id"],"agent_id":"a10a58f03893928c2","extract":null}
{"event":"SubagentStop","keys":["agent_id","agent_transcript_path","agent_type","background_tasks","cwd","hook_event_name","last_assistant_message","permission_mode","prompt_id","session_crons","session_id","stop_hook_active"],"agent_id":"a10a58f03893928c2","extract":null}
{"event":"Stop","keys":["background_tasks","cwd","hook_event_name","last_assistant_message","permission_mode","prompt_id","session_crons","session_id","stop_hook_active"],"agent_id":null,"extract":null}
{"event":"UserPromptSubmit","keys":["cwd","hook_event_name","permission_mode","prompt","prompt_id","session_id"],"agent_id":null,"extract":null}
{"event":"Stop","keys":["background_tasks","cwd","hook_event_name","last_assistant_message","permission_mode","prompt_id","session_crons","session_id","stop_hook_active"],"agent_id":null,"extract":{"model":"claude-haiku-4-5-20251001","text":"I've launched the subagent. It's working in the background now, and I'll get a notification when it completes."}}
```

Model result: `I've launched the subagent. ...` (first turn), then `parent-ok` / `sub-ok`.
The subagent ran in the background, so its completion arrived as a second `UserPromptSubmit` with no human input; the prompt, read from the sandbox transcript, begins:

```
<task-notification>
<task-id>a10a58f03893928c2</task-id>
<tool-use-id>toolu_01BqZWiXbN4NMgdhc8srZC1N</tool-use-id>
<output-file>...</output-file>
<status>completed</status>
<summary>Agent "Test subagent reply" finished</summary>
```

Observations: no `UserPromptSubmit` fired between `SubagentStart` and `SubagentStop` (the subagent's dispatch prompt did not fire it); `Stop` carries `last_assistant_message` directly and no `model` field; the transcript-tail extraction was empty on the first `Stop` and one turn stale on the second, so the transcript is not a reliable source for the current turn's text.

## Run 6: `Stop` payload values with a foreground subagent

`settings.json`: `UserPromptSubmit` and `Stop` wired to `canary.sh` with `CANARY_LOG=<SANDBOX>/canary6.log`.

Command:

```bash
CLAUDE_CONFIG_DIR=<SANDBOX>/cfg6 claude -p "Use the Agent tool to dispatch one general-purpose subagent with the prompt 'Reply with exactly the word: sub-ok'. After it returns, reply with exactly: parent-ok" \
  --model haiku --permission-mode bypassPermissions --output-format json
```

Canary log:

```
{"event":"UserPromptSubmit","at":"2026-09-22T18:27:43-07:00","stdin":{"session_id":"e9143166-6c3c-44ed-8e61-3ac41eebf11c","cwd":"<SANDBOX>/proj6","prompt_id":"88b8e7d3-be72-4dba-92fb-2557b5c885ba","permission_mode":"bypassPermissions","hook_event_name":"UserPromptSubmit","prompt":"Use the Agent tool to dispatch one general-purpose subagent with the prompt 'Reply with exactly the word: sub-ok'. After it returns, reply with exactly: parent-ok"}}
{"event":"Stop","at":"2026-09-22T18:27:49-07:00","stdin":{"session_id":"e9143166-...","cwd":"<SANDBOX>/proj6","prompt_id":"88b8e7d3-...","permission_mode":"bypassPermissions","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"parent-ok","background_tasks":[],"session_crons":[]}}
```

Model result: `parent-ok`.
With the subagent in the foreground there was exactly one `UserPromptSubmit`, and `last_assistant_message` equals the printed result.

## Run 7: `PostToolUse` on `Read` and `Edit`

`settings.json`:

```json
{"hooks":{
 "PostToolUse":[{"matcher":"Read|Edit|Write|Glob|Grep","hooks":[{"type":"command","command":"CANARY_LOG=<SANDBOX>/canary7.log <SANDBOX>/canary7.sh PostToolUse","timeout":5}]}],
 "Stop":[{"hooks":[{"type":"command","command":"CANARY_LOG=<SANDBOX>/canary7.log <SANDBOX>/canary7.sh Stop","timeout":5}]}]
}}
```

Fixture: `a.txt` containing `alpha line`, `b.txt` containing `beta line`.

Command:

```bash
CLAUDE_CONFIG_DIR=<SANDBOX>/cfg7 claude -p "Read a.txt with the Read tool, then Read b.txt, then use Edit to change 'beta' to 'gamma' in b.txt. Then reply with exactly: files-ok" \
  --model haiku --permission-mode bypassPermissions --output-format json
```

Canary log:

```
{"event":"PostToolUse","tool":"Read","path":"<SANDBOX>/proj7/a.txt","at":"2026-09-22T18:34:04-07:00"}
{"event":"PostToolUse","tool":"Read","path":"<SANDBOX>/proj7/b.txt","at":"2026-09-22T18:34:05-07:00"}
{"event":"PostToolUse","tool":"Edit","path":"<SANDBOX>/proj7/b.txt","at":"2026-09-22T18:34:07-07:00"}
{"event":"Stop","tool":null,"path":null,"at":"2026-09-22T18:34:09-07:00"}
```

Model result: `files-ok`; `b.txt` afterwards contains `gamma line`.
This recorder did not log `agent_id`; the round-1 review's independent Run A ([`2026-09-22-review-of-chat-record-devlog-management.md`](../../reviews/2026-09-22-review-of-chat-record-devlog-management.md), "Independent Verification") showed `PostToolUse` also fires inside a dispatched subagent with `agent_id` and `agent_type` set, which is why the hook contract guards on `agent_id`.

## Not exercised

- Interactive `/compact` typed into a TUI session (the path [#13572](https://github.com/anthropics/claude-code/issues/13572) was filed against; closed-stale upstream).
- `/clear` and `/resume` effects on `session_id` and on `UserPromptSubmit`.
- A user-defined slash command (the review's Run B covered it: `UserPromptSubmit` fires with the raw invocation string).
