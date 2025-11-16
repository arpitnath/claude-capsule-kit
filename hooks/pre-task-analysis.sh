#!/bin/bash
# Pre-task analysis hook - analyzes user prompt and suggests optimal approach
# Runs before Claude responds to encourage best practices and efficient workflows

USER_PROMPT=$(timeout 0.1 cat 2>/dev/null || echo "$1")

MESSAGE_COUNT_FILE=".claude/message_count.txt"
if [ -f "$MESSAGE_COUNT_FILE" ]; then
  COUNT=$(cat "$MESSAGE_COUNT_FILE")
  NEW_COUNT=$((COUNT + 1))
  echo $NEW_COUNT > "$MESSAGE_COUNT_FILE"
else
  NEW_COUNT=1
  echo "1" > "$MESSAGE_COUNT_FILE"
fi

# Output JSON with systemMessage on first message BEFORE any plain text
# (Ensures first character is '{' for proper JSON parsing)
if [ "$NEW_COUNT" -eq 1 ]; then
  cat << 'EOF'
{
  "systemMessage": "Super Claude Kit - Context and tools loaded"
}
EOF
fi

if ./.claude/hooks/check-refresh-needed.sh 2>/dev/null; then
  ./.claude/hooks/detect-changes.sh 2>/dev/null
  ./.claude/hooks/update-capsule.sh 2>/dev/null
  ./.claude/hooks/inject-capsule.sh 2>/dev/null
else
  :
fi

SUGGESTIONS_MADE=false

if echo "$USER_PROMPT" | grep -qiE "explore|find.*file|search.*code|where.*is|how does.*work|understand.*architecture|locate|discover|investigate|show.*me"; then
    cat << 'EOF'

<delegation-suggestion>
  <agent type="Explore" task-type="exploration-discovery">
    <reason>Fast multi-round investigation with pattern matching</reason>
    <usage>Task tool with subagent_type='Explore'</usage>
    <thoroughness options="quick, medium, very thorough"/>
  </agent>
</delegation-suggestion>

EOF
    SUGGESTIONS_MADE=true
fi

if echo "$USER_PROMPT" | grep -qiE "plan|implement|build|create|develop|design|architect|add.*feature|new.*system"; then
    cat << 'EOF'

<delegation-suggestion>
  <agent type="Plan" task-type="planning-implementation">
    <reason>Creates systematic implementation strategy</reason>
    <usage>Task tool with subagent_type='Plan'</usage>
    <returns>Detailed implementation plan with steps</returns>
  </agent>
</delegation-suggestion>

EOF
    SUGGESTIONS_MADE=true
fi

if echo "$USER_PROMPT" | grep -qiE "fix.*and.*test|migrate.*and.*verify|update.*across|refactor.*entire"; then
    cat << 'EOF'

<delegation-suggestion>
  <agent type="general-purpose" task-type="complex-multi-step">
    <reason>Handles complex workflows with multiple operations</reason>
    <usage>Task tool with subagent_type='general-purpose'</usage>
  </agent>
</delegation-suggestion>

EOF
    SUGGESTIONS_MADE=true
fi

if echo "$USER_PROMPT" | grep -qiE "and|also|both|multiple|all three|check.*check|verify.*verify"; then
    cat << 'EOF'

<performance-tip type="parallel-tool-calls">
  <detected>Multiple independent operations</detected>
  <best-practice>Execute tool calls in parallel</best-practice>
  <reason>Faster execution - single message with multiple tools</reason>
  <example>Read 3 files -> Use 3 Read calls in one message</example>
</performance-tip>

EOF
    SUGGESTIONS_MADE=true
fi

if echo "$USER_PROMPT" | grep -qiE "continue|resume|pick.*up|where.*left|last.*time|previous|what.*next"; then
    if [ -f "docs/exploration/CURRENT_SESSION.md" ]; then
        cat << 'EOF'

<memory-available source="exploration-journal">
  <action required="true">Read exploration journal FIRST</action>
  <location>docs/exploration/CURRENT_SESSION.md</location>
  <reason>Avoid repeating work, maintain continuity</reason>
  <next-step>Summarize previous session for user</next-step>
</memory-available>

EOF
        SUGGESTIONS_MADE=true
    fi
fi

if echo "$USER_PROMPT" | grep -qiE "implement|build|create|fix.*bug|add.*feature"; then
    cat << 'EOF'

<reminder type="task-tracking">
  <tool>TodoWrite</tool>
  <suggestion>Break complex work into trackable steps</suggestion>
</reminder>

EOF
    SUGGESTIONS_MADE=true
fi

if [ "$SUGGESTIONS_MADE" = false ]; then
    PROMPT_LENGTH=${#USER_PROMPT}
    if [ $PROMPT_LENGTH -gt 200 ]; then
        cat << 'EOF'

<reminder type="complex-task">
  <detected>Long prompt - complex task</detected>
  <available-subagents>Plan, Explore, general-purpose</available-subagents>
  <consider>Breaking into smaller tasks with TodoWrite</consider>
</reminder>

EOF
    fi
fi

if [ -f "./.claude/hooks/tool-auto-suggest.sh" ]; then
    ./.claude/hooks/tool-auto-suggest.sh "$USER_PROMPT" 2>/dev/null || true
fi

exit 0
