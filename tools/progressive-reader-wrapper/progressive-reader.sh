#!/bin/bash
# Progressive Reader Tool Wrapper
# Calls the installed progressive-reader binary

PROGRESSIVE_READER="$HOME/.claude/bin/progressive-reader"

if [ ! -f "$PROGRESSIVE_READER" ]; then
  echo "Error: Progressive Reader not installed"
  echo "Run: cd tools/progressive-reader && ./install.sh"
  exit 1
fi

# Pass all arguments to the binary
exec "$PROGRESSIVE_READER" "$@"
