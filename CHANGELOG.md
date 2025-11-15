# Changelog

All notable changes to Super Claude Kit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- [Super Claude Kit Repository](https://github.com/arpitnath/super-claude-kit)
