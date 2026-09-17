---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-17T10:55:07-07:00
task_list: cdocs/browser-delegation
type: report
state: live
status: wip
tags: [research, browser, isolation, parallelization, testing, sync, playwright, mcp, lace]
---

# Browser Isolation and Parallelization: Affordances for Multi-Client Sync Testing and a Parallelized Browser Delegate

> BLUF: weftwise's browser tooling is architected around exactly one implicit browser session per Claude Code session (one pinned `@playwright/mcp` process, no `--isolated`/`--user-data-dir`, one `.mcp.json` entry), and its e2e suite is explicitly serialized (`fullyParallel: false`, `workers: 1`, "port contention, shared sync state"). Both are load-bearing choices, not oversights, but both block the two things this report was asked to unblock: driving 2+ synchronized clients from one agent, and parallelizing a browser-delegate agent across worktrees.
> The fix is not "make one MCP server juggle N sessions". Playwright's own maintainers have closed that exact feature request and said, verbatim, "start multiple mcp servers" for multi-session isolation.
> The cheapest correct unit for multi-client sync tests is a **single Playwright script driving N `browser.newContext()`s** (already how weftwise's own `createIsolatedContext` helper works, minus its unnecessary second `chromium.launch()`); the cheapest correct unit for a **parallelized delegate agent** is **`@playwright/cli`'s named, isolated sessions**, a new (Jan 2026+) official Microsoft tool built specifically for coding agents that sidesteps the "subagents don't inherit MCP tools" wall weftwise has already documented.
> This is exploratory, reference material for the forthcoming `/propose-revise`; no option below is a decision.

## Context / Background

This is the isolation/parallelization sidecar to the browser-delegation plugin effort tracked in the untracked devlog `cdocs/devlogs/2026-09-17-browser-delegation-plugin.md`.
Two problems motivate it in the downstream project (`weftwise`, real path `../../weftwise/main`):

1. UI testing is held back because concurrent Playwright browser instances are hard to spawn today.
2. weftwise's sync/collab stack (Loro CRDT, `packages/loro-multiplex`, referred to as "bocsync" in the commissioning brief) inherently needs 2+ concurrent clients to test, and that has always been painful.

This report inventories what exists today, what upstream Playwright/MCP now offers for isolation, and how weftwise's own `lace` devcontainer machinery (port + mount assignment) could plausibly plug in. Without deciding anything.

## Key Findings

- **The current MCP wrapper hardcodes a single browser identity, not a single-instance limit.**
`scripts/playwright-mcp-launch.sh` pins `@playwright/mcp@0.0.78` and one `chromium_headless_shell-1232` binary in lockstep with `.devcontainer/Dockerfile`, and passes only `--no-sandbox --headless --executable-path`.
It passes neither `--isolated` nor `--user-data-dir`, so every launch gets *some* profile, but the isolation behavior is whatever `@playwright/mcp`'s default resolves to (see below).
Nothing in the wrapper deliberately enables or defeats multi-instance use.
- **Per-client-root-dir isolation already exists, undocumented in weftwise.**
A Playwright MCP maintainer (`yury-s`) closed the exact "support isolated instances" feature request by pointing out: *"The user-data-dir created by default will be unique for each unique client root dir."*
Because each worktree is a distinct directory, two Claude Code sessions in two worktrees already launching their own `playwright-mcp-launch.sh` child process should already get non-colliding profiles today, with zero config change.
This has not been empirically verified in this container and should be a cheap first spike for the proposal.
- **Playwright's maintainers have closed the door on one-server-many-sessions.**
A second feature request (`sessionId` parameter so one MCP server multiplexes N isolated browser contexts) was closed with the lead maintainer's verbatim reply: *"Please start multiple mcp servers or use https://github.com/microsoft/playwright-cli instead for multiple sessions."*
This settles the "single server + more tool surface" option: it is not the sanctioned path.
- **A new official tool exists that was built for exactly this: `@playwright/cli` (`microsoft/playwright-cli`).**
First published `0.0.60` on 2026-01-26 (i.e., after this model's training cutoff), actively released through `0.1.20` on 2026-09-14 (three days before this report).
It is a **CLI**, not an MCP server: commands like `playwright-cli open`, `playwright-cli click <ref>`, `playwright-cli screenshot` are invoked directly (optionally installed as Claude Code Skills).
Its README states the intended split plainly: *"CLI + SKILLs [are] better suited for high-throughput coding agents,"* while *"MCP remains relevant for... long-running autonomous workflows where maintaining continuous browser context outweighs token cost concerns."*
- **`@playwright/cli` has first-class named, isolated sessions.**
`playwright-cli -s=<name> open <url>` addresses a specific named browser instance; `PLAYWRIGHT_CLI_SESSION=<name>` sets it for a whole agent invocation.
`playwright-cli list` / `close-all` / `kill-all` manage the set.
Sessions default to in-memory (fresh each run); `--persistent` opts into disk persistence.
This is a ready-made "session/profile per agent" primitive weftwise does not currently have.
- **`@playwright/cli` ships a multi-session monitoring dashboard.**
`playwright-cli show` opens "a session grid... grouped by workspace, each with a live screencast preview," with the ability to click into any session for full remote control.
This is directly useful for a human supervising N parallelized browser-delegate agents at once.
- **Because it is a CLI, it is available to subagents; MCP tools are not.**
`docs/playwright_mcp_usage.md` already documents, from painful experience, that "the `mcp__playwright__*` tools are connected at the top-level session and are **not** inherited by nested subagents."
A CLI invoked via `Bash` has no such boundary.
This alone may be the single most important finding for the "parallelize the browser-delegate agent" half of the ask, independent of the sync-testing half.
- **Playwright's own docs say contexts, not new browser instances, are the correct multi-client unit**, and weftwise's own test helper does not follow that guidance today.
`playwright.dev/docs/browser-contexts` states contexts are "fast and cheap to create" relative to launching a browser, are "equivalent to incognito-like profiles" with separate cookies/localStorage/sessionStorage, and gives exactly weftwise's use case (two isolated users) as the canonical example: "Create two isolated browser contexts... Create pages and interact with contexts independently."
weftwise's `e2e/livesharing/helpers.ts` `createIsolatedContext()` instead calls `chromium.launch()` **and** `browser.newContext()` per client.
Every sharer/sharee pair (used in `convergence.spec.ts`, `content_metadata_sync.spec.ts` x6, `presence_scoping.spec.ts`, `revoke.spec.ts`) pays for two full browser process launches when Playwright's own model says one browser + two contexts is isolated enough.
- **The e2e suite is already globally serialized, and the stated reason is server-side, not browser-side.**
`playwright.config.ts` sets `fullyParallel: false`, `workers: 1`, with the comment "Livesharing tests must run serially (port contention, shared sync state)."
The single embedded dev server (`webServer`, one `/sync` endpoint, one persistence path) is shared by every test in the run; parallel workers would need their own server + persistence + port, not just cheaper browsers.
This mirrors, structurally, the same problem `worktree.sh qa-up` already solves for interactive dev (`data/qa/<branch>/` scratch persistence + a portless-routed server per worktree).
The e2e config just doesn't reuse that pattern for automated multi-worker CI runs.
- **weftwise already has a scriptable, agent-drivable second Electron client**, independent of the browser question.
`packages/weft/scripts/test-electron-pw.mjs`'s `PW_CLIENT_ACTION` env hook imports a module exporting `async ({ app, win, summary }) => ...` and runs it against a live Electron window before teardown: "This makes the same harness a scriptable SECOND Electron client against a live dogfood web server."
This is the one piece of the multi-client story that is *not* a research gap; it is shipped and just needs a browser-side counterpart to pair with.
- **`pnpm qa` / `worktree.sh qa-up` is the existing multi-client sync verification path today, and it is human-in-the-loop by design.**
It builds a production server, health-checks it, and launches a container-headed Electron client on a worktree's portless route so "a maintainer... exercises live sync between their real host browser and the Electron window."
The two clients already have "naturally distinct storage (the browser profile; the Electron's per-branch `WEFT_USER_DATA_DIR`)."
Nothing about it is agent-drivable on the browser side today.
That gap is exactly what this sidecar is scoping affordances for.
- **`lace`'s port/mount assignment machinery operates at container granularity, not per-worktree or per-agent granularity.**
`.lace/port-assignments.json` and the generated `.lace/devcontainer.json` show ports are allocated once per devcontainer **feature** (`portless:1` -> `proxyPort: 22427`, `lace-fundamentals:1` -> `sshPort: 22425`), declared via each feature's `devcontainer-feature.json` and resolved by lace's allocator into `appPort`/`forwardPorts` at container build time.
Per-worktree distinctness (the `<branch>.weftwise.localhost:1355` routing, the dynamic vite port, the `TANSTACK_DEVTOOLS_PORT` offset) is handled *inside* the container at runtime by the `portless` CLI + `scripts/worktree.sh`, never re-touching `.lace/port-assignments.json`.
A browser/MCP port would plug into lace the same way `portless` does today (as a new devcontainer feature declaring one container-level port), not as a per-worktree lace record; per-worktree/per-agent browser isolation is a `portless`/`worktree.sh`-layer problem, mirroring how vite ports are already solved, not a `lace`-layer one.
- **The devcontainer's version pinning is a packaging constraint, not a parallelism constraint.**
The `PLAYWRIGHT_MCP_VERSION`/`PINNED_MCP_VERSION` lockstep pin (`0.0.78`, three releases behind the current `0.0.81` as of 2026-09-14) exists to avoid the SIGTRAP-inducing `channel: "chrome-for-testing"` regression class (documented across three prior incident reports: 2026-01-18, 2026-05-24, 2026-07-25).
Running N copies of the *same* pinned binary concurrently is unaffected by this; the pin only becomes a parallelism concern if a future design wants different worktrees or clients to intentionally use *different* browser builds (e.g., cross-browser sync testing), which the pin currently forecloses project-wide.

## Why the Current Setup Resists Parallelism

Three independent layers each assume "one browser session," for different reasons, and they compound:

1. **The MCP launch path** (`scripts/playwright-mcp-launch.sh` + `.mcp.json`) is written for one Claude Code session driving one browser through one set of MCP tools.
It neither declares isolation (`--isolated`/`--user-data-dir`) nor a shared/multi-client transport (`--port` for SSE, `--shared-browser-context`).
Concurrency across *sessions* may already work by accident (client-root-dir-keyed profile paths, per the closed upstream issue), but concurrency *within* a session, driving two logically distinct clients from one agent turn, is not something the MCP tool surface exposes at all: `browser_navigate`/`browser_click`/etc. operate on an implicit single page/context.
2. **Subagents cannot reach the MCP tools at all.**
This is the wall `docs/playwright_mcp_usage.md` already hit twice ("no browser evidence, Chromium missing," diagnosed as a tool-inheritance gap, not an environment gap).
Any plan to parallelize a browser-delegate agent across subagents or worktrees must route around MCP for the delegated work, not through it.
3. **The e2e test harness is globally serial by explicit design**, because the thing being shared across a hypothetical parallel run is the *server* (one dev server process, one `/sync` endpoint, one persistence directory), not the browser.
`createIsolatedContext`'s extra `chromium.launch()` per client adds browser-side cost on top, but removing it would not unblock parallel *workers*.
Only cut the per-test cost of the two-client pattern already run serially.

None of these are simple oversights: the version pin defends against a real, twice-recurring crash class; the serial `workers: 1` defends against real shared server state; the MCP-not-in-subagents boundary is a Claude Code platform property, not a weftwise choice.
Any recommendation has to work with these constraints, not against them.

## Isolation & Parallelism Affordances

### Contexts vs. pages vs. full browser instances

| Unit | Isolation | Cost | Fit for multi-client sync tests |
| --- | --- | --- | --- |
| Page (tab) in a shared context | None — shares cookies, localStorage, IndexedDB, service workers with every other page in that context | Cheapest | Wrong unit: two "clients" sharing storage means they are the same client if the app derives identity from local state (weftwise's guest ID is `localStorage`-derived per `setupCleanState`) |
| **Browser context** (`browser.newContext()`) | Full: separate cookies/localStorage/sessionStorage/cache, "equivalent to incognito-like profiles" (Playwright docs) | Cheap — no new process | **Cheapest correct unit.** This is Playwright's own documented pattern for exactly this scenario (two isolated users, one browser) |
| Full browser instance (`chromium.launch()` per client) | Full, plus separate OS process / crash domain | Most expensive (~2x+ memory/CPU/startup per extra client) | Only worth it when process-level isolation is actually needed (e.g., simulating genuinely different machines, or driving one client headed and one headless) — not needed for weftwise's current sync tests, which use it today without apparent reason |

**Trade-off, stated plainly:** weftwise's `createIsolatedContext` already gets full storage isolation from `browser.newContext()` alone; the paired `chromium.launch()` buys process-level isolation that nothing in the sync tests currently requires. Collapsing to one shared `browser` + N `newContext()` calls is a same-behavior, lower-cost change confined to one helper file. A good first, cheap thing for the eventual proposal to scope, independent of any MCP/CLI decision.

### Multiple MCP server instances vs. one server driving multiple contexts

- **One server, multiple contexts (via a `sessionId`-style API): not available, and Playwright's maintainers declined to build it**, per the closed `microsoft/playwright#40585` request. The MCP tool surface (`browser_navigate`, `browser_click`, ...) is designed around one implicit session per server connection; `browser_tabs` manages multiple *tabs*, which is the "page in a shared context" row above, not isolated clients.
- **Multiple MCP server processes, each with its own `--isolated` or distinct `--user-data-dir`: the maintainer-endorsed path** for concurrent/isolated MCP-driven sessions ("Please start multiple mcp servers"). Concretely this means N entries in `.mcp.json` (or N dynamically-launched server processes if going outside the static-config model), each pinned to the same reviewed executable/version, each with a distinct `--user-data-dir` (or `--isolated` for throwaway isolation). This scales but adds N processes' worth of the exact packaging risk (`chromium_headless_shell` binary, `--executable-path`, version pin) the current wrapper already manages once.
- **`--shared-browser-context` exists and does the opposite of what's wanted here**. It forces multiple *HTTP* clients connecting to one SSE-transport server to reuse one context. Worth knowing it exists (and that the unstated default is evidently per-client contexts under SSE transport, which is itself a candidate affordance: see Open Questions), but not a fit for "isolated" multi-client testing as posed.

### Per-worktree / per-agent isolation via `lace`

Lace's port/mount assignment machinery (`.lace/port-assignments.json`, `.lace/mount-assignments.json`, and the generated `.lace/devcontainer.json`) allocates one port per devcontainer **feature**, at container build time, from a project-wide range (e.g., `portless:1` -> `proxyPort: 22427`). It is not a per-worktree or per-agent registry today.
Per-worktree distinctness for the *app* is solved one layer down, inside the running container, by `portless` + `scripts/worktree.sh`: a branch-derived route name (`<branch>.weftwise.localhost`), a dynamically-picked vite port, and an offset `TANSTACK_DEVTOOLS_PORT` to dodge a hardcoded default port.
That pattern (stable name derived from the worktree branch, dynamic port picked at runtime, fronted by one shared container-level proxy) is the one weftwise has already proven works for N concurrent worktrees, and is the natural template for browser isolation too:

- **If browser sessions should be visible/named per worktree:** key session names off the same branch string `worktree.sh` already derives (`git branch --show-current`), e.g. `playwright-cli -s=<branch>` or `-s=<branch>-sharer` / `-s=<branch>-sharee` for the two sync roles. No new lace port is required for this. `@playwright/cli` sessions are addressed by name, not by port.
- **If a human needs to *watch* those sessions from the host browser** (the `playwright-cli show` dashboard, or a future SSE-transport MCP server), that is the one place a new lace-managed port plausibly makes sense, by the same mechanism `portless` already uses: a new devcontainer feature (or an extension of an existing one) declaring a port need, which lace's allocator then publishes via `appPort` and which `portless`'s existing host-front-end (`:1355`) or a sibling proxy could route by Host header, exactly as it already does for every worktree's vite server.
This is new plumbing (no existing feature declares a "browser dashboard" port today) and should be scoped as such, not assumed to already exist.
- **Mount isolation** (`.lace/mount-assignments.json`) is a different axis (host paths bind-mounted into the container: AWS config, dotfiles, screenshots) and has no obvious browser-profile analogue yet.
`@playwright/cli`/`@playwright/mcp` profile directories live inside the container's filesystem already (`~/.cache/ms-playwright/...`, or wherever `--user-data-dir` points), so there is nothing to mount from the host unless a future design wants browser profiles to persist *across* container rebuilds, which is a real but separate question from per-worktree/per-agent concurrency.

### Containerized/sandboxed browsers vs. the devcontainer's version pin

The pin (`PLAYWRIGHT_MCP_VERSION` / `PINNED_MCP_VERSION` / the Dockerfile's matching `install-browser` step) exists to guarantee the `@playwright/mcp`-bundled `playwright-core`'s expected Chromium revision is present at image build time, defending against the exact class of regression that broke MCP three separate times (2026-01-18, 2026-05-24, 2026-07-25 reports).
This is orthogonal to running multiple *copies* of that same pinned binary concurrently. Nothing about the pin limits process count, only build identity.
It would become a live constraint only if a future design wants:
- Different browser engines per client (e.g., Chromium sharer + WebKit sharee, for cross-browser sync coverage). The Dockerfile already installs `chromium` and `firefox` for the project's own `playwright@1.57.0` (separate from the MCP-pinned headless-shell), so the raw binaries exist; wiring them into a multi-client scheme is unexplored.
- Per-worktree browser version drift (e.g., a worktree testing a Playwright upgrade). Currently impossible without touching the shared Dockerfile, since the pin and the binary cache are container-wide, not per-worktree.

### Session/profile-per-agent for a parallelized delegate

`@playwright/cli`'s named sessions (`-s=<name>` / `PLAYWRIGHT_CLI_SESSION`) are close to a ready-made answer to "give each delegate agent instance its own safe browser identity": each parallel delegate (one per worktree, or one per logical role in a sync test) gets a distinct session name, sessions default to fresh in-memory profiles (no cross-contamination unless `--persistent` is explicitly requested), and `playwright-cli list` / `kill-all` give the orchestrating agent (or a human) a way to audit and reap live sessions.
This is a capability `@playwright/mcp`'s single-implicit-session model does not expose at all.
Because it is invoked as a CLI, this composes with Claude Code's subagent model without hitting the MCP-tool-inheritance wall: a browser-delegate subagent just needs `Bash` access to `playwright-cli`, in any worktree, with no per-worktree `.mcp.json` wiring.

The one open packaging question this report did not resolve: whether `@playwright/cli` (which likely bundles its own `playwright-core`, like `@playwright/mcp` does) is subject to the same `channel: "chrome-for-testing"` / crashpad SIGTRAP class this devcontainer has hit three times with `@playwright/mcp`.
This needs its own empirical spike (a TDD-style launch check, per `CLAUDE.md`'s validation-workflow instincts, but for `playwright-cli open --headless` instead of `wezterm ls-fonts`) before any proposal leans on it.

## Testing Sync Specifically

Three patterns for driving 2+ synchronized clients, none mutually exclusive:

1. **Single script, N `browser.newContext()`s (already partially shipped).**
This is what `e2e/livesharing/*.spec.ts` already does, modulo the extra `chromium.launch()` per client noted above.
It is the cheapest, most CI-friendly pattern for pure browser-to-browser sync coverage, and the one Playwright's own docs recommend by name for this exact scenario.
Its current ceiling is the shared single dev server + `workers: 1`. Parallelizing *across* such tests (not just within one) needs the server-side isolation `qa-up` already has (`data/qa/<branch>/` scratch persistence, a portless route, a fresh `SYNC_JWT_SECRET`) ported into the e2e harness's `webServer`/worker model, which is unexplored today.
2. **Two separate `@playwright/cli` sessions, potentially driven by two different agent turns or subagents.**
Useful when the two clients genuinely need independent driving intelligence - e.g., an Opus lead interactively steering "client A" while a Sonnet delegate subagent drives "client B" against the same live route, or when a human wants to watch both via `playwright-cli show` while an agent drives one side.
This is the pattern that most directly serves "parallelize the browser-delegate agent," and is novel relative to anything weftwise has today.
3. **A real Electron peer via `PW_CLIENT_ACTION`, paired with either of the above on the browser side.**
Already shipped (`test-electron-pw.mjs`), already used by `qa-up`'s human-in-the-loop flow.
The gap is purely on the browser side: `qa-up` today expects a *human* at the host browser; swapping that side for an agent-driven `@playwright/cli` (or a second MCP server) session pointed at the same portless route would make the whole two-client flow agent-drivable end to end, with the Electron half needing no new work.

**Coordination model, whichever pattern is chosen.**
CRDT sync is eventually consistent, and weftwise's own `CLAUDE.md` already mandates the right posture for this ("MULTI-CLIENT: verify with 2+ browser tabs," systematic debugging with "timestamped events... to identify race conditions," logging "at LiveSharing -> Y.js multiplex -> WebRTC -> Y.js CRDT -> CodeMirror boundaries").
A delegate agent coordinating N sessions needs the same discipline mechanized: explicit convergence polling (poll shared/awareness state until both sides agree, as `e2e/livesharing/convergence.spec.ts` already does under the hood) rather than fixed sleeps, and (if sessions are named/addressable per `@playwright/cli`'s model, or route-addressable per `qa-up`'s portless route) a small registry mapping logical roles ("sharer," "sharee") to concrete session/route handles, so a multi-turn delegate agent can re-address the same live client across tool calls the way `.lace/port-assignments.json` lets lace re-address a stable port across a container's lifetime.
No such registry exists for browser sessions today; it is the one piece of net-new state this line of work would need to invent.

## Recommendations (Reference, Not a Decision)

Ranked by how directly each serves the two stated goals, for the forthcoming `/propose-revise` to weigh:

1. **Adopt `@playwright/cli` as the browser-delegate agent's primary interface**, not `@playwright/mcp`.
It is CLI-based (works in subagents, unlike MCP), has native named/isolated sessions (the per-agent identity primitive), and ships a multi-session dashboard for human oversight.
Spike the crashpad/channel-pinning question before committing.
2. **Fix `e2e/livesharing/helpers.ts`'s `createIsolatedContext` to reuse one `browser` across `newContext()` calls**, matching Playwright's own documented pattern.
Independent of every other recommendation, cheap, and reduces the per-test cost that the existing `workers: 1` serialization already pays for on every run.
3. **For agent-drivable multi-client sync testing, close the gap in `qa-up`** by giving its browser side an agent-drivable counterpart to the human today: either a second named `@playwright/cli` session or a second isolated `@playwright/mcp` server instance pointed at the same portless route, alongside the already-working `PW_CLIENT_ACTION` Electron peer.
4. **Treat "N MCP server instances" as the fallback, not the default**, for any scenario that specifically needs MCP's tool surface (accessibility snapshots, etc.) rather than CLI's token efficiency. Each instance needs its own `--isolated`/`--user-data-dir` and its own copy of the version-pin discipline the current wrapper already carries once.
5. **Scope per-worktree browser session naming off the same branch-derivation `worktree.sh` already uses**, rather than inventing a second naming scheme; reserve an actual `lace`-managed port only for the human-facing dashboard/monitoring surface, following the `portless` feature as the template, and treat that as new plumbing to be designed, not assumed.
6. **Do not touch the `@playwright/mcp` version pin as part of this work.**
It defends against a real, three-times-recurring failure class and is orthogonal to the concurrency problem; any multi-instance MCP design should pin the *same* reviewed version N times, not relax the pin.

## Open Questions for the Proposal

- Does `@playwright/cli` bundle a `playwright-core` subject to the same `channel: "chrome-for-testing"` SIGTRAP class as `@playwright/mcp`? Needs an empirical spike in this devcontainer before being relied on.
- Is the "unique user-data-dir per client root dir" default (confirmed by upstream maintainer comment, not yet empirically verified in this container) actually sufficient today for two worktrees to run `@playwright/mcp` concurrently without collision?
Or does the shared `.mcp.json`/wrapper script path resolve to the same root dir regardless of worktree?
- What should the server-side isolation story be for parallelizing the e2e suite itself (not just the delegate agent)?
Porting `qa-up`'s per-branch scratch persistence + portless routing into the `playwright.config.ts` `webServer`/worker model is sketched here but not designed.
- Is a new lace devcontainer feature (a "browser-mcp" or "playwright-dashboard" port, modeled on `portless`) worth building for host-visible session monitoring?
Or is SSH-port/existing-proxy tunneling sufficient for the near term?
- How should the sync-test coordination registry (role -> session/route handle) be shaped, and should it live alongside or reuse `.lace/*-assignments.json`'s label/timestamp convention, or be a weftwise-local concern entirely?

## Prior Art in This Corpus

- `cdocs/reports/2026-08-05-visual-verification-skills-web-survey.md` (clauthier): established that MCP browser servers are capture tools, not verdict tools, for visual review.
This report extends the capture-layer analysis to the isolation/concurrency dimension.
- `cdocs/reports/2026-07-18-lace-portless-ingress-architecture.md` (weftwise): the definitive reference for how lace + portless + podman/pasta wire host-to-container reachability.
Grounds this report's "lace ports are container-feature-level, not per-worktree" finding.
- `cdocs/reports/2026-07-25-dev-environment-and-test-debt.md` and `cdocs/proposals/2026-07-25-dev-environment-fixes.md` (weftwise): the incident history behind the current version pin.
Source of the exact wrapper script this report analyzes.
- `docs/worktree_development.md` and `docs/playwright_mcp_usage.md` (weftwise): source of the `portless`/`worktree.sh` per-worktree routing pattern, the `qa-up` two-client flow, the `PW_CLIENT_ACTION` Electron hook.
Documents the MCP-tools-not-inherited-by-subagents boundary this report leans on throughout.
