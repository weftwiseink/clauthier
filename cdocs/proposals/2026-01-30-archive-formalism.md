---
first_authored:
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-30T12:00:00-08:00
task_list: cdocs/archive-formalism
type: proposal
state: live
status: implementation_ready
tags: [architecture, archival, cli, conventions]
last_reviewed:
  status: accepted
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-30T12:45:00-08:00
  round: 2
---

# Archive Formalism

> BLUF(mjr/cdocs/archive-formalism): Formalize the cdocs document lifecycle with a `_archive/` subdirectory convention: active documents live in `cdocs/$type/`, archived documents move to `cdocs/$type/_archive/`.
> The convention is adoptable immediately via a manual procedure (move file, update frontmatter, update references).
> A future `archive` command in the CDocs CLI (`cdocs/proposals/2026-01-30-cdocs-cli.md`) automates the move and rewrites all path references across the project; CLI automation is blocked on the CLI RFP being elaborated.

## Objective

CDocs documents accumulate over time.
Completed, superseded, or obsolete documents clutter the active directory alongside current work.
There is no formal convention for where archived documents go or how references to them should be updated.
This proposal establishes the archive convention and specifies the automation needed to maintain referential integrity when documents move.

## Background

### Current state

Documents in `cdocs/$type/` have a `state` field that can be set to `archived`, but there is no corresponding filesystem convention.
Archived documents remain in the same directory as active ones, making it harder to scan for current work.
The `state: archived` frontmatter value is defined in `plugins/cdocs/rules/frontmatter-spec.md` but has no associated tooling.

### Prior art

Common archival patterns in documentation systems:
- **`_archive/` subdirectory**: used by many wikis and documentation frameworks. The underscore prefix sorts it last and signals "not primary content."
- **Date-prefixed archive directories**: e.g., `_archive/2026-01/`. Adds temporal organization but complicates path rewriting.
- **Separate top-level directory**: e.g., `cdocs/_archive/proposals/`. Centralizes all archives but loses type-local context.

### Relevant components

- **Frontmatter spec** (`plugins/cdocs/rules/frontmatter-spec.md`): defines `state: archived` as a valid value.
- **Status skill** (`plugins/cdocs/skills/status/SKILL.md`): filters documents by state; already supports `--state=archived`.
- **CDocs CLI RFP** (`cdocs/proposals/2026-01-30-cdocs-cli.md`): the CLI that will house the archive command.

## Proposed Solution

### Directory convention

Active documents live in `cdocs/$type/`.
Archived documents live in `cdocs/$type/_archive/`.

```
cdocs/
├── proposals/
│   ├── 2026-01-30-archive-formalism.md        # active
│   ├── 2026-01-30-cdocs-cli.md                # active
│   └── _archive/
│       ├── 2026-01-29-superseded-proposal.md  # archived
│       └── 2026-01-28-obsolete-idea.md        # archived
├── devlogs/
│   ├── 2026-01-30-current-work.md
│   └── _archive/
│       └── 2026-01-28-old-session.md
├── reviews/
│   └── _archive/
└── reports/
    └── _archive/
```

The `_archive/` directory is created lazily: it appears only when a document is first archived into that type.
`/cdocs:init` does not scaffold `_archive/` directories; they are created on first use by either the manual procedure or the CLI command.

### Manual archival procedure

The directory convention is usable immediately without CLI tooling.
To archive a document manually:

1. Set `state: archived` in the document's frontmatter.
2. Create `cdocs/$type/_archive/` if it does not exist.
3. Move the file from `cdocs/$type/$filename` to `cdocs/$type/_archive/$filename`.
4. Search the project for references to the old path (e.g., `git grep "cdocs/$type/$filename"`) and update them to the new path.
5. Commit the move and all reference updates together.

This procedure is sufficient for low-volume archival.
The CLI `archive` command (below) automates steps 1-5 for higher-volume or error-prone cases.

### Archive command (CLI automation)

The CDocs CLI provides an `archive` command:

```
cdocs-cli archive cdocs/proposals/2026-01-29-superseded-proposal.md
```

This command:
1. Validates the document exists and is a cdocs document (has valid frontmatter).
2. Sets `state: archived` in the document's frontmatter (if not already set).
3. Moves the file from `cdocs/$type/$filename` to `cdocs/$type/_archive/$filename`.
4. Scans the entire project for references to the old path and rewrites them to the new path.
5. Reports what it changed: the file move and every reference rewrite, with file and line number.

### Path reference scanning

The scanner searches for the old path string across all files in the project (excluding `.git/`, `node_modules/`, and other common ignore patterns).
Reference formats to detect:

- **Markdown links**: `[text](cdocs/proposals/old-path.md)`
- **Frontmatter fields**: `review_of: cdocs/proposals/old-path.md`
- **Inline references**: plain text mentions of `cdocs/proposals/old-path.md`
- **Relative paths**: `../proposals/old-path.md` (resolved relative to the referencing file)

The rewrite is a literal string replacement of the old path with the new path.
Relative paths are recalculated based on the referencing file's location.

Fragment identifiers (e.g., `cdocs/proposals/foo.md#section-heading`) and query strings are handled naturally by literal replacement: the path portion is rewritten and the suffix is preserved.
The scanner skips binary files (detected by null byte presence or file extension heuristics) to avoid corrupting non-text content.

### Unarchive support

The command should also support unarchiving:

```
cdocs-cli unarchive cdocs/proposals/_archive/2026-01-29-superseded-proposal.md
```

This reverses the process: moves the file back, sets `state: live`, and rewrites references.
Unarchive always sets `state: live` regardless of the pre-archive state.
This is a deliberate simplification: `deferred` or other pre-archive states are not tracked, and the user can manually adjust `state` after unarchiving if needed.

## Important Design Decisions

### Type-local `_archive/` vs. centralized archive

**Decision**: type-local `_archive/` subdirectories.

**Why**: keeps archived documents near their active counterparts.
A reviewer looking at proposals can see the archive right there.
A centralized `cdocs/_archive/proposals/` directory would require navigating to a different part of the tree and duplicating the type hierarchy.
Type-local archives also make the path rewriting simpler: only one path segment changes (`$type/$file` to `$type/_archive/$file`).

### Underscore prefix for `_archive/`

**Decision**: use `_archive/` with leading underscore.

**Why**: the underscore prefix sorts the directory last in lexicographic listings, keeping it out of the way.
It also signals "infrastructure, not content" - a convention familiar from `_media/`, `__tests__/`, and similar patterns.
The existing `_media/` directory in cdocs already establishes this convention.

### Whole-project path scanning

**Decision**: scan the entire project, not just `cdocs/`.

**Why**: references to cdocs documents can appear in `CLAUDE.md`, plugin skill files, agent definitions, hooks, and arbitrary project files.
Limiting the scan to `cdocs/` would miss these references.
The scan respects `.gitignore` patterns to avoid touching generated or vendored files.

### Literal string replacement

**Decision**: use literal path string replacement, not AST-aware rewriting.

**Why**: cdocs references appear in markdown, YAML frontmatter, plain text, and potentially code comments.
There is no single AST that covers all these formats.
Literal string replacement is simple, predictable, and correct for path references: if the old path appears as a substring, it should be updated.
False positives are unlikely because cdocs paths are structured (`cdocs/$type/YYYY-MM-DD-name.md`) and distinctive.

## Edge Cases / Challenging Scenarios

### Document referenced by documents outside the project

The archive command only rewrites references within the project.
External references (other repos, wikis, bookmarks) will break.
The command should warn about this possibility in its output.

### Circular references during bulk archival

Archiving multiple documents in sequence could cause reference churn if document A references document B and both are being archived.
The command operates on one document at a time; bulk archival should be a separate higher-level operation that plans all moves before executing any rewrites.

### Filename collisions in `_archive/`

Two documents with the same filename but different dates cannot collide (filenames include dates).
If somehow a collision occurs (e.g., archiving a document, creating a new one with the same name, then archiving that too), the command should detect the collision and refuse to overwrite, prompting the user.

### Relative path resolution

A document at `cdocs/reviews/2026-01-29-review.md` might reference `../proposals/2026-01-29-proposal.md`.
After archival, the correct relative path becomes `../proposals/_archive/2026-01-29-proposal.md`.
The scanner must resolve relative paths against the referencing file's directory to correctly detect and rewrite these references.

### Symlinks

If a project uses symlinks pointing to cdocs documents, the archive move breaks the symlink target.
The archive command does not attempt to detect or update symlinks; this is documented as an unsupported edge case.
Projects using symlinks to cdocs paths should use path references (which are rewritten) rather than filesystem symlinks.

### Non-markdown files referencing cdocs paths

Shell scripts, JSON configs, and TypeScript files may contain cdocs paths (e.g., hooks, plugin manifests).
The literal string replacement approach handles these naturally since it operates on raw text, not parsed markdown.

### Bulk archival

Archiving many documents at once (e.g., end-of-sprint cleanup) is out of scope for this proposal.
A bulk archival command should plan all moves before executing any rewrites to avoid reference churn.
This is tracked as future work for the CDocs CLI.

## Test Plan

### Unit tests

- Path transformation: given an input path, produce the correct archive path.
- Frontmatter state update: parse YAML frontmatter, set `state: archived`, serialize without corruption.
- Reference detection: given file content and an old path, find all occurrences (absolute, relative, in links, in frontmatter).
- Reference rewriting: given occurrences, produce correct replacement strings.
- Collision detection: refuse to archive when target path already exists.

### Integration tests

- Archive a document in a temporary project, verify file moved and frontmatter updated.
- Create cross-references between documents, archive one, verify all references updated.
- Unarchive a document, verify reverse operation and `state: live` assignment.
- Archive a document with `state: deferred`, unarchive it, verify `state: live` (not `deferred`).
- Archive with relative path references, verify correct recalculation.

### Manual verification

- Archive a document in the cdocs repo itself, verify `git diff` shows clean path rewrites.

## Implementation Phases

> NOTE(claude-opus-4-5/cdocs/archive-formalism): Phase 1 is adoptable immediately. Phases 2-5 are blocked on the CDocs CLI RFP (`cdocs/proposals/2026-01-30-cdocs-cli.md`) being elaborated into a full proposal and its initial scaffolding being implemented.

### Phase 1: Directory convention (no CLI dependency)

- Update `plugins/cdocs/rules/frontmatter-spec.md` to document the `_archive/` convention and its relationship to `state: archived`.
- Document the manual archival procedure in the frontmatter spec or a new conventions document.
- `_archive/` directories are created lazily on first use, not eagerly scaffolded by `/cdocs:init`.

**Success criteria**: frontmatter spec documents the convention and manual procedure; first manual archival creates `_archive/` and correctly updates references.

### Phase 2: Archive command core

- Implement `cdocs-cli archive <path>` in the CDocs CLI.
- File move from `cdocs/$type/` to `cdocs/$type/_archive/`.
- Frontmatter `state` update to `archived`.
- Dry-run mode (`--dry-run`) that reports what would change without modifying files.

**Success criteria**: command moves a file and updates its frontmatter; dry-run mode produces correct output without side effects.

### Phase 3: Path reference rewriting

- Implement whole-project scanning for path references.
- Handle absolute paths, relative paths, markdown links, and frontmatter fields.
- Report all rewrites with file and line number.
- Respect `.gitignore` for scan exclusions.

**Success criteria**: archiving a document with cross-references produces a clean `git diff` with all paths updated.

### Phase 4: Unarchive and edge cases

- Implement `cdocs-cli unarchive <path>`.
- Collision detection and user prompting.
- Warning for potential external reference breakage.

**Success criteria**: round-trip archive/unarchive produces identical file state; collision detection prevents overwrites.

### Phase 5: Integration with existing skills

- Update `/cdocs:status` to distinguish active vs. archived documents (or delegate to `cdocs-cli status`).
- Consider whether `/cdocs:triage` should suggest archival for documents with `state: archived` still in the active directory.

**Success criteria**: status listing clearly separates active and archived documents.
