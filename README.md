# StudyStream

A private Flutter application for learning from folders of video, audio, PDFs,
text, HTML, images, and externally opened resources. Media stays in its source
folder. Drift stores learning history, notes, bookmarks, and preferences.

## Learning locally

- Import folders recursively, refresh manually, cancel scans, and watch supported
  desktop filesystems with debouncing and a manual-refresh fallback.
- Natural lesson ordering, visible missing lessons/sections, metadata editing,
  same-type file relinking, and moved-root relinking from Library refresh.
- Full SHA-256 file identity calculated off the UI thread. Unambiguous moves keep
  progress; ambiguous duplicates do not inherit another lesson's history.
- Video/audio controls, track selection, external subtitles, completion,
  previous/next lessons, configurable auto-advance, rewind resume, and serialized
  progress saves. Completed lessons remain completed during replay unless changed
  manually.
- PDF page, zoom, offset and fit controls; text search; positioned notes/bookmarks.
  Scanned pages require an external OCR tool to become searchable.
- Search across libraries, sections, filenames, lessons, notes, and bookmarks.
  SQLite filters and caps results rather than loading the whole database per query.
- Light/dark themes, responsive sidebar/rail/bottom navigation, keyboard controls,
  reduced-motion-aware navigation and progress animation, bounded image memory,
  lazy PDF covers, and native macOS video thumbnails.

## Connecting another device

1. On the desktop, open **Settings → Local network sync host → Start host**.
2. On the companion, use **Settings → Connect to your desktop**. Discover nearby
   hosts where subnet broadcasting is supported, or enter the displayed address.
3. Enter a device name and the host's current six-digit pairing code.
4. Browse the mirrored libraries using the normal Libraries screen. Protected
   media and PDFs open using authorization headers. Notes, bookmarks, completion,
   progress, metadata and activity reconcile every 15 seconds while connected.
5. Disconnected edits stay in the local database. Retries back off from 2 to 60
   seconds. **Sync now** retries immediately. Approved devices can be revoked on
   the host; **Disconnect & forget** removes the companion's saved credential.

Tokens use platform secure storage and are excluded from backups. The host stores
only token hashes. Pairing codes expire after ten minutes and rotate after pairing;
failed pairing attempts are rate limited. File serving checks canonical paths
against imported roots, including symlink escapes.

**Transport is authenticated HTTP, without encryption or peer certificates.**
Pairing codes, tokens, learning data and source media can be observed by someone
able to inspect network traffic. Use a trusted private network. UDP discovery is
best effort and may be blocked by routers or OS entitlements; manual entry remains
available. One desktop host is paired at a time. Remote media is streamed, not
cached for offline playback. Sync snapshots are capped at 10 MiB.

## Backups and permissions

Backups contain database records, not source media or pairing tokens. Restore is
transactional: newer local progress/settings survive, and conflicting user content
is retained as deterministic copies. Backups over 64 MiB are rejected. Existing
media paths stay local when matching records already exist.

macOS retains user-selected folder permissions using security-scoped bookmarks.
Unavailable volumes and stale permissions do not cause learning-data deletion.
Android/iOS currently use the companion workflow: persistent arbitrary-folder
imports through mobile document providers are not implemented. Background audio
services, OS picture-in-picture and offline media downloads are not integrated.

## Development and verification

Verified toolchain: Flutter **3.47.6**, Dart **3.13.5**, macOS/Xcode and Android SDK.
After changing SDKs, regenerate dependency configuration with `flutter pub get`.
Do not edit package caches or `.dart_tool/package_config.json`.

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter test integration_test/library_flow_test.dart -d macos
flutter build macos --debug
flutter build apk --debug
flutter build ios --simulator
```

The integration test uses synthetic valid audio and a searchable three-page PDF,
actual native playback/rendering, isolated secure-storage credentials, and a disk
SQLite close/reopen. Network tests use two separate disk databases and a real HTTP
server, including automatic reconnect, revocation, and authenticated range reads.

For isolated interactive checks without opening your normal database:

```sh
flutter run -d macos --dart-define=STUDYSTREAM_DATA_DIR=ui-verification
```

A relative verification directory is created inside the app's own temporary
container. See [VALIDATION.md](VALIDATION.md) for baseline findings, exact check
results, interactive evidence, limitations, and the acceptance checklist.
