---
name: code-review
description: |
  Pre-commit code review using code-reviewer agent for bug detection, security analysis, and quality assurance. Manual invocation only. Use before git commits to catch issues early. Blocks commits on REQUEST_CHANGES verdict.
allowed-tools: [Task, Read, Grep, Glob, Bash]
disable-model-invocation: true
---

# Code Review Gate

You are a **Code Review Gate** responsible for ensuring code quality, security, and correctness BEFORE commits reach version control.

## Purpose

**Problem**: Bugs, security issues, and quality problems slip into commits because reviews happen after code is already committed.

**Solution**: Mandatory pre-commit review using `code-reviewer` agent with structured feedback and approval workflow.

## When to Use This Skill

**Manual invocation ONLY**: `/code-review`

**When to invoke**:
- Before running `git commit`
- After completing feature implementation
- Before creating pull request
- When user asks "review my changes"

**NOT auto-triggered** (disable-model-invocation: true)

---

## The 5-Phase Review Workflow

### Phase 1: IDENTIFY CHANGES

**Goal**: Determine what needs review

**Git commands**:
```bash
# See all changes
git status

# Staged changes (will be committed)
git diff --cached --stat
git diff --cached

# Unstaged changes (might want to stage first)
git diff --stat
git diff

# Recent commits (if reviewing after commit)
git log -1 --stat
git show HEAD
```

**Categorize changes**:
- **New files**: Complete review needed
- **Modified files**: Focus on changes only
- **Deleted files**: Check dependencies (use impact-analysis)
- **Renamed files**: Verify refactoring correctness

**Deliverable**: List of files to review with change types

---

### Phase 2: LAUNCH REVIEWER

**Goal**: Get structured code review from code-reviewer agent

**Prepare review prompt**:
```
Task(
  subagent_type="code-reviewer",
  description="Pre-commit code review",
  prompt="""
Review these changes for bugs, security issues, performance problems, and code quality:

**Files Changed**:
[List files with brief description of changes]

**Context**:
- Purpose: [what this code does]
- Related: [related files or systems]

**Focus Areas**:
- [BUG]: Logic errors, edge cases
- [SECURITY]: Vulnerabilities, input validation
- [PERF]: Performance issues, N+1 queries
- [QUALITY]: Code smells, maintainability
- [STYLE]: Formatting, naming (low priority)

Provide structured feedback with:
1. Issues categorized by severity
2. Specific line references
3. Suggested fixes
4. Verdict: APPROVE or REQUEST_CHANGES
"""
)
```

**Wait for review results**

**Deliverable**: Structured code review with categorized issues

---

### Phase 3: ANALYZE FEEDBACK

**Goal**: Prioritize issues and plan fixes

**Issue Categories** (from code-reviewer):

**CRITICAL (Must fix before commit)**:
- [BUG] - Logic errors, crashes, data corruption
- [SECURITY] - Vulnerabilities, injection risks, auth bypasses

**WARNINGS (Should fix before commit)**:
- [PERF] - Performance issues, scalability problems
- [QUALITY] - Code smells, maintainability issues

**SUGGESTIONS (Optional, can defer)**:
- [STYLE] - Formatting, naming conventions
- [DOCS] - Missing or unclear comments

**Verdict Analysis**:

**APPROVE**:
- No critical issues found
- No warnings that block commit
- Code meets quality standards
- → Proceed to commit (Phase 5)

**REQUEST_CHANGES**:
- Critical issues present (MUST fix)
- Warnings that should be addressed
- → Fix issues (Phase 4)

**NEEDS_DISCUSSION**:
- Unclear requirements
- Architectural concerns
- → Consult user or brainstorm-coordinator

**Deliverable**: Prioritized issue list with fix plan

---

### Phase 4: FIX ISSUES

**Goal**: Address critical and warning issues

**Fixing Strategy**:

**For each CRITICAL issue**:
1. Read file with issue
2. Understand the problem
3. Apply minimal fix
4. Verify fix doesn't break tests
5. Mark as resolved

**For each WARNING**:
1. Assess impact (breaking change? refactor needed?)
2. Apply fix if straightforward
3. Create TODO if complex (defer to separate commit)
4. Mark as resolved or deferred

**Example fix workflow**:
```bash
# Read file
Read(file_path="src/auth/login.ts")

# Apply fix
Edit(
  file_path="src/auth/login.ts",
  old_string="if (user.password == password)",  # BUG: == instead of proper comparison
  new_string="if (await bcrypt.compare(password, user.password))"
)

# Run tests
npm test src/auth/login.test.ts

# Verify fix
Read(file_path="src/auth/login.ts", offset=40, limit=10)
```

**Deliverable**: All critical issues fixed, warnings addressed

---

### Phase 5: RE-REVIEW & APPROVE

**Goal**: Verify fixes and get final approval

**Re-review process**:

**If fixes were applied**:
```
Task(
  subagent_type="code-reviewer",
  description="Re-review after fixes",
  prompt="""
Re-review changes after addressing previous feedback:

**Previous Issues**:
[List issues that were fixed]

**Files Changed** (after fixes):
[Updated file list]

Focus on:
- Verify previous issues resolved
- No new issues introduced by fixes
- Overall code quality

Provide verdict: APPROVE or REQUEST_CHANGES (if still issues)
"""
)
```

**Wait for verdict**

**Verdict Handling**:

**APPROVE**:
- ✅ All issues resolved
- ✅ No new issues from fixes
- → Proceed to commit

**REQUEST_CHANGES** (still issues):
- ❌ Return to Phase 4 (fix remaining issues)
- ❌ Maximum 2 iterations (prevent infinite loop)
- ❌ After 2 iterations, ask user for guidance

**Deliverable**: Final APPROVE verdict

---

### Phase 6: COMMIT (After Approval)

**Goal**: Commit reviewed, approved code

**Pre-commit checklist**:
```bash
# Ensure all changes staged
git add <fixed-files>

# Final status check
git status

# Run tests one more time
npm test

# Commit with descriptive message
git commit -m "$(cat <<'EOF'
feat: Add user authentication

- Implement JWT-based auth
- Add login/logout endpoints
- Secure password hashing with bcrypt

Fixes: #123

Co-Authored-By: Claude Sonnet 4.5 (1M context) <noreply@anthropic.com>
EOF
)"
```

**Post-commit**:
```bash
# Verify commit
git show HEAD

# Log to memory
bash .claude/hooks/log-discovery.sh "achievement" "Implemented user authentication (code-reviewed, approved)"
```

**Deliverable**: Clean commit with reviewed, approved code

---

## Integration Points

### With Other Skills

- **After /workflow**: Review work before committing
- **After /debug**: Review bug fixes for correctness
- **After /refactor-safely**: Verify refactoring didn't break anything
- **Before push**: Final quality gate

### With Pre-Tool-Use Hook

**Suggested integration**:
```bash
# In hooks/pre-tool-use.sh
if [[ "$TOOL" == "Bash" && "$COMMAND" =~ "git commit" ]]; then
  echo "💡 Suggestion: Run /code-review before committing"
fi
```

### With Memory Graph

**Log review outcomes**:
```bash
bash .claude/hooks/log-discovery.sh "quality" "Code review approved: 3 bugs fixed before commit"
```

---

## Examples

### Example 1: New Feature Review (Issues Found)

**Phase 1: Identify Changes**
```bash
git status
# Modified: src/auth/login.ts, src/auth/register.ts
# New: src/middleware/auth.middleware.ts
```

**Phase 2: Launch Reviewer**
```
Reviewing 3 files for authentication feature...
```

**Phase 3: Analyze Feedback**
```
CRITICAL ISSUES:
[BUG] src/auth/login.ts:42 - Password comparison uses == instead of bcrypt.compare()
[SECURITY] src/auth/register.ts:28 - No password strength validation

WARNINGS:
[QUALITY] src/middleware/auth.middleware.ts:15 - Error handling missing for invalid tokens

Verdict: REQUEST_CHANGES
```

**Phase 4: Fix Issues**
```javascript
// Fix 1: Password comparison
- if (user.password == password)
+ if (await bcrypt.compare(password, user.password))

// Fix 2: Password validation
+ if (password.length < 8) {
+   throw new Error('Password must be at least 8 characters')
+ }

// Fix 3: Error handling
+ try {
    const decoded = jwt.verify(token, SECRET)
+ } catch (error) {
+   throw new UnauthorizedException('Invalid token')
+ }
```

**Phase 5: Re-review**
```
All issues resolved ✓
Fixes look good ✓
No new issues introduced ✓

Verdict: APPROVE
```

**Phase 6: Commit**
```bash
git add src/auth/*
git commit -m "feat: Add user authentication with security fixes"
```

---

### Example 2: Bug Fix Review (Clean)

**Phase 1: Identify Changes**
```bash
git diff --cached
# Modified: src/services/order.service.ts (1 file, 3 lines changed)
```

**Phase 2: Launch Reviewer**
```
Reviewing bug fix in order service...
```

**Phase 3: Analyze Feedback**
```
No issues found ✓

The fix correctly:
- Adds null check before property access
- Matches the root cause (TypeError prevention)
- Minimal change (good)
- Test coverage exists

Verdict: APPROVE
```

**Phase 4: Fix Issues**
Skipped (no issues)

**Phase 5: Re-review**
Skipped (already approved)

**Phase 6: Commit**
```bash
git commit -m "fix: Add null check in order service (fixes TypeError)"
```

---

### Example 3: Large Refactor Review

**Phase 1: Identify Changes**
```bash
git diff --cached --stat
# 12 files changed, 450 insertions(+), 320 deletions(-)
```

**Phase 2: Launch Reviewer**
```
Reviewing large refactoring across 12 files...
```

**Phase 3: Analyze Feedback**
```
WARNINGS:
[QUALITY] Inconsistent error handling in 3 files
[DOCS] Missing JSDoc for new public methods
[STYLE] Some files use var instead of const/let

No CRITICAL issues ✓
Refactoring is structurally sound ✓

Verdict: APPROVE (with suggestions for future cleanup)
```

**Phase 4: Fix Issues**
```
Warnings are minor, can be addressed in follow-up PR.
Creating TODO issue for cleanup.
```

**Phase 5: Re-review**
Skipped (approved with minor suggestions)

**Phase 6: Commit**
```bash
git commit -m "refactor: Modernize authentication module

- Extract auth logic to separate services
- Improve testability with dependency injection
- Update imports across 12 files

TODO: Follow-up cleanup for error handling consistency"
```

---

## Success Criteria

### Review Execution

✅ Code-reviewer agent consulted (not manual review)
✅ All CRITICAL issues fixed before commit
✅ WARNINGS addressed or acknowledged
✅ APPROVE verdict received before committing
✅ Tests pass after fixes

### Quality Signals

- **Zero Bugs in Review**: No logic errors found
- **Security Checked**: No vulnerabilities introduced
- **Performance OK**: No obvious scalability issues
- **Clean Commit**: Reviewed code only (no debug logs, TODOs)

---

## Anti-Patterns

❌ **Committing without review**: Always review first
❌ **Ignoring REQUEST_CHANGES**: Fix issues before committing
❌ **Fixing only some issues**: Address all CRITICAL, acknowledge WARNINGS
❌ **Infinite fix loop**: Max 2 re-reviews, then ask user
❌ **Skipping tests**: Always test after fixes

---

## Advanced Patterns

### Selective Review (Large Changes)

For commits with 20+ files changed:

```
# Review critical files only
Task(subagent_type="code-reviewer", prompt="Review these 5 critical files: ...")

# Defer non-critical files to PR review
# Focus on: security-sensitive, complex logic, core functionality
```

### Security-Focused Review

For auth, payments, data handling:

```
Task(subagent_type="security-engineer", prompt="Security review of authentication changes")
Task(subagent_type="code-reviewer", prompt="General code review")

# Both must APPROVE before commit
```

### Performance Review

For database, API, algorithm changes:

```
Task(subagent_type="code-reviewer", prompt="Review with focus on performance and scalability")

# Look for: N+1 queries, inefficient algorithms, missing indexes
```

---

**Remember**: Code review BEFORE commit is 10x cheaper than fixing bugs in production. Use this skill religiously.
