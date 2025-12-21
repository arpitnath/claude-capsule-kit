#!/usr/bin/env bash
# Audit logger - logs tool executions with timestamps and outcomes
# Tracks tool runs, permission checks, and hook executions

set -euo pipefail

AUDIT_LOG="${AUDIT_LOG:-$HOME/.claude/audit.log}"

mkdir -p "$(dirname "$AUDIT_LOG")"

log_tool_execution() {
    local tool_name="$1"
    local operation="$2"
    local status="$3"
    local details="${4:-}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local log_entry="[$timestamp] TOOL=$tool_name OPERATION=$operation STATUS=$status"

    if [ -n "$details" ]; then
        log_entry="$log_entry DETAILS=$details"
    fi

    echo "$log_entry" >> "$AUDIT_LOG"
}

log_permission_check() {
    local tool_name="$1"
    local permission_type="$2"
    local target="$3"
    local result="$4"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local log_entry="[$timestamp] PERMISSION_CHECK TOOL=$tool_name TYPE=$permission_type TARGET=$target RESULT=$result"

    echo "$log_entry" >> "$AUDIT_LOG"
}

log_hook_execution() {
    local hook_name="$1"
    local status="$2"
    local duration="${3:-}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local log_entry="[$timestamp] HOOK=$hook_name STATUS=$status"

    if [ -n "$duration" ]; then
        log_entry="$log_entry DURATION=${duration}ms"
    fi

    echo "$log_entry" >> "$AUDIT_LOG"
}

query_audit_log() {
    local filter="${1:-}"
    local limit="${2:-100}"

    if [ ! -f "$AUDIT_LOG" ]; then
        echo "No audit log found at: $AUDIT_LOG" >&2
        return 1
    fi

    if [ -z "$filter" ]; then
        tail -n "$limit" "$AUDIT_LOG"
    else
        grep "$filter" "$AUDIT_LOG" | tail -n "$limit"
    fi
}

get_audit_stats() {
    if [ ! -f "$AUDIT_LOG" ]; then
        echo "No audit log found" >&2
        return 1
    fi

    echo "Claude Capsule Kit - Audit Log Statistics"
    echo ""

    local total_entries=$(wc -l < "$AUDIT_LOG")
    echo "Total entries: $total_entries"
    echo ""

    echo "Tool executions:"
    grep "TOOL=" "$AUDIT_LOG" | grep -o "TOOL=[^ ]*" | sort | uniq -c | sort -rn | head -10

    echo ""
    echo "Permission checks:"
    grep "PERMISSION_CHECK" "$AUDIT_LOG" | grep -o "RESULT=[^ ]*" | sort | uniq -c

    echo ""
    echo "Hook executions:"
    grep "HOOK=" "$AUDIT_LOG" | grep -o "HOOK=[^ ]*" | sort | uniq -c | sort -rn | head -10
    echo ""
}

rotate_audit_log() {
    if [ ! -f "$AUDIT_LOG" ]; then
        return 0
    fi

    local file_size=$(stat -f%z "$AUDIT_LOG" 2>/dev/null || stat -c%s "$AUDIT_LOG" 2>/dev/null || echo "0")
    local max_size=$((10 * 1024 * 1024))

    if [ "$file_size" -gt "$max_size" ]; then
        local timestamp=$(date +"%Y%m%d-%H%M%S")
        mv "$AUDIT_LOG" "${AUDIT_LOG}.${timestamp}"
        gzip "${AUDIT_LOG}.${timestamp}" &
        touch "$AUDIT_LOG"
        echo "Audit log rotated to: ${AUDIT_LOG}.${timestamp}.gz"
    fi
}

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f log_tool_execution
    export -f log_permission_check
    export -f log_hook_execution
    export -f query_audit_log
    export -f get_audit_stats
    export -f rotate_audit_log
fi
