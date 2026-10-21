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
