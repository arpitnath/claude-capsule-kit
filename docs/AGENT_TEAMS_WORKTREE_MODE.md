# Agent Teams Worktree Mode - Architecture & Implementation Plan

**Version:** 1.0 (Draft)
**Date:** February 2026
**Status:** Architecture Planning
**Note:** Subject to changes post-review

---

## Executive Summary

Enable Claude Code Agent Teams to work across different git branches using git worktrees. Each teammate operates in their own worktree (different branch) while maintaining Agent Teams coordination (messaging, task lists, shared discoveries).

**Key Innovation:** PreToolUse hooks with `updatedInput` to automatically rewrite file paths and prefix git commands, redirecting all teammate operations to their assigned worktree.

**Implementation:** ~150 lines of hook code + setup scripts, 3-5 days to production-ready.

---

## Problem Statement

**Current Limitation:**
- Agent Teams teammates spawn in Lead's working directory
- Task tool has no `working_directory` parameter
- All teammates share same git branch
- Result: Can't do parallel development on different branches

**Current Workaround (Option 5):**
- All teammates work on same branch
- Lead creates feature branches AFTER completion
- Works but not true parallel branch development

**Desired State:**
- Lead: main branch in `/project`
- Teammate-1: feature-1 branch in `/project-feature-1` (worktree)
- Teammate-2: feature-2 branch in `/project-feature-2` (worktree)
- Full Agent Teams coordination maintained

---

## System Architecture

### High-Level Design

```
┌─────────────────────────────────────────────┐
│  Lead Agent                                  │
│  Directory: /project                         │
│  Branch: main                                │
│  ├─ Creates worktrees                       │
│  ├─ Spawns teammates (Task tool)            │
│  └─ Coordinates via task list + messaging   │
└─────────────────┬───────────────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
┌───────▼──────┐    ┌───────▼──────┐
│ Teammate-1   │    │ Teammate-2   │
│ Spawned in:  │    │ Spawned in:  │
│ /project     │    │ /project     │
│      ↓       │    │      ↓       │
│ [PreToolUse  │    │ [PreToolUse  │
│  Hook]       │    │  Hook]       │
│      ↓       │    │      ↓       │
│ Redirected:  │    │ Redirected:  │
│ /project-    │    │ /project-    │
│  feature-1   │    │  feature-2   │
│ Branch:      │    │ Branch:      │
│  feature-1   │    │  feature-2   │
└──────────────┘    └──────────────┘
        │                   │
        └─────────┬─────────┘
                  │
        ┌─────────▼─────────┐
        │ Shared State       │
        ├────────────────────┤
        │ .claude/memory/    │
        │   (discoveries,    │
        │    sessions)       │
        │                    │
        │ Task list          │
        │ Messaging          │
        └────────────────────┘
```

### Core Mechanism: Path Rewriting

**PreToolUse Hook intercepts all tool calls:**

```
Teammate-1 calls: Read("/project/src/auth.ts")
    ↓
PreToolUse hook:
    - Detects teammate: teammate-1
    - Loads config: worktree_path = /project-feature-1
    - Rewrites path: /project/src/auth.ts → /project-feature-1/src/auth.ts
    - Returns: updatedInput: { file_path: "/project-feature-1/src/auth.ts" }
    ↓
Read tool executes with: /project-feature-1/src/auth.ts ✓
```

**Same for Bash commands:**

```
Teammate-1 calls: Bash("git status")
    ↓
PreToolUse hook:
    - Rewrites: "git status" → "cd /project-feature-1 && git status"
    - Returns: updatedInput: { command: "cd /project-feature-1 && git status" }
    ↓
Bash executes in worktree, sees feature-1 branch ✓
```

---

## Component Design

### 1. Worktree Setup Script

**File:** `scripts/setup-agent-worktree.sh`

```bash
#!/bin/bash
# Setup worktree for Agent Teams teammate

set -euo pipefail

PROJECT_ROOT="$1"      # /project
BRANCH_NAME="$2"       # feature-auth
TEAMMATE_NAME="$3"     # teammate-1

WORKTREE_DIR="${PROJECT_ROOT}-${BRANCH_NAME}"
CONFIG_DIR="${PROJECT_ROOT}/.claude/worktree-config"

# Create worktree
cd "$PROJECT_ROOT"
git worktree add "$WORKTREE_DIR" -b "$BRANCH_NAME" 2>/dev/null || \
git worktree add "$WORKTREE_DIR" "$BRANCH_NAME"

# Create teammate config
mkdir -p "$CONFIG_DIR"
cat > "${CONFIG_DIR}/${TEAMMATE_NAME}.json" <<EOF
{
  "teammate_name": "$TEAMMATE_NAME",
  "worktree_path": "$WORKTREE_DIR",
  "branch": "$BRANCH_NAME",
  "project_root": "$PROJECT_ROOT",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Symlink .claude directory (shared memory)
ln -sf "$PROJECT_ROOT/.claude" "$WORKTREE_DIR/.claude"

echo "✓ Worktree ready: $WORKTREE_DIR (branch: $BRANCH_NAME)"
```

---

### 2. PreToolUse Hook (Core Redirection)

**File:** `hooks/worktree-redirect.sh`

```bash
#!/bin/bash
# PreToolUse hook: Redirect file operations to worktree

set -euo pipefail

INPUT_JSON=$(cat)

# Get worktree path from environment (set by SessionStart)
WORKTREE_PATH="${WORKTREE_PATH:-}"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-}"

if [ -z "$WORKTREE_PATH" ] || [ -z "$PROJECT_ROOT" ]; then
    exit 0  # No redirection configured
fi

TOOL_NAME=$(echo "$INPUT_JSON" | jq -r '.tool_name // empty')
TOOL_INPUT=$(echo "$INPUT_JSON" | jq -c '.tool_input // {}')

# Path rewriting function
rewrite_path() {
    local path="$1"
    # Replace project root with worktree path
    if [[ "$path" == "${PROJECT_ROOT}"* ]]; then
        echo "${WORKTREE_PATH}${path#${PROJECT_ROOT}}"
    else
        echo "$path"
    fi
}

case "$TOOL_NAME" in
    Read|Write|Edit)
        FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty')
        if [ -n "$FILE_PATH" ]; then
            NEW_PATH=$(rewrite_path "$FILE_PATH")
            if [ "$NEW_PATH" != "$FILE_PATH" ]; then
                jq -n --argjson input "$TOOL_INPUT" --arg newpath "$NEW_PATH" '{
                    hookSpecificOutput: {
                        hookEventName: "PreToolUse",
                        permissionDecision: "allow",
                        updatedInput: ($input | .file_path = $newpath)
                    }
                }'
                exit 0
            fi
        fi
        ;;

    Glob|Grep)
        SEARCH_PATH=$(echo "$TOOL_INPUT" | jq -r '.path // empty')
        NEW_PATH=$(rewrite_path "${SEARCH_PATH:-$PROJECT_ROOT}")
        jq -n --argjson input "$TOOL_INPUT" --arg newpath "$NEW_PATH" '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "allow",
                updatedInput: ($input | .path = $newpath)
            }
        }'
        exit 0
        ;;

    Bash)
        COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // empty')
        if [ -n "$COMMAND" ] && [[ "$COMMAND" != "cd $WORKTREE_PATH"* ]]; then
            jq -n --argjson input "$TOOL_INPUT" --arg wt "$WORKTREE_PATH" --arg cmd "$COMMAND" '{
                hookSpecificOutput: {
                    hookEventName: "PreToolUse",
                    permissionDecision: "allow",
                    updatedInput: ($input | .command = ("cd " + $wt + " && " + $cmd))
                }
            }'
            exit 0
        fi
        ;;
esac

exit 0
```

---

### 3. SessionStart Hook (Environment Setup)

**File:** `hooks/worktree-session-start.sh`

```bash
#!/bin/bash
# SessionStart: Set worktree path for teammates

set -euo pipefail

TEAMMATE_NAME="${TEAMMATE_NAME:-}"

if [ -n "$TEAMMATE_NAME" ]; then
    CONFIG_FILE=".claude/worktree-config/${TEAMMATE_NAME}.json"
    if [ -f "$CONFIG_FILE" ]; then
        WORKTREE_PATH=$(jq -r '.worktree_path' "$CONFIG_FILE")

        if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
            echo "export WORKTREE_PATH=\"${WORKTREE_PATH}\"" >> "$CLAUDE_ENV_FILE"
            echo "export TEAMMATE_NAME=\"${TEAMMATE_NAME}\"" >> "$CLAUDE_ENV_FILE"
        fi
    fi
fi

exit 0
```

---

### 4. Worktree Cleanup Script

**File:** `scripts/cleanup-agent-worktree.sh`

```bash
#!/bin/bash
# Cleanup worktree after team work completes

set -euo pipefail

TEAMMATE_NAME="$1"
CONFIG_DIR=".claude/worktree-config"
CONFIG_FILE="${CONFIG_DIR}/${TEAMMATE_NAME}.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "No config for $TEAMMATE_NAME"
    exit 1
fi

WORKTREE_PATH=$(jq -r '.worktree_path' "$CONFIG_FILE")

# Remove worktree
git worktree remove "$WORKTREE_PATH" --force

# Remove config
rm "$CONFIG_FILE"

echo "✓ Cleaned up worktree: $WORKTREE_PATH"
```

---

## Implementation Plan

### Phase 0: Validation (2 hours)

**Goal:** Prove PreToolUse `updatedInput` works for all tool types

**Tasks:**
1. Write minimal PreToolUse hook
2. Hardcode `WORKTREE_PATH=/tmp/test-worktree`
3. Test Read tool → verify path rewritten
4. Test Write tool → verify path rewritten
5. Test Bash tool → **CRITICAL:** verify command prefixed with cd
6. Test Glob/Grep → verify path rewritten

**Success Criteria:**
- [ ] All 5 tool types successfully redirected
- [ ] Bash `updatedInput` for `command` field works
- [ ] No data corruption or errors

**If validation fails:** Fallback to Option E+ (instruction-based) only

---

### Phase 1: MVP (1-2 days)

**Goal:** Working worktree mode for 1 teammate

**Tasks:**
1. Build `setup-agent-worktree.sh` script
2. Build `worktree-redirect.sh` PreToolUse hook
3. Build `worktree-session-start.sh` SessionStart hook
4. Test with single teammate on feature branch
5. Verify git operations work correctly
6. Verify file operations write to correct worktree

**Success Criteria:**
- [ ] Lead creates worktree successfully
- [ ] Teammate operates in correct worktree
- [ ] Git commands show correct branch
- [ ] File edits go to correct worktree
- [ ] No data loss or conflicts

**Deliverables:**
- 3 scripts (~200 lines total)
- Test documentation
- Known issues list

---

### Phase 2: Multi-Teammate Support (1-2 days)

**Goal:** 3+ teammates in different worktrees simultaneously

**Tasks:**
1. Build `cleanup-agent-worktree.sh` script
2. Add teammate name discovery mechanism
3. Test 3 teammates in parallel (different branches)
4. Verify shared memory works (symlinked .claude/)
5. Verify no file conflicts across worktrees
6. Add health checks (TeammateIdle hook)

**Success Criteria:**
- [ ] 3 teammates operate independently
- [ ] Each on correct branch
- [ ] Shared discoveries work
- [ ] Task list coordination works
- [ ] Messaging works across worktrees

**Deliverables:**
- Cleanup scripts
- Multi-teammate tests
- Health check monitoring

---

### Phase 3: Production Hardening (2-3 days)

**Goal:** Robust, error-handled, documented feature

**Tasks:**
1. Add edge case handling (absolute paths, paths outside project)
2. Add failure recovery (worktree deleted mid-work)
3. Add file conflict detection (optional)
4. Write comprehensive documentation
5. Add integration tests
6. Performance validation (<10ms overhead)

**Success Criteria:**
- [ ] All edge cases handled
- [ ] Graceful degradation on errors
- [ ] Documentation complete
- [ ] Tests passing
- [ ] Performance targets met

**Deliverables:**
- Production-ready scripts
- User documentation
- Architecture doc (this document)
- Test suite

---

## Technical Specification

### Hook Integration

**Register in `.claude/settings.local.json` (or via install script):**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read|Write|Edit|Glob|Grep|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/worktree-redirect.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/worktree-session-start.sh"
          }
        ]
      }
    ]
  }
}
```

---

### Worktree Structure

```
Project Layout:
├── /project/                          (main branch - Lead works here)
│   ├── .claude/                       (shared memory, tools, hooks)
│   │   ├── memory/                    (Capsule storage - shared!)
│   │   ├── worktree-config/           (teammate → worktree mappings)
│   │   │   ├── teammate-1.json
│   │   │   └── teammate-2.json
│   │   └── hooks/
│   │       └── worktree-redirect.sh
│   └── src/
│
├── /project-feature-1/                (feature-1 branch - Teammate-1)
│   ├── .claude/ → /project/.claude/   (symlink!)
│   └── src/                           (isolated files)
│
└── /project-feature-2/                (feature-2 branch - Teammate-2)
    ├── .claude/ → /project/.claude/   (symlink!)
    └── src/                           (isolated files)
```

**Key insight:** `.claude/` is symlinked, so all teammates share:
- Memory/discoveries (Capsule storage)
- Tools and hooks
- Task list (Agent Teams native)
- Messaging (Agent Teams native)

But each teammate edits files in their own worktree!

---

### Teammate Config Schema

**File:** `.claude/worktree-config/{teammate-name}.json`

```json
{
  "teammate_name": "teammate-1",
  "worktree_path": "/Users/arpit/Desktop/project-feature-1",
  "branch": "feature-1",
  "project_root": "/Users/arpit/Desktop/project",
  "created_at": "2026-02-11T10:00:00Z",
  "owned_paths": [
    "src/auth/",
    "src/middleware/"
  ]
}
```

---

## Workflow

### Setup (Lead Agent)

```bash
# 1. Create worktrees for each feature
bash scripts/setup-agent-worktree.sh /project feature-auth teammate-1
bash scripts/setup-agent-worktree.sh /project feature-api teammate-2

# 2. Create tasks
TaskCreate("Implement auth module")
TaskCreate("Build API endpoints")

# 3. Spawn teammates with names
Task(
  name="teammate-1",
  team_name="dev-team",
  prompt="You are teammate-1. Work on auth module. Check task list for assignments."
)

Task(
  name="teammate-2",
  team_name="dev-team",
  prompt="You are teammate-2. Work on API endpoints. Check task list for assignments."
)
```

### Execution (Teammates)

```
Teammate-1 (auto-redirected to /project-feature-1):
1. Checks task list → Claims "Implement auth module"
2. Reads files → PreToolUse rewrites paths to /project-feature-1/
3. Edits code → Changes go to feature-1 branch
4. Commits → git commit runs in worktree (feature-1 branch)
5. Completes task → Messages lead with results

Teammate-2 (auto-redirected to /project-feature-2):
1. Claims "Build API endpoints"
2. Works in /project-feature-2/ (feature-2 branch)
3. No file conflicts with Teammate-1 (different worktrees!)
4. Completes and messages lead
```

### Merge (Lead Agent)

```bash
# After teammates complete:

# 1. Review Teammate-1's work
cd /project
git diff main..feature-1

# 2. Merge if approved
git merge feature-1

# 3. Review Teammate-2's work
git diff main..feature-2

# 4. Merge if approved
git merge feature-2

# 5. Cleanup worktrees
bash scripts/cleanup-agent-worktree.sh teammate-1
bash scripts/cleanup-agent-worktree.sh teammate-2
```

---

## Known Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| **PreToolUse `updatedInput` doesn't work for Bash** | HIGH | Phase 0 validation REQUIRED before building |
| **Teammate name not discoverable** | HIGH | Use SubagentStart hook to inject teammate name |
| **Worktree deleted mid-work** | MEDIUM | Health check in TeammateIdle hook |
| **Path rewriting edge cases** | MEDIUM | Only rewrite paths under project root |
| **Agent Teams API changes** | MEDIUM | Feature is experimental, may change |
| **Memory race conditions** | LOW | Symlinked .claude/, minor contention acceptable |

**CRITICAL:** Phase 0 validation must confirm `updatedInput` works for Bash `command` field. Documentation doesn't explicitly state this!

---

## Performance Impact

| Operation | Overhead | Impact |
|-----------|----------|--------|
| PreToolUse hook execution | ~5-10ms | Negligible vs 2-30s LLM inference |
| Worktree setup | ~2-5s | One-time per teammate |
| Git operations | 0ms | Native worktree performance |
| Memory access | 0ms | Symlink, no overhead |

**Total impact:** <1% slowdown, imperceptible to users

---

## Success Metrics

### Technical Validation
- [ ] All tool types (Read, Write, Edit, Glob, Grep, Bash) redirect correctly
- [ ] Git operations show correct branch
- [ ] No file corruption across worktrees
- [ ] Performance overhead <10ms per tool call

### Functional Validation
- [ ] 3 teammates work on different branches simultaneously
- [ ] Shared discoveries work (symlinked memory)
- [ ] Task list coordination works
- [ ] Messaging works across worktrees
- [ ] Lead can review and merge branches

### User Experience
- [ ] Zero manual path adjustments by teammates
- [ ] Clear worktree context in prompts
- [ ] Easy setup (single script)
- [ ] Easy cleanup (single script)

---

## Alternative Approaches

### Option E+ (Instruction-Based) - No Implementation Needed

**Lead instructs teammates:**
> "You are working in /project-feature-1/ worktree on feature-1 branch. Use absolute paths for all file operations: Read('/project-feature-1/src/...'), Bash('cd /project-feature-1 && git ...')"

**Success rate:** ~90% (LLM compliance is good but not perfect)
**Effort:** 0 days (just instructions)
**Recommended:** Use this TODAY while building hooks-based approach

### Option F (Hooks-Based) - This Document

**Automatic redirection via PreToolUse hooks**

**Success rate:** ~99% (hooks intercept all operations)
**Effort:** 3-5 days
**Recommended:** Build after Phase 0 validation succeeds

---

## Open Questions (Post-Review)

1. **Teammate name discovery:** Best mechanism? (env, config, marker file)
2. **File ownership:** Enforce or just warn?
3. **Capsule integration:** How does capsule namespace isolation work with worktrees?
4. **Error handling:** Fallback strategy if worktree unavailable?
5. **Multi-project:** Does this work across different projects?

---

## Next Steps

**Immediate (This Week):**
1. **Phase 0 validation** (2 hours) - Test PreToolUse `updatedInput`
2. **Go/no-go decision** based on validation results

**If validation succeeds:**
1. **Phase 1 MVP** (1-2 days) - Single teammate worktree support
2. **Phase 2 multi-teammate** (1-2 days) - 3+ teammates
3. **Phase 3 production** (2-3 days) - Hardening, docs, tests

**Timeline:** ~1 week from validation to production-ready

---

## Notes

- This design assumes Agent Teams API remains stable (experimental risk)
- PreToolUse `updatedInput` for Bash commands is unvalidated (MUST TEST)
- Symlinked .claude/ approach is novel (not documented elsewhere)
- This enables true parallel branch development with Agent Teams coordination
- Falls back gracefully to Option E+ if hooks don't work

---

**Status:** Architecture defined, ready for validation. Post-review changes expected.

**Owner:** Arpit
**Reviewers:** Fresh Claude instance (for unbiased evaluation)

---

**End of Architecture Document**
