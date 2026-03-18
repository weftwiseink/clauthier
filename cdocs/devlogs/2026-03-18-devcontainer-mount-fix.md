---
first_authored:
  by: "@claude-opus-4-6"
  at: 2026-03-18T09:23:00-07:00
task_list: devcontainer/setup
type: devlog
state: live
status: done
tags: [devcontainer, lace, bugfix]
---

# Devcontainer Mount Path Fix

> BLUF: `lace up` failed because the opencode static mount used `~` instead of an absolute path.
> Fixed by replacing `~` with `${localEnv:HOME}` in the mount source.

## Problem

Running `lace up` on clauthier failed at the `devcontainerUp` phase with:

```
docker: Error response from daemon: create ~/.local/share/opencode:
"~/.local/share/opencode" includes invalid characters for a local volume name
```

The static mount in `.devcontainer/devcontainer.json` used shell-style tilde expansion (`~/.local/share/opencode`), which Docker's `--mount` syntax does not support.
Lace-managed mounts (via `customizations.lace.mounts`) are resolved to absolute paths automatically, but this mount was in the plain `mounts` array and passed through to Docker as-is.

## Fix

Replaced `source=~/.local/share/opencode` with `source=${localEnv:HOME}/.local/share/opencode,type=bind`.
The `${localEnv:HOME}` variable is a devcontainer spec feature that the devcontainer CLI resolves to the host user's home directory before passing to Docker.
Also added explicit `type=bind` to match the other mount entries.

## Files Changed

- `.devcontainer/devcontainer.json`: Fixed opencode mount source path.
