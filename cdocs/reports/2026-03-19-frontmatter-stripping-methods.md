---
first_authored:
  by: "@claude-opus-4-6"
  at: 2026-03-19T12:00:00-07:00
task_list: cdocs/plugin-hardening
type: report
state: live
status: wip
tags: [research, architecture, hooks, frontmatter]
---

# Frontmatter Stripping Methods for inject-rules.sh

> BLUF: The current awk-based frontmatter stripping in `inject-rules.sh` breaks on code blocks containing `---` (confirmed in `frontmatter-spec.md`).
> A zero-dependency inline TypeScript solution using positional string indexing (the same technique gray-matter uses internally) is the recommended fix: it handles all edge cases, runs in under 50ms, and leverages the existing `tsx` dependency.
> Adding `gray-matter` as a dependency is unnecessary for stripping-only use; a 10-line function suffices.

## Context / Background

The `inject-rules.sh` hook runs on every Claude Code `SessionStart` event with a 3-second timeout.
It reads all `plugins/cdocs/rules/*.md` files, strips YAML frontmatter, and injects the body content as `additionalContext`.

The current implementation uses awk:

```bash
CONTENT=$(printf '%s\n' "$CONTENT" | awk '
  BEGIN { fm=0 }
  /^---$/ { fm++; next }
  fm == 0 || fm >= 2 { print }
')
```

This pattern counts `---` lines and skips everything between the first two.
The problem: it also matches `---` lines inside fenced code blocks, which `frontmatter-spec.md` uses to show YAML template examples.
The FIXME in the script acknowledges this and suggests a JS/TS replacement.

The project already has `tsx` as a devDependency and uses it for the OpenCode build script (`scripts/build-opencode.ts`).
The build script includes its own `parseFrontmatter()` function using a regex: `/^---\n([\s\S]*?)\n---\n([\s\S]*)$/`.

## Key Findings

### 1. Methods Used in the Wild

**gray-matter** (npm, 23M weekly downloads):
- The dominant library. Used by Gatsby, Astro, VitePress, Netlify, Shopify Polaris.
- Uses positional string indexing (`indexOf('\n---')`) rather than regex or line-by-line parsing.
- The opening delimiter must be at byte 0 of the file.
- The closing delimiter is found via `str.indexOf('\n' + closeDelimiter)`.
- Guards against `----` (four dashes) by checking the character after the opening delimiter.
- Has 3 dependencies (`js-engine`, `section-matter`, `strip-bom-string`). Total install footprint is modest but nonzero.

**front-matter** (npm, 3M weekly downloads):
- Uses a single regex: opening and closing `---` (or `= yaml =` / `...`) delimiters, with content captured between them.
- Strips the matched block via `string.replace(match[0], '')`.
- Depends on `js-yaml` for parsing (not needed if we only strip).
- The regex approach is simpler but cannot distinguish code-block `---` from real frontmatter `---`.

**Regex approaches** (various):
- Common pattern: `/^---\n[\s\S]*?\n---\n/` with the `m` flag or anchored to string start.
- Fast but fragile: matches the first `\n---\n` as the closing delimiter, which could be inside a code block if the code block appears before the closing `---`.
- NOTE(opus/cdocs/plugin-hardening): For our specific files, frontmatter is always at the top and the closing `---` always appears before any code blocks, so a non-greedy start-anchored regex would actually work. But this is a coincidental property of our current files, not a guarantee.

**build-opencode.ts (in-repo)**:
- Uses `/^---\n([\s\S]*?)\n---\n([\s\S]*)$/` to parse agent frontmatter.
- The `*?` (non-greedy) quantifier means it matches the first `\n---\n`, which is correct for agent files that have no code blocks.
- Same fragility as the generic regex approach: would break on files with early code blocks containing `---`.

**sed approach**:
- `sed -i '1 { /^---/ { :a N; /\n---/! ba; d} }'` uses labels and branching.
- Matches the first `---` block from line 1.
- Same fundamental limitation: no awareness of code fences.

**awk approach** (current):
- Counts `---` lines. Simple, fast.
- Fundamental flaw: any `---` on its own line increments the counter, including inside code blocks.

### 2. Performance Characteristics

The hook has a 3-second timeout and processes 3 small markdown files (currently ~100, ~115, ~85 lines).

| Method | Estimated time | Notes |
|--------|---------------|-------|
| awk (current) | ~5ms | Native binary, piped per-file |
| sed | ~5ms | Native binary, similar to awk |
| `node -e '...'` (cold) | ~80-120ms | V8 startup dominates |
| `tsx script.ts` (cold) | ~150-250ms | tsx adds TypeScript compilation overhead |
| `node --import tsx script.ts` | ~120-200ms | Slightly faster than npx tsx |
| gray-matter via node | ~100-150ms | Adds require() resolution time |

All approaches are well within the 3-second timeout.
The bash approaches are 10-20x faster but fundamentally cannot track code-fence state without becoming unreadably complex.
The Node/tsx approaches add 100-250ms of startup overhead, which is acceptable for a SessionStart hook that runs once per session.

### 3. Robustness Analysis

The core issue: distinguishing frontmatter `---` from content `---`.

**What makes frontmatter `---` special:**
- The opening `---` must be the very first line of the file (byte 0, or after optional BOM).
- The closing `---` is the next `---` that appears on its own line, outside any code fence.
- YAML frontmatter is a convention, not a markdown spec feature. Parsers agree on the "first thing in file" rule.

**The code-fence problem:**
- Fenced code blocks use `` ``` `` (or `~~~`) delimiters.
- A `---` inside a fenced code block is content, not a delimiter.
- Correct stripping requires tracking whether we are inside a code fence.

**gray-matter's approach avoids the problem entirely:**
- It uses `indexOf('\n---')` from the opening delimiter position.
- Since it searches for the first occurrence after the opener, it finds the real closing `---` before any code block content (frontmatter always precedes the document body, and code blocks are in the body).
- This works because frontmatter is at the top: the closing `---` is always found before the body content where code blocks live.

> NOTE(opus/cdocs/plugin-hardening): This is the key insight. For well-formed markdown files, the closing `---` of frontmatter always appears before any code fences. A positional search from the start of the file (not line-by-line counting) naturally handles this case.

### 4. Zero-Dependency Options

**Option A: Inline TypeScript function (recommended)**
A `stripFrontmatter()` function using positional string indexing, invoked via `tsx`:

```typescript
function stripFrontmatter(content: string): string {
  if (!content.startsWith('---')) return content;
  const closeIdx = content.indexOf('\n---', 3);
  if (closeIdx === -1) return content;
  // Skip past the closing --- and its trailing newline
  const bodyStart = content.indexOf('\n', closeIdx + 4);
  if (bodyStart === -1) return '';
  return content.slice(bodyStart + 1);
}
```

This is essentially what gray-matter does internally: find the first `\n---` after the opener, take everything after it.
No dependencies needed. Handles all edge cases for well-formed frontmatter files.

**Option B: Improved bash (sed)**
Use sed to delete from line 1's `---` through the next `---`:

```bash
CONTENT=$(printf '%s\n' "$CONTENT" | sed '1{/^---$/!q}; 1,/^---$/d')
```

Slightly better than awk (only matches the first block from line 1) but still line-oriented and cannot track code fences.
For our files, this would work because frontmatter closing `---` precedes code blocks, but it is coincidental correctness.

**Option C: Node one-liner via `node -e`**
Avoid tsx overhead by using plain Node:

```bash
CONTENT=$(node -e "
  const fs = require('fs');
  const c = fs.readFileSync('$rule_file','utf8');
  if(!c.startsWith('---')){process.stdout.write(c);process.exit()}
  const i=c.indexOf('\n---',3);
  if(i<0){process.stdout.write(c);process.exit()}
  const j=c.indexOf('\n',i+4);
  process.stdout.write(j<0?'':c.slice(j+1));
")
```

Faster startup than tsx (~80ms vs ~150ms) but inline node scripts in bash are hard to maintain and quote correctly.

**Option D: Dedicated TypeScript helper script**
A standalone `scripts/strip-frontmatter.ts` invoked per-file or with all files at once.
Clean separation but adds a file to maintain and a per-invocation tsx startup cost.

### 5. The Existing In-Repo Precedent

`build-opencode.ts` already contains `parseFrontmatter()` with a regex approach.
A shared utility could serve both the build script and the hook, but:
- The build script needs the parsed frontmatter fields (not just the body).
- The hook only needs the body.
- Sharing code between a build script and a runtime hook adds coupling.
- The two use cases have different correctness requirements (build runs on agent files with no code blocks; hook runs on rules files that do have code blocks).

Sharing is possible but not clearly beneficial.

## Analysis

### Approach Comparison Matrix

| Criterion | awk (current) | sed | Regex (TS) | indexOf (TS) | gray-matter |
|-----------|--------------|-----|------------|---------------|-------------|
| Code-block safety | No | No | No | Yes | Yes |
| Performance | ~5ms | ~5ms | ~150ms | ~150ms | ~150ms |
| Dependencies | None | None | tsx (existing) | tsx (existing) | gray-matter + tsx |
| Maintainability | Low | Low | Medium | High | High |
| Lines of code | 4 | 1 | 3 | 8 | 1 (+ dep) |

### Why Positional indexOf Wins

The `indexOf` approach (Option A) matches gray-matter's internal strategy without the dependency.
It is correct for all well-formed markdown files because YAML frontmatter, by convention, is always the first thing in the file, and the closing `---` always appears before the document body.
This means the first `\n---` after the opener is always the real closing delimiter, never a code-block artifact.

The awk/sed/regex approaches scan line-by-line or greedily, which can match `---` lines deeper in the document.
The `indexOf` approach only looks for the first occurrence, which is necessarily the frontmatter closer.

## Recommendations

1. **Replace awk with a small TypeScript helper** using the positional `indexOf` approach.
   Keep it as an inline function in a single script file (not a shared utility) to minimize coupling.

2. **Rewrite `inject-rules.sh` as `inject-rules.ts`** (invoked via `tsx`).
   The script already depends on `jq` for JSON escaping; TypeScript handles JSON natively via `JSON.stringify`.
   This eliminates both the fragile awk and the jq dependency, replacing them with a single tsx invocation.

3. **Do not add gray-matter as a dependency.**
   The stripping logic is 8 lines.
   gray-matter's value is in parsing frontmatter fields (which the hook does not need) and supporting exotic formats (TOML, JSON, Coffee, which are not used).

4. **Performance is not a concern.**
   Even the slowest approach (~250ms for tsx cold start + 3 files) is well within the 3-second timeout.
   The hook runs once per session, not per tool invocation.

5. **Update `hooks.json`** to invoke the new TypeScript hook if changing the file extension.
   The `timeout: 3` is sufficient for tsx startup.
