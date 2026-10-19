# Tangerine update plan

Planning baseline: 18 October 2026; reader plan revised 19 October 2026 using
[the Panels deep decompilation report](PANELS_DEEP_DECOMPILATION.md) and its
geometry, cache/background and EPUB companion reports.
The consolidated execution order and current source baseline now live in
[TANGERINE_MASTER_IMPLEMENTATION_PLAN.md](TANGERINE_MASTER_IMPLEMENTATION_PLAN.md),
including the [targeted Plex native findings](PLEX_TARGETED_DECOMPILATION.md).
Use that master plan for implementation slices; this document retains the
detailed product scope and reader acceptance contracts.
The user's added Netflix-style UI requirement is specified in the master
plan's UI track: cinematic browsing, horizontal rows, poster/detail surfaces
and Continue Watching/Reading/Listening, with MyVLC capabilities and Study
tools retained throughout.
Product name selected by the user:
**Tangerine**, tied to the existing orange accent. This is an implementation
roadmap. Execution has started; see `TANGERINE_IMPLEMENTATION.md` for actual
completed work, verification and remaining gates. The full roadmap is not complete.

User clarification: the requested merge keeps **MyVLC at the forefront**, including
its playback engine and functional workflows. Tangerine is the new product name.
The initial Flutter/media_kit integration was an incomplete merge baseline, not
the intended final playback architecture. The implementation ledger records the
subsequent macOS libVLC integration and remaining platform gaps. This correction supersedes the earlier
plan's instruction to retain media_kit as the permanent native backend.

**1. Product and retained work**

Tangerine is the evolution of MyVLC into a personal media library, player and
server with integrated reading and learning tools. Preserve MyVLC's visual
language, controls, workflows and libVLC-based native playback. Integrate
StudyStream's libraries, progress, notes, bookmarks, PDFs and synchronization
into that media-player experience. Preserve the working data/services while
correcting the incomplete playback integration.

Already implemented: player/server role selection, guided server setup, local
folder scans and file imports, content fingerprints and conservative relinking,
video/audio playback, PDF reading, notes/bookmarks, progress, backups, native
companion pairing, authenticated range streaming, browser playback and study
sync. Current workspace source additionally contains typed library kinds,
multiple source records, generic catalog payloads and reader prototypes.
These have open release gates; their presence is not proof of completed
typed browsing, multiple-root hosting or migration acceptance.

`docs/MEDIA_PLATFORM.md` records the prior verification, including 73 tests,
native integration and macOS/Android/iOS simulator builds. These are historical
results, not checks rerun during planning. Keep existing worktree changes and
verification artifacts intact.

**1a. Required merge correction: MyVLC engine and feature preservation**

The original source at `/Users/satwikpallerla/Documents/ChatGPT/MyPlayer` has a
`CLibVLC` dependency and a `VLCEngine.swift` that owns the libVLC instance/player,
video surface, transport, track selection, effects and related engine calls.
The initial StudyStream player constructed media_kit's Player/VideoController;
the macOS player now uses the MyVLC native boundary described in the implementation
ledger, while other native targets retain interim backends. Compilation/playback
checks of the initial Flutter app do not demonstrate completion of the requested
MyVLC merge.

Before expanding the catalog or reader, establish a feature-preservation matrix
against MyVLC's actual source, settings, persistence and prior validation. Classify
each feature as integrated, missing, platform-specific or awaiting runtime
verification. Preserve implemented MyVLC capabilities as merge requirements;
hardware/account limitations must remain explicit rather than being counted as
verified. The original source and its data remain intact during this work.

Introduce a native playback boundary and integrate libVLC as the primary native
engine. On macOS, evaluate reusing the existing Swift/C engine and stable video
surface through a native bridge. Other native targets need their own supported
bindings, rendering/lifecycle integration and verification. Choose the shared UI/
native view boundary by whether it preserves MyVLC behavior; retaining Flutter
alone is not a justification for dropping its engine or features. Investigate
current platform support before selecting packages or distribution methods.
The existing HTML browser client has a separate playback capability boundary;
do not claim it runs native libVLC. Any interim media_kit route must be explicit,
not silently treated as completion of the requested engine merge.

Required source-to-merged-app coverage includes transport, resume, chapters,
frame stepping, tracks/subtitles and assignments; library/recent history; queue,
shuffle/repeat and named playlist import/export; effects/equalizer, picture and
audio adjustments; shortcuts, preferences and profiles; multi-window/mini-player;
recording, conversion, stream output, casting, capture and web-remote workflows;
and existing add-on/customization behavior where supported. Preserve the MyVLC
interaction design while incorporating StudyStream tools. Each platform must
show implemented behavior, a clear unsupported boundary or an identified gap.

Make migration of MyVLC's library.json, playlists, recent/resume records, subtitle
assignments and supported preferences part of the merge. Prepare a read-only
preview, retain originals, import transactionally, make repeat imports idempotent,
and explicitly resolve identity/progress conflicts with StudyStream records.
Preserve credential-store boundaries and never copy secrets into general backups.

Engine acceptance requires actual local and protected remote playback, video
rendering, seek/pause/rate, tracks/subtitles, lifecycle cleanup and durable progress
through the new boundary. Effects, outputs and device-dependent features need
their own meaningful checks; retaining menu labels does not count as preserving
functionality. Keep the old working path available during development until
replacement checks pass. Test switching libraries/readers without leaking native
players or losing progress. Do not claim cross-platform parity from a macOS build.

**2. Evidence that shapes the design**

The supplied Plex first-scan report established distinct library, source-root,
file, technical-media and catalog-match records for one observed movie.
The [targeted native investigation](PLEX_TARGETED_DECOMPILATION.md) now adds
scan completion/unavailable-root handling, path/size/fingerprint reconciliation,
edition-aware identity and subtitle rules, extras, multi-episode guards,
manual search/match/unmatch, field-lock reset guards and provider requests.
Packaged legacy scoring is separate from modern native behavior; modern remote
ranking/confidence and complete inbound library authorization remain unresolved.
The packaged schema is a baseline template, not the fully migrated live schema.

[`PANELS_INVESTIGATION.md`](PANELS_INVESTIGATION.md) records the first Panels
investigation. Confirmed
behavior includes CBZ/PDF/fixed-layout EPUB rendering, natural archive ordering,
reverse page navigation, restored reading direction/progress after restart,
continuous vertical PDF reading and visually distinct dynamic backgrounds.
Generated geometry uses content-hash identity.

[`PANELS_NATIVE_DECOMPILATION.md`](PANELS_NATIVE_DECOMPILATION.md) adds native
REA/Ghidra evidence for PDFKit view setup and an alternate image path, continuous
aspect-ratio sizing, canonical-page/spread lookup, tap-region geometry, Realm
session writes, edge-strip color sampling, prefetch cancellation and the EPUB
native/JavaScript metrics bridge. Its per-feature sections link to exact evidence.
The [deep pass](PANELS_DEEP_DECOMPILATION.md) further establishes named fitting
calculators, cover/landscape/square pairing, configurable physical edge taps,
mode-identified raw zoom offsets, configuration snapshot/default fallback,
VisionKit image analysis and interaction installation, axial gradient/fade
composition, count/date cache trimming and allocated-byte disk cleanup, plus
EPUB resource/snapshot sequencing. Complete PDF/Study transforms, every
mode/rotation/gesture handoff, library-specific settings precedence, global
decoded-memory budgets and some EPUB mode transitions remain unresolved.
Cloud sync internals remain unknown. Recovery is evidence for design and
acceptance checks; no reader milestone is marked implemented by decompilation.

Use those relationships and observed outcomes to define Tangerine's own behavior.
Reproducing a proprietary implementation is not a prerequisite for independent
library and reader features. Provider selection and remaining ambiguous behavior
need documented decisions before dependent implementation.

**3. Library types and delivery scope**

Users can create multiple named libraries of each type. A library type supplies
organization, matching rules, reader/player defaults and a suitable browsing
surface; a file extension alone must not determine whether audio is music,
an audiobook, a podcast or a course lesson.

| Type | Organization and expected experience | Delivery |
| --- | --- | --- |
| Movies | Posters, title/year, synopsis, credits, editions and resume | First catalog release |
| TV Shows | Shows, seasons, episodes, watched state and next episode | Following movie catalog foundations |
| Music | Artists, albums, tracks, tags, queue and playlists | Music release |
| Music Videos | Artist/title organization, video playback and playlists | Music/video extension |
| Home Videos | Folders, dates, thumbnails and user titles; matching optional | Initial generic-video specialization |
| Photos | Albums, timeline, zoom and slideshow | Photo release |
| Audiobooks | Books/authors, chapters, listening position and sleep timer | Listening release |
| Podcasts | Shows, episodes and listening state; feeds later | Local files first, subscriptions later |
| Books | Authors/series, covers, reading locators and EPUB support | Reader releases; distinguish fixed-layout from reflowable EPUB |
| Comics & Manga | Series/volumes/issues, CBZ, thumbnails and persistent reverse reading | First new reader release |
| Documents | Existing PDFs/text/resources, search, notes and bookmarks | Retain current capability, extend formats deliberately |
| Courses | Existing sections/lessons, mixed resources, completion and learning tools | Preserve throughout |
| Mixed | Folder-oriented browsing for heterogeneous collections | Compatibility default for unclassified imports |

Registering a type does not count as completing its experience. Expose only
working capabilities and indicate format/platform limits clearly. Existing
libraries retain their current hierarchy and course tools until explicitly
classified; migration must not guess a library's purpose from file extensions.

**4. Baseline, rebrand and compatibility**

Record the current database schema, storage/credential paths and verification
baseline. Use isolated fixture databases and media for new acceptance journeys.

Change visible application names, native product/window labels, browser title,
onboarding, server defaults, artwork and documentation to Tangerine. Retain the
charcoal/orange palette and provide a distinct app mark. Preserve a user's
custom server name and appearance choices.

Keep bundle/application identifiers, package imports, credential keys and
database identity stable during the initial rebrand. A display/product name can
affect platform storage lookup, so explicitly verify old data locations and
security-scoped folder bookmarks. Pin the existing location or implement and
verify a one-time migration before changing any storage lookup. Keep existing
LAN discovery compatibility until a versioned replacement is available.

Acceptance: an upgraded installation opens its existing libraries, notes,
reading/playback state, preferences and paired credentials under the new visible
name; a new install starts with Tangerine onboarding.

**5. Shared library and data foundation**

Add library type and source-folder records using additive, versioned migrations.
Backfill each current root into one source record without regenerating library,
section or item IDs. Continue supporting legacy backups through explicit import
conversion. Old clients must receive compatible responses or an actionable
incompatibility result, never silently lose data.

Introduce the following responsibilities incrementally:

| Record/service | Responsibility |
| --- | --- |
| Library + library source | Logical collection, type/defaults, roots, permissions and availability |
| Existing item/file identity | Durable association for current progress, notes, bookmarks and relinking |
| Catalog entity + match link | Provider identity, descriptive metadata, match provenance and correction |
| Media properties | Container, tracks, codecs, resolution and explicitly defined duration units |
| Reader configuration | Versioned app/library defaults and sparse title overrides for direction, mode, fit and background; resume state stored separately |
| Reading locator + study anchor | Canonical source-page identity, page-local reading position and zoom; independent stable note/bookmark/selection anchors |
| Page geometry/artwork cache | Regenerable derived information with limits and invalidation versions |
| Collections, playlists and albums | User organization with distinct grouping/playback semantics |

Support multiple roots, source-specific refresh/relinking and duplicate/overlap
review. An unavailable root must not mark files from healthy roots missing or
erase progress. Preserve scan cancellation, unreadable-folder handling and
transactional updates. Canonical/source-relative paths need an explicit mapping;
do not change the current ID derivation accidentally while adding source IDs.

Continue using existing item IDs for reading/playback history. Catalog corrections
and user-title changes must not reset it. Do not automatically merge histories
of duplicate files, alternate editions or different page layouts. When a visible
movie groups multiple files, choose a version explicitly and resume the correct
file. Canonical metadata, user overrides and filesystem names remain separate.

Acceptance: upgrade, rescan, rename, moved roots, duplicate files, disconnected
volumes, backup restore and catalog corrections retain the correct identities.

**6. First reader release: comics, manga and reverse reading**

This is a core release requirement, reflecting the user's explicit priority.
Retain the existing PDF text/search and Study tools while adding shared reader
geometry, state and navigation. Implement CBZ/image archives and fixed-layout
EPUB as distinct page sources. CBR/CB7/CBT need evaluated decoder support and real
fixtures before being advertised. Reflowable EPUB retains separate text locators
and typography; spine resource names alone do not preserve a text position.

The subsections below are implementation requirements. Where Panels evidence
stops, the stated behavior is a Tangerine decision, not an assertion about Panels.
Do not translate Ghidra pseudocode directly into production code or copy its
unresolved Swift arguments/returns. The recovered PDFKit OS-version workaround
does not justify adding that workaround to Tangerine's different PDF backend.

**6a. Current code and shared reader boundary — C0**

Inspect and evolve the existing `lib/data/reader/book_page_source.dart`,
`safe_book_archive.dart` and `lib/features/reader/book_reader_screen.dart`.
These workspace prototypes are present but have no acceptance evidence in this
plan. Do not count them as completing C or replace them wholesale without review.
Their current gaps include viewport-height continuous items, adjacent-page spreads
with single-page advancement, 18% edge taps, a four-entry future cache, sampled
left/right image bands, whole-title settings snapshots, and fixed-layout EPUB
restricted to a single image per HTML page. Existing PDF reading remains separate.

Extend the page-source boundary to expose stable source-page identity and count,
intrinsic geometry/page box/rotation, render and thumbnail requests with target
size, cancellation, and explicit disposal. Keep renderer-specific text search,
selection, page-coordinate conversion and EPUB metrics as optional capabilities;
do not require every renderer to return only compressed image bytes. Separate
source access, layout, navigation, persistence and background calculation from
the screen widget so each can be verified independently.

Retain archive/path validation, CRC checks and expansion/image-size limits.
Extend cancellation through reads, decode queues and source disposal; a cache
entry removal is not cancellation. Natural sorting determines CBZ source order;
EPUB spine order determines EPUB source order. Presentation direction changes
neither order nor image pixels.

**6b. Canonical locators, configuration and durable state — C0/C1**

Define a versioned reading locator with item/content revision, source-page key,
canonical 1-based page, normalized unrotated page-local position, user zoom
relative to the selected fit, and layout/fit context. Define zoom-lock state
explicitly if implemented. Keep resume state out of library defaults and title
preferences. Store last-read and furthest-read/completion separately: reversing
direction or moving back must not reset completion or attach notes to another page.

Panels' recovered zoom lock contains identifier, scale and raw UIScrollView
content offset; restoration checks reader identifiers and single-page fit mode.
Retain that compatibility guard concept, while keeping Tangerine's normalized
page-local Study anchors separate from viewport resume offsets. Do not migrate
notes into UIKit pixel/point offsets or assume unchanged raw offsets preserve
content after rotation. Add mode-mismatch and viewport-resize restore fixtures.

Resolve each preference as explicit title override, then library default, then
application default. Absence means inherit; false/zero are real values. Provide
a reset-to-inherit action. Saving a locator must not materialize all inherited
preferences into title overrides. An explicit “Use these defaults for this
library” action copies only supported preferences, never locator/page/zoom state.
This precedence is our chosen contract. Panels' last-title configuration followed
by serialized app default/static fallback is recovered; a complete sparse
library-specific inheritance model is not established.

Use additive migrations for legacy page/vertical-offset/zoom records. Recover
the canonical page first, convert legacy offsets only in a compatible layout,
and retain a safe page-level fallback when exact conversion is unavailable.
Changed content/page order must not silently reinterpret existing study anchors;
record the revision mismatch and allow explicit recovery/relinking.

Hydrate settings, geometry and locator before enabling autosave; restore once
layout is ready and suppress save feedback during restoration. Serialize writes
per item and flush on settled navigation, explicit setting changes, reader close
and supported app lifecycle transitions. Use the existing 700 ms debounce for
continuous scroll/zoom updates as an initial Tangerine policy, with an explicit
flush for normal close/quit. Treat abrupt termination as recovery from the last
committed locator. Do not infer a Panels 30-second timer from its store guard.

Add locator/override versions to backup and companion transport in the same
milestone. Keep legacy page-level notes/bookmarks readable. Define conflict
resolution for resume state and individual overrides, including override removal,
so a stale client cannot restore a deleted override or reset an annotation anchor.
Unsupported clients must preserve unknown fields or reject incompatible writes.

**6c. PDF and Study integration — C1**

Adapt `lib/features/reader/pdf_reader_screen.dart` around the shared geometry and
locator contracts while retaining `pdfrx`, `PdfTextSearcher`, selection/search
capabilities and existing notes/bookmarks. Retain authenticated remote loading.
PDF rendering, tile/cache behavior and text coordinates are backend capabilities
to verify; Panels' PDFKit setup does not establish their implementation in pdfrx.

Panels also analyzes rendered page images with VisionKit and installs image
analysis interactions. Treat optional raster OCR as a separate capability;
it does not replace pdfrx native PDF text/search or define durable Study anchors.
Neither PDFKit's private tiling nor VisionKit selection quads were recovered
from the app binary. Keep source text and OCR coordinates explicitly identified.

Define one tested transform from unrotated page-local coordinates through the
chosen crop/page box, rotation, fit, user zoom and viewport offset, plus its
inverse for hit testing. Preserve nonzero crop origins. Keep search/selection
quads in page coordinates and transform them for each presented page/spread.
Extend study anchors additively with content/page identity, declared coordinate
box, normalized regions and optional text quote/range information. Existing
page-only notes remain page-only; do not fabricate their positions.

Gate: visible text search results, selection and anchored notes agree on PDFs
with mixed page sizes, nonzero crop origins and 0/90/180/270-degree rotations.
Check them after fit/zoom/pan, direction changes, spread/continuous switches and
restart. Keep study controls reachable on compact screens and keyboard layouts.
Coordinate support must survive any future optional bitmap rendering path.

**6d. Geometry, spreads and mode changes — C2**

Cache intrinsic page geometry by content revision and geometry algorithm version.
Compute presentation geometry from available viewport space. Paginated cells
occupy the viewport; inner fit-page uses `min(viewWidth/pageWidth,
viewHeight/pageHeight)`, and fit-width uses `viewWidth/pageWidth`. In continuous
vertical mode use width-constrained page heights, `viewWidth * pageHeight /
pageWidth`, with explicit gaps/insets and cumulative page offsets. A future
continuous horizontal mode uses the analogous height-constrained calculation.
Do not calculate page identity as `scrollOffset / viewportHeight`.

Build a spread map from canonical page identities before rendering. Initial
Tangerine policy: a cover is single by default; subsequent eligible portrait
and square pages pair sequentially; a strictly landscape page
(`rotatedWidth > rotatedHeight`) stands alone and breaks pairing; an unmatched
final page stands alone. Allow explicit cover/pairing adjustment and repair
orphan halves around wide-page breaks. This adopts the recovered Panels square
boundary and supersedes the earlier square-single choice; the prototype's 1.25
threshold is not the recovered rule. Disabling spreads
on narrow viewports must preserve the same locator.

Advance through spread entries, not `currentPage + 1`, to avoid overlapping
two-page displays. RTL changes placement within each spread and presentation
order; source pages retain their identities. Resolve a requested canonical page
to its containing spread. Track the focused source page inside a spread for
reading state and Study tools. Use the page intersecting the viewport center
as the initial focus rule, with deterministic direction-aware tie breaking.

Before changing mode, fit, direction, size or orientation, capture the focused
page and page-local position; map that anchor into the new layout and clamp only
when necessary. Never replay an old document-wide pixel offset into a new mode.
Gate: covers, odd counts, wide/square pages, mixed page sizes and both directions
visit every canonical page without omission, duplication or anchor drift.

**6e. Reverse reading, touch and accessible controls — C2**

Route keyboard, swipe, edge tap, buttons, thumbnails and scrubber through one
semantic next/previous/jump controller. In horizontal LTR, left action goes back,
right advances and a leftward swipe advances. In RTL, left action advances,
right goes back and a rightward swipe advances. A spread step follows the spread
map. PageUp/PageDown remain explicit previous/next actions in canonical reading
order. Images are never mirrored.

Use the recovered tap layout as the initial Tangerine default: a full-width top
band 20% of the reference-view height, then left/right regions each 33% of its
width with the center between. Top/center toggle controls; side actions navigate
when enabled. Test region boundaries and coordinate conversion when the host and
scroll reference view differ. These action bindings are our policy; the recovered
Panels handler only established generic closures and gates.

Resolve single/double-tap competition explicitly. Disable navigation gestures
while selecting text, manipulating Study overlays or panning a zoomed page; keep
deliberate buttons/keyboard navigation available. Give double-tap a defined zoom
action and respect accessibility gestures and reduced motion.

Reverse horizontal thumbnail order and scrubber presentation together, mapping
each position back to its canonical page. Labels, counts and percentages retain
canonical meaning. In vertical mode keep canonical top-to-bottom source order
and vertical scrolling; RTL may affect spread placement without reversing the
document vertically. Gate: first/last boundaries, mouse/keyboard/touch, zoom and
selection gates, direction changes during loading and restored state all agree.

**6f. Loading, prefetch and cache lifecycle — C3**

Add a scheduler for visible-page rendering, nearby-page prefetch, thumbnails,
geometry and background jobs, with visible work prioritized over speculative
work. Keep page and thumbnail task maps separate; coalesce duplicate requests.
Use renderer cancellation and generation/revision checks so stale work cannot
paint a reused page, update another title or overwrite a newer background.
Drain/cancel owned jobs and dispose decoded images on close or source replacement.

Specify limits in decoded bytes as well as task counts; a four-entry future map
does not bound image memory. Account for the framework image cache and full-size
decodes, request viewport/zoom-appropriate resolutions, use LRU eviction for
unneeded decoded resources, and reduce speculative work on memory pressure.
Set and record per-platform queue, look-ahead and byte budgets before enabling
prefetch; tune them against large CBZ/PDF fixtures. Those measured budgets are
Tangerine decisions, not recovered Panels constants.

Panels provides useful reference policies: separate page/thumbnail dictionaries,
access-date refresh, pre-insertion trimming at >=11 to 9 and >=51 to 49,
memory-warning result clearing, and priority-aware shared tasks with cancellation
retries. Its app-wide disk limiter uses allocated bytes, 90% cleanup target,
600-second grace, write-activity gating and open-document protection. These
recovered count/disk rules do not supply Tangerine's decoded-byte or look-ahead
budgets. Specify ownership and cancellation semantics before adopting any of them.

Keep disk thumbnails, intrinsic geometry and derived-color caches regenerable,
versioned and separately bounded. Keys include content revision and relevant
page/render/rotation/color inputs; invalidate affected entries when those inputs
change. Never evict reading state or study anchors with generated caches. A
memory-availability allocation guard can be an additional safeguard where
supported; Panels' 1.5-times estimate is not a cache budget or portable API.

Gate: rapid jumps, direction/mode changes, repeated open/close, corrupt pages,
memory pressure and a long mixed-size book keep resource use within the recorded
budgets. Cancelled/stale jobs do not update current UI, and page errors retain
navigation and Study access. Check temporary authenticated downloads are removed
after cancellation, failure and disposal.

**6g. Dynamic backgrounds — C4**

Provide Black, White, single derived color and immersive opposite-edge colors.
The decompilation establishes actual edge sampling, replacing the old plan's
“visual result only” limitation. Use the recovered sampling relationship as a
reference for our implementation: `t = max(1, sqrt(0.009 * width * height) / 4)`;
sample left/right strips for horizontal presentation and top/bottom for vertical.
For single color, normalize and combine all four strips before averaging. Do
not use the current prototype's entire left quarter as the single-color result.

Declare the sampling coordinate space and scaling/rounding so a bounded
downsample gives consistent colors across resolutions and formats. Produce
opaque output. Choose a deterministic alpha-compositing matte and fallback for
empty/failed samples; include the matte in the cache key. Preserve white borders
in the initial algorithm as a Tangerine policy. Panels' sampler itself does not
remove white borders, although the deep pass identifies an optional upstream
removeBorders transformation. Any Tangerine border exclusion needs its own
versioned, tested algorithm and transformation-aware cache key.

Coalesce per-page color jobs and retain separate single/horizontal/vertical
results. Invalidate on source revision, sampling version, matte or relevant
render/rotation changes. Include transformation inputs when they alter sampled
pixels. Reuse C3's task and memory limits. Compose immersive side colors outside
the content, preserve Study-control contrast and interpolate only the active
background. Panels' recovered composition uses axial colors [A,A,B,B] and a
0.3-second normal transition, with interactive alpha blending. Tangerine adopts
300 ms as its normal default, or zero for reduced motion, superseding the
prototype's 180 ms choice.

Gate: solid colors, distinct edges, white borders, transparency, narrow images,
rotation, rapid navigation and mode changes have deterministic samples, correct
opposite-edge orientation, no late color flashes and bounded caches.

**6h. Fixed-layout EPUB pipeline — C5**

Replace the single-image-per-HTML restriction with a renderer that preserves
fixed-layout HTML/CSS, text, images and SVG composition. Keep EPUB resource/spine
identity independent of visual scaling. Evaluate platform rendering and local
resource access before selecting a new dependency; mark unsupported platforms
explicitly. Preserve the existing reflowable text path while its separate stable
text-position work is pending.

Implement a constrained package-resource resolver for relative HTML/CSS/image/
font URLs using the existing archive validation. Do not expose arbitrary local
paths or propagate companion credentials into publication content. The rendering
bridge owns its messages/scripts, validates message shapes and request identity,
and separates package-script policy from the required geometry bridge.

Use the recovered handshake as a behavioral reference: measure unscaled content,
preserve declared body/viewport dimensions, calculate scaled size from the reader
width, and return content width/height, scaled width/height and scale to native
layout. Validate positive finite usable dimensions and scale and bound their
sizes before allocation. Handle load, image/font readiness, resize and stale
responses; allow only bounded remeasurement to avoid layout feedback loops.
Panels' native resource/base-URL path, retry layers and 200 ms pre-snapshot wait
are now recovered references. A fixed wait is not proof of resource readiness;
Tangerine still needs bounded asset-readiness handling and a controlled timeout.
Keep transform origin/page-local coordinate mapping explicit. An absent or invalid
metric result yields a controlled page error/fallback, not unbounded dimensions.

Gate: image-only, mixed text/image, SVG, CSS backgrounds, relative styles/fonts,
body dimensions, viewport-only dimensions, late assets, invalid metrics and
viewport resize retain correct geometry and source-page identity. Verify Study
anchors and navigation alongside rendering. A two-page image-only fixture alone
does not establish fixed-layout EPUB completeness.

**6i. Reader release acceptance — C6**

| Gate | Required evidence |
| --- | --- |
| Identity/state | Additive upgrade and legacy page-only anchors; title override/inheritance/reset; normal close/quit/restart; backup restore and companion conflict cases |
| PDF/Study | Search/selection/notes on cropped, rotated and mixed-size PDFs through fit, zoom, pan and mode/direction changes |
| Layout/navigation | Natural CBZ order `1,2,3,10`; cover/odd/wide/square spreads; variable-height continuous pages; all input and scrubber mappings |
| Backgrounds | Numerical sample fixtures plus rendered single/immersive results; alpha/border policy, invalidation and reduced motion |
| Resources | Recorded queue/decoded-byte/disk limits, cancellation, stale-result suppression, long books and repeated disposal |
| EPUB | Actual rendered mixed-content/resource/resize fixtures, validated metrics and retained Study anchors on supported platforms |

Preserve the original journey: open the ordered CBZ, jump to page 2, enable RTL,
advance to canonical page 3, go back, quit/relaunch, and verify page/direction
without changing notes or completion. Extend it across spreads, continuous PDF,
mixed-content fixed EPUB, backup and companion sync. Record actual test commands,
platforms, failures and unsupported cases in `TANGERINE_IMPLEMENTATION.md` and
`VALIDATION.md` when implementation is performed. This planning revision supplies
no new runtime or test-pass claims.

**7. Movie and television catalog releases**

Add conservative title/year parsing and provider search behind a provider
interface. Validate the selected provider's current API, attribution, credentials
and caching requirements before implementation. Automatic enrichment should be
optional; local browsing/manual metadata must work without an account.

Store match source, provider ID, candidate/selected state, timestamps and user
overrides. Make searching, selecting, correcting and clearing a match explicit.
Uncertain files remain usable and unmatched. Define confidence using our own
tested rules. The native Plex consumer's legacy score branch, modern-agent
synthetic score of 100 and EPG-specific cutoff are not a general matching policy.

Build poster grids and details pages with synopsis, credits, genre, labeled
ratings, technical media and version-aware Play/Resume. TV adds show/season/
episode identity, numbering, specials and next-episode rules. Extras must not
be counted as primary movies/episodes by accident. Trailers/catalog extras and
local playable files are separate associations.

Acceptance: correct and wrong years, ambiguous titles, remakes, unmatched files,
duplicates, multiple editions, extras, provider failure, manual correction and
rescan all behave predictably without losing history.

**8. Remaining media experiences**

Music adds tag extraction, artists/albums/tracks, disc/track sorting, artwork,
queue and named playlists. Music videos reuse video playback with artist/title
organization. Audiobooks add books/chapters, durable listening locators, speed,
bookmarks and a sleep timer. Podcasts start with local shows/episodes; feed
subscriptions, refresh and managed downloads form a separate subsequent scope.

Photos add albums, date browsing, image zoom and slideshows. Home Videos retain
folder/date browsing and user labels. Books add reflowable EPUB typography,
contents and stable text locators when its renderer is ready. Documents retain
current PDF/text behavior; DOC/PPT/external-app formats should not be advertised
as complete native readers. Course tools remain available and tested throughout.

Add favorites, tags and user collections across types. Keep a grouping collection,
an ordered playlist and a photo album semantically distinct. Expand search to
catalog fields, authors/artists/series and user notes with bounded SQL queries.

**9. Home, navigation and server/client delivery**

Adapt Home, Libraries, Search, Collections, Network and Settings to the broader
product. Keep Study tools accessible from courses and item details. On compact
screens use a small primary destination set with secondary navigation; do not
place every library type in the bottom navigation bar. Preserve desktop rail/
sidebar layouts, keyboard focus, large-text support and scroll restoration.

Continue watching/listening/reading should use the correct content identity and
reader/player. User libraries determine the visible shelves and filters.

Version catalog transport separately from the local database schema. Deliver
typed libraries, metadata and reader settings to native clients and the browser.
Add query pagination and later delta sync before scaling to large catalogs;
current native/browser browsing caps are 120/240 and sync snapshots are capped
at 10 MiB. Do not raise the cap and assume scalability is solved. Serve artwork
and page resources through authenticated endpoints, avoiding local-path leaks.

Add per-library access controls and enforce them consistently on listing, search,
artwork, original files, pages and progress endpoints. Preserve revocation,
canonical-path checks, range streaming and exclusion of mirrored remote libraries
from hosting. Define ownership/conflict handling for metadata and reader settings
so a stale client cannot silently revert a corrected match or direction.

The existing trusted-LAN HTTP transport remains a known boundary. Internet
hosting/encryption, background services and offline downloads need their own
scope and acceptance evidence. MyVLC's existing recording/conversion, stream
output, casting and related player features remain merge requirements with
platform-specific implementation and verification. They are not optional future
work merely because the current Flutter integration omitted them. Physical mobile
behavior and Windows/Linux builds require their own hosts/devices.

**10. Delivery order and verification gates**

| Milestone | Deliverable | Gate |
| --- | --- | --- |
| A0 | MyVLC source/feature audit and native engine integration | Actual libVLC rendering/transport and StudyStream progress integration pass |
| A1 | MyVLC workflow preservation and existing-data import | Feature matrix, idempotent migration and supported workflow checks pass |
| A | Recorded baseline and Tangerine rebrand | Existing installation opens unchanged user data |
| B | Typed libraries, multiple sources and additive migration | Identity, backup and source-failure tests pass |
| C | Shared reader/Study contracts, comics/manga, reverse reading, backgrounds and fixed-layout EPUB | C0–C6 gates below pass on declared supported platforms |
| D | Movie catalog and matching correction | Ambiguous matches and file versions preserve progress |
| E | TV organization and next episode | Season/special/episode fixtures behave correctly |
| F | Music, audiobooks, local podcasts and books | Type-specific organization and locators verified |
| G | Photos, home video and shared organization refinements | Browsing, albums/playlists and search verified |
| H | Large-catalog transport and per-library sharing | Pagination, permissions and client compatibility verified |

The MyVLC merge correction precedes the new catalog/reader expansion. Rebranding
can accompany the merge, but cannot substitute for it. Reverse reading remains
a core requirement of the first comics/manga reader release.

Reader work is split into reviewable increments within C. Preserve the A0/A1 and
B dependencies above; the following order applies once that reader work is ready
to execute. C1 starts with bounded visible rendering; C3 adds scheduled prefetch
and the complete cache lifecycle before dynamic backgrounds or EPUB expansion.

| Increment | Deliverable | Gate / dependency |
| --- | --- | --- |
| C0 | Page-source capabilities, canonical locators, sparse preferences and additive schema/transport contracts | Legacy anchors and identity preserved; settings inheritance/reset specified; required B records available |
| C1 | PDF adapter, coordinate transforms, Study anchors and durable restore/commit | C0; cropped/rotated search/selection/notes and lifecycle/restore checks pass |
| C2 | Page geometry, spread map, continuous layout and unified RTL input/presentation | C0/C1; all canonical pages reachable and anchors preserved across mode/direction changes |
| C3 | Cancellation scheduler, page/thumbnail jobs and measured memory/disk cache budgets | C0–C2; long-book, rapid-jump and disposal checks pass |
| C4 | Versioned edge-derived single/immersive backgrounds | C2/C3; sample, invalidation, contrast and reduced-motion checks pass |
| C5 | Fixed-layout EPUB HTML/CSS/resource renderer and validated metrics bridge | C0–C3; supported-platform mixed-content and Study-anchor fixtures pass |
| C6 | Reader upgrade, backup, companion sync and cross-format release acceptance | All preceding applicable gates; original PDF/Study and MyVLC workflows remain intact |

Panels investigation priorities map to these increments: PDF/Study → C1;
geometry and reverse gestures → C2; saved state → C0/C1/C6; dynamic backgrounds
→ C4; loading/caches → C3; fixed-layout EPUB → C5. No sub-increment is marked
complete merely because a corresponding Panels procedure has been recovered.

Transport, schema, backup and browser support must accompany each milestone's
new records; H completes scale/access work rather than postponing all client
compatibility until the end. Each milestone should remain usable independently.

Run targeted migration, identity, reader/progress and sync tests as appropriate,
then formatting/analyzer/full tests and relevant native/browser journeys. Add
meaningful format fixtures and actual rendering/decoding evidence. Validate
mobile widths, large text, reduced motion and keyboard controls. Reuse the
existing isolated-data-directory mechanism and update validation records with
actual results, failures and remaining platform limits.

Deeper Panels/Plex investigation can resolve named unknowns, but should not be
mistaken for implemented Tangerine features. The edge-color sampling algorithm
is now recovered; its remaining composition/invalidation gaps have explicit
Tangerine policies in C4. Automatic panel detection, full proprietary behavioral
parity, cloud/account sync and remote server integrations remain separate,
evidence-dependent follow-ups. Existing MyVLC data migration and player workflow
preservation belong to the merge milestones above.

Execution note, 19 October 2026: the macOS portion of A0, the cross-platform
rebrand in A, and the initial local-data import portion of A1 are implemented.
`TANGERINE_IMPLEMENTATION.md` records the exact passing checks and open gates.
Full MyVLC workflow preservation, other native libVLC bindings, typed multiple-root
library release gates, reader C0–C6 acceptance, matching/catalog releases and
scale/access work remain open. Reader prototype files are present in the current
workspace, but their presence and the decompilation report do not establish
passing reader release gates. The ordered roadmap remains the source of scope;
the implementation ledger distinguishes source-present prototypes from
verified release gates. This revision
changes planning requirements only and does not promote prototype code to
delivered functionality.
