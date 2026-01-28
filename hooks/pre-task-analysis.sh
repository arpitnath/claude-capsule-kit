#!/bin/bash
# Pre-task analysis hook - analyzes user prompt and suggests optimal approach
# Runs before Claude responds to encourage best practices and efficient workflows

# Defensive check: Ensure CWD exists (can be invalid if directory was deleted)
if ! cd "$(pwd 2>/dev/null)" 2>/dev/null; then
  cd "$HOME" 2>/dev/null || exit 0
fi

USER_PROMPT=$(timeout 0.1 cat 2>/dev/null || echo "$1")

MESSAGE_COUNT_FILE=".claude/message_count.txt"
if [ -f "$MESSAGE_COUNT_FILE" ]; then
  NEW_COUNT=$(cat "$MESSAGE_COUNT_FILE")
else
  NEW_COUNT=1
fi
# Note: Counter is now incremented by user-prompt-submit.sh (runs first)

# Refresh capsule if needed
if ./.claude/hooks/check-refresh-needed.sh 2>/dev/null; then
  ./.claude/hooks/detect-changes.sh 2>/dev/null
  ./.claude/hooks/update-capsule.sh 2>/dev/null
fi

# Collect suggestions as JSON array
SUGGESTIONS="[]"

# Explore suggestion
if echo "$USER_PROMPT" | grep -qiE "explore|find.*file|search.*code|where.*is|how does.*work|understand.*architecture|locate|discover|investigate|show.*me"; then
  SUGGESTIONS=$(echo "$SUGGESTIONS" | python3 -c "import sys, json; arr=json.load(sys.stdin); arr.append({'type':'delegation','agent':'Explore','taskType':'exploration-discovery','reason':'Fast multi-round investigation with pattern matching','usage':'Task tool with subagent_type=Explore','options':{'thoroughness':['quick','medium','very thorough']}}); print(json.dumps(arr))" 2>/dev/null || echo "$SUGGESTIONS")
fi

# Plan suggestion
if echo "$USER_PROMPT" | grep -qiE "plan|implement|build|create|develop|design|architect|add.*feature|new.*system"; then
  SUGGESTIONS=$(echo "$SUGGESTIONS" | python3 -c "import sys, json; arr=json.load(sys.stdin); arr.append({'type':'delegation','agent':'Plan','taskType':'planning-implementation','reason':'Creates systematic implementation strategy','usage':'Task tool with subagent_type=Plan','returns':'Detailed implementation plan with steps'}); print(json.dumps(arr))" 2>/dev/null || echo "$SUGGESTIONS")
fi

# General-purpose suggestion
if echo "$USER_PROMPT" | grep -qiE "fix.*and.*test|migrate.*and.*verify|update.*across|refactor.*entire"; then
  SUGGESTIONS=$(echo "$SUGGESTIONS" | python3 -c "import sys, json; arr=json.load(sys.stdin); arr.append({'type':'delegation','agent':'general-purpose','taskType':'complex-multi-step','reason':'Handles complex workflows with multiple operations','usage':'Task tool with subagent_type=general-purpose'}); print(json.dumps(arr))" 2>/dev/null || echo "$SUGGESTIONS")
fi

# Parallel execution tip
if echo "$USER_PROMPT" | grep -qiE "and|also|both|multiple|all three|check.*check|verify.*verify"; then
  SUGGESTIONS=$(echo "$SUGGESTIONS" | python3 -c "import sys, json; arr=json.load(sys.stdin); arr.append({'type':'performance-tip','category':'parallel-tool-calls','detected':'Multiple independent operations','bestPractice':'Execute tool calls in parallel','reason':'Faster execution - single message with multiple tools','example':'Read 3 files -> Use 3 Read calls in one message'}); print(json.dumps(arr))" 2>/dev/null || echo "$SUGGESTIONS")
fi

# Memory available suggestion
if echo "$USER_PROMPT" | grep -qiE "continue|resume|pick.*up|where.*left|last.*time|previous|what.*next"; then
  if [ -f "docs/exploration/CURRENT_SESSION.md" ]; then
    SUGGESTIONS=$(echo "$SUGGESTIONS" | python3 -c "import sys, json; arr=json.load(sys.stdin); arr.append({'type':'memory-available','source':'exploration-journal','actionRequired':True,'location':'docs/exploration/CURRENT_SESSION.md','reason':'Avoid repeating work, maintain continuity','nextStep':'Summarize previous session for user'}); print(json.dumps(arr))" 2>/dev/null || echo "$SUGGESTIONS")
  fi
fi

# Task tracking enforcement
if echo "$USER_PROMPT" | grep -qiE "implement|build|create|fix.*bug|add.*feature"; then
  SUGGESTIONS=$(echo "$SUGGESTIONS" | python3 -c "import sys, json; arr=json.load(sys.stdin); arr.append({'type':'enforcement','category':'task-tracking','required':True,'tool':'TodoWrite','instruction':'Break complex work into trackable steps'}); print(json.dumps(arr))" 2>/dev/null || echo "$SUGGESTIONS")
fi

# Complex task reminder
PROMPT_LENGTH=${#USER_PROMPT}
if [ "$(echo "$SUGGESTIONS" | python3 -c "import sys,json;print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)" = "0" ] && [ $PROMPT_LENGTH -gt 200 ]; then
  SUGGESTIONS=$(echo "$SUGGESTIONS" | python3 -c "import sys, json; arr=json.load(sys.stdin); arr.append({'type':'reminder','category':'complex-task','detected':'Long prompt - complex task','availableSubagents':['Plan','Explore','general-purpose'],'consider':'Breaking into smaller tasks with TodoWrite'}); print(json.dumps(arr))" 2>/dev/null || echo "$SUGGESTIONS")
fi

# Get capsule content (now outputs JSON)
CAPSULE_JSON="{}"
if [ -f "./.claude/hooks/inject-capsule.sh" ]; then
  CAPSULE_JSON=$(./.claude/hooks/inject-capsule.sh 2>/dev/null || echo "{}")
fi

# Output JSON response (first character MUST be '{' for Claude Code parsing)
if [ "$NEW_COUNT" -eq 1 ]; then
  # First message includes systemMessage
  python3 -c "
import json, sys
try:
    capsule = json.loads('''$CAPSULE_JSON''') if '''$CAPSULE_JSON'''.strip() else {}
except:
    capsule = {}
suggestions = json.loads('''$SUGGESTIONS''')
output = {
  'systemMessage': 'Claude Capsule Kit - Context and tools loaded',
  'hookSpecificOutput': {
    'hookEventName': 'UserPromptSubmit',
    'context': capsule,
    'suggestions': suggestions
  }
}
print(json.dumps(output))
" 2>/dev/null || echo '{"systemMessage":"Claude Capsule Kit - Context and tools loaded"}'
else
  # Subsequent messages - only if we have content
  if [ "$CAPSULE_JSON" != "{}" ] || [ "$SUGGESTIONS" != "[]" ]; then
    python3 -c "
import json, sys
try:
    capsule = json.loads('''$CAPSULE_JSON''') if '''$CAPSULE_JSON'''.strip() else {}
except:
    capsule = {}
suggestions = json.loads('''$SUGGESTIONS''')
output = {
  'hookSpecificOutput': {
    'hookEventName': 'UserPromptSubmit',
    'context': capsule,
    'suggestions': suggestions
  }
}
print(json.dumps(output))
" 2>/dev/null || true
  fi
fi

# Run tool suggestions (output to stderr to not interfere with JSON)
if [ -f "./.claude/hooks/tool-auto-suggest.sh" ]; then
  ./.claude/hooks/tool-auto-suggest.sh "$USER_PROMPT" >&2 2>/dev/null || true
fi

exit 0
