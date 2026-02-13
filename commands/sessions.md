---
description: List synced sessions from GitHub
allowed-tools: Bash
---

# List Synced Sessions

Show all sessions synced to GitHub that can be continued in Claude Web/Desktop.

## List Sessions

```bash
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

echo ""
echo "📂 Synced Sessions"
echo "   Repository: github.com/$SYNC_REPO"
echo ""

# List projects
gh api "repos/$SYNC_REPO/contents/sessions" -q '.[].name' 2>/dev/null | while read project; do
    echo "━━━ $project ━━━"
    gh api "repos/$SYNC_REPO/contents/sessions/$project" -q '.[].name' 2>/dev/null | while read session; do
        echo "  • $session"
    done
    echo ""
done

echo "Use /load-session <project>/<session> to load a session"
```

## Output Example

```
📂 Synced Sessions
   Repository: github.com/username/claude-sessions

━━━ super-claude-kit ━━━
  • 2024-12-13-abc12345
  • 2024-12-12-def67890

━━━ my-project ━━━
  • 2024-12-13-xyz11111
```
