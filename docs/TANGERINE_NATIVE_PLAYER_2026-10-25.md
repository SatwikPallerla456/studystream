# Native player/platform implementation — 25 October 2026

## Findings saved before changes

Source review only, following the user's cancellation of screenshot review.
PlaybackEngine selects libVLC only on macOS and AppKitView is hard-coded. Android,
iOS, Windows and Linux use the interim engine. Native output/window controls show
capabilities that are presently macOS-specific without a shared capability model.
The independent desktop player window journey is absent; the floating mini-player
reuses its owner's engine. Live Playback tools expose EQ/picture/timing/chapters
but not the engine's framing/output-device/diagnostic API. Shortcut editing has
only eleven actions and no mouse bindings. Imported settings are restricted to
engine values and speed; original named profiles/equalizers and playlist artwork
are not migrated. Export supports M3U only.

## Implementation contract

Use real VideoLAN libVLC bindings with an explicit interim development flag and
no silent backend fallback. Keep authenticated relay credentials off engine URLs.
Each native player owns its instance, rendering surface, callbacks and cleanup.
Desktop secondary windows own independent playback/queue context and retain
contextual Study/progress. Preserve file IDs and existing saved user settings.
Expose capabilities honestly; a backend must reject unsupported commands rather
than acknowledge them without an effect. Live controls are bounded and validated.
Migration is previewed, transactional/idempotent, non-secret and keeps originals.

Reference: retained MyVLC VLCEngine/Preferences/Shortcuts/MediaLibrary sources,
P0/P11 master-plan requirements and the Plex/Panel identity/resource ownership
findings. Public libVLC/VLCKit platform APIs govern the new platform bindings.
No tests, analyzers, builds, screenshots or runtime acceptance in this pass.

## Source implementation record

- Added `packages/tangerine_vlc/`: Android libVLC-all 3.6.5 with an owned
  SurfaceTexture; iOS MobileVLCKit 3.6.0 with a UIView; Windows/Linux libVLC 3 with
  bounded software textures. Native playback is now the default on all five
  native targets. The interim flag remains explicit and has no silent fallback.
- Added capability negotiation at creation and state polling. Supported controls
  are exposed per backend rather than acknowledging unavailable commands.
- Added independent desktop engines/windows, temporary queue namespaces, plugin
  registration in every engine, per-window folder scope restoration on macOS,
  WAL/busy-timeout database opening and cross-engine invalidation. The primary
  engine alone starts library processing/sync workers. Eight child windows are
  admitted. Close requests flush playback progress before native destruction;
  orphaned temporary queues are pruned without deleting shared playlists.
- Playback tools now present live aspect/crop/scale, deinterlace and picture
  controls, EQ, delays, chapters, output devices/system route picker and readable
  metadata/statistics. Texture geometry is owned by Flutter, avoiding reliance on
  an external VLC video window. Windows/Linux snapshots use an explicit save
  picker and export the native source frame.
- All nineteen original action identities are mapped; modifier seek amounts,
  single/double clicks, vertical/horizontal scroll and reversal are editable.
  macOS global shortcuts route through a shared physical-key broker to the
  focused/last-active window; Windows registers the active player's hotkeys.
- Added validated application behavior for auto-start, resume Always/Ask/Never,
  stop-after-item, start-fullscreen, sleep prevention, saved/startup volume,
  compact controls, artwork, control visibility/opacity/history exclusions and
  desktop window title/topmost/opacity/display/size/minimize policies. macOS
  audio-only players use the owning Flutter view's window rather than requiring
  an attached video surface. Saved notes are retained and remain contextual.
- Preference/profile import stages changes until Save. Original JSON/profile
  arrays and macOS exported plist Data values are supported. Original profile
  EQ/picture/timing values are bounded; imported profiles preserve unrelated
  current shortcut bindings. Stable legacy IDs and deletion tombstones prevent
  repeated imports from replacing user edits or resurrecting removed profiles.
- Original playlist artwork is validated during preview (1 MiB encoded-image
  ceiling, 16 MP geometry ceiling, 8 MiB total base64 budget). Repeat imports fill
  missing art without changing existing membership/names. PLS export now joins
  existing M3U export and M3U/PLS import; it exports local approved file references
  without credentials.

## Declared platform boundary

| Area | Android | iOS | Windows / Linux | macOS |
| --- | --- | --- | --- | --- |
| Decode/playback | libVLC-all | MobileVLCKit | libVLC 3 | retained MyVLC/libVLC |
| Presentation | SurfaceTexture + Flutter framing | UIView + VLCKit framing | texture + Flutter framing | AppKit drawable |
| Native picture adjustment / deinterlace | not advertised | present | present | retained |
| Audio output selection | system media controls | system route picker | enumerated VLC devices | enumerated VLC devices |
| Frame step / snapshot | not advertised | not advertised | present | retained |
| Global shortcuts | not advertised | not advertised | Windows present; Linux local only | present |
| Independent windows | desktop only | desktop only | present | present; mini-player retained |
| Recording / conversion / casting | not advertised | not advertised | not advertised | retained |

Mobile app-background transitions pause playback; interruption/headphone-route
handling is source-implemented. A foreground Android media service/background iOS
audio workflow is not advertised. Linux positioning/topmost/opacity behavior is
subject to the window compositor. Linux global shortcut portals are not supplied.
Windows/Linux software output is capped at 1920×1080 per session; release hardware
and resource ceilings have not been measured. See the plugin README for runtime
provisioning. None of this establishes device or distribution acceptance.

## Additional preference workflows completed in source

The primary engine now owns the menu-bar/system-tray icon, show/quit menu,
tray-enabled hidden startup and track-change notifications with duration/minimized
policy. Child engines route notification/open-window requests through the primary
engine; registration preserves the primary macOS notification delegate. Desktop
notifications require OS permission; Linux tray presentation requires a panel or
AppIndicator extension. Errors appear in Player controls rather than failing
playback or hiding a window before its tray icon is configured.

Embedded-versus-independent playback is applied before engine creation. New
windows copy the selected position/title and their own queue snapshot when
appropriate, with admission serialized by the primary engine. A finish action
can stop, minimize or quit; quit preparation pauses/flushes every open player
before termination. Snapshot folder/prefix/format/width/sequential numbering and
preview are applied. Original decimal-string slider values are validated and
normalized without losing custom seek amounts. Queue repeat/shuffle and volume
step migrate and apply; unrelated saves do not reshuffle an unchanged queue.
Playlist folder grouping preserves queue order and keeps reordering in flat mode.
The retained macOS engine's safe startup DSP toggles are exposed through its
existing argument builder (normalization, compressor/night/spatial effects,
visualizer and two-pass EQ); mobile/portable engine catalogs remain narrower.

This is not all-original-category or all-platform-output parity. Tangerine's
existing theme/library/setup controls remain authoritative; custom skins/control
strip/add-ons belong to N09. Service credentials, proxy/scrobble/subtitle accounts,
capture/discs, wallpaper output and release/update infrastructure remain the
separate backlog areas. Imported settings are restricted to documented supported
behavior/engine/picture fields. Normal volume is bounded to 100 in the shared UI;
original volume-boost and other unexposed advanced catalog policies are not
claimed as working migrated controls.

## Evidence and separate testing phase

Only source inspection, dependency resolution, formatting and graph maintenance
were performed. `flutter pub get` and iOS `pod install` completed for iOS/macOS; MobileVLCKit
3.6.0 is resolved in Podfile.lock. iOS 15 and a distinct Profile.xcconfig are
explicit. Pinned desktop dependencies are tray_manager 0.5.2 and local_notifier
0.1.6. macOS CocoaPods completed with custom-base-configuration and generated
DART_DEFINES parsing warnings: existing project configs include Flutter/Pods and
target AppInfo inherits flags, but final configuration/build acceptance is still
pending. These are dependency/configuration results, not application builds.
No tests, analyzer, compiler/build, startup, screenshot or acceptance journey was
run. Earlier historical passes do not validate these changes.

Graphify query/path scoped the player/settings/window review. The graph was
rebuilt for the new backends; project channel extraction now includes Objective-C
`.m`/`.mm`. A verified structural path is `NativeVlcEngine -> playback_engine.dart
-> tangerine/playback -> TangerineVlcPlugin.kt -> TangerineVlcPlugin` (undirected
edge traversal). Graph relationships do not prove native API/runtime correctness.
Some C macro/Gradle files have partial AST extraction; they stay inventoried.

Cross-engine queue/progress transactions reserve the WAL writer before reading
a mutable snapshot; snapshot numbering uses an atomic settings upsert. Imported
engine fields are validated against their platform catalog, and macOS repeats
validation before constructing its native preference arguments. These remain
source changes rather than concurrency/runtime acceptance evidence.

Later acceptance must cover real platform builds, interrupted/failed opens,
seek/rate/subtitle/EQ/framing/route changes, multiple-window close/queue/history
ownership, runtime packaging, migrations/repeated imports/deletions, PLS round
trips, shortcut focus and memory/surface release. Testing stays separate until
master implementation is complete.
