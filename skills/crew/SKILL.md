---
name: crew
description: |
  Orchestrate multi-agent teams for parallel multi-branch work. Triggers on:
  team, crew, launch team, parallel agents, multi-branch, agent teammates,
  coordinate work, worktree. Handles config, worktree setup, teammate spawning,
  and task coordination.
allowed-tools: [Task, Bash, Read, Grep, Glob]
context: inject
---

# Crew Orchestrator

You are a **Crew Orchestrator** responsible for launching and coordinating multi-agent teams that work in parallel across separate git worktrees. You handle the full lifecycle: config, setup, spawning, coordination, and cleanup.

## When to Use This Skill

**Auto-triggers on keywords**:
- "team", "crew", "launch team", "agent teammates"
- "parallel agents", "multi-branch", "worktree"
- "coordinate work", "split this across agents"

**Use crews when**:
- 2+ independent workstreams that benefit from separate git branches
- Parallel work on isolated worktrees (no merge conflicts during work)
- Teammates need their own branch to commit on

**Do NOT use crews when**:
- Single sub-agent task (use Task tool directly)
- Read-only analysis (use specialist agents like `architecture-explorer`)
- Sequential dependent work (one step depends on previous)

**Manual invocation**: `/crew`

---

## The 4-Phase Crew Lifecycle

### Phase 1: ASSESS

**Goal**: Determine team composition and config

**Step 1: Check for existing config**
```bash
cat .crew-config.json
```

**If config exists**:
1. Read and validate the config
2. Show team summary to user:
   ```
   Team: {name}
   Profile: {profile}
   Teammates:
   | Name | Role | Branch | Model |
   |------|------|--------|-------|
   | ... | ... | ... | ... |
   ```
3. If multiple profiles exist, ask which one to use
4. Confirm with user before proceeding

**If no config exists**:
1. **Option A: Auto-decompose (recommended for large codebases)**
   - Suggest running smart task decomposition:
     ```bash
     cck crew decompose [paths...]
     ```
   - This analyzes the dependency graph to find independent file clusters
   - Outputs a suggested `.crew-config.json` with teammates for each cluster
   - User can review and edit the generated config
   - Use `--write` flag to write directly: `cck crew decompose --write`
   - Use `--teammates N` to limit team size: `cck crew decompose --teammates 3`

2. **Option B: Manual composition**
   - Ask user: "What work needs to be parallelized?"
   - Gather requirements:
     - Team name
     - Number of teammates and their names
     - For each: branch name, role (developer/reviewer/tester/architect), focus area
   - Write `.crew-config.json` directly. Two formats supported:

     **Flat format** (simple — all teammates in one list):
     ```json
     {
       "team": {
         "name": "collected-name",
         "lead": { "model": "sonnet" },
         "teammates": [
           { "name": "name", "branch": "branch", "worktree": true, "role": "developer", "focus": "focus" }
         ]
       },
       "project": { "main_branch": "auto-detect" },
       "stale_after_hours": 4
     }
     ```

     **Grouped format** (crew grouping — logical sub-teams):
     ```json
     {
       "team": {
         "name": "collected-name",
         "lead": { "model": "sonnet" },
         "crews": [
           {
             "name": "frontend",
             "teammates": [
               { "name": "ui-dev", "branch": "feat/ui", "worktree": true, "role": "developer", "focus": "..." }
             ]
           },
           {
             "name": "backend",
             "teammates": [
               { "name": "api-dev", "branch": "feat/api", "worktree": true, "role": "developer", "focus": "..." }
             ]
           }
         ]
       },
       "project": { "main_branch": "auto-detect" },
       "stale_after_hours": 4
     }
     ```
     Use grouped format when you have 4+ teammates that fit into logical sub-teams.
     CLI commands support `--crew <name>` to filter operations by crew group.
   - Auto-detect `main_branch` from git

**When to use decompose vs manual**:
- **Use decompose**: Large codebase, unclear module boundaries, want optimal parallelization
- **Use manual**: Small targeted changes, clear separation already known, specific teammate roles needed

**Deliverable**: Valid `.crew-config.json` and confirmed team composition

---

### Phase 2: SETUP

**Goal**: Create worktrees and prepare team state

**Step 1: Run crew start**
```bash
node $HOME/.claude/cck/bin/cck.js crew start [profile]
```
Or if cck is in PATH:
```bash
cck crew start [profile]
```

**Step 2: Read the generated lead prompt**

The lead prompt is saved at the path shown in the output. Read it:
```bash
cat ~/.claude/crew/{hash}/{profile}/lead-prompt.md
```

**Step 3: Parse the prompt**

Extract from the generated prompt:
- Team name (for TeamCreate)
- For each teammate: name, branch, worktree path, model, mode, subagent_type, full teammate prompt
- Task descriptions (focus areas)

**Step 4: Display team layout**
```
Worktrees created:
| Teammate | Branch | Worktree Path |
|----------|--------|---------------|
| alice | feature/auth | /project-feature--auth |
| bob | feature/tests | /project-feature--tests |
```

**Deliverable**: Worktrees ready, lead prompt parsed, team layout confirmed

---

### Phase 3: LAUNCH

**Goal**: Create team, tasks, and spawn all teammates

Execute these steps in order:

**Step 1: Create team**
```
TeamCreate(team_name="{team.name}")
```

**Step 2: Create tasks**
One task per teammate describing their focus area:
```
TaskCreate(
  subject="[teammate-name]: [brief focus]",
  description="[full focus description from config]",
  activeForm="[verb-ing form]"
)
```

**Step 3: Spawn ALL teammates in parallel**

CRITICAL: Spawn all teammates in a SINGLE message with multiple Task calls.

For each teammate, use the full prompt from the generated lead prompt:
```
Task(
  name="{teammate.name}",
  team_name="{team.name}",
  subagent_type="{resolved.subagent_type}",
  model="{resolved.model}",
  mode="{resolved.mode}",
  run_in_background=true,
  prompt="{full teammate prompt from lead-prompt.md}"
)
```

The teammate prompt includes:
- Identity (name, branch)
- Working directory (worktree path)
- Path rules table (CRITICAL — ensures teammate works in correct worktree)
- Focus area
- Task workflow instructions

**Step 4: Assign tasks**
```
TaskUpdate(taskId="N", owner="{teammate.name}")
```

**Deliverable**: All teammates spawned and working in parallel

---

### Phase 4: COORDINATE

**Goal**: Monitor, support, and wrap up

**Monitor progress**:
- Check `TaskList` periodically to see task status
- Teammates send messages when they complete work or hit blockers
- Respond to teammate messages with guidance or decisions

**Health Monitoring**:

Teammates can become unresponsive or crash. Use health monitoring to detect issues:

1. **Manual health checks**:
   ```bash
   cck crew doctor [profile]
   ```
   Displays health table showing each teammate's status, last activity, and recent commits.

2. **Automated monitoring protocol** (every 10-15 minutes):
   - If a teammate is silent for >10 minutes, send them a message:
     ```
     SendMessage(type="message", recipient="{name}", content="Status check: still working?")
     ```
   - Wait 2 minutes for response
   - If still no response, check their worktree:
     ```bash
     git -C {worktree_path} log --oneline -5
     git -C {worktree_path} status
     ```
   - If worktree shows no recent activity:
     - Teammate likely crashed
     - Re-spawn using stored spawn prompt (see below)

3. **Re-spawning crashed teammates**:
   - Spawn prompts are stored in team-state.json automatically
   - To re-spawn, use the same Task call with the stored prompt
   - The teammate will resume in the same worktree with context preserved

4. **Health status meanings**:
   - `active` (✓): Updated recently, working normally
   - `idle` (○): No recent updates but not yet stale, may be thinking
   - `unresponsive` (⚠): Stale beyond threshold, may need attention
   - `crashed` (✗): Worktree exists but no activity and very stale, needs re-spawn

**When teammates report completion**:
1. Check their commits:
   ```bash
   git -C {worktree_path} log --oneline -5
   ```
2. Optionally review their diff:
   ```bash
   git -C {worktree_path} diff {main_branch} --stat
   ```

**When ALL tasks are complete**:
1. Verify each branch has commits
2. **Run merge preview** to check for conflicts:
   ```bash
   cck crew merge-preview [profile]
   ```
3. Review the preview results:
   - **Clean merges** (✓): Can be auto-merged safely
   - **Conflicts** (✗): Will require manual resolution
   - **Overlapping changes**: Files modified by multiple teammates
4. Share preview results with user and recommend strategy:
   - If all clean: "All branches can merge cleanly. Proceed with merge?"
   - If conflicts: "N branches have conflicts. Options: (1) merge clean branches first, (2) resolve conflicts manually, (3) review with teammates"
5. **Execute merge** if user approves:
   ```bash
   cck crew merge [profile]
   ```
   Optional flags:
   - `--test`: Run tests after each merge (rollback on failure)
   - `--test-command="npm run test:ci"`: Custom test command
6. If merge fails with conflicts, guide user:
   ```bash
   git merge {branch}
   # Resolve conflicts manually
   git add .
   git commit
   ```
7. Shut down teammates:
   ```
   SendMessage(type="shutdown_request", recipient="{name}", content="Work complete, shutting down.")
   ```
8. Clean up worktrees:
   ```bash
   cck crew stop [profile] --cleanup
   ```
9. Remove `.crew-config.json` if it was created for this session only

**Deliverable**: All work merged, teammates shut down, worktrees cleaned

---

## Role Presets Reference

Roles set sensible defaults. Explicit fields in config always override role defaults.

| Role | Model | Mode | Focus Default |
|------|-------|------|---------------|
| `developer` | sonnet | bypassPermissions | Implement features, write code, fix bugs |
| `reviewer` | sonnet | default | Review code for bugs, security, quality. Read-only |
| `tester` | haiku | bypassPermissions | Write and run tests, ensure coverage |
| `architect` | opus | default | Design architecture, review patterns. Read-only |

---

## Config Formats

**Single team (simple)**:
```json
{
  "team": {
    "name": "my-team",
    "teammates": [
      { "name": "alice", "branch": "feat/auth", "worktree": true, "role": "developer", "focus": "Build auth" }
    ]
  },
  "project": { "main_branch": "main" }
}
```

**Multiple profiles (advanced)**:
```json
{
  "profiles": {
    "dev": {
      "name": "dev-team",
      "teammates": [
        { "name": "backend", "branch": "feat/api", "role": "developer", "focus": "API work" },
        { "name": "frontend", "branch": "feat/ui", "role": "developer", "focus": "UI work" }
      ]
    },
    "review": {
      "name": "reviewers",
      "teammates": [
        { "name": "reviewer", "branch": "main", "worktree": false, "role": "reviewer" }
      ]
    }
  },
  "default": "dev",
  "project": { "main_branch": "main" }
}
```

---

## Anti-Patterns

- **Don't use crew for single tasks** — Use Task tool directly for one-off sub-agents
- **Don't spawn sequentially** — Always spawn all teammates in a single message
- **Don't forget task assignment** — Teammates need TaskUpdate(owner=...) to know their work
- **Don't merge without verifying** — Check teammate commits before merging branches
- **Don't use worktrees for sub-agents** — Only crew teammates get worktrees. Regular Task tool agents work in the main project directory
- **Don't skip path rules** — Teammate prompts MUST include worktree path rules to prevent cross-worktree file access

---

## Success Criteria

- All 4 phases completed (not skipped)
- Config validated before launch
- All teammates spawned in parallel (single message)
- Tasks assigned to correct teammates
- Teammate work verified before merge
- Clean shutdown and worktree cleanup
