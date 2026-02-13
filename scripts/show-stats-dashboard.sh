#!/bin/bash
# Stats Dashboard with Visual Progress Bars (v3 - uses capsule.db)

# In v3, capsule.db is always at the global location
CAPSULE="$HOME/.claude/capsule.db"

# Colors
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

echo ""
echo -e "${BOLD}Claude Capsule Kit - Session Stats${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Count files
FILE_COUNT=$(awk '/^FILES\{/,/^$/ {if ($0 ~ /^ /) count++} END {print count+0}' "$CAPSULE" 2>/dev/null || echo "0")
echo -e "  ${BLUE}📁 Files Tracked:${RESET} ${FILE_COUNT}"

# Count tasks by status
TASK_TOTAL=$(awk '/^TASK\{/,/^$/ {if ($0 ~ /^ /) count++} END {print count+0}' "$CAPSULE" 2>/dev/null || echo "0")
TASK_ACTIVE=$(awk -F',' '/^TASK\{/,/^$/ {if ($0 ~ /^ / && $1 ~ /in_progress/) count++} END {print count+0}' "$CAPSULE" 2>/dev/null || echo "0")
TASK_PENDING=$(awk -F',' '/^TASK\{/,/^$/ {if ($0 ~ /^ / && $1 ~ /pending/) count++} END {print count+0}' "$CAPSULE" 2>/dev/null || echo "0")
TASK_DONE=$(awk -F',' '/^TASK\{/,/^$/ {if ($0 ~ /^ / && $1 ~ /completed/) count++} END {print count+0}' "$CAPSULE" 2>/dev/null || echo "0")

if [ "$TASK_TOTAL" -gt 0 ]; then
  echo -e "  ${YELLOW}✓ Tasks:${RESET} ${TASK_TOTAL} (${TASK_ACTIVE} active, ${TASK_PENDING} pending, ${TASK_DONE} done)"
else
  echo -e "  ${YELLOW}✓ Tasks:${RESET} ${TASK_TOTAL}"
fi

# Session duration
DURATION=$(awk -F',' '/^META\{/,/^$/ {if ($0 ~ /^ /) {print $2; exit}}' "$CAPSULE" 2>/dev/null || echo "0")
if [ "$DURATION" -lt 60 ]; then
  DUR_STR="${DURATION}s"
elif [ "$DURATION" -lt 3600 ]; then
  DUR_STR="$((DURATION / 60))m"
else
  DUR_STR="$((DURATION / 3600))h $((DURATION % 3600 / 60))m"
fi
echo -e "  ${CYAN}⏱  Session Duration:${RESET} ${DUR_STR}"

echo ""
echo -e "  ${GREEN}Context:${RESET} ${FILE_COUNT} files in capsule (not re-read)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
