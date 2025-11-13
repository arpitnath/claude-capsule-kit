#!/bin/bash

# Pre-Tool-Use Hook
# Warns before redundant file reads to encourage using capsule data
# Runs BEFORE each tool call

set -euo pipefail

TOOL_NAME="${1:-}"
TOOL_INPUT="${2:-}"

# Only process Read operations
if [ "$TOOL_NAME" != "Read" ]; then
  exit 0
fi

# Extract file path from JSON input
FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('file_path', ''))" 2>/dev/null || echo "")

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Tracking files
RECENT_READS_LOG=".claude/recent_reads.log"
WARNINGS_SHOWN=".claude/read_warnings_shown.log"

# Create logs if they don't exist
mkdir -p .claude
touch "$RECENT_READS_LOG"
touch "$WARNINGS_SHOWN"

# Check if we already warned about this file this session
if grep -q "^${FILE_PATH}$" "$WARNINGS_SHOWN" 2>/dev/null; then
  exit 0
fi

# Check if file was recently accessed
CURRENT_TIME=$(date +%s)
THRESHOLD=300  # 5 minutes in seconds

if grep -q "^${FILE_PATH}," "$RECENT_READS_LOG" 2>/dev/null; then
  # Get last read time
  LAST_READ=$(grep "^${FILE_PATH}," "$RECENT_READS_LOG" | tail -1 | cut -d',' -f2)
  TIME_SINCE=$((CURRENT_TIME - LAST_READ))

  if [ $TIME_SINCE -lt $THRESHOLD ]; then
    # Convert to human readable
    if [ $TIME_SINCE -lt 60 ]; then
      TIME_STR="${TIME_SINCE}s"
    else
      TIME_STR="$((TIME_SINCE / 60))m"
    fi

    # Show warning
    echo "[TIP] File recently read (${TIME_STR} ago) - check capsule first"

    # Mark as warned
    echo "$FILE_PATH" >> "$WARNINGS_SHOWN"
  fi
fi

# Record this read attempt
echo "$FILE_PATH,$CURRENT_TIME" >> "$RECENT_READS_LOG"

exit 0
