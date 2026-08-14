# StudyStream

StudyStream is a private, folder-based learning app for video, audio, PDFs,
text, HTML, images, and externally opened course resources. It keeps source
files in place while storing progress, completion, notes, bookmarks, library
metadata, and settings in a local Drift database.

## Current capabilities

- Recursive library scanning with natural course ordering, cancellation,
  missing-file visibility, relinking, and rename/move identity preservation.
- Video and audio playback with resume rewind, speed, volume, keyboard
  shortcuts, subtitle/audio-track selection, external subtitles, completion,
  next/previous navigation, and configurable auto-advance.
- PDF reading with page restore, zoom, text search, page notes, and bookmarks.
- In-app text, HTML, and image viewing; honest external-open fallbacks for DOC,
  DOCX, PPT, PPTX, and EPUB.
- Global lesson/note/bookmark search, continue-learning lists, hierarchical
  progress, light/dark themes, backup/restore, and responsive navigation.
- Token-authenticated LAN host with pairing, revocation, range streaming,
  conflict-aware progress merging, and path-sanitized snapshots.

## Development

Use Flutter 3.41 or newer with Dart 3.11 or newer.

```sh
flutter pub get
flutter analyze
flutter test
flutter test integration_test/library_flow_test.dart -d macos
```

Desktop folder import is the primary host workflow. Android and iOS builds are
supported, but a complete discovery/pairing companion client and background
audio service are not yet implemented. LAN transport is intended for trusted
local networks: device tokens authenticate requests, but traffic is not
end-to-end encrypted.
