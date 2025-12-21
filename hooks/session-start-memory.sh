#!/bin/bash
# SessionStart Memory Injection
# Injects memory context at session start

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

# Check if memory graph exists
if [ ! -d "$MEMORY_DIR/nodes" ] || [ ! -f "$QUERY_PY" ]; then
    exit 0
fi

# Check if graph.json exists and has nodes
if [ ! -f "$MEMORY_DIR/graph.json" ]; then
    exit 0
fi

NODE_COUNT=$(python3 -c "import json; print(json.load(open('$MEMORY_DIR/graph.json')).get('node_count', 0))" 2>/dev/null || echo "0")
if [ "$NODE_COUNT" = "0" ]; then
    exit 0
fi

echo "# Memory Context"
echo ""

# Recent session summary
RECENT_SESSION=$(CLAUDE_MEMORY_DIR="$MEMORY_DIR" python3 "$QUERY_PY" \
    --memory-dir "$MEMORY_DIR" \
    --command type \
    --query session \
    --format summary \
    --limit 1 \
    --status all 2>/dev/null || echo "")

if [ -n "$RECENT_SESSION" ]; then
    echo "## Last Session"
    echo "$RECENT_SESSION"
    echo ""
fi

# Active decisions
DECISIONS=$(CLAUDE_MEMORY_DIR="$MEMORY_DIR" python3 "$QUERY_PY" \
    --memory-dir "$MEMORY_DIR" \
    --command type \
    --query decision \
    --format summary \
    --limit 3 \
    --status active 2>/dev/null || echo "")

if [ -n "$DECISIONS" ]; then
    echo "## Active Decisions"
    echo "$DECISIONS"
    echo ""
fi

# In-progress tasks
TASKS=$(CLAUDE_MEMORY_DIR="$MEMORY_DIR" python3 "$QUERY_PY" \
    --memory-dir "$MEMORY_DIR" \
    --command type \
    --query task \
    --format summary \
    --limit 5 \
    --status in_progress 2>/dev/null || echo "")

if [ -n "$TASKS" ]; then
    echo "## Active Tasks"
    echo "$TASKS"
    echo ""
fi

# Recent file knowledge
FILES=$(CLAUDE_MEMORY_DIR="$MEMORY_DIR" python3 "$QUERY_PY" \
    --memory-dir "$MEMORY_DIR" \
    --command recent \
    --format summary \
    --limit 5 \
    --status active 2>/dev/null || echo "")

if [ -n "$FILES" ]; then
    echo "## Recent Context"
    echo "$FILES"
    echo ""
fi

exit 0
