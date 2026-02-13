---
description: Load a synced session summary for context
allowed-tools: Bash
---

# Load Session

Load a previously synced session summary from GitHub for context.

## Usage

Provide the session path from `/sessions` output:

```
/load-session super-claude-kit/2024-12-13-abc12345
```

## Load Session

```bash
# Get session path from argument (passed after command)
SESSION_PATH="$1"

if [ -z "$SESSION_PATH" ]; then
    echo "Usage: /load-session <project>/<session>"
    echo ""
    echo "Example: /load-session super-claude-kit/2024-12-13-abc12345"
    echo ""
    echo "Run /sessions to see available sessions"
    exit 0
fi

# Load sync config
if [ ! -f ".claude/sync-config.json" ]; then
    echo "Session sync not configured. Run /sync-enable first."
    exit 0
fi

SYNC_REPO=$(python3 -c "import json; print(json.load(open('.claude/sync-config.json')).get('repo', ''))" 2>/dev/null)

if [ -z "$SYNC_REPO" ]; then
    echo "No sync repo configured"
    exit 0
fi

# Fetch and display summary
echo ""
echo "📄 Loading session: $SESSION_PATH"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SUMMARY=$(gh api "repos/$SYNC_REPO/contents/sessions/$SESSION_PATH/summary.md" -q '.content' 2>/dev/null | base64 -d)

if [ -z "$SUMMARY" ]; then
    echo "❌ Session not found: $SESSION_PATH"
    echo ""
    echo "Run /sessions to see available sessions"
    exit 1
fi

echo "$SUMMARY"
```

## Notes

- The summary provides context for continuing the session
- Copy the "Continue Prompt" section to start where you left off
- Works across devices via GitHub MCP in Claude Web/Desktop
