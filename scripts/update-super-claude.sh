#!/bin/bash
# Claude Capsule Kit Update Script
# Checks for updates and upgrades to latest version
# Author: Arpit Nath

set -euo pipefail

# Parse flags
DEV_MODE=false
TARGET_VERSION=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --dev)
      DEV_MODE=true
      echo "🔧 Development mode enabled - will update regardless of version"
      echo ""
      shift
      ;;
    --version)
      TARGET_VERSION="$2"
      echo "📌 Target version: $TARGET_VERSION"
      echo ""
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--dev] [--version <tag>]"
      echo ""
      echo "Options:"
      echo "  --dev              Use local repository for testing"
      echo "  --version <tag>    Install specific version (e.g., v2.0.0)"
      echo ""
      exit 1
      ;;
  esac
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔄 Claude Capsule Kit Update Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if we're in a Claude Capsule Kit installation
if [ ! -d ".claude" ]; then
  echo "❌ Error: Not in a Claude Capsule Kit installation"
  echo "   Run this from your project directory"
  exit 1
fi

# Get current version
if [ -f ".claude/.super-claude-version" ]; then
  CURRENT_VERSION=$(cat .claude/.super-claude-version)
  echo "Current version: $CURRENT_VERSION"
else
  echo "⚠️  No version file found (pre-v1.1.0 installation)"
  CURRENT_VERSION="unknown"
fi

# Determine target version
if [ -n "$TARGET_VERSION" ]; then
  # User specified a version
  INSTALL_VERSION="$TARGET_VERSION"
  echo "Target version: $INSTALL_VERSION (user-specified)"
else
  # Get latest version from GitHub
  echo "Checking for updates..."
  INSTALL_VERSION=$(curl -fsSL --max-time 5 https://raw.githubusercontent.com/arpitnath/claude-capsule-kit/master/manifest.json 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin)['version'])" 2>/dev/null || echo "")

  if [ -z "$INSTALL_VERSION" ]; then
    echo "❌ Failed to check for updates (network error or timeout)"
    exit 1
  fi

  echo "Latest version:  $INSTALL_VERSION"
fi
echo ""

# Compare versions
if [ "$CURRENT_VERSION" = "$INSTALL_VERSION" ] && [ "$DEV_MODE" = false ] && [ -z "$TARGET_VERSION" ]; then
  echo "✅ Already on latest version"
  echo ""
  echo "Current version: $CURRENT_VERSION"
  echo "No update needed"
  echo ""
  echo "💡 Tip: Use --dev flag to force update for testing/development"
  echo "💡 Tip: Use --version <tag> to install a specific version"
  exit 0
fi

# Offer update
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Update Available"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Current: $CURRENT_VERSION"
echo "Target:  $INSTALL_VERSION"
echo ""
read -p "Update now? (y/n) " -n 1 -r
echo ""
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Update cancelled"
  exit 0
fi

# Backup current installation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💾 Backing up current installation..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
BACKUP_DIR=".claude/.backup-$(date +%s)"
mkdir -p "$BACKUP_DIR"

# Backup critical files
if [ -d ".claude/hooks" ]; then
  cp -r .claude/hooks "$BACKUP_DIR/" && echo "✓ Hooks backed up"
fi

if [ -d ".claude/skills" ]; then
  cp -r .claude/skills "$BACKUP_DIR/" && echo "✓ Skills backed up"
fi

if [ -d ".claude/agents" ]; then
  cp -r .claude/agents "$BACKUP_DIR/" && echo "✓ Agents backed up"
fi

if [ -d ".claude/scripts" ]; then
  cp -r .claude/scripts "$BACKUP_DIR/" && echo "✓ Scripts backed up"
fi

if [ -f ".claude/settings.local.json" ]; then
  cp .claude/settings.local.json "$BACKUP_DIR/" && echo "✓ Settings backed up"
fi

echo ""
echo "Backup saved to: $BACKUP_DIR"
echo ""

# Download and run installer
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$DEV_MODE" = true ]; then
  echo "🔧 Installing from local repository..."
else
  echo "⬇️  Downloading and installing update..."
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$DEV_MODE" = true ]; then
  # Dev mode: Use local install script
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
  if [ -f "$SCRIPT_DIR/install" ]; then
    bash "$SCRIPT_DIR/install"
  else
    echo "❌ Error: Local install script not found at $SCRIPT_DIR/install"
    echo "   Make sure you're running from the claude-capsule-kit repository"
    exit 1
  fi
else
  if [ -n "$TARGET_VERSION" ]; then
    INSTALL_URL="https://raw.githubusercontent.com/arpitnath/claude-capsule-kit/${TARGET_VERSION}/install"
    curl -fsSL "$INSTALL_URL" | VERSION="$TARGET_VERSION" bash
  else
    INSTALL_URL="https://raw.githubusercontent.com/arpitnath/claude-capsule-kit/master/install"
    curl -fsSL "$INSTALL_URL" | bash
  fi
fi

echo ""

# Apply hook error fix for users on v2.0.0 or v2.0.1
if [ -f ".claude/scripts/fix-hook-errors.sh" ]; then
  echo "Applying hook error fix..."
  bash .claude/scripts/fix-hook-errors.sh
  echo ""
fi

# Check if migration needed
if [ "$CURRENT_VERSION" != "unknown" ]; then
  OLD_MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1 | tr -d 'v')
  OLD_MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)
  NEW_MAJOR=$(echo "$INSTALL_VERSION" | cut -d. -f1 | tr -d 'v')
  NEW_MINOR=$(echo "$INSTALL_VERSION" | cut -d. -f2)

  # Check if migration script exists
  MIGRATION_SCRIPT=".claude/scripts/migrate-${OLD_MAJOR}.${OLD_MINOR}-to-${NEW_MAJOR}.${NEW_MINOR}.sh"

  if [ "$OLD_MAJOR" != "$NEW_MAJOR" ] || [ "$OLD_MINOR" != "$NEW_MINOR" ]; then
    if [ -f "$MIGRATION_SCRIPT" ]; then
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "🔄 Running migration script..."
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
      bash "$MIGRATION_SCRIPT"
      echo ""
    fi
  fi
fi

# Verify new version
if [ -f ".claude/.super-claude-version" ]; then
  INSTALLED_VERSION=$(cat .claude/.super-claude-version)
else
  INSTALLED_VERSION="unknown"
fi

# Clean up backup on successful installation
echo ""
echo "Cleaning up temporary backup..."
if [ -d "$BACKUP_DIR" ]; then
  rm -rf "$BACKUP_DIR"
  echo "✓ Backup removed (installation successful)"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Update Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Updated: $CURRENT_VERSION → $INSTALLED_VERSION"
echo ""
echo "🔄 Restart Claude Code to use the updated version"
echo ""
echo "📖 To see what's new:"
echo "   cat .claude/docs/CHANGELOG.md"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
