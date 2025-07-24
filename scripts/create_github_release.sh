#!/bin/bash

# GitHub Release Creator for Prezefren
# Automates GitHub release creation with assets

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Configuration
APP_NAME="Prezefren"
APP_VERSION="1.0.15"
REPO="Hangry-eggplant/Prezefren"
TAG_NAME="v${APP_VERSION}"
RELEASE_NAME="Prezefren v${APP_VERSION}"
DRAFT="${1:-true}"  # Create as draft by default

echo "🚀 Creating GitHub release: $RELEASE_NAME"

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) not found. Please install it:"
    echo "   brew install gh"
    echo "   Then run: gh auth login"
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub. Please run:"
    echo "   gh auth login"
    exit 1
fi

# Verify distribution files exist
DIST_DIR="dist"
if [ ! -d "$DIST_DIR" ]; then
    echo "❌ Distribution directory not found. Please run:"
    echo "   ./scripts/package_release.sh"
    exit 1
fi

REQUIRED_FILES=(
    "${APP_NAME}-${APP_VERSION}.dmg"
    "${APP_NAME}-${APP_VERSION}.zip"
    "RELEASE_NOTES.md"
    "${APP_NAME}-${APP_VERSION}.dmg.sha256"
    "${APP_NAME}-${APP_VERSION}.zip.sha256"
)

echo "🔍 Verifying distribution files..."
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$DIST_DIR/$file" ]; then
        echo "❌ Missing file: $DIST_DIR/$file"
        echo "Please run: ./scripts/package_release.sh"
        exit 1
    fi
    echo "✅ Found: $file"
done

# Create release notes from markdown file
RELEASE_NOTES=$(cat "$DIST_DIR/RELEASE_NOTES.md")

# Check if release already exists
if gh release view "$TAG_NAME" &> /dev/null; then
    echo "⚠️  Release $TAG_NAME already exists"
    read -p "Delete and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️ Deleting existing release..."
        gh release delete "$TAG_NAME" --yes
        git tag -d "$TAG_NAME" 2>/dev/null || true
        git push origin --delete "$TAG_NAME" 2>/dev/null || true
    else
        echo "❌ Aborted"
        exit 1
    fi
fi

# Create git tag
echo "🏷️ Creating git tag..."
git tag "$TAG_NAME" -m "Release $RELEASE_NAME"
git push origin "$TAG_NAME"

# Create GitHub release
echo "📦 Creating GitHub release..."
RELEASE_ARGS=(
    "$TAG_NAME"
    --title "$RELEASE_NAME"
    --notes "$RELEASE_NOTES"
)

if [ "$DRAFT" = "true" ]; then
    RELEASE_ARGS+=(--draft)
    echo "📝 Creating as draft (use --publish to make public)"
else
    echo "🌍 Creating as public release"
fi

# Create the release
gh release create "${RELEASE_ARGS[@]}"

# Upload assets
echo "📤 Uploading release assets..."
cd "$DIST_DIR"

# Upload main distribution files
gh release upload "$TAG_NAME" \
    "${APP_NAME}-${APP_VERSION}.dmg" \
    "${APP_NAME}-${APP_VERSION}.zip" \
    "${APP_NAME}-${APP_VERSION}.dmg.sha256" \
    "${APP_NAME}-${APP_VERSION}.zip.sha256" \
    "verify_installation.sh"

cd ..

# Get release info
RELEASE_URL=$(gh release view "$TAG_NAME" --json url --jq '.url')

echo ""
echo "🎉 GitHub release created successfully!"
echo ""
echo "📋 Release Details:"
echo "├── Tag: $TAG_NAME"
echo "├── Title: $RELEASE_NAME"
echo "├── Status: $([ "$DRAFT" = "true" ] && echo "Draft" || echo "Published")"
echo "├── URL: $RELEASE_URL"
echo "└── Assets: $(gh release view "$TAG_NAME" --json assets --jq '.assets | length') files"
echo ""
echo "📦 Distribution Assets:"
echo "├── ${APP_NAME}-${APP_VERSION}.dmg (macOS installer)"
echo "├── ${APP_NAME}-${APP_VERSION}.zip (app bundle archive)"
echo "├── SHA256 checksums for verification"
echo "└── Installation verification script"
echo ""

if [ "$DRAFT" = "true" ]; then
    echo "📝 Next Steps (Draft Release):"
    echo "1. Review release at: $RELEASE_URL"
    echo "2. Test download and installation"
    echo "3. Publish when ready: gh release edit $TAG_NAME --draft=false"
else
    echo "🌍 Release is now public!"
    echo "1. Share the release URL with users"
    echo "2. Update website with download links"
    echo "3. Announce on social media"
fi

echo ""
echo "🔗 Quick Commands:"
echo "├── View release: gh release view $TAG_NAME"
echo "├── Edit release: gh release edit $TAG_NAME"
echo "├── Download assets: gh release download $TAG_NAME"
echo "└── Delete release: gh release delete $TAG_NAME"