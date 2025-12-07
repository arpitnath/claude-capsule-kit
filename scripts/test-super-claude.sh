#!/bin/bash
# Claude Capsule Kit Installation Test Script
# Verifies that Claude Capsule Kit is installed and working correctly

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Testing Claude Capsule Kit Installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

PASSED=0
FAILED=0

# Test 1: Check directories exist
echo "1️⃣ Checking installation directories..."
if [ -d ".claude/hooks" ]; then
  echo "   ✅ .claude/hooks/ exists"
  PASSED=$((PASSED + 1))
else
  echo "   ❌ .claude/hooks/ missing"
  FAILED=$((FAILED + 1))
fi

if [ -d ".claude/agents" ]; then
  echo "   ✅ .claude/agents/ exists"
  PASSED=$((PASSED + 1))
else
  echo "   ❌ .claude/agents/ missing"
  FAILED=$((FAILED + 1))
fi

if [ -d ".claude/skills" ]; then
  echo "   ✅ .claude/skills/ exists"
  PASSED=$((PASSED + 1))
else
  echo "   ❌ .claude/skills/ missing"
  FAILED=$((FAILED + 1))
fi

if [ -d ".claude/docs" ]; then
  echo "   ✅ .claude/docs/ exists"
  PASSED=$((PASSED + 1))
else
  echo "   ❌ .claude/docs/ missing"
  FAILED=$((FAILED + 1))
fi

echo ""

# Test 2: Check core files
echo "2️⃣ Checking core files..."
if [ -f ".claude/hooks/session-start.sh" ]; then
  echo "   ✅ session-start.sh present"
  PASSED=$((PASSED + 1))
else
  echo "   ❌ session-start.sh missing"
  FAILED=$((FAILED + 1))
fi

if [ -f ".claude/hooks/pre-task-analysis.sh" ]; then
  echo "   ✅ pre-task-analysis.sh present"
  PASSED=$((PASSED + 1))
else
  echo "   ❌ pre-task-analysis.sh missing"
  FAILED=$((FAILED + 1))
fi

if [ -f ".claude/docs/CAPSULE_USAGE_GUIDE.md" ]; then
  echo "   ✅ CAPSULE_USAGE_GUIDE.md present"
  PASSED=$((PASSED + 1))
else
  echo "   ❌ CAPSULE_USAGE_GUIDE.md missing"
  FAILED=$((FAILED + 1))
fi

if [ -f ".claude/settings.local.json" ]; then
  echo "   ✅ settings.local.json present"
  PASSED=$((PASSED + 1))
else
  echo "   ❌ settings.local.json missing"
  FAILED=$((FAILED + 1))
fi

echo ""

# Test 3: Check hooks are executable
echo "3️⃣ Checking hook permissions..."
executable_count=$(find .claude/hooks -name "*.sh" -perm +111 2>/dev/null | wc -l | tr -d ' ')
if [ "$executable_count" -gt 0 ]; then
  echo "   ✅ $executable_count hooks are executable"
  PASSED=$((PASSED + 1))
else
  echo "   ❌ No executable hooks found"
  FAILED=$((FAILED + 1))
fi

echo ""

# Test 4: Test logging functionality
echo "4️⃣ Testing logging functionality..."
./.claude/hooks/log-file-access.sh "test.txt" "read" 2>/dev/null
if [ -f ".claude/session_files.log" ]; then
  echo "   ✅ File logging works"
  PASSED=$((PASSED + 1))
else
  echo "   ❌ File logging failed"
  FAILED=$((FAILED + 1))
fi

./.claude/hooks/log-discovery.sh "test" "Test discovery" 2>/dev/null
if [ -f ".claude/session_discoveries.log" ]; then
  echo "   ✅ Discovery logging works"
  PASSED=$((PASSED + 1))
else
  echo "   ❌ Discovery logging failed"
  FAILED=$((FAILED + 1))
fi

echo ""

# Test 5: Test capsule generation
echo "5️⃣ Testing capsule generation..."
./.claude/hooks/init-capsule-session.sh >/dev/null 2>&1
./.claude/hooks/update-capsule.sh >/dev/null 2>&1

if [ -f ".claude/capsule.toon" ]; then
  echo "   ✅ Capsule generated successfully"
  PASSED=$((PASSED + 1))

  # Check if capsule has content
  capsule_size=$(wc -c < .claude/capsule.toon)
  if [ "$capsule_size" -gt 50 ]; then
    echo "   ✅ Capsule contains data ($capsule_size bytes)"
    PASSED=$((PASSED + 1))
  else
    echo "   ⚠️  Capsule seems empty"
  fi
else
  echo "   ❌ Capsule generation failed"
  FAILED=$((FAILED + 1))
fi

echo ""

# Test 6: Check gitignore
echo "6️⃣ Checking .gitignore..."
if [ -f ".gitignore" ]; then
  if grep -q "Claude Capsule Kit" .gitignore 2>/dev/null; then
    echo "   ✅ .gitignore updated with Claude Capsule Kit entries"
    PASSED=$((PASSED + 1))
  else
    echo "   ⚠️  .gitignore exists but no Claude Capsule Kit entries"
  fi
else
  echo "   ⚠️  .gitignore not found"
fi

echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Test Results:"
echo "   ✅ Passed: $PASSED"
if [ "$FAILED" -gt 0 ]; then
  echo "   ❌ Failed: $FAILED"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$FAILED" -eq 0 ]; then
  echo "✅ Claude Capsule Kit is installed correctly!"
  echo ""
  echo "🚀 Next steps:"
  echo "   1. Start Claude Code in this directory"
  echo "   2. Look for: '🚀 Claude Capsule Kit ACTIVATED'"
  echo "   3. Check capsule displays before each prompt"
  echo ""
  echo "📊 View statistics: bash .claude/hooks/show-stats.sh"
  exit 0
else
  echo "❌ Some tests failed. Please check the installation."
  exit 1
fi
