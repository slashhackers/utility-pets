#!/usr/bin/env bash
set -euo pipefail

: "${CODE_SIGN_IDENTITY:?Set this to your Developer ID Application certificate name.}"
: "${NOTARY_PROFILE:?Set this to a notarytool keychain profile.}"
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
export CODE_SIGN_IDENTITY
"$project_dir/Scripts/build-app.sh" release
app_path="$project_dir/dist/Utility Pets.app"
archive="$project_dir/dist/Utility-Pets-0.1.0.zip"
codesign --force --options runtime --timestamp --sign "$CODE_SIGN_IDENTITY" "$app_path"
ditto -c -k --keepParent "$app_path" "$archive"
xcrun notarytool submit "$archive" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$app_path"
spctl --assess --type execute --verbose=4 "$app_path"
echo "Notarized release: $archive"
