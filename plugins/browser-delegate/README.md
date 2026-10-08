# browser-delegate

> BLUF: One sonnet leaf agent, `browser-delegate`, drives named [`@playwright/cli`](https://github.com/microsoft/playwright-cli) browser sessions for a dispatching agent and returns a fixed `BROWSER DELEGATE REPORT` of artifact paths and mechanical facts, never a verdict.
> The dispatcher pays one dispatch and one report instead of holding the browser tool-call loop itself.

Claude Code only.
The plugin ships one agent and nothing else: no skills, no rules, no hooks, no MCP server.

## Install

```bash
claude plugin marketplace add weftwiseink/clauthier
claude plugin install browser-delegate@clauthier
```

### Prerequisites

1. **A global, pinned `@playwright/cli`:** `npm install -g @playwright/cli@0.1.22` (the version this plugin is verified against).
   The agent resolves a global `playwright-cli` first, then a project-local `node_modules/.bin/playwright-cli`, and otherwise reports `Status: FAILED` without falling back to anything.
   Prefer the global install: sessions are namespaced by the CLI's install root, so one stable install is what lets a later dispatch find a session by name.
   The agent never uses `npx -y`, since each npx cache copy is a separate namespace.
2. **A browser the CLI can launch.**
   With no config, the CLI launches the system Google Chrome channel (`/opt/google/chrome/chrome` on Linux) and fails where it is absent, as in most devcontainers.
   Point it at a Playwright headless shell with a config file:

   ```json
   {
     "browser": {
       "browserName": "chromium",
       "launchOptions": {
         "executablePath": "/home/node/.cache/ms-playwright/chromium_headless_shell-1232/chrome-headless-shell-linux64/chrome-headless-shell",
         "headless": true
       }
     }
   }
   ```

   Put it at `~/.playwright/cli.config.json` (read from any cwd), at `<project>/.playwright/cli.config.json` (the agent passes it with `--config` because it runs from scratch, where the CLI's own cwd-relative lookup would miss it), or give its path in the dispatch prompt.
3. **ImageMagick** (`compare`, `identify`), only for baseline diffs.

### Pinning

`@playwright/cli` resolves browser channels with the same `playwright-core` code as `@playwright/mcp`, so it shares that package's version-coupling hazard: `--browser=chromium` means the full chrome-for-testing binary (with `chrome_crashpad_handler`, the binary behind weftwise's 2026 SIGTRAP incidents), and the default means system Chrome.
At 0.1.22 (chrome-for-testing 155) the full binary launched cleanly in the weftwise devcontainer image; the crashes on record are weftwise's `@playwright/mcp` incidents at earlier chrome-for-testing revisions, which were not retested with the CLI.
Apply the same discipline as for `@playwright/mcp`: pin the CLI version, pin `executablePath` to an installed headless-shell revision in the config, and bump both together.

## Dispatch

Dispatch with the Agent tool, `subagent_type: "browser-delegate:browser-delegate"`.
The prompt is a few labeled lines:

```
Sessions: preview
Route: https://<branch>.weftwise.localhost:1355/settings
Actions: navigate; wait-for #settings-panel; screenshot full-page
Baseline: cdocs/_media/2026-09-10-settings-mock.png (diff the full-page screenshot)
```

- **Sessions** are roles.
  Each session is named `<sanitized-branch>-<role>` (`feature/foo` + `preview` is `feature-foo-preview`) unless the prompt names it explicitly (`preview (name: my-session)`).
- **Actions:** `navigate`, `click <target>`, `type <target> <text>`, `wait-for <selector>`, `text present <text>`, `screenshot [full-page]`, `snapshot`, `poll-until <condition>`.
  Targets are selectors or refs from a prior snapshot.
- **Optional:** `Baseline:` one image and the screenshot to diff it against (`compare -metric AE`), `Config:` a CLI config path, `fresh sessions` (close any live session of that name first), `idle timeout <ms>`, and a convergence timeout for `poll-until`.

The model defaults to sonnet; override per dispatch with the Agent tool's `model` parameter.

## Report

```
BROWSER DELEGATE REPORT
Sessions: <name> (role: <role>, route: <url>, opened | reused | reopened)
Status: OK | FAILED | WARNINGS
Artifacts: <abs path> (<screenshot | snapshot | diff>)
AE score: <n> (<candidate abs path> vs <baseline abs path>) | size mismatch <WxH> vs <WxH> | n/a
Facts:
- <mechanical fact>: <yes | no | value>
- converged: yes after <n>s | no, timed out at <n>s; last-seen <session>: <state>
Truncated: none | <what was omitted>; see: <path>
```

`Sessions` and `Artifacts` repeat once per session and per artifact.
There is no field a verdict could go in: looking at the artifacts and judging them is the dispatcher's job.

Session states are what one dispatch can observe:

| State | Meaning | Dispatcher reading |
|---|---|---|
| `opened` | Not live at dispatch start, or closed first because fresh sessions were asked for | Empty cookies and storage; if you expected continuity, state was lost |
| `reused` | Live at dispatch start | State carried over from an earlier dispatch |
| `reopened` | Died during this dispatch and was re-opened under the same name | State lost mid-dispatch |

Artifacts live under `${TMPDIR:-/tmp}/claude-<uid>/browser-delegate/run.XXXXXX/`.
The agent runs every CLI command from that scratch root, so the CLI's auto-written `.playwright-cli/` never lands in your worktree.
The `Sessions` lines are the role-to-session registry; copy them into your devlog if you want it durable.

## Sessions across dispatches

Sessions outlive the agent: a later dispatch on the same name reports `reused` and continues in the same browser.
For a long flow, keep one named delegate and resume it with `SendMessage`; past the ~400K-context threshold, dispatch a new delegate on the same session names with the remaining steps (the browser state carries over, so no handoff file is needed).
A headless session shuts down after an hour idle; pass `idle timeout <ms>` for longer flows.
Profiles are in memory; the agent never uses `--persistent` unless asked, because on-disk profiles weaken isolation.

Keep one live delegate per session name (the session analog of one writer per file): serialize, or use a different role.
Two worktrees never collide because their branch prefixes differ.

## Multi-client sync testing

One delegate drives N sessions in one dispatch and sequences cross-client actions itself:

```
Sessions: sharer, sharee
Route: http://127.0.0.1:8787/doc/demo (both)
Actions: navigate both; sharer: type #editor "hello"; poll-until document.querySelector('#editor').value is equal across sessions (timeout 30s); screenshot both
```

`poll-until` runs as one shell loop over `playwright-cli -s=<name> eval ...` per session, bounded by the timeout (max 570 s, under the Bash tool's 600 s limit).
A timeout is reported as divergence with each session's last-seen value, never as success.
Dispatch separate delegates in parallel only for genuinely independent driving (two worktrees, unrelated flows).

For fixed CI regression flows, a Playwright test driving N `browser.newContext()`s stays cheaper; this agent is for agent-driven and exploratory checks.

## Under `/cdocs:iterate`

When a verification floor needs browser evidence, the round's **reviewer** dispatches the delegate itself:

- It names sessions `<branch>-review-<role>` and asks for fresh sessions, so it never lands in the implementer's browser and its report lists every session as `opened`.
  Passing the role as `review-<role>` gets that name from the default `<branch>-<role>` rule:

  ```
  Sessions: review-viewer
  Fresh sessions.
  ```

  An explicit name works too: `Sessions: viewer (name: feature-foo-review-viewer)`.
  A `reused` session never backs a `confirmed` row.
- It inlines every report line except `Truncated` in the review, plus its own description of what each cited artifact shows.
- For each screenshot its verdict relies on (only paths in the inlined `Artifacts` lines), it copies the file with `cp -n` to `cdocs/_media/YYYY-MM-DD-<review-doc-name>-<description>.png`, checks the copy with `cmp` (a mismatch means the name was taken: pick another description, never overwrite), embeds it captioned with its scratch source path, and commits it with the review by exact path.
  Uncited captures stay in scratch.

Artifacts from a delegate the reviewer dispatched in the same round count as reviewer-produced for iterate's `confirmed` row; an implementer's or an earlier round's do not.

Depth: the delegate is a leaf (no `Agent` tool).
Under a nested overseer it sits at the platform's three-layer limit, so fan-out to several delegates is always done by the dispatcher directly, never through a wrapper agent.

## Complements

The delegate never substitutes another tool for the CLI.
Reach for these yourself when the job fits:

| Tool | Use it for |
|---|---|
| `browser-delegate` (this plugin) | Driving, capture, baseline diffs, and multi-session sync checks, without the lead holding the loop |
| [`@playwright/mcp`](https://github.com/microsoft/playwright-mcp) | A lead-held interactive session, accessibility-tree-driven test authoring |
| [`chrome-devtools-mcp`](https://github.com/ChromeDevTools/chrome-devtools-mcp) | Network and performance traces, DevTools-level debugging |
| Claude in Chrome (`claude --chrome`) | Driving your own signed-in desktop Chrome interactively |

Subagents inherit the session's MCP tools, so a configured browser MCP server is reachable from the delegate too; the delegate still uses only the CLI, keeping browser tools out of every agent's tool list.
