#!/bin/sh
# Xcode build phase. Only copies the selected runtime; never changes the VLC app.
set -eu
runtime="${VLC_APP_PATH:-/Applications/VLC.app}/Contents/MacOS"
destination="${TARGET_BUILD_DIR:?}/${FRAMEWORKS_FOLDER_PATH:?}/VLC"
if [ ! -f "$runtime/lib/libvlc.dylib" ]; then
  echo "error: Set VLC_APP_PATH to a VLC 3 installation with headers and libraries."
  exit 1
fi
resources="${TARGET_BUILD_DIR:?}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:?}/VLC"
mkdir -p "$destination" "$resources"
/usr/bin/rsync -a --delete "$runtime/lib/" "$destination/lib/"
/usr/bin/rsync -a --delete --exclude=plugins.dat "$runtime/plugins/" "$resources/plugins/"
# Dynamic loaders resolve plugin dependencies relative to this private rpath.
identity="${EXPANDED_CODE_SIGN_IDENTITY:--}"
if [ -z "$identity" ]; then identity=-; fi
/usr/bin/find "$destination" "$resources/plugins" -type f -name '*.dylib' -exec /usr/bin/codesign --force --sign "$identity" --timestamp=none {} \;
# Retain the distributor's license alongside the bundled runtime.
if [ -f "${VLC_APP_PATH:-/Applications/VLC.app}/Contents/Resources/COPYING.txt" ]; then
  /bin/cp "${VLC_APP_PATH:-/Applications/VLC.app}/Contents/Resources/COPYING.txt" "$destination/COPYING.txt"
fi
