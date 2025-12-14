#!/bin/bash
# Push Session to GitHub
# Called by session-end.sh in background
# Syncs session state to GitHub for cross-device continuation

set -euo pipefail

# Defensive check: Ensure CWD exists
if ! cd "$(pwd 2>/dev/null)" 2>/dev/null; then
    exit 0
fi

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration
if [ -f "$SCRIPT_DIR/sync-config.sh" ]; then
    source "$SCRIPT_DIR/sync-config.sh"
elif [ -f ".claude/scripts/sync-config.sh" ]; then
    source ".claude/scripts/sync-config.sh"
else
    exit 0
fi

# Exit if sync disabled
if [ "$SYNC_ENABLED" != "true" ]; then
    exit 0
fi

# Check gh CLI
if ! command -v gh &>/dev/null; then
    echo "[SYNC] gh CLI not found, skipping" >&2
    exit 0
fi

# Check auth
if ! gh auth status &>/dev/null 2>&1; then
    echo "[SYNC] gh not authenticated, skipping" >&2
    exit 0
fi

# Check repo configured
if [ -z "$SYNC_REPO" ]; then
    echo "[SYNC] No repo configured, skipping" >&2
    exit 0
fi

# Determine project name
PROJECT_NAME=$(basename "$(pwd)")

# Get session ID from memory or generate
SESSION_ID=""
if [ -f ".claude/session_start.txt" ]; then
    SESSION_ID=$(cat ".claude/session_start.txt" 2>/dev/null || echo "")
fi
if [ -z "$SESSION_ID" ]; then
    SESSION_ID=$(date +%s)
fi

# Check if this is a continuation (session already synced)
EXISTING_PATH=""
if [ -f "$SYNC_CONFIG_FILE" ]; then
    EXISTING_PATH=$(python3 -c "
import json
try:
    data = json.load(open('$SYNC_CONFIG_FILE'))
    session_map = data.get('session_id_map', {})
    print(session_map.get('$SESSION_ID', ''))
except:
    print('')
" 2>/dev/null || echo "")
fi

# Determine target path
TODAY=$(date +%Y-%m-%d)
if [ -n "$EXISTING_PATH" ]; then
    TARGET_PATH="$EXISTING_PATH"
    COMMIT_MSG="sync: session update ($TODAY)"
    IS_UPDATE="true"
else
    TARGET_PATH="sessions/$PROJECT_NAME/$TODAY-${SESSION_ID:0:8}"
    COMMIT_MSG="sync: new session ($TODAY)"
    IS_UPDATE="false"
fi

# Check for AI-generated summary first (from Stop hook)
AI_SUMMARY=""
if [ -f ".claude/session-summary.md" ]; then
    AI_SUMMARY=$(cat ".claude/session-summary.md" 2>/dev/null || echo "")
fi

# Use AI summary if available, otherwise generate from logs
if [ -n "$AI_SUMMARY" ]; then
    SUMMARY_CONTENT="$AI_SUMMARY"
    echo "[SYNC] Using AI-generated summary" >&2
else
    echo "[SYNC] Generating log-based summary" >&2
    # Build summary content from logs
    SUMMARY_CONTENT=$(python3 << 'PYTHON_SCRIPT'
import json
import os
from datetime import datetime

# Gather session data
data = {
    "project": os.path.basename(os.getcwd()),
    "date": datetime.now().strftime("%Y-%m-%d %H:%M"),
    "tasks": [],
    "files": [],
    "discoveries": [],
    "duration": "unknown"
}

# Read tasks
if os.path.exists(".claude/current_tasks.log"):
    with open(".claude/current_tasks.log") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split("|", 1)
            if len(parts) == 2:
                data["tasks"].append({"status": parts[0], "content": parts[1]})

# Read recent files (deduplicated, last 15)
if os.path.exists(".claude/session_files.log"):
    seen = set()
    files_list = []
    with open(".claude/session_files.log") as f:
        for line in f:
            parts = line.strip().split(",")
            if len(parts) >= 2:
                path = parts[0].strip().strip('"')
                if path and path not in seen:
                    seen.add(path)
                    files_list.append(path)
    data["files"] = files_list[-15:]  # Last 15

# Read discoveries
if os.path.exists(".claude/session_discoveries.log"):
    with open(".claude/session_discoveries.log") as f:
        for line in f:
            parts = line.strip().split(",", 2)
            if len(parts) >= 3:
                data["discoveries"].append({
                    "category": parts[1].strip().strip('"'),
                    "insight": parts[2].strip().strip('"')
                })

# Calculate duration
if os.path.exists(".claude/session_start.txt"):
    try:
        with open(".claude/session_start.txt") as f:
            start = int(f.read().strip())
            duration_secs = int(datetime.now().timestamp()) - start
            if duration_secs < 60:
                data["duration"] = f"{duration_secs}s"
            elif duration_secs < 3600:
                data["duration"] = f"{duration_secs // 60}m"
            else:
                hours = duration_secs // 3600
                mins = (duration_secs % 3600) // 60
                data["duration"] = f"{hours}h {mins}m"
    except:
        pass

# Generate markdown
md = f"""# Session: {data['project']}

**Date**: {data['date']}
**Duration**: {data['duration']}

## Summary

This session was synced from Claude Code for continuation in Claude Web/Desktop/Mobile.

## Tasks

"""

# Completed tasks first
completed = [t for t in data["tasks"] if t["status"] == "completed"]
in_progress = [t for t in data["tasks"] if t["status"] == "in_progress"]
pending = [t for t in data["tasks"] if t["status"] == "pending"]

if completed:
    for task in completed:
        md += f"- [x] {task['content']}\n"

if in_progress:
    md += "\n**In Progress:**\n"
    for task in in_progress:
        md += f"- [ ] {task['content']} *(in progress)*\n"

if pending:
    md += "\n**Pending:**\n"
    for task in pending:
        md += f"- [ ] {task['content']}\n"

if not data["tasks"]:
    md += "(No tasks tracked this session)\n"

md += "\n## Files Accessed\n\n"
if data["files"]:
    for f in data["files"]:
        md += f"- `{f}`\n"
else:
    md += "(No files tracked)\n"

if data["discoveries"]:
    md += "\n## Discoveries\n\n"
    for d in data["discoveries"]:
        md += f"- **{d['category']}**: {d['insight']}\n"

md += """
---

*Synced via [Super Claude Kit](https://github.com/arpitnath/super-claude-kit) Session Sync*
"""

print(md)
PYTHON_SCRIPT
)
fi

# Build metadata
METADATA=$(python3 << PYTHON_META
import json
from datetime import datetime
import os

metadata = {
    "session_id": "$SESSION_ID",
    "project": "$PROJECT_NAME",
    "synced_at": datetime.utcnow().isoformat() + "Z",
    "is_update": $( [ "$IS_UPDATE" = "true" ] && echo "True" || echo "False" )
}

# Count activities
try:
    if os.path.exists(".claude/session_files.log"):
        with open(".claude/session_files.log") as f:
            metadata["files_count"] = sum(1 for _ in f)
except:
    pass

try:
    if os.path.exists(".claude/session_discoveries.log"):
        with open(".claude/session_discoveries.log") as f:
            metadata["discoveries_count"] = sum(1 for _ in f)
except:
    pass

print(json.dumps(metadata, indent=2))
PYTHON_META
)

# Get existing SHA if updating
SUMMARY_SHA=""
METADATA_SHA=""
if [ "$IS_UPDATE" = "true" ]; then
    SUMMARY_SHA=$(gh api "repos/$SYNC_REPO/contents/$TARGET_PATH/summary.md" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('sha',''))" 2>/dev/null || echo "")
    METADATA_SHA=$(gh api "repos/$SYNC_REPO/contents/$TARGET_PATH/metadata.json" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('sha',''))" 2>/dev/null || echo "")
fi

# Push summary.md
SUMMARY_B64=$(echo "$SUMMARY_CONTENT" | base64)
if [ -n "$SUMMARY_SHA" ]; then
    gh api "repos/$SYNC_REPO/contents/$TARGET_PATH/summary.md" \
        --method PUT \
        -f message="$COMMIT_MSG" \
        -f content="$SUMMARY_B64" \
        -f sha="$SUMMARY_SHA" \
        >/dev/null 2>&1 || true
else
    gh api "repos/$SYNC_REPO/contents/$TARGET_PATH/summary.md" \
        --method PUT \
        -f message="$COMMIT_MSG" \
        -f content="$SUMMARY_B64" \
        >/dev/null 2>&1 || true
fi

# Push metadata.json
METADATA_B64=$(echo "$METADATA" | base64)
if [ -n "$METADATA_SHA" ]; then
    gh api "repos/$SYNC_REPO/contents/$TARGET_PATH/metadata.json" \
        --method PUT \
        -f message="sync: metadata" \
        -f content="$METADATA_B64" \
        -f sha="$METADATA_SHA" \
        >/dev/null 2>&1 || true
else
    gh api "repos/$SYNC_REPO/contents/$TARGET_PATH/metadata.json" \
        --method PUT \
        -f message="sync: metadata" \
        -f content="$METADATA_B64" \
        >/dev/null 2>&1 || true
fi

# Push transcript if enabled
if [ "$SYNC_INCLUDE_TRANSCRIPT" = "true" ]; then
    # Find transcript file
    CWD_ENCODED=$(echo "$(pwd)" | sed 's|^/||' | tr '/' '-')
    TRANSCRIPT_DIR="$HOME/.claude/projects/-$CWD_ENCODED"

    if [ -d "$TRANSCRIPT_DIR" ]; then
        # Get most recent transcript
        TRANSCRIPT_FILE=$(ls -t "$TRANSCRIPT_DIR"/*.jsonl 2>/dev/null | head -1)

        if [ -n "$TRANSCRIPT_FILE" ] && [ -f "$TRANSCRIPT_FILE" ]; then
            echo "[SYNC] Backing up transcript" >&2

            # Compress and encode
            TRANSCRIPT_B64=$(gzip -c "$TRANSCRIPT_FILE" | base64)

            # Check for existing SHA
            TRANSCRIPT_SHA=""
            if [ "$IS_UPDATE" = "true" ]; then
                TRANSCRIPT_SHA=$(gh api "repos/$SYNC_REPO/contents/$TARGET_PATH/transcript.jsonl.gz" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('sha',''))" 2>/dev/null || echo "")
            fi

            # Push transcript
            if [ -n "$TRANSCRIPT_SHA" ]; then
                gh api "repos/$SYNC_REPO/contents/$TARGET_PATH/transcript.jsonl.gz" \
                    --method PUT \
                    -f message="sync: transcript backup" \
                    -f content="$TRANSCRIPT_B64" \
                    -f sha="$TRANSCRIPT_SHA" \
                    >/dev/null 2>&1 || true
            else
                gh api "repos/$SYNC_REPO/contents/$TARGET_PATH/transcript.jsonl.gz" \
                    --method PUT \
                    -f message="sync: transcript backup" \
                    -f content="$TRANSCRIPT_B64" \
                    >/dev/null 2>&1 || true
            fi
        fi
    fi
fi

# Update session ID map in config
python3 << PYTHON_UPDATE
import json
import os
from datetime import datetime

config_file = "$SYNC_CONFIG_FILE"
if os.path.exists(config_file):
    with open(config_file) as f:
        config = json.load(f)
else:
    config = {"enabled": True, "repo": "$SYNC_REPO"}

if "session_id_map" not in config:
    config["session_id_map"] = {}

config["session_id_map"]["$SESSION_ID"] = "$TARGET_PATH"
config["last_sync"] = datetime.utcnow().isoformat() + "Z"

with open(config_file, "w") as f:
    json.dump(config, f, indent=2)
PYTHON_UPDATE

echo "[SYNC] Session synced to github.com/$SYNC_REPO/$TARGET_PATH"
