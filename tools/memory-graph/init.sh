#!/bin/bash
# Initialize memory graph directory structure
# Usage: ./init.sh [memory_dir]

set -euo pipefail

MEMORY_DIR="${1:-.claude/memory}"

echo "Initializing memory graph at $MEMORY_DIR..."

# Create directory structure
mkdir -p "$MEMORY_DIR/nodes/files"
mkdir -p "$MEMORY_DIR/nodes/decisions"
mkdir -p "$MEMORY_DIR/nodes/discoveries"
mkdir -p "$MEMORY_DIR/nodes/sessions"
mkdir -p "$MEMORY_DIR/nodes/tasks"
mkdir -p "$MEMORY_DIR/nodes/errors"

# Create default config
cat > "$MEMORY_DIR/config.json" << 'EOF'
{
  "version": "1.0.0",
  "capture": {
    "auto_summarize_threshold_kb": 50,
    "auto_summarize_languages": ["typescript", "javascript", "python", "go"],
    "capture_todos": true,
    "capture_subagent_results": true
  },
  "injection": {
    "session_start_max_tokens": 500,
    "prompt_max_tokens": 1000,
    "max_nodes_per_query": 5
  },
  "retention": {
    "max_nodes": 500,
    "session_archive_days": 7,
    "prune_strategy": "least_connected_oldest"
  }
}
EOF

# Create empty graph cache
cat > "$MEMORY_DIR/graph.json" << 'EOF'
{
  "version": "1.0.0",
  "updated_at": "",
  "node_count": 0,
  "nodes": {},
  "tags": {},
  "types": {},
  "recent": []
}
EOF

# Create initial index
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > "$MEMORY_DIR/index.md" << EOF
---
updated: $NOW
---

# Memory Index

## Project Context
(Auto-populated after first session)

## Active Decisions
(None yet)

## Recent Sessions
(None yet)

## Key Files
(None yet)

## Active Tasks
(None yet)
EOF

echo "Created directories:"
echo "  $MEMORY_DIR/nodes/files/"
echo "  $MEMORY_DIR/nodes/decisions/"
echo "  $MEMORY_DIR/nodes/discoveries/"
echo "  $MEMORY_DIR/nodes/sessions/"
echo "  $MEMORY_DIR/nodes/tasks/"
echo "  $MEMORY_DIR/nodes/errors/"
echo ""
echo "Created files:"
echo "  $MEMORY_DIR/config.json"
echo "  $MEMORY_DIR/graph.json"
echo "  $MEMORY_DIR/index.md"
echo ""
echo "Memory graph initialized at $MEMORY_DIR"
