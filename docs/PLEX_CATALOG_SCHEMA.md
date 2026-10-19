# Plex catalog schema findings for Tangerine

This focused pass recovers the catalog's storage boundaries from Plex's shipped library database template and metadata-combiner XML. It supports separating libraries, source folders, physical files, technical media and descriptive metadata in Tangerine. It does **not** recover Plex's matching score, duplicate-merging rules, edition grouping, network providers or live database contents.

**The template is a baseline, not the final schema of this Plex release.** Canonical REA pseudocode for `0x10055e92c` executes the `ALTER TABLE` adding `metadata_items.edition_title`, drops any old edition-title index, and creates that index ([server-native-008](../.verification/plex-targeted-20261019/pseudocode/server-native-008.c), Evidence `ev_664a1522264b5c9c5f17decb839fa5ba97e3ef9821df76dbe2241ee9c9af7c88`). This template lacks that column. Treat template absence as a statement about this specific resource; use native migration analysis for features added afterward. Its `PRAGMA schema_version = 878` is SQLite's schema edit counter, not Plex's application migration version.

## Sources and method

Inspected `/Applications/Plex Media Server.app`, bundle `com.plexapp.plexmediaserver`, version **1.43.4.10903** (`CFBundleShortVersionString` 1.43.4). The explicit source was `Contents/Resources/com.plexapp.plugins.library.db`: **318,464 bytes**, SHA-256 `b1d0e2a2fd945a4f5630b185d489b71ee48f5260973f448c9c1dfb49809a7c8f`.

The database was opened using Python SQLite URI `mode=ro&immutable=1`. Only stored SQL, column/foreign-key declarations, database pragmas and row counts were read. No installed user database, server, network service or account row values were accessed. Neither `-wal` nor `-shm` siblings existed beside the shipped template. The schema-only derivatives were generated through ordinary format-aware SQLite inspection. A separate canonical REA database inspection confirms the same source digest and complete stored schema ([template-schema Evidence](../.verification/plex-targeted-20261019/evidence/template-schema.json), ID `ev_ad6729322f72392896b57ebcf7eb4e741eacd5fba9a10f3a2d40edd7504b08e3`).

The template stores 71 table definitions, 172 explicit SQL index definitions and eight triggers. Canonical REA inventory counts 177 indexes when the five implicit SQLite autoindexes are included. The 71 include virtual tables and their backing tables, rather than 71 independent product entities. Relevant catalog tables contain zero rows. The extractor does not export row values from any table. SQLite can read the FTS4 declarations, but cannot introspect the two `spellfix1` virtual tables without Plex's extension; their stored definitions remain available. Custom `naturalsort` collation and virtual-table backing declarations mean the SQL derivative is an inspection artifact, not a portable migration script.

Source identities, exact declarations and the reproducible extractor are in [the schema artifact directory](../.verification/plex-targeted-20261019/schema/). The most useful files are [source identity](../.verification/plex-targeted-20261019/schema/source-identity.json), [stored SQL](../.verification/plex-targeted-20261019/schema/template-schema.sql), [table inventory](../.verification/plex-targeted-20261019/schema/table-inventory.json) and [combiner identities](../.verification/plex-targeted-20261019/schema/combiner-identities.json).

## Storage relationships actually present

The relationships below are inferred from explicit column names and supporting indexes. The principal library/media/metadata tables do **not** declare SQL foreign keys, so this inspection does not establish enforced referential integrity, cascading deletion or uniqueness of those links. Some unrelated tables in the complete template do declare foreign keys; the limitation is specific to these central catalog relationships.

| Boundary | Stored structure | What this establishes |
| --- | --- | --- |
| Logical library | `library_sections(id, library_id, name, name_sort, section_type, language, agent, scanner, uuid, user_fields, changed_at, …)` | A library has its own identity, type, language and agent/scanner configuration; it is not merely a filesystem root. Integer type mappings and configuration serialization need code evidence. |
| Library source roots | `section_locations(id, library_section_id, root_path, available, scanned_at, …)` | Several root records can reference one library; root availability and scanning state can be stored separately. No unique root constraint or per-source access-control policy is declared here. |
| Physical directories | `directories(id, library_section_id, parent_directory_id, path, deleted_at, …)` | A filesystem-oriented parent tree is stored apart from metadata hierarchy. It is not evidence that the browsed catalog must mirror folders. |
| Catalog metadata | `metadata_items(id, library_section_id, parent_id, metadata_type, guid, …)` | Descriptive items have stable internal IDs, provider-shaped GUID storage and a separate parent hierarchy. The schema does not enumerate which integer means show/season/episode or prove how the hierarchy is populated. |
| Technical media | `media_items(id, library_section_id, section_location_id, metadata_item_id, width, height, duration, container, codecs, …)` | Multiple technical-media records can reference one catalog item and retain their source root. This supports representation/version separation but does not explain edition selection or duplicate rules. |
| Physical parts | `media_parts(id, media_item_id, directory_id, file, hash, open_subtitle_hash, index, size, duration, deleted_at, …)` | A media representation can have ordered file parts with independent paths/hashes. Hash fields alone do not establish their algorithms, when calculated, or identity across moves. |
| Streams and choices | `media_streams(media_item_id, media_part_id, stream_type_id, codec, language, index, default, forced, …)` plus per-account item/part/stream settings | Streams and selected audio/subtitle choices are modeled below the catalog item. This storage capability does not establish player/transcoder behavior. |

`media_metadata_mappings` stores `media_guid` and `metadata_guid`, separately from these ID links. This is useful evidence that media identity and descriptive identity need not be the same string, but this template cannot establish matching provenance, confidence, rematching transaction behavior or whether a move retains a particular internal ID.

`versioned_metadata_items` includes `metadata_item_id`, `generator_id`, `target_tag_id`, state/context, `selected_media_id`, `version_media_id`, `media_decision` and `file_size`. The structure can track generated media versions. It must **not** be labeled the movie-edition model from its name alone. The native edition-column migration is additional evidence outside this baseline, and exact edition grouping remains a code question.

## Metadata, overrides and grouping

`metadata_items` stores `title`, `title_sort`, `original_title`, year, studio, summary, tagline, content ratings, several ratings and dates. Artwork is represented by `user_thumb_url`, `user_art_url`, `user_banner_url` and `user_music_url`; `user_fields` and `extra_data` provide opaque extension fields. `library_sections` has corresponding library artwork and `user_fields` storage.

These columns establish separately addressable descriptive fields and user-named resource fields. They do **not** decode field-lock flags or prove which provider wins when a user edit conflicts with a refresh. No such serialization or overwrite policy was inferred from `user_fields` alone. The later [native API analysis](PLEX_NATIVE_CATALOG_API.md) independently recovers a `lockedFields` loader and lock-aware reset guards; use that code evidence for the narrower supported rules.

The template includes both denormalized `metadata_items.tags_genre`, `tags_collection`, `tags_director`, `tags_writer`, `tags_star` and `tags_country`, and normalized `tags`/`taggings`. A tagging links `metadata_item_id` to `tag_id`, with an `index`, optional text/time offsets and extra data; tags carry type, value, key, parent and artwork fields. This supports indexed many-to-many organization. Numeric tag-type meanings, collection membership rules, ordering and smart-collection query evaluation remain unproven by schema alone. `metadata_relations` also stores typed links between metadata items without enumerating relation types.

The 19 shipped combiner XML files explicitly list ordered agent sources. For example, `themoviedb-combiner-movies.xml` lists local media then The Movie Database; `musicbrainz-combiner-albums.xml` lists MusicBrainz then local media then LyricFind; local-media-only files list one source; `none-combiner-*` lists the none agent then local media. All XML is retained with hashes and parsed source order.

This is evidence of configurable source lists with different order for different agents. The XML contains **no per-field merge algorithm, user-lock rule or universal local-metadata-wins policy**. Without tracing the combiner consumer, source order is not proof of overwrite precedence. These are shipped agent resources and may represent legacy paths; their presence does not prove that a modern provider uses them on every scan.

## Progress and user-specific state

`metadata_item_settings` stores `account_id` plus `guid`, rating, `view_offset`, `view_count`, `last_viewed_at`, skip count/date, `changed_at` and extra data. It does not link this state solely to `metadata_items.id`. This offers an architectural precedent for keeping user progress apart from filesystem rows and descriptive metadata.

The schema does not establish the unit of `view_offset`, completion thresholds, update cadence, edition-specific versus shared progress, conflict resolution or whether `(account_id, guid)` is unique in current runtime code. Its template indexes on account, GUID and offset are separate, non-unique indexes. Do not copy an assumed unique key into Tangerine without choosing and testing the intended semantics.

`metadata_item_views` is a separate history-shaped table with account, GUID, type/library, title and hierarchy snapshots, thumbnail and `viewed_at`. `view_settings` stores account/client/view grouping and sort identifiers/direction. These are distinct storage concerns from resume state. `media_item_settings`, `media_part_settings` and `media_stream_settings` permit lower-level user choices; only the last declares the unique `(media_stream_id, account_id)` constraint in this template.

## Indexes, search and large libraries

The catalog has separate indexes on library, metadata type, parent, GUID, title, sort title, hash, creation/addition/change/deletion dates, plus the composite `(library_section_id, metadata_type, added_at)`. `title_sort` has a stored NOCASE declaration and an additional `naturalsort` index. The collation's implementation and locale behavior are not present in the schema.

Media parts are indexed by owning media item, directory, path, hash, size and deletion timestamp. Taggings are indexed separately by item and tag; tags by type, text, `(tag_type, tag)`, key and parent. These declarations support bounded lookup patterns, but they do not show query plans for live data, API pagination, cursor stability or scan batch sizes.

Two external-content FTS4 tables index metadata titles (`title`, `title_sort`, `original_title`) and tag text. Eight explicit triggers maintain insert/update/delete synchronization: before update/delete removes the old FTS record; after insert/update inserts the current values. This is stronger evidence than merely finding an FTS table name. It does not establish ranking, tokenizer configuration beyond the stored declaration, typo tolerance, stemming or cross-field query behavior. The separate spellfix virtual-table declarations suggest a spelling facility is available in the package, but its actual integration is unresolved.

Many central records have `changed_at`, `updated_at` or `deleted_at`, and `library_timeline_entries` stores library/item/state/update time. Those are useful change/tombstone storage capabilities. They do not prove the synchronization protocol, monotonic revision policy, deletion retention or that a query should use timestamps as a safe pagination cursor.

## Implementation consequences for Tangerine

These are design recommendations derived from the recovered boundaries, not a claim that Tangerine must reproduce Plex's internal tables:

1. Keep `Library`, `LibrarySource`, physical `FileAsset`, technical `MediaRepresentation`/ordered parts and `CatalogEntity`/match link separate. Preserve existing Tangerine item IDs through migration and rematching.
2. Give root availability an explicit state. An unavailable volume should not immediately delete catalog items or progress. Choose disappearance/tombstone behavior explicitly; the Plex template alone does not supply that algorithm.
3. Store provider identity/provenance independently from user overrides. Implement per-field locks and transactional match correction as Tangerine policies rather than pretending the XML defines them.
4. Use separate user progress, history, presentation settings and selected streams. Define progress identity deliberately for alternate cuts and split files, while preserving Study anchors against existing resource identity.
5. Build explicit collection membership and ordering, instead of relying on a comma-delimited cache field. Keep playlists and generated media versions semantically separate.
6. Add indexes for actual bounded browsing/search queries and verify them with representative data. Choose stable pagination using a sort key plus ID tie-breaker; no Plex cursor algorithm was recovered here.
7. Limit the first implementation to the program's existing catalog requirements. Streaming/transcoding, account federation, cloud agents, subscription recording and sync internals are outside this pass.

The recovered template answers storage separation and declared index/search maintenance. The [native scanner report](PLEX_NATIVE_SCANNER.md) and [native catalog/API report](PLEX_NATIVE_CATALOG_API.md) add matching/reconciliation, cancellation, edition and lock-aware reset evidence. Full edition grouping, progress thresholds, inbound pagination and permission policy remain open; schema alone cannot establish those behaviors.
