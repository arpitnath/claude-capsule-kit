#!/usr/bin/env bash
# Context-Query Tool v3.0 - Blink context database CRUD
# Usage: bash .claude/tools/context-query/context-query.sh <command> [args]

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find project root with .claude directory (walk-up)
PROJECT_ROOT=""
DIR="$PWD"
while [ "$DIR" != "/" ]; do
  if [ -d "$DIR/.claude" ]; then
    PROJECT_ROOT="$DIR"
    break
  fi
  DIR=$(dirname "$DIR")
done

if [ -z "$PROJECT_ROOT" ]; then
  echo "Error: No .claude directory found"
  exit 1
fi

# Run the Node.js query tool from the project root
# Node resolves blink-query from .claude/node_modules/
cd "$PROJECT_ROOT"
exec node "$SCRIPT_DIR/context-query.js" "$@"
