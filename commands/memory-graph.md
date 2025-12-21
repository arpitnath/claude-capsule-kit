---
description: Visualize the semantic memory graph
allowed-tools: Bash
---

# Visualize Memory Graph

Display the semantic memory graph showing entities, relationships, and connections discovered during your sessions.

## Visualize

```bash
python3 tools/memory-graph/lib/visualize_rich.py
```

## What It Shows

- **Files**: Source files you've worked with
- **Functions**: Code entities and exports
- **Decisions**: Architectural choices made
- **Tasks**: Work completed and in-progress
- **Relationships**: How everything connects

## Notes

- Rich terminal visualization with colors
- Shows graph structure and relationships
- Helps understand context connections
- Memory graph builds automatically as you work
