#!/bin/bash
# Claude Capsule Kit Stats Dashboard
# Shows usage statistics for the current session

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Claude Capsule Kit Usage Statistics"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if .claude directory exists
if [ ! -d ".claude" ]; then
  echo "⚠️  Claude Capsule Kit not initialized in this directory"
  exit 0
fi

# Get counts
FILES_COUNT=0
DISC_COUNT=0
TASKS_COUNT=0
SUBAGENT_COUNT=0
MESSAGE_COUNT=0

[ -f ".claude/session_files.log" ] && FILES_COUNT=$(wc -l < .claude/session_files.log 2>/dev/null || echo 0)
[ -f ".claude/session_discoveries.log" ] && DISC_COUNT=$(wc -l < .claude/session_discoveries.log 2>/dev/null || echo 0)
[ -f ".claude/current_tasks.log" ] && TASKS_COUNT=$(wc -l < .claude/current_tasks.log 2>/dev/null || echo 0)
[ -f ".claude/subagent_results.log" ] && SUBAGENT_COUNT=$(wc -l < .claude/subagent_results.log 2>/dev/null || echo 0)
[ -f ".claude/message_count.txt" ] && MESSAGE_COUNT=$(cat .claude/message_count.txt 2>/dev/null || echo 0)

echo "📁 Files accessed: $FILES_COUNT"
echo "💡 Discoveries logged: $DISC_COUNT"
echo "✅ Tasks tracked: $TASKS_COUNT"
echo "🤖 Sub-agents used: $SUBAGENT_COUNT"
echo "💬 Messages in session: $MESSAGE_COUNT"
echo ""

# Show last entries if they exist
if [ -f ".claude/session_files.log" ] && [ "$FILES_COUNT" -gt 0 ]; then
  echo "📄 Last file accessed:"
  tail -1 .claude/session_files.log | awk -F'|' '{print "   " $1 " (" $2 ")"}'
  echo ""
fi

if [ -f ".claude/session_discoveries.log" ] && [ "$DISC_COUNT" -gt 0 ]; then
  echo "💡 Last discovery:"
  tail -1 .claude/session_discoveries.log | awk -F'|' '{print "   [" $1 "] " $2}'
  echo ""
fi

if [ -f ".claude/current_tasks.log" ] && [ "$TASKS_COUNT" -gt 0 ]; then
  echo "✅ Current task:"
  tail -1 .claude/current_tasks.log | awk -F'|' '{print "   [" $1 "] " $2}'
  echo ""
fi

# Session duration
if [ -f ".claude/session_start.txt" ]; then
  session_start=$(cat .claude/session_start.txt)
  current_time=$(date +%s)
  duration=$((current_time - session_start))
  minutes=$((duration / 60))
  echo "⏱️  Session duration: ${minutes}m"
  echo ""
fi

# Capsule health check
if [ "$MESSAGE_COUNT" -gt 0 ]; then
  total_logs=$((FILES_COUNT + DISC_COUNT + TASKS_COUNT))
  logs_per_message=$(echo "scale=1; $total_logs / $MESSAGE_COUNT" | bc 2>/dev/null || echo "0")

  echo "🏥 Capsule Health:"
  if (( $(echo "$logs_per_message >= 1.0" | bc -l 2>/dev/null || echo 0) )); then
    echo "   ✅ Active ($logs_per_message logs/message)"
  elif (( $(echo "$logs_per_message >= 0.5" | bc -l 2>/dev/null || echo 0) )); then
    echo "   ⚠️  Moderate ($logs_per_message logs/message)"
  else
    echo "   ❌ Low ($logs_per_message logs/message)"
  fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
