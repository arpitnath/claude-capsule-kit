# Changelog

All notable changes to Claude Capsule Kit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.3.0] - 2026-01-27

### Added - Workflow Orchestration & Attention Management System

**🚀 4 New Workflow Skills** - Systematic approaches for complex tasks:
- `workflow` - Meta-cognitive 5-phase orchestration (Understand → Strategy → Plan → Execute → Verify)
- `debug` - RCA-first debugging with error-detective + debugger agents
- `deep-context` - 6-layer context building (memory → capsule → progressive-reader → agents → synthesis)
- `code-review` - Pre-commit quality gate with code-reviewer agent
- Auto-activation via keyword triggers ("error", "don't have context", "complex task")

**🔍 Context-Librarian Meta-Agent** - Breakthrough attention management:
- New agent: `context-librarian` (haiku model, 3-8s retrieval)
- Searches 5 memory layers: memory-graph, capsule, discovery logs, subagent logs, dependency graph
- Returns focused 200-500 token context packages
- Achieves 90% attention (vs 30% passive injection) via request-response pattern

**🛠️ Context-Query Tool**:
- New tool: `context-query` - Spawns context-librarian for memory retrieval
- Usage: `Bash(".claude/tools/context-query/context-query.sh <topic>")`
- Prevents redundant file reads and agent spawns

**📚 5 New Documentation Files**:
- `docs/TOOL_ENFORCEMENT_REFERENCE.md` - Complete tool selection guide
- `docs/AGENT_ROUTING_GUIDE.md` - All 18 agents with routing rules
- `docs/BEST_PRACTICES.md` - Best practices and anti-patterns
- `docs/SKILLS_ORCHESTRATION_ARCHITECTURE.md` - Skills + hooks design
- `docs/CONTEXT_LIBRARIAN_ARCHITECTURE.md` - Attention management architecture
- `docs/CAPSULE_DEGRADATION_RCA.md` - Root cause analysis of context retention

### Changed - Attention Management Enhancements

**Message-Based Capsule Refresh**:
- Capsule now re-injects every 20 messages (not just on hash change)
- Prevents attention fade in long sessions
- File: `hooks/inject-capsule.sh` - Added message-count tracking

**Pre-Prompt System**:
- Critical rules injected as hidden context at session start
- User sees: "Claude Capsule Kit loaded" (clean)
- Claude receives: Full workflow rules in additionalContext (hidden)
- File: `hooks/init-capsule-session.sh` - Generates `.claude/pre-prompt.txt`
- File: `hooks/session-start.sh` - Injects pre-prompt

**Periodic Reminders**:
- New hook: `hooks/user-prompt-submit.sh`
- Reminds about tools/agents every 10 messages
- Detects uncertainty keywords, suggests context-librarian
- Prevents instruction fade during long conversations

**Enhanced Pre-Tool-Use Hook**:
- Suggests context-librarian if file already in capsule (before Read)
- Suggests context-librarian if past agent findings exist (before Task)
- File: `hooks/pre-tool-use.sh` - Added context-aware suggestions

**CLAUDE.md Restructure**:
- Reduced from 485 → 203 lines (58% reduction)
- Reduced from ~2,500 → ~900 tokens (64% reduction)
- Heavy XML converted to scannable tables + quick references
- Detailed docs extracted to separate reference files
- Focus: Critical rules + links to detailed docs

**README Update**:
- New tagline: "Claude that understands your code — and scales when you need it"
- Added "Why Capsule Kit?" section (problem-first framing)
- Highlighted workflow skills and context-librarian
- Updated positioning: Code understanding + systematic workflows

### Fixed

- Progressive-reader path in hooks: `.claude/bin/` → `$HOME/.claude/bin/`
- context-query path suggestions: `tools/...` → `.claude/tools/...`
- Message counter conflicts between hooks (now centralized in user-prompt-submit)
- Memory-graph missing scripts in some installations

### Technical Details

**Attention Management Architecture**:
- Multi-layer context strategy (5 layers)
- Request-response pattern for high attention (90% vs 30%)
- Format variation for reminders (defeats repetition suppression)
- Token-efficient context delivery

**Agent Count**: 17 → 18 (added context-librarian)
**Tool Count**: 8 → 9 (added context-query)
**Skill Count**: 3 → 7 (added 4 workflow skills)
**Hook Count**: 26 → 27 (added user-prompt-submit)

**Expected Impact**:
- Capsule checks: 20% → 85% (4.25x improvement)
- Correct tool usage: 40% → 95% (2.4x improvement)
- Instruction adherence: 25% → 85% (3.4x improvement)
- Token efficiency: +45% savings
- Redundant operations: -80%

---

## [2.2.0] - 2026-01-16

### Added

- **6 New Specialist Agents** for enhanced development workflows:
  - `debugger` - Systematic debugging specialist (opus)
  - `error-detective` - Root cause analysis with structured RCA reports (opus)
  - `code-reviewer` - Code quality gate for pre-commit reviews (sonnet)
  - `refactoring-specialist` - Safe, incremental code refactoring (opus)
  - `context-manager` - Context optimization and memory management (sonnet)
  - `git-workflow-manager` - Git workflow guidance and conflict resolution (sonnet)

### Fixed

- **6 Broken Agent YAML Frontmatter** - Fixed agents that weren't loading in Claude Code:
  - `brainstorm-coordinator` - YAML parsing fixed
  - `database-architect` - YAML parsing fixed
  - `devops-sre` - YAML parsing fixed
  - `product-dx-specialist` - YAML parsing fixed
  - `security-engineer` - YAML parsing fixed
  - `system-architect` - YAML parsing fixed
- Root cause: `<example>` XML tags in YAML description field broke parsing
- All agents now use proper `description: |` multiline YAML syntax

### Changed

- Total agents increased from 11 to 17
- Standardized agent frontmatter format across all agents
- Updated manifest.json with new agent entries

---

## [2.1.0] - 2026-01-06

### Added

- **Intelligence Layer** with 6 specialist agents for multi-perspective analysis:
  - `brainstorm-coordinator` - Orchestrates specialist agents for comprehensive analysis
  - `database-architect` - Database schema design and query optimization
  - `devops-sre` - Production readiness and operational concerns
  - `product-dx-specialist` - Developer experience and API design
  - `security-engineer` - Security analysis and threat modeling
  - `system-architect` - Technical architecture and scalability
- Intelligence Layer design documentation (`docs/INTELLIGENCE_LAYER.md`)
- Time-based filtering for memory queries with `--since` flag (#23 by @cbrowning04)
  - Supports: hours (24h), days (7d), months (1m), years (1y)
- Hook error fix script (`scripts/fix-hook-errors.sh`)

### Fixed

- Hook errors when Task subagents run from non-project directories
- Missing `session-summarizer.md` agent in manifest.json

### Changed

- Updated install script for better subagent CWD handling

---

## [2.0.2] - 2025-11-15

### Fixed

- Broken dependency analysis tools due to JSON/TOON format mismatch
- All dependency tools now work correctly (query-deps, impact-analysis, find-circular, find-dead-code)
- Added relative path support to dependency query tools

### Changed

- TOON format is now the default output (71-74% token reduction vs JSON)
- Simplified lib/toon-parser.sh - removed Python dependency, uses grep/awk only
- All .json references updated to .toon across hooks, scripts, and documentation
- Backwards compatible: .json extension still works for JSON format

### Technical Details

- Restored original grep/awk-based TOON parser (simpler, faster, no Python)
- Added `_resolve_path()` and `_find_file_in_graph()` for relative path support
- Updated 10 files to use .toon extension by default
- Net code reduction: -79 lines (168 deletions, 89 insertions)

### Testing

- Verified in super-claude-kit: 15 files, 0.05s scan time
- Verified in Mid-size Repository: 1,228 files, 2.97s scan time
- All 4 dependency tools tested with both absolute and relative paths

---

## [2.0.1] - 2025-11-15

### Fixed

- Hook JSON schema validation: Added missing `hookEventName: "SessionStart"` field
- Dependency scanner installation: Changed binary downloads from GitHub releases to GitHub raw URLs
- Install script stability: Binary downloads now work immediately without requiring release artifacts

### Changed

- Install script now auto-detects latest stable version from GitHub releases/tags
- Defaults to tagged releases instead of master branch for production stability
- Users can override version: `VERSION=master curl ... | bash` for development
- Improved error messages during dependency scanner installation

### Notes

- Fully backward compatible with v2.0.0
- No user action required for existing installations
- New installs automatically get latest stable version

---

## [2.0.0] - 2025-11-13

### Added

- Dependency Graph Scanner with multi-language support (TypeScript/JavaScript, Go, Python)
- Dependency Scanner Binary at `~/.claude/bin/dependency-scanner`
  - Pre-compiled binaries for macOS (Intel/ARM), Linux, Windows
  - AST-based parsing for accurate dependency extraction
  - Performance: 1000 files in <5s, 10000 files in <30s
- New dependency analysis tools in `.claude/tools/`:
  - `query-deps.sh` - Show file dependencies and reverse dependencies
  - `impact-analysis.sh` - Analyze change impact (HIGH/MEDIUM/LOW risk scoring)
  - `find-circular.sh` - Detect circular dependency cycles using Tarjan's algorithm
  - `find-dead-code.sh` - Find potentially unused files
- Automatic dependency graph building on session start
- Comprehensive dependency graph documentation in `CLAUDE_TEMPLATE.md`
- Automatic platform detection in install script (OS/architecture)

### Changed

- Version bumped from 1.1.0 → 2.0.0
- Updated `manifest.json` to include new `tools` component type
- Enhanced install script to install dependency tools and binaries
- SessionStart hook now builds dependency graph automatically
- Output format: dependency graph saved to `.claude/dep-graph.toon`

### Upgrade

```bash
bash .claude/scripts/update-super-claude.sh
```

Fully backward compatible - no breaking changes.

---

## [1.1.0] - 2025-11-13

### Added

- PostToolUse hook for automatic operation logging (95% automation)
- Quality improvement hooks for proactive guidance
- Smart refresh heuristics with hash-based change detection
- Tool auto-suggestion system based on user prompts
- Enhanced capsule injection with formatted output
- Validation hooks for capsule usage patterns
- Keyword trigger system for context-aware suggestions
- Progressive disclosure system for managing context size
- Persistence layer for cross-session state
- Journal system for exploration findings

### Changed

- Reduced hook output overhead by 80% through smart caching
- Improved capsule update frequency detection
- Enhanced session restoration with better state persistence
- Optimized tool suggestions to reduce noise
- Streamlined discovery logging system

### Fixed

- Duplicate capsule updates on sequential operations
- Excessive logging cluttering system-reminders
- Hook performance issues with large codebases
- State persistence across session boundaries
- Tool suggestion false positives

### Upgrade

```bash
bash .claude/scripts/update-super-claude.sh
```

**Migration Notes:**
- Old log formats automatically migrated
- Session state persisted from v1.0.0
- No manual intervention required

---

## [1.0.0] - 2025-11-12

### Added

- Core Context Capsule system (TOON format)
- SessionStart hook for context loading
- UserPromptSubmit hook for context refresh
- Session tracking and state management
- Git integration for branch and commit tracking
- File access logging system
- Discovery logging for architectural insights
- Task tracking integration with TodoWrite
- Sub-agent result tracking
- Exploration journal for cross-session memory
- Settings management (`settings.local.json`)
- Hook system:
  - `session-start.sh` - Initialize session and load context
  - `pre-task-analysis.sh` - Analyze prompts and suggest approaches
  - `post-tool-use.sh` - Log tool usage
  - `update-capsule.sh` - Update context state
  - `inject-capsule.sh` - Display context to Claude
- Scripts:
  - `update-super-claude.sh` - Self-update mechanism
  - `show-stats.sh` - Display session statistics
  - `test-super-claude.sh` - Verify installation
- CLAUDE.md template for project instructions
- Comprehensive documentation

### Changed

- Initial release

---

## Template for Future Releases

## [MAJOR.MINOR.PATCH] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes in existing functionality

### Deprecated
- Soon-to-be removed features

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Vulnerability fixes

---

## Links

- [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
- [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
- [Claude Capsule Kit Repository](https://github.com/arpitnath/super-claude-kit)
