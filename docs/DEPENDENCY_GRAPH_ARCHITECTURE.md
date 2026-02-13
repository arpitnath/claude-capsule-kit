## Overview

The dependency scanner is a Go-based tool that:
1. Scans codebase on session start
2. Builds dependency graph (imports/exports)
3. Saves to `.claude/dep-graph.toon` (TOON format)
4. Provides query tools for Claude to use during session



---

## Architecture

```
  SessionStart Hook
  ├─ Detects codebase language(s)
  └─ Calls: dependency-scanner
     └─ Scans all files
    └─ Builds graph
    └─ Saves: .claude/dep-graph.toon

During Session:
Claude uses query tools:
├─ query-deps.sh <file>
├─ impact-analysis.sh <symbol>
 ├─ find-circular.sh
 └─ find-dead-code.sh

  Tools read: .claude/dep-graph.toon
```

---

## Implementation Details

### Project Structure

The dependency scanner is implemented as a simple Go binary with a flat structure:

```
tools/dependency-scanner/
├── main.go           # CLI entry point and orchestration
├── graph.go          # Graph data structures and serialization
├── scanner.go        # Directory scanning and file discovery
├── parser.go         # Multi-language parser using tree-sitter
├── algorithms.go     # Circular dependency detection (Tarjan's)
├── bin/              # Pre-compiled binaries (darwin-arm64, etc.)
├── tool.json         # Tool manifest for Claude Capsule Kit
├── go.mod
├── go.sum
├── Makefile
└── README.md
```

### Core Components

**Data Structures** (graph.go):
- `DependencyGraph`: Top-level container with files, circular deps, dead code
- `FileNode`: Represents a source file with imports, exports, and reverse dependencies
- `Import`: Import statement with path, symbols, and line number
- `Export`: Exported symbol with name, type, and line number

**Parser** (parser.go):
- Uses tree-sitter for AST-based parsing
- Supports TypeScript, JavaScript, Go, Python
- Extracts import/export statements accurately
- Handles both named and default imports/exports

**Scanner** (scanner.go):
- Walks directory tree to find source files
- Filters by supported languages (.ts, .js, .go, .py)
- Skips common ignored directories (node_modules, .git, etc.)
- Resolves import paths to actual file locations

**Algorithms** (algorithms.go):
- Tarjan's algorithm for circular dependency detection
- Dead code detection (files with no importers)
- Reverse dependency graph building

**Output Formats**:
- TOON format (default, 52% smaller than JSON)
- JSON format (optional, for compatibility)

### CLI Interface

**Command-line options:**
- `--path`: Directory to scan (default: current directory)
- `--output`: Output file path (default: ~/.claude/dep-graph.toon)
- `--verbose`: Enable verbose output
- `--version`: Show version information

**Example usage:**
```bash
# Scan current directory
dependency-scanner --path .

# Save as JSON instead of TOON
dependency-scanner --output deps.json

# Verbose mode for debugging
dependency-scanner --verbose
```

---

## Hook Integration

### SessionStart Hook

The session-start.sh hook automatically builds the dependency graph:

```bash
#!/bin/bash
set -euo pipefail

# ... existing session start logic ...

# Build dependency graph
echo "🔍 Building dependency graph..."

SCANNER="$HOME/.claude/bin/dependency-scanner"
if [ -f "$SCANNER" ]; then
  # Build graph
  "$SCANNER" \
    --path "$(pwd)" \
    --output .claude/dep-graph.toon \
    2>&1 | grep -E "^(Dependency|Files|Circular|Potentially)" || true

  echo ""
fi
```

---

## Query Tools

### Tool 1: Query Dependencies

**$HOME/.claude/cck/tools/query-deps/query-deps.sh:**

Shows who imports a file and what it imports:

```bash
#!/bin/bash
# Query who imports a file

FILE_PATH="$1"
GRAPH=".claude/dep-graph.toon"

if [ ! -f "$GRAPH" ]; then
  echo "❌ Dependency graph not built"
  echo "Run: ./.claude/hooks/session-start.sh"
  exit 1
fi

# Query graph using TOON parser
echo "📊 Dependencies for: $FILE_PATH"
echo ""

# Who imports this file?
IMPORTERS=$(toon_get_importers "$GRAPH" "$FILE_PATH")
if [ -n "$IMPORTERS" ]; then
  echo "Imported by:"
  echo "$IMPORTERS" | while read -r file; do
    echo "  • $file"
  done
else
  echo "Not imported by any files (dead code?)"
fi

echo ""

# What does this file import?
IMPORTS=$(toon_get_imports "$GRAPH" "$FILE_PATH")
if [ -n "$IMPORTS" ]; then
  echo "Imports:"
  echo "$IMPORTS" | while read -r file; do
    echo "  • $file"
  done
fi
```

### Tool 2: Impact Analysis

**$HOME/.claude/cck/tools/impact-analysis/impact-analysis.sh:**

Shows what would break if file changes:

```bash
#!/bin/bash
# Show what would break if file changes

FILE_PATH="$1"
GRAPH=".claude/dep-graph.toon"

if [ ! -f "$GRAPH" ]; then
  echo "❌ Dependency graph not built"
  exit 1
fi

echo "⚠️  Impact Analysis: $FILE_PATH"
echo ""

# Direct dependents
DIRECT=$(toon_get_importers "$GRAPH" "$FILE_PATH")
DIRECT_COUNT=$(echo "$DIRECT" | wc -l | tr -d ' ')

echo "Direct dependents: $DIRECT_COUNT files"
if [ -n "$DIRECT" ] && [ "$DIRECT_COUNT" -gt 0 ]; then
  echo "$DIRECT" | while read -r file; do
    echo "  • $file"
  done
fi

echo ""
echo "Total impact: $DIRECT_COUNT files could be affected"

# Risk level
if [ "$DIRECT_COUNT" -gt 10 ]; then
  echo "🔴 RISK: HIGH - Many dependents"
elif [ "$DIRECT_COUNT" -gt 3 ]; then
  echo "🟡 RISK: MEDIUM"
else
  echo "🟢 RISK: LOW"
fi
```

### Tool 3: Find Circular Dependencies

**$HOME/.claude/cck/tools/find-circular/find-circular.sh:**

Detects import cycles:

```bash
#!/bin/bash
GRAPH=".claude/dep-graph.toon"

if [ ! -f "$GRAPH" ]; then
  echo "❌ Dependency graph not built"
  exit 1
fi

CIRCULAR=$(toon_get_circular "$GRAPH")

if [ -z "$CIRCULAR" ]; then
  echo "✅ No circular dependencies found"
  exit 0
fi

echo "⚠️  Circular Dependencies Found:"
echo ""
echo "$CIRCULAR"
echo ""
echo "💡 Suggestion: Extract shared code to break cycles"
```

### Tool 4: Find Dead Code

**$HOME/.claude/cck/tools/find-dead-code/find-dead-code.sh:**

Lists files not imported by anyone:

```bash
#!/bin/bash
GRAPH=".claude/dep-graph.toon"

if [ ! -f "$GRAPH" ]; then
  echo "❌ Dependency graph not built"
  exit 1
fi

DEAD=$(toon_get_deadcode "$GRAPH")

if [ -z "$DEAD" ]; then
  echo "✅ No dead code found"
  exit 0
fi

echo "🗑️  Dead Code (not imported by anyone):"
echo ""
echo "$DEAD" | while read -r file; do
  echo "  • $file"
done

echo ""
echo "⚠️  Review before deleting - may be entry points or tests"
```

---

## Output Format

The dependency graph is saved in TOON format for token efficiency (52% smaller than JSON):

**.claude/dep-graph.toon:**
```
FILE:src/auth/auth.ts
LANG:typescript
IMPORT:src/crypto/hash.ts|hashPassword,compareHash|false|3
IMPORT:src/user/user.ts|User|false|4
EXPORT:authenticateUser|function|false|15
EXPORT:validateToken|function|false|32
IMPORTED_BY:src/api/routes.ts
IMPORTED_BY:src/middleware/auth.ts
IMPORTED_BY:tests/auth.test.ts
---

CIRCULAR:src/auth/auth.ts,src/user/user.ts,src/session/session.ts
---

DEADCODE:src/legacy/oldAuth.ts
---

META:updated=2025-11-15T21:30:00Z|files=42|circular=1|deadcode=3
---
```

---


## Performance Characteristics

**Complexity**:
- File scanning: O(n) where n = number of files
- Circular detection (Tarjan's): O(V + E) where V = files, E = imports
- Dead code detection: O(V)

**TOON Format Benefits**:
- 52% smaller than JSON
- Faster parsing for bash tools
- Human-readable for debugging

---

## Use Cases

### Before Refactoring
```
User: "Refactor auth.ts"
Claude: Let me check impact first...
        [Runs: impact-analysis.sh auth.ts]
        "⚠️ 15 files depend on this. Proceed carefully."
```

### Before Deleting
```
User: "Can I delete this file?"
Claude: Let me check...
        [Runs: query-deps.sh file.ts]
        "❌ No! 5 files still import it."
```

### Understanding Architecture
```
User: "Why does this import fail?"
Claude: Let me check for circular dependencies...
        [Runs: find-circular.sh]
        "Found cycle: A → B → C → A"
```

### Code Cleanup
```
User: "Find unused code to remove"
Claude: [Runs: find-dead-code.sh]
        "Found 12 potentially unused files"
```



## Technical Notes

### Why Go?
- Performance: 10-20x faster than bash/Python
- Tree-sitter bindings: Native support
- Cross-compilation: Easy platform builds
- Memory efficiency: Better than Node.js for parsing

### Why TOON Format?
- 52% smaller than JSON
- Faster bash parsing (grep/awk friendly)
- Human-readable for debugging
- Consistent with Claude Capsule Kit

### Why Tarjan's Algorithm?

**Alternatives Considered:**
- **Simple DFS cycle detection**: Finds cycles one at a time, requires multiple passes
- **Kosaraju's algorithm**: Also finds SCCs but requires two DFS passes instead of one
- **Floyd-Warshall**: O(V³) complexity - too slow for large codebases

**Why Tarjan's is Optimal:**
- **Single-pass**: O(V + E) - finds ALL cycles in one traversal
- **Space efficient**: O(V) stack space
- **Complete**: Finds all strongly connected components, not just individual cycles
- **Industry standard**: Used by most dependency analyzers (npm, cargo, etc.)

---
