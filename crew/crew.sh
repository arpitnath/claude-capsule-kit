#!/bin/bash
# Claude Crew - Multi-Branch AI Development Teams
#
# Orchestrates Claude Code Agent Teams across different git branches using worktrees.
# Combines Agent Teams coordination with branch isolation for parallel development.
#
# Usage:
#   crew setup    - Create worktrees from crew.yaml
#   crew launch   - Start Agent Teams with worktree assignments
#   crew cleanup  - Remove worktrees after completion

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREW_CONFIG="${CREW_CONFIG:-$SCRIPT_DIR/crew.yaml}"

# Load library functions
source "$SCRIPT_DIR/lib/worktree-manager.sh"
source "$SCRIPT_DIR/lib/team-spawner.sh"

command="${1:-}"
shift 2>/dev/null || true

case "$command" in
    setup)
        setup_worktrees "$CREW_CONFIG"
        ;;

    launch)
        launch_team "$CREW_CONFIG"
        ;;

    cleanup)
        cleanup_worktrees "$CREW_CONFIG"
        ;;

    status)
        show_team_status
        ;;

    *)
        echo "Claude Crew - Multi-Branch AI Development Teams"
        echo ""
        echo "Usage:"
        echo "  crew setup    Create worktrees from crew.yaml"
        echo "  crew launch   Start Agent Teams with worktree assignments"
        echo "  crew cleanup  Remove worktrees after completion"
        echo "  crew status   Show team status"
        echo ""
        echo "Config: $CREW_CONFIG"
        exit 1
        ;;
esac
