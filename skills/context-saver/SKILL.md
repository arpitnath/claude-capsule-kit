---
name: context-saver
description: |
  Automatically save exploration findings, discoveries, and current state to
  the exploration journal (docs/exploration/). Use when making important discoveries
  or completing a phase of work. Ensures future Claude sessions can continue
  where this session left off.
allowed-tools: [Write, Edit, Read, Bash]
---

# Context Saver Skill

This skill enables Claude Capsule Kit to save discoveries to persistent storage.

## Purpose

**Problem**: Claude sessions are stateless - discoveries are lost when session ends.
**Solution**: Save findings to `docs/exploration/` files that next Claude reads.

## When to Use

Use this skill when:
- Completing an exploration phase
- Making important architectural discoveries
- Finding bugs or issues
- Learning how a system works
- Finishing a significant task

## How It Works

1. **Determine what to save**: Summarize key findings from current work
2. **Choose appropriate file**:
   - `CURRENT_SESSION.md` - Update with latest progress
   - `PHASE_X_FINDINGS.md` - Save phase-specific discoveries
   - `DISCOVERY_[TOPIC].md` - Document specific insights
3. **Write structured markdown**: Clear, scannable format for future Claude
4. **Update session state**: Track what's done, what's next

## File Structure

### CURRENT_SESSION.md
```markdown
# Current Session: [Goal]
**Date**: YYYY-MM-DD
**Status**: In Progress / Complete

## Completed
- [x] Task 1
- [x] Task 2

## Discovered
- Finding 1 with file references
- Finding 2 with code examples

## Next Steps
- [ ] Continue with...
```

### PHASE_X_FINDINGS.md
```markdown
# Phase X: [Phase Name]
**Date**: YYYY-MM-DD
**Status**: Complete

## Summary
3-5 sentence overview of what was explored.

## Key Findings
1. **Finding 1**: Details with file paths
2. **Finding 2**: Details with code snippets

## Files Explored
- `/path/to/file:123` - What we learned
```

## Example Usage

**Situation**: Just completed exploring Labs database schema

**Skill Execution**:
1. Create `/docs/exploration/LABS_DATABASE_SCHEMA.md`
2. Document findings:
   - 3 main tables (experiments, experiment_runs, validation_rules)
   - Foreign key relationships
   - JSONB config storage patterns
   - Confidence score calculation (DECIMAL 3,2)
3. Update `CURRENT_SESSION.md` with progress
4. Mark task as completed

**Result**: Next Claude session reads `LABS_DATABASE_SCHEMA.md` and knows exactly what was discovered.

## Best Practices

### DO:
- ✅ Save concrete findings (file paths, line numbers, code snippets)
- ✅ Use clear section headers for scannability
- ✅ Include "Next Steps" for continuity
- ✅ Reference specific files explored
- ✅ Document both what works AND what doesn't

### DON'T:
- ❌ Save vague statements ("looked at some code")
- ❌ Omit file references
- ❌ Write walls of text without structure
- ❌ Forget to update CURRENT_SESSION.md

## Integration with SessionStart Hook

When next Claude session starts:
1. SessionStart hook detects files in `docs/exploration/`
2. Prints: "🧠 Claude Capsule Kit MEMORY LOADED: Previous exploration findings available"
3. Lists all saved files
4. Next Claude reads relevant files to continue work

This creates **persistent memory across sessions**!

## Commands

```bash
# List saved findings
ls docs/exploration/

# Read a specific finding
cat docs/exploration/PHASE_1_FINDINGS.md

# Update current session
# (Edit CURRENT_SESSION.md with new progress)
```

## Success Criteria

✅ Findings are clear enough that another developer could understand
✅ File paths included for easy navigation
✅ Next steps documented for continuity
✅ CURRENT_SESSION.md always reflects latest state

---

**Remember**: This skill is THE KEY to making Claude truly "SUPER" - it's how we remember and build on past work!
