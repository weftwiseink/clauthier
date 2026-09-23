#!/usr/bin/env bash
# Unit tests for graphify-scope.sh -- the deterministic scoping mechanics I can exercise WITHOUT a
# real graphify binary (it is NOT installed on this host). A `graphify` STUB on PATH emits recorded
# fixture output / error codes so the present-binary path is exercised deterministically. The stub
# also records every invocation (a sentinel file) so the flag-off = zero-graphify-calls invariant is
# checkable, not merely asserted.
#
# Coverage (the verification floor):
#   - Brief SHAPE against stubbed CLI output: dependent set rendered, AID caveat present, observe/
#     subscribe channel present, NEVER-exhaustive framing.
#   - ALL fallback branches -> labeled skip-scope, no context narrowing:
#       flag off, missing binary, missing index, stale index, engine error, empty set.
#   - The near-empty-set-with-observe-sites -> CRDT skip-scope trigger (D3).
#   - Flag off -> NO graphify invocation (sentinel proof).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SH="$HERE/graphify-scope.sh"
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/gscope-test.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT
PASS=0; FAIL=0
ok()   { echo "  PASS: $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1 ($2)"; else bad "$1 (got '$2' want '$3')"; fi; }
has()  { if printf '%s' "$2" | grep -qE "$3"; then ok "$1"; else bad "$1 (missing /$3/)"; fi; }
hasnt(){ if printf '%s' "$2" | grep -qE "$3"; then bad "$1 (unexpected /$3/)"; else ok "$1"; fi; }

# --- the graphify STUB. One shim serves every case, steered by env vars. -----------------------
#   GSTUB_MODE     : ok (emit fixture) | error (exit 3)
#   GSTUB_FIXTURE  : path to JSON emitted for `explain`
#   GSTUB_SENTINEL : touched on EVERY invocation (proves the binary was/ wasn't called)
STUBDIR="$SCRATCH/bin"; mkdir -p "$STUBDIR"
cat > "$STUBDIR/graphify" <<'STUB'
#!/usr/bin/env bash
[ -n "${GSTUB_SENTINEL:-}" ] && echo "$*" >> "$GSTUB_SENTINEL"
case "$1" in
  explain)
    if [ "${GSTUB_MODE:-ok}" = "error" ]; then exit 3; fi
    if [ -n "${GSTUB_FIXTURE:-}" ] && [ -f "$GSTUB_FIXTURE" ]; then cat "$GSTUB_FIXTURE"; fi
    ;;
  *) : ;;
esac
exit 0
STUB
chmod +x "$STUBDIR/graphify"

# a multi-file dependent-set fixture (node + neighbors across several files), shape-tolerant.
FIX_MULTI="$SCRATCH/fix_multi.json"
cat > "$FIX_MULTI" <<'JSON'
{
  "node": { "id": "widget", "file": "src/widget.ts" },
  "neighbors": [
    { "id": "barrel",   "file": "src/index.ts",        "relation": "re-export" },
    { "id": "alias",    "file": "src/aliases.ts",      "relation": "aliased-re-export" },
    { "id": "consumer", "path": "src/app/consumer.ts", "relation": "import" }
  ]
}
JSON
# an EMPTY dependent-set fixture (engine resolves nothing)
FIX_EMPTY="$SCRATCH/fix_empty.json"
echo '{ "node": null, "neighbors": [] }' > "$FIX_EMPTY"

# --- a workspace with a touched file that carries observe/subscribe sites --------------------
WS="$SCRATCH/ws"; mkdir -p "$WS/src/app"
cat > "$WS/src/widget.ts" <<'TS'
export const widget = () => {
  store.observe(() => refresh());
  bus.subscribe(handler);
};
TS
IDX="$WS/graph.json"; echo '{}' > "$IDX"
# a leaf file with NO observe sites, for the plain empty-set case
cat > "$WS/src/leaf.ts" <<'TS'
export const leaf = 1;
TS

run() { # PATH-injected + env-scoped invocation of the script under test
  PATH="$STUBDIR:$PATH" "$@"
}

echo "=== TEST 1: flag OFF (default) -> disabled, ZERO graphify calls ==="
SENT="$SCRATCH/sent_off.log"
OUT="$(GSTUB_SENTINEL="$SENT" run bash "$SH" brief --files "src/widget.ts")"
has  "flag off labeled disabled"        "$OUT" "SCOPE-STATUS: disabled"
has  "flag off points at unscoped sweep" "$OUT" "SCOPE-FALLBACK: unscoped-sweep"
hasnt "flag off emits no dependent set"  "$OUT" "Resolved dependent set"
[ ! -f "$SENT" ] && ok "flag off invoked graphify ZERO times (no sentinel)" || bad "flag off called graphify: $(cat "$SENT")"

echo
echo "=== TEST 2: flag ON, fresh index, multi-file set -> scoped brief SHAPE ==="
touch -d '2000-01-01' "$WS/src/widget.ts"   # older than the index => fresh
touch "$IDX"
SENT="$SCRATCH/sent_on.log"
OUT="$(cd "$WS" && GSTUB_SENTINEL="$SENT" GSTUB_FIXTURE="$FIX_MULTI" run bash "$SH" brief \
        --enable --files "src/widget.ts" --index "$IDX")"
has  "scoped labeled"                    "$OUT" "SCOPE-STATUS: scoped"
has  "dependent set rendered"            "$OUT" "Resolved dependent set"
has  "  barrel re-export file listed"    "$OUT" "src/index.ts"
has  "  aliased re-export file listed"   "$OUT" "src/aliases.ts"
has  "  multi-hop consumer file listed"  "$OUT" "src/app/consumer.ts"
# fixture = node(widget) + 3 neighbors; the input widget.ts is excluded => dep count 3.
has  "input excluded from dep set (count=3)" "$OUT" "SCOPE-DEP-COUNT: 3"
has  "AID caveat present"                "$OUT" "AID, NOT a guarantee"
has  "never-exhaustive framing"          "$OUT" "NOT exhaustive|not treat this set as exhaustive|Do NOT treat this set as exhaustive"
has  "observe/subscribe channel present" "$OUT" "observe/subscribe channel"
has  "  observe site surfaced"           "$OUT" "widget.ts:.*observe"
has  "  subscribe site surfaced"         "$OUT" "widget.ts:.*subscribe"
has  "CLI follow-up instruction"         "$OUT" "graphify explain"
has  "never raw graph.json instruction"  "$OUT" "Never ingest raw graph.json"
check "graphify WAS invoked when scoped" "$([ -f "$SENT" ] && echo yes || echo no)" "yes"

echo
echo "=== TEST 3: fallback branch -- missing binary -> labeled skip-scope ==="
# empty PATH dir so `graphify` is absent
EMPTYBIN="$SCRATCH/emptybin"; mkdir -p "$EMPTYBIN"
OUT="$(cd "$WS" && PATH="$EMPTYBIN:/usr/bin:/bin" bash "$SH" brief --enable --files "src/widget.ts" --index "$IDX")"
has  "missing binary skip-scope"      "$OUT" "SCOPE-STATUS: skip-scope"
has  "missing binary reason"          "$OUT" "SCOPE-REASON: no-binary"
hasnt "missing binary no narrowing"   "$OUT" "Resolved dependent set"

echo
echo "=== TEST 4: fallback branch -- missing index -> labeled skip-scope ==="
OUT="$(cd "$WS" && GSTUB_FIXTURE="$FIX_MULTI" run bash "$SH" brief --enable --files "src/widget.ts" --index "$WS/nope.json")"
has  "missing index skip-scope"       "$OUT" "SCOPE-STATUS: skip-scope"
has  "missing index reason"           "$OUT" "SCOPE-REASON: missing-index"
hasnt "missing index no narrowing"    "$OUT" "Resolved dependent set"

echo
echo "=== TEST 5: fallback branch -- stale index -> labeled skip-scope ==="
touch "$IDX"                              # index now OLD relative to...
touch -d '2099-01-01' "$WS/src/widget.ts" # ...a changed file dated in the future => stale
OUT="$(cd "$WS" && GSTUB_FIXTURE="$FIX_MULTI" run bash "$SH" brief --enable --files "src/widget.ts" --index "$IDX")"
has  "stale index skip-scope"         "$OUT" "SCOPE-STATUS: skip-scope"
has  "stale index reason"             "$OUT" "SCOPE-REASON: stale-index"
hasnt "stale index no narrowing"      "$OUT" "Resolved dependent set"
touch -d '2000-01-01' "$WS/src/widget.ts"; touch "$IDX"   # restore fresh for later tests

echo
echo "=== TEST 6: fallback branch -- engine error -> labeled skip-scope ==="
OUT="$(cd "$WS" && GSTUB_MODE=error run bash "$SH" brief --enable --files "src/widget.ts" --index "$IDX")"
has  "engine error skip-scope"        "$OUT" "SCOPE-STATUS: skip-scope"
has  "engine error reason"            "$OUT" "SCOPE-REASON: engine-error"
hasnt "engine error no narrowing"     "$OUT" "Resolved dependent set"

echo
echo "=== TEST 7: near-empty set + observe sites -> CRDT skip-scope TRIGGER (D3) ==="
# widget.ts DOES carry observe/subscribe sites; the engine resolves an EMPTY dependent set.
OUT="$(cd "$WS" && GSTUB_FIXTURE="$FIX_EMPTY" run bash "$SH" brief --enable --files "src/widget.ts" --index "$IDX")"
has  "CRDT near-empty skip-scope"     "$OUT" "SCOPE-STATUS: skip-scope"
has  "CRDT near-empty reason"         "$OUT" "SCOPE-REASON: crdt-near-empty-trigger"
hasnt "CRDT trigger hands back NO small set" "$OUT" "Resolved dependent set"

echo
echo "=== TEST 8: empty set, NO observe sites -> empty-set skip-scope (engine-empty) ==="
# leaf.ts has no observe sites; engine resolves nothing => treat like a missing index.
touch -d '2000-01-01' "$WS/src/leaf.ts"; touch "$IDX"
OUT="$(cd "$WS" && GSTUB_FIXTURE="$FIX_EMPTY" run bash "$SH" brief --enable --files "src/leaf.ts" --index "$IDX")"
has  "empty set skip-scope"           "$OUT" "SCOPE-STATUS: skip-scope"
has  "empty set reason"               "$OUT" "SCOPE-REASON: empty-set"
hasnt "empty set no narrowing"        "$OUT" "Resolved dependent set"

echo
echo "=== TEST 9: multi-file set + observe sites -> scoped, observe channel CO-SURFACED ==="
# the healthy case: a real dependent set AND observe coupling both present -> scope, do not drop.
OUT="$(cd "$WS" && GSTUB_FIXTURE="$FIX_MULTI" run bash "$SH" brief --enable --files "src/widget.ts" --index "$IDX")"
has  "healthy multi-file scoped"      "$OUT" "SCOPE-STATUS: scoped"
has  "observe channel co-surfaced with real set" "$OUT" "nearby .observe/.subscribe site"
has  "observe count > 0 header"       "$OUT" "SCOPE-OBSERVE-COUNT: [1-9]"

echo
echo "======================================"
echo "RESULTS: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
