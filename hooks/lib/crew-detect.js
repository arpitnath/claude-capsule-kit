/**
 * Crew Detection Utilities for Capsule Hooks
 *
 * Detects whether hooks are running inside a Claude Crew worktree
 * and resolves the correct shared capsule.db path.
 *
 * KEY CHALLENGE: When Agent Teams spawns teammates via the Task tool,
 * child processes inherit the PARENT's CWD (main project root).
 * Teammates use absolute paths to operate in their worktrees, but
 * process.cwd() returns the main project path. So we can't rely
 * on CWD to find crew-identity.json — we need alternate strategies:
 *
 * 1. CREW_WORKTREE_PATH env var (if set by spawn infrastructure)
 * 2. Worktree registry scan + file path matching from tool_input
 * 3. Direct CWD lookup (only works if CWD = worktree)
 *
 * Outside crew: everything resolves to ./.claude/capsule.db as normal.
 */

import { resolve, dirname } from 'path';
import { existsSync, readFileSync, lstatSync, readlinkSync } from 'fs';
import { createHash } from 'crypto';
import { execSync } from 'child_process';
import { homedir } from 'os';

/**
 * Resolve the path to the canonical capsule.db.
 *
 * Strategy (in priority order):
 * 1. CWD crew-identity.json → use its project_root/.claude/capsule.db
 * 2. CREW_WORKTREE_PATH env → worktree's crew-identity.json → project_root
 * 3. Worktree registry scan → any crew-identity.json → project_root
 * 4. .claude/hooks symlink → follow to main project
 * 5. Default → ./.claude/capsule.db
 */
export function getCapsuleDbPath() {
  // Strategy 0: Global installation path (highest priority for global CCK)
  const globalDbPath = resolve(homedir(), '.claude', 'capsule.db');
  if (existsSync(globalDbPath)) return globalDbPath;

  const cwdClaudeDir = resolve(process.cwd(), '.claude');

  // Strategy 1: Direct CWD lookup
  try {
    const identityFile = resolve(cwdClaudeDir, 'crew-identity.json');
    if (existsSync(identityFile)) {
      const identity = JSON.parse(readFileSync(identityFile, 'utf-8'));
      if (identity.project_root) {
        return resolve(identity.project_root, '.claude', 'capsule.db');
      }
    }
  } catch { /* fall through */ }

  // Strategy 2: Environment variable
  const envWorktree = process.env.CREW_WORKTREE_PATH;
  if (envWorktree) {
    try {
      const envIdentity = resolve(envWorktree, '.claude', 'crew-identity.json');
      if (existsSync(envIdentity)) {
        const identity = JSON.parse(readFileSync(envIdentity, 'utf-8'));
        if (identity.project_root) {
          return resolve(identity.project_root, '.claude', 'capsule.db');
        }
      }
    } catch { /* fall through */ }
  }

  // Strategy 3: Worktree registry — any identity gives us project_root
  try {
    const registryPath = resolve(cwdClaudeDir, 'crew', 'worktrees.json');
    if (existsSync(registryPath)) {
      const registry = JSON.parse(readFileSync(registryPath, 'utf-8'));
      const worktrees = registry.worktrees || [];
      for (const wt of worktrees) {
        const wtIdentity = resolve(wt.path, '.claude', 'crew-identity.json');
        try {
          if (existsSync(wtIdentity)) {
            const identity = JSON.parse(readFileSync(wtIdentity, 'utf-8'));
            if (identity.project_root) {
              return resolve(identity.project_root, '.claude', 'capsule.db');
            }
          }
        } catch { /* skip this worktree */ }
      }
    }
  } catch { /* no registry */ }

  // Strategy 4: Follow .claude/hooks symlink
  try {
    const hooksDir = resolve(cwdClaudeDir, 'hooks');
    const stats = lstatSync(hooksDir);
    if (stats.isSymbolicLink()) {
      const realHooksDir = readlinkSync(hooksDir);
      const parent = dirname(realHooksDir);
      if (parent.endsWith('.claude')) {
        return resolve(parent, 'capsule.db');
      }
      return resolve(parent, '.claude', 'capsule.db');
    }
  } catch { /* not a symlink */ }

  // Strategy 5: Default local path
  return resolve(cwdClaudeDir, 'capsule.db');
}

/**
 * Detect crew identity for the current teammate.
 *
 * Since teammates inherit the main project's CWD (not their worktree),
 * we use multiple strategies to find the right crew-identity.json:
 *
 * 1. Direct CWD lookup (works if CWD = worktree)
 * 2. CREW_WORKTREE_PATH env var
 * 3. Worktree registry + file path hint matching (for PostToolUse)
 * 4. Worktree registry + single-worktree fallback (for SessionStart/End)
 *
 * @param {object} [hints] - Optional hints for disambiguation
 * @param {string} [hints.filePath] - File path from tool_input to match against worktrees
 * @returns {{ teammate_name: string, project_root: string, branch: string } | null}
 */
export function getCrewIdentity(hints = {}) {
  // Strategy 1: Direct CWD lookup (original approach — works if CWD = worktree)
  const cwdIdentity = resolve(process.cwd(), '.claude', 'crew-identity.json');
  try {
    if (existsSync(cwdIdentity)) {
      return JSON.parse(readFileSync(cwdIdentity, 'utf-8'));
    }
  } catch { /* fall through */ }

  // Strategy 2: Environment variable override
  const envWorktree = process.env.CREW_WORKTREE_PATH;
  if (envWorktree) {
    try {
      const envIdentityFile = resolve(envWorktree, '.claude', 'crew-identity.json');
      if (existsSync(envIdentityFile)) {
        return JSON.parse(readFileSync(envIdentityFile, 'utf-8'));
      }
    } catch { /* fall through */ }
  }

  // Strategy 3 & 4: Worktree registry scan
  const registryPath = resolve(process.cwd(), '.claude', 'crew', 'worktrees.json');
  try {
    if (!existsSync(registryPath)) return null;

    const registry = JSON.parse(readFileSync(registryPath, 'utf-8'));
    const worktrees = registry.worktrees || [];
    if (worktrees.length === 0) return null;

    // Strategy 3a: Match file path hint against worktree paths
    if (hints.filePath) {
      for (const wt of worktrees) {
        if (hints.filePath.startsWith(wt.path)) {
          const wtIdentity = resolve(wt.path, '.claude', 'crew-identity.json');
          try {
            if (existsSync(wtIdentity)) {
              return JSON.parse(readFileSync(wtIdentity, 'utf-8'));
            }
          } catch { /* skip */ }
        }
      }
    }

    // Strategy 3b: Single worktree fallback (unambiguous)
    if (worktrees.length === 1) {
      const wtIdentity = resolve(worktrees[0].path, '.claude', 'crew-identity.json');
      try {
        if (existsSync(wtIdentity)) {
          return JSON.parse(readFileSync(wtIdentity, 'utf-8'));
        }
      } catch { /* fall through */ }
    }

    // Multiple worktrees + no file path hint = can't disambiguate
  } catch { /* no registry or parse error */ }

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
export function crewNamespace(base, crewId, projectHash = null) {
  const projPrefix = projectHash ? `proj/${projectHash}/` : '';
  return crewId ? `${projPrefix}crew/${crewId.teammate_name}/${base}` : `${projPrefix}${base}`;
}

export function getProjectHash() {
  let identifier;
  try {
    identifier = execSync('git remote get-url origin', { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
  } catch {
    identifier = process.cwd();
  }
  return createHash('sha256').update(identifier).digest('hex').slice(0, 12);
}

export function isDisabled() {
  let dir = process.cwd();
  while (dir !== '/') {
    if (existsSync(resolve(dir, '.cck-disable'))) return true;
    dir = dirname(dir);
  }
  return false;
}
