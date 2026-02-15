#!/usr/bin/env node
/**
 * Stats Tool v3.0 - Query Capsule for usage analytics
 * Uses blink-query for namespace/type-aware querying
 */

import { Blink } from 'blink-query';
import { existsSync } from 'fs';
import { dirname, join } from 'path';
import { homedir } from 'os';
import { createHash } from 'crypto';
import { execSync } from 'child_process';

function findCapsuleDb() {
  const globalDb = join(homedir(), '.claude', 'capsule.db');
  if (existsSync(globalDb)) return globalDb;
  let dir = process.cwd();
  while (dir !== '/') {
    const dbPath = join(dir, '.claude', 'capsule.db');
    if (existsSync(dbPath)) return dbPath;
    dir = dirname(dir);
  }
  return null;
}

function getProjectHash() {
  let identifier;
  try {
    identifier = execSync('git remote get-url origin', { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
  } catch {
    identifier = process.cwd();
  }
  return createHash('sha256').update(identifier).digest('hex').slice(0, 12);
}

function getCurrentBranch() {
  try {
    return execSync('git branch --show-current', { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
  } catch {
    return null;
  }
}

function getAllRecords(blink) {
  const hash = getProjectHash();
  let projRecords = [];
  try { projRecords = blink.list(`proj/${hash}/session`, 'recent'); } catch { /* no proj records */ }
  let projCrew = [];
  try { projCrew = blink.list(`proj/${hash}/crew`, 'recent'); } catch { /* no crew records */ }
  let solo = [];
  try { solo = blink.list('session', 'recent'); } catch { /* no legacy records */ }
  let crew = [];
  try { crew = blink.list('crew', 'recent'); } catch { /* no crew records */ }
  return [...projRecords, ...projCrew, ...solo, ...crew];
}

function getBranchRecords(blink, branchName) {
  const hash = getProjectHash();
  const branchNs = `proj/${hash}/branch/${branchName}`;
  let records = [];
  try {
    records = blink.list(branchNs, 'recent');
  } catch { /* no branch records */ }
  return records;
}

const dbPath = findCapsuleDb();
if (!dbPath) {
  console.log('No capsule.db found. Stats will be available after your first session.');
  process.exit(0);
}

const blink = new Blink({ dbPath });
const [,, cmd = 'help', arg] = process.argv;

try {
  switch (cmd) {
    case 'overview': {
      const all = getAllRecords(blink);

      // Count sessions (unique session IDs in namespaces)
      const sessions = new Set();
      all.forEach(r => {
        const match = r.namespace?.match(/session\/([^/]+)/);
        if (match) sessions.add(match[1]);
      });

      // Count files and agents
      const fileRecords = all.filter(r => r.namespace?.includes('/files'));
      const agentRecords = all.filter(r => r.namespace?.includes('/subagents'));

      // Top 5 files (by frequency)
      const fileCounts = {};
      fileRecords.forEach(r => {
        const file = r.title || 'unknown';
        fileCounts[file] = (fileCounts[file] || 0) + 1;
      });
      const topFiles = Object.entries(fileCounts)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5);

      // Top 5 agents (by frequency)
      const agentCounts = {};
      agentRecords.forEach(r => {
        const agent = r.title?.split(':')[0] || 'unknown';
        agentCounts[agent] = (agentCounts[agent] || 0) + 1;
      });
      const topAgents = Object.entries(agentCounts)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5);

      console.log('## Capsule Stats Overview\n');
      console.log(`Total records:  ${all.length}`);
      console.log(`Sessions:       ${sessions.size}`);
      console.log(`File ops:       ${fileRecords.length}`);
      console.log(`Sub-agents:     ${agentRecords.length}`);

      if (topFiles.length > 0) {
        console.log('\nTop 5 Files:');
        topFiles.forEach(([file, count]) => {
          console.log(`  ${count.toString().padStart(3)}× ${file}`);
        });
      }

      if (topAgents.length > 0) {
        console.log('\nTop 5 Agents:');
        topAgents.forEach(([agent, count]) => {
          console.log(`  ${count.toString().padStart(3)}× ${agent}`);
        });
      }
      break;
    }

    case 'files': {
      const limit = parseInt(arg) || 50;
      const all = getAllRecords(blink);
      const fileRecords = all.filter(r => r.namespace?.includes('/files'));

      // Count by file
      const fileCounts = {};
      fileRecords.forEach(r => {
        const file = r.title || 'unknown';
        fileCounts[file] = (fileCounts[file] || 0) + 1;
      });

      const ranked = Object.entries(fileCounts)
        .sort((a, b) => b[1] - a[1])
        .slice(0, limit);

      console.log(`## Most Accessed Files (top ${limit})\n`);
      if (ranked.length === 0) {
        console.log('No file operations recorded yet');
      } else {
        ranked.forEach(([file, count], idx) => {
          console.log(`${(idx + 1).toString().padStart(3)}. ${count.toString().padStart(3)}× ${file}`);
        });
      }
      break;
    }

    case 'agents': {
      const limit = parseInt(arg) || 20;
      const all = getAllRecords(blink);
      const agentRecords = all.filter(r => r.namespace?.includes('/subagents'));

      // Count by agent type (extract from title)
      const agentCounts = {};
      agentRecords.forEach(r => {
        const agent = r.title?.split(':')[0] || 'unknown';
        agentCounts[agent] = (agentCounts[agent] || 0) + 1;
      });

      const ranked = Object.entries(agentCounts)
        .sort((a, b) => b[1] - a[1])
        .slice(0, limit);

      console.log(`## Most Used Sub-Agents (top ${limit})\n`);
      if (ranked.length === 0) {
        console.log('No sub-agent records found');
      } else {
        ranked.forEach(([agent, count], idx) => {
          console.log(`${(idx + 1).toString().padStart(3)}. ${count.toString().padStart(3)}× ${agent}`);
        });
      }
      break;
    }

    case 'sessions': {
      const limit = parseInt(arg) || 10;
      const all = getAllRecords(blink);

      // Group records by session
      const sessionMap = {};
      all.forEach(r => {
        const match = r.namespace?.match(/session\/([^/]+)/);
        if (match) {
          const sid = match[1];
          if (!sessionMap[sid]) {
            sessionMap[sid] = { files: 0, agents: 0, records: [] };
          }
          sessionMap[sid].records.push(r);
          if (r.namespace?.includes('/files')) sessionMap[sid].files++;
          if (r.namespace?.includes('/subagents')) sessionMap[sid].agents++;
        }
      });

      // Sort by most recent (use latest created_at in each session)
      const sessions = Object.entries(sessionMap)
        .map(([sid, data]) => {
          const latest = Math.max(...data.records.map(r => new Date(r.created_at || 0).getTime()));
          return { sid, ...data, latest };
        })
        .sort((a, b) => b.latest - a.latest)
        .slice(0, limit);

      console.log(`## Recent Sessions (last ${limit})\n`);
      if (sessions.length === 0) {
        console.log('No session records found');
      } else {
        sessions.forEach((s, idx) => {
          const date = new Date(s.latest).toISOString().split('T')[0];
          console.log(`${(idx + 1).toString().padStart(2)}. ${s.sid.slice(0, 12)}... (${date}) — ${s.files} files, ${s.agents} agents`);
        });
      }
      break;
    }

    case 'branch': {
      const branchName = arg || getCurrentBranch();
      if (!branchName) {
        console.log('Error: Not in a git repository or no branch name provided');
        console.log('Usage: stats branch [branch-name]');
        process.exit(1);
      }

      const branchRecords = getBranchRecords(blink, branchName);
      const allRecords = getAllRecords(blink);

      // Filter all records by branch (check if namespace contains branch name)
      const branchFiltered = allRecords.filter(r =>
        r.namespace?.includes(`branch/${branchName}`) ||
        r.tags?.includes(`branch:${branchName}`)
      );

      const combined = [...branchRecords, ...branchFiltered];

      if (combined.length === 0) {
        console.log(`## Branch Stats: ${branchName}\n`);
        console.log('No records found for this branch yet.');
        break;
      }

      // Count files and agents for this branch
      const fileRecords = combined.filter(r => r.namespace?.includes('/files'));
      const agentRecords = combined.filter(r => r.namespace?.includes('/subagents'));

      // Top files for this branch
      const fileCounts = {};
      fileRecords.forEach(r => {
        const file = r.title || 'unknown';
        fileCounts[file] = (fileCounts[file] || 0) + 1;
      });
      const topFiles = Object.entries(fileCounts)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5);

      console.log(`## Branch Stats: ${branchName}\n`);
      console.log(`Total records:  ${combined.length}`);
      console.log(`File ops:       ${fileRecords.length}`);
      console.log(`Sub-agents:     ${agentRecords.length}`);

      if (topFiles.length > 0) {
        console.log('\nTop Files:');
        topFiles.forEach(([file, count]) => {
          console.log(`  ${count.toString().padStart(3)}× ${file}`);
        });
      }
      break;
    }

    default:
      console.log('## Capsule Stats Tool\n');
      console.log('Usage: bash $HOME/.claude/cck/tools/stats/stats.sh <command> [args]\n');
      console.log('Commands:');
      console.log('  overview           Session count, record count, top files, top agents');
      console.log('  files [limit]      Most accessed files ranked (default: 50)');
      console.log('  agents [limit]     Most used sub-agents ranked (default: 20)');
      console.log('  sessions [limit]   Session history with file/agent counts (default: 10)');
      console.log('  branch [name]      Stats scoped to current or named git branch');
      console.log('');
      console.log('Examples:');
      console.log('  cck stats overview');
      console.log('  cck stats files 20');
      console.log('  cck stats agents');
      console.log('  cck stats branch feature/new-feature');
  }
} finally {
  blink.close();
}
