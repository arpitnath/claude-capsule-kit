#!/bin/bash
# Intelligent Session Summarization
# Generates TL;DR of current session

set -euo pipefail

# Redirect all stdout to stderr to avoid JSON validation errors in command hooks
exec 1>&2

SESSION_START=$(cat .claude/session_start.txt 2>/dev/null || date +%s)
CURRENT_TIME=$(date +%s)
DURATION=$((CURRENT_TIME - SESSION_START))
MESSAGE_COUNT=$(cat .claude/message_count.txt 2>/dev/null || echo "0")

# Convert duration to human readable
if [ $DURATION -lt 60 ]; then
  DUR_STR="${DURATION}s"
elif [ $DURATION -lt 3600 ]; then
  DUR_STR="$((DURATION / 60))m"
else
  DUR_STR="$((DURATION / 3600))h $((DURATION % 3600 / 60))m"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 SESSION SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⏱️  Duration: $DUR_STR | Messages: $MESSAGE_COUNT"
echo "🌿 Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
echo ""

# Tasks summary
if [ -f ".claude/current_tasks.log" ] && [ -s ".claude/current_tasks.log" ]; then
  COMPLETED_COUNT=$(grep -c "^completed|" .claude/current_tasks.log 2>/dev/null || echo "0")
  IN_PROGRESS_COUNT=$(grep -c "^in_progress|" .claude/current_tasks.log 2>/dev/null || echo "0")
  PENDING_COUNT=$(grep -c "^pending|" .claude/current_tasks.log 2>/dev/null || echo "0")

  echo "✅ Tasks:"
  echo "   Completed: $COMPLETED_COUNT | In Progress: $IN_PROGRESS_COUNT | Pending: $PENDING_COUNT"

  if [ $COMPLETED_COUNT -gt 0 ]; then
    echo ""
    echo "   Completed this session:"
    grep "^completed|" .claude/current_tasks.log 2>/dev/null | cut -d'|' -f2 | head -5 | while read -r task; do
      echo "   ✓ $task"
    done
  fi

  if [ $IN_PROGRESS_COUNT -gt 0 ]; then
    echo ""
    echo "   Still in progress:"
    grep "^in_progress|" .claude/current_tasks.log 2>/dev/null | cut -d'|' -f2 | while read -r task; do
      echo "   → $task"
    done
  fi
  echo ""
fi

# Files worked on
if [ -f ".claude/session_files.log" ] && [ -s ".claude/session_files.log" ]; then
  TOTAL_FILES=$(awk -F',' '{print $1}' .claude/session_files.log 2>/dev/null | sort -u | wc -l | tr -d ' ')
  EDITED_FILES=$(grep ",edit," .claude/session_files.log 2>/dev/null | wc -l | tr -d ' ')
  WRITTEN_FILES=$(grep ",write," .claude/session_files.log 2>/dev/null | wc -l | tr -d ' ')

  echo "📁 Files Accessed: $TOTAL_FILES unique files"
  [ $EDITED_FILES -gt 0 ] && echo "   Edited: $EDITED_FILES"
  [ $WRITTEN_FILES -gt 0 ] && echo "   Created: $WRITTEN_FILES"
  echo ""
fi

# Key discoveries
if [ -f ".claude/session_discoveries.log" ] && [ -s ".claude/session_discoveries.log" ]; then
  DISCOVERY_COUNT=$(wc -l < .claude/session_discoveries.log 2>/dev/null | tr -d ' ')

  echo "💡 Discoveries: $DISCOVERY_COUNT insights captured"
  echo ""
  echo "   Top discoveries:"

  # Group by category and show counts
  for category in pattern insight decision architecture bug optimization achievement; do
    COUNT=$(grep -c ",$category," .claude/session_discoveries.log 2>/dev/null || echo "0")
    if [ "$COUNT" -gt 0 ]; then
      case "$category" in
        "pattern") echo "   🔍 $COUNT patterns identified" ;;
        "insight") echo "   💭 $COUNT insights gained" ;;
        "decision") echo "   🎯 $COUNT decisions made" ;;
        "architecture") echo "   🏗️ $COUNT architectural learnings" ;;
        "bug") echo "   🐛 $COUNT bugs found" ;;
        "optimization") echo "   ⚡ $COUNT optimizations discovered" ;;
        "achievement") echo "   🎉 $COUNT achievements unlocked" ;;
      esac
    fi
  done
  echo ""
fi

# Sub-agent usage
if [ -f ".claude/subagent_results.log" ] && [ -s ".claude/subagent_results.log" ]; then
  SUBAGENT_COUNT=$(wc -l < .claude/subagent_results.log 2>/dev/null | tr -d ' ')

  echo "🤖 Sub-Agents: $SUBAGENT_COUNT agents used"

  # Count by type
  for agent_type in Explore Plan architecture-explorer database-navigator agent-developer github-issue-tracker general-purpose; do
    COUNT=$(grep -c ",$agent_type," .claude/subagent_results.log 2>/dev/null || echo "0")
    [ "$COUNT" -gt 0 ] && echo "   • $agent_type: $COUNT time(s)"
  done
  echo ""
fi

# Git changes
DIRTY_COUNT=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [ $DIRTY_COUNT -gt 0 ]; then
  echo "⚠️  Uncommitted Changes: $DIRTY_COUNT dirty files"
  echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Session complete. State persisted for next session."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
