#!/usr/bin/env bash
# Tests for plugins/cdocs/bin/chat-record.
#
#   chat-record.test.sh --unit                 pure-shell suite (bash, jq, git); runs in CI
#   chat-record.test.sh --headless [--only RE] headless `claude -p` scenarios (needs credentials)
#   chat-record.test.sh [--only RE]            both
#   --optional                                 also run the default-permission-mode scenarios
#   --only init_real|rules_check|multi_turn    extras: real /cdocs:init, post-compaction rules check,
#                                              and a 20-turn resumed session under the rules
#
# Headless scenarios use a sandboxed CLAUDE_CONFIG_DIR holding copies of
# $CHAT_RECORD_CREDS_DIR/{.credentials.json,.claude.json} (default ~/.claude), `env -i` so the
# calling session's variables do not leak, scratch git projects outside any repo, `--model haiku`,
# and `--plugin-dir` pointing at the plugin under test. The sandbox is deleted on exit unless
# CHAT_RECORD_KEEP=1. Spec: cdocs/proposals/2026-09-22-chat-record-devlog-management.md.
set -uo pipefail
export LC_ALL=C
unset CDPATH CDOCS_CHAT_RECORD

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$(cd "$HERE/../.." && pwd)"
CR="$PLUGIN/bin/chat-record"

RUN_UNIT=1; RUN_HEADLESS=1; RUN_OPTIONAL=0; ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --unit) RUN_HEADLESS=0; shift ;;
    --headless) RUN_UNIT=0; shift ;;
    --optional) RUN_OPTIONAL=1; shift ;;
    --only) ONLY="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/chat-record-test.XXXXXX")"
cleanup() { [ "${CHAT_RECORD_KEEP:-0}" = 1 ] && echo "kept: $SCRATCH" || rm -rf "$SCRATCH"; }
trap cleanup EXIT

PASS=0; FAIL=0; FAILED=()
ok()   { echo "  PASS: $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL: $1"; FAIL=$((FAIL+1)); FAILED+=("$CUR: $1"); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2' want '$3')"; fi; }
has()  { if printf '%s' "$2" | grep -qE -- "$3"; then ok "$1"; else bad "$1 (missing /$3/)"; fi; }
hasnt(){ if printf '%s' "$2" | grep -qE -- "$3"; then bad "$1 (unexpected /$3/)"; else ok "$1"; fi; }
CUR=""
section() { CUR="$1"; echo "== $1"; }
want() { [ -z "$ONLY" ] || printf '%s' "$1" | grep -qE -- "$ONLY"; }

# Grammar, sourced from the script so writer and reader cannot drift.
HEADER_RE="$(sed -n "s/^HEADER_RE='\(.*\)'$/\1/p" "$CR")"
SIGNOFF_RE="$(sed -n "s/^SIGNOFF_RE='\(.*\)'$/\1/p" "$CR")"
HDR_CORE="${HEADER_RE#^}"; SIG_CORE="${SIGNOFF_RE#^}"
TS_RE="${SIGNOFF_RE##* at }"; TS_RE="${TS_RE%\$}"

# Reference splitter: one line per marker (`<<H speaker>>`, `<<S token>>`), body lines
# unescaped, trailing blank lines of each body stripped.
split_record() {
  awk -v H="$HEADER_RE" -v S="$SIGNOFF_RE" -v E="^\\\\\\\\+($HDR_CORE|$SIG_CORE)" '
    function flush() { while (n > 0 && buf[n] == "") n--; for (i = 1; i <= n; i++) print buf[i]; n = 0 }
    $0 ~ H { flush(); h = $0; sub(/:.*/, "", h); print "<<H " substr(h, 2) ">>"; next }
    $0 ~ S { flush(); print "<<S " $2 ">>"; next }
    { l = $0; if (l ~ E) l = substr(l, 2); buf[++n] = l }
    END { flush() }' "$1"
}

# Marker sequence of a record: U (@user), A:<speaker>, S:<token>.
markers() {
  grep -E -e "$HEADER_RE" -e "$SIGNOFF_RE" "$1" 2>/dev/null | while IFS= read -r l; do
    case "$l" in
      '@user:'*) echo U ;;
      '@'*) l="${l%%:*}"; echo "A:${l#@}" ;;
      *) l="${l#-- }"; echo "S:${l%% at *}" ;;
    esac
  done | paste -sd' ' -
}

# Marker counts of a record: `A:x=2 S:y=2 U=2`.
tally() {
  markers "$1" | tr ' ' '\n' | sort | uniq -c | awk '{printf "%s%s=%s", (NR > 1 ? " " : ""), $2, $1}'
}

# ======================================================================================
# Unit suite
# ======================================================================================

SID="0123abcd-4567-89ef-0123-456789abcdef"
SID8="0123abcd"

newproj() { # newproj <dir>: git repo with cdocs/_chat/
  mkdir -p "$1/cdocs/_chat" && git -C "$1" init -q . 2>/dev/null
}
payload() { # payload <cwd> [jq-args...] <filter-extension>
  local cwd="$1"; shift
  jq -cn --arg sid "$SID" --arg cwd "$cwd" "$@"
}
ups() { # ups <cwd> <prompt> [transcript] [extra-env...] -> stdout of the hook; UPS_TITLE sets session_title
  local cwd="$1" prompt="$2" tr="${3:-/nonexistent}"; shift 3 2>/dev/null || shift $#
  jq -cn --arg sid "$SID" --arg cwd "$cwd" --arg p "$prompt" --arg tr "$tr" --arg st "${UPS_TITLE:-}" \
    '{session_id: $sid, cwd: $cwd, prompt: $p, transcript_path: $tr, hook_event_name: "UserPromptSubmit"}
     + (if $st == "" then {} else {session_title: $st} end)' \
    | env "$@" "$CR" UserPromptSubmit
}
stop() { # stop <cwd> <stop_hook_active> [permission_mode] [transcript] [extra-env...]
  local cwd="$1" active="$2" pm="${3:-default}" tr="${4:-/nonexistent}"; shift 4 2>/dev/null || shift $#
  jq -cn --arg sid "$SID" --arg cwd "$cwd" --argjson a "$active" --arg pm "$pm" --arg tr "$tr" \
    '{session_id: $sid, cwd: $cwd, stop_hook_active: $a, permission_mode: $pm, transcript_path: $tr, hook_event_name: "Stop"}' \
    | env "$@" "$CR" Stop
}
note() { # note <cwd> [args...] ; body on stdin
  local cwd="$1"; shift
  (cd "$cwd" && CLAUDE_CODE_SESSION_ID="$SID" "$CR" note "$@")
}
rec() { ls "$1"/cdocs/_chat/*-"$SID".md 2>/dev/null | head -n 1; }
titles() { # titles <transcript> <title>...: append one custom-title line per title
  local f="$1" t; shift
  for t in "$@"; do jq -cn --arg t "$t" '{type: "custom-title", customTitle: $t, sessionId: "x"}' >> "$f"; done
}

unit_suite() {
  local U="$SCRATCH/unit" P out f rc D
  D="$(date +%Y-%m-%d)"
  # Hermetic config dir: agent modes glob <config>/projects/*/<sid>.jsonl for the session
  # name, and must never see the calling session's transcripts.
  mkdir -p "$U/cfg"
  export CLAUDE_CONFIG_DIR="$U/cfg"

  section "unit: script and hooks.json"
  check "script is mode 755 in the index" \
    "$(git -C "$PLUGIN" ls-files -s bin/chat-record | awk '{print $1}')" "100755"
  check "UserPromptSubmit hook runs chat-record" \
    "$(jq -r '.hooks.UserPromptSubmit[0].hooks[0].command' "$PLUGIN/hooks/hooks.json")" \
    '${CLAUDE_PLUGIN_ROOT}/bin/chat-record UserPromptSubmit'
  check "Stop hook runs chat-record" \
    "$(jq -r '.hooks.Stop[0].hooks[0].command' "$PLUGIN/hooks/hooks.json")" \
    '${CLAUDE_PLUGIN_ROOT}/bin/chat-record Stop'
  has "hooks.json description names the chat record" \
    "$(jq -r .description "$PLUGIN/hooks/hooks.json")" "chat record"
  check "init's rule order names every rule file once (init_rules uses it)" \
    "$(init_rule_order | sort | paste -sd' ' -)" "$(cd "$PLUGIN/rules" && ls *.md | sort | paste -sd' ' -)"
  check "awk supports regex intervals (reference splitter needs them)" \
    "$(echo aaaa | awk '/^a{4}$/ {print "y"}')" "y"

  section "unit: timestamp"
  P="$U/ts"; newproj "$P"
  ups "$P" "hi" >/dev/null; stop "$P" true >/dev/null
  f="$(rec "$P")"
  has "header timestamp matches SIGNOFF_RE time part" "$(head -n 1 "$f")" "^@user: ${TS_RE}\$"
  has "sign-off matches SIGNOFF_RE" "$(grep -E -- '^-- ' "$f")" "$SIGNOFF_RE"
  has "unnamed record is <date>-<sid>.md" "$(basename "$f")" "^[0-9]{4}-[0-9]{2}-[0-9]{2}-$SID\.md\$"

  section "unit: grammar round trip"
  P="$U/grammar"; newproj "$P"
  local -a bodies=(
    $'@user: injected header-shaped first line\nsecond line'
    '@alice: hey'
    $'@color: #fff;\n@page:first {\n  margin: 0;\n}\n@media (min-width: 1px) {}'
    $'```\n@user: inside a fence\n-- fenced at 2026-10-05T12:00:00-07:00\n```'
    $'\\@user: already escaped once\n\\\\@x: escaped twice'
    '-- my-canary at 2026-10-05T12:00:00-07:00'
    ''
    $'crlf line one\r\ncrlf line two\r\n'
    $'line ending in r\ncrlf line ending in r\r\nuse the bar'
  )
  local expected="$U/grammar.expected" b nb
  : > "$expected"
  for b in "${bodies[@]}"; do
    ups "$P" "$b" >/dev/null
    # Expected body without sed, so a sed that mishandles \r cannot agree with the script.
    nb="${b//$'\r\n'/$'\n'}"; nb="${nb%$'\r'}"; nb="$(printf '%s' "$nb")"
    { echo "<<H user>>"; [ -n "$nb" ] && printf '%s\n' "$nb"; } >> "$expected"
    if [ -n "$b" ]; then
      printf '%s\n' "$b" | note "$P" --as tester
      { echo "<<H tester>>"; printf '%s\n' "$nb"; } >> "$expected"
    fi
    stop "$P" true >/dev/null
    echo "<<S $SID8>>" >> "$expected"
  done
  f="$(rec "$P")"
  if diff -u "$expected" <(split_record "$f") > "$U/grammar.diff"; then
    ok "every body and sign-off recovered exactly (${#bodies[@]} prompts, $((${#bodies[@]} - 1)) notes)"
  else
    bad "round trip differs:"; cat "$U/grammar.diff"
  fi
  hasnt "no CR survives in the record" "$(cat "$f")" $'\r'
  check "a line ending in r keeps its r (with and without CRLF)" \
    "$(grep -cE '^(line ending in r|crlf line ending in r|use the bar)$' "$f")" "6"
  check "only real markers parse as markers" "$(grep -cE -e "$HEADER_RE" -e "$SIGNOFF_RE" "$f")" \
    "$(( ${#bodies[@]} * 2 + ${#bodies[@]} - 1 ))"

  section "unit: session token"
  P="$U/title"; newproj "$P"
  local T="$U/transcript.jsonl"
  printf '%s\n' '{"type":"custom-title","customTitle":"old title","sessionId":"x"}' \
    '{"type":"user","message":"noise"}' \
    '{"type":"custom-title","customTitle":"my canary \"v2\"","sessionId":"x"}' > "$T"
  ups "$P" "t1" "$T" >/dev/null; stop "$P" true default "$T" >/dev/null
  check "last custom-title, slugged" \
    "$(tail -n 2 "$P/cdocs/_chat/$D-my-canary-v2-$SID.md" | head -n 1 | sed 's/ at .*//')" "-- my-canary-v2"
  printf '%s\n' '{"type":"custom-title","customTitle":"","sessionId":"x"}' > "$T"
  ups "$P" "t2" "$T" >/dev/null; stop "$P" true default "$T" >/dev/null
  check "empty title -> sid8" "$(tail -n 2 "$P/cdocs/_chat/$D-$SID.md" | head -n 1 | sed 's/ at .*//')" "-- $SID8"
  ups "$P" "t3" "$U/missing.jsonl" >/dev/null; stop "$P" true default "$U/missing.jsonl" >/dev/null
  check "unreadable transcript -> sid8" "$(tail -n 2 "$P/cdocs/_chat/$D-$SID.md" | head -n 1 | sed 's/ at .*//')" "-- $SID8"

  section "unit: session name in the record filename"
  mkdir -p "$U/name"
  name_of() { # name_of <transcript-lines...>: name segment of the record one UPS writes ('' = unnamed)
    local d t b; d="$(mktemp -d "$U/name/XXXXXX")"; newproj "$d"; t="$d.jsonl"; : > "$t"
    [ $# -gt 0 ] && printf '%s\n' "$@" > "$t"
    ups "$d" "x" "$t" >/dev/null
    b="$(basename "$(rec "$d")" .md)"; b="${b:11}"; b="${b%"$SID"}"; printf '%s' "${b%-}"
  }
  ct() { jq -cn --arg t "$1" '{type: "custom-title", customTitle: $t, sessionId: "x"}'; }
  local A63; A63="$(printf 'a%.0s' $(seq 63))"
  check "slug: quotes and spaces" "$(name_of "$(ct 'my canary "v2"')")" "my-canary-v2"
  check "slug: punctuation" "$(name_of "$(ct 'Second: Name!')")" "second-name"
  check "slug: non-ASCII dropped" "$(name_of "$(ct 'Café plan')")" "caf-plan"
  check "slug: no alphanumerics -> unnamed" "$(name_of "$(ct '!!!')")" ""
  check "slug: 70 chars cut at 64, no trailing -" "$(name_of "$(ct "$A63 bbbbbb")")" "$A63"
  check "slug: a later ai-title is ignored" \
    "$(name_of "$(ct 'Real Name')" '{"type":"ai-title","aiTitle":"Auto Title","sessionId":"x"}')" "real-name"
  check "slug: ai-title alone -> unnamed" "$(name_of '{"type":"ai-title","aiTitle":"Auto Title","sessionId":"x"}')" ""

  section "unit: first prompt of a named session (transcript not yet written)"
  P="$U/firstname"; newproj "$P"
  local FC="$U/cfg-first"; mkdir -p "$FC/projects/p"; local FT="$FC/projects/p/$SID.jsonl"
  UPS_TITLE="First Name" ups "$P" "one" "$FT" >/dev/null
  check "no transcript yet: UPS names the record from session_title" "$(ls "$P/cdocs/_chat" | paste -sd' ' -)" \
    "$D-first-name-$SID.md"
  titles "$FT" "First Name"
  echo "- one" | CLAUDE_CONFIG_DIR="$FC" note "$P" --as tester; stop "$P" false default "$FT" >/dev/null
  check "note and Stop join the same record" "$(markers "$P/cdocs/_chat/$D-first-name-$SID.md")|$(ls "$P/cdocs/_chat" | wc -l | tr -d ' ')" \
    "U A:tester S:first-name|1"
  P="$U/firstname2"; newproj "$P"; : > "$U/firstname2.jsonl"
  UPS_TITLE="Auto Title" ups "$P" "one" "$U/firstname2.jsonl" >/dev/null
  check "transcript exists: session_title ignored, transcript decides" "$(ls "$P/cdocs/_chat" | paste -sd' ' -)" "$D-$SID.md"

  section "unit: rename starts a new record; renaming back resumes"
  local RC="$U/cfg-rename" TR
  mkdir -p "$RC/projects/p"; TR="$RC/projects/p/$SID.jsonl"; : > "$TR"
  P="$U/rename"; newproj "$P"
  rturn() { # rturn <tag>: UPS, note, Stop, all reading the session's transcript
    ups "$P" "prompt $1" "$TR" >/dev/null
    echo "- $1" | CLAUDE_CONFIG_DIR="$RC" note "$P" --as tester
    stop "$P" false default "$TR" >/dev/null
  }
  titles "$TR" "Name A"; rturn one
  check "turn 1 writes only A's record" "$(ls "$P/cdocs/_chat" | paste -sd' ' -)" "$D-name-a-$SID.md"
  check "A's record: one full turn" "$(markers "$P/cdocs/_chat/$D-name-a-$SID.md")" "U A:tester S:name-a"
  titles "$TR" "B"; rturn two
  check "turn 2 writes B's record" "$(markers "$P/cdocs/_chat/$D-b-$SID.md")" "U A:tester S:b"
  check "turn 2 leaves A's record unchanged" "$(markers "$P/cdocs/_chat/$D-name-a-$SID.md")" "U A:tester S:name-a"
  check "path prints B's record" "$(cd "$P" && CLAUDE_CONFIG_DIR="$RC" CLAUDE_CODE_SESSION_ID="$SID" "$CR" path)" \
    "cdocs/_chat/$D-b-$SID.md"
  titles "$TR" "name a"; rturn three
  check "renaming back resumes A's record" "$(markers "$P/cdocs/_chat/$D-name-a-$SID.md")" \
    "U A:tester S:name-a U A:tester S:name-a"
  check "renaming back leaves B's record unchanged" "$(markers "$P/cdocs/_chat/$D-b-$SID.md")" "U A:tester S:b"
  check "two records, no unnamed one" "$(ls "$P/cdocs/_chat" | wc -l | tr -d ' ')" "2"

  section "unit: agent modes find the session name"
  local AC="$U/cfg-agent"; mkdir -p "$AC/projects/some-project"
  titles "$AC/projects/some-project/$SID.jsonl" "Agent A"
  P="$U/agentname"; newproj "$P"
  echo "- named" | CLAUDE_CONFIG_DIR="$AC" note "$P" --as tester
  check "note appends to the named record" "$(ls "$P/cdocs/_chat" | paste -sd' ' -)" "$D-agent-a-$SID.md"
  check "path prints the named record" "$(cd "$P" && CLAUDE_CONFIG_DIR="$AC" CLAUDE_CODE_SESSION_ID="$SID" "$CR" path)" \
    "cdocs/_chat/$D-agent-a-$SID.md"
  echo "- unnamed" | note "$P" --as tester
  check "no transcript: note uses the unnamed record" "$(markers "$P/cdocs/_chat/$D-$SID.md")" "A:tester"
  check "no transcript: path prints the unnamed record" "$(cd "$P" && CLAUDE_CODE_SESSION_ID="$SID" "$CR" path)" \
    "cdocs/_chat/$D-$SID.md"
  mkdir -p "$U/home/.claude/projects/p"; titles "$U/home/.claude/projects/p/$SID.jsonl" "Home Name"
  check "CLAUDE_CONFIG_DIR unset: path globs ~/.claude" \
    "$(cd "$P" && env -u CLAUDE_CONFIG_DIR HOME="$U/home" CLAUDE_CODE_SESSION_ID="$SID" "$CR" path)" \
    "cdocs/_chat/$D-home-name-$SID.md"

  section "unit: name-exact lookup"
  P="$U/exact"; newproj "$P"
  local UREC="$P/cdocs/_chat/2026-01-01-$SID.md" NREC="$P/cdocs/_chat/2026-01-02-name-a-$SID.md"
  printf '%s' $'@user: 2026-10-05T12:00:00-07:00\nq\n\n' > "$UREC"; cp "$UREC" "$NREC"
  echo "- unnamed" | note "$P" --as tester; stop "$P" false >/dev/null
  check "unnamed calls touch only the unnamed record" "$(markers "$UREC")|$(markers "$NREC")" "U A:tester S:$SID8|U"
  local EC="$U/cfg-exact"; mkdir -p "$EC/projects/p"; titles "$EC/projects/p/$SID.jsonl" "Name A"
  echo "- named" | CLAUDE_CONFIG_DIR="$EC" note "$P" --as tester
  stop "$P" false default "$EC/projects/p/$SID.jsonl" >/dev/null
  check "named calls touch only the named record" "$(markers "$UREC")|$(markers "$NREC")" \
    "U A:tester S:$SID8|U A:tester S:name-a"
  check "no other record created" "$(ls "$P/cdocs/_chat" | wc -l | tr -d ' ')" "2"

  section "unit: Stop decision table"
  local base="$U/stop" r
  stop_case() { # stop_case <name> <record-content> <active> <pm> -> sets OUT, R (record after)
    local d="$base/$1"; newproj "$d"
    printf '%s' "$2" > "$d/cdocs/_chat/2026-10-05-$SID.md"
    OUT="$(stop "$d" "$3" "$4")"; R="$(cat "$d/cdocs/_chat/2026-10-05-$SID.md")"
  }
  local U1=$'@user: 2026-10-05T12:00:00-07:00\nq\n\n'
  local A1=$'@opus-5-5: 2026-10-05T12:00:01-07:00\n- x\n\n'
  local S1=$'-- s at 2026-10-05T12:00:02-07:00\n\n'
  stop_case agent "$U1$A1" false default
  check "last=agent header: no output" "$OUT" ""
  check "last=agent header: sign-off appended" "$(markers "$base/agent/cdocs/_chat/2026-10-05-$SID.md")" "U A:opus-5-5 S:$SID8"
  stop_case user "$U1" false default
  check "last=@user, first Stop: record unchanged" "$R" "${U1%$'\n\n'}"
  check "last=@user, first Stop: decision block" "$(printf '%s' "$OUT" | jq -r .decision)" "block"
  has "block reason names the record path" "$(printf '%s' "$OUT" | jq -r .reason)" "record: cdocs/_chat/2026-10-05-$SID\.md\)"
  has "block reason carries the heredoc note command" "$(printf '%s' "$OUT" | jq -r .reason)" \
    "chat-record note --as <your model id> <<'EOF'"
  r="$(printf '%s' "$OUT" | jq -r .reason)"
  has "block reason carries the free-form note template" "$r" '^- <the most important thing you are telling the user>$'
  hasnt "block reason carries no note type" "$r" '(gist|query|read|follow-up):'
  [ "${#r}" -lt 300 ] && ok "block reason under 300 bytes (${#r})" || bad "block reason ${#r} bytes"
  check "block JSON has exactly decision and reason" "$(printf '%s' "$OUT" | jq -c 'keys')" '["decision","reason"]'
  stop_case active "$U1" true default
  check "last=@user, stop_hook_active: no output" "$OUT" ""
  check "last=@user, stop_hook_active: sign-off" "$(markers "$base/active/cdocs/_chat/2026-10-05-$SID.md")" "U S:$SID8"
  stop_case plan "$U1" false plan
  check "last=@user, plan mode: no output" "$OUT" ""
  check "last=@user, plan mode: sign-off" "$(markers "$base/plan/cdocs/_chat/2026-10-05-$SID.md")" "U S:$SID8"
  stop_case signoff "$U1$A1$S1" false default
  check "last=sign-off: no output" "$OUT" ""
  check "last=sign-off: nothing written" "$R" "${U1}${A1}${S1%$'\n\n'}"
  stop_case none $'stray text\n' false default
  check "no marker: no output" "$OUT" ""
  check "no marker: nothing written" "$R" "stray text"
  stop_case escaped "$U1$A1"$'\\@user: x\n' false default
  check "escaped @user body after agent header: no output" "$OUT" ""
  check "escaped @user body after agent header: sign-off" \
    "$(markers "$base/escaped/cdocs/_chat/2026-10-05-$SID.md")" "U A:opus-5-5 S:$SID8"
  P="$base/norecord"; newproj "$P"
  check "no record file: no output" "$(stop "$P" false default)" ""
  check "no record file: none created" "$(ls "$P/cdocs/_chat" | wc -l | tr -d ' ')" "0"

  section "unit: harness skip and stdout"
  P="$U/skip"; newproj "$P"
  out="$(ups "$P" '<task-notification><task-id>x</task-id></task-notification>')"
  check "task-notification: stdout empty" "$out" ""
  out="$(ups "$P" $'  \n\t<system-reminder>r</system-reminder>')"
  check "system-reminder after blanks: stdout empty" "$out" ""
  check "harness envelopes write nothing" "$(ls "$P/cdocs/_chat" | wc -l | tr -d ' ')" "0"
  out="$(ups "$P" '<div>pasted html</div>')"
  check "<div>: stdout empty" "$out" ""
  ups "$P" 'hello <task-notification>' >/dev/null
  check "<div> and mid-line tag recorded as @user" "$(markers "$(rec "$P")")" "U U"

  section "unit: hook mode on an empty or invalid payload"
  P="$U/badpayload"; newproj "$P"
  local bp m
  for bp in '' ' ' 'not json' '[1]' '"s"' 'null' '{}'; do
    for m in UserPromptSubmit Stop; do
      out="$(cd "$P" && printf '%s' "$bp" | "$CR" "$m" 2>/dev/null)"; rc=$?
      check "$m payload '$bp': exit 0, stdout empty" "$rc:$out" "0:"
    done
  done
  check "empty or invalid payloads write nothing" "$(ls "$P/cdocs/_chat" | wc -l | tr -d ' ')" "0"

  section "unit: agent-mode exit codes"
  P="$U/exit"; newproj "$P"
  (cd "$P" && echo "- x" | env -u CLAUDE_CODE_SESSION_ID "$CR" note 2>/dev/null); rc=$?
  [ "$rc" -ne 0 ] && ok "note without session id exits non-zero ($rc)" || bad "note without session id exit 0"
  (cd "$P" && env -u CLAUDE_CODE_SESSION_ID "$CR" path >/dev/null 2>&1); rc=$?
  [ "$rc" -ne 0 ] && ok "path without session id exits non-zero ($rc)" || bad "path without session id exit 0"
  out="$(cd "$P" && echo "- x" | CDOCS_CHAT_RECORD=off CLAUDE_CODE_SESSION_ID="$SID" "$CR" note 2>&1)"; rc=$?
  check "note with CDOCS_CHAT_RECORD=off exits 0 silently" "$rc:$out" "0:"
  out="$(cd "$P" && CDOCS_CHAT_RECORD=off CLAUDE_CODE_SESSION_ID="$SID" "$CR" path 2>&1)"; rc=$?
  check "path with CDOCS_CHAT_RECORD=off exits 0 silently" "$rc:$out" "0:"
  ups "$P" "x" /nonexistent CDOCS_CHAT_RECORD=off >/dev/null
  check "hooks with CDOCS_CHAT_RECORD=off write nothing" "$(ls "$P/cdocs/_chat" | wc -l | tr -d ' ')" "0"
  (cd "$P" && printf '' | CLAUDE_CODE_SESSION_ID="$SID" "$CR" note 2>/dev/null); rc=$?
  [ "$rc" -ne 0 ] && ok "empty note body exits non-zero" || bad "empty note body exit 0"
  check "nothing written by failed or disabled agent modes" "$(ls "$P/cdocs/_chat" | wc -l | tr -d ' ')" "0"
  local NOJQ="$U/nojq-bin" t
  mkdir -p "$NOJQ"
  for t in bash sh env cat date sed tr grep tail head cut git dirname ls; do
    ln -sf "$(command -v "$t")" "$NOJQ/$t"
  done
  out="$(jq -cn --arg sid "$SID" --arg cwd "$P" '{session_id:$sid,cwd:$cwd,prompt:"x"}' \
    | PATH="$NOJQ" "$CR" UserPromptSubmit 2>&1)"; rc=$?
  check "hook without jq exits 0 silently" "$rc:$out" "0:"
  (cd "$P" && echo "- x" | PATH="$NOJQ" CLAUDE_CODE_SESSION_ID="$SID" "$CR" note 2>/dev/null); rc=$?
  [ "$rc" -ne 0 ] && ok "note without jq exits non-zero" || bad "note without jq exit 0"

  section "unit: speaker"
  P="$U/speaker"; newproj "$P"
  local as
  for as in 'opus-4-6[1m]' 'Opus 5.5' Haiku-4.5 haiku-4-5 claude-haiku-4-5-20251001 'Sonnet 4 6' \
    'Claude Opus 4.6' 'opus-4-6 [1m]'; do
    echo "- $as" | note "$P" --as "$as"
  done
  echo "- c" | note "$P"
  local spk="A:opus-4-6 A:opus-5-5 A:haiku-4-5 A:haiku-4-5 A:haiku-4-5 A:sonnet-4-6 A:opus-4-6 A:opus-4-6 A:assistant"
  check "speakers normalized to one short id per model; default assistant" "$(markers "$(rec "$P")")" "$spk"
  local bad_as
  for bad_as in user User claude-user 'Claude user' '' claude- -x _x; do
    (echo "- z" | note "$P" --as "$bad_as" 2>/dev/null); rc=$?
    [ "$rc" -ne 0 ] && ok "--as '$bad_as' rejected ($rc)" || bad "--as '$bad_as' accepted"
  done
  check "rejected speakers wrote nothing" "$(markers "$(rec "$P")")" "$spk"

  section "unit: activation"
  local A="$U/act"
  mkdir -p "$A/cdocs/_chat" "$A/repo/sub"; git -C "$A/repo" init -q .
  ups "$A/repo/sub" "x" >/dev/null
  stop "$A/repo/sub" false >/dev/null
  check "cdocs/_chat above the git toplevel is not used" "$(ls "$A/cdocs/_chat" | wc -l | tr -d ' ')" "0"
  (cd "$A/repo" && echo "- x" | CLAUDE_CODE_SESSION_ID="$SID" "$CR" note 2>/dev/null); rc=$?
  [ "$rc" -ne 0 ] && ok "note fails when only an above-toplevel cdocs/_chat exists" || bad "note succeeded above toplevel"
  mkdir -p "$A/repo/cdocs"
  out="$(ups "$A/repo/sub" "x")$(stop "$A/repo/sub" false)"
  check "cdocs/ without _chat/: no output" "$out" ""
  check "cdocs/ without _chat/: no file" "$(ls -A "$A/repo/cdocs" | wc -l | tr -d ' ')" "0"
  mkdir -p "$A/nogit/cdocs/_chat"
  out="$(ups "$A/nogit" "x")$(stop "$A/nogit" false)"
  check "outside a git work tree: no output, no file" "$out:$(ls "$A/nogit/cdocs/_chat" | wc -l | tr -d ' ')" ":0"
  mkdir -p "$A/repo/cdocs/_chat"
  out="$(cd "$A/repo/sub" && CLAUDE_CODE_SESSION_ID="$SID" "$CR" path)"
  has "path from a subdirectory is toplevel-relative" "$out" "^cdocs/_chat/[0-9]{4}-[0-9]{2}-[0-9]{2}-$SID\.md\$"
  check "path creates nothing" "$(ls "$A/repo/cdocs/_chat" | wc -l | tr -d ' ')" "0"
  out="$(jq -cn --arg sid "$SID" --arg cwd "$A/repo" '{session_id:$sid,cwd:$cwd,prompt:"x",agent_id:"a1b2"}' \
    | "$CR" UserPromptSubmit)"
  check "payload with agent_id: no output, no file" "$out:$(ls "$A/repo/cdocs/_chat" | wc -l | tr -d ' ')" ":0"

  section "unit: multiple matches"
  P="$U/multi"; newproj "$P"
  printf '%s' "$U1" > "$P/cdocs/_chat/2026-01-01-$SID.md"
  printf '%s' "$U1" > "$P/cdocs/_chat/2026-02-01-$SID.md"
  echo "- m" | note "$P" --as tester
  stop "$P" false >/dev/null
  check "note and Stop use the earliest-dated record" \
    "$(markers "$P/cdocs/_chat/2026-01-01-$SID.md")|$(markers "$P/cdocs/_chat/2026-02-01-$SID.md")" \
    "U A:tester S:$SID8|U"
  check "path prints the earliest-dated record" \
    "$(cd "$P" && CLAUDE_CODE_SESSION_ID="$SID" "$CR" path)" "cdocs/_chat/2026-01-01-$SID.md"

  section "unit: union merge"
  merge_suite "$U/merge"
}

merge_suite() {
  local M="$1" G
  G=(env GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git)
  # Union merge keeps one copy of a line both sides added identically, so turns made in
  # the same second (identical header and sign-off lines) would collapse: space them.
  turn() { # turn <repo> <tag>: one full recorded turn
    sleep 1
    ups "$1" "prompt $2" >/dev/null
    echo "- turn $2" | note "$1" --as tester
    stop "$1" false >/dev/null
  }
  setup_repo() {
    mkdir -p "$1/cdocs/_chat"
    "${G[@]}" -C "$1" init -q -b main .
    "${G[@]}" -C "$1" config user.name "Chat Record Test"
    "${G[@]}" -C "$1" config user.email "test@example.invalid"
    "${G[@]}" -C "$1" config commit.gpgsign false
    printf '*.md merge=union\n' > "$1/cdocs/_chat/.gitattributes"
    echo seed > "$1/seed.txt"
    "${G[@]}" -C "$1" add -A && "${G[@]}" -C "$1" commit -qm seed
  }
  local op R f n
  for op in merge rebase; do
    R="$M/append-$op"; setup_repo "$R"
    turn "$R" base; "${G[@]}" -C "$R" add -A; "${G[@]}" -C "$R" commit -qm base
    "${G[@]}" -C "$R" checkout -qb a; turn "$R" a; "${G[@]}" -C "$R" commit -qam a
    "${G[@]}" -C "$R" checkout -q main; "${G[@]}" -C "$R" checkout -qb b; turn "$R" b; "${G[@]}" -C "$R" commit -qam b
    if [ "$op" = merge ]; then "${G[@]}" -C "$R" merge -q --no-edit a >/dev/null 2>&1
    else "${G[@]}" -C "$R" rebase -q a >/dev/null 2>&1; fi
    check "divergent appends to a committed record: $op exits clean" "$?" "0"
    f="$(rec "$R")"
    check "$op keeps every block (append)" "$(tally "$f")" "A:tester=3 S:$SID8=3 U=3"
    hasnt "$op leaves no conflict markers (append)" "$(cat "$f")" '^(<<<<<<<|>>>>>>>)'

    R="$M/addadd-$op"; setup_repo "$R"
    "${G[@]}" -C "$R" checkout -qb a; turn "$R" a; "${G[@]}" -C "$R" add -A; "${G[@]}" -C "$R" commit -qm a
    "${G[@]}" -C "$R" checkout -q main; "${G[@]}" -C "$R" checkout -qb b; turn "$R" b; "${G[@]}" -C "$R" add -A; "${G[@]}" -C "$R" commit -qm b
    # Both branches created the same file name (same date, same session).
    n="$(ls "$R/cdocs/_chat"/*.md | wc -l | tr -d ' ')"
    if [ "$op" = merge ]; then "${G[@]}" -C "$R" merge -q --no-edit a >/dev/null 2>&1
    else "${G[@]}" -C "$R" rebase -q a >/dev/null 2>&1; fi
    check "same record created on two branches (add/add): $op exits clean" "$?:$n" "0:1"
    f="$(rec "$R")"
    check "$op keeps every block (add/add)" "$(tally "$f")" "A:tester=2 S:$SID8=2 U=2"
  done
}

# ======================================================================================
# Headless scenarios
# ======================================================================================

CREDS="${CHAT_RECORD_CREDS_DIR:-$HOME/.claude}"
MODEL="${CHAT_RECORD_MODEL:-haiku}"
HTIMEOUT="${CHAT_RECORD_TIMEOUT:-300}"
SB="$SCRATCH/headless"
CFG="$SB/cfg"
CANARY="$SB/canary-plugin"
# The calling session's plugin bin dirs are dropped so `chat-record` resolves only via
# the plugin under test.
BASEPATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -v '/plugins/' | paste -sd: -)"
NOTE_FMT=$'chat-record note --as haiku-4-5 <<\'EOF\'\n%s\nEOF'

headless_setup() {
  command -v claude >/dev/null || { echo "claude not on PATH" >&2; exit 2; }
  [ -f "$CREDS/.credentials.json" ] || { echo "no $CREDS/.credentials.json" >&2; exit 2; }
  mkdir -p "$CFG" "$CANARY/.claude-plugin" "$CANARY/hooks"
  cp "$CREDS/.credentials.json" "$CFG/"
  [ -f "$CREDS/.claude.json" ] && cp "$CREDS/.claude.json" "$CFG/"
  # Canary plugin: logs every UserPromptSubmit, Stop, and chat-record PreToolUse payload.
  echo '{"name":"chat-record-canary","version":"0.0.0"}' > "$CANARY/.claude-plugin/plugin.json"
  cat > "$CANARY/hooks/canary.sh" <<EOF
#!/usr/bin/env bash
IN="\$(cat)"
printf '{"event":"%s","stdin":%s}\n' "\$1" "\$(printf '%s' "\$IN" | jq -c .)" >> "\${CANARY_LOG:-$SB/canary-default.jsonl}"
exit 0
EOF
  chmod +x "$CANARY/hooks/canary.sh"
  cat > "$CANARY/hooks/hooks.json" <<'EOF'
{"hooks": {
  "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/canary.sh UserPromptSubmit"}]}],
  "Stop": [{"hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/canary.sh Stop"}]}],
  "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "if": "Bash(chat-record:*)", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/canary.sh PreToolUse"}]}]
}}
EOF
}

# hproj <name> [nochat]: fresh scratch project (git repo, cdocs/_chat/ unless nochat).
hproj() {
  local p="$SB/proj-$1"
  rm -rf "$p"; mkdir -p "$p"
  git -C "$p" init -q .
  [ "${2:-}" = nochat ] || mkdir -p "$p/cdocs/_chat"
  echo "canary fixture" > "$p/a.txt"
  printf '%s' "$p"
}

# claude_run <name> <proj> [env KEY=VAL ...] -- <claude args...>
# Writes $SB/<name>.jsonl (stream) and $SB/<name>.canary.jsonl (hook payloads).
claude_run() {
  local name="$1" proj="$2"; shift 2
  local -a envs=()
  while [ $# -gt 0 ] && [ "$1" != "--" ]; do envs+=("$1"); shift; done
  shift
  (cd "$proj" && timeout "$HTIMEOUT" env -i HOME="$HOME" PATH="$BASEPATH" TERM=dumb \
    CLAUDE_CONFIG_DIR="$CFG" CANARY_LOG="$SB/$name.canary.jsonl" "${envs[@]}" \
    claude --model "$MODEL" --plugin-dir "$PLUGIN" --plugin-dir "$CANARY" \
      --output-format stream-json --verbose --include-hook-events "$@") \
    >> "$SB/$name.jsonl" 2>> "$SB/$name.err"
}

# drive <name> <proj> <msg>...: one stream-json session, each message sent after the
# previous turn's result event (a turn-by-turn driver, so prompts are not queued).
drive() {
  local name="$1" proj="$2"; shift 2
  local fifo="$SB/$name.fifo" before t lim m
  rm -f "$fifo"; mkfifo "$fifo"
  claude_run "$name" "$proj" -- -p --input-format stream-json --permission-mode bypassPermissions < "$fifo" &
  local pid=$!
  exec 7> "$fifo"
  for m in "$@"; do
    before="$(grep -c '"type":"result"' "$SB/$name.jsonl" 2>/dev/null)"
    jq -cn --arg c "$m" '{type: "user", message: {role: "user", content: $c}}' >&7
    t=0; lim="$HTIMEOUT"
    case "$m" in /*) lim=60 ;; esac
    while [ "$(grep -c '"type":"result"' "$SB/$name.jsonl" 2>/dev/null)" -le "${before:-0}" ] && [ "$t" -lt "$lim" ]; do
      sleep 1; t=$((t + 1))
    done
  done
  exec 7>&-
  wait "$pid"
}

# Stream helpers.
stop_responses() { jq -c 'select(.type == "system" and .subtype == "hook_response" and .hook_event == "Stop") | .stdout' "$1"; }
# Stop fires are counted from the canary log: the stream has one hook_response per plugin.
stop_count() { jq -c 'select(.event == "Stop")' "${1%.jsonl}.canary.jsonl" 2>/dev/null | grep -c . ; }
stop_blocks() { stop_responses "$1" | grep -c 'decision' ; }
stream_sid() { jq -r 'select(.type == "system" and .subtype == "init") | .session_id' "$1" | head -n 1; }
# Results of the top-level Agent tool calls only (the subagents' final reports).
agent_results() { jq -rs '[.[] | select(.type == "assistant" and .parent_tool_use_id == null) | .message.content[]? | select(.type == "tool_use" and .name == "Agent") | .id] as $ids | .[] | select(.type == "user") | .message.content[]? | select(.type == "tool_result" and (.tool_use_id as $t | $ids | index($t))) | (.content | if type == "array" then map(.text // "") | join("") else . end)' "$1"; }
tool_results() { jq -r 'select(.type == "user") | .message.content[]? | select(.type == "tool_result") | (.content | if type == "array" then map(.text // "") | join("") else . end)' "$1"; }
# Records are dated files; README.md is not one.
the_rec() { ls "$1"/cdocs/_chat/[0-9]*.md 2>/dev/null | head -n 1; }
nrec() { ls "$1"/cdocs/_chat/[0-9]*.md 2>/dev/null | wc -l | tr -d ' '; }
entry_body() { # entry_body <record> <n>: body of the n-th agent entry
  split_record "$1" | awk -v n="$2" '/^<<H /{ k += ($0 !~ /^<<H user>>/); on = ($0 !~ /^<<H user>>/ && k == n); next } /^<<S /{ on = 0; next } on'
}
note_prompt() { # note_prompt <task> <bullet>
  printf '%s\nThen run exactly this Bash command, byte for byte (a quoted heredoc):\n%s\nThen reply done.' "$1" "$(printf "$NOTE_FMT" "$2")"
}

hs() { # hs <name> <description>: scenario header; returns 1 when filtered out
  want "$1" || return 1
  section "headless: $1 - $2"
  return 0
}

headless_suite() {
  headless_setup
  local P F J out sid sid2 b day

  if hs cmdv "command -v chat-record resolves into the plugin under test"; then
    P="$(hproj cmdv)"
    claude_run cmdv "$P" -- -p "$(note_prompt 'Run `command -v chat-record` with the Bash tool.' '- checked chat-record on PATH')" --permission-mode bypassPermissions
    has "command -v output is the plugin's bin" "$(tool_results "$SB/cmdv.jsonl")" "^$PLUGIN/bin/chat-record"
  fi

  if hs read_note "read a file, then note"; then
    P="$(hproj read_note)"
    claude_run read_note "$P" -- -p "$(note_prompt 'Read the file a.txt with the Read tool.' '- Read a.txt: canary fixture')" --permission-mode bypassPermissions
    J="$SB/read_note.jsonl"; F="$(the_rec "$P")"; sid="$(stream_sid "$J")"
    check "markers" "$(markers "$F")" "U A:haiku-4-5 S:${sid:0:8}"
    check "entry body" "$(entry_body "$F" 1)" "- Read a.txt: canary fixture"
    check "one Stop, no decision" "$(stop_count "$J"):$(stop_blocks "$J")" "1:0"
  fi

  if hs byte_exact "note body with shell metacharacters is byte-exact"; then
    P="$(hproj byte_exact)"
    b='- `rg -n "x"` keeps $HOME and $(date) literal; it'"'"'s a \back\slash "test"'
    claude_run byte_exact "$P" -- -p "$(note_prompt 'No other task.' "$b")" --permission-mode bypassPermissions
    F="$(the_rec "$P")"
    check "body byte-exact" "$(entry_body "$F" 1)" "$b"
  fi

  if [ "$RUN_OPTIONAL" = 1 ] && hs default_allowed "(optional) default mode with Bash(chat-record:*) allowed"; then
    P="$(hproj default_allowed)"
    claude_run default_allowed "$P" -- -p "$(note_prompt 'No other task.' '- default mode allowed')" \
      --permission-mode default --allowedTools 'Bash(chat-record:*)'
    J="$SB/default_allowed.jsonl"
    check "no permission_denials" "$(jq -c 'select(.type == "result") | .permission_denials' "$J")" "[]"
    check "one entry" "$(markers "$(the_rec "$P")" | cut -d' ' -f2)" "A:haiku-4-5"
  fi

  if [ "$RUN_OPTIONAL" = 1 ] && hs default_denied "(optional) default mode, no allow rule"; then
    P="$(hproj default_denied)"
    claude_run default_denied "$P" -- -p "$(note_prompt 'No other task.' '- default mode denied')" --permission-mode default
    J="$SB/default_denied.jsonl"; sid="$(stream_sid "$J")"
    has "note in permission_denials" "$(jq -c 'select(.type == "result") | .permission_denials' "$J")" "chat-record"
    check "first Stop blocks, second silent" "$(stop_count "$J"):$(stop_blocks "$J")" "2:1"
    check "@user then sign-off, no entry" "$(markers "$(the_rec "$P")")" "U S:${sid:0:8}"
  fi

  if hs block_recover "told not to note: first Stop blocks, model notes, second Stop silent"; then
    P="$(hproj block_recover)"
    claude_run block_recover "$P" -- -p 'Read the file a.txt with the Read tool and reply with its contents. Do not run chat-record unless a hook tells you to.' --permission-mode bypassPermissions
    J="$SB/block_recover.jsonl"; F="$(the_rec "$P")"; sid="$(stream_sid "$J")"
    out="$(stop_responses "$J" | grep decision | head -n 1 | jq -r . | jq -r .reason 2>/dev/null)"
    has "first Stop blocks with the real path" "$out" "record: cdocs/_chat/$(basename "$F")"
    has "block carries the heredoc command" "$out" "chat-record note --as <your model id> <<'EOF'"
    check "two Stops, one block" "$(stop_count "$J"):$(stop_blocks "$J")" "2:1"
    has "one entry then sign-off" "$(markers "$F")" "^U A:[^ ]+ S:${sid:0:8}\$"
  fi

  if hs no_tools "all tools forbidden: block once, then sign-off, no third Stop"; then
    P="$(hproj no_tools)"
    claude_run no_tools "$P" -- -p 'Reply with the single word ok.' --tools "" --permission-mode bypassPermissions
    J="$SB/no_tools.jsonl"; sid="$(stream_sid "$J")"
    check "two Stops, one block" "$(stop_count "$J"):$(stop_blocks "$J")" "2:1"
    check "@user then sign-off, no entry" "$(markers "$(the_rec "$P")")" "U S:${sid:0:8}"
  fi

  if hs minimal "minimal turn: reply ok, then note"; then
    P="$(hproj minimal)"
    claude_run minimal "$P" -- -p "$(note_prompt 'Reply ok.' '- replied ok')" --permission-mode bypassPermissions
    J="$SB/minimal.jsonl"; sid="$(stream_sid "$J")"
    check "one entry, one Stop, no block" "$(markers "$(the_rec "$P")")|$(stop_count "$J"):$(stop_blocks "$J")" "U A:haiku-4-5 S:${sid:0:8}|1:0"
  fi

  if hs two_prompts "two stream-json prompts, each noted"; then
    P="$(hproj two_prompts)"
    drive two_prompts "$P" "$(note_prompt 'Reply one.' '- turn one')" "$(note_prompt 'Reply two.' '- turn two')"
    J="$SB/two_prompts.jsonl"; F="$(the_rec "$P")"; sid="$(stream_sid "$J")"
    check "U A S twice" "$(markers "$F")" "U A:haiku-4-5 S:${sid:0:8} U A:haiku-4-5 S:${sid:0:8}"
    out="$(grep -oE "$TS_RE" "$F")"
    check "timestamps non-decreasing" "$out" "$(printf '%s\n' "$out" | sort)"
  fi

  if hs note_twice "note twice in one turn"; then
    P="$(hproj note_twice)"
    claude_run note_twice "$P" -- -p "$(note_prompt 'Run this Bash command first, exactly:
chat-record note --as haiku-4-5 <<'"'"'EOF'"'"'
- first note
EOF' '- second note')" --permission-mode bypassPermissions
    J="$SB/note_twice.jsonl"; sid="$(stream_sid "$J")"
    check "two entries, one sign-off" "$(markers "$(the_rec "$P")")" "U A:haiku-4-5 A:haiku-4-5 S:${sid:0:8}"
    check "one Stop, no block" "$(stop_count "$J"):$(stop_blocks "$J")" "1:0"
  fi

  if hs no_as "note without --as"; then
    P="$(hproj no_as)"
    claude_run no_as "$P" -- -p $'Run exactly this Bash command, byte for byte:\nchat-record note <<\'EOF\'\n- no speaker given\nEOF\nThen reply done.' --permission-mode bypassPermissions
    sid="$(stream_sid "$SB/no_as.jsonl")"
    check "speaker assistant" "$(markers "$(the_rec "$P")")" "U A:assistant S:${sid:0:8}"
  fi

  if hs session_env "CLAUDE_CODE_SESSION_ID equals the stream session_id and the file suffix"; then
    P="$(hproj session_env)"
    claude_run session_env "$P" -- -p "$(note_prompt 'Run `echo SID=$CLAUDE_CODE_SESSION_ID` with the Bash tool.' '- echoed the session id')" --permission-mode bypassPermissions
    J="$SB/session_env.jsonl"; sid="$(stream_sid "$J")"
    has "Bash env carries the stream session_id" "$(tool_results "$J")" "SID=$sid"
    check "record suffix is the session_id" "$(basename "$(the_rec "$P")")" "$(date +%Y-%m-%d)-$sid.md"
  fi

  if hs path_mode "chat-record path prints the path, creates nothing"; then
    P="$(hproj path_mode)"
    claude_run path_mode "$P" -- -p "$(note_prompt 'Run `chat-record path` with the Bash tool.' '- printed the record path')" --permission-mode bypassPermissions
    J="$SB/path_mode.jsonl"
    has "printed path is the record" "$(tool_results "$J")" "^cdocs/_chat/$(basename "$(the_rec "$P")")"
    check "exactly one record" "$(nrec "$P")" "1"
  fi

  if hs background "background Agent: notification turn not recorded, told not to note"; then
    P="$(hproj background)"
    claude_run background "$P" -- -p "Use the Agent tool with run_in_background set to true to dispatch a general-purpose agent whose task is: run \`echo bg-done\` with Bash and report the output. Do not wait for it. Then run exactly this Bash command, byte for byte:
$(printf "$NOTE_FMT" '- dispatched a background agent')
Then end your turn. Later, when the background agent's completion notification arrives, reply with the single word received and do NOT run chat-record or any tool." --permission-mode bypassPermissions
    J="$SB/background.jsonl"; F="$(the_rec "$P")"; sid="$(stream_sid "$J")"
    has "a harness prompt was delivered" "$(jq -c 'select(.event == "UserPromptSubmit") | .stdin.prompt' "$SB/background.canary.jsonl")" "task-notification"
    hasnt "no envelope line in the record" "$(cat "$F")" "<task-notification|<task-id>|<tool-use-id>|<output-file>"
    check "markers: one human turn only" "$(markers "$F")" "U A:haiku-4-5 S:${sid:0:8}"
    check "no Stop decision" "$(stop_blocks "$J")" "0"
    check "two Stops (human turn, notification turn)" "$(stop_count "$J")" "2"
  fi

  if hs background_note "background Agent: notification turn told to note"; then
    P="$(hproj background_note)"
    claude_run background_note "$P" -- -p "Use the Agent tool with run_in_background set to true to dispatch a general-purpose agent whose task is: run \`echo bg-done\` with Bash and report the output. Do not wait for it. Then run exactly this Bash command, byte for byte:
$(printf "$NOTE_FMT" '- dispatched a background agent')
Then end your turn. Later, when the background agent's completion notification arrives, run exactly this Bash command, byte for byte:
$(printf "$NOTE_FMT" '- background agent reported bg-done')
and then reply received." --permission-mode bypassPermissions
    J="$SB/background_note.jsonl"; F="$(the_rec "$P")"; sid="$(stream_sid "$J")"
    check "notification entry follows the sign-off and gets its own" "$(markers "$F")" \
      "U A:haiku-4-5 S:${sid:0:8} A:haiku-4-5 S:${sid:0:8}"
    check "no Stop decision" "$(stop_blocks "$J")" "0"
  fi

  if hs foreground_agent "foreground Agent reading a file: nothing written for agent_id events"; then
    P="$(hproj foreground_agent)"
    # Agents run in the background by default in 2.1.289; this forces a foreground run.
    claude_run foreground_agent "$P" CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 -- -p "$(note_prompt 'Use the Agent tool (foreground, general-purpose) to dispatch an agent whose task is: read the file a.txt and report its contents. Wait for its result.' '- subagent read a.txt')" --permission-mode bypassPermissions
    J="$SB/foreground_agent.jsonl"; F="$(the_rec "$P")"; sid="$(stream_sid "$J")"
    check "one @user, one entry, one sign-off" "$(markers "$F")" "U A:haiku-4-5 S:${sid:0:8}"
    check "UserPromptSubmit/Stop payloads with agent_id" \
      "$(jq -c 'select(.event != "PreToolUse" and (.stdin.agent_id // null) != null)' "$SB/foreground_agent.canary.jsonl" | grep -c .)" "0"
    has "an agent actually ran" "$(jq -c 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .name' "$J")" '"(Agent|Task)"'
    out="$(agent_results "$J")"
    hasnt "the agent ran in the foreground" "$out" 'Async agent launched'
    has "the agent reported a.txt" "$out" 'canary fixture'
  fi

  if hs top_level_only "rules loaded; proposer and fork dispatched; no subagent chat-record call"; then
    P="$(hproj top_level_only)"
    init_rules "$P"
    # Forks are gated behind CLAUDE_CODE_FORK_SUBAGENT in 2.1.289, and agents run in the
    # background by default there; CLAUDE_CODE_DISABLE_BACKGROUND_TASKS forces foreground.
    claude_run top_level_only "$P" CLAUDE_CODE_FORK_SUBAGENT=1 CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 -- -p 'Do not run chat-record yourself unless a hook tells you to. First, use the Agent tool to dispatch a foreground agent with subagent_type "cdocs:proposer" whose task is: write a short 3-section proposal stub about adding a --verbose flag to a hypothetical CLI, at cdocs/proposals/2026-10-05-verbose-flag.md, then re-read it and tighten one sentence. Wait for it. Second, use the Agent tool with subagent_type "fork" and the task: report the first line of a.txt. Wait for it. Then reply done.' --permission-mode bypassPermissions
    J="$SB/top_level_only.jsonl"; F="$(the_rec "$P")"
    check "no chat-record call with an agent_id" \
      "$(jq -c 'select(.event == "PreToolUse" and (.stdin.agent_id // null) != null)' "$SB/top_level_only.canary.jsonl" 2>/dev/null | grep -c .)" "0"
    check "top-level first Stop still blocks" "$(jq -c 'select(.event == "Stop") | .stdin.stop_hook_active' "$SB/top_level_only.canary.jsonl" | head -n 1):$(stop_blocks "$J")" "false:1"
    out="$(jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == "Agent") | .input.subagent_type' "$J" | paste -sd, -)"
    echo "  info: Agent subagent_types dispatched: $out"
    has "a cdocs:proposer and a fork were dispatched" "$out" 'cdocs:proposer.*fork|fork.*cdocs:proposer'
    hasnt "the fork dispatch was not refused" "$(tool_results "$J")" "Agent type 'fork' not found"
    # Positive controls: the no-leak check above is vacuous unless the subagents worked.
    out="$(agent_results "$J")"
    hasnt "both dispatches ran in the foreground" "$out" 'Async agent launched'
    has "the fork reported a.txt's first line" "$out" 'canary fixture'
    [ -s "$P/cdocs/proposals/2026-10-05-verbose-flag.md" ] && ok "the proposer wrote its proposal" \
      || bad "the proposer wrote no cdocs/proposals/2026-10-05-verbose-flag.md"
    out="$(jq -r 'select(.type == "assistant" and .parent_tool_use_id != null) | .message.content[]? | select(.type == "tool_use") | .name' "$J" | sort | uniq -c | awk '{printf "%s%s=%s", (NR > 1 ? "," : ""), $2, $1}')"
    echo "  info: subagent tool calls: $out"
    has "the subagents made tool calls under the rules" "$out" '(Write|Edit)='
  fi

  if hs slash_command "user slash command recorded as the raw invocation"; then
    P="$(hproj slash_command)"
    mkdir -p "$P/.claude/commands"
    printf '%s\n' 'Reply with: $ARGUMENTS' 'Then run exactly this Bash command, byte for byte:' "$(printf "$NOTE_FMT" '- echoed the argument')" > "$P/.claude/commands/echo.md"
    claude_run slash_command "$P" -- -p '/echo hello-world' --permission-mode bypassPermissions
    F="$(the_rec "$P")"
    check "@user body is the invocation" "$(split_record "$F" | sed -n '2p')" "/echo hello-world"
    check "one @user" "$(markers "$F" | tr ' ' '\n' | grep -c '^U$')" "1"
  fi

  if hs compact "stream-json /compact between two prompts leaves no trace"; then
    P="$(hproj compact)"
    drive compact "$P" "$(note_prompt 'Reply one.' '- turn one')" "/compact" "$(note_prompt 'Reply two.' '- turn two')"
    J="$SB/compact.jsonl"; F="$(the_rec "$P")"; sid="$(stream_sid "$J")"
    check "two turns, nothing between" "$(markers "$F")" "U A:haiku-4-5 S:${sid:0:8} U A:haiku-4-5 S:${sid:0:8}"
    hasnt "no line mentions compaction" "$(cat "$F")" "[Cc]ompact"
    has "a compaction happened" "$(jq -c 'select(.type == "system") | .subtype' "$J" | paste -sd' ' -)" "compact"
  fi

  if hs clear "stream-json /clear then a prompt: new file for the new session"; then
    P="$(hproj clear)"
    drive clear "$P" "$(note_prompt 'Reply one.' '- turn one')" "/clear" \
      "$(note_prompt 'Run `echo SID=$CLAUDE_CODE_SESSION_ID` with the Bash tool.' '- after clear')"
    J="$SB/clear.jsonl"; sid="$(stream_sid "$J")"
    check "two records" "$(nrec "$P")" "2"
    sid2="$(tool_results "$J" | sed -n 's/^SID=//p' | tail -n 1)"
    [ -n "$sid2" ] && [ "$sid2" != "$sid" ] && ok "Bash id after /clear is new ($sid2)" || bad "Bash id after /clear: '$sid2' (first $sid)"
    [ -f "$P/cdocs/_chat/$(date +%Y-%m-%d)-$sid2.md" ] && ok "second record named by the new id" || bad "no record for $sid2"
    check "first record ends at its sign-off" "$(markers "$P/cdocs/_chat/$(date +%Y-%m-%d)-$sid.md")" "U A:haiku-4-5 S:${sid:0:8}"
  fi

  if hs resume "--resume and --continue append; --fork-session starts a new file"; then
    P="$(hproj resume)"
    claude_run resume "$P" -- -p "$(note_prompt 'Reply one.' '- turn one')" --permission-mode bypassPermissions
    sid="$(stream_sid "$SB/resume.jsonl")"
    claude_run resume "$P" -- -p "$(note_prompt 'Reply two.' '- resumed')" --resume "$sid" --permission-mode bypassPermissions
    claude_run resume "$P" -- -p "$(note_prompt 'Reply three.' '- continued')" --continue --permission-mode bypassPermissions
    check "resume and continue append to the same file" "$(nrec "$P"):$(markers "$P/cdocs/_chat/$(date +%Y-%m-%d)-$sid.md" | tr ' ' '\n' | grep -c '^U$')" "1:3"
    claude_run resume "$P" -- -p "$(note_prompt 'Reply four.' '- forked')" --resume "$sid" --fork-session --permission-mode bypassPermissions
    check "fork-session starts a new file" "$(nrec "$P")" "2"
  fi

  if hs rename_record "stream-json /rename between two prompts starts a new record; the old one stays"; then
    P="$(hproj rename_record)"
    drive rename_record "$P" "$(note_prompt 'Reply one.' '- turn one')" "/rename Second Name" \
      "$(note_prompt 'Reply two.' '- turn two')"
    J="$SB/rename_record.jsonl"; sid="$(stream_sid "$J")"; day="$(date +%Y-%m-%d)"
    echo "  info: records: $(ls "$P/cdocs/_chat" | paste -sd' ' -)"
    check "two records" "$(nrec "$P")" "2"
    check "unnamed record: turn one only" "$(markers "$P/cdocs/_chat/$day-$sid.md")" "U A:haiku-4-5 S:${sid:0:8}"
    check "named record: turn two only" "$(markers "$P/cdocs/_chat/$day-second-name-$sid.md")" "U A:haiku-4-5 S:second-name"
    hasnt "no @user block for /rename" "$(cat "$P"/cdocs/_chat/[0-9]*.md)" "/rename"
    check "two Stops, no block" "$(stop_count "$J"):$(stop_blocks "$J")" "2:0"
  fi

  if hs rename_record_name "--name names the first record; --resume with another --name starts a new one"; then
    P="$(hproj rename_record_name)"
    claude_run rename_record_name "$P" -- -p "$(note_prompt 'Reply one.' '- turn one')" --name "First Name" \
      --permission-mode bypassPermissions
    sid="$(stream_sid "$SB/rename_record_name.jsonl")"; day="$(date +%Y-%m-%d)"
    claude_run rename_record_name "$P" -- -p "$(note_prompt 'Reply two.' '- turn two')" --resume "$sid" --name "Other" \
      --permission-mode bypassPermissions
    echo "  info: records: $(ls "$P/cdocs/_chat" | paste -sd' ' -)"
    check "two records, none unnamed" "$(nrec "$P"):$([ -e "$P/cdocs/_chat/$day-$sid.md" ] && echo unnamed)" "2:"
    check "first turn in first-name" "$(markers "$P/cdocs/_chat/$day-first-name-$sid.md")" "U A:haiku-4-5 S:first-name"
    check "resumed turn in other" "$(markers "$P/cdocs/_chat/$day-other-$sid.md")" "U A:haiku-4-5 S:other"
  fi

  if hs plan_mode "plan mode: one Stop, no decision, @user then sign-off"; then
    P="$(hproj plan_mode)"
    claude_run plan_mode "$P" -- -p 'Briefly plan how you would add a README to this project. Do not run any tools.' --permission-mode plan
    J="$SB/plan_mode.jsonl"; sid="$(stream_sid "$J")"
    check "one Stop, no decision" "$(stop_count "$J"):$(stop_blocks "$J")" "1:0"
    check "@user then sign-off" "$(markers "$(the_rec "$P")")" "U S:${sid:0:8}"
  fi

  if hs cd_sibling "cd into a sibling project with its own cdocs/_chat"; then
    P="$(hproj cd_sibling)"; local SIB; SIB="$(hproj cd_sibling_sib)"
    claude_run cd_sibling "$P" -- -p "Run the Bash command \`cd $SIB\` on its own. Then, as a separate Bash command, run exactly this, byte for byte:
$(printf "$NOTE_FMT" '- noted from the sibling')
Then reply done." --add-dir "$SIB" --permission-mode bypassPermissions
    J="$SB/cd_sibling.jsonl"; sid="$(stream_sid "$J")"
    check "original record holds only the unsigned @user" "$(markers "$(the_rec "$P")")" "U"
    check "note and sign-off land in the sibling" "$(markers "$(the_rec "$SIB")")" "A:haiku-4-5 S:${sid:0:8}"
    check "one Stop, no decision" "$(stop_count "$J"):$(stop_blocks "$J")" "1:0"
  fi

  if hs off "CDOCS_CHAT_RECORD=off"; then
    P="$(hproj off)"
    claude_run off "$P" CDOCS_CHAT_RECORD=off -- -p 'Read a.txt and reply with its contents. Do not run chat-record.' --permission-mode bypassPermissions
    J="$SB/off.jsonl"
    check "no file; one Stop, no decision" "$(nrec "$P"):$(stop_count "$J"):$(stop_blocks "$J")" "0:1:0"
  fi

  if hs uninitialized "cdocs/ without _chat/, and outside any git work tree"; then
    P="$(hproj uninit nochat)"; mkdir -p "$P/cdocs"
    claude_run uninit "$P" -- -p 'Read a.txt and reply with its contents. Do not run chat-record.' --permission-mode bypassPermissions
    J="$SB/uninit.jsonl"
    check "cdocs/ without _chat/: no file; one Stop, no decision" "$(ls -A "$P/cdocs" | wc -l | tr -d ' '):$(stop_count "$J"):$(stop_blocks "$J")" "0:1:0"
    P="$SB/nogit"; rm -rf "$P"; mkdir -p "$P/cdocs/_chat"; echo x > "$P/a.txt"
    claude_run nogit "$P" -- -p 'Read a.txt and reply with its contents. Do not run chat-record.' --permission-mode bypassPermissions
    J="$SB/nogit.jsonl"
    check "outside git: no file; one Stop, no decision" "$(nrec "$P"):$(stop_count "$J"):$(stop_blocks "$J")" "0:1:0"
  fi

  if hs payload_shape "hook payload fields"; then
    local C="$SB/read_note.canary.jsonl"
    if [ ! -s "$C" ]; then
      P="$(hproj payload_shape)"
      claude_run payload_shape "$P" -- -p "$(note_prompt 'No other task.' '- payload shape')" --permission-mode bypassPermissions
      C="$SB/payload_shape.canary.jsonl"
    fi
    check "UserPromptSubmit has prompt, session_id, cwd, transcript_path" \
      "$(jq -c 'select(.event == "UserPromptSubmit") | .stdin | [has("prompt"), has("session_id"), has("cwd"), has("transcript_path")]' "$C" | head -n 1)" "[true,true,true,true]"
    check "Stop has stop_hook_active, session_id, cwd, transcript_path, permission_mode" \
      "$(jq -c 'select(.event == "Stop") | .stdin | [has("stop_hook_active"), has("session_id"), has("cwd"), has("transcript_path"), has("permission_mode")]' "$C" | head -n 1)" "[true,true,true,true,true]"
  fi

  # Extras: run only when --only names them.
  if [ -n "$ONLY" ]; then
    want init_real && init_real
    want rules_check && rules_check
    want multi_turn && multi_turn
  fi
}

# Rule files in /cdocs:init's order (its AGENTS.md block, which step 3 follows).
init_rule_order() { sed -n 's/.*\[Full content of \([a-z-]*\.md\), frontmatter stripped\].*/\1/p' "$PLUGIN/skills/init/SKILL.md"; }

# init_rules <proj>: materialize the cdocs rules the way /cdocs:init does (marker plus every
# rule body, in init's order; no CLAUDE.md import, since Claude Code auto-loads .claude/rules/),
# plus the _chat scaffold.
init_rules() {
  local p="$1" hash f
  mkdir -p "$p/.claude/rules"
  hash="$(cd "$PLUGIN/rules" && ls *.md | sort | xargs cat | sha256sum | awk '{print $1}')"
  {
    echo "<!-- cdocs rules v$(jq -r .version "$PLUGIN/.claude-plugin/plugin.json") hash=$hash - regenerate with /cdocs:init (use version from plugin.json) -->"
    for f in $(init_rule_order); do f="$PLUGIN/rules/$f"; echo; awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {fm=0; next} !fm' "$f"; done
  } > "$p/.claude/rules/cdocs.md"
  printf '# Project\n' > "$p/CLAUDE.md"
  mkdir -p "$p/cdocs/devlogs" "$p/cdocs/proposals" "$p/cdocs/reviews" "$p/cdocs/reports" "$p/cdocs/_chat"
  printf '*.md merge=union\n' > "$p/cdocs/_chat/.gitattributes"
}

# init_real (extra, run with --only init_real): the real /cdocs:init skill in a sandbox project.
init_real() {
  section "headless: init_real - /cdocs:init scaffolds cdocs/_chat and rules; --minimal does not"
  local P J HTIMEOUT=900 # init writes every rule file twice (rules file, AGENTS.md)
  # CLAUDE.md is seeded with the legacy import line, which init must remove.
  P="$(hproj init_real nochat)"; printf '# Project\n\n@.claude/rules/cdocs.md\n' > "$P/CLAUDE.md"
  claude_run init_real "$P" -- -p '/cdocs:init' --permission-mode bypassPermissions
  J="$SB/init_real.jsonl"
  check ".gitattributes is the union rule" "$(cat "$P/cdocs/_chat/.gitattributes" 2>/dev/null)" "*.md merge=union"
  [ -s "$P/cdocs/_chat/README.md" ] && ok "_chat/README.md written" || bad "_chat/README.md missing"
  has "rules file carries the scope sentence" "$(cat "$P/.claude/rules/cdocs.md" 2>/dev/null)" \
    'Top-level agents must use the `chat-record` command'
  has "rules file carries the resumption step" "$(cat "$P/.claude/rules/cdocs.md" 2>/dev/null)" '\*\*After a compaction.* run `chat-record path`'
  hasnt "CLAUDE.md rules import line is gone" "$(cat "$P/CLAUDE.md")" '^@\.claude/rules/cdocs\.md'
  # Every rule reference in shipped content resolves against what init actually wrote.
  # `node --import tsx`, not the tsx CLI, whose IPC socket under a long TMPDIR exceeds the
  # unix socket path limit.
  local mat
  if mat="$(cd "$PLUGIN/../.." && node --import tsx scripts/check-rule-refs.ts --materialized "$P" 2>&1)"; then
    ok "check-rule-refs --materialized passes"
  else
    bad "check-rule-refs --materialized: $(printf '%s' "$mat" | grep -v -i deprecat | tail -n 5)"
  fi
  check "init turn: no record, no Stop decision" "$(nrec "$P"):$(stop_blocks "$J")" "0:0"
  P="$(hproj init_minimal nochat)"
  claude_run init_minimal "$P" -- -p '/cdocs:init --minimal' --permission-mode bypassPermissions
  [ -d "$P/cdocs/devlogs" ] && ok "--minimal created the doc directories" || bad "--minimal created no cdocs/devlogs"
  [ ! -e "$P/cdocs/_chat" ] && ok "--minimal creates no cdocs/_chat" || bad "--minimal created cdocs/_chat"
}

# rules_check (extra, run with --only rules_check): a session under the materialized rules is
# compacted mid-task; its first post-compaction tool calls should be `chat-record path` and
# reads of the Scratchpoint and the record tail, with no hook emitting additionalContext.
rules_check() {
  section "headless: rules_check - post-compaction resumption under the rules"
  local P J post
  P="$(hproj rules_check)"; init_rules "$P"
  drive rules_check "$P" \
    "Start a cdocs devlog at cdocs/devlogs/$(date +%Y-%m-%d)-greeter.md (frontmatter per the cdocs spec, Objective, Scratchpoint, Plan) for writing greeter.py, a script that prints hello. Follow the cdocs rules for the devlog (chat_record, Scratchpoint) and for this turn. Then write greeter.py." \
    "/compact" \
    "Continue with the next step: add a --name flag to greeter.py."
  J="$SB/rules_check.jsonl"
  post="$(awk '/"compact_boundary"/ {on = 1} on' "$J" | jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | "\(.name) \(.input.command // .input.file_path // "" | gsub("\n"; "; "))"' 2>/dev/null | head -n 8)"
  echo "  info: first post-compaction tool calls:"; printf '%s\n' "$post" | sed 's/^/    /'
  has "a compaction happened" "$(grep -c '"compact_boundary"' "$J")" '^[1-9]'
  has "first post-compaction call runs chat-record path" "$(printf '%s\n' "$post" | head -n 1)" 'chat-record path'
  # Reads that count must precede the first Write or Edit outside the devlog (acting on the task).
  local before; before="$(printf '%s\n' "$post" | awk '/^(Write|Edit) / && !/cdocs\/devlogs\// {exit} {print}')"
  # A read means the devlog's content was opened: a Read, or cat/sed/head/tail/awk on its
  # path. A lookup (`grep -l <path> cdocs/devlogs/*.md`) finds the devlog but reads nothing.
  has "devlog (Scratchpoint, handoff) read before acting" "$before" \
    '^(Read .*cdocs/devlogs/[^/]+\.md|Bash (.*[^A-Za-z0-9_-])?(cat|sed|head|tail|awk) [^|;&]*cdocs/devlogs/)'
  has "record tail read before acting" "$before" 'tail -n 80|^Read .*cdocs/_chat/'
  hasnt "no hook emitted additionalContext" "$(jq -r 'select(.type == "system" and .subtype == "hook_response") | .stdout' "$J")" 'additionalContext'
  echo "  info: devlog chat_record: $(grep -A2 '^chat_record:' "$P"/cdocs/devlogs/*.md 2>/dev/null | tr '\n' ' ')"
  echo "  info: record markers: $(markers "$(the_rec "$P")")"
}

# multi_turn (extra, run with --only multi_turn): a realistic multi-turn session under the
# materialized rules, never told how to note; every @user must get an entry and one sign-off.
multi_turn() {
  section "headless: multi_turn - $((${#MT_PROMPTS[@]})) resumed turns under the rules, no note instructions"
  local P sid i
  P="$(hproj multi_turn)"; init_rules "$P"
  claude_run multi_turn "$P" -- -p "${MT_PROMPTS[0]}" --permission-mode bypassPermissions
  sid="$(stream_sid "$SB/multi_turn.jsonl")"
  for ((i = 1; i < ${#MT_PROMPTS[@]}; i++)); do
    claude_run multi_turn "$P" -- -p "${MT_PROMPTS[$i]}" --resume "$sid" --permission-mode bypassPermissions
  done
  local F; F="$(the_rec "$P")"
  local m; m="$(markers "$F")"
  echo "  info: markers: $m"
  check "every @user followed by >=1 entry and exactly one sign-off" \
    "$(printf '%s' "$m" | sed -E 's/A:[^ ]+( A:[^ ]+)*/A/g; s/S:[^ ]+/S/g')" \
    "$(for ((i = 0; i < ${#MT_PROMPTS[@]}; i++)); do printf 'U A S '; done | sed 's/ $//')"
  # Failure picture: a second block or a loop. Each turn's Stops must be `S` or `S S*`
  # (blocked once, then stop_hook_active); the block count itself is reported, not gated.
  local seq; seq="$(jq -r 'select(.event == "UserPromptSubmit" or .event == "Stop") | .event[0:1] + (if .stdin.stop_hook_active then "*" else "" end)' "$SB/multi_turn.canary.jsonl" | paste -sd' ' -)"
  has "each turn blocks at most once and never loops" "$seq" '^(U S( S\*)?)( U S( S\*)?)*$'
  echo "  info: turns needing the one-shot block: $(stop_blocks "$SB/multi_turn.jsonl") of ${#MT_PROMPTS[@]}"
  cp "$F" "$SCRATCH/multi_turn-record.md" 2>/dev/null
  echo "  info: record copy: $SCRATCH/multi_turn-record.md (kept only with CHAT_RECORD_KEEP=1)"
}
MT_PROMPTS=(
  "Create a devlog for adding a tiny Python CLI to this project at cdocs/devlogs/$(date +%Y-%m-%d)-tiny-cli.md with frontmatter per the cdocs frontmatter spec, Objective and Plan sections."
  "Write cli.py: a script that prints the line count of a file given as its argument."
  "Run python3 cli.py a.txt and tell me the result."
  "Add a --words flag that prints the word count instead."
  "What does a.txt contain?"
  "Add a short README.md describing the CLI usage."
  "Make cli.py exit with status 2 and a message on stderr when the file is missing; test it."
  "Commit everything with git (set a local user.name and user.email first if needed)."
  "Summarize what we have done so far in two sentences."
  "Add a tests/test_cli.py using unittest that covers the line count; run it."
  "Rename the --words flag to --word-count everywhere."
  "Which files have we created?"
  "Update the devlog's Scratchpoint to reflect current state."
  "Add a --chars flag for character count and a test for it; run the tests."
  "Is there anything risky about how cli.py reads files? One paragraph."
  "Make cli.py read UTF-8 explicitly."
  "Run the full test suite again."
  "Commit the latest changes."
  "Append a Verification section to the devlog with the last test output."
  "We are done for now; give a one-line status."
)

# ======================================================================================

[ "$RUN_UNIT" = 1 ] && unit_suite
[ "$RUN_HEADLESS" = 1 ] && headless_suite

echo
echo "chat-record tests: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then printf '  %s\n' "${FAILED[@]}"; exit 1; fi
exit 0
