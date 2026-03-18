#!/usr/bin/env node
/**
 * postinstall.js — Copy cdocs skills and rules to project paths on npm install.
 *
 * This script runs after `npm install @weftwise/cdocs-opencode` and copies:
 * - skills/ -> .opencode/skills/cdocs/ (or .claude/skills/cdocs/)
 * - rules/ -> .claude/rules/
 *
 * Set CDOCS_SKIP_POSTINSTALL=1 to skip this step.
 *
 * The script uses the bundled copies within the npm package (__dirname-relative)
 * rather than parent directory traversal, so it works for both in-repo and
 * standalone npm installs.
 */

const { cpSync, mkdirSync, existsSync, readdirSync } = require("fs");
const { join, resolve } = require("path");

// Allow users to opt out
if (process.env.CDOCS_SKIP_POSTINSTALL === "1") {
  console.log("cdocs-opencode: postinstall skipped (CDOCS_SKIP_POSTINSTALL=1)");
  process.exit(0);
}

// Package root is one level up from scripts/
const PKG_ROOT = resolve(__dirname, "..");
const SKILLS_SRC = join(PKG_ROOT, "skills");
const RULES_SRC = join(PKG_ROOT, "rules");

// Project root is where npm install was run (INIT_CWD is set by npm)
const PROJECT_ROOT = process.env.INIT_CWD || process.cwd();

// Destination paths
const SKILLS_DEST_OC = join(PROJECT_ROOT, ".opencode", "skills", "cdocs");
const SKILLS_DEST_CC = join(PROJECT_ROOT, ".claude", "skills", "cdocs");
const RULES_DEST = join(PROJECT_ROOT, ".claude", "rules");

/**
 * Copy a directory if the source exists.
 * Creates the destination directory if needed.
 */
function copyIfExists(src, dest, label) {
  if (!existsSync(src)) {
    console.log(`cdocs-opencode: ${label} source not found, skipping: ${src}`);
    return false;
  }
  mkdirSync(dest, { recursive: true });
  cpSync(src, dest, { recursive: true });
  console.log(`cdocs-opencode: ${label} copied to ${dest}`);
  return true;
}

// Copy skills
// Prefer .opencode/skills/ if .opencode/ exists, otherwise use .claude/skills/
if (existsSync(join(PROJECT_ROOT, ".opencode"))) {
  copyIfExists(SKILLS_SRC, SKILLS_DEST_OC, "Skills");
} else {
  copyIfExists(SKILLS_SRC, SKILLS_DEST_CC, "Skills");
}

// Copy rules to .claude/rules/ (OC reads this path natively)
copyIfExists(RULES_SRC, RULES_DEST, "Rules");
