# Targeted Plex packaged scanner findings

This report is limited to packaged source. The later
[native scanner report](PLEX_NATIVE_SCANNER.md) and
[native catalog/API report](PLEX_NATIVE_CATALOG_API.md) supply the additional
corroboration and remaining gaps for the current executable.

Inspected 19 October 2026 for Tangerine's movie and TV catalog requirements. The installed app identifies as Plex Media Server **1.43.4.10903** (`com.plexapp.plexmediaserver`); the selected shipped bundles identify revision `e5521bd`, dated 16 August 2026.

This report describes immutable packaged Python source. **It is not native decompiler output or runtime evidence.** Current `Plex Movie.py` and `Plex TV Series.py` each contain only `# Stub for Native Scanner.` The older scanner implementations remain packaged, and the Python metadata agent explicitly names itself **Plex Movie (Legacy)**. Their rules are useful implementation references, but do not establish that the current native scanner uses the same algorithms or thresholds.

Evidence is retained in [the source manifest](/Users/satwikpallerla/StudioProjects/study_stream/.verification/plex-targeted-20261019/packaged/source-manifest.json), with SHA-256 of each original file and numbered excerpts. The file identifiers below refer to that manifest and the adjacent `.txt` excerpts. No Plex code was executed, no service was contacted, and no user media database was inspected.

## Scope and answer status

| Question | Result in this inspection | Current native Plex status |
|---|---|---|
| Filename title/year cleanup | Complete legacy source path recovered | Requires native corroboration |
| Movie directory hints, NFO ID and disc parts | Legacy rules recovered | Requires native corroboration |
| TV show/season/episode/date parsing | Legacy ordered rules recovered | Requires native corroboration |
| Extras versus primary movies | Legacy scanner exclusion and local-asset association recovered | Requires native corroboration |
| Split movie parts versus alternate versions | Explicit legacy part stacking; limited version-directory handling | Modern edition and duplicate identity unresolved |
| Matching confidence and fallback | Legacy agent formula and sequence recovered | Modern matching thresholds unresolved |
| Local artwork association | Legacy filename and content-key rules recovered | Native precedence and user-lock behavior unresolved |

## Filename cleanup and title/year hints

`scanner-video-common`, original lines 37–199, contains `CleanName`:

1. Build lowercase name tokens. If more than two distinct recognized reversed codec/source tokens occur, reverse the entire name. Only codec/source strings longer than three characters contribute reversed tokens.
2. Attempt filesystem-encoding then UTF-8 decoding and Unicode **NFKC** normalization; lowercase the name.
3. Search a four-digit year bounded by the delimiters in `yearRx`. A year is accepted only when **1900 < year < current year + 1**. Replace that matched region with an internal year-break token.
4. Repeatedly remove nonempty square-bracket groups, strip selected suffixes and audio channel descriptions, then tokenize on spaces, hyphens, underscores, dots, parentheses and plus signs.
5. Mark release/source/codec/subtitle/edition tokens as garbage, processing from the end. Only the rightmost occurrence of any garbage token is removed; an earlier occurrence can remain part of the title. The source comment uses `Internal.Affairs.1990-INTERNAL.mkv` to explain this distinction.
6. Walk tokens from the beginning. Once two bad tokens have accumulated, later good tokens stop entering the result. A noninitial year-break terminates the title; an initial year-break is skipped. For names with at most two tokens, all tokens are treated as potentially real title words.
7. If cleanup removes everything, retain the first token. Apply the shipped `titlecase` helper and return `(name, year)`.

The code lists `extended` and `unrated` as cleanup garbage and `se` as a special-edition token (`scanner-video-common`, 25–35). It **does not create a typed edition record**. Tangerine should extract edition information before title cleanup rather than discard it and try to reconstruct it afterward.

`RetrieveSource`, lines 239–251, maps recognized release tokens into source categories such as Blu-ray, DVD, web and broadcast. These filename hints are not measured codec, resolution, bitrate or HDR facts. Tangerine's technical-media analysis should remain a separate operation.

Implementation caution: the legacy function aliases the global `subs` list and extends it on every call (126–133); its web-dl branch changes a Python `for` loop index without advancing the iterator (170–173). Recover the intention, but do not copy these implementation details into a new parser.

## Movie discovery, directory precedence and explicit identity

`scanner-movie-legacy`, lines 12–179:

- Run the common video filter before creating movie candidates.
- A DVD path containing `video_ts.ifo` or fallback `video_ts.bup` creates a movie from a suitable directory name. The IFO/BUP is first in `parts`; the largest VOB is also included for thumbnail/art/analysis (17–65).
- A `.../<title>/BDMV/STREAM` path creates one movie whose parts include the supplied stream files (68–74). This is a legacy source rule, not proof of modern Blu-ray playlist selection.
- Ordinary files start with cleaned filename title/year. The first two strong TV patterns are used to skip files that look episodic (80–96).
- Run multipart stacking. When one movie remains, a useful cleaned directory title/year can replace filename-derived title/year. This directory override is skipped for paths containing `Plex Versions` (97–108).
- Multiple `cd N` child directories create ordered parts sorted by numeric CD index (110–135).
- When one media item is present, search for the first `.nfo` file returned by `os.listdir`; with multiple items, look for the exact same-stem `.nfo`. Extract the first `tt[0-9]+` occurrence as a GUID hint (153–179). This is **not full NFO XML metadata ingestion**, and directory enumeration order is not guaranteed.

The model in `scanner-model`, 1–40, already separates `Movie(name, year, guid)` from a list of physical `parts`. That is a useful distinction for Tangerine, but a list of sequential parts is not interchangeable with a list of playable alternate versions.

## Split parts, alternate versions and editions

`scanner-stack`, 7–68, sorts candidates by first physical filename and compares adjacent names using `difflib.SequenceMatcher`. A stack requires exactly one one-character replacement and a recognized differing character from `123456789abcdefghijklmn`, plus a part suffix (`cd`, `dvd`, `part`, `pt`, `disk`, `disc`, `scene`) or an `x of y` form. Leading zero handling supports forms such as `part 01` versus `part 02`. Roots ending in `vol` or `volume` are explicitly excluded to avoid merging separate works such as two volumes of a series. Matching candidates append their first part to the first candidate and are removed from the top-level candidate list.

This is a bounded filename heuristic, not content duplicate detection. It does not establish stable file identity, hash deduplication, alternate-cut relationships or modern edition grouping. In TV paths, a `Plex Versions` component and the following quality component are removed before parsing organization (`scanner-series-legacy`, 86–89). This is the only explicit version-directory normalization recovered here.

`localmedia-video`, 94–103, treats files sharing their prefix through the first delimiter-bounded year as one item **for counting candidates during local asset association**. This must not be misreported as catalog-level duplicate or version merging.

Tangerine should retain four distinct concepts: catalog work, edition/cut, playable version, and ordered physical part. A re-match or edition-label change must not move file-specific playback progress to a different timeline.

## TV organization and episode parsing

`scanner-series-legacy` defines and uses ordered families of patterns:

- Strong season/episode forms: `S03E04-E05`, `S03-03`, `3x03` and related ranges; special forms `SP01` map to season zero (8–14).
- Date forms: `YYYY-MM-DD` or `MM-DD-YYYY`, with specified nonalphanumeric separators (16–19).
- Standalone episode-directory forms and a fallback family for `01 of 08`, leading episode numbers, `ep234` and other episode-only names (21–40).

At the library root, only stronger episode forms are admitted; the weakest compact numeric pattern is omitted. Valid names create a record for each episode in the inclusive range, all pointing to the same physical file (52–81). Their `display_offset` is `(episode - first) * 100 / episodeCount`, evaluated using Python 2 arithmetic. This is an evenly divided display hint, **not detected episode boundary timestamps**.

Within show directories:

1. Normalize the legacy version-directory components. A single-file directory that itself fully describes an episode can supply show, year, season, episode range and title (86–117).
2. Otherwise derive show/year from the first relative path component. The final directory's trailing digits are a potential season number (121–136).
3. For MP4/M4V/MOV, try embedded show, season, episode and title atoms. Filename season/episode patterns can refine embedded values; all required embedded identifiers must be positive before this path yields a candidate. Embedded recorded/release year is deliberately not used as a show-matching year hint (143–209).
4. Try date patterns, unless a stronger season/episode pattern exists. A date candidate stores the year as season, leaves episode number unset, and records `released_at` (211–235). This is a separate numbering scheme.
5. Try explicit patterns after masking a recognized year and codec/resolution noise. The weakest compact numeric form is additionally rejected in movie-looking directories, rejects season zero, and contains directory-season checks intended to protect absolute episode numbering (237–300).
6. Fall back to episode-only patterns with season one or a season derived from the directory. Avoid multipart stacking for `01 of 08` matches (302–343).

The presence of a `secondSeason` regex group does not prove cross-season range support: the construction loops use the first season with an episode range. Tangerine should represent cross-season or ambiguous multi-episode names explicitly and request correction instead of inheriting that behavior.

This packaged code does not establish the modern native TV ordering provider, absolute/DVD/air-date order selection, next-episode ranking, watched-state thresholds or episode-boundary detection.

## Extras and local artwork

The common legacy video scanner filters sample files below **300 MiB**, named trailers and known extra suffixes, and ignores extra directories below the source root (`scanner-video-common`, 8–14, 201–237). This prevents them becoming ordinary catalog movies during that path.

`localmedia-video`, 8–174, performs a different job: attaching local extras to an existing movie. It checks framework/server support, counts primary media while excluding trailers, samples, explicit extra suffixes and stacked parts, and searches movie extras only when the effective primary-media count is **exactly one**. Supported classifications are trailer, deleted scene, behind the scenes, interview, scene/sample, featurette, short and other. It recognizes normalized directory names beginning with the class key and filename suffixes such as `-deleted` or `-featurette`. Extras sort alphabetically within the type sequence trailer, behind the scenes, interview, deleted, scene, sample, featurette, short, other.

There is an apparent legacy bug at original lines 154–156: the branch for a filename exactly `trailer` or starting `movie-trailer` uses the existing loop variable `key` instead of explicitly assigning the trailer type. No runtime verification was attempted. Tangerine should use an explicit trailer classification and test it.

Artwork patterns (`localmedia-video`, 179–226) include movie `poster/default/cover/movie/folder` or media-stem files; fanart/art/background/backdrop; show/season posters and banners; season-zero `season-specials-*`; and episode stem/thumb files. Generic movie artwork is restricted in directories containing multiple primary movies, while a media-stem prefix can disambiguate. Asset content gets an **MD5 content key** and keys absent from the current valid set are validated away. These are local artwork keys, not media-file fingerprint identities.

The local-media agents are secondary contributors. They clear their title contribution before refresh to avoid stale local data clobbering another agent, then discover local assets/subtitles (`localmedia-entry`, 53–169). The movie agent passes only the first media item's parts to artwork association, while subtitles iterate all media items and parts. Do not infer a universal metadata precedence policy from this one contribution path.

## Legacy matching formula, useful as a reference

`movie-legacy-match`, original 81–85, explicitly labels this class `Plex Movie (Legacy)`. It provides a concrete historical algorithm, **not the current native Plex matcher**:

- Explicit GUID/ID lookup can return score 100 and stop automatic fallback (344–384).
- Otherwise consult existing media-part hashes, then a normalized title/year SHA-1 lookup key, then TMDb search. Manual matching continues through the fallbacks. The source consumes preexisting part hashes; it does not reveal their file hashing algorithm (99–163, 392–459).
- Aggregate a candidate's percentage/count across lookup results, choosing the spelling with smallest title Levenshtein distance. Score is integer `100 - titleDistance - penalties`. Percentage penalty is `(100 - aggregatePercentage) * .2`. Counts below 500 add `(500-count)/500*10`. A future release adds 10. A year difference of one/two/three adds 3/6/9; larger differences add 10 (14–22, 163–197).
- Automatic hash/title-year candidates require aggregate percentage at least 80; manual requests bypass that filter. A best score at least 98 stops the next automatic lookup stage (412–453). These numbers are stage-specific and do not prove a universal acceptance-confidence threshold.
- TMDb candidates start at 90 minus lowercase title distance, minus `5 * popularitySortedIndex`, with the same year penalty. This path also retries the original Unicode title when aggressive diacritic stripping returns nothing (199–297).
- Sort descending by score and remove repeated provider IDs (461–473). This deduplicates **search results**, not physical files or editions.

Tangerine should adopt explicit-ID priority, traceable per-candidate scoring inputs, Unicode-preserving fallback and manual correction. Its confidence thresholds must be calibrated against its own fixtures and providers; copying these historical constants would not establish Plex parity.

## Concrete Tangerine decisions and acceptance fixtures

The following are proposed independent design decisions, supported by the failure cases exposed above:

1. Emit a parse result containing raw path, preserved display title, normalized lookup title, year hint, explicit provider IDs, edition label, source hint, part index and ordered parse evidence. Never mutate physical filenames or overwrite a user's corrected catalog title during rescans.
2. Keep candidate parsing, file technical analysis, catalog matching and local-asset association as separate idempotent jobs. A service failure must leave local playback and manual organization available.
3. Classify extras before primary-title creation. Associate them with an unambiguous parent using typed relationships; preserve ambiguity in shared directories.
4. Preserve numbering scheme and inclusive episode links independently from playback timeline. Require explicit metadata or user correction for cross-season ranges and exact multi-episode boundaries.
5. Persist provider, confidence inputs, chosen match, correction and refresh provenance. Keep confidence policy versioned and user overrides durable.
6. Reconcile removed assets per source only after a completed scan. An inaccessible source or failed metadata request should not erase known assets or progress.

Required fixtures: meaningful titles containing `Internal`, `Web` or `XXX`; Unicode and decomposed filenames; `Movie (2024) 1080p` and a title beginning with a year; extension/case variants; same title with two years; NFO exact-stem versus unrelated NFO; separate `Vol 1/Vol 2` works versus `CD1/CD2` parts; two cuts with separate timelines; trailers/extras in shared folders; missing or unreadable source; `S00E01`, `SP01`, `S01E02-E03`, cross-season ranges, absolute numbering, date-based episodes, `01 of 08`, embedded tags conflicting with filename, and manual re-match without losing resume.

## Remaining evidence boundary

This pass does not establish current native filename parse scores, modern edition syntax, file-hash construction, library reconciliation/deletion semantics, live provider responses, user locks, watch/resume conflict rules or next-episode selection. The native investigation should answer those only where required for Tangerine. None requires decompiling unrelated Plex account, remote-access, discovery, billing or transcoding systems.
