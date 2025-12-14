#!/bin/bash
# Session Sync Configuration Loader
# Source this file to get sync settings

# Config file location
SYNC_CONFIG_FILE=".claude/sync-config.json"

# Default values
SYNC_ENABLED="false"
SYNC_REPO=""
SYNC_INCLUDE_TRANSCRIPT="false"

# Load config if exists
if [ -f "$SYNC_CONFIG_FILE" ]; then
    SYNC_ENABLED=$(python3 -c "import json; print(json.load(open('$SYNC_CONFIG_FILE')).get('enabled', False))" 2>/dev/null || echo "false")
    SYNC_REPO=$(python3 -c "import json; print(json.load(open('$SYNC_CONFIG_FILE')).get('repo', ''))" 2>/dev/null || echo "")
    SYNC_INCLUDE_TRANSCRIPT=$(python3 -c "import json; print(json.load(open('$SYNC_CONFIG_FILE')).get('include_transcript', False))" 2>/dev/null || echo "false")
fi

# Normalize boolean values
if [ "$SYNC_ENABLED" = "True" ] || [ "$SYNC_ENABLED" = "true" ]; then
    SYNC_ENABLED="true"
else
    SYNC_ENABLED="false"
fi

if [ "$SYNC_INCLUDE_TRANSCRIPT" = "True" ] || [ "$SYNC_INCLUDE_TRANSCRIPT" = "true" ]; then
    SYNC_INCLUDE_TRANSCRIPT="true"
else
    SYNC_INCLUDE_TRANSCRIPT="false"
fi

# Export for use in other scripts
export SYNC_ENABLED SYNC_REPO SYNC_INCLUDE_TRANSCRIPT SYNC_CONFIG_FILE
