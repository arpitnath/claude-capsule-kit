#!/bin/bash

# Quality Check Hook
# Post-response validation to ensure optimal approach was used
# Runs AFTER Claude responds but BEFORE sending to user

# This hook analyzes the response and provides improvement suggestions
# It's a learning/reminder tool, not blocking

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 QUALITY CHECK (Post-Response Validation)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Self-Assessment Checklist:"
echo ""
echo "1. ⚡ Parallel Tool Calls"
echo "   ❓ Did I use parallel tool calls for independent operations?"
echo "   💡 If reading 3+ files → Use multiple Read calls in one message"
echo ""
echo "2. 🤖 Sub-Agent Delegation"
echo "   ❓ Should this task have been delegated to a sub-agent?"
echo "   💡 Complex (>30 min) or specialized (agent dev, Labs, DB) → Delegate"
echo ""
echo "3. 🧠 Memory Usage"
echo "   ❓ Did I check exploration journal for continuation work?"
echo "   💡 'Continue/resume' keywords → Read docs/exploration/ first"
echo ""
echo "4. 📝 Progress Tracking"
echo "   ❓ Did I use TodoWrite for multi-step tasks?"
echo "   💡 3+ steps or >30 min → Track with todos"
echo ""
echo "5. 💾 Save Discoveries"
echo "   ❓ Should I save important findings for future sessions?"
echo "   💡 Discoveries are auto-saved via session handoff on session end"
echo ""
echo "6. 🔄 Avoid Redundancy"
echo "   ❓ Did I re-read files I already read recently?"
echo "   💡 Reference previous reads when possible"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ If all checked: Response quality is optimal!"
echo "⚠️  If any unchecked: Consider improvements for next time"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Always continue (this is informational, not blocking)
exit 0
