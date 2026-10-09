#!/usr/bin/env bash
# Unit tests for detect-usage.sh: transcript tool_use detection on hand-built JSONL fixtures
# (MCP full and bare name; CLI used, unused, no false positive, regex; caret anchor through a
# `cd <dir> &&` prefix, and the mid-string-argument negative).
# Run: bash scripts/detect-usage.test.sh
set -uo pipefail
# self-locating: the script under test sits next to this test file.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SH="$HERE/detect-usage.sh"
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/detect-usage-test.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT
PASS=0; FAIL=0
ok()   { echo "  PASS: $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1 ($2)"; else bad "$1 (got '$2' want '$3')"; fi; }

echo "=== detect-usage: transcript tool_use detection ==="
# fixture transcript WITH a target mcp tool_use (fully-qualified id)
cat > "$SCRATCH/tx_used.jsonl" <<'JSON'
{"type":"user","message":{"content":"go"}}
{"type":"assistant","message":{"content":[{"type":"text","text":"looking"},{"type":"tool_use","id":"t1","name":"Read","input":{}}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t2","name":"mcp__example__scope","input":{}}]}}
JSON
# fixture transcript WITHOUT the target tool (present-but-unused case)
cat > "$SCRATCH/tx_unused.jsonl" <<'JSON'
{"type":"user","message":{"content":"go"}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Read","input":{}}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t2","name":"Grep","input":{}}]}}
JSON
check "detect-usage: target used"   "$(bash "$SH" --transcript "$SCRATCH/tx_used.jsonl"   --tool mcp__example__scope)" "used"
check "detect-usage: target unused" "$(bash "$SH" --transcript "$SCRATCH/tx_unused.jsonl" --tool mcp__example__scope)" "unused"
# bare-name match against mcp__server__tool form
check "detect-usage: bare-name match" "$(bash "$SH" --transcript "$SCRATCH/tx_used.jsonl" --tool scope)" "used"

# --- CLI-first detection (a CLI shell-out surfaces as a Bash tool_use) ---
# fixture: a Bash tool_use running the sometool CLI
cat > "$SCRATCH/tx_cli_used.jsonl" <<'JSON'
{"type":"user","message":{"content":"go"}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Read","input":{}}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t2","name":"Bash","input":{"command":"sometool update --scope src/","description":"scope"}}]}}
JSON
# fixture: a Bash tool_use running SOMETHING ELSE (sometool never invoked -> unused)
cat > "$SCRATCH/tx_cli_unused.jsonl" <<'JSON'
{"type":"user","message":{"content":"go"}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"rg -n foo src/","description":"grep"}}]}}
JSON
check "detect-usage CLI: sometool invoked -> used"  "$(bash "$SH" --transcript "$SCRATCH/tx_cli_used.jsonl"   --tool 'cli:sometool ')" "used"
check "detect-usage CLI: other command -> unused"   "$(bash "$SH" --transcript "$SCRATCH/tx_cli_unused.jsonl" --tool 'cli:sometool ')" "unused"
# a CLI signature must NOT be satisfied by a Bash call to an unrelated command
check "detect-usage CLI: no false-positive on Bash" "$(bash "$SH" --transcript "$SCRATCH/tx_used.jsonl" --tool 'cli:sometool ')" "unused"
# regex form of the signature works too
check "detect-usage CLI: regex signature"           "$(bash "$SH" --transcript "$SCRATCH/tx_cli_used.jsonl" --tool 'cli:sometool (update|scope)')" "used"

# --- caret anchor vs a `cd <dir> && …` prefix ---
# agents often wrap commands as `cd <dir> && <cmd>`; a caret anchor must match the real
# command, not the leading `cd`, or it reports a false `unused` on a run where sometool
# WAS invoked.
cat > "$SCRATCH/tx_cli_wt_used.jsonl" <<'JSON'
{"type":"user","message":{"content":"go"}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"cd /some/worktree && sometool update --scope src/","description":"scope"}}]}}
JSON
# cd-prefixed Bash that never runs sometool -> must stay unused (no false positive)
cat > "$SCRATCH/tx_cli_wt_unused.jsonl" <<'JSON'
{"type":"user","message":{"content":"go"}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"cd /wt && rg foo","description":"grep"}}]}}
JSON
check "detect-usage CLI: caret anchor matches through cd-prefix -> used" \
  "$(bash "$SH" --transcript "$SCRATCH/tx_cli_wt_used.jsonl" --tool 'cli:^sometool ')" "used"
check "detect-usage CLI: caret anchor, cd-prefixed non-sometool -> unused" \
  "$(bash "$SH" --transcript "$SCRATCH/tx_cli_wt_unused.jsonl" --tool 'cli:^sometool ')" "unused"
# caret anchor on a bare command still works (whole-string is a segment too)
check "detect-usage CLI: caret anchor, bare command -> used" \
  "$(bash "$SH" --transcript "$SCRATCH/tx_cli_used.jsonl" --tool 'cli:^sometool ')" "used"
# caret anchor must NOT match a command that only mentions sometool mid-string as an arg
cat > "$SCRATCH/tx_cli_wt_arg.jsonl" <<'JSON'
{"type":"user","message":{"content":"go"}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"cd /wt && rg sometool src/","description":"grep"}}]}}
JSON
check "detect-usage CLI: caret anchor, sometool only as rg arg -> unused" \
  "$(bash "$SH" --transcript "$SCRATCH/tx_cli_wt_arg.jsonl" --tool 'cli:^sometool ')" "unused"

echo
echo "======================================"
echo "RESULTS: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
