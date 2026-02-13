#!/usr/bin/env node
/**
 * Context-Query Tool v3.0 - Query Blink context database
 * Uses blink-query for proper namespace/type-aware querying
 *
 * Usage: node $HOME/.claude/cck/tools/context-query/context-query.js <command> [args]
 */

import { Blink } from 'blink-query';
import { existsSync } from 'fs';
import { dirname, join } from 'path';
import { homedir } from 'os';
import { createHash } from 'crypto';
import { execSync } from 'child_process';

// Find blink.db - check global path first, then walk up from CWD
function findBlinkDb() {
  // Global installation: check ~/.claude/blink.db first
  const globalDb = join(homedir(), '.claude', 'blink.db');
  if (existsSync(globalDb)) return globalDb;
  // Fallback: walk up from CWD (for development/testing)
  let dir = process.cwd();
  while (dir !== '/') {
    const dbPath = join(dir, '.claude', 'blink.db');
    if (existsSync(dbPath)) return dbPath;
    dir = dirname(dir);
  }
  return null;
}

// Compute project hash for namespace scoping
function getProjectHash() {
  let identifier;
  try {
    identifier = execSync('git remote get-url origin', { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
  } catch {
    identifier = process.cwd();
  }
  return createHash('sha256').update(identifier).digest('hex').slice(0, 12);
}

// Helper: get all records from project-scoped session tree
function getAllRecords(blink) {
  const hash = getProjectHash();
  // Try project-scoped namespaces first (global mode)
  let projRecords = [];
  try { projRecords = blink.list(`proj/${hash}/session`, 'recent'); } catch { /* no proj records */ }
  let projCrew = [];
  try { projCrew = blink.list(`proj/${hash}/crew`, 'recent'); } catch { /* no crew records */ }
  // Also try legacy namespaces (pre-global mode)
  let solo = [];
  try { solo = blink.list('session', 'recent'); } catch { /* no legacy records */ }
  let crew = [];
  try { crew = blink.list('crew', 'recent'); } catch { /* no crew records */ }
  return [...projRecords, ...projCrew, ...solo, ...crew];
}

const dbPath = findBlinkDb();
if (!dbPath) {
  console.log('No blink.db found. Context will be available after your first session.');
  process.exit(0);
}

const blink = new Blink({ dbPath });
const [,, cmd = 'help', arg, limitArg] = process.argv;

try {
  switch (cmd) {
    case 'search': {
      if (!arg) {
        console.log('Usage: context-query search <term>');
        process.exit(1);
      }
      const results = blink.search(arg, undefined, parseInt(limitArg) || 10);
      console.log(`## Blink Search: ${arg}\n`);
      if (results.length === 0) {
        console.log(`No results found for '${arg}'`);
      } else {
        results.forEach(r => {
          console.log(`- **[${r.type}]** ${r.title}`);
          if (r.summary) console.log(`  ${r.summary.replace(/\n/g, ' ').slice(0, 120)}`);
        });
      }
      break;
    }

    case 'files': {
      const limit = parseInt(arg) || 20;
      const all = getAllRecords(blink);
      const fileRecords = all.filter(r => r.namespace?.includes('/files')).slice(0, limit);
      console.log(`## Recent File Operations (${fileRecords.length})\n`);
      if (fileRecords.length === 0) {
        console.log('No file operations recorded yet');
      } else {
        fileRecords.forEach(r => {
          console.log(`- **${r.title}**: ${r.summary?.replace(/\n/g, ' ').slice(0, 100) || ''}`);
        });
      }
      break;
    }

    case 'agents': {
      const limit = parseInt(arg) || 10;
      const all = getAllRecords(blink);
      const agentRecords = all.filter(r => r.namespace?.includes('/subagents')).slice(0, limit);
      console.log(`## Sub-Agent History (${agentRecords.length})\n`);
      if (agentRecords.length === 0) {
        console.log('No sub-agent records found');
      } else {
        agentRecords.forEach(r => {
          console.log(`- **${r.title}**`);
          if (r.summary) console.log(`  ${r.summary.replace(/\n/g, ' ').slice(0, 120)}`);
        });
      }
      break;
    }

    case 'sessions': {
      const limit = parseInt(arg) || 5;
      const all = getAllRecords(blink);
      const sessionRecords = all.filter(r =>
        r.namespace?.endsWith('/session') || r.namespace === 'session' || (r.namespace?.includes('crew') && r.type === 'META')
      ).slice(0, limit);
      console.log(`## Session History (${sessionRecords.length})\n`);
      if (sessionRecords.length === 0) {
        console.log('No session records found');
      } else {
        sessionRecords.forEach(r => {
          console.log(`- **${r.title}**`);
          if (r.summary) console.log(`  ${r.summary.replace(/\n/g, ' ').slice(0, 120)}`);
        });
      }
      break;
    }

    case 'recent': {
      const limit = parseInt(arg) || 15;
      const all = getAllRecords(blink).slice(0, limit);
      console.log(`## Recent Activity (${all.length})\n`);
      all.forEach(r => {
        console.log(`- [${r.type}] **${r.title}** (${r.namespace})`);
        if (r.summary) console.log(`  ${r.summary.replace(/\n/g, ' ').slice(0, 80)}`);
      });
      break;
    }

    case 'ns': {
      if (!arg) {
        console.log('Usage: context-query ns <namespace> [limit]');
        console.log('Example: context-query ns "session" 10');
        process.exit(1);
      }
      const limit = parseInt(limitArg) || 10;
      const results = blink.query(`${arg} limit ${limit}`);
      console.log(`## Namespace: ${arg} (${results.length})\n`);
      if (results.length === 0) {
        console.log('No records in this namespace');
      } else {
        results.forEach(r => {
          console.log(`- **[${r.type}]** ${r.title}`);
          if (r.summary) console.log(`  ${r.summary.replace(/\n/g, ' ').slice(0, 120)}`);
        });
      }
      break;
    }

    case 'save': {
      // save <namespace> <title> <summary> [type]
      // e.g.: context-query save discoveries/auth "OAuth flow" "Uses PKCE with refresh tokens" SUMMARY
      if (!arg) {
        console.log('Usage: context-query save <namespace> <title> <summary> [type]');
        console.log('Types: SUMMARY (default), META, COLLECTION, SOURCE, ALIAS');
        console.log('');
        console.log('Examples:');
        console.log('  save discoveries "OAuth flow" "Uses PKCE with refresh tokens"');
        console.log('  save session/notes "DB schema" "Users table has soft deletes" META');
        process.exit(1);
      }
      const namespace = arg;
      const title = process.argv[4];
      const summary = process.argv[5];
      const type = process.argv[6] || 'SUMMARY';
      if (!title || !summary) {
        console.log('Error: title and summary are required');
        console.log('Usage: context-query save <namespace> <title> <summary> [type]');
        process.exit(1);
      }
      blink.save({ namespace, title, summary, type, tags: [] });
      console.log(`Saved to ${namespace}: "${title}" [${type}]`);
      break;
    }

    case 'update': {
      // update <search-term> <new-summary>
      // Finds the most recent record matching search-term and updates its summary
      if (!arg) {
        console.log('Usage: context-query update <search-term> <new-summary>');
        console.log('');
        console.log('Finds the most recent record matching the search term and updates it.');
        console.log('');
        console.log('Examples:');
        console.log('  update "OAuth flow" "Now uses PKCE + DPoP with 15min token expiry"');
        process.exit(1);
      }
      const searchTerm = arg;
      const newSummary = process.argv[4];
      if (!newSummary) {
        console.log('Error: new summary is required');
        process.exit(1);
      }
      const matches = blink.search(searchTerm, undefined, 1);
      if (matches.length === 0) {
        console.log(`No record found matching '${searchTerm}'`);
        process.exit(1);
      }
      const record = matches[0];
      // Re-save with updated summary (blink upserts by namespace+title)
      blink.save({
        namespace: record.namespace,
        title: record.title,
        summary: newSummary,
        type: record.type,
        tags: record.tags || []
      });
      console.log(`Updated "${record.title}" in ${record.namespace}`);
      console.log(`  Old: ${record.summary?.replace(/\n/g, ' ').slice(0, 80)}`);
      console.log(`  New: ${newSummary.slice(0, 80)}`);
      break;
    }

    case 'stats': {
      const all = getAllRecords(blink);
      const byType = {};
      let files = 0, agents = 0;
      const sessions = new Set();
      all.forEach(r => {
        byType[r.type] = (byType[r.type] || 0) + 1;
        if (r.namespace?.includes('/files')) files++;
        if (r.namespace?.includes('/subagents')) agents++;
        const match = r.namespace?.match(/session\/([^/]+)/);
        if (match) sessions.add(match[1]);
      });
      console.log(`## Blink Stats\n`);
      console.log(`- Total records: ${all.length}`);
      console.log(`- Files tracked: ${files}`);
      console.log(`- Sub-agents: ${agents}`);
      console.log(`- Sessions: ${sessions.size}`);
      console.log(`- Types: ${Object.entries(byType).map(([k,v]) => `${k}(${v})`).join(', ')}`);
      break;
    }

    default:
      console.log(`## Blink Context Query\n`);
      console.log(`Usage: bash $HOME/.claude/cck/tools/context-query/context-query.sh <command> [args]\n`);
      console.log(`Read:`);
      console.log(`  search <term>      Search records by keyword`);
      console.log(`  files [limit]      Recent file operations (default: 20)`);
      console.log(`  agents [limit]     Sub-agent invocation history (default: 10)`);
      console.log(`  sessions [limit]   Session summaries (default: 5)`);
      console.log(`  recent [limit]     All recent activity (default: 15)`);
      console.log(`  ns <namespace>     Query specific Blink namespace`);
      console.log(`  stats              Database statistics`);
      console.log(``);
      console.log(`Write:`);
      console.log(`  save <ns> <title> <summary> [type]   Save a record`);
      console.log(`  update <search> <new-summary>        Update most recent match`);
  }
} finally {
  blink.close();
}
