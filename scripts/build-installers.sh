#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"

echo "==============================================="
echo " 🛠️ Building Native macOS Installer (.pkg & .dmg)"
echo "==============================================="

# 1. Ensure production app bundle is built
"$PROJECT_DIR/scripts/build-app.sh" release

APP_PATH="$DIST_DIR/Utility Pets.app"
PKG_OUTPUT="$DIST_DIR/UtilityPets.pkg"
DMG_OUTPUT="$DIST_DIR/UtilityPets.dmg"

# 2. Build Native macOS .pkg Package
echo "📦 Creating macOS Installer Package: UtilityPets.pkg..."
rm -f "$PKG_OUTPUT"
pkgbuild \
  --component "$APP_PATH" \
  --install-location "/Applications" \
  --scripts "$PROJECT_DIR/scripts/pkg-scripts" \
  "$PKG_OUTPUT"

# 3. Build Native macOS .dmg Disk Image
echo "💿 Creating macOS Disk Image: UtilityPets.dmg..."
rm -rf "$DIST_DIR/dmg-staging" "$DMG_OUTPUT"
mkdir -p "$DIST_DIR/dmg-staging"
cp -r "$APP_PATH" "$DIST_DIR/dmg-staging/"
ln -s /Applications "$DIST_DIR/dmg-staging/Applications"
cp "$PROJECT_DIR/README.md" "$DIST_DIR/dmg-staging/"

hdiutil create -volname "Utility Pets" -srcfolder "$DIST_DIR/dmg-staging" -ov -format UDZO "$DMG_OUTPUT"
rm -rf "$DIST_DIR/dmg-staging"

echo ""
echo "==============================================="
echo " ✅ Created Native Installers:"
echo " 📦 PKG: $PKG_OUTPUT"
echo " 💿 DMG: $DMG_OUTPUT"
echo "==============================================="
