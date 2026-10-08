#!/usr/bin/env bash
# Unit tests for plugins/cdocs/bin/cdocs-graphify against a `graphify` stub that logs argv,
# GRAPHIFY_OUT, and PWD. Fixture: a bare repo with worktrees `aaa` (listed first), `main`, and
# `wt` (branch feat), mirroring this repo's layout. Portable bash: CI runs it on Linux and macOS.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CG="$HERE/../../bin/cdocs-graphify"
T="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/cgfy-test.XXXXXX")" && pwd -P)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok()  { echo "  PASS: $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2' want '$3')"; fi; }
has() { if printf '%s' "$2" | grep -qE -- "$3"; then ok "$1"; else bad "$1 (missing /$3/)"; fi; }
hasnt() { if printf '%s' "$2" | grep -qE -- "$3"; then bad "$1 (unexpected /$3/)"; else ok "$1"; fi; }

mkdir -p "$T/stub" && cat >"$T/stub/graphify" <<'STUB'
#!/usr/bin/env bash
printf '<%s>' "$@" >>"$GLOG"; echo " OUT=${GRAPHIFY_OUT:-} PWD=$PWD" >>"$GLOG"
[ "$1" = update ] && { [ -n "${GSTUB_UPDFAIL:-}" ] && exit 4; exit 0; }
[ -n "${GSTUB_OUT:-}" ] && printf '%s\n' "$GSTUB_OUT"; exit "${GSTUB_RC:-0}"
STUB
chmod +x "$T/stub/graphify"
NOGFY=$(printf '%s' "$PATH" | tr ':' '\n' | while IFS= read -r d; do [ -x "$d/graphify" ] || printf '%s:' "$d"; done)
export GLOG="$T/log" PATH="$T/stub:$NOGFY"; unset GRAPHIFY_OUT; : >"$GLOG"
G() { git -c user.email=t@t -c user.name=t "$@"; }
mkdir -p "$T/seed/src" && cd "$T/seed" && git init -q . && git symbolic-ref HEAD refs/heads/main
printf 'a.observe(cb)\n' >src/a.ts; printf 'export const b = 1\n' >src/b.ts
G add -A && G commit -qm seed && G clone -q --bare "$T/seed" "$T/.bare"
W() { G -C "$T/.bare" worktree add -q "$@"; }
W "$T/aaa" -b aaa && W "$T/main" main && W "$T/wt" -b feat
WT="$T/wt"; MG="$T/main/graphify-out"; cd "$WT" || exit 1
run() { OUT=$("${CGENV[@]}" "$CG" "$@" 2>"$T/err"); RC=$?; ERR=$(cat "$T/err"); }
CGENV=(env)

echo "== availability"
CGENV=(env PATH="$NOGFY"); run query q
check "no graphify: exit 0, one stderr line" "$RC $(grep -c . "$T/err")" "0 1"
check "no graphify: no index created" "$([ -e "$WT/graphify-out" ] && echo y || echo n)" "n"
CGENV=(env); run query q
check "no index: exit 0, one stderr line, stub never queried" "$RC $(grep -c . "$T/err") $(grep -c '^<query>' "$GLOG")" "0 1 0"
(cd "$T" && "$CG" query q 2>"$T/err"); check "not in git: exit 0, one line" "$? $(grep -c . "$T/err")" "0 1"

echo "== copy from the main worktree's graph (found by branch, not list order)"
mkdir -p "$MG/2026-01-02" && echo '{}' >"$MG/graph.json" && echo "$T/main" >"$MG/.graphify_root" && echo m1 >"$MG/sentinel"
sum0=$(cksum <"$MG/graph.json"); : >"$GLOG"; run query "how does b work"
check "copied graph and sentinel" "$(cat "$WT/graphify-out/graph.json") $(cat "$WT/graphify-out/sentinel")" "{} m1"
check "copied .graphify_root and dated backups dropped, .gitignore is *" "$(ls -d "$WT/graphify-out/.graphify_root" "$WT/graphify-out/2026-01-02" 2>/dev/null)$(cat "$WT/graphify-out/.gitignore")" "*"
check "git status clean, no temp dir left" "$(git status --porcelain)$(ls -d "$WT"/graphify-out.tmp.* 2>/dev/null)" ""
check "update into the worktree index, then query" "$(sed 's/ PWD=.*//' "$GLOG")" \
  "<update><$WT> OUT=$WT/graphify-out
<query><how does b work><--graph><$WT/graphify-out/graph.json> OUT=$WT/graphify-out"
check "main graph untouched" "$(cksum <"$MG/graph.json") $([ -e "$MG/update.log" ] && echo y || echo n)" "$sum0 n"
echo m2 >"$MG/sentinel"; run query q
check "second call, unchanged tree: no copy, no update" "$(cat "$WT/graphify-out/sentinel") $(grep -c '^<update>' "$GLOG")" "m1 1"

echo "== GRAPHIFY_OUT names the main graph (container)"
rm -rf "$WT/graphify-out"; mv "$MG" "$T/shared"; CGENV=(env GRAPHIFY_OUT="$T/shared"); : >"$GLOG"; run query q
check "copied from GRAPHIFY_OUT, update targets the worktree" "$(cat "$WT/graphify-out/sentinel") $(grep -c "^<update>.*OUT=$WT/graphify-out" "$GLOG")" "m2 1"
check "shared graph untouched" "$(cksum <"$T/shared/graph.json") $([ -e "$T/shared/update.log" ] && echo y || echo n)" "$sum0 n"

echo "== ignore hint"
CGENV=(env); mkdir "$WT/cdocs"; run query q
check "cdocs/ without ignore line: one hint, query runs" "$(grep -c 'hint' "$T/err") $(grep -c '^<query>' "$GLOG")" "1 2"
echo "cdocs/" >"$WT/.graphifyignore"; run query q; check "unanchored cdocs/ line: hint" "$(grep -c 'hint' "$T/err")" "1"
echo "/cdocs/" >"$WT/.graphifyignore"; run query q; check "with /cdocs/ line: no stderr" "$ERR" ""

echo "== staleness stamp"
ups() { grep -c '^<update>' "$GLOG"; }
: >"$GLOG"; run query q; check "unchanged tree: update skipped" "$(ups)" "0"
echo x >"$WT/cdocs/note.md"; run query q; check "edit under ignored /cdocs/: update skipped" "$(ups)" "0"
echo "export const c = 2" >>"$WT/src/b.ts"; run query q; check "code edit: update runs" "$(ups)" "1"
G add src/b.ts && G commit -qm c; run query q; check "commit of the graphed edit: update skipped" "$(ups)" "1"

echo "== passthrough and update failure"
CGENV=(env GSTUB_OUT="hello out" GSTUB_RC=3); run path "A B" C
check "stdout and exit code unchanged" "$OUT|$RC" "hello out|3"
check "argv exact" "$(tail -n 1 "$GLOG" | sed 's/ OUT=.*//')" "<path><A B><C><--graph><$WT/graphify-out/graph.json>"
echo "// e" >>"$WT/src/b.ts"; CGENV=(env GSTUB_UPDFAIL=1 GSTUB_OUT=x); run explain e
check "update failure: one stderr line, query runs" "$(grep -c . "$T/err") $OUT $(tail -n 1 "$GLOG" | cut -c1-9)" "1 x <explain>"
CGENV=(env); : >"$GLOG"; run query q; check "failed update leaves the stamp stale" "$(ups)" "1"

echo "== runtime coupling"
CGENV=(env GSTUB_OUT="NODE a [src=src/a.ts loc=L1] at=src/b.ts:L1 consumer.ts"); run query q
has "observe site appended" "$OUT" "RUNTIME COUPLING \(not in the graph\):"
has "hit is path:line: text" "$OUT" "src/a.ts:1:a.observe\(cb\)"
CGENV=(env GSTUB_OUT="NODE b [src=src/b.ts loc=L1]"); run query q
hasnt "no coupling section without a hit" "$OUT" "RUNTIME COUPLING"
printf '"label": ".observe()",\n' >"$WT/graphify-out/graph.json"; CGENV=(env GSTUB_OUT="Graph: $WT/graphify-out/graph.json"); run query q
hasnt "absolute index path is not scanned" "$OUT" "RUNTIME COUPLING"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
