#!/bin/bash
set -euo pipefail

# Token Tracker - Analyze Claude Code session token usage
# Usage:
#   token-tracker.sh <session-file.jsonl>
#   token-tracker.sh <project-path> --latest
#   token-tracker.sh <session-file.jsonl> --detailed

VERSION="1.0.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_usage() {
    cat << EOF
Token Tracker v${VERSION}

Analyze Claude Code session token usage from JSONL logs.

USAGE:
    $(basename "$0") <session-file.jsonl>              Analyze specific session
    $(basename "$0") <project-path> --latest           Auto-find latest session
    $(basename "$0") <session-file.jsonl> --detailed   Show per-message breakdown

EXAMPLES:
    $(basename "$0") ~/.claude/projects/.../abc123.jsonl
    $(basename "$0") ~/node --latest
    $(basename "$0") session.jsonl --detailed

OPTIONS:
    --latest        Find and analyze the most recent session for a project
    --detailed      Show per-message token breakdown
    --help          Show this help message
    --version       Show version

OUTPUT:
    Displays total token usage including:
    - Input tokens (new content)
    - Cache read tokens (from prompt cache)
    - Cache creation tokens (building cache)
    - Output tokens (Claude's responses)
EOF
}

find_latest_session() {
    local project_path="$1"
    local normalized_path

    # Normalize project path
    normalized_path=$(cd "$project_path" && pwd | sed 's/\//-/g')
    local session_dir="${HOME}/.claude/projects/${normalized_path}"

    if [[ ! -d "$session_dir" ]]; then
        echo "Error: No Claude sessions found for project: $project_path" >&2
        echo "Expected directory: $session_dir" >&2
        exit 1
    fi

    # Find most recently modified JSONL file
    local latest_session
    latest_session=$(find "$session_dir" -name "*.jsonl" -type f -exec stat -f "%m %N" {} \; 2>/dev/null | sort -rn | head -1 | awk '{print $2}')

    if [[ -z "$latest_session" ]]; then
        echo "Error: No session files found in $session_dir" >&2
        exit 1
    fi

    echo "$latest_session"
}

analyze_session() {
    local session_file="$1"
    local detailed="${2:-false}"

    if [[ ! -f "$session_file" ]]; then
        echo "Error: Session file not found: $session_file" >&2
        exit 1
    fi

    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required but not installed" >&2
        echo "Install with: brew install jq" >&2
        exit 1
    fi

    # Extract session info
    local session_id
    session_id=$(basename "$session_file" .jsonl)

    local file_size
    file_size=$(du -h "$session_file" | awk '{print $1}')

    local message_count
    message_count=$(jq -s 'map(select(.type == "assistant" and .message.usage != null)) | length' "$session_file")

    # Calculate totals
    local totals
    totals=$(jq -s '
        map(select(.type == "assistant" and .message.usage != null) | .message.usage) |
        {
            input_tokens: (map(.input_tokens // 0) | add // 0),
            cache_read_tokens: (map(.cache_read_input_tokens // 0) | add // 0),
            cache_creation_tokens: (map(.cache_creation_input_tokens // 0) | add // 0),
            output_tokens: (map(.output_tokens // 0) | add // 0)
        } |
        .total = (.input_tokens + .cache_read_tokens + .cache_creation_tokens + .output_tokens)
    ' "$session_file")

    # Extract individual values
    local input_tokens cache_read cache_create output_tokens total_tokens
    input_tokens=$(echo "$totals" | jq -r '.input_tokens')
    cache_read=$(echo "$totals" | jq -r '.cache_read_tokens')
    cache_create=$(echo "$totals" | jq -r '.cache_creation_tokens')
    output_tokens=$(echo "$totals" | jq -r '.output_tokens')
    total_tokens=$(echo "$totals" | jq -r '.total')

    # Format numbers with commas
    input_tokens_fmt=$(printf "%'d" "$input_tokens")
    cache_read_fmt=$(printf "%'d" "$cache_read")
    cache_create_fmt=$(printf "%'d" "$cache_create")
    output_tokens_fmt=$(printf "%'d" "$output_tokens")
    total_tokens_fmt=$(printf "%'d" "$total_tokens")

    # Print results
    echo ""
    echo "=============================================="
    echo "  TOKEN USAGE ANALYSIS"
    echo "=============================================="
    echo ""
    echo "Session: $session_id"
    echo "File size: $file_size"
    echo "Messages analyzed: $message_count"
    echo ""
    echo "TOKEN BREAKDOWN:"
    echo "  Input tokens:           $input_tokens_fmt"
    echo "  Cache read tokens:      $cache_read_fmt"
    echo "  Cache creation tokens:  $cache_create_fmt"
    echo "  Output tokens:          $output_tokens_fmt"
    echo "  --------------------------------------"
    echo "  TOTAL:                  $total_tokens_fmt"
    echo ""

    # Calculate efficiency metrics
    if [[ $total_tokens -gt 0 ]]; then
        local cache_efficiency
        cache_efficiency=$(echo "scale=1; ($cache_read * 100) / $total_tokens" | bc)
        echo "EFFICIENCY:"
        echo "  Cache usage: ${cache_efficiency}%"
        echo ""
    fi

    # Detailed breakdown if requested
    if [[ "$detailed" == "true" ]]; then
        echo "=============================================="
        echo "  PER-MESSAGE BREAKDOWN"
        echo "=============================================="
        echo ""

        jq -r '
            select(.type == "assistant" and .message.usage != null) |
            "Message \(.message.id // "unknown"):
  Input: \(.message.usage.input_tokens // 0)
  Cache Read: \(.message.usage.cache_read_input_tokens // 0)
  Output: \(.message.usage.output_tokens // 0)
  Total: \((.message.usage.input_tokens // 0) + (.message.usage.cache_read_input_tokens // 0) + (.message.usage.output_tokens // 0))
"
        ' "$session_file"
        echo ""
    fi
}

# Main
main() {
    local session_file=""
    local detailed=false
    local use_latest=false
    local project_path=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                print_usage
                exit 0
                ;;
            --version|-v)
                echo "Token Tracker v${VERSION}"
                exit 0
                ;;
            --latest)
                use_latest=true
                shift
                ;;
            --detailed)
                detailed=true
                shift
                ;;
            *)
                if [[ -z "$session_file" ]]; then
                    session_file="$1"
                fi
                shift
                ;;
        esac
    done

    # Validate input
    if [[ -z "$session_file" ]]; then
        echo "Error: Session file or project path required" >&2
        echo ""
        print_usage
        exit 1
    fi

    # Handle --latest flag
    if [[ "$use_latest" == "true" ]]; then
        if [[ -f "$session_file" && "$session_file" =~ \.jsonl$ ]]; then
            echo "Error: --latest flag requires a project path, not a session file" >&2
            exit 1
        fi
        project_path="$session_file"
        session_file=$(find_latest_session "$project_path")
        echo "Latest session: $(basename "$session_file")"
    fi

    # Analyze session
    analyze_session "$session_file" "$detailed"
}

main "$@"
