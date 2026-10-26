# Automatic TheTVDB identification — 26 October 2026

## Before-change user-screen findings

Saved running-app screenshots in `.verification/automatic-identification-2026-10-26/`.
Identify titles offers local reindexing and per-item Find match only; one duplicate
movie is still filename-only while another has a user-selected TheTVDB match.
Library processing shows organization and technical analysis as Ready but has no
online identification jobs or review state. Prior live search evidence established
that the filename-derived full title/year failed, but `Brand New Day` found the
correct movie and supplied metadata/poster. Provider setup and Find match screens
were visually reviewed in `.verification/thetvdb-2026-10-26/` before those changes.

## Intended behavior

Improve manual and automatic TheTVDB searches with bounded fallback queries,
normalization, original-query title/year ranking and deduplication. Automatic
identification runs as an owned library-processing job while the app is open,
for eligible local movies/TV only. Require an explicit TheTVDB ID or a unique
normalized title/alias plus exact year; television also needs a valid episode.
Never use provider popularity as match confidence. Ambiguous or missing results
stay in review with manual correction available. Existing matches, cleared
matches, overrides, editions, progress and contextual Study notes remain intact.
Add an on/off control and explicit retry for existing unmatched files. Send only
title/year/episode identity, never filesystem paths or Study state.

The Plex targeted/native scanner and catalog findings establish separate asset,
metadata and user-state identities, locks and review; their provider ranking is
unknown. This matching policy is Tangerine's conservative policy. Panels deep
cache/geometry references support bounded work and durable reader state; no
reader changes are needed. Implementation and source inspection remain distinct
from live acceptance; tests/analyzers are deferred by project execution order.

## Implementation

- Shared manual/automatic search now issues at most four original/relaxed/punctuation/subtitle queries, deduplicates IDs and ranks against the full original title and year. An abbreviated fallback result never becomes a confidence signal on its own.
- Added per-video `identify` jobs to the existing persisted processing queue. New/changed files and existing files discovered by its bounded seeding are covered. Per-library disabling, playback/reader holds, pause, source checks, bounded retries and job recovery apply.
- Automatic application requires a unique normalized full title or alias plus exact year, or an explicit `{tvdb-ID}`. Television additionally needs exact official-order season/episode; absent/ambiguous information stays in Needs review. Provider popularity scores are not used. TV filenames without a reliable show year can require manual review.
- Selected and cleared matches are skipped. Publication rechecks the source signature, availability, input identity, setting and decision revision inside the catalog transaction. Automatic matches retain all user overrides, not only locked ones. Matching updates descriptive identity via the existing catalog store and never progress/notes/bookmarks.
- Identify titles and Processing share an automatic-identification switch and Identify unmatched titles action. Queue states expose review reasons and open manual matching. Identify titles refreshes when processing states change and distinguishes automatic matches.
- Provider privacy and manual-search copy now describe automatic behavior accurately. The embedded project credential remains outside metadata and sync.

## Verification boundary

Formatting and source inspection performed. Tests and analyzers remain deferred.
Startup/hot reload are used for permitted design review; no broad acceptance phase
is implied. Before/after screenshot and startup outcomes are recorded below.

## Startup and visual observations

macOS debug startup compiled successfully with the embedded project key; final
search-policy edits hot-reloaded successfully. During the permitted screen
review, the routine background worker identified the previously filename-only
second movie copy as **Spider-Man: Brand New Day (2026)**. Identify titles visibly
labels it “Automatically matched · TheTVDB · 2026”, while the existing first
copy remains “Catalog matched”. Both retain Find match / edit details controls.
Processing shows six Ready jobs, no review/retry jobs, the original decision kept
and the second TheTVDB identification complete. The per-library toggle is on.
This is observed coverage for the existing movie and saved manual decision,
not an exhaustive test of ambiguity, TV, offline, race or cancellation cases.

Evidence in the before-change directory: `identify-after.png`,
`processing-after.png`, `jobs-after.png`, and
`automatic-match-and-manual-controls.png`. Search result sets reaching the
20-result limit are excluded from automatic application; manual review remains
available. The matching policy is conservative, not statistically calibrated.
No automated tests or analyzers ran. `graphify update .` was attempted after code changes but its semantic-node preservation guard refused the rebuild because README nodes `readme_document` and `readme` would be lost. The existing graph was preserved; no force overwrite was used. New automatic-identification relationships are not yet reflected in graph.json.

## Obsession release-year finding (before corrective implementation)

The user added `Obsession 2026 ...mkv`. Running Processing shows its identification
job Needs review, with automatic identification enabled. Screenshot saved in
`.verification/obsession-identification-2026-10-26/before.png`.
TheTVDB year=2026 search has no exact-title candidate; its movie/369536 Obsession
has year=2025 because of its Toronto festival premiere on 2025-09-06. Extended
metadata explicitly lists theatrical releases on 2026-05-14/15 and later.
Corrective policy: bounded adjacent-year searches, exact full title/alias, and
verification of a release date matching the filename year. Require one unique
verified candidate across both adjacent years; no blanket ±1-year acceptance.
Keep the verified distribution year for this file, with match provenance recording
the premiere distinction. Bump identification job version so review jobs retry.

Implemented the release-year rule and identification version 2. The user-requested
new-movie workflow was observed after successful macOS startup: the queue retried
its review job automatically and changed to Ready with no Needs review jobs.
Obsession's details now show its poster, verified 2026 release year, cast, synopsis
and TheTVDB attribution. No manual candidate selection/application was used.
Evidence: `.verification/obsession-identification-2026-10-26/identified.png`.
Adjacent-year fallback does not resolve an ambiguous exact-year title, refuses
truncated narrow result sets, examines at most three detail records and requires
one unique candidate with an explicit matching release date. Existing selected
and cleared decisions remain protected. Tests/analyzers remain deferred.
Graphify update was attempted again; its existing README-node preservation guard
still prevents refresh and the existing graph was kept.
