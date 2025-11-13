#!/bin/bash

# Session End Hook
# Persists capsule and cleans up on session exit
# Runs when Claude Code session ends

set -euo pipefail

# Persist current session state
if [ -f ".claude/hooks/persist-capsule.sh" ]; then
  ./.claude/hooks/persist-capsule.sh 2>/dev/null || true
fi

# Generate session summary (compact format)
SESSION_START_FILE=".claude/session_start.txt"
FILE_LOG=".claude/session_files.log"
DISCOVERY_LOG=".claude/session_discoveries.log"
SUBAGENT_LOG=".claude/subagent_results.log"

if [ -f "$SESSION_START_FILE" ]; then
  START_TIME=$(cat "$SESSION_START_FILE" 2>/dev/null || echo "0")
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  # Convert to human readable
  if [ $DURATION -lt 60 ]; then
    DUR_STR="${DURATION}s"
  elif [ $DURATION -lt 3600 ]; then
    DUR_STR="$((DURATION / 60))m"
  else
    DUR_STR="$((DURATION / 3600))h"
  fi

  # Count activities
  FILES_COUNT=$(wc -l < "$FILE_LOG" 2>/dev/null | tr -d ' ' || echo "0")
  DISCOVERIES_COUNT=$(wc -l < "$DISCOVERY_LOG" 2>/dev/null | tr -d ' ' || echo "0")
  AGENTS_COUNT=$(wc -l < "$SUBAGENT_LOG" 2>/dev/null | tr -d ' ' || echo "0")

  echo ""
  echo "[SCK] Session ended | Duration: $DUR_STR"
  echo "Activity: $FILES_COUNT files, $DISCOVERIES_COUNT discoveries, $AGENTS_COUNT agents"
  echo "State persisted for next session"
  echo ""
fi

# Clean up temporary session files (not logs, just trackers)
rm -f .claude/recent_reads.log 2>/dev/null || true
rm -f .claude/read_warnings_shown.log 2>/dev/null || true
rm -f .claude/suggestions_shown.log 2>/dev/null || true
rm -f .claude/quality_suggestions_shown.log 2>/dev/null || true
rm -f .claude/quality_check_state.txt 2>/dev/null || true
rm -f .claude/capsule.hash 2>/dev/null || true

exit 0
