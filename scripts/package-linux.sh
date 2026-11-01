#!/usr/bin/env bash
# Ubuntu 24.04 x64 installer. Run after flutter build linux --release.
set -euo pipefail
version="${1:?Pass the release version}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.+~-][a-zA-Z0-9.]+)?$ ]] || { echo 'Invalid package version' >&2; exit 1; }
bundle=build/linux/x64/release/bundle
[[ -x "$bundle/study_stream" ]] || { echo 'Linux release bundle missing' >&2; exit 1; }
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/opt/tangerine" "$stage/usr/bin" "$stage/usr/share/applications" "$stage/usr/share/icons/hicolor/256x256/apps" "$stage/DEBIAN" dist
cp -a "$bundle/." "$stage/opt/tangerine/"
ln -s /opt/tangerine/study_stream "$stage/usr/bin/tangerine"
cp assets/brand/tangerine.png "$stage/usr/share/icons/hicolor/256x256/apps/tangerine.png"
cat > "$stage/usr/share/applications/tangerine.desktop" <<'DESKTOP'
[Desktop Entry]
Name=Tangerine
Comment=Media libraries, music, reading and learning
Exec=tangerine
Icon=tangerine
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Video;Education;
StartupNotify=true
DESKTOP
cat > "$stage/DEBIAN/control" <<CONTROL
Package: tangerine
Version: $version
Section: video
Priority: optional
Architecture: amd64
Maintainer: Tangerine <noreply@github.com>
Depends: libgtk-3-0t64, libstdc++6, libsecret-1-0, libnotify4, libayatana-appindicator3-1, libvlc5, vlc-plugin-base, vlc-plugin-video-output, libmpv2, libepoxy0, libwpewebkit-1.0-3, libwpebackend-fdo-1.0-1, libwpe-1.0-1, libwayland-server0
Description: Tangerine media library, player and reader
 Local media libraries, music playback, reading and learning tools.
 Built for Ubuntu 24.04 LTS on x86-64.
CONTROL
chmod 0755 "$stage/DEBIAN"
find "$stage" -type d -exec chmod 0755 {} +
dpkg-deb --root-owner-group --build "$stage" "dist/Tangerine-${version}-linux-x64.deb"
dpkg-deb --info "dist/Tangerine-${version}-linux-x64.deb"
