#!/bin/bash
# Claude Capsule Kit Stats Dashboard
# Shows usage statistics from capsule.db (v3)

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Claude Capsule Kit Usage Statistics"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# In v3, capsule.db is always at the global location
DB="$HOME/.claude/capsule.db"

if [ ! -f "$DB" ]; then
  echo "⚠️  Capsule database not found at $DB"
  echo "    Start a Claude Code session first to initialize Capsule."
  exit 0
fi

# Get counts from capsule.db
FILES_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM records WHERE namespace LIKE '%/files';" 2>/dev/null || echo 0)
DISC_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM records WHERE namespace LIKE '%discoveries%';" 2>/dev/null || echo 0)
SUBAGENT_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM records WHERE namespace LIKE '%/subagents';" 2>/dev/null || echo 0)
SESSION_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM records WHERE namespace = 'session' AND type IN ('META','SUMMARY');" 2>/dev/null || echo 0)
TOTAL_RECORDS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM records;" 2>/dev/null || echo 0)

echo "📁 Files tracked: $FILES_COUNT"
echo "💡 Discoveries logged: $DISC_COUNT"
echo "🤖 Sub-agents used: $SUBAGENT_COUNT"
echo "📝 Sessions recorded: $SESSION_COUNT"
echo "📊 Total records: $TOTAL_RECORDS"
echo ""

# Show last file accessed
if [ "$FILES_COUNT" -gt 0 ]; then
  echo "📄 Last file accessed:"
  sqlite3 "$DB" "SELECT '   ' || title FROM records WHERE namespace LIKE '%/files' ORDER BY rowid DESC LIMIT 1;" 2>/dev/null
  echo ""
fi

# Show last discovery
if [ "$DISC_COUNT" -gt 0 ]; then
  echo "💡 Last discovery:"
  sqlite3 "$DB" "SELECT '   ' || substr(summary, 1, 80) FROM records WHERE namespace LIKE '%discoveries%' ORDER BY rowid DESC LIMIT 1;" 2>/dev/null
  echo ""
fi

# Show last sub-agent
if [ "$SUBAGENT_COUNT" -gt 0 ]; then
  echo "🤖 Last sub-agent:"
  sqlite3 "$DB" "SELECT '   ' || title || ': ' || substr(summary, 1, 60) FROM records WHERE namespace LIKE '%/subagents' ORDER BY rowid DESC LIMIT 1;" 2>/dev/null
  echo ""
fi

# Database stats
DB_SIZE=$(du -h "$DB" | cut -f1)
echo "💾 Database size: $DB_SIZE"
echo "📂 Database path: $DB"
echo ""

# Capsule health check (simplified for v3)
if [ "$TOTAL_RECORDS" -gt 100 ]; then
  echo "🏥 Capsule Health: ✅ Active ($TOTAL_RECORDS records)"
elif [ "$TOTAL_RECORDS" -gt 10 ]; then
  echo "🏥 Capsule Health: ⚠️  Moderate ($TOTAL_RECORDS records)"
else
  echo "🏥 Capsule Health: 📊 Building context ($TOTAL_RECORDS records)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "For detailed views, use: bash $HOME/.claude/cck/tools/context-query/context-query.sh"
echo "  - files: Show recent file operations"
echo "  - agents: Show sub-agent history"
echo "  - sessions: Show session summaries"
echo "  - search <term>: Search context"
echo ""
