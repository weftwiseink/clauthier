---
first_authored:
  by: "@claude-opus-4-6"
  at: 2026-03-18T09:30:00-07:00
task_list: devcontainer/setup
type: report
state: live
status: final
tags: [lace, debuggability, devcontainer, developer-experience]
---

# Lace Debuggability Assessment

> BLUF: Lace's debugging story is above average for a young CLI, with well-structured phased console output and a machine-readable `LACE_RESULT` line.
> However, when fixing a static mount path error in clauthier's devcontainer, the actual diagnosis came from Docker's error message, not from any lace-specific affordance.
> The main gaps are: no verbose/debug mode, no persistent logs, and no validation of passthrough (non-lace-managed) config.

## Context

This assessment is based on hands-on debugging of a `lace up` failure for the clauthier project's devcontainer.
The failure was a static mount using `~` in the source path, which Docker rejected because `--mount` syntax requires absolute paths.
The fix was a one-line change: replacing `~` with `${localEnv:HOME}` in `.devcontainer/devcontainer.json`.

## Strengths

### Phased Console Output
Lace's pipeline output is organized by phase (workspace layout, metadata fetch, port allocation, mount resolution, prebuild, devcontainer up).
This made it immediately clear the failure was in `devcontainerUp`, not in lace's own config generation.
The `--skip-devcontainer-up` flag was useful for confirming lace's pipeline completed cleanly in isolation.

### Machine-Readable Exit Status
The `LACE_RESULT` JSON line emitted to stderr (`{"exitCode":1,"failedPhase":"devcontainerUp","containerMayBeRunning":false}`) is a thoughtful design for programmatic callers like `wez-into`.
Most CLIs don't provide structured error metadata for downstream tooling.

### Internal Documentation
The lace repo has thorough error-triage analysis in `cdocs/reports/` and a troubleshooting guide at `packages/lace/docs/troubleshooting.md` covering 12 specific failure modes with causes and fixes.
The error-triage report (`cdocs/reports/2026-02-22-error-triaging-and-fallback-handling.md`) demonstrates careful thinking about error classification and retry semantics.

## What We Actually Used

The debugging session relied primarily on:

1. Reading the `lace up` console output to identify the failing phase.
2. Reading Docker's error message, which was the actual diagnostic: `"~/.local/share/opencode" includes invalid characters for a local volume name`.
3. Using `--skip-devcontainer-up` to confirm lace's pipeline was healthy.

The `LACE_RESULT` JSON confirmed what the console already showed.
The troubleshooting doc's 12 failure modes did not cover this case.
No other lace-specific debugging affordance was involved.

## Gaps

### No Verbose or Debug Mode
There is no `--verbose`, `--debug` flag, or `LACE_DEBUG` environment variable.
When lace's pipeline succeeds but `devcontainer up` fails, the only diagnostic is whatever the devcontainer CLI prints.
A verbose mode that logged the resolved mount specs before invoking Docker would have made the bad `~` path obvious without needing to read the generated `.lace/devcontainer.json`.

### No Persistent Log File
Output is ephemeral.
The `wez-into` wrapper does a `tee` to a temp file, but it's cleaned up on exit via trap.
If you run `lace up` directly and don't capture output, the diagnostic is gone.

### No Validation of Passthrough Config
Lace validates its own managed mounts thoroughly: namespace checks, `sourceMustBe` type enforcement, missing-source warnings, target conflict detection.
But the plain `mounts` array in `devcontainer.json` passes through unexamined.
This is the gap that caused our failure.
Lace could detect `~` or other shell-expansion characters in static mount sources and warn before handing off to Docker.

### Documentation is Contributor-Focused
The error-triage reports and troubleshooting guide are written more as architectural analysis for contributors than as user-facing debugging guides.
The volume of `cdocs/` content (60+ reports, 30+ proposals) makes it hard for an unfamiliar user to find the right document.
`packages/lace/docs/troubleshooting.md` is the best entry point but is not discoverable from CLI output on failure.

## Recommendations

1. **Validate static mounts**: Warn on `~`, unresolved env vars, or non-absolute paths in the passthrough `mounts` array before invoking `devcontainer up`.
2. **Add `--verbose` flag**: Log resolved config details (mount specs, port mappings, Dockerfile path) to aid diagnosis when the downstream Docker build or run fails.
3. **Persist logs on failure**: Write `lace up` output to `.lace/last-run.log` (or similar) when the exit code is non-zero, so diagnostics survive the terminal session.
4. **Surface troubleshooting doc on failure**: Print a hint like `See: https://... or packages/lace/docs/troubleshooting.md` when `devcontainer up` fails with a non-zero exit.
