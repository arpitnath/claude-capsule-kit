#!/bin/bash
# Dependency Tree Visualization (v3 - uses query-deps tool)
# Shows file dependencies in tree format with colors

FILE="${1:-}"

if [ -z "$FILE" ]; then
  echo "Usage: show-deps-tree.sh <file-path>"
  exit 1
fi

# In v3, use the query-deps tool instead of dep-graph.toon
QUERY_DEPS_TOOL="$HOME/.claude/cck/tools/query-deps/query-deps.sh"

if [ ! -f "$QUERY_DEPS_TOOL" ]; then
  echo "query-deps tool not found at $QUERY_DEPS_TOOL"
  echo "Make sure CCK v3 is installed: npm install -g claude-capsule-kit && cck setup"
  exit 1
fi

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
GRAY='\033[0;90m'
RED='\033[0;31m'
RESET='\033[0m'

echo ""
echo -e "${BLUE}${FILE}${RESET} dependency tree:"
echo ""

# Get imports for this file
source .claude/lib/toon-parser.sh
IMPORTS=$(toon_get_imports "$DEP_GRAPH" "$FILE")

if [ -z "$IMPORTS" ]; then
  echo -e "${GRAY}  (no imports)${RESET}"
else
  echo "$IMPORTS" | while read -r import_file; do
    echo -e "  ${GREEN}├─→${RESET} ${import_file}"
  done
fi

echo ""

# Get files that import THIS file  
IMPORTERS=$(toon_get_importers "$DEP_GRAPH" "$FILE")
IMPORTER_COUNT=$(echo "$IMPORTERS" | /usr/bin/grep -c . 2>/dev/null | tr -d '\n' || echo "0")
IMPORTER_COUNT=${IMPORTER_COUNT//[^0-9]/}  # Remove non-digits
IMPORTER_COUNT=${IMPORTER_COUNT:-0}        # Default to 0 if empty

if [ "$IMPORTER_COUNT" -gt 0 ]; then
  echo -e "${YELLOW}Files depending on ${FILE}:${RESET} ${IMPORTER_COUNT}"
  echo ""
  
  echo "$IMPORTERS" | head -10 | while read -r importer; do
    echo -e "  ${RED}◀─┤${RESET} ${importer}"
  done
  
  if [ "$IMPORTER_COUNT" -gt 10 ]; then
    echo -e "  ${GRAY}... and $((IMPORTER_COUNT - 10)) more${RESET}"
  fi
fi

echo ""
