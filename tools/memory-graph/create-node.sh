#!/bin/bash
# Create a memory node manually
# Usage: create-node.sh <type> <title> [--tags tag1,tag2] [--related id1,id2]

set -euo pipefail

usage() {
    echo "Usage: create-node.sh <type> <title> [--tags tag1,tag2] [--related id1,id2]"
    echo ""
    echo "Types: decision, discovery, error"
    echo ""
    echo "Examples:"
    echo "  create-node.sh decision 'Use JWT Auth' --tags auth,security"
    echo "  create-node.sh discovery 'Repository Pattern' --tags pattern,data-access"
    echo "  create-node.sh error 'Circular Import' --related file-src-auth-ts"
    exit 1
}

if [ $# -lt 2 ]; then
    usage
fi

TYPE="$1"
TITLE="$2"
shift 2

TAGS=""
RELATED=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --tags)
            TAGS="$2"
            shift 2
            ;;
        --related)
            RELATED="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

MEMORY_DIR="${CLAUDE_MEMORY_DIR:-.claude/memory}"

# Determine node directory based on type
case "$TYPE" in
    decision)
        NODE_DIR="$MEMORY_DIR/nodes/decisions"
        ;;
    discovery)
        NODE_DIR="$MEMORY_DIR/nodes/discoveries"
        ;;
    error)
        NODE_DIR="$MEMORY_DIR/nodes/errors"
        ;;
    *)
        echo "Error: Unknown type '$TYPE'. Use: decision, discovery, error" >&2
        exit 1
        ;;
esac

# Generate node ID from title
NODE_ID="${TYPE}-$(echo "$TITLE" | sed 's/[^a-zA-Z0-9]/-/g' | tr '[:upper:]' '[:lower:]' | sed 's/-\+/-/g' | sed 's/^-//' | sed 's/-$//' | head -c 50)"
NODE_PATH="$NODE_DIR/$NODE_ID.md"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mkdir -p "$NODE_DIR"

# Format tags as YAML array
TAGS_YAML="[$TYPE]"
if [ -n "$TAGS" ]; then
    TAGS_YAML="[$TYPE, $(echo "$TAGS" | sed 's/,/, /g')]"
fi

# Format related as YAML array
RELATED_YAML="[]"
if [ -n "$RELATED" ]; then
    # Convert comma-separated list to [[id1]], [[id2]] format
    RELATED_YAML="[$(echo "$RELATED" | sed 's/,/]], [[/g' | sed 's/^/[[/' | sed 's/$/]]/')]"
fi

# Create node content based on type
case "$TYPE" in
    decision)
        CONTENT="## Context
(What prompted this decision?)

## Decision
(What was decided?)

## Alternatives Considered
1. Alternative 1 - (why rejected)
2. Alternative 2 - (why rejected)

## Consequences
- **Positive**:
- **Negative**:

## Implementation
(Where is this implemented?)"
        ;;
    discovery)
        CONTENT="## Insight
(What did you learn?)

## Details
(More information)

## Where Used
(Files or areas where this applies)

## Implications
(What this means for future work)"
        ;;
    error)
        CONTENT="## Error Message
\`\`\`
(Paste error here)
\`\`\`

## Cause
(What caused the error?)

## Solution
(How was it fixed?)

## Prevention
(How to avoid in future)"
        ;;
esac

cat > "$NODE_PATH" << EOF
---
id: $NODE_ID
type: $TYPE
created: $NOW
updated: $NOW
status: active
tags: $TAGS_YAML
related: $RELATED_YAML
---

# $TITLE

$CONTENT
EOF

echo "Created node: $NODE_PATH"
echo ""
echo "Edit the node to add content, then rebuild the graph:"
echo "  CLAUDE_MEMORY_DIR=\"$MEMORY_DIR\" python3 tools/memory-graph/lib/graph.py rebuild"
