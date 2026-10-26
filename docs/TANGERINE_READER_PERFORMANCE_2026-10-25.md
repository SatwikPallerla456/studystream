# Books, comics and reader performance — 25 October 2026

## Pre-change screen/source findings

Source-only review. The user cancelled screenshot review; tests, analyzers,
builds and runtime acceptance remain a separate phase after master implementation.
Graphify scoped PublicationView, ArchiveBookSource, PublicationServer,
ReaderJobScheduler, ReaderLocator and the book/PDF reader screens before edits.

1. Windows/Linux are explicitly rejected by PublicationView. A title can be
   discovered/opened from its category but cannot complete its EPUB reading path.
2. Contents shows generated `Chapter N` / one row per spine resource, with no
   EPUB 3 navigation or NCX hierarchy/fragment destinations. Package links cannot
   navigate between resources through the reader.
3. EPUB has no search capability or search screen. Selection-only text offsets
   are discarded when selection is cleared; scrolling only reports x/y ratios.
4. Typography reloads the webview and restores a scroll percentage. That is not
   the same text position after reflow. There is no capture-before-settings API.
5. A 12-second timeout is text-only. `_attempts` does not enforce a retry budget,
   and there is no Retry/another-section action or generation-scoped retry owner.
6. DOM dimensions are validated but never delivered to outer layout. Fixed EPUB
   geometry may remain an 800×1100 guess despite author CSS/viewport measurements.
7. Book startup reads every page's geometry before publishing the source, making
   opening latency proportional to all archive entries. Geometry is outside the
   priority scheduler and cannot yield to the visible page.
8. Contents has no page-thumbnail navigation. Visible image jobs use the
   scheduler, but reusable page/thumbnail caches, publication render ownership and
   geometry jobs are not integrated. Speculative decoded prefetch is disabled.
9. Raster OCR is implicitly macOS-only; other platforms have no explicit support
   explanation. Native EPUB/PDF text and raster OCR must remain separate.

## Design and implementation contract

Keep canonical resource/page identity independent of TOC depth, spread position
and RTL thumbnail presentation. Load EPUB 3 nav / EPUB 2 NCX titles and local
fragment destinations; preserve source order and old path locators. Search the
same sanitized DOM text model used by selection and resume, with bounded results,
cancellation and chapter/page destinations. Do not replace publication rendering
with first-image extraction: recovered Panels direct-image and HTML modes are
materially different.

Use embedded native publication surfaces on all five native targets with scoped
loopback resources, navigation policy and a request/revision/page/sequence bridge.
A viewport text anchor is independent from active selection; capture before
reflow and restore text before reporting progress. Author geometry updates outer
fixed-page layout while preserving canonical position. Reflowable sections keep
bounded viewport surfaces and internal text scrolling.

Prepare the visible geometry neighborhood first; use placeholders elsewhere and
load additional geometry on demand through cancellable priority jobs. Thumbnails
are requested only for visible navigation cells, with separate cache keys and
render leases. Keep visible surfaces bounded, clean up native/headless renderers
on cancellation/timeouts, retain caches by bytes/recency, protect active document
files, and clear regenerable memory on pressure. Budgets are conservative source
limits, not measured RSS guarantees. Speculative decoded look-ahead stays off.

Retries are actionable and finite for the mounted page/load generation, with
fresh request identities, old-message rejection, cancellation and an explicit
terminal action to choose a different section/reopen. Private framework behavior
or unrecovered retry counts are not invented.

Reference: PANELS_DEEP_DECOMPILATION.md and its linked EPUB, geometry and
cache/background reports. Recovered placeholder geometry, measured layout
invalidation, independent retry layers, page/thumbnail task maps, cache recency
and active-document protection inform these contracts. No Panels binary/runtime
was changed or executed.

OCR decision: retain the implemented macOS Vision path. iOS, Android, Windows,
Linux and browser raster OCR are not advertised in this pass; show an explicit
capability explanation. Their native EPUB/PDF text selection/search remains
separate and usable. Adding another OCR engine is a separate declared binding,
resource/language/privacy decision, not a guessed VisionKit port.

Additional source finding before toolbar adjustment: AppTopBar places every action
in one unwrapped row. Adding navigation/search previews to the existing book/PDF
actions would crowd the title and overflow narrow displays. Keep core reader
actions visible and put secondary actions in a labelled menu on compact screens;
retain accessible names and existing reading/study controls.

## Implemented source and visible workflow

| Request | Source implementation |
| --- | --- |
| Windows/Linux EPUB | PublicationView uses flutter_inappwebview_forge 2.1.77 across native platforms: Windows WebView2, Linux WPE WebKit, Android WebView and Apple WKWebView. Generated native plugin registration and Apple Swift package references are resolved. Android minimum SDK is explicitly at least 24. Windows checks the installed WebView2 runtime and explains how to recover when absent. |
| Real contents | ArchiveBookSource parses EPUB 3 `nav[epub:type=toc]`/`role=doc-toc`, with EPUB 2 NCX fallback. Contents retains hierarchy, chapter names, canonical resources and fragments. Readable auxiliary TOC resources append after the original linear spine, preserving existing path/page identities. Package links use the same scoped canonical destination path. Invalid individual destinations are omitted; a bad TOC does not prevent reading. |
| Text search | Search book text opens a query/results sheet. Each cancellable analysis job scans at most 24 sections or returns 60 matches, with page/offset continuation inside dense sections. The UI retains at most 480 results before requesting a narrower query. Results jump to and select the matched text; unreadable sections are counted explicitly. Query length is capped at 200. Text extraction uses the server's sanitizer in a worker isolate, with UTF-16 offsets and an 8 MiB retained text cache. |
| Stable resume | Ordinary scroll captures a visible caret/text node, UTF-16 offset, short quote and relative viewport line independently of selection. Capture is awaited before save, settings, navigation and Study. Reflow restores scoped text/quote first, with unique-quote recovery and old fractional-position fallback. Selection clearing no longer clears the viewport text anchor. ReaderLocator transports the bounded quote/bias while continuing to omit device-local raw viewport state. |
| Publication retries | A mounted load generation permits three explicit attempts with fresh request identities and readiness ownership. Errors expose Retry section and Choose another section; exhausted attempts explain reopening/checking the renderer. Stale request/revision/page/sequence packets are ignored. Asset readiness is bounded at 8 seconds and page readiness at 15 seconds. Failed platform surfaces are removed before retry. |
| Measured layout | Validated native metrics update CanonicalPage geometry and invalidate presentation/continuous layout. Continuous layout restores the current canonical page and fraction after offset changes. Reflowable chapters report viewport geometry to the surrounding reader and keep long text scrolling inside that viewport. Fixed geometry changes are forwarded into the live renderer without reopening it. |
| Incremental geometry | Startup retains placeholder 100x200 geometries and prepares only the current section and up to two neighbors. Further visible geometry is requested through cancellable scheduler leases, rather than scanning the whole archive. Visible decoded source dimensions also update geometry. A malformed neighbor uses fallback geometry without blocking the book. |
| Thumbnails/cache | Page thumbnails opens a lazy navigation grid for comics, EPUB sections and PDFs, with canonical numbering and RTL presentation. EPUB previews render actual HTML/CSS through a bounded headless native view; they are never first-image substitutes. The headless lifetime, readiness, cancellation, screenshot and disposal stay inside its scheduler reservation. Flowing chapters are labelled section previews. All image buffers/codecs and thumbnail surfaces have explicit release paths. |
| OCR decision | macOS retains on-device Apple Vision. Other native hosts and the browser do not advertise an implemented raster OCR engine. OCR availability controls explain this; EPUB/PDF native text capabilities are independent. No image upload or cloud OCR fallback was added. |

The book toolbar keeps Contents and contextual Notes visible on compact screens;
Reader tools exposes previews, search, preferences and OCR availability. PDF
previews are visible beside its document menu; existing compact search/Study
controls remain in the bottom bar. TOC, search and page navigation have close
controls and concrete canonical jump destinations.

## Resource ownership and provisional limits

The existing scheduler retains two concurrent jobs and 128 MiB of conservative
in-flight reservations. New reservations distinguish publication readiness
(32 MiB), search (32 MiB), geometry (16 MiB) and thumbnail work (48 MiB); existing
visible raster work retains its 96 MiB reservation. Visible decoded pages retain
at most 4 MiPixels each. Reusable decoded pages use a 48 MiB/eight-entry LRU with
owned image clones; encoded thumbnail memory uses a separate 12 MiB LRU. Generic
LRUs also cap entry count. Visible widgets bypass Flutter's global image cache.
Memory pressure drops regenerable page/text/thumbnail data and speculative jobs.
Speculative decoded prefetch remains disabled pending measured acceptance.

Thumbnail disk files are revision/pipeline/document keyed, atomically published,
access-recency touched and pruned oldest first above 64 MiB toward 90 percent.
Current document owners and files accessed within ten minutes are protected, so
this is best-effort disk cleanup rather than an absolute ceiling. macOS uses
allocated-byte metadata with a logical-byte fallback; other hosts use logical
bytes. Disk failures do not prevent reading. Native/decode work keeps its
reservation until unwinding; book cleanup awaits scheduler settlement before
closing archives or deleting authenticated temporary downloads.

Shared publication sanitization removes package scripts, active embeds, handlers
and external navigation/resources. Only the nonce-scoped bridge executes under
CSP. A bounded loopback request queue avoids dropping normal parallel CSS/font/
image loads while limiting archive reads to four concurrent requests. HTML/SVG
sections are limited to 2 MiB, other served resources to 32 MiB, text to eight
million UTF-16 units/250,000 nodes, and linear reading order to 10,000 sections.
These are declared implementation limits, not recovered private Panels constants
or measured peak RSS guarantees.

## Platform setup and deferred acceptance

Windows requires the Microsoft Edge WebView2 Runtime. Linux requires WPE WebKit
(pkg-config `wpe-webkit-2.0`, with the dependency's supported legacy fallbacks),
`wpe-1.0`, `epoxy`, GTK 3, `libsecret-1`, `wayland-server`, and either the modern
`wpe-platform-2.0` plus `wpe-platform-headless-2.0` backend or legacy
`wpebackend-fdo-1.0`. The pinned renderer's CMake owns these checks and native
linkage. Its WPE runtime/helper/transitive libraries must be provisioned for a
Linux release; this pass does not certify relocatable installers. See the pinned
[renderer requirements](https://pub.dev/packages/flutter_inappwebview_forge) and
its Linux WPE_BACKEND.md in the installed dependency for distro-specific setup.
Apple targets already have iOS 15/macOS 12 minimums and generated Swift package
integration. Browser EPUB/CBZ reading remains the separate W02 backlog item.

Dependency resolution (`flutter pub get`, macOS/iOS `pod install`) and Dart
formatting completed. Apple renderer packages appear in generated Swift package
manifests rather than the CocoaPods list. macOS CocoaPods repeated the existing
custom-base-configuration and generated DART_DEFINES warnings recorded during the
native-player pass. No app build, analyzer, automated test, screenshot or runtime
acceptance journey was executed. Native creation/disposal, search/anchor accuracy
on diverse EPUB DOMs, fonts/layout/RTL, huge/malformed archives, PDF render
cancellation, cache pressure and release runtime provisioning still require the
separate acceptance phase. Source coverage must not be reported as visual or
measured target validation.
