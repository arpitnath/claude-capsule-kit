---
description: Enable session sync to GitHub for cross-device continuation
allowed-tools: Bash
---

# Enable Session Sync

Enable automatic syncing of Claude Code sessions to GitHub. This allows you to continue sessions in Claude Web/Desktop/Mobile.

## What This Does

1. Verifies GitHub CLI is installed and authenticated
2. Creates a private `claude-sessions` repository (if needed)
3. Enables automatic sync on session end

## Run Setup

```bash
bash .claude/scripts/enable-sync.sh
```

## After Setup

- Sessions automatically sync when you exit Claude Code
- Use `/sync` to manually sync anytime
- Use `/sessions` to list synced sessions
- Use `/sync-disable` to turn off

## Requirements

- GitHub CLI (`gh`) installed: https://cli.github.com/
- Authenticated: `gh auth login`
