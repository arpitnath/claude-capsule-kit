#!/bin/bash
# Memory Query Tool - Query the memory graph
# Usage: memory-query.sh [OPTIONS]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEMORY_DIR="${CLAUDE_MEMORY_DIR:-.claude/memory}"

# Show help
show_help() {
    cat << 'EOF'
Memory Query Tool - Query the memory graph

USAGE:
    memory-query.sh [OPTIONS]

OPTIONS:
    --recent [N]           Get N most recent nodes (default: 5)
    --type <type>          Get nodes by type (file-summary, decision, discovery, etc.)
    --tag <tag>            Get nodes with a specific tag
    --related <id>         Get nodes related to a specific node
    --search <term>        Full-text search in node content
    --id <id>              Get a specific node by ID

    --format <format>      Output format: summary (default), json, full, ids
    --limit <N>            Maximum results (default: 5)
    --status <status>      Filter by status: active (default), archived, all

EXAMPLES:
    # Get recent context for session start
    memory-query.sh --recent 5

    # Find all auth-related knowledge
    memory-query.sh --tag auth

    # Get context before editing a file
    memory-query.sh --related file-src-auth-ts

    # Find all active decisions
    memory-query.sh --type decision --status active

    # Search for specific topic
    memory-query.sh --search "jwt token"
EOF
}

# Parse arguments
COMMAND=""
QUERY=""
FORMAT="summary"
LIMIT=5
STATUS="active"

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --recent)
            COMMAND="recent"
            if [[ "${2:-}" =~ ^[0-9]+$ ]]; then
                LIMIT="$2"
                shift
            fi
            shift
            ;;
        --type)
            COMMAND="type"
            QUERY="${2:-}"
            shift 2 || { echo "Error: --type requires an argument" >&2; exit 1; }
            ;;
        --tag)
            COMMAND="tag"
            QUERY="${2:-}"
            shift 2 || { echo "Error: --tag requires an argument" >&2; exit 1; }
            ;;
        --related)
            COMMAND="related"
            QUERY="${2:-}"
            shift 2 || { echo "Error: --related requires an argument" >&2; exit 1; }
            ;;
        --search)
            COMMAND="search"
            QUERY="${2:-}"
            shift 2 || { echo "Error: --search requires an argument" >&2; exit 1; }
            ;;
        --id)
            COMMAND="id"
            QUERY="${2:-}"
            shift 2 || { echo "Error: --id requires an argument" >&2; exit 1; }
            ;;
        --format)
            FORMAT="${2:-summary}"
            shift 2 || { echo "Error: --format requires an argument" >&2; exit 1; }
            ;;
        --limit)
            LIMIT="${2:-5}"
            shift 2 || { echo "Error: --limit requires an argument" >&2; exit 1; }
            ;;
        --status)
            STATUS="${2:-active}"
            shift 2 || { echo "Error: --status requires an argument" >&2; exit 1; }
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Check if command was specified
if [ -z "$COMMAND" ]; then
    echo "Error: No query command specified" >&2
    echo "Use --help for usage information" >&2
    exit 1
fi

# Check if memory directory exists
if [ ! -d "$MEMORY_DIR" ]; then
    echo "Memory graph not initialized. Run: bash $SCRIPT_DIR/init.sh" >&2
    exit 1
fi

# Run the Python query engine
export CLAUDE_MEMORY_DIR="$MEMORY_DIR"
python3 "$SCRIPT_DIR/lib/query.py" \
    --memory-dir "$MEMORY_DIR" \
    --command "$COMMAND" \
    --query "$QUERY" \
    --format "$FORMAT" \
    --limit "$LIMIT" \
    --status "$STATUS"
