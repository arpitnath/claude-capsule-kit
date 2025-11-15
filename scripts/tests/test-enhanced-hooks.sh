#!/usr/bin/env bash
# Super Claude Kit v2.0.0 - Test Enhanced Hooks System
# Tests Phase 3: Tool auto-suggestion and keyword triggers

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
print_test() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "TEST $1: $2"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    TESTS_RUN=$((TESTS_RUN + 1))
}

pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

skip() {
    echo -e "${YELLOW}⊘ SKIP${NC}: $1"
}

# Change to project root
cd "$PROJECT_ROOT"

# Test 1: Verify hook files exist
print_test "1" "Hook files exist and are executable"

HOOKS=(
    "hooks/tool-auto-suggest.sh"
    "hooks/keyword-triggers.sh"
    "hooks/pre-edit-analysis.sh"
)

ALL_EXIST=true
for hook in "${HOOKS[@]}"; do
    if [ ! -f "$hook" ]; then
        fail "$hook does not exist"
        ALL_EXIST=false
    elif [ ! -x "$hook" ]; then
        fail "$hook is not executable"
        ALL_EXIST=false
    fi
done

if $ALL_EXIST; then
    pass "All Phase 3 hooks exist and are executable"
fi

# Test 2: Tool auto-suggest - dependency keywords
print_test "2" "Tool auto-suggest detects dependency keywords"

OUTPUT=$(./hooks/tool-auto-suggest.sh "Show me all dependencies for user.ts" 2>/dev/null || true)

if echo "$OUTPUT" | grep -q "query-deps"; then
    pass "Detected 'query-deps' suggestion for dependency query"
else
    fail "Failed to suggest query-deps for dependency keywords"
fi

# Test 3: Tool auto-suggest - circular dependency keywords
print_test "3" "Tool auto-suggest detects circular dependency keywords"

OUTPUT=$(./hooks/tool-auto-suggest.sh "Are there any circular dependencies in the code?" 2>/dev/null || true)

if echo "$OUTPUT" | grep -q "find-circular"; then
    pass "Detected 'find-circular' suggestion for circular keywords"
else
    fail "Failed to suggest find-circular for circular dependency keywords"
fi

# Test 4: Tool auto-suggest - dead code keywords
print_test "4" "Tool auto-suggest detects dead code keywords"

OUTPUT=$(./hooks/tool-auto-suggest.sh "Find unused files and dead code" 2>/dev/null || true)

if echo "$OUTPUT" | grep -q "find-dead-code"; then
    pass "Detected 'find-dead-code' suggestion for dead code keywords"
else
    fail "Failed to suggest find-dead-code for dead code keywords"
fi

# Test 5: Tool auto-suggest - impact analysis keywords
print_test "5" "Tool auto-suggest detects impact analysis keywords"

OUTPUT=$(./hooks/tool-auto-suggest.sh "What will be affected if I change auth.ts?" 2>/dev/null || true)

if echo "$OUTPUT" | grep -q "impact-analysis"; then
    pass "Detected 'impact-analysis' suggestion for impact keywords"
else
    fail "Failed to suggest impact-analysis for impact keywords"
fi

# Test 6: Tool auto-suggest - refactoring keywords (multiple tools)
print_test "6" "Tool auto-suggest detects refactoring keywords (multiple suggestions)"

OUTPUT=$(./hooks/tool-auto-suggest.sh "I want to refactor the authentication module" 2>/dev/null || true)

FOUND_DEPS=false
FOUND_IMPACT=false

if echo "$OUTPUT" | grep -q "query-deps"; then
    FOUND_DEPS=true
fi

if echo "$OUTPUT" | grep -q "impact-analysis"; then
    FOUND_IMPACT=true
fi

if $FOUND_DEPS && $FOUND_IMPACT; then
    pass "Detected multiple tool suggestions for refactoring"
elif $FOUND_DEPS || $FOUND_IMPACT; then
    fail "Detected only one tool suggestion (expected both)"
else
    fail "Failed to suggest tools for refactoring keywords"
fi

# Test 7: Tool auto-suggest - no suggestions for non-matching prompt
print_test "7" "Tool auto-suggest returns empty for non-matching prompts"

OUTPUT=$(./hooks/tool-auto-suggest.sh "Hello, how are you?" 2>/dev/null || true)

if [ -z "$OUTPUT" ] || ! echo "$OUTPUT" | grep -q "Super Claude Kit"; then
    pass "No suggestions for non-matching prompt"
else
    fail "Unexpected suggestions for non-matching prompt"
fi

# Test 8: Pre-task-analysis integration
print_test "8" "Pre-task-analysis hook includes tool suggestions"

if grep -q "tool-auto-suggest.sh" hooks/pre-task-analysis.sh; then
    pass "Pre-task-analysis hook integrates tool auto-suggest"
else
    fail "Pre-task-analysis hook does not call tool-auto-suggest"
fi

# Test 9: Manifest includes new hooks
print_test "9" "Manifest includes Phase 3 hooks"

ALL_IN_MANIFEST=true
for hook in "tool-auto-suggest.sh" "keyword-triggers.sh" "pre-edit-analysis.sh"; do
    if ! grep -q "$hook" manifest.json; then
        fail "$hook not found in manifest.json"
        ALL_IN_MANIFEST=false
    fi
done

if $ALL_IN_MANIFEST; then
    pass "All Phase 3 hooks included in manifest"
fi

# Test 10: Pre-edit-analysis hook functionality
print_test "10" "Pre-edit-analysis hook can analyze file impact"

# Create a mock dependency graph for testing
TEMP_DEP_GRAPH="$HOME/.claude/dep-graph.toon"
TEMP_DIR_CREATED=false

if [ ! -d "$HOME/.claude" ]; then
    mkdir -p "$HOME/.claude"
    TEMP_DIR_CREATED=true
fi

cat > "$TEMP_DEP_GRAPH" << 'EOF'
FILE:/tmp/test-file.ts
LANG:typescript
IMPORTS:
EXPORTS:
IMPORTEDBY:/tmp/other-file.ts,/tmp/another-file.ts
---
EOF

OUTPUT=$(./hooks/pre-edit-analysis.sh "/tmp/test-file.ts" 2>/dev/null || true)

# Cleanup
rm -f "$TEMP_DEP_GRAPH"
if $TEMP_DIR_CREATED; then
    rmdir "$HOME/.claude" 2>/dev/null || true
fi

if echo "$OUTPUT" | grep -q "Impact Analysis"; then
    pass "Pre-edit-analysis correctly analyzes file impact"
else
    fail "Pre-edit-analysis did not show impact analysis"
fi

# Print summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST SUMMARY - Enhanced Hooks (Phase 3)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Tests Run:    $TESTS_RUN"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
else
    echo -e "Tests Failed: $TESTS_FAILED"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All enhanced hooks tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
