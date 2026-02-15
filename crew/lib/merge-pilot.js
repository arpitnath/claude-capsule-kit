/**
 * Merge Pilot - Intelligent multi-branch merge orchestration for Crew Mode
 *
 * Provides dry-run merge previews and safe merge execution for parallel
 * teammate branches. Uses git merge-tree for conflict detection without
 * touching the working tree.
 */

import { execSync } from 'child_process';
import { existsSync } from 'fs';

/**
 * Preview merges for all branches without modifying working tree.
 * Uses git merge-tree to detect conflicts and changed files.
 *
 * @param {string} projectRoot - Absolute path to main project repository
 * @param {string} mainBranch - Name of the main branch (e.g., 'main', 'master')
 * @param {Array<{name: string, branch: string, worktree_path?: string}>} teammates - Array of teammate objects
 * @returns {Array<{name: string, branch: string, status: 'clean'|'conflict'|'error', conflictFiles: string[], changedFiles: string[], message?: string}>}
 */
export function mergePreview(projectRoot, mainBranch, teammates) {
  if (!existsSync(projectRoot)) {
    throw new Error(`Project root does not exist: ${projectRoot}`);
  }

  const results = [];

  for (const mate of teammates) {
    const { name, branch } = mate;

    try {
      // Verify branch exists
      try {
        execSync(`git rev-parse --verify "${branch}"`, {
          cwd: projectRoot,
          stdio: 'pipe',
          encoding: 'utf-8'
        });
      } catch {
        results.push({
          name,
          branch,
          status: 'error',
          conflictFiles: [],
          changedFiles: [],
          message: `Branch '${branch}' does not exist`
        });
        continue;
      }

      // Get changed files between main and branch
      let changedFiles = [];
      try {
        const diffOutput = execSync(
          `git diff --name-only "${mainBranch}...${branch}"`,
          { cwd: projectRoot, stdio: 'pipe', encoding: 'utf-8' }
        );
        changedFiles = diffOutput.trim().split('\n').filter(f => f.length > 0);
      } catch (err) {
        results.push({
          name,
          branch,
          status: 'error',
          conflictFiles: [],
          changedFiles: [],
          message: `Failed to get changed files: ${err.message}`
        });
        continue;
      }

      // Run merge-tree to detect conflicts
      // git merge-tree exits 0 for clean merge, 1 for conflicts
      let mergeTreeOutput;
      let hasConflicts = false;

      try {
        // Try modern merge-tree (Git 2.38+) with --write-tree flag
        mergeTreeOutput = execSync(
          `git merge-tree --write-tree "${mainBranch}" "${branch}"`,
          { cwd: projectRoot, stdio: 'pipe', encoding: 'utf-8' }
        );
      } catch (err) {
        // Exit code 1 means conflicts detected
        if (err.status === 1) {
          hasConflicts = true;
          mergeTreeOutput = err.stdout || '';
        } else {
          // Real error (old git version or other issue)
          // Fall back to traditional merge-tree
          try {
            mergeTreeOutput = execSync(
              `git merge-tree $(git merge-base "${mainBranch}" "${branch}") "${mainBranch}" "${branch}"`,
              { cwd: projectRoot, stdio: 'pipe', encoding: 'utf-8' }
            );
            // Traditional merge-tree shows conflict markers
            hasConflicts = mergeTreeOutput.includes('<<<<<<<');
          } catch (fallbackErr) {
            results.push({
              name,
              branch,
              status: 'error',
              conflictFiles: [],
              changedFiles,
              message: `merge-tree failed: ${fallbackErr.message}`
            });
            continue;
          }
        }
      }

      // Parse conflict files from merge-tree output
      let conflictFiles = [];
      if (hasConflicts) {
        // Modern merge-tree outputs conflict info to stderr or in special format
        // Extract conflicting files by looking for conflict markers or parsing output
        const conflictMatches = mergeTreeOutput.matchAll(/(?:^\+<<<<<<<|^conflict in (.+))/gm);
        const fileSet = new Set();
        for (const match of conflictMatches) {
          if (match[1]) fileSet.add(match[1]);
        }
        conflictFiles = Array.from(fileSet);

        // If we didn't find conflicts via parsing, but merge-tree indicated conflicts,
        // check which changed files might conflict
        if (conflictFiles.length === 0 && hasConflicts) {
          // Conservative: mark all changed files as potential conflicts
          conflictFiles = changedFiles.slice();
        }
      }

      results.push({
        name,
        branch,
        status: hasConflicts ? 'conflict' : 'clean',
        conflictFiles,
        changedFiles
      });

    } catch (err) {
      results.push({
        name,
        branch,
        status: 'error',
        conflictFiles: [],
        changedFiles: [],
        message: err.message
      });
    }
  }

  return results;
}

/**
 * Detect overlapping file changes between branches.
 * Returns pairs of teammates that modified the same files.
 *
 * @param {string} projectRoot - Absolute path to main project repository
 * @param {string} mainBranch - Name of the main branch
 * @param {Array<{name: string, branch: string}>} teammates - Array of teammate objects
 * @returns {Array<{teammates: [string, string], files: string[]}>}
 */
export function detectOverlaps(projectRoot, mainBranch, teammates) {
  const overlaps = [];

  // Get changed files for each teammate
  const teammateFiles = teammates.map(mate => {
    try {
      const diffOutput = execSync(
        `git diff --name-only "${mainBranch}...${mate.branch}"`,
        { cwd: projectRoot, stdio: 'pipe', encoding: 'utf-8' }
      );
      return {
        name: mate.name,
        files: new Set(diffOutput.trim().split('\n').filter(f => f.length > 0))
      };
    } catch {
      return { name: mate.name, files: new Set() };
    }
  });

  // Find intersections
  for (let i = 0; i < teammateFiles.length; i++) {
    for (let j = i + 1; j < teammateFiles.length; j++) {
      const common = [...teammateFiles[i].files].filter(f => teammateFiles[j].files.has(f));
      if (common.length > 0) {
        overlaps.push({
          teammates: [teammateFiles[i].name, teammateFiles[j].name],
          files: common
        });
      }
    }
  }

  return overlaps;
}

/**
 * Execute merges in optimal order (clean first, conflicts last).
 * Creates a backup tag before merging for rollback capability.
 *
 * @param {string} projectRoot - Absolute path to main project repository
 * @param {string} mainBranch - Name of the main branch
 * @param {Array<{name: string, branch: string}>} teammates - Array of teammate objects
 * @param {Object} options - Merge options
 * @param {boolean} [options.runTests=false] - Whether to run tests after each merge
 * @param {string} [options.testCommand='npm test'] - Command to run for tests
 * @param {boolean} [options.createBackup=true] - Create backup tag before merging
 * @returns {Object} Merge execution results
 */
export function executeMerge(projectRoot, mainBranch, teammates, options = {}) {
  const {
    runTests = false,
    testCommand = 'npm test',
    createBackup = true
  } = options;

  const results = {
    success: [],
    failed: [],
    skipped: [],
    backup_tag: null
  };

  // 1. Run merge preview first
  const preview = mergePreview(projectRoot, mainBranch, teammates);

  // 2. Create backup tag
  if (createBackup) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupTag = `crew-backup-${timestamp}`;
    try {
      execSync(`git tag "${backupTag}"`, {
        cwd: projectRoot,
        stdio: 'pipe'
      });
      results.backup_tag = backupTag;
    } catch (err) {
      throw new Error(`Failed to create backup tag: ${err.message}`);
    }
  }

  // 3. Sort branches: clean merges first, conflicts last, errors skipped
  const cleanBranches = preview.filter(p => p.status === 'clean');
  const conflictBranches = preview.filter(p => p.status === 'conflict');
  const errorBranches = preview.filter(p => p.status === 'error');

  // Skip error branches
  for (const err of errorBranches) {
    results.skipped.push({
      name: err.name,
      branch: err.branch,
      reason: err.message || 'Preview error'
    });
  }

  // Merge in order: clean first
  const mergeOrder = [...cleanBranches, ...conflictBranches];

  for (const item of mergeOrder) {
    const { name, branch, status } = item;

    try {
      // Switch to main branch
      execSync(`git checkout "${mainBranch}"`, {
        cwd: projectRoot,
        stdio: 'pipe'
      });

      // Attempt merge
      try {
        execSync(`git merge "${branch}" --no-edit`, {
          cwd: projectRoot,
          stdio: 'pipe'
        });

        // Merge succeeded
        let testResult = null;
        if (runTests) {
          try {
            execSync(testCommand, {
              cwd: projectRoot,
              stdio: 'pipe',
              encoding: 'utf-8'
            });
            testResult = 'passed';
          } catch (testErr) {
            testResult = 'failed';
            // Rollback this merge
            execSync(`git reset --hard HEAD~1`, {
              cwd: projectRoot,
              stdio: 'pipe'
            });
            results.failed.push({
              name,
              branch,
              reason: 'Tests failed after merge',
              testOutput: testErr.stdout || testErr.message
            });
            continue;
          }
        }

        results.success.push({
          name,
          branch,
          status,
          testResult
        });

      } catch (mergeErr) {
        // Merge failed (conflicts)
        // Abort the merge
        try {
          execSync(`git merge --abort`, {
            cwd: projectRoot,
            stdio: 'pipe'
          });
        } catch {}

        results.failed.push({
          name,
          branch,
          reason: 'Merge conflicts detected',
          message: 'Run `git merge ' + branch + '` manually to resolve'
        });
      }

    } catch (err) {
      results.failed.push({
        name,
        branch,
        reason: 'Unexpected error',
        message: err.message
      });
    }
  }

  return results;
}
