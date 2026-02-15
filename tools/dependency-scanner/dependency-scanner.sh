#!/bin/bash
# Dependency Scanner Wrapper
# Rebuilds the dependency graph for current project

set -euo pipefail

# Find .claude directory by searching parent directories
find_claude_dir() {
  local current_dir="$PWD"
  while [ "$current_dir" != "/" ]; do
    if [ -d "$current_dir/.claude" ]; then
      echo "$current_dir/.claude"
      return 0
    fi
    current_dir=$(dirname "$current_dir")
  done
  echo ".claude"
  return 1
}

CLAUDE_DIR=$(find_claude_dir)

# Check if dependency-scanner binary exists
if [ ! -x "${HOME}/.claude/bin/dependency-scanner" ]; then
  echo "Error: dependency-scanner binary not found at ~/.claude/bin/dependency-scanner"
  echo "Run installation to build it."
  exit 1
fi

echo "Building dependency graph..."
echo ""

# Run the scanner
"${HOME}/.claude/bin/dependency-scanner" \
  --output "${CLAUDE_DIR}/dep-graph.toon" \
  --languages typescript,javascript,python,go \
  . 2>&1

if [ -f "${CLAUDE_DIR}/dep-graph.toon" ]; then
  FILE_COUNT=$(grep -c "^FILE{" "${CLAUDE_DIR}/dep-graph.toon" || echo "0")
  echo ""
  echo "✓ Dependency graph built successfully"
  echo "  Files analyzed: ${FILE_COUNT}"
  echo "  Graph saved to: ${CLAUDE_DIR}/dep-graph.toon"
  echo ""
  echo "Query with:"
  echo "  bash $HOME/.claude/cck/tools/query-deps/query-deps.sh <file>"
  echo "  bash $HOME/.claude/cck/tools/find-circular/find-circular.sh"
  echo "  bash $HOME/.claude/cck/tools/find-dead-code/find-dead-code.sh"
else
  echo "Error: Failed to create dependency graph"
  exit 1
fi
