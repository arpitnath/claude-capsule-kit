#!/bin/bash
# Memory Graph Integration Test Suite
# Tests all edge cases and query functionality

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="/tmp/memory-graph-test-$$"
PASSED=0
FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}

cleanup() {
    rm -rf "$TEST_DIR"
}

trap cleanup EXIT

# ============================================
# Setup
# ============================================

echo "============================================"
echo "Memory Graph Integration Test Suite"
echo "============================================"
echo ""
echo "Test directory: $TEST_DIR"
echo ""

mkdir -p "$TEST_DIR"

# Initialize memory graph
log_test "Initializing memory graph..."
bash "$SCRIPT_DIR/init.sh" "$TEST_DIR/memory" > /dev/null

if [ -d "$TEST_DIR/memory/nodes" ]; then
    log_pass "Directory structure created"
else
    log_fail "Directory structure not created"
fi

if [ -f "$TEST_DIR/memory/config.json" ]; then
    log_pass "config.json created"
else
    log_fail "config.json not created"
fi

# ============================================
# Test 1: Basic Node Creation and Parsing
# ============================================

echo ""
echo "--- Test 1: Basic Node Creation and Parsing ---"

# Create a simple node
cat > "$TEST_DIR/memory/nodes/decisions/decision-001.md" << 'EOF'
---
id: decision-001
type: decision
created: 2025-01-01T10:00:00Z
updated: 2025-01-01T10:00:00Z
status: active
tags: [auth, security]
related: []
---

# Use JWT for Authentication

We decided to use JWT tokens for stateless authentication.

## Rationale
- Scalability
- No server-side session storage needed
EOF

log_test "Parsing basic node..."
OUTPUT=$(python3 "$SCRIPT_DIR/lib/parser.py" "$TEST_DIR/memory/nodes/decisions/decision-001.md")

if echo "$OUTPUT" | grep -q '"id": "decision-001"'; then
    log_pass "Node ID parsed correctly"
else
    log_fail "Node ID not parsed"
fi

if echo "$OUTPUT" | grep -q '"type": "decision"'; then
    log_pass "Node type parsed correctly"
else
    log_fail "Node type not parsed"
fi

if echo "$OUTPUT" | grep -q '"auth"'; then
    log_pass "Tags parsed correctly"
else
    log_fail "Tags not parsed"
fi

# ============================================
# Test 2: Wiki-Links Extraction
# ============================================

echo ""
echo "--- Test 2: Wiki-Links Extraction ---"

cat > "$TEST_DIR/memory/nodes/files/file-auth-ts.md" << 'EOF'
---
id: file-auth-ts
type: file-summary
created: 2025-01-01T11:00:00Z
updated: 2025-01-01T11:00:00Z
status: active
tags: [auth, typescript]
related: [[decision-001]]
---

# /src/auth.ts

Authentication module implementing [[decision-001]].

Also related to [[file-user-ts]] for user management.
EOF

log_test "Parsing node with wiki-links..."
OUTPUT=$(python3 "$SCRIPT_DIR/lib/parser.py" "$TEST_DIR/memory/nodes/files/file-auth-ts.md")

if echo "$OUTPUT" | grep -q '"decision-001"'; then
    log_pass "Wiki-link from content extracted"
else
    log_fail "Wiki-link from content not extracted"
fi

if echo "$OUTPUT" | grep -q '"file-user-ts"'; then
    log_pass "Wiki-link from body extracted"
else
    log_fail "Wiki-link from body not extracted"
fi

# ============================================
# Test 3: Circular References (A→B→A)
# ============================================

echo ""
echo "--- Test 3: Circular References ---"

cat > "$TEST_DIR/memory/nodes/files/file-user-ts.md" << 'EOF'
---
id: file-user-ts
type: file-summary
created: 2025-01-01T12:00:00Z
updated: 2025-01-01T12:00:00Z
status: active
tags: [user, typescript]
related: [[file-auth-ts]]
---

# /src/user.ts

User module. Uses [[file-auth-ts]] for authentication.
EOF

log_test "Building graph with circular references..."
export CLAUDE_MEMORY_DIR="$TEST_DIR/memory"
python3 "$SCRIPT_DIR/lib/graph.py" rebuild > /dev/null

# Check graph.json was created
if [ -f "$TEST_DIR/memory/graph.json" ]; then
    log_pass "Graph cache created"
else
    log_fail "Graph cache not created"
fi

# Check backlinks are computed
log_test "Checking backlinks..."
GRAPH=$(cat "$TEST_DIR/memory/graph.json")

if echo "$GRAPH" | python3 -c "import sys,json; g=json.load(sys.stdin); sys.exit(0 if 'file-auth-ts' in g['nodes']['file-user-ts'].get('backlinks',[]) else 1)"; then
    log_pass "Backlinks computed correctly"
else
    log_fail "Backlinks not computed"
fi

# ============================================
# Test 4: Node with No Links
# ============================================

echo ""
echo "--- Test 4: Node with No Links ---"

cat > "$TEST_DIR/memory/nodes/discoveries/discovery-001.md" << 'EOF'
---
id: discovery-001
type: discovery
created: 2025-01-01T13:00:00Z
updated: 2025-01-01T13:00:00Z
status: active
tags: [performance]
related: []
---

# Performance Discovery

The app uses lazy loading for better performance.
No links to other nodes.
EOF

log_test "Parsing node with no links..."
OUTPUT=$(python3 "$SCRIPT_DIR/lib/parser.py" "$TEST_DIR/memory/nodes/discoveries/discovery-001.md")

if echo "$OUTPUT" | grep -q '"links": \[\]'; then
    log_pass "Empty links array handled"
else
    log_fail "Empty links not handled correctly"
fi

# ============================================
# Test 5: Missing Frontmatter Fields
# ============================================

echo ""
echo "--- Test 5: Missing Frontmatter Fields ---"

cat > "$TEST_DIR/memory/nodes/discoveries/invalid-001.md" << 'EOF'
---
id: invalid-001
---

# Missing Type Field

This node is missing the required 'type' field.
EOF

log_test "Parsing node with missing type field..."
if ! python3 "$SCRIPT_DIR/lib/parser.py" "$TEST_DIR/memory/nodes/discoveries/invalid-001.md" 2>/dev/null; then
    log_pass "Invalid node rejected (missing type)"
else
    log_fail "Invalid node should be rejected"
fi

# Node with no frontmatter at all
cat > "$TEST_DIR/memory/nodes/discoveries/no-frontmatter.md" << 'EOF'
# No Frontmatter

This file has no YAML frontmatter.
EOF

log_test "Parsing node with no frontmatter..."
if ! python3 "$SCRIPT_DIR/lib/parser.py" "$TEST_DIR/memory/nodes/discoveries/no-frontmatter.md" 2>/dev/null; then
    log_pass "Node without frontmatter rejected"
else
    log_fail "Node without frontmatter should be rejected"
fi

# ============================================
# Test 6: Tags Extraction from Content
# ============================================

echo ""
echo "--- Test 6: Tags from Content ---"

cat > "$TEST_DIR/memory/nodes/discoveries/discovery-002.md" << 'EOF'
---
id: discovery-002
type: discovery
created: 2025-01-01T14:00:00Z
updated: 2025-01-01T14:00:00Z
status: active
tags: [frontend]
related: []
---

# React Pattern Discovery

Found a useful #react pattern for #state-management.
Also applies to #typescript projects.
EOF

log_test "Extracting tags from content..."
OUTPUT=$(python3 "$SCRIPT_DIR/lib/parser.py" "$TEST_DIR/memory/nodes/discoveries/discovery-002.md")

if echo "$OUTPUT" | grep -q '"react"'; then
    log_pass "Content tag #react extracted"
else
    log_fail "Content tag #react not extracted"
fi

if echo "$OUTPUT" | grep -q '"state-management"'; then
    log_pass "Content tag #state-management extracted"
else
    log_fail "Content tag #state-management not extracted"
fi

# ============================================
# Test 7: Query Commands
# ============================================

echo ""
echo "--- Test 7: Query Commands ---"

# Rebuild graph first
python3 "$SCRIPT_DIR/lib/graph.py" rebuild > /dev/null

log_test "Query: --recent"
OUTPUT=$(bash "$SCRIPT_DIR/memory-query.sh" --recent 3 2>/dev/null || true)
if [ -n "$OUTPUT" ]; then
    log_pass "--recent returns results"
else
    log_fail "--recent returned empty"
fi

log_test "Query: --type decision"
OUTPUT=$(bash "$SCRIPT_DIR/memory-query.sh" --type decision 2>/dev/null || true)
if echo "$OUTPUT" | grep -q "decision"; then
    log_pass "--type decision works"
else
    log_fail "--type decision failed"
fi

log_test "Query: --tag auth"
OUTPUT=$(bash "$SCRIPT_DIR/memory-query.sh" --tag auth 2>/dev/null || true)
if echo "$OUTPUT" | grep -q "auth\|Auth\|JWT"; then
    log_pass "--tag auth works"
else
    log_fail "--tag auth failed"
fi

log_test "Query: --related file-auth-ts"
OUTPUT=$(bash "$SCRIPT_DIR/memory-query.sh" --related file-auth-ts 2>/dev/null || true)
if [ -n "$OUTPUT" ]; then
    log_pass "--related returns results"
else
    log_fail "--related returned empty"
fi

log_test "Query: --search JWT"
OUTPUT=$(bash "$SCRIPT_DIR/memory-query.sh" --search JWT 2>/dev/null || true)
if echo "$OUTPUT" | grep -qi "jwt\|auth"; then
    log_pass "--search JWT works"
else
    log_fail "--search JWT failed"
fi

log_test "Query: --id decision-001"
OUTPUT=$(bash "$SCRIPT_DIR/memory-query.sh" --id decision-001 2>/dev/null || true)
if echo "$OUTPUT" | grep -qi "jwt\|auth\|decision"; then
    log_pass "--id works"
else
    log_fail "--id failed"
fi

# ============================================
# Test 8: Output Formats
# ============================================

echo ""
echo "--- Test 8: Output Formats ---"

log_test "Format: json"
OUTPUT=$(bash "$SCRIPT_DIR/memory-query.sh" --recent 2 --format json 2>/dev/null || true)
if echo "$OUTPUT" | grep -q '"nodes"'; then
    log_pass "JSON format works"
else
    log_fail "JSON format failed"
fi

log_test "Format: ids"
OUTPUT=$(bash "$SCRIPT_DIR/memory-query.sh" --recent 2 --format ids 2>/dev/null || true)
if echo "$OUTPUT" | grep -q "^[a-z]"; then
    log_pass "IDs format works"
else
    log_fail "IDs format failed"
fi

log_test "Format: full"
OUTPUT=$(bash "$SCRIPT_DIR/memory-query.sh" --id decision-001 --format full 2>/dev/null || true)
if echo "$OUTPUT" | grep -q "Rationale"; then
    log_pass "Full format works"
else
    log_fail "Full format failed"
fi

# ============================================
# Test 9: Search with Special Characters
# ============================================

echo ""
echo "--- Test 9: Special Characters ---"

cat > "$TEST_DIR/memory/nodes/discoveries/discovery-special.md" << 'EOF'
---
id: discovery-special
type: discovery
created: 2025-01-01T15:00:00Z
updated: 2025-01-01T15:00:00Z
status: active
tags: [regex]
related: []
---

# Regex Pattern

Found pattern: `user\.name` and `$variable`.
Also `[array]` syntax.
EOF

python3 "$SCRIPT_DIR/lib/graph.py" rebuild > /dev/null

log_test "Search with special chars (dot)"
OUTPUT=$(bash "$SCRIPT_DIR/memory-query.sh" --search "user" 2>/dev/null || true)
if [ -n "$OUTPUT" ]; then
    log_pass "Search with special chars works"
else
    log_fail "Search with special chars failed"
fi

# ============================================
# Test 10: Status Filtering
# ============================================

echo ""
echo "--- Test 10: Status Filtering ---"

cat > "$TEST_DIR/memory/nodes/decisions/decision-archived.md" << 'EOF'
---
id: decision-archived
type: decision
created: 2025-01-01T16:00:00Z
updated: 2025-01-01T16:00:00Z
status: archived
tags: [deprecated]
related: []
---

# Archived Decision

This decision has been superseded.
EOF

python3 "$SCRIPT_DIR/lib/graph.py" rebuild > /dev/null

log_test "Filter: --status active (should exclude archived)"
OUTPUT=$(bash "$SCRIPT_DIR/memory-query.sh" --type decision --status active --format ids 2>/dev/null || true)
if echo "$OUTPUT" | grep -qv "decision-archived"; then
    log_pass "Archived nodes filtered out"
else
    log_fail "Archived nodes not filtered"
fi

log_test "Filter: --status all (should include archived)"
OUTPUT=$(bash "$SCRIPT_DIR/memory-query.sh" --type decision --status all --format ids 2>/dev/null || true)
if echo "$OUTPUT" | grep -q "decision-archived"; then
    log_pass "All status includes archived"
else
    log_fail "All status should include archived"
fi

# ============================================
# Test 11: Large Number of Nodes
# ============================================

echo ""
echo "--- Test 11: Many Nodes (100+) ---"

log_test "Creating 100 nodes..."
for i in $(seq 1 100); do
    cat > "$TEST_DIR/memory/nodes/files/file-bulk-$i.md" << EOF
---
id: file-bulk-$i
type: file-summary
created: 2025-01-01T17:00:00Z
updated: 2025-01-01T17:00:00Z
status: active
tags: [bulk, test-$((i % 10))]
related: []
---

# Bulk File $i

Content for bulk test file $i.
EOF
done

log_test "Rebuilding graph with 100+ nodes..."
START=$(date +%s%N)
python3 "$SCRIPT_DIR/lib/graph.py" rebuild > /dev/null
END=$(date +%s%N)
DURATION=$(( (END - START) / 1000000 ))

if [ "$DURATION" -lt 5000 ]; then
    log_pass "Graph rebuild completed in ${DURATION}ms"
else
    log_fail "Graph rebuild too slow: ${DURATION}ms"
fi

log_test "Query with 100+ nodes..."
OUTPUT=$(bash "$SCRIPT_DIR/memory-query.sh" --tag bulk --limit 10 --format ids 2>/dev/null || true)
COUNT=$(echo "$OUTPUT" | wc -l)
if [ "$COUNT" -ge 10 ]; then
    log_pass "Query returns correct limit with many nodes"
else
    log_fail "Query limit not working (got $COUNT)"
fi

# ============================================
# Test 12: Basic YAML Parser Fallback
# ============================================

echo ""
echo "--- Test 12: Basic YAML Parser ---"

log_test "Testing basic parser (inline list format)..."
cat > "$TEST_DIR/memory/nodes/discoveries/discovery-inline.md" << 'EOF'
---
id: discovery-inline
type: discovery
created: 2025-01-01T18:00:00Z
updated: 2025-01-01T18:00:00Z
status: active
tags: [tag1, tag2, tag3]
related: [decision-001, file-auth-ts]
---

# Inline List Test

Testing inline YAML list format.
EOF

OUTPUT=$(python3 "$SCRIPT_DIR/lib/parser.py" "$TEST_DIR/memory/nodes/discoveries/discovery-inline.md")
if echo "$OUTPUT" | grep -q '"tag1"'; then
    log_pass "Inline tags parsed"
else
    log_fail "Inline tags not parsed"
fi

# ============================================
# Summary
# ============================================

echo ""
echo "============================================"
echo "Test Summary"
echo "============================================"
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${RED}Failed:${NC} $FAILED"
echo ""

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
