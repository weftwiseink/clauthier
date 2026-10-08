---
review_of: cdocs/proposals/2026-10-06-nested-subagent-workflows.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T18:23:28-07:00
task_list: cdocs/nested-subagent-workflows
type: review
state: archived
status: done
tags: [fresh_agent, runtime_validated, test_plan, minimalism, steering_applied]
---

# Review: Nested Subagent Workflows (Round 3)

> BLUF(opus-5-5/cdocs/nested-subagent-workflows): The r2 blocker is resolved: the Phase 3 harness is the `chat-record.test.sh` sandbox, foreground is forced process-wide, and the layers are read from `.meta.json`.
> The maintainer steering is applied faithfully, and the proposal shrank from 3,558 to 2,529 words.
> Verdict: **Accept**, with four non-blocking fixes for the accepting round. The harness omits `init_rules`, so the rule text never loads in the fixture. Nothing says what the arc overseer does with a sub-overseer's missing-`Agent` error. Check 3 gates on a judgment call. The `chat_record` timing rule can be replaced by a pass-down.

## Summary Assessment

The proposal deletes cdocs's "subagents cannot dispatch" machinery and makes the loop skills nest-safe, with the top-level session as the only human-facing chat layer.
Round 3 does what the steering asked.
The generic Nesting section is gone, an overseer without `Agent` fails loudly, `/oversee` dispatches one sub-overseer per proposal, and the choice between inline and nested is left to the chat layer's judgment.
The design is sound.
What remains is harness and check detail: two of the five Phase 3 checks depend on setup or behavior the text does not pin down, and both are one-line fixes.

## Round 2 Disposition

| R2 item | Status | Notes |
|---|---|---|
| 1 [blocking] confine Phase 3, force foreground | Resolved | Fixture outside any repo with no remote, sandboxed `CLAUDE_CONFIG_DIR`, `env -i`, `--plugin-dir`, `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`. It omits one piece of `claude_run`'s setup (finding 1). |
| 2 `.meta.json` layer checks | Resolved | The `jq` over `"$CFG"/projects/*/*/subagents/*.meta.json` matches the real layout. Check 1 asserts the failure picture. Verbose fixture, no `fork`, check 4 reworded. |
| 3 escalation outside the floor | Resolved | Stated explicitly after check 5. |
| 4 trim Nesting | Superseded | The section was removed under steering. |
| 5 word estimates vs `wc -w` | Resolved | The Words column is gone, and the gate is now "expected to drop". |
| 6 grep wording and code span | Resolved | The grep is in a fenced block, and the oversee text no longer says "cannot dispatch". |
| 7 cut about 700 words | Resolved | Down about 1,030 words. |

## Verification Performed

- Ran the static grep against today's tree. It hits exactly the sites in Section 2's table and the oversee NOTE, with no unlisted sites.
- `AskUserQuestion` appears in the loop skills only at iterate:29 and propose-revise:15 and :20, as Section 3 says. `full-send` has neither a role line nor an `AskUserQuestion` (finding 5).
- `tools:` lists: `judge`, `bash-runner`, `nit-fix`, and `triage` omit `Agent`, and `implementer`, `reviewer`, and `proposer` are `"*"`, which matches Summary bullet 3.
- `.meta.json` path and shape were confirmed from this session's own transcripts. `parentAgentId` is absent at depth 1, so the `// "-"` default is needed.
- **Probe: `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1`** in a sandboxed headless run (CC 2.1.292, haiku, `env -i`, copied credentials deleted afterwards). The top level dispatched, and the depth-1 child, recorded as `requestShape: foreground`, reported having no `Agent`. So check 5's premise holds, with no off-by-one at this version ([#84974](https://github.com/anthropics/claude-code/issues/84974) does not reproduce here).
- Read `chat-record.test.sh`'s `claude_run` and `init_rules` (finding 1).

## Section-by-Section Findings

### Test Plan (live)

1. **non-blocking (fix in the accepting round): the harness omits `init_rules`.**
   Every rules-dependent scenario in `chat-record.test.sh` calls `init_rules "$P"` (line 796), which writes `.claude/rules/cdocs.md`, the `CLAUDE.md` import, and the `_chat` scaffold.
   Without it, the fixture never loads `orchestration-discipline.md`.
   Then the explicit-error instruction behind check 5 and the `chat_record` step behind check 4 reach the model only if it happens to follow the skills' relative links, and `chat-record` may run as uninitialized.
   Add "`init_rules` on the fixture" to the harness bullets.

2. **non-blocking (fix in the accepting round): nothing says what the arc overseer does with a sub-overseer's missing-`Agent` error.**
   Check 5 expects "no commits beyond its baseline", which assumes the arc stops.
   But `/oversee`'s hard gates do not list this error, and Section 1 makes "inline or sub-overseer" the chat layer's call.
   So under `--afk`, an arc overseer could reasonably retry, or run `/cdocs:iterate` inline with depth-1 leaf children.
   Those children would commit, and the matching failure picture ("an overseer played its own children") would misattribute it.
   Fix: add "a sub-overseer's missing-`Agent` error" to `/oversee`'s hard gates, and have check 5 assert that the arc file marks the proposal `blocked`.
   This is the fail-loudly decision carried up one layer.

3. **non-blocking: check 3 gates the floor on a model's judgment.**
   For a known verbose command, the Bash section's option 1 (`cmd > file; tail`) is as valid as `bash-runner`, so an implementer that skips delegation is not wrong.
   As a gate, a missing depth-3 agent would push an iterate loop to coax nesting out of the model, which is the generic guidance the steering removed.
   Layer-3 reachability is already established empirically, and the static grep covers stale "cannot dispatch" text.
   Record check 3 as an observation in the devlog rather than a floor item, and drop "whose implementer delegates at layer 3" from the Verification Methodology floor.

4. **non-blocking (minor): check 1 identifies the sub-overseer by type alone.**
   A thin arc overseer may also dispatch a `general-purpose` helper.
   "The depth-1 agent that is the `parentAgentId` of the depth-2 implementer and reviewer is `general-purpose`" is exact and costs nothing extra in the `jq` output.

### Proposed Solution 1 and 4: `chat_record` ownership

5. **non-blocking: replace the timing rule with a pass-down.**
   The current text is sound: a write made before the `Agent` call or after a return has no concurrent writer, and parallel sub-overseers own disjoint devlogs.
   But it has three rough edges:
   - For a `full-send` on an RFP, the proposal devlog does not exist at dispatch, so the link waits for the return. During a long run, post-compaction recovery has to rely on the gist bullets, or on the arc devlog for `/oversee`.
   - Section 4's "as chat layer it adds its `chat_record`" is wrong when `/oversee` is itself dispatched. Then it is not the chat layer.
   - The chat layer writes into a devlog it does not own, which is the cross-agent write that "one writer per file" exists to avoid.
   Alternative, at the same length: "The chat layer passes its `chat-record path` in the dispatch brief; the overseer that owns the devlog adds it to `chat_record`."
   This removes the timing clause, works for devlogs created after dispatch, adds one item to `/oversee`'s Down contract, and keeps "never run `chat-record` if dispatched" intact, since the sub-overseer writes a given string and runs nothing.

### Minimalism

6. **non-blocking: remaining cuts.**
   - Section 4, hard gates: "or dispatches a fresh one from the proposal devlog if the last `subagent_tokens` was past ~400K" restates "Stay thin"'s warm-child rule and skips that rule's handoff step. Keep "resumes the sub-overseer by `SendMessage` with the answer", since the rule already covers rotation.
   - Section 3 lists `full-send`, but it has no role line and no `AskUserQuestion`. Say that it needs no edit, or drop it from the list.
   - Section 1's third line: "inline when the human is steering it, dispatched for long or autonomous loops or several at once" is a light heuristic. It is cdocs-specific, so keeping it is defensible, but "is the chat layer's call" alone matches the steering more closely. Author's choice.
   - The shipped rule text (Section 1, lines 79 and 87) uses two semicolons, which the writing conventions discourage. Use colons or periods.

### Soundness spot checks (no finding)

- **Foreground at every depth.** `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` is process-wide (r2 probe), and check 4's all-`foreground` assertion and the `background` failure picture enforce it.
- **Explicit-error path.** It is placed in the rule paragraph that defines the overseer, so it binds a sub-overseer that reaches it through the loop skill's role line, provided the rules load (finding 1). The `=1` probe confirms that a depth-1 sub-overseer lacks `Agent`.
- **Escalation by return.** It is consistent across Section 1, Section 4's hard gates, and the trade-offs, and resumed agents keep their spawn depth (2.1.187). Steering mid-run needs background dispatch, which is the interactive default. The harness's foreground mode cannot exercise it, which the proposal states.
- **Sub-overseer death.** `/oversee`'s existing Resume ("Ambiguous: re-run the loop") now means dispatching a fresh sub-overseer, which resumes from the proposal devlog through iterate's own resume-from-disk. Orphaned children are unlikely, because an interactive subagent cannot finish while its children are live. No text is needed.
- **Depth budget.** The arc overseer, a layer-1 sub-overseer, layer-2 loop roles, and layer-3 leaves fit the default exactly. The dispatched-`/oversee` edge case (implementers become leaves) is correct.
- **Steering fidelity.** No generic nesting guidance ships. The added rule text is about 150 words, against about 235 that Section 2 deletes, and finding 5's pass-down would shorten it further. The "Inline or nested: trade-offs" section is rationale inside the proposal, not shipped text.

## Verdict

**Accept.**
The r2 blocker is resolved, the steering is applied minimally, and no new soundness gap rises to blocking.
Per propose-revise, resolve findings 1 and 2 in the accepting round: each is a sentence, and without them Phase 3 checks 4 and 5 can fail for reasons unrelated to the design.
Findings 3 to 6 are recommended but optional.

## Action Items

1. [non-blocking, accepting round] Add "`init_rules` on the fixture (rules file, `CLAUDE.md` import, `_chat` scaffold)" to the Phase 3 harness bullets.
2. [non-blocking, accepting round] Add "a sub-overseer's missing-`Agent` error" to `/oversee`'s hard gates in Section 4, and have check 5 assert that the arc file marks the proposal `blocked`.
3. [non-blocking] Demote check 3 (depth-3 helper) to a logged observation, and drop "whose implementer delegates at layer 3" from the floor.
4. [non-blocking] Identify the sub-overseer in check 1 as the depth-1 parent of the depth-2 implementer and reviewer.
5. [non-blocking] Replace the `chat_record` timing sentence with a pass-down: the chat layer gives its `chat-record path` in the brief, and the owning overseer writes it. Add it to `/oversee`'s Down contract, and drop "as chat layer" from Section 4.
6. [non-blocking] Cut the ~400K clause from Section 4's hard gates. Say that `full-send` needs no edit. Optionally trim Section 1's inline/dispatch heuristic. Replace the two semicolons in the shipped rule text.

## Questions for the Author

1. `chat_record` on a dispatched loop's devlog:
   - (a) Pass-down: the owning overseer writes the chat layer's path from its brief (recommended: single writer by construction, and it works for devlogs created after dispatch).
   - (b) Keep the chat-layer write, timed outside the sub-overseer's live window, and fix Section 4's "as chat layer" for a dispatched `/oversee`.
2. Check 3 (depth-3 helper):
   - (a) A logged observation, not a floor item (recommended: delegation is the model's judgment, per the steering).
   - (b) A floor item with a stronger fixture cue. This risks a loop that coaxes nesting.
