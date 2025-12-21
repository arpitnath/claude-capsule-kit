---
name: exploration-continue
description: |
  Resume exploration from where previous Claude session left off by reading
  the exploration journal (docs/exploration/). Use at start of session when
  user says "continue", "resume", or "pick up where we left off".
allowed-tools: [Read, Grep, Glob]
---

# Exploration Continue Skill

This skill enables Claude Capsule Kit to resume work from previous sessions.

## Purpose

**Problem**: User wants to continue work from previous session, but Claude doesn't remember.
**Solution**: Read exploration journal to understand what was done and what's next.

## When to Use

Activate this skill when user says:
- "Continue where we left off"
- "Resume exploration"
- "What did we discover last time?"
- "Pick up from previous session"
- "What's next?"

## How It Works

1. **Check for exploration journal**: Look in `docs/exploration/`
2. **Read CURRENT_SESSION.md**: Understand current state
3. **Read phase findings**: Load specific discoveries
4. **Identify next steps**: Find what needs to be done
5. **Present summary**: Show user what was done and what's next
6. **Offer to continue**: Ask if user wants to proceed

## Execution Flow

```
Step 1: Check docs/exploration/ exists
  ↓
Step 2: List all exploration files
  ↓
Step 3: Read CURRENT_SESSION.md (always read this first)
  ↓
Step 4: Read other relevant findings based on topic
  ↓
Step 5: Summarize for user:
  - What was explored
  - Key discoveries
  - Current status
  - Next steps
  ↓
Step 6: Ask user: "Should I continue with [next step]?"
```

## Example Usage

**User**: "Continue where we left off"

**Skill Execution**:
1. Check `docs/exploration/` exists ✅
2. Find files:
   - `CURRENT_SESSION.md`
   - `PHASE_1_SERVICE_DISCOVERY.md`
3. Read `CURRENT_SESSION.md`:
   - Goal: Becoming Claude Capsule Kit
   - Status: 60% complete
   - Completed: Hooks, sub-agents, skills
   - Next: Test complete system
4. Present to user:
   ```
   📚 Previous Session Summary:

   Goal: Transform into Claude Capsule Kit
   Progress: 60% complete

   ✅ Completed:
   - SessionStart hook (auto-context loading)
   - 4 specialized sub-agents
   - 3 reusable skills

   🔄 Next Steps:
   - Test complete Claude Capsule Kit system
   - Explore codebase using new capabilities
   - Create unified documentation

   Should I continue with testing Claude Capsule Kit?
   ```

## Reading Priority

**Always read first**:
1. `CURRENT_SESSION.md` - Most recent state

**Read as needed**:
2. `PHASE_X_FINDINGS.md` - Specific phase discoveries
3. `DISCOVERY_[TOPIC].md` - Topic-specific insights

**Tip**: Don't read ALL files - only what's relevant to next steps.

## Best Practices

### DO:
- ✅ Always read CURRENT_SESSION.md first
- ✅ Summarize clearly for user
- ✅ Identify concrete next steps
- ✅ Ask user before proceeding
- ✅ Reference file paths when discussing findings

### DON'T:
- ❌ Read entire exploration journal (too much context)
- ❌ Proceed without user confirmation
- ❌ Assume what user wants to work on
- ❌ Forget to check if files exist

## Integration with Context-Saver

**Context-Saver writes**, Exploration-Continue reads:
```
Session 1: Claude explores, uses context-saver to write findings
  ↓
Session 2: User says "continue", exploration-continue reads findings
  ↓
Session 2: Claude picks up where Session 1 left off
  ↓
Session 2: Uses context-saver to write new findings
  ↓
Session 3: Repeat...
```

This creates **true continuity across sessions**!

## Commands

```bash
# Check if exploration journal exists
ls docs/exploration/ 2>/dev/null

# Read current session
cat docs/exploration/CURRENT_SESSION.md

# List all findings
ls -1 docs/exploration/*.md
```

## Success Criteria

✅ User feels continuity between sessions
✅ No work is repeated unnecessarily
✅ Clear understanding of what's been done
✅ Obvious path forward

## Error Handling

**If no exploration journal exists**:
```
"No previous exploration found. This appears to be a fresh start.
Would you like to begin a new exploration?"
```

**If CURRENT_SESSION.md is outdated** (>7 days old):
```
"Previous session was 7+ days ago. The codebase may have changed.
Should I verify findings are still accurate before continuing?"
```

---

**Remember**: This skill makes Claude Capsule Kit feel like a continuous teammate, not a fresh start every time!
