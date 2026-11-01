#!/usr/bin/env bash
# Native Fedora 44 x64 RPM. Requires a release bundle built on Fedora 44.
set -euo pipefail
version="${1:?Pass release version}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.+~-][a-zA-Z0-9.]+)?$ ]] || { echo 'Invalid version' >&2; exit 1; }
bundle="$(pwd)/build/linux/x64/release/bundle"
[[ -x "$bundle/study_stream" ]] || { echo 'Release bundle missing' >&2; exit 1; }
top=$(mktemp -d)
trap 'rm -rf "$top"' EXIT
mkdir -p "$top/BUILD" "$top/RPMS" "$top/SOURCES" "$top/SPECS" "$top/SRPMS" dist
icon="$(pwd)/assets/brand/tangerine.png"
# RPM uses ~ for prereleases so the final 1.0.0 upgrades this preview correctly.
rpmversion="${version/-/\~}"
cat > "$top/SPECS/tangerine.spec" <<SPEC
%global debug_package %{nil}
%global __os_install_post %{nil}
Name: tangerine
Version: $rpmversion
Release: 1%{?dist}
Summary: Tangerine media library, music player and reader
License: LicenseRef-Tangerine
URL: https://github.com/SatwikPallerla456/studystream
Requires: vlc-plugins-base, vlc-plugins-video-out, vlc-plugin-pulseaudio, mpv-libs
BuildArch: x86_64
%description
Local media libraries, music playback, reading and learning tools.
%install
mkdir -p %{buildroot}/opt/tangerine %{buildroot}/usr/bin %{buildroot}/usr/share/applications %{buildroot}/usr/share/icons/hicolor/256x256/apps
cp -a "$bundle/." %{buildroot}/opt/tangerine/
ln -s /opt/tangerine/study_stream %{buildroot}/usr/bin/tangerine
cp "$icon" %{buildroot}/usr/share/icons/hicolor/256x256/apps/tangerine.png
cat > %{buildroot}/usr/share/applications/tangerine.desktop <<DESKTOP
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
%files
/opt/tangerine
/usr/bin/tangerine
/usr/share/applications/tangerine.desktop
/usr/share/icons/hicolor/256x256/apps/tangerine.png
SPEC
rpmbuild --define "_topdir $top" -bb "$top/SPECS/tangerine.spec"
cp "$top"/RPMS/x86_64/*.rpm "dist/Tangerine-${version}-fedora44-x64.rpm"
rpm -qip "dist/Tangerine-${version}-fedora44-x64.rpm"
