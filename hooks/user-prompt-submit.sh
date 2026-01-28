#!/bin/bash
# UserPromptSubmit Hook - Increments message counter and injects periodic reminders
# Called before each user prompt is processed

set -euo pipefail

# Defensive check: Ensure CWD exists
if ! cd "$(pwd 2>/dev/null)" 2>/dev/null; then
  cd "$HOME" 2>/dev/null || exit 0
fi

# Read prompt from stdin (hook protocol)
INPUT_JSON=$(cat)

# Message count tracking
MESSAGE_COUNT_FILE=".claude/message_count.txt"
CURRENT_COUNT=$(cat "$MESSAGE_COUNT_FILE" 2>/dev/null || echo "0")
NEXT_COUNT=$((CURRENT_COUNT + 1))
echo "$NEXT_COUNT" > "$MESSAGE_COUNT_FILE"

# Extract user prompt for analysis
USER_PROMPT=$(echo "$INPUT_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('user_prompt', ''))" 2>/dev/null || echo "")

# Detect uncertainty keywords and suggest context-librarian
if [ -n "$USER_PROMPT" ]; then
  if echo "$USER_PROMPT" | grep -qiE "(don't have context|need to understand|how does.*work|explain.*architecture|what is|before I start|learn about)"; then
    # Extract potential topic
    TOPIC=$(echo "$USER_PROMPT" | grep -oiE "(auth|authentication|database|schema|api|routing|session|payment|order|user|error|bug)" | head -1)

    if [ -n "$TOPIC" ]; then
      cat << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 CONTEXT RETRIEVAL SUGGESTION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Detected: Uncertainty about "$TOPIC"

Before proceeding, query context-librarian for existing knowledge:
  Bash(".claude/tools/context-query/context-query.sh $TOPIC")

This searches all memory layers (3-8s) and returns focused context with 90% attention.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
    fi
  fi
fi

# Check if reminder should be shown (every 10 messages)
REMINDER_INTERVAL=10
if [ $((NEXT_COUNT % REMINDER_INTERVAL)) -eq 0 ]; then
  # Inject memory context (existing functionality from prompt-submit-memory.sh)
  MEMORY_OUTPUT=$(./.claude/hooks/prompt-submit-memory.sh <<< "$INPUT_JSON" 2>/dev/null || echo "")

  # Build reminder message
  REMINDER="💡 Capsule Kit Reminder (Message $NEXT_COUNT):
- Check .claude/capsule.toon for session state (files, tasks, git)
- Use specialized tools: query-deps, impact-analysis, progressive-reader
- Launch agents proactively: error-detective, architecture-explorer, code-reviewer

$MEMORY_OUTPUT"

  # Output as plain text (Claude Code handles injection)
  echo "$REMINDER"
else
  # Not a reminder turn, just inject memory if available
  ./.claude/hooks/prompt-submit-memory.sh <<< "$INPUT_JSON" 2>/dev/null || exit 0
fi

exit 0
