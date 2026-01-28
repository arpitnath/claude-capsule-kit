# Claude Capsule Kit - Best Practices

Guidelines for getting the most value from Capsule Kit's context memory and tool ecosystem.

---

## Required Behaviors

### High Priority

#### ✅ Check Capsule Before Redundant File Reads

**Why**: Capsule tracks files already accessed this session. Don't re-read what you already know.

**How**:
```bash
# Before reading a file
cat .claude/capsule.toon | grep "FILES" | grep "filename"

# If file shown in capsule (and recent):
# → Reference capsule content instead of re-reading
# → Only re-read if stale (>30 min) or needs fresh view
```

**Example**:
```
User: "What did we change in auth.service.ts?"

# BAD: Re-read file
Read(file_path="src/auth/auth.service.ts")

# GOOD: Check capsule first
cat .claude/capsule.toon | grep "auth.service.ts"
# Shows: "read, 5m ago" → reference from memory

"We modified auth.service.ts 5 minutes ago to add JWT validation..."
```

---

#### ✅ Reference Capsule Context in Responses

**Why**: Users appreciate when you remember session context

**How**:
```bash
# Check capsule for session state
cat .claude/capsule.toon

# Reference in responses:
"Based on our earlier work on X..."
"As discovered 10 minutes ago when we analyzed Y..."
"Following the pattern we found in Z file..."
```

**Example**:
```
User: "Now add logout functionality"

# Reference capsule:
cat .claude/capsule.toon | grep "TASK\|FILES"

Response:
"Building on the authentication system we implemented earlier (auth.service.ts),
I'll add logout by invalidating the JWT token..."
```

---

### Medium Priority

#### ✅ Capture Sub-Agent Findings Immediately

**Why**: Agent insights are valuable—log them before they're lost

**How**:
```bash
# After Task tool returns with agent findings:
bash .claude/hooks/log-subagent.sh "<agent-type>" "<summary-of-findings>"
```

**Example**:
```
# After error-detective analysis:
Task(subagent_type="error-detective", ...) # returns RCA

# Log the findings:
bash .claude/hooks/log-subagent.sh "error-detective" "TypeError root cause: missing null check in user.name access"
```

---

#### ✅ Note Architectural Discoveries as You Learn

**Why**: Architectural insights help future sessions, prevent re-learning

**How**:
```bash
# When you discover patterns, decisions, or insights:
bash .claude/hooks/log-discovery.sh "<category>" "<insight>"

# Categories:
# - pattern: Code patterns, architectural patterns
# - insight: Important realizations, gotchas
# - decision: Why something was done a certain way
# - architecture: System structure, component relationships
# - bug: Bug causes and fixes
# - optimization: Performance improvements
```

**Example**:
```
# During exploration:
"I see this codebase uses Repository pattern for data access"

# Log it:
bash .claude/hooks/log-discovery.sh "pattern" "Repository pattern used for data access layer"

# Later session can query:
bash .claude/tools/memory-graph/memory-query.sh --search "repository"
# Returns: "Repository pattern used for data access layer"
```

---

## Forbidden Behaviors

### Critical

#### ❌ NEVER Ignore the Capsule

**Problem**: Defeats the entire purpose of Capsule Kit

**What NOT to do**:
- Skip checking capsule before work
- Treat capsule as optional
- Only use capsule when reminded

**What to DO**:
- Check capsule FIRST (before redundant operations)
- Make it automatic: "Check capsule, then act"
- Reference capsule in responses

---

### High Priority

#### ❌ DON'T Re-Read Files Shown in Capsule (Unless Stale)

**Problem**: Wastes tokens, ignores session memory

**What NOT to do**:
```
User: "What's in auth.service.ts?"

# Capsule shows: "auth.service.ts, read, 5m ago"
# BAD: Re-read anyway
Read(file_path="src/auth/auth.service.ts")
```

**What to DO**:
```
# Check capsule first
cat .claude/capsule.toon | grep "auth.service.ts"
# Shows: "read, 5m ago"

# Reference from memory:
"From our reading 5 minutes ago, auth.service.ts contains JWT validation..."

# Only re-read if:
# - Capsule shows >30 min ago (might be stale)
# - User made changes since last read
# - Need fresh detailed view
```

---

### Medium Priority

#### ❌ DON'T Launch Duplicate Sub-Agents for Same Task

**Problem**: Wastes time and API costs

**What NOT to do**:
```
# Message 1:
Task(subagent_type="architecture-explorer", prompt="Understand auth flow")

# Message 5:
Task(subagent_type="architecture-explorer", prompt="How does auth work?")
# ^ Same question! Check capsule first
```

**What to DO**:
```bash
# Before launching agent, check capsule:
cat .claude/capsule.toon | grep "SUBAGENT" | grep "architecture-explorer"

# If recent finding exists:
# → Reference previous agent's findings
# → Don't re-run unless context changed
```

---

## Efficient Workflow Patterns

### Pattern 1: Check → Work → Log

```
1. CHECK context (capsule + memory-graph)
   ↓
2. WORK (use tools/agents as needed)
   ↓
3. LOG discoveries (file access, findings, decisions)
```

**Example**:
```bash
# 1. CHECK
cat .claude/capsule.toon | grep "auth"
bash .claude/tools/memory-graph/memory-query.sh --search "authentication"

# 2. WORK
Read(file_path="src/auth/login.ts")
[analyze code]

# 3. LOG
bash .claude/hooks/log-file-access.sh "src/auth/login.ts" "read"
bash .claude/hooks/log-discovery.sh "pattern" "Login uses bcrypt for password hashing"
```

---

### Pattern 2: Parallel Agent Spawning

```
# DON'T do this (sequential):
Message 1: Task(subagent_type="agent-1", ...)
[wait]
Message 2: Task(subagent_type="agent-2", ...)
[wait]
Message 3: Task(subagent_type="agent-3", ...)

# DO this (parallel):
# Single message, 3 Task calls:
Task(subagent_type="agent-1", ...)
Task(subagent_type="agent-2", ...)
Task(subagent_type="agent-3", ...)

# All run simultaneously (3x faster)
```

---

### Pattern 3: Progressive File Reading

```
# Large file (>50KB)

# DON'T:
Read(file_path="large-file.ts")  # Might fail or waste 12,000+ tokens

# DO:
# Step 1: List structure
$HOME/.claude/bin/progressive-reader --path large-file.ts --list

# Step 2: Read specific chunk
$HOME/.claude/bin/progressive-reader --path large-file.ts --chunk 2

# 75-97% token savings
```

---

### Pattern 4: Tool Selection Hierarchy

```
Dependency question?
  ↓
  Use specialized tool (query-deps, impact-analysis)
    NOT Task/Explore

Large file (>50KB)?
  ↓
  Use progressive-reader
    NOT Read

File/code search?
  ↓
  Use Glob/Grep
    NOT Task/Explore

Complex architectural analysis?
  ↓
  THEN use Task with architecture-explorer agent
```

---

## Success Metrics

### You're Using Capsule Kit Well If:

✅ **Fewer redundant file reads** - Check capsule first, reference memory
✅ **Better task continuity** - Sessions build on previous work
✅ **Richer context** - Discoveries accumulated over time
✅ **Faster responses** - Right tools, parallel agents, efficient reading
✅ **Persistent learning** - Memory-graph grows with knowledge

### Warning Signs of Poor Usage:

❌ Re-reading files multiple times per session
❌ Not using specialized tools (falling back to Task/Explore)
❌ Sequential agent spawning (wasting time)
❌ Empty capsule (no logging happening)
❌ Empty memory-graph (discoveries not persisted)

---

## Common Mistakes

### Mistake 1: "I'll just read the file quickly"

**Problem**: Quick reads add up, overwhelm context

**Fix**:
```bash
# Check capsule first
cat .claude/capsule.toon | grep "filename"

# If already read recently → reference it
# If not in capsule → then read
```

---

### Mistake 2: "Task/Explore is easier for dependencies"

**Problem**: 10x slower than specialized tools

**Fix**:
```bash
# NOT:
Task(subagent_type="Explore", prompt="Find what imports auth.ts")

# INSTEAD:
bash .claude/tools/query-deps/query-deps.sh src/auth/auth.ts
# Instant result, complete graph
```

---

### Mistake 3: "I'll debug this myself"

**Problem**: Complex bugs need RCA, not guessing

**Fix**:
```
# NOT:
[Read files, guess causes, try fixes]

# INSTEAD:
Task(subagent_type="error-detective", prompt="RCA for [error]")
# Get root cause, then fix
```

---

### Mistake 4: "I'll spawn agents one by one"

**Problem**: Sequential is slower than parallel

**Fix**:
```
# NOT (3 messages):
Message 1: Task(subagent_type="agent-1", ...)
Message 2: Task(subagent_type="agent-2", ...)
Message 3: Task(subagent_type="agent-3", ...)

# INSTEAD (1 message):
Task(subagent_type="agent-1", ...)
Task(subagent_type="agent-2", ...)
Task(subagent_type="agent-3", ...)
```

---

### Mistake 5: "I found something interesting... I'll remember it"

**Problem**: You won't remember it next session

**Fix**:
```bash
# When you discover something:
bash .claude/hooks/log-discovery.sh "insight" "Module X uses pattern Y for Z reason"

# Future session:
bash .claude/tools/memory-graph/memory-query.sh --search "Module X"
# Returns your discovery
```

---

## Integration with Skills

Skills automate many of these best practices:

| Best Practice | Skill |
|---------------|-------|
| Check capsule + memory before work | `/deep-context` |
| Use error-detective for debugging | `/debug` |
| Code review before commit | `/code-review` |
| Systematic approach to complex tasks | `/workflow` |

**Recommendation**: Use skills for complex work—they enforce best practices automatically.

---

## Quick Checklist

Before starting any task:

- [ ] Check capsule for session context
- [ ] Query memory-graph for historical knowledge
- [ ] Use specialized tools (not Task/Explore)
- [ ] Launch agents for deep work (parallel when possible)
- [ ] Log discoveries as you learn
- [ ] Persist knowledge to memory-graph

---

**Remember**: Capsule Kit makes you smarter over time. Use it consistently, and future sessions start with accumulated knowledge instead of from scratch.
