# Agent Routing Guide

Complete guide for selecting and orchestrating Claude Capsule Kit's 17 specialized agents.

---

## Overview

Claude Capsule Kit provides **17 specialized agents**. Use the RIGHT agent for each task.

**Key Principle**: Agents run in fresh context with focused expertise—they're MORE EFFECTIVE than doing everything yourself.

---

## When to Use Agents

### Core Principles

1. **Use agents when task requires DEEP expertise or PARALLEL investigation**
   - Complex debugging → error-detective
   - Architectural understanding → architecture-explorer
   - Multi-perspective analysis → brainstorm-coordinator

2. **Don't use agents for simple, quick tasks you can do directly**
   - Single file edit → Direct work
   - Known bug fix → Direct work
   - Simple config change → Direct work

3. **Prefer parallel agent spawning when tasks are independent**
   - Bug investigation → error-detective + architecture-explorer (parallel)
   - Pre-refactor analysis → refactoring-specialist + code-reviewer (parallel)

---

## Agent Categories

### 1. Debugging (error-detective, debugger)

**Triggers**: Error, bug, stack trace, "why is this failing", test failure

**Agents**:

**error-detective** (Opus)
- **Use for**: Root cause analysis - returns structured RCA report
- **Output**: What Failed, Root Cause, Evidence, Chain of Events, Suggested Fix, Confidence
- **When**: Always use FIRST for errors/bugs

**debugger** (Opus)
- **Use for**: Systematic debugging, code tracing, isolating issues
- **Output**: Symptom, Hypotheses, Investigation Path, Root Cause, Recommended Fix
- **When**: RCA confidence < 80% or complex code tracing needed

**Pattern**:
1. Start with `error-detective` for RCA
2. Use `debugger` if issue is complex or needs code tracing
3. Run in PARALLEL if investigating multiple potential causes

**Example**:
```
User: "Tests are failing with TypeError"

Task(subagent_type="error-detective", description="RCA for TypeError")
# If RCA confidence low:
Task(subagent_type="debugger", description="Trace code execution for TypeError")
```

---

### 2. Code Quality (code-reviewer, refactoring-specialist)

**Triggers**: Review code, check for bugs, before commit, PR review

**Agents**:

**code-reviewer** (Sonnet)
- **Use for**: Code review with structured feedback
- **Output**: Issues by category (BUG/SECURITY/PERF/QUALITY), Verdict (APPROVE/REQUEST_CHANGES)
- **When**: BEFORE commits/PRs

**refactoring-specialist** (Opus)
- **Use for**: Safe refactoring plans
- **Output**: Code Smells, Refactoring Steps, Risk Assessment, Rollback Plan
- **When**: Improving structure without changing behavior

**Pattern**:
1. Use `code-reviewer` BEFORE commits/PRs
2. Use `refactoring-specialist` when improving structure without changing behavior

**Example**:
```
User: "Review my changes before commit"

Task(subagent_type="code-reviewer", description="Pre-commit review")
# Wait for verdict
# If APPROVE → commit
# If REQUEST_CHANGES → fix issues, re-review
```

---

### 3. Architecture (architecture-explorer, system-architect)

**Triggers**: How does X work, architecture question, system design, integration

**Agents**:

**architecture-explorer** (Sonnet) - PROACTIVE
- **Use for**: Understanding codebase architecture, data flows
- **When**: "How does X work?", exploring systems, understanding integration
- **Proactive**: Use without being explicitly asked

**system-architect** (Sonnet)
- **Use for**: Technical architecture, algorithms, scalability
- **Output**: Architecture Analysis, Design Recommendations, Trade-offs
- **When**: Designing new systems, evaluating algorithms

**Pattern**: Use `architecture-explorer` for "how does X work?" questions

**Example**:
```
User: "How does the authentication flow work?"

Task(subagent_type="architecture-explorer", description="Understand auth flow")
# Agent explores: login endpoint → middleware → JWT validation → protected routes
```

---

### 4. Database (database-navigator, database-architect)

**Triggers**: Schema, query, database, SQL, migration, data model

**Agents**:

**database-navigator** (Sonnet) - PROACTIVE
- **Use for**: Exploring schemas, understanding data models
- **When**: Schema questions, migration analysis, understanding relationships
- **Proactive**: Use without being explicitly asked

**database-architect** (Opus)
- **Use for**: Schema design, query optimization, data modeling
- **Output**: Schema Analysis, Query Optimization, Index Recommendations
- **When**: Designing new schemas, optimizing queries

**Example**:
```
User: "What's the database structure?"

Task(subagent_type="database-navigator", description="Explore database schema")
# Agent maps: tables, relationships, foreign keys, migrations
```

---

### 5. Security (security-engineer)

**Triggers**: Security, vulnerability, auth, encryption, compliance

**Agents**:

**security-engineer** (Opus)
- **Use for**: Security analysis, threat modeling, compliance
- **Output**: Threat Model, Vulnerabilities, Security Recommendations
- **When**: Auth implementation, data handling, compliance requirements

**Example**:
```
User: "Review this authentication code for security"

Task(subagent_type="security-engineer", description="Security review of auth implementation")
# Agent checks: password handling, token security, injection risks, session management
```

---

### 6. Git Operations (git-workflow-manager)

**Triggers**: Git conflict, branching strategy, git history, merge issues

**Agents**:

**git-workflow-manager** (Sonnet)
- **Use for**: Git workflows, conflict resolution, history management
- **Output**: Workflow Recommendation, Step-by-Step Commands, Rollback Plan
- **When**: Merge conflicts, complex git operations, branching decisions

**Example**:
```
User: "I have merge conflicts in 5 files"

Task(subagent_type="git-workflow-manager", description="Resolve merge conflicts")
# Agent provides: conflict resolution strategy, step-by-step git commands, verification steps
```

---

### 7. DevOps (devops-sre)

**Triggers**: Deployment, monitoring, production, incident, CI/CD

**Agents**:

**devops-sre** (Sonnet)
- **Use for**: Operational concerns, production readiness
- **Output**: Operational Analysis, Monitoring Recommendations, Incident Response
- **When**: Deployment issues, production bugs, monitoring setup, incident response

**Example**:
```
User: "App is slow in production"

Task(subagent_type="devops-sre", description="Analyze production performance issue")
# Agent checks: metrics, logs, resource usage, scaling, database performance
```

---

### 8. Complex Tasks (brainstorm-coordinator)

**Triggers**: Multiple perspectives needed, brainstorming, complex decision

**Agents**:

**brainstorm-coordinator** (Sonnet)
- **Use for**: Coordinating multiple specialists
- **Output**: Synthesized recommendations from multiple agents
- **Special**: Can spawn other agents in parallel (meta-agent)
- **When**: Design decisions, trade-off analysis, multi-perspective needed

**Example**:
```
User: "Should we use microservices or monolith?"

Task(subagent_type="brainstorm-coordinator", description="Analyze architecture decision: microservices vs monolith")

# brainstorm-coordinator spawns:
- system-architect (technical perspective)
- devops-sre (operational perspective)
- product-dx-specialist (developer experience)

# Then synthesizes all perspectives into recommendation
```

---

### 9. Context Management (context-manager, session-summarizer)

**Triggers**: Session handoff, context optimization, memory management

**Agents**:

**context-manager** (Sonnet)
- **Use for**: Context optimization, handoff summaries
- **Output**: Optimized context, Session summary for continuation
- **When**: Session getting long, preparing for handoff, context cleanup

**session-summarizer** (Haiku)
- **Use for**: Quick session summaries for sync
- **Output**: Concise summary optimized for Claude Web/Desktop/Mobile
- **When**: End of session, sync to other devices

**Example**:
```
User: "Summarize this session for continuation tomorrow"

Task(subagent_type="context-manager", description="Create session handoff summary")
# Agent extracts: key decisions, progress made, next steps
```

---

## Parallel Spawning Strategies

### When to Spawn Multiple Agents

**Principle**: When investigating complex issues, spawn multiple agents in PARALLEL (not sequential)

**How**: Single message with multiple Task tool calls

```
# CORRECT - Parallel (single message, 3 Task calls)
Task(subagent_type="error-detective", prompt="RCA for error X")
Task(subagent_type="code-reviewer", prompt="Review related code")
Task(subagent_type="architecture-explorer", prompt="Understand system Y")

# WRONG - Sequential (3 separate messages)
Message 1: Task(subagent_type="error-detective", ...)
[wait for result]
Message 2: Task(subagent_type="code-reviewer", ...)
[wait for result]
Message 3: Task(subagent_type="architecture-explorer", ...)
```

### Example Scenarios

**Bug Investigation**:
```
Spawn simultaneously:
- error-detective (find root cause)
- code-reviewer (check related code quality)
- architecture-explorer (understand affected systems)
```

**Pre-Refactor Analysis**:
```
Spawn simultaneously:
- refactoring-specialist (plan the refactor)
- code-reviewer (identify issues to fix)
- database-navigator (if DB schema affected)
```

**New Feature Design**:
```
Spawn simultaneously:
- architecture-explorer (understand existing patterns)
- security-engineer (security considerations)
- database-navigator (schema requirements)
```

---

## Complete Agent Index

| Agent | Model | Category | Use For |
|-------|-------|----------|---------|
| **error-detective** | Opus | Debugging | Root cause analysis (RCA) |
| **debugger** | Opus | Debugging | Systematic debugging, code tracing |
| **code-reviewer** | Sonnet | Code Quality | Pre-commit review, bug detection |
| **refactoring-specialist** | Opus | Code Quality | Safe refactoring plans |
| **architecture-explorer** | Sonnet | Architecture | Understanding systems, data flows |
| **system-architect** | Sonnet | Architecture | Technical design, algorithms |
| **database-navigator** | Sonnet | Database | Schema exploration, data models |
| **database-architect** | Opus | Database | Schema design, query optimization |
| **security-engineer** | Opus | Security | Threat modeling, vulnerabilities |
| **git-workflow-manager** | Sonnet | Git | Conflict resolution, git workflows |
| **devops-sre** | Sonnet | DevOps | Production readiness, incidents |
| **brainstorm-coordinator** | Sonnet | Complex | Multi-perspective coordination |
| **context-manager** | Sonnet | Context | Session optimization, handoffs |
| **session-summarizer** | Haiku | Context | Quick session summaries |
| **github-issue-tracker** | Sonnet | Tools | GitHub issue management |
| **product-dx-specialist** | Sonnet | Product | Developer experience, API design |
| **agent-developer** | Haiku | Development | Mini-agent development |

---

## Model Selection Guide

**Opus (Deep Reasoning)**:
- Use for: Complex analysis, design decisions, security
- Agents: error-detective, debugger, refactoring-specialist, database-architect, security-engineer, system-architect
- Cost: Higher, use for critical thinking

**Sonnet (Balanced)**:
- Use for: Exploration, review, coordination, operational tasks
- Agents: code-reviewer, architecture-explorer, database-navigator, git-workflow-manager, devops-sre, brainstorm-coordinator, context-manager
- Cost: Moderate, good for frequent use

**Haiku (Quick)**:
- Use for: Fast tasks, summaries, lightweight operations
- Agents: session-summarizer, agent-developer
- Cost: Low, use for simple tasks

---

## Anti-Patterns

### Don't Do This:

❌ **Use Task/Explore agent for dependency queries**
   - **Problem**: Slow, incomplete, can't detect circular dependencies
   - **Instead**: Use `query-deps` tool

❌ **Work on complex bugs without error-detective**
   - **Problem**: Guessing causes, wasting time, treating symptoms
   - **Instead**: Get RCA first, then fix root cause

❌ **Refactor without refactoring-specialist**
   - **Problem**: Break things, introduce bugs, unsafe changes
   - **Instead**: Get plan, ensure safe incremental changes

❌ **Commit without code-reviewer**
   - **Problem**: Bugs ship to production
   - **Instead**: Catch bugs before they're committed

❌ **Spawn agents sequentially when they can run in parallel**
   - **Problem**: Wastes time, inefficient
   - **Instead**: Single message, multiple Task calls

---

## Decision Matrix

| Task Type | Direct Work | Single Agent | Multiple Agents (Parallel) |
|-----------|-------------|--------------|----------------------------|
| Simple edit (<3 files) | ✅ | ❌ | ❌ |
| Bug with clear cause | ✅ | ❌ | ❌ |
| Bug with unclear cause | ❌ | ✅ error-detective | ❌ |
| Complex bug (multiple theories) | ❌ | ❌ | ✅ error-detective + debugger + architecture-explorer |
| Code review | ❌ | ✅ code-reviewer | ❌ |
| Architecture question | ❌ | ✅ architecture-explorer | ❌ |
| Multi-file refactoring | ❌ | ❌ | ✅ refactoring-specialist + code-reviewer + impact-analysis |
| Design decision | ❌ | ❌ | ✅ brainstorm-coordinator (spawns specialists) |

---

## Usage Examples

### Example 1: Simple Debugging (Single Agent)

```
User: "Getting TypeError: Cannot read property 'name' of undefined"

# Clear error, likely simple null check issue
Task(
  subagent_type="error-detective",
  description="RCA for TypeError",
  prompt="Analyze TypeError in user.name access - likely null/undefined user object"
)

# error-detective returns:
# Root Cause: Missing null check
# Fix: Add validation before property access
# Confidence: 90%

# Apply fix directly (no need for debugger)
```

---

### Example 2: Complex Debugging (Parallel Agents)

```
User: "Application crashes on startup, no error message"

# Complex, multiple potential causes
# Spawn 3 agents in PARALLEL (single message):

Task(
  subagent_type="error-detective",
  description="RCA for startup crash",
  prompt="Application exits on startup with no error. Investigate dependency issues, env vars, database connection"
)

Task(
  subagent_type="devops-sre",
  description="Check production environment",
  prompt="Verify environment variables, service health, resource availability"
)

Task(
  subagent_type="database-navigator",
  description="Check database connectivity",
  prompt="Verify database connection, migrations, schema state"
)

# All 3 run simultaneously
# Synthesize findings: Database connection timeout (env var missing)
```

---

### Example 3: Pre-Refactor Analysis (Parallel Agents)

```
User: "Refactor the authentication module"

# Spawn 3 agents in PARALLEL:

Task(
  subagent_type="refactoring-specialist",
  description="Plan auth module refactor",
  prompt="Create safe refactoring plan for authentication module"
)

Task(
  subagent_type="code-reviewer",
  description="Identify code smells",
  prompt="Review auth module for code quality issues"
)

Task(
  subagent_type="security-engineer",
  description="Security review",
  prompt="Review auth module for security vulnerabilities"
)

# Synthesize:
# - Refactoring plan (step-by-step)
# - Known issues to fix during refactor
# - Security considerations to maintain
```

---

### Example 4: Architecture Understanding (Single Agent)

```
User: "How does the SSE streaming work?"

Task(
  subagent_type="architecture-explorer",
  description="Understand SSE streaming architecture",
  prompt="Explore and explain how Server-Sent Events streaming is implemented"
)

# architecture-explorer investigates:
# - SSE endpoint setup
# - Event emitter pattern
# - Client connection management
# - Data flow from backend to frontend
```

---

### Example 5: Design Decision (Meta-Agent)

```
User: "Should we use REST or GraphQL for the new API?"

Task(
  subagent_type="brainstorm-coordinator",
  description="Analyze API design decision",
  prompt="""
Analyze trade-offs between REST and GraphQL for new API.

Context:
- Mobile app + web frontend
- Complex data relationships
- Team has REST experience

Perspectives needed:
- Technical architecture
- Developer experience
- Operational complexity
"""
)

# brainstorm-coordinator spawns specialists:
# - system-architect (technical trade-offs)
# - product-dx-specialist (developer experience)
# - devops-sre (operational concerns)

# Then synthesizes unified recommendation
```

---

## Agent Coordination Patterns

### Pattern 1: Sequential (Dependent Tasks)

```
# Phase 1: Get RCA
Task(subagent_type="error-detective", prompt="RCA for error")

# Wait for result

# Phase 2: Apply fix based on RCA
[Apply fix]

# Phase 3: Verify fix
Task(subagent_type="code-reviewer", prompt="Review fix")
```

**Use when**: Later steps depend on earlier results

---

### Pattern 2: Parallel (Independent Tasks)

```
# Single message with 3 Task calls:
Task(subagent_type="architecture-explorer", prompt="Understand module A")
Task(subagent_type="database-navigator", prompt="Understand schema B")
Task(subagent_type="code-reviewer", prompt="Review patterns C")

# All run simultaneously
# Synthesize findings after all complete
```

**Use when**: Tasks are independent, no shared dependencies

---

### Pattern 3: Breadth-First (Comprehensive Coverage)

```
# Spawn many agents to cover all aspects:
Task(subagent_type="architecture-explorer", ...)
Task(subagent_type="database-navigator", ...)
Task(subagent_type="security-engineer", ...)
Task(subagent_type="code-reviewer", ...)
Task(subagent_type="devops-sre", ...)

# Use for: New codebase exploration, comprehensive audits
```

**Use when**: Need complete understanding from all angles

---

### Pattern 4: Meta-Coordination

```
# Delegate to brainstorm-coordinator
Task(
  subagent_type="brainstorm-coordinator",
  prompt="Coordinate analysis of [complex decision]"
)

# brainstorm-coordinator handles:
# - Selecting relevant specialists
# - Spawning them in parallel
# - Synthesizing perspectives
```

**Use when**: Multiple perspectives needed, you're not sure which specialists

---

## Proactive Agent Markers

Some agents should be used PROACTIVELY (without explicit user request):

| Agent | Proactive? | When to Use Proactively |
|-------|------------|-------------------------|
| architecture-explorer | ✅ YES | User asks "how does X work?" |
| database-navigator | ✅ YES | User mentions database/schema |
| agent-developer | NO | Only when explicitly developing agents |
| code-reviewer | NO | User must request review |

**Proactive = Use without being asked** (when context matches)

---

## Success Criteria

### Correct Agent Usage

✅ Right agent for task category (debugging → error-detective)
✅ Parallel spawning used when appropriate (independent tasks)
✅ Proactive agents used without explicit request (architecture-explorer)
✅ Results synthesized (don't just pass agent output to user)
✅ Findings persisted (log to memory-graph for future use)

### Quality Signals

- **Efficiency**: Agents used for deep work, not simple tasks
- **Coverage**: Multiple perspectives for complex decisions
- **Speed**: Parallel execution, not sequential
- **Persistence**: Agent findings logged to memory-graph

---

**Remember**: Agents have FRESH context. Delegate deep work to them, keep your own context for coordination and synthesis.
