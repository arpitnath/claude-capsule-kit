# Tool Enforcement Reference

Complete guide for tool selection and enforcement rules in Claude Capsule Kit.

---

## Overview

Claude Capsule Kit provides specialized tools that are **FASTER and MORE ACCURATE** than generic exploration. These rules are **MANDATORY** and enforced by the PreToolUse hook.

**Principle**: Use the right tool for the job—specialized tools beat Task/Explore agents for simple queries.

---

## Dependency Analysis Tools

### Always Use Specialized Tools (NEVER Task/Explore)

#### 1. query-deps - "What imports this file?"

**Command**:
```bash
bash .claude/tools/query-deps/query-deps.sh <file-path>
```

**Use cases**:
- Finding files that import/depend on a specific file
- Checking if a function/export is used before deleting
- Understanding dependency relationships

**Example**:
```bash
bash .claude/tools/query-deps/query-deps.sh src/auth/auth.service.ts

# Output:
Imported by 12 files:
- src/controllers/auth.controller.ts
- src/middleware/auth.middleware.ts
- src/guards/jwt.guard.ts
...
```

---

#### 2. impact-analysis - "What would break if I change this?"

**Command**:
```bash
bash .claude/tools/impact-analysis/impact-analysis.sh <file-path>
```

**Use cases**:
- Impact analysis before refactoring
- Understanding blast radius of changes
- Risk assessment for modifications

**Returns**:
- Direct dependents
- Transitive dependents
- Risk assessment (LOW/MEDIUM/HIGH/CRITICAL)

**Example**:
```bash
bash .claude/tools/impact-analysis/impact-analysis.sh src/auth/auth.service.ts

# Output:
DIRECT DEPENDENTS (5 files):
- src/controllers/auth.controller.ts
- src/middleware/auth.middleware.ts
...

TRANSITIVE DEPENDENTS (18 files):
[Files that depend on the direct dependents]

RISK: MEDIUM
Recommendation: Update tests after changes
```

---

#### 3. find-circular - "Any circular dependencies?"

**Command**:
```bash
bash .claude/tools/find-circular/find-circular.sh
```

**Use cases**:
- Finding import cycles
- Debugging module resolution errors
- Code cleanup and refactoring prep

**Returns**:
- All circular dependency chains with fix suggestions

**Example**:
```bash
bash .claude/tools/find-circular/find-circular.sh

# Output:
CIRCULAR DEPENDENCY FOUND:
A.ts → B.ts → C.ts → A.ts

Suggestion: Break cycle by extracting shared code to D.ts
```

---

#### 4. find-dead-code - "What files are unused?"

**Command**:
```bash
bash .claude/tools/find-dead-code/find-dead-code.sh
```

**Use cases**:
- Finding unused/unreferenced files
- Code cleanup
- Identifying candidates for deletion

**Returns**:
- List of potentially unused files

**Example**:
```bash
bash .claude/tools/find-dead-code/find-dead-code.sh

# Output:
Potentially unused files (5):
- src/utils/legacy-helper.ts (not imported anywhere)
- src/models/old-user.model.ts (not imported)
...
```

---

### Why NOT Task/Explore for Dependencies?

| Issue | Reason |
|-------|--------|
| **Slower** | Must read and parse files sequentially |
| **Incomplete** | May miss indirect dependencies |
| **Expensive** | High token usage for simple queries |
| **Cannot detect cycles** | Needs graph analysis (pre-computed) |

**Use dependency tools instead** - they read the pre-built dependency graph (instant, complete, accurate).

---

## File Search: Glob Tool

### Always Use Glob (NOT Task/Explore)

**Tool**: Glob
**Reason**: Direct file pattern matching

**Examples**:

**Find file by name**:
```
Glob(pattern="**/*auth*")
# Finds: auth.service.ts, auth.controller.ts, auth.middleware.ts
```

**Find files by extension**:
```
Glob(pattern="**/*.ts")
# Finds: All TypeScript files
```

**Find files in specific directory**:
```
Glob(pattern="src/controllers/**/*.ts")
# Finds: All controllers
```

**Why NOT Task/Explore?**
- Slower (agent must search iteratively)
- Glob is instant (built-in file system query)

---

## Code Search: Grep Tool

### Always Use Grep (NOT Task/Explore)

**Tool**: Grep
**Reason**: Fast pattern matching

**Examples**:

**Find by keyword**:
```
Grep(pattern="TODO", output_mode="files_with_matches")
# Finds: All files with TODO comments
```

**Find definition**:
```
Grep(pattern="function authenticateUser", output_mode="content")
# Finds: Function definition with line numbers
```

**Find with context**:
```
Grep(pattern="error", output_mode="content", -A=3, -B=3)
# Shows 3 lines before/after each match
```

**Why NOT Task/Explore?**
- Grep is instant (ripgrep is extremely fast)
- Task/Explore must read files sequentially

---

## Progressive Reader (Large Files >50KB)

### Navigation Tool for Large Files

**Tool**: `progressive-reader`
**Reason**: File navigation and structure discovery

**Purpose**:
Progressive-reader is a NAVIGATION TOOL for large files. Use it to understand file structure BEFORE reading, then read only what you need.

### Primary Value: `--list` Command

The `--list` command shows file structure WITHOUT reading content:

**Benefits**:
- Shows all functions/classes with their chunk numbers
- Each chunk has a summary of what it contains
- ~500 tokens to see entire file structure (vs ~48,000 for full read)
- BETTER THAN GREP for understanding "what's in this file?"

### Workflow

**Step 1**: Discover structure
```bash
$HOME/.claude/bin/progressive-reader --path <file> --list
```

**Output**:
```
File: src/services/large-service.ts
Total Chunks: 8

Chunk 0 (lines 1-200): Imports, type definitions, class declaration
Chunk 1 (lines 201-400): Constructor and initialization methods
Chunk 2 (lines 401-600): Core business logic (create, update, delete)
Chunk 3 (lines 601-800): Validation and helper methods
...
```

**Step 2**: Find relevant chunks from function/class names in the list

**Step 3**: Read specific chunk
```bash
$HOME/.claude/bin/progressive-reader --path <file> --chunk N
```

**Step 4**: Continue if needed
```bash
$HOME/.claude/bin/progressive-reader --continue-file /tmp/continue.toon
```

### When to Use Progressive Reader

- **Understanding file structure**: "What functions are in this file?"
- **Finding specific functionality**: "Which part handles authentication?"
- **Adding new code**: "Show me similar functions so I can follow the pattern"
- **Targeted reading**: "I need to understand just the login function"
- **Context-limited sessions**: Nearing token limits, need efficient reading

### When Grep is Fine

- Finding specific keyword occurrences
- Searching for error messages or strings
- Quick lookups where you know what you're searching for

### Language Support

**Full AST parsing** (intelligent chunking):
- TypeScript
- JavaScript
- Python
- Go

**Fallback** (line-based chunking):
- Other languages (still useful, less intelligent)

**Token Savings**: 75-97% vs full file read

---

## File Size Check (MANDATORY)

### BEFORE using Read tool, ALWAYS check file size first

**Check command**:
```bash
wc -c <file> | awk '{print int($1/1024)"KB"}'
```

**Decision**:
- **If under 50KB**: Use Read tool normally
- **If over 50KB**: STOP. Use progressive-reader instead

**Why this matters**:
- Files over 50KB (~12,500+ tokens) cause `MaxFileReadTokenExceededError`
- Each failed Read attempt wastes tokens
- Check size FIRST to avoid errors

**Progressive reader command** (for large files):
```bash
$HOME/.claude/bin/progressive-reader --path <file> --list
$HOME/.claude/bin/progressive-reader --path <file> --chunk N
```

---

## Error Recovery

### MaxFileReadTokenExceededError

**Trigger**: Attempted to read file >50KB with Read tool

**Action**: IMMEDIATELY stop using Read tool on this file

**Solution**: Switch to progressive-reader
```bash
$HOME/.claude/bin/progressive-reader --path <file> --list
```

**Do NOT**: Retry Read with offset/limit—use progressive-reader instead

**Note**: PreToolUse hook will warn/block large file reads automatically

---

## Task Tool - Allowed Uses

### When Task Tool IS Allowed

**Allowed Use Cases**:

1. **Complex architectural questions** requiring analysis
   - Example: "How does the authentication system work?"

2. **Implementation understanding**
   - Example: "How does X work internally?"

3. **Multi-file refactoring planning**
   - Example: "Plan refactoring of auth module across files"

4. **Design pattern identification**
   - Example: "What patterns are used in this codebase?"

### When Task Tool is NOT Allowed

**Forbidden**:
- Dependency lookups → Use `query-deps` instead
- File searches → Use `Glob` instead
- Code searches → Use `Grep` instead

**Why**: Specialized tools are instant and accurate. Task/Explore agents are slow and may miss results.

---

## Enforcement Mechanism

**PreToolUse Hook**: Intercepts tool calls and displays enforcement warnings

**How it works**:
1. Hook detects dependency query keywords in Task/Explore prompts
2. Outputs enforcement warning to stderr
3. Suggests correct tool with example command
4. Task still executes (warning only, not blocking)

**You must**: HEED THESE WARNINGS—they indicate you are using the wrong tool.

**Example warning**:
```json
{
  "type": "tool-enforcement",
  "category": "dependency-analysis",
  "warning": "Query appears to be about code dependencies",
  "dontUse": {
    "tool": "Task",
    "reason": "inefficient"
  },
  "useInstead": [
    {
      "name": "query-deps",
      "command": "bash .claude/tools/query-deps/query-deps.sh <file-path>"
    }
  ]
}
```

---

## Quick Reference Card

| Need | Use | NOT |
|------|-----|-----|
| What imports X? | `query-deps` | Task/Explore |
| What breaks if I change X? | `impact-analysis` | Task/Explore |
| Circular deps? | `find-circular` | Task/Explore |
| Dead code? | `find-dead-code` | Task/Explore |
| Find files by name | Glob | Task/Explore |
| Find code patterns | Grep | Task/Explore |
| Read large files (>50KB) | `progressive-reader` | Read |
| Understand architecture | Task/architecture-explorer | Read files |

---

**These tools exist to make you FASTER. Use them.**
