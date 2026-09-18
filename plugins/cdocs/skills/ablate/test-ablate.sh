#!/usr/bin/env bash
# Unit tests for ablate.sh — the deterministic mechanics I can exercise WITHOUT dispatch.
# Covers: (1) worktree isolation off a pinned base w/o touching the stash stack, on THIS repo's
# bare+worktree layout; (2) meter aggregation from a hand-written mock payload; (3) transcript
# tool_use parsing + VALID/VOID/TASK-FAIL decision on hand-built fixtures, incl. VOID>TASK-FAIL.
set -uo pipefail
# self-locating: the script under test sits next to this test file.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SH="$HERE/ablate.sh"
REPO="$(git -C "$HERE" rev-parse --show-toplevel)"
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/ablate-test.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT
PASS=0; FAIL=0
ok()   { echo "  PASS: $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1 ($2)"; else bad "$1 (got '$2' want '$3')"; fi; }

echo "=== TEST 1: worktree isolation off a pinned base, stash stack untouched ==="
cd "$REPO"
STASH_BEFORE="$(git stash list | wc -l | tr -d ' ')"
BASE="$(git rev-parse HEAD)"
WA="$SCRATCH/arm-A"; WB="$SCRATCH/arm-B"
# real repo tree carries WIP (.lace/*.json); the ablation tests the COMMITTED base, so --allow-dirty.
CA="$(bash "$SH" worktree-create --base "$BASE" --path "$WA" --allow-dirty 2>/dev/null)"
CB="$(bash "$SH" worktree-create --base "$BASE" --path "$WB" --allow-dirty 2>/dev/null)"
check "arm A checked out at pinned base" "$CA" "$BASE"
check "arm B checked out at pinned base" "$CB" "$BASE"
[ -d "$WA/.git" -o -f "$WA/.git" ] && ok "arm A worktree exists" || bad "arm A worktree exists"
[ -d "$WB/.git" -o -f "$WB/.git" ] && ok "arm B worktree exists" || bad "arm B worktree exists"
# cross-arm contamination: write into A, assert B unaffected
echo "ARM-A-ONLY" > "$WA/ABLATE_ARM_MARKER.txt"
[ ! -e "$WB/ABLATE_ARM_MARKER.txt" ] && ok "arm A write invisible to arm B (fs isolation)" || bad "arm A write leaked to arm B"
# both start byte-identical to base
DA="$(git -C "$WA" rev-parse HEAD)"; DB="$(git -C "$WB" rev-parse HEAD)"
check "arms start from identical base commit" "$DA" "$DB"
# teardown captures diff first, then removes (dirty tree => needs --force)
bash "$SH" worktree-remove --path "$WA" --diff-out "$SCRATCH/A.diff" >/dev/null 2>&1
bash "$SH" worktree-remove --path "$WB" >/dev/null 2>&1
[ ! -e "$WA" ] && ok "arm A removed on teardown" || bad "arm A not removed"
[ ! -e "$WB" ] && ok "arm B removed on teardown" || bad "arm B not removed"
grep -q "ARM-A-ONLY" "$SCRATCH/A.diff" 2>/dev/null && ok "arm A diff captured before removal" || bad "arm A diff not captured"
STASH_AFTER="$(git stash list | wc -l | tr -d ' ')"
check "stash stack depth UNCHANGED (never touched)" "$STASH_AFTER" "$STASH_BEFORE"
git worktree prune 2>/dev/null || true

echo
echo "=== TEST 1b: dirty-tree refusal (guard), --allow-dirty override ==="
# simulate by pointing at a dir with a tracked-file modification: use a temp clone-ish check.
# We can't easily dirty the real repo safely; instead assert the guard fires on a synthetic dirty
# tree by checking the code path via a subshell in an isolated throwaway git repo.
TR="$SCRATCH/dirtyrepo"; mkdir -p "$TR"; ( cd "$TR" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > f && git add f && git commit -qm init && echo b >> f )
OUT="$(cd "$TR" && bash "$SH" worktree-create --base HEAD --path "$SCRATCH/dw" 2>&1 || true)"
echo "$OUT" | grep -q "invoking tree is dirty" && ok "dirty tree REFUSED by default" || bad "dirty tree not refused ($OUT)"
[ ! -e "$SCRATCH/dw" ] && ok "no worktree created on refusal" || bad "worktree created despite refusal"
( cd "$TR" && bash "$SH" worktree-create --base HEAD --path "$SCRATCH/dw" --allow-dirty >/dev/null 2>&1 ) \
  && [ -e "$SCRATCH/dw" ] && ok "--allow-dirty override creates worktree (tests committed base)" || bad "--allow-dirty did not create worktree"
( cd "$TR" && bash "$SH" worktree-remove --path "$SCRATCH/dw" >/dev/null 2>&1 ) || true

echo
echo "=== TEST 2: meter aggregation from a MOCK Task result payload ==="
# hand-written payload mirroring Claude Code's real toolUseResult shape (confirmed field names).
cat > "$SCRATCH/payload.json" <<'JSON'
{
  "agentId": "a1b2c3d4e5f6",
  "status": "completed",
  "totalTokens": 48213,
  "totalDurationMs": 91234,
  "totalToolUseCount": 17,
  "usage": { "input_tokens": 41000, "output_tokens": 7213, "cache_read_input_tokens": 300000 }
}
JSON
bash "$SH" meter --payload "$SCRATCH/payload.json" --arm assisted --tool "mcp__graphify__scope" \
  --tool-granted true --tool-invoked used --task-completed true \
  --transcript "/x/agent.jsonl" --diff "/x/A.diff" --out "$SCRATCH/A.meter.json" >/dev/null
M="$SCRATCH/A.meter.json"
check "meter tokens from totalTokens"        "$(jq -r '.tokens' "$M")"        "48213"
check "meter duration_ms from totalDurationMs" "$(jq -r '.duration_ms' "$M")"  "91234"
check "meter tool_use_count from totalToolUseCount" "$(jq -r '.tool_use_count' "$M")" "17"
check "meter agent_id"                        "$(jq -r '.agent_id' "$M")"      "a1b2c3d4e5f6"
check "meter status"                          "$(jq -r '.status' "$M")"        "completed"
check "meter arm_label defaults A for assisted" "$(jq -r '.arm_label' "$M")"   "A"
check "meter tool_granted bool"               "$(jq -r '.tool_granted' "$M")"  "true"
check "meter tool_invocation_confirmed (assisted)" "$(jq -r '.tool_invocation_confirmed' "$M")" "true"
check "meter usage passthrough preserved"     "$(jq -r '.usage.output_tokens' "$M")" "7213"
[ "$(jq -r '.duration_note' "$M")" != "null" ] && ok "duration flagged INDICATIVE in meter" || bad "duration not flagged"
# alias test: a payload using the proposal's placeholder names still reads
cat > "$SCRATCH/payload_alias.json" <<'JSON'
{ "subagent_tokens": 100, "duration_ms": 200 }
JSON
bash "$SH" meter --payload "$SCRATCH/payload_alias.json" --arm unassisted --out "$SCRATCH/al.meter.json" >/dev/null
check "meter aliases subagent_tokens->tokens" "$(jq -r '.tokens' "$SCRATCH/al.meter.json")" "100"
check "unassisted arm tool_invocation_confirmed is null" "$(jq -r '.tool_invocation_confirmed' "$SCRATCH/al.meter.json")" "null"

echo
echo "=== TEST 3: transcript tool_use detection + outcome decision fixtures ==="
# fixture transcript WITH a target mcp tool_use (fully-qualified id)
cat > "$SCRATCH/tx_used.jsonl" <<'JSON'
{"type":"user","message":{"content":"go"}}
{"type":"assistant","message":{"content":[{"type":"text","text":"looking"},{"type":"tool_use","id":"t1","name":"Read","input":{}}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t2","name":"mcp__graphify__scope","input":{}}]}}
JSON
# fixture transcript WITHOUT the target tool (present-but-unused case)
cat > "$SCRATCH/tx_unused.jsonl" <<'JSON'
{"type":"user","message":{"content":"go"}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Read","input":{}}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t2","name":"Grep","input":{}}]}}
JSON
check "detect-usage: target used"   "$(bash "$SH" detect-usage --transcript "$SCRATCH/tx_used.jsonl"   --tool mcp__graphify__scope)" "used"
check "detect-usage: target unused" "$(bash "$SH" detect-usage --transcript "$SCRATCH/tx_unused.jsonl" --tool mcp__graphify__scope)" "unused"
# bare-name match against mcp__server__tool form
check "detect-usage: bare-name match" "$(bash "$SH" detect-usage --transcript "$SCRATCH/tx_used.jsonl" --tool scope)" "used"

# --- CLI-first detection (graphify is CLI-first: shell-out surfaces as a Bash tool_use) ---
# fixture: a Bash tool_use running the graphify CLI (the assisted-arm treatment for a CLI tool)
cat > "$SCRATCH/tx_cli_used.jsonl" <<'JSON'
{"type":"user","message":{"content":"go"}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Read","input":{}}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t2","name":"Bash","input":{"command":"graphify update --scope src/","description":"scope"}}]}}
JSON
# fixture: a Bash tool_use running SOMETHING ELSE (graphify never invoked -> unused/VOID)
cat > "$SCRATCH/tx_cli_unused.jsonl" <<'JSON'
{"type":"user","message":{"content":"go"}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"rg -n foo src/","description":"grep"}}]}}
JSON
check "detect-usage CLI: graphify invoked -> used"  "$(bash "$SH" detect-usage --transcript "$SCRATCH/tx_cli_used.jsonl"   --tool 'cli:graphify ')" "used"
check "detect-usage CLI: other command -> unused"   "$(bash "$SH" detect-usage --transcript "$SCRATCH/tx_cli_unused.jsonl" --tool 'cli:graphify ')" "unused"
# a CLI signature must NOT be satisfied by a Bash call to an unrelated command
check "detect-usage CLI: no false-positive on Bash" "$(bash "$SH" detect-usage --transcript "$SCRATCH/tx_used.jsonl" --tool 'cli:graphify ')" "unused"
# regex form of the signature works too
check "detect-usage CLI: regex signature"           "$(bash "$SH" detect-usage --transcript "$SCRATCH/tx_cli_used.jsonl" --tool 'cli:graphify (update|scope)')" "used"

mk_meter(){ # arm granted invoked completed -> file
  local f="$SCRATCH/m_$1_$RANDOM.json"
  jq -n --arg arm "$1" --argjson g "$2" --arg inv "$3" --argjson c "$4" \
    '{arm:$arm, tool:"mcp__graphify__scope", tool_granted:$g, tokens:100, duration_ms:100,
      task_completed:$c, tool_invocation_confirmed:(if $arm=="assisted" then ($inv=="used") else null end)}' > "$f"
  echo "$f"
}
# Case A: tool used, both complete -> VALID
AV=$(mk_meter assisted true used true);  UV=$(mk_meter unassisted true "" true)
check "VALID: used + both complete"   "$(bash "$SH" decide --assisted "$AV" --unassisted "$UV" | jq -r '.outcome')" "VALID"
# Case B: present-but-unused -> VOID (available_unused)
AB=$(mk_meter assisted true unused true)
check "VOID: present-but-unused"      "$(bash "$SH" decide --assisted "$AB" --unassisted "$UV" | jq -r '.outcome')" "VOID"
check "VOID reason: available_unused" "$(bash "$SH" decide --assisted "$AB" --unassisted "$UV" | jq -r '.void_reason')" "available_unused"
# Case C: tool unavailable -> VOID (unavailable)
AC=$(mk_meter assisted false unused true)
check "VOID: tool unavailable"        "$(bash "$SH" decide --assisted "$AC" --unassisted "$UV" | jq -r '.outcome')" "VOID"
check "VOID reason: unavailable"      "$(bash "$SH" decide --assisted "$AC" --unassisted "$UV" | jq -r '.void_reason')" "unavailable"
# Case D: used-but-incomplete -> TASK-FAIL
AD=$(mk_meter assisted true used false)
check "TASK-FAIL: used but incomplete" "$(bash "$SH" decide --assisted "$AD" --unassisted "$UV" | jq -r '.outcome')" "TASK-FAIL"
# Case E: VOID PRECEDENCE over TASK-FAIL: unused AND incomplete -> must be VOID, not TASK-FAIL
AE=$(mk_meter assisted true unused false)
check "VOID precedence over TASK-FAIL" "$(bash "$SH" decide --assisted "$AE" --unassisted "$UV" | jq -r '.outcome')" "VOID"

# --- null-completion guard (nit): a MISSING completion flag must not silently pass as completed ---
AN=$(jq -n '{arm:"assisted", tool_granted:true, tokens:1, duration_ms:1, task_completed:null, tool_invocation_confirmed:true}' > "$SCRATCH/an.json"; echo "$SCRATCH/an.json")
UN=$(jq -n '{arm:"unassisted", tool_granted:false, tokens:1, duration_ms:1, task_completed:null, tool_invocation_confirmed:null}' > "$SCRATCH/un.json"; echo "$SCRATCH/un.json")
UNC=$(mk_meter unassisted true "" true)
# non-VOID run (granted+used) with null completion -> REFUSE (exit != 0)
bash "$SH" decide --assisted "$AN" --unassisted "$UNC" >/dev/null 2>&1
check "null completion on non-VOID run REFUSED (exit)" "$?" "1"
# VOID run (tool unavailable) still resolves despite null completion (completion irrelevant by precedence)
AUV=$(jq -n '{arm:"assisted", tool_granted:false, tokens:1, duration_ms:1, task_completed:null, tool_invocation_confirmed:false}' > "$SCRATCH/auv.json"; echo "$SCRATCH/auv.json")
check "null completion tolerated on VOID run" "$(bash "$SH" decide --assisted "$AUV" --unassisted "$UN" 2>/dev/null | jq -r '.outcome')" "VOID"

echo
echo "=== TEST 4: scorecard single-shot gate_admissible guard ==="
OUTF="$SCRATCH/outcome.json"; bash "$SH" decide --assisted "$AV" --unassisted "$UV" > "$OUTF"
bash "$SH" scorecard --outcome "$OUTF" --assisted "$AV" --unassisted "$UV" --trials 1 --run-dir "$SCRATCH/run1" >/dev/null
check "single-shot VALID gate_admissible=false" "$(jq -r '.gate_admissible' "$SCRATCH/run1/scorecard.json")" "false"
[ "$(jq -r '.single_shot_caveat' "$SCRATCH/run1/scorecard.json")" != "null" ] && ok "single-shot caveat present" || bad "single-shot caveat missing"
check "token_delta computed"  "$(jq -r '.token_delta.delta' "$SCRATCH/run1/scorecard.json")" "0"
[ -f "$SCRATCH/run1/scorecard.md" ] && ok "scorecard.md emitted" || bad "scorecard.md missing"
grep -q "Outcome: VALID" "$SCRATCH/run1/scorecard.md" && ok "scorecard.md leads with outcome" || bad "md missing outcome lead"
# a VOID run still emits a scorecard with gate_admissible=false and no context_gap
bash "$SH" decide --assisted "$AB" --unassisted "$UV" > "$SCRATCH/vout.json"
bash "$SH" scorecard --outcome "$SCRATCH/vout.json" --assisted "$AB" --unassisted "$UV" --trials 1 --run-dir "$SCRATCH/run2" >/dev/null
check "VOID run emits scorecard, gate_admissible=false" "$(jq -r '.gate_admissible' "$SCRATCH/run2/scorecard.json")" "false"
check "VOID run has null context_gap" "$(jq -r '.context_gap' "$SCRATCH/run2/scorecard.json")" "null"
# even hypothetically multi-trial, a VOID never becomes admissible
bash "$SH" scorecard --outcome "$SCRATCH/vout.json" --assisted "$AB" --unassisted "$UV" --trials 3 --run-dir "$SCRATCH/run3" >/dev/null
check "VOID never admissible even at trials>1" "$(jq -r '.gate_admissible' "$SCRATCH/run3/scorecard.json")" "false"

echo
echo "======================================"
echo "RESULTS: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
