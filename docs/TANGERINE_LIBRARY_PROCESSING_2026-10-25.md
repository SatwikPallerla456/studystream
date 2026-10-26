# Library processing and organization — 25 October 2026

## Screen findings saved before changes

The current Imported media library shows Scan, Identify and Sources, but no
processing status, pause/resume, backlog or retry action. Two versions of one
movie appear as files; file identity and progress must remain separate. Details
show a collapsed Files & versions section; technical analysis is an on-demand
control inside that workflow, with no library-wide queue visibility. Captures:
.verification/library-processing-2026-10-25/library-before.png and
technical-before.png (the latter shows the collapsed details surface, not an
executed analysis). No scan, match, analysis, playback or reader was run.

Source review additionally finds category roots for audiobooks/podcasts/photos/
home videos/music videos/documents using the generic browser, while older named
library group queries exclude missing facets and unavailable files. Technical
analysis is macOS audio/video only and has no restart-safe scheduling. Existing
scan commits, source availability, user overrides and item IDs are retained.

## Recovered reference and implementation decisions

Use docs/PLEX_TARGETED_DECOMPILATION.md and its native scanner, catalog/schema and
packaged scanner reports as standing references:

- Native S003/S008/S009/S018 distinguish completed/unavailable/cancelled/failed
  source scans. Analysis jobs are downstream of committed discoveries and never
  authorize deleting records or treating an offline source as empty.
- Native S010/S023–S026 distinguish physical identity, moves and duplicate copies.
  Job invalidation uses fingerprint plus size/mtime while canonical resume and
  Study identity remain unchanged. No automatic duplicate/cut merging.
- The recovered metadata→media→ordered parts→streams separation guides distinct
  organization and technical jobs. Manual part/edition ownership remains explicit.
- Native extras classification and legacy unambiguous-parent handling guide
  conservative, reviewable associated-resource suggestions. Unknown private
  ranking/merge algorithms are not invented; online matching is not automatic.
- Metadata/user locks and selected matches win over newly read local tags. All
  derived grouping/search updates are bounded, idempotent and regenerable.
- Panels cache/job findings guide one owned background job at a time, bounded
  resource reads, cancellation/stale-result guards, and no full publication render.

Add a persistent device-local queue, bounded startup reconciliation and scan
hooks, version/revision checks, restart recovery, pause/resume, bounded retry,
offline deferral, visible library processing and per-title status. Background means
work while Tangerine is open, not an unsupported claim of OS execution after exit.
Extend the shared category model to the remaining media types, including unknown
buckets, file-month/folder views, audio series/chapter order and document formats.
Preserve course curriculum, existing albums/collections and contextual notes.

## Evidence boundary

Implementation is separate from later testing. No tests, analyzers, processing
jobs or runtime acceptance journeys will run in this pass. Native build/startup
is only allowed for isolated UI review; do not launch the production worker merely
to claim analysis coverage. Record any visual preview separately from real data.

## Source review refinement before organization-review changes

The existing title-files editor adds extras from their parent title. Opening an
ambiguous extra's own details cannot complete that association. The processing
review must therefore offer a bounded parent picker and open the chosen parent's
editor with the extra as an unsaved suggestion. Saving remains explicit. Existing
part/extra associations should disappear from the pending-review list.

## Source implementation

- Added device-local `library_processing_jobs` and `processing_suggestions` tables.
  Scans enqueue committed assets in their transaction; startup reconciles existing
  local files in pages of 100. Signature/version changes requeue derived work.
  One owned job runs at a time. Restart recovers unfinished claims; leases and
  file/revision checks prevent stale publication. Automatic failures stop after
  three attempts, while unavailable/changed sources defer without spending an
  attempt. The queue does not delete assets or initiate provider matching.
- Pause/resume is per library. Playback, books, PDFs, resource viewers and photos
  suspend new work and invalidate in-flight publication. Existing native parsing
  drains before its resources are released; pause is not a claim of instantaneous
  native interruption. Mobile paused/detached lifecycle states suspend work.
- Library/category controls open Processing, with job counts, bounded job pages,
  retry/reprocess controls and explicit organization review. Details watch local
  analysis status and offer queued reanalysis. Extras use a bounded parent picker
  where needed, then an unsaved draft in the existing title-files editor. Ordered
  parts remain a manual sequence with known durations and explicit save.
- Discovery no longer waits for audio-tag parsing. Organization reads bounded
  ID3/FLAC metadata, local media-container tags, EPUB package metadata and CBZ
  ComicInfo. Derived tags are content-revision checked. Selected provider snapshots
  and user field overrides retain precedence. No rename/move or cut deduplication
  occurs. Existing album/collection and contextual Study workflows remain.
- Technical analysis retains the existing macOS VLC binding for ordinary audio/
  video and adds a separate paused, local-only media-kit probe for other supported
  native hosts and M4A/M4B chapters. Stream hints use the official
  [mpv property contract](https://mpv.io/manual/stable/), not recovered Plex-private
  parser behavior. The probe disables automatic external tracks/scripts/network
  protocols, bounds track/chapter enumeration and demux buffers, and disposes its
  player. Its four-entry cache retains plain metadata futures, never players.
  No video frame/audio output is requested.
- Images use bounded encoded-header geometry; PDFs read page metadata; EPUB/CBZ
  use the existing bounded archive source and close it without rendering content.
  Technical payloads remain path-free. Durations/page counts update item facts;
  canonical file identity, progress and Study anchors are unchanged. EPUB page
  count means reading sections, not a claim of fixed print pagination.
- Shared bounded browsing now covers audiobook authors/books/files and embedded
  chapter seeking, podcast shows/episodes, music-video artists, photo/home-video
  file months and source folders, and document formats/folders. Missing metadata
  remains visible. Same-named audiobook books from different authors and folders
  from different named libraries keep distinct group keys. Source namespace IDs
  receive readable folder labels. Photo viewing retains the selected scope and
  uses one-photo keyset navigation, rather than loading the entire library.

## Implementation evidence and remaining acceptance

The isolated `tool/library_processing_design_preview.dart` uses an in-memory
synthetic catalog and prefilled queue snapshots. It never calls service.start,
normal main, source scanning, online matching, a player or a reader. Native macOS
compilation for design review succeeded. The Mac was locked when the preview was
about to open, so revised screenshots are pending unlock; the pre-change real
screens above remain distinct evidence.

No automated tests, analyzers, real processing jobs, retry/restart/source failure
journeys, playback/chapter seek, reading, sync acceptance or platform acceptance
were executed. Those belong to the user's separate testing phase after the full
master implementation. Processing is app-open work, not a new OS daemon. Parsing
unsupported/malformed files, resource ceilings and native dependency availability
on each supported platform require that later phase. No release gate is passed.

The final isolated preview and normal entry-point restoration both compiled for
this design work. The normal app was not launched. The Mac remained locked on a
second availability check; no revised visual screenshots are claimed. Chapter
payloads use the bounded technical transport contract, and local content revision
now comes from current asset facts while remote assets retain their host revision.
The rebuilt search index also includes the basename for filename discovery.
