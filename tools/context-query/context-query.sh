#!/bin/bash
# Context-Query Tool - Bash wrapper for global CCK
# Queries Blink context database
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec node "$SCRIPT_DIR/context-query.js" "$@"
