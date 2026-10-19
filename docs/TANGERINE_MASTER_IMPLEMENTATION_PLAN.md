# Tangerine implementation master plan

19 October 2026. This is the consolidated execution plan for the MyVLC-led
product, StudyStream's learning tools, the Panels reader findings and the
targeted Plex catalog investigation. It refines the scope in
[TANGERINE_UPDATE_PLAN.md](TANGERINE_UPDATE_PLAN.md). Implementation status and
actual verification remain in
[TANGERINE_IMPLEMENTATION.md](TANGERINE_IMPLEMENTATION.md); source presence and
decompilation do not count as release acceptance.

The user additionally requested a **Netflix-style UI**. Use cinematic browsing,
poster artwork, horizontal rows and rich details throughout the library
experience, while retaining MyVLC functionality and integrated Study tools.
Plex and Panels findings establish reference behavior. Proposed schemas,
defaults, UI and delivery choices below are Tangerine decisions that the user
can refine; they are not requirements imposed by those applications.

## Product contract and present baseline

Keep MyVLC's player capabilities and workflows at the forefront under the
Tangerine name. Evolve browsing into a Netflix-style experience with Tangerine's
orange accent, recognizable player controls and coherent Study surfaces.
Libraries, catalog browsing, server delivery, reading and Study
tools share resource identity and user state. A library's content type determines
its browsing experience; extension detection determines file capabilities.

Retain multiple named libraries of every planned type: Movies, TV Shows, Music,
Music Videos, Home Videos, Photos, Audiobooks, Podcasts, Books, Comics & Manga,
Documents, Courses and Mixed. Existing Courses and Mixed libraries remain usable
throughout. Do not force users to reimport media to gain catalog or reader tools.

| Area | Evidence-based baseline | Work still required |
| --- | --- | --- |
| MyVLC integration | Implementation ledger records macOS libVLC/native-view playback, effects, safe local import and protected relay acceptance | Full source-feature parity, preference/profile migration, distribution/runtime packaging and other native platforms |
| Branding | Tangerine display names and stable identity/storage were previously verified | Continue upgrade checks as schemas and native packaging change |
| Library/catalog source | Current workspace contains LibraryKind, library_sources, generic media_records, source-aware indexing/watchers and a local JSON provider | Explicit item-source ownership; normalized catalog/match/override model; completed workflows and release evidence |
| Reader source | Archive/page-source and reader prototypes exist alongside the existing pdfrx reader | Shared contracts, geometry, durable state, bounded jobs and mixed-content EPUB rendering |
| Study state | Existing item-linked notes, bookmarks, reading/playback progress and synchronization | Additive anchor/locator versions; content-revision handling and tested mode/rotation transforms |
| Server | Existing pairing, range streaming, snapshots and browser player | Secondary-root media resolution, complete snapshot scoping, library grants, paged catalog queries and compatibility |

This baseline corrects the older plan/status wording that described all typed
library and reader code as absent. The current source audit is retained in the
[catalog gap map](../.verification/plex-targeted-20261019/tangerine-catalog-gap-map.md).
It does not promote prototypes or source-only findings to tested functionality.

## Findings that determine the architecture

| Recovered finding | Tangerine implementation consequence |
| --- | --- |
| Plex separates library, location, metadata item, media representation, file part and stream records | Separate source ownership, descriptive identity, playable representation and user state. Catalog corrections retain existing item IDs. |
| Native scan reconciliation distinguishes unavailable roots from failed/cancelled scans | Track scan outcome explicitly. Preserve unavailable-source records; authorize disappearance only after a complete relevant scan. |
| Plex's local fingerprint/reconciliation path is distinct from catalog matching | Keep file matching and metadata matching separate. An identical fingerprint alone cannot authorize a destructive merge. |
| Modern movie/series scanner entry files hand off to native code; packaged scoring is explicitly legacy | Do not present historical Python thresholds as the modern algorithm or use them as an unexplained Tangerine confidence score. |
| Native modern-agent classification can force the consumer score to 100 | Provider score and local confidence are distinct. Explicit candidate choice and match provenance come before automatic matching. |
| Panels retains canonical pages while changing spread placement and horizontal reverse presentation | Persist source-page identity. Derive presentation order, neighbors, thumbnails and scrubbers from one map. |
| Panels recovers first-cover/strictly-landscape singletons, square pairing and pairing-anchor repair | Use these concrete rules for the Panels-style spread policy, with tested optional cover/pairing controls. |
| Panels zoom locks store mode identifiers and raw viewport offsets | Retain a compatibility gate for view-state replay; keep durable Study anchors in normalized page coordinates. |
| Panels uses PDFKit page/raster paths and VisionKit image analysis | Preserve pdfrx native text/search; expose optional OCR as a separate capability with its own coordinates and limits. |
| Panels color sampling, axial four-stop gradient and 0.3-second layer fade are recovered | Implement versioned edge sampling, solid/immersive composition and a 300 ms default fade, with reduced motion. |
| Panels separates page/thumbnail tasks and uses count/date trimming plus separate disk cleanup | Build explicit task ownership and decoded-byte budgets. Count limits and individual allocation guards are insufficient. |
| EPUB has a preserved HTML/CSS/resource pipeline as well as an image route | Replace the single-image restriction with a constrained publication renderer and a validated metrics/anchor bridge. |

Detailed evidence and limitations remain in
[Panels deep findings](PANELS_DEEP_DECOMPILATION.md),
[Plex targeted investigation](PLEX_TARGETED_DECOMPILATION.md),
[Plex native scanner findings](PLEX_NATIVE_SCANNER.md),
[Plex native catalog/API findings](PLEX_NATIVE_CATALOG_API.md),
[Plex schema findings](PLEX_CATALOG_SCHEMA.md) and
[packaged scanner findings](PLEX_PACKAGED_SCANNERS.md).
External provider behavior and framework internals are not reconstructed source.

## Identity and ownership model

Keep the existing Item ID as the compatibility identity for all current notes,
bookmarks and progress. Introduce explicit relationships through additive
migrations; use 1:1 adapters for existing single-file items before introducing
multi-file playback.

| Record | Required responsibility |
| --- | --- |
| Library | Stable ID, user name, content kind, defaults, hosting/access policy |
| LibrarySource | Stable ID, library, approved root/bookmark, availability, scan generations and last-success state |
| Item/FileAsset | Existing resource ID, explicit source ID, relative path, verified fingerprint, content revision and availability |
| TechnicalMedia | Container/streams, duration with declared units, dimensions/rotation, analysis version and errors |
| CatalogWork | Descriptive identity and type: movie, show, season, episode, artist, album, book or other supported entity |
| ProviderIdentity/MatchDecision | Provider ID, remote ID, candidate/fetch provenance, selected/cleared state, revision and decision origin |
| CatalogOverride | Sparse field overrides and explicit removals/locks, independent of provider snapshots |
| Edition | A cut/content variant; may have a different timeline or page order |
| PlayableRepresentation | A selectable technical representation of compatible content, retaining exact asset-specific resume |
| MediaPart | Explicit ordered physical components, with declared part durations and offsets when supported |
| Collection/Playlist/Album | Distinct membership and ordering semantics; scope and permissions are explicit |
| ReadingLocator/StudyAnchor | Source identity, content revision, page/text location and version; separate from library preferences |

A provider GUID never replaces a file/resource ID. A rematch or title edit does
not rewrite notes, completion or playback position. Identical bytes in two paths
remain distinct imports unless the user chooses an explicit relink/merge policy.
Do not copy exact resume across cuts. Logical title watched/completed state can
be derived separately from asset-level position.

Generic media_records payloads need a lossless migration path. Introduce typed
records for indexed/permission-sensitive fields; retain extension payloads only
where their schemas, ownership and size are validated. Preserve old backup and
transport readers through explicit version adapters.

## Netflix-style UI and interaction track

The visual direction is a cinematic dark browsing theme, large artwork,
horizontal media rows, clear type and restrained chrome. Preserve a light theme,
large text, reduced motion and high-contrast controls. Tangerine's existing
orange is the primary action/focus accent. Use the user's media artwork and
honest placeholders when metadata is missing. Keep artwork optional so an
unmatched file remains understandable and playable.

Build the shared shell and representative screens early using synthetic data;
connect them incrementally to the catalog contracts. A finished-looking mockup
is not a completed matching, scanning or playback workflow.

| Surface | Required experience |
| --- | --- |
| App shell | Persistent desktop navigation, adaptive compact navigation, visible library/server context, global search and access to Study/settings. Keep native/browser capability differences explicit. |
| Home | Optional featured artwork with title, concise context and Play/Read/Resume; Continue Watching, Continue Reading, Continue Listening, Recently Added and user collections. Rows come from real local state. |
| Library | Several named libraries of the same kind, type-appropriate poster/cover/photo cards, grid/list toggle, indexed search, sort/filter controls and full pagination. Retain folder/course browsing. |
| Details | Synopsis, creators, relevant metadata, technical information, available source/version, primary Play/Read/Resume, completion/bookmark actions and collection membership. Offer correction/clear-match and field editing. |
| Movies and TV | Posters/backdrops, edition/representation selection, extras as an associated row; TV season/episode navigation, specials, clear numbering and deliberate next-episode behavior. |
| Music and listening | Artist/album/track/disc browsing, queue controls, album artwork; audiobook/podcast chapters, exact resume, speed and sleep timer. Do not make every track a movie-style poster. |
| Books, comics and documents | Cover cards, Continue Reading, reader settings and visible Study entry. Courses retain sections/lessons and learning progress. Photos use albums/timelines and a viewer/slideshow. |
| Search | Group or filter by content kind/library; support title, creator and indexed tags. Display unmatched/local items and obey the same library grants as browsing. |
| Player | MyVLC transport, tracks/subtitles, chapters, queue and effects remain accessible. Include a compact information overlay and a Study side panel where space allows. Preserve shortcuts and supported advanced workflows. |
| Reader and Study | Focused reading surface, responsive Study side panel or sheet, chapter/page navigation, search/selection, notes/bookmarks and shared stable anchors. Opening tools can resize content without losing position. |
| Library management | Create/edit libraries, add/relink sources, scan status/cancel/retry, missing-source diagnosis, metadata correction and device/library sharing controls. Use clear progress and actionable errors. |

Cards support pointer, touch and keyboard equally. Hover may reveal extra
information, but primary actions are always discoverable without hover. Focus
must remain visible and stable when returning from details, player or reader.
Restore both a row's horizontal position and the page's vertical position.
Detail navigation has stable routes for native/browser back behavior.

Start Home with deterministic, explainable rows from library membership,
recent imports, user collections and actual progress. Do not imply a recovered
Netflix/Plex recommendation algorithm. Rich recommendation ranking can be added
later as an independent, user-controllable feature.

Use a shared token/component layer in the existing Flutter theme: colors,
spacing, typography, poster/cover/backdrop ratios, focus, loading, error and
empty states. Native and browser clients implement the same information
hierarchy and media contracts through their own rendering boundaries. Avoid
replacing the existing browser playback architecture merely to share widgets.

Virtualize rows and grids; load sized artwork and page row queries independently.
Prioritize visible cards, cancel stale work and bound decoded artwork memory.
Do not load the complete catalog to assemble Home or enable background autoplay
by default. Skeletons preserve geometry; offline, unavailable, unmatched and
denied states have distinct messages and actions.

**UI gate:** desktop, compact/mobile and browser journeys support import → browse
→ details → play/read → Study → return, with preserved focus/scroll/state.
Validate long titles, missing art, large text, keyboard traversal, reduced motion,
empty/offline libraries, many rows and library permission changes. Representative
screens must show actual data and working actions before being marked delivered.

## Ordered work packages

Each package finishes with its gate and an implementation-ledger entry containing
the commands, fixtures, supported platforms and actual result. Release gates are
dependencies; they are not a request to redo already passing unchanged work.

### P0 — Freeze preservation and close existing integration gaps

Map the present source and prior verification to the MyVLC feature matrix. Record
fixture IDs, source namespaces, metadata JSON, notes/bookmarks, manual completion,
reading/playback locators, queues/playlists, subtitle assignments and permissions.
Preserve existing uncommitted work and original import sources.

Prioritize the source-audit gaps before expanding hosted catalog data:

- Resolve media bytes through the item's approved source; current serving still
  checks the legacy library root and can reject secondary-root content.
- Filter media_records and every derived record by hosted/permitted library.
  Snapshot construction must not spread an unscoped payload before filtering
  only the older tables.
- Validate per-kind payload schema, immutable ownership and revisions at import.
- Retain current credential-safe relay, canonical containment, pairing/revocation
  and range behavior while changing those paths.

Primary files: `lib/data/db/app_database.dart`,
`lib/data/sync/lan_sync_server.dart`,
`lib/data/sync/sync_snapshot_merger.dart`,
`lib/domain/catalog/media_catalog_repository.dart` and the MyVLC native boundary.

**Gate:** fixture upgrades and repeated imports preserve IDs/state; a healthy
secondary source streams when the legacy root is absent; out-of-source paths
and unhosted-library records remain inaccessible. Actual native playback/Study
regression journeys remain passing. No test result is claimed by this plan.

### P1 — Complete library source and scan identity

Add an explicit Item→LibrarySource relationship. Backfill existing legacy roots
and synthetic source namespaces without regenerating Item IDs. Preserve namespace
compatibility and refuse ambiguous backfill. Root relinking retains its source ID
and macOS folder permission/bookmark.

Represent source status and scan result separately: available/unavailable and
complete/cancelled/failed/partial. Stage discoveries under a scan generation,
commit authoritative results only for the successfully observed scope, and keep
prior records for unreadable/excluded subtrees. Report scan outcomes to the user.
Cancellation must not look like an empty successful scan.

Use path, size, verified fingerprints and candidate cardinality to retain
unambiguous moves. Define cross-source moves explicitly. Fingerprint collisions,
duplicate paths and changed bytes require revision/review rather than automatic
history merging. Cache verified hashes for unchanged files and keep hashing
cancellable; never call a bounded fingerprint a full-file content hash.

Primary files: `library_indexer.dart`, `library_watcher.dart`, database migrations
and `MediaCatalogRepository`. Extract a proposed scan-session/reconciliation
service when that keeps filesystem discovery separate from database commits.

**Gate:** two roots, disconnected volume, unreadable subtree, cancelled scan,
rename, cross-source move, duplicate bytes, ambiguous matches, changed bytes and
relinking all preserve the correct resource and Study identity.

### P2 — Establish catalog, match and user-override boundaries

Implement the model above for Movies first, while retaining typed setup for all
library kinds. Migrate generic metadata losslessly. Keep technical analysis,
descriptive provider snapshots, explicit user fields and filename hints separate.

Make match selection, replacement and clearing atomic. Record provenance and a
revision; refresh updates provider data while preserving locked overrides.
Plex's recovered search, selected-match and unmatch paths are separate operations;
its reset guards also preserve marked fields. Implement explicit override/lock
ownership rather than clearing all metadata on correction or copying Plex's
opaque numeric field IDs.
Clearing a match records an explicit decision so a stale client cannot silently
restore it. Artifacts remain usable offline and unmatched.

Extract edition/cut markers before title cleanup. Resolution/codec/HDR tokens
describe a representation, not an edition. Represent extras as typed associated
resources, and split parts as ordered components, never alternate cuts. Add
multipart playback only once duration/part seeking and Study anchors are defined.

**Gate:** two files for one movie, two cuts, a multipart title, local extra,
metadata refresh, explicit override/removal and rematch all preserve the right
asset's position and notes. Backup round-trips preserve all relationships.

### P3 — Deliver matching and type-appropriate browsing

Connect the existing local JSON CatalogProvider to search, candidate preview,
select, correct and clear-match screens. Use synthetic/offline catalog fixtures
first. Implement tested title/year/folder/explicit-ID hints and TV episode/date
parsing with deterministic precedence and provenance. Display uncertainty.

Only then add an optional online provider through the same boundary. Verify that
provider's current API, attribution, access and caching requirements at that time.
Choose and test Tangerine ranking/automatic-selection rules; remote Plex results
and legacy thresholds are not a reusable offline ranking service.

Movies gain poster/detail/technical/version-aware Play and Resume. TV adds
show→season→episode navigation, explicit numbering order, specials and deliberate
next-episode rules. Exclude extras from ordinary episode progression. Music uses
embedded tags, artist/album/track/disc relationships and ordered playback queues.
Course/folder browsing keeps its existing section semantics.

Replace fixed first-120 browsing with bounded query pages using a deterministic
sort key plus stable ID. Add indexed catalog filters, transactional FTS maintenance
and explicit collection membership. Artwork jobs use content/provider revision,
bounded concurrency, cancellation and regenerable caches.

**Gate:** remakes, bad year, explicit ID, ambiguous/absent results, offline/provider
failure, >120 items, repeated sort keys, catalog edit during paging, wrong match,
multiple representations and TV specials behave consistently without state loss.

### P4 — Shared reader contracts and durable state

Evolve `BookPageSource` into a capability boundary for canonical page keys,
intrinsic geometry, source revision, targeted render/thumbnail requests,
cancellation and disposal. Preserve natural archive order and EPUB spine order.
Text search, selection, coordinate conversion and publication metrics are
capabilities; a renderer need not reduce everything to compressed images.

Split source access, layout, navigation, session persistence, rendering jobs and
background sampling out of `book_reader_screen.dart` into focused proposed
services/controllers. Retain archive validation, CRC/expansion bounds and current
PDF/remote-loading behavior.

Define a versioned locator containing resource/revision, canonical source-page
key and index, normalized unrotated page-local point, fit context, relative user
zoom and optional compatible view-state/zoom-lock payload. Define page/text Study
anchors independently; legacy page-only notes stay page-only.

Resolve settings per field: explicit title override → library default → app
default. Absence means inherit. A reset removes an override; resume writes do not
materialize inherited settings. Restore after hydration/layout, suppress save
feedback during restoration, serialize writes and flush on settled navigation,
explicit settings, close and supported lifecycle transitions. Keep the existing
700 ms scroll/zoom debounce as an initial Tangerine policy, not a Panels finding.

**Gate:** migration/restart, inherited defaults, explicit false/zero, reset,
content revision mismatch, incompatible zoom payload, ordinary close and abrupt
termination recover the defined state without moving annotations.

### P5 — Preserve PDF and Study coordinates

Adapt `pdf_reader_screen.dart` and pdfrx to the shared locator/geometry contracts.
Retain native PDF text/search, selection, notes/bookmarks and authenticated loading.

Define and test the transform and inverse through page box/crop origin, rotation,
fit, user zoom and viewport offset. Keep search quads and Study regions in declared
page-local coordinates. Map each spread's source page independently. Optional
raster OCR has an explicit source coordinate system, analysis size/cache and
capability flag; its output never silently replaces native PDF text anchors.

PDFKit's private tiling and VisionKit's private selection geometry do not define
pdfrx behavior. Use the current backend's actual APIs and runtime fixtures when
implementing this package. Keep bounded visible rendering before prefetch.

**Gate:** mixed page sizes, nonzero crop origins, rotations 0/90/180/270, fit/zoom/
pan, RTL placement, spread/continuous changes and restart preserve selection,
search highlight and note position on the same canonical page.

### P6 — Layout, spreads, RTL and gestures

Use an explicit presentation map built from canonical source pages. Persist a
focused source page within a spread. Layout changes capture that page and a
page-local point, then map/clamp the anchor into the new geometry.

The default Panels-style spread policy is: first cover single; strictly landscape
pages single; square and portrait pages pair; wide breaks repair orphan halves;
the final unpaired page is single. Support explicit pairing/cover adjustment
without renumbering source pages. This revises the older plan's square-single
choice to use the recovered Panels rule.

Paginated outer cells occupy the reader viewport. Expose clear Fit Page, Fit
Width and Fill policies in Tangerine, with tested square/orientation handling.
Panels' differently named calculator branches are references, not assumptions
that all fit modes are equivalent. Continuous vertical layout uses cross-axis
width and intrinsic aspect ratios, cumulative offsets and bounded virtualization.

All navigation inputs use one controller: buttons, physical keyboard, edge taps,
swipes, thumbnails and scrubber. Horizontal RTL changes presentation/placement;
vertical reading remains top-to-bottom. Map selected positions back to canonical
source identities. Advance spreads by spread, avoiding overlapping page pairs.

Provide configurable edge actions. Top/center toggle chrome by default; use the
recovered 20% top and 33% side regions as the initial reference, adapting to
safe areas and accessible controls. Selection, Study interaction, zoom/pan and
active transitions have explicit gesture priority. Double tap defaults to
fit↔2.5× around the tapped content point, with a bounded 1–5 zoom range as an
initial policy; buttons/keyboard remain available during gesture suppression.

**Gate:** covers, odd counts, wide/square pages, pairing shifts, narrow windows,
side-by-side Study tools, all boundaries and all input paths visit every canonical
page without omissions, duplicates or annotation drift.

### P7 — Rendering jobs, prefetch and caches

Introduce a shared scheduler with visible render, analysis/text, adjacent-page,
thumbnail, geometry and background priorities. Keep separate ownership for page
and thumbnail jobs; coalesce compatible requests by resource/revision/page/target
size/processing context. Consumer cancellation releases interest; shared work
is cancelled when no owner needs it. A completed stale generation cannot paint
another page/title or overwrite newer state.

Track decoded bytes, retained buffers, framework cache interaction and in-flight
allocations. Establish measured per-platform byte/task budgets before enabling
speculation; record the selected values and large-fixture results. Request
viewport/zoom-appropriate resolutions, shed speculative work under pressure and
dispose on source replacement. Never use a future-map count as a memory budget.

Use access-aware eviction and versioned keys for regenerable disk thumbnails,
geometry and colors. Keep state/annotations outside eviction. Disk cleanup has
an explicit size target, grace and live-reference protections. Panels' 11→9 and
51→49 pre-insertion trimming, 90% disk target and 600-second grace are useful
reference policies; choose Tangerine budgets from its measured workload.

**Gate:** large CBZ/PDF/EPUB, huge images, rapid jumps, mode/direction changes,
corrupt pages, multiple windows, memory pressure and repeated open/dispose stay
within recorded limits and leave no stale jobs or authenticated temp files.

### P8 — Dynamic backgrounds

Implement Black, White, Single Derived Color and Immersive. Use a bounded,
versioned edge sampler with the recovered relationship
`t=max(1,sqrt(0.009*w*h)/4)`, selected horizontal/vertical opposite edges and
combined normalized strips for one color. Declare rounding, image coordinate
space, opaque alpha matte and failure fallback.

Preserve borders by default. Optional border removal is a separate tested
transformation included in render/sample cache keys. It is not intrinsic to
the ColorKit sampler. Include revision, rotation, relevant transformations,
sampling algorithm and matte in invalidation.

Compose immersive axial colors `[A,A,B,B]` outside content, crossfade complete
background layers and support interactive progress. Default normal duration is
300 ms, zero under reduced motion. This revises the prototype's 180 ms choice
to use the recovered Panels duration. Maintain Study-control contrast.

**Gate:** numerical color fixtures and rendered edges cover white borders,
transparency, narrow images, rotation, sampling resolution, rapid navigation,
processing changes and reduced motion without late color flashes.

### P9 — Fixed-layout EPUB and separate reflowable capability

Replace the single-image restriction with a supported-platform publication
renderer that preserves fixed-layout HTML/CSS/text/images/SVG and constrained
relative resources. Keep BookPageSource/resource identity independent of screen
pagination and viewport metrics.

Build a package resolver and a versioned, request-scoped metrics bridge. Preserve
declared body/viewport geometry, measure unscaled/scaled sizes, reject invalid or
unbounded dimensions, and handle stale load/resize responses. Define publication
script policy, resource readiness, timeouts and bounded retries. A fixed 200 ms
wait observed in Panels is not the readiness contract.

An image-only optimization requires proven equivalent composition. A failed
optimization falls back or reports a controlled error; it does not silently
drop text/overlays. Reflowable books retain separate text-range/spine locators,
typography and selection contracts. Existing sanitized textual display remains
explicitly limited until those gates pass.

**Gate:** mixed text/image, SVG, CSS backgrounds, relative styles/fonts,
body/viewport-only sizing, late assets, resize and failure fixtures retain source
identity, correct layout, navigation and defined Study anchors.

### P10 — Scoped catalog transport and cross-device state

Version the wire protocol separately from local database migrations. Define
capabilities for catalog fields, locators, overrides and supported renderers.
Add deterministic bounded list/search pages, authenticated artwork/page delivery,
and then revision-based deltas with explicit tombstone retention.

Add per-library browse/stream/mutation grants and apply them to every listing,
search result, artwork, media/page byte, snapshot, note and progress endpoint.
Mirror libraries remain excluded from rehosting. Filter derived payloads and
avoid exposing host-local paths or provider secrets.

Resolve match/override/membership conflicts separately from resume/completion.
Explicit resets and override removals need durable revisioned events; a
furthest-progress rule cannot erase newer intentional reset decisions. Preserve
legacy clients through adapters or actionable incompatibility responses.

**Gate:** allowed/denied libraries, revoked pairing, secondary roots, stale edits,
deleted overrides, interrupted transfer, old clients, backup restore and browser/
native clients agree on scope and identity under bounded data volumes.

### P11 — Complete the media experiences and release

Finish the MyVLC feature matrix: editable queues/named playlists, shortcuts,
preferences/profiles, multi-window/mini-player, effects/subtitles, recording,
conversion, stream output, casting/capture, web remote and supported customization.
Each advertised platform needs real engine/workflow evidence and distribution
packaging; interim backends remain explicitly identified.

This package closes the feature matrix; it does not defer MyVLC preservation
until the end. Carry player parity and preference migration as a continuous
track from P0, checking each feature as shared UI, schema and playback boundaries
change. Establish the core player/Study regression gate before catalog expansion.

Deliver Music Videos/Home Videos/Photos, Audiobooks/local Podcasts and Books on
the same catalog/resource boundaries. Add albums/timelines/slideshow, chapters,
listening locators/speed/sleep timer and type-specific search. Podcast feeds,
internet hosting, transcoding/DVR and external remote-server integrations require
their own product scope; none is inferred from merely being present in Plex.

Run the cross-format release journey: import, rescan/relink, match/correct,
play/read, study, close/restart, backup/restore and companion sync. Include a large
catalog and long books, compact/large-text layouts, keyboard/accessibility and
reduced motion. Update release capability declarations from actual results.

## Dependencies and implementation slices

| Slice | Required packages | Deliverable |
| --- | --- | --- |
| Preservation and transport correctness | P0 | Stable upgrade baseline and safe existing hosting scope |
| Library foundation | P1–P2 | Explicit source ownership and catalog/media/state separation |
| First catalog experience | P3 + applicable P10 | Offline/manual movie catalog, correction and paged delivery |
| PDF/Study foundation | P4–P5 | Shared locators/transforms without PDF or annotation regression |
| Comics & Manga | P4–P7 | Canonical CBZ/spread/continuous/RTL reader with durable state and bounded work |
| Backgrounds | P7–P8 | Versioned single/immersive colors and verified invalidation |
| Fixed-layout EPUB | P4–P7 + P9 | Mixed-content publication rendering with defined anchors |
| Cross-device release | P10–P11 | Scoped compatible transport, media experiences and end-to-end acceptance |

The MyVLC A0/A1 preservation requirements remain release gates before claiming
the broader merge complete. Schema/transport/backup work accompanies every slice;
P10 completes the protocol rather than deferring all compatibility to the end.
Within reader work, P4→P5→P6→P7 precedes background/EPUB expansion.

The UI track starts with P0's preserved workflows and representative fixtures.
Deliver the shell and Home/library/detail components alongside P1–P3, then adapt
the player/reader/Study surfaces alongside P4–P9. P10 supplies complete scoped
browser delivery. P11 closes platform packaging and whole-product acceptance.

## First reviewable implementation slices

1. Record preservation fixtures and fix secondary-source serving plus snapshot
   scoping. Add meaningful regressions around the demonstrated gaps.
2. Establish the cinematic shell, shared media-card/row/detail components and
   Home backed by current real data. Preserve current player/Study routes.
3. Add explicit source ownership and scan-generation migration; verify missing
   roots, cancellation, moves and duplicates without changing item IDs.
4. Add catalog/match/override identity and migrate generic metadata. Connect the
   offline candidate preview/select/correct/clear workflow to the detail screen.
5. Finish paged browsing and type-specific movie/TV details, while introducing
   shared locators and PDF/Study transforms for the reader track.

Each slice ships its database/backup/transport compatibility work together with
the corresponding workflow. Platform-specific player work may proceed alongside
the shared contracts, but no platform is labeled complete from another's result.

## Decisions and unknowns that remain explicit

| Topic | Initial Tangerine policy / implementation step |
| --- | --- |
| Matching rank | Manual/offline selection first; define and calibrate an explainable policy before automatic matching. Plex's modern remote rank was not recovered. |
| Edition progress | Exact resume belongs to a representation/asset; maintain title completion separately. Cross-cut resume needs an explicit mapping. |
| Reader defaults | Proposed defaults are cover single, strictly landscape single, square pairing, configurable physical edge actions, 300 ms background fade and sparse title→library→app settings. User changes can revise these policies. |
| PDF text/OCR | Preserve the existing native PDF text path; optional OCR has separate capability/coordinates. Private PDFKit/VisionKit behavior is not a pdfrx contract. |
| Memory and prefetch | Measure workload before fixing platform byte/concurrency limits; visible work precedes speculation. Retain recorded limits and acceptance results. |
| EPUB backend | Select a supported-platform HTML/CSS/resource host through a representative mixed-content spike, then validate metrics and Study anchors. No package has been selected by decompilation. |
| Provider integration | Check the selected provider's actual current API/access/caching contract during implementation; retain a fully usable offline library. |
| Platform release | macOS has existing native playback evidence; each other native platform needs its own engine/packaging/workflow gates. The browser has a separate playback capability boundary. |

Further REA work should answer a concrete dependency that would change a
Tangerine decision. Named unknowns are documented rather than filled with guessed
Plex/Netflix behavior. New product improvements remain independently selectable.

Implement in reviewable steps: first the migration/contract, then one complete
working path, then its meaningful regression fixtures and integration gate.
Record actual evidence in the implementation ledger. Do not run unrelated build
matrices for a documentation-only change, and do not count unexecuted gates as
passes.
