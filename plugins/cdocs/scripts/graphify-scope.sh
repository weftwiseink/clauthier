#!/usr/bin/env bash
# graphify-scope.sh - thin, CLI-backed graph-scoping helper for cdocs loops (proposal Phase 2).
#
# Turns a round's changed files/symbols into a compact SCOPED-CONTEXT BRIEF by shelling out to
# graphify's QUERY SUBCOMMANDS (`explain`/`query`/`path`) over its pre-built index -- NEVER raw
# `graph.json` ingestion (D4). The brief carries the resolved multi-file dependent set, the standing
# AID-not-guarantee caveat (D3), and a co-surfaced `.observe`/`.subscribe` channel for the touched
# files (the D3 structural CRDT guard). It is deliberately MINIMAL: prime a brief + point the role
# at the graphify CLI for follow-ups; nothing more.
#
# Non-negotiable disciplines this script enforces mechanically (so a token-pressured role cannot
# skip them):
#   - ADDITIVE ONLY. The brief only ever ADDS context. Its absence must NEVER lower baseline recall.
#   - skip-scope (labeled) on: flag off, missing graphify binary, missing index, stale index,
#     engine error, OR an empty/near-empty dependent set. Every non-scoped exit prints a LABELED
#     `SCOPE-STATUS:` marker so instrumentation tells scoped rounds from fallback rounds, and emits
#     NOTHING that narrows context -- the consuming role falls back to today's unscoped sweep.
#   - CRDT trigger (D3). A near-empty graph set on touched files that DO carry `.observe`/`.subscribe`
#     sites TRIGGERS skip-scope (never hand back a small confident set that masks CRDT coupling).
#   - NEVER exhaustive. A scoped brief always co-surfaces the observe/subscribe channel and the
#     AID caveat, and never frames the dependent set as complete.
#
# The graphify-specific parse is isolated to ONE function (`graphify_dependents`) so a later swap
# onto the engine-agnostic adapter or the MCP transport is a surface change, not a rewrite (D4).
#
# graphify is NOT installed on the authoring host; this script is exercised host-side by
# test-graphify-scope.sh against a `graphify` STUB on PATH (fixtures + error codes). The LIVE
# real-graphify ablate spot-check is the overseer's job, not this script's.
#
# jq 1.6-compatible; container-safe bash. Never touches the git stash stack.
set -euo pipefail

die() { echo "graphify-scope: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }
need jq

# --- arg parsing: reads --flag value pairs into the assoc array A -----------------------------
declare -A A
parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --*) local k="${1#--}"; shift
           if [ $# -gt 0 ] && [[ "${1:-}" != --* ]]; then A["$k"]="$1"; shift
           else A["$k"]=1; fi ;;
      *) die "unexpected argument: $1" ;;
    esac
  done
}

# ---------------------------------------------------------------------------------------------
# skip: print the labeled fallback marker and exit 0 (additive: skip never blocks a round).
#   status  : "disabled" | "skip-scope"
#   reason  : machine-readable reason token (empty for disabled)
# Emits NOTHING that narrows context: just the label plus a one-line instruction to fall back to
# the unscoped sweep. Instrumentation greps `SCOPE-STATUS:` to classify the round.
# ---------------------------------------------------------------------------------------------
skip() {
  local status="$1" reason="${2:-}"
  echo "SCOPE-STATUS: $status"
  [ -n "$reason" ] && echo "SCOPE-REASON: $reason"
  echo "SCOPE-FALLBACK: unscoped-sweep"
  echo "# graphify scoping did not run this round; this is ADDITIVE fallback, not a narrowing."
  echo "# Fall back to your normal unscoped context-gathering sweep -- recall is unchanged."
  exit 0
}

# ---------------------------------------------------------------------------------------------
# graphify_dependents (THE thin translation layer -- the ONLY graphify-shape-coupled function).
# Shells out to `graphify explain <target> --json` per target and unions the resolved file set.
# Uses the QUERY SUBCOMMAND only, never raw graph.json. Robust to output-shape drift: pulls every
# `.file`/`.path` field at any depth of the JSON, so a shape wobble in a pre-1.0 engine changes
# only THIS function (D4). Prints the deduped dependent file list (one per line) on stdout.
# Returns non-zero on ANY engine error (caller maps that to skip-scope).
# ---------------------------------------------------------------------------------------------
graphify_dependents() {
  local out="" t rc
  for t in "$@"; do
    local raw
    # `--json` requests structured output; a caret-free positional target mirrors the probe usage
    # (`graphify explain "inject-rules.ts"`). An engine error here fails the whole resolution.
    # Capture inside an `if` so `set -e` does not kill us before we read the exit code.
    if raw="$(graphify explain "$t" --json 2>/dev/null)"; then rc=0; else rc=$?; fi
    [ "$rc" -eq 0 ] || return "$rc"
    [ -n "$raw" ] || return 0   # empty output is a legitimately empty set, not an error
    local files
    files="$(printf '%s' "$raw" | jq -r '[.. | (.file? // .path? // empty)] | unique[]' 2>/dev/null)" \
      || return 1               # unparseable output => treat as engine error
    out="$out$files
"
  done
  # dedupe the union across all targets
  printf '%s' "$out" | grep -v '^$' | sort -u || true
}

# ---------------------------------------------------------------------------------------------
# observe_sites: scan the touched files for CRDT `.observe(` / `.subscribe(` sites (the D3 channel
# the graph is BLIND to). Prints `file:line:trimmed-snippet` lines; count = line count.
# ---------------------------------------------------------------------------------------------
observe_sites() {
  local f
  for f in "$@"; do
    [ -f "$f" ] || continue
    grep -nE '\.(observe|subscribe)[[:space:]]*\(' "$f" 2>/dev/null \
      | sed -E "s#^([0-9]+):[[:space:]]*#$f:\1: #" || true
  done
}

# ---------------------------------------------------------------------------------------------
# cmd_brief: the sole deliverable. Resolve the round's dependent set and emit a scoped brief, or
# skip-scope (labeled) on any additive-safe fallback condition.
#
# Options:
#   --enable                    turn scoping ON for this round (default OFF; env CDOCS_GRAPHIFY_SCOPE
#                               in {1,true,on,yes} also enables). OFF => zero graphify calls.
#   --files "<a> <b> ..."       explicit changed files (space-separated). Else derived from git.
#   --diff-base <ref>           derive changed files from `git diff --name-only <ref>`.
#   --symbols "<x> <y> ..."     explicit graph targets. Else the changed files' basenames are used.
#   --index <path>              path to graph.json (else ${GRAPHIFY_OUT:-.}/graph.json).
#   --near-empty-threshold <n>  dependent-set size <= n counts as near-empty for the CRDT trigger
#                               (default 1).
# ---------------------------------------------------------------------------------------------
cmd_brief() {
  parse_args "$@"
  local enable="${A[enable]:-}" env_flag="${CDOCS_GRAPHIFY_SCOPE:-}"
  case "$env_flag" in 1|true|on|yes|TRUE|ON|YES) enable=1 ;; esac
  # FLAG OFF (default): zero graphify calls, zero binary/index probing -- exactly today's behavior.
  [ -n "$enable" ] || skip "disabled" ""

  local near_empty="${A[near-empty-threshold]:-1}"
  local index="${A[index]:-${GRAPHIFY_OUT:-.}/graph.json}"

  # --- resolve the round's changed files -----------------------------------------------------
  local changed=()
  if [ -n "${A[files]:-}" ]; then
    # shellcheck disable=SC2206
    changed=(${A[files]})
  elif [ -n "${A[diff-base]:-}" ]; then
    mapfile -t changed < <(git diff --name-only "${A[diff-base]}" 2>/dev/null || true)
  else
    mapfile -t changed < <(git diff --name-only HEAD 2>/dev/null || true)
  fi
  # drop empty entries
  local tmp=(); local f
  for f in "${changed[@]:-}"; do [ -n "$f" ] && tmp+=("$f"); done
  changed=("${tmp[@]:-}")
  [ "${#changed[@]}" -gt 0 ] || skip "skip-scope" "no-changed-files"

  # --- skip-scope preconditions (each additive-safe) -----------------------------------------
  command -v graphify >/dev/null 2>&1 || skip "skip-scope" "no-binary"
  [ -f "$index" ] || skip "skip-scope" "missing-index"
  # Staleness: any changed file NEWER than the index means the index predates the change (D5).
  local idx_mtime fmt
  idx_mtime="$(stat -c %Y "$index" 2>/dev/null || echo 0)"
  for f in "${changed[@]}"; do
    [ -f "$f" ] || continue
    fmt="$(stat -c %Y "$f" 2>/dev/null || echo 0)"
    if [ "$fmt" -gt "$idx_mtime" ]; then skip "skip-scope" "stale-index"; fi
  done

  # --- resolve targets and query the engine --------------------------------------------------
  local targets=()
  if [ -n "${A[symbols]:-}" ]; then
    # shellcheck disable=SC2206
    targets=(${A[symbols]})
  else
    for f in "${changed[@]}"; do targets+=("$(basename "$f")"); done
  fi

  local deps rc
  # Capture inside an `if` so `set -e` does not kill us before we read the engine's exit code.
  if deps="$(graphify_dependents "${targets[@]}")"; then rc=0; else rc=$?; fi
  [ "$rc" -eq 0 ] || skip "skip-scope" "engine-error"

  # dependent set = engine files MINUS the round's own changed files (inputs are not "dependents")
  local dep_list=()
  if [ -n "$deps" ]; then
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      local is_input=""
      local c
      for c in "${changed[@]}"; do
        if [ "$f" = "$c" ] || [ "$(basename "$f")" = "$(basename "$c")" ]; then is_input=1; break; fi
      done
      [ -n "$is_input" ] || dep_list+=("$f")
    done <<< "$deps"
  fi
  local dep_count="${#dep_list[@]}"

  # --- CRDT observe/subscribe scan on the touched files (D3 channel) --------------------------
  local sites; sites="$(observe_sites "${changed[@]}")"
  local site_count=0
  [ -n "$sites" ] && site_count="$(printf '%s\n' "$sites" | grep -c . || true)"

  # --- fallback decisions on the resolved set ------------------------------------------------
  # Empty/near-empty set + observe sites => CRDT trigger (D3): never hand back a small confident set.
  if [ "$dep_count" -le "$near_empty" ] && [ "$site_count" -gt 0 ]; then
    skip "skip-scope" "crdt-near-empty-trigger"
  fi
  # Truly empty set with no observe signal => treat like a missing index (engine returned nothing).
  if [ "$dep_count" -eq 0 ]; then
    skip "skip-scope" "empty-set"
  fi

  # --- emit the SCOPED-CONTEXT BRIEF ---------------------------------------------------------
  echo "SCOPE-STATUS: scoped"
  echo "SCOPE-DEP-COUNT: $dep_count"
  echo "SCOPE-OBSERVE-COUNT: $site_count"
  echo
  echo "SCOPED-CONTEXT BRIEF (graphify-resolved; an AID, never a completeness guarantee)"
  echo "==============================================================================="
  echo
  echo "Changed files this round (query inputs):"
  for f in "${changed[@]}"; do echo "  - $f"; done
  echo
  echo "Resolved dependent set ($dep_count file(s), graph-derived, NOT exhaustive):"
  for f in "${dep_list[@]}"; do echo "  - $f"; done
  echo
  echo "CRDT observe/subscribe channel (D3 structural guard -- the graph is BLIND to this coupling):"
  if [ "$site_count" -gt 0 ]; then
    echo "  $site_count nearby .observe/.subscribe site(s) in the touched files:"
    printf '%s\n' "$sites" | sed 's/^/  - /'
  else
    echo "  0 .observe/.subscribe sites found in the touched files (still not a guarantee of no coupling)."
  fi
  echo
  echo "CAVEAT (AID, NOT a guarantee): This dependent set is a SCOPING AID resolved by the graphify"
  echo "  code graph, NOT a related-code completeness guarantee. The graph is blind to CRDT"
  echo "  .observe/.subscribe coupling (see channel above). Do NOT treat this set as exhaustive or"
  echo "  read a small set as \"nothing else is coupled.\" Continue your normal related-code"
  echo "  consideration; on any doubt, fall back to the full unscoped sweep."
  echo
  echo "FOLLOW-UP: use the graphify CLI for further queries over the same index --"
  echo "  graphify explain \"<symbol>\"   (a node + its neighbors)"
  echo "  graphify query   \"<question>\" (BFS traversal for a question)"
  echo "  graphify path    \"<A>\" \"<B>\"  (shortest path between two nodes)"
  echo "  Never ingest raw graph.json; use the query subcommands (they return scoped answers)."
}

# --- dispatch --------------------------------------------------------------------------------
[ $# -ge 1 ] || die "usage: graphify-scope.sh brief [--enable] [--files \"...\"] [--diff-base <ref>] [--symbols \"...\"] [--index <path>] [--near-empty-threshold <n>]"
sub="$1"; shift
case "$sub" in
  brief) cmd_brief "$@" ;;
  *) die "unknown subcommand: $sub" ;;
esac
