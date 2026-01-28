#!/bin/bash
# Context Capsule Injection Script
# Injects capsule into system context with hash-based change detection
# Outputs JSON format for Claude Code compatibility

set -euo pipefail

CAPSULE_FILE=".claude/capsule.toon"
HASH_FILE=".claude/capsule.hash"

# Check if capsule exists
if [ ! -f "$CAPSULE_FILE" ]; then
  exit 0  # No capsule yet, skip injection
fi

# Calculate current capsule hash
CURRENT_HASH=$(md5 -q "$CAPSULE_FILE" 2>/dev/null || md5sum "$CAPSULE_FILE" 2>/dev/null | cut -d' ' -f1 || echo "unknown")

# Get message counts for periodic refresh
MESSAGE_COUNT=$(cat ".claude/message_count.txt" 2>/dev/null || echo "0")
LAST_INJECTION=$(cat ".claude/last_capsule_injection.txt" 2>/dev/null || echo "0")
MESSAGES_SINCE=$((MESSAGE_COUNT - LAST_INJECTION))

# Decide whether to inject capsule
SHOULD_INJECT=false

# Condition 1: Hash changed (content updated)
if [ -f "$HASH_FILE" ]; then
  LAST_HASH=$(cat "$HASH_FILE")
  if [ "$CURRENT_HASH" != "$LAST_HASH" ]; then
    SHOULD_INJECT=true
  fi
else
  SHOULD_INJECT=true  # First run
fi

# Condition 2: 20+ messages since last injection (periodic refresh)
if [ "$MESSAGES_SINCE" -ge 20 ]; then
  SHOULD_INJECT=true
fi

# Exit early if neither condition met
if [ "$SHOULD_INJECT" = false ]; then
  exit 0
fi

# Initialize JSON arrays
GIT_JSON=""
FILES_JSON="[]"
TASKS_JSON="[]"
SUBAGENTS_JSON="[]"
DISCOVERIES_JSON="[]"
META_JSON=""
SECTION=""

# Helper function to escape JSON strings
escape_json() {
  echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | tr -d '\n'
}

# Helper function to format age
format_age() {
  local AGE=$1
  if [ "$AGE" -lt 60 ]; then
    echo "${AGE}s ago"
  elif [ "$AGE" -lt 3600 ]; then
    echo "$((AGE / 60))m ago"
  else
    echo "$((AGE / 3600))h ago"
  fi
}

# Parse capsule file
while IFS= read -r line; do
  [ -z "$line" ] && continue

  # Parse section headers
  if echo "$line" | grep -q "^[A-Z][A-Z]*{"; then
    SECTION=$(echo "$line" | cut -d'{' -f1)
    continue
  fi

  # Parse data rows
  if echo "$line" | grep -q "^ "; then
    DATA=$(echo "$line" | sed 's/^ //')

    if [ -n "$SECTION" ]; then
      case "$SECTION" in
        "GIT")
          BRANCH=$(echo "$DATA" | cut -d',' -f1)
          HEAD=$(echo "$DATA" | cut -d',' -f2)
          DIRTY=$(echo "$DATA" | cut -d',' -f3)
          AHEAD=$(echo "$DATA" | cut -d',' -f4)
          BEHIND=$(echo "$DATA" | cut -d',' -f5)
          GIT_JSON="{\"branch\":\"$(escape_json "$BRANCH")\",\"head\":\"$HEAD\",\"dirtyFiles\":$DIRTY,\"ahead\":$AHEAD,\"behind\":$BEHIND}"
          ;;
        "FILES")
          PATH_NAME=$(echo "$DATA" | cut -d',' -f1)
          ACTION=$(echo "$DATA" | cut -d',' -f2)
          AGE=$(echo "$DATA" | cut -d',' -f3)
          AGE_STR=$(format_age "$AGE")
          FILE_OBJ="{\"path\":\"$(escape_json "$PATH_NAME")\",\"action\":\"$ACTION\",\"age\":\"$AGE_STR\"}"
          if [ "$FILES_JSON" = "[]" ]; then
            FILES_JSON="[$FILE_OBJ"
          else
            FILES_JSON="$FILES_JSON,$FILE_OBJ"
          fi
          ;;
        "TASK")
          STATUS=$(echo "$DATA" | cut -d',' -f1)
          CONTENT=$(echo "$DATA" | cut -d',' -f2-)
          TASK_OBJ="{\"status\":\"$STATUS\",\"content\":\"$(escape_json "$CONTENT")\"}"
          if [ "$TASKS_JSON" = "[]" ]; then
            TASKS_JSON="[$TASK_OBJ"
          else
            TASKS_JSON="$TASKS_JSON,$TASK_OBJ"
          fi
          ;;
        "SUBAGENT")
          AGE=$(echo "$DATA" | cut -d',' -f1)
          TYPE=$(echo "$DATA" | cut -d',' -f2)
          SUMMARY=$(echo "$DATA" | cut -d',' -f3-)
          AGE_STR=$(format_age "$AGE")
          SUB_OBJ="{\"type\":\"$TYPE\",\"age\":\"$AGE_STR\",\"summary\":\"$(escape_json "$SUMMARY")\"}"
          if [ "$SUBAGENTS_JSON" = "[]" ]; then
            SUBAGENTS_JSON="[$SUB_OBJ"
          else
            SUBAGENTS_JSON="$SUBAGENTS_JSON,$SUB_OBJ"
          fi
          ;;
        "DISCOVERY")
          AGE=$(echo "$DATA" | cut -d',' -f1)
          CATEGORY=$(echo "$DATA" | cut -d',' -f2)
          CONTENT=$(echo "$DATA" | cut -d',' -f3-)
          AGE_STR=$(format_age "$AGE")
          DISC_OBJ="{\"category\":\"$CATEGORY\",\"age\":\"$AGE_STR\",\"content\":\"$(escape_json "$CONTENT")\"}"
          if [ "$DISCOVERIES_JSON" = "[]" ]; then
            DISCOVERIES_JSON="[$DISC_OBJ"
          else
            DISCOVERIES_JSON="$DISCOVERIES_JSON,$DISC_OBJ"
          fi
          ;;
        "META")
          MESSAGES=$(echo "$DATA" | cut -d',' -f1)
          DURATION=$(echo "$DATA" | cut -d',' -f2)
          if [ "$DURATION" -lt 60 ]; then
            DUR_STR="${DURATION}s"
          elif [ "$DURATION" -lt 3600 ]; then
            DUR_STR="$((DURATION / 60))m"
          else
            DUR_STR="$((DURATION / 3600))h $((DURATION % 3600 / 60))m"
          fi
          META_JSON="{\"messages\":$MESSAGES,\"duration\":\"$DUR_STR\"}"
          ;;
      esac
    fi
  fi
done < "$CAPSULE_FILE"

# Close JSON arrays that were opened
[ "$FILES_JSON" != "[]" ] && FILES_JSON="$FILES_JSON]"
[ "$TASKS_JSON" != "[]" ] && TASKS_JSON="$TASKS_JSON]"
[ "$SUBAGENTS_JSON" != "[]" ] && SUBAGENTS_JSON="$SUBAGENTS_JSON]"
[ "$DISCOVERIES_JSON" != "[]" ] && DISCOVERIES_JSON="$DISCOVERIES_JSON]"

# Build final capsule JSON
echo -n "{\"capsule\":{\"updated\":true"
[ -n "$GIT_JSON" ] && echo -n ",\"git\":$GIT_JSON"
[ "$FILES_JSON" != "[]" ] && echo -n ",\"files\":$FILES_JSON"
[ "$TASKS_JSON" != "[]" ] && echo -n ",\"tasks\":$TASKS_JSON"
[ "$SUBAGENTS_JSON" != "[]" ] && echo -n ",\"subagents\":$SUBAGENTS_JSON"
[ "$DISCOVERIES_JSON" != "[]" ] && echo -n ",\"discoveries\":$DISCOVERIES_JSON"
[ -n "$META_JSON" ] && echo -n ",\"meta\":$META_JSON"
echo "},\"reminder\":\"Capsule contains session state - check before redundant operations\"}"

# Save hash and message count for next comparison
echo "$CURRENT_HASH" > "$HASH_FILE"
echo "$MESSAGE_COUNT" > ".claude/last_capsule_injection.txt"
