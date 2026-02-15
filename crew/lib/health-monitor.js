/**
 * Crew Health Monitor - Detect crashed/hung teammates
 *
 * Checks teammate health by examining:
 * 1. last_active timestamps in team-state.json
 * 2. Recent git commits in worktrees
 * 3. Configurable staleness threshold
 */

import { execSync } from 'child_process';
import { existsSync } from 'fs';
import { loadTeamState } from './team-state-manager.js';

/**
 * Health status values:
 * - active: Updated recently (within threshold)
 * - idle: No recent updates but not yet stale
 * - unresponsive: Stale beyond threshold, may be hung
 * - crashed: Worktree exists but no activity and very stale
 */

/**
 * Check health of all teammates in a crew profile.
 * @param {string} projectHash - 12-char project hash
 * @param {string} profileName - Profile name
 * @param {object} options - Health check options
 * @param {number} [options.staleThresholdMinutes=10] - Minutes before teammate is considered stale
 * @param {number} [options.commitWindowMinutes=30] - Window for checking recent commits
 * @returns {Array<object>} Array of teammate health reports
 */
export function checkHealth(projectHash, profileName, options = {}) {
  const staleThresholdMinutes = options.staleThresholdMinutes || 10;
  const commitWindowMinutes = options.commitWindowMinutes || 30;

  const state = loadTeamState(projectHash, profileName);
  if (!state || !state.teammates) {
    return [];
  }

  const staleThresholdMs = staleThresholdMinutes * 60 * 1000;
  const now = Date.now();
  const results = [];

  for (const [name, mate] of Object.entries(state.teammates)) {
    const report = {
      name,
      branch: mate.branch,
      status: mate.status || 'unknown',
      lastActive: mate.last_active || null,
      worktreePath: mate.worktree_path || null,
      recentCommits: 0,
      health: 'unknown'
    };

    // Calculate age of last activity
    let ageMs = null;
    if (mate.last_active) {
      ageMs = now - new Date(mate.last_active).getTime();
    }

    // Check for recent commits in worktree
    if (mate.worktree_path && existsSync(mate.worktree_path)) {
      try {
        const sinceTime = `${commitWindowMinutes} minutes ago`;
        const output = execSync(
          `git -C "${mate.worktree_path}" log --oneline --since="${sinceTime}"`,
          { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] }
        );
        report.recentCommits = output.trim().split('\n').filter(line => line.length > 0).length;
      } catch {
        report.recentCommits = 0;
      }
    }

    // Determine health status
    if (!mate.last_active) {
      report.health = 'unresponsive';
    } else if (ageMs < staleThresholdMs) {
      report.health = 'active';
    } else if (ageMs < staleThresholdMs * 2) {
      // Between threshold and 2x threshold: idle
      report.health = 'idle';
    } else if (mate.worktree_path && existsSync(mate.worktree_path) && report.recentCommits === 0) {
      // Very stale and no recent commits: likely crashed
      report.health = 'crashed';
    } else {
      report.health = 'unresponsive';
    }

    results.push(report);
  }

  return results;
}

/**
 * Format health report as human-readable text.
 * @param {Array<object>} healthReports - Array from checkHealth()
 * @returns {string} Formatted report text
 */
export function formatHealthReport(healthReports) {
  if (healthReports.length === 0) {
    return 'No teammates found.';
  }

  const lines = [];
  lines.push('Crew Health Report');
  lines.push('─'.repeat(100));
  lines.push(
    '  Name'.padEnd(22) +
    'Branch'.padEnd(32) +
    'Health'.padEnd(14) +
    'Last Active'.padEnd(22) +
    'Commits (30m)'
  );
  lines.push('─'.repeat(100));

  for (const report of healthReports) {
    const healthIcon = {
      active: '✓',
      idle: '○',
      unresponsive: '⚠',
      crashed: '✗',
      unknown: '?'
    }[report.health] || '?';

    const healthLabel = `${healthIcon} ${report.health}`;
    const lastActive = report.lastActive
      ? formatAge(new Date(report.lastActive))
      : 'never';

    lines.push(
      `  ${report.name.padEnd(20)}${report.branch.padEnd(32)}${healthLabel.padEnd(14)}${lastActive.padEnd(22)}${report.recentCommits}`
    );
  }

  lines.push('');

  // Add recovery steps for unhealthy teammates
  const unhealthy = healthReports.filter(r => r.health === 'crashed' || r.health === 'unresponsive');
  if (unhealthy.length > 0) {
    lines.push('Recovery Steps:');
    lines.push('─'.repeat(100));
    for (const report of unhealthy) {
      lines.push(`\n${report.name} (${report.health}):`);
      lines.push(`  1. Check worktree status: git -C "${report.worktreePath}" status`);
      lines.push(`  2. Check recent commits: git -C "${report.worktreePath}" log --oneline -5`);
      lines.push(`  3. If crashed, re-spawn the teammate using the stored spawn prompt`);
      lines.push(`  4. If unresponsive, send a message: SendMessage(type="message", recipient="${report.name}", ...)`);
    }
  }

  return lines.join('\n');
}

/**
 * Format time age as human-readable string.
 * @param {Date} timestamp - Timestamp to format
 * @returns {string} Age string like "5m ago", "2h ago"
 */
function formatAge(timestamp) {
  const ageMs = Date.now() - timestamp.getTime();
  const ageMinutes = Math.floor(ageMs / 60000);
  const ageHours = Math.floor(ageMs / 3600000);
  const ageDays = Math.floor(ageMs / 86400000);

  if (ageDays > 0) return `${ageDays}d ago`;
  if (ageHours > 0) return `${ageHours}h ago`;
  if (ageMinutes > 0) return `${ageMinutes}m ago`;
  return 'just now';
}
