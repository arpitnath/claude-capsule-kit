#!/bin/bash
# Cross-Session Capsule Persistence
# Saves key session state for next session to restore
# Uses Python for reliable JSON generation (avoids bash subshell issues)

set -euo pipefail

# First, show session summary
./.claude/hooks/summarize-session.sh 2>/dev/null || true

PERSIST_FILE=".claude/capsule_persist.json"

# Use Python to generate valid JSON (avoids bash while-loop subshell issues)
python3 << 'PYTHON'
import json
import os
import subprocess
from datetime import datetime

persist_file = ".claude/capsule_persist.json"

# Get session info
try:
    with open(".claude/session_start.txt") as f:
        session_start = int(f.read().strip())
except:
    session_start = int(datetime.now().timestamp())

timestamp = int(datetime.now().timestamp())
duration = timestamp - session_start

# Get git info
try:
    branch = subprocess.check_output(["git", "rev-parse", "--abbrev-ref", "HEAD"],
                                     stderr=subprocess.DEVNULL).decode().strip()
    head = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"],
                                   stderr=subprocess.DEVNULL).decode().strip()
except:
    branch = "none"
    head = "none"

# Build persistence object
data = {
    "last_session": {
        "ended_at": timestamp,
        "duration_seconds": duration,
        "branch": branch,
        "head": head
    },
    "discoveries": [],
    "key_files": [],
    "sub_agents": []
}

# Read discoveries
try:
    with open(".claude/session_discoveries.log") as f:
        lines = f.readlines()[-10:]  # Last 10
        for line in lines:
            parts = line.strip().split(",", 2)
            if len(parts) >= 3:
                data["discoveries"].append({
                    "timestamp": int(parts[0]),
                    "category": parts[1],
                    "content": parts[2]
                })
except:
    pass

# Read key files
try:
    with open(".claude/session_files.log") as f:
        lines = f.readlines()[-15:]  # Last 15
        files = set()
        for line in lines:
            parts = line.strip().split(",")
            if parts:
                files.add(parts[0])
        data["key_files"] = list(files)
except:
    pass

# Read sub-agent results
try:
    with open(".claude/subagent_results.log") as f:
        lines = f.readlines()[-5:]  # Last 5
        for line in lines:
            parts = line.strip().split(",", 2)
            if len(parts) >= 3:
                data["sub_agents"].append({
                    "timestamp": int(parts[0]),
                    "type": parts[1],
                    "summary": parts[2]
                })
except:
    pass

# Write JSON
with open(persist_file, "w") as f:
    json.dump(data, f, indent=2)

print(f"Persisted: {len(data['discoveries'])} discoveries, {len(data['key_files'])} files, {len(data['sub_agents'])} agents")
PYTHON

# Also sync discoveries to exploration journal
./.claude/hooks/sync-to-journal.sh 2>/dev/null || true

echo "✓ Session state persisted for next session" >&2
