# Tangerine compatibility baseline

Baseline read before this implementation on 18 October 2026:

- The worktree already contained the MyVLC/StudyStream merge and Panels evidence.
  Those changes/artifacts were retained. No original source or user library was
  moved, reset or deleted.
- Drift database schema: version 2. Database filename: `study_stream.sqlite`.
  Production lookup: `getApplicationDocumentsDirectory()`. No schema, filename
  or database lookup changes are introduced by the rebrand.
- Test isolation: `STUDYSTREAM_DATA_DIR` remains supported. Fixture integration
  tests use their own disk database in a newly created temporary directory.
- macOS bundle ID: `com.example.studyStream`. It remains unchanged, retaining
  the existing sandbox container and Documents/Application Support identity.
  Executable/product display name changes from MyVLC to Tangerine; bundle-based
  storage and the Documents database identity remain stable.
- Folder bookmarks: `StudyStream.folderBookmarks` in macOS UserDefaults; unchanged.
- Secure pairing keys, `sync.*` settings, device ID, native package imports,
  Android application ID and Linux/Windows executable IDs remain unchanged.
- LAN discovery service `StudyStream`, protocol `StudyStream.discover.v1`, `/v1`
  routes and browser cookie `myvlc_session` remain unchanged for existing clients.
  Health/product labels and new-server defaults now say Tangerine. Existing
  saved server names and appearance settings are loaded without rewriting them.
- Legacy MyVLC source: `/Users/satwikpallerla/Documents/ChatGPT/MyPlayer`.
  Legacy library: `MyPlayer/library.json` under its Application Support directory.
  Originals are read only, and import requires choosing a file and reviewing
  the concrete preview. Credentials are outside the import.

Historical tests/builds are recorded in `MEDIA_PLATFORM.md` and `VALIDATION.md`.
Fresh Tangerine verification results belong in `TANGERINE_IMPLEMENTATION.md`.
