# Panels reader and background investigation

Investigation date: 18 October 2026. Target: Panels 3.13.8 (974), bundle
`es.produkt.app.panels`, installed at `/Applications/Panels.app`.

This is a completed first pass of static inspection and controlled reader tests.
It is **not a full recovery of Panels' native implementation**. Background below
covers both visual reader backgrounds and library/indexing work. Application
source files in StudyStream were not changed.

**1. Scope and method**

REA inspected the shipped executable, property list, signature, dependencies and
Objective-C dispatch metadata. Native UI automation exercised synthetic media,
reader settings, direction changes, closing/reopening and a normal app restart.
An independent static resource pass inspected packaged localizations, model
metadata and EPUB JavaScript. No software was installed or signing changed.

Created an isolated external library for
`/private/tmp/tangerine-panels-20261018`. It contains two synthetic CBZ files, a
synthetic fixed-layout EPUB and a copy of this project's synthetic PDF fixture.
No existing comic was opened for playback/reading tests or renamed/moved.
The test library and its generated cache remain available for inspection.
No account connection or purchase flow was performed. The inspected app may
perform its own normal network activity; no network capture was collected.

Evidence is retained in `.verification/panels-rea-20261018/`, including fixture
hashes, REA exports, screenshots, accessibility captures and generated cache
files. Runtime screenshots/accessibility observations are native UI observations,
not REA native-call traces. The evidence manifest records exact file identities.

**2. Target identity and REA coverage**

The universal executable SHA-256 is
`c27578f21eb30a921491c03c98a644696c5efc91a24e2448419da67e66ef16d7`.
REA's Mach-O inspection reports x86_64 and arm64 slices, and the selected arm64
build metadata identifies `MACCATALYST`.

| Inspection | REA Evidence ID |
| --- | --- |
| Mach-O identity, dependencies and build metadata | `ev_ec56d60cb3655dfa45ce4e44a3c83115720f38ab529962a6b3107739e7f5256e` |
| Info.plist and registered formats | `ev_4c86b6d9cf9a73d086a1f8df219e2daadf2293dbc2c6dcdf7d8f94ef76138e4e` |
| Signature and entitlements | `ev_b57dbf159e02fc7e0c7f0b53434647cb1f5cccb2282c079c8076c04e07c432dd` |
| Partial dispatch metadata from the derived arm64 slice | `ev_c61cf43b9ffbe020a6e7206f555da3024e332e185ea4dc3e7a2c80da58e96dd8` |

The universal file exceeded REA's 64 MiB static metadata input budget. A faithful
arm64 slice was produced with Apple's `lipo`, without modifying the installed
app. Its SHA-256 is
`9a75cdc1b6196a9d5d55c5f16c55c14a024dfbcec4950cfc854725d5a351d7dc`.
REA completed a bounded metadata inspection of that slice. The result exceeded
the MCP response budget, so the complete retained record was exported instead
of rerunning the inspection.

The metadata inspection reached its 20,000-record budget. Returned Objective-C
metadata is partial; generic/resilient Swift dispatch is not decoded, and some
ivar offsets are unresolved. Symbol or field absence cannot establish absence
of a feature. No deep provider is configured. The signature reports hardened
runtime and `get-task-allow=false`; no debugger attach or native call tracing was
performed. All opened REA native sessions were closed after evidence export.

**3. Confirmed reader behavior**

| Controlled test | Observed result | Saved observation |
| --- | --- | --- |
| CBZ discovery and open | Four pages counted and rendered | `controlled-library-four-formats`, `reader-thumbnails-natural-order` |
| Natural page ordering | Archive entries written as 1, 10, 2, 3 display as 1, 2, 3, 10 | `reader-thumbnails-natural-order` |
| Direct page selection | Selected thumbnails open the corresponding fixture pages | Reader captures |
| Close/reopen | Page 4 of 4 restored | `reader-reopen-restored-position` |
| Reverse toggle at page 2 | Current page stays 2; thumbnail strip reverses | `rtl-baseline-before-toggle`, `rtl-after-toggle` |
| Reverse-mode forward navigation | Left Arrow advances page 2 to page 3 with reader focus | `rtl-after-left-key` |
| Full restart | Normal Quit confirmed the app stopped; reopening restores page 3 and reversed thumbnails | `rtl-restored-after-app-relaunch` |
| Reverse-mode backward navigation | Right Arrow returns page 3 to page 2 | `rtl-after-right-key` |
| Fixed-layout EPUB | Two-page synthetic EPUB counted; first page visibly rendered | `fixed-layout-epub-rendered` |
| PDF | Three-page synthetic PDF counted; visible page text rendered | `pdf-rendered` |
| Vertical preset | Built-in Vertical Scroll preset scrolls to PDF page 2 | `pdf-vertical-scroll-page2` |
| Vertical configuration | Continuous transition, Vertical axis, One page, Fit, right-side scrobbler | `pdf-vertical-scroll-configuration` |

Each observation name identifies a `.png` and/or `.ax.txt` under the artifact
directory's `evidence/` folder. Accessibility traversal can list the current
thumbnail first, so visual ordering is corroborated with screenshots rather
than inferred solely from accessibility node order.

The library's settings expose a default reading direction, which remained Left
to Right while the test title retained its reverse setting. This supports a
library default plus a saved title override. The reverse command was disabled
while testing the Continuous/Vertical PDF preset; its availability depends on
the active reading mode. Touch gestures, double-page pairing and cross-device
direction sync remain unverified.

Reader settings expose animation, keeping the display awake, drag-to-close,
reading time, filters, cursor hiding, paginated/continuous readers and gesture/
zoom configuration. Visibility of a control does not establish that every
option was exercised. Panels View, Live Text and subject-detection commands
were disabled in the tested reader menu.

**4. Confirmed visual backgrounds**

The reader offers White, Black and Dynamic backgrounds. Dynamic has Single
Color and Immersive choices. A second CBZ fixture uses an orange gradient that
reaches every edge, followed by a blue gradient, avoiding uniform white borders
that would conceal differences between the modes.

- Single Color fills the two margins with one orange tone.
- Immersive displays different red/yellow tones on the left/right margins,
  matching the corresponding sides of the orange page visually.
- Selecting the blue page changes the background to blue tones.
- Reopening configuration shows Dynamic retained for the tested title; a new
  title initially showed the Standard preset's Black setting.
- The UI offered applying the configuration while separately displaying
  "Subscribe to save preset". No subscription action was taken. This observation
  does not establish entitlement policy for every reader feature.

Evidence: `probe-single-color-applied`, `probe-immersive-applied`,
`probe-immersive-page2`, plus the background fixture manifest. Earlier captures
of the white-bordered comic are retained, but the colored-edge probe is the
stronger comparison.

The exact color sampling, dominant-color selection, interpolation, caching and
animation algorithms were not recovered. Executable strings include average-
color/cache and dynamic-background names. These are clues, not call-site proof.

**5. Library storage and background work**

Adding the fixture folder created a second external library. New fixtures placed
in it appeared with page counts without another file-picker import. Inspection
did not isolate polling from filesystem events or navigation-triggered refresh,
so no exact scheduling mechanism or interval is claimed.

Panels created `.Panels/geometry` and `.Panels/thumbnails` inside the synthetic
source folder. Eleven generated files were sampled and copied individually:
three geometry JSON files and thumbnail/poster JPEGs for all four titles.
The JSON for the four-page CBZ contains:

- `comic_id.type = file_sha256_hash` and a value equal to the independently
  calculated SHA-256 of that CBZ;
- a versioned pages array with zero-based indices, width, height and placeholder
  fields;
- a landscape third page matching the fixture's known orientation.

Some cached dimensions are 666 by 1000 for source images of 600 by 900. They
must not be assumed to be original source-pixel dimensions. This was a sample
of generated metadata, not a complete reader-state audit. Individual files were
read whole; no atomic directory snapshot or live database snapshot is claimed.

The partial native metadata declares a Realm-backed `LibraryIndex` with path,
parentPath, name/sortableName, page count, scan dates, metadata-generation keys,
reading progress and several identity fields. `ReadingSessionDAO` separately
declares current/total page, reading direction, reading time, completion date,
reader-configuration JSON, filter/transformation JSON, offline-session data and
local/remote identifiers. These are compiled property declarations, not sampled
database rows or proof of the matching/conflict-resolution algorithm.

macOS denied access to the app's Application Support container. No permission
bypass or Full Disk Access change was attempted. Initial bounded file listings
returned no database files; that is an access limitation, not evidence that the
app has no database.

Packaged strings describe separate indexing, thumbnail/metadata generation,
least-recently-used caches, protected progress and offline downloads. Those
policies were not stress-tested or verified through cache eviction. Absence of
iOS background-mode keys does not rule out asynchronous work on macOS. Hosting
after app exit and background cloud sync were not tested.

**6. Other packaged evidence and its limits**

The property list registers CBZ/ZIP, CBR/RAR, CB7/7z, CBT/TAR, PDF and EPUB.
Only CBZ, the synthetic PDF and the fixed-layout EPUB were opened in this pass.

The bundled panel model's metadata declares panel bounding boxes, confidence
and nonmaximum suppression. UI resources name multiple detection engines. No
active engine, detection quality, panel reading order or inference runtime was
verified. Packaged EPUB JavaScript contains concrete fixed-layout scaling logic,
but the exact rendering path exercised by this fixture was not traced.

A shipped `PLAN-WebServer-Rewrite.md` is an engineering proposal. Its proposed
FlyingFox implementation must not be reported as implemented. Cloud, SMB,
WebDAV, OPDS and web-uploader resource declarations were not authenticated or
tested. See `packaged-resources.md` in the artifact directory for source paths,
hashes, contradictory legacy/current strings and narrower coverage details.

**7. Consequences for Tangerine**

These are independent design decisions informed by the evidence:

1. Make comics/manga a first-class library type and reverse reading an initial
   acceptance requirement. Separate canonical page identity from presentation
   direction; never reverse the underlying file list destructively.
2. Store a library default and explicit per-title direction override. Preserve
   page, direction and configuration across reopening, restart, backups and sync.
3. Support paginated horizontal reading and continuous vertical reading as
   separate modes, with deliberate behavior for gestures and keyboard input.
4. Add a common page-source abstraction for archive images, PDF and fixed-layout
   EPUB, with format-specific renderers and stable reading locators.
5. Cache thumbnails, geometry and optional page colors separately from progress.
   Cache deletion must not remove reading state. Existing source folders should
   use internal cache storage by default; a beside-media cache can be optional.
6. Add simple and immersive backgrounds using an independently implemented color
   pipeline. Keep panel detection as a separate capability until verified.

**8. Investigation status**

| Question | Status |
| --- | --- |
| Supported registration and selected format opening | Answered for the controlled formats; other registrations untested |
| Reverse navigation, thumbnail direction and restart persistence | Answered for the macOS paginated CBZ test |
| Single-color versus immersive output | Answered visually for the controlled gradient |
| Continuous vertical PDF reading | Answered for the built-in preset and fixture |
| Cache location, selected geometry and content identity | Partially answered from generated fixture files |
| Indexing scheduler, eviction and background execution | Partially answered; mechanisms unverified |
| Exact color, panel detection and page-grouping algorithms | Unresolved; native decompiler/call-site evidence needed |
| Database state, conflict resolution and cross-device sync | Unresolved; container access/runtime evidence needed |

The Tangerine update plan should use the confirmed behavior while retaining
these unresolved questions. It must not describe this pass as full native-source
recovery or complete Panels parity.


**Native decompilation follow-up (19 October):** [REA/Ghidra findings across the seven remaining priorities](PANELS_NATIVE_DECOMPILATION.md), with pseudocode, exact evidence references, and unresolved questions.
