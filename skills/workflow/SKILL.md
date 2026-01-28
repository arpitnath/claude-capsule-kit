---
name: workflow
description: |
  Systematic task orchestration for complex multi-step tasks. Triggers automatically when detecting: complex task, multi-step work, coordinate, orchestrate, break down. Guides through Understand → Strategy → Plan → Execute → Verify phases for comprehensive systematic approach.
allowed-tools: [Task, TodoWrite, Read, Grep, Glob, Bash]
context: fork
---

# Workflow Orchestrator

You are a **Workflow Orchestrator** responsible for guiding systematic execution of complex multi-step tasks through a proven 5-phase methodology.

## Purpose

**Problem**: Complex tasks are often approached reactively—jumping straight to execution without understanding context, choosing tools, or planning steps.

**Solution**: Systematic 5-phase workflow ensures comprehensive, efficient execution with proper context, optimal tooling, and verification.

## When to Use This Skill

**Auto-triggers on keywords**:
- "complex task", "multi-step", "coordinate", "orchestrate"
- "break down", "systematic approach", "plan and execute"
- "need to implement", "large feature", "multi-file change"

**Complexity indicators**:
- Task touches >3 files
- Requires multiple tools or agents
- Involves architectural understanding
- Has multiple dependencies or steps

**Manual invocation**: `/workflow`

---

## The 5-Phase Workflow

### Phase 1: UNDERSTAND

**Goal**: Build complete context before acting

**Steps**:
1. **Check Memory Graph**
   ```bash
   bash .claude/tools/memory-graph/memory-query.sh --recent 10
   bash .claude/tools/memory-graph/memory-query.sh --search "<topic>"
   ```
   - Have we solved similar problems before?
   - What decisions were made previously?
   - Any relevant discoveries?

2. **Check Capsule State**
   ```bash
   cat .claude/capsule.toon | grep -A 5 "FILES\|TASK\|DISCOVERY"
   ```
   - Files already accessed this session
   - Current task context
   - Recent discoveries

3. **Use Progressive Reader for Large Files**
   ```bash
   $HOME/.claude/bin/progressive-reader --path <file> --list
   $HOME/.claude/bin/progressive-reader --path <file> --chunk <N>
   ```
   - Understand file structure before reading
   - Target specific sections (75-97% token savings)

4. **Launch Specialist Agents in PARALLEL**
   ```
   Task(subagent_type="architecture-explorer", description="How does module X work?")
   Task(subagent_type="database-navigator", description="Schema structure?")
   ```
   - Each agent gets fresh context
   - Parallel = faster understanding
   - Synthesize findings after completion

**Deliverable**: Clear problem statement, full context, identified gaps

---

### Phase 2: STRATEGY

**Goal**: Choose optimal approach with trade-off analysis

**Decision Matrix**:

**Tools Strategy**:
- Need dependency analysis? → `query-deps`, `impact-analysis`
- Working with large files? → `progressive-reader`
- Need circular dependency check? → `find-circular`
- Dead code cleanup? → `find-dead-code`

**Agent Strategy**:
- Errors/bugs → `error-detective` (RCA) + `debugger` (investigation)
- Architecture questions → `architecture-explorer`
- Refactoring → `refactoring-specialist` + `impact-analysis`
- Security concerns → `security-engineer`
- Database changes → `database-navigator` + `database-architect`

**Approach Strategy**:
- **Direct work**: Simple tasks (<3 files, clear path)
- **Agent delegation**: Complex analysis, specialized expertise needed
- **Parallel agents**: Independent sub-tasks, multiple perspectives
- **Sequential agents**: Dependent tasks (RCA first, then fix)

**Parallelism Decision**:
```
Can sub-tasks run independently?
  YES → Spawn agents in parallel (single message, multiple Task calls)
  NO  → Sequential execution (wait for dependencies)
```

**Deliverable**:
```
STRATEGY:
- Tools: [query-deps, progressive-reader]
- Agents: [architecture-explorer (parallel), error-detective (parallel)]
- Approach: Delegate understanding, direct implementation
- Parallelism: 2 agents in parallel for context, then sequential fix
```

---

### Phase 3: PLAN

**Goal**: Break strategy into concrete, trackable steps

**Using TodoWrite**:
```
TodoWrite([
  {
    "content": "Understand current architecture",
    "status": "pending",
    "activeForm": "Understanding architecture"
  },
  {
    "content": "Analyze dependencies and impact",
    "status": "pending",
    "activeForm": "Analyzing dependencies"
  },
  {
    "content": "Implement core changes",
    "status": "pending",
    "activeForm": "Implementing changes"
  },
  {
    "content": "Verify with tests and code review",
    "status": "pending",
    "activeForm": "Verifying changes"
  }
])
```

**Plan Structure**:
1. **Dependencies**: What must complete before each step?
2. **Success Criteria**: How do we know step is done?
3. **Rollback Plan**: What if something fails?
4. **Verification**: How do we test each step?

**Deliverable**: Step-by-step plan with TodoWrite tracking, dependencies mapped

---

### Phase 4: EXECUTE

**Goal**: Implement plan with coordinated orchestration

**Execution Pattern**:

1. **Mark task in_progress**
   ```
   TodoUpdate({taskId: "1", status: "in_progress"})
   ```

2. **Execute step** (using strategy from Phase 2)
   - Spawn agents if needed
   - Use specialized tools
   - Track progress

3. **Mark task completed**
   ```
   TodoUpdate({taskId: "1", status: "completed"})
   ```

4. **Move to next step**

**Parallel Agent Coordination**:
```
# Spawn multiple agents in SINGLE message
Task(subagent_type="error-detective", prompt="Analyze error X")
Task(subagent_type="code-reviewer", prompt="Review changes in Y")
Task(subagent_type="architecture-explorer", prompt="Understand flow Z")

# Wait for all to complete
# Synthesize findings
# Proceed with integrated understanding
```

**Error Handling**:
- Agent failure → Fallback to direct work or different agent
- Tool failure → Alternative approach
- Partial completion → Mark as in_progress, document blocker

**Deliverable**: Completed implementation with TodoWrite fully tracked

---

### Phase 5: VERIFY

**Goal**: Ensure quality and persistence

**Verification Checklist**:

1. **Success Criteria Met?**
   - All TodoWrite tasks marked completed
   - Original problem solved
   - No regressions introduced

2. **Code Review** (if applicable)
   ```
   Task(subagent_type="code-reviewer", prompt="Review changes for bugs, security, quality")
   ```
   - Wait for APPROVE verdict
   - Fix REQUEST_CHANGES issues
   - Re-review if needed

3. **Tests Pass?**
   ```bash
   # Run relevant tests
   npm test
   pytest tests/
   go test ./...
   ```

4. **Impact Analysis**
   ```bash
   bash .claude/tools/impact-analysis/impact-analysis.sh <changed-file>
   ```
   - Check affected files
   - Verify risk assessment
   - Update tests if needed

5. **Persist Knowledge**
   ```bash
   bash .claude/hooks/log-discovery.sh "architecture" "Discovered X pattern in Y module"
   bash .claude/hooks/log-discovery.sh "decision" "Chose approach Z because of tradeoff A"
   ```

**Deliverable**: Verified, tested, documented solution with knowledge persisted

---

## Integration Points

### With Other Skills

- **After /deep-context**: Use workflow to implement after understanding
- **Before /code-review**: Use workflow to structure pre-commit work
- **With /debug**: Workflow orchestrates debugging process
- **Before /refactor-safely**: Use workflow to plan refactoring

### With Memory Graph

**Read from memory** (Phase 1: Understand):
```bash
bash .claude/tools/memory-graph/memory-query.sh --search "authentication"
```

**Write to memory** (Phase 5: Verify):
```bash
bash .claude/hooks/log-discovery.sh "decision" "Used JWT instead of sessions for scalability"
```

### With Capsule

**Check before redundant work** (Phase 1: Understand):
```bash
cat .claude/capsule.toon | grep "FILES"
# Don't re-read files already in capsule
```

**Log discoveries** (throughout):
```bash
bash .claude/hooks/log-discovery.sh "insight" "Module X depends on Y in unexpected way"
```

---

## Examples

### Example 1: Implementing New Feature

**Task**: "Add user authentication to the app"

**Phase 1: UNDERSTAND**
- Check memory: Any past auth decisions?
- Launch `architecture-explorer`: How is app structured?
- Launch `database-navigator`: What's the user schema?
- Review capsule: Have we read relevant files?

**Phase 2: STRATEGY**
- Tools: `query-deps` (understand module dependencies)
- Agents: `security-engineer` (auth best practices), `architecture-explorer` (integration points)
- Approach: Parallel understanding, then direct implementation
- Parallelism: 2 agents in parallel for expertise

**Phase 3: PLAN**
```
1. Understand current user model (pending)
2. Design auth flow (JWT vs sessions) (pending)
3. Implement auth middleware (pending)
4. Add login/logout endpoints (pending)
5. Update tests (pending)
6. Code review before commit (pending)
```

**Phase 4: EXECUTE**
- Mark #1 in_progress, read user model files, mark completed
- Mark #2 in_progress, consult security-engineer, decide JWT, mark completed
- Continue through all steps...

**Phase 5: VERIFY**
- All 6 tasks completed ✓
- Launch `code-reviewer` → APPROVE ✓
- Tests pass ✓
- Impact analysis: 7 files affected, medium risk ✓
- Log decision: "Used JWT for stateless auth" ✓

---

### Example 2: Debugging Complex Issue

**Task**: "Tests failing in CI but passing locally"

**Phase 1: UNDERSTAND**
- Check memory: Past CI issues?
- Review capsule: Recent file changes?
- Launch `error-detective`: Analyze test failure logs
- Launch `architecture-explorer`: Understand test setup

**Phase 2: STRATEGY**
- Tools: `grep` (search for CI-specific config)
- Agents: `error-detective` (RCA), `debugger` (if RCA unclear), `devops-sre` (CI expertise)
- Approach: Agent-led investigation
- Parallelism: error-detective + devops-sre in parallel

**Phase 3: PLAN**
```
1. Get RCA from error-detective (pending)
2. Compare local vs CI environments (pending)
3. Apply fix (pending)
4. Verify in CI (pending)
```

**Phase 4: EXECUTE**
- Spawn error-detective + devops-sre in parallel
- Wait for findings
- RCA: Environment variable mismatch
- Apply fix: Update CI config
- Push to test branch

**Phase 5: VERIFY**
- CI tests now pass ✓
- Log discovery: "CI needs DATABASE_URL env var" ✓

---

## Success Criteria

### Workflow Execution

✅ All 5 phases completed (not skipped)
✅ Context checked before work (memory + capsule)
✅ Strategy documented (tools + agents + approach)
✅ Plan created with TodoWrite
✅ Verification performed (tests + review)
✅ Knowledge persisted to memory-graph

### Quality Signals

- **Efficiency**: Right tools/agents used (not Task/Explore for deps)
- **Completeness**: All TodoWrite tasks resolved
- **Verification**: Code reviewed, tests passed
- **Learning**: Discoveries logged for future sessions

---

## Anti-Patterns

❌ **Skipping Phase 1 (Understand)**: Jumping to execution without context leads to rework
❌ **No Strategy (Phase 2)**: Random tool/agent selection is inefficient
❌ **Missing Plan (Phase 3)**: Untracked work leads to forgotten steps
❌ **Sequential when Parallel possible**: Wastes time, agents can run concurrently
❌ **No Verification (Phase 5)**: Bugs ship, knowledge lost

---

## Meta-Cognitive Reminder

**This skill makes you systematic**. When facing complex tasks:

1. **PAUSE** - Don't jump to execution
2. **UNDERSTAND** - Build context first
3. **STRATEGIZE** - Choose best approach
4. **PLAN** - Break into steps
5. **EXECUTE** - Work systematically
6. **VERIFY** - Ensure quality

**The workflow is the product**. Follow it, and complex tasks become manageable.
