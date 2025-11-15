#!/usr/bin/env bash
# Pre-edit analysis - shows impact analysis before file modifications
# Auto-runs before significant edits to show which files might be affected

set -euo pipefail

FILE_PATH="${1:-}"

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

DEP_GRAPH="$HOME/.claude/dep-graph.toon"

if [ ! -f "$DEP_GRAPH" ]; then
    TOOL_RUNNER_PATH="$HOME/.claude/lib/tool-runner.sh"

    if [ -f "$TOOL_RUNNER_PATH" ]; then
        source "$TOOL_RUNNER_PATH"
        if command -v run_tool &> /dev/null; then
            run_tool dependency-scanner --path "$(pwd)" --output "$DEP_GRAPH" &> /dev/null || true
        fi
    fi
fi

if [ ! -f "$DEP_GRAPH" ]; then
    exit 0
fi

# Source TOON parser
TOON_PARSER="$HOME/.claude/lib/toon-parser.sh"
if [ -f "$TOON_PARSER" ]; then
    source "$TOON_PARSER"
else
    exit 0
fi

# Check if file exists in graph
if ! toon_file_exists "$DEP_GRAPH" "$FILE_PATH"; then
    exit 0
fi

IMPORTER_COUNT=$(toon_count_importers "$DEP_GRAPH" "$FILE_PATH")

if [ "$IMPORTER_COUNT" -gt 0 ]; then
    echo ""
    echo "Impact Analysis for: $(basename "$FILE_PATH")"
    echo "   Files that import this: $IMPORTER_COUNT"

    IMPORTERS=$(toon_get_importers "$DEP_GRAPH" "$FILE_PATH" | head -5)

    if [ -n "$IMPORTERS" ]; then
        echo "   Affected files:"
        echo "$IMPORTERS" | while read -r importer; do
            echo "     $(basename "$importer")"
        done
    fi

    if [ "$IMPORTER_COUNT" -gt 5 ]; then
        echo "     ... and $((IMPORTER_COUNT - 5)) more"
    fi

    echo ""
    echo "   Run 'run_tool impact-analysis $FILE_PATH' for full analysis"
    echo ""
fi

exit 0
