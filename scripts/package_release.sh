#!/usr/bin/env bash
# Package app/ release artifacts as downloadable archives for GitHub Releases.
#
# Usage:
#   ./scripts/package_release.sh
#
# Output (in app/):
#   waar_mac_apple_release.zip
#   waar_mac_intel_release.zip
#   waar_windows_release.zip   (if the Windows folder exists)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$REPO_ROOT/app"

if [[ ! -d "$APP_DIR" ]]; then
  echo "App directory not found: $APP_DIR" >&2
  exit 1
fi

package_mac_app() {
  local app_path="$1"
  local zip_path="${app_path%.app}.zip"

  rm -f "$zip_path"
  ditto -c -k --keepParent "$app_path" "$zip_path"
  echo "  -> $zip_path"
}

package_windows_dir() {
  local dir_path="$1"
  local zip_path="${dir_path%/}.zip"

  if [[ ! -d "$dir_path" ]] || [[ -z "$(ls -A "$dir_path" 2>/dev/null)" ]]; then
    echo "  skip empty or missing: $(basename "$dir_path")"
    return 0
  fi

  rm -f "$zip_path"
  (
    cd "$(dirname "$dir_path")"
    zip -r -q "$(basename "$zip_path")" "$(basename "$dir_path")"
  )
  echo "  -> $zip_path"
}

echo "==> Packaging release artifacts in $APP_DIR"
echo

shopt -s nullglob
mac_apps=("$APP_DIR"/waar_mac_*_release.app)
windows_dirs=("$APP_DIR"/waar_windows_release)

if ((${#mac_apps[@]} == 0 && ${#windows_dirs[@]} == 0)); then
  echo "No macOS .app or Windows release folder found under app/." >&2
  exit 1
fi

found=0
for app in "${mac_apps[@]}"; do
  echo "macOS: $(basename "$app")"
  package_mac_app "$app"
  found=1
done

for dir in "${windows_dirs[@]}"; do
  echo "Windows: $(basename "$dir")"
  package_windows_dir "$dir"
  if [[ -d "$dir" && -n "$(ls -A "$dir" 2>/dev/null)" ]]; then
    found=1
  fi
done

if [[ "$found" -eq 0 ]]; then
  echo "No packageable release artifacts found." >&2
  exit 1
fi

echo
echo "Done. Upload the .zip files to GitHub Releases for one-click download."
