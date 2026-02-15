/**
 * Handoff Document Generator
 *
 * Builds structured session handoff documents for continuity between sessions.
 * Replaces the old context-saver skill with automated handoff generation.
 *
 * Works in both solo and crew modes.
 */

import { Blink } from 'blink-query';
import { crewNamespace } from './crew-detect.js';

/**
 * Generate a structured handoff document from session data
 *
 * @param {string} dbPath - Path to capsule.db
 * @param {string} sessionId - Current session ID
 * @param {object|null} crewIdentity - Crew identity or null for solo mode
 * @param {string|null} projectHash - Project hash for namespacing
 * @returns {string} Markdown handoff document
 */
export function generateHandoff(dbPath, sessionId, crewIdentity = null, projectHash = null) {
  const blink = new Blink({ dbPath });

  try {
    const parts = [];

    // Query session files (META type)
    const filesNs = crewNamespace(`session/${sessionId}/files`, crewIdentity, projectHash);
    const fileRecords = blink.list(filesNs);

    // Query sub-agents (SUMMARY type)
    const agentsNs = crewNamespace(`session/${sessionId}/subagents`, crewIdentity, projectHash);
    const agentRecords = blink.list(agentsNs);

    // Section 1: What Was Accomplished
    if (fileRecords.length > 0) {
      parts.push('## What Was Accomplished\n');

      // Group files by action
      const actionGroups = {
        write: [],
        edit: [],
        read: []
      };

      for (const record of fileRecords) {
        try {
          const content = typeof record.content === 'string'
            ? JSON.parse(record.content)
            : record.content;

          const action = content?.action || 'read';
          const filePath = content?.filePath || record.summary?.split(': ')[1] || record.title;

          if (actionGroups[action]) {
            actionGroups[action].push(filePath);
          }
        } catch {
          // Fallback to summary parsing
          const summary = record.summary || '';
          if (summary.startsWith('write:')) {
            actionGroups.write.push(summary.split(': ')[1] || record.title);
          } else if (summary.startsWith('edit:')) {
            actionGroups.edit.push(summary.split(': ')[1] || record.title);
          } else {
            actionGroups.read.push(summary.split(': ')[1] || record.title);
          }
        }
      }

      // Output file groups
      if (actionGroups.write.length > 0) {
        parts.push('**Created:**');
        actionGroups.write.forEach(f => parts.push(`- ${f}`));
        parts.push('');
      }

      if (actionGroups.edit.length > 0) {
        parts.push('**Modified:**');
        actionGroups.edit.forEach(f => parts.push(`- ${f}`));
        parts.push('');
      }

      if (actionGroups.read.length > 0 && actionGroups.read.length <= 5) {
        // Only show reads if there aren't too many
        parts.push('**Reviewed:**');
        actionGroups.read.slice(0, 5).forEach(f => parts.push(`- ${f}`));
        if (actionGroups.read.length > 5) {
          parts.push(`- ...and ${actionGroups.read.length - 5} more files`);
        }
        parts.push('');
      }
    }

    // Section 2: Sub-Agents Used
    if (agentRecords.length > 0) {
      parts.push('## Sub-Agents Used\n');

      for (const record of agentRecords) {
        try {
          const content = typeof record.content === 'string'
            ? JSON.parse(record.content)
            : record.content;

          const agentType = content?.agentType || 'unknown';
          const finding = record.summary || content?.prompt?.slice(0, 150) || 'No summary';

          parts.push(`- **${agentType}**: ${finding}`);
        } catch {
          parts.push(`- ${record.title}: ${record.summary || 'No details'}`);
        }
      }
      parts.push('');
    }

    // Section 3: Session Summary
    parts.push('## Session Summary\n');
    parts.push(`- Files touched: ${fileRecords.length}`);
    parts.push(`- Agents invoked: ${agentRecords.length}`);

    // Try to calculate session duration from first and last record
    if (fileRecords.length > 0 || agentRecords.length > 0) {
      const allRecords = [...fileRecords, ...agentRecords];
      const timestamps = allRecords
        .map(r => {
          try {
            const content = typeof r.content === 'string' ? JSON.parse(r.content) : r.content;
            return content?.timestamp;
          } catch {
            return null;
          }
        })
        .filter(t => t != null);

      if (timestamps.length >= 2) {
        const start = Math.min(...timestamps);
        const end = Math.max(...timestamps);
        const durationMs = end - start;
        const durationMin = Math.round(durationMs / 60000);

        if (durationMin > 0) {
          parts.push(`- Duration: ~${durationMin}m`);
        }
      }
    }

    const handoff = parts.join('\n');
    blink.close();

    return handoff;

  } catch (error) {
    blink.close();
    // Return minimal handoff on error
    return `## Session Summary\n\nSession ${sessionId} completed.\n\nError generating detailed handoff: ${error.message}`;
  }
}
