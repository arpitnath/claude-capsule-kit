#!/bin/bash
# Stats Tool - Bash wrapper for global CCK
# Queries Capsule for usage analytics
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec node "$SCRIPT_DIR/stats.js" "$@"
