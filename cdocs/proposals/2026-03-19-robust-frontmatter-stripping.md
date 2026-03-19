---
first_authored:
  by: "@claude-opus-4-6"
  at: 2026-03-19T12:00:00-07:00
task_list: cdocs/plugin-hardening
type: proposal
state: live
status: wip
tags: [hooks, frontmatter, architecture, typescript]
---

# Robust Frontmatter Stripping for inject-rules Hook

> BLUF(opus/cdocs/plugin-hardening): Rewrite `inject-rules.sh` as `inject-rules.ts` (invoked via `tsx`) to fix the fragile awk-based frontmatter stripping that breaks on code blocks containing `---`.
> The fix uses positional string indexing (the same technique gray-matter uses internally) in a zero-dependency 8-line function.
> This also eliminates the `jq` dependency by using native `JSON.stringify`, reducing the hook's external requirements from `bash + awk + jq` to `node + tsx` (both already in the project).
> See [frontmatter-stripping-methods report](../reports/2026-03-19-frontmatter-stripping-methods.md) for the full research.

## Summary

The change is small in scope but touches a critical path: the `SessionStart` hook that injects plugin rules into every Claude Code session.
The core fix is an 8-line `stripFrontmatter()` function.
The rest of the proposal addresses the surrounding concerns: rewriting the shell script to TypeScript, maintaining the source-repo skip logic, and ensuring the hook stays within its 3-second timeout.

## Objective

Fix the FIXME in `plugins/cdocs/hooks/inject-rules.sh` where the awk pattern `/^---$/` incorrectly strips `---` lines inside fenced code blocks.
The immediate victim is `frontmatter-spec.md`, which contains YAML template examples with `---` delimiters inside code fences.

## Background

### The Current Hook

`inject-rules.sh` runs on every `SessionStart` event.
It reads `plugins/cdocs/rules/*.md`, strips YAML frontmatter from each, concatenates the bodies with section headers, and emits a JSON response with the content as `additionalContext`.

The hook has a 3-second timeout (`hooks.json`).
It depends on `bash`, `awk` (frontmatter stripping), and `jq` (JSON escaping).

### The Bug

The awk approach counts `---` lines:

```bash
awk 'BEGIN{fm=0} /^---$/{fm++; next} fm==0 || fm>=2{print}'
```

This increments `fm` on every `---` line in the file, including those inside fenced code blocks.
In `frontmatter-spec.md`, the YAML template example contains `---` delimiters inside a ` ```yaml ` code fence, causing the awk counter to overshoot and strip body content.

### The Insight

YAML frontmatter is always the first thing in a file.
The closing `---` is always the first `\n---` after the opener.
A positional search from byte 0 (using `indexOf`) finds the correct closing delimiter without scanning deeper into the document where code blocks live.
This is the same technique [gray-matter](https://github.com/jonschlinkert/gray-matter) uses internally.

### Existing Infrastructure

The project has `tsx` as a devDependency and uses it for `scripts/build-opencode.ts`.
The build script contains its own `parseFrontmatter()` regex, but it serves a different purpose (extracting frontmatter fields for agent conversion) and has the same fragility.

## Proposed Solution

Replace `inject-rules.sh` with `inject-rules.ts`, invoked via `tsx`.

### Core Stripping Function

```typescript
function stripFrontmatter(content: string): string {
  if (!content.startsWith('---')) return content;
  const closeIdx = content.indexOf('\n---', 3);
  if (closeIdx === -1) return content;
  const bodyStart = content.indexOf('\n', closeIdx + 4);
  if (bodyStart === -1) return '';
  return content.slice(bodyStart + 1);
}
```

The function:
1. Checks if the file starts with `---`. If not, returns unchanged (no frontmatter).
2. Finds the first `\n---` after position 3 (past the opening `---`).
3. Finds the newline after the closing `---` to skip past it.
4. Returns everything after that newline.

### Full Hook Structure

```typescript
#!/usr/bin/env -S npx tsx
import { readdirSync, readFileSync, existsSync } from 'fs';
import { join, basename } from 'path';

const RULES_DIR = join(process.env.CLAUDE_PLUGIN_ROOT!, 'rules');

// Skip injection in source repo (rules already loaded via CLAUDE.md @-imports)
const projectClaudeMd = join(process.cwd(), 'CLAUDE.md');
if (existsSync(projectClaudeMd)) {
  const claudeMd = readFileSync(projectClaudeMd, 'utf-8');
  if (claudeMd.includes('@plugins/cdocs/rules/')) {
    process.exit(0);
  }
}

function stripFrontmatter(content: string): string {
  if (!content.startsWith('---')) return content;
  const closeIdx = content.indexOf('\n---', 3);
  if (closeIdx === -1) return content;
  const bodyStart = content.indexOf('\n', closeIdx + 4);
  if (bodyStart === -1) return '';
  return content.slice(bodyStart + 1);
}

let context = '';

const files = readdirSync(RULES_DIR).filter(f => f.endsWith('.md'));
for (const file of files) {
  const filePath = join(RULES_DIR, file);
  const raw = readFileSync(filePath, 'utf-8');
  const body = stripFrontmatter(raw);
  const name = basename(file, '.md');
  context += `\n\n## [cdocs rule: ${name}]\n\n${body}\n`;
}

if (context) {
  const output = {
    hookSpecificOutput: {
      hookEventName: 'SessionStart',
      additionalContext: context,
    },
  };
  console.log(JSON.stringify(output));
}
```

### hooks.json Update

```json
{
  "type": "command",
  "command": "npx tsx ${CLAUDE_PLUGIN_ROOT}/hooks/inject-rules.ts",
  "timeout": 3
}
```

> NOTE(opus/cdocs/plugin-hardening): The shebang `#!/usr/bin/env -S npx tsx` works on Linux/macOS for direct execution.
> However, CC hooks use the `command` field, so the shebang is a convenience for manual testing only.
> The `hooks.json` command explicitly invokes via `npx tsx` for clarity and portability.

## Important Design Decisions

### TypeScript over improved bash

The awk/sed approaches are fundamentally line-oriented and cannot correctly handle the code-block edge case without tracking fenced-code-block state, which makes them unreadably complex.
TypeScript with `indexOf` is both correct and readable.
The project already depends on `tsx` for the build script, so no new dependency is introduced.

### Zero new dependencies

gray-matter is the standard library for frontmatter parsing (23M weekly npm downloads), but the hook only needs stripping, not parsing.
The 8-line `stripFrontmatter()` function replicates gray-matter's core technique without the dependency.
If the hook later needs to parse frontmatter fields, adding gray-matter becomes justified.

### Not sharing code with build-opencode.ts

The build script has its own `parseFrontmatter()` that returns both frontmatter fields and body.
Sharing a utility would couple the build and hook, which have different requirements.
The build script operates on agent files (no code blocks in frontmatter region); the hook operates on rules files (code blocks present).
The duplication is intentional and minimal (8 lines).

### Keeping the source-repo skip check

The `grep -q '@plugins/cdocs/rules/' CLAUDE.md` check prevents double-injection when developing in the source repo.
The TypeScript version uses `string.includes()` instead of grep, which is simpler and avoids a subprocess.

### Shebang line

Using `#!/usr/bin/env -S npx tsx` allows the script to be run directly for testing (`./inject-rules.ts`).
The `-S` flag splits the argument so `env` passes `npx tsx` as a program and argument.
This works on Linux and macOS but not on some older BSDs.
The `hooks.json` command field does not rely on the shebang.

## Edge Cases / Challenging Scenarios

### Files with no frontmatter

`workflow-patterns.md` and `writing-conventions.md` have no YAML frontmatter.
`stripFrontmatter()` returns the content unchanged because `content.startsWith('---')` is false.

### Files where frontmatter is the entire content

If a file contains only frontmatter with no body, `content.indexOf('\n', closeIdx + 4)` returns -1, and the function returns `''` (empty string).
The section header is still emitted, which is harmless.

### Frontmatter with trailing content on the closing `---` line

Some parsers allow `--- # end` as a closing delimiter.
The `indexOf('\n---', 3)` approach matches `\n---` at any position, so `\n--- # end` would not match.
This is correct for cdocs files, which always use bare `---`.

### `CLAUDE_PLUGIN_ROOT` not set

The existing shell script assumes `CLAUDE_PLUGIN_ROOT` is set by the CC hook runtime.
The TypeScript version uses `process.env.CLAUDE_PLUGIN_ROOT!` with a non-null assertion.
If the variable is missing, Node throws at `join(undefined, 'rules')`, which is a correct failure mode (the hook cannot function without knowing its plugin root).

### tsx not available

If `tsx` is not installed (e.g., `node_modules` missing), the hook fails and CC logs the error.
This is the same failure mode as the current script when `jq` is missing.
The `package.json` `devDependencies` includes `tsx`, so `npm install` in the repo root makes it available.

> WARN(opus/cdocs/plugin-hardening): For marketplace installs, `tsx` must be available in the user's PATH or the plugin must include it.
> The current CC plugin manifest does not declare runtime dependencies.
> This is an existing gap that affects the shell hook too (it requires `jq`).
> Consider filing a follow-up to address plugin dependency declaration.

### Performance under cold tsx startup

The tsx cold-start overhead is ~150-250ms.
Combined with reading 3 small files and JSON serialization, the total execution is ~200-300ms.
The 3-second timeout provides a 10x safety margin.

## Test Plan

### Unit verification of `stripFrontmatter()`

Test cases:

| Input | Expected output |
|-------|----------------|
| `---\nfoo: bar\n---\nBody content` | `Body content` |
| `No frontmatter here` | `No frontmatter here` |
| `---\nfoo: bar\n---\n` | `` (empty) |
| `---\nfoo: bar\n---\n\n## Heading\n\n` ` ` `yaml\n---\nkey: val\n---\n` ` ` `\n\nMore body` | Full body including the code block with `---` intact |
| `---\nfoo: bar\n` (no closing) | Full content unchanged |

### Integration verification

1. Run the new hook manually against the actual rules files:
   ```bash
   CLAUDE_PLUGIN_ROOT=plugins/cdocs npx tsx plugins/cdocs/hooks/inject-rules.ts
   ```
2. Verify the output JSON is valid and contains all three rules.
3. Verify `frontmatter-spec.md` body retains the `---` lines inside its code blocks.
4. Verify `workflow-patterns.md` (no frontmatter) passes through unchanged.
5. Verify the source-repo skip works (run from the clauthier repo root, expect no output).
6. Run from a directory without `CLAUDE.md` containing `@plugins/cdocs/rules/` to verify injection works.

### Timing verification

```bash
time CLAUDE_PLUGIN_ROOT=plugins/cdocs npx tsx plugins/cdocs/hooks/inject-rules.ts
```

Confirm total execution is under 1 second (well within the 3-second timeout).

## Verification Methodology

1. **Before**: Run the current `inject-rules.sh` and capture its output for `frontmatter-spec.md`.
   Note the missing `---` lines in the code block section.
2. **After**: Run the new `inject-rules.ts` and capture its output.
   Diff the two outputs, confirming the code-block `---` lines are now preserved.
3. **Regression**: Verify the other two rules files produce identical output between old and new implementations.
4. **Live test**: Install the plugin in a fresh CC session and verify rules appear in the system context via `/context` or by asking Claude to recite the rules.

## Implementation Phases

### Phase 1: Create `inject-rules.ts`

Write the TypeScript hook at `plugins/cdocs/hooks/inject-rules.ts`.
Port the logic from `inject-rules.sh`:
- Source-repo skip check (replace `grep` with `string.includes`).
- Rules directory iteration (replace `for ... in *.md` with `readdirSync` + `filter`).
- Frontmatter stripping (replace awk with `stripFrontmatter()`).
- JSON output (replace `jq -Rs` with `JSON.stringify`).

**Success criteria**: Running the script from a non-source-repo directory produces valid JSON with all rules and intact code-block `---` lines.

**Constraint**: Do not modify `build-opencode.ts` or its `parseFrontmatter()`. The two implementations serve different purposes.

### Phase 2: Update `hooks.json`

Change the SessionStart hook command from `${CLAUDE_PLUGIN_ROOT}/hooks/inject-rules.sh` to `npx tsx ${CLAUDE_PLUGIN_ROOT}/hooks/inject-rules.ts`.

**Success criteria**: CC loads the hook without errors on session start.

### Phase 3: Remove `inject-rules.sh`

Delete the old shell script.
The FIXME is resolved.

**Success criteria**: No references to `inject-rules.sh` remain in the codebase.

### Phase 4: Verify end-to-end

Run the integration and timing tests from the Test Plan section.
Confirm the frontmatter-spec code-block content is preserved.
Confirm timing is within budget.

**Success criteria**: All test cases pass, execution under 1 second.
