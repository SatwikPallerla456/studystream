# Tangerine implementation worklog

Updated 20 October 2026 (Europe/London).

## Current phase

Implementation is in progress. The complete master plan is **not finished**.
The user's execution order is binding: finish implementation first, then perform
testing as a separate process. Automated tests and analyzers remain deferred.
The user subsequently authorised starting the macOS app, taking screenshots and
using a user-role walkthrough to revise the UI; startup builds and hot reload
were run for that visual design work only. They do not establish full acceptance.
Dart formatting, dependency resolution and Graphify maintenance are implementation
operations; their completion is not evidence that the application works.

Historical verification in TANGERINE_IMPLEMENTATION.md predates these changes.
It must not be presented as verification of the current working tree.

## Source implemented in this continuation

- Library source management is reachable from libraries. Folder setup requests a
  library name and one of the thirteen content kinds. Courses retain their lesson
  route; Mixed and other kinds use media browsing, with grouping where applicable.
- Catalog editor connects offline JSON search, candidate preview and explicit
  selection, revision-checked correction/clearing, sparse field edits, locks,
  removal and reset. Matching preserves the existing Item identity and history.
- Catalog search uses FTS with bounded pages and stable sort keys. Named-library
  filters, TV show/season groups, specials, artist/album, author/series and month
  groups have UI. ID3v2 and FLAC Vorbis comments have a bounded local tag reader.
- Details exposes editions and alternative files with per-file playback routes.
  TV next/previous navigation uses numbered episodes and excludes specials and
  attached extras. Title Files now edits edition/version labels, ordered parts
  and typed extras. A saved title timeline maps into one exact file and local
  position. The player advances through explicit parts and ends at title Details;
  each file retains its progress and Study identity. Details derives title resume
  and completion from its parts; explicit title completion updates those files
  atomically. Saves are transactional and
  reject stale editor snapshots. Part/extra removals have syncable tombstones.
- Collections and ordered albums have membership editing and membership records.
  Photos have a bounded-decoding slideshow. Existing queue, playlist, sleep timer,
  native output, preferences and shortcut source from the checkpoint is retained.
- Reader services define versioned canonical locators, page transforms and their
  inverse, presentation maps, variable-height continuous layout, sparse settings,
  serialized session writes and cancellable/coalesced jobs. Rendering has explicit
  allocation limits; speculative decoded prefetch remains disabled pending later
  workload measurements. Those limits are provisional, not measured guarantees.
- The archive reader uses canonical spread groups, cover/landscape singleton
  rules, pairing overrides, RTL placement, unified navigation, continuous intrinsic
  heights, fit choices and bounded zoom. Reader images own decoded resources.
- PDF uses the locator/session boundary and custom layout maps while retaining
  pdfrx rendering, native text selection and search. It has layout/direction/fit
  preferences and background sampling. Cross-format coordinate and lifecycle
  correctness remain unverified.
- Study notes/bookmarks can carry additive canonical page anchors or versioned
  passage ranges with distinct start/end endpoints, offset units and quotes.
  The Study panel lets users attach new notes/bookmarks to the selected passage
  or the page. PDF restores native text ranges; publication pages restore scoped
  DOM ranges and verify quote prefixes. Legacy page-only annotations remain
  unchanged; incompatible revisions retain their original references.
- Background sampling declares its version, edge-band relationship, white alpha
  matte and bounded sampling resolution. The reader composes four-stop immersive
  gradients with a 300 ms transition, zero under reduced motion.
- EPUB publication rendering preserves package HTML/CSS/images/SVG through a
  publication-only loopback origin and official Flutter WebView dependency.
  Package scripts, external resources and navigation are constrained. Metrics
  have request/revision/page identities, readiness timeout, resize sequence checks
  and bounded retry. Reflowable chapters now use separate scroll-height limits
  rather than raster-area limits, and a body ResizeObserver reports late layout
  changes. The package supports Android/iOS/macOS; other platforms still need
  publication renderers. Range/long-chapter behavior remains unverified.
- Local schema is version 5; wire protocol is independently version 2 with legacy
  adapters. Catalog identities, overrides, embedded tags, memberships and Study
  anchors have backup/transport integration and payload projection.
- Approved devices have separate browse, stream and mutation grants per library.
  New libraries require grants. Catalog, snapshots, media, page, artwork and host
  playback-control routes apply scope; mirror roots remain excluded.
- A monotonic change journal retains identifier tombstones for 90 days and asks
  expired cursors to refresh. Initial sync, changed records and uploads have
  bounded pages/batches. The companion client stores cursors and handles scope
  changes. The browser uses bounded catalog pages and authenticated artwork.
- Artwork has versioned cache keys, serialized generation, consumer leases,
  access-aware disk trimming, a grace interval and protected live files. Remote
  artwork requests use authenticated bounded reads without forwarding redirects.


## UI-first continuation, 20 October 2026

The user requested UI first, followed by the backing implementation. This wave
adds reachable workflows, then connects their persistence and playback behavior:

- Typed library groups now use real member artwork, responsive cards, Specials
  labels and deterministic bounded pages. Leaf title cards use effective catalog
  names and progress. Artwork members load in one bounded query per page.
- Details → Manage title files provides edition/version editing, reorderable
  parts, title-time seeking/resume and typed extras. File selection is scoped to
  the current library and paged; incomplete durations are clearly disabled.
- `media_extras` and additive `media_parts.deleted` storage participate in backup,
  scoped sync, identity validation and change-journal removals. Clearing a title
  sequence does not delete its underlying files or progress.
- One Reading Preferences panel serves PDF, comics and EPUB, Library Sources and
  app Settings. App/library/title layers are sparse, show inherited values and
  reset per field. Title-only pairing adjustments cannot leak into library/app
  defaults. Locator writes remain separate from preference edits.
- Tap-region preferences expose leading/trailing/top/center actions. Raster
  swipes use bounded one-pointer gestures; transitions, selected text and zoom
  suppress tap navigation. PDF keeps native text/link interaction ahead of reader
  taps. PDF background double tap uses a fit/2.5× toggle and clamps settled pinch
  zoom to the configured 1–5 relative range. Publication clicks report scoped tap
  events without overriding links, selection or double-click selection.
- Study has a passage preview and explicit passage/page attachment choice.
  Passage endpoints and quotes are validated and transported separately from
  viewport/page locators. PDF and EPUB restore their respective native ranges.

These are source changes, not acceptance results. This entry predates the later
user-authorised visual review below. The complete P0–P11 implementation remains in progress.

## User-role design review, 20 October 2026

The user requested app startup, screenshots, impressions and UI correction, then
specified a complete screen review saved before further implementation. The
screen inventory, concrete findings, category contract, proposed changes and
coverage limits were saved in `TANGERINE_UI_DESIGN_REVIEW_2026-10-20.md` before
the subsequent design pass.

Observed: Home, Libraries, populated mixed/video library, movie Details, Search,
empty Notes, Settings, upper player settings, empty queue/playlists, disconnected
Network and device-mode selection. Screenshots live in
`.verification/ui-review-2026-10-20/`. Other categories and connected/populated
states received source review and remain visually unaccepted.

Earlier screenshot-driven changes removed the old course dashboard from generic
media, reduced duplicated shelves and headers, corrected movie completion labels,
preserved title punctuation, distinguished duplicate files, and restricted player,
photo and browser tools using actual library/media context. Study paging now has
bounded notes/bookmark pages in the native sheet and server/browser interface.

Following the saved design report:

- Root tab routing now makes the Home action select Home while Back retains its
  route context. In-app mode selection has a Back exit.
- Search uses Titles, and Search/Notes EPUB and comic jumps use the book reader.
- Metadata opens on Edit details with category-relevant fields. Other fields
  remain available under Advanced fields, preserving existing overrides.
- Library settings gates reading defaults by library category and shows concise
  scan results. Category initial state is keyed to the loaded value.
- Settings groups infrequent controls into expandable sections. Player settings
  separates shortcuts from native engine preferences; Network has one header.
- Home's secondary shelf has bounded artwork; empty-home copy is shorter.
- Empty queues lead with Add media; collection creation has an explicit action;
  utility pagination is hidden when inapplicable. Reader wording/errors and device
  permission load recovery were improved.

The authorised startup initially exposed an unsupported icon name and two numeric
clamp type mismatches; these were corrected. A later queue conditional required an
explicit non-null playlist branch. Hot reload compiled after correction; adding a
new widget field required hot restart to clear the old live widget instance.
No automated tests or analyzer were run. Mac locking interrupted visual review;
the resumed walkthrough is recorded below. No release gate,
full category acceptance or master-plan completion is claimed.

Graphify's project mapper now retains structural Markdown headings alongside the
curated document references. The refreshed graph has 4,419 nodes, 9,121 edges and
206 communities; its Linux macro-header extraction limitation and 42 unresolved
references are documented in the graph report. The previous graph was preserved
while investigating the shrink guard, then replaced after retaining the report
headings and all existing curated references.

### Resumed visual walkthrough

After unlock, the current source was rebuilt and screenshots captured for Home,
Settings, empty queue, mixed/video library, metadata, library settings, Search,
Notes, Network, device mode, empty collections and the new collection editor.
Home actions returned to Home; mode Back returned without changing the role.
Six further presentation refinements were recorded in the design report before
editing: full-width card titles with artwork playback actions; quieter metadata
field menus and header Save; compact in-app mode selection; effective catalog
title in Title Files; labelled/spaced collection fields; and clearer built-in
reader-default wording. No user media or library
metadata was edited during the walkthrough.

The launchable debug build is refreshed from source, rather than relying on
in-memory hot reload. Flutter logged native AXTree bridge update errors during
the development walkthrough; their cause and accessibility acceptance remain
open for the dedicated later phase. Title Files, the file picker, All media and
player/reader preference panels were also captured. This is visual evidence for the captured
states, not full master-plan acceptance. Automated tests remain deferred.

## Plex targeted and Panels deep findings implementation pass

20 October 2026. Added conservative explicit edition/range/extra hints and
existing-library facet/automatic-edition upgrades; range-aware TV labels and
navigation; explainable offline candidate ranking; edition-aware local subtitle
discovery with IDX/SUB checks; and on-demand revision-bound macOS technical
analysis with validated stream payloads and a Details action.

Readers now have compatible raw viewport replay independent of portable anchors,
shared complete-layer 300 ms backgrounds, RTL spread edge sampling, cancelled-job
replacement and memory-pressure cleanup. PDF cache targets/adjacent extents are
explicit. Thumbnail recency/pruned-result handling and macOS allocated-byte disk
accounting are connected. On-demand macOS OCR uses bounded raster inputs and
public Vision APIs, with selection/copy and page-quote Study handoff; native PDF
text and EPUB DOM text remain independent.

Full behavior, implementation choices, boundaries and the future acceptance
inventory are saved in
[TANGERINE_PLEX_PANELS_IMPLEMENTATION_2026-10-20.md](TANGERINE_PLEX_PANELS_IMPLEMENTATION_2026-10-20.md).
This pass is source-only. No tests, analyzers, builds or runtime acceptance were
run. The launchable app still contains the previous visual-review build.

## User-journey correction: category -> source -> scan -> identify

The user correctly called out the mismatch between the visible app and the
StudyStream + Plex + Panels product contract. The standing rule and the
requirement to use the retained decompilation as an implementation reference are
now recorded in AGENTS.md.

The renewed native walkthrough found that Movies hid existing Mixed-library
videos, category destinations were absent from Home/Libraries, add-library opened
a folder picker before type/name, and Notes occupied primary navigation. Saved
the findings before changing those screens. Implemented indexed per-file category
facets with explicit library/user precedence, versioned backfill, visible category
entry points, category/source scan and identify actions, a real cancellable scan
dialog, a bounded local-identification review screen and category-first creation.
Retained contextual notes and a compatibility route for old Notes links.

The rebuilt running app now shows Movies with the existing two files. Home has
compact category entry points plus Continue; Libraries retains the full category
directory. Movies shows its source with labelled Scan library / Identify titles;
Books receives its own empty-state icon/search/add action. Initial visual
impressions led to removing duplicate Movies headings/redundant filtering and
reducing Home's category footprint. The macOS debug build succeeds. No automated
tests or analyzers were run. Imports, rescans, matching, OCR and analysis actions
were not executed as acceptance tests. Populated category-specific reading/music/
TV journeys still need content and later coverage; online matching/artwork is
not yet integrated. Screenshots and limits are in the saved design review.

## Remaining implementation before testing may start

The master plan is the complete scope; this list highlights known open work and
is not a reduction of that scope:

- Complete automatic/background technical-analysis scheduling, other-platform
  technical bindings, remaining type-specific organization and online-provider
  integration. macOS on-demand analysis and explainable offline ranking now have
  source implementations, alongside title files and associated extras.
- Reconcile remaining renderer/cache ownership edge cases. Compatible viewport
  replay, page-quote macOS OCR, complete-layer backgrounds, cancellation and cache
  accounting now have source implementations. Coordinate/gesture correctness,
  framework cache behavior and total budgets require later acceptance/measurement.
- Finish supported-platform publication renderer coverage and remaining geometry,
  asset and lifecycle edge cases. The new long-content, resize and range paths
  have not been exercised.
- Finish cross-device conflict/reset edge cases, bounded Study listing and full
  compatibility behavior. The new sync path has not been executed.
- Reconcile the stale MyVLC matrix against checkpoint source, complete missing
  MyVLC workflows, native bindings on the other platforms and distribution work.
  Account/hardware-dependent features still need both implementation as applicable
  and later real-device acceptance. Interim backends do not count as parity.
- Reconcile every P0–P11 implementation requirement against final source before
  declaring implementation complete. Only then begin the separate testing phase,
  including regression tests, analysis, builds, measurement and runtime journeys.

No release gate is marked passed by this worklog. Working changes are not a new
release or a verified checkpoint. The earlier committed checkpoint is 3ae476b.
