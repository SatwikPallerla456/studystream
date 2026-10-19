# Tangerine implementation status

Updated 19 October 2026 (Europe/London). This implements the initial engine,
rebrand and local-data migration work. **The full update plan remains incomplete.**

## Delivered

- The normal macOS player uses the original MyVLC `VLCEngine` through a Flutter
  method/native-view boundary, preserving actual libVLC decoding/rendering. Audio,
  video, protected range streams, seek/pause/rate, tracks, subtitles and study
  progress run through that boundary. macOS startup no longer initializes the
  interim media_kit player by default.
- Native playback tools expose chapters, frame stepping, ten-band equalizer and
  preamp, picture adjustments, and audio/subtitle delays. Per-title effects and
  external subtitle assignments persist; loading a paused item stays silent.
- Protected native playback uses an ephemeral loopback relay, without embedding
  companion pairing credentials in libVLC URLs or options. Range requests retain
  the existing server authorization and canonical-root checks. Redirects never
  receive credentials. Closing the player closes the relay and releases native
  player/video ownership.
- Visible app/window/product names, browser player, onboarding, fresh-server
  defaults, backup labels and icons now use Tangerine. Artwork is generated from
  a shared AppKit source for macOS, iOS, Android, Windows and the browser. Saved
  custom server names, appearance, bundle/package IDs, database identity, folder
  bookmarks, credential keys and LAN discovery compatibility are retained.
- Settings has a read-only `library.json` preview with explicit progress-conflict
  policy and a transactional import. Local audio/video, history/resume, subtitle
  assignments, queue and playlist membership are preserved. Repeating the import
  preserves newer progress, original IDs and relinked file locations. Invalid
  records roll back the complete transaction. Original files are never changed.
- File-only imported collections stay local while multiple-source support is
  pending. Explicit individual-file relinking retains macOS file permission;
  folder refresh is disabled for these collections so it cannot mark other
  source roots missing. Stream URLs and original preferences/profiles/artwork
  conversion are not imported.

See `MYVLC_FEATURE_MATRIX.md` for the source-by-source preservation audit and
`TANGERINE_BASELINE.md` for retained identities and storage boundaries.

## Verification

Fresh checks on 18–19 October 2026; earlier MyVLC/StudyStream/REA evidence remains
intact. Tests use synthetic fixtures and isolated databases, not personal media.

| Check | Result |
| --- | --- |
| Dart formatting | Pass |
| `flutter analyze --no-pub` | Pass; no issues |
| `flutter test --no-pub` | Pass; 82 unit/widget tests |
| `python3 scripts/verify-tangerine-native.py` | Pass; both native acceptance journeys |
| `flutter build macos --debug --no-pub` | Pass; `build/macos/Build/Products/Debug/Tangerine.app` |
| `flutter build apk --debug --no-pub` | Pass; `build/app/outputs/flutter-apk/app-debug.apk` |
| `flutter build ios --simulator --no-pub` | Pass; `build/ios/iphonesimulator/Runner.app` |
| Browser player JavaScript syntax (`node --check`) | Pass |
| `git diff --check` | Pass |

The first native journey decodes synthetic audio through libVLC, seeks/pauses,
writes durable media progress, reopens the disk database, renders/changes PDF
pages, and opens the existing library under the Tangerine UI. The second renders
640×360 H.264 video into the native surface, asserts actual decoded/displayed
frame counters, loads external subtitles, changes rate/position, applies effects
and steps a frame. It disposes the local player, pairs with the real protected
LAN server, renders/seeks/pauses remote video through the authenticated range
relay, disposes again, and then exercises the merged player screen itself.
The screen’s native transport, effects modal and automatically persisted progress
are checked. The fixture is embedded only into the integration test build.

Unit/regression coverage includes read-only previews, millisecond/date conversion,
repeat imports after playback and relinking, retained queues/playlists, malformed
record rollback, skipped streams, range/header forwarding, credential-safe relay
URLs, redirect isolation, relay closure, native file-URL normalization, paused
transport, seek boundaries, player cleanup and explicit startup errors. The
existing library, reader, study, server, backup, accessibility/width and reduced
motion checks remain passing.

Logs are under `.verification/tangerine/`. Native acceptance initially exposed
incorrect Xcode references during rebranding, local-path URI normalization and
test expectations for HTTP 201 pairing; these were corrected. One run had a
semantics-handle failure after external accessibility inspection during the test;
subsequent acceptance completed without UI-inspector interference. A later run
was interrupted while diagnosing variable test duration; the final run completed
both journeys in 13 seconds. Those intermediate runs are not counted as passes.

Xcode continues to warn about the installed simulator-runtime version, but all
three builds above completed. Existing media_kit Swift Package Manager and Android
Kotlin/Gradle deprecation warnings remain. No Windows/Linux build or physical
mobile libVLC/hosting acceptance is claimed.

## Remaining roadmap gates

| Milestone | Current status |
| --- | --- |
| A0 | macOS libVLC core/runtime journey passes. Other native libVLC bindings and self-contained runtime packaging remain open. |
| A1 | Source matrix and initial safe local import delivered. Full original workflow parity and supported-preference/profile migration remain open. |
| A | Rebrand and stable storage/identity delivered; fixture database reopen and native/mobile builds pass. |
| B | Source present: typed kinds, source records, source-aware indexing/watchers and generic media_records. Explicit item-source ownership, multiple-root hosting, scoped transport and migration/release acceptance remain open. |
| C | Reader/page-source prototypes present; existing PDF reader retained. Shared Study/locator contracts and reader C0–C6 release acceptance remain open; source presence is not a verified release. |
| D/E | Local JSON provider and metadata prototypes present. Candidate/correction workflows, normalized identities, online integration and TV/next-episode release gates remain open. |
| F/G | Not implemented: typed music/audiobook/podcast/book/photo experiences, collections/albums/playlists and expanded catalog search. |
| H | Not implemented: paginated catalog transport, per-library authorization and large-catalog acceptance. |

Status wording reconciled against current source on 19 October 2026; no app
tests or runtime journeys were rerun during that documentation/investigation
pass. The [master plan](TANGERINE_MASTER_IMPLEMENTATION_PLAN.md) records the
current gaps, dependencies and acceptance gates informed by Panels and targeted
Plex findings. Prior verification above remains historical evidence.

A1 still requires editable named playlists/queue parity, global/editable shortcuts,
preferences/profiles, mini-player/multiple windows, recording/conversion/stream
output, casting/capture, original web remote and add-on/customization workflows.
These are retained merge requirements, not reclassified as optional follow-ups.
Hardware/account-dependent workflows need their own real verification.

Development macOS builds link installed VLC 3 at `/Applications/VLC.app`.
`VLC_APP_PATH` is an Xcode override. Runtime bundling/notarization and other native
platform libVLC integration remain open. The explicit development comparison flag
`TANGERINE_INTERIM_PLAYER=true` retains the older backend; Android/iOS/Windows/Linux
still use an interim media_kit implementation. The browser uses its own HTML
codec boundary. None of these interim paths count as native libVLC parity.
