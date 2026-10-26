# Advanced MyVLC workflows — 26 October 2026

## Findings before design changes

Source review using Graphify and the original MyPlayer source; no screenshot or
runtime journey review is claimed. The current settings/player surfaces expose
transport, effects, outputs and queues, but lack a place to open a live input,
manage saved network streams, configure subtitle accounts, or manage add-ons.
The original capture/disc, subtitle, JavaScript API, JSON skin and control order
sources remain implementation references. Lua extensions and VLC .vlt skins are
not compatible with the original app either.

## Design to implement

- A discoverable Advanced player entry from Settings and the player. Tabs separate
  Open inputs, Subtitle service, Accounts/proxy, and Customization.
- Network streams have explicit Open and Save actions, rename/remove, read-only
  MyVLC library preview/import and credential-free URL validation.
- Capture and discs have native capability gates, device/permission feedback,
  explicit Start/Stop, live preview, recording and navigation. Never start capture
  on page entry. Camera/mic permissions belong to the OS; unsupported targets say so.
- Subtitle searches are deliberate, paged and language-scoped; show results before
  a quota-consuming download, then attach and persist for the selected title.
- Secrets use OS credential storage, never ordinary settings, backups or logs.
  Scrobbling is opt-in; proxy settings apply when a player is created.
- Add-ons are imported disabled and explicitly enabled, with a bounded transport
  API. Skins are validated MyVLC JSON colors. Control-strip order/visibility is
  persisted with always-available play/pause and exit.

Implementation and verification evidence will be appended after changes.

## Implemented workflow and ownership

Settings → Advanced player workflows and the library player's Advanced button
open the same four-tab screen. The track picker also links directly to online
subtitles; the shared strip links directly to customization. Contextual Study
controls and saved progress/notes stay in the library player.

- **Inputs:** explicit open, name/save, select to edit, remove, and read-only
  MyVLC library.json remote-entry preview/import. Stable URL identities prevent
  duplication. Query URLs are stored in OS credentials; only their base URL is in
  ordinary settings/backups. Restored signed streams require re-entry on machines
  without the vault secret. Embedded username/password URLs and fragments are
  rejected. The importer does not open streams or grant source/server access.
- **Capture:** retained AVFoundation session, serial device operations, requested
  camera/mic permissions, preview and audio-only capture, user-selected MOV
  recording destination, finish reporting/reveal and stop on window close.
  Generation guards stop permission/start races from leaving hidden capture.
  Screen capture uses the original screen:// input and explicit OS screen consent;
  it can use the existing record/output job controls.
- **Discs:** readable folder/image/device input with DVD menu/no-menu, Blu-ray,
  Audio CD and VCD modes. Uses the installed VLC modules; menu direction/activate/
  popup commands, title selection and chapter selection call the real libVLC API.
  Input readiness is bounded to 15 seconds; Stop disposes the independent input
  engine and its outputs.
- **Subtitles:** original OpenSubtitles endpoint/response model, OS-stored API
  key/token, deliberate query/language/page requests, named result files and
  accessibility/download facts. Download confirmation explains quota use. The
  HTTPS download host is restricted to opensubtitles.com, redirects are rejected,
  service credentials never accompany the download, JSON is bounded to 2 MiB and
  SRT to 10 MiB, and requests/body reads have time limits. Validated UTF-8 SRT files
  attach to the active title and persist in the existing subtitle assignment path.
- **Accounts/proxy:** opt-in original libVLC audioscrobbler and HTTP proxy options
  are now activated at native engine creation. Usernames/endpoints are separate
  from Keychain passwords; secrets use new Tangerine-scoped accounts, not an
  automatic read/import of original application accounts. Saving, preserving a
  blank secret, disabling and disconnect/clear are explicit. Changes apply to new
  playback instances. Existing players are unaffected by editing credentials.
- **Add-ons:** import disabled, review source, enable/disable, run once and remove.
  Playback-start runs receive the original transport API and optional onPlay.
  Execution uses a disposable nonpersistent WebKit Worker with no native/filesystem/
  shell/network bridge, a two-second worker watchdog, three-second native watchdog,
  256 KiB source/20-script/64-command limits and a concurrency cap. Transport
  commands are range-checked on the native actor. Failed startup scripts disable
  themselves and do not make ordinary playback fail. This deliberately supports
  synchronous startup/onPlay scripts; long-lived asynchronous add-on events are
  outside this bounded contract.
- **Customization:** original six-digit MyVLC JSON color keys map to player
  canvas/panel/chrome/track/accent/text/muted/divider surfaces. Persisted control
  groups can be added/hidden/reordered/reset; Transport stays available. Audio,
  video and independent network/disc/screen inputs use the shared strip. Existing
  speed, Study, track and output menus remain discoverable. Library category design
  stays authoritative outside playback.

## Capability and acceptance boundaries

Camera/mic/screen/disc, JavaScript execution, Last.fm and authenticated playback
proxy activation currently use the **macOS** adapter. Other platforms display
that capability boundary. HTTP/HTTPS stream workflows, saved stream migration,
subtitle search/download/assignment, JSON skins and control-strip persistence use
portable Dart. Additional network protocols currently use the macOS bridge.
VLC Lua and .vlt formats remain unsupported as in the original app.

The original audioscrobbler implementation is retained, including its native
service protocol. This is not a claim of a new modern Last.fm API adapter, live
account authentication, accepted submissions, protected-disc compatibility or
cross-platform capture parity. Device/permission, subtitle quota/authentication,
proxy server and Last.fm acceptance need the relevant hardware/accounts. No
capture, credential submission or external service request was performed merely
by opening/building the app. No screenshot review or automated feature tests were
performed during this implementation pass.

References: original MyPlayer UtilityViews.swift, SubtitleWorkflows.swift,
Addons.swift, ControlStrip.swift, Theme.swift and Preferences.swift at the source
location recorded in MYVLC_FEATURE_MATRIX.md; installed VLC 3 C headers;
[OpenSubtitles API](https://opensubtitles.stoplight.io/docs/opensubtitles-api),
[Last.fm authentication](https://www.last.fm/api/authspec) and
[scrobbling protocol reference](https://www.last.fm/api/scrobbling).

## Executed build evidence

Final `flutter build macos --debug --no-pub`: **exit 0**, built Tangerine.app.
`codesign --verify --deep --strict`: **exit 0**.
`flutter run -d macos --debug --no-pub --no-resident`: **exit 0**, application
initialization and file synchronization observed. Existing upstream plugin/SPM
notices, deprecated native API warnings and an early desktop_multi_window engine
message remain documented in TANGERINE_MACOS_BUILD_VERIFICATION_2026-10-25.md.
These are build/startup checks, not device/account/feature acceptance tests.

Graph maintenance: the CLI incremental update protected existing README semantic
aliases instead of overwriting them. The project mapper then preserved the research
nodes and completed the source/configuration/evidence refresh (8,550 nodes, 18,113
edges; 917 source files and 2,492 evidence files). AST-only maintenance used no
external API. Existing C-header/Gradle parser limitations are not compiler results.
