---
description: Disable session sync to GitHub
allowed-tools: Bash
---

# Disable Session Sync

Turn off automatic session syncing to GitHub.

## Disable Sync

```bash
python3 -c "
import json
import os

config_file = '.claude/sync-config.json'
if os.path.exists(config_file):
    with open(config_file) as f:
        config = json.load(f)
    config['enabled'] = False
    with open(config_file, 'w') as f:
        json.dump(config, f, indent=2)
    print('✓ Session sync disabled')
    print('  Re-enable anytime with /sync-enable')
else:
    print('Session sync was not configured')
"
```

## Notes

- Your existing synced sessions remain on GitHub
- The sync config is preserved (just disabled)
- Re-enable anytime with `/sync-enable`
