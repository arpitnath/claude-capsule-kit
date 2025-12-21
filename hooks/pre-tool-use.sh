#!/bin/bash

# Pre-Tool-Use Hook
# 1. Warns before redundant file reads to encourage using capsule data
# 2. Enforces Claude Capsule Kit tools for dependency analysis
# 3. Auto-logs file access to capsule
# Runs BEFORE each tool call
# Claude Code passes arguments via stdin as JSON, NOT positional args

set -euo pipefail

# Defensive check: Ensure CWD exists (can be invalid if directory was deleted)
if ! cd "$(pwd 2>/dev/null)" 2>/dev/null; then
  cd "$HOME" 2>/dev/null || exit 0
fi

# Read JSON from stdin (Claude Code's hook protocol)
INPUT_JSON=$(cat)

# Extract fields from JSON using python3
TOOL_NAME=$(echo "$INPUT_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('tool_name', ''))" 2>/dev/null || echo "")
TOOL_INPUT=$(echo "$INPUT_JSON" | python3 -c "import sys, json; import json as j; print(j.dumps(json.load(sys.stdin).get('tool_input', {})))" 2>/dev/null || echo "{}")

# Task tool interception - enforce dependency tools
if [ "$TOOL_NAME" == "Task" ]; then
  # Extract prompt from Task tool input
  TASK_PROMPT=$(echo "$TOOL_INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('prompt', ''))" 2>/dev/null || echo "")

  if [ -n "$TASK_PROMPT" ]; then
    # Convert to lowercase for pattern matching
    PROMPT_LOWER=$(echo "$TASK_PROMPT" | tr '[:upper:]' '[:lower:]')

    # Detect dependency-related queries
    if echo "$PROMPT_LOWER" | grep -qE '(depend|import|require|module.*load|circular.*depend|who.*use|what.*import|find.*import)'; then
      # Output JSON enforcement message (to stderr for informational display)
      cat << 'EOF' >&2
{"type":"tool-enforcement","category":"dependency-analysis","warning":"Query appears to be about code dependencies","dontUse":{"tool":"Task","reason":"inefficient","issues":["Slower: Scans files one-by-one","Limited: Cannot detect circular dependencies","Expensive: High token usage"]},"useInstead":[{"name":"query-deps","useCase":"what imports X, who uses X","command":"bash .claude/tools/query-deps/query-deps.sh <file-path>"},{"name":"impact-analysis","useCase":"what would break if I change X","command":"bash .claude/tools/impact-analysis/impact-analysis.sh <file-path>"},{"name":"find-circular","useCase":"circular dependencies","command":"bash .claude/tools/find-circular/find-circular.sh"}],"benefit":"These tools are instant and read pre-built dependency graph"}
EOF
    fi

    # Detect file search queries
    if echo "$PROMPT_LOWER" | grep -qE '(where.*file|find.*file|locate.*file|search.*file)' && ! echo "$PROMPT_LOWER" | grep -qE '(depend|import|require)'; then
      # Output JSON suggestion message (to stderr for informational display)
      cat << 'EOF' >&2
{"type":"tool-suggestion","category":"file-search","useInstead":{"tool":"Glob","reason":"faster-and-direct","pattern":"**/*<filename>*","description":"For finding files by name pattern"}}
EOF
    fi
  fi

  exit 0
fi

# Read tool monitoring and large file detection
if [ "$TOOL_NAME" != "Read" ]; then
  exit 0
fi

FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('file_path', ''))" 2>/dev/null || echo "")

# Get project root from script location (.claude/hooks/ -> project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Check file size and block Read for large files (force progressive-reader)
if [ -n "$FILE_PATH" ]; then
  RESOLVED_PATH=""

  # Try multiple path resolutions
  if [ -f "$FILE_PATH" ]; then
    RESOLVED_PATH="$FILE_PATH"
  elif [ -f "$PROJECT_ROOT/$FILE_PATH" ]; then
    RESOLVED_PATH="$PROJECT_ROOT/$FILE_PATH"
  elif [ -f "$(pwd)/$FILE_PATH" ]; then
    RESOLVED_PATH="$(pwd)/$FILE_PATH"
  fi

  if [ -n "$RESOLVED_PATH" ]; then
    # Skip size check for images and binary files (Claude handles these natively)
    FILE_EXT="${RESOLVED_PATH##*.}"
    FILE_EXT_LOWER=$(echo "$FILE_EXT" | tr '[:upper:]' '[:lower:]')

    case "$FILE_EXT_LOWER" in
      jpg|jpeg|png|gif|webp|svg|bmp|ico|pdf|ipynb)
        # Allow images, PDFs, notebooks regardless of size
        exit 0
        ;;
    esac

    FILE_SIZE=$(stat -f%z "$RESOLVED_PATH" 2>/dev/null || stat -c%s "$RESOLVED_PATH" 2>/dev/null || echo "0")
    FILE_SIZE_KB=$((FILE_SIZE / 1024))

    if [ "$FILE_SIZE" -gt 51200 ]; then  # 50KB threshold
      echo "{\"decision\": \"block\", \"reason\": \"File ${FILE_SIZE_KB}KB exceeds 50KB. Use progressive-reader instead: .claude/bin/progressive-reader --path $FILE_PATH --list\"}"
      exit 0
    fi
  fi
fi

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Tracking files
RECENT_READS_LOG=".claude/recent_reads.log"
WARNINGS_SHOWN=".claude/read_warnings_shown.log"

# Create logs if they don't exist
mkdir -p .claude
touch "$RECENT_READS_LOG"
touch "$WARNINGS_SHOWN"

# Check if we already warned about this file this session
if grep -q "^${FILE_PATH}$" "$WARNINGS_SHOWN" 2>/dev/null; then
  exit 0
fi

# Check if file was recently accessed
CURRENT_TIME=$(date +%s)
THRESHOLD=300  # 5 minutes in seconds

if grep -q "^${FILE_PATH}," "$RECENT_READS_LOG" 2>/dev/null; then
  # Get last read time
  LAST_READ=$(grep "^${FILE_PATH}," "$RECENT_READS_LOG" | tail -1 | cut -d',' -f2)
  TIME_SINCE=$((CURRENT_TIME - LAST_READ))

  if [ $TIME_SINCE -lt $THRESHOLD ]; then
    # Convert to human readable
    if [ $TIME_SINCE -lt 60 ]; then
      TIME_STR="${TIME_SINCE}s"
    else
      TIME_STR="$((TIME_SINCE / 60))m"
    fi

    # Show warning as JSON (to stderr so it doesn't interfere with JSON blocking output)
    echo "{\"type\":\"read-warning\",\"file\":\"$FILE_PATH\",\"lastRead\":\"${TIME_STR} ago\",\"message\":\"File recently read - check capsule first\"}" >&2

    # Mark as warned
    echo "$FILE_PATH" >> "$WARNINGS_SHOWN"
  fi
fi

# Record this read attempt
echo "$FILE_PATH,$CURRENT_TIME" >> "$RECENT_READS_LOG"

# Auto-log file access to capsule
if [ -x ".claude/hooks/log-file-access.sh" ]; then
  # Auto-log this read operation (suppress output to avoid noise)
  .claude/hooks/log-file-access.sh "$FILE_PATH" "read" > /dev/null 2>&1 || true
fi

exit 0
