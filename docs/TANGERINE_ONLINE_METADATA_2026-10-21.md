# Online identification and artwork — 21 October 2026

## Findings saved before design changes

Native user-role review followed Home → Movies → Identify titles → Review title
& match → Offline catalog match. Screenshot:
`.verification/online-metadata-2026-10-21/match-before.png`.

- Identification is discoverable, but the editor opens manual fields first.
- Matching requires the user to manufacture/open a JSON file. Search is disabled
  otherwise; there is no provider choice, credential setup or network feedback.
- Candidates have no artwork previews and the confirmation identifies every
  source as local JSON. A user cannot get a poster or online description.
- Mixed-library imports need the resolved category, not just library kind, to
  choose a provider. TV episode hints must survive selection of a show.

## Design and implementation decision

Keep manual fields and offline catalogs. Make Find match the first editor tab,
with category-appropriate provider selection, editable query/year/episode hints,
explicit search, candidate preview and explicit apply. Show source attribution
and links in previews and saved details. Keep locked edits, media identity,
progress and StudyStream notes. No scan-triggered upload or automatic match.

Providers: TMDB movies/TV (user's read-access token in secure storage), TVmaze TV
(no key), Open Library books/comics/audiobooks (no key), MusicBrainz music (no
key) with Cover Art Archive. Personal media and unsupported types keep manual
and offline options. No invented online catalog for private courses/photos.

API references: https://developer.themoviedb.org/docs/faq,
https://developer.themoviedb.org/docs/image-basics,
https://www.tvmaze.com/api, https://openlibrary.org/dev/docs/api/search,
https://openlibrary.org/dev/docs/api/covers,
https://musicbrainz.org/doc/MusicBrainz_API,
https://musicbrainz.org/doc/Cover_Art_Archive/API.

Plex reference: docs/PLEX_TARGETED_DECOMPILATION.md, Metadata matching and
correction. Search and applying a candidate remain separate; no private ranking
threshold is inferred. Selected metadata is a snapshot; sparse locked fields
retain precedence. Artwork is a bounded derived cache, separate from media.

## Evidence boundary

The screenshot above establishes the pre-change UI. Source implementation and
any later visual review are recorded separately below. Automated tests,
analyzers and runtime acceptance remain deferred by the user's execution order.

## Interrupted WIP checkpoint

The user requested “stop and commit” during implementation. Provider adapters,
secure-token setup, candidate previews, explicit selection, metadata URL
validation, attribution, bounded artwork caching and hosted artwork integration
have been written. They have not completed post-change visual review or live
provider acceptance. This is not a completed feature or a release checkpoint.

Resume with source review and completion, including TMDB's required approved
logo in credits, provider response/error edge cases and artwork refresh/fallback
behavior. The UI-review build failed while resolving Xcode Swift Package Manager
dependencies, before confirming compilation. No successful build is claimed for
this source. No tests or analyzers were run.

## Resumed implementation

- Find match is the initial editor tab. Mixed-library items use their resolved
  category. Provider choice, query/year, explicit search, no-result feedback,
  preview and apply are wired to the existing revision-guarded match store.
- TMDB supports movies and TV, including exact episode details. The user's
  API Read Access Token is stored with flutter_secure_storage, never in database
  settings, URLs, snapshots, backup or sync. No shared token is bundled. Setup is
  reachable from matching and Settings → Metadata providers & credits.
- TVmaze provides key-free show search and exact episode lookup. Shared episode
  files retain the declared range; the preview identifies descriptions as those
  of the first episode. No episode timestamps are invented.
- Open Library provides book/comic/audiobook work search, author, first publish
  year, work description and available cover. This identifies the literary work;
  it does not claim to identify a particular narration, chapter or comic issue.
- MusicBrainz searches recordings and retrieves annotation/genres. The preview
  lets the user choose among up to 20 returned releases for album/cover, or keep
  recording-only details. Release-specific snapshot identities avoid one album
  choice overwriting another recording match's album. Covers use CAA; unavailable
  annotations/covers are explicitly empty, not invented.
- Personal/unsupported categories retain manual fields and local JSON catalogs.
  This pass does not claim podcast, photo or course provider coverage.
- Selected snapshots include source URL and attribution. Details displays the
  attribution and source link. TMDB's approved unmodified logo and required
  notice appear in credits; the logo source is documented in assets/brand/README.md.
- Artwork is downloaded through an HTTPS host allowlist, bounded to 2 MiB and
  decoded at most 600×900 from sources at most 32 MP. The 100 MiB derived disk
  cache excludes active leases from eviction and refuses additions if occupied.
  Downloads/decode are serialized and queued admission is bounded. Failure uses
  local art. Preview retry and Edit details → Artwork source are available.
- Browsing/details resolve selected artwork reactively; originals and
  Items.thumbnailPath remain intact. Clearing a match restores filename/local
  artwork, subject to retained user overrides. Hosted artwork uses the same
  approved library scope and normalized PNG output. Credentials are not hosted.
- Network requests have connection/overall timeouts, body limits, manual bounded
  redirects, per-host pacing and rate-limit cooldown. Known CAA HTTP redirects
  are upgraded to HTTPS before any request. Authentication is only sent to TMDB.

Source review corrected the MusicBrainz `annotation` include, TV search-year
semantics, malformed detail ownership checks, reactive artwork invalidation,
secure-storage feedback and partial-file cleanup. Formatting completed. A native
UI build succeeded after dependency resolution was retried; the final visual
review and its limits are recorded below when captured.

## Separate testing phase

No automated tests or analyzers have run. Later acceptance must cover real
TMDB credentials/authentication, each provider's live responses/rate limits,
network interruption, apply/rematch/clear and field locks, artwork refresh and
eviction, backup/transport compatibility, hosted permissions, Unicode and
malformed metadata, supported devices and concurrent screen ownership. The
implementation does not claim those gates passed.

## Visual review findings before final corrections

The rebuilt native app opens Find match by default and selects Open Library for
the existing comic. A read-only search for Fire Punch displayed multiple real
volumes with authors, years and downloaded covers; Vol. 7's preview displayed
its cover and attributed source. That record supplies no work description, and
the preview honestly reports this. The preview was cancelled; no match, field
edit, credential or progress mutation was applied in this walkthrough.

Two follow-up design findings were saved before correction: editing the query
left the previous results visible, and flutter_svg rendered TMDB's CSS-class
fill as black. Clear candidate results when search fields change. Normalize
that SVG class fill to the identical gradient presentation attribute, preserving
TMDB's geometry, proportions and approved colors. Screenshots:
`match-after.png`, `candidate-preview.png`, `provider-credits-first-pass.png`
in `.verification/online-metadata-2026-10-21/`.

## Final visual coverage

The final native macOS debug build succeeded and was launched. Settings →
Metadata providers & credits is discoverable, shows the empty-token setup state,
and now renders TMDB's approved green/blue gradient correctly. Captured in
`provider-credits-final.png`. No credentials were entered or saved. Search input
changes clear previous candidates in source; this is not a regression-test claim.

The Open Library candidate/cover preview is direct visual evidence of a real
online response. Its missing synopsis is a provider coverage limitation, not
substitute text. TMDB authentication, TVmaze episodes, MusicBrainz release/CAA
selection, persistence/rematch/clear/locks, hosted-client refresh and resource
budgets remain source implementations pending the separate acceptance phase.
The final source also uses per-title category corrections for provider routing,
refreshes visible artwork after explicit apply, and includes match revisions in
remote artwork job identities. Graphify maintenance was run after code changes.
