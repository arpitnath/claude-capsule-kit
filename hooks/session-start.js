#!/usr/bin/env node
/**
 * SessionStart Hook - Capsule Integration
 *
 * Queries Capsule for recent context and injects it into the Claude Code session.
 * Crew-aware: shared capsule.db with personal + team context in worktree mode.
 */

import { Blink } from 'blink-query';
import { createInterface } from 'readline';
import { getCapsuleDbPath, getCrewIdentity, crewNamespace, getProjectHash, isDisabled } from './lib/crew-detect.js';
import { existsSync, readFileSync, rmSync, unlinkSync } from 'fs';
import { resolve } from 'path';
import { homedir } from 'os';

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

    const blink = new Blink({ dbPath: getCapsuleDbPath() });
    const crewId = getCrewIdentity();

    const contextParts = [];

    try {
      const cutoff = new Date(Date.now() - 30 * 86400000).toISOString();
      const pruned = blink.db.prepare('DELETE FROM records WHERE updated_at < ?').run(cutoff);
      if (pruned.changes > 0) {
        contextParts.push(`[CCK] Auto-pruned ${pruned.changes} stale records.`);
      }
    } catch { /* don't block session start if prune fails */ }

    const sessionNs = crewNamespace('session', crewId, projectHash);
    const recentSessions = blink.list(sessionNs, 'recent').slice(0, 1);

    if (recentSessions.length > 0) {
      const session = recentSessions[0];
      contextParts.push(`## Last Session\n${session.summary || session.title}`);
    }

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

    const recentFiles = blink.search('file', undefined, 3);

    if (recentFiles.length > 0) {
      contextParts.push(
        `## Recent Files\n` +
        recentFiles.map(f => `- ${f.title}: ${f.summary?.slice(0, 80) || ''}`).join('\n')
      );
    }

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

    // Team profile awareness — inject .crew-config.json context
    const crewConfigPath = resolve(process.cwd(), '.crew-config.json');
    if (existsSync(crewConfigPath)) {
      try {
        const crewConfig = JSON.parse(readFileSync(crewConfigPath, 'utf-8'));
        const baseStateDir = resolve(homedir(), '.claude', 'crew', projectHash);

        if (crewConfig.profiles) {
          // New multi-profile format
          const profileNames = Object.keys(crewConfig.profiles);
          let parts = [`## Crew Profiles: ${profileNames.join(', ')}`];
          if (crewConfig.default) parts.push(`Default: ${crewConfig.default}`);

          for (const pName of profileNames) {
            const profile = crewConfig.profiles[pName];
            parts.push(`\n### ${pName}: ${profile.name}`);
            parts.push(`Teammates: ${profile.teammates.map(t => t.name).join(', ')}`);

            const statePath = resolve(baseStateDir, pName, 'team-state.json');
            if (existsSync(statePath)) {
              const state = JSON.parse(readFileSync(statePath, 'utf-8'));
              const ageHours = Math.round((Date.now() - new Date(state.updated_at).getTime()) / 3600000);
              for (const [name, mate] of Object.entries(state.teammates || {})) {
                parts.push(`- ${name}: ${mate.status}, ${ageHours}h ago`);
              }
              if (ageHours <= 4) {
                parts.push(`\nResumable. Use \`cck crew start ${pName}\` to launch.`);
              }
            } else {
              parts.push(`No previous session. Use \`cck crew start ${pName}\` to launch.`);
            }
          }
          contextParts.push(parts.join('\n'));
        } else if (crewConfig.team) {
          // Old single-team format
          let parts = [`## Team: ${crewConfig.team.name}`];
          parts.push(`Teammates: ${crewConfig.team.teammates.map(t => t.name).join(', ')}`);

          // Check both old flat path and new profile-scoped path
          const oldStatePath = resolve(baseStateDir, 'team-state.json');
          const newStatePath = resolve(baseStateDir, 'default', 'team-state.json');
          const statePath = existsSync(newStatePath) ? newStatePath : oldStatePath;

          if (existsSync(statePath)) {
            const state = JSON.parse(readFileSync(statePath, 'utf-8'));
            const ageHours = Math.round((Date.now() - new Date(state.updated_at).getTime()) / 3600000);
            for (const [name, mate] of Object.entries(state.teammates || {})) {
              parts.push(`- ${name}: ${mate.status}, ${ageHours}h ago`);
            }
            if (ageHours <= 4) {
              parts.push('\nTeammates may be resumable. Use `cck crew start` to launch.');
            }
          } else {
            parts.push('No previous team session. Use `cck crew start` to launch.');
          }
          contextParts.push(parts.join('\n'));
        }
      } catch { /* silent */ }
    }

    let context = contextParts.length > 0
      ? `# Capsule Context\n\n${contextParts.join('\n\n')}\n\n---`
      : '';

    if (didCleanup) {
      context += '\n\n[CCK] Cleaned up local v2 artifacts from this project.';
    }

    blink.close();

    const response = {
      hookSpecificOutput: {
        hookEventName: 'SessionStart',
        additionalContext: context
      }
    };

    console.log(JSON.stringify(response));

  } catch (error) {
    // Graceful degradation - don't block session start if database doesn't exist yet
    if (error.code === 'SQLITE_CANTOPEN' || error.message?.includes('no such file')) {
      process.exit(0);
    }

    console.error(`[session-start.js] Error: ${error.message}`);
    process.exit(0);
  }
}

main();
