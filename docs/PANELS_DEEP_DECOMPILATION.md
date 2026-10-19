# Panels deep decompilation findings

19 October 2026 · Panels 3.13.8 (974), `es.produkt.app.panels`.

This pass substantially narrows all seven requested investigation areas. It
recovers concrete layout, direction, persistence, background, cache and EPUB
rules, plus a previously untraced VisionKit Live Text pipeline. It does not
recover original Swift source or establish complete behavioral parity. This
report supersedes the broad unknowns in the earlier
[native report](PANELS_NATIVE_DECOMPILATION.md) where explicitly stated.

Detailed companion reports contain the longer traces:

- [Geometry, gestures, RTL, thumbnails and zoom restoration](PANELS_DEEP_GEOMETRY.md).
- [Dynamic backgrounds, image tasks, memory caches and disk eviction](PANELS_DEEP_CACHE_BACKGROUND.md).
- [EPUB resources, native/WebKit rendering and snapshots](PANELS_DEEP_EPUB.md).

No Panels binary, signature, user library or StudyStream application source was
changed by this analysis. No new target-app runtime experiment was performed in
this pass. Earlier observed behavior remains in
[the first investigation](PANELS_INVESTIGATION.md); it must not be conflated with
the new static evidence.

## What is now established

| Requested priority | New recovered detail | Remaining boundary |
| --- | --- | --- |
| 1. PDF and Study | PDFKit page view and raster-image paths; crop-box raster generation, white matte, flipped drawing transform, screen-scale output; VisionKit image analysis, size/aspect guards, interaction installation and analysis cache | PDFKit private tiling; VisionKit internal selection geometry; full native PDF text-search/annotation transform; runtime renderer choice for each fixture |
| 2. Geometry | Named fit/fill/automatic policies, continuous aspect sizing, first-cover and strictly-landscape singleton rules, square-page pairing, pairing anchor and orphan repair | Exact visual position through every rotation and mode change; malformed geometry behavior |
| 3. Reverse reading and gestures | Mode/axis-dependent RTL predicate, canonical neighbor bounds, configurable physical edge taps, shared top/center action, mirrored thumbnail layout and canonical thumbnail selection | Complete swipe arbitration and touch behavior on every supported device/mode |
| 4. Saved state | Exact reflected session fields and optional types, configuration snapshot/default fallback, encoder fields, raw offset capture, mode-identified zoom locks, close/dismiss commit paths, newer-record protection | Complete library-specific inheritance, every lifecycle trigger and conflict rule, portable serialization round-trip for every enum variant |
| 5. Backgrounds | Edge-strip sampler, solid/axial four-stop composition, 0.3-second transition, interactive alpha blending, upstream transformation gate and pipeline-aware cache checks | All runtime combinations of borders/transparency, shaders and geometry; cache invalidation outside recovered paths |
| 6. Loading/caches | Distinct page/thumbnail task maps; priority-aware sharing and cancellation handling; access-date cache trimming; memory-warning clearing; allocated-byte disk limits, oldest-date cleanup, grace period and active-document protection | A global decoded-byte/RSS budget; a universal fixed look-ahead count; measured large-book behavior |
| 7. Fixed-layout EPUB | Folder/archive resource paths, preserved HTML/CSS/JS WebKit path, alternate image extraction, viewport metrics, native reuse keys, retry layers, delayed snapshots and memory guard | Complete generator-mode switching trigger, unpacker internals, exhaustive mixed-content/runtime behavior |

These are specific recovered implementations and scoped unknowns. A framework
boundary is not evidence that an app-side gap cannot be investigated further.
Conversely, another pass over the same app functions cannot reveal the private
implementation of an external framework.

## Evidence identity and limits

The installed universal executable has SHA-256
`c27578f21eb30a921491c03c98a644696c5efc91a24e2448419da67e66ef16d7`.
The immutable arm64 slice analyzed here has SHA-256
`9a75cdc1b6196a9d5d55c5f16c55c14a024dfbcec4950cfc854725d5a351d7dc`.
REA 6.7.0 used Ghidra 12.1.4 with 347 explicit function seeds; the source was
imported into an ephemeral analysis database. The successful analysis profile
digest is `b6146b24536f8db9cc5b1ae27a15a4eb3b90f798cd8fd3e3fef59e79e6e0bc9e`.
The seed SHA-256 is
`223e1c1c2b30170fed4b60388189732084430190f8ec3ffe6ac7d0493e57f483`.

The [deep evidence directory](../.verification/panels-native-deep-20261019/)
retains complete JSON responses, verbatim pseudocode, derived annotations,
ordinary Mach-O/LLVM inspection, a portable evidence bundle and session snapshot.
The [index](../.verification/panels-native-deep-20261019/evidence-index.json)
maps each procedure request to its full Evidence ID, profile and limitations.
Below, **D105** means `deep3-105`; **E003** means `targeted-003` from the
[previous index](../.verification/panels-native-20261019/evidence-index.json).
The [procedure ledger](../.verification/panels-native-deep-20261019/procedure-ledger.md)
provides directly linked records and pseudocode for the complete new pass.

The seeded profile disables ten expensive analyzers, including global reference
discovery. A successful response is not an exhaustive call graph. Some requests
resolve to thunks or a containing procedure; selectors alone do not identify a
semantic body. Several large merged bodies and Swift asynchronous continuations
remain unsuitable for literal source translation. Ghidra can lose floating-point
aggregate returns, error registers and small-string representations. Numeric
claims were checked against instructions where that affects the conclusion.

Reflection fields, parsed relative pointers, import annotations and LLVM assembly
are ordinary immutable-artifact inspection, not newly minted REA Evidence. The
raw REA responses remain unmodified. The resilient Swift conformance parser was
checked against the primary
[Swift ABI metadata definitions](https://github.com/swiftlang/swift/blob/main/include/swift/ABI/Metadata.h);
an absent witness-table pattern was not treated as a function pointer. The
corrected [encoding-witness ledger](../.verification/panels-native-deep-20261019/state-reader-config-encoding-witness.json)
retains that interpretation.

## 1. PDF rendering, image analysis and Study implications

### Native page view

The earlier recovered `PDFContentView` setup remains valid: it is a `PDFView`
subclass configured for single-page horizontal display, crop box, no page
shadows/breaks, automatic scaling and clipping in its wrapper. Its document
setter compares identity before replacing the document. A main-queue observer
uses `PDFViewVisiblePagesChangedNotification`, reads the current page and obtains
its document index. Asynchronous navigation uses `goToPage:` and a continuation.
These are app-side PDFKit calls, not a custom recovered PDF tile engine.
**E003, E142–E145, E152**.

New success/cancellation bodies clarify continuation cleanup. `0x10141f860`
clears the stored continuation, cancels/releases a fallback task when present,
and resumes the continuation. `0x10141fa50` performs analogous cleanup with a
cancellation error. The previously recovered navigation continuation can resume
immediately if the requested page is already current. This does not establish
the fallback task's exact timeout from those cleanup bodies alone. **D109–D110**.

`PDFPageRenderer` also owns an `ImagePageRenderer`. The prior default selector
chooses Image on variant OS versions 26.0 through below 26.1 and PDF otherwise.
That compiled workaround is not proof that every PDF in the current runtime
uses one renderer, and is not a requirement for Tangerine's pdfrx backend.
**E004, E012, E035–E036**.

### Raster generation

`PDFPageImageGenerator` reflection identifies the PDF document, thumbnail
generator, internal-image-cache flags/path and logging fields. New bodies
`0x10122e308` and `0x10122ed00` obtain `PDFDocument.pageAtIndex:`, reject a missing
page and check task cancellation. Their task setup passes display-box value 1,
the crop box, into the recovered generation chain. **D228–D229**.

Drawing bodies `0x10122f74c` and `0x10122feb8` fill the output rectangle with
white, translate the CGContext to `(0, outputHeight)`, scale by `(s,-s)`, then
call `PDFPage.drawWithBox:toContext:`. This is a real PDFKit rasterization path.
The CGContext y flip is not a recovered text-selection-to-annotation transform.
**D105–D106**.

The thumbnail sizing body `0x10122f150` starts with rotated bounds. Its quality
branches choose a nominal long-edge size of 500 or 1000, preserve aspect ratio
and truncate computed dimensions. For aspect ratio above 3, it instead scales
the short edge toward 70% of that nominal size. The mapping of every quality
byte to a user-facing option was not recovered; do not label those values as
universal page sizes. The renderer uses current UIScreen scale when available
and 1 otherwise. `UIGraphicsImageRenderer` receives the point size, while its
format receives that screen scale. **D226, D269, D287, D297, D307; assembly
D325–D326**.

A separate full-bounds path calls `0x10122cf94` before rendering. It compares an
estimated allocation with physical memory at a **0.025** fraction. If exceeded,
the recovered formula multiplies each scaled dimension by the linear ratio
`0.025 / (estimatedBytes / physicalMemory)` and truncates it. This is an
allocation-size adjustment in that path, not an app-wide decoded-image budget,
and not a reason to substitute a square-root formula in the report. The shared
image estimator includes its own overhead factor, described in the earlier
helper report. **D227, D270, D288–D289; assembly D327**.

The `PDFPage.rotatedBounds(for:)` helper swaps width/height for exactly 90 or
270 degrees while retaining origin. That helper does not establish the entire
rotation/crop-origin transform used by interactive page views.

### VisionKit Live Text is a separate pipeline

The newly traced `ComicReaders.LiveTextAnalyzer` contains a
`VisionKit.ImageAnalyzer`, a page renderer, a previous-task slot and
`NSCache<NSString, ImageAnalysis>`. Its constructor checks
`ImageAnalyzer.isSupported`, throws on the unsupported branch and sets the
analysis cache's **countLimit to 8**. NSCache countLimit is a configured policy,
not evidence of a measured hard RSS limit. **D256** and retained instructions
`llvm-0x1016279bc.asm`.

Analysis types are deliberately selected:

| Panels detection choice | VisionKit analysis types | Interaction types |
| --- | --- | --- |
| textOnly | text + machine-readable code | automaticTextOnly |
| subjectOnly | visualLookUp | imageSubject |
| textAndSubject | text + machine-readable code + visualLookUp | automatic |

`0x101628224` builds analysis types; `0x10162c1b8` builds interaction types.
The async pipeline first checks an analysis-cache key. A hit reuses the
`ImageAnalysis`; a miss asks the page renderer for an image result, checks
cancellation and calls `ImageAnalyzer.analyze(UIImage, configuration:)`.
The key-construction function combines page index, detection-mode string,
renderer-associated identity and a comma-joined pipeline-derived list. The
complete meaning of every pipeline fingerprint and every invalidation caller
is not asserted here. **D257, D260–D262, D285, D295, D309–D310, D321**.

The recovered image-analysis branch rejects NaN or a width/height ratio outside
**0.2 through 5.0**. For an image whose longest UIImage dimension exceeds
**3000**, it scales by `3000 / max(width,height)` before analysis. The unit at
this call is `UIImage.size`; this is not automatically a statement about CGImage
pixel dimensions at every scale. The comparison, scale factor and call are
preserved in canonical assembly. **D309, D319, D324**.

Panels constructs an `ImageAnalysisInteraction`, attaches the analysis, hides
VisionKit's supplementary interface, chooses the interaction types, applies the
selectable-items-highlighted flag, permits long-press data detectors in text
mode and calls `setContentsRectNeedsUpdate()`. The installation helper removes
the prior associated interaction, records weak association/page/mode metadata,
and adds the replacement interaction to the target view. **D258, D260, D262,
D284**.

The recovered delegate forwarders for `contentsRect(for:)` and
`contentView(for:)` call VisionKit's default implementations. These exact
forwarders contain no custom PDF crop-box/text-quad mapping. Reset code removes
the interaction and clears associated state; selection helpers query active text
selection or reset it. **D263–D264, D267–D268, D320**.

The concrete inference is that Panels has a raster-image Live Text path shared
through its page renderer. It is not evidence that PDFKit's selectable text layer
is the sole mechanism or that every PDF always uses OCR. A bounded direct-call
scan of imported PDF APIs did not reveal a complete native PDF search/selection
coordinate chain; indirect calls and other implementations remain possible.
The scan is retained in `state-pdf-import-calls.json` and is not proof of global
feature absence.

For Tangerine, preserve the existing pdfrx text/search and Study anchors. Define
page-local transforms independently, and treat optional raster OCR as a separate
capability. A VisionKit interaction does not provide a recovered durable note
anchor format. The main unresolved PDF work is now a named external-framework
or integration boundary, rather than uncertainty about whether a renderer or
image-analysis pipeline exists.

## 2. Layout and canonical page geometry

The [geometry report](PANELS_DEEP_GEOMETRY.md) recovers the actual classifiers
and calculators. The first zero-based page is always a singleton cover;
strictly landscape pages (`width > height`) are singletons; **square pages
participate in portrait pairing**. The stored `doublePageFixedIndex` anchors
pairing, is clamped when invalid, and does not renumber canonical source pages.
Pairing repairs orphans around landscape breaks and makes a final unpaired
half a singleton. Placeholder geometry is `(100,200,index,true)` until real
geometry arrives. **D045–D046, D080–D081**.

Paginated outer cells use the viewport. The inner frame calculators are distinct:
fit returns the reference frame; fill computes aspect-preserving cover for the
recovered nonsquare cases; automatic expands across orientation mismatch. Square
source or viewport can take the unchanged-frame branch, so a universal cover
formula would misdescribe Panels. Continuous layout uses the viewport's cross
axis and intrinsic aspect ratio. **D113–D115, D141–D142**.

The earlier unexplained geometry tag 2 is **Optional.none**, not a special page
category. `0x101536500` returns a present PageGeometry for a valid index, otherwise
a nil aggregate. This corrects the interpretation of the earlier continuous
fallback. **D172** is canonical assembly.

Canonical source index+1 identifies a page. A spread may contain one or two such
pages and can swap their visual placement under effective RTL. The source
identity does not change. Exact pixel-preserving handoff across every mode,
rotation or change from placeholder to real geometry remains unproven.

## 3. Direction, taps and thumbnail navigation

The effective predicate is:

```text
reversePresentation = !session.leftToRightReading
  && (transition is pageCurl or panelsView
      || transition.scrollDirection == horizontal)
```

Thus vertical paginated/continuous presentation does not become reversed solely
because the title is RTL. Bounded neighbor functions add/subtract canonical page
numbers according to this predicate and return no page beyond the ends.
**E127, D075–D076, D313–D314**.

Physical left/right tap behavior is configurable through global tap settings;
the closures pass physical-navigation triggers 8/9. The left and right getters
both interpret the `left` string, but have different invalid-value fallbacks.
Canonical next/previous still depends on effective presentation direction.
Do not encode a universal edge-to-canonical-next rule that ignores customization.
**D047–D050, D146–D153, D194–D196, D200**.

The earlier top/center distinction was overstated: the recovered generic tap
continuation routes both top and center classifications to `centerTapAction`.
Having a compiled `topTapAction` property does not show it is read by that body.
**E066** plus the named field-offset metadata establishes this correction.

Thumbnail layout mirrors presentation while keeping canonical index-path/page
associations. New layout/selection bodies preserve the represented canonical
page on selection, rather than blindly applying `count-index` to persisted page
identity. See the detailed report for layout invalidation, spread selection and
the exact body addresses. **D215–D221, D253–D255**.

The static paths establish much more than the earlier keyboard observations,
but do not constitute a complete physical swipe trace. UIKit's recognizer
arbitration, nested scrolling and live selection conflicts still need fixtures.

## 4. Saved reading state and precedence

### Recovered fields

The full reflected type is **ComicReaders.ReadingSession**. Its zoom-lock value
is **ComicModels.ReadingSessionZoomLock**; those modules must not be confused.
The [schema ledger](../.verification/panels-native-deep-20261019/state-recovered-schema.json)
retains field ordering, symbolic types and descriptor addresses.

| Group | Fields and types |
| --- | --- |
| Identity/device | identifier, title, fileName, deviceName, devicePlatform: String; deviceAppVersion, deviceAppBuild: String? |
| Canonical progress | currentPage, totalPages, doublePageFixedIndex: Int |
| Timing/completion | startedOn, lastSession: Date; timeSpentReading: Double; spentUntilCompleted: Double?; completionDate: Date? |
| Presentation state | leftToRightReading: Bool; scrollOffset: CGPoint?; lastReaderConfiguration: ReaderConfiguration?; lastZoomLock: ReadingSessionZoomLock? |
| Visibility/locking | isHidden, isLocked: Bool |
| Source/sync | source: ReadingSessionSource; updaterIdentifier: String; serverSessionId: String? |
| Processing | filtersPipeline, shadersPipeline, transformationsPipeline: typed arrays; customRenderingMode: RenderingMode?; translationSourceLanguage: String? |

`ReadingSessionZoomLock` contains **identifier: String, scale: CGFloat,
offset: CGPoint**. This is separate from the optional normal scrollOffset.
There is no standalone ordinary zoom field in this recovered session schema.
The schema describes compiled data, not every database serialization decision.
Some later initial field-offset-vector slots are zero before runtime metadata
completion; those are not literal zero offsets in a live ReadingSession.

### Configuration selection and encoding

`ComicViewerViewModel` copies the incoming session into original/current state.
It reads optional `lastReaderConfiguration`; when absent it asks the concrete
environment for its default. That getter reads serialized default-reader data,
attempts Decodable conversion, and falls back to the static configuration on
absence/failure. The candidate configuration also passes an environment feature
availability check; a failed check resets it to static defaults. This is not a
generic geometry-validation function and does not establish a library hierarchy.
**D005, D170, D197–D198, D210, D225**.

The static initializer resolves to customTitle absent; paginated horizontal fit;
numberOfPages automatic; black background; system brightness; bottom scrobbler.
That is a compiled fallback, not an observed fresh-install preference on every
device. Enum and field decoding is retained in the geometry reflection ledger.

The outer ReaderConfiguration encoder uses keyed fields in this order:
customTitle (encodeIfPresent), pageTransition, backgroundColor, screenBrightness,
scrobblerPosition. Background colors encode as strings white/black/automatic;
scrobbler position as left/right/bottom; system brightness uses the string
`system`, with the fixed case using a keyed payload. **D143, D157,
D277–D280, D291–D294**.

These functions do not establish a complete byte-for-byte interchange sample for
every transition variant, all decoder defaults, ordering or error behavior. The
transition encoder has branches needing further ABI/control-flow validation;
do not invent a fully recovered JSON example. Likewise, whole-title last-reader
configuration followed by an app default is not proof of sparse
title→library→application inheritance. Tangerine's planned inheritance contract
remains an independent design choice.

### Scroll and zoom offsets

`0x1016b3968` compares optional scrollOffset with an incoming CGPoint, stores a
changed point, updates lastSession and invokes the session update path.
New cell callbacks read **UIScrollView.contentOffset** and pass it directly to
that setter. There is no normalization between these calls. One restoration
body checks whether the saved offset is currently scrollable in bounds; if not,
it keeps it as a pending offset instead of immediately applying it. This is a
concrete single-page cell path, not proof that every continuous/global offset
uses one common coordinate space. **D188, D328–D330; assembly D331–D333**.

ZoomLocker applies the supplied scale, directly applies supplied content offset
when scale>1, stores the same triple and notifies its delegate. Pinch completion
reads actual zoomScale/contentOffset. The delegate chain copies those values
into the session's optional zoom lock without dividing by page size.
**D241–D246, D192–D193**.

Restoration is identified by mode:

| Reader | Identifier/gate | Recovered behavior |
| --- | --- | --- |
| Single page | `standard_single_page_reader`, fitting must be fit | Restores matching saved scale/x/y; non-fit save path clears lastZoomLock |
| Double page | `standard_double_page_reader` | Restores only matching identifier, copies same values |
| Continuous | `continuous_scroll_reader_` plus axis label | Compares constructed identifier, then applies saved scale/x/y without animation |

The continuous axis label reaches localized Horizontal/Vertical fallback
initializers; a language-switch check is needed before treating that string as
a locale-independent identifier. These gates prevent ordinary single/spread
zoom-lock replay across incompatible reader modes. They do not prove exact
content preservation after viewport resizing or UIKit clamping.
**D247–D248, D281–D283**.

### Mutation, commit and conflict protection

`0x1016b3878` accepts a changed canonical page only in 1..totalPages, updates
lastSession and has a completion-related branch when the final page and reading
time threshold are reached. `0x1016b35fc` forwards actual page changes to that
setter and the session update path. Mutation and an eventual Realm commit are
different operations. **D010, D176**.

The store procedure guards whether storage is needed, copies the current reader
configuration back into the session, updates relevant document/visibility fields
and performs asynchronous storage with background-task cleanup. It is not
evidence of a universal 30-second timer. **E034, E149–E151, D322–D323**.

Named close/dismiss callbacks now bind some concrete triggers. Mac
`containerWillBeDismissed` and `closeReader` reach bodies that call the store
wrapper under the document-state gate. The iOS-style container's corresponding
callbacks reach `0x101695da0`, which also calls that path before cleanup/dismiss.
`viewDidDisappear:` itself mostly forwards lifecycle work and should not be
reported as an independently proven direct store call. Additional recovered
callbacks call the wrapper, but their complete notification registration and
every lifecycle trigger remain unclosed. **D178–D180, D183, D201–D204,
D303–D306**.

The Realm conflict-selection helper compares stored DAO.lastSession with the
incoming session's timestamp. If stored data is newer, it constructs a snapshot
of currentPage, doublePageFixedIndex, scrollOffset and lastSession for the write
path. That is concrete protection against overwriting newer reading position;
it is not a recovered complete multi-device merge algorithm for preferences,
notes or annotations. The optional scroll-offset DTO setter stores/clears its
two components together. **D006–D007, D168; E155**.

For Tangerine, keep normalized page-local study anchors independent from raw
viewport resume data. The recovered raw offsets explain a Panels implementation
choice; they do not justify migrating existing notes to view pixels. Preserve
mode identity and compatible-layout restore, and test offset conversion/clamping
at the integration boundary.

## 5. Dynamic backgrounds

The [background/cache report](PANELS_DEEP_CACHE_BACKGROUND.md) combines the
earlier ColorKit edge-strip algorithm with newly recovered composition and
invalidation paths. The strip thickness is
`max(1, sqrt(0.009 * width * height) / 4)`. Separate sides support left/right
or top/bottom; the combined path averages normalized edge regions. Generated
colors force alpha 1. This is not a newly discovered perceptual palette or
white-border detector.

The native gradient uses an axial layer with colors `[A,A,B,B]`, with vertical
or horizontal endpoints selected by the mode. Solid mode hides the gradient.
No explicit color-stop locations are established in this setter. A normal
transition uses **0.3 seconds**, zero delay and BeginFromCurrentState;
interactive transitions blend B over A by progress, with endpoint promotion.
This corrects any assumption that the prototype's 180 ms transition was copied
from Panels. **D030–D036**.

Upstream image transformations include optional border removal; the color
provider itself does not implement a white-border-removal algorithm. Cache hits
validate processing state, and stale entries can be removed lazily per key.
That is stronger than a names-only cache observation, but does not establish
every upstream transformation, alpha-compositing branch or invalidation event.

## 6. Loading, memory and disk caches

The [dedicated report](PANELS_DEEP_CACHE_BACKGROUND.md) contains the exact
thresholds, roots, dates and cancellation branches. The most material recovered
rules are:

- Page results and thumbnails use separate dictionaries and task maps.
  Trimming begins at page count **>=11**, retaining **9** newest entries, and
  thumbnail count **>=51**, retaining **49**. The insertion path invokes the
  cleaner **before insertion**, so these are hysteresis thresholds rather than
  strict caps of 10/50. Cache access refreshes its date.
- A compatible noncancelled existing task can be shared when its stored
  priority is at least the caller's; replacement and cancellation races have
  explicit branches. A cancellation caused by another consumer can lead to a
  retry when the current consumer itself is still active.
- Memory warnings clear page and thumbnail result dictionaries in the recovered
  handler. That handler does not itself empty every task map.
- Provider disk keys at this layer are page/thumbnail cache directory plus
  decimal page index. Do not conflate them with the separate geometry store.
- The app-wide limiter supports decimal 1/5/16/32 GB and unlimited. Missing or
  invalid maximum-size settings take the recovered unlimited fallback. It counts
  allocated disk bytes, not decoded image memory or RSS.
- Cleanup over limit targets **90%** of the limit, considers oldest aggregate
  resource dates first, and avoids recent entries inside a **600-second** grace
  period and paths in use by open documents. A **600-second** periodic trigger
  is gated by recorded unaccounted writes, so it does not rescan unconditionally.

Open-document protection uses standardized path relationships against live
document registrations, including equal paths and ancestor/descendant prefixes.
It is not an OS-level filesystem lock. The limiter has eight configured roots
with different units/depth/date policies. See the companion report before
translating these rules into an independent cache design.

Neither these count thresholds nor the individual image-allocation guard
establishes a global decoded-byte memory budget. UIKit collection prefetch paths
accept requested indices; no universal fixed number of pages ahead was recovered.
Those remain measurements/design decisions for Tangerine C3.

## 7. Fixed-layout EPUB

The [EPUB report](PANELS_DEEP_EPUB.md) now follows both native resources and
WebKit. The native loader has separate folder and archive paths. The WebKit page
path preserves HTML, CSS and JavaScript; it supplies the HTML resource directory
as base URL to `loadHTMLString:baseURL:`, then injects styles/scripts/media overlay
support. This materially exceeds a single-image HTML extractor. **D024–D029,
D051–D056, D101–D104, D163–D166**.

An alternate image path extracts the first matched img/image source, including
SVG xlink:href, resolves relative resources and obtains UIImage data. Its regex
and first-match behavior are not a complete HTML renderer. Native/image mode
existence does not prove automatic fallback for every mixed-content page; the
complete generator-mode-switch trigger remains untraced.

The recovered native view can choose text mode when height/width exceeds **2.5**
under its automatic configuration. Base asynchronous render settings include a
2-second timeout and 2 retries; a separate native renderer failure path allows
up to 3 retries. These are separate layers, not contradictory counts.

The generator waits **200 ms** in the recovered snapshot sequence, checks image
allocation suitability, then snapshots the rendered page. WKSnapshotConfiguration
receives the requested rectangle, optional snapshotWidth and afterScreenUpdates
enabled; the recovered generator call passes nil snapshotWidth. Success/error
callbacks return UIImage or propagate failure. These calls establish app-side
sequencing, not a promise that arbitrary scripts/fonts finish within 200 ms.
**D111–D112, D138, D237–D239**.

Resource, page, reader and mode identities participate in recovered reuse checks.
Study text anchors across HTML layout changes still require an independent
contract. A raster snapshot and a spine resource name alone do not preserve
the location of a note in mixed text/image content.

## Corrections and implementation consequences

The following earlier uncertainties can now be narrowed or corrected:

1. Optional geometry tag 2 means missing geometry, not a special page class.
2. Cover/wide/square pairing has concrete rules; square pages are pairable.
3. Top and center reach the same action in the traced generic tap continuation.
4. Zoom locks store raw scroll-view offsets with mode identifiers; they are not
   a recovered normalized page anchor.
5. Image cache eviction and disk cleanup are implemented, with thresholds and
   date/size policies now recovered.
6. Background composition has a recovered 0.3-second transition and axial
   `[A,A,B,B]` gradient; the prototype's 180 ms is an independent choice.
7. EPUB has a preserved HTML/WebKit resource pipeline as well as image extraction.
8. Live Text includes VisionKit analysis of rendered images; native PDF text
   selection must not be assumed to be the sole mechanism.

The [Tangerine implementation plan](TANGERINE_UPDATE_PLAN.md) is updated to cite
these findings. Its normalized anchors, sparse title/library inheritance,
square-page policy, measured memory budgets and reduced-motion behavior remain
explicit Tangerine choices. MyVLC preservation remains the prior A0/A1 release
priority; this investigation does not mark any reader milestone implemented.

Further work should be evidence-directed: runtime fixtures for mode/rotation
handoff and gesture arbitration, actual default/title/library resolution,
VisionKit/PDFKit surface coordinates, generator-mode changes and large-book
memory behavior. Every remaining item has a concrete target rather than a claim
that stripped code makes all gaps impossible to investigate.
