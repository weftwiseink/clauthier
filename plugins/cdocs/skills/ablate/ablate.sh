#!/usr/bin/env bash
# ablate.sh - deterministic mechanics for the /cdocs:ablate MCP-tool effectiveness harness.
#
# The skill (SKILL.md) is the thin overseer: it pins the base + task prompt, DISPATCHES the two
# arms and the evaluator as subagents, and interprets their results. This script owns ONLY the
# mechanical, correctness-critical steps that must be deterministic and must never be improvised
# by a language model (proposal D6): worktree lifecycle (D1), payload -> meter normalization (D2),
# transcript tool-invocation detection (usage precondition), the VALID/VOID/TASK-FAIL decision
# (outcome taxonomy), and scorecard assembly with the single-shot gate_admissible guard (D3/D7).
#
# Judgment stays in the subagents; mechanics stay here.
#
# Subcommands:
#   worktree-create   --base <commit> --path <dir> [--allow-dirty]   fresh worktree off a pinned base
#   worktree-remove   --path <dir> [--diff-out <file>]               capture diff, then remove --force
#   resolve-transcript --agent-id <id> --session-dir <dir>           agentId -> subagent JSONL path
#   detect-usage      --transcript <file> --tool <mcp-tool-id>       print "used" | "unused"
#   meter             --payload <file> --arm <name> [opts] --out <f> normalize Task payload -> meter
#   decide            --assisted <meter> --unassisted <meter>        print outcome + void_reason JSON
#   scorecard         --outcome <json> --assisted <m> --unassisted <m> --trials N --run-dir <d> [--eval <f>]
#
# NEVER touches the git stash stack (D1): the stash stack is shared across the bare repo's
# worktrees and other sessions; a bare `git stash`/`pop` could clobber concurrent work.
set -euo pipefail

die() { echo "ablate: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }
need git; need jq

# --- arg parsing helper: reads --flag value pairs into the assoc array A -------------------
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

# ==========================================================================================
# worktree-create: fresh, throwaway worktree checked out at a PINNED COMMIT (D1).
#   - Detached checkout at the commit => byte-identical, immutable base; no branch churn.
#   - Refuses a dirty invoking tree by default (the committed base is what is tested; WIP is
#     deliberately excluded). --allow-dirty downgrades the refusal to a warning. The guard is a
#     UX guard, not a correctness one: the pinned commit is used regardless of WIP.
#   - Never stashes. Isolation is filesystem-level: each arm gets its own tree.
# ==========================================================================================
cmd_worktree_create() {
  parse_args "$@"
  local base="${A[base]:-HEAD}" path="${A[path]:-}" allow_dirty="${A[allow-dirty]:-}"
  [ -n "$path" ] || die "worktree-create: --path required"
  local commit; commit="$(git rev-parse --verify "${base}^{commit}" 2>/dev/null)" \
    || die "worktree-create: cannot resolve base commit '$base'"
  if [ -z "$allow_dirty" ] && [ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ]; then
    die "worktree-create: invoking tree is dirty; the ablation tests the committed base '$base' and
     EXCLUDES uncommitted work. Commit it, pass an explicit --base <commit>, or --allow-dirty to
     proceed testing the committed base anyway. (This harness never stashes: the stash stack is
     shared across worktrees and concurrent sessions.)"
  fi
  [ ! -e "$path" ] || die "worktree-create: path already exists: $path"
  # Detached checkout at the pinned commit; --detach avoids creating/occupying a branch name.
  git worktree add --detach "$path" "$commit" >&2
  echo "$commit"   # emit the resolved pinned commit for the caller to record in the run log
}

# ==========================================================================================
# worktree-remove: ordered teardown. Capture the arm's produced diff FIRST (the tree is dirty
# with the arm's work), THEN `git worktree remove --force` (plain remove refuses a dirty tree).
# Touches no shared mutable state (no stash, no shared branch).
# ==========================================================================================
cmd_worktree_remove() {
  parse_args "$@"
  local path="${A[path]:-}" diff_out="${A[diff-out]:-}"
  [ -n "$path" ] || die "worktree-remove: --path required"
  if [ -n "$diff_out" ] && [ -d "$path" ]; then
    # Diff of the arm's work vs the pinned base it was checked out at (its own HEAD commit).
    ( git -C "$path" add -A -N >/dev/null 2>&1 || true
      git -C "$path" diff HEAD ) > "$diff_out" 2>/dev/null || true
  fi
  git worktree remove --force "$path" >&2 || die "worktree-remove: failed to remove $path"
  echo "removed $path"
}

# ==========================================================================================
# resolve-transcript: map a Task result's agentId to its subagent transcript JSONL.
# Claude Code writes dispatched-agent transcripts to
#   <project-session-dir>/subagents/agent-<agentId-prefix>*.jsonl   (isSidechain:true)
# The on-disk filename is an agentId PREFIX of variable length, so match by prefix-glob and fall
# back to the newest sidechain transcript if the id does not resolve uniquely.
# ==========================================================================================
cmd_resolve_transcript() {
  parse_args "$@"
  local id="${A[agent-id]:-}" dir="${A[session-dir]:-}"
  [ -n "$dir" ] || die "resolve-transcript: --session-dir required"
  local sub="$dir/subagents"
  [ -d "$sub" ] || die "resolve-transcript: no subagents dir under $dir"
  local hit=""
  if [ -n "$id" ]; then
    # try progressively shorter prefixes of the agentId against agent-<prefix>*.jsonl
    local p="$id"
    while [ -n "$p" ]; do
      hit="$(ls -1 "$sub"/agent-"$p"*.jsonl 2>/dev/null | head -1 || true)"
      [ -n "$hit" ] && break
      p="${p%?}"
    done
  fi
  if [ -z "$hit" ]; then
    # Newest-sidechain fallback. If a NON-EMPTY agentId was given but did not resolve, warn LOUDLY:
    # binding the wrong arm's transcript would silently corrupt the usage gate.
    if [ -n "$id" ]; then
      echo "ablate: WARN: agentId '$id' did not resolve to a transcript under $sub;" \
           "falling back to the NEWEST sidechain transcript, which MAY be the wrong arm." \
           "Verify the resolved path before trusting the usage gate." >&2
    fi
    hit="$(ls -1t "$sub"/agent-*.jsonl 2>/dev/null | head -1 || true)"
  fi
  [ -n "$hit" ] || die "resolve-transcript: no transcript found for agent '$id' under $sub"
  echo "$hit"
}

# ==========================================================================================
# detect-usage (the honesty gate's mechanical half): does the transcript contain at least one
# `tool_use` block for the target tool? An errored call still counts as INVOKED (the treatment
# occurred, presence not result). --tool expresses EITHER form:
#   - MCP tool name:      "mcp__graphify__scope" (or a bare trailing name "scope"). Matched
#                         against tool_use `.name` == $tool or endswith("__" + $tool).
#   - CLI-command sig:    "cli:<regex>" (e.g. "cli:graphify "). graphify is CLI-first (its MCP is
#                         shadowed by the lace over-mount bug), so its shell-out surfaces as a
#                         `Bash` tool_use whose command lives in `.input.command`, NOT in `.name`
#                         (which is just "Bash"). The `cli:` prefix matches the regex against a
#                         Bash tool_use's `.input.command`, so a CLI-shaped tool has a real,
#                         non-sentinel usage signal. The regex is applied verbatim (anchor it if
#                         a bare command name could match a substring of an unrelated command).
# Prints "used" or "unused"; exit 0 either way (the caller/decide branches on the string).
# ==========================================================================================
cmd_detect_usage() {
  parse_args "$@"
  local t="${A[transcript]:-}" tool="${A[tool]:-}"
  [ -n "$t" ] || die "detect-usage: --transcript required"
  [ -n "$tool" ] || die "detect-usage: --tool required"
  [ -f "$t" ] || die "detect-usage: transcript not found: $t"
  local n
  if [ "${tool#cli:}" != "$tool" ]; then
    # CLI-command signature: match the regex against a Bash tool_use's .input.command.
    local sig="${tool#cli:}"
    [ -n "$sig" ] || die "detect-usage: empty cli: signature"
    n="$(jq -r --arg sig "$sig" '
          select(.type=="assistant")
          | .message.content[]? | select(.type=="tool_use") | select(.name=="Bash")
          | (.input.command // "") | select(test($sig))
        ' "$t" 2>/dev/null | wc -l | tr -d ' ')"
  else
    # MCP tool name (fully-qualified or bare trailing name).
    n="$(jq -r --arg tool "$tool" '
          select(.type=="assistant")
          | .message.content[]? | select(.type=="tool_use") | .name
          | select(. == $tool or endswith("__" + $tool))
        ' "$t" 2>/dev/null | wc -l | tr -d ' ')"
  fi
  if [ "${n:-0}" -gt 0 ]; then echo "used"; else echo "unused"; fi
}

# ==========================================================================================
# meter: normalize a dispatched-agent Task result payload into a per-arm meter file (D2/D7).
# Reads the REAL field names surfaced by Claude Code's `toolUseResult`:
#   totalTokens, totalDurationMs, usage, agentId, status, totalToolUseCount.
# (The proposal's placeholder names subagent_tokens/duration_ms are aliased on read for safety.)
# --payload may be the bare toolUseResult object or a full transcript line wrapping it.
# duration_ms is recorded but flagged INDICATIVE-only downstream; it never drives a verdict.
# ==========================================================================================
cmd_meter() {
  parse_args "$@"
  local payload="${A[payload]:-}" arm="${A[arm]:-}" out="${A[out]:-}"
  [ -n "$payload" ] || die "meter: --payload required"
  [ -n "$arm" ] || die "meter: --arm required (assisted|unassisted)"
  [ -n "$out" ] || die "meter: --out required"
  [ -f "$payload" ] || die "meter: payload file not found: $payload"

  jq \
    --arg arm "$arm" \
    --arg armlabel "${A[label]:-}" \
    --arg tool "${A[tool]:-}" \
    --arg granted "${A[tool-granted]:-}" \
    --arg transcript "${A[transcript]:-}" \
    --arg diff "${A[diff]:-}" \
    --arg completed "${A[task-completed]:-}" \
    --arg invoked "${A[tool-invoked]:-}" \
    '
    # unwrap a full transcript line to its toolUseResult if present
    (if has("toolUseResult") then .toolUseResult else . end) as $r
    | {
        arm: $arm,
        arm_label: (if $armlabel=="" then (if $arm=="assisted" then "A" else "B" end) else $armlabel end),
        tool: $tool,
        tool_granted: ($granted=="true" or $granted=="1"),
        tokens: ($r.totalTokens // $r.subagent_tokens // null),
        duration_ms: ($r.totalDurationMs // $r.duration_ms // null),
        duration_note: "INDICATIVE ONLY: model-latency variance dominates; never sole basis for a verdict (D2)",
        usage: ($r.usage // null),
        tool_use_count: ($r.totalToolUseCount // null),
        agent_id: ($r.agentId // null),
        status: ($r.status // null),
        transcript: (if $transcript=="" then null else $transcript end),
        diff: (if $diff=="" then null else $diff end),
        task_completed: (if $completed=="" then null else ($completed=="true" or $completed=="1") end),
        # tool_invocation_confirmed is meaningful for the assisted arm only (the honesty gate).
        tool_invocation_confirmed: (if $arm=="assisted"
                                    then ($invoked=="used" or $invoked=="true" or $invoked=="1")
                                    else null end)
      }' "$payload" > "$out"
  echo "$out"
}

# ==========================================================================================
# decide: resolve the run to exactly one outcome, applying the proposal's PRECEDENCE (D:usage gate):
#   1. VOID  (treatment absent) takes precedence over everything, split by void_reason:
#        - "unavailable"        : assisted arm lacked the tool (tool_granted=false)
#        - "available_unused"   : had the tool but no target tool_use in its transcript
#   2. TASK-FAIL : treatment occurred but one or both arms did not complete the task.
#   3. VALID     : both arms completed AND the assisted arm verifiably USED the tool.
# Only VALID may later carry a context-gap verdict. Emits a JSON object on stdout.
# ==========================================================================================
cmd_decide() {
  parse_args "$@"
  local am="${A[assisted]:-}" um="${A[unassisted]:-}"
  [ -f "$am" ] || die "decide: --assisted meter not found: $am"
  [ -f "$um" ] || die "decide: --unassisted meter not found: $um"

  # Null-completion guard: a MISSING task_completed must not silently read as completed and mask a
  # TASK-FAIL. It is only load-bearing when the run is NOT VOID (VOID ignores completion by
  # precedence), so refuse only when completion would actually decide VALID-vs-TASK-FAIL.
  local void_now
  void_now="$(jq -rn --slurpfile a "$am" --slurpfile u "$um" '
    ($a[0].tool_granted != true) or ($a[0].tool_invocation_confirmed != true)')"
  if [ "$void_now" != "true" ]; then
    local ac uc
    ac="$(jq -r '.task_completed' "$am")"; uc="$(jq -r '.task_completed' "$um")"
    if [ "$ac" = "null" ] || [ "$uc" = "null" ]; then
      die "decide: task_completed is unset for an arm (assisted=$ac unassisted=$uc) on a non-VOID
     run; the completion signal is required to distinguish VALID from TASK-FAIL. Record each arm's
     completion via meter --task-completed true|false (SKILL Step 2)."
    fi
  fi

  jq -n --slurpfile a "$am" --slurpfile u "$um" '
    $a[0] as $A | $u[0] as $U
    | ($A.tool_granted == true) as $granted
    | ($A.tool_invocation_confirmed == true) as $invoked
    | (($A.task_completed != false) and ($U.task_completed != false)) as $both_done
    | (if ($granted | not) then
         {outcome:"VOID", void_reason:"unavailable",
          rationale:"Assisted arm lacked the target tool; the treatment never occurred, so no effect can be attributed."}
       elif ($invoked | not) then
         {outcome:"VOID", void_reason:"available_unused",
          rationale:"Assisted arm HAD the tool but never invoked it; treatment absent != no effect (honesty gate)."}
       elif ($both_done | not) then
         {outcome:"TASK-FAIL", void_reason:null,
          failed_arms: ([ (if $A.task_completed==false then "assisted" else empty end),
                          (if $U.task_completed==false then "unassisted" else empty end) ]),
          rationale:"Treatment occurred but a token/speed comparison across a completion and a non-completion is not apples-to-apples; no token-win verdict is emitted."}
       else
         {outcome:"VALID", void_reason:null,
          rationale:"Both arms completed and the assisted arm verifiably used the tool; a context-gap verdict is admissible."}
       end)
  '
}

# ==========================================================================================
# scorecard: assemble scorecard.json + scorecard.md under the run dir (D7).
# The single-shot admissibility guard is enforced HERE, on the MACHINE artifact (D3/D7):
#   gate_admissible = (outcome=="VALID" AND trials>1). trials==1 => false, always.
# --eval (optional) is the evaluator subagent's JSON contribution: {context_gap, qualitative,
# per_arm_read, divergent_paths}. When absent (Phase-1 pre-evaluator, or a non-VALID run), only
# outcome + metered deltas are written and no context-gap verdict is claimed.
# ==========================================================================================
cmd_scorecard() {
  parse_args "$@"
  local outcome_f="${A[outcome]:-}" am="${A[assisted]:-}" um="${A[unassisted]:-}"
  local trials="${A[trials]:-1}" run_dir="${A[run-dir]:-}" eval_f="${A[eval]:-}"
  [ -f "$outcome_f" ] || die "scorecard: --outcome json not found: $outcome_f"
  [ -f "$am" ] || die "scorecard: --assisted meter not found: $am"
  [ -f "$um" ] || die "scorecard: --unassisted meter not found: $um"
  [ -n "$run_dir" ] || die "scorecard: --run-dir required"
  mkdir -p "$run_dir"
  local eval_json='null'
  [ -n "$eval_f" ] && [ -f "$eval_f" ] && eval_json="$(cat "$eval_f")"

  jq -n \
    --slurpfile outcome "$outcome_f" \
    --slurpfile a "$am" \
    --slurpfile u "$um" \
    --argjson trials "$trials" \
    --argjson eval "$eval_json" '
    $outcome[0] as $O | $a[0] as $A | $u[0] as $U
    | ($O.outcome=="VALID") as $valid
    | {
        outcome: $O.outcome,
        void_reason: ($O.void_reason // null),
        tool: $A.tool,
        trials: $trials,
        # single-shot is INDICATIVE-ONLY: a one-draw A/B pair may never silently become a gate verdict.
        gate_admissible: ($valid and ($trials > 1)),
        single_shot_caveat: (if $trials <= 1
          then "SINGLE-SHOT, INDICATIVE ONLY: deltas are ONE draw, not an estimate; a sign flip on a small delta is within noise. NOT admissible as a downstream gate verdict (D3)."
          else null end),
        token_delta: (if ($A.tokens != null and $U.tokens != null)
                      then { assisted:$A.tokens, unassisted:$U.tokens, delta:($A.tokens - $U.tokens),
                             note:"CORROBORATING magnitude only: a joint measure of tool effect + path variance; does not attribute cause (D3)." }
                      else null end),
        wallclock_delta: (if ($A.duration_ms != null and $U.duration_ms != null)
                      then { assisted_ms:$A.duration_ms, unassisted_ms:$U.duration_ms, delta_ms:($A.duration_ms - $U.duration_ms),
                             note:"INDICATIVE ONLY: model-latency variance dominates; never the sole basis for a verdict (D2)." }
                      else null end),
        # context_gap is the PRIMARY CAUSAL axis; only present on a VALID run WITH an evaluator contribution.
        context_gap: (if $valid and $eval != null then $eval.context_gap else null end),
        qualitative: (if $eval != null then $eval.qualitative else null end),
        divergent_paths: (if $eval != null then ($eval.divergent_paths // null) else null end),
        spread: null,
        failed_arms: ($O.failed_arms // null),
        arms: { assisted: $A, unassisted: $U }
      }' > "$run_dir/scorecard.json"

  # human-readable summary: lead with outcome + caveat, then the qualitative read.
  {
    echo "# Ablation scorecard: $(jq -r '.tool // "<tool>"' "$run_dir/scorecard.json")"
    echo
    echo "> **Outcome: $(jq -r '.outcome' "$run_dir/scorecard.json")**"
    local vr; vr="$(jq -r '.void_reason // empty' "$run_dir/scorecard.json")"
    [ -n "$vr" ] && echo "> Void reason: \`$vr\`"
    local ssc; ssc="$(jq -r '.single_shot_caveat // empty' "$run_dir/scorecard.json")"
    [ -n "$ssc" ] && { echo ">"; echo "> WARN: $ssc"; }
    echo ">"
    echo "> gate_admissible: \`$(jq -r '.gate_admissible' "$run_dir/scorecard.json")\` (a downstream gate MUST refuse a non-admissible scorecard)."
    echo
    echo "## Metered deltas"
    echo
    echo "| axis | assisted | unassisted | delta | weight |"
    echo "|---|---|---|---|---|"
    jq -r '.token_delta as $t | if $t then "| tokens | \($t.assisted) | \($t.unassisted) | \($t.delta) | corroborating |" else "| tokens | - | - | - | (unavailable) |" end' "$run_dir/scorecard.json"
    jq -r '.wallclock_delta as $w | if $w then "| wallclock (ms) | \($w.assisted_ms) | \($w.unassisted_ms) | \($w.delta_ms) | INDICATIVE only |" else "| wallclock (ms) | - | - | - | (unavailable) |" end' "$run_dir/scorecard.json"
    echo
    local cg; cg="$(jq -r '.context_gap // empty' "$run_dir/scorecard.json")"
    if [ -n "$cg" ]; then
      echo "## Context gap (PRIMARY causal axis): \`$cg\` in [-10,+10]"
    else
      echo "## Context gap"
      echo
      echo "Not rendered: a context-gap verdict is emitted only on a VALID run with an evaluator contribution."
    fi
    echo
    local q; q="$(jq -r '.qualitative // empty' "$run_dir/scorecard.json")"
    [ -n "$q" ] && { echo "## Qualitative assessment"; echo; echo "$q"; echo; }
    echo "_The assisted arm is identifiable by its tool calls; the blind is PARTIAL (D5)._"
  } > "$run_dir/scorecard.md"

  echo "$run_dir/scorecard.json"
  echo "$run_dir/scorecard.md"
}

# --- dispatch ------------------------------------------------------------------------------
[ $# -ge 1 ] || die "usage: ablate.sh <worktree-create|worktree-remove|resolve-transcript|detect-usage|meter|decide|scorecard> [opts]"
sub="$1"; shift
case "$sub" in
  worktree-create)    cmd_worktree_create "$@" ;;
  worktree-remove)    cmd_worktree_remove "$@" ;;
  resolve-transcript) cmd_resolve_transcript "$@" ;;
  detect-usage)       cmd_detect_usage "$@" ;;
  meter)              cmd_meter "$@" ;;
  decide)             cmd_decide "$@" ;;
  scorecard)          cmd_scorecard "$@" ;;
  *) die "unknown subcommand: $sub" ;;
esac
