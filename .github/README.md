# Assets Directory

This directory contains visual assets for the README.

## Required GIFs/Images

### Hero Section
- **super-claude-kit-logo.png** (200x200px) - Logo
- **capsule-restore.gif** (80% width) - Shows context capsule restoring on session start

### Feature Demonstrations
- **session-resume.gif** (80% width) - Shows Claude remembering context after restart
- **file-reread-prevention.gif** (70% width) - Shows token savings from file memory
- **dependency-graph.gif** (70% width) - Shows dependency intelligence in action

## GIF Recording Guidelines

### Terminal Setup
- Font: JetBrains Mono or Fira Code, 16pt
- Theme: Dark background (#1e1e1e)
- Window: 100 cols x 30 rows
- High contrast colors

### Recording Tools
```bash
# Option 1: Asciinema (recommended)
brew install asciinema agg
asciinema rec session.cast
agg --font-size 16 session.cast output.gif

# Option 2: Terminalizer
npm install -g terminalizer
terminalizer record demo
terminalizer render demo
```

### Optimization
```bash
# Keep GIFs under 5MB
gifsicle -O3 --colors 256 input.gif -o output.gif
```

## Placeholder Status

All assets currently have placeholder comments in README.md.
Uncomment the `<img>` tags once assets are created.
