---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-17T15:30:00-08:00
task_list: code-graph/lace-devcontainer-enablement
type: proposal
state: live
status: review_ready
tags: [devcontainer_features, code_graph, lace, tooling, mcp]
---

# Enable the graphify lace devcontainer feature in clauthier

> BLUF(claude-opus-4-8/code-graph/lace-devcontainer-enablement): Add the `graphify:1` lace devcontainer feature to clauthier's `.devcontainer/devcontainer.json` with `installMcpServer: true`, so `lace up` installs the CLI and registers the MCP for cdocs iterate-phase subagents. First task: resolve which devcontainer.json is authoritative (the 3-vs-7 drift) and guarantee `claude-code` is declared there, or registration no-ops. Pin `0.9.61`, no git hook, accept one shared index. In-loop acceptance is `lace validate`; `lace up` plus the in-container smoke test are post-accept.

## Summary

This is the clauthier consumer-side wiring for graphify. The loop-and-MCP-layer decisions live in the accepted [graphify-cdocs-integration proposal](2026-09-17-graphify-cdocs-integration.md), which held lace explicitly out of scope; this proposal is the devcontainer enablement that proposal deferred. The producer feature is already implemented and accepted lace-side; enabling it here is a one-entry addition to the devcontainer `features` map plus a source-of-truth reconciliation.

The substance is five decisions (D1 to D5): where the authoritative devcontainer config lives and how to guarantee `claude-code` survives regeneration (D1), turning the MCP server on (D2), accepting a single shared graph index under the bare-worktree layout (D3), pinning the pre-1.0 version and carrying the license precondition (D4), and refusing the global git hook (D5). Verification splits cleanly: `lace validate` is a safe, in-loop static check the isolated implementer runs; `lace up` and the in-container smoke test mutate the real devcontainer and route to the overseer or user.

## Objective

Make graphify available in clauthier's dev environment: `lace up` installs the `graphify` CLI and registers the `graphify` MCP server so cdocs iterate-phase subagents can query the code graph, with the index persisting across container rebuilds. Do this without disturbing the loop-layer surfaces owned by the graphify-cdocs-integration proposal.

## Background

- **Producer spec** (sibling `lace` repo, local path, not navigable from clauthier): `cdocs/proposals/2026-09-15-graphify-lace-devcontainer-feature.md`, status `implementation_accepted`. It defines the consumer contract: the feature installs `graphifyy` via isolated system-wide pipx, declares a lace mount for the index, and provisions a scoping aid with a documented grep fallback, never a related-code guarantee. Feature source: `devcontainers/features/src/graphify/{devcontainer-feature.json,install.sh,README.md}`.
- **Accepted loop-layer proposal**: [`cdocs/proposals/2026-09-17-graphify-cdocs-integration.md`](2026-09-17-graphify-cdocs-integration.md), status `implementation_ready`. It owns the scoping tool, the MCP query contract, recall-parity gating, and the CRDT blind-spot framing. Its "what is lace?" open question is what this proposal answers. Do NOT touch its surfaces.
- **The feature**: `ghcr.io/weftwiseink/devcontainer-features/graphify:1`. Installs `graphifyy` (PyPI) via pipx, yielding the `graphify` CLI and the `graphify-mcp` server. Options: `version` (exact pin, default `0.9.61`), `installMcpServer` (default false; runs `claude mcp add graphify -s user -- graphify-mcp`, requires the `claude-code` feature or it no-ops with a warning), `installGitHook` (default false; sets a global `core.hooksPath`). It bakes `GRAPHIFY_OUT=/var/cache/graphify` as container ENV and declares mount `index` -> `/var/cache/graphify`, `recommendedSource: ~/.cache/graphify`, `sourceMustBe: directory` (lace auto-creates the source during `lace up`). No ports (MCP is stdio).
- **clauthier's devcontainer**: source [`.devcontainer/devcontainer.json`](../../.devcontainer/devcontainer.json) declares 3 features (git, lace-fundamentals, opencode); the lace-generated [`.lace/devcontainer.json`](../../.lace/devcontainer.json) declares 7 (adds neovim, blesh, bash-history, `claude-code`). They are out of sync. The `.lace/*.json` files (devcontainer.json, mount-assignments.json, port-assignments.json, devcontainer-lock.json) are lace-generated state and are never hand-edited; `lace up` (and `lace validate`) regenerate them.
- **lace generation model** (from `lace up`'s pipeline): `lace up` reads `.devcontainer/devcontainer.json`, resolves templates, allocates ports, resolves mounts, and writes the extended config to `.lace/devcontainer.json` via `generateExtendedConfig` from the resolved `.devcontainer/` config, then invokes `devcontainer up`. `lace validate` runs that same pipeline with `validateOnly`, so it regenerates `.lace/devcontainer.json` and validates feature metadata and mounts but stops before `devcontainer up`.

## Proposed Solution

Add one entry to the authoritative devcontainer `features` map:

```jsonc
"ghcr.io/weftwiseink/devcontainer-features/graphify:1": {
  "version": "0.9.61",
  "installMcpServer": true,
  "installGitHook": false
}
```

and ensure the same file declares the `claude-code` feature (`ghcr.io/weftwiseink/devcontainer-features/claude-code:1`), the prerequisite for MCP registration. The feature's own `installsAfter: [claude-code]` orders the install correctly once both are present.

No mount config is authored here: the feature declares its `index` mount, and lace resolves it during `lace up`, auto-creating `~/.cache/graphify` on the host (per `sourceMustBe: directory`). No ports, no `containerEnv` changes (`GRAPHIFY_OUT` is baked by the feature).

## Important Design Decisions

### D1: Resolve the source-of-truth before adding anything

The 3-vs-7 drift means adding the feature to the wrong file either has no effect or is silently reverted on the next regeneration. The generation input is the resolved `.devcontainer/devcontainer.json`; `.lace/devcontainer.json` is a generated artifact. So `.devcontainer/devcontainer.json` is the edit target. The open question is whether the four extra features currently in `.lace/` (including `claude-code`) come from generation-time expansion (feature `dependsOn`/`installsAfter` pulling in dependencies) or are stale residue from a since-trimmed `.devcontainer/`. If the latter, a fresh `lace up` would DROP `claude-code`, and MCP registration would no-op.

**Decision rule (implementer's first verifiable step, in-loop):** run `lace validate --workspace-folder .` on the current tree, then inspect the freshly regenerated `.lace/devcontainer.json`. If `claude-code` is absent from the regenerated output, the extra features were stale residue and `claude-code` MUST be added explicitly to `.devcontainer/devcontainer.json`. If `claude-code` survives regeneration, it is expansion-provided and already assured. Either way, declaring `claude-code` explicitly in `.devcontainer/devcontainer.json` is the safe, idempotent action: harmless if already expanded, required if not. Do not guess the drift mechanism; let the regenerated file decide, and declare `claude-code` regardless.

> NOTE(claude-opus-4-8/code-graph/lace-devcontainer-enablement): `lace validate` regenerating `.lace/*.json` is lace doing its job, not a hand-edit. The "never hand-edit `.lace/*.json`" constraint stands; running validate to regenerate them is expected.

### D2: Enable the MCP server (`installMcpServer: true`)

The point of this enablement is a graph queryable by cdocs iterate-phase subagents, which requires the `graphify` MCP registered in the container's Claude config. This depends on D1 landing `claude-code`. If D1 reveals `claude-code` cannot be assured in the authoritative source, fall back to `installMcpServer: false` (CLI-only) and flag it to the overseer, because the feature would otherwise install the CLI and warn-then-no-op on registration, giving a false sense that MCP is wired.

### D3: Accept a single shared graph index under bare-worktree

clauthier runs `customizations.lace.workspace.layout: bare-worktree` with `mountTarget: /workspace/clauthier`, so multiple worktrees share one container. `GRAPHIFY_OUT` is a single fixed `/var/cache/graphify`, so all worktrees share one graph index.

**Decision: accept the shared index.** It is the simplest option and matches lace's one-project-per-container norm. The risk is cross-worktree staleness: an index built against worktree A's tree is stale for worktree B, and `graphify update` overwrites rather than namespaces. This is tolerable because the loop-layer proposal already mandates skip-scope on a stale index and treats the graph as a best-effort aid; a stale-across-worktrees index degrades to the same grep fallback as any stale index. Per-worktree namespacing (distinct `GRAPHIFY_OUT` per worktree) is a real future option but is not wired by the feature and is out of scope here.

> NOTE(claude-opus-4-8/code-graph/lace-devcontainer-enablement): If cross-worktree index thrash proves costly in practice, per-worktree namespacing is the escalation, and it belongs to a follow-up (it needs feature or wrapper support, not a devcontainer.json edit).

### D4: Pin the version explicitly, carry the license precondition

Set `version: 0.9.61` (the feature default, stated explicitly so the pin is visible and reviewable). graphify is pre-1.0 with frequent releases, so the pin is a standing maintenance item: bumping it is a deliberate, re-verified change, not an automatic float. The Apache/MIT license re-verification precondition is shared with the graphify-cdocs-integration proposal (its Open Questions and Phase 2 precondition); this proposal does NOT re-adjudicate it, it references it as a common precondition that must clear before graphify is a standing in-environment dependency.

### D5: No git hook (`installGitHook: false`)

The feature's `installGitHook` sets a global `core.hooksPath`, which shadows repo hooks container-wide. In clauthier's multi-worktree container that would override hooks for every worktree at once. This is unacceptable. `installGitHook: false` is a hard constraint. Index freshness is handled by the loop layer's skip-scope-on-stale policy, not by a commit-time hook.

## Edge Cases / Challenging Scenarios

- **`claude-code` absent from the authoritative source.** MCP registration warns and no-ops; the CLI still installs. D1 guards against this; if it cannot be assured, D2 falls back to CLI-only and flags it. Never ship `installMcpServer: true` believing MCP is wired when `claude-code` is not guaranteed post-regeneration.
- **Mount source unwritable.** `sourceMustBe: directory` makes lace validate the source before template resolution; a regular auto-created dir is created with `mkdir -p`. If `~/.cache/graphify` exists as a file or is unwritable, `lace up` aborts with an actionable error rather than silently mounting the wrong thing. This surfaces at `lace validate` time.
- **`lace validate` network failure.** Validate fetches and validates feature metadata from GHCR; an OCI fetch failure fails validation for reasons unrelated to the edit. The `--skip-metadata-validation` flag is the documented offline escape; a network failure is not evidence the feature entry is malformed. Distinguish a metadata-fetch failure from a genuine config error before treating a red `lace validate` as a rejection.
- **Pre-1.0 pin drift.** `0.9.61` may be yanked or superseded. A yanked pin fails `pipx install` at build (`lace up`), loudly, which is correct (no silent drift). Bumping the pin is a tracked maintenance action, not an automatic float (D4).
- **Regeneration drops an unrelated feature.** If D1's `lace validate` shows the regenerated `.lace/` also drops neovim/blesh/bash-history, that is a pre-existing drift beyond this proposal's scope; flag it to the overseer rather than silently restoring all four. Only `claude-code` is load-bearing for this proposal.

## Verification Methodology

Two tiers, split by whether the step mutates the real environment.

**In-loop (safe, static, the isolated implementer's acceptance criterion):**
`lace validate --workspace-folder .` must pass with the graphify feature added. This regenerates `.lace/devcontainer.json`, validates the new feature's metadata against GHCR, and validates the resolved mount set (catching a malformed feature entry or an unresolvable `sourceMustBe` mount) without building a container. This is the isolated implementer's verifiable green. The same command, run before the edit, is D1's authority probe.

**Environment-mutating (route OUT of the isolated loop, to the overseer or user):**
The isolated implementer must NOT run `lace up`: it rebuilds the real devcontainer and requires Docker/podman and host lace. After acceptance, an un-isolated session runs:
1. `lace up` (rebuild, applies the feature).
2. in-container `graphify --version` (reports the `0.9.61` pin).
3. `graphify update .` on a fixture, asserting `graph.json` appears under `/var/cache/graphify`.
4. `claude mcp list` showing the `graphify` entry (proves D2 registration landed, which in turn proves D1's `claude-code` guarantee held through regeneration).

> NOTE(claude-opus-4-8/code-graph/lace-devcontainer-enablement): Per the producer spec, mount persistence across rebuilds is exercised only by a real `lace up`, not by `devcontainer features test` (which does not apply lace mounts). Index-survives-rebuild is therefore a post-accept, `lace up`-tier check, not an in-loop one.

## Implementation Phases

Phases are ordered; 1 to 3 are the in-loop deliverable, 4 is post-accept.

**Phase 1: Resolve source-of-truth and guarantee `claude-code` (D1).**
Run `lace validate --workspace-folder .` on the current tree, inspect the regenerated `.lace/devcontainer.json`, apply D1's decision rule, and ensure `claude-code` is declared in `.devcontainer/devcontainer.json`. Success: `.devcontainer/devcontainer.json` declares `claude-code`, and a regeneration retains it.
Depends on: nothing. Blocks: Phase 2.

**Phase 2: Add the graphify feature entry (D2, D4, D5).**
Add the `graphify:1` entry to `.devcontainer/devcontainer.json` with `version: 0.9.61`, `installMcpServer: true` (or `false` per D2 fallback if Phase 1 could not assure `claude-code`), `installGitHook: false`. Author no mount or port config. Success: the entry is present and well-formed.
Depends on: Phase 1. Blocks: Phase 3.

**Phase 3: `lace validate` green (in-loop acceptance).**
`lace validate --workspace-folder .` passes (distinguishing a genuine config error from a metadata-fetch network failure per Edge Cases). Success: validation passes; the regenerated `.lace/devcontainer.json` contains both `graphify` and `claude-code`.
Depends on: Phase 2. Blocks: Phase 4.

**Phase 4 (post-accept, environment-mutating, overseer or user): `lace up` and smoke test.**
Run the environment-mutating verification tier above. Success: `graphify --version` reports the pin, `graphify update .` produces `graph.json` under `/var/cache/graphify`, and `claude mcp list` shows `graphify`.
Depends on: Phase 3 acceptance. Blocks: nothing.

**What NOT to change:** never hand-edit `.lace/*.json` (lace regenerates them; validate/up own that file). Do not touch the loop-layer graphify-cdocs-integration proposal's surfaces (the scoping tool, MCP query contract, agents, or loop skills). Do not author mount or port config for graphify; the feature declares its own. Do not enable `installGitHook`. Do not modify the producer feature in the sibling `lace` repo.

## Investigation Requested

Dispatched-mode review targets for a reviewer to pressure-test:

- **D1 authority mechanism.** The decision rule leans on `lace validate` regenerating `.lace/devcontainer.json` from the resolved `.devcontainer/` config (confirmed: `validateOnly` runs `generateExtendedConfig` then returns before `devcontainer up`). Confirm that inspecting the regenerated file is a sufficient authority probe, and that declaring `claude-code` explicitly is genuinely idempotent under lace's `dependsOn`/`installsAfter` expansion (i.e., an already-expanded feature declared again does not double-install or error).
- **D2/D1 coupling.** Is "declare `claude-code` explicitly, unconditionally" the right guard, or should the implementer instead diagnose WHY the drift exists (stale seed vs expansion) before editing? The proposal chooses the idempotent-declare shortcut over root-causing the drift; confirm that is acceptable.
- **D3 shared-index risk.** Is accepting a single shared `/var/cache/graphify` across worktrees the right default, or does cross-worktree staleness/thrash warrant flagging per-worktree namespacing as a gating concern now rather than a deferred follow-up?
- **`lace validate` as the in-loop gate.** Validate fetches feature metadata from GHCR, so it is not fully offline/static. Confirm it is the correct in-loop acceptance criterion given that dependency, and that the network-failure-vs-config-error distinction is adequately specified for an isolated implementer.

## Open Questions

- **Drift mechanism (D1).** Whether the four extra features in the current `.lace/` are expansion-provided or stale residue is resolved empirically by the Phase 1 `lace validate` inspection, not by this proposal.
- **`lace validate`/`lace doctor` documentation.** Both are real lace commands (present in the CLI source) but are not listed in the lace README's Commands section, which documents only `lace up` and `lace resolve-mounts`. Cited here from source; a reader consulting only the README will not find them.
