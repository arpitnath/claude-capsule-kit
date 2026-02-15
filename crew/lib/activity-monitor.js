/**
 * Crew Activity Monitor
 *
 * Provides real-time visibility into teammate file operations and detects overlapping work.
 * Queries the shared capsule.db for crew-scoped file operation records.
 */

import { Blink } from 'blink-query';

/**
 * Get recent file operation activity for all teammates.
 *
 * @param {string} dbPath - Path to capsule.db
 * @param {string} projectHash - Project hash for namespace scoping
 * @param {object} options - Query options
 * @param {number} [options.limit=10] - Max operations per teammate
 * @param {number} [options.since] - Timestamp to filter operations after (ms since epoch)
 * @returns {Array<{teammateName: string, lastActive: number, recentOps: Array}>}
 */
export function getTeammateActivity(dbPath, projectHash, options = {}) {
  const { limit = 10, since = 0 } = options;
  const blink = new Blink({ dbPath });
  const activities = [];

  try {
    // Query all crew namespaces for file operations
    const crewPrefix = `proj/${projectHash}/crew/`;

    // Get all records in crew namespaces
    const allRecords = blink.db.prepare(
      `SELECT * FROM records
       WHERE namespace LIKE ?
       AND namespace LIKE '%/session/%/files'
       AND created_at >= ?
       ORDER BY created_at DESC`
    ).all(`${crewPrefix}%`, since);

    // Group by teammate
    const byTeammate = {};

    for (const record of allRecords) {
      // Extract teammate name from namespace: proj/{hash}/crew/{teammate}/session/{id}/files
      const match = record.namespace.match(/crew\/([^/]+)\/session/);
      if (!match) continue;

      const teammateName = match[1];

      if (!byTeammate[teammateName]) {
        byTeammate[teammateName] = {
          teammateName,
          lastActive: 0,
          recentOps: []
        };
      }

      // Parse content (it's JSON stringified in META records)
      let content;
      try {
        content = typeof record.content === 'string'
          ? JSON.parse(record.content)
          : record.content;
      } catch {
        content = {};
      }

      const timestamp = content.timestamp || record.created_at || 0;

      // Update last active timestamp
      if (timestamp > byTeammate[teammateName].lastActive) {
        byTeammate[teammateName].lastActive = timestamp;
      }

      // Add operation if under limit
      if (byTeammate[teammateName].recentOps.length < limit) {
        byTeammate[teammateName].recentOps.push({
          action: content.action || 'unknown',
          file: content.filePath || record.title || 'unknown',
          timestamp
        });
      }
    }

    // Convert to array and sort by last active (most recent first)
    activities.push(...Object.values(byTeammate));
    activities.sort((a, b) => b.lastActive - a.lastActive);

  } finally {
    blink.close();
  }

  return activities;
}

/**
 * Detect files that have been touched by multiple teammates (potential conflicts).
 *
 * @param {Array<{teammateName: string, recentOps: Array}>} activities - Teammate activities from getTeammateActivity
 * @returns {Array<{file: string, teammates: Array<string>}>}
 */
export function detectOverlaps(activities) {
  const fileToTeammates = {};

  // Build map of files to teammates who touched them
  for (const activity of activities) {
    for (const op of activity.recentOps) {
      if (!fileToTeammates[op.file]) {
        fileToTeammates[op.file] = new Set();
      }
      fileToTeammates[op.file].add(activity.teammateName);
    }
  }

  // Find files touched by 2+ teammates
  const overlaps = [];
  for (const [file, teammates] of Object.entries(fileToTeammates)) {
    if (teammates.size > 1) {
      overlaps.push({
        file,
        teammates: Array.from(teammates)
      });
    }
  }

  // Sort by number of teammates (highest first)
  overlaps.sort((a, b) => b.teammates.length - a.teammates.length);

  return overlaps;
}
