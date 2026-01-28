<p align="center">
  <img src="./.github/super_claude_kit.png" alt="Claude Capsule Kit" width="100%" />
</p>

<p align="center">
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
  <a href="https://claude.ai"><img src="https://img.shields.io/badge/Claude_Code-Compatible-orange.svg" alt="Claude Code"></a>
  <a href="https://github.com/arpitnath/super-claude-kit"><img src="https://img.shields.io/badge/version-2.3.0-blue.svg" alt="Version"></a>
</p>

<p align="center">
  <strong>Claude that understands your code — and scales when you need it.</strong>
  <br/>
  <br/>
  Systematic workflows + persistent memory + attention management.
  <br/>
  Stop re-explaining. Start building.
</p>

<p align="center">
  <code>curl -fsSL https://raw.githubusercontent.com/arpitnath/super-claude-kit/master/install | bash</code>
</p>

<p align="center">
  <strong>📍 Per-project installation</strong> — Run from your project root, installs to <code>.claude/</code>
  <br/>
  Works alongside vanilla Claude Code (enhancement, not replacement)
</p>





<p align="center">
  <img src="./.github/hero.gif" alt="Claude Capsule Kit" width="100%" />
</p>


---

## Why Capsule Kit?

**The Problem**: Claude Code loses context, forgets what it learned, and doesn't use its tools systematically.

Claude instances typically:
- ❌ Re-read files you already discussed (wastes 10,000+ tokens)
- ❌ Re-analyze code you already understood (repeats expensive agent work)
- ❌ Don't check memory before spawning agents (ignores past solutions)
- ❌ Work reactively instead of systematically (jumps to execution without strategy)

**The Solution**: Capsule Kit makes Claude systematic and memory-aware.

✅ **Workflow Skills** - Guides Claude through proven approaches
- `/workflow` - 5-phase systematic approach (Understand → Strategy → Plan → Execute → Verify)
- `/debug` - RCA-first debugging with error-detective agent
- `/deep-context` - 6-layer context building (memory → capsule → agents)
- `/code-review` - Pre-commit quality gate

✅ **Context-Librarian** - Retrieves past knowledge before re-work
- Searches 5 memory layers in 3-8 seconds
- Returns focused context with 90% attention (vs 30% passive injection)
- Prevents redundant file reads and agent spawns

✅ **Persistent Memory** - Never lose context
- Capsule: Current session state (files, tasks, discoveries)
- Memory-graph: Cross-session knowledge (decisions, patterns, solutions)
- 24-hour context retention

✅ **18 Specialist Agents** - Fresh context for deep work
- error-detective, debugger, architecture-explorer, code-reviewer, security-engineer, etc.
- Each gets fresh context window (no baggage from main conversation)

**Result**: Claude works like an experienced developer—checks context first, uses the right tools, learns from past work.

**Impact**: 3-4x better instruction adherence, 45% token savings, 80% fewer redundant operations.

---

## Quickstart

### Installing Claude Capsule Kit

Run the one-line installer **from your project root**:

```bash
cd your-project
curl -fsSL https://raw.githubusercontent.com/arpitnath/super-claude-kit/master/install | bash
```

> **Note:** This installs to your project's `.claude/` directory (like `.claude/settings.json`).
> Install separately in each project where you want Claude Capsule Kit features.
> This is **not** a global installation — it enhances Claude Code per-project.

That's it! Restart Claude Code and you'll see the context capsule on every session.

<details>
<summary>Manual installation (advanced)</summary>

```bash
# Clone to your project directory
cd your-project
git clone https://github.com/arpitnath/super-claude-kit.git .super-claude-kit-src
cd .super-claude-kit-src

# Run the installer (installs to parent project)
bash install
```

The installer will:
- Install hooks to `.claude/hooks/`
- Build Go tools (dependency-scanner, progressive-reader)
- Configure `.claude/settings.local.json`
- Auto-install Go 1.23+ if not present

</details>

### What you get immediately

<p align="center">

  <img src="./.github/stats.png" alt="Session Resume" width="100%" />

</p>

**After installation, Claude Code will:**
- 🚀 **Work systematically** - Guided workflows for complex tasks
- 🔍 **Check context first** - 90% attention via context-librarian
- 🧠 **Remember everything** - Capsule + memory-graph persistence
- 🤖 **Use specialists** - 18 agents for deep work
- 🔗 **Understand dependencies** - Pre-computed dependency graph
- ✅ **Track progress** - Tasks and discoveries logged automatically

### How it works

Claude Capsule Kit uses **hooks** (SessionStart, UserPromptSubmit) to:

1. **Capture context** as you work (file access, tasks, git state)
2. **Store in capsule** (`.claude/capsule.json`)
3. **Restore on restart** (automatic, zero manual input)

No configuration needed. It just works.

---

## Features

### 🚀 Systematic Workflow Skills (NEW)

**Make Claude work systematically, not reactively.**

Claude Capsule Kit includes 4 workflow skills that auto-trigger based on keywords:

#### `/workflow` - Meta-Cognitive Orchestration

```
Triggers: "complex task", "multi-step", "coordinate"
```

Guides through 5 phases:
1. **Understand** - Build context (memory-graph + capsule + agents)
2. **Strategy** - Choose approach (tools vs agents, parallel vs sequential)
3. **Plan** - Break into steps with TodoWrite tracking
4. **Execute** - Systematic implementation with coordination
5. **Verify** - Tests + code review + knowledge persistence

**Use when**: Complex multi-file features, architectural changes, coordinated work

---

#### `/debug` - RCA-First Debugging

```
Triggers: "error", "bug", "broken", "failing"
```

Systematic error resolution:
1. **Capture** - Gather complete error context
2. **RCA** - Launch error-detective for root cause analysis
3. **Investigate** - Use debugger if RCA confidence low
4. **Fix** - Address root cause (not symptoms)
5. **Verify** - Tests + code review + log to memory

**Use when**: Errors, test failures, crashes, unexpected behavior

---

#### `/deep-context` - 6-Layer Context Building

```
Triggers: "don't have context", "understand codebase", "learn about"
```

Build understanding through layers:
1. **Memory-graph** - Check cross-session knowledge
2. **Capsule** - Check current session state
3. **Progressive-reader** - Navigate large files efficiently
4. **Dependency analysis** - Map code relationships
5. **Specialist agents** - Parallel architectural deep-dives
6. **Synthesis** - Store discoveries for future sessions

**Use when**: Starting work on unfamiliar code, need architectural understanding

---

#### `/code-review` - Pre-Commit Quality Gate

```
Manual: /code-review (before commits)
```

Mandatory review workflow:
1. **Identify changes** - Git diff analysis
2. **Launch reviewer** - code-reviewer agent with structured prompt
3. **Analyze feedback** - Categorize by severity (CRITICAL/WARNING/SUGGESTION)
4. **Fix issues** - Address all critical issues
5. **Approve** - Only commit after APPROVE verdict

**Use when**: Before git commits, before PRs, quality assurance

---

**How it works**: Skills auto-load based on keywords. Claude becomes systematic—checking context first, using right tools, following proven workflows.

---

### 🧠 Persistent Memory

**Stop wasting tokens on re-reads.**

Vanilla Claude Code re-reads files on every question. Claude Capsule Kit tracks what's been read and references from memory.


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

### 🧠 Memory Graph

**Understand relationships, not just files.**

Memory Graph tracks semantic connections between files, functions, decisions, and tasks as you work.

<p align="center">
  <img src="./.github/hero_memory.png" alt="Claude Capsule Kit" width="100%" />
</p>

```bash
# Visualize the graph
/memory-graph
```



**Auto-linking while you work:**
- Read a file → Creates node
- Edit imports → Links dependencies
- Complete task → Updates relationships
- Make decision → Links to affected files

**Query the graph:**
- "What depends on this file?" → Instant traversal
- "Why did we choose X?" → Decision nodes with context
- "What breaks if I change this?" → Impact via relationships

---

### 🔗 Dependency Intelligence

<p align="center">

  <img src="./.github/dependency-graph.png" alt="Dependency Graph" width="100%" />

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


---

### 📊 Progressive Reader Demo

See the difference when working with large files (187KB React source):

<p align="center">
  <video src="https://github.com/user-attachments/assets/6ed49428-ce3e-48d5-8e07-0d0ab702071b" controls width="100%">
    Progressive Reader Comparison
  </video>
</p>

| Metric | Vanilla Claude Code | Claude Capsule Kit |
|--------|---------------------|------------------|
| **Initial Read** | `MaxFileReadTokenExceededError` | Same error |
| **Recovery** | 8+ Read calls with offset/limit | Uses progressive-reader |
| **Lines read** | 5,339 lines (guessing) | 100 lines (targeted) |
| **Token savings** | — | **98%** for structure |

<details>
<summary>🧪 Try it yourself</summary>

```bash
# 1. Clone React and install Claude Capsule Kit
git clone https://github.com/facebook/react.git && cd react
curl -fsSL https://raw.githubusercontent.com/arpitnath/super-claude-kit/master/install | bash

# 2. Run Claude Code in debug mode
claude --debug

# 3. Send this prompt:
# "Summarize all functions in ReactFiberWorkLoop.js, organized by category"
```

**What to look for:**
- Vanilla: 8+ Read operations with arbitrary 800-line chunks
- Claude Capsule Kit: `progressive-reader --list` → targeted chunk reads

</details>

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

### 🤖 Specialized Sub-Agents (18 Total)

Production-safe specialist agents for deep work:

**Context & Analysis**:
- **context-librarian** (NEW) - Retrieves context from 5 memory layers with 90% attention
- **architecture-explorer** - Understand service boundaries and data flows
- **database-navigator** - Explore schemas, migrations, and relationships

**Debugging & Quality**:
- **error-detective** - Root cause analysis for errors (structured RCA reports)
- **debugger** - Systematic debugging and code tracing
- **code-reviewer** - Pre-commit review with severity categorization
- **refactoring-specialist** - Safe refactoring plans with rollback strategies

**Design & Security**:
- **system-architect** - Technical architecture and algorithm evaluation
- **database-architect** - Schema design and query optimization
- **security-engineer** - Threat modeling and security analysis
- **brainstorm-coordinator** - Multi-perspective decision analysis

**And 7 more**: devops-sre, git-workflow-manager, context-manager, product-dx-specialist, github-issue-tracker, session-summarizer, agent-developer

All agents run with fresh context and are designed for read-only exploration (write operations require explicit permission).

---

## Docs & Guides

- **Getting Started**
  - [Installation & Verification](#installing-super-claude-kit)
  - [Understanding the Capsule](#-context-capsule)
  - [First Session Walkthrough](docs/CAPSULE_USAGE_GUIDE.md#first-session)
- **Usage Guide**
  - [File Access Logging](docs/CAPSULE_USAGE_GUIDE.md#file-logging)
  - [Task Tracking](docs/CAPSULE_USAGE_GUIDE.md#task-tracking)
  - [Discovery Logging](docs/CAPSULE_USAGE_GUIDE.md#discovery-logging)
  - [Best Practices](docs/CAPSULE_USAGE_GUIDE.md#best-practices)
- **Tools**
  - [Progressive Reader](docs/PROGRESSIVE_READER_ARCHITECTURE.md)
  - [Dependency Scanner](docs/DEPENDENCY_GRAPH_ARCHITECTURE.md)
  - [Custom Tools Guide](docs/CUSTOM_TOOLS.md)
- **Architecture**
  - [System Architecture](docs/SUPER_CLAUDE_SYSTEM_ARCHITECTURE.md)
  - [Hook System](docs/SUPER_CLAUDE_SYSTEM_ARCHITECTURE.md#hooks)
  - [Capsule Design](docs/SUPER_CLAUDE_SYSTEM_ARCHITECTURE.md#capsule)
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
- **Bash 4.0+**

**Optional (for enhanced features):**
- **Git** - Provides branch tracking and git-aware change detection
  - Without git: Uses file modification time for change detection
  - All core features work without git

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
✅ Claude Capsule Kit v1.0.0
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

## Common Questions

**Q: Do I install this globally or per-project?**
A: **Per-project.** Run the install script from each project where you want Claude Capsule Kit. It installs to `.claude/` in that directory.

**Q: Does this replace Claude Code?**
A: **No.** It enhances Claude Code by adding hooks, tools, and persistent context memory. You still use the normal `claude` command.

**Q: Where are files installed?**
A: In your project's `.claude/` directory: hooks, tools, bin, settings. Similar to how `.claude/settings.json` works.

**Q: Can I use it in multiple projects?**
A: Yes! Install separately in each project. Each project gets its own context capsule and dependency graph.

---

## Performance

### Benchmarks

| Operation | Performance | Details |
|-----------|-------------|---------|
| **Context Refresh** | <100ms | Smart change detection |
| **Graph Building** | 1000 files in <5s | Parallel parsing |
| **Large Project** | 10000 files in <30s | Incremental updates |
| **Token Efficiency** | ~52% reduction | TOON vs JSON and avoids re-reads |


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


---

## Star History

If you found Claude Capsule Kit useful, please star the repo! ⭐

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
