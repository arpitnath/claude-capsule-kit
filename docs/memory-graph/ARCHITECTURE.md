# Claude Memory Graph - Architecture Document

> **Version**: 1.0.0
> **Status**: Design Finalized
> **Date**: 2025-12-08

## Executive Summary

The Claude Memory Graph is a persistent knowledge system that transforms Claude from a stateless assistant into a cumulative learning agent. Using an Obsidian-inspired architecture of linked markdown files, it enables Claude to remember file summaries, architectural decisions, discoveries, and session context across conversations.

---

## Problem Statement

### Current Limitations

| Issue | Impact |
|-------|--------|
| **Session Amnesia** | Every session starts from zero context |
| **Repeated Work** | Must re-read and re-understand files |
| **Lost Decisions** | "We decided X" forgotten next session |
| **No Pattern Learning** | Can't build up codebase understanding |
| **Context Ceiling** | 200k tokens, then summarize and forget |

### Goal

Create a prosthetic memory system that:
1. Persists knowledge across sessions
2. Automatically captures file summaries and discoveries
3. Links related concepts into a queryable graph
4. Injects relevant context at the right moments
5. Grows smarter about YOUR specific project over time

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           CLAUDE CODE SESSION                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                  │
│  │ SessionStart│───►│UserPrompt   │───►│ PostToolUse │                  │
│  │    Hook     │    │ Submit Hook │    │    Hook     │                  │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘                  │
│         │                  │                  │                          │
│         │ Load             │ Query            │ Capture                  │
│         │ Context          │ Relevant         │ Knowledge                │
│         ▼                  ▼                  ▼                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                      MEMORY GRAPH LAYER                          │    │
│  ├─────────────────────────────────────────────────────────────────┤    │
│  │                                                                  │    │
│  │   ┌──────────────┐      ┌──────────────┐      ┌─────────────┐   │    │
│  │   │ Node Parser  │◄────►│ Graph Cache  │◄────►│ Query Engine│   │    │
│  │   │  (Python)    │      │  (JSON)      │      │   (Python)  │   │    │
│  │   └──────────────┘      └──────────────┘      └─────────────┘   │    │
│  │          │                    │                      │          │    │
│  │          ▼                    ▼                      ▼          │    │
│  │   ┌─────────────────────────────────────────────────────────┐   │    │
│  │   │                  FILESYSTEM STORAGE                      │   │    │
│  │   │                                                          │   │    │
│  │   │   .claude/memory/                                        │   │    │
│  │   │   ├── nodes/           # Markdown knowledge nodes        │   │    │
│  │   │   ├── graph.json       # Computed link cache             │   │    │
│  │   │   └── index.md         # Entry point / recent context    │   │    │
│  │   │                                                          │   │    │
│  │   └─────────────────────────────────────────────────────────┘   │    │
│  │                                                                  │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. Memory Nodes (Markdown Files)

Each piece of knowledge is stored as a markdown file with YAML frontmatter.

#### Directory Structure

```
.claude/memory/
├── nodes/
│   ├── files/                    # File summaries
│   │   ├── src-auth-ts.md
│   │   ├── src-api-routes-ts.md
│   │   └── ...
│   ├── decisions/                # Architectural decisions
│   │   ├── decision-001-jwt-auth.md
│   │   ├── decision-002-redis-cache.md
│   │   └── ...
│   ├── discoveries/              # Learned insights
│   │   ├── discovery-pattern-repository.md
│   │   ├── discovery-error-handling.md
│   │   └── ...
│   ├── sessions/                 # Session summaries
│   │   ├── session-2025-12-08-abc123.md
│   │   └── ...
│   ├── tasks/                    # Task context
│   │   ├── task-fix-auth-bug.md
│   │   └── ...
│   └── errors/                   # Error learnings
│       ├── error-circular-import.md
│       └── ...
├── graph.json                    # Computed metadata cache
├── index.md                      # Entry point with recent context
└── config.json                   # Memory system configuration
```

#### Node Schema

All nodes share a common YAML frontmatter structure:

```yaml
---
# Required fields
id: <unique-identifier>
type: file-summary | decision | discovery | session | task | error
created: <ISO-8601 timestamp>
updated: <ISO-8601 timestamp>

# Optional fields
tags: [<tag1>, <tag2>]
related: [[<node-id>], [<node-id>]]
status: active | archived | superseded
supersedes: <node-id>           # For decisions that replace older ones
path: <file-path>               # For file-summary nodes
session_id: <session-id>        # For session-scoped nodes
---
```

### 2. Node Types

#### 2.1 File Summary Node

Created automatically for large files (>50KB) or manually for important files.

```markdown
---
id: file-src-auth-ts
type: file-summary
path: /src/auth.ts
created: 2025-12-08T10:30:00Z
updated: 2025-12-08T14:20:00Z
tags: [auth, security, jwt, middleware]
related: [[file-src-config-ts]], [[discovery-jwt-pattern]]
status: active
file_size: 12500
line_count: 450
language: typescript
---

# /src/auth.ts

## Purpose
JWT authentication module handling user login, token verification, and session management.

## Key Exports
- `login(credentials)` - Validates credentials, returns JWT
- `verifyToken(token)` - Middleware for protected routes
- `refreshToken(token)` - Token refresh logic
- `logout(userId)` - Invalidates session in Redis

## Dependencies
- Uses [[file-src-config-ts]] for JWT secret
- Connects to Redis via [[file-src-redis-client-ts]]

## Patterns
- Repository pattern for user lookup
- Middleware composition for route protection

## Notes
- Token expiry: 15 minutes (access), 7 days (refresh)
- Sessions stored in Redis with prefix `session:`
```

#### 2.2 Decision Node

Created when architectural or implementation decisions are made.

```markdown
---
id: decision-001-jwt-auth
type: decision
created: 2025-12-08T11:00:00Z
updated: 2025-12-08T11:00:00Z
tags: [auth, security, architecture]
related: [[file-src-auth-ts]], [[discovery-jwt-pattern]]
status: active
supersedes: null
---

# Decision: Use JWT with Redis Session Store

## Context
User asked about session management for the API. Need stateless auth that can scale horizontally while maintaining ability to invalidate sessions.

## Decision
Use JWT tokens for stateless authentication, with Redis for session invalidation (blacklist approach).

## Alternatives Considered
1. **Session cookies** - Rejected: Requires sticky sessions, doesn't scale
2. **JWT only** - Rejected: Can't invalidate tokens before expiry
3. **OAuth2** - Rejected: Overkill for this use case

## Consequences
- **Positive**: Stateless scaling, fast verification
- **Negative**: Redis dependency, token refresh complexity

## Implementation
See [[file-src-auth-ts]] for implementation details.
```

#### 2.3 Discovery Node

Created when architectural patterns or insights are learned.

```markdown
---
id: discovery-repository-pattern
type: discovery
created: 2025-12-08T12:00:00Z
updated: 2025-12-08T12:00:00Z
tags: [pattern, architecture, data-access]
related: [[file-src-user-repository-ts]], [[file-src-auth-ts]]
status: active
category: pattern
---

# Discovery: Repository Pattern Usage

## Insight
This codebase uses the Repository pattern for all database access. Each entity has a dedicated repository class in `/src/repositories/`.

## Pattern Details
```typescript
// Pattern structure
class EntityRepository {
  constructor(private db: Database) {}

  async findById(id: string): Promise<Entity | null>
  async findAll(filters?: Filters): Promise<Entity[]>
  async create(data: CreateDTO): Promise<Entity>
  async update(id: string, data: UpdateDTO): Promise<Entity>
  async delete(id: string): Promise<void>
}
```

## Where Used
- [[file-src-user-repository-ts]]
- [[file-src-product-repository-ts]]
- [[file-src-order-repository-ts]]

## Implications
When adding new entities, follow this pattern. Create repository in `/src/repositories/`.
```

#### 2.4 Session Node

Created automatically at session end.

```markdown
---
id: session-2025-12-08-abc123
type: session
created: 2025-12-08T10:00:00Z
updated: 2025-12-08T16:00:00Z
tags: [session]
related: [[task-fix-auth-bug]], [[decision-001-jwt-auth]]
status: archived
session_id: abc123
duration_minutes: 360
message_count: 45
---

# Session: 2025-12-08

## Summary
Fixed authentication bug in JWT refresh flow. Added Redis session invalidation.

## Tasks Completed
- [x] Investigate auth bug ([[task-fix-auth-bug]])
- [x] Implement session invalidation
- [x] Add tests for refresh flow

## Tasks In Progress
- [ ] Add rate limiting to auth endpoints

## Key Decisions Made
- [[decision-001-jwt-auth]]

## Files Modified
- [[file-src-auth-ts]] (major changes)
- [[file-src-redis-client-ts]] (minor changes)

## Discoveries
- [[discovery-repository-pattern]]

## Notes
User prefers explicit error messages over generic "unauthorized".
```

#### 2.5 Task Node

Created/updated via TodoWrite hook.

```markdown
---
id: task-fix-auth-bug
type: task
created: 2025-12-08T10:30:00Z
updated: 2025-12-08T14:00:00Z
tags: [bug, auth, priority-high]
related: [[file-src-auth-ts]], [[session-2025-12-08-abc123]]
status: completed
---

# Task: Fix Auth Bug in JWT Refresh

## Description
Token refresh returning 401 for valid refresh tokens.

## Root Cause
Redis key prefix mismatch: using `token:` instead of `session:`.

## Solution
Updated prefix in [[file-src-auth-ts]] line 142.

## Blockers Encountered
- Initially thought it was token expiry issue
- Debugging Redis keys revealed the prefix mismatch

## Completion Notes
Fixed and tested. Added unit test to prevent regression.
```

#### 2.6 Error Node

Created when errors occur and are resolved.

```markdown
---
id: error-circular-import
type: error
created: 2025-12-08T13:00:00Z
updated: 2025-12-08T13:30:00Z
tags: [error, import, typescript]
related: [[file-src-auth-ts]], [[file-src-user-repository-ts]]
status: resolved
---

# Error: Circular Import Between auth.ts and user-repository.ts

## Error Message
```
Error: Cannot access 'UserRepository' before initialization
```

## Cause
`auth.ts` imports `UserRepository`, which imports `auth.ts` for type definitions.

## Solution
Extracted shared types to [[file-src-types-auth-ts]].

## Prevention
Use the `find-circular` tool before committing:
```bash
.claude/tools/find-circular.sh
```
```

---

### 3. Graph Cache (graph.json)

The graph cache is a computed JSON file that enables fast queries without parsing all markdown files.

```json
{
  "version": "1.0.0",
  "updated_at": "2025-12-08T16:00:00Z",
  "node_count": 42,

  "nodes": {
    "file-src-auth-ts": {
      "path": "nodes/files/src-auth-ts.md",
      "type": "file-summary",
      "tags": ["auth", "security", "jwt", "middleware"],
      "links_to": ["file-src-config-ts", "discovery-jwt-pattern"],
      "linked_from": ["decision-001-jwt-auth", "session-2025-12-08-abc123"],
      "created": "2025-12-08T10:30:00Z",
      "updated": "2025-12-08T14:20:00Z",
      "status": "active",
      "mtime": 1733669220
    },
    "decision-001-jwt-auth": {
      "path": "nodes/decisions/decision-001-jwt-auth.md",
      "type": "decision",
      "tags": ["auth", "security", "architecture"],
      "links_to": ["file-src-auth-ts", "discovery-jwt-pattern"],
      "linked_from": ["session-2025-12-08-abc123"],
      "created": "2025-12-08T11:00:00Z",
      "updated": "2025-12-08T11:00:00Z",
      "status": "active",
      "mtime": 1733666400
    }
  },

  "tags": {
    "auth": ["file-src-auth-ts", "decision-001-jwt-auth"],
    "security": ["file-src-auth-ts", "decision-001-jwt-auth"],
    "pattern": ["discovery-repository-pattern"]
  },

  "types": {
    "file-summary": ["file-src-auth-ts", "file-src-config-ts"],
    "decision": ["decision-001-jwt-auth"],
    "discovery": ["discovery-repository-pattern"],
    "session": ["session-2025-12-08-abc123"]
  },

  "recent": [
    "session-2025-12-08-abc123",
    "file-src-auth-ts",
    "decision-001-jwt-auth"
  ]
}
```

---

### 4. Link Semantics

#### Wiki-Link Syntax

```markdown
[[node-id]]                    # Basic link
[[node-id|Display Text]]       # Link with custom display
[[node-id#section]]            # Link to specific section
```

#### Link Types

| Syntax | Meaning | Example |
|--------|---------|---------|
| `[[node-id]]` | Direct reference | `[[file-src-auth-ts]]` |
| `related::` | Soft connection | `related:: [[concept-x]]` |
| `supersedes::` | Replaces older | `supersedes:: decision-001` |
| `depends_on::` | Dependency | `depends_on:: [[file-config]]` |
| `#tag` | Category | `#auth #security` |

#### Backlinks

Backlinks are computed, not stored. The `linked_from` field in graph.json is derived by scanning all `links_to` arrays.

---

### 5. Query Engine

#### Query API

```bash
# memory-query tool interface
memory-query [OPTIONS]

OPTIONS:
  --id <node-id>          # Get specific node
  --type <type>           # Filter by type (file-summary, decision, etc.)
  --tag <tag>             # Filter by tag
  --related <node-id>     # Get related nodes (links + backlinks + tag overlap)
  --recent [N]            # Get N most recent nodes (default: 5)
  --search <term>         # Full-text search in node content
  --status <status>       # Filter by status (active, archived, superseded)
  --since <date>          # Nodes created/updated since date
  --format <format>       # Output format: json, summary, full (default: summary)
```

#### Query Examples

```bash
# Get recent context for session start
memory-query --recent 5 --status active --format summary

# Find all auth-related knowledge
memory-query --tag auth --format summary

# Get related nodes before reading a file
memory-query --related file-src-auth-ts --format summary

# Find all active decisions
memory-query --type decision --status active --format full

# Search for error solutions
memory-query --search "circular import" --type error
```

#### Query Output Formats

**Summary Format** (for injection):
```
[file-summary] src/auth.ts - JWT auth module with Redis sessions
[decision] Use JWT with Redis - Stateless auth, can invalidate sessions
[discovery] Repository pattern - All entities use /src/repositories/
```

**JSON Format** (for programmatic use):
```json
{
  "nodes": [
    {
      "id": "file-src-auth-ts",
      "type": "file-summary",
      "summary": "JWT auth module with Redis sessions",
      "path": "nodes/files/src-auth-ts.md"
    }
  ],
  "count": 1,
  "query_time_ms": 12
}
```

---

### 6. Hook Integration

#### 6.1 SessionStart Hook

**Purpose**: Load initial context when session begins

**Trigger**: Session start or resume

**Actions**:
1. Read `index.md` for high-level context
2. Query recent active nodes
3. Load any in-progress tasks
4. Inject as context (~500 tokens max)

**Output** (stdout for Claude to see):
```
# Memory Context

## Last Session (2025-12-08)
Fixed JWT refresh bug, added Redis session invalidation.

## Active Tasks
- [ ] Add rate limiting to auth endpoints

## Key Decisions
- Using JWT with Redis session store for auth

## Recent Files
- src/auth.ts - JWT auth module (modified recently)
```

#### 6.2 UserPromptSubmit Hook

**Purpose**: Inject relevant context based on user's prompt

**Trigger**: Before Claude processes each prompt

**Actions**:
1. Extract keywords from prompt
2. Query nodes matching keywords (files, concepts, decisions)
3. Inject relevant summaries (~1000 tokens max)

**Logic**:
```python
def get_relevant_context(prompt: str) -> str:
    keywords = extract_keywords(prompt)
    relevant_nodes = []

    # Check for file mentions
    for keyword in keywords:
        if matches_file_pattern(keyword):
            nodes = query_by_path(keyword)
            relevant_nodes.extend(nodes)

    # Check for concept/tag matches
    for keyword in keywords:
        nodes = query_by_tag(keyword)
        relevant_nodes.extend(nodes)

    # Dedupe and limit
    relevant_nodes = dedupe(relevant_nodes)[:5]

    # Format for injection
    return format_summary(relevant_nodes)
```

#### 6.3 PostToolUse Hook (Capture)

**Purpose**: Automatically capture knowledge from tool usage

**Triggers**:
- `Read` (large files) → Create/update file-summary node
- `TodoWrite` → Update task nodes
- `Task` (sub-agents) → Capture agent findings

**Logic for File Summary**:
```python
def on_read_complete(file_path: str, content: str):
    # Only auto-summarize large files
    if len(content) < 50000:  # ~50KB
        return

    node_id = path_to_node_id(file_path)
    existing = get_node(node_id)

    if existing and existing.mtime >= file_mtime(file_path):
        return  # Node is fresh

    # Generate summary (could use LLM or heuristics)
    summary = generate_file_summary(content)

    # Create/update node
    save_node(node_id, {
        "type": "file-summary",
        "path": file_path,
        "content": summary
    })

    # Rebuild graph cache
    rebuild_graph_cache()
```

#### 6.4 SessionEnd Hook

**Purpose**: Persist session knowledge

**Trigger**: Session end

**Actions**:
1. Create session summary node
2. Update task nodes with final status
3. Prune old nodes if over limit
4. Update index.md with recent context

---

### 7. Index File (index.md)

The index file serves as the entry point and contains curated recent context.

```markdown
---
updated: 2025-12-08T16:00:00Z
---

# Memory Index

## Project Context
E-commerce API using Node.js, TypeScript, Express, Redis.

## Active Decisions
- [[decision-001-jwt-auth]] - JWT with Redis sessions
- [[decision-002-repository-pattern]] - Repository pattern for data access

## Current Focus
Working on authentication improvements and rate limiting.

## Recent Sessions
- [[session-2025-12-08-abc123]] - Fixed auth bug, added session invalidation

## Key Files
- [[file-src-auth-ts]] - Auth module (recently modified)
- [[file-src-api-routes-ts]] - API routes

## Active Tasks
- [ ] Add rate limiting to auth endpoints

## User Preferences
- Prefers explicit error messages
- Uses pnpm, not npm
- TypeScript strict mode enabled
```

---

### 8. Configuration (config.json)

```json
{
  "version": "1.0.0",

  "capture": {
    "auto_summarize_threshold_kb": 50,
    "auto_summarize_languages": ["typescript", "javascript", "python", "go"],
    "capture_todos": true,
    "capture_subagent_results": true
  },

  "injection": {
    "session_start_max_tokens": 500,
    "prompt_max_tokens": 1000,
    "max_nodes_per_query": 5
  },

  "retention": {
    "max_nodes": 500,
    "session_archive_days": 7,
    "prune_strategy": "least_connected_oldest"
  },

  "graph": {
    "rebuild_on_change": true,
    "cache_ttl_seconds": 300
  }
}
```

---

## Data Flow

### Write Path (Capturing Knowledge)

```
Tool Use (Read/Edit/Write/TodoWrite)
    │
    ▼
PostToolUse Hook
    │
    ├─► Is it a significant operation?
    │       │
    │       ├─ Read large file → Generate summary → Create file-summary node
    │       ├─ TodoWrite → Update task nodes
    │       └─ Task agent → Capture findings in discovery node
    │
    ▼
Node Written to .claude/memory/nodes/
    │
    ▼
Graph Cache Rebuilt (graph.json)
```

### Read Path (Injecting Context)

```
Session Start / User Prompt
    │
    ▼
Hook Triggered
    │
    ├─► SessionStart: Load index.md + recent nodes
    │
    └─► UserPromptSubmit:
            │
            ├─► Extract keywords from prompt
            ├─► Query graph cache for relevant nodes
            ├─► Read node summaries
            └─► Format and inject as context
    │
    ▼
Context Injected via stdout / additionalContext
    │
    ▼
Claude Sees Context + Processes Prompt
```

---

## Security & Privacy Considerations

1. **Local Storage Only**: All data stored locally in `.claude/memory/`
2. **Git-Friendly**: Memory files can be committed (project knowledge is valuable)
3. **No External Calls**: Graph building and queries are fully local
4. **Sensitive File Filtering**: Can configure files to exclude from summaries
5. **User Control**: Manual nodes for sensitive decisions

---

## Performance Considerations

1. **Graph Cache**: Avoid re-parsing markdown on every query
2. **Lazy Summary Generation**: Only summarize files when first read
3. **Incremental Updates**: Only rebuild affected parts of cache
4. **Token Budget**: Hard limits on injection size
5. **Pruning**: Automatic cleanup of old, low-value nodes

---

## Integration with Existing Capsule System

The Memory Graph extends (doesn't replace) the existing capsule:

| Component | Capsule (Current) | Memory Graph (New) |
|-----------|------------------|-------------------|
| Scope | Session | Cross-session |
| Content | Files touched, tasks | Summaries, decisions, insights |
| Format | TOON | Markdown + JSON |
| Persistence | 24-hour window | Permanent (until pruned) |
| Injection | SessionStart | SessionStart + UserPromptSubmit |

**Integration Point**: SessionEnd hook writes current session to Memory Graph before capsule persists.

---

## Future Extensions

1. **Semantic Search**: Embed nodes for similarity search
2. **Graph Visualization**: Generate visual graph for user
3. **Cross-Project Memory**: Share patterns across projects
4. **Memory Merge**: Combine knowledge from multiple sessions
5. **Conflict Resolution**: Handle contradictory decisions

---

## Appendix: Node ID Conventions

| Type | Pattern | Example |
|------|---------|---------|
| File Summary | `file-{path-slug}` | `file-src-auth-ts` |
| Decision | `decision-{number}-{slug}` | `decision-001-jwt-auth` |
| Discovery | `discovery-{slug}` | `discovery-repository-pattern` |
| Session | `session-{date}-{id}` | `session-2025-12-08-abc123` |
| Task | `task-{slug}` | `task-fix-auth-bug` |
| Error | `error-{slug}` | `error-circular-import` |
