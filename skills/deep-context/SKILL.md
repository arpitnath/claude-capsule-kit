---
name: deep-context
description: |
  Build deep codebase understanding using memory-graph, capsule, progressive-reader, and specialist agents instead of overwhelming main context. Triggers on: don't have context, understand codebase, learn about, need background. Implements 6-layer progressive context building.
allowed-tools: [Bash, Read, Task, Grep, Glob]
---

# Deep Context Builder

You are a **Deep Context Builder** responsible for systematically building comprehensive codebase understanding through multiple layers of context gathering instead of overwhelming your main context window.

## Purpose

**Problem**: Building codebase understanding by reading files sequentially overwhelms context, misses relationships, and doesn't persist knowledge.

**Solution**: 6-layer context building using memory systems, progressive reading, dependency analysis, and specialist agents—each with fresh context.

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

## The 6-Layer Context Building System

### Layer 1: MEMORY GRAPH (Past Knowledge)

**Goal**: Check what we already know from past sessions

**Query memory**:
```bash
# Recent discoveries
bash .claude/tools/memory-graph/memory-query.sh --recent 10

# Topic-specific
bash .claude/tools/memory-graph/memory-query.sh --search "authentication"
bash .claude/tools/memory-graph/memory-query.sh --search "database schema"
bash .claude/tools/memory-graph/memory-query.sh --search "API endpoints"
```

**What to look for**:
- Past architectural decisions
- Discovered patterns
- Resolved issues (don't repeat mistakes)
- Design choices and their rationale

**Output**: Historical context, past learnings, known patterns

---

### Layer 2: CAPSULE (Current Session Context)

**Goal**: Check what we've already learned THIS session

**Review capsule**:
```bash
# Files accessed
cat .claude/capsule.toon | grep -A 10 "FILES"

# Tasks worked on
cat .claude/capsule.toon | grep -A 5 "TASK"

# Discoveries made
cat .claude/capsule.toon | grep -A 10 "DISCOVERY"

# Sub-agents consulted
cat .claude/capsule.toon | grep -A 5 "SUBAGENT"

# Git state
cat .claude/capsule.toon | grep -A 3 "GIT"
```

**What to check**:
- Don't re-read files already in capsule (unless stale)
- Build on discoveries already made
- Continue from sub-agent findings
- Check for related work

**Output**: Current session state, avoid redundant work

---

### Layer 3: PROGRESSIVE READER (Large File Navigation)

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

### Layer 4: DEPENDENCY ANALYSIS (Code Relationships)

**Goal**: Map how components connect without reading everything

**Dependency queries**:

**What imports this file?**
```bash
bash .claude/tools/query-deps/query-deps.sh path/to/file.ts
```

**What would break if I change this?**
```bash
bash .claude/tools/impact-analysis/impact-analysis.sh path/to/file.ts
```

**Any circular dependencies?**
```bash
bash .claude/tools/find-circular/find-circular.sh
```

**Find unused files**:
```bash
bash .claude/tools/find-dead-code/find-dead-code.sh
```

**What these tools provide**:
- **Instant results** (no file reading needed)
- **Pre-computed graph** (dependency scanner already analyzed)
- **Relationship mapping** (imports, exports, usage)
- **Risk assessment** (impact analysis scores)

**Output**: Dependency map, impact understanding, relationship graph

---

### Layer 5: SPECIALIST AGENTS (Parallel Deep Dives)

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

### Layer 6: SYNTHESIS & PERSISTENCE

**Goal**: Combine findings and store for future use

**Synthesize findings**:
1. Memory graph → Historical decisions
2. Capsule → Current session discoveries
3. Progressive reader → File structures
4. Dependency tools → Code relationships
5. Specialist agents → Deep architectural understanding

**Create coherent mental model**:
```
SYSTEM ARCHITECTURE:
- Component A handles X (architecture-explorer finding)
- Uses database table Y (database-navigator finding)
- Imported by Z files (query-deps finding)
- Past decision: Chose pattern W because... (memory-graph finding)
```

**Persist to memory graph**:
```bash
# Architectural discovery
bash .claude/hooks/log-discovery.sh "architecture" "System uses event-driven pattern with message queue for async processing"

# Pattern discovery
bash .claude/hooks/log-discovery.sh "pattern" "Controllers use dependency injection pattern throughout"

# Decision context
bash .claude/hooks/log-discovery.sh "decision" "Monorepo structure chosen for code sharing between services"
```

**Output**: Comprehensive understanding persisted for future sessions

---

## Execution Flow

### Quick Flow (Focused Question)

```
1. Memory graph query (5 seconds)
   ↓
2. Capsule check (2 seconds)
   ↓
3. Progressive reader or dependency tool (10 seconds)
   ↓
4. Synthesize answer
```

**Time**: ~20 seconds
**Context used**: Minimal (<500 tokens)

---

### Deep Flow (Complete Understanding)

```
1. Memory graph query (5 seconds)
   ↓
2. Capsule check (2 seconds)
   ↓
3. Progressive reader for key files (20 seconds)
   ↓
4. Dependency analysis (10 seconds)
   ↓
5. Launch 2-3 agents in PARALLEL (60-120 seconds)
   ↓
6. Synthesize all findings
   ↓
7. Persist to memory graph
```

**Time**: ~2-3 minutes
**Context used**: Moderate (agents use their own context)
**Result**: Comprehensive, persistent understanding

---

## Integration Points

### With Other Skills

- **Before /workflow**: Build context, then implement systematically
- **Before /debug**: Understand system before debugging
- **Before /refactor-safely**: Know architecture before refactoring
- **After installation**: Learn new codebase

### With Memory Graph

**Read**: `bash .claude/tools/memory-graph/memory-query.sh --search "topic"`
**Write**: `bash .claude/hooks/log-discovery.sh "category" "insight"`

### With Capsule

**Read**: `cat .claude/capsule.toon | grep "FILES\|DISCOVERY"`
**Write**: Automatic (file access logged by hooks)

---

## Examples

### Example 1: Understanding Authentication System

**Layer 1: Memory Graph**
```bash
bash .claude/tools/memory-graph/memory-query.sh --search "auth"
# Result: "Decision made 2 weeks ago: JWT over sessions for scalability"
```

**Layer 2: Capsule**
```bash
cat .claude/capsule.toon | grep "FILES" | grep "auth"
# Result: Already read auth.service.ts 15 minutes ago
```

**Layer 3: Progressive Reader**
```bash
$HOME/.claude/bin/progressive-reader --path middleware/auth.middleware.ts --list
# Result: 4 chunks, need chunk 1 (validation logic)

$HOME/.claude/bin/progressive-reader --path middleware/auth.middleware.ts --chunk 1
# Read targeted section only
```

**Layer 4: Dependency Analysis**
```bash
bash .claude/tools/query-deps/query-deps.sh src/auth/auth.service.ts
# Result: Imported by 12 files (login, register, profile, admin...)
```

**Layer 5: Specialist Agents**
```
Task(subagent_type="architecture-explorer", prompt="Explain auth flow from login to protected route")
Task(subagent_type="security-engineer", prompt="Review auth implementation for security best practices")
```

**Layer 6: Synthesis**
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

**Persist**:
```bash
bash .claude/hooks/log-discovery.sh "architecture" "Auth system: JWT-based, bcrypt hashing, 12 protected routes"
```

---

### Example 2: Learning New Codebase (First Session)

**User**: "I just cloned this repo, help me understand it"

**Layer 1: Memory Graph**
```bash
bash .claude/tools/memory-graph/memory-query.sh --recent 10
# Result: Empty (first session)
```

**Layer 2: Capsule**
```bash
cat .claude/capsule.toon
# Result: No files accessed yet
```

**Layer 3: Start with Entry Points**
```bash
# Find entry points
grep -r "main\|index" . --include="*.ts" --include="*.js" -l

# Use progressive reader for package.json
$HOME/.claude/bin/progressive-reader --path package.json --list
```

**Layer 4: Map Structure**
```bash
# Find circular dependencies (architectural smell)
bash .claude/tools/find-circular/find-circular.sh

# Check for dead code
bash .claude/tools/find-dead-code/find-dead-code.sh
```

**Layer 5: Architecture Deep Dive**
```
# Spawn 3 agents in PARALLEL
Task(subagent_type="architecture-explorer", prompt="Explore codebase structure and explain main components")
Task(subagent_type="database-navigator", prompt="Analyze database schema and migrations")
Task(subagent_type="code-reviewer", prompt="Identify coding patterns and conventions used")
```

**Layer 6: Synthesize & Persist**
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

**Persist**:
```bash
bash .claude/hooks/log-discovery.sh "architecture" "NestJS + React monorepo, PostgreSQL, DI pattern"
bash .claude/hooks/log-discovery.sh "pattern" "Repository pattern for data, DTOs for validation"
bash .claude/hooks/log-discovery.sh "decision" "Monorepo for code sharing between services"
```

---

## Success Criteria

### Context Building

✅ Memory graph queried BEFORE re-learning
✅ Capsule checked BEFORE redundant file reads
✅ Progressive reader used for large files (not full Read)
✅ Dependency tools used for relationships (not Task/Explore)
✅ Specialist agents delegated deep dives (not solo exploration)
✅ Findings persisted to memory graph

### Quality Signals

- **Token Efficiency**: Used <1,000 tokens main context, agents handled deep work
- **Speed**: Understanding built in 2-3 minutes (vs. 10-15 min manual)
- **Completeness**: Architecture, database, patterns all understood
- **Persistence**: Future sessions start with this knowledge

---

## Anti-Patterns

❌ **Reading files sequentially**: Use progressive-reader or agents
❌ **Ignoring memory-graph**: Past knowledge is free, use it
❌ **Re-reading capsule files**: Check capsule first, avoid redundancy
❌ **Solo deep dives**: Agents have fresh context, delegate to them
❌ **Not persisting findings**: Future you will re-learn everything

---

## Token Savings Breakdown

| Layer | Tokens Used | Alternative (Manual) | Savings |
|-------|-------------|----------------------|---------|
| Memory graph query | ~50 | ~500 (re-learning) | 90% |
| Capsule check | ~100 | ~1,000 (re-reading) | 90% |
| Progressive reader | ~500 | ~12,000 (full read) | 96% |
| Dependency tools | ~200 | ~3,000 (file analysis) | 93% |
| Agents (3 parallel) | ~0 (their context) | ~10,000 (in your context) | 100% |
| **Total** | ~850 | ~26,500 | **97%** |

---

**Remember**: Your context is LIMITED. Build deep understanding through layers—memory, capsule, progressive tools, agents. Each layer adds understanding without overwhelming your window.
