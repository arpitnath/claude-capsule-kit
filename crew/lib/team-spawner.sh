#!/bin/bash
# Team Spawner - Agent Teams integration for Claude Crew
#
# Generates Agent Teams configurations from crew.yaml and launches
# Claude Code with instruction-based worktree assignment.
#
# Flow:
#   1. Parse crew.yaml → JSON (via PyYAML or yq)
#   2. Generate teammate spawn prompts (with worktree path rules)
#   3. Generate lead prompt (team creation + spawn instructions)
#   4. Optionally set up visual layout (tmux/iTerm2)
#   5. Launch claude CLI with the lead prompt
#
# Design: "Instruction-based" approach (Option E+ from AGENT_TEAMS_WORKTREE_MODE.md)
#   - No hooks or path rewriting needed
#   - Each teammate's prompt contains explicit absolute worktree paths
#   - ~90-95% path compliance via LLM instruction following

# ─── Config Parsing ─────────────────────────────────────────────────────
# Strategy: Convert YAML→JSON once, then extract fields via Python3 json (stdlib).
# YAML parsing requires PyYAML or yq - JSON extraction uses only Python3 stdlib.

# Cached JSON representation of crew.yaml
_CREW_JSON=""

# Convert YAML file to JSON string
# Tries PyYAML first, then yq, then fails with install instructions
_yaml_to_json() {
    local config_file="$1"

    # Try 1: Python3 + PyYAML (most common on dev machines)
    if python3 -c "
import yaml, json, sys
with open(sys.argv[1]) as f:
    print(json.dumps(yaml.safe_load(f), ensure_ascii=False))
" "$config_file" 2>/dev/null; then
        return 0
    fi

    # Try 2: yq (popular YAML CLI tool)
    if command -v yq &>/dev/null; then
        yq -o json "$config_file" 2>/dev/null && return 0
    fi

    echo "Error: YAML parsing requires python3+PyYAML or yq" >&2
    echo "Install one of:" >&2
    echo "  pip3 install pyyaml" >&2
    echo "  brew install yq" >&2
    return 1
}

# Load crew.yaml into cached JSON
_load_config() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        echo "Error: Config file not found: $config_file" >&2
        echo "Create one from the example: crew/examples/crew.yaml" >&2
        return 1
    fi

    _CREW_JSON=$(_yaml_to_json "$config_file") || return 1

    if [[ -z "$_CREW_JSON" || "$_CREW_JSON" == "null" ]]; then
        echo "Error: Failed to parse config (empty result)" >&2
        return 1
    fi
}

# Extract a value from cached JSON using dot-path notation
# Usage: _config_get ".project.root"  or  _config_get ".team.teammates[0].name"
_config_get() {
    local path="$1"
    python3 -c "
import json, re, sys
data = json.loads(sys.argv[1])
parts = []
for m in re.finditer(r'\.(\w+)|\[(\d+)\]', sys.argv[2]):
    parts.append(m.group(1) if m.group(1) else int(m.group(2)))
try:
    for p in parts:
        data = data[p]
    if isinstance(data, bool):
        print('true' if data else 'false')
    elif isinstance(data, (dict, list)):
        print(json.dumps(data, ensure_ascii=False))
    elif data is not None:
        print(data)
except (KeyError, IndexError, TypeError):
    pass
" "$_CREW_JSON" "$path"
}

# Get the number of teammates in the config
_teammate_count() {
    python3 -c "
import json, sys
data = json.loads(sys.argv[1])
print(len(data.get('team', {}).get('teammates', [])))
" "$_CREW_JSON"
}

# ─── Path Utilities ─────────────────────────────────────────────────────

# Sanitize a branch name for filesystem use
# feature/backend-api → feature-backend-api
_sanitize_branch() {
    echo "$1" | tr '/' '-' | tr ' ' '-' | tr -cd 'a-zA-Z0-9._-'
}

# Compute worktree directory from project root and branch
# Convention matches worktree-manager.sh: {project_root}-{sanitized_branch}
_worktree_path() {
    local project_root="$1" branch="$2"
    echo "${project_root}-$(_sanitize_branch "$branch")"
}

# ─── Prompt Generation ──────────────────────────────────────────────────

# Generate the spawn prompt for one teammate.
# This prompt is what the lead passes to the Task tool's `prompt` parameter.
# It contains explicit worktree path rules (the "instruction-based" approach).
_generate_teammate_prompt() {
    local name="$1"
    local branch="$2"
    local worktree_path="$3"
    local focus="$4"
    local project_root="$5"

    # Substitute template variables in focus text
    local resolved_focus="${focus//\{WORKTREE_PATH\}/$worktree_path}"
    resolved_focus="${resolved_focus//\{PROJECT_ROOT\}/$project_root}"
    resolved_focus="${resolved_focus//\{TEAMMATE_NAME\}/$name}"

    cat << PROMPT_EOF
You are **${name}**, a teammate working on branch \`${branch}\`.

## CRITICAL: Worktree Path Rules

Your isolated worktree is at: \`${worktree_path}\`

**Every file operation MUST use absolute paths under your worktree:**

| Tool | Correct | Wrong |
|------|---------|-------|
| Read/Write/Edit | \`${worktree_path}/src/...\` | \`src/...\` or \`${project_root}/src/...\` |
| Glob | \`path="${worktree_path}"\` | \`path="${project_root}"\` |
| Grep | \`path="${worktree_path}"\` | omitting path |
| Bash (git) | \`cd ${worktree_path} && git ...\` | \`git ...\` |
| Bash (other) | \`cd ${worktree_path} && ...\` | running in wrong directory |

**NEVER operate in \`${project_root}\`** — that is the lead's main branch.

Before ANY file operation, verify the absolute path starts with \`${worktree_path}\`.

## Your Focus

${resolved_focus}
## Available Tools & Workflows

- **Workflows**: \`/workflow\` (systematic multi-step), \`/debug\` (error RCA), \`/deep-context\` (codebase understanding)
- **Sub-agents**: error-detective, architecture-explorer, refactoring-specialist, code-reviewer, debugger
- **Analysis**: Run \`query-deps\` and \`impact-analysis\` from your worktree

## Task Workflow

1. Check \`TaskList\` for your assignments
2. Claim tasks with \`TaskUpdate\` (set owner to "${name}")
3. Work exclusively in your worktree (\`${worktree_path}\`)
4. Send progress updates to team lead via \`SendMessage\`
5. Mark tasks \`completed\` when done, then check \`TaskList\` for next work
6. When blocked, message the team lead immediately
PROMPT_EOF
}

# Generate the lead's comprehensive orchestration prompt.
# This is the initial prompt passed to `claude` that tells it to:
#   1. Create the team (TeamCreate)
#   2. Create tasks (TaskCreate)
#   3. Spawn each teammate (Task tool) with their worktree-aware prompt
#   4. Coordinate work (TaskList, SendMessage)
_generate_lead_prompt() {
    local team_name="$1"
    local project_root="$2"
    local lead_branch="$3"
    local teammate_count
    teammate_count=$(_teammate_count)

    # --- Header ---
    cat << LEAD_HEADER
# Claude Crew — Team Lead Instructions

You are the **team lead** for the "${team_name}" team.
Your working directory is \`${project_root}\` (branch: \`${lead_branch}\`).

Follow these steps IN ORDER to set up and coordinate the team.

---

## Step 1: Create the Team

\`\`\`
TeamCreate(team_name="${team_name}", description="Parallel development team with worktree-isolated branches")
\`\`\`

---

## Step 2: Create Tasks

Create tasks for each piece of work using \`TaskCreate\`. Give each task:
- A clear imperative subject (e.g., "Implement user authentication")
- A detailed description with acceptance criteria
- An \`activeForm\` for progress tracking (e.g., "Implementing user authentication")

---

## Step 3: Spawn Teammates

Spawn each teammate below using the \`Task\` tool. Use the EXACT prompt text between the ═══ markers as the \`prompt\` parameter.

LEAD_HEADER

    # --- Per-teammate spawn sections ---
    for ((i = 0; i < teammate_count; i++)); do
        local t_name t_branch t_model t_worktree t_focus wt_path t_prompt

        t_name=$(_config_get ".team.teammates[$i].name")
        t_branch=$(_config_get ".team.teammates[$i].branch")
        t_model=$(_config_get ".team.teammates[$i].model")
        t_worktree=$(_config_get ".team.teammates[$i].worktree")
        t_focus=$(_config_get ".team.teammates[$i].focus")

        # Defaults
        [[ -z "$t_model" ]] && t_model="sonnet"
        [[ -z "$t_focus" ]] && t_focus="Work on your assigned tasks."

        # Compute worktree path
        if [[ "$t_worktree" == "true" ]]; then
            wt_path=$(_worktree_path "$project_root" "$t_branch")
        else
            wt_path="$project_root"
        fi

        # Generate this teammate's spawn prompt
        t_prompt=$(_generate_teammate_prompt "$t_name" "$t_branch" "$wt_path" "$t_focus" "$project_root")

        cat << TEAMMATE_SECTION

### Teammate $((i + 1)): ${t_name}

| Field | Value |
|-------|-------|
| name | \`${t_name}\` |
| branch | \`${t_branch}\` |
| worktree | \`${wt_path}\` |
| model | \`${t_model}\` |
| subagent_type | \`general-purpose\` |

**Spawn with Task tool:**
\`\`\`
Task(
    subagent_type = "general-purpose",
    name          = "${t_name}",
    team_name     = "${team_name}",
    model         = "${t_model}",
    description   = "Spawn ${t_name}",
    prompt        = "<prompt below>"
)
\`\`\`

═══ PROMPT START for ${t_name} ═══
${t_prompt}
═══ PROMPT END for ${t_name} ═══

TEAMMATE_SECTION
    done

    # --- Coordination instructions ---
    cat << LEAD_FOOTER

---

## Step 4: Assign Tasks

After spawning all teammates, assign tasks using \`TaskUpdate\`:
\`\`\`
TaskUpdate(taskId="<id>", owner="<teammate-name>")
\`\`\`

---

## Step 5: Coordinate

- **Monitor progress**: Use \`TaskList\` regularly to check status
- **Communicate**: Use \`SendMessage(type="message", recipient="<name>", ...)\` — always refer to teammates by NAME
- **Unblock**: If a teammate is stuck, message them with guidance or reassign the task
- **Review**: When teammates complete work, review their changes:
  \`\`\`
  Bash("cd <worktree-path> && git log --oneline -5")
  Bash("cd <worktree-path> && git diff HEAD~3")
  \`\`\`

## Step 6: Wrap Up

When all work is complete:
1. Review results in each worktree
2. Coordinate merges (teammates have committed to their branches)
3. Shutdown teammates: \`SendMessage(type="shutdown_request", recipient="<name>", content="Work complete")\`
4. Clean up: \`TeamDelete()\`
5. Worktree cleanup is handled by \`crew cleanup\` (outside this session)

---

**Important reminders:**
- Teammates work in ISOLATED worktrees — they will NOT modify your main branch
- Use \`TaskList\` after each major event to stay aware of progress
- Teammates can use \`/workflow\`, \`/debug\`, and spawn their own sub-agents
- Shared \`.claude/\` directory means discoveries are visible to all teammates
LEAD_FOOTER
}

# ─── Visual Mode ─────────────────────────────────────────────────────────

# Set up tmux layout: lead pane (left) + monitoring pane (right)
_setup_tmux() {
    local session_name="$1"
    local project_root="$2"

    if ! command -v tmux &>/dev/null; then
        echo "Warning: tmux not found, skipping visual mode" >&2
        return 1
    fi

    # Kill existing session with same name (if any)
    tmux kill-session -t "$session_name" 2>/dev/null || true

    # Create detached session — lead pane on the left
    tmux new-session -d -s "$session_name" -n "crew" -x 220 -y 50

    # Right pane (35% width): worktree monitoring
    tmux split-window -h -t "$session_name:crew" -p 35

    # Write a monitoring script to avoid complex quoting in tmux send-keys
    local monitor_script
    monitor_script=$(mktemp /tmp/crew-monitor-XXXXXX.sh)
    cat > "$monitor_script" << MONITOR_EOF
#!/bin/bash
watch -n 5 '
echo "══ Crew Worktree Status ══"
echo
git -C "$project_root" worktree list 2>/dev/null
echo
for wt in "$project_root"-*/; do
    [ -d "\$wt" ] && echo "── \$wt ──" && git -C "\$wt" log --oneline -3 2>/dev/null && echo
done
'
MONITOR_EOF
    chmod +x "$monitor_script"

    # Start monitoring in right pane
    tmux send-keys -t "$session_name:crew.1" "bash '$monitor_script'" Enter

    # Focus on lead pane (left)
    tmux select-pane -t "$session_name:crew.0"

    echo "$session_name"
}

# Set up iTerm2 split panes (macOS only, via AppleScript)
_setup_it2() {
    local project_root="$1"

    if [[ "$(uname)" != "Darwin" ]]; then
        echo "Warning: iTerm2 visual mode is macOS only" >&2
        return 1
    fi

    if ! osascript << APPLE_EOF 2>/dev/null
tell application "iTerm2"
    tell current session of current tab of current window
        set monitorSession to (split vertically with default profile)
        tell monitorSession
            write text "watch -n 5 'echo Crew Worktree Status; git -C \"${project_root}\" worktree list 2>/dev/null'"
        end tell
    end tell
end tell
APPLE_EOF
    then
        echo "Warning: iTerm2 scripting failed (is iTerm2 running?)" >&2
        return 1
    fi
}

# ─── Pre-flight Validation ──────────────────────────────────────────────

_validate_config() {
    local project_root="$1"
    local team_name="$2"
    local teammate_count="$3"
    local errors=0

    if [[ -z "$project_root" ]]; then
        echo "Error: project.root is required in config" >&2
        ((errors++))
    elif [[ ! -d "$project_root" ]]; then
        echo "Error: project.root directory does not exist: $project_root" >&2
        ((errors++))
    fi

    if [[ -z "$team_name" ]]; then
        echo "Error: team.name is required in config" >&2
        ((errors++))
    fi

    if [[ "$teammate_count" -lt 1 ]]; then
        echo "Error: At least one teammate is required in team.teammates" >&2
        ((errors++))
    fi

    # Validate each teammate has a name and branch
    for ((i = 0; i < teammate_count; i++)); do
        local t_name t_branch
        t_name=$(_config_get ".team.teammates[$i].name")
        t_branch=$(_config_get ".team.teammates[$i].branch")

        if [[ -z "$t_name" ]]; then
            echo "Error: teammates[$i] is missing required field: name" >&2
            ((errors++))
        fi
        if [[ -z "$t_branch" ]]; then
            echo "Error: teammates[$i] ($t_name) is missing required field: branch" >&2
            ((errors++))
        fi

        # Warn if worktree is true but worktree directory doesn't exist yet
        local t_worktree wt_path
        t_worktree=$(_config_get ".team.teammates[$i].worktree")
        if [[ "$t_worktree" == "true" ]]; then
            wt_path=$(_worktree_path "$project_root" "$t_branch")
            if [[ ! -d "$wt_path" ]]; then
                echo "Note: Worktree not yet created for $t_name: $wt_path" >&2
                echo "      Run 'crew setup' first to create worktrees." >&2
            fi
        fi
    done

    return $errors
}

# ─── Launch ──────────────────────────────────────────────────────────────

launch_team() {
    local config_file="$1"

    echo "══════════════════════════════════════"
    echo "  Claude Crew — Agent Teams Launcher"
    echo "══════════════════════════════════════"
    echo ""

    # --- Dependency check ---
    if ! command -v python3 &>/dev/null; then
        echo "Error: python3 is required" >&2
        exit 1
    fi
    if ! command -v claude &>/dev/null; then
        echo "Error: claude CLI is required (https://docs.anthropic.com/en/docs/claude-code)" >&2
        exit 1
    fi

    # --- Load config ---
    _load_config "$config_file" || exit 1

    # --- Extract top-level config ---
    local project_root main_branch team_name lead_branch lead_model
    local visual_mode teammate_count

    project_root=$(_config_get ".project.root")
    main_branch=$(_config_get ".project.main_branch")
    team_name=$(_config_get ".team.name")
    lead_branch=$(_config_get ".team.lead.branch")
    lead_model=$(_config_get ".team.lead.model")
    visual_mode=$(_config_get ".visual.mode")
    teammate_count=$(_teammate_count)

    # Defaults
    [[ -z "$main_branch" ]] && main_branch="main"
    [[ -z "$lead_branch" ]] && lead_branch="$main_branch"
    [[ -z "$lead_model" ]] && lead_model="sonnet"

    # --- Validate ---
    _validate_config "$project_root" "$team_name" "$teammate_count" || exit 1

    # --- Summary ---
    echo "  Project:    $project_root"
    echo "  Team:       $team_name"
    echo "  Lead:       $lead_branch (model: $lead_model)"
    echo "  Teammates:  $teammate_count"
    for ((i = 0; i < teammate_count; i++)); do
        local t_name t_branch t_worktree wt_display
        t_name=$(_config_get ".team.teammates[$i].name")
        t_branch=$(_config_get ".team.teammates[$i].branch")
        t_worktree=$(_config_get ".team.teammates[$i].worktree")
        wt_display=""
        if [[ "$t_worktree" == "true" ]]; then
            wt_display=" → $(_worktree_path "$project_root" "$t_branch")"
        fi
        echo "    $((i + 1)). $t_name ($t_branch)$wt_display"
    done
    echo "  Visual:     ${visual_mode:-none}"
    echo ""

    # --- Generate lead prompt ---
    local lead_prompt prompt_file
    lead_prompt=$(_generate_lead_prompt "$team_name" "$project_root" "$lead_branch")

    prompt_file=$(mktemp "/tmp/crew-${team_name}-lead-XXXXXX.md")
    echo "$lead_prompt" > "$prompt_file"
    echo "  Lead prompt: $prompt_file"
    echo ""

    # --- Visual mode setup ---
    local tmux_session=""
    case "$visual_mode" in
        tmux-split|tmux)
            tmux_session=$(_setup_tmux "crew-${team_name}" "$project_root")
            if [[ -n "$tmux_session" ]]; then
                echo "  tmux session: $tmux_session"
                echo ""

                # Launch claude in the lead pane, reading prompt from file
                # Using cat to avoid shell argument length issues with long prompts
                tmux send-keys -t "${tmux_session}:crew.0" \
                    "cd '$project_root' && claude \"\$(cat '$prompt_file')\"" Enter

                echo "══════════════════════════════════════"
                echo "  Attach with:  tmux attach -t $tmux_session"
                echo "══════════════════════════════════════"
                return 0
            fi
            # Fall through to direct launch if tmux setup failed
            echo "  Falling back to direct launch..." >&2
            ;;

        it2-split|it2|iterm2)
            _setup_it2 "$project_root"
            # iTerm2 mode: launch claude in the current pane (left)
            ;;
    esac

    # --- Direct launch (no tmux, or it2 mode, or fallback) ---
    echo "══════════════════════════════════════"
    echo "  Launching Claude Code as team lead..."
    echo "══════════════════════════════════════"
    echo ""

    cd "$project_root" && exec claude "$(cat "$prompt_file")"
}
