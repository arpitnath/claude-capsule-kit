<p align="center">
  <!-- TODO: Add logo -->
  <!-- <img src="./.github/super-claude-kit-logo.png" alt="Super Claude Kit" width="200" /> -->
  <h1>Super Claude Kit</h1>
</p>

<p align="center">
  <code>bash <(curl -fsSL https://raw.githubusercontent.com/arpitnath/super-claude-kit/master/install)</code>
</p>

<p align="center">
  <strong>Super Claude Kit</strong> adds persistent memory to Claude Code.
  <br/>
  <br/>
  Claude Code forgets everything between sessions. Super Claude Kit remembers.
  <br/>
  Files, tasks, discoveries — all restored instantly.
</p>

<p align="center">
  <!-- TODO: Add hero GIF showing capsule restore -->
  <!-- <img src="./.github/capsule-restore.gif" alt="Context Capsule Restore" width="80%" /> -->
  <em>(Hero GIF: Context Capsule Restore - Coming Soon)</em>
</p>

<p align="center">
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
  <a href="https://claude.ai"><img src="https://img.shields.io/badge/Claude_Code-Compatible-blue.svg" alt="Claude Code"></a>
  <a href="https://github.com/arpitnath/super-claude-kit"><img src="https://img.shields.io/badge/version-1.0.0-blue.svg" alt="Version"></a>
</p>

---

## Quickstart

### Installing Super Claude Kit

Run the one-line installer:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/arpitnath/super-claude-kit/master/install)
```

That's it! Restart Claude Code and you'll see the context capsule on every session.

<details>
<summary>Manual installation (advanced)</summary>

```bash
# Clone the repository
git clone https://github.com/arpitnath/super-claude-kit.git
cd super-claude-kit

# Run the installer
bash install
```

The installer will:
- Install hooks to `.claude/hooks/`
- Build Go tools (dependency-scanner, progressive-reader)
- Configure `~/.claude/settings.local.json`
- Auto-install Go 1.23+ if not present

</details>

### What you get immediately

<p align="center">
  <!-- TODO: Add session resume GIF -->
  <!-- <img src="./.github/session-resume.gif" alt="Session Resume" width="80%" /> -->
  <em>(GIF: Session Resume - Coming Soon)</em>
</p>

**After installation, Claude Code will:**
- 🧠 **Remember files** you've accessed (no re-reads)
- 📦 **Restore context** between sessions (up to 24 hours)
- ✅ **Track tasks** across restarts
- 🔍 **Log discoveries** as you work
- 🔗 **Understand dependencies** in your codebase

### How it works

Super Claude Kit uses **hooks** (SessionStart, UserPromptSubmit) to:

1. **Capture context** as you work (file access, tasks, git state)
2. **Store in capsule** (`.claude/capsule.json`)
3. **Restore on restart** (automatic, zero manual input)

No configuration needed. It just works.

---

## Features

### 🧠 Persistent Memory

<p align="center">
  <!-- TODO: Add file re-read prevention GIF -->
  <!-- <img src="./.github/file-reread-prevention.gif" alt="File Re-read Prevention" width="70%" /> -->
  <em>(GIF: File Re-read Prevention - Coming Soon)</em>
</p>

**Stop wasting tokens on re-reads.**

Vanilla Claude Code re-reads files on every question. Super Claude Kit tracks what's been read and references from memory.

**Result:** ~50% token savings on multi-turn conversations.

---

### 📦 Context Capsule

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 CONTEXT CAPSULE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🌿 Git State:
   Branch: feat/oauth (2 commits ahead)

📁 Files in Context:
   • auth/OAuthController.ts (read 2h ago)
   • config/google.ts (edited 1h ago)
   • routes/auth.ts (read 2h ago)

🔍 Discoveries:
   • Google OAuth requires state parameter
   • Token stored in httpOnly cookie

✅ Current Tasks:
   ⚡ Implementing OAuth callback handler
   ✓ Controller setup complete
   ✓ Google provider config added

💡 Previous session: 2 hours ago
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**See exactly what Claude remembers.** Every session start shows your capsule with:
- Git branch and commit status
- Files accessed with timestamps
- Discoveries logged during work
- Active and completed tasks
- Time since last session

The capsule uses TOON format for **52% token reduction** compared to JSON.

---

### 🔗 Dependency Intelligence

<p align="center">
  <!-- TODO: Add dependency graph GIF -->
  <!-- <img src="./.github/dependency-graph.gif" alt="Dependency Graph" width="70%" /> -->
  <em>(GIF: Dependency Graph - Coming Soon)</em>
</p>

**Know what breaks before you break it.**

Built-in dependency scanner analyzes your codebase:

#### Available Commands

```bash
# Query what files import this file
.claude/tools/query-deps/query-deps.sh src/auth.ts

# Analyze impact of changing a file
.claude/tools/impact-analysis/impact-analysis.sh src/database.ts

# Find circular dependencies
.claude/tools/find-circular/find-circular.sh

# Identify unused files
.claude/tools/find-dead-code/find-dead-code.sh
```

#### Performance

- **1,000 files** scanned in <5 seconds
- **10,000 files** scanned in <30 seconds
- Supports TypeScript, JavaScript, Python, Go

**No other AI coding tool has this.**

---

### 🛠️ Built-in Tools

#### Progressive Reader

Read large files (>50KB) in semantic chunks using tree-sitter AST parsing.

```bash
# Read first chunk of a large file
progressive-reader --path src/large-file.ts

# List all chunks without content (preview)
progressive-reader --list --path src/large-file.ts

# Read specific chunk by index
progressive-reader --chunk 2 --path src/large-file.ts

# Continue from previous read (uses TOON token)
progressive-reader --continue-file /tmp/continue.toon
```

**Supported languages:** TypeScript, JavaScript, Python, Go

**When to use:**
- Files > 50KB that would consume too much context
- Reading sub-agent outputs progressively
- Large codebase exploration with minimal context usage

#### Dependency Scanner

Analyzes code structure and relationships using tree-sitter AST parsing.

```bash
# Build dependency graph
~/.claude/bin/dependency-scanner --path . --output .claude/dep-graph.toon
```

**Features:**
- Import/export tracking
- Circular dependency detection (Tarjan's algorithm)
- Impact analysis
- Dead code identification

---

### 🤖 Specialized Sub-Agents

Production-safe, read-only agents for common development tasks:

- **architecture-explorer** - Understand service boundaries and data flows
- **database-navigator** - Explore schemas, migrations, and relationships
- **agent-developer** - Build and debug AI agents with MCP integration
- **github-issue-tracker** - Create well-formatted issues from discoveries

All agents are sandboxed and require explicit permission for write operations.

---

## Docs & Guides

- **Getting Started**
  - [Installation & Verification](#installing-super-claude-kit)
  - [Understanding the Capsule](#-context-capsule)
  - [First Session Walkthrough](.claude/docs/CAPSULE_USAGE_GUIDE.md#first-session)
- **Usage Guide**
  - [File Access Logging](.claude/docs/CAPSULE_USAGE_GUIDE.md#file-logging)
  - [Task Tracking](.claude/docs/CAPSULE_USAGE_GUIDE.md#task-tracking)
  - [Discovery Logging](.claude/docs/CAPSULE_USAGE_GUIDE.md#discovery-logging)
  - [Best Practices](.claude/docs/CAPSULE_USAGE_GUIDE.md#best-practices)
- **Tools**
  - [Progressive Reader](docs/PROGRESSIVE_READER_ARCHITECTURE.md)
  - [Dependency Scanner](docs/DEPENDENCY_GRAPH_ARCHITECTURE.md)
  - [Custom Tools Guide](docs/CUSTOM_TOOLS.md)
- **Architecture**
  - [System Architecture](.claude/docs/SUPER_CLAUDE_SYSTEM_ARCHITECTURE.md)
  - [Hook System](.claude/docs/SUPER_CLAUDE_SYSTEM_ARCHITECTURE.md#hooks)
  - [Capsule Design](.claude/docs/SUPER_CLAUDE_SYSTEM_ARCHITECTURE.md#capsule)
  - [Sandboxing](docs/SANDBOXING_ARCHITECTURE.md)
- **Advanced**
  - [Configuration](docs/CONFIGURATION.md)
  - [Debug Mode](#debug-mode)
  - [Custom Hooks](docs/CUSTOM_HOOKS.md)
  - [Contributing](CONTRIBUTING.md)
- **Reference**
  - [CHANGELOG](CHANGELOG.md)
  - [FAQ](docs/FAQ.md)
  - [Troubleshooting](#troubleshooting)

---

## Requirements

- **Claude Code** (Desktop CLI or VSCode extension)
- **macOS** or **Linux** (Windows WSL supported)
- **Go 1.23+** (auto-installed if not present)
- **Git** (recommended for branch-aware features)
- **Bash 4.0+**

---

## Verification

After installation, verify everything works:

```bash
# Run comprehensive tests
bash .claude/scripts/test-super-claude.sh

# View current stats
bash .claude/scripts/show-stats.sh

# Check installed tools
~/.claude/bin/dependency-scanner --version
~/.claude/bin/progressive-reader --version
```

Expected output:
```
✅ Super Claude Kit v1.0.0
✅ dependency-scanner v1.0.0
✅ progressive-reader v1.0.0
✅ All hooks configured
✅ All tests passed
```

---

## Updating

### Check for Updates

```bash
bash .claude/scripts/update-super-claude.sh
```

### Development Mode

Install latest development version:

```bash
bash .claude/scripts/update-super-claude.sh --dev
```

---

## Configuration

### Settings Location

`.claude/settings.local.json`

```json
{
  "permissions": {
    "allow": [
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(~/.claude/bin/dependency-scanner:*)",
      "Bash(progressive-reader:*)"
    ]
  },
  "hooks": {
    "SessionStart": ["bash .claude/hooks/session-start.sh"],
    "UserPromptSubmit": ["bash .claude/hooks/pre-task-analysis.sh"]
  }
}
```

### Customization

- **Custom hooks** - Add to `hooks/` directory
- **Custom tools** - Add to `tools/` directory
- **Specialized agents** - Add to `agents/` directory
- **Reusable skills** - Add to `skills/` directory

See [Configuration Guide](docs/CONFIGURATION.md) for details.

---

## Troubleshooting

### Hooks not executing

```bash
# Verify settings
cat .claude/settings.local.json

# Test hook manually
bash .claude/hooks/session-start.sh
```

### Capsule not updating

```bash
# Force refresh
rm .claude/last_refresh_state.txt

# Check logs
tail -f .claude/hooks.log
```

### Dependency graph not building

```bash
# Verify scanner installation
ls -la ~/.claude/bin/dependency-scanner

# Rebuild manually
~/.claude/bin/dependency-scanner --path . --output .claude/dep-graph.toon
```

### Debug Mode

Enable verbose logging:

```bash
CLAUDE_DEBUG_HOOKS=true claude
```

For more issues, see [FAQ](docs/FAQ.md) or [open an issue](https://github.com/arpitnath/super-claude-kit/issues).

---

## Performance

### Benchmarks

| Operation | Performance | Details |
|-----------|-------------|---------|
| **Context Refresh** | <100ms | Smart change detection |
| **Graph Building** | 1000 files in <5s | Parallel parsing |
| **Large Project** | 10000 files in <30s | Incremental updates |
| **Memory Footprint** | ~20MB | Typical projects |
| **Token Efficiency** | 52% reduction | TOON vs JSON |

### Tested On

- ✅ React projects (100-500 files)
- ✅ Node.js APIs (50-200 files)
- ✅ Python packages (200-1000 files)
- ✅ Go services (100-500 files)
- ✅ Monorepos (1000+ files)

---

## Uninstall

```bash
cd super-claude-kit
bash uninstall
```

Removes hooks, tools, and configuration. Your `.claude/` data logs are preserved in `.claude/backup/`.

---

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes with clear messages
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

### Development Setup

```bash
git clone https://github.com/arpitnath/super-claude-kit.git
cd super-claude-kit
bash install
```

### Running Tests

```bash
bash .claude/scripts/test-super-claude.sh
```

---

## License

This repository is licensed under the [MIT License](LICENSE).

Copyright (c) 2025 Arpit Nath

---

## Acknowledgments

- [Anthropic](https://www.anthropic.com/) - Claude and Claude Code
- [TOON Format](https://github.com/toon-format/toon) - Token-Oriented Object Notation
- [Tree-sitter](https://tree-sitter.github.io/) - Incremental parsing system
- Developer community for feedback and contributions

---

## Star History

If you found Super Claude Kit useful, please star the repo! ⭐

<p align="center">
  <a href="https://star-history.com/#arpitnath/super-claude-kit&Date">
    <img src="https://api.star-history.com/svg?repos=arpitnath/super-claude-kit&type=Date" alt="Star History Chart" width="600">
  </a>
</p>

---

<p align="center">
  <strong>Never re-explain yourself to Claude. Ever.</strong>
  <br/>
  <br/>
  <a href="https://github.com/arpitnath/super-claude-kit/issues">Report Bug</a> ·
  <a href="https://github.com/arpitnath/super-claude-kit/issues">Request Feature</a> ·
  <a href="https://github.com/arpitnath">GitHub</a> ·
  <a href="https://www.linkedin.com/in/arpit-nath-38280a173/">LinkedIn</a>
</p>
