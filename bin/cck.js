#!/usr/bin/env node

import { readFileSync, writeFileSync, mkdirSync, existsSync, cpSync, rmSync, statSync } from 'fs';
import { join, dirname } from 'path';
import { execSync } from 'child_process';
import { fileURLToPath } from 'url';

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

const commands = { setup, teardown, status, version, prune };

if (!command || !commands[command]) {
  console.log(`cck v${VERSION} - Claude Capsule Kit`);
  console.log('');
  console.log('Commands:');
  console.log('  cck setup      Install hooks, tools, and context system');
  console.log('  cck teardown   Remove CCK (keeps capsule.db user data)');
  console.log('  cck status     Show installation status');
  console.log('  cck version    Print version');
  console.log('  cck prune [days]  Remove old records (default: 30 days)');
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

  const assetDirs = ['hooks', 'tools', 'lib'];
  for (const dir of assetDirs) {
    const src = join(PKG_ROOT, dir);
    const dest = join(CCK_DIR, dir);
    if (existsSync(src)) {
      cpSync(src, dest, { recursive: true });
      console.log(`  Copied ${dir}/`);
    }
  }

  writeFileSync(join(CCK_DIR, 'package.json'), JSON.stringify({ type: 'module' }, null, 2) + '\n');

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
  settings.hooks = hooksTemplate;
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

  if (existsSync(CCK_DIR)) {
    rmSync(CCK_DIR, { recursive: true, force: true });
    console.log('  Removed ~/.claude/cck/');
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

  const depScanner = join(BIN_DIR, 'dependency-scanner');
  const progReader = join(BIN_DIR, 'progressive-reader');
  console.log(`  dep-scanner:      ${existsSync(depScanner) ? 'installed' : 'not found'}`);
  console.log(`  progressive-reader: ${existsSync(progReader) ? 'installed' : 'not found'}`);
}

function version() {
  console.log(`cck v${VERSION}`);
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
