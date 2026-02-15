#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract current working directory from JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir')

# Change to the working directory for git commands
cd "$cwd" 2>/dev/null || cd "$HOME"

# Get directory path with home substitution
dir_path="${PWD/#$HOME/~}"

# --- Config: load section visibility ---
config_file="$HOME/.claude/statusline-config.json"
cfg_model=true; cfg_duration=true; cfg_context=true
cfg_worktree=true; cfg_crew=true; cfg_capsule_pill=true
cfg_compact_threshold=85
if [ -f "$config_file" ]; then
    _cfg_val() { jq -r "if has(\"$1\") then .$1 else true end" "$config_file" 2>/dev/null; }
    cfg_model=$(_cfg_val model)
    cfg_duration=$(_cfg_val duration)
    cfg_context=$(_cfg_val context)
    cfg_worktree=$(_cfg_val worktree)
    cfg_crew=$(_cfg_val crew)
    cfg_capsule_pill=$(_cfg_val capsule_pill)
    ct=$(jq -r 'if has("compact_threshold") then .compact_threshold else 85 end' "$config_file" 2>/dev/null)
    [ -n "$ct" ] && [ "$ct" != "null" ] && cfg_compact_threshold=$ct
fi

# --- Colors ---
C_RESET='\033[0m'
C_TEAL='\033[38;5;116m'
C_LAVENDER='\033[38;5;183m'
C_ORANGE='\033[38;5;214m'
C_GREEN='\033[38;5;114m'
C_YELLOW='\033[38;5;221m'
C_RED='\033[38;5;203m'
C_CYAN='\033[38;5;117m'
C_DIM='\033[38;5;245m'
C_SEPARATOR='\033[38;5;240m'
C_THRESHOLD='\033[38;5;198m'
C_BOLD='\033[1m'

# Initialize output
output=""

# ── Section 1: Directory ──
output+="$(printf "${C_TEAL}%s${C_RESET}" "$dir_path")"

# ── Section 2: Git info ──
is_worktree=false
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # Detect if this is a git worktree (not the main working tree)
    git_common=$(git rev-parse --git-common-dir 2>/dev/null)
    git_dir=$(git rev-parse --git-dir 2>/dev/null)
    if [ -n "$git_common" ] && [ -n "$git_dir" ] && [ "$git_common" != "$git_dir" ]; then
        is_worktree=true
    fi

    # Get git remote symbol
    git_remote=$(git ls-remote --get-url 2>/dev/null)
    git_symbol=""

    if [[ "$git_remote" =~ "github" ]]; then
        git_symbol=" "
    elif [[ "$git_remote" =~ "gitlab" ]]; then
        git_symbol=" "
    elif [[ "$git_remote" =~ "bitbucket" ]]; then
        git_symbol=" "
    elif [[ "$git_remote" =~ "git" ]]; then
        git_symbol=" "
    else
        git_symbol=" "
    fi

    output+=" $git_symbol "

    # Get git branch (bold lavender)
    git_branch=$(git branch --show-current 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    if [ -n "$git_branch" ]; then
        output+="$(printf "on ${C_LAVENDER}${C_BOLD}%s${C_RESET} " "$git_branch")"
    fi

    # Worktree indicator (pill badge, right after branch)
    if [ "$is_worktree" = true ] && [ "$cfg_worktree" = true ]; then
        C_WT_BG='\033[48;5;54m'    # purple background
        C_WT_FG='\033[38;5;177m'   # light magenta text
        output+="$(printf "${C_WT_BG}${C_WT_FG}${C_BOLD}  worktree ${C_RESET} ")"
    fi

    # Get git status
    git_status_output=""

    porcelain=$(git status --porcelain 2>/dev/null)
    if [ -n "$porcelain" ]; then
        modified=$(echo "$porcelain" | grep -c '^ M' 2>/dev/null || true)
        added=$(echo "$porcelain" | grep -c '^A' 2>/dev/null || true)
        deleted=$(echo "$porcelain" | grep -c '^ D' 2>/dev/null || true)
        untracked=$(echo "$porcelain" | grep -c '^??' 2>/dev/null || true)
        modified=$((modified + 0))
        added=$((added + 0))
        deleted=$((deleted + 0))
        untracked=$((untracked + 0))

        [ "$modified" -gt 0 ] && git_status_output+="!${modified} "
        [ "$added" -gt 0 ] && git_status_output+="+${added} "
        [ "$deleted" -gt 0 ] && git_status_output+="✘${deleted} "
        [ "$untracked" -gt 0 ] && git_status_output+="?${untracked} "
    fi

    ahead_behind=$(git -c core.fileMode=false rev-list --left-right --count HEAD...@{upstream} 2>/dev/null | tr -s '[:space:]' ' ')
    if [ -n "$ahead_behind" ]; then
        ahead=$(echo "$ahead_behind" | awk '{print $1+0}')
        behind=$(echo "$ahead_behind" | awk '{print $2+0}')
        [ "$ahead" -gt 0 ] 2>/dev/null && git_status_output+="⇡${ahead} "
        [ "$behind" -gt 0 ] 2>/dev/null && git_status_output+="⇣${behind} "
    fi

    if [ -n "$git_status_output" ]; then
        output+=" $(printf '%s' "$git_status_output")"
    fi
fi

# ── Separator ──
output+="$(printf " ${C_SEPARATOR}║${C_RESET} ")"

# ── Section 3: Model ──
if [ "$cfg_model" = true ]; then
    model_name=$(echo "$input" | jq -r '.model.display_name // empty')
    if [ -n "$model_name" ]; then
        output+="$(printf "${C_ORANGE} %s${C_RESET}" "$model_name")"
    fi
fi

# ── Section 3b: Session duration ──
if [ "$cfg_duration" = true ]; then
    duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')
    if [ -n "$duration_ms" ] && [ "$duration_ms" != "0" ]; then
        total_sec=$((duration_ms / 1000))
        if [ "$total_sec" -ge 3600 ]; then
            hrs=$((total_sec / 3600))
            mins=$(( (total_sec % 3600) / 60 ))
            dur_str="${hrs}h ${mins}m"
        elif [ "$total_sec" -ge 60 ]; then
            mins=$((total_sec / 60))
            dur_str="${mins}m"
        else
            dur_str="${total_sec}s"
        fi
        output+="$(printf " ${C_DIM}%s${C_RESET}" "$dur_str")"
    fi
fi


# ── Section 4: Context window usage ──
if [ "$cfg_context" = true ]; then
    ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
    if [ -n "$ctx_pct" ] && [ "$ctx_pct" != "null" ]; then
        pct_int=${ctx_pct%.*}
        pct_int=${pct_int:-0}
        filled=$((pct_int / 10))

        if [ "$pct_int" -ge 80 ]; then
            bar_color="$C_RED"
        elif [ "$pct_int" -ge 50 ]; then
            bar_color="$C_YELLOW"
        else
            bar_color="$C_GREEN"
        fi

        # Build bar with auto-compact threshold marker
        threshold_seg=$((cfg_compact_threshold / 10))
        bar=""
        for ((i=0; i<10; i++)); do
            if [ "$i" -eq "$threshold_seg" ]; then
                bar+="$(printf "${C_THRESHOLD}┃${C_RESET}")"
            elif [ "$i" -lt "$filled" ]; then
                bar+="$(printf "${bar_color}█${C_RESET}")"
            else
                bar+="$(printf "${C_DIM}░${C_RESET}")"
            fi
        done

        output+="$(printf " ${C_DIM}context${C_RESET} %s ${bar_color}%s%%${C_RESET}" "$bar" "$pct_int")"
    fi
fi

# ── Section 5: CCK active (pill badge) ──
if [ "$cfg_capsule_pill" = true ] && [ -d "$HOME/.claude/cck" ]; then
    C_PILL_BG='\033[48;5;22m'   # dark green background
    C_PILL_FG='\033[38;5;157m'  # light green text
    output+="$(printf " ${C_SEPARATOR}║${C_RESET} ${C_PILL_BG}${C_PILL_FG}${C_BOLD} capsule kit ${C_RESET}")"
fi

# ── Section 6: Crew mode ──
if [ "$cfg_crew" = true ]; then
    crew_file="$cwd/crew-identity.json"
    if [ -f "$crew_file" ]; then
        crew_name=$(jq -r '.teammate_name // empty' "$crew_file" 2>/dev/null)
        if [ -n "$crew_name" ]; then
            output+="$(printf " ${C_CYAN}${C_BOLD}@crew${C_RESET}${C_DIM}=${C_RESET}${C_CYAN}%s${C_RESET}" "$crew_name")"
        fi
    fi
fi

echo "$output"
