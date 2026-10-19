# Targeted native Plex scanner reconstruction

This static investigation covers installed Plex Media Server **1.43.4.10903**, specifically its native `Plex Media Scanner` arm64 slice. It answers the movie/TV organization, local-asset, identity-reconciliation and scan-recovery questions needed for Tangerine. It does not decompile unrelated Plex systems.

The original universal scanner SHA-256 is `5692fde84e902f29792751ae803e173266b72fa41c76ee054a078deaa58d7471`; the faithful arm64 slice is `2ad6d6495fd97de51932026b1a54123243a78cc6d18b2ebfec63ed0f901ac526`. REA/Ghidra pseudocode is canonical evidence; selected LLVM assembly and raw Mach-O references are separately labeled ordinary immutable inspection. No investigated code was executed.

For full Evidence IDs, raw C and limitations, see [the native ledger](/Users/satwikpallerla/StudioProjects/study_stream/.verification/plex-targeted-20261019/native-scanner-notes.md) and [the evidence index](/Users/satwikpallerla/StudioProjects/study_stream/.verification/plex-targeted-20261019/derived/scanner-native-evidence-index.json). References such as S003 identify the corresponding `scanner-native-003` REA record and C file.

## Most important confidence correction

The native match consumer has a score-at-least-80 branch, **but modern Plex agents force that consumer score to 100**. The helper at `0x100189e04` recognizes modern movie, series, none, audiobook, music, NFO movie/series and custom agent identifiers. For those agents, `0x1002e9dcc` replaces the candidate score before deciding whether to apply identity changes. Other agent results retain the returned score. Missing score parses as -1. The consumer takes the first returned candidate in this recovered path. [S012, S021, S022]

Therefore neither this native branch nor the [packaged legacy matcher](/Users/satwikpallerla/StudioProjects/study_stream/docs/PLEX_PACKAGED_SCANNERS.md) establishes modern Plex's confidence formula, ranking, ambiguity margin or automatic-match threshold. Modern provider selection remains outside this local consumer evidence. Tangerine needs its own calibrated and explainable policy.

## Scan completion, offline roots and deletion

Three cases must remain separate in Tangerine's scan state machine.

**Completed root:** the native per-location helper processes its queue and returns success. The outer section scan removes candidates left in the missing-media/directory maps only when all relevant processing remained complete. `autoEmptyTrash` selects hard database-record deletion or soft deletion. [S003 `0x10017d948`; S008 `0x1001cc230`]

**Unavailable root:** a failed availability check marks the section location unavailable and updates its timestamp. The helper then removes that location's known media and directories, plus directory ancestors, from the leftover deletion maps and returns success. The records are protected from missing-media cleanup while other roots can still complete. This is more precise than treating an unplugged drive as an empty folder or failing every source in the library. [S008]

**Error or cancellation:** directory processing failure or cancellation returns false; the outer scan suppresses its missing-media cleanup, explicitly logging that the scan was incomplete. The native cancellation callback sets its cancellation flag and wakes the waiting work through locks and a condition variable. [S003, S008, S009, S018 `0x1001bab94`]

Soft deletion has a further qualification: `0x1002a01c4` looks for another matching part. If one exists, it promotes that media-record operation to the hard-delete helper. Otherwise it schedules a transaction callback carrying the current timestamp for an item that is not already marked deleted. The hard-delete wrapper performs transactional record cleanup and later housekeeping. These recovered wrappers do **not** establish removal of the user's underlying video file. [S011, S024, S027]

Tangerine should represent `complete`, `unavailable`, `cancelled` and `failed` separately, with a scan generation and per-root completion result. Missing-file reconciliation must use only positively completed scope; unavailable sources retain their files, catalog links, progress and user corrections. A separate explicit user action should control permanent catalog cleanup.

## Incremental scan reuse

The recovered directory path queries existing `media_parts.file`, `size`, `updated_at` and `deleted_at`, scoped by directory and section location. A previously recorded file cannot be skipped when it no longer exists, its size changes, write time changes, it is marked deleted, or directory/file counts differ. These are cheap filesystem checks before more expensive analysis. [S009 `0x1001cd1e4`]

This does not recover a live filesystem watcher or prove that a size/mtime pair is a unique identity. For Tangerine, treat this pair as an invalidation shortcut, and retain an explicit rescan path for equal-size content changes or unreliable timestamps.

## Path, size and fingerprint reconciliation

`0x10029b33c` separates path reuse, possible moves and additional copies. [S010]

1. Try existing part paths first. The helper loops incoming physical parts and builds a lookup from path, location context and logical display offset; a hit loads the existing media item. [S025 `0x10029cdac`]
2. On a path miss, use a size-based candidate query before calculating fingerprints. The size is the part's `+0xd8` value; a nonpositive size becomes an absent typed query value. The query excludes the incoming part identifier and is scoped to the supplied library/context. A size hit is only a cheap reason to attempt the hash path. [S023 `0x1002b1430`; S010]
3. If a size candidate exists and the incoming hash is absent, calculate it. Then query a matching part by fingerprint, library/context, excluded current-part ID and display offset. Offset -1 and zero are treated as equivalent alternatives by this query. [S024 `0x1002b0c38`; S026 `0x1002afcf8`]
4. When an old matched path is absent, the recovered branch recognizes a rename/move. When it still exists, filesystem path equivalence can also qualify that branch. It records old/new path information and reuses the existing item. [S010; S031 `0x10029cf7c`]
5. A different existing path is treated as a duplicate-part situation and scanning continues. Hash matches on IFO/BUP disc metadata receive a special exclusion. **A duplicate fingerprint does not universally collapse every file into one record.** [S010]

The logical display-offset condition is essential: multiple episode records can refer to the same physical video. A file fingerprint alone cannot identify which episode occurrence or timeline segment a resume point belongs to.

After reuse, hint comparisons can cause metadata refresh. Recovered hint names include title/year-related fields, edition, episode, season, release date, strong show GUID and show edition. Exact edition/show-edition mismatches are significant independently of approximate name comparison. A final orphan check can remove a media record whose claimed metadata parent no longer exists. [S010]

Tangerine should keep stable physical-file IDs independently from work IDs; retain path history; distinguish a move from a second copy; and keep progress bound to the selected file/version and timeline. Different cuts must not silently share a resume timestamp.

## Fingerprint boundaries

The native fingerprint wrapper verifies path existence, distinguishes local paths from another supported path class, and returns whether either of two stored fingerprint fields changed. For local media it delegates to `0x1001f3938`. It seeds a string with decimal file size and a 64-bit accumulator with file size, then reads the first **65,536 bytes**. The block helper appends that block's digest to the string and adds each complete native 64-bit word to the accumulator. It ignores fewer than eight trailing bytes for the sum. [S026, S032, S035]

For files at least 65,536 bytes long, it reads the last **65,536 bytes**, repeats the block operation, digests the combined size-and-block-digests string, and formats the accumulator as `%016llx`. At exactly 65,536 bytes the two windows cover the same block; between 65,536 and 131,072 bytes they overlap. The second output is the size-seeded word sum, not a second full content digest. [S032, S035, S036]

For smaller files, the tiny-file branch uses only the first block and skips the final digest and accumulator formatting. In the recovered function this leaves the first output as the size-and-block-digest seed and the second output empty. Ordinary LLVM assembly corroborates the branch and output storage: `0x1001f3ba8` branches to the tiny-file log at `0x1001f3c9c`, then falls through to copies from the seed at stack `+0x60` and the still-empty second string at `+0x40`. Failed reads throw an error on negative results. This is a static reconstruction; no tiny media file was executed through Plex to verify surrounding runtime behavior. [S032]

LLVM assembly independently confirms the end offset as **size minus 65,536**, despite Ghidra's pointer-typed expression displaying a subtraction of `0x2000` pointer elements. That is an ABI/type-recovery artifact, not an 8 KiB tail window.

The digest selector is OpenSSL NID **64 (`0x40`), SHA-1**: the recovered constructor passes it through `OBJ_nid2sn` and `EVP_get_digestbyname`. A separate, hashed local development-header reference maps NID 64 to SHA1; that header is supporting API interpretation, not a shipped Plex source file. [S037; `derived/openssl-nid64-reference.json`]

These are sampled fingerprints rather than a full media-content digest. They can accelerate candidate matching, but cannot serve as collision-proof identity or prove identical playback timelines.

## Editions and sidecar isolation

The native static initializer constructs an edition marker expression accepting braces or square brackets: `[\{\[]edition-(.+?)[\}\]]`. The title cleaner removes that marker before normalizing the lookup name. This gives direct native corroboration that edition annotations must be separated from title cleanup. [S004 `0x1001b7724`; S019 `0x1001af030`]

A separate edition-regex consumer is **subtitle association**, not edition creation: `0x1001b42b0` recursively finds accepted subtitle extensions. When its matching mode is active and the candidate subtitle carries an edition marker, the reference media stem must also carry an equal captured edition. A mismatch is excluded. The captured strings use byte equality in this path; case-insensitive marker recognition does not imply case-insensitive edition-value equality. An IDX subtitle also requires a companion SUB file. [S028]

`0x10020a42c`, containing an `Episode.cpp` diagnostic path, constructs a fallback parent/work lookup using library section, optional year, title and `edition_title`. Edition therefore participates in that lookup's identity. It does not by itself recover all movie-edition grouping or version-selection rules. [S013]

For Tangerine, the concrete requirement is to carry edition/cut identity through parse hints, catalog relationships, subtitle selection and playback version choice. A generic title match must not attach a subtitle from another cut.

## Native extras collection

Native collection groups accepted video paths by extra type. The filename classifier can supply an explicit type; otherwise the caller's default type is used. The directory helper classifies its stem and enumerates accepted-extension children. A native single-primary-item gate was **not** established here; that gate in the older Python local-assets code must not be transferred into the native claim. [S005 `0x1001bb97c`; S006 `0x1001bbc3c`]

The native directory classifier uses exact case-insensitive comparisons:

| Directory stem | Native type ID |
|---|---:|
| Behind The Scenes | 5 |
| Deleted Scenes | 2 |
| Featurettes | 10 |
| Interviews | 3 |
| Scenes | 6 |
| Shorts | 11 |
| Trailers | 1 |
| Other | 12 |

Unknown names return -1. This differs from the legacy Python normalized-prefix rule. The filename classifier recognizes exact `trailer` and a `movie-trailer` prefix as type one, with additional suffix and opening/ending branches. [S016 `0x1001baed8`; S020 `0x100332538`]

Tangerine should classify extras before primary-work creation and use typed associations. Preserve the source path and the classification reason so a mistaken automatic classification can be corrected. Do not treat directory spelling variations as proven Plex compatibility beyond these recovered cases.

## Native multi-episode guard

The episode helper searches named captures `ep`, `secondEp`, `show`, `season`, `epTitle` and `year`. Absent `secondEp` defaults to the first episode. An inverted range or **end minus start greater than 100** becomes a single episode; otherwise expansion is inclusive. This permits at most 101 entries in this helper. `sp` maps to season zero. [S007 `0x1001d49cc`]

Each episode points to the same physical media. Later episode entries get integer display hints `(episode - first) * 100 / episodeCount`. These hints divide the file evenly; they are not detected boundaries or evidence that episode two begins exactly halfway through the media.

Tangerine should retain one physical file with explicit episode links and a numbering scheme. It should support user/provider boundary timestamps separately, and refuse pathological range expansion. An independent conservative expansion limit can be chosen and tested without copying Plex's limit of 101.

## Implementation consequences and remaining gaps

This investigation supports six concrete jobs: conservative filename/ID/edition parsing; local asset classification; technical-media analysis; stable file reconciliation; provider matching with durable correction; and scan completion with protected unavailable roots. Their inputs and output identities should be independent so a catalog refresh cannot overwrite progress or a user's chosen cut.

Acceptance cases should include an unplugged source; cancelled and partially failed scans; unchanged files; equal-size replacements; moves versus second copies; identical sampled prefixes/tails with different middle content; two editions with different subtitle sidecars; IFO/BUP false hash matches; multi-episode files; inverted and oversized episode ranges; extras in shared directories; and manual re-match followed by rescan.

Still unresolved: modern remote matching rank/confidence, full current native parser precedence, complete edition/version merging, stable-ID behavior across every reconciliation case, watched-state thresholds, next-episode selection and user-setting conflict rules. Those must remain explicit product decisions or receive focused evidence when needed. The recovered behavior should guide Tangerine's requirements and fixtures, not imply that all of Plex has been reconstructed.
