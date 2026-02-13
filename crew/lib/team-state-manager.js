/**
 * Team State Manager - Persistent team state CRUD
 *
 * Manages team-state.json for tracking teammate sessions across restarts.
 * State lives at ~/.claude/crew/{projectHash}/team-state.json
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'fs';
import { resolve } from 'path';
import { homedir } from 'os';

/**
 * Get the state directory for a project.
 * @param {string} projectHash - 12-char project hash
 * @returns {string} Path to ~/.claude/crew/{projectHash}/
 */
export function getStateDir(projectHash) {
  return resolve(homedir(), '.claude', 'crew', projectHash);
}

/**
 * Load existing team state, or null if none exists.
 * @param {string} projectHash - 12-char project hash
 * @returns {object|null} Parsed team state or null
 */
export function loadTeamState(projectHash) {
  const statePath = resolve(getStateDir(projectHash), 'team-state.json');
  if (!existsSync(statePath)) return null;
  try {
    return JSON.parse(readFileSync(statePath, 'utf-8'));
  } catch {
    return null;
  }
}

/**
 * Save team state to disk.
 * @param {string} projectHash - 12-char project hash
 * @param {object} state - Team state object
 */
export function saveTeamState(projectHash, state) {
  const dir = getStateDir(projectHash);
  mkdirSync(dir, { recursive: true });
  state.updated_at = new Date().toISOString();
  writeFileSync(resolve(dir, 'team-state.json'), JSON.stringify(state, null, 2) + '\n');
}

/**
 * Merge a partial update into a specific teammate's state.
 * @param {string} projectHash - 12-char project hash
 * @param {string} name - Teammate name
 * @param {object} update - Partial update to merge
 */
export function updateTeammateState(projectHash, name, update) {
  const state = loadTeamState(projectHash) || { teammates: {} };
  if (!state.teammates) state.teammates = {};
  state.teammates[name] = { ...(state.teammates[name] || {}), ...update };
  saveTeamState(projectHash, state);
}

/**
 * Check if a teammate's state is stale (last active too long ago).
 * @param {object} teammate - Teammate state object with last_active field
 * @param {number} [maxAgeMs=14400000] - Max age in ms (default: 4 hours)
 * @returns {boolean} True if stale
 */
export function isStale(teammate, maxAgeMs = 4 * 3600000) {
  if (!teammate || !teammate.last_active) return true;
  return (Date.now() - new Date(teammate.last_active).getTime()) > maxAgeMs;
}

/**
 * Check if config has changed since last state save.
 * @param {string} currentHash - Hash of current config
 * @param {string} stateHash - Hash stored in state
 * @returns {boolean} True if different
 */
export function isConfigChanged(currentHash, stateHash) {
  return currentHash !== stateHash;
}
