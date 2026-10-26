# Tangerine VideoLAN backend

Local Flutter plugin for Android, iOS, Windows and Linux. macOS continues to use
`Runner/MyVLCBridge.swift` and the retained MyVLC libVLC engine. The shared Dart
boundary is `lib/data/playback/playback_engine.dart`. These implementations have
not yet been built or accepted on target devices; testing is a separate phase.

## Dependencies

| Target | Binding / required runtime |
| --- | --- |
| Android | `org.videolan.android:libvlc-all:3.6.5`, Maven Central; min SDK 24, Java 17. SurfaceTexture rendering. |
| iOS | `MobileVLCKit 3.6.0`, CocoaPods; iOS 15+. UIView drawable and AVAudioSession. |
| Windows | VLC **3** runtime and SDK of the target architecture. Set `VLC_ROOT` before CMake configuration. The directory must include `sdk/include/vlc/vlc.h` (or `include/vlc/vlc.h`), `libvlc.dll`, `libvlccore.dll`, dependent DLLs and `plugins/`. The DLL resolver avoids requiring a MinGW import library in MSVC. Runtime DLLs/plugins/licenses are installed alongside the executable. |
| Linux | System libVLC **3**, development headers, pkg-config metadata and runtime plugins. For Debian/Ubuntu packaging these normally come from `libvlc-dev`, `libvlc5`, `vlc-plugin-base` and `vlc-plugin-video-output`. Other distributions use their own package names. Software texture rendering works without X11 window handles. |

`flutter pub get` resolves the local plugin and desktop multi-window package.
`pod install` resolves the iOS runtime. Windows/Linux dependency provisioning and
release artifact/signing checks remain part of distribution work. No runtime is
silently replaced by another engine. The explicit development escape hatch is
`--dart-define=TANGERINE_INTERIM_PLAYER=true`.

## Capability contract

Every session reports capabilities; unavailable actions are omitted from the UI
or reject explicitly. All four implementations provide playback, seek/rate/volume,
tracks, subtitles, chapters, ten-band EQ, timing delays and diagnostics/metadata.

- Android: texture aspect/crop/scale; audio focus and headphone-disconnect pause.
  Physical output routing uses Android's system media controls. Picture
  filters, frame stepping, snapshots, conversion/recording/casting are not
  advertised through the Java binding.
- iOS: aspect/crop/scale, deinterlacing/picture adjustment, system audio route
  picker, interruption/route-loss handling. Desktop outputs and frame stepping
  are not advertised.
- Windows/Linux: aspect/crop/scale, deinterlacing/picture adjustment, audio output
  enumeration/selection, frame stepping, snapshots, fullscreen and window policy.
  Shared software video frames are capped at 1920×1080; decoding still uses VLC.
  Texture aspect/crop/zoom is presented in Flutter, avoiding dependence on an
  external VLC window. Snapshots export the native source frame.
- macOS: retains mini-player, outputs/recording/conversion/casting, snapshots,
  frame stepping and the original engine's option catalog.

Global shortcuts have native bridges on macOS and Windows. Linux global shortcut
portals/X11 registration are not advertised; local keyboard/mouse bindings work
inside the player. Mobile fullscreen hides system chrome. Mobile playback pauses
when the app enters the background; this plugin does not advertise a foreground
media service or background audio session workflow.

Desktop UI uses pinned `tray_manager 0.5.2` and `local_notifier 0.1.6` from the
primary engine only. Linux build packaging additionally needs AppIndicator
(`libayatana-appindicator3-dev` or its distribution equivalent) and `libnotify-dev`.
GNOME may require an AppIndicator extension; notifications need OS permission.
These components do not change the libVLC decode boundary.

## Ownership

A Flutter engine owns its channel/plugin. Each player owns its libVLC instance,
player, media and render resources. Surface/texture cleanup stops decoding before
unregistering/freeing output storage. Linux frame notifications are coalesced and
hold an object reference until delivery; Windows unregistration retains storage
until its completion callback. The Windows DLL module is process-owned.

The primary desktop engine alone runs background library work. Independent
windows own player sessions and temporary queues; shared playlists/progress stay
in the same WAL database. At most eight child playback windows are admitted.
Credentialed HTTP input passes through the existing authenticated loopback relay;
credentials are not serialized into VLC input URLs or window arguments.

`native/vlc_windows_symbols.h` is generated from the core's public API calls by
`python3 scripts/generate-windows-vlc-symbols.py` at the repository root. Regenerate
it after adding a libVLC call. This is source generation, not a target build.

The bridge source is MIT-licensed. VideoLAN runtimes and their bundled modules
retain their upstream licenses; release packaging must retain the corresponding
notices/source obligations rather than treating the bridge license as a license
for VLC. See [VideoLAN libVLC](https://www.videolan.org/vlc/libvlc.html),
[VLCKit](https://github.com/videolan/vlckit),
[Android audio focus](https://developer.android.com/media/optimize/audio-focus)
and [Apple interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions).
