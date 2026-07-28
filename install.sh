#!/usr/bin/env bash
# macOS Utility Pet - Professional 1-Line Remote Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/slashhackers/utility-pets/master/install.sh | bash

set -e

REPO_OWNER="slashhackers"
REPO_NAME="utility-pets"
INSTALL_DIR="$HOME/.utility-pets"
APP_TARGET_DIR="/Applications"

echo "==============================================="
echo " 🐾 Utility Pet macOS Host - Installer"
echo "==============================================="
echo ""

# 1. Verify macOS System
if [[ "$OSTYPE" != "darwin"* ]]; then
  echo "❌ Error: Utility Pet is designed exclusively for macOS."
  exit 1
fi

echo "✅ macOS $(sw_vers -productVersion) detected."

# 2. Destination path
mkdir -p "$INSTALL_DIR"
if [ -w "$APP_TARGET_DIR" ]; then
  DEST_APP="$APP_TARGET_DIR/Utility Pets.app"
else
  DEST_APP="$HOME/Applications/Utility Pets.app"
  mkdir -p "$HOME/Applications"
fi

# 3. Check for pre-built release binary on GitHub Releases
echo "📦 Fetching latest pre-built app release from GitHub..."
LATEST_RELEASE_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest"
TARBALL_URL=$(curl -s "$LATEST_RELEASE_URL" | grep "browser_download_url.*UtilityPet-macos.tar.gz" | cut -d : -f 2,3 | tr -d \" || true)

if [ -n "$TARBALL_URL" ]; then
  echo "⬇️ Downloading pre-built release from: $TARBALL_URL"
  curl -fsSL "$TARBALL_URL" | tar -xz -C "$INSTALL_DIR"
  if [ -d "$INSTALL_DIR/Utility Pets.app" ]; then
    rm -rf "$DEST_APP"
    cp -r "$INSTALL_DIR/Utility Pets.app" "$DEST_APP"
  elif [ -d "$INSTALL_DIR/UtilityPet.app" ]; then
    rm -rf "$DEST_APP"
    cp -r "$INSTALL_DIR/UtilityPet.app" "$DEST_APP"
  fi
else
  echo "ℹ️ No pre-built release found on GitHub Releases yet. Building from source locally..."
  if command -v swift &> /dev/null; then
    if [ -f "scripts/install-app.sh" ]; then
      bash scripts/install-app.sh
    else
      swift build -c release
      bash scripts/build-app.sh release
      cp -r "dist/Utility Pets.app" "$DEST_APP"
    fi
  else
    echo "❌ Error: Swift compiler not found and pre-compiled release missing."
    echo "💡 Install Xcode Command Line Tools via: xcode-select --install"
    exit 1
  fi
fi

# 4. Register Finder Quick Action Workflow
echo "🔗 Registering macOS Finder Quick Action..."
if [ -f "scripts/install-finder-quick-action.sh" ]; then
  bash scripts/install-finder-quick-action.sh
fi

# 5. Launch Application
echo "🛑 Restarting Utility Pets process..."
killall UtilityPet 2>/dev/null || true
open "$DEST_APP" 2>/dev/null || true

echo ""
echo "==============================================="
echo " 🎉 Utility Pet Installation Complete!"
echo "==============================================="
echo ""
echo "▶️ Installed: $DEST_APP"
echo "💡 Usage: Right-click any video file in Finder -> Quick Actions -> Cast with Scooby"
echo ""


