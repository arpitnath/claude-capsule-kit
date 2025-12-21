#!/bin/bash
# Log session discoveries and key insights
# Usage: ./log-discovery.sh <category> <discovery>
# Categories: pattern, insight, decision, architecture, bug, optimization

set -euo pipefail

DISCOVERY_LOG=".claude/session_discoveries.log"
TIMESTAMP=$(date +%s)

if [ $# -lt 2 ]; then
  echo "Usage: $0 <category> <discovery>" >&2
  exit 1
fi

CATEGORY="$1"
shift
DISCOVERY="$*"

# Create log directory if needed
mkdir -p .claude

# Append to log (format: timestamp,category,discovery)
echo "$TIMESTAMP,$CATEGORY,$DISCOVERY" >> "$DISCOVERY_LOG"

# Capture to memory graph if enabled
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$SCRIPT_DIR" == *".claude/hooks"* ]]; then
    CLAUDE_DIR="$(dirname "$SCRIPT_DIR")"
    PROJECT_ROOT="$(dirname "$CLAUDE_DIR")"
    if [ -d "$CLAUDE_DIR/tools/memory-graph" ]; then
        TOOLS_DIR="$CLAUDE_DIR/tools/memory-graph"
    else
        TOOLS_DIR="$PROJECT_ROOT/tools/memory-graph"
    fi
else
    TOOLS_DIR="$(dirname "$SCRIPT_DIR")/tools/memory-graph"
fi
CAPTURE_PY="$TOOLS_DIR/lib/capture.py"
MEMORY_DIR="${CLAUDE_MEMORY_DIR:-.claude/memory}"

if [ -d "$MEMORY_DIR" ] && [ -f "$CAPTURE_PY" ]; then
    CLAUDE_MEMORY_DIR="$MEMORY_DIR" python3 "$CAPTURE_PY" discovery "$CATEGORY" "$DISCOVERY" >/dev/null 2>&1 &
fi

echo "✓ Discovery logged: $CATEGORY" >&2
