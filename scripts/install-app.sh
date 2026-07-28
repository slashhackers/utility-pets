#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
"$project_dir/scripts/build-app.sh" debug
app_path="$project_dir/dist/Utility Pets.app"
destination="/Applications/Utility Pets.app"

echo "🛑 Terminating existing UtilityPets process if running..."
killall UtilityPet 2>/dev/null || true
sleep 0.5

rm -rf "$destination"
ditto "$app_path" "$destination"
open "$destination"
echo "Installed and opened: $destination"

