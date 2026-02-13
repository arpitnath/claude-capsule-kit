#!/usr/bin/env node
/**
 * SessionStart Hook - Blink Integration
 *
 * Queries Blink for recent context and injects it into the Claude Code session.
 * Crew-aware: when running in a worktree, uses the shared blink.db and
 * injects both personal + team context.
 *
 * Input: JSON from stdin with session metadata
 * Output: JSON with additionalContext for session initialization
 */

import { Blink } from 'blink-query';
import { createInterface } from 'readline';
import { getBlinkDbPath, getCrewIdentity, crewNamespace, getProjectHash, isDisabled } from './lib/crew-detect.js';
import { existsSync, rmSync, unlinkSync } from 'fs';
import { resolve } from 'path';

function cleanupV2Artifacts() {
  const localClaude = resolve(process.cwd(), '.claude');
  const versionFile = resolve(localClaude, '.super-claude-version');
  if (!existsSync(versionFile)) return false;
  const dirsToRemove = ['hooks', 'tools', 'agents', 'skills', 'scripts', 'docs', 'lib', 'memory'];
  for (const dir of dirsToRemove) {
    const p = resolve(localClaude, dir);
    if (existsSync(p)) { try { rmSync(p, { recursive: true, force: true }); } catch {} }
  }
  try { unlinkSync(versionFile); } catch {}
  return true;
}

async function main() {
  try {
    // Read hook input from stdin
    const rl = createInterface({ input: process.stdin });
    let inputJson = '';

    for await (const line of rl) {
      inputJson += line;
    }

    const input = JSON.parse(inputJson);
    if (isDisabled()) process.exit(0);
    const didCleanup = cleanupV2Artifacts();
    const projectHash = getProjectHash();
    const sessionId = input.session_id || 'default';

    // Initialize Blink (shared DB in crew mode, local otherwise)
    const blink = new Blink({ dbPath: getBlinkDbPath() });
    const crewId = getCrewIdentity();

    // Build context message
    const contextParts = [];

    // --- Personal context (own recent session) ---
    const sessionNs = crewNamespace('session', crewId, projectHash);
    const recentSessions = blink.list(sessionNs, 'recent').slice(0, 1);

    if (recentSessions.length > 0) {
      const session = recentSessions[0];
      contextParts.push(`## Last Session\n${session.summary || session.title}`);
    }

    // --- Discoveries (shared in crew mode) ---
    const discoveryNs = crewId
      ? (projectHash ? `proj/${projectHash}/crew/_shared/discoveries` : 'crew/_shared/discoveries')
      : crewNamespace('discoveries', null, projectHash);
    const topDiscoveries = blink.query(`${discoveryNs} order by hit_count desc limit 5`);

    if (topDiscoveries.length > 0) {
      contextParts.push(
        `## Top Discoveries\n` +
        topDiscoveries.map(d => `- ${d.title}: ${d.summary?.slice(0, 100) || ''}`).join('\n')
      );
    }

    // --- Recent files ---
    const recentFiles = blink.search('file', undefined, 3);

    if (recentFiles.length > 0) {
      contextParts.push(
        `## Recent Files\n` +
        recentFiles.map(f => `- ${f.title}: ${f.summary?.slice(0, 80) || ''}`).join('\n')
      );
    }

    // --- Team activity (crew mode only) ---
    if (crewId) {
      const teamSessions = blink.list('crew', 'recent').slice(0, 3);
      const otherTeammates = teamSessions.filter(s =>
        !s.namespace.startsWith(`crew/${crewId.teammate_name}`)
      );
      if (otherTeammates.length > 0) {
        contextParts.push(
          `## Team Activity\n` +
          otherTeammates.map(s => `- ${s.title}: ${s.summary?.slice(0, 80) || ''}`).join('\n')
        );
      }
    }

    let context = contextParts.length > 0
      ? `# Capsule Context (Blink)\n\n${contextParts.join('\n\n')}\n\n---`
      : '';

    if (didCleanup) {
      context += '\n\n[CCK] Cleaned up local v2 artifacts from this project.';
    }

    // Close database
    blink.close();

    // Output hook response
    const response = {
      hookSpecificOutput: {
        hookEventName: 'SessionStart',
        additionalContext: context
      }
    };

    console.log(JSON.stringify(response));

  } catch (error) {
    // Graceful degradation - if blink not available, just exit quietly
    // Don't block session start if database doesn't exist yet
    if (error.code === 'SQLITE_CANTOPEN' || error.message?.includes('no such file')) {
      // Database doesn't exist yet - first session
      process.exit(0);
    }

    // Log error but don't block session
    console.error(`[session-start.js] Error: ${error.message}`);
    process.exit(0);
  }
}

main();
