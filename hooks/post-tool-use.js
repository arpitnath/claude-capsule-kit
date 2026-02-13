#!/usr/bin/env node
/**
 * PostToolUse Hook - Capsule Integration
 *
 * Captures tool operations and saves them to Capsule for future context.
 * Crew-aware: when running in a worktree, uses the shared capsule.db
 * and scopes namespaces to the teammate.
 *
 * Captures:
 * - Read/Write/Edit operations → META records (file operation metadata)
 * - Task tool (sub-agents) → SUMMARY records (direct consumption)
 */

import { Blink } from 'blink-query';
import { createInterface } from 'readline';
import { basename } from 'path';
import { getCapsuleDbPath, getCrewIdentity, crewNamespace, getProjectHash, isDisabled } from './lib/crew-detect.js';

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
    const projectHash = getProjectHash();
    const toolName = input.tool_name;
    const toolInput = input.tool_input || {};
    const sessionId = input.session_id || 'default';

    // Shared DB in crew mode, local otherwise
    // Pass file path hint for worktree-based crew identity detection
    const filePath = toolInput.file_path || toolInput.path || '';
    const blink = new Blink({ dbPath: getCapsuleDbPath() });
    const crewId = getCrewIdentity({ filePath });

    // Capture file operations
    if (['Read', 'Write', 'Edit'].includes(toolName)) {
      if (filePath && !filePath.includes('node_modules') && !filePath.includes('.git/')) {
        const fileName = basename(filePath);
        const action = toolName.toLowerCase();

        // Save file operation metadata (META = structured operation data)
        blink.save({
          namespace: crewNamespace(`session/${sessionId}/files`, crewId, projectHash),
          title: fileName,
          summary: `${action}: ${filePath}`,
          type: 'META',
          content: {
            filePath,
            action,
            timestamp: Date.now()
          },
          tags: ['file', action, sessionId, ...(crewId ? [crewId.teammate_name] : [])]
        });
      }
    }

    // Capture sub-agent results
    if (toolName === 'Task') {
      const agentType = toolInput.subagent_type;
      const prompt = toolInput.prompt;

      if (agentType && prompt) {
        // Save sub-agent invocation (SUMMARY = read directly, no fetching needed)
        blink.save({
          namespace: crewNamespace(`session/${sessionId}/subagents`, crewId, projectHash),
          title: `${agentType} - ${new Date().toISOString()}`,
          summary: prompt.slice(0, 200),
          type: 'SUMMARY',
          content: {
            agentType,
            prompt: prompt.slice(0, 500),
            timestamp: Date.now()
          },
          tags: ['subagent', agentType, sessionId, ...(crewId ? [crewId.teammate_name] : [])]
        });
      }
    }

    blink.close();

    // No output needed for PostToolUse (unless blocking/warning)
    process.exit(0);

  } catch (error) {
    // Graceful degradation
    console.error(`[post-tool-use.js] Error: ${error.message}`);
    process.exit(0);
  }
}

main();
