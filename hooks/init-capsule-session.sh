#!/bin/bash
# Initialize capsule session tracking
# Called from SessionStart hook

set -euo pipefail

SESSION_START_FILE=".claude/session_start.txt"
MESSAGE_COUNT_FILE=".claude/message_count.txt"
FILE_LOG=".claude/session_files.log"
TASK_FILE=".claude/current_tasks.log"
SUBAGENT_LOG=".claude/subagent_results.log"
DISCOVERY_LOG=".claude/session_discoveries.log"
SNAPSHOT_FILE=".claude/last_snapshot.txt"

# Create .claude directory
mkdir -p .claude

# Set session start time
date +%s > "$SESSION_START_FILE"

# Reset message count
echo "0" > "$MESSAGE_COUNT_FILE"

# Clear file log (start fresh each session)
> "$FILE_LOG"

# Clear task log (start fresh each session)
> "$TASK_FILE"

# Clear sub-agent log (start fresh each session)
> "$SUBAGENT_LOG"

# Clear discovery log (start fresh each session)
> "$DISCOVERY_LOG"

# Initialize git snapshot for change detection (if git available)
if git rev-parse --git-dir > /dev/null 2>&1; then
  git status --porcelain 2>/dev/null > "$SNAPSHOT_FILE" || touch "$SNAPSHOT_FILE"
else
  # No git - create empty snapshot (mtime-based detection will be used)
  touch "$SNAPSHOT_FILE"
fi

# Generate pre-prompt with critical workflow rules
PRE_PROMPT_FILE=".claude/pre-prompt.txt"
cat > "$PRE_PROMPT_FILE" << 'EOF'
MANDATORY CAPSULE KIT WORKFLOW RULES

## Context Check Protocol
BEFORE file operations: Check .claude/capsule.toon FILES section
BEFORE git operations: Check .claude/capsule.toon GIT section
BEFORE task questions: Check .claude/capsule.toon TASK section

## Tool Selection Matrix
Dependency queries → .claude/tools/query-deps/query-deps.sh <file>
Impact analysis → .claude/tools/impact-analysis/impact-analysis.sh <file>
Large files (>50KB) → $HOME/.claude/bin/progressive-reader --path <file> --list
File search → Glob tool with pattern
Code search → Grep tool with pattern

## Agent Orchestration Rules
Errors/bugs → error-detective agent (provides RCA)
Architecture questions → architecture-explorer agent
Refactoring → refactoring-specialist + impact-analysis
Pre-commit review → code-reviewer agent

## Post-Operation Logging
After Read/Edit/Write → ./.claude/hooks/log-file-access.sh <path> <action>
After Task agent → ./.claude/hooks/log-subagent.sh <type> <summary>
After discoveries → ./.claude/hooks/log-discovery.sh <category> <insight>

These are REQUIRED workflows, not suggestions. Follow them consistently.
EOF

echo "✓ Capsule session initialized" >&2
