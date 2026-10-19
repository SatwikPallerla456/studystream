# Plex functionality: targeted REA investigation

19 October 2026. This report explains the Plex functionality relevant to the
program's library, catalog, media identity and server requirements. It preserves
Plex's recovered behavior separately from proposed Tangerine choices. The
findings are a reference for the user's own improvements; they are not a
requirement to reproduce Plex's implementation.

The target was the installed **Plex Media Server 1.43.4.10903** app, using its
server and scanner arm64 slices, shipped scanner/agent source and database
template. REA with Ghidra 12.1.4 produced **73 function pseudocode outputs and two
assembly outputs**, retained as 75 canonical native Evidence records. Additional
REA evidence covers Mach-O identity and the complete shipped database schema.
This was a bounded static investigation. Plex was not launched, its providers
were not contacted, and no personal Plex database was read or changed.

## Functionality and evidence coverage

“Recovered” below applies to the named local path, not every Plex feature or
every runtime case. The companion reports contain exact procedures, Evidence
IDs, raw outputs and limitations.

| Requested capability | What Plex's artifacts establish | Coverage |
| --- | --- | --- |
| Named libraries with multiple folders | Separate library sections and source-location records; each root has availability and scan state | Recovered storage and native scan paths; complete type-ID/UI mapping remains partial |
| Separate files, technical media, catalog and progress | Metadata hierarchy, media representations, ordered physical parts, streams and account/GUID state are separate | Recovered template structure; all runtime consistency rules remain partial |
| Reliable rescans and offline sources | Unavailable roots are protected from deletion; failed/cancelled processing suppresses incomplete-scan missing-record cleanup | Recovered native control flow |
| Moves, copies and duplicate candidates | Path lookup, size filtering, sampled fingerprints, old-path existence and logical display offset affect reuse | Recovered local reconciliation path; all merge cases remain partial |
| Filename/title/year/provider matching | Legacy cleanup/TV parsing source; native edition cleanup, episode expansion, provider request and result-consumer paths | Partial modern parser; remote ranking remains unknown |
| Manual correction and unmatch | Candidate search, selected-match mutation, possible identity merge, reset/none-agent refresh and field-lock guards | Recovered local handlers; full downstream merge transaction remains partial |
| Editions, multipart titles, extras and sidecars | Native edition migration/lookups and subtitle isolation; typed extras; legacy part stacking and native multi-episode guard | Partial; complete edition/version UI and grouping rules remain unknown |
| Browsing, search, collections and artwork | Hierarchical metadata, tags/taggings, artwork fields, FTS declarations and maintenance triggers | Recovered storage; full query/ranking/UI behavior remains partial |
| Native/browser catalog delivery and pagination | Response pagination headers and separate outbound HTTP/sync paging clients | Partial; complete inbound pagination and library authorization were not recovered |
| Saved watch/resume state | Separate user-state fields and outbound play-state sync paging | Partial; completion thresholds, cross-edition sharing and conflict semantics remain unknown |

Detailed reports:

- [Native scanning, reconciliation, fingerprints, extras and episodes](PLEX_NATIVE_SCANNER.md).
- [Native search, match/unmatch, locks, editions and API boundaries](PLEX_NATIVE_CATALOG_API.md).
- [Catalog schema, source roots, search storage and user state](PLEX_CATALOG_SCHEMA.md).
- [Packaged legacy filename/TV rules, part stacking and local assets](PLEX_PACKAGED_SCANNERS.md).

## How the recovered local pipeline works

### Library and media organization

The shipped schema distinguishes a logical `library_sections` record from its
`section_locations`. Directories describe filesystem organization; metadata
parents describe catalog organization. A metadata item may link to technical
`media_items`, which link to physical `media_parts` and audio/video/subtitle
streams. Tags and taggings provide another grouping boundary. This explains how
a browsed title can be distinct from a file path or playback representation.

The inspected database is an empty packaged **baseline template**, with 71
table definitions, 172 explicit indexes (177 including autoindexes) and eight
triggers. Native migration code adds `edition_title`, which is absent from that
template. Template absence therefore cannot establish that the installed release
lacks a feature. The schema report distinguishes declared columns/indexes from
inferred relationships and unenforced foreign-key assumptions.

### Scanning and file reconciliation

The native scanner has three consequential outcomes. An available, completed
root participates in missing-file reconciliation. An unavailable root gets its
availability/timestamp updated and its known records removed from the deletion
candidate maps, allowing other healthy roots to finish. Processing errors or
cancellation leave the outer scan incomplete and suppress that cleanup.
Database-record cleanup is not proof that Plex deletes underlying media files.

Incremental checks compare recorded existence, size, write time, deletion state
and directory/file counts. Reconciliation first tries the known path with its
location and logical display offset. A path miss can lead to size-filtered
fingerprint candidates. A missing old path supports move/rename reuse; a distinct
old path that still exists can become a duplicate-copy case. Equal fingerprints
do not universally collapse all copies. IFO/BUP files receive special treatment.

The local fingerprint samples the first and last 65,536 bytes, using SHA-1 block
digests and file size for one output and a size-seeded 64-bit word sum for another.
Windows can overlap; this is not a full-content hash. A separate tiny-file branch
has unusual output handling, documented with assembly corroboration in the
scanner report. No tiny-file runtime result is claimed. This distinction matters
when interpreting how strongly Plex has established file identity.

### Metadata matching and correction

Candidate search and applying a chosen match are distinct operations. Search
accepts type-specific name/year hints and library/provider configuration.
The universal provider request can carry filename, file size and available Plex/
OpenSubtitles fingerprints and parse returned Video/Directory metadata.
The ranking performed by that remote service is outside the local executable.

The recovered scanner consumer selects the first candidate and contains a
score-at-least-80 branch, but modern-agent classification sets that consumer's
score to **100** before the branch. A **94** cutoff elsewhere belongs to EPG
enhancement. Neither value establishes a modern movie-match confidence formula.
The separately recovered Python formula belongs to the explicitly legacy agent.

Applying a selected GUID can update identity or enter a merge path when an
eligible target already exists. Unmatch runs identity/metadata reset and a
none-agent refresh path. Reset consults marked-field guards, including artwork
and edition handling. The lock loader parses a stored `lockedFields` entry into
integer field IDs using `&`, `=` and `|` delimiters. The complete serializer,
escaping rules, field-ID dictionary and every downstream overwrite rule remain
unrecovered. These guards concern metadata fields, not library access rights.

### Editions, extras, subtitles and episodes

Native code recognizes brace/square-bracket edition markers, removes them from
cleaned titles and includes edition in bounded identity lookups. Subtitle
association can exclude a sidecar whose captured edition differs from the media's
edition; IDX also requires SUB. Native extras collection recognizes typed
directories such as Trailers, Featurettes, Interviews and Deleted Scenes.

The episode helper supports a first/last episode range and special-season hint.
Inverted ranges or a difference over 100 collapse to a single episode; accepted
ranges expand inclusively. Its evenly divided display offsets are hints, not
detected episode boundaries. Packaged legacy part stacking is a separate
filename heuristic; it must not be confused with alternate cuts or the complete
modern movie parser.

### Browsing, user state and delivery

Stored artwork, metadata hierarchy, tags, collections and FTS maintenance support
catalog organization. Storage alone does not recover the entire browser UI,
search ranking, smart-collection evaluator or next-episode policy.

Account/GUID progress is stored separately from descriptive/file rows. A recovered
outbound sync client pages view-state fields using timestamp plus identifier
ordering and has consistency/retry checks. Another helper writes response
container headers. Those functions do not establish a complete inbound catalog
endpoint, its page-size policy, or per-library authorization.

## What can be chosen or improved independently

The recovered behavior is the reference material. The
[Tangerine master plan](TANGERINE_MASTER_IMPLEMENTATION_PLAN.md) contains proposed
implementation decisions, acceptance cases and priorities based on that material
and the separate Panels findings. Those decisions can be revised without
changing what this investigation established about Plex.

Particularly useful decision points are file-versus-title identity, unavailable
folder behavior, duplicate handling, edition-specific progress, manual matching,
field-override ownership, ranking transparency, catalog pagination and library
permissions. Plex's sampled hash, opaque field IDs, remote scorer and merge paths
are recovered observations rather than mandatory implementation choices.

## Evidence, reproducibility and limits

[The retained analysis directory](../.verification/plex-targeted-20261019/README.md)
records target hashes, REA/Ghidra profiles, seeded analysis, complete portable
Evidence bundles, raw C, query errors, source manifests and validation. The
[native evidence index](../.verification/plex-targeted-20261019/native-evidence-index.json)
links all 75 native records. Reconstructed C is decompiler output rather than
original Plex source; warnings and unresolved calls remain in the raw evidence.

One oversized route-registry decompilation failed with a response-buffer error
and has no Evidence ID. Focused handler decompilation succeeded; bounded ordinary
LLVM assembly establishes the registry bindings separately. Literal-reference
candidates are discovery aids and do not independently prove control flow.
All owned native REA sessions were exported and closed.

Remaining gaps are modern remote ranking, complete native parser precedence,
all identity-merge consequences, full edition/version grouping, inbound catalog
authorization, watch-completion thresholds and next-episode rules. The findings
provide useful local functionality detail without claiming whole-server coverage.
