#!/bin/bash

set -euo pipefail

PASSED=0
FAILED=0
TEST_NAME=""

start_test_suite() {
  echo "================================================================"
  echo "Test Suite: $1"
  echo "================================================================"
  echo ""
  TEST_NAME="$1"
  PASSED=0
  FAILED=0
}

pass() {
  PASSED=$((PASSED + 1))
  echo "[PASS] $1"
}

fail() {
  FAILED=$((FAILED + 1))
  echo "[FAIL] $1"
  [ "${2:-}" ] && echo "       $2"
}

assert_equals() {
  local actual="$1"
  local expected="$2"
  local msg="${3:-Values not equal}"

  if [ "$actual" = "$expected" ]; then
    return 0
  else
    echo "   Expected: $expected"
    echo "   Actual: $actual"
    return 1
  fi
}

assert_file_exists() {
  local file="$1"
  local msg="${2:-File does not exist: $file}"

  if [ -f "$file" ]; then
    return 0
  else
    echo "   $msg"
    return 1
  fi
}

assert_dir_exists() {
  local dir="$1"
  local msg="${2:-Directory does not exist: $dir}"

  if [ -d "$dir" ]; then
    return 0
  else
    echo "   $msg"
    return 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="${3:-String does not contain expected value}"

  if echo "$haystack" | grep -q "$needle"; then
    return 0
  else
    echo "   Expected to contain: $needle"
    echo "   Actual: $haystack"
    return 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="${3:-String should not contain value}"

  if ! echo "$haystack" | grep -q "$needle"; then
    return 0
  else
    echo "   Should not contain: $needle"
    echo "   Actual: $haystack"
    return 1
  fi
}

assert_command_success() {
  local cmd="$1"
  local msg="${2:-Command failed: $cmd}"

  if eval "$cmd" &>/dev/null; then
    return 0
  else
    echo "   $msg"
    return 1
  fi
}

assert_command_fails() {
  local cmd="$1"
  local msg="${2:-Command should have failed: $cmd}"

  if ! eval "$cmd" &>/dev/null; then
    return 0
  else
    echo "   $msg"
    return 1
  fi
}

assert_executable() {
  local file="$1"
  local msg="${2:-File is not executable: $file}"

  if [ -x "$file" ]; then
    return 0
  else
    echo "   $msg"
    return 1
  fi
}

end_test_suite() {
  local total=$((PASSED + FAILED))
  local percentage=0

  if [ "$total" -gt 0 ]; then
    percentage=$(( (PASSED * 100) / total ))
  fi

  echo ""
  echo "================================================================"
  echo "Results: $PASSED passed, $FAILED failed ($percentage%)"
  echo "================================================================"
  echo ""

  if [ "$FAILED" -gt 0 ]; then
    return 1
  fi
  return 0
}

cleanup_test_logs() {
  rm -f .claude/session_*.log 2>/dev/null || true
  # v3: capsule.db is at global location, not per-project
  rm -f "$HOME/.claude/capsule.db" 2>/dev/null || true
  rm -f .claude/last_refresh_state.txt 2>/dev/null || true
}
