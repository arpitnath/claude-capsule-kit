#!/bin/bash
# Context-Query Tool - Retrieves relevant context from all memory layers
# Spawns context-librarian meta-agent for systematic memory search

set -euo pipefail

# Usage information
usage() {
  cat << EOF
Usage: context-query <topic> [options]

Retrieves relevant context from all memory layers (memory-graph, capsule,
discoveries, subagent logs, dependency graph).

Arguments:
  <topic>              Topic to search for (e.g., "authentication", "database")

Options:
  --file <path>        Specific file context (includes dependency analysis)
  --recent <n>         Limit to last N entries (default: 5)
  --help               Show this help message

Examples:
  context-query authentication
  context-query "error handling" --recent 10
  context-query auth --file src/auth/auth.service.ts

Output:
  Focused context package (200-500 tokens) synthesized from all layers.
  Delivered via Claude Code as tool output (90% attention).
EOF
}

# Parse arguments
QUERY_TOPIC=""
FILE_PATH=""
RECENT_LIMIT=5

while [[ $# -gt 0 ]]; do
  case $1 in
    --help)
      usage
      exit 0
      ;;
    --file)
      FILE_PATH="$2"
      shift 2
      ;;
    --recent)
      RECENT_LIMIT="$2"
      shift 2
      ;;
    *)
      if [ -z "$QUERY_TOPIC" ]; then
        QUERY_TOPIC="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$QUERY_TOPIC" ]; then
  echo "Error: Query topic required"
  usage
  exit 1
fi

# Build prompt for context-librarian meta-agent
AGENT_PROMPT="Retrieve relevant context about: \"$QUERY_TOPIC\"

Search all memory layers:
1. Memory-graph (cross-session knowledge)
2. Capsule (current session state)
3. Discovery logs (session insights)
4. Subagent logs (past agent findings)
5. Dependency graph (code relationships)"

if [ -n "$FILE_PATH" ]; then
  AGENT_PROMPT="$AGENT_PROMPT

Specific file: $FILE_PATH
Include: Dependency analysis, import chains, impact score"
fi

AGENT_PROMPT="$AGENT_PROMPT

Limit results to recent $RECENT_LIMIT entries per layer.
Return focused context package (200-500 tokens max).
Format: Structured with actionable recommendations."

# Output instructions for Claude to spawn the agent
# (Claude Code will execute this via Task tool)
cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 CONTEXT QUERY: $QUERY_TOPIC
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Spawning context-librarian agent to search memory layers...

Expected: 3-8 seconds for comprehensive 5-layer search
Output: Focused context package (200-500 tokens)

To spawn the agent, use:

Task(
  subagent_type="context-librarian",
  description="Retrieve context: $QUERY_TOPIC",
  model="haiku",
  prompt="""$AGENT_PROMPT"""
)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
