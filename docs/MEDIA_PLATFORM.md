# MyVLC + StudyStream media platform (historical baseline)

**Current execution:** Tangerine’s macOS libVLC integration, rebrand and import
preview are now implemented. See `TANGERINE_IMPLEMENTATION.md` for current results
and outstanding roadmap work. The remaining sections below describe the earlier
Flutter/media_kit baseline, not the current native engine.

**Scope correction, 18 October 2026:** this document records the existing
Flutter/media_kit implementation and its earlier verification. That is an
incomplete implementation of the user's requested MyVLC-led merge. The user
clarified that MyVLC's libVLC engine and functional workflows must remain at the
forefront. `TANGERINE_UPDATE_PLAN.md` now prioritizes that engine integration,
feature preservation and MyVLC data migration. No runtime engine change is
claimed by this documentation correction.

The product is one application that can act as a player or a server on each
native device. MyVLC is the visual foundation; StudyStream's learning features
are part of the media application. The original Swift MyVLC repository at
`/Users/satwikpallerla/Documents/ChatGPT/MyPlayer` remains untouched.

## Shared implementation

Flutter renders the MyVLC interface on macOS, Windows, Linux, Android, and iOS.
The macOS-only SwiftUI application cannot supply a shared UI on those platforms.
The merged application retains media_kit as its portable native playback backend
and pdfrx for documents. It does not require an installed VLC application.

MyVLC's charcoal/orange palette, compact corner radii, media cards, category
filters, grid/list browsing, navigation, and 0.25×–4× playback speed are carried
into the common app. Saved appearance preferences continue to apply; dark mode
is the default for devices without a preference.

StudyStream library indexing, identity/relinking, completion, reading position,
notes, bookmarks, search, backups, and companion synchronization remain in the
same database. There is no schema migration or app ID change. Verification uses
synthetic fixtures and isolated databases; no personal media was imported for
testing. The macOS product is named MyVLC.app.

## Roles and server setup

`DeviceRuntime` owns the selected device role and startup behavior. Configuration
is saved as `sync.deviceConfiguration`: the sync transport omits settings and
backup restoration skips `sync.*`, so another device or an old backup cannot
turn a server on. A failed bind does not commit a new configuration. Concurrent
server starts share one operation; TCP binds are exclusive.

Selecting Server opens setup rather than immediately opening a port. The user
names the server, chooses a port (45831 by default; 0 allocates one), adds a local
library or individual files, and explicitly starts it. Runtime controls expose
its addresses, expiring code, approved players, revocation, and stop action.
Stopping explicitly disables restart-on-launch. Switching to Player stops the
server and preserves the media catalogue and learning records.

`LanSyncServer` continues to own pairing, hashed tokens, discovery, media path
validation, HTTP byte ranges, and study synchronization. Discovery retains its
existing wire protocol identifier for compatibility and adds the configured
display name. Only locally imported library records are advertised by the host;
mirrored remote catalogues are excluded. All local libraries are shared with
approved devices; per-library access controls are not implemented.

Individual-file imports stream into temporary files in application storage,
validate the copied length, rename on success, and then index the managed root.
Duplicate filenames receive a suffix. Source files are retained; failed copies
do not leave playable partial files. Desktop folder imports keep their original
file locations and existing macOS security-scoped access.

## Browser player

The native server serves the browser player at `/`. The browser uses the same
pairing and catalogue endpoints as native clients. An HttpOnly,
SameSite=Strict cookie authorizes media elements and their byte-range requests;
tokens are not embedded in media URLs or stored in JavaScript storage. Bearer
authorization remains supported for native players. `/v1/logout` revokes that
browser's device token and expires its cookie.

The browser filters video, music, documents, and collections, streams media,
restores position, serializes progress writes, and adds timestamped notes and
bookmarks to the same server database. Text previews are bounded to 2 MiB and
render as text. HTML media responses carry a restrictive sandbox CSP. Browser
media cards and notes use textContent rather than interpolated HTML.

The browser UI caps displayed cards to 240; native browsing caps its SQL query
to 120. Search/categories narrow the results. Catalogue transport retains the
existing 10 MiB snapshot limit; pagination/delta sync is a later requirement.

## Platform boundaries and remaining work

| Area | Current behavior |
| --- | --- |
| Desktop native apps | Shared player/server source; leave the application open and machine awake |
| Android/iOS | Shared player/server source; durable individual-file import; foreground hosting |
| Browser | Player served by the native server; no browser-side server mode |
| Video/audio | Direct streaming; native media_kit or browser codecs; no server transcoding |
| PDFs | Native pdfrx reading; browser uses its built-in PDF viewer where available |
| Network | Authenticated, unencrypted HTTP on a trusted private LAN; optional UDP discovery |
| Background operation | No headless daemon, Android foreground service, or iOS background hosting |
| Windows/Linux | Native source retained; builds and physical behavior require their own hosts |

The original MyVLC engine-specific features still require portable implementation:
named playlists and queue parity, effects/equalizer, recording and conversion,
capture, casting, global shortcuts, mini-player/PiP, add-ons, and advanced
preferences. The Swift implementation is a reference for those ports rather
than a second application bundled inside the Flutter app. Automatic migration
of MyVLC's `library.json`, subtitle assignments, preferences, and playlists is
not implemented. Existing source folders can already be imported without moving
their media. This change establishes the unified product, UI foundation, roles,
server setup, and player access; it does not claim full legacy MyVLC parity.

## Verification

Verified on 18 October 2026. The previous StudyStream validation remains in
`VALIDATION.md` as historical evidence.

| Check | Result |
| --- | --- |
| Dart formatting | Pass |
| `flutter analyze --no-pub` | Pass; no issues |
| `flutter test --no-pub` | Pass; 73 unit/widget tests |
| Native macOS integration journey | Pass; real audio decode/seek, disk reopen, PDF render/page changes, role choice and populated catalogue |
| `flutter build macos --debug --no-pub` | Pass; `build/macos/Build/Products/Debug/MyVLC.app` |
| `flutter build apk --debug --no-pub` | Pass; `build/app/outputs/flutter-apk/app-debug.apk` |
| `flutter build ios --simulator --no-pub` | Pass; `build/ios/iphonesimulator/Runner.app` |
| Browser JavaScript syntax | Pass; Node syntax check |
| `git diff --check` | Pass |

New automated coverage checks role persistence, opted-in restart, explicit stop,
switching to Player, occupied ports, backup isolation, copy durability, duplicate
filenames, concurrent imports, partial-copy cleanup, concurrent server starts,
cookie authentication, byte ranges, browser study writes/logout/revocation, and
the exclusion of mirrored libraries from a host's catalogue. Setup and the mode
chooser are checked at 320, 430, 768, and 1280 logical pixels with 1.7× text.

Interactive verification used only synthetic audio/PDF fixtures and the isolated
`STUDYSTREAM_DATA_DIR=myvlc-merge-verification` database. Through the native UI,
selected Server, imported fixtures, started hosting, and viewed the address and
code. Through the browser, paired, streamed real audio, saved a positioned note
and bookmark, reloaded to verify persistence, and disconnected. Then stopped the
server, switched to Player, and verified the browser note in native Study.

Evidence and logs are under `.verification/myvlc-merge/`. Browser inline PDF
rendering was not verified in the in-app browser; an external PDF link and the
verified native reader are available. Physical mobile hosting/pairing, real
video formats, Windows/Linux builds, and background operation still need their
own acceptance checks. Xcode emitted an outdated simulator-runtime warning, but
both macOS and iOS simulator builds completed. Existing media_kit Swift Package
Manager and Android toolchain deprecation warnings remain.

The native integration now waits for visible PDF page labels and scrolls the
onboarding button into view in a small desktop window. Earlier test runs exposed
those timing/visibility assumptions; they are not recorded as passing runs.
