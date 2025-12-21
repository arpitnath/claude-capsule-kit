#!/bin/bash
# SessionEnd Memory Persistence
# Creates session summary and updates index

set -euo pipefail

# Determine script directory for finding tools
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$SCRIPT_DIR" == *".claude/hooks"* ]]; then
    PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
else
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
fi

MEMORY_DIR="${CLAUDE_MEMORY_DIR:-.claude/memory}"
TOOLS_DIR="$PROJECT_ROOT/tools/memory-graph"
QUERY_PY="$TOOLS_DIR/lib/query.py"
GRAPH_PY="$TOOLS_DIR/lib/graph.py"

# Check if memory graph exists
if [ ! -d "$MEMORY_DIR/nodes" ] || [ ! -f "$QUERY_PY" ]; then
    exit 0
fi

# Read session info from stdin (if any)
INPUT_JSON=$(cat 2>/dev/null || echo "{}")

# Get session ID from environment or generate
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%s)}"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TODAY=$(date +"%Y-%m-%d")

NODE_DIR="$MEMORY_DIR/nodes/sessions"
NODE_ID="session-$TODAY-${SESSION_ID:0:8}"
NODE_PATH="$NODE_DIR/$NODE_ID.md"

mkdir -p "$NODE_DIR"

# Get completed tasks
COMPLETED_TASKS=$(CLAUDE_MEMORY_DIR="$MEMORY_DIR" python3 "$QUERY_PY" \
    --memory-dir "$MEMORY_DIR" \
    --command type \
    --query task \
    --format summary \
    --status completed \
    --limit 10 2>/dev/null || echo "(none)")

# Get active tasks
ACTIVE_TASKS=$(CLAUDE_MEMORY_DIR="$MEMORY_DIR" python3 "$QUERY_PY" \
    --memory-dir "$MEMORY_DIR" \
    --command type \
    --query task \
    --format summary \
    --status in_progress \
    --limit 5 2>/dev/null || echo "(none)")

# Get recent files
RECENT_FILES=$(CLAUDE_MEMORY_DIR="$MEMORY_DIR" python3 "$QUERY_PY" \
    --memory-dir "$MEMORY_DIR" \
    --command type \
    --query file-summary \
    --format summary \
    --limit 5 2>/dev/null || echo "(none)")

# Get decisions made
DECISIONS=$(CLAUDE_MEMORY_DIR="$MEMORY_DIR" python3 "$QUERY_PY" \
    --memory-dir "$MEMORY_DIR" \
    --command type \
    --query decision \
    --format summary \
    --status active \
    --limit 3 2>/dev/null || echo "(none)")

# Create session summary node
cat > "$NODE_PATH" << EOF
---
id: $NODE_ID
type: session
created: $NOW
updated: $NOW
status: archived
tags: [session]
related: []
session_id: $SESSION_ID
---

# Session: $TODAY

## Summary
(Session summary - auto-generated at session end)

## Tasks Completed
$COMPLETED_TASKS

## Tasks In Progress
$ACTIVE_TASKS

## Key Decisions
$DECISIONS

## Files Accessed
$RECENT_FILES
EOF

# Update index.md
INDEX_PATH="$MEMORY_DIR/index.md"

cat > "$INDEX_PATH" << EOF
---
updated: $NOW
---

# Memory Index

## Last Session
[[$NODE_ID]]

## Active Tasks
$ACTIVE_TASKS

## Key Decisions
$DECISIONS

## Recent Files
$RECENT_FILES
EOF

# Rebuild graph in background
CLAUDE_MEMORY_DIR="$MEMORY_DIR" python3 "$GRAPH_PY" rebuild >/dev/null 2>&1 &

echo "Session persisted: $NODE_ID"

exit 0
