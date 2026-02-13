/**
 * Crew Config Reader - Load, validate, and hash .crew-config.json
 */

import { readFileSync } from 'fs';
import { resolve } from 'path';
import { createHash } from 'crypto';

/**
 * Load .crew-config.json from project root.
 * @param {string} projectRoot - Path to project root
 * @returns {object} Parsed config
 * @throws {Error} If file not found or invalid JSON
 */
export function loadCrewConfig(projectRoot) {
  const configPath = resolve(projectRoot, '.crew-config.json');
  const raw = readFileSync(configPath, 'utf-8');
  return JSON.parse(raw);
}

/**
 * Compute a short hash of the config for change detection.
 * @param {object} configObj - Config object to hash
 * @returns {string} 12-char hex hash
 */
export function hashConfig(configObj) {
  return createHash('sha256')
    .update(JSON.stringify(configObj))
    .digest('hex')
    .slice(0, 12);
}

/**
 * Validate a crew config. Returns array of error strings (empty = valid).
 * @param {object} config - Config to validate
 * @returns {string[]} Array of validation errors
 */
export function validateConfig(config) {
  const errors = [];

  if (!config.team) {
    errors.push('Missing "team" section');
    return errors;
  }

  if (!config.team.name || typeof config.team.name !== 'string') {
    errors.push('team.name is required and must be a string');
  }

  if (!Array.isArray(config.team.teammates) || config.team.teammates.length === 0) {
    errors.push('team.teammates must be a non-empty array');
    return errors;
  }

  for (let i = 0; i < config.team.teammates.length; i++) {
    const t = config.team.teammates[i];
    if (!t.name || typeof t.name !== 'string') {
      errors.push(`teammate[${i}]: name is required`);
    }
    if (!t.branch || typeof t.branch !== 'string') {
      errors.push(`teammate[${i}]: branch is required`);
    }
  }

  return errors;
}

/**
 * Resolve the worktree path for a teammate branch.
 * Convention: {projectRoot}-{sanitized-branch} where / → --
 * @param {string} projectRoot - Path to main project
 * @param {string} branch - Git branch name
 * @returns {string} Absolute path for worktree
 */
export function resolveWorktreePath(projectRoot, branch) {
  const sanitized = branch.replace(/\//g, '--');
  return `${projectRoot}-${sanitized}`;
}
