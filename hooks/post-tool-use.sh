#!/bin/bash
# PostToolUse Hook - Auto-logs file operations and task updates
# Claude Code passes arguments via stdin as JSON, NOT positional args

set -euo pipefail

# Defensive check: Ensure CWD exists (can be invalid if directory was deleted)
if ! cd "$(pwd 2>/dev/null)" 2>/dev/null; then
  cd "$HOME" 2>/dev/null || exit 0
fi

# Read JSON from stdin (Claude Code's hook protocol)
INPUT_JSON=$(cat)

# Determine script directory for finding tools
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Check if we're in .claude/hooks (installed) or hooks/ (source)
if [[ "$SCRIPT_DIR" == *".claude/hooks"* ]]; then
    # Installed location - check .claude/tools first, then project root tools/
    CLAUDE_DIR="$(dirname "$SCRIPT_DIR")"
    PROJECT_ROOT="$(dirname "$CLAUDE_DIR")"
    if [ -d "$CLAUDE_DIR/tools/memory-graph" ]; then
        TOOLS_DIR="$CLAUDE_DIR/tools/memory-graph"
    else
        TOOLS_DIR="$PROJECT_ROOT/tools/memory-graph"
    fi
else
    # Source location - tools are sibling to hooks/
    TOOLS_DIR="$(dirname "$SCRIPT_DIR")/tools/memory-graph"
fi
CAPTURE_PY="$TOOLS_DIR/lib/capture.py"
GRAPH_PY="$TOOLS_DIR/lib/graph.py"

# Memory graph config
MEMORY_DIR="${CLAUDE_MEMORY_DIR:-.claude/memory}"
MEMORY_ENABLED="false"
if [ -d "$MEMORY_DIR" ] && [ -f "$CAPTURE_PY" ]; then
    MEMORY_ENABLED="true"
fi

# Function to capture file access to memory graph
capture_file() {
    local file_path="$1"
    local action="$2"
    if [ "$MEMORY_ENABLED" = "true" ]; then
        CLAUDE_MEMORY_DIR="$MEMORY_DIR" python3 "$CAPTURE_PY" file "$file_path" --action "$action" >/dev/null 2>&1 &
    fi
}

# Function to capture task to memory graph
capture_task() {
    local content="$1"
    local status="$2"
    if [ "$MEMORY_ENABLED" = "true" ]; then
        CLAUDE_MEMORY_DIR="$MEMORY_DIR" python3 "$CAPTURE_PY" task "$content" --status "$status" >/dev/null 2>&1 &
    fi
}

# Function to capture subagent result to memory graph
capture_subagent() {
    local agent_type="$1"
    local summary="$2"
    if [ "$MEMORY_ENABLED" = "true" ]; then
        CLAUDE_MEMORY_DIR="$MEMORY_DIR" python3 "$CAPTURE_PY" subagent "$agent_type" "$summary" >/dev/null 2>&1 &
    fi
}

# Extract fields from JSON using python3
TOOL_NAME=$(echo "$INPUT_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('tool_name', ''))" 2>/dev/null || echo "")
TOOL_INPUT=$(echo "$INPUT_JSON" | python3 -c "import sys, json; import json as j; print(j.dumps(json.load(sys.stdin).get('tool_input', {})))" 2>/dev/null || echo "{}")
TOOL_OUTPUT=$(echo "$INPUT_JSON" | python3 -c "import sys, json; import json as j; r = json.load(sys.stdin).get('tool_response', {}); print(j.dumps(r) if isinstance(r, dict) else str(r))" 2>/dev/null || echo "")

if [ -z "$TOOL_NAME" ]; then
  exit 0
fi

case "$TOOL_NAME" in
  "Read")
    if FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('file_path', ''))" 2>/dev/null); then
      if [ -n "$FILE_PATH" ]; then
        ./.claude/hooks/log-file-access.sh "$FILE_PATH" "read" 2>/dev/null || true
        capture_file "$FILE_PATH" "read"
      fi
    fi
    ;;

  "Edit")
    if FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('file_path', ''))" 2>/dev/null); then
      if [ -n "$FILE_PATH" ]; then
        ./.claude/hooks/log-file-access.sh "$FILE_PATH" "edit" 2>/dev/null || true
        capture_file "$FILE_PATH" "edit"
      fi
    fi
    ;;

  "Write")
    if FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('file_path', ''))" 2>/dev/null); then
      if [ -n "$FILE_PATH" ]; then
        ./.claude/hooks/log-file-access.sh "$FILE_PATH" "write" 2>/dev/null || true
        capture_file "$FILE_PATH" "write"
      fi
    fi
    ;;

  "Task")
    if AGENT_TYPE=$(echo "$TOOL_INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('subagent_type', ''))" 2>/dev/null); then
      if [ -n "$AGENT_TYPE" ] && [ -n "$TOOL_OUTPUT" ]; then
        SUMMARY=$(echo "$TOOL_OUTPUT" | head -c 200 | tr '\n' ' ')
        ./.claude/hooks/log-subagent.sh "$AGENT_TYPE" "$SUMMARY" 2>/dev/null || true
        # Capture to memory graph
        capture_subagent "$AGENT_TYPE" "$SUMMARY"
      fi
    fi
    ;;

  "Bash")
    # Log progressive-reader usage and output
    if echo "$TOOL_INPUT" | grep -q "progressive-reader"; then
      if FILE_PATH=$(echo "$TOOL_INPUT" | grep -oE '\-\-path [^ ]+' | cut -d' ' -f2); then
        if [ -n "$FILE_PATH" ]; then
          ./.claude/hooks/log-file-access.sh "$FILE_PATH" "progressive-read" 2>/dev/null || true
          # Also capture to memory graph
          capture_file "$FILE_PATH" "read"
        fi
      fi
      # Log progressive-reader output for debugging
      if [ -n "$TOOL_OUTPUT" ]; then
        echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] progressive-reader output:" >> .claude/progressive-reader.log
        echo "$TOOL_OUTPUT" >> .claude/progressive-reader.log
        echo "---" >> .claude/progressive-reader.log
      fi
    fi
    ;;

  "TodoWrite")
    if [ -n "$TOOL_INPUT" ]; then
      # Clear existing tasks and write new ones directly from Python
      echo "$TOOL_INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    todos = data.get('todos', [])
    with open('.claude/current_tasks.log', 'w') as f:
        for todo in todos:
            status = todo.get('status', 'unknown')
            content = todo.get('content', '')
            if content:
                f.write(f'{status}|{content}\n')
except Exception as e:
    pass
" 2>/dev/null || true
      # Capture tasks to memory graph (only in_progress and completed)
      echo "$TOOL_INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    todos = data.get('todos', [])
    for todo in todos:
        status = todo.get('status', '')
        content = todo.get('content', '')
        if content and status in ('in_progress', 'completed'):
            print(f'{status}|{content}')
except:
    pass
" 2>/dev/null | while IFS='|' read -r status content; do
        capture_task "$content" "$status"
      done
    fi
    ;;
esac

exit 0
