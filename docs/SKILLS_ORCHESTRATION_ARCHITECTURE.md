# Skills + Hooks: Proactive Orchestration Architecture

**Date**: 2026-01-22
**Status**: Design Complete - Implementation Pending
**Context**: Claude Code instances aren't proactively using tools/agents despite instructions in CLAUDE.md

---

## The Core Problem

### What's Broken
```
User: "This is broken"
Claude: *Reads files manually, debugs alone*
Expected: *Auto-launches error-detective + debugger agents*
```

**Root Cause**: Instructions in CLAUDE.md are **passive documentation**, not **active workflows**.

---

## The Solution: Skills as Orchestration Layer

### Why Skills > CLAUDE.md Instructions

| Aspect | CLAUDE.md | Skills |
|--------|-----------|--------|
| **Activation** | Manual (Claude must remember) | Auto (keyword matching) |
| **Discoverability** | Hidden in long doc | `/command` in menu |
| **Workflow** | Prose instructions | Executable steps |
| **Context** | Always loaded (tokens wasted) | Loaded on-demand |
| **User Control** | Passive | Active (`/debug`) |
| **Proactivity** | Low (Claude forgets) | High (triggers on keywords) |

---

## Core Workflow Skills

### 1. `/debug` - Debug Orchestration Skill

```yaml
---
name: debug
description: Systematically debug errors using error-detective and debugger agents. Triggers: error, bug, stack trace, failing test, exception, "why is this failing".
context: fork
agent: general-purpose
---
```

**When user says:**
- "This is broken"
- "Getting this error: ..."
- "Tests are failing"
- "Why isn't this working?"

**Workflow:**
1. Launch `error-detective` for RCA (Root Cause Analysis)
2. If unclear, launch `debugger` for systematic investigation
3. Run agents in PARALLEL if multiple potential causes
4. Apply fix with `code-reviewer` verification

**Example invocation:**
```
Task(
  subagent_type="error-detective",
  description="Analyze error RCA",
  prompt="User reports: [error details]"
)
```

---

### 2. `/deep-context` - Context Building Skill

```yaml
---
name: deep-context
description: Build deep codebase understanding using memory-graph, capsule, progressive-reader, and specialist agents. Triggers: "you don't have context", "understand the codebase", "learn about", "build context".
---
```

**When user says:**
- "You don't have enough context"
- "Understand the codebase first"
- "Learn about [system/module]"

**Workflow:**
1. Check memory-graph for existing knowledge
   ```bash
   bash .claude/tools/memory-graph/memory-query.sh --recent 10
   bash .claude/tools/memory-graph/memory-query.sh --search "topic"
   ```

2. Check capsule state (recent session context)

3. Use progressive-reader for large docs (>50KB)
   ```bash
   $HOME/.claude/bin/progressive-reader --path README.md --list
   ```

4. Launch specialist agents in PARALLEL:
   - `architecture-explorer`: "How does module X work?"
   - `database-navigator`: "What's the schema structure?"
   - `system-architect`: "What patterns are used?"

5. Build dependency map
   ```bash
   bash .claude/tools/query-deps/query-deps.sh src/
   bash .claude/tools/impact-analysis/impact-analysis.sh key-file.ts
   ```

6. Store discoveries in memory-graph
   ```bash
   bash .claude/tools/memory-graph/create-node.sh --type discovery
   ```

**Key principle**: Don't hold entire codebase in context. Use agents (fresh context) + memory-graph (persistence).

---

### 3. `/code-review` - Pre-Commit Review

```yaml
---
name: code-review
description: Review code before commits using code-reviewer agent. Triggers: "review this", "check my code", "before I commit", "/commit".
disable-model-invocation: true
---
```

**When to use:**
- Before creating commits
- User explicitly asks for review
- Pre-PR quality gate

**Workflow:**
1. Launch `code-reviewer` agent with changed files
2. Get structured feedback (BUG/SECURITY/PERF/QUALITY)
3. If verdict is `REQUEST_CHANGES`, fix issues first
4. Re-review until `APPROVE`
5. Then proceed with commit

---

### 4. `/refactor-safely` - Safe Refactoring Workflow

```yaml
---
name: refactor-safely
description: Plan and execute safe refactoring with refactoring-specialist and impact-analysis. Triggers: "refactor", "clean up code", "improve structure", "reorganize".
---
```

**When user says:**
- "Refactor this code"
- "Clean up [module]"
- "Improve code structure"

**Workflow:**
1. Run impact analysis first
   ```bash
   bash .claude/tools/impact-analysis/impact-analysis.sh <file>
   ```

2. Launch `refactoring-specialist` for step-by-step plan

3. Execute changes incrementally (one step at a time)

4. Verify after each step (run tests, check nothing broke)

5. Use `code-reviewer` to validate final result

---

### 5. `/plan-implementation` - Planning Skill

```yaml
---
name: plan-implementation
description: Plan complex implementations using Plan agent and architecture-explorer. Triggers: "plan how to", "implement feature", "add functionality".
disable-model-invocation: true
---
```

**When to use:**
- Complex features (>3 files, >30 min work)
- Architectural changes
- User explicitly asks for planning

**Workflow:**
1. Launch `architecture-explorer` to map existing patterns
2. Use `Plan` agent for step-by-step roadmap
3. Present plan to user, wait for approval
4. Execute with TodoWrite tracking

---

### 6. `/advise` - Knowledge Retrieval (Sionic AI Pattern)

```yaml
---
name: advise
description: Query memory-graph and capsule for relevant past knowledge before starting new work.
disable-model-invocation: true
---
```

**When to use:**
- Before starting new tasks
- User says "what do we know about X?"
- Check for past similar work

**Workflow:**
```bash
# Query memory for similar discoveries
bash .claude/tools/memory-graph/memory-query.sh --search "topic"

# Check capsule for recent context
cat .claude/capsule.toon | grep -A 5 "topic"

# Synthesize findings
```

**Output**: "Based on past sessions, here's what we know..."

---

### 7. `/retrospective` - Session Capture (Sionic AI Pattern)

```yaml
---
name: retrospective
description: Capture session learnings and create memory nodes for future reference.
disable-model-invocation: true
---
```

**When to use:**
- End of complex debugging session
- After implementing new feature
- Made important discoveries

**Workflow:**
1. Review session context (files changed, decisions made)
2. Extract key insights
3. Create memory nodes:
   ```bash
   bash .claude/tools/memory-graph/create-node.sh --type discovery --title "Finding"
   bash .claude/tools/memory-graph/create-node.sh --type decision --title "Decision"
   ```
4. Log to capsule discoveries

---

## Knowledge Skills (Background, Not Invocable)

### 8. `agent-routing-knowledge`

```yaml
---
name: agent-routing-knowledge
description: Knowledge about when to use which specialist agent
user-invocable: false
---
```

**Purpose**: Background knowledge Claude always has, not a command

**Content**: Full agent selection rules from CLAUDE.md (debugging → error-detective, architecture → architecture-explorer, etc.)

---

### 9. `tool-enforcement-knowledge`

```yaml
---
name: tool-enforcement-knowledge
description: Rules for using dependency tools, progressive-reader, and avoiding Task/Explore for simple queries
user-invocable: false
---
```

**Content**: Tool enforcement rules from CLAUDE.md

---

## Skills + Hooks Integration

### How Hooks Enhance Skills

| Hook | Enhancement | Example |
|------|-------------|---------|
| **PreToolUse** | Suggest relevant skills before tool use | Read large file → suggests `/deep-context` |
| **PostToolUse** | Trigger skills after patterns detected | Error in output → triggers `/debug` |
| **UserPromptSubmit** | Keyword detection → auto-load skill | User says "this is broken" → loads `/debug` |
| **SessionStart** | Load relevant skills for session | Resume session → loads `/advise` |
| **Stop** | Capture learnings | Session ends → prompts `/retrospective` |

### Proactive Skill Loading via Hooks

**Example: UserPromptSubmit hook**
```bash
#!/bin/bash
# hooks/user-prompt-submit.sh

USER_PROMPT="$1"

# Detect debugging intent
if echo "$USER_PROMPT" | grep -qiE '(broken|error|bug|failing|exception)'; then
  echo "💡 Suggestion: Use /debug skill for systematic debugging"
fi

# Detect context building intent
if echo "$USER_PROMPT" | grep -qiE "(don't have context|understand codebase|learn about)"; then
  echo "💡 Suggestion: Use /deep-context skill to build understanding"
fi

# Detect refactoring intent
if echo "$USER_PROMPT" | grep -qiE '(refactor|clean up|improve structure)'; then
  echo "💡 Suggestion: Use /refactor-safely skill"
fi
```

---

## Implementation Phases

### Phase 1: Core Workflow Skills (Week 1)
- [ ] Create `/debug` skill
- [ ] Create `/deep-context` skill
- [ ] Create `/code-review` skill
- [ ] Create `/refactor-safely` skill
- [ ] Test keyword auto-activation

### Phase 2: Planning & Knowledge (Week 2)
- [ ] Create `/plan-implementation` skill
- [ ] Create `agent-routing-knowledge` skill (user-invocable: false)
- [ ] Create `tool-enforcement-knowledge` skill
- [ ] Refine descriptions for better triggers

### Phase 3: Continuous Learning (Week 3)
- [ ] Create `/advise` skill (knowledge retrieval)
- [ ] Create `/retrospective` skill (session capture)
- [ ] Integrate with memory-graph
- [ ] Build learning loop

### Phase 4: Hooks Integration (Week 4)
- [ ] Add skill suggestions to UserPromptSubmit hook
- [ ] Add skill triggers to PostToolUse hook
- [ ] Add `/advise` prompt to SessionStart hook
- [ ] Add `/retrospective` reminder to Stop hook

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    User Request                          │
│         "This is broken" / "Understand codebase"        │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│              UserPromptSubmit Hook                       │
│  Detects keywords → Suggests relevant skill              │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│                 Skill Auto-Loads                         │
│  /debug, /deep-context, /refactor-safely, etc.          │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│           Skill Orchestrates Workflow                    │
│  1. Launch specialist agents (parallel)                  │
│  2. Use tools strategically                              │
│  3. Store discoveries in memory-graph                    │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│              Results → User                              │
│  Structured, agent-assisted, persisted                   │
└─────────────────────────────────────────────────────────┘
```

---

## Success Metrics

### Before (Current State)
- ❌ Claude ignores agent instructions in CLAUDE.md
- ❌ Manual tool usage, no orchestration
- ❌ Context lost between sessions
- ❌ Users must explicitly say "use error-detective"

### After (With Skills)
- ✅ "This is broken" → `/debug` auto-loads → agents launch
- ✅ "Understand codebase" → `/deep-context` → systematic learning
- ✅ `/advise` before work → past knowledge retrieved
- ✅ `/retrospective` after work → learnings persisted

---

## Key Design Principles

1. **Skills for workflows, CLAUDE.md for reference**
   - Workflows → Skills (executable, keyword-triggered)
   - Architecture/rules → CLAUDE.md (persistent reference)

2. **Proactive > Reactive**
   - Hooks detect patterns and suggest skills
   - Keywords auto-load relevant skills
   - Don't wait for user to remember commands

3. **Parallel > Sequential**
   - Skills orchestrate parallel agent execution
   - Fresh context for each agent
   - Faster, more comprehensive results

4. **Persist > Forget**
   - `/advise` retrieves past knowledge
   - `/retrospective` captures new learnings
   - Memory-graph as cross-session brain

5. **Simple > Complex**
   - Each skill has ONE clear purpose
   - 3-5 step workflows, not 20-step procedures
   - User can invoke manually if auto-loading fails

---

## References

- [Extend Claude with skills - Claude Code Docs](https://code.claude.com/docs/en/skills)
- [Agent Skills - Claude Platform Docs](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)
- [VoltAgent/awesome-claude-skills on GitHub](https://github.com/VoltAgent/awesome-claude-skills)
- [Sionic AI: Claude Code Skills for ML Experiments](https://huggingface.co/blog/sionic-ai/claude-code-skills-training)

---

## Next Steps

1. **Create skills/** directory structure
2. **Implement Phase 1 skills** (`/debug`, `/deep-context`, `/code-review`, `/refactor-safely`)
3. **Test auto-activation** with keyword triggers
4. **Enhance hooks** to suggest skills proactively
5. **Measure adoption**: How often are skills used vs. ignored?

---

**Status**: Design documented, ready for implementation.
