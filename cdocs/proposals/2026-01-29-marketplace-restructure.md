---
first_authored:
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-29T17:00:00-08:00
task_list: marketplace/restructure
type: proposal
state: archived
status: implementation_accepted
tags: [architecture, marketplace, rename]
---

# Marketplace Restructure and cdocs→cdocs Rename

> BLUF: Restructure the repo from a single plugin into a Claude Code marketplace, moving plugin components under `plugins/cdocs/` with a root `marketplace.json`.
> Rename `cdocs` to `cdocs` (short for CircumLOCutory; also a play on CLaude + docs).
> Install the plugin in the repo itself for dogfooding via `.claude/settings.json`.

## Objective

Convert this repository from a single Claude Code plugin into a marketplace that can host multiple plugins.
The existing plugin gets renamed from `cdocs`/`cdocs` to `cdocs`/`cdocs` and moved under `plugins/cdocs/`.

## Background

The repo currently uses the single-plugin layout (`.claude-plugin/plugin.json` at root).
Claude Code supports a marketplace format: `.claude-plugin/marketplace.json` at root, with plugins in subdirectories.
The `cdocs-plan.md` noted this as a future possibility.

The Claude Code marketplace docs specify:
- `.claude-plugin/marketplace.json` at repo root with `name`, `owner`, `plugins[]` fields.
- Each plugin entry has `name`, `source` (relative path), and optional metadata.
- Each plugin directory contains its own `.claude-plugin/plugin.json`, `rules/`, `skills/`, `hooks/`.
- Plugins are copied to a cache on install, so they cannot reference files outside their directory.

## Proposed Solution

### New Layout

```
/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace catalog
├── plugins/
│   └── cdocs/
│       ├── .claude-plugin/
│       │   └── plugin.json       # Plugin metadata (name: "cdocs")
│       ├── rules/                # Writing conventions, workflow, frontmatter spec
│       ├── skills/               # devlog, propose, review, report, status, init, implement
│       └── hooks/                # Frontmatter validation hook
├── cdocs/                        # Dogfood docs (our own docs using the plugin)
├── .claude/
│   └── settings.json             # Marketplace + plugin enable for dogfooding
├── CLAUDE.md
├── README.md                     # Updated for marketplace context
├── cdocs-plan.md
├── LICENSE
└── .gitignore
```

### Rename Scope

| Old | New | Context |
|-----|-----|---------|
| `cdocs` | `cdocs` | Plugin name, skill prefix (`/cdocs:devlog`) |
| `cdocs` | `cdocs` | Directory names, path references |
| `CDocs` | `CDocs` | Titles, headings |
| `cdocs-validate-frontmatter.sh` | `cdocs-validate-frontmatter.sh` | Hook script |

### Dogfooding

`.claude/settings.json` will reference the marketplace via GitHub so the plugin is active when working in this repo:
```json
{
  "extraKnownMarketplaces": {
    "clauthier": {
      "source": {
        "source": "github",
        "repo": "weftwiseink/cdocs"
      }
    }
  },
  "enabledPlugins": {
    "cdocs@clauthier": true
  }
}
```

NOTE(mjr): For local development, add the marketplace locally via `/plugin marketplace add .` to use unpushed changes.

## Important Design Decisions

### Decision: marketplace name `clauthier`

**Why:** Neutral, org-level name that can host plugins beyond cdocs in the future.

### Decision: keep `cdocs/` docs directory at repo root

**Why:** The docs directory is not part of the plugin (it is output produced by using the plugin).
It stays at repo root for dogfooding.
Plugins are copied to cache on install, so plugin consumers create their own `cdocs/` in their repos via `/cdocs:init`.

### Decision: fix hook script name mismatch during rename

**Why:** `hooks.json` references `cdocs_validate_frontmatter.sh` (underscores) but the file uses dashes.
The rename normalizes to `cdocs-validate-frontmatter.sh` with a matching hooks.json reference.

## Implementation Phases

### Phase 1: Structural moves

1. Create `plugins/cdocs/.claude-plugin/` directory.
2. `git mv rules/ plugins/cdocs/rules/`
3. `git mv skills/ plugins/cdocs/skills/`
4. `git mv hooks/ plugins/cdocs/hooks/`
5. Remove `.claude-plugin/plugin.json`, create `.claude-plugin/marketplace.json`.
6. Create `plugins/cdocs/.claude-plugin/plugin.json`.
7. `git mv cdocs/ cdocs/`
8. `git mv cdocs-plan.md cdocs-plan.md`

### Phase 2: Content rename

Search-and-replace across all files:
- `cdocs` → `cdocs`
- `cdocs` → `cdocs`
- `CDocs` → `CDocs`
- Fix hook filename in `hooks.json`.
- Update README.md for marketplace framing.
- Update CLAUDE.md references.

### Phase 3: Dogfooding setup

1. Create `.claude/settings.json` with marketplace and plugin config.
2. Verify with `claude plugin validate .` if available.
