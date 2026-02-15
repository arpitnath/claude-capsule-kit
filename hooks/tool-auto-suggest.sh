#!/usr/bin/env bash
# Tool auto-suggest - suggests relevant tools based on user prompt keywords
# Integrated into pre-task-analysis hook for automatic tool recommendations
# Output goes to stderr to not interfere with JSON hook responses

set -euo pipefail

USER_PROMPT="${1:-}"

if [ -z "$USER_PROMPT" ]; then
    exit 0
fi

PROMPT_LOWER=$(echo "$USER_PROMPT" | tr '[:upper:]' '[:lower:]')

declare -a SUGGESTIONS=()

if echo "$PROMPT_LOWER" | grep -qE '(depend|import|require|reference|use)'; then
    SUGGESTIONS+=("query-deps:Query file dependencies and relationships")
fi

if echo "$PROMPT_LOWER" | grep -qE '(circular|cycle|loop|recursive depend)'; then
    SUGGESTIONS+=("find-circular:Detect circular dependency cycles")
fi

if echo "$PROMPT_LOWER" | grep -qE '(unused|dead code|orphan|unreferenced|not used)'; then
    SUGGESTIONS+=("find-dead-code:Find potentially unused files")
fi

if echo "$PROMPT_LOWER" | grep -qE '(impact|affect|break|change.*will|what if|consequence)'; then
    SUGGESTIONS+=("impact-analysis:Analyze change impact on codebase")
fi

if echo "$PROMPT_LOWER" | grep -qE '(refactor|restructure|reorganize|move.*file|rename)'; then
    if ! echo "${SUGGESTIONS[*]}" | grep -q "query-deps"; then
        SUGGESTIONS+=("query-deps:Check dependencies before refactoring")
    fi
    if ! echo "${SUGGESTIONS[*]}" | grep -q "impact-analysis"; then
        SUGGESTIONS+=("impact-analysis:Understand refactoring impact")
    fi
fi

if echo "$PROMPT_LOWER" | grep -qE '(architecture|structure|organization|how.*organized)'; then
    SUGGESTIONS+=("dependency-scanner:Analyze codebase structure")
fi

if echo "$PROMPT_LOWER" | grep -qE '(large file|big file|huge file|read.*entire|bundle|compiled|minified)'; then
    SUGGESTIONS+=("progressive-reader:Read large files efficiently in semantic chunks")
fi

# Output JSON format if suggestions exist
if [ ${#SUGGESTIONS[@]} -gt 0 ]; then
    TOOLS_JSON="["
    FIRST=true
    SEEN_TOOLS=""

    for suggestion in "${SUGGESTIONS[@]}"; do
        TOOL_NAME="${suggestion%%:*}"
        TOOL_DESC="${suggestion#*:}"

        if ! echo "$SEEN_TOOLS" | grep -q "^${TOOL_NAME}$"; then
            SEEN_TOOLS="${SEEN_TOOLS}${TOOL_NAME}"$'\n'
            if [ "$FIRST" = true ]; then
                FIRST=false
            else
                TOOLS_JSON+=","
            fi
            TOOLS_JSON+="{\"name\":\"$TOOL_NAME\",\"description\":\"$TOOL_DESC\"}"
        fi
    done

    TOOLS_JSON+="]"

    echo "{\"type\":\"enforcement\",\"category\":\"capsule-kit-tools\",\"required\":true,\"tools\":$TOOLS_JSON,\"usage\":\"bash $HOME/.claude/cck/lib/tool-runner.sh <tool-name> [args]\"}"
fi

exit 0
