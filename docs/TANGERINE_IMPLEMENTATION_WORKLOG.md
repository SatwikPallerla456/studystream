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

## Online identification and artwork — 21 October 2026

Resumed the WIP checkpoint and completed the source path for TMDB movies/TV,
TVmaze, Open Library and MusicBrainz/CAA. The match editor now opens on Find
match, offers category-appropriate providers, previews real metadata/artwork and
applies only explicit selections through the existing revision/lock rules.
TMDB has device-secure token setup; key-free providers and offline JSON remain
available for their supported categories. Selected attribution/source URLs and
artwork are wired through details, browsing and scoped server delivery.

The native app compiled for design review. A read-only Open Library query
displayed real candidates and a cover preview for an existing comic; the preview
was cancelled, with no match or credential saved. This is visual design evidence,
not acceptance of matching persistence, other providers, synchronization or
cache budgets. See TANGERINE_ONLINE_METADATA_2026-10-21.md and its screenshots.
Tests/analyzers remain deferred; the full master plan remains unfinished.

## Category-specific TV, music and reading screens — 21 October 2026

Implemented one bounded category-browsing backend and UI shared by category
roots and named libraries: TV shows → seasons → episode rows; music artists/
albums → disc/track rows; books/comics with author and series shelves, numeric
volumes/chapters, reading status and progress. Search, source filtering, unknown
metadata groups, breadcrumbs and full-scope bounded queues are connected. Offline
titles remain visible, while new queues omit unavailable files. Metadata editing
includes publication numbering and disc/track corrections.

Local comic filename hints and single-resource CBZ/EPUB covers populate reading
shelves without launching a reader. Derived hints preserve overrides, item IDs,
notes and positions. Saved pre-change findings and subsequent visual refinements
are in TANGERINE_CATEGORY_BROWSING_2026-10-21.md.

Native builds succeeded for design review. Real-content screenshots show all
three local comic series and naturally ordered volumes, with existing progress.
TV/music/book populated layouts were reviewed separately through a clearly
labelled in-memory synthetic preview because those production categories are
empty. The normal app entry point is restored. This is source implementation
and visual evidence only; playback, queue, import, persistence, scale and device
acceptance remain deferred with all automated tests/analyzers.

## Manga reverse page turning — 21 October 2026

The user's current manga title visibly has Right to left selected, but the
bottom arrows/slider remain LTR. Source inspection also found missing trackpad
page-turn handlers and separate ownership of image double taps versus outer
single taps. Saved pre-change findings in TANGERINE_MANGA_DIRECTION_2026-10-21.md.
Implemented mirrored horizontal controls, image-owned single/double tap handling,
trackpad pan and horizontal-wheel turning with zoom/pinch/selection guards, and
spread boundary controls. Canonical page identity and stored preferences remain
unchanged. Tests/analyzers and full gesture acceptance remain deferred.

## Animated opening screen — 22 October 2026

Added a first-frame Tangerine splash before native/database startup, with the
existing brand mark, a short orbit/scale reveal, staggered wordmark/tagline and
a readiness-gated fade into the routed app. Light/dark appearance, static
reduced-motion behavior, actual startup-stage labels and guarded retry are
implemented. Existing provider/watcher/client initialization is retained.

Saved pre-change design notes and coverage boundaries in
TANGERINE_SPLASH_DESIGN_2026-10-22.md. An isolated preview covered light, dark,
replayed animation and failure appearance. The normal macOS build succeeds
and opens the existing Home/library; it is restored and running. Automated
tests/analyzers and full startup/platform acceptance remain deferred.

## Opening chooser after splash — 22 October 2026

Extended the existing logo reveal with a one-second hold, then an 850 ms hero
transition to a distinct opening page. The logo moves from the centre to an
upper-left header, while Player/Server choices occupy the middle. Every launch
waits for a mode choice, with last-used role guidance and persisted setup.
Server auto-start now waits for Server selection, and its preference wording
matches that behavior. Existing later mode switching remains available.

Pre-change findings, the preview-only toolbar rendering fault and its correction,
and light/dark/replay screenshots are recorded in
TANGERINE_SPLASH_DESIGN_2026-10-22.md. The final normal macOS build succeeds and visibly waits on the new opening
chooser after the splash; it is left running for the user. No mode selection
was executed as runtime acceptance; automated tests/analyzers remain deferred.

## Automatic library processing and remaining category organization — 25 October 2026

Implemented persistent device-local organization/analysis jobs, transactional scan
hooks, bounded startup reconciliation, revision/lease guards, restart recovery,
per-library pause/resume, foreground viewer priority and bounded retries/offline
waits. Processing is visible in library/category controls and title details.
Organization candidates lead to explicit parent/part/edition editing; matches,
manual corrections, file identity, notes and progress retain their ownership.

Added local metadata/technical probes for audio/video and supported reading/image
formats, embedded audiobook chapters, and category browsing for audiobooks,
podcasts, photos, home videos, music videos and documents. File-month labels do
not imply recovered camera capture metadata. See
TANGERINE_LIBRARY_PROCESSING_2026-10-25.md for concrete pre-change findings,
Plex scanner/catalog and Panels job/cache mappings, source scope and limitations.

The isolated synthetic UI preview and normal entry-point restoration compile on
macOS. The app is left closed. Revised visual review is pending a Mac unlock; no
processing worker or runtime acceptance was run.
Automated tests/analyzers remain deferred until full master-plan implementation.

## Remaining implementation before testing may start

The master plan is the complete scope; this list highlights known open work and
is not a reduction of that scope:

- Automatic app-open technical/organization scheduling and the remaining category
  browsing now have source implementations. Reconcile their source contracts with
  final P0–P11 requirements; platform availability, lifecycle, retry/restart,
  resource and end-to-end acceptance remain unverified. Online-provider
  search/preview/selection and artwork have source implementations; see
  TANGERINE_ONLINE_METADATA_2026-10-21.md for provider scope and evidence limits.
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
release or a verified checkpoint. Checkpoint 2a3ff62 preceded the online metadata, category browsing and manga-direction changes documented above.

## Remaining-feature source audit — 25 October 2026

The user cancelled further screenshot review, then requested the complete remaining
feature list. Saved TANGERINE_REMAINING_IMPLEMENTATION_2026-10-25.md with 36 grouped
implementation/integration/capability entries, seven source-audit closure items,
and a separate later acceptance inventory. It corrects stale “missing” statuses
for queues/playlists, mini-player, outputs/casting, preferences/profiles, typed
browsing and current catalog/transport work. No product source, tests, analyzers,
builds, screenshots or runtime journeys were executed for this audit.


## Native player/platform implementation — 25 October 2026

Saved pre-change source findings in TANGERINE_NATIVE_PLAYER_2026-10-25.md, then
added real VideoLAN Android/iOS/Windows/Linux bindings, independent desktop
engines/windows with queues/close-flush ownership, live framing/output selection
and diagnostics, all original action/mouse/modifier bindings, supported original
settings/profile/EQ/picture/artwork migration and PLS export. Reconciled N01/N02/
N10/N11/N12/N13 source status with explicit supported-field/platform boundaries,
without claiming all original catalog/volume-boost/service policies as parity. The plugin README records platform
capability, lifecycle, resource and runtime provisioning boundaries.

Dependency resolution completed (`flutter pub get`, iOS `pod install`), with
MobileVLCKit 3.6.0 locked and iOS Profile configuration separated. Dart formatting
and source diff whitespace review were performed. Graphify query/path guided
scoped investigation; AST maintenance and project remapping include the new
native package and Objective-C method-channel literals. Graph parser warnings
for macros/Gradle are extraction limitations, not compiler results.

No application tests, analyzers, builds, startup, screenshots or runtime journeys
were run. Platform acceptance remains deferred until the full master-plan
implementation phase is closed. Changes are uncommitted; no commit/push was
requested for this pass. The prior library-processing visual review was cancelled
by the user, superseding its historical pending-unlock note above.

Follow-on source work wires embedded/detached policy, primary-serialized window
admission, queue snapshot handoff, tray/start-hidden, track notifications, folder
playlist grouping, finish/quit preparation across windows, original decimal skip
values, queue repeat/shuffle and snapshot defaults/preview. Primary ownership
keeps process-wide desktop resources out of child services. Pinned tray/notifier
dependencies resolved and macOS pods installed. CocoaPods emitted custom base
configuration and generated DART_DEFINES parsing warnings; no application build
was run to accept those configurations. Windows/Linux now additionally require
the documented tray/notification system dependencies at build/distribution time.

### 25 October 2026 — books/comics/publication performance implementation

Saved source-only findings first in TANGERINE_READER_PERFORMANCE_2026-10-25.md;
used Graphify query/explain mappings and the retained Panels EPUB/geometry/cache
findings. Added native Windows/Linux EPUB rendering through the pinned Forge
WebView2/WPE dependency and shared Apple/Android bridge; EPUB 3/NCX contents and
fragment/internal destinations; bounded/cancellable text search with continuation;
ordinary-scroll text anchors and capture-before-reflow persistence; finite,
actionable publication retries; measured outer geometry and on-demand geometry
loading; lazy HTML/raster/PDF thumbnail navigation; scheduler lifetime settlement,
separate byte/count caches and protected-recency disk cleanup. Declared macOS-only
Vision OCR and visible availability explanations elsewhere. Narrow reader toolbars
keep navigation/Study discoverable without adding every control to one row.
Reconciled R01–R09 as source implementation/capability decisions with target
acceptance and runtime distribution limits kept separate. Dependency resolution
and formatting only; no tests, analyzers, builds, app runs or screenshot review.

### 25 October 2026 — browsing, global search and organization

Saved screen/source findings first in TANGERINE_BROWSING_ORGANIZATION_2026-10-25.md
and used Graphify plus retained Plex catalog/schema/API and Panels geometry/cache
references. Implemented catalog FTS global search with SQL filters/order/keyset
paging and saved Study destinations; shared specialized/generic sort/grid/list/
favorite/tag controls; dedicated ordered collection/album detail, reading,
playback and photo journeys; tag editing and transaction-safe organization writes;
separate Continue Watching/Reading/Listening and Home collection shelves; bounded
photo zoom/pan/reset and album-scoped navigation; offline ID3/FLAC/MP4/Vorbis/Opus
embedded cover extraction with cache invalidation and atomic publication. Kept
provider/user artwork precedence, named-library membership, saved notes and file
identity. Source-only implementation with explicit parser/platform limits; no
tests, analyzers, builds, app runs or screenshot review. Later acceptance remains
separate. Updated U01–U07 backlog entries to reflect source coverage.

### 25 October 2026 — reported macOS Dart compilation blockers

The user's launch log reported an unwired PdfReaderScreen.initialStudyAnchor
constructor argument, nullable import-preview data captured by a dialog closure,
and player-state calls to an audio-surface-local time formatter. Added the PDF
constructor parameter, captured an immutable checked preview for dialog/state
callbacks, and qualified the existing formatter consistently. Dart formatting
completed; Graphify refreshed. The supplied failed build is user evidence, not a
locally executed check. No build, analyzer, tests or runtime launch was performed
for this repair; startup success is not yet verified. The plugin Swift Package
Manager notices and libVLC script-phase warning are separate from these reported
Dart errors.

Follow-up to the user's next launch log: corrected the remaining speed read in
_importPreferences' setState callback to use the checked immutable preview.
Reviewed the entire method; all reads after its null guard, including both UI
callbacks, now use preview/native/local/global rather than nullable data. The
previous repair missed this final reference. Formatting only; no local build,
analyzer or tests were run.

### 26 October 2026 — macOS build verification and Advanced MyVLC workflows

The user explicitly authorized solving the supplied build errors and executing a
verified build. The original macOS debug build now succeeds with a durable local
Forge macOS WebView override (SDK insets, availability and public default arguments),
preserved macOS 12 target and explicit always-run VLC bundling. Signature verification
passes. Historical startup found a Future-returning identification setState callback;
both refresh sites are corrected. See TANGERINE_MACOS_BUILD_VERIFICATION_2026-10-25.md
for the actual build/startup evidence and remaining upstream warnings.

Saved source-only workflow findings first in TANGERINE_ADVANCED_MYVLC_2026-10-26.md
and used Graphify plus original MyPlayer capture/subtitle/add-on/skin/control-strip/
preferences sources. Added the Advanced player entry from Settings and playback,
separate input player, explicit AVFoundation capture, libVLC screen/disc inputs and
navigation, saved streams with credential-vault query URLs and previewed idempotent
legacy remote-entry import, bounded paged subtitle search/download/current-title
assignment, opt-in original Last.fm and authenticated proxy configuration through
native Keychain, bounded macOS MyVLC JavaScript management/execution, JSON color
skins and shared reorderable audio/video/input controls. Native-only capabilities
are labeled on other platforms. Source implementation, final successful macOS
build/signature and later hardware/account acceptance are recorded separately.
No screenshot review or automated acceptance tests were run.

### 26 October 2026 — browser experience safe checkpoint

Reviewed the browser/server/catalog/reader boundary using Graphify and retained
Plex/Panels findings; saved source-only screen findings before edits. Drafted
category/details/reader APIs, EPUB text bridge, HTML screen structure and richer
host-remote integration. The user requested stopping before the browser JavaScript
controller was complete. Restored the existing browser/server/remote contract and
removed only this turn's additions from previously modified player/category code.
Saved inactive drafts, isolated patches and remaining correctness/integration work
in docs/browser-checkpoint-2026-10-26/. No partial feature is activated. No tests,
analyzers, builds, screenshot review, commit or push were performed for this task.
