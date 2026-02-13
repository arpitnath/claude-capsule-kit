/**
 * Prompt Generator - Generate lead prompts for team launch/resume
 *
 * Builds structured prompts that guide the lead agent through creating
 * a team, spawning teammates, and assigning tasks.
 */

import { isStale, isConfigChanged } from './team-state-manager.js';

/**
 * Generate the full lead prompt for launching or resuming a team.
 *
 * @param {object} config - Parsed .crew-config.json
 * @param {object|null} teamState - Existing team state (null = fresh)
 * @param {object} worktreePaths - Map of teammate name → worktree path
 * @returns {string} Lead prompt string
 */
export function generateLeadPrompt(config, teamState, worktreePaths) {
  const { team } = config;
  const projectRoot = worktreePaths._projectRoot || process.cwd();

  const canResume = teamState
    && !isConfigChanged(teamState.config_hash, teamState.config_hash) // same hash
    && teamState.teammates
    && Object.values(teamState.teammates).some(t => !isStale(t));

  if (canResume) {
    return generateResumePrompt(team, teamState, worktreePaths, projectRoot);
  }

  return generateFreshPrompt(team, worktreePaths, projectRoot);
}

/**
 * Generate a resume prompt for an existing team session.
 */
function generateResumePrompt(team, teamState, worktreePaths, projectRoot) {
  const lastActive = teamState.updated_at
    ? Math.round((Date.now() - new Date(teamState.updated_at).getTime()) / 3600000)
    : '?';

  const lines = [
    `## Team Resume: ${team.name}`,
    '',
    `Previous teammates were active ${lastActive} hours ago. Attempt resume for each.`,
    '',
    '### Step 1: Create Team',
    `Use TeamCreate with team_name="${team.name}"`,
    '',
    '### Step 2: Resume Teammates',
    'For each teammate below, TRY to resume with their saved agent_id.',
    'If resume fails (agent expired), spawn fresh with the full prompt.',
    '',
  ];

  for (const mate of team.teammates) {
    const savedState = teamState.teammates?.[mate.name];
    const wtPath = worktreePaths[mate.name] || 'unknown';
    const agentId = savedState?.agent_id || 'none';
    const stale = !savedState || isStale(savedState);

    lines.push(`#### ${mate.name}`);
    lines.push(`- Agent ID: ${agentId}${stale ? ' (STALE — spawn fresh)' : ''}`);
    lines.push(`- Branch: ${mate.branch}`);
    lines.push(`- Worktree: ${wtPath}`);

    if (stale || agentId === 'none') {
      lines.push(`- Action: Spawn fresh with prompt below`);
      lines.push('');
      lines.push('```');
      lines.push(generateTeammatePrompt(mate, wtPath, projectRoot));
      lines.push('```');
    } else {
      lines.push(`- Action: Resume with agent_id="${agentId}"`);
      lines.push(`- Resume prompt: "Continue working on your tasks. Check TaskList for pending work."`);
    }
    lines.push('');
  }

  lines.push('### Step 3: Assign Tasks');
  lines.push('After all teammates are running, create tasks and assign them.');

  return lines.join('\n');
}

/**
 * Generate a fresh launch prompt for a new team session.
 */
function generateFreshPrompt(team, worktreePaths, projectRoot) {
  const lines = [
    `## Team Launch: ${team.name}`,
    '',
    '### Step 1: Create Team',
    `Use TeamCreate with team_name="${team.name}"`,
    '',
    '### Step 2: Create Tasks',
    'Create one task per teammate describing their focus area:',
    '',
  ];

  for (const mate of team.teammates) {
    lines.push(`- Task for **${mate.name}**: ${mate.focus || 'See teammate prompt for details'}`);
  }

  lines.push('');
  lines.push('### Step 3: Spawn Teammates');
  lines.push('Spawn all teammates in parallel using the Task tool with run_in_background=true.');
  lines.push('');

  for (const mate of team.teammates) {
    const wtPath = worktreePaths[mate.name] || 'unknown';
    lines.push(`#### ${mate.name}`);
    lines.push('```');
    lines.push(`Task tool parameters:`);
    lines.push(`  name: "${mate.name}"`);
    lines.push(`  team_name: "${team.name}"`);
    lines.push(`  subagent_type: "${mate.subagent_type || 'general-purpose'}"`);
    lines.push(`  mode: "${mate.mode || 'bypassPermissions'}"`);
    lines.push(`  model: "${mate.model || 'sonnet'}"`);
    lines.push(`  run_in_background: true`);
    lines.push(`  prompt: |`);
    lines.push(indent(generateTeammatePrompt(mate, wtPath, projectRoot), 4));
    lines.push('```');
    lines.push('');
  }

  lines.push('### Step 4: Assign Tasks');
  lines.push('Use TaskUpdate to assign each task to the corresponding teammate by name.');

  return lines.join('\n');
}

/**
 * Generate the prompt for an individual teammate.
 */
function generateTeammatePrompt(mate, worktreePath, projectRoot) {
  const focus = (mate.focus || '')
    .replace(/\{WORKTREE_PATH\}/g, worktreePath)
    .replace(/\{PROJECT_ROOT\}/g, projectRoot)
    .replace(/\{TEAMMATE_NAME\}/g, mate.name);

  const lines = [
    `# Identity`,
    `You are "${mate.name}" — a teammate working on branch "${mate.branch}".`,
    '',
    `# Working Directory`,
    `Your worktree is at: ${worktreePath}`,
    '',
    '# Path Rules',
    '| Action | Correct | Wrong |',
    '|--------|---------|-------|',
    `| Read/Write files | ${worktreePath}/... | ${projectRoot}/... |`,
    `| Run commands | cd ${worktreePath} first | Commands in ${projectRoot} |`,
    `| Create new files | ${worktreePath}/src/... | ${projectRoot}/src/... |`,
    '',
    `CRITICAL: ALL file operations MUST use paths starting with ${worktreePath}/`,
    `NEVER use ${projectRoot}/ — that is the lead\'s project root.`,
    '',
    '# Focus',
    focus,
    '',
    '# Task Workflow',
    '1. Read your assigned task via TaskGet',
    '2. Mark it in_progress via TaskUpdate',
    '3. Do the work in your worktree',
    '4. When done, mark the task completed via TaskUpdate',
    '5. Check TaskList for more pending tasks',
    '6. Send a message to the team lead when you finish all tasks',
  ];

  return lines.join('\n');
}

/**
 * Indent every line of text by N spaces.
 */
function indent(text, spaces) {
  const pad = ' '.repeat(spaces);
  return text.split('\n').map(line => pad + line).join('\n');
}
