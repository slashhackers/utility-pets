#!/usr/bin/env bash
# Utility Pet - Uninstaller
# Usage: curl -fsSL https://raw.githubusercontent.com/slashhackers/utility-pets/master/uninstall.sh | bash

set -e

INSTALL_DIR="$HOME/.utility-pets"
APP_PATHS=("/Applications/UtilityPet.app" "$HOME/Applications/UtilityPet.app")
SERVICES_DIR="$HOME/Library/Services"
WORKFLOW_PATH="$SERVICES_DIR/Cast with Scooby.workflow"

echo "================================================"
echo "  🐾 macOS Utility Pet — Uninstaller"
echo "================================================"
echo ""

# 1. Remove Finder Quick Action
if [ -d "$WORKFLOW_PATH" ]; then
  rm -rf "$WORKFLOW_PATH"
  echo "✅ Removed Finder Quick Action: $WORKFLOW_PATH"
fi

# 2. Remove installed app bundles
for APP_PATH in "${APP_PATHS[@]}"; do
  if [ -d "$APP_PATH" ]; then
    rm -rf "$APP_PATH"
    echo "✅ Removed App: $APP_PATH"
  fi
done

# 3. Remove installation directory
if [ -d "$INSTALL_DIR" ]; then
  rm -rf "$INSTALL_DIR"
  echo "✅ Removed installation directory: $INSTALL_DIR"
fi

# 4. Terminate running UtilityPet process
if pkill -x "UtilityPet" 2>/dev/null; then
  echo "✅ Stopped running UtilityPet application."
fi

# 5. Refresh macOS Finder Services cache
pbs -flush 2>/dev/null || true

echo ""
echo "================================================"
echo "  🎉 Utility Pet has been uninstalled!"
echo "================================================"
echo ""

