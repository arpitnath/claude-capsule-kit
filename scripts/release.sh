#!/bin/bash
# Complete release workflow for Claude Capsule Kit
# Usage: ./scripts/release.sh <version>
# Example: ./scripts/release.sh v1.0.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

NEW_VERSION="$1"

if [ -z "$NEW_VERSION" ]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 v1.0.0"
  exit 1
fi

# Ensure version starts with 'v'
if [[ ! "$NEW_VERSION" =~ ^v ]]; then
  NEW_VERSION="v$NEW_VERSION"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Claude Capsule Kit Release Workflow"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📌 Target version: $NEW_VERSION"
echo ""

cd "$ROOT_DIR"

# Check for uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  echo "⚠️  Warning: You have uncommitted changes"
  echo ""
  git status --short
  echo ""
  read -p "Continue anyway? (y/n) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
  echo ""
fi

# Step 1: Update version strings
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Step 1/5: Updating Version Strings"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if bash "$SCRIPT_DIR/update-version.sh" "$NEW_VERSION"; then
  echo ""
  echo "✅ Version strings updated successfully"
else
  echo ""
  echo "❌ Failed to update version strings"
  exit 1
fi
echo ""

# Step 2: Verify tool source builds
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔨 Step 2/4: Verifying Tool Source Builds"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Note: Users build binaries locally during installation"
echo ""

if bash "$SCRIPT_DIR/build-all-binaries.sh"; then
  echo ""
  echo "✅ Tool sources build successfully"
else
  echo ""
  echo "❌ Failed to build tool sources"
  exit 1
fi
echo ""

# Step 3: Commit changes
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💾 Step 3/4: Committing Changes"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Modified files:"
git status --short
echo ""

read -p "Commit these changes? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "❌ Release cancelled"
  exit 1
fi

git add .
git commit -m "chore: bump version to $NEW_VERSION

- Updated version strings in manifest.json, README.md, install script
- Updated tool source code version strings
- Users build tools locally during installation (no pre-built binaries)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

echo ""
echo "✅ Changes committed"
echo ""

# Step 4: Create tag
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏷️  Step 4/4: Creating Git Tag"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if git tag -l "$NEW_VERSION" | grep -q "$NEW_VERSION"; then
  echo "⚠️  Tag $NEW_VERSION already exists locally"
  read -p "Delete and recreate? (y/n) " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    git tag -d "$NEW_VERSION"
    echo "Deleted local tag $NEW_VERSION"
  else
    echo "❌ Release cancelled"
    exit 1
  fi
  echo ""
fi

git tag -a "$NEW_VERSION" -m "Release $NEW_VERSION

Claude Capsule Kit - Persistent Context Memory System for Claude Code

This release includes:
- Updated binaries for all supported platforms
- Version $NEW_VERSION verified across all tools

🤖 Generated with [Claude Code](https://claude.com/claude-code)"

echo "✅ Created tag $NEW_VERSION"
echo ""

# Final summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Release $NEW_VERSION Ready!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Summary:"
echo "   • Version strings updated"
echo "   • Tool sources verified (build successfully)"
echo "   • Changes committed"
echo "   • Git tag $NEW_VERSION created"
echo ""
echo "ℹ️  Note: Users build binaries locally during installation"
echo ""
echo "🚀 Next steps:"
echo "   1. Push to GitHub:"
echo "      git push origin master && git push origin $NEW_VERSION"
echo ""
echo "   2. Create GitHub release:"
echo "      gh release create $NEW_VERSION --generate-notes"
echo ""
echo "   Or run both automatically:"
read -p "Push and create GitHub release now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo ""
  echo "Pushing to GitHub..."
  git push origin master
  git push origin "$NEW_VERSION"
  echo "✅ Pushed to GitHub"
  echo ""

  echo "Creating GitHub release..."
  if command -v gh &> /dev/null; then
    gh release create "$NEW_VERSION" \
      --title "Claude Capsule Kit $NEW_VERSION" \
      --notes "Claude Capsule Kit - Persistent Context Memory System for Claude Code

This release includes updated binaries for all supported platforms.

## Installation

\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/arpitnath/claude-capsule-kit/$NEW_VERSION/install | bash
\`\`\`

## What's Changed
See commit history for detailed changes.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
    echo "✅ GitHub release created"
  else
    echo "⚠️  gh CLI not found. Install it to create releases automatically:"
    echo "   brew install gh"
    echo ""
    echo "   Or create the release manually at:"
    echo "   https://github.com/arpitnath/claude-capsule-kit/releases/new?tag=$NEW_VERSION"
  fi
else
  echo ""
  echo "⏸️  Release prepared locally. Push manually when ready:"
  echo "   git push origin master && git push origin $NEW_VERSION"
  echo "   gh release create $NEW_VERSION --generate-notes"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
