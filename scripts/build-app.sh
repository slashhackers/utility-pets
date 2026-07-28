#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
configuration="${1:-release}"
app_name="Utility Pets"
app_dir="$project_dir/dist/$app_name.app"
binary="$project_dir/.build/$configuration/UtilityPet"
identity="${CODE_SIGN_IDENTITY:--}"
cd "$project_dir"
swift build -c "$configuration"
rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary" "$app_dir/Contents/MacOS/UtilityPet"
chmod +x "$app_dir/Contents/MacOS/UtilityPet"
if [ -f "$project_dir/App/UtilityPets/Resources/AppIcon.icns" ]; then
  cp "$project_dir/App/UtilityPets/Resources/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
fi
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>UtilityPet</string>
<key>CFBundleIdentifier</key><string>dev.utilitypets.app</string>
<key>CFBundleName</key><string>Utility Pets</string>
<key>CFBundleDisplayName</key><string>Utility Pets</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSServices</key><array><dict>
<key>NSMenuItem</key><dict><key>default</key><string>Cast with Scooby</string></dict>
<key>NSMessage</key><string>castWithScooby</string>
<key>NSPortName</key><string>Utility Pets</string>
<key>NSSendTypes</key><array><string>public.file-url</string></array>
</dict></array>
</dict></plist>
PLIST
codesign --force --sign "$identity" "$app_dir"
codesign --verify --deep --strict --verbose=2 "$app_dir"
echo "Built: $app_dir"
