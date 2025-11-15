# Dependency Scanner

A fast, language-agnostic dependency scanner that builds a comprehensive dependency graph of your codebase.

Part of **Super Claude Kit v2.0**.

## Features

- 🚀 **Multi-language support**: TypeScript, JavaScript, Go, Python
- 🔍 **Dependency tracking**: Imports, exports, and reverse dependencies
- ⚠️ **Circular dependency detection**: Uses Tarjan's algorithm
- 🗑️ **Dead code detection**: Finds unused files
- 💾 **TOON/JSON output**: Easy to query and integrate
- ⚡ **Fast**: Scans 1000+ files in seconds

## Installation

### Pre-built Binaries

Download from releases:
```bash
# macOS (Intel)
curl -fsSL https://github.com/arpitnath/super-claude-kit/releases/latest/download/dependency-scanner-darwin-amd64 -o dependency-scanner
chmod +x dependency-scanner

# macOS (ARM - M1/M2/M3)
curl -fsSL https://github.com/arpitnath/super-claude-kit/releases/latest/download/dependency-scanner-darwin-arm64 -o dependency-scanner
chmod +x dependency-scanner
```

### Build from Source

```bash
# Clone repository
git clone https://github.com/arpitnath/super-claude-kit.git
cd super-claude-kit/tools/dependency-scanner

# Build
make build

# Or build for all platforms
make build-all

# Or install locally
make install
```

## Usage

### Basic Scan

```bash
dependency-scanner --path /path/to/project --output dep-graph.toon
```

### Options

```
--path string      Path to scan (default: ".")
--output string    Output file (default: "dep-graph.toon", .json for JSON format)
--verbose         Enable verbose logging
--version         Show version
```

### Example

```bash
$ dependency-scanner --path ~/projects/my-app

🔍 Scanning: /Users/arpit/projects/my-app
✅ Scanned 247 files
   Languages: typescript (189), javascript (58)
   ✅ No circular dependencies
   🗑️  Found 3 potentially dead files
   ⏱️  Completed in 1.23s
💾 Saved to: dep-graph.toon
```

## Output Format

The scanner supports two output formats:

### TOON Format (default)

Optimized for bash parsing with grep/awk:
```
FILE:/absolute/path/to/file.ts
LANG:typescript
IMPORTS:./utils:5,@/lib/api:1
EXPORTS:authenticate:function:10,User:class:25
IMPORTEDBY:/path/to/importer.ts
---
CIRCULAR:file1>file2>file3>file1
---
DEADCODE:/unused/file.ts
---
META:lastUpdated=2025-11-15T17:52:00Z
```

### JSON Format (use .json extension)

The scanner generates a JSON file with the following structure:

```json
{
  "Files": {
    "src/auth/auth.ts": {
      "Path": "src/auth/auth.ts",
      "Language": "typescript",
      "Imports": [
        {
          "Path": "src/crypto/hash.ts",
          "Symbols": ["hashPassword", "compareHash"],
          "IsDefault": false,
          "Line": 3
        }
      ],
      "Exports": [
        {
          "Name": "authenticateUser",
          "Type": "function",
          "IsDefault": false,
          "Line": 15
        }
      ],
      "ImportedBy": [
        "src/api/routes.ts",
        "src/middleware/auth.ts"
      ]
    }
  },
  "Circular": [
    ["src/a.ts", "src/b.ts", "src/c.ts"]
  ],
  "DeadCode": [
    "src/legacy/oldAuth.ts"
  ],
  "LastUpdated": "2025-11-13T21:30:00Z"
}
```

## Integration with Super Claude Kit

This scanner is automatically run by Super Claude Kit on session start:

```bash
# In .claude/hooks/session-start.sh
dependency-scanner \
  --path "$(pwd)" \
  --output .claude/dep-graph.toon
```

Claude then uses query tools to analyze the graph:
- `.claude/tools/query-deps.sh <file>` - Show dependencies
- `.claude/tools/impact-analysis.sh <file>` - Impact analysis
- `.claude/tools/find-circular.sh` - Find circular dependencies
- `.claude/tools/find-dead-code.sh` - Find dead code

## Supported Languages

### TypeScript / JavaScript
- `.ts`, `.tsx`, `.js`, `.jsx`, `.mjs`, `.cjs`
- Detects: `import`, `export`, `require()`
- Handles: Named imports, default imports, re-exports

### Go
- `.go` files (excludes `*_test.go`)
- Uses Go's built-in AST parser
- Detects: All exported symbols (uppercase identifiers)

### Python
- `.py`, `.pyi` files
- Detects: `import`, `from ... import`
- Exports: Functions and classes not starting with `_`

## Performance

| Files | Time  | Memory |
|-------|-------|--------|
| 100   | <1s   | ~10MB  |
| 1000  | <5s   | ~50MB  |
| 10000 | <30s  | ~500MB |

## Algorithm: Circular Dependency Detection

Uses **Tarjan's Strongly Connected Components (SCC)** algorithm:
- Time complexity: O(V + E) where V = files, E = imports
- Finds all cycles in O(n) time
- Industry-standard approach

## Development

```bash
# Format code
make fmt

# Run tests
make test

# Build for all platforms
make build-all

# Clean
make clean
```

## License

MIT License - Part of Super Claude Kit

## Author

**Arpit Nath** - Creator of Orpheus CLI and Super Claude Kit

## Links

- Super Claude Kit: https://github.com/arpitnath/super-claude-kit
- Documentation: https://github.com/arpitnath/super-claude-kit#readme
