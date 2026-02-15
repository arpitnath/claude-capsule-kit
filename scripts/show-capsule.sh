#!/bin/bash
# show-capsule.sh - View Capsule context records
# Usage: bash .claude/scripts/show-capsule.sh [command]
# Commands: summary (default), files, agents, sessions, all, search <term>

set -eo pipefail

# In v3, capsule.db is always at the global location
DB="$HOME/.claude/capsule.db"

if [ ! -f "$DB" ]; then
  echo "No capsule.db found at $DB. Start a Claude Code session first to initialize Capsule."
  exit 1
fi

CMD="${1:-summary}"

case "$CMD" in
  summary)
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Capsule Context Dashboard"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM records;")
    echo "  Total records: $TOTAL"
    echo ""
    echo "  By type:"
    sqlite3 "$DB" "SELECT '    ' || type || ': ' || COUNT(*) FROM records GROUP BY type ORDER BY COUNT(*) DESC;"
    echo ""
    echo "  Recent sessions:"
    sqlite3 "$DB" "SELECT '    ' || title FROM records WHERE namespace LIKE 'session' AND type IN ('META','SUMMARY') ORDER BY rowid DESC LIMIT 5;" 2>/dev/null
    echo ""
    AGENT_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM records WHERE namespace LIKE '%/subagents';" 2>/dev/null)
    FILE_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM records WHERE namespace LIKE '%/files';" 2>/dev/null)
    echo "  Files tracked: $FILE_COUNT"
    echo "  Sub-agents logged: $AGENT_COUNT"
    echo ""
    echo "  DB size: $(du -h "$DB" | cut -f1)"
    echo "  DB path: $DB"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ;;

  files)
    echo "Recent file operations:"
    echo ""
    sqlite3 -column -header "$DB" \
      "SELECT title AS file, substr(summary,1,60) AS operation
       FROM records
       WHERE namespace LIKE '%/files'
       ORDER BY rowid DESC
       LIMIT 30;"
    ;;

  agents)
    echo "Sub-agent invocations:"
    echo ""
    sqlite3 -column -header "$DB" \
      "SELECT title AS agent, substr(summary,1,70) AS prompt
       FROM records
       WHERE namespace LIKE '%/subagents'
       ORDER BY rowid DESC
       LIMIT 20;"
    ;;

  sessions)
    echo "Session summaries:"
    echo ""
    sqlite3 -column -header "$DB" \
      "SELECT title AS session, substr(summary,1,80) AS details
       FROM records
       WHERE namespace = 'session' OR (type = 'SUMMARY' AND namespace NOT LIKE '%/subagents')
       ORDER BY rowid DESC
       LIMIT 10;"
    ;;

  all)
    echo "All records (recent first):"
    echo ""
    sqlite3 -column -header "$DB" \
      "SELECT namespace, type, title, substr(summary,1,50) AS summary
       FROM records
       ORDER BY rowid DESC
       LIMIT 50;"
    ;;

  search)
    TERM="${2:-}"
    if [ -z "$TERM" ]; then
      echo "Usage: show-capsule.sh search <term>"
      exit 1
    fi
    echo "Search results for '$TERM':"
    echo ""
    sqlite3 -column -header "$DB" \
      "SELECT type, title, substr(summary,1,60) AS summary
       FROM records
       WHERE title LIKE '%${TERM}%' OR summary LIKE '%${TERM}%' OR namespace LIKE '%${TERM}%'
       ORDER BY rowid DESC
       LIMIT 30;"
    ;;

  *)
    echo "Usage: bash .claude/scripts/show-capsule.sh [command]"
    echo ""
    echo "Commands:"
    echo "  summary   Dashboard overview (default)"
    echo "  files     Recent file operations"
    echo "  agents    Sub-agent invocations"
    echo "  sessions  Session summaries"
    echo "  all       All records (recent first)"
    echo "  search    Search records by term"
    ;;
esac
