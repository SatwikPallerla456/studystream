# MyVLC preservation matrix

**Historical checkpoint matrix.** Platform/controls/migration entries below are
superseded by the source implementation and capability table in
[TANGERINE_NATIVE_PLAYER_2026-10-25.md](TANGERINE_NATIVE_PLAYER_2026-10-25.md).
The native default now includes Android/iOS/Windows/Linux; target acceptance is
deferred. Preserve historical evidence without treating these older statuses as
the current backlog.

Source audit: `/Users/satwikpallerla/Documents/ChatGPT/MyPlayer`, including
`Sources/MyPlayer/`, `docs/FEATURE_COVERAGE.md`, and `docs/verification-results.json`.
The source application and its user data have not been modified. Original
verification is historical evidence, not verification of this integration.

## Native boundary and platform decision

The macOS runner reuses `VLCEngine.swift`, `Preferences.swift`, `OptionLexer.swift`
and `MediaLibrary.swift` from the original source. The only compatibility edit in
the copied preference source changes `Bundle.module` to `Bundle.main` for Xcode
resource lookup. `MyVLCBridge.swift` owns engines and stable AppKit video surfaces;
`PlaybackEngine` supplies the existing Flutter player and study progress writer.
All C calls remain serialized on the macOS platform thread. Cleanup stops playback,
detaches the drawable and releases the player/instance. The original engine's
software decoder preference remains intact.

Development builds currently link the VLC 3 installation at `/Applications/VLC.app`;
override `VLC_APP_PATH` in Xcode build settings for another installation. This is
not a self-contained distribution. Runtime bundling/notarization is unfinished.

VideoLAN documents the macOS NSView boundary in its
[libVLC media-player API](https://videolan.videolan.me/vlc-3.0/group__libvlc__media__player.html).
Its supported platform bindings include
[VLCKit for Apple platforms](https://github.com/videolan/vlckit) and
[libVLC Android](https://code.videolan.org/videolan/vlc-android).
These need separate lifecycle/rendering implementations and device verification.
No third-party Flutter package has been selected as a substitute for the original
engine. Android, iOS, Windows and Linux retain an explicitly labeled interim
media_kit backend. The browser continues to use HTML media codecs. Building one
platform does not establish parity on the others.

`--dart-define=TANGERINE_INTERIM_PLAYER=true` selects the earlier working player
for development. The default macOS path is libVLC; failures do not silently select
another engine. Authenticated LAN streams use a temporary loopback range relay:
its random endpoint contains no pairing secret; credentials only go to the exact
upstream address, redirects are not followed, and disposal closes active streams.

## Coverage

“Integrated” means the behavior is wired into the merged application. Runtime
results and device limits are recorded in `TANGERINE_IMPLEMENTATION.md`.

| Original capability and source | Merged application status |
| --- | --- |
| libVLC instance/player/video surface (`VLCEngine`) | Integrated on macOS; native video surface and transport boundary |
| Play/pause, seek, rate, volume/mute | Integrated; existing Flutter transport and progress writer use the native boundary |
| Frame stepping and chapters | Integrated on macOS; frame action under video and chapter selection in Playback tools |
| Embedded audio/subtitle tracks and external subtitles | Integrated on macOS; saved external assignments reopen with the item |
| Equalizer/preamp (`VLCEngine`, `PlayerFeatures`) | Integrated on macOS with ten bands, preamp and per-title persistence |
| Brightness/contrast/saturation/gamma and timing | Integrated on macOS; per-title effects and reset in Playback tools |
| Crop/aspect/zoom/deinterlace/output devices/snapshots | Original engine APIs retained; merged controls remain missing |
| Metadata/statistics | Native diagnostics collected; merged diagnostic UI remains missing |
| Original library/recent/resume (`MediaLibrary`) | Read-only preview and transactional import for local audio/video; current StudyStream identity/progress retained |
| Named playlists, queue, shuffle/repeat/reorder (`PlaylistViews`, `PlayerModel`) | Legacy membership/queue imported and backed up; full editable queue/playlist experience remains missing |
| Playlist M3U/PLS import/export | Original behavior audited; merged actions remain missing |
| Thirteen preference categories/profiles (`Preferences`, `SettingsView`) | Source schema retained; common appearance/playback preferences work; full UI and original-defaults migration remain missing |
| Local/global shortcuts and mouse bindings (`Shortcuts`) | Existing local Flutter transport shortcuts work; editable/global bindings and modifier/mouse parity remain missing |
| Multi-window/mini-player (`PlayerWindowSession`, `DesktopServices`) | Missing from merged app |
| Recording/conversion/stream output (`OutputJobs`) | Missing from merged app; original source tests do not count as merged acceptance |
| Casting (`PlayerFeatures`) | Missing; receiver-dependent verification remains required |
| Camera/mic/screen/discs (`Sheets`, `PlayerFeatures`) | Missing; permission/device-dependent verification remains required |
| Web remote (`WebRemote`) | LAN player/browser and study sync work; original transport-control remote parity remains missing |
| Online subtitle service (`SubtitleWorkflows`) | Missing; account/API-dependent verification remains required |
| Scrobbling/proxy/Keychain (`Preferences`) | Original credential-store identity retained in copied source; original settings and service workflows are not activated/imported |
| JavaScript add-ons/skins/control-strip customization (`Addons`, `Theme`, `ControlStrip`) | Missing from merged app; VLC Lua/`.vlt` formats remain unsupported as in original |
| Learning tools, notes/bookmarks/PDF/backup/native/browser sync | Existing workflows retained; new engine supplies the same item-based media progress |

## Import behavior

Settings → Preview MyVLC import opens a selected `library.json` without writing.
It counts new/existing items, progress conflicts and playlists, and reports skipped
remote/unsupported or ambiguous duplicate paths. The importer never scans all of
a user's home directory or copies source media. Missing files are retained as
unavailable, preserving their identity/history. File-only imported collections
are excluded from hosting until multiple-source linking is implemented. Individual files can be explicitly
relinked with durable macOS file permission; folder refresh is disabled for these
collections to avoid marking files in other roots missing. The importer does not
widen the server’s approved-root boundary. Repeat imports retain relinked paths.

Import runs in one database transaction. Existing exact-path items keep their IDs;
multiple existing matches require manual resolution. New IDs derive from canonical
file URLs. Legacy `resumeTime` is milliseconds; Swift reference dates use the
2001 epoch. The default conflict policy keeps Tangerine progress; the alternate
policy accepts a newer MyVLC event. Repeat imports preserve newer local progress,
playlist records, queue, subtitle assignments and original files. Invalid playlist
or queue data rolls back the whole import.

Remote stream URLs, original preference/profile defaults and credential-store
secrets are not imported. Playlist artwork, M3U/PLS files and supported-preference
conversion remain open work. Imported membership is preserved as durable settings,
not advertised as a completed playlist experience. Secrets are never read or
copied by the Dart importer.
