#!/usr/bin/env bash
# Keyword triggers - auto-suggests tools based on user prompt keywords
# Can be called standalone or integrated into other hooks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_RUNNER_PATH="$HOME/.claude/lib/tool-runner.sh"

if [ ! -f "$TOOL_RUNNER_PATH" ]; then
    exit 0
fi

source "$TOOL_RUNNER_PATH"

USER_PROMPT="${1:-}"

if [ -z "$USER_PROMPT" ]; then
    exit 0
fi

PROMPT_LOWER=$(echo "$USER_PROMPT" | tr '[:upper:]' '[:lower:]')

SUGGESTIONS_MADE=false

suggest_tool() {
    local tool_name="$1"
    local reason="$2"

    if ! $SUGGESTIONS_MADE; then
        echo ""
        echo "Claude Capsule Kit - Available Tools:"
        SUGGESTIONS_MADE=true
    fi

    echo "   $tool_name - $reason"
}

if echo "$PROMPT_LOWER" | grep -qE '(depend|import|require|reference)'; then
    suggest_tool "query-deps" "Query dependency relationships"
fi

if echo "$PROMPT_LOWER" | grep -qE '(circular|cycle|loop)'; then
    suggest_tool "find-circular" "Find circular dependency cycles"
fi

if echo "$PROMPT_LOWER" | grep -qE '(unused|dead code|orphan|unreferenced)'; then
    suggest_tool "find-dead-code" "Find potentially unused files"
fi

if echo "$PROMPT_LOWER" | grep -qE '(impact|affect|break|change.*will)'; then
    suggest_tool "impact-analysis" "Analyze impact of file changes"
fi

if echo "$PROMPT_LOWER" | grep -qE '(refactor|restructure|reorganize)'; then
    suggest_tool "query-deps" "Check dependencies before refactoring"
    suggest_tool "impact-analysis" "Analyze refactoring impact"
fi

if $SUGGESTIONS_MADE; then
    echo ""
    echo "   Usage: run_tool <tool-name> [args...]"
    echo ""
fi

exit 0
