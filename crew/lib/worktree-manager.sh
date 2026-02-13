#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# Worktree Manager - Git worktree operations for Claude Crew
# ═══════════════════════════════════════════════════════════════════
#
# Manages git worktrees for teammate branch isolation.
# Each teammate with worktree: true gets their own working directory
# at {project-root}-{sanitized-branch-name}/.
#
# Functions exported for crew.sh:
#   setup_worktrees    - Create worktrees from crew.yaml
#   cleanup_worktrees  - Remove worktrees and prune references
#   show_team_status   - Display worktree + team state
#   get_worktree_path  - Query worktree path for a teammate name
#
# Dependencies: git, python3 (with pyyaml) OR yq
# ═══════════════════════════════════════════════════════════════════

# ─── State ────────────────────────────────────────────────────────
_CREW_STATE_DIR=""        # Set per-project in setup/cleanup
_WORKTREE_REGISTRY=""     # JSON metadata file path
_YAML_PARSER=""           # Detected parser: "python3" or "yq"

# ─── Logging ──────────────────────────────────────────────────────
_log() { echo "[crew:worktree] $*"; }
_err() { echo "[crew:worktree] ERROR: $*" >&2; }
_ok()  { echo "[crew:worktree] ✓ $*"; }
_warn() { echo "[crew:worktree] ⚠ $*" >&2; }

# ═══════════════════════════════════════════════════════════════════
# YAML Parsing
# ═══════════════════════════════════════════════════════════════════
# Tries python3+pyyaml first, then yq. Outputs shell-evaluable
# variables from a single parse call to minimize process spawning.

_detect_yaml_parser() {
    if python3 -c "import yaml" 2>/dev/null; then
        _YAML_PARSER="python3"
    elif command -v yq &>/dev/null; then
        _YAML_PARSER="yq"
    else
        _err "YAML parser required. Install one of:"
        _err "  pip3 install pyyaml   (recommended)"
        _err "  brew install yq"
        return 1
    fi
}

# Parse crew.yaml into shell-evaluable variable assignments.
# Output format: KEY=VALUE lines, one per field.
# Usage: eval "$(_parse_config "$config_file")"
_parse_config() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        _err "Config file not found: $config_file"
        return 1
    fi

    case "$_YAML_PARSER" in
        python3)
            python3 - "$config_file" << 'PYEOF'
import yaml, sys, shlex

with open(sys.argv[1]) as f:
    config = yaml.safe_load(f)

project = config.get("project", {})
team = config.get("team", {})
teammates = team.get("teammates", [])

# Shell-safe quoting via shlex
def sq(val):
    """Shell-quote a value safely."""
    if val is None:
        return "''"
    return shlex.quote(str(val))

print(f'CREW_PROJECT_ROOT={sq(project.get("root", "."))}')
print(f'CREW_MAIN_BRANCH={sq(project.get("main_branch", "main"))}')
print(f'CREW_TEAM_NAME={sq(team.get("name", "crew"))}')
print(f'CREW_TEAMMATE_COUNT={len(teammates)}')

for i, t in enumerate(teammates):
    print(f'CREW_MATE_NAME_{i}={sq(t.get("name", "unnamed"))}')
    print(f'CREW_MATE_BRANCH_{i}={sq(t.get("branch", "main"))}')
    print(f'CREW_MATE_WORKTREE_{i}={sq(str(t.get("worktree", False)).lower())}')
    print(f'CREW_MATE_MODEL_{i}={sq(t.get("model", "sonnet"))}')
    # Focus is multiline - escape newlines for shell
    focus = t.get("focus", "")
    print(f'CREW_MATE_FOCUS_{i}={sq(focus)}')
PYEOF
            ;;
        yq)
            # yq-based parsing: extract each field individually
            local root main_branch team_name count
            root=$(yq eval '.project.root // "."' "$config_file")
            main_branch=$(yq eval '.project.main_branch // "main"' "$config_file")
            team_name=$(yq eval '.team.name // "crew"' "$config_file")
            count=$(yq eval '.team.teammates | length' "$config_file")

            echo "CREW_PROJECT_ROOT='$root'"
            echo "CREW_MAIN_BRANCH='$main_branch'"
            echo "CREW_TEAM_NAME='$team_name'"
            echo "CREW_TEAMMATE_COUNT=$count"

            for i in $(seq 0 $((count - 1))); do
                echo "CREW_MATE_NAME_${i}='$(yq eval ".team.teammates[$i].name // \"unnamed\"" "$config_file")'"
                echo "CREW_MATE_BRANCH_${i}='$(yq eval ".team.teammates[$i].branch // \"main\"" "$config_file")'"
                echo "CREW_MATE_WORKTREE_${i}='$(yq eval ".team.teammates[$i].worktree // false" "$config_file")'"
                echo "CREW_MATE_MODEL_${i}='$(yq eval ".team.teammates[$i].model // \"sonnet\"" "$config_file")'"
                echo "CREW_MATE_FOCUS_${i}='$(yq eval ".team.teammates[$i].focus // \"\"" "$config_file")'"
            done
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════
# Git Worktree Operations
# ═══════════════════════════════════════════════════════════════════

# Sanitize branch name for filesystem use.
# Uses -- for / to avoid collisions (feature-api vs feature/api).
# feature/backend-api → feature--backend-api
_sanitize_branch() {
    echo "$1" | sed 's|/|--|g; s|[^a-zA-Z0-9._-]|_|g'
}

# Compute worktree path: {project-root}-{sanitized-branch}
_worktree_path_for() {
    local project_root="$1"
    local branch="$2"
    echo "${project_root}-$(_sanitize_branch "$branch")"
}

# Validate that a directory is a git repository.
_validate_git_repo() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        _err "Directory does not exist: $dir"
        return 1
    fi
    if ! git -C "$dir" rev-parse --git-dir &>/dev/null; then
        _err "Not a git repository: $dir"
        return 1
    fi
}

# Create a single git worktree for a teammate.
_create_worktree() {
    local project_root="$1"
    local main_branch="$2"
    local teammate_name="$3"
    local branch="$4"

    local worktree_path
    worktree_path=$(_worktree_path_for "$project_root" "$branch")

    _log "Creating worktree: $teammate_name → $branch"
    _log "  Path: $worktree_path"

    # If worktree directory already exists, check if it's a valid worktree
    if [[ -d "$worktree_path" ]]; then
        if git -C "$project_root" worktree list --porcelain | grep -q "worktree $worktree_path"; then
            _log "  Worktree already exists, reusing"
        else
            _err "Directory exists but is not a git worktree: $worktree_path"
            _err "  Remove it manually or choose a different branch name"
            return 1
        fi
    else
        # Determine branch source and create worktree
        if git -C "$project_root" show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
            # Branch exists locally - check divergence from main
            local behind
            behind=$(git -C "$project_root" rev-list --count "refs/heads/${branch}..refs/heads/${main_branch}" 2>/dev/null || echo "0")
            if [[ "$behind" -gt 100 ]]; then
                _warn "Branch '$branch' is $behind commits behind '$main_branch'. Consider rebasing."
            fi
            git -C "$project_root" worktree add "$worktree_path" "$branch" 2>&1 || {
                _err "Failed to create worktree at $worktree_path"
                return 1
            }
        elif git -C "$project_root" show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null; then
            # Branch exists on remote but not locally
            _log "  Tracking remote branch 'origin/$branch'"
            git -C "$project_root" worktree add --track -b "$branch" "$worktree_path" "origin/$branch" 2>&1 || {
                _err "Failed to create worktree from remote branch"
                return 1
            }
        else
            # Branch doesn't exist anywhere - create from main
            _log "  Creating new branch '$branch' from '$main_branch'"
            git -C "$project_root" worktree add -b "$branch" "$worktree_path" "$main_branch" 2>&1 || {
                _err "Failed to create worktree with new branch"
                return 1
            }
        fi
    fi

    # Setup hybrid .claude/ directory (shared tools, isolated session state)
    _setup_claude_dir "$project_root" "$worktree_path"

    # Write crew identity marker for Capsule hooks
    # This file is LOCAL to the worktree (not symlinked), so each
    # teammate gets their own identity for namespace scoping.
    local identity_file="$worktree_path/.claude/crew-identity.json"
    cat > "$identity_file" << EOF
{
  "teammate_name": "$teammate_name",
  "project_root": "$project_root",
  "branch": "$branch",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    _log "  Crew identity written: $identity_file"

    # Register in metadata
    _register_worktree "$teammate_name" "$branch" "$worktree_path"

    _ok "Worktree ready: $teammate_name ($branch)"
}

# Remove a single worktree safely.
# CRITICAL: removes .claude symlink BEFORE removing directory
# to prevent following the symlink and deleting source .claude/.
_remove_worktree() {
    local project_root="$1"
    local teammate_name="$2"
    local branch="$3"
    local worktree_path="$4"

    _log "Removing worktree: $teammate_name ($branch)"

    if [[ ! -d "$worktree_path" ]]; then
        _warn "Worktree directory not found: $worktree_path (already removed?)"
        return 0
    fi

    # SAFETY: Clean up .claude/ FIRST (removes symlinks before directory removal)
    # Handles both legacy full-symlink and hybrid setups.
    _cleanup_claude_dir "$worktree_path"

    # Remove the worktree via git
    if git -C "$project_root" worktree remove "$worktree_path" --force 2>/dev/null; then
        _ok "Removed worktree: $teammate_name"
    else
        _warn "git worktree remove failed, cleaning up manually"
        rm -rf "$worktree_path"
        git -C "$project_root" worktree prune
        _ok "Manually removed: $teammate_name"
    fi
}

# ═══════════════════════════════════════════════════════════════════
# .claude/ Hybrid Symlink Management
# ═══════════════════════════════════════════════════════════════════
# Creates a REAL .claude/ directory in the worktree, then selectively
# symlinks read-only/safe-to-share subdirectories from the main repo.
# Session state files (capsule.toon, logs) remain LOCAL to each
# worktree, preventing concurrent-write hazards between agents.
#
# Shared (symlinked):  hooks, tools, agents, commands, docs, lib, memory
# Isolated (local):    capsule.toon, session_files.log, session_discoveries.log,
#                      subagent_results.log, message_count.txt, capsule_persist.json

# Directories safe to share (read-only or append-only with distinct files)
_SHARED_DIRS=(hooks tools agents commands docs lib memory worktree-config)
# Config files safe to share (read-only at runtime)
_SHARED_FILES=(settings.local.json settings.json)

_setup_claude_dir() {
    local source_root="$1"
    local worktree_path="$2"
    local claude_source="$source_root/.claude"
    local claude_target="$worktree_path/.claude"

    if [[ ! -d "$claude_source" ]]; then
        _log "  No .claude/ in project root, skipping"
        return 0
    fi

    # If worktree has a full .claude/ symlink (legacy), remove it
    if [[ -L "$claude_target" ]]; then
        _log "  Removing legacy full .claude/ symlink"
        rm "$claude_target"
    fi

    # If worktree has its own .claude/ dir (from git checkout), back it up
    if [[ -d "$claude_target" ]]; then
        # Check if it looks like our hybrid setup (has symlinks inside)
        local has_our_symlinks=false
        for dir in "${_SHARED_DIRS[@]}"; do
            if [[ -L "$claude_target/$dir" ]]; then
                has_our_symlinks=true
                break
            fi
        done

        if [[ "$has_our_symlinks" == "true" ]]; then
            _log "  Hybrid .claude/ already set up, verifying symlinks"
        else
            _log "  Backing up existing .claude/ in worktree"
            mv "$claude_target" "${claude_target}.bak"
        fi
    fi

    # Create the real .claude/ directory
    mkdir -p "$claude_target"

    # Symlink shared directories (read-only / safe for concurrent access)
    for dir in "${_SHARED_DIRS[@]}"; do
        if [[ -d "$claude_source/$dir" ]]; then
            if [[ -L "$claude_target/$dir" ]]; then
                # Already a symlink - verify it points to the right place
                local current
                current=$(readlink "$claude_target/$dir")
                if [[ "$current" != "$claude_source/$dir" ]]; then
                    rm "$claude_target/$dir"
                    ln -sfn "$claude_source/$dir" "$claude_target/$dir"
                fi
            else
                ln -sfn "$claude_source/$dir" "$claude_target/$dir"
            fi
        fi
    done

    # Symlink shared config files
    for file in "${_SHARED_FILES[@]}"; do
        if [[ -f "$claude_source/$file" ]]; then
            ln -sfn "$claude_source/$file" "$claude_target/$file"
        fi
    done

    # Session state files are NOT symlinked - they stay local to
    # each worktree so concurrent agents don't corrupt each other's
    # capsule.toon, session_files.log, message_count.txt, etc.

    _log "  Hybrid .claude/ setup complete (shared: ${#_SHARED_DIRS[@]} dirs, isolated: session state)"
}

# Clean up .claude/ in a worktree before removal.
# Handles both legacy full-symlink and hybrid setups.
_cleanup_claude_dir() {
    local worktree_path="$1"
    local claude_target="$worktree_path/.claude"

    if [[ ! -e "$claude_target" && ! -L "$claude_target" ]]; then
        return 0
    fi

    if [[ -L "$claude_target" ]]; then
        # Legacy: entire .claude/ is a symlink - just remove it
        rm "$claude_target"
        _log "  Removed legacy .claude symlink"
    elif [[ -d "$claude_target" ]]; then
        # Hybrid: real directory with symlinks inside
        # Remove symlinks first (safety: never follows into source)
        find "$claude_target" -maxdepth 1 -type l -delete 2>/dev/null
        # Remove remaining local files (session logs, capsule, etc.)
        rm -rf "$claude_target"
        _log "  Removed hybrid .claude/ directory"
    fi

    # Restore backup if we made one
    if [[ -d "${claude_target}.bak" ]]; then
        mv "${claude_target}.bak" "$claude_target"
        _log "  Restored original .claude/ from backup"
    fi
}

# ═══════════════════════════════════════════════════════════════════
# Metadata Registry
# ═══════════════════════════════════════════════════════════════════
# Tracks created worktrees in a JSON file for reliable cleanup.
# Uses python3 for JSON operations (safe, no jq dependency).

_init_state_dir() {
    local project_root="$1"
    _CREW_STATE_DIR="$project_root/.claude/crew"
    _WORKTREE_REGISTRY="$_CREW_STATE_DIR/worktrees.json"
    mkdir -p "$_CREW_STATE_DIR"
}

_init_registry() {
    echo '{"worktrees":[],"created_at":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}' > "$_WORKTREE_REGISTRY"
}

_register_worktree() {
    local name="$1"
    local branch="$2"
    local path="$3"
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    if [[ "$_YAML_PARSER" == "python3" ]]; then
        python3 - "$_WORKTREE_REGISTRY" "$name" "$branch" "$path" "$timestamp" << 'PYEOF'
import json, sys

registry_path, name, branch, wt_path, ts = sys.argv[1:6]

with open(registry_path) as f:
    registry = json.load(f)

# Avoid duplicates (idempotent registration)
existing = [w for w in registry["worktrees"] if w["name"] == name]
if not existing:
    registry["worktrees"].append({
        "name": name,
        "branch": branch,
        "path": wt_path,
        "created_at": ts
    })

with open(registry_path, "w") as f:
    json.dump(registry, f, indent=2)
PYEOF
    else
        # Fallback: append a simple line-based format
        echo "$name|$branch|$path|$timestamp" >> "${_WORKTREE_REGISTRY}.txt"
    fi
}

# Read all registered worktrees as tab-separated lines.
# Output: name\tbranch\tpath  (one per line)
_read_registry() {
    local registry="$1"

    if [[ ! -f "$registry" ]]; then
        return 0
    fi

    if [[ "$_YAML_PARSER" == "python3" ]]; then
        python3 - "$registry" << 'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    registry = json.load(f)

for w in registry["worktrees"]:
    print(f"{w['name']}\t{w['branch']}\t{w['path']}")
PYEOF
    else
        # Fallback: read line-based format
        if [[ -f "${registry}.txt" ]]; then
            while IFS='|' read -r name branch path _ts; do
                echo "$name\t$branch\t$path"
            done < "${registry}.txt"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════
# Public API
# ═══════════════════════════════════════════════════════════════════

# setup_worktrees CONFIG_FILE
# Main orchestrator: parse config, create all worktrees, symlink .claude/.
setup_worktrees() {
    local config_file="$1"

    _log "═══ Claude Crew Worktree Setup ═══"

    # Detect YAML parser
    _detect_yaml_parser || return 1

    # Parse configuration
    local config_output
    config_output=$(_parse_config "$config_file") || return 1
    eval "$config_output"

    # Resolve project root to absolute path
    if [[ "$CREW_PROJECT_ROOT" != /* ]]; then
        CREW_PROJECT_ROOT="$(cd "$(dirname "$config_file")" && cd "$CREW_PROJECT_ROOT" && pwd)"
    fi

    # Validate git repo
    _validate_git_repo "$CREW_PROJECT_ROOT" || return 1

    # Check for uncommitted changes (warning only)
    if ! git -C "$CREW_PROJECT_ROOT" diff-index --quiet HEAD -- 2>/dev/null; then
        _warn "Working tree has uncommitted changes"
        _warn "Worktrees will branch from the last commit, not uncommitted work"
    fi

    # Initialize state
    _init_state_dir "$CREW_PROJECT_ROOT"
    _init_registry

    _log "Team: $CREW_TEAM_NAME"
    _log "Project: $CREW_PROJECT_ROOT"
    _log "Main branch: $CREW_MAIN_BRANCH"
    _log "Teammates: $CREW_TEAMMATE_COUNT"
    echo ""

    # Create worktrees for each teammate that needs one
    local created=0
    local failed=0
    for i in $(seq 0 $((CREW_TEAMMATE_COUNT - 1))); do
        local name_var="CREW_MATE_NAME_$i"
        local branch_var="CREW_MATE_BRANCH_$i"
        local worktree_var="CREW_MATE_WORKTREE_$i"

        local name="${!name_var}"
        local branch="${!branch_var}"
        local needs_worktree="${!worktree_var}"

        if [[ "$needs_worktree" != "true" ]]; then
            _log "Skipping $name (worktree: false)"
            continue
        fi

        if _create_worktree "$CREW_PROJECT_ROOT" "$CREW_MAIN_BRANCH" "$name" "$branch"; then
            created=$((created + 1))
        else
            failed=$((failed + 1))
        fi
        echo ""
    done

    echo ""
    _log "═══ Setup Complete ═══"
    _ok "$created worktrees created"
    if [[ $failed -gt 0 ]]; then
        _err "$failed worktrees failed"
        return 1
    fi

    # Print summary
    echo ""
    _log "Worktree registry: $_WORKTREE_REGISTRY"
    show_team_status
}

# cleanup_worktrees CONFIG_FILE
# Remove all worktrees tracked in the registry.
cleanup_worktrees() {
    local config_file="$1"

    _log "═══ Claude Crew Worktree Cleanup ═══"

    # Detect YAML parser
    _detect_yaml_parser || return 1

    # Parse config to get project root
    local config_output
    config_output=$(_parse_config "$config_file") || return 1
    eval "$config_output"

    # Resolve project root
    if [[ "$CREW_PROJECT_ROOT" != /* ]]; then
        CREW_PROJECT_ROOT="$(cd "$(dirname "$config_file")" && cd "$CREW_PROJECT_ROOT" && pwd)"
    fi

    _init_state_dir "$CREW_PROJECT_ROOT"

    if [[ ! -f "$_WORKTREE_REGISTRY" ]]; then
        _warn "No worktree registry found at $_WORKTREE_REGISTRY"
        _warn "Nothing to clean up. Run 'crew setup' first."
        return 0
    fi

    # Read registry and remove each worktree
    local removed=0
    while IFS=$'\t' read -r name branch path; do
        [[ -z "$name" ]] && continue
        _remove_worktree "$CREW_PROJECT_ROOT" "$name" "$branch" "$path"
        removed=$((removed + 1))
    done < <(_read_registry "$_WORKTREE_REGISTRY")

    # Prune any stale worktree references
    git -C "$CREW_PROJECT_ROOT" worktree prune 2>/dev/null

    # Clean up registry
    rm -f "$_WORKTREE_REGISTRY"
    _log "Removed worktree registry"

    echo ""
    _ok "$removed worktrees removed and cleaned up"
}

# show_team_status
# Display current worktree and team state.
show_team_status() {
    echo ""
    echo "═══ Claude Crew ─ Team Status ═══"
    echo ""

    # Find project root from crew state
    local state_dir=""
    local project_root=""

    # Search up from current directory
    local search_dir="$PWD"
    while [[ "$search_dir" != "/" ]]; do
        if [[ -f "$search_dir/.claude/crew/worktrees.json" ]]; then
            state_dir="$search_dir/.claude/crew"
            project_root="$search_dir"
            break
        fi
        search_dir="$(dirname "$search_dir")"
    done

    if [[ -z "$state_dir" ]]; then
        echo "  No crew state found. Run 'crew setup' first."
        echo ""
        return 0
    fi

    # Show registered worktrees
    echo "  Teammates:"
    if [[ -f "$state_dir/worktrees.json" ]]; then
        python3 - "$state_dir/worktrees.json" << 'PYEOF' 2>/dev/null || {
import json, sys, os

with open(sys.argv[1]) as f:
    registry = json.load(f)

if not registry["worktrees"]:
    print("    (none registered)")
    sys.exit(0)

for w in registry["worktrees"]:
    exists = "●" if os.path.isdir(w["path"]) else "○"
    print(f"    {exists} {w['name']:<25s} branch: {w['branch']:<30s}")
    print(f"      path: {w['path']}")
PYEOF
            echo "    (could not read registry)"
        }
    fi

    # Show git worktree list for completeness
    echo ""
    echo "  Git Worktrees:"
    git -C "$project_root" worktree list 2>/dev/null | while IFS= read -r line; do
        echo "    $line"
    done

    echo ""
}

# get_worktree_path TEAMMATE_NAME [REGISTRY_PATH]
# Query the worktree path for a given teammate.
# Returns the path on stdout, exits 1 if not found.
get_worktree_path() {
    local teammate_name="$1"
    local registry="${2:-$_WORKTREE_REGISTRY}"

    if [[ ! -f "$registry" ]]; then
        _err "No registry at $registry"
        return 1
    fi

    python3 - "$registry" "$teammate_name" << 'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    registry = json.load(f)

for w in registry["worktrees"]:
    if w["name"] == sys.argv[2]:
        print(w["path"])
        sys.exit(0)

sys.exit(1)
PYEOF
}

# get_all_worktree_paths [REGISTRY_PATH]
# Output all worktree paths, one per line.
# Format: name\tpath
get_all_worktree_paths() {
    local registry="${1:-$_WORKTREE_REGISTRY}"

    if [[ ! -f "$registry" ]]; then
        return 0
    fi

    python3 - "$registry" << 'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    registry = json.load(f)

for w in registry["worktrees"]:
    print(f"{w['name']}\t{w['path']}")
PYEOF
}
