#!/bin/bash
# Enable Session Sync
# Sets up GitHub repo and configuration for session sync

set -euo pipefail

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📡 Session Sync Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check gh CLI
if ! command -v gh &>/dev/null; then
    echo "❌ GitHub CLI (gh) not installed"
    echo ""
    echo "Install from: https://cli.github.com/"
    echo ""
    exit 1
fi

# Check auth
if ! gh auth status &>/dev/null 2>&1; then
    echo "❌ GitHub CLI not authenticated"
    echo ""
    echo "Run: gh auth login"
    echo ""
    exit 1
fi

echo "✓ GitHub CLI authenticated"

# Get GitHub username
GH_USER=$(gh api user --jq '.login' 2>/dev/null)
if [ -z "$GH_USER" ]; then
    echo "❌ Could not get GitHub username"
    exit 1
fi

echo "✓ GitHub user: $GH_USER"

# Repo name
REPO_NAME="claude-sessions"
REPO_FULL="$GH_USER/$REPO_NAME"

# Check if repo exists
if gh repo view "$REPO_FULL" &>/dev/null 2>&1; then
    echo "✓ Repository exists: github.com/$REPO_FULL"
else
    echo ""
    echo "Creating private repository: $REPO_FULL"
    gh repo create "$REPO_NAME" --private --description "Claude Code session sync (via Super Claude Kit)" 2>/dev/null || {
        echo "❌ Failed to create repository"
        exit 1
    }
    echo "✓ Repository created"

    # Add README
    README_CONTENT='# Claude Sessions

Private repository for syncing Claude Code sessions across devices.

## Purpose

Continue Claude Code conversations in Claude Web/Desktop/Mobile with full context.

## Structure

```
sessions/
└── {project-name}/
    └── {date}-{session-id}/
        ├── summary.md        # Session summary
        └── metadata.json     # Session info
```

## Usage

### From Claude Code
- Automatic sync on session end (if enabled)
- Manual: `/sync` command

### From Claude Web/Desktop
- Connect GitHub MCP server
- Load session via summary.md

## Related

- [Super Claude Kit](https://github.com/arpitnath/super-claude-kit)
'

    README_B64=$(echo "$README_CONTENT" | base64)
    gh api "repos/$REPO_FULL/contents/README.md" \
        --method PUT \
        -f message="docs: Initial README" \
        -f content="$README_B64" \
        >/dev/null 2>&1 || true
fi

# Create config directory
mkdir -p .claude

# Write config
cat > .claude/sync-config.json << EOF
{
  "enabled": true,
  "repo": "$REPO_FULL",
  "include_transcript": false,
  "session_id_map": {},
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Session Sync Enabled!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Repository: github.com/$REPO_FULL"
echo ""
echo "  Sessions will automatically sync when you:"
echo "  • End a session (exit Claude Code)"
echo "  • Run /sync command"
echo ""
echo "  To continue in Claude Web/Desktop:"
echo "  • Connect GitHub MCP server"
echo "  • Load the session summary"
echo ""
echo "  Commands:"
echo "  • /sync         - Sync now"
echo "  • /sync-disable - Disable sync"
echo "  • /sessions     - List synced sessions"
echo ""
