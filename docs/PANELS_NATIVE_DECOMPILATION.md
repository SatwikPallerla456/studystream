# Panels native decompilation findings

19 October 2026 · Panels 3.13.8 (974), `es.produkt.app.panels`.

**Follow-up:** [the deep decompilation report](PANELS_DEEP_DECOMPILATION.md)
substantially narrows this pass's unknowns and corrects geometry-tag and tap-action
interpretations. Its companion reports cover geometry/zoom, backgrounds/caches
and EPUB. The coverage table below records the earlier pass, not current total
recovery; consult the deep report for the latest seven-priority status.

REA with Ghidra now produces native pseudocode for the installed application.
This follow-up goes beyond the [first investigation](PANELS_INVESTIGATION.md):
it establishes reader code paths, edge-color sampling, tap geometry, continuous
page sizing, EPUB/native communication, and the reading-session persistence path.
Recovery is partial. The unresolved parts of each requested feature are listed
explicitly below; this is not recovered original Swift source.

No StudyStream application code, Panels executable, signature, or user library
was modified during this pass. The Study integration recommendations at the end
are an independent design proposal, not behavior attributed to Panels.

## Evidence and reproducibility

The main executable is `/Applications/Panels.app/Contents/MacOS/Panels`, SHA-256
`c27578f21eb30a921491c03c98a644696c5efc91a24e2448419da67e66ef16d7`.
The analyzed arm64 slice has SHA-256
`9a75cdc1b6196a9d5d55c5f16c55c14a024dfbcec4950cfc854725d5a351d7dc`.
This is the same slice identity used by the earlier investigation.

All new files are retained in
[`../.verification/panels-native-20261019/`](../.verification/panels-native-20261019/).
The [evidence index](../.verification/panels-native-20261019/evidence-index.json)
maps each REA operation and procedure selector to its full Evidence ID, profile
digest, limitations, and complete response. References such as **E003** below
mean `evidence/targeted-003-procedure_pseudo_code.json`; assembly records are
identified separately. Verbatim C is in `pseudocode/targeted-003.c`, etc.
`annotated/` contains derived copies with Mach-O imports and Objective-C selector
names substituted for unnamed stub calls. These annotations are ordinary analyst
inspection, not additional REA Evidence. Raw REA C remains unchanged.

The executable is heavily stripped. Default whole-program analysis and a profile
disabling only switch discovery exceeded their 20-minute startup deadlines.
The successful profile used 329 explicit function seeds and disabled selected
expensive analyzers, including global reference discovery. Its digest is
`1c8e42c32baa9cff1715e42a9a8f3bec6cdcdb6f948c82844b615d1e31dcd8b8`.
The seed file SHA-256 is
`1c192c0f32efe7617ff4f3b5c68eb372346b2611df7e978917606366057c4d4b`.
The profile and disabled-analyzer list are embedded in each successful record.
Seeds came from compiled callback metadata, class code-pointer candidates, and
direct references; they are analyst assertions, not discovered source names.
Successful analysis completed under that profile before REA served these results.
There is no claim of a complete application call graph or exhaustive string/xref
inventory. Some selectors resolve to containing procedures or thunks; use the
returned body and address, not the requested selector alone.

Ghidra sometimes loses Swift error registers, asynchronous arguments, floating
aggregate returns, and small-string representations. ARM64 instructions and local
Mach-O import tables were used to check numeric formulas and external calls.
`llvm-*.asm`, `reader-objc-*.json`, and pointer/string candidate files are ordinary
offline inspection, separately retained from canonical REA records. A string or
class declaration by itself does not establish that a path executes.

## Coverage of the seven priorities

| Priority | Established in this pass | Still unresolved |
| --- | --- | --- |
| 1. PDF and Study | PDFKit view setup, separate image mode, OS-dependent default, page-change observer/navigation, rotation-bounds helper | PDFKit internal tiling, exact zoom lifecycle, selection/search-to-page coordinate pipeline |
| 2. Layout | Viewport-sized paginated cells, continuous aspect-ratio sizing, spread construction and canonical-page lookup | Full fit-page/fit-width policy, real-geometry landscape/cover exceptions, exact position transfer between modes |
| 3. RTL and gestures | Exact tap-region sizes and classification, action gates, shared direction predicate in spreads/scrubber, spread-to-page lookup | Full swipe/action binding and thumbnail reversal for every mode/device |
| 4. State | Compiled locator-related fields, guarded session store, asynchronous storage call, Realm write, background-task cleanup | Complete serialization/default precedence and full restore/commit trigger specification |
| 5. Backgrounds | Actual ColorKit provider, edge sampling formula, separate versus combined averages, forced alpha, task/result caching | All transition/composition paths, cache invalidation, upstream border/alpha preprocessing |
| 6. Loading | UIKit prefetch and cancellation handlers, page/thumbnail task separation, allocation guard, stale-result checks | Full decoded-image budget, eviction policy, fixed look-ahead counts if any |
| 7. Fixed EPUB | WKWebView bridge, scale calls, five-number metrics response, native parsing, viewport injection/preservation | Complete resource-serving implementation and exhaustive mixed-content/runtime behavior |

## 1. PDF rendering and Study integration

Compiled metadata identifies `ComicPDFSupport.PDFContentView` as a `PDFView`
subclass, hosted by a `PDFPageView` wrapper. The actual setup procedure at
`0x10141ea8c` calls the PDFKit setters for display mode **0** (single page),
display direction **1** (horizontal), display box **1** (crop box), page shadows
off, page breaks off, and automatic scaling on. It disables interaction on the
wrapper and enables clipping. A flag prevents repeated setup. The document setter
at `0x10141e930` compares document identity before replacing it. **E003** and
the matching assembly **E152** support the setup; enum interpretation was checked
against the installed Apple PDFKit SDK headers.

`0x10141f434` installs an observer for
`PDFViewVisiblePagesChangedNotification` on the main queue with a weak capture.
The callback reads `currentPage`, `document`, and `indexForPage:`.
Asynchronous navigation reaches `goToPage:` and continuation-handling code.
These are concrete page-navigation paths, not evidence of PDFKit's private tile
sizes or raster cache policy. **E142–E145**.

`PDFPageRenderer` also owns an `ImagePageRenderer` and PDF image-generation
objects. Its initializer constructs a rendering option labelled `PDF` or
`Image`. The default selector at `0x1014f8868` chooses the image flag when the
variant OS is at least **26.0 and below 26.1**, and the PDF flag otherwise.
Thus PDFKit view rendering is not the only compiled path. A selected/default
option is not a runtime trace of every document's renderer. **E004, E012,
E035–E036**.

The bundled `PDFPage.rotatedBounds(for:)` helper obtains bounds for the requested
box and swaps width/height for rotations of exactly 90 or 270 degrees, preserving
the origin. Other values retain dimensions. This is a bounds helper, not a full
annotation transform. Framework Evidence and assembly are detailed in
[helper-findings.md](../.verification/panels-native-20261019/helper-findings.md).

The app-side evidence does **not** establish text-selection quads, search result
rectangles, crop-origin corrections, or the transformation order for annotations.
Those must not be reconstructed from a width/height swap alone. PDFKit's internal
page tiling is outside this app binary's recovered implementation.

## 2. Page layout and geometry

Single- and double-page collection-view size callbacks return the viewport's
`bounds.size`, with negative dimensions clamped to zero. That establishes the
outer paginated cell size, not how the image inside that cell is fitted.
Offline instruction records are `llvm-0x1017009f0.asm` and
`llvm-0x1016f05c8.asm`.

The continuous callback reaches `0x1016d90b8`. It obtains page geometry for the
item and, when its geometry tag is not 2, computes either
`height = viewportWidth * pageHeight / pageWidth`, or
`width = viewportHeight * pageWidth / pageHeight`, depending on its axis flag.
The computed dimension is clamped nonnegative. Geometry tag 2 retains the
viewport dimensions. The deep pass resolves it as Optional.none (missing
PageGeometry), rather than a special page category. The assembly preserves the floating-point argument/return
details omitted by the wrapper's C signature. **E016, E033, E153**.

`DoublePageReaderViewModel` builds an array of spread objects from page geometry.
The function at `0x1016b8210` supports single-page entries and paired adjacent
entries, with a direction-dependent placement branch. Another path initializes
the first and last entries as singles and assigns alternating pair tags to
interior entries (`0x1016b89b8`). The tags are recovered machine values, not yet a
complete semantic specification of real cover/landscape handling. **E017–E018**.

The lookup at `0x1016b8c04` examines each spread's one or two source pages,
compares their stored index plus one with the requested canonical page number,
and returns the spread index or absence. This is useful evidence that spread
presentation and canonical page identity are distinct. Adjacent-spread navigation
also uses direction-dependent steps and bounds checks. **E019, E124–E126**.

The framework's current-spread helper filters visible cells against the middle
half of the viewport, sorts candidates, and chooses the last for manga or first
otherwise. Its comparator is not fully resolved. The framework's square-fit and
smallest-side-fit helpers are recovered, but their existence does not establish
the complete reader fitting policy. See `helper-findings.md`.

## 3. Reverse reading and gestures

The tap setup at `0x1016c74f4` creates four noninteractive overlay regions.
It attaches them to the supplied reference view, or that view's superview when
the reference is a scroll view and a superview exists.
Their accessibility suffixes are `top_tappable_area`, `left_tappable_area`,
`center_tappable_area`, and `right_tappable_area`.

- The top region spans the host width and uses **20% of the reference view's height**.
- Below it, the left and right regions each use **33% of the reference view's width**.
- The center fills the space between those side regions below the top band.

These are literal 0.20 and 0.33 multipliers, not exact thirds. Frame containment
is checked in top, left, center, right order. Classification values are 0, 1, 3,
and 2 respectively; a point outside all regions falls back to center.
**E030, E104–E105, assembly E111** and corresponding annotated LLVM assembly.

The single-tap handler requires a gesture view and the ended state, classifies
the location, then dispatches through a MainActor task. Left/right taps consult
side-tap gates and a zoom-control delegate, cancel conflicting gestures where
present, and invoke their configured closures. The deep pass corrects the
generic continuation: top and center both use centerTapAction in this body.
Double-tap has a separate relative-view override and action closure.
The lower-level handler therefore does not by itself prove that left always
means next or previous in a particular reading mode. **E010, E062, E066, E090**.

The same direction predicate at `0x1016adb6c` is used by spread navigation and
the horizontal scrubber. The scrubber sends it to its presentation object while
progress uses a clamped canonical current page and total count. **E127–E128**.
The earlier runtime observation that the left arrow advances in RTL remains
valid, but a complete touch/swipe and thumbnail reversal matrix is not established
by that keyboard observation or by the generic tap closures.

## 4. Saved reading state

The retained compiled declarations establish these locator-related fields in
`ReadingSessionDAO`: `currentPage`, `totalPages`, `doublePageFixedIndex`,
`leftToRightReading`, `scrollOffsetX`, `scrollOffsetY`, `zoomLockOffsetX`,
`zoomLockOffsetY`, `zoomLockScale`, `zoomLockIdentifier`, and
`readerConfigurationJSON`. The prior Evidence ID and exact metadata locations
are retained in `reading-session-declarations-from-prior-evidence.json`.
Unresolved Swift ivar offset/type entries are not zero-valued fields or defaults.

`storeReadingSession` at `0x1016b4390` first calls a guard. The guard compares
session snapshots and configuration and includes a `<= 30.0` accumulator check.
This is evidence of conditional suppression, **not a proven 30-second timer**.
The store updates session/configuration data and dispatches an asynchronous
storage operation on the MainActor. Nonzero accumulated reading time enters an
application background-task path. Both success and failure continuations end
the background task. **E007, E034, E063, E067, E089, E102–E103**.

Tracing the injected storage witness reaches `0x1000d3394`, which invokes
`RealmSwift.Realm.write` with a closure. This establishes actual database-write
machinery beyond the earlier model declarations. Its closure reaches
`0x1000d38a0`, which JSON-encodes reader configuration, calls
`setReaderConfigurationJSON:`, and updates `currentPage`, `doublePageFixedIndex`,
last-session and reading-time fields through guarded paths. This still does not
recover every encoded key or restoration rule. A wrapper updates reading-time
accounting before calling the store. **E148–E151, E154–E155**.

The complete wire/JSON schema, exact offset coordinate units, restore ordering,
all commit triggers, and library/title/default precedence remain incomplete.
The earlier restart test established persistence of the title's RTL choice; it
did not establish every precedence combination. Keep those runtime and static
claims separate.

## 5. Dynamic backgrounds

The injected provider is the compiled `PanelsColorKit.ColorKit` class. Following
its witness methods through asynchronous task wrappers reaches the actual
sampling bodies at `0x1015d7a04`, `0x1015d8348`, and `0x1015d88d0`.
The reader's provider wrappers pass the literal sampling parameter **0.009**.
Metadata pointers and witness-table decoding are ordinary offline corroboration;
the recovered procedure bodies are **E108–E117, E130–E135**.

For an input image with UIKit dimensions `w,h`, the sampling thickness is:

```text
t = max(1, sqrt(0.009 * w * h) / 4)
left  = crop(0,     0,     t, h)
right = crop(w - t, 0,     t, h)
top   = crop(0,     0,     w, t)
bottom= crop(0,     h - t, w, t)
```

The horizontal variant averages the left/right crops separately; the vertical
variant averages top/bottom separately. The single-color variant takes all four
edge strips, rotates the side strips by approximately pi/2, normalizes strip
widths to a shared minimum, composes a four-strip image, and averages that image.
This is edge-derived color, not a whole-page dominant-color quantizer.
**E133–E135; assembly E139–E141**.

The average uses the bundled CoreExtensions helper: `CIAreaAverage` over the
input image's full extent, rendered to one RGBA8 pixel. The ColorKit caller then
sets the resulting color's alpha to **1**. Failed crops throw; failed averages
produce an absent result (or an absent pair). These paths show no explicit
white-border exclusion or clustering stage. They do not rule out preprocessing
upstream of the sampled image, and forcing output alpha does not define how all
transparent input pixels were composited.

`BackgroundColorCalculator` has separate per-page single, horizontal-pair, and
vertical-pair result arrays plus corresponding task arrays. A request returns a
cached result, waits for an already queued task, or creates and retains a task.
Completion writes the result and clears/releases the task slot. Fixed white and
black configurations bypass dynamic calculation. **E009, E015, E044–E055,
E074–E076**. The complete invalidation policy and visual transition/composition
algorithm are not established; the earlier visual distinction between single
and immersive remains runtime evidence, not proof of a particular gradient shader.

## 6. Loading, prefetch, and caches

The single, double, and continuous readers implement UIKit collection-view
prefetch and cancellation callbacks. Single-page prefetch maps the supplied item
indices to page objects and creates asynchronous tasks; its cancellation path
calls the renderer cancellation witness for each corresponding source page.
Double-page prefetch maps an item to its spread object, and cancellation forwards
to that object. These callbacks process the indices supplied by UIKit; no fixed
application-wide look-ahead count is established here. **E020–E023, E119–E120**.

`ImagePageRenderer` declares distinct page and thumbnail prefetch-task maps.
Recovered display paths check the requested page against the cell's current
identity before applying a result, which protects reused cells from stale page
or thumbnail results. The page and thumbnail paths log completion separately.
An image appearance path uses a **0.2-second** fade in its animated branch;
that is not evidence of the background transition duration. **E038–E040**.

The framework allocation guard estimates
`ceil((width * scale) * (height * scale)) * bytesPerPixel` (default four), then
compares 1.5 times that estimate against positive `os_proc_available_memory()`.
Insufficient memory throws `ImageMemoryError`; finite/range checks guard numeric
conversions. A nonpositive available-memory result takes the success path.
This is an allocation guard, not a decoded-image cache cap or LRU specification.
The Swift error register is lost in one public wrapper's pseudocode, so its
apparent unconditional true return must not be copied. See `helper-findings.md`.

The earlier fixture generated `.Panels/geometry` and `.Panels/thumbnails` caches.
Their existence does not reveal eviction thresholds. Total decoded memory,
disk eviction, concurrency bounds, and geometry-job cancellation were unknown in
this pass. The [deep cache report](PANELS_DEEP_CACHE_BACKGROUND.md) now recovers
count/date trimming, memory-warning clearing, disk limits and cleanup policy;
a global decoded-byte budget remains unestablished.

## 7. Fixed-layout EPUB rendering

Native code loads `PanelsEpubScripts` from the support bundle and distinguishes
local-directory resources from another resource-loading branch. `EPUBPageView`
uses WKWebView evaluation to call `panelsAdjustContentScale(...)`, passing width
and a true/false adjustment mode. It evaluates a second JavaScript expression
returning **content width, content height, scaled width, scaled height, scale**,
joined by `#`. The continuation splits the string, requires at least five
components, converts values to doubles, and checks the first four dimensions for
nonnegative finite-range values before proceeding. **E005–E006, E011, E024,
E031**. The C sometimes displays a Swift string's base pointer 32 bytes before
its characters; adjacent string labels must not be treated as literal content.

The recovered HTML delegate calls `0x10141a5c4`. It matches an existing viewport
meta tag. If none exists it injects a tag before `</head>` with initial, minimum,
and maximum scale 1 and `user-scalable=no`. If a tag includes numeric width and
height it preserves those dimensions while replacing scale directives; otherwise
it uses the no-dimensions tag. **E025, E032**.

The shipped JavaScript itself resets the body transform and column width before
measurement. It uses explicit pixel body width if available, otherwise scroll
width, otherwise reader width; explicit pixel height is used with explicit pixel
width, or height is inferred from scroll aspect ratio. Invalid dimensions trigger
a viewport-meta fallback. Scaling uses `readerWidth/contentWidth` when enabled,
records all five metrics, and sets a CSS transform. With scaling disabled it
retains scale 1 and sets column width to the reader width. A nonzero supplied
reader width is remembered across later calls. Load and resize rerun measurement.
The shipped CSS pins the transform origin to top left and preserves original
body width/height declarations. Exact resource files and SHA-256 hashes are in
`evidence/epub-resource-identities.json`.

This establishes a native/web geometry handshake that preserves EPUB HTML and
CSS. Complete resource URL serving, all rendering-mode decisions, and full
mixed image/text semantics still require further tracing or controlled fixtures.

## Consequences for StudyStream

StudyStream currently uses `pdfrx` and `PdfTextSearcher` in
[`pdf_reader_screen.dart`](../lib/features/reader/pdf_reader_screen.dart).
It restores a page, zoom, and saved document vertical offset, and uses the
searcher's page-paint highlighting callback. The database stores canonical page
numbers for notes/bookmarks; it does not currently store selection quads or
page-local region anchors. See
[`app_database.dart`](../lib/data/db/app_database.dart).

An independent implementation can retain that PDF text/search capability while
adding Panels-style reader behavior around a common page surface:

1. Keep document/page identity canonical. Derive RTL order and spread placement
   from it; never renumber stored notes when presentation changes.
2. Store annotations as unrotated page-local coordinates, normalized against a
   declared page box, plus document identity and canonical page number. Preserve
   text anchors separately when supported. Convert through crop, rotation, fit,
   zoom, and viewport transforms for display/hit testing.
3. Keep the reading locator separate: canonical page, page-local position,
   zoom/zoom-lock state, and layout configuration. Transfer that anchor when
   modes change instead of replaying a continuous-document pixel offset.
4. Resolve library defaults and explicit title overrides deliberately in our own
   configuration model. Panels' complete precedence rules are not yet recovered.
5. Give image, PDF, and EPUB surfaces shared geometry/prefetch/cancellation
   contracts. Retain renderer-specific text/search support instead of flattening
   every PDF into a bitmap for the study workflow.

These are implementation recommendations only. No migrations, reader rewrites,
or changes to existing study tools were made by this investigation.
