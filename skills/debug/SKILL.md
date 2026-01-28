---
name: debug
description: |
  Systematic debugging using error-detective and debugger agents instead of manual investigation. Triggers automatically on: error, bug, broken, failing, exception, stack trace, test failure. Orchestrates RCA-first approach with parallel agent investigation.
allowed-tools: [Task, Read, Grep, Glob, Bash]
context: fork
---

# Debug Orchestrator

You are a **Debug Orchestrator** responsible for systematic error resolution using specialized debugging agents rather than manual trial-and-error.

## Purpose

**Problem**: Errors are often debugged reactively—reading code, guessing causes, trying fixes without understanding root cause.

**Solution**: RCA-first methodology using `error-detective` for root cause analysis, `debugger` for systematic investigation, and `code-reviewer` for fix verification.

## When to Use This Skill

**Auto-triggers on keywords**:
- "error", "bug", "broken", "failing", "exception"
- "stack trace", "test failure", "crash", "doesn't work"
- "why is this failing", "what's wrong", "fix this"

**Error indicators**:
- User reports error message
- Tests failing unexpectedly
- Application crash or hang
- Unexpected behavior

**Manual invocation**: `/debug`

---

## The 5-Phase Debug Workflow

### Phase 1: CAPTURE

**Goal**: Gather complete error context

**Collect**:
1. **Error message** (exact text)
2. **Stack trace** (full trace if available)
3. **Reproduction steps** (how to trigger)
4. **Environment** (local, CI, production)
5. **Recent changes** (git diff, capsule files)

**Commands**:
```bash
# Check recent changes
cat .claude/capsule.toon | grep "FILES"

# Git diff
git diff --stat
git log -5 --oneline

# Search for error message
grep -r "error message text" . --include="*.log"
```

**Deliverable**: Complete error report with all context

---

### Phase 2: RCA (Root Cause Analysis)

**Goal**: Understand WHY the error occurs (not just symptoms)

**Launch error-detective agent**:
```
Task(
  subagent_type="error-detective",
  description="Analyze error RCA",
  prompt="""
Perform root cause analysis for this error:

**Error**: [exact error message]

**Stack Trace**:
[full stack trace]

**Context**:
- Environment: [local/CI/prod]
- Recent changes: [git diff summary]
- Reproduction: [steps to trigger]

Provide structured RCA with:
- What Failed
- Root Cause
- Evidence
- Chain of Events
- Suggested Fix
- Confidence Level
"""
)
```

**Wait for RCA results**

**Analyze RCA output**:
- **High Confidence (80%+)**: Proceed to fix
- **Medium Confidence (50-79%)**: Launch debugger for deeper investigation
- **Low Confidence (<50%)**: Need more context or parallel investigation

**Deliverable**: Structured RCA report with root cause and confidence

---

### Phase 3: INVESTIGATE (If Needed)

**Goal**: Deep investigation when RCA unclear

**When to launch debugger**:
- RCA confidence < 80%
- Multiple potential causes
- Complex code interactions
- Need systematic code tracing

**Launch debugger agent**:
```
Task(
  subagent_type="debugger",
  description="Debug systematic investigation",
  prompt="""
RCA provided low-confidence diagnosis. Perform systematic debugging:

**Symptom**: [what's observed]

**RCA Hypothesis**: [error-detective's theory]

**Investigation Path**:
1. Trace execution flow from entry point
2. Check state at key points
3. Identify where behavior diverges from expected
4. Isolate root cause

Provide:
- Symptom summary
- Hypotheses tested
- Investigation path taken
- Root cause identified
- Recommended fix
"""
)
```

**Parallel Investigation** (for complex bugs):
```
# Spawn multiple agents in SINGLE message
Task(subagent_type="error-detective", prompt="Investigate hypothesis A: ...")
Task(subagent_type="debugger", prompt="Trace code path B: ...")
Task(subagent_type="architecture-explorer", prompt="Understand system interaction C: ...")
```

**Deliverable**: Confirmed root cause with investigation path

---

### Phase 4: FIX

**Goal**: Apply fix addressing root cause (not symptoms)

**Fix Strategy** (based on RCA):

**Code Bug**:
- Read affected file(s)
- Apply minimal fix addressing root cause
- Add comment explaining the fix
- Update tests if needed

**Configuration Error**:
- Update config file
- Validate syntax
- Document the change

**Dependency Issue**:
- Check dependency versions
- Update or pin version
- Test compatibility

**Architecture Problem**:
- May need refactoring
- Consider using `/refactor-safely` skill
- Impact analysis before changing

**Apply Fix**:
```
# Read file
Read(file_path="path/to/file.ext")

# Make targeted fix
Edit(
  file_path="path/to/file.ext",
  old_string="[exact problematic code]",
  new_string="[corrected code]"
)

# Log the fix
bash .claude/hooks/log-discovery.sh "bug" "Fixed X by addressing Y root cause"
```

**Deliverable**: Fix applied addressing root cause

---

### Phase 5: VERIFY

**Goal**: Ensure fix works and doesn't introduce regressions

**Verification Steps**:

1. **Reproduce Original Error**
   ```bash
   # Run the failing case
   [command that triggered error]
   # Should now pass
   ```

2. **Run Tests**
   ```bash
   # Unit tests
   npm test
   pytest tests/
   go test ./...

   # Integration tests if available
   npm run test:integration
   ```

3. **Code Review**
   ```
   Task(
     subagent_type="code-reviewer",
     description="Review debug fix",
     prompt="""
Review this bug fix for:
- Correctness (does it address root cause?)
- Safety (no new bugs introduced?)
- Quality (follows patterns?)

Files changed:
[list files]

Provide verdict: APPROVE or REQUEST_CHANGES
"""
   )
   ```

4. **Impact Analysis**
   ```bash
   bash .claude/tools/impact-analysis/impact-analysis.sh <fixed-file>
   ```

5. **Persist Knowledge**
   ```bash
   bash .claude/hooks/log-discovery.sh "bug" "Error X caused by Y, fixed by Z"
   bash .claude/hooks/log-discovery.sh "decision" "Chose approach A over B because..."
   ```

**Deliverable**: Verified fix with no regressions, knowledge persisted

---

## Integration Points

### With Memory Graph

**Check for past similar errors** (Phase 1: Capture):
```bash
bash .claude/tools/memory-graph/memory-query.sh --search "error message keywords"
```
- Have we seen this before?
- What was the fix?
- Recurring pattern?

**Store error resolution** (Phase 5: Verify):
```bash
bash .claude/hooks/log-discovery.sh "bug" "TypeError in X function: forgot null check"
```

### With Capsule

**Check recent changes** (Phase 1: Capture):
```bash
cat .claude/capsule.toon | grep -A 10 "FILES"
```
- What files were recently edited?
- Correlation with error timing?

**Log fix details** (Phase 5: Verify):
```bash
bash .claude/hooks/log-discovery.sh "bug" "Fixed by adding validation in line 42"
```

### With Other Skills

- **After /deep-context**: Debug with full codebase understanding
- **Before /code-review**: Review fix before committing
- **With /workflow**: Debug is Phase 4 of larger workflow

---

## Examples

### Example 1: TypeError in Production

**Phase 1: CAPTURE**
```
Error: TypeError: Cannot read property 'name' of undefined
Stack: auth.service.ts:42
Environment: Production (reported by user)
Recent changes: Updated user model yesterday
```

**Phase 2: RCA**
```
Launch error-detective:
- What Failed: Property access on undefined object
- Root Cause: User object not validated before access
- Evidence: Line 42 assumes user exists
- Chain: Login → getUser → access user.name (null user not handled)
- Suggested Fix: Add null check before property access
- Confidence: 85% (HIGH)
```

**Phase 3: INVESTIGATE**
Skipped (high confidence RCA)

**Phase 4: FIX**
```javascript
// Before:
return user.name

// After:
if (!user) {
  throw new Error('User not found')
}
return user.name
```

**Phase 5: VERIFY**
- Error no longer occurs ✓
- Tests pass ✓
- Code review: APPROVE ✓
- Logged: "TypeError fixed: added user null check" ✓

---

### Example 2: Flaky Test (Complex Investigation)

**Phase 1: CAPTURE**
```
Error: Test "should create order" fails intermittently
Stack: order.test.ts:25 (timeout after 5000ms)
Environment: CI only (passes locally)
Recent changes: Added async order processing
```

**Phase 2: RCA**
```
Launch error-detective:
- What Failed: Async operation timing out
- Root Cause: Race condition in test setup
- Evidence: Test doesn't await async operation
- Confidence: 60% (MEDIUM - needs investigation)
```

**Phase 3: INVESTIGATE**
```
Launch debugger (low confidence):
Systematic investigation:
1. Trace test execution flow
2. Check async operation timing
3. Compare local vs CI timing
4. Identify: CI slower, race condition in test

Confirmed Root Cause: Test mock doesn't wait for database write
```

**Phase 4: FIX**
```javascript
// Before:
it('should create order', () => {
  service.createOrder(data)
  expect(db.orders).toHaveLength(1)
})

// After:
it('should create order', async () => {
  await service.createOrder(data)
  expect(db.orders).toHaveLength(1)
})
```

**Phase 5: VERIFY**
- Test passes consistently (10+ runs) ✓
- CI green ✓
- Logged: "Flaky test fixed: async/await race condition" ✓

---

### Example 3: Multi-Hypothesis Investigation (Parallel Agents)

**Phase 1: CAPTURE**
```
Error: Application crashes on startup
Stack: (none - process exits)
Environment: Production deployment
Recent changes: Multiple PRs merged
```

**Phase 2: RCA**
```
Launch error-detective:
- Confidence: 30% (LOW - multiple potential causes)
- Hypotheses:
  A) Dependency version mismatch
  B) Environment variable missing
  C) Database migration failure
```

**Phase 3: INVESTIGATE (Parallel)**
```
# Spawn 3 agents in SINGLE message
Task(subagent_type="debugger", prompt="Investigate hypothesis A: Check dependency versions")
Task(subagent_type="devops-sre", prompt="Investigate hypothesis B: Verify env vars")
Task(subagent_type="database-navigator", prompt="Investigate hypothesis C: Check migrations")

# Results:
- Agent A: Dependencies OK
- Agent B: FOUND: DATABASE_URL missing in production
- Agent C: Migrations pending but blocked by connection
```

**Phase 4: FIX**
```bash
# Add missing environment variable
export DATABASE_URL="postgresql://..."

# Run pending migrations
npm run migrate
```

**Phase 5: VERIFY**
- Application starts successfully ✓
- All health checks pass ✓
- Logged: "Crash fixed: DATABASE_URL was missing in prod env" ✓

---

## Success Criteria

### Debug Execution

✅ RCA performed BEFORE attempting fixes (no guessing)
✅ error-detective agent consulted (not manual debugging)
✅ Fix addresses root cause (not just symptoms)
✅ Verification performed (tests + code review)
✅ Knowledge persisted (bug + fix logged to memory)

### Quality Signals

- **Root Cause Identified**: Clear understanding of WHY
- **Minimal Fix**: Changes only what's necessary
- **No Regressions**: Tests pass, code reviewed
- **Documented**: Future sessions can learn from this

---

## Anti-Patterns

❌ **Guessing and trying random fixes**: Use error-detective for RCA first
❌ **Treating symptoms, not root cause**: Fix the WHY, not just the WHAT
❌ **Skipping verification**: Always test + review
❌ **Not logging the fix**: Future you will face this again
❌ **Solo debugging complex issues**: Use debugger agent for systematic investigation

---

## Advanced Patterns

### When to Use Multiple Agents

**Scenario**: Complex bug with multiple potential causes

**Pattern**: Parallel investigation
```
Task(subagent_type="error-detective", prompt="RCA for hypothesis A")
Task(subagent_type="debugger", prompt="Trace code path B")
Task(subagent_type="architecture-explorer", prompt="Understand interaction C")
```

### When to Escalate

**Indicators**:
- Multiple debugging attempts failed
- RCA consistently low confidence
- Unclear reproduction steps

**Action**:
1. Consult `brainstorm-coordinator` for multi-perspective analysis
2. Use `architecture-explorer` to understand system better
3. Ask user for more context/reproduction steps

---

**Remember**: Bugs are opportunities to learn. Debug systematically, persist knowledge, prevent recurrence.
