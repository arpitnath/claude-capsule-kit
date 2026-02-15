/**
 * Team State Manager - Persistent team state CRUD
 *
 * Manages team-state.json for tracking teammate sessions across restarts.
 * State lives at ~/.claude/crew/{projectHash}/{profileName}/team-state.json
 *
 * Profile scoping: each profile gets its own state directory.
 * Migration: old flat state (~/.claude/crew/{hash}/team-state.json)
 * auto-moves to the 'default' profile subdirectory.
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync, renameSync, readdirSync } from 'fs';
import { resolve } from 'path';
import { homedir } from 'os';

/**
 * Get the state directory for a project profile.
 * @param {string} projectHash - 12-char project hash
 * @param {string} [profileName='default'] - Profile name
 * @returns {string} Path to ~/.claude/crew/{projectHash}/{profileName}/
 */
export function getStateDir(projectHash, profileName = 'default') {
  const baseDir = resolve(homedir(), '.claude', 'crew', projectHash);

  // Auto-migrate: if old flat team-state.json exists and we're asking for 'default'
  if (profileName === 'default') {
    const oldStatePath = resolve(baseDir, 'team-state.json');
    const newDir = resolve(baseDir, 'default');
    const newStatePath = resolve(newDir, 'team-state.json');
    if (existsSync(oldStatePath) && !existsSync(newStatePath)) {
      mkdirSync(newDir, { recursive: true });
      renameSync(oldStatePath, newStatePath);
    }
  }

  return resolve(baseDir, profileName);
}

/**
 * Load existing team state, or null if none exists.
 * @param {string} projectHash - 12-char project hash
 * @param {string} [profileName='default'] - Profile name
 * @returns {object|null} Parsed team state or null
 */
export function loadTeamState(projectHash, profileName = 'default') {
  const statePath = resolve(getStateDir(projectHash, profileName), 'team-state.json');
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
 * @param {string} [profileName='default'] - Profile name
 */
export function saveTeamState(projectHash, state, profileName = 'default') {
  const dir = getStateDir(projectHash, profileName);
  mkdirSync(dir, { recursive: true });
  state.updated_at = new Date().toISOString();
  writeFileSync(resolve(dir, 'team-state.json'), JSON.stringify(state, null, 2) + '\n');
}

/**
 * Merge a partial update into a specific teammate's state.
 * @param {string} projectHash - 12-char project hash
 * @param {string} name - Teammate name
 * @param {object} update - Partial update to merge
 * @param {string} [profileName='default'] - Profile name
 */
export function updateTeammateState(projectHash, name, update, profileName = 'default') {
  const state = loadTeamState(projectHash, profileName) || { teammates: {} };
  if (!state.teammates) state.teammates = {};
  state.teammates[name] = { ...(state.teammates[name] || {}), ...update };
  saveTeamState(projectHash, state, profileName);
}

/**
 * List all profile names that have state for a project.
 * @param {string} projectHash - 12-char project hash
 * @returns {string[]} Array of profile names with existing state
 */
export function listProfiles(projectHash) {
  const baseDir = resolve(homedir(), '.claude', 'crew', projectHash);
  if (!existsSync(baseDir)) return [];

  // Trigger migration for 'default' profile if needed
  getStateDir(projectHash, 'default');

  return readdirSync(baseDir, { withFileTypes: true })
    .filter(d => d.isDirectory() && existsSync(resolve(baseDir, d.name, 'team-state.json')))
    .map(d => d.name);
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

/**
 * Store a teammate's spawn prompt for recovery/re-spawn.
 * @param {string} projectHash - 12-char project hash
 * @param {string} profileName - Profile name
 * @param {string} teammateName - Teammate name
 * @param {string} prompt - Full spawn prompt text
 */
export function setSpawnPrompt(projectHash, profileName, teammateName, prompt) {
  const state = loadTeamState(projectHash, profileName);
  if (!state) {
    throw new Error(`No team state found for profile "${profileName}"`);
  }

  if (!state.spawn_prompts) {
    state.spawn_prompts = {};
  }

  state.spawn_prompts[teammateName] = prompt;
  saveTeamState(projectHash, state, profileName);
}

/**
 * Retrieve a teammate's spawn prompt.
 * @param {string} projectHash - 12-char project hash
 * @param {string} profileName - Profile name
 * @param {string} teammateName - Teammate name
 * @returns {string|null} Spawn prompt or null if not found
 */
export function getSpawnPrompt(projectHash, profileName, teammateName) {
  const state = loadTeamState(projectHash, profileName);
  if (!state || !state.spawn_prompts) {
    return null;
  }

  return state.spawn_prompts[teammateName] || null;
}
