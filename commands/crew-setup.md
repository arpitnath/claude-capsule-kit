---
description: Check and set up everything needed for /crew (agent teams, Go binaries)
allowed-tools: Bash, Read, WebFetch
---

# Crew Setup

Check if your environment is ready for `/crew` (parallel multi-branch agent teams) and guide you through any missing pieces.

## Step 1: Check Agent Teams

Agent Teams must be enabled in Claude Code for `/crew` to work.

Verify by checking if TeamCreate, SendMessage, and team-aware Task tools are available in your current session. If you can see these tools, agent teams are enabled.

If agent teams are NOT enabled:
1. Tell the user: "Agent Teams are not enabled in your Claude Code instance."
2. Share the setup guide: https://code.claude.com/docs/en/agent-teams
3. Once enabled, ask the user to restart Claude Code and run `/crew-setup` again.

## Step 2: Check CCK Installation

```bash
node $HOME/.claude/cck/bin/cck.js status 2>/dev/null || echo "CCK not installed. Run: npx claude-capsule-kit setup"
```

If CCK is not installed, guide the user:
```
npm install -g claude-capsule-kit
cck setup
```

## Step 3: Check Go Binaries

```bash
ls -la $HOME/.claude/bin/dependency-scanner $HOME/.claude/bin/progressive-reader 2>/dev/null || echo "MISSING"
```

If binaries are missing:
1. Check if Go is available: `go version`
2. If Go is available, build them:
   ```bash
   cck build
   ```
3. If Go is NOT available:
   - Tell the user: "Go binaries (dependency-scanner, progressive-reader) are optional but recommended."
   - "Install Go 1.20+ from https://go.dev/dl/ then run `cck build`"
   - "Without them: dependency analysis and large file navigation won't be available."

## Step 4: Check .crew-config.json

```bash
cat .crew-config.json 2>/dev/null || echo "NO_CONFIG"
```

If no config exists:
- Tell the user: "No `.crew-config.json` found. You can create one with `cck crew init` or the `/crew` skill will create one interactively."

If config exists:
- Show the team composition summary (name, teammates, roles, branches)

## Step 5: Summary

Print a readiness checklist:
```
Crew Readiness:
  [x/!] Agent Teams: enabled / NOT enabled
  [x/!] CCK installed: v3.0.0 / not found
  [x/!] Go binaries: built / missing (optional)
  [x/!] Crew config: found / not found (created by /crew)

Ready to use /crew!
```

If everything is ready, tell the user they can use `/crew` to launch a team.
