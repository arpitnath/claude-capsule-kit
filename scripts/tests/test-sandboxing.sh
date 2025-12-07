#!/usr/bin/env bash
# Claude Capsule Kit v2.0.0 - Test Sandboxing System
# Tests Phase 4: Permission validation, audit logging, and resource limits

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

# Source sandboxing components
source lib/sandbox-validator.sh
source lib/audit-logger.sh

# Test 1: Sandbox validator file exists
print_test "1" "Sandbox validator exists and is sourceable"

if [ -f "lib/sandbox-validator.sh" ]; then
    if command -v validate_permissions >/dev/null 2>&1; then
        pass "Sandbox validator functions loaded correctly"
    else
        fail "Sandbox validator functions not loaded"
    fi
else
    fail "Sandbox validator file not found"
fi

# Test 2: Audit logger file exists
print_test "2" "Audit logger exists and is sourceable"

if [ -f "lib/audit-logger.sh" ]; then
    if command -v log_tool_execution >/dev/null 2>&1; then
        pass "Audit logger functions loaded correctly"
    else
        fail "Audit logger functions not loaded"
    fi
else
    fail "Audit logger file not found"
fi

# Test 3: Blacklist path detection
print_test "3" "Blacklist path detection works"

if is_blacklisted_path "$HOME/.ssh/id_rsa"; then
    pass "Correctly identified .ssh as blacklisted"
else
    fail "Failed to identify .ssh as blacklisted"
fi

if is_blacklisted_path "/etc/passwd"; then
    pass "Correctly identified /etc/passwd as blacklisted"
else
    fail "Failed to identify /etc/passwd as blacklisted"
fi

if is_blacklisted_path "$HOME/project/.env"; then
    pass "Correctly identified .env as blacklisted"
else
    fail "Failed to identify .env as blacklisted"
fi

# Test 4: Project path detection
print_test "4" "Project path detection works"

if is_within_project "$(pwd)/test-file.txt"; then
    pass "Correctly identified path within project"
else
    fail "Failed to identify path within project"
fi

if ! is_within_project "/tmp/outside-file.txt"; then
    pass "Correctly identified path outside project"
else
    fail "Failed to identify path outside project"
fi

# Test 5: Path pattern matching
print_test "5" "Path pattern matching with wildcards"

if path_matches_pattern "/tmp/test/file.txt" "/tmp/*/file.txt"; then
    pass "Single wildcard pattern matching works"
else
    fail "Single wildcard pattern matching failed"
fi

if path_matches_pattern "/tmp/test/deep/file.txt" "/tmp/**/file.txt"; then
    pass "Double wildcard pattern matching works"
else
    fail "Double wildcard pattern matching failed"
fi

# Test 6: Audit logging
print_test "6" "Audit logging functionality"

# Clean up any existing audit log for testing
AUDIT_LOG="$HOME/.claude/test-audit.log"
export AUDIT_LOG
rm -f "$AUDIT_LOG"

log_tool_execution "test-tool" "execute" "started" "param1 param2"
log_tool_execution "test-tool" "execute" "success" "duration:100ms"

if [ -f "$AUDIT_LOG" ]; then
    if grep -q "test-tool" "$AUDIT_LOG"; then
        pass "Audit log created and entries written"
    else
        fail "Audit log exists but no entries found"
    fi
else
    fail "Audit log not created"
fi

# Clean up
rm -f "$AUDIT_LOG"

# Test 7: Permission logging
print_test "7" "Permission check logging"

AUDIT_LOG="$HOME/.claude/test-audit.log"
rm -f "$AUDIT_LOG"

log_permission_check "test-tool" "read" "/tmp/test.txt" "allowed"
log_permission_check "test-tool" "write" "$HOME/.ssh/id_rsa" "denied"

if [ -f "$AUDIT_LOG" ]; then
    ALLOW_COUNT=$(grep -c "PERMISSION_CHECK.*allowed" "$AUDIT_LOG" || echo "0")
    DENY_COUNT=$(grep -c "PERMISSION_CHECK.*denied" "$AUDIT_LOG" || echo "0")

    if [ "$ALLOW_COUNT" -eq 1 ] && [ "$DENY_COUNT" -eq 1 ]; then
        pass "Permission checks logged correctly"
    else
        fail "Permission check counts incorrect (allow:$ALLOW_COUNT deny:$DENY_COUNT)"
    fi
else
    fail "Audit log not created for permission checks"
fi

# Clean up
rm -f "$AUDIT_LOG"

# Test 8: Tool-runner integration
print_test "8" "Tool-runner has sandboxing integrated"

if grep -q "sandbox-validator.sh" lib/tool-runner.sh; then
    pass "Tool-runner sources sandbox-validator"
else
    fail "Tool-runner does not source sandbox-validator"
fi

if grep -q "audit-logger.sh" lib/tool-runner.sh; then
    pass "Tool-runner sources audit-logger"
else
    fail "Tool-runner does not source audit-logger"
fi

if grep -q "log_tool_execution" lib/tool-runner.sh; then
    pass "Tool-runner uses audit logging"
else
    fail "Tool-runner does not use audit logging"
fi

# Test 9: Timeout support in tool-runner
print_test "9" "Tool-runner has timeout support"

if grep -q "timeout.*s.*bash" lib/tool-runner.sh; then
    pass "Tool-runner implements timeout for tool execution"
else
    fail "Tool-runner does not implement timeout"
fi

# Test 10: Manifest includes sandboxing components
print_test "10" "Manifest includes sandboxing components"

ALL_IN_MANIFEST=true
for lib_file in "sandbox-validator.sh" "audit-logger.sh"; do
    if ! grep -q "$lib_file" manifest.json; then
        fail "$lib_file not found in manifest.json"
        ALL_IN_MANIFEST=false
    fi
done

if $ALL_IN_MANIFEST; then
    pass "All sandboxing components included in manifest"
fi

# Print summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST SUMMARY - Sandboxing System (Phase 4)"
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
    echo -e "${GREEN}✓ All sandboxing tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
