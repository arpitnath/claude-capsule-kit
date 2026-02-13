#!/bin/bash
# Discovery Suggestion Engine
# Analyzes recent activity and suggests potential discoveries to log

set -euo pipefail

SUGGESTION_COUNT=0

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 DISCOVERY SUGGESTIONS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Based on recent activity, consider logging these discoveries:"
echo ""

# Analyze git changes for patterns
if git status --porcelain 2>/dev/null | grep -q "^M.*\.sh$"; then
  echo "🔍 [pattern] Found shell scripts being modified - consider documenting script patterns"
  SUGGESTION_COUNT=$((SUGGESTION_COUNT + 1))
fi

if git status --porcelain 2>/dev/null | grep -q "^M.*\.ts$"; then
  echo "🔍 [pattern] TypeScript files modified - consider documenting code patterns"
  SUGGESTION_COUNT=$((SUGGESTION_COUNT + 1))
fi

if git status --porcelain 2>/dev/null | grep -q "^M.*\.py$"; then
  echo "🔍 [pattern] Python files modified - consider documenting implementation patterns"
  SUGGESTION_COUNT=$((SUGGESTION_COUNT + 1))
fi

# Analyze file access patterns
if [ -f ".claude/session_files.log" ]; then
  # Check for multiple edits to same file (deep work)
  MOST_EDITED=$(awk -F',' '$2=="edit" {print $1}' .claude/session_files.log 2>/dev/null | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
  if [ -n "$MOST_EDITED" ]; then
    echo "💭 [insight] Spent significant time on $MOST_EDITED - document key learnings"
    SUGGESTION_COUNT=$((SUGGESTION_COUNT + 1))
  fi

  # Check for new files created
  NEW_FILES=$(grep -c ",write," .claude/session_files.log 2>/dev/null || echo "0")
  if [ $NEW_FILES -gt 3 ]; then
    echo "🏗️ [architecture] Created $NEW_FILES new files - document architectural decisions"
    SUGGESTION_COUNT=$((SUGGESTION_COUNT + 1))
  fi
fi

# Analyze task completion patterns
if [ -f ".claude/current_tasks.log" ]; then
  COMPLETED_TASKS=$(grep -c "^completed|" .claude/current_tasks.log 2>/dev/null || echo "0")
  if [ $COMPLETED_TASKS -gt 3 ]; then
    echo "⚡ [optimization] Completed $COMPLETED_TASKS tasks - document process improvements"
    SUGGESTION_COUNT=$((SUGGESTION_COUNT + 1))
  fi
fi

# Analyze sub-agent usage
if [ -f ".claude/subagent_results.log" ]; then
  SUBAGENT_COUNT=$(wc -l < .claude/subagent_results.log 2>/dev/null | tr -d ' ')
  if [ $SUBAGENT_COUNT -gt 2 ]; then
    echo "🎯 [decision] Used $SUBAGENT_COUNT sub-agents - document delegation strategy"
    SUGGESTION_COUNT=$((SUGGESTION_COUNT + 1))
  fi
fi

# Check for test files
if git status --porcelain 2>/dev/null | grep -qE "test|spec"; then
  echo "✅ [decision] Working with tests - document testing approach"
  SUGGESTION_COUNT=$((SUGGESTION_COUNT + 1))
fi

if [ $SUGGESTION_COUNT -eq 0 ]; then
  echo "   No specific suggestions at this time."
  echo "   Continue working and discoveries will emerge!"
fi

echo ""
echo "💡 To log a discovery, use:"
echo "   $HOME/.claude/cck/hooks/log-discovery.sh \"<category>\" \"<content>\""
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
