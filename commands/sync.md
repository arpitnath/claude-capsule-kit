---
description: Manually sync current session to GitHub now
allowed-tools: Bash
---

# Sync Session Now

Push the current session state to GitHub immediately.

## Sync

```bash
if [ -f ".claude/scripts/push-session.sh" ]; then
    bash .claude/scripts/push-session.sh
else
    echo "Session sync not installed. Run /sync-enable first."
fi
```

## What Gets Synced

- Current tasks (completed, in-progress, pending)
- Files accessed this session
- Discoveries logged
- Session duration and metadata

## Notes

- Safe to run multiple times (updates existing session)
- Requires sync to be enabled first (`/sync-enable`)
- Sessions also sync automatically on exit
