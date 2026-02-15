/**
 * Crew Config Reader - Load, validate, hash, and resolve .crew-config.json
 *
 * Supports two config formats:
 * - Old: { team: {...}, project: {...} }
 * - New: { profiles: { dev: {...}, review: {...} }, default: "dev", project: {...} }
 *
 * Old format auto-normalizes at resolve time (no file rewrite needed).
 */

import { readFileSync } from 'fs';
import { resolve } from 'path';
import { createHash } from 'crypto';
import { ROLE_PRESETS } from './role-presets.js';

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
 * Resolve which profile to use from a config.
 *
 * Old format ({ team }) → returns { profile: config.team, profileName: 'default' }
 * New format ({ profiles }) → looks up requestedName || config.default || first key
 *
 * @param {object} config - Parsed .crew-config.json
 * @param {string} [requestedName] - Profile name from CLI arg
 * @returns {{ profile: object, profileName: string }}
 * @throws {Error} If profile not found
 */
export function resolveProfile(config, requestedName) {
  // Old format — single team
  if (config.team && !config.profiles) {
    return { profile: config.team, profileName: 'default' };
  }

  // New format — multiple profiles
  if (!config.profiles || typeof config.profiles !== 'object') {
    throw new Error('Config must have either "team" or "profiles" section');
  }

  const profileNames = Object.keys(config.profiles);
  if (profileNames.length === 0) {
    throw new Error('No profiles defined in config');
  }

  const name = requestedName || config.default || profileNames[0];
  const profile = config.profiles[name];

  if (!profile) {
    throw new Error(
      `Profile "${name}" not found. Available: ${profileNames.join(', ')}`
    );
  }

  return { profile, profileName: name };
}

/**
 * Resolve teammates from a team/profile config.
 * Supports two formats:
 * - Flat: { teammates: [...] } — backward compatible
 * - Grouped: { crews: [{ name, teammates: [...] }] } — crew grouping
 *
 * Returns a flat array of teammates with `crew` property set on each.
 * When using flat format, crew defaults to 'default'.
 *
 * @param {object} teamOrProfile - Team or profile object
 * @param {string} [filterCrew] - Optional crew name to filter by
 * @returns {object[]} Flat array of teammates with crew metadata
 */
export function resolveTeammates(teamOrProfile, filterCrew) {
  let teammates = [];

  if (teamOrProfile.crews && Array.isArray(teamOrProfile.crews)) {
    // Grouped format: flatten crews into teammates with crew metadata
    for (const crew of teamOrProfile.crews) {
      for (const mate of crew.teammates || []) {
        teammates.push({ ...mate, crew: crew.name });
      }
    }
  } else if (teamOrProfile.teammates && Array.isArray(teamOrProfile.teammates)) {
    // Flat format: assign 'default' crew
    teammates = teamOrProfile.teammates.map(m => ({ ...m, crew: m.crew || 'default' }));
  }

  // Filter by crew if requested
  if (filterCrew) {
    teammates = teammates.filter(m => m.crew === filterCrew);
  }

  return teammates;
}

/**
 * List crew names from a team/profile config.
 * @param {object} teamOrProfile - Team or profile object
 * @returns {string[]} Array of crew names
 */
export function listCrews(teamOrProfile) {
  if (teamOrProfile.crews && Array.isArray(teamOrProfile.crews)) {
    return teamOrProfile.crews.map(c => c.name);
  }
  return ['default'];
}

/**
 * Validate a crew config. Returns array of error strings (empty = valid).
 * Handles both old format (team) and new format (profiles).
 * @param {object} config - Config to validate
 * @returns {string[]} Array of validation errors
 */
export function validateConfig(config) {
  const errors = [];

  // Detect format
  if (config.profiles) {
    // New multi-profile format
    if (typeof config.profiles !== 'object' || Array.isArray(config.profiles)) {
      errors.push('"profiles" must be an object');
      return errors;
    }

    const profileNames = Object.keys(config.profiles);
    if (profileNames.length === 0) {
      errors.push('"profiles" must contain at least one profile');
      return errors;
    }

    if (config.default && !config.profiles[config.default]) {
      errors.push(`"default" profile "${config.default}" does not exist in profiles`);
    }

    for (const pName of profileNames) {
      const profile = config.profiles[pName];
      const pfx = `profiles.${pName}`;
      errors.push(...validateTeam(profile, pfx));
    }
  } else if (config.team) {
    // Old single-team format
    errors.push(...validateTeam(config.team, 'team'));
  } else {
    errors.push('Missing "team" or "profiles" section');
  }

  return errors;
}

/**
 * Validate a single team object (used for both old and new format).
 * @param {object} team - Team object with name, teammates[]
 * @param {string} prefix - Error prefix (e.g. "team" or "profiles.dev")
 * @returns {string[]} Validation errors
 */
function validateTeam(team, prefix) {
  const errors = [];

  if (!team.name || typeof team.name !== 'string') {
    errors.push(`${prefix}.name is required and must be a string`);
  }

  // Support both flat teammates and crews grouping
  if (team.crews && Array.isArray(team.crews)) {
    if (team.crews.length === 0) {
      errors.push(`${prefix}.crews must be a non-empty array`);
      return errors;
    }
    for (let c = 0; c < team.crews.length; c++) {
      const crew = team.crews[c];
      if (!crew.name || typeof crew.name !== 'string') {
        errors.push(`${prefix}.crews[${c}]: name is required`);
      }
      if (!Array.isArray(crew.teammates) || crew.teammates.length === 0) {
        errors.push(`${prefix}.crews[${c}].teammates must be a non-empty array`);
        continue;
      }
      for (let i = 0; i < crew.teammates.length; i++) {
        const t = crew.teammates[i];
        if (!t.name || typeof t.name !== 'string') {
          errors.push(`${prefix}.crews[${c}].teammate[${i}]: name is required`);
        }
        if (!t.branch || typeof t.branch !== 'string') {
          errors.push(`${prefix}.crews[${c}].teammate[${i}]: branch is required`);
        }
        if (t.role && !ROLE_PRESETS[t.role]) {
          errors.push(
            `${prefix}.crews[${c}].teammate[${i}]: unknown role "${t.role}". Valid: ${Object.keys(ROLE_PRESETS).join(', ')}`
          );
        }
      }
    }
  } else if (Array.isArray(team.teammates)) {
    if (team.teammates.length === 0) {
      errors.push(`${prefix}.teammates must be a non-empty array`);
      return errors;
    }
    for (let i = 0; i < team.teammates.length; i++) {
      const t = team.teammates[i];
      if (!t.name || typeof t.name !== 'string') {
        errors.push(`${prefix}.teammate[${i}]: name is required`);
      }
      if (!t.branch || typeof t.branch !== 'string') {
        errors.push(`${prefix}.teammate[${i}]: branch is required`);
      }
      if (t.role && !ROLE_PRESETS[t.role]) {
        errors.push(
          `${prefix}.teammate[${i}]: unknown role "${t.role}". Valid: ${Object.keys(ROLE_PRESETS).join(', ')}`
        );
      }
    }
  } else {
    errors.push(`${prefix} must have either "teammates" or "crews" array`);
  }

  return errors;
}

/**
 * Resolve the worktree path for a teammate branch.
 * Convention:
 *   default profile: {projectRoot}-{sanitized-branch}
 *   named profile:   {projectRoot}-{profileName}-{sanitized-branch}
 *
 * @param {string} projectRoot - Path to main project
 * @param {string} branch - Git branch name
 * @param {string} [profileName] - Profile name (null/'default' = no prefix)
 * @returns {string} Absolute path for worktree
 */
export function resolveWorktreePath(projectRoot, branch, profileName) {
  const sanitized = branch.replace(/\//g, '--');
  if (!profileName || profileName === 'default') {
    return `${projectRoot}-${sanitized}`;
  }
  return `${projectRoot}-${profileName}-${sanitized}`;
}
