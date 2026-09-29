---
review_of: cdocs/reports/2026-09-28-converser-options-vetting.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-28T11:40:00-07:00
task_list: voice/converser-lace-feature
type: review
state: live
status: done
tags: [rereview_agent, security, isolation, messaging, cross_report_consistency]
---

# Review (round 2): converser options vetting

> BLUF(opus/voice/converser-lace-feature): **Accept.**
> All four round-1 blocking items are resolved, and the new claims verify.
> The revision's decision points and prototype/packaging tagging make it actionable.
> Three small non-blocking notes remain.

## Summary Assessment

The revised report corrects `label=disable` (A14), rescopes the isolation claims to the local socket transport, and recognizes the own-child relay and RC routing.
It fixes the harmful loop filter, declares the broker's SELinux gain void, and reorders the first experiment to host `voicemode serve`.
Round-1 non-blocking items 5-10 are also applied.
Verdict: **Accept**.

## Round-1 Blocking Items

| # | Item | Status |
|---|---|---|
| 1 | Scope "any boundary" claims; add RC-routed `SendMessage` | **Resolved.** The BLUF, 2b ("scoped correctly: over the local socket transport"), and a new H-RC row with its unknowns. Gate (o) added |
| 2 | Separate UID feasible via own-child relay | **Resolved.** The "Workable relay" and "Relay costs" rows, with the verdict reframed as "feasible, rejected for v0 on cost". The same-UID bwrap/Landlock option is included with its `~/.claude` limit |
| 3 | Amendment 5 / gate (k) turn-origin filter | **Resolved.** Ack suppression only. Amendment 5 explicitly says "No turn-origin filtering", and (k) requires replies to user requests to be spoken |
| 4 | Broker SELinux gain void; reconcile first experiment | **Resolved.** "Cross-report correction" (also catches the fork review's `:155`). Section 3 adopts host `serve` first with P as fallback, and the reasons match round 1's F3a |

## New Claims Verified

- **Claude Code is not PID 1:** verified/live on all five containers (jif, whelm, clauthier, dioxus, weftwise). PID 1 is the devcontainer `/bin/sh -c ... while sleep 1` loop, so Linux process evidence for own-child verification exists.
- **Detached-poster reparenting caveat:** correctly flagged as unverified. A `SessionStart`-spawned poster must outlive its hook, so it will be reparented to PID 1. The docs speak only to children that exited, not children that were reparented.
- **`CLAUDE_CLIENT_PRESENCE_FILE`:** exists (Remote Control docs, "Mobile push notifications"): "notifications are skipped while the file exists," maintained by "a screen-lock listener or similar tool."
- **RC "one session at a time" correction:** matches the docs' "Limitations" ("one remote session per interactive process"; server mode for many) and the auto-connect text.
- **`VOICEMODE_TOOLS_ENABLED`** default includes `service`: consistent with `voice_mode/config.py:128`.

## Non-blocking Notes

1. **Presence-file plumbing (amendment 3).** The file signals presence by *existing*, and something on the host must create and delete it on unlock and lock. An in-container relay hook can only see it on a shared mount, such as a path under `~/.claude`. Name the writer and the path when tier 3 is revisited.
2. **Gate (n) fallback.** If the detached poster fails process-evidence verification, test the documented token path: an auth line with `CLAUDE_CODE_MESSAGING_TOKEN`, which is exported to hooks. The docs describe token verification for PID-1 containers and macOS. Whether Linux accepts it when process evidence is absent is itself unverified, but it is the obvious second arm of the spike.
3. **Latency table label.** The "Floor" row's "~7-16s of converser overhead" is a range, not a floor. Relabel it "Range", or give ~7s as the floor.

The revision dropped the `last_reviewed` block from the frontmatter. This review restores it.

## Verdict

**Accept.**

## Action Items

1. [non-blocking] Name the presence-file writer and a container-visible path in amendment 3.
2. [non-blocking] Add the `CLAUDE_CODE_MESSAGING_TOKEN` auth-line fallback as a second arm of gate (n).
3. [non-blocking] Relabel the latency table's relay "Floor" cell.
