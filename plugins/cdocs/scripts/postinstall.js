#!/usr/bin/env node
/**
 * postinstall.js -- Copy cdocs skills and rules to .opencode/ on npm install.
 *
 * This script runs after `npm install @weftwise/cdocs-opencode` and copies:
 * - skills/ -> .opencode/skills/<name>/  (flat, no cdocs/ nesting)
 * - rules/ -> .opencode/rules/cdocs/     (namespaced under cdocs/)
 *
 * IMPORTANT: This script ONLY writes to .opencode/ directories.
 * It NEVER creates or modifies anything under .claude/.
 * CC artifact delivery is handled by the CC plugin system (SessionStart hook,
 * /cdocs:init), not by this OC-specific npm package.
 *
 * Set CDOCS_SKIP_POSTINSTALL=1 to skip this step.
 */

const { cpSync, mkdirSync, existsSync, readdirSync } = require("fs");
const { join, resolve } = require("path");

// Allow users to opt out
if (process.env.CDOCS_SKIP_POSTINSTALL === "1") {
  console.log("cdocs-opencode: postinstall skipped (CDOCS_SKIP_POSTINSTALL=1)");
  process.exit(0);
}

// Source-repo guard: skip when running inside the plugin source repo.
// The source repo has plugins/cdocs/.claude-plugin/plugin.json as a marker.
const PROJECT_ROOT = process.env.INIT_CWD || process.cwd();
const SOURCE_REPO_MARKER = join(PROJECT_ROOT, "plugins", "cdocs", ".claude-plugin", "plugin.json");
if (existsSync(SOURCE_REPO_MARKER)) {
  console.log("cdocs-opencode: source repo detected, skipping postinstall");
  process.exit(0);
}

// Package root is one level up from scripts/
const PKG_ROOT = resolve(__dirname, "..");
const SKILLS_SRC = join(PKG_ROOT, "skills");
const RULES_SRC = join(PKG_ROOT, "rules");

// Destination paths -- ONLY .opencode/, NEVER .claude/
const SKILLS_DEST = join(PROJECT_ROOT, ".opencode", "skills");
const RULES_DEST = join(PROJECT_ROOT, ".opencode", "rules", "cdocs");

/**
 * Copy skill directories to flat .opencode/skills/<name>/ paths.
 * OC discovers skills at .opencode/skills/<name>/SKILL.md (one level).
 * No cdocs/ namespace prefix -- skills are flat in the .opencode/skills/ directory.
 */
function copySkillsFlat(src, dest) {
  if (!existsSync(src)) {
    console.log("cdocs-opencode: skills source not found, skipping");
    return;
  }
  const skills = readdirSync(src, { withFileTypes: true }).filter(d => d.isDirectory());
  for (const skill of skills) {
    const skillSrc = join(src, skill.name);
    const skillDest = join(dest, skill.name);
    mkdirSync(skillDest, { recursive: true });
    cpSync(skillSrc, skillDest, { recursive: true });
  }
  console.log(`cdocs-opencode: ${skills.length} skills copied to ${dest}`);
}

/**
 * Copy rules to .opencode/rules/cdocs/ (namespaced to avoid collisions).
 */
function copyRules(src, dest) {
  if (!existsSync(src)) {
    console.log("cdocs-opencode: rules source not found, skipping");
    return;
  }
  mkdirSync(dest, { recursive: true });
  cpSync(src, dest, { recursive: true });
  console.log(`cdocs-opencode: rules copied to ${dest}`);
}

// Ensure .opencode/ exists
mkdirSync(join(PROJECT_ROOT, ".opencode"), { recursive: true });

copySkillsFlat(SKILLS_SRC, SKILLS_DEST);
copyRules(RULES_SRC, RULES_DEST);
