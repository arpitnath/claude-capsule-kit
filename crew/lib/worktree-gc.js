/**
 * Worktree Garbage Collection - Find and cleanup orphaned worktrees
 *
 * Prevents worktree accumulation from abandoned crew sessions by:
 * - Scanning all worktree registries for stale/stopped sessions
 * - Checking if worktree directories still exist
 * - Optionally removing orphaned worktrees and their branches
 */

import { existsSync, readdirSync, statSync, readFileSync } from 'fs';
import { resolve, join } from 'path';
import { homedir } from 'os';
import { execSync } from 'child_process';

/**
 * Find orphaned worktrees across all projects.
 *
 * A worktree is considered orphaned if:
 * - Directory doesn't exist anymore (manual deletion)
 * - Team state is 'stopped'
 * - Teammate is stale (last_active beyond threshold)
 *
 * @param {string} [claudeDir] - Path to ~/.claude directory (for testing)
 * @param {number} [staleAfterHours=4] - Hours before a worktree is considered stale
 * @returns {Array} List of orphan objects with metadata
 */
export function findOrphans(claudeDir = null, staleAfterHours = 4) {
  const crewDir = claudeDir ? join(claudeDir, 'crew') : resolve(homedir(), '.claude', 'crew');

  if (!existsSync(crewDir)) {
    return [];
  }

  const orphans = [];
  const staleThresholdMs = staleAfterHours * 3600000;

  // Scan all project hashes
  const projectHashes = readdirSync(crewDir, { withFileTypes: true })
    .filter(d => d.isDirectory())
    .map(d => d.name);

  for (const projectHash of projectHashes) {
    const projectDir = join(crewDir, projectHash);
    const worktreesPath = join(projectDir, 'worktrees.json');

    // Skip if no worktree registry
    if (!existsSync(worktreesPath)) {
      continue;
    }

    let registry;
    try {
      registry = JSON.parse(readFileSync(worktreesPath, 'utf-8'));
    } catch {
      continue;
    }

    if (!registry.worktrees || !Array.isArray(registry.worktrees)) {
      continue;
    }

    // Load all team states for this project (all profiles)
    const teamStates = loadAllTeamStates(projectDir);

    // Check each registered worktree
    for (const worktree of registry.worktrees) {
      const { name, branch, path } = worktree;

      // Check if directory exists
      const dirExists = existsSync(path);

      // Check team state
      const teammateState = findTeammateInStates(teamStates, name);
      const isTeamStopped = teammateState ? teammateState.teamStatus === 'stopped' : false;
      const isTeammateStopped = teammateState ? teammateState.status === 'stopped' : false;

      // Check staleness
      let lastActiveDate = null;
      let ageDays = null;
      let isStale = false;

      if (teammateState && teammateState.last_active) {
        lastActiveDate = new Date(teammateState.last_active);
        const ageMs = Date.now() - lastActiveDate.getTime();
        ageDays = Math.round(ageMs / 86400000);
        isStale = ageMs > staleThresholdMs;
      } else if (teammateState && teammateState.teamUpdatedAt) {
        // Fall back to team updated_at if no last_active
        lastActiveDate = new Date(teammateState.teamUpdatedAt);
        const ageMs = Date.now() - lastActiveDate.getTime();
        ageDays = Math.round(ageMs / 86400000);
        isStale = ageMs > staleThresholdMs;
      }

      // Determine if this is an orphan
      let reason = null;
      if (!dirExists) {
        reason = 'directory-missing';
      } else if (isTeamStopped) {
        reason = 'team-stopped';
      } else if (isTeammateStopped) {
        reason = 'teammate-stopped';
      } else if (isStale && lastActiveDate) {
        reason = 'stale';
      }

      if (reason) {
        const orphan = {
          projectHash,
          name,
          branch,
          path,
          reason,
          exists: dirExists,
          ageDays: ageDays || 'unknown',
          lastActive: lastActiveDate ? lastActiveDate.toISOString() : null,
          profile: teammateState?.profileName || 'unknown',
          diskSize: null
        };

        // Try to get disk size if directory exists
        if (dirExists) {
          try {
            const sizeBytes = getDirSize(path);
            orphan.diskSize = formatBytes(sizeBytes);
          } catch {
            // Ignore errors
          }
        }

        orphans.push(orphan);
      }
    }
  }

  return orphans;
}

/**
 * Load all team states for a project (across all profiles).
 * @param {string} projectDir - Path to ~/.claude/crew/{projectHash}
 * @returns {Array} Array of team state objects with profile names
 */
function loadAllTeamStates(projectDir) {
  const states = [];

  try {
    const profiles = readdirSync(projectDir, { withFileTypes: true })
      .filter(d => d.isDirectory())
      .map(d => d.name);

    for (const profile of profiles) {
      const statePath = join(projectDir, profile, 'team-state.json');
      if (!existsSync(statePath)) continue;

      try {
        const state = JSON.parse(readFileSync(statePath, 'utf-8'));
        states.push({ ...state, _profileName: profile });
      } catch {
        // Skip malformed states
      }
    }
  } catch {
    // Directory doesn't exist or can't be read
  }

  return states;
}

/**
 * Find a teammate across all team states.
 * @param {Array} teamStates - Array of team state objects
 * @param {string} name - Teammate name to find
 * @returns {object|null} Teammate state with additional context
 */
function findTeammateInStates(teamStates, name) {
  for (const state of teamStates) {
    if (state.teammates && state.teammates[name]) {
      return {
        ...state.teammates[name],
        teamStatus: state.status,
        teamUpdatedAt: state.updated_at,
        profileName: state._profileName
      };
    }
  }
  return null;
}

/**
 * Calculate directory size recursively (synchronous).
 * @param {string} dirPath - Directory path
 * @returns {number} Size in bytes
 */
function getDirSize(dirPath) {
  let totalSize = 0;

  function walk(path) {
    try {
      const stats = statSync(path);
      if (stats.isDirectory()) {
        const entries = readdirSync(path, { withFileTypes: true });
        for (const entry of entries) {
          walk(join(path, entry.name));
        }
      } else {
        totalSize += stats.size;
      }
    } catch {
      // Skip files we can't read
    }
  }

  walk(dirPath);
  return totalSize;
}

/**
 * Format bytes into human-readable string.
 * @param {number} bytes - Size in bytes
 * @returns {string} Formatted string (e.g., "1.2 MB")
 */
function formatBytes(bytes) {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

/**
 * Clean up orphaned worktrees.
 *
 * @param {Array} orphans - List of orphan objects from findOrphans()
 * @param {object} options - Cleanup options
 * @param {boolean} [options.deleteBranches=false] - Also delete git branches
 * @param {boolean} [options.force=false] - Skip confirmation prompts
 * @param {string} [options.projectRoot=null] - Project root for git commands (auto-detect if null)
 * @returns {object} Results: { removed: number, failed: Array, branchesDeleted: number }
 */
export function cleanup(orphans, options = {}) {
  const { deleteBranches = false, force = false, projectRoot = null } = options;
  const results = {
    removed: 0,
    failed: [],
    branchesDeleted: 0
  };

  // Group orphans by project root for git operations
  const byProject = {};
  for (const orphan of orphans) {
    if (!orphan.exists) {
      // Directory already gone, just skip (will clean up registry separately)
      results.removed++;
      continue;
    }

    // Try to find project root from worktree path
    // Convention: worktree path is {project-root}-{branch-sanitized}
    // We need to reverse this to find the project root
    const root = projectRoot || inferProjectRoot(orphan.path, orphan.branch);

    if (!root) {
      results.failed.push({
        ...orphan,
        error: 'Could not determine project root'
      });
      continue;
    }

    if (!byProject[root]) {
      byProject[root] = [];
    }
    byProject[root].push(orphan);
  }

  // Remove worktrees project by project
  for (const [root, projectOrphans] of Object.entries(byProject)) {
    for (const orphan of projectOrphans) {
      try {
        // Use git worktree remove
        execSync(`git worktree remove "${orphan.path}" --force`, {
          cwd: root,
          stdio: 'pipe'
        });
        results.removed++;

        // Delete branch if requested
        if (deleteBranches) {
          try {
            execSync(`git branch -D "${orphan.branch}"`, {
              cwd: root,
              stdio: 'pipe'
            });
            results.branchesDeleted++;
          } catch (err) {
            // Branch might not exist or already deleted, don't fail the whole operation
          }
        }
      } catch (err) {
        results.failed.push({
          ...orphan,
          error: err.message
        });
      }
    }
  }

  return results;
}

/**
 * Infer project root from worktree path and branch.
 * Convention: {project-root}-{sanitized-branch}
 * @param {string} worktreePath - Full worktree path
 * @param {string} branch - Branch name
 * @returns {string|null} Project root path or null
 */
function inferProjectRoot(worktreePath, branch) {
  // Sanitize branch name the same way worktree-manager.sh does
  const sanitizedBranch = branch.replace(/\//g, '--').replace(/[^a-zA-Z0-9._-]/g, '_');

  // Remove the branch suffix from the worktree path
  const suffix = `-${sanitizedBranch}`;
  if (worktreePath.endsWith(suffix)) {
    return worktreePath.slice(0, -suffix.length);
  }

  // Fallback: try to find .git directory by walking up
  let current = worktreePath;
  const parts = current.split('/');

  // Remove last part (the worktree dir name) and try parent directories
  for (let i = parts.length - 1; i >= 0; i--) {
    const candidate = parts.slice(0, i).join('/');
    if (!candidate) continue;

    try {
      // Check if this directory is a git repo
      execSync('git rev-parse --git-dir', { cwd: candidate, stdio: 'pipe' });
      // Check if it's not a worktree itself
      const gitDir = execSync('git rev-parse --git-dir', {
        cwd: candidate,
        encoding: 'utf-8',
        stdio: 'pipe'
      }).trim();

      if (!gitDir.includes('worktrees')) {
        return candidate;
      }
    } catch {
      // Not a git repo, keep searching
    }
  }

  return null;
}
