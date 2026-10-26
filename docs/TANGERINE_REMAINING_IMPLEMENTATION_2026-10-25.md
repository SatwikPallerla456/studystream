# Remaining Tangerine implementation — 25 October 2026

Source audit against TANGERINE_MASTER_IMPLEMENTATION_PLAN.md (P0–P11), the update
plan, current Graphify relationships, retained Plex/Panels findings and current
working source. No tests, analyzers, builds, screenshots or runtime journeys were
run for this audit. The user cancelled further screenshot review.

The old MYVLC_FEATURE_MATRIX.md and TANGERINE_IMPLEMENTATION.md remain useful
historical evidence but contain stale “missing” entries. They cannot be used as
the current backlog without reconciling newer code. This document records known
implementation gaps and closure work; it is not a certificate that no undiscovered
bugs remain. Source implementation, incomplete integration and acceptance are
separate states. No defensible completion percentage is available.

## Already source-implemented: do not rebuild as missing

- Named media categories, library/source creation/relinking, scan generations,
  cancellation/partial/offline preservation and file identity reconciliation.
- Catalog work/edition/representation/part/extra relationships, explicit matches,
  provider snapshots, field overrides/removals and scoped backup/transport.
- Online matching/artwork through TMDB, TVmaze, Open Library and MusicBrainz/CAA,
  alongside offline/manual identification. These are not automatic match choices.
- TV seasons/episodes/specials, music artists/albums/discs/tracks, books/comics
  authors/series/numbering, plus the latest audiobook/podcast/photo/home-video/
  music-video/document category source implementations.
- Automatic app-open organization/analysis queue, pause/retry/offline waits,
  revision/lease checks, local tag extraction and organization review.
- Manga RTL input changes, reader locators/settings, PDF native text/search,
  page/passage Study anchors, backgrounds and macOS optional OCR.
- Editable queues/named playlists, shuffle/repeat/reordering, M3U/PLS import and
  M3U and PLS export, including bounded migrated playlist artwork. These exist in player_library_repository.dart/playlists_screen.dart.
- macOS mini-player, fullscreen, snapshots, recording/conversion/HTTP output and
  cast discovery/selection. NativeOutputTools, MyVLCDesktop and MyVLCBridge wire
  these paths; device/account/runtime acceptance is still outstanding.
- All nineteen local action bindings, mouse/modifier controls, macOS/Windows global
  shortcut bridges, supported original settings/profile import and Tangerine
  profile save/apply/delete. Native platform/window details are recorded in
  TANGERINE_NATIVE_PLAYER_2026-10-25.md; target acceptance remains deferred.
- Per-library browse/stream/mutation grants, catalog/bootstrap/delta paging,
  identifier tombstones, authenticated artwork and paged contextual Study.
- Animated splash and opening mode chooser.

## Confirmed implementation or integration work

IDs are retained from the original audit. Rows marked source-implemented now
track deferred acceptance or explicit platform boundaries, not missing code.
Other rows still describe implementation gaps. Related behaviors stay grouped.

| ID | Area | Remaining work and current source evidence |
| --- | --- | --- |
| N01 | Native engine | **Source-implemented 25 Oct:** local VideoLAN plugin for Android/iOS/Windows/Linux, default native boundary and capability declarations. Target builds/runtime/resource acceptance and release provisioning remain separate. See TANGERINE_NATIVE_PLAYER_2026-10-25.md. |
| N02 | Desktop windows | **Source-implemented 25 Oct:** independent Flutter engines/player sessions, temporary separate queues, shared playlist/progress DB, child registration/scopes and close-before-destroy progress flush. macOS mini-player retained. Multi-window target acceptance remains deferred. |
| N03 | Capture | **Source-implemented 26 Oct (macOS):** AVFoundation camera/mic selection, permission-gated preview, save/finalize recording, close/cancel lifecycle; screen capture through libVLC with screen permission and output controls. Other native targets explicitly report missing capture adapters. Hardware/permission acceptance remains separate. |
| N04 | Optical media | **Source-implemented 26 Oct (macOS):** DVD menus/DVD/Blu-ray/CD/VCD folder/image/device opening, title/chapter selection and libVLC menu navigation. Compatible modules/drives/discs and sandbox access still need acceptance. |
| N05 | Network sources | **Source-implemented 26 Oct:** Open/save/edit/remove network streams and previewed idempotent MyVLC remote-entry import. Signed/query URLs use OS credential storage; HTTP(S) works across native players, additional RTSP/RTP/UDP/RTMP input is currently macOS-only. No implicit source/server grants. |
| N06 | Subtitle service | **Source-implemented 26 Oct:** secure OpenSubtitles key/token configuration, explicit paged language search, candidate selection, quota confirmation, bounded validated SRT download, current-title assignment and reopen. Live API/account/quota acceptance is pending. |
| N07 | Accounts | **Source-implemented 26 Oct (macOS):** opt-in original libVLC Last.fm audioscrobbler setup and native Keychain secret ownership, disconnect/clear and new-player application. Service/account submission and module availability still require acceptance; modern cross-platform service adapter is not claimed. |
| N08 | Proxy | **Source-implemented 26 Oct (macOS):** validated HTTP proxy endpoint, separate username/password, native Keychain secret storage and new libVLC-player activation. No global proxying of metadata/subtitle/pairing clients. Authenticated proxy acceptance remains pending. |
| N09 | Extensions/customization | **Source-implemented 26 Oct:** imported-disabled MyVLC JavaScript management/source review, opt-in playback-start runs in bounded macOS Web Worker sandbox; original JSON color skin mapping on player surfaces; persisted reorder/hide/add/reset control groups shared across audio/video/input playback. Transport remains mandatory. Lua/.vlt stay unsupported; JS execution on other platforms is explicitly unavailable. |
| N10 | Controls | **Source-implemented 25 Oct:** nineteen original action IDs, modifier seeks, mouse bindings; native global bridges on macOS/Windows. Linux global shortcut portals are not advertised. Actions follow declared backend capabilities; unavailable outputs are not claimed as parity. |
| N11 | Preferences/migration | **Source-implemented for documented supported fields 25 Oct:** window/controls/history/resume/volume/queue policies, embedded or independent startup, tray/start-hidden, track notifications, finish actions, snapshot defaults, folder grouping, safe macOS DSP startup settings and staged original profiles/EQ/picture/settings import. Original volume boost and unexposed advanced catalog policies are not claimed as migrated working controls; custom skins/control strip/add-ons remain N09 and service/update workflows have separate entries. See the native-player capability report. |
| N12 | Advanced player tools | **Source-implemented for declared capabilities 25 Oct:** live framing/deinterlace/picture/timing, output selection or iOS route picker, readable metadata/statistics and Windows/Linux snapshots. Android physical output selection remains through system media controls; unsupported mobile filters/frame/snapshot and non-macOS output jobs/casting are not advertised. Target acceptance remains deferred. |
| N13 | Playlist format parity | **Source-implemented 25 Oct:** PLS export plus bounded original artwork migration/preview and idempotent artwork upgrades. M3U export and both import formats retained. Later round-trip/migration acceptance is separate. |
| R01 | Publication platforms | **Source-implemented 25 Oct:** native EPUB through embedded WebView2 on Windows and WPE WebKit on Linux; Apple/Android retained on the shared bridge. Runtime prerequisites and target acceptance are explicit in TANGERINE_READER_PERFORMANCE_2026-10-25.md. Browser reading remains W02. |
| R02 | EPUB contents | **Source-implemented 25 Oct:** EPUB 3 nav / EPUB 2 NCX titles, hierarchy and fragment destinations, plus scoped internal resource links and preserved canonical spine identity. See the reader performance report. |
| R03 | EPUB search | **Source-implemented 25 Oct:** bounded EPUB text search, cancellation, section/offset continuation, skipped-section feedback and canonical passage jumps. PDF native text search retained. Diverse-DOM anchor acceptance remains deferred. |
| R04 | Reflowable resume | **Source-implemented 25 Oct:** visible text offset/quote/viewport-line capture during ordinary scrolling and before reflow/save, text-first restoration and portable locator fields. Selection and viewport anchors are separate. Later typography/DOM/resize acceptance remains required. |
| R05 | Publication retry/lifecycle | **Source-implemented 25 Oct:** three explicit attempts per mounted publication load generation, fresh scope identities, readiness cancellation/timeouts and Retry/Choose another section/terminal guidance. Native lifetime acceptance is deferred. |
| R06 | Geometry/startup | **Source-implemented 25 Oct:** measured publication geometry updates outer canonical layout; continuous offsets preserve page/fraction and flowing sections keep viewport-sized native surfaces. Geometry/rotation/font acceptance remains deferred. |
| R07 | Publication geometry | **Source-implemented 25 Oct:** only the current geometry neighborhood blocks readiness; other pages use placeholders and cancellable on-demand jobs. Page-thumbnail navigation now covers comic pages, HTML EPUB section previews and PDFs. |
| R08 | Reader scheduler/cache integration | **Source-implemented 25 Oct:** separate geometry, publication, search, page and thumbnail leases; byte/count LRUs, revision/pipeline keys, active-document/recency disk cleanup, memory-pressure eviction and settlement-before-archive/temp cleanup. Limits are provisional, not measured RSS claims. Speculative decoded prefetch intentionally remains disabled until acceptance. |
| R09 | OCR platform coverage | **Capability decision implemented 25 Oct:** optional raster OCR is macOS Vision only. iOS/Android/Windows/Linux/browser engines are not advertised; native reader OCR availability UI explains this. Native EPUB/PDF text capabilities remain independent. See the platform table in the reader performance report. |
| U01 | Global Search | **Source-implemented 25 Oct:** catalog-title/creator/tag FTS global Search; SQL result-kind/category/named-library/favorite/tag restrictions, recent/title ordering and 48-result keyset pages. Notes/bookmarks retain time/page and compatible reader Study anchors. Large/changing-catalog acceptance is deferred. See TANGERINE_BROWSING_ORGANIZATION_2026-10-25.md. |
| U02 | Category browsing controls | **Source-implemented 25 Oct:** common original/title/date/activity sort, grid/list and favorite/tag controls across specialized category groups/titles and generic browsers. SQL ordering precedes continuation; hierarchy drills retain the selected scope and natural episode/disc/track/volume order remains the default. Layout/order acceptance is deferred. |
| U03 | Collections/albums | **Source-implemented 25 Oct:** dedicated collection/ordered-album detail with bounded members, explicit editing, available-member ordered/shuffled playback, reading resume and album-only photo viewing. Home collection shelf and cross-library index are connected; named-library ownership and membership order remain authoritative. Acceptance is deferred. |
| U04 | Tags/favorites | **Source-implemented 25 Oct:** Details tag editing/display, preserved Favorite/tags during atomic updates, existing reindex/backup/transport integration, and useful SQL favorite/tag filters plus paged usage facets in global/generic/specialized browsing. Cross-device field conflict policy remains separate S02. |
| U05 | Home | **Source-implemented 25 Oct:** independently bounded Continue Watching, Reading and Listening, first-section text-locator/open-activity reading resume, separate Recently added and Home collections/albums with detail/index/creation destinations. No recommendation-ranking algorithm is invented. Resume/empty-layout acceptance is deferred. |
| U06 | Photos | **Source-implemented 25 Oct:** shared photo route with zoom/pan/double tap/buttons/keyboard/reset, pause-on-interaction and transform reset on image changes; collection photos use saved membership order and stop at album boundaries. Existing category/favorite/tag scopes are retained. Gesture/platform acceptance remains deferred. |
| U07 | Embedded audio artwork | **Source-implemented for declared containers 25 Oct:** offline worker-isolate ID3v2.3/v2.4 APIC, FLAC PICTURE, MP4/M4A/M4B covr and Vorbis/Opus comment cover extraction; bounded decode/cache, timestamp/size/revision invalidation, atomic publication and selected/provider artwork precedence. Unsupported container/ID3 transformations remain explicit fallback capabilities, not claimed parity. See the artwork table in the browsing report. |
| W01 | Browser categories | Replace the generic Videos/Music/Documents selector with the supported catalog-kind hierarchies, details and source/version relationships. web_player.dart still renders a generic bounded card grid; it does not mirror native TV seasons, artists/albums, books/comics or collection browsing. Browser codecs remain a separate capability boundary. |
| W02 | Browser reading | Complete advertised browser EPUB/CBZ reading and durable page/passage handling. openItem treats EPUB/CBZ as unsupported; PDF uses an iframe without native-reader locator restoration. Paged notes alone are not reader parity. A deliberately native-only format must be declared explicitly instead of claimed complete in the browser. |
| W03 | Web remote parity | Complete original supported host-control behavior beyond the current active-player transport subset. RemotePlaybackController accepts play/pause/seek/rate/volume/mute/next/previous; the browser exposes fewer controls and requires an already active host player. Preserve per-library mutation authorization. |
| S01 | Progress conflict/reset semantics | Add revisioned intentional reset/rewind events and reconcile completion intent independently of furthest position. SyncConflictResolver currently gives any non-null manualCompletion priority over a row without one, then otherwise prefers completed/furthest progress. A newer ordinary/reset state can therefore lose to older intent/progress. Do not merely change timestamp comparisons without defining separate events. |
| S02 | Settings conflicts | Complete field-level reader/library preference edit and reset/removal conflict semantics. ReaderPreferenceStore removes keys from one media-record payload; generic metadata merging chooses a whole newest record. Catalog field overrides have their own records, but ordinary reader preferences can still overwrite unrelated concurrent fields. |
| S03 | Remaining unbounded paths | Remove whole-catalog materialization from interactive operations that bypass the new pages: playlist import currently selects every item to build its path map; the old Study/global search watchers and remaining collection/member lookup paths need a final caller audit. The main item Study sheet and v2 Study endpoint already use pages and must not be called absent. |
| D01 | Distribution | Finish reproducible runtime sourcing, relocatability, release signing/notarization/installers and platform packaging declarations. bundle-vlc-runtime.sh already copies/signs dylibs/plugins; it is not absent. AppInfo.xcconfig still builds against a selected /Applications/VLC.app installation. A copied debug runtime is not a completed distributable release. |

## Required source-audit closure, not invented missing features

The following still need explicit reconciliation before declaring all implementation
finished. Existing source is substantial; these are not statements that every path
listed is broken or absent.

1. Reconcile every original MyVLC feature/action/preference and its persistence
   against merged routes/native calls. Replace stale matrix statuses with current
   source evidence and capability boundaries. Open N01–N13 policies and their declared platform boundaries are not a license
   to drop other implemented original features.
2. Reconcile every P0–P11 requirement with its current migration, UI, backend,
   backup and transport path. Keep exact file/representation identity and user
   state separate; do not count a schema or control alone as a complete journey.
3. Close source-level renderer/crop/rotation/viewport, cancellation/disposal and
   authenticated temporary-file ownership edge cases. Coordinate correctness and
   resource ceilings then require measurement/acceptance, not further guessed code.
4. Audit old-client adapters, tombstone expiry/bootstrap, interrupted sync and
   permission changes across all endpoints. Versioned transport/grants/deltas
   already exist. Unknown compatibility issues must stay unknown until inspected
   or exercised; do not list all sync as “not implemented.”
5. Finish format/platform capability declarations for technical analysis, chapter
   extraction, selection/OCR and document readers. Generic DOC/PPT external-app
   behavior is not a complete native office renderer.
6. Reconcile UI return focus/scroll restoration, keyboard/touch behavior, large
   text, compact layouts and category-specific tools against current component
   source. The cancelled screenshot review is not an implementation feature left
   to build, nor a release pass.
7. Audit the latest processing service against the completed source/scan/catalog
   contracts, especially explicit retry versus probe-cache reuse, source relinking,
   changing library kinds, stale jobs and closed/reopened resources. Queue source
   exists; no restart/offline/runtime success is inferred from compilation.

## Separate testing and release-acceptance phase

Start only after implementation is complete, as the user requires:

- Migrations/import idempotency, identities, source scans/failures/cancellation,
  relinks/moves/duplicates, complete matching and override/removal behavior.
- Real processing jobs, pause/resume, restart recovery, unavailable sources,
  retries, revision races, chapter seeking and durable discovered facts.
- PDF crops/rotation/text/Study; manga all RTL inputs/spreads; EPUB mixed content,
  real fonts/assets, long chapters, typography/resume and corrupted publications.
- Large catalog/book/image workloads; measured memory, in-flight work, framework
  caches, disk ceilings and resource disposal. Only then choose final per-platform
  budgets and whether to enable speculative prefetch.
- Queues/playlists, effects/output devices, conversion/recording/streaming,
  receivers, capture permissions/hardware, subtitle accounts and service flows.
- Browser/native compatibility, grants/revocation, resets/conflicts/deletions,
  interrupted transfer, old clients and backup/restore.
- Supported platform builds, actual native playback/reading, accessibility,
  compact/large-text/reduced-motion behavior and signed packaged releases.

Historical passes remain historical. The current feature implementation does not
have a release-wide acceptance pass.

## Explicit separate scopes

Do not silently inflate this master plan into all of Plex/Panels: podcast feed
subscriptions/download management; internet hosting/TLS/cloud/account sync; DVR;
server-side adaptive transcoding; external Plex/Jellyfin servers; proprietary
recommendation ranking; and automatic comic-panel detection require separate
scope. Original MyVLC conversion/recording/cast/stream-output parity is already in
scope and is not the same as adding a Plex transcoding server.
