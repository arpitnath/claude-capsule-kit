#!/usr/bin/env node
/**
 * SessionEnd Hook - Blink Integration
 *
 * Finalizes the session by creating a session summary record in Blink.
 * Crew-aware: scopes to teammate namespace and writes to shared DB.
 */

import { Blink } from 'blink-query';
import { createInterface } from 'readline';
import { getBlinkDbPath, getCrewIdentity, crewNamespace, getProjectHash, isDisabled } from './lib/crew-detect.js';

async function main() {
  try {
    // Read hook input from stdin
    const rl = createInterface({ input: process.stdin });
    let inputJson = '';

    for await (const line of rl) {
      inputJson += line;
    }

    const input = JSON.parse(inputJson);
    const sessionId = input.session_id || 'default';
    if (isDisabled()) process.exit(0);
    const projectHash = getProjectHash();

    // Initialize Blink (shared DB in crew mode, local otherwise)
    const blink = new Blink({ dbPath: getBlinkDbPath() });
    const crewId = getCrewIdentity();

    // Query session activity (from this teammate's namespace)
    const filesNs = crewNamespace(`session/${sessionId}/files`, crewId, projectHash);
    const agentsNs = crewNamespace(`session/${sessionId}/subagents`, crewId, projectHash);
    const sessionFiles = blink.list(filesNs);
    const sessionSubagents = blink.list(agentsNs);

    // Create session summary
    const teammateSuffix = crewId ? ` (${crewId.teammate_name})` : '';
    const summary = [
      `Session ${sessionId}${teammateSuffix}`,
      `Files accessed: ${sessionFiles.length}`,
      `Sub-agents used: ${sessionSubagents.length}`,
      `Completed at: ${new Date().toISOString()}`
    ].join(' | ');

    // Save SESSION record (META = structured session metadata)
    blink.save({
      namespace: crewNamespace('session', crewId, projectHash),
      title: `Session ${new Date().toISOString()}`,
      summary,
      type: 'META',
      content: {
        sessionId,
        teammateName: crewId?.teammate_name || null,
        filesCount: sessionFiles.length,
        subagentsCount: sessionSubagents.length,
        endedAt: Date.now()
      },
      tags: ['session', sessionId, ...(crewId ? [crewId.teammate_name] : [])]
    });

    blink.close();

    // No output needed for SessionEnd
    process.exit(0);

  } catch (error) {
    console.error(`[session-end.js] Error: ${error.message}`);
    process.exit(0);
  }
}

main();
