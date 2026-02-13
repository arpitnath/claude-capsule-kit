#!/bin/bash
# Visual Capsule Display (v3 - uses capsule.db)
# Shows current session state with colors and formatting

# In v3, capsule.db is always at the global location
CAPSULE_FILE="$HOME/.claude/capsule.db"

if [ ! -f "$CAPSULE_FILE" ]; then
  echo "No capsule found"
  exit 1
fi

# Colors
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
RESET='\033[0m'

echo ""
echo -e "${BOLD}╔════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║     Claude Capsule Kit - Context Capsule                 ║${RESET}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Parse capsule sections
SECTION=""
while IFS= read -r line; do
  # Detect section headers
  if echo "$line" | grep -q "^GIT{"; then
    SECTION="GIT"
    echo -e "${BLUE}├─ Git State${RESET}"
    continue
  elif echo "$line" | grep -q "^FILES{"; then
    SECTION="FILES"
    echo ""
    echo -e "${GREEN}├─ Files in Context${RESET}"
    continue
  elif echo "$line" | grep -q "^TASK{"; then
    SECTION="TASKS"
    echo ""
    echo -e "${YELLOW}├─ Current Tasks${RESET}"
    continue
  elif echo "$line" | grep -q "^META{"; then
    SECTION="META"
    echo ""
    echo -e "${CYAN}└─ Session Info${RESET}"
    continue
  fi
  
  # Parse data rows
  if echo "$line" | grep -q "^ "; then
    DATA=$(echo "$line" | sed 's/^ //')
    
    case "$SECTION" in
      "GIT")
        BRANCH=$(echo "$DATA" | cut -d',' -f1)
        HEAD=$(echo "$DATA" | cut -d',' -f2)
        DIRTY=$(echo "$DATA" | cut -d',' -f3)
        echo -e "   ${GRAY}Branch:${RESET} ${BRANCH} ${GRAY}(${HEAD})${RESET}"
        [ "$DIRTY" != "0" ] && echo -e "   ${YELLOW}Modified files:${RESET} ${DIRTY}"
        ;;
      "FILES")
        PATH=$(echo "$DATA" | cut -d',' -f1)
        ACTION=$(echo "$DATA" | cut -d',' -f2)
        AGE=$(echo "$DATA" | cut -d',' -f3)
        
        AGE_SEC=$(echo "$AGE")
        if [ "$AGE_SEC" -lt 60 ]; then
          AGE_STR="${AGE_SEC}s ago"
        elif [ "$AGE_SEC" -lt 3600 ]; then
          AGE_STR="$((AGE_SEC / 60))m ago"
        else
          AGE_STR="$((AGE_SEC / 3600))h ago"
        fi
        
        ACTION_ICON="📄"
        [ "$ACTION" = "edit" ] && ACTION_ICON="✏️ "
        [ "$ACTION" = "write" ] && ACTION_ICON="➕"
        
        echo -e "   ${ACTION_ICON} ${PATH} ${GRAY}(${AGE_STR})${RESET}"
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
        
        echo -e "   ${GRAY}Messages:${RESET} ${MESSAGES}  ${GRAY}Duration:${RESET} ${DUR_STR}"
        ;;
    esac
  fi
done < "$CAPSULE_FILE"

echo ""
