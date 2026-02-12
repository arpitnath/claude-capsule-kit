/**
 * Crew Detection Utilities for Blink Hooks
 *
 * Detects whether hooks are running inside a Claude Crew worktree
 * and resolves the correct shared blink.db path.
 *
 * In a crew worktree:
 *   .claude/hooks → symlink → main-project/.claude/hooks (SHARED)
 *   .claude/crew-identity.json → local file (ISOLATED)
 *   blink.db → should point to main-project/.claude/blink.db (SHARED)
 *
 * Outside crew: everything resolves to ./.claude/blink.db as normal.
 */

import { resolve, dirname } from 'path';
import { existsSync, readFileSync, lstatSync, readlinkSync } from 'fs';

/**
 * Resolve the path to the canonical blink.db.
 *
 * Strategy (in priority order):
 * 1. If crew-identity.json exists → use its project_root/.claude/blink.db
 * 2. If .claude/hooks is a symlink → follow it to find the main .claude/
 * 3. Default → ./.claude/blink.db
 *
 * In a normal (non-crew) session, returns ./.claude/blink.db.
 */
export function getBlinkDbPath() {
  const cwdClaudeDir = resolve(process.cwd(), '.claude');

  // Strategy 1: Use crew-identity.json (most reliable)
  try {
    const identityFile = resolve(cwdClaudeDir, 'crew-identity.json');
    if (existsSync(identityFile)) {
      const identity = JSON.parse(readFileSync(identityFile, 'utf-8'));
      if (identity.project_root) {
        return resolve(identity.project_root, '.claude', 'blink.db');
      }
    }
  } catch {
    // Fall through to symlink detection
  }

  // Strategy 2: Follow .claude/hooks symlink
  try {
    const hooksDir = resolve(cwdClaudeDir, 'hooks');
    const stats = lstatSync(hooksDir);
    if (stats.isSymbolicLink()) {
      const realHooksDir = readlinkSync(hooksDir);
      // Symlink could point to:
      //   /project/.claude/hooks  → dirname gives /project/.claude
      //   /project/hooks          → dirname gives /project
      // We need to find the .claude/ dir in either case
      const parent = dirname(realHooksDir);
      if (parent.endsWith('.claude')) {
        return resolve(parent, 'blink.db');
      }
      // Parent is the project root itself
      return resolve(parent, '.claude', 'blink.db');
    }
  } catch {
    // Not a symlink or doesn't exist
  }

  // Strategy 3: Default local path
  return resolve(cwdClaudeDir, 'blink.db');
}

/**
 * Detect crew identity from the worktree's crew-identity.json.
 *
 * This file is written by worktree-manager.sh during `crew setup`.
 * It's LOCAL to each worktree (not symlinked), so each teammate
 * gets their own identity.
 *
 * @returns {{ teammate_name: string, project_root: string, branch: string } | null}
 */
export function getCrewIdentity() {
  const identityFile = resolve(process.cwd(), '.claude', 'crew-identity.json');
  try {
    if (existsSync(identityFile)) {
      return JSON.parse(readFileSync(identityFile, 'utf-8'));
    }
  } catch {
    // Corrupted or unreadable — not in crew mode
  }
  return null;
}

/**
 * Build a namespace path, optionally scoped to a crew teammate.
 *
 * Normal:  crewNamespace('session/abc/files', null) → 'session/abc/files'
 * Crew:    crewNamespace('session/abc/files', id)   → 'crew/backend-dev/session/abc/files'
 *
 * @param {string} base - Base namespace path
 * @param {{ teammate_name: string } | null} crewId - Crew identity or null
 * @returns {string}
 */
export function crewNamespace(base, crewId) {
  return crewId ? `crew/${crewId.teammate_name}/${base}` : base;
}
