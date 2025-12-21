#!/bin/bash
# Validation Hook - Checks if Claude is using the capsule system properly
# Runs silently, only warns if issues detected

set -euo pipefail

# Check if we're in a git repository
if [ ! -d ".git" ]; then
  exit 0
fi

# Create .claude directory if it doesn't exist
mkdir -p .claude

# Check if logs exist and have recent activity
FILES_LOG=".claude/session_files.log"
DISC_LOG=".claude/session_discoveries.log"
TASKS_LOG=".claude/current_tasks.log"

# Get message count
MESSAGE_COUNT=0
if [ -f ".claude/message_count.txt" ]; then
  MESSAGE_COUNT=$(cat .claude/message_count.txt 2>/dev/null || echo 0)
fi

# Only validate after 3+ messages
if [ "$MESSAGE_COUNT" -lt 3 ]; then
  exit 0
fi

# Check if ANY logging has happened
total_logs=0
[ -f "$FILES_LOG" ] && total_logs=$((total_logs + $(wc -l < "$FILES_LOG" 2>/dev/null || echo 0)))
[ -f "$DISC_LOG" ] && total_logs=$((total_logs + $(wc -l < "$DISC_LOG" 2>/dev/null || echo 0)))
[ -f "$TASKS_LOG" ] && total_logs=$((total_logs + $(wc -l < "$TASKS_LOG" 2>/dev/null || echo 0)))

# Warn if no logs after 3 messages
if [ "$total_logs" -eq 0 ] && [ "$MESSAGE_COUNT" -ge 3 ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "⚠️  Claude Capsule Kit: Capsule logging not detected"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "💡 Reminder: Log your actions for better context:"
  echo "   • After Read/Edit/Write → log-file-access.sh"
  echo "   • After discoveries → log-discovery.sh"
  echo "   • After Task tool → log-subagent.sh"
  echo "   • After TodoWrite → log-task.sh"
  echo ""
  echo "📖 Guide: .claude/docs/CAPSULE_USAGE_GUIDE.md"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
fi

exit 0
