---
name: deep-context
description: |
  Build deep codebase understanding using Capsule context, progressive-reader, and specialist agents instead of overwhelming main context. Triggers on: don't have context, understand codebase, learn about, need background. Implements progressive context building.
allowed-tools: [Bash, Read, Task, Grep, Glob]
---

# Deep Context Builder

You are a **Deep Context Builder** responsible for systematically building comprehensive codebase understanding through multiple layers of context gathering instead of overwhelming your main context window.

## Purpose

**Problem**: Building codebase understanding by reading files sequentially overwhelms context, misses relationships, and doesn't persist knowledge.

**Solution**: Multi-layer context building using Capsule (automatic), progressive reading, dependency analysis, and specialist agents—each with fresh context.

## When to Use This Skill

**Auto-triggers on keywords**:
- "don't have context", "you don't have enough context"
- "understand the codebase", "learn about this system"
- "need background", "how does this work"
- "explain the architecture", "what's the structure"

**Context indicators**:
- User says you're missing understanding
- Complex task needs architectural knowledge
- Unfamiliar part of codebase
- Need to understand before implementing

**Manual invocation**: `/deep-context`

---

## The Multi-Layer Context Building System

### Layer 1: CAPSULE CONTEXT (Automatic)

**Goal**: Review what Capsule has already provided

At session start, `session-start.js` automatically injects:
- **Last Session** — Summary of most recent session
- **Top Discoveries** — Most-accessed architectural insights
- **Recent Files** — Last 3 files worked on
- **Team Activity** (crew mode) — What other teammates have been doing

**What to check**:
- Review the injected context for past decisions and patterns
- Don't re-read files already mentioned in injected context
- Build on discoveries from previous sessions
- Check for related team work (in crew mode)

**Output**: Historical + session context, automatically provided

---

### Layer 2: PROGRESSIVE READER (Large Files)

**Goal**: Understand file structure WITHOUT reading entire files

**For large files (>50KB)**:

**Step 1**: List file structure
```bash
$HOME/.claude/bin/progressive-reader --path <file> --list
```

**Output**:
```
Chunk 0 (lines 1-150): Imports and type definitions
Chunk 1 (lines 151-300): AuthService class initialization
Chunk 2 (lines 301-450): Login/logout methods
Chunk 3 (lines 451-600): Token validation
Chunk 4 (lines 601-750): Helper functions
```

**Step 2**: Read only relevant chunks
```bash
$HOME/.claude/bin/progressive-reader --path <file> --chunk 2
```

**Step 3**: Continue if needed
```bash
$HOME/.claude/bin/progressive-reader --continue-file /tmp/continue.toon
```

**Token Savings**: 75-97% vs. full file read

**When to use**:
- File >50KB (~12,500 tokens)
- Need specific functionality, not full file
- Exploring structure before detailed reading
- Context window pressure

**Output**: Targeted understanding without overwhelming context

---

### Layer 3: DEPENDENCY ANALYSIS (Code Relationships)

**Goal**: Map how components connect without reading everything

**Dependency queries**:

**What imports this file?**
```bash
bash $HOME/.claude/cck/tools/query-deps/query-deps.sh path/to/file.ts
```

**What would break if I change this?**
```bash
bash $HOME/.claude/cck/tools/impact-analysis/impact-analysis.sh path/to/file.ts
```

**Any circular dependencies?**
```bash
bash $HOME/.claude/cck/tools/find-circular/find-circular.sh
```

**Find unused files**:
```bash
bash $HOME/.claude/cck/tools/find-dead-code/find-dead-code.sh
```

**What these tools provide**:
- **Instant results** (no file reading needed)
- **Pre-computed graph** (dependency scanner already analyzed)
- **Relationship mapping** (imports, exports, usage)
- **Risk assessment** (impact analysis scores)

**Output**: Dependency map, impact understanding, relationship graph

---

### Layer 4: SPECIALIST AGENTS (Parallel Deep Dives)

**Goal**: Delegate deep understanding to fresh-context specialists

**Launch agents in PARALLEL** (single message):

**Architecture Understanding**:
```
Task(
  subagent_type="architecture-explorer",
  description="Understand system architecture",
  prompt="""
Explore and explain how [module/system] works:

Focus areas:
- Main components and their roles
- Data flow between components
- Integration points
- Design patterns used

Provide architectural overview with file references.
"""
)
```

**Database Understanding**:
```
Task(
  subagent_type="database-navigator",
  description="Understand database schema",
  prompt="""
Analyze the database schema and data model:

Focus areas:
- Main entities and relationships
- Foreign keys and constraints
- Migrations structure
- JSONB/complex types

Provide schema overview with table relationships.
"""
)
```

**Code Quality Check**:
```
Task(
  subagent_type="code-reviewer",
  description="Understand code patterns",
  prompt="""
Review codebase for patterns and structure:

Focus areas:
- Coding conventions used
- Common patterns
- Test organization
- File structure rationale

Provide pattern guide for this codebase.
"""
)
```

**Why agents?**:
- **Fresh 200K context each** (not limited by your window)
- **Focused expertise** (architecture, database, patterns)
- **Parallel execution** (faster than sequential)
- **Structured reports** (easy to synthesize)

**Output**: Deep specialist analysis without consuming your context

---

### Layer 5: SYNTHESIS

**Goal**: Combine findings and store for future use

**Synthesize findings**:
1. Capsule context → Historical decisions + recent files
2. Progressive reader → File structures
3. Dependency tools → Code relationships
4. Specialist agents → Deep architectural understanding

**Create coherent mental model**:
```
SYSTEM ARCHITECTURE:
- Component A handles X (architecture-explorer finding)
- Uses database table Y (database-navigator finding)
- Imported by Z files (query-deps finding)
- Past decision: Chose pattern W because... (Capsule context)
```

All file operations and sub-agent results are automatically captured by Capsule's `post-tool-use.js` hook. No manual persistence needed.

**Output**: Comprehensive understanding, automatically captured for future sessions

---

## Execution Flow

### Quick Flow (Focused Question)

```
1. Review Capsule injected context (instant)
   ↓
2. Progressive reader or dependency tool (10 seconds)
   ↓
3. Synthesize answer
```

**Time**: ~15 seconds
**Context used**: Minimal (<500 tokens)

---

### Deep Flow (Complete Understanding)

```
1. Review Capsule injected context (instant)
   ↓
2. Progressive reader for key files (20 seconds)
   ↓
3. Dependency analysis (10 seconds)
   ↓
4. Launch 2-3 agents in PARALLEL (60-120 seconds)
   ↓
5. Synthesize all findings
```

**Time**: ~2-3 minutes
**Context used**: Moderate (agents use their own context)
**Result**: Comprehensive understanding, automatically persisted by Capsule

---

## Integration Points

### With Other Skills

- **Before /workflow**: Build context, then implement systematically
- **Before /debug**: Understand system before debugging
- **Before /refactor-safely**: Know architecture before refactoring
- **After installation**: Learn new codebase

### With Capsule Context

Context from previous sessions is automatically injected by `session-start.js`. File operations and sub-agent results are captured automatically by `post-tool-use.js`. No manual logging needed.

---

## Examples

### Example 1: Understanding Authentication System

**Layer 1: Capsule Context**
```
# Automatically injected at session start:
# - Last Session: worked on auth module
# - Top Discoveries: "JWT over sessions for scalability"
# - Recent Files: auth.service.ts (read 15 min ago)
```

**Layer 2: Progressive Reader**
```bash
$HOME/.claude/bin/progressive-reader --path middleware/auth.middleware.ts --list
# Result: 4 chunks, need chunk 1 (validation logic)

$HOME/.claude/bin/progressive-reader --path middleware/auth.middleware.ts --chunk 1
# Read targeted section only
```

**Layer 3: Dependency Analysis**
```bash
bash $HOME/.claude/cck/tools/query-deps/query-deps.sh src/auth/auth.service.ts
# Result: Imported by 12 files (login, register, profile, admin...)
```

**Layer 4: Specialist Agents**
```
Task(subagent_type="architecture-explorer", prompt="Explain auth flow from login to protected route")
Task(subagent_type="security-engineer", prompt="Review auth implementation for security best practices")
```

**Layer 5: Synthesis**
```
AUTHENTICATION SYSTEM UNDERSTANDING:

Architecture:
- JWT-based (decision: scalability over session state)
- auth.service.ts: Token generation and validation
- auth.middleware.ts: Request authentication
- Used by: 12 routes (all protected endpoints)

Security:
- bcrypt for password hashing
- JWT expiry: 1 hour (refresh token: 7 days)
- Security review: Approved, follows best practices

Files:
- src/auth/auth.service.ts (core logic)
- middleware/auth.middleware.ts (request validation)
- types/auth.d.ts (type definitions)
```

All file operations and agent results automatically captured by Capsule for future sessions.

---

### Example 2: Learning New Codebase (First Session)

**User**: "I just cloned this repo, help me understand it"

**Layer 1: Capsule Context**
```
# First session — no previous context injected
# Start fresh with code exploration
```

**Layer 2: Start with Entry Points**
```bash
# Find entry points
grep -r "main\|index" . --include="*.ts" --include="*.js" -l

# Use progressive reader for package.json
$HOME/.claude/bin/progressive-reader --path package.json --list
```

**Layer 3: Map Structure**
```bash
# Find circular dependencies (architectural smell)
bash $HOME/.claude/cck/tools/find-circular/find-circular.sh

# Check for dead code
bash $HOME/.claude/cck/tools/find-dead-code/find-dead-code.sh
```

**Layer 4: Architecture Deep Dive**
```
# Spawn 3 agents in PARALLEL
Task(subagent_type="architecture-explorer", prompt="Explore codebase structure and explain main components")
Task(subagent_type="database-navigator", prompt="Analyze database schema and migrations")
Task(subagent_type="code-reviewer", prompt="Identify coding patterns and conventions used")
```

**Layer 5: Synthesize**
```
CODEBASE OVERVIEW:

Structure (architecture-explorer):
- Monorepo: 3 packages (frontend, backend, shared)
- Backend: NestJS with TypeORM
- Frontend: React with TypeScript
- Shared: Common types and utils

Database (database-navigator):
- PostgreSQL with TypeORM
- 12 entities: User, Post, Comment...
- Migrations in src/migrations/

Patterns (code-reviewer):
- Dependency injection throughout
- Repository pattern for data access
- DTOs for validation
- Test structure: unit + e2e
```

All findings automatically captured by Capsule for future sessions.

---

## Success Criteria

### Context Building

✅ Capsule context reviewed before starting (injected automatically)
✅ Progressive reader used for large files (not full Read)
✅ Dependency tools used for relationships (not Task/Explore)
✅ Specialist agents delegated deep dives (not solo exploration)
✅ All operations automatically captured by Capsule

### Quality Signals

- **Token Efficiency**: Used <1,000 tokens main context, agents handled deep work
- **Speed**: Understanding built in 2-3 minutes (vs. 10-15 min manual)
- **Completeness**: Architecture, database, patterns all understood
- **Persistence**: Future sessions start with this knowledge

---

## Anti-Patterns

❌ **Reading files sequentially**: Use progressive-reader or agents
❌ **Ignoring Capsule context**: Past knowledge is injected automatically, use it
❌ **Solo deep dives**: Agents have fresh context, delegate to them
❌ **Redundant file reads**: Check injected context before re-reading

---

## Token Savings Breakdown

| Layer | Tokens Used | Alternative (Manual) | Savings |
|-------|-------------|----------------------|---------|
| Capsule context (auto) | ~100 | ~1,500 (re-learning) | 93% |
| Progressive reader | ~500 | ~12,000 (full read) | 96% |
| Dependency tools | ~200 | ~3,000 (file analysis) | 93% |
| Agents (3 parallel) | ~0 (their context) | ~10,000 (in your context) | 100% |
| **Total** | ~800 | ~26,500 | **97%** |

---

**Remember**: Your context is LIMITED. Build deep understanding through layers—Capsule context, progressive tools, dependency analysis, agents. Each layer adds understanding without overwhelming your window.
