# Capsule Kit v3.0 - Usage Guide

## For Claude: How to Use This System Effectively

Capsule Kit v3.0 uses **Capsule** (SQLite) for automatic context tracking. No manual logging needed — JS hooks capture everything.

---

## Core Principle

**Context is automatic.** The Capsule hooks handle all logging:

| Hook | When | What It Captures |
|------|------|-----------------|
| `session-start.js` | Session begins | Injects last session summary, recent files, team activity |
| `post-tool-use.js` | After Read/Write/Edit/Task | File operations (META), sub-agent invocations (SUMMARY) |
| `session-end.js` | Session ends | Session summary with file count, agent count |

**You don't need to call any logging scripts.** Just work normally.

---

## What Gets Tracked Automatically

### File Operations
Every Read/Write/Edit is captured as a META record with:
- File path and action type
- Timestamp
- Session ID
- Crew teammate name (in crew mode)

### Sub-Agent Results
Every Task tool invocation is captured as a SUMMARY record with:
- Agent type (e.g., `error-detective`, `architecture-explorer`)
- Prompt summary (first 200 chars)
- Timestamp

### Session Summaries
At session end, a META record captures:
- Total files accessed
- Total sub-agents used
- Session duration

---

## Capsule Record Types

Records have a `type` field that tells you how to consume them:

| Type | Meaning | How to Use |
|------|---------|-----------|
| `SUMMARY` | Read the summary directly — you have what you need | Sub-agent findings, discoveries |
| `META` | Structured data in JSON `content` field | File operations, session metadata |
| `COLLECTION` | Browse children, pick what's relevant | Groups of related records |
| `SOURCE` | Summary here, fetch source if you need depth | External references |
| `ALIAS` | Follow the redirect to the target record | Pointers |

---

## Capsule Namespaces

### Solo Mode
```
session/{session_id}/files       -- File operation records (META)
session/{session_id}/subagents   -- Sub-agent invocation records (SUMMARY)
session                          -- Session summary records (META)
discoveries                      -- Architectural discoveries
```

### Crew Mode (Agent Teams with worktrees)
```
crew/{teammate_name}/session/{session_id}/files       -- Teammate file ops
crew/{teammate_name}/session/{session_id}/subagents   -- Teammate sub-agents
crew/{teammate_name}/session                          -- Teammate session summaries
crew/_shared/discoveries                              -- Shared team discoveries
```

All teammates share the same `capsule.db` in the main project root. Crew identity is detected automatically via worktree registry.

---

## Context at Session Start

When a session starts, `session-start.js` injects context automatically:

1. **Last Session** — Summary of the most recent session
2. **Top Discoveries** — Most-accessed architectural insights
3. **Recent Files** — Last 3 files worked on
4. **Team Activity** (crew mode) — What other teammates have been doing

This context appears in your prompt without any action needed.

---

## Sub-Agent Production Safety

All sub-agents are **read-only** for production safety:

**Sub-agents CAN:**
- Read files (Read tool)
- Search code (Grep tool)
- Find files (Glob tool)
- Fetch web content (WebFetch — select agents only)

**Sub-agents CANNOT:**
- Execute bash commands
- Modify files (no Edit/Write tools)
- Delete files or run destructive operations

---

## Efficient Workflow Patterns

### Pattern 1: Just Work

With Capsule, the workflow is simple:

```
1. Session starts → context injected automatically
2. Work normally → hooks capture everything
3. Session ends → summary saved automatically
```

No manual check/log/persist cycle needed.

### Pattern 2: Parallel Agent Spawning

```
# DON'T (sequential):
Message 1: Task(subagent_type="agent-1", ...)
Message 2: Task(subagent_type="agent-2", ...)

# DO (parallel, single message):
Task(subagent_type="agent-1", ...)
Task(subagent_type="agent-2", ...)
Task(subagent_type="agent-3", ...)
# All run simultaneously
```

### Pattern 3: Progressive File Reading

```bash
# Large file (>50KB) — DON'T:
Read(file_path="large-file.ts")  # Might fail or waste tokens

# DO:
$HOME/.claude/bin/progressive-reader --path large-file.ts --list   # Structure
$HOME/.claude/bin/progressive-reader --path large-file.ts --chunk 2  # Specific chunk
# 75-97% token savings
```

### Pattern 4: Tool Selection Hierarchy

```
Dependency question?  → query-deps / impact-analysis (NOT Task/Explore)
Large file (>50KB)?   → progressive-reader (NOT Read)
File/code search?     → Glob / Grep (NOT Task/Explore)
Complex analysis?     → Task with specialist agent
```

---

## Integration with Skills

Skills automate best practices:

| Skill | Purpose |
|-------|---------|
| `/workflow` | Systematic multi-step task orchestration |
| `/debug` | RCA-first debugging with error-detective |
| `/code-review` | Pre-commit quality gate |
| `/deep-context` | Build codebase understanding |

---

## Quick Checklist

Before starting any task:

- [ ] Review injected context (appears automatically at session start)
- [ ] Use specialized tools (not Task/Explore) for deps/search
- [ ] Launch agents for deep work (parallel when possible)
- [ ] Use progressive-reader for large files

**That's it.** No manual logging, no capsule management, no memory-graph commands. Capsule handles persistence automatically.
