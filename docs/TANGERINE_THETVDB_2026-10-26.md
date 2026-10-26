# TheTVDB setup — 26 October 2026

## Pre-change visual review

Reviewed the running macOS Tangerine app before implementation. Evidence:
`.verification/thetvdb-2026-10-26/providers-before.png` and `matching-before.png`.

- Movie Find match offers TMDB and Offline JSON only. TMDB is selected but has no credential, so the public project key created for TheTVDB cannot be used.
- Provider setup leads with a personal TMDB token and has no TheTVDB configuration or credit.
- Matching already offers candidate review before applying metadata, preserving the file and contextual Study state. Keep that interaction and add TheTVDB as the default for new movie/TV matches, respecting existing saved decisions.

## Implementation intent

Add TheTVDB v4 application login, bounded authenticated search/detail requests, movie/series and official-order episode identity, allowed artwork/source URLs, keychain credential management and attribution. Configure this device with the issued project key. Never include keys or bearer tokens in metadata, backups or sync.

Reference: Plex targeted findings and native catalog API establish descriptive identity separated from physical assets and user state, explicit candidate selection and field locks. Panels deep findings preserve reader positions and bounded artwork ownership; no reader behavior changes are needed here. Provider protocol comes from TheTVDB's public v4 OpenAPI specification, not recovered Plex private behavior.

## Evidence boundaries

Pre-change visual coverage: provider setup and movie matching/provider picker. TV and candidate paths are source coverage until reviewed. Tests/analyzers and runtime acceptance remain deferred by project execution order. Startup/hot reload for design review is permitted.

## Embedded application key

User explicitly requested the project key embedded in the app. `CatalogCredentials`
reads the compile-time `THETVDB_API_KEY` first; the keychain field is a fallback for
unconfigured development builds. Bundled builds show “Included with Tangerine ·
no setup required” and hide key entry/removal controls.

Use `python3 scripts/flutter_with_tvdb.py run -d macos --no-pub` or
`python3 scripts/flutter_with_tvdb.py build macos --release`. The wrapper reads
ignored `.env.tvdb.local`, writes owner-only ignored `.dart_tool/tvdb-build.json`,
and supplies Flutter's `--dart-define-from-file`. It supports other Flutter build
targets too. Future release jobs must supply that same project define through
this wrapper or their private build configuration; plain Flutter builds without
a define do not contain the key. Application keys embedded in binaries are
extractable. No key value is committed or included in this report.

Additional visual finding saved before editing the Settings entry: its subtitle
still said “TMDB setup”, although providers now include TheTVDB. Evidence:
`.verification/thetvdb-2026-10-26/settings-entry-before.png`.

## Implementation and design-review result

Implemented v4 login with memory-only expiring bearer tokens and shared in-flight
login; bounded/paced HTTPS requests, rejected credential-bearing redirects,
provider-neutral access errors and token invalidation on authorization refusal.
Added typed movie/series search, selected extended details, English overview
selection, credits/genres/artwork, exact official-order episode lookup and
first-episode description semantics for a shared file. Metadata persistence uses
the existing validated match/override transaction and source attribution.

The macOS debug app compiled and started using the wrapper and embedded key.
Post-change visual review confirms TheTVDB is selected for the existing cleared
movie's Find match screen; provider settings show the included-key status with
no TheTVDB entry field, plus attribution and source links. Screenshots:
`providers-after.png` and `matching-after.png` in the evidence directory above.
TV episode lookup, real API authentication/search/detail responses and applying
matches remain source implementation only; no acceptance claim is made.
No tests or analyzers were executed. Startup compilation and hot reload were
used only for the authorized design review. Existing Flutter startup logs include
a multi-window invalid-engine message and foreground warning; the app rendered
and both reviewed screens were accessible. Graphify was updated after changes.

## Focused live identification check

User explicitly requested checking movie identification and metadata, authorizing
this focused live check despite the general deferral. In the running embedded-key
app, the original `Spider-Man Brand New Day` / 2026 query returned no candidates.
A broader `Spider-Man` query without year returned multiple movies; opening
Spider-Man (2002), movie/301, loaded its synopsis and poster successfully.
Searching `Brand New Day` without year found **Spider-Man: Brand New Day (2026)**,
movie/135896. Opening that candidate fetched the film synopsis and displayed its
poster. Correct-film evidence: `live-brand-new-day-metadata.png`; control preview:
`live-movie-metadata.png` in the evidence directory. This verifies app-side
embedded credential authentication, candidate search, selected details and image
delivery for these movies. Search tolerance for the original filename-derived
full title remains limited. No match was applied, so persistence, rematching,
episode handling, and the full library journey are not covered by this check.
A direct bounded provider response inspection also confirmed successful login
and movie search; credentials were not printed. No source code was changed and
no automated tests/analyzers were run in this check.
