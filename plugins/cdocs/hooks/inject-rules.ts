#!/usr/bin/env -S npx tsx
// SessionStart freshness-check hook for cdocs.
//
// Compares the plugin's rule-content sha256 hash (computed over the
// alphabetically-sorted, concatenated raw bodies of CLAUDE_PLUGIN_ROOT/rules/*.md)
// against the hash embedded in the project's .claude/rules/cdocs.md marker.
// Hash-based rather than version-based: empirical Q3 patch-bump test (see
// cdocs/devlogs/2026-05-12-rule-delivery-materialization-implementation.md)
// showed version-only comparison fires the directive on content-unchanged
// version bumps, which is noisy.
//
// Behavior summary:
// - Source-repo skip: if CLAUDE.md @-imports plugins/cdocs/rules/, exit silently.
// - File-missing: if .claude/rules/cdocs.md does not exist, exit silently.
// - Plugin manifest unreadable or rules dir unreadable: exit silently.
// - Marker absent/malformed: treat as stale; emit directive with hash="unknown".
// - Hashes match (opaque string compare): exit silently.
// - Hashes differ: emit directive (< 500 bytes).
import { createHash } from 'crypto';
import { readdirSync, readFileSync, existsSync } from 'fs';
import { join } from 'path';

function silentExit(): never {
  process.exit(0);
}

const pluginRoot = process.env.CLAUDE_PLUGIN_ROOT;
if (!pluginRoot) silentExit();

// Source-repo skip: rules already loaded via CLAUDE.md @-imports.
const projectClaudeMd = join(process.cwd(), 'CLAUDE.md');
if (existsSync(projectClaudeMd)) {
  try {
    const claudeMd = readFileSync(projectClaudeMd, 'utf-8');
    if (claudeMd.includes('@plugins/cdocs/rules/')) silentExit();
  } catch {
    // fall through; treat as non-source-repo
  }
}

// Project marker file: silently skip if absent (cdocs not initialized here).
const ruleFile = join(process.cwd(), '.claude', 'rules', 'cdocs.md');
if (!existsSync(ruleFile)) silentExit();

// Read plugin version (used only in the directive text, not for comparison).
let pluginVersion: string;
try {
  const pluginManifest = readFileSync(
    join(pluginRoot, '.claude-plugin', 'plugin.json'),
    'utf-8'
  );
  const parsed = JSON.parse(pluginManifest);
  if (typeof parsed.version !== 'string' || !parsed.version) silentExit();
  pluginVersion = parsed.version;
} catch {
  silentExit();
}

// Compute current plugin rule-content hash: sha256 over the alphabetically
// sorted, concatenated raw bodies of <pluginRoot>/rules/*.md.
let pluginHash: string;
try {
  const rulesDir = join(pluginRoot, 'rules');
  const files = readdirSync(rulesDir)
    .filter((f) => f.endsWith('.md'))
    .sort();
  const hash = createHash('sha256');
  for (const f of files) {
    hash.update(readFileSync(join(rulesDir, f)));
  }
  pluginHash = hash.digest('hex');
} catch {
  silentExit();
}

// Extract marker hash from project rule file.
// Canonical marker shape:
//   <!-- cdocs rules vX.Y.Z hash=<sha256> - regenerate with /cdocs:init (use version from plugin.json) -->
// Opaque-string compare: any deviation (missing comment, missing hash,
// non-hex hash) is treated as stale.
let markerHash: string | null = null;
try {
  const ruleContent = readFileSync(ruleFile, 'utf-8');
  const match = ruleContent.match(
    /<!--\s*cdocs rules v[^\s]+\s+hash=([a-f0-9]+)\s*-\s*regenerate with \/cdocs:init/
  );
  if (match) markerHash = match[1];
} catch {
  // Treat unreadable rule file as marker-absent.
}

if (markerHash !== null && markerHash === pluginHash) {
  silentExit();
}

const staleLabel = markerHash ?? 'unknown';
const stalePrefix = staleLabel === 'unknown' ? 'unknown' : staleLabel.slice(0, 8);
const freshPrefix = pluginHash.slice(0, 8);

const directive =
  `Your project's cdocs rules at .claude/rules/cdocs.md are content-hash ${stalePrefix}, ` +
  `but the cdocs plugin (v${pluginVersion}) ships content-hash ${freshPrefix}. ` +
  `Run \`/cdocs:init\` now to refresh the materialized rules, then Read the ` +
  `rewritten .claude/rules/cdocs.md to update your working context for this ` +
  `session. The current session's @-imported rules are stale until you do.`;

const output = {
  hookSpecificOutput: {
    hookEventName: 'SessionStart',
    additionalContext: directive,
  },
};
console.log(JSON.stringify(output));
