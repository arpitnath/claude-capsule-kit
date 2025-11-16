#!/bin/bash
# Context Capsule Injection Script
# Injects capsule into system context with hash-based change detection

set -euo pipefail

CAPSULE_FILE=".claude/capsule.toon"
HASH_FILE=".claude/capsule.hash"

# Check if capsule exists
if [ ! -f "$CAPSULE_FILE" ]; then
  exit 0  # No capsule yet, skip injection
fi

# Calculate current capsule hash
CURRENT_HASH=$(md5 -q "$CAPSULE_FILE" 2>/dev/null || md5sum "$CAPSULE_FILE" 2>/dev/null | cut -d' ' -f1 || echo "unknown")

# Check if capsule changed since last injection
if [ -f "$HASH_FILE" ]; then
  LAST_HASH=$(cat "$HASH_FILE")
  if [ "$CURRENT_HASH" = "$LAST_HASH" ]; then
    # Capsule unchanged, skip injection
    exit 0
  fi
fi

# Capsule changed or first injection - display it
echo ""
echo "<context-capsule updated=\"true\">"

# Parse and display capsule sections in human-readable format
while IFS= read -r line; do
  # Skip empty lines
  [ -z "$line" ] && continue

  # Parse section headers
  if echo "$line" | grep -q "^[A-Z][A-Z]*{"; then
    SECTION=$(echo "$line" | cut -d'{' -f1)
    echo ""

    case "$SECTION" in
      "GIT")
        echo "<git-state>"
        ;;
      "FILES")
        echo "<files-in-context>"
        ;;
      "TASK")
        echo "<current-tasks>"
        ;;
      "SUBAGENT")
        echo "<subagent-results>"
        ;;
      "DISCOVERY")
        echo "<session-discoveries>"
        ;;
      "META")
        echo "<session-meta>"
        ;;
    esac
    continue
  fi

  # Parse data rows (skip header line with field names)
  if echo "$line" | grep -q "^ "; then
    # This is a data row, parse it
    DATA=$(echo "$line" | sed 's/^ //')

    # Format based on context
    if [ -n "$SECTION" ]; then
      case "$SECTION" in
        "GIT")
          # branch,head,dirty_count,ahead,behind
          BRANCH=$(echo "$DATA" | cut -d',' -f1)
          HEAD=$(echo "$DATA" | cut -d',' -f2)
          DIRTY=$(echo "$DATA" | cut -d',' -f3)
          AHEAD=$(echo "$DATA" | cut -d',' -f4)
          BEHIND=$(echo "$DATA" | cut -d',' -f5)
          echo "  <branch>$BRANCH</branch> <head>$HEAD</head>"
          [ "$DIRTY" != "0" ] && echo "  <dirty-files count=\"$DIRTY\"/>"
          [ "$AHEAD" != "0" ] && echo "  <ahead count=\"$AHEAD\"/>"
          [ "$BEHIND" != "0" ] && echo "  <behind count=\"$BEHIND\"/>"
          ;;
        "FILES")
          # path,action,age_seconds
          PATH_NAME=$(echo "$DATA" | cut -d',' -f1)
          ACTION=$(echo "$DATA" | cut -d',' -f2)
          AGE=$(echo "$DATA" | cut -d',' -f3)

          # Convert age to human readable
          if [ "$AGE" -lt 60 ]; then
            AGE_STR="${AGE}s ago"
          elif [ "$AGE" -lt 3600 ]; then
            AGE_STR="$((AGE / 60))m ago"
          else
            AGE_STR="$((AGE / 3600))h ago"
          fi

          echo "  <file path=\"$PATH_NAME\" action=\"$ACTION\" age=\"$AGE_STR\"/>"
          ;;
        "TASK")
          # status,content
          STATUS=$(echo "$DATA" | cut -d',' -f1)
          CONTENT=$(echo "$DATA" | cut -d',' -f2-)

          echo "  <task status=\"$STATUS\">$CONTENT</task>"
          ;;
        "SUBAGENT")
          # age_seconds,type,summary
          AGE=$(echo "$DATA" | cut -d',' -f1)
          TYPE=$(echo "$DATA" | cut -d',' -f2)
          SUMMARY=$(echo "$DATA" | cut -d',' -f3-)

          # Convert age to human readable
          if [ "$AGE" -lt 60 ]; then
            AGE_STR="${AGE}s ago"
          elif [ "$AGE" -lt 3600 ]; then
            AGE_STR="$((AGE / 60))m ago"
          else
            AGE_STR="$((AGE / 3600))h ago"
          fi

          echo "  <subagent type=\"$TYPE\" age=\"$AGE_STR\">$SUMMARY</subagent>"
          ;;
        "DISCOVERY")
          # age_seconds,category,content
          AGE=$(echo "$DATA" | cut -d',' -f1)
          CATEGORY=$(echo "$DATA" | cut -d',' -f2)
          CONTENT=$(echo "$DATA" | cut -d',' -f3-)

          # Convert age to human readable
          if [ "$AGE" -lt 60 ]; then
            AGE_STR="${AGE}s ago"
          elif [ "$AGE" -lt 3600 ]; then
            AGE_STR="$((AGE / 60))m ago"
          else
            AGE_STR="$((AGE / 3600))h ago"
          fi

          echo "  <discovery category=\"$CATEGORY\" age=\"$AGE_STR\">$CONTENT</discovery>"
          ;;
        "META")
          # messages,duration_seconds,updated_at
          MESSAGES=$(echo "$DATA" | cut -d',' -f1)
          DURATION=$(echo "$DATA" | cut -d',' -f2)
          UPDATED=$(echo "$DATA" | cut -d',' -f3)

          # Convert duration to human readable
          if [ "$DURATION" -lt 60 ]; then
            DUR_STR="${DURATION}s"
          elif [ "$DURATION" -lt 3600 ]; then
            DUR_STR="$((DURATION / 60))m"
          else
            DUR_STR="$((DURATION / 3600))h $((DURATION % 3600 / 60))m"
          fi

          echo "  <messages>$MESSAGES</messages> <duration>$DUR_STR</duration>"
          ;;
      esac
    fi
  fi
done < "$CAPSULE_FILE"

echo "</context-capsule>"
echo ""
echo "<reminder>Capsule contains session state - check before redundant operations</reminder>"
echo ""

# Save hash for next comparison
echo "$CURRENT_HASH" > "$HASH_FILE"
