# Category-specific browsing — 21 October 2026

## Saved findings before implementation

Reviewed the native app from Home into TV Shows, Music, Books and the populated
Comics & Manga category. Screenshots are in
`.verification/category-browsing-2026-10-21/`: `tv-before.png`,
`music-before.png`, `books-before.png`, `comics-before.png`.

- TV, music and books currently have no user content. Their empty screens show
  only the generic file search/grid/list controls, with no indication of the
  intended hierarchy. No populated TV/music/book visual coverage is claimed.
- Comics contains 63 actual files but opens a flat alphabetic grid of 60 entries,
  separating chapters and volumes of the same series across pagination. The
  visible covers are placeholders; browsing has no series or reading-status lens.
- The category page bypasses the partially typed library browser. In source,
  library-only grouping excludes files missing a grouping facet, has no search,
  and uses poster cards for episodes and tracks. It offers only a current-page
  queue. Comics has no default grouping at all.
- Group navigation has no clickable ancestry; title text is not enough to make
  the hierarchy discoverable. All-files fallback is necessary but should not be
  the default music/TV experience.

## Design decisions

Use one bounded catalog browsing model for category and named-library scopes.
TV: shows → seasons (including Specials) → numbered episode rows, resume/progress
and clear missing-identification groups. Music: artist/album entry points → disc
and track rows, explicit play/shuffle queue for the selected scope. Reading:
cover shelves with Books/Series/Authors and All/In progress/Unread/Completed
lenses; comic series drill down to naturally ordered volumes/chapters. Missing
metadata stays visible in labelled groups; local filename hints are not online
matches. Retain per-file identity, notes and durable reader/player positions.

Keep source scanning and identification visible at category/library roots,
with source-library filtering, search, breadcrumb navigation and bounded pages.
Use real archive/EPUB covers where available, with the existing reader's bounded
archive ownership; do not render entire publications to populate shelves.

References: docs/PLEX_TARGETED_DECOMPILATION.md (catalog hierarchy separate from
physical files and progress), docs/PLEX_PACKAGED_SCANNERS.md (local parse hints),
docs/PANELS_DEEP_DECOMPILATION.md and its cache/geometry companion reports
(bounded thumbnails, per-title reading state). These inform the reconstruction;
no private grouping or ranking algorithm is claimed.

## Evidence boundary

This report precedes design changes. Implementation and later screenshot review
are distinct from the separate testing phase. No automated tests/analyzers or
runtime acceptance journeys are authorized during this implementation pass.

## First rebuilt UI review, before follow-up changes

The native debug build succeeded. The actual 63-file comic collection now shows
three series (35, 20 and 8 entries). Choujin X opens volumes 1–11 followed by
decimal-numbered chapters, retaining the existing 18% chapter progress. Local
archive cover images load without launching a reader. Captured in
`comics-series-first-pass.png` and `comics-volumes-first-pass.png`.

The review also found overly tall toolbar stacks, a redundant source selector
when only one library exists, cover frames pushing titles below the initial
viewport, and a series representative chosen by arbitrary item ID. Compact the
filters, hide a redundant one-source selector, use denser reading shelves, and
prefer the earliest volume/chapter as the representative. Keep the full covers
visible in group cards. These findings precede those follow-up design changes.

## Source implementation

- CategoryBrowseRepository provides category and optional library scope, exact
  ancestry filters, literal FTS search, reading/watch status, missing-facet
  buckets, grouped counts, and stable keyset pages of 48 groups/titles. Group
  queries/counts stay in SQLite. Root album keys include artist so identically
  named albums by different artists remain distinct. This is presentation
  grouping by known labels, not an inferred merge of provider identities.
- CategoryBrowseSection is shared by category roots and named TV/music/book/
  comic libraries. TV opens Shows → Seasons → episode rows, including Specials,
  shared episode labels, progress and explicit next-unwatched playback. Music
  offers Artists/Albums/Tracks, artist → album → disc/track ordering, and explicit
  play/shuffle scope queues. Queues include the selected scope beyond the current
  page, bounded to 10,000 entries with an explicit narrowing error.
- Reading offers Books (or Volumes & chapters), Series and Authors, status
  filters, per-file progress, read/resume actions and comic volume/chapter lenses.
  Unknown authors/series and unidentified TV/music groups are visible. Ancestry
  is clickable; returning from details/player refreshes the bounded page.
- Version-4 local hint backfill derives conservative publication series and
  numeric volume/chapter hints. Explicit publication markers work for reading
  media; bare terminal chapter numbers are comic-only. Metadata overrides retain
  precedence. No files, item identities, user notes or saved positions move.
  Volume/chapter and music disc/track corrections are editable in title details.
- ThumbnailCache reads a single CBZ page or EPUB-declared raster cover through
  SafeBookArchive, bounded to 8 MiB cover reads, with no extraction or WebKit.
  Existing serial decode, geometry limits and owned thumbnail cache are reused.
  Books without declared/supported covers retain a placeholder. Series choose
  their first numbered volume/chapter as representative; group covers preserve
  their full aspect. Selected online artwork retains precedence.
- Relevant sources, Scan and Identify remain visible. The source filter lists
  only libraries containing/declaring the category and disappears if redundant.
  Other media categories and the course curriculum retain their existing flows.

## Production-content visual coverage

The second native build and screenshot review show full local covers on the
three real comic series, their counts and existing progress. The Choujin X shelf
shows the first five volumes in numeric order in the initial viewport, with
the volume/chapter lens and compact reading-status selector. Screenshots:
`comics-series-final.png` and `comics-volumes-final.png`.

## Populated-layout preview boundary

TV/music/books have no production content on this machine. A separate manual
entry point, `tool/category_design_preview.dart`, supplies an in-memory synthetic
catalog with a prominent DESIGN PREVIEW banner. It never opens the user's
database, source folders or paired devices. It is for screenshot design review,
contains no test assertions and is not imported by the normal main entry point.
Playback/reading media and queue execution are intentionally not exercised by
the review. Restore the normal lib/main.dart build after capturing layouts.

Source review also found that the old availability predicate would hide a saved
title when its source went offline. Preserve it in the new category views, mark
offline members and disable their open/play actions; omit offline files from
new queues. Keep alternate representations distinguishable using edition and
format labels rather than silently merging their progress identities.

## Populated preview findings before final refinement

The synthetic TV screenshot shows Specials before Season 1 and Season 2, and
numbered episode rows with completed/in-progress state and a shared E3–4 file.
Music shows artist → albums → disc/track rows; two Daybreak albums retain their
artist qualifiers. Reading shows book progress and volume labels. These are
layout observations, not playback, import, persistence or renderer acceptance.

The preview also exposes unknown groups sorted before known content, singular
counts rendered as “1 tracks”, uneven cover frames when subtitles wrap, and a
separate playback-actions row pushing artist labels below the initial viewport.
Place unknown groups last, use singular counts, reserve consistent group label
space and combine the section heading with its playback actions.

## Final visual review and remaining acceptance

The isolated populated preview visibly reaches show → seasons → episode rows,
artist → album → numbered tracks, a root album shelf distinguishing identical
album names by artist, and author → series → numbered books. The final music
preview places known groups first, uses “1 track”, aligns card cover frames, and
shows artist names in the initial viewport after combining the heading/actions.
Captures include `preview-tv-seasons.png`, `preview-tv-episodes.png`,
`preview-music-tracks.png`, `preview-music-artists-final.png`,
`preview-music-albums-final.png`, `preview-book-shelf.png` and
`preview-book-author-series.png`. The earlier TV/track/book captures precede the
final compact heading and count refinement. They use synthetic in-memory data
and honest artwork placeholders; they do not demonstrate real TV/music imports.

The normal main entry point is restored after preview work. Category screen
implementation is complete for this requested scope; this does not declare the
full master plan complete. No tests or analyzers were run. Actual playback/queue
execution, reader opening, rescanning/import, metadata-change refresh, offline
source behavior, pagination at large scale, cross-device sync and non-macOS
behavior remain for the separate testing phase. Native builds/startup and screen
navigation here served only the explicitly authorized design review.
