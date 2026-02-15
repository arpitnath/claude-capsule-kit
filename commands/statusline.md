---
description: Configure which sections appear in the Claude Code statusline
allowed-tools: Bash, Read, AskUserQuestion
---

# Statusline Configuration

Configure which sections are visible in your Claude Code statusline.

## Step 1: Read current config

```bash
cat ~/.claude/statusline-config.json 2>/dev/null || echo '{"model":true,"duration":true,"context":true,"worktree":true,"crew":true,"capsule_pill":true}'
```

## Step 2: Show current state and ask what to change

Show the user which sections are currently enabled/disabled, then use AskUserQuestion with multiSelect to let them pick which sections to **show**. Unselected sections will be hidden.

Sections available:
- **Model** — Current model name (e.g., Opus, Sonnet)
- **Duration** — Session duration (e.g., 2h 15m)
- **Context** — Context window progress bar with percentage
- **Worktree** — Git worktree indicator pill (only when in a worktree)
- **Crew** — Crew mode indicator (@crew=name, only when in a crew worktree)
- **Capsule Kit** — CCK active pill badge

Use AskUserQuestion with multiSelect=true. Pre-select the currently enabled sections by listing them first with "(Enabled)" suffix. The question should be: "Which sections should be visible in the statusline?"

## Step 3: Write config

Based on the user's selection, write the config file:

```bash
cat > ~/.claude/statusline-config.json << 'CONF'
{
  "model": true/false,
  "duration": true/false,
  "context": true/false,
  "worktree": true/false,
  "crew": true/false,
  "capsule_pill": true/false
}
CONF
```

## Step 4: Confirm

Show the user what changed. List enabled and disabled sections clearly.

Tell the user: "Restart Claude Code to see the changes in your statusline."
