#!/bin/bash

# Stop Hook
# Analyzes session quality after each response
# Suggests logging discoveries if quality ratio is poor

set -euo pipefail

# Defensive check: Ensure CWD exists (can be invalid if directory was deleted)
if ! cd "$(pwd 2>/dev/null)" 2>/dev/null; then
  # CWD is invalid, try to recover by going to home directory
  cd "$HOME" 2>/dev/null || exit 0
fi

# Find .claude directory by searching parent directories
find_claude_dir() {
  local current_dir="$PWD"
  while [ "$current_dir" != "/" ]; do
    if [ -d "$current_dir/.claude" ]; then
      echo "$current_dir/.claude"
      return 0
    fi
    current_dir=$(dirname "$current_dir")
  done
  echo ".claude"
  return 1
}

CLAUDE_DIR=$(find_claude_dir)

# Tracking files
QUALITY_CHECK_STATE="$CLAUDE_DIR/quality_check_state.txt"
SUGGESTIONS_SHOWN="$CLAUDE_DIR/quality_suggestions_shown.log"
FILE_LOG="$CLAUDE_DIR/session_files.log"
DISCOVERY_LOG="$CLAUDE_DIR/session_discoveries.log"

# Create files if needed
mkdir -p "$CLAUDE_DIR"
touch "$QUALITY_CHECK_STATE"
touch "$SUGGESTIONS_SHOWN"

# Check if already shown suggestion this session
if grep -q "^stop_quality$" "$SUGGESTIONS_SHOWN" 2>/dev/null; then
  exit 0
fi

# Get current counts
CURRENT_FILES=$(wc -l < "$FILE_LOG" 2>/dev/null | tr -d ' ' || echo "0")
CURRENT_DISCOVERIES=$(wc -l < "$DISCOVERY_LOG" 2>/dev/null | tr -d ' ' || echo "0")

# Get last checked counts
if [ -f "$QUALITY_CHECK_STATE" ]; then
  LAST_FILES=$(cut -d',' -f1 "$QUALITY_CHECK_STATE" 2>/dev/null || echo "0")
  LAST_DISCOVERIES=$(cut -d',' -f2 "$QUALITY_CHECK_STATE" 2>/dev/null || echo "0")
else
  LAST_FILES=0
  LAST_DISCOVERIES=0
fi

# Calculate new activity this turn
NEW_FILES=$((CURRENT_FILES - LAST_FILES))
NEW_DISCOVERIES=$((CURRENT_DISCOVERIES - LAST_DISCOVERIES))

# Update state for next check
echo "$CURRENT_FILES,$CURRENT_DISCOVERIES" > "$QUALITY_CHECK_STATE"

# Quality heuristic: If 3+ files accessed but 0 discoveries, suggest logging
if [ $NEW_FILES -ge 3 ] && [ $NEW_DISCOVERIES -eq 0 ]; then
  echo ""
  echo "[QUALITY TIP] Accessed $NEW_FILES files but logged 0 discoveries"
  echo "Consider: bash $CLAUDE_DIR/hooks/log-discovery.sh \"<category>\" \"<finding>\""
  echo ""

  # Mark as shown
  echo "stop_quality" >> "$SUGGESTIONS_SHOWN"
fi

exit 0
