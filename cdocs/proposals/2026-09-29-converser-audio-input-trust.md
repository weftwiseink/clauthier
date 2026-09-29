---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-29T15:30:00-07:00
task_list: voice/converser-audio-input-trust
type: proposal
state: live
status: request_for_proposal
tags: [voice, converser, security, provenance]
---

# converser: audio-input trust, provenance, and speaker attribution

> BLUF(opus/voice/converser-audio-input-trust): Replace v0's accepted "the audio stream is a keyboard" risk with real controls over *whose* speech reaches bypass-mode overseers: speaker verification (voice fingerprinting), audio provenance, and attribution of relayed messages.
> - **Motivated By:** [`2026-09-29-converser-host-voicemode-serve.md`](2026-09-29-converser-host-voicemode-serve.md) (accepted residual risk; Future Work), user direction 2026-09-29 deferring these items.

## Objective

v0 treats anything captured inside an open listen window as the user's input.
A video, a call, another person in the room, or leaked TTS can be relayed to an overseer that runs with permissions bypassed, and the only mitigations are listen gating, a headset default, intent verification (a comprehension aid, not a control), and after-the-fact correction.
That is acceptable for a one-user, headset-first prototype; it is not acceptable for hands-free use in a shared room, or for a remote/Android surface.

## Scope

- **Speaker verification.** Enrolment and per-utterance voice fingerprint checks (local models, e.g. speaker-embedding comparison), thresholds, failure behaviour (drop, ask, or mark low-trust), and latency cost against the ~15s round-trip floor.
- **Provenance.** Distinguishing live mic capture from playback: the converser's own TTS (echo/leak), system audio, and remote sources (Android, VoiceMode Connect). Whether capture metadata can be carried with a transcript through `serve`.
- **Attribution in relays.** Marking relayed messages with a trust level so overseers (or hooks) can refuse or escalate low-trust instructions; how that interacts with bypass mode.
- **Policy.** Which actions require verified speech (destructive, external-facing) vs any speech; how this composes with v0's intent verification.
- **Where it runs.** Host `serve` (needs a VoiceMode change or a sidecar between STT and the converser) vs the converser side (sees only text).

## Open Questions

1. Is local speaker verification accurate and fast enough on this hardware (RTX 3080, possibly CPU-only) to run per utterance?
2. Can verification sit in front of VoiceMode without forking it (e.g. a proxy STT endpoint that verifies before transcribing)?
3. What does a trust marker on a relayed message buy, given overseers run with bypassed permissions and cannot enforce it without hooks?
4. Does the Android/remote path need a different mechanism (device-level auth) rather than voice fingerprinting?

## Prior Art

- [`2026-09-29-converser-host-voicemode-serve.md`](2026-09-29-converser-host-voicemode-serve.md): security table and the accepted "audio stream is a keyboard" risk.
- [`2026-09-28-converser-options-vetting.md`](../reports/2026-09-28-converser-options-vetting.md): relay-injection threat analysis.
