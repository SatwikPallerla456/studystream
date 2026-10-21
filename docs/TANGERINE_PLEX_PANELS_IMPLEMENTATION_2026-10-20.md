# Plex targeted findings and Panels deep findings: implementation pass

20 October 2026. Scope: the user's request to implement
[PLEX_TARGETED_DECOMPILATION.md](PLEX_TARGETED_DECOMPILATION.md) and
[PANELS_DEEP_DECOMPILATION.md](PANELS_DEEP_DECOMPILATION.md), including their
scanner, geometry and cache/background companion findings. Graphify queries
located the relevant implementation before source inspection. The research
reports remain evidence about the reference apps; this document records
Tangerine's independently chosen behavior.

**Status: implemented source plus the limited core-UI review recorded below;
not release acceptance.** Subsequent user feedback correctly identified that
category discovery and the source/scan/identify journey were still missing from
the visible app. Those workflows were reviewed, revised and rebuilt under the
user's standing authorization for native visual review. The macOS debug build
compiles the source in this report. Reader/OCR/technical-analysis behavior has
not been exercised. No tests or analyzers were run; the separate testing process
still starts only after master-plan implementation is complete.

## New Plex-related behavior

| Finding | Tangerine implementation |
| --- | --- |
| Explicit brace/square edition markers | `CatalogHints` extracts `{edition-X}` and `[edition-X]` before cleaning titles. Labels preserve case. Existing conservative cut words remain hints; remastered is a technical representation hint. Parent folders can supply missing edition/title/year/provider hints. |
| Existing libraries must gain improved parsing | A versioned, bounded 200-item backfill rebuilds derived facets. Automatic Original editions with previously missing labels detach into the appropriate edition; shared Original rows and saved user editions are preserved. No provider match is applied. |
| Bounded multi-episode files | Contiguous SxxExx ranges/repeated E markers and NxN ranges produce `episode`/`episodeEnd`. Tangerine caps a range at 32 episodes. Inverted, cross-season, non-contiguous and oversized ranges keep the first episode rather than inventing coverage. No detected boundary or timestamp is claimed. |
| One file remains one resource | Episode ranges extend metadata/facets/transport and labels on TV cards/Details. Next/previous episode lookup avoids overlapping range representations. File IDs, progress and Study anchors remain unchanged. Metadata editing validates the final range atomically. |
| Typed extras | Exact typed folder names and explicit filename suffixes supply hints. A title containing “trailer” is not enough. Title Files suggests a detected type when the user explicitly attaches an extra; featurette, scene, short and other join the existing types. No ambiguous primary-title association is automatic. |
| Edition-specific subtitles and IDX/SUB | The player's tracks panel has **Find subtitles beside this file**. Discovery checks the media stem, bounded language/flag suffixes and edition labels; a filename-labelled cut requires a labelled companion. Folder-labelled cuts can use unlabelled companions in that folder. IDX requires its matching SUB. Explicit selection permits unlabelled files but rejects a different named edition. Saved subtitles are checked again on open. |
| Explainable candidate choice | Offline JSON results rank exact ID, exact title and title-word matches, then matching year; stable ID breaks ties. Supplied type hints narrow results. Reasons and year/type differences are visible. Weights are local sorting policy, not Plex confidence or automatic-match permission. |
| Real technical media separate from catalog | **Details → Files & versions → Technical media → Analyze file** performs local-only libVLC parsing on macOS in a separate headless instance, without playback. It stores version-2 analysis tied to the content revision: duration in seconds, codecs, encoded dimensions, orientation enum and bounded audio/video/subtitle stream data. Bitrate is bits/s, sample rate Hz and frame rate frames/s. The container string remains a filename-extension hint, not a detected demux format. |
| Technical ownership and export | Analysis checks file stats before/after and the current item revision before saving. It updates known duration without changing progress or descriptive identity. Known technical fields and nested streams are validated for backup/import and transport; native paths and error details are not exported. Failed/unsupported analysis is explicit and can be retried. |

Companion discovery is local and bounded to 2,000 folder entries, 50 displayed
results, 16 MiB text/IDX files and a 64 MiB SUB companion. It never enumerates a
remote library path on the client. Very large folders can use explicit selection.
Technical analysis is on demand; scans still create indexed placeholders. Native
parsing has a 3-second parser limit, a 4-second polling deadline and an 8-second
Dart response timeout. App-level calls are serialized; the native bridge also
rejects concurrent analysis. A timed-out native operation retains its ownership
until it unwinds. No throughput or format-coverage measurement is claimed.

## New Panels-related behavior

| Finding | Tangerine implementation |
| --- | --- |
| Raw zoom locks differ from source anchors | A validated `ReaderViewportState` records renderer/layout/fit, viewport and rendered-page geometry, raw scale/offset and a canonical focal point. The archive raster reader replays raw values only when compatible; resizing/layout changes use the focal point and clamp pan. PDF also captures/replays compatible native offsets and falls back to its source-page locator. |
| Device-specific state must not become a portable lock | `ReaderLocator` still carries the normalized source point independently. Reader/Study transport continues to omit raw view state. Old locator formats retain their top-left interpretation. PDF layout signatures are bounded hashes, including sparse pairing settings. |
| Whole-layer 300 ms backgrounds | Shared `ReaderBackgroundSurface` fades complete solid/gradient layers using `[A,A,B,B]`, rather than interpolating raw gradient colors. It holds at most two layers and retains the latest target during an active fade. Reduced motion switches immediately. |
| Background orientation and spread ownership | Archive and PDF readers sample the physical outside edges of the displayed cell, including RTL spreads. PDF samples both pages of a spread; continuous backgrounds use the vertical axis. Sampling failures never block the reader. |
| Cancelled task reuse | A rapid return to a cancelled job key starts a fresh job. Old cleanup/release checks identity before removing a replacement. In-flight bytes remain charged until asynchronous work unwinds. Shared visible-page leases remain owned. |
| Memory pressure and separate budgets | Reader observers drop speculative/background work and retained color results, while preserving visible leases and durable reading state. PDF declares a 64 MiB best-effort image-cache target, 2,000-pixel one-pass threshold and zero adjacent cache extents. Speculative archive decoding remains disabled pending measurements. |
| Disk accounting and recency | Thumbnail hits touch access recency, missing/pruned results regenerate, and macOS pruning uses allocated file bytes where available. Other platforms/resource-read failures fall back to logical bytes. The existing 64 MiB trigger, 90% target, 10-minute grace and active leases remain separate from decoded/RSS limits. |
| Image OCR is independent of native PDF text | macOS readers expose **Recognize page text** for raster archive pages and PDFs. A white-matted upright raster goes to Apple's public Vision text-recognition API on device. Native PDF search/selection and EPUB DOM selection keep their existing paths. |
| OCR coordinates, limits and lifetime | OCR lines have normalized top-left analysis-raster bounds and confidence, not PDF media-box or character-offset coordinates. Inputs are bounded to 4 MiPixels/20 MiB PNG, output to 500 lines/16,000 UTF-16 characters. Native work is single-owner and cancellable. Closing the dialog releases its scheduler lease. |
| OCR-to-Study behavior | Recognized text can be selected/copied or used as a quote in a page-linked note (up to 4,000 characters). This does not manufacture an exact native/DOM text range, deterministic OCR offset or OCR highlight-restoration claim. |

The Vision bridge uses public `VNRecognizeTextRequest` and
`VNImageRequestHandler`, as described by [Apple's image text-recognition
example](https://developer.apple.com/documentation/vision/recognizing-text-in-images).
This is a separate Tangerine tool, not a reproduction of Panels' VisionKit UI.
Raster bounds, byte estimates and cache targets are implementation limits, not
measured whole-process memory guarantees. Framework-owned PDF caches and native
OCR allocations require later measurement.

## Existing foundations retained

Earlier source work already provides named typed libraries with multiple roots,
explicit scan generations/availability, conservative full-content file identity,
separate matching/overrides/locks, editions/parts/extras, paged catalog/search,
collections, approved range streaming and library grants. It also provides
canonical reader pages, spread/square/cover pairing, RTL/tap policies, sparse
preferences, serialized durable locators and a constrained HTML/CSS publication
renderer with scoped metrics and text bridges. This pass builds on those paths;
it does not reclassify them as tested or recreate the reference apps' private
internals.

## Remaining scope and the later testing phase

The full P0–P11 master plan remains in progress. Online-provider integration,
automatic/background technical-analysis scheduling, technical analysis/OCR on
other platforms, remaining publication-platform coverage, broader MyVLC parity
and packaging are not completed by this pass. Unknown reference-app ranking,
identity-merge internals and framework internals remain unknown; no hidden Plex
thresholds or Panels private APIs are assumed.

After implementation is complete, the separate testing phase must cover:

- Parser precedence, valid/invalid dates, explicit IDs, brace/square labels,
  existing-library upgrades, user edition preservation and all range bounds.
- One-file range browsing, overlapping representations, metadata reset/rematch,
  locked fields, transport/backup compatibility and next/previous ordering.
- Subtitle language flags, edition case, filename/folder labels, missing/mixed-case
  IDX/SUB pairs, large folders, removed files and remote-library boundaries.
- Native technical parse success/failure/timeout, C/Swift track bindings,
  changed-file races, stream units, duration updates and no playback side effects.
- Reader raw-state compatibility across resize, mode/fit/direction changes,
  spread focus, revision changes, legacy locators and cross-device transfer.
- Rapid cancellation/revisit, lease cleanup, memory pressure, measured peak
  allocations, PDF cache behavior and allocated-byte pruning/fallback behavior.
- Whole-layer fade interruption, reduced motion, physical RTL edge selection,
  vertical composition and stale sampling results.
- OCR platform availability, malformed/large rasters, cancellation, timeout,
  multilingual/empty results, Unicode limits, copying and page-linked notes.

No item in this list has been executed or marked passed in this pass.

## Subsequent core-workflow correction

The user reiterated that Tangerine combines StudyStream, Plex and Panels, and
that prior decompilation must inform the actual product. This is now recorded in
AGENTS.md as a standing project instruction.

The renewed user walkthrough found a functional bug: Movies returned no items
because the filter matched declared library kinds and excluded imported Mixed
files. A versioned category facet now derives from explicit library context or
local hints, with per-title correction; the existing two imported videos appear
in Movies without being moved. Home/Libraries expose all 13 categories; Notes is
removed from primary navigation while saved/contextual notes and legacy links
are retained. Named library setup now precedes folder selection.

Category and library screens expose labelled Scan library and Identify titles
routes. The new scan dialog uses explicit source ownership and the existing
indexer, with cancellation/progress. Identification provides paged local hints,
category correction and the existing title/match editor, without pretending to
have contacted an online provider. Source-type changes rebuild category facets.

Captured UI review confirms Home/category visibility, Movies' two files, the
source/Scan/Identify entry points, local identification display and library setup.
See TANGERINE_UI_DESIGN_REVIEW_2026-10-20.md for before/after observations. No
actual rescan, metadata correction, provider match or new import was performed in
that walkthrough. Populated music/book/TV category journeys and online metadata/
artwork integration remain incomplete. The full master plan is not marked done.
