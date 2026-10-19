# P0 preservation inventory and first UI path

19 October 2026 (Europe/London).

This inventory accompanies the first two reviewable slices of the master plan.
The pre-existing uncommitted MyVLC, branding, reader and catalog work remains in
place. No personal media, database or original import file is used by these
fixtures. These checks do not establish full MyVLC parity or complete P1–P11.

## Synthetic identity inventory

The executable fixture is `test/fixtures/tangerine_preservation_fixture.dart`.
It defines three stable library IDs: `local`, `mirror` (`remote:fixture`) and
`imports` (`import:fixture`). Each has `<library>-section`, `<library>-video`
and `<library>-book` items. Only the local library is eligible for hosting.

| Preserved contract | Fixture |
| --- | --- |
| Source identity | `legacy:local` has an absent root and unavailable flag; `secondary` owns `@sources/secondary/` and remains available |
| Item IDs and verified-fingerprint field | `local-video`, `local-book`; deterministic synthetic fingerprint, never presented as a real hash |
| Playback and manual completion | video position 47 seconds, exact resume 42 seconds, duration 100 seconds, explicit manual false |
| Reading locator | PDF page 7, resume page 6, scroll offsets 120/80, zoom 1.5, vertical mode, manual completion true |
| Notes and bookmarks | `<library>-note` on canonical page 6; `<library>-bookmark` at 42 seconds |
| Metadata JSON | `metadata:<library>-video`, local title/year/match state and retained local extension |
| Reader options | `reader:<library>-book`, explicit false RTL and `chapter-6` locator |
| Organization and membership | `organization:<library>-video`, favorites, `<library>-collection` |
| Queues, named playlists and subtitles | `myvlc.queue`, `myvlc.playlists`, `player.item.local-video` local settings |
| Local-only access context | `sync.fixturePermission` demonstrates that sync settings do not enter remote snapshots or backup restoration |

The disk fixture is reopened before comparison, exported through JSON and
imported twice into another database. Device identity and `sync.*` settings
retain the existing intentional local-only restore policy. Folder security
bookmarks remain managed by the existing native FolderAccess boundary; a string
fixture is not native permission acceptance.

## Implemented boundaries

Serving selects exactly one source from the existing namespace, then opens the
canonical file within that source's canonical root. A missing legacy root does
not block a healthy secondary root. Another approved source cannot authorize
bytes owned by a different namespace. Remote mirrors and file-only imports are
excluded, as before. Traversal, ambiguous ownership, unavailable roots and
symlink escapes have explicit failures. This is a compatibility adapter until
P1 adds an explicit item-to-source relationship.

Hosted snapshot construction explicitly enumerates supported fields and scopes
items through sections and libraries, then scopes every progress, annotation and
catalog row through its owner. Collection members must belong to that same scope.
Sources, settings, file paths, fingerprints and undeclared extension fields do
not enter the transport. Backups retain their original local payloads.

Incoming server edits receive the same hosted-library scope. Catalog ownership
(kind/library/item) and existing note/bookmark ownership cannot be rewritten.
Catalog ingestion is transactional and validates kind-specific payloads, bounded
JSON, byte size, timestamps and tombstones. Repeated local writes receive
strictly increasing timestamps, and stale imports retain the newer record.
Unknown backup extension kinds remain local and are omitted from transport.
Per-device library grants, typed catalog revisions and protocol deltas remain P10.

## First cinematic UI path

Home uses bounded real-data rows, a featured local/server title, sized artwork,
honest missing-art placeholders, persistent Play/Read/View actions and a stable
`/details/:itemId` route. Details reads existing metadata and resumes through the
existing player/PDF/resource routes, with Study, favorite and completion actions.
Each horizontal row has independent scroll state and lazy cards. Light/dark
appearance, large text, visible keyboard focus and reduced motion are retained.
The separate `/browse` route uses 60-item keyset pages, ordered by title and ID,
with previous/next/start-over controls. Search/category changes reset the cursor.

Full movie/TV representations, normalized matching/correction, library grants,
collections on Home, browser UI parity, artwork job ownership/budgets and the
complete UI acceptance matrix remain in the ordered master plan. Existing
Continue Watching/Listening/Reading and course/folder surfaces remain available.

## Verification

Tests are deliberately executed after implementation, as requested by the user.
Actual commands and results are recorded in `TANGERINE_IMPLEMENTATION.md`; this
inventory alone is not a passing result.
