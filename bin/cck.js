#!/usr/bin/env node

import { readFileSync, writeFileSync, mkdirSync, existsSync, cpSync, rmSync, statSync, symlinkSync, lstatSync, readlinkSync } from 'fs';
import { join, dirname, resolve } from 'path';
import { execSync } from 'child_process';
import { fileURLToPath } from 'url';
import { homedir } from 'os';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const PKG_ROOT = join(__dirname, '..');
const CLAUDE_DIR = join(process.env.HOME, '.claude');
const CCK_DIR = join(CLAUDE_DIR, 'cck');
const SETTINGS_PATH = join(CLAUDE_DIR, 'settings.json');
const CLAUDE_MD_PATH = join(CLAUDE_DIR, 'CLAUDE.md');
const CAPSULE_DB_PATH = join(CLAUDE_DIR, 'capsule.db');
const BIN_DIR = join(CLAUDE_DIR, 'bin');

const pkg = JSON.parse(readFileSync(join(PKG_ROOT, 'package.json'), 'utf8'));
const VERSION = pkg.version;

const command = process.argv[2];

const commands = { setup, teardown, status, version, update, prune, crew };

if (!command || !commands[command]) {
  console.log(`cck v${VERSION} - Claude Capsule Kit`);
  console.log('');
  console.log('Commands:');
  console.log('  cck setup      Install hooks, tools, and context system');
  console.log('  cck teardown   Remove CCK (keeps capsule.db user data)');
  console.log('  cck status     Show installation status');
  console.log('  cck version    Print version');
  console.log('  cck update     Update CCK installation if version changed');
  console.log('  cck prune [days]  Remove old records (default: 30 days)');
  console.log('  cck crew <sub> Manage team profiles (init|start|stop|status)');
  process.exit(command ? 1 : 0);
}

try {
  await commands[command]();
} catch (err) {
  console.error(`Error running '${command}': ${err.message}`);
  process.exit(1);
}

function setup() {
  console.log(`Setting up CCK v${VERSION}...`);

  mkdirSync(CCK_DIR, { recursive: true });

  const assetDirs = ['hooks', 'tools', 'lib', 'agents', 'skills', 'commands', 'crew', 'templates'];
  for (const dir of assetDirs) {
    const src = join(PKG_ROOT, dir);
    const dest = join(CCK_DIR, dir);
    if (existsSync(src)) {
      cpSync(src, dest, { recursive: true });
      console.log(`  Copied ${dir}/`);
    }
  }

  // Symlink agents, skills, commands into ~/.claude/ for Claude Code discovery
  for (const dir of ['agents', 'skills', 'commands']) {
    const target = join(CCK_DIR, dir);
    const link = join(CLAUDE_DIR, dir);
    if (!existsSync(target)) continue;
    try {
      const stat = lstatSync(link);
      if (stat.isSymbolicLink()) {
        if (readlinkSync(link) === target) continue;
        rmSync(link);
      } else {
        rmSync(link, { recursive: true, force: true });
      }
    } catch { /* doesn't exist */ }
    symlinkSync(target, link);
    console.log(`  Linked ${dir}/ → ~/.claude/${dir}/`);
  }

  writeFileSync(join(CCK_DIR, 'package.json'), JSON.stringify({ type: 'module', version: VERSION }, null, 2) + '\n');

  console.log('  Installing blink-query...');
  try {
    execSync('npm link blink-query', { cwd: CCK_DIR, stdio: 'pipe' });
    console.log('  blink-query linked (local)');
  } catch {
    try {
      execSync('npm install blink-query', { cwd: CCK_DIR, stdio: 'pipe' });
      console.log('  blink-query installed (npm)');
    } catch {
      console.warn('  Warning: Failed to install blink-query.');
      console.warn('  Run: npm link blink-query  OR  cd ~/.claude/cck && npm install blink-query');
    }
  }

  const hooksTemplate = JSON.parse(readFileSync(join(PKG_ROOT, 'templates', 'settings-hooks.json'), 'utf8'));
  let settings = {};
  if (existsSync(SETTINGS_PATH)) {
    try {
      settings = JSON.parse(readFileSync(SETTINGS_PATH, 'utf8'));
    } catch {
      // Start fresh if settings.json is malformed
    }
  }
  // Merge CCK hooks into existing hooks (preserve user's non-CCK hooks)
  if (!settings.hooks) {
    settings.hooks = {};
  }
  settings.hooks = { ...settings.hooks, ...hooksTemplate };
  mkdirSync(dirname(SETTINGS_PATH), { recursive: true });
  writeFileSync(SETTINGS_PATH, JSON.stringify(settings, null, 2) + '\n');
  console.log('  Hooks registered in settings.json');

  const claudeMdSrc = join(PKG_ROOT, 'templates', 'CLAUDE.md');
  if (existsSync(claudeMdSrc)) {
    cpSync(claudeMdSrc, CLAUDE_MD_PATH);
    console.log('  CLAUDE.md installed');
  }

  mkdirSync(BIN_DIR, { recursive: true });
  try {
    execSync('go version', { stdio: 'pipe' });
    console.log('  Go detected, building binaries...');

    const goBinaries = [
      { name: 'dependency-scanner', src: join(PKG_ROOT, 'tools', 'dependency-scanner'), pkg: '.' },
      { name: 'progressive-reader', src: join(PKG_ROOT, 'tools', 'progressive-reader'), pkg: './cmd/' },
    ];

    for (const bin of goBinaries) {
      if (existsSync(bin.src)) {
        try {
          execSync(`go build -o ${join(BIN_DIR, bin.name)} ${bin.pkg}`, { cwd: bin.src, stdio: 'pipe' });
          console.log(`  Built ${bin.name}`);
        } catch {
          console.warn(`  Warning: Failed to build ${bin.name}`);
        }
      }
    }
  } catch {
    console.log('  Go not found, skipping binary builds (optional)');
  }

  console.log('');
  console.log(`CCK v${VERSION} setup complete!`);
}

function teardown() {
  console.log('Tearing down CCK...');

  // Remove symlinks first (before removing cck/ which is their target)
  for (const dir of ['agents', 'skills', 'commands']) {
    const link = join(CLAUDE_DIR, dir);
    try {
      if (lstatSync(link).isSymbolicLink()) {
        rmSync(link);
        console.log(`  Removed ~/.claude/${dir} symlink`);
      }
    } catch { /* not a symlink or doesn't exist */ }
  }

  if (existsSync(CCK_DIR)) {
    rmSync(CCK_DIR, { recursive: true, force: true });
    console.log('  Removed ~/.claude/cck/');
  }

  if (existsSync(BIN_DIR)) {
    rmSync(BIN_DIR, { recursive: true, force: true });
    console.log('  Removed ~/.claude/bin/');
  }

  if (existsSync(SETTINGS_PATH)) {
    try {
      const settings = JSON.parse(readFileSync(SETTINGS_PATH, 'utf8'));
      delete settings.hooks;
      writeFileSync(SETTINGS_PATH, JSON.stringify(settings, null, 2) + '\n');
      console.log('  Removed hooks from settings.json');
    } catch {
      console.warn('  Warning: Could not update settings.json');
    }
  }

  if (existsSync(CLAUDE_MD_PATH)) {
    rmSync(CLAUDE_MD_PATH);
    console.log('  Removed ~/.claude/CLAUDE.md');
  }

  // Note: capsule.db is intentionally preserved
  if (existsSync(CAPSULE_DB_PATH)) {
    console.log('  Kept ~/.claude/capsule.db (user data preserved)');
  }

  console.log('');
  console.log('CCK teardown complete.');
}

function status() {
  console.log(`CCK v${VERSION} Status`);
  console.log('─'.repeat(40));

  const hooksDir = join(CCK_DIR, 'hooks');
  console.log(`  Hooks directory:  ${existsSync(hooksDir) ? 'installed' : 'not found'}`);

  let hooksRegistered = false;
  if (existsSync(SETTINGS_PATH)) {
    try {
      const settings = JSON.parse(readFileSync(SETTINGS_PATH, 'utf8'));
      hooksRegistered = !!settings.hooks && Object.keys(settings.hooks).length > 0;
    } catch {}
  }
  console.log(`  Hooks registered: ${hooksRegistered ? 'yes' : 'no'}`);

  if (existsSync(CAPSULE_DB_PATH)) {
    const stats = statSync(CAPSULE_DB_PATH);
    const sizeKB = (stats.size / 1024).toFixed(1);
    console.log(`  Capsule database: ${sizeKB} KB`);
  } else {
    console.log('  Capsule database: not created yet');
  }

  // Agents, skills, commands
  for (const dir of ['agents', 'skills', 'commands']) {
    const link = join(CLAUDE_DIR, dir);
    try {
      const isLink = lstatSync(link).isSymbolicLink();
      console.log(`  ${dir.padEnd(18)} ${isLink ? 'linked' : 'exists (not symlink)'}`);
    } catch {
      console.log(`  ${dir.padEnd(18)} not found`);
    }
  }

  // Crew and templates directories
  for (const dir of ['crew', 'templates']) {
    const path = join(CCK_DIR, dir);
    console.log(`  ${dir.padEnd(18)} ${existsSync(path) ? 'installed' : 'not found'}`);
  }

  const depScanner = join(BIN_DIR, 'dependency-scanner');
  const progReader = join(BIN_DIR, 'progressive-reader');
  console.log(`  dep-scanner:      ${existsSync(depScanner) ? 'installed' : 'not found'}`);
  console.log(`  progressive-reader: ${existsSync(progReader) ? 'installed' : 'not found'}`);
}

function version() {
  console.log(`cck v${VERSION}`);
}

function update() {
  // Check if CCK is installed
  const installedPkgPath = join(CCK_DIR, 'package.json');

  if (!existsSync(CCK_DIR) || !existsSync(installedPkgPath)) {
    console.log('CCK is not installed yet. Run "cck setup" first.');
    return;
  }

  // Read installed version from the marker package.json
  let installedVersion = null;
  try {
    const installedPkg = JSON.parse(readFileSync(installedPkgPath, 'utf8'));
    installedVersion = installedPkg.version;
  } catch {
    // No version in installed package.json
  }

  if (!installedVersion) {
    console.log('Cannot determine installed version. Re-running setup...');
    setup();
    return;
  }

  if (installedVersion === VERSION) {
    console.log(`CCK is up to date (v${VERSION}).`);
    return;
  }

  console.log(`Updating CCK: v${installedVersion} → v${VERSION}`);
  console.log('');

  // Re-run setup
  setup();

  console.log('');
  console.log('Update complete.');
}

async function crew() {
  const sub = process.argv[3];
  const subs = { init: crewInit, start: crewStart, stop: crewStop, status: crewStatus };

  if (!sub || !subs[sub]) {
    console.log('Usage: cck crew <command>');
    console.log('');
    console.log('Commands:');
    console.log('  cck crew init              Create .crew-config.json in current directory');
    console.log('  cck crew start [profile]   Launch team (setup worktrees, generate lead prompt)');
    console.log('  cck crew stop [profile]    Stop team and update state');
    console.log('  cck crew status [profile]  Show team state (all profiles if omitted)');
    process.exit(sub ? 1 : 0);
  }

  await subs[sub]();
}

async function crewInit() {
  const dest = resolve(process.cwd(), '.crew-config.json');
  if (existsSync(dest)) {
    console.log('.crew-config.json already exists. Edit it directly.');
    return;
  }

  const template = JSON.parse(readFileSync(join(PKG_ROOT, 'templates', 'crew-config.json'), 'utf8'));

  // Auto-detect main branch
  let mainBranch = 'main';
  try {
    mainBranch = execSync('git symbolic-ref refs/remotes/origin/HEAD', {
      encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe']
    }).trim().replace('refs/remotes/origin/', '');
  } catch {
    try {
      // Fallback: check if 'main' or 'master' exists
      execSync('git rev-parse --verify main', { stdio: 'pipe' });
      mainBranch = 'main';
    } catch {
      try {
        execSync('git rev-parse --verify master', { stdio: 'pipe' });
        mainBranch = 'master';
      } catch {
        mainBranch = 'main';
      }
    }
  }

  template.project.main_branch = mainBranch;
  writeFileSync(dest, JSON.stringify(template, null, 2) + '\n');

  console.log('Created .crew-config.json');
  console.log('');
  console.log('Next steps:');
  console.log('  1. Edit .crew-config.json — set team name, add teammates');
  console.log('  2. Run: cck crew start');
}

async function crewStart() {
  const { loadCrewConfig, hashConfig, validateConfig, resolveWorktreePath, resolveProfile } = await import(
    join(PKG_ROOT, 'crew', 'lib', 'crew-config-reader.js')
  );
  const { resolveRole } = await import(
    join(PKG_ROOT, 'crew', 'lib', 'role-presets.js')
  );
  const { loadTeamState, saveTeamState, isStale: isTeammateStale, isConfigChanged } = await import(
    join(PKG_ROOT, 'crew', 'lib', 'team-state-manager.js')
  );
  const { generateLeadPrompt } = await import(
    join(PKG_ROOT, 'crew', 'lib', 'prompt-generator.js')
  );
  const { getProjectHash } = await import(
    join(PKG_ROOT, 'hooks', 'lib', 'crew-detect.js')
  );

  const projectRoot = process.cwd();
  const fresh = process.argv.includes('--fresh');
  // Profile name: first non-flag arg after "crew start"
  const profileArg = process.argv.slice(4).find(a => !a.startsWith('--'));

  // 1. Load and validate config
  let config;
  try {
    config = loadCrewConfig(projectRoot);
  } catch (err) {
    console.error('Failed to load .crew-config.json:', err.message);
    console.error('Run "cck crew init" first.');
    process.exit(1);
  }

  const errors = validateConfig(config);
  if (errors.length > 0) {
    console.error('Invalid .crew-config.json:');
    for (const e of errors) console.error(`  - ${e}`);
    process.exit(1);
  }

  // 2. Resolve profile
  let profile, profileName;
  try {
    ({ profile, profileName } = resolveProfile(config, profileArg));
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  }

  // Resolve roles for all teammates
  const resolvedTeammates = profile.teammates.map(resolveRole);
  const team = { ...profile, teammates: resolvedTeammates };

  // 3. Compute hashes and load state
  const projectHash = getProjectHash();
  const configHash = hashConfig(config);
  const existingState = loadTeamState(projectHash, profileName);

  // 4. Determine staleness threshold (profile > top-level > default 4h)
  const staleAfterHours = profile.stale_after_hours ?? config.stale_after_hours ?? 4;
  const staleAfterMs = staleAfterHours * 3600000;

  // 5. Resume decision
  let shouldResume = false;
  if (fresh) {
    console.log('--fresh flag: starting fresh team session.');
  } else if (existingState) {
    if (isConfigChanged(configHash, existingState.config_hash)) {
      console.log('Config changed since last session. Starting fresh.');
    } else {
      const anyActive = existingState.teammates &&
        Object.values(existingState.teammates).some(t => !isTeammateStale(t, staleAfterMs));
      if (anyActive) {
        shouldResume = true;
        console.log('Resumable team session found.');
      } else {
        console.log(`Previous session is stale (>${staleAfterHours}h). Starting fresh.`);
      }
    }
  }

  // 6. Setup worktrees
  const worktreePaths = { _projectRoot: projectRoot };

  for (const mate of team.teammates) {
    if (!mate.worktree) continue;

    const wtPath = resolveWorktreePath(projectRoot, mate.branch, profileName);
    worktreePaths[mate.name] = wtPath;

    if (existsSync(wtPath)) {
      console.log(`  Worktree exists: ${wtPath}`);
    } else {
      console.log(`  Creating worktree: ${wtPath} (branch: ${mate.branch})`);
      try {
        execSync(`git worktree add "${wtPath}" "${mate.branch}"`, {
          cwd: projectRoot, stdio: 'pipe'
        });
      } catch {
        try {
          const mainBranch = config.project?.main_branch || 'main';
          execSync(`git worktree add -b "${mate.branch}" "${wtPath}" "${mainBranch}"`, {
            cwd: projectRoot, stdio: 'pipe'
          });
        } catch (err) {
          console.error(`  Failed to create worktree for ${mate.name}: ${err.message}`);
          continue;
        }
      }
    }

    // Write crew-identity.json in worktree root
    const identity = {
      teammate_name: mate.name,
      project_root: projectRoot,
      branch: mate.branch,
      team_name: team.name,
      profile_name: profileName,
      created_at: new Date().toISOString()
    };
    writeFileSync(resolve(wtPath, 'crew-identity.json'), JSON.stringify(identity, null, 2) + '\n');
  }

  // 7. Write worktrees.json
  const crewDir = resolve(homedir(), '.claude', 'crew', projectHash);
  mkdirSync(crewDir, { recursive: true });
  const worktreeEntries = team.teammates
    .filter(m => m.worktree && worktreePaths[m.name])
    .map(m => ({
      name: m.name,
      branch: m.branch,
      path: worktreePaths[m.name]
    }));
  writeFileSync(
    resolve(crewDir, 'worktrees.json'),
    JSON.stringify({ worktrees: worktreeEntries }, null, 2) + '\n'
  );

  // 8. Generate lead prompt (pass resolved team and staleness threshold)
  const teamState = shouldResume ? existingState : null;
  const prompt = generateLeadPrompt(team, teamState, worktreePaths, configHash, staleAfterMs);

  // 9. Save state
  const newState = {
    team_name: team.name,
    profile_name: profileName,
    config_hash: configHash,
    status: 'active',
    started_at: shouldResume ? (existingState.started_at || new Date().toISOString()) : new Date().toISOString(),
    updated_at: new Date().toISOString(),
    teammates: {}
  };

  for (const mate of team.teammates) {
    const prev = existingState?.teammates?.[mate.name];
    newState.teammates[mate.name] = {
      branch: mate.branch,
      worktree_path: worktreePaths[mate.name] || null,
      status: shouldResume && prev ? prev.status : 'pending',
      agent_id: shouldResume && prev ? prev.agent_id : null,
      last_active: shouldResume && prev ? prev.last_active : null
    };
  }

  saveTeamState(projectHash, newState, profileName);

  // 10. Output prompt
  const promptPath = resolve(crewDir, profileName, 'lead-prompt.md');
  mkdirSync(resolve(crewDir, profileName), { recursive: true });
  writeFileSync(promptPath, prompt + '\n');

  console.log('');
  console.log(`Team "${team.name}" (profile: ${profileName}) ready.`);
  console.log(`Lead prompt saved to: ${promptPath}`);
  console.log('');
  console.log('Copy the prompt below and paste it into Claude Code to launch the team:');
  console.log('─'.repeat(60));
  console.log(prompt);
}

async function crewStop() {
  const { loadCrewConfig, resolveProfile } = await import(
    join(PKG_ROOT, 'crew', 'lib', 'crew-config-reader.js')
  );
  const { loadTeamState, saveTeamState, listProfiles } = await import(
    join(PKG_ROOT, 'crew', 'lib', 'team-state-manager.js')
  );
  const { getProjectHash } = await import(
    join(PKG_ROOT, 'hooks', 'lib', 'crew-detect.js')
  );

  const projectRoot = process.cwd();
  const projectHash = getProjectHash();
  const cleanup = process.argv.includes('--cleanup');
  const profileArg = process.argv.slice(4).find(a => !a.startsWith('--'));

  // Determine which profile(s) to stop
  let profilesToStop = [];
  if (profileArg) {
    profilesToStop = [profileArg];
  } else {
    // Try to resolve from config, fall back to 'default'
    try {
      const config = loadCrewConfig(projectRoot);
      const { profileName } = resolveProfile(config);
      profilesToStop = [profileName];
    } catch {
      profilesToStop = ['default'];
    }
  }

  for (const pName of profilesToStop) {
    const state = loadTeamState(projectHash, pName);
    if (!state) {
      console.log(`No active team session found for profile "${pName}".`);
      continue;
    }

    for (const name of Object.keys(state.teammates || {})) {
      state.teammates[name].status = 'stopped';
    }
    state.status = 'stopped';
    saveTeamState(projectHash, state, pName);
    console.log(`Team "${state.team_name}" (profile: ${pName}) stopped.`);

    if (cleanup) {
      for (const [name, mate] of Object.entries(state.teammates || {})) {
        if (mate.worktree_path && existsSync(mate.worktree_path)) {
          console.log(`  Removing worktree: ${mate.worktree_path}`);
          try {
            execSync(`git worktree remove "${mate.worktree_path}" --force`, {
              cwd: projectRoot, stdio: 'pipe'
            });
          } catch (err) {
            console.warn(`  Warning: Could not remove worktree for ${name}: ${err.message}`);
          }
        }
      }
      console.log('Worktrees cleaned up.');
    }
  }
}

async function crewStatus() {
  const { loadTeamState, listProfiles } = await import(
    join(PKG_ROOT, 'crew', 'lib', 'team-state-manager.js')
  );
  const { getProjectHash } = await import(
    join(PKG_ROOT, 'hooks', 'lib', 'crew-detect.js')
  );

  const projectHash = getProjectHash();
  const profileArg = process.argv.slice(4).find(a => !a.startsWith('--'));

  // Determine which profiles to show
  let profilesToShow;
  if (profileArg) {
    profilesToShow = [profileArg];
  } else {
    // Show all profiles that have state
    profilesToShow = listProfiles(projectHash);
    if (profilesToShow.length === 0) {
      console.log('No team state found. Run "cck crew start" first.');
      return;
    }
  }

  for (let idx = 0; idx < profilesToShow.length; idx++) {
    const pName = profilesToShow[idx];
    const state = loadTeamState(projectHash, pName);

    if (!state) {
      console.log(`No team state found for profile "${pName}".`);
      continue;
    }

    if (idx > 0) console.log('');

    const ageHours = Math.round((Date.now() - new Date(state.updated_at).getTime()) / 3600000);

    console.log(`Profile: ${pName}`);
    console.log(`Team: ${state.team_name}`);
    console.log(`Status: ${state.status} (updated ${ageHours}h ago)`);
    console.log(`Config hash: ${state.config_hash}`);
    console.log('─'.repeat(60));
    console.log('  Name'.padEnd(22) + 'Status'.padEnd(12) + 'Branch'.padEnd(30) + 'Agent ID');
    console.log('─'.repeat(60));

    for (const [name, mate] of Object.entries(state.teammates || {})) {
      const agentId = mate.agent_id ? mate.agent_id.slice(0, 12) + '...' : 'none';
      console.log(
        `  ${name.padEnd(20)}${(mate.status || 'unknown').padEnd(12)}${(mate.branch || '').padEnd(30)}${agentId}`
      );
    }
  }
}

async function prune() {
  if (!existsSync(CAPSULE_DB_PATH)) {
    console.log('No database found. Nothing to prune.');
    return;
  }

  const days = parseInt(process.argv[3]) || 30;
  const dryRun = process.argv.includes('--dry-run');
  const cutoff = new Date(Date.now() - days * 86400000).toISOString();

  const { Blink } = await import('blink-query');
  const blink = new Blink({ dbPath: CAPSULE_DB_PATH });

  const stale = blink.db.prepare(
    'SELECT COUNT(*) as count FROM records WHERE updated_at < ?'
  ).get(cutoff);

  if (stale.count === 0) {
    console.log(`No records older than ${days} days.`);
    blink.close();
    return;
  }

  if (dryRun) {
    console.log(`Would prune ${stale.count} records older than ${days} days.`);
    blink.close();
    return;
  }

  const result = blink.db.prepare(
    'DELETE FROM records WHERE updated_at < ?'
  ).run(cutoff);

  console.log(`Pruned ${result.changes} records older than ${days} days.`);
  blink.close();
}
