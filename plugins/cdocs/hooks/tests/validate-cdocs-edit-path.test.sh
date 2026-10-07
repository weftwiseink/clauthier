#!/usr/bin/env bash
# Unit tests for plugins/cdocs/hooks/validate-cdocs-edit-path.sh.
#
# Covers the agent_type guard: Claude Code reports a plugin-registered agent's
# agent_type as the plugin-scoped name (e.g. "cdocs:triage"), not the bare
# agent name, so the hook must match both forms. See
# cdocs/devlogs/2026-10-06-atlas-loose-ends.md for the empirical confirmation.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../validate-cdocs-edit-path.sh"

PASS=0; FAIL=0
ok()  { echo "  PASS: $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

# run <agent_type|""> <file_path|""> -> sets RC, OUT, ERR
run() {
  local agent_type="$1" file_path="$2" payload
  payload="$(jq -cn --arg a "$agent_type" --arg f "$file_path" \
    '{agent_type: (if $a == "" then null else $a end),
      tool_input: {file_path: (if $f == "" then null else $f end)}}')"
  OUT="$(printf '%s' "$payload" | "$HOOK" 2>"$HERE/.stderr.tmp")"
  RC=$?
  ERR="$(cat "$HERE/.stderr.tmp")"; rm -f "$HERE/.stderr.tmp"
}

check_allow() { # check_allow <name> <agent_type> <file_path>
  run "$2" "$3"
  [ "$RC" -eq 0 ] && ok "$1 (exit 0)" || bad "$1 (exit $RC, want 0; stderr: $ERR)"
}
check_block() { # check_block <name> <agent_type> <file_path>
  run "$2" "$3"
  if [ "$RC" -eq 2 ]; then ok "$1 (exit 2)"; else bad "$1 (exit $RC, want 2)"; fi
}

echo "== main session (no agent_type) is never restricted"
check_allow "no agent_type, cdocs path"       ""       "cdocs/devlogs/2026-01-01-x.md"
check_allow "no agent_type, non-cdocs path"   ""       "plugins/cdocs/README.md"

echo "== unknown/non-cdocs agent_type is never restricted"
check_allow "general-purpose, non-cdocs path" "general-purpose" "plugins/cdocs/README.md"
check_allow "cdocs:judge, non-cdocs path"     "cdocs:judge"     "plugins/cdocs/README.md"

echo "== bare cdocs agent names (pre-existing form)"
for a in triage nit-fix reviewer; do
  check_block "bare '$a', non-cdocs path" "$a" "plugins/cdocs/README.md"
  check_allow "bare '$a', cdocs path"     "$a" "cdocs/devlogs/2026-01-01-x.md"
done

echo "== cdocs:-prefixed agent names (actual agent_type Claude Code reports for plugin agents)"
for a in cdocs:triage cdocs:nit-fix cdocs:reviewer; do
  check_block "'$a', non-cdocs path" "$a" "plugins/cdocs/README.md"
  check_allow "'$a', cdocs path"     "$a" "cdocs/devlogs/2026-01-01-x.md"
done

echo "== no file_path: allow regardless of agent_type"
check_allow "cdocs:triage, no file_path" "cdocs:triage" ""

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
