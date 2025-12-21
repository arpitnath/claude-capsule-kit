#!/bin/bash
# UserPromptSubmit Memory Injection
# Injects relevant context based on user's prompt

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

# Read prompt from stdin
INPUT_JSON=$(cat)
PROMPT=$(echo "$INPUT_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('prompt', ''))" 2>/dev/null || echo "")

if [ -z "$PROMPT" ]; then
    exit 0
fi

# Check if memory graph exists
if [ ! -d "$MEMORY_DIR/nodes" ] || [ ! -f "$QUERY_PY" ]; then
    exit 0
fi

# Check if graph has nodes
NODE_COUNT=$(python3 -c "import json; print(json.load(open('$MEMORY_DIR/graph.json')).get('node_count', 0))" 2>/dev/null || echo "0")
if [ "$NODE_COUNT" = "0" ]; then
    exit 0
fi

CONTEXT=""

# Extract potential file paths from prompt (common extensions)
FILE_MATCHES=$(echo "$PROMPT" | grep -oE '[a-zA-Z0-9_/.-]+\.(ts|tsx|js|jsx|py|go|rs|java|md|sh|json|yaml|yml)' | head -3 || echo "")

# Search for file-related knowledge
for FILE in $FILE_MATCHES; do
    # Convert file path to node ID pattern
    NODE_PATTERN=$(echo "$FILE" | sed 's/[^a-zA-Z0-9]/-/g' | tr '[:upper:]' '[:lower:]')

    RESULT=$(CLAUDE_MEMORY_DIR="$MEMORY_DIR" python3 "$QUERY_PY" \
        --memory-dir "$MEMORY_DIR" \
        --command search \
        --query "$FILE" \
        --format summary \
        --limit 2 \
        --status active 2>/dev/null || echo "")

    if [ -n "$RESULT" ]; then
        CONTEXT="$CONTEXT$RESULT"$'\n'
    fi
done

# Extract keywords (simple approach - words 4+ chars)
KEYWORDS=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]' | grep -oE '\b[a-z]{4,}\b' | sort -u | head -5 || echo "")

# Search for keyword matches in tags
for KEYWORD in $KEYWORDS; do
    RESULT=$(CLAUDE_MEMORY_DIR="$MEMORY_DIR" python3 "$QUERY_PY" \
        --memory-dir "$MEMORY_DIR" \
        --command tag \
        --query "$KEYWORD" \
        --format summary \
        --limit 2 \
        --status active 2>/dev/null || echo "")

    if [ -n "$RESULT" ]; then
        CONTEXT="$CONTEXT$RESULT"$'\n'
    fi
done

# Dedupe and output
if [ -n "$CONTEXT" ]; then
    echo "# Relevant Memory"
    echo ""
    echo "$CONTEXT" | sort -u | head -10
    echo ""
fi

exit 0
