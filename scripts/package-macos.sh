#!/usr/bin/env bash
# Package only the release app, never the local user's container or cache.
set -euo pipefail
version="${1:?Pass the release version}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.+~-][a-zA-Z0-9.]+)?$ ]] || { echo 'Invalid release version' >&2; exit 1; }
app=build/macos/Build/Products/Release/Tangerine.app
codesign --verify --deep --strict "$app"
if find "$app" -type f \( -name '*.sqlite' -o -name '*.sqlite-wal' -o -name '*.sqlite-shm' -o -name '.env' \) -print -quit | grep -q .; then
  echo 'Unexpected user data in release app' >&2; exit 1
fi
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/Tangerine.app"
ln -s /Applications "$stage/Applications"
mkdir -p dist
hdiutil create -volname Tangerine -srcfolder "$stage" -ov -format UDZO "dist/Tangerine-${version}-macos-universal.dmg"
hdiutil verify "dist/Tangerine-${version}-macos-universal.dmg"
