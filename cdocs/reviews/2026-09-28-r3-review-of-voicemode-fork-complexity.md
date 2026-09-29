---
review_of: cdocs/reports/2026-09-28-voicemode-fork-complexity.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-28T11:27:00-07:00
task_list: voice/converser-lace-feature
type: review
state: live
status: done
tags: [rereview_agent, voicemode, cross_doc_consistency, conch]
---

# Review (round 3): How complex would forking or replacing VoiceMode actually be

> BLUF(opus/voice/converser-lace-feature): The round-2 blocking item is resolved: Decision point 1, the Section 3 close, and Section 5 "Own for the first slice" now adopt the vetting report's host-`serve`-first experiment, and treat talk-over as a real cost.
> Both round-2 non-blocking notes are applied.
> One inconsistency with the accepted broker report's corrected conch finding is fixed inline.
> Verdict: **Accept.**

## Round-2 Action Items

1. [blocking] Realign Decision point 1 with the vetting report: **resolved**.
   Decision point 1, the Section 3 closing paragraph, and Section 5 all put host `serve` first, keep in-container as the fallback, and count cross-container talk-over as a cost.
2. [non-blocking] Add the `psutil.pid_exists` cross-PID-namespace caveat: **resolved**.
   It appears in Decision point 1 and in Unverified claims.
3. [non-blocking] Describe the token as the only effective gate: **resolved** (Section 2).

## Consistency with the Broker Report's Conch Finding

The accepted broker report (`cdocs/reports/2026-09-28-host-audio-broker-split.md:109-110`) says the conch path is hardcoded and every same-user host `serve` process shares it automatically.
I verified this against source: `LOCK_FILE = Path.home() / ".voicemode" / "conch"` at `conch.py:133` is independent of `BASE_DIR` at `config.py:545`.

Section 3 of this report still said host `serve` processes gain cross-container serialization only by "deliberately sharing one conch directory," and repeated that in its closing paragraph.
That was inconsistent with the broker report.
I fixed it inline. Section 3 now says:
- the conch file is shared automatically across same-user host `serve` processes;
- a per-project `VOICEMODE_BASE_DIR` isolates transcripts, audio, and logs without splitting the conch;
- only a per-process `HOME` override would split it.

Decision point 1's follow-up spike now names its actual scope: bind-mounting one conch directory into several containers, for the in-container fallback.
The `pid_exists` caveat applies there, not to host `serve`, whose processes share one PID namespace.

## Verdict

**Accept.**
No blocking items remain.
