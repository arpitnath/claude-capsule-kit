/**
 * Role Presets - Default configurations for common teammate roles
 *
 * Roles reduce boilerplate: declare "role": "reviewer" instead of
 * manually setting model, mode, subagent_type, and focus.
 */

export const ROLE_PRESETS = {
  developer: {
    model: 'sonnet',
    mode: 'bypassPermissions',
    subagent_type: 'general-purpose',
    focus_prefix: 'Implement features, write code, fix bugs in your worktree.'
  },
  reviewer: {
    model: 'sonnet',
    mode: 'default',
    subagent_type: 'general-purpose',
    focus_prefix: 'Review code for bugs, security issues, and quality. Read-only — do not modify files.'
  },
  tester: {
    model: 'haiku',
    mode: 'bypassPermissions',
    subagent_type: 'general-purpose',
    focus_prefix: 'Write and run tests. Ensure coverage for new features.'
  },
  architect: {
    model: 'opus',
    mode: 'default',
    subagent_type: 'general-purpose',
    focus_prefix: 'Design architecture, review patterns, suggest improvements. Read-only.'
  }
};

/**
 * Resolve a teammate's role into concrete config fields.
 * Role sets defaults; explicit fields on the teammate override role defaults.
 * Focus: role prefix is prepended to user's focus (not replaced).
 *
 * @param {object} teammate - Teammate config from .crew-config.json
 * @returns {object} Teammate with role defaults merged in
 */
export function resolveRole(teammate) {
  if (!teammate.role) return teammate;

  const preset = ROLE_PRESETS[teammate.role];
  if (!preset) return teammate;

  const resolved = { ...teammate };

  // Role provides defaults — explicit fields override
  if (!resolved.model) resolved.model = preset.model;
  if (!resolved.mode) resolved.mode = preset.mode;
  if (!resolved.subagent_type) resolved.subagent_type = preset.subagent_type;

  // Focus: prepend role prefix to user's focus
  const userFocus = resolved.focus || '';
  resolved.focus = userFocus
    ? `${preset.focus_prefix}\n\n${userFocus}`
    : preset.focus_prefix;

  return resolved;
}
