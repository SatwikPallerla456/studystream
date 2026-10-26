# Browsing, Search and organization — 25 October 2026

## Findings saved before design changes

Source-only screen/journey review, scoped through Graphify. The user cancelled
screenshot review. No tests, analyzers, builds or runtime journeys were run.

1. Global Search calls the old capped searchAll query against item/path/context
   text. Catalog titles, creators and tags already have an FTS index, but this
   screen does not query it. Result kind/sort are applied to an already capped
   list, with no category, named-library or continuation controls. Notes and
   bookmarks must remain searchable with their saved locations.
2. Specialized category screens group shows/seasons, artists/albums, reading
   series and photo months, but force their own card/list presentation and fixed
   SQL order. Generic browsing has grid/list controls but no common sort or
   favorites/tag filters. Sorting must happen before pagination, and natural
   episode/disc/track/volume order must remain the default within hierarchies.
3. Collections and ordered albums open the membership editor directly. Users
   cannot browse a dedicated collection, play its ordered queue, resume reading
   its members or start an album-scoped slideshow. The editor's membership cap,
   order and named-library ownership must remain intact.
4. Details exposes Favorite and a repository setTags method exists, but there is
   no tag editor or useful discoverable tag/favorite filter. Organization edits
   already trigger catalog reindexing and must retain that path.
5. Home has one mixed Continue shelf and one Recently added shelf. Watching,
   reading and listening compete for the same twelve results; collections have
   no shelf. Continue detection also misses a flowing EPUB's saved text anchor
   while it remains on the first canonical section.
6. Photos are decoded with bounded ownership, but the viewer offers only contain
   fit, previous/next and a timer. It has no zoom/pan or transform reset and its
   category scope cannot represent an ordered user album. Zoom interactions must
   pause automatic advances and navigation must stay in the chosen album.
7. ThumbnailCache excludes audio. EmbeddedAudioTags reads only scalar ID3/FLAC
   fields, and a large artwork frame currently ends the scalar-frame walk.
   Offline MP3/FLAC/M4A music and audiobook artwork needs bounded local extraction
   and downsampling, retaining selected provider/user artwork precedence.

## Implementation contract

Use bounded SQL queries with deterministic keyset continuation and literal search
terms. Apply category/library/result-kind/sort/tag/favorite restrictions before
limits; do not materialize the catalog for filtering. Keep notes/bookmarks and
canonical anchor destinations. Common browse controls change presentation/order,
not category-specific hierarchy or playback identity. Group drilling carries the
active scope. Preserve original file identity, progress, contextual Study and
all saved notes.

Collection detail is the default destination; edit is an explicit action.
Ordered membership remains authoritative for mixed collections and photo albums;
playback queues contain only available audio/video members, and a selected member
starts at its canonical position in that queue. A photo album never leaks into
other photos. Home shelves are independently bounded and collections are scoped
to their named library. Favorites/tags are user organization, separate from
provider metadata and selected artwork.

Plex references: PLEX_TARGETED_DECOMPILATION.md and its catalog schema/API reports
establish separate hierarchical catalog, tags/taggings, collection memberships,
FTS maintenance and user state; they do not recover universal ranking or smart
collection algorithms. Panels references: PANELS_DEEP_DECOMPILATION.md and linked
geometry/cache findings guide canonical navigation, owned decoded buffers,
transform reset and bounded cache lifetime. No private behavior is invented.

Embedded cover extraction is offline and format-bounded. Prefer a front-cover
picture where declared, enforce metadata/encoded/pixel limits, downsample before
cache publication, and never scan/decode the complete audio track. Unsupported or
malformed artwork falls back to existing art placeholders. These source limits
are provisional pending the separate measured testing phase.

## Implemented source workflows

| Area | Implementation and visible outcome |
| --- | --- |
| Global Search | CatalogDiscoveryRepository queries effective catalog titles, creators and tags through catalog_search FTS, retaining filename fallback for unindexed items. Notes/bookmarks remain in the same SQL result union. Result kind, category, named library, favorites, exact tag and recent/title order apply before a 48-result keyset page. SearchScreen exposes Previous/Next pages and ignores stale responses; catalog/organization/Study changes refresh the active page. Named-library and tag pickers have their own bounded searchable continuation pages. |
| Saved locations | Note/bookmark results retain their reference ID and time/page destinations. EPUB/comic/PDF reader routes accept an optional Study reference, load only an anchor owned by the exact item/library, and apply compatible page or passage anchors. Incompatible revisions retain the original saved reference and use the existing page fallback. Photo results open the zoom-capable photo route. |
| Category controls | Shared CatalogBrowseControls exposes Original order, Title A–Z/Z–A, Newest/Oldest added, Recently opened, grid/list, Favorites and tag filtering. Category SQL applies these before pagination for both groups and titles. Natural season/episode/disc/track/volume ordering remains the default; explicit user sorts change it. Drill-down and ancestor navigation retain query, sort, presentation, status, reading units and organization scope. Named-library typed screens use the same hierarchy, and generic movie/mixed browsing uses the same controls. Existing course learning journeys remain contextual. |
| Collections/albums | Collection selection opens CollectionDetailsScreen; Edit membership and order is separate. Members are browsed in 48-entry pages with effective titles, progress, offline state and grid/list presentation. Play in order/Shuffle builds a bounded queue from available audio/video members in saved membership order; choosing a member starts that queue there. Continue reading chooses an unfinished reading member, prioritizing already opened members, then source order. Each member retains Details and its exact-file read/open action. Photos open only the chosen collection/album. |
| Collection management | The cross-library index identifies each collection's named library, sorts by name plus ID and retains bounded continuation. New collection chooses a named library through the paged picker when necessary. Add to collection from Details appends the selected item to an existing collection without replacing its order; existing membership is visibly checked. The editor retains explicit ordered membership, catalog-backed paged member search and the 1,000-member cap. Deleting a collection does not delete media or Study. |
| Tags/favorites | Details exposes Add/Edit tags and displays saved tags. One tag per line, at most 100 tags of 200 characters; trim and case-insensitive de-duplication preserve display labels. Atomic organization updates retain Favorite while editing tags and retain tags while toggling Favorite. Existing reindex, backup and transport fields are reused. Tag/favorite filters work in global, generic and specialized browsing before limits; tag pickers show bounded usage counts and continuation. |
| Home | Independently bounded Continue Watching, Continue Reading and Continue Listening shelves prevent one medium from crowding out the others. Reading resume also considers first-section text locators/open activity. Recently added remains separate. Collections & albums displays up to twelve recent collections with covers/library names and dedicated detail destinations, plus a View all index. The empty shelf offers a discoverable creation journey. Custom catalog record updates invalidate discovery streams after transaction commit. |
| Photos | A dedicated photo route is used from normal media navigation/search/Home. InteractiveViewer supplies pinch/scroll zoom and drag pan; double tap, zoom buttons and keyboard +/−/0 offer zoom/reset, with a 1x–8x range. Image changes reset the transform. Zoom/pan interactions pause automatic slideshow advances. Previous/Next stops at scope boundaries; ordered albums query only available image memberships in their saved order. Explicit category/favorite/tag scopes remain intact. Exact image opening also works outside photo categories without inventing album membership. |
| Embedded audio covers | ThumbnailCache uses an offline worker-isolate extractor and the existing cover decode/downsample pipeline. Provider artwork remains first, chosen/local item artwork second, and extracted embedded art is a regenerable fallback. Revision keys now include fingerprint plus timestamp/size, and cache files are atomically published with unique staging files. The host's existing authorized artwork endpoint uses the same cache; no audio payload or extracted local cache path is added to transport metadata. |

## Offline artwork capability and bounds

| Container/tag | Source coverage |
| --- | --- |
| MP3 / audio beginning with ID3v2.3 or ID3v2.4 | Ordinary APIC frames, one- or two-byte description terminators, front cover preference and embedded fallback images. Tag-level unsynchronization/extended headers and transformed/compressed/encrypted frames are not decoded; ID3v2.2 PIC is not advertised. |
| Native FLAC | PICTURE metadata blocks with bounded field lengths and front-cover preference. Declared dimensions are only a skip guard; the actual image descriptor controls decoding limits. |
| M4A / M4B / MP4 audio | Seek through bounded moov/udta/meta/ilst/covr atoms and JPEG/PNG data atoms, including extended atom sizes. mdat audio bytes are skipped. Other QuickTime mdta artwork layouts are not advertised. |
| Ogg Vorbis / Opus | First logical codec stream's comment packet, base64 METADATA_BLOCK_PICTURE and legacy COVERART fallback. Multiplexed Skeleton-first streams, unsupported containers and linked images fall back to existing artwork/placeholder. |
| Other audio containers | Existing selected/provider artwork or placeholder; no claim that WAV/AIFF/ASF/Matroska/APE picture bindings were implemented. |

Extraction caps encoded pictures at 8 MiB, metadata traversal at 32 MiB, ID3/
FLAC/MP4 structures at 4,096 entries, atom depth at twelve, and Ogg traversal at
1,024 pages with a sixteen-MiB packet limit. Picture magic and actual decoder
geometry are checked; native decoding rejects over 80 MP and generates covers
within 320x640. Thumbnail generation stays serialized per cache instance and
uses the existing 64 MiB best-effort disk cleanup, recency/grace and owner guards.
These are implementation limits, not measured peak RSS guarantees. Source files
are read-only, handles are awaited before closing, and no linked picture URL is
fetched. Invalid/unavailable art does not prevent media opening.

The scalar ID3 reader now seeks over large APIC/unknown frames instead of ending
the tag walk, so later artist/album/title fields remain discoverable. Scalar FLAC
metadata likewise skips large non-comment blocks within the traversal bound.
Neither art nor scalar tags authorize file identity merging.

Primary format references consulted for these choices:
[ID3 APIC](https://id3.org/id3v2.3.0),
[ID3v2.4 structure](https://id3.org/id3v2.4.0-structure),
[FLAC PICTURE specification](https://datatracker.ietf.org/doc/html/rfc9639#section-8.8),
[Xiph VorbisComment pictures](https://wiki.xiph.org/VorbisComment),
[Apple metadata atoms](https://developer.apple.com/documentation/quicktime-file-format/metadata_atoms_and_types),
[Apple image type indicators](https://developer.apple.com/documentation/quicktime-file-format/well-known_types),
and [FFmpeg's covr reader](https://github.com/FFmpeg/FFmpeg/blob/master/libavformat/mov.c).
This source pass does not claim universal container parity.

## Implementation versus later acceptance

Dart formatting and Graphify maintenance are implementation work. No analyzer,
automated test, application build, startup, screenshot or runtime acceptance
journey was executed. No new binary decompilation or personal media inspection
was needed. Existing changes from the native-player, processing and reader passes
remain in the working tree.

The later phase must cover SQL/FTS/filter/order continuation on large and changing
catalogs, Unicode/case facets, Study revision/anchor restoration, empty/offline/
deleted collection membership, mixed queues and shuffle, narrow-screen/keyboard
layouts, photo transforms/album boundaries, malformed/truncated/large metadata,
cache invalidation/pressure and platform codec behavior. The browser companion's
separate W01/W02 category/reader parity backlog is unchanged. Source coverage is
not visual or measured acceptance evidence.
