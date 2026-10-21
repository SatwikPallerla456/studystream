# Tangerine screen-by-screen design review

Review date: 20 October 2026. This report was saved before the next implementation pass, as requested. Earlier edits from the screenshot session remain in the working tree; the observations below describe that intermediate state, rather than an untouched baseline.

## What the user should experience

Tangerine should feel like one media application. A person opens a library, recognises its content, and sees the tools needed for that content. Courses have lessons and learning progress. Movies have watched status and versions. Music has tracks and queues. Books have reading positions and bookmarks. Photos have viewing and slideshow controls. The underlying file identity and existing history must survive these presentation changes.

Keep the warm neutral surfaces, orange accent, typography and existing icon system. Replace competing old/new layouts through clearer hierarchy, shorter headers and category-specific controls. Do not invent artwork, online catalog results or capabilities.

## Evidence and coverage

**Observed in the running macOS app:** Home, Libraries, the populated mixed/video library, movie Details, global Search, Notes, Settings, player controls, empty Queue & playlists, Network pairing and device-mode selection. Screenshots are in `.verification/ui-review-2026-10-20/`. `*-before.png` are earlier baselines; `*-review.png` and `*-after.png` show the intermediate UI.

**Reviewed in source:** every screen listed below, its route or modal entry point, category policy, and major loading/empty/error states. Graphify supplied the screen and dependency inventory before source inspection. The route inventory is `lib/app.dart`; five main tabs live in `HomeScreen` behind `DeviceHome`. Other screens use direct Navigator routes or sheets.

**Not visually accepted:** audio, TV, books, comics, PDFs, photos, course libraries, populated playlists/collections, paired-device permissions and browser playback. The current real library has two video files; no unrelated fixture data was added to the user's library. The Mac locked during the walkthrough, so the remaining visual observations need an unlocked session. Source findings below are labelled separately from observed problems.

This is design inspection, not the deferred automated testing phase. No automated tests or analyzer were run. User-authorised app startup/hot reload and screenshots are permitted for this review.

## Cross-screen findings

1. **Observed: category language is inconsistent.** Movies previously appeared under “Learning library”; Search still says “Lessons,” Notes empty states say “any lesson,” and Settings repeatedly describes learning. Reserve this vocabulary for explicit course libraries.
2. **Observed: Home does not always mean Home.** The house button on movie Details returned to Libraries because root tab selection is retained separately from routing. Give the Home action an explicit destination while preserving Back's return context.
3. **Observed: headers and placeholders dominate useful content.** Network repeats its title; Settings has an oversized slogan; Home's empty poster consumes much of the window. Use concise page titles, compact resume cards and bounded secondary artwork.
4. **Source: controls leak between categories.** All libraries get reading preferences; the metadata form includes unrelated TV, music and book fields. Gate tools using library kind with actual media type as the mixed-library fallback.
5. **Observed/source: navigation and advanced controls are hard to discover.** Compact sidebar utility icons have no visible labels. Keep tooltips and semantic labels, and use clearly titled destinations. Advanced settings should be collapsed into labelled sections rather than a long uninterrupted page.
6. **Source: identical titles and raw errors weaken trust.** Preserve the earlier file-number/filename distinction for duplicate titles. Replace raw technical exceptions in user-facing editors with useful action text; do not discard detailed errors from diagnostics when available.
7. **Source: inactive pagination and empty controls create noise.** Hide Previous/Next when there is only one page; empty queues need Add media before shuffle/repeat/filter controls.

## Screen decisions

| Screen or surface | Evidence / user's job | Change to make in this pass |
| --- | --- | --- |
| Device startup (`DeviceHome`) | Source; open the existing mode safely | Keep the existing recovery/retry state and media-preservation message. Carry an explicit root tab request through the device-mode wrapper. |
| Mode selection | Observed; choose a role or return | Shorten the opening copy. Add Back when reached from inside the app, so reviewing the roles does not require choosing one again. Keep first-run role choice and existing data. |
| Home, populated | Observed; resume or find recent media | Keep one Continue shelf and a distinct Recently added shelf. Bound secondary poster height; keep library access nearby. Preserve genuine punctuation in titles. |
| Home, empty | Source; add the first library | Replace course-oriented multi-step prose with concise folder/files/network guidance. Keep both file-management behaviours clear. |
| Libraries | Observed; select/manage a named library | Retain compact list default, search and sort. Use items and in-progress counts; no course-wide completion bar for mixed media. |
| Library setup sheet | Source; name and categorise a folder | Keep one name, one category and one primary Create and scan action. Category selection determines subsequent screens. No extra wizard is needed. |
| Movies / music videos / mixed / other library | Observed for mixed videos; source for others | Keep direct title browsing without a course header or irrelevant global category chips. Display per-file identity when cleaned titles collide. |
| TV / artist / album / author / podcast / month drilldown | Source; browse the category hierarchy | Preserve Shows → Seasons, Artists → Albums and author/series/month grouping. Hide inactive pager; keep a direct All files escape for unmatched metadata. |
| Course library and section list | Source; follow lessons | Keep lessons, sections, course progress, sequential controls and Study tools here. Avoid replacing useful course semantics with generic media terms. |
| Library sources and category | Source; repair/add folders | Rename the surface to Library settings. Reading defaults appear for books, comics, documents, courses and mixed libraries only. Keep path/availability visible; use readable scan outcomes/errors. |
| All media browse | Source; search across libraries | Keep the two compact scope dropdowns, search, grid/list and meaningful pagination; avoid a wall of category chips. |
| Details | Observed for movie; source for other types | Retain one primary Play/Resume/Open action, quieter organisation/edit actions and collapsed file management. Use watched/read/finished category labels; no Study for ordinary movie/music/photo. |
| Metadata editor and match preview | Source; correct a title | Open on Edit details. Show common fields plus category-relevant fields; keep other existing fields available under Advanced fields so edits are not stranded. Put offline matching in a clearly named tab, without implying an online provider exists. |
| Title files / editions / multipart / extras | Source; manage advanced representations | Keep advanced organisation behind Details' Files & versions. Shorten its duplicate header; retain save/discard protections and filenames. Do not merge histories. |
| File chooser sheet | Source; attach a part/extra | Keep filename and selected state, bounded search, and hide one-page pagination. |
| Collections list | Source; organise a library | Keep named collection/ordered album data. Use a clear create action and hide one-page pagination. Do not imply every library is a photo album. |
| Collection editor | Source; name/select/reorder members | Label new vs existing collection accurately. Keep member ordering, filenames and Save. Replace raw save errors with a helpful message. |
| Global Search | Observed; find media or annotations | Rename Lessons filter/results to Titles. Route EPUB/CBZ results into their actual reader, preserving page/location parameters. Shorten the empty state. |
| Notes & bookmarks | Observed empty; source populated | Use title-based labels and relevant instructions for course/reading notes. Fix EPUB/CBZ jump routing. Retain existing notes, even for categories where new Study controls are hidden. |
| Note/bookmark sheet and editors | Source; capture or edit a location | Keep bounded item-scoped paging, two tabs and meaningful positions/passages. Reader labels say Notes & bookmarks; course labels say Study tools. No extra changes to the editor's data model. |
| Video player | Source; watch a title | Keep video tracks/subtitles/effects. Restrict sequential course/TV actions to applicable sequences or explicit queues/parts. Keep Study only for course video. |
| Audio player | Source; listen to a track/long-form title | Keep audio tracks, equalizer, speed and queue; hide video effects/subtitles. Ordinary music must not show course Study/completion. |
| Player effects / output / tracks / queue sheets | Source; adjust playback | Keep these advanced tools reachable from player menus, not competing with Play. Audio/video gating must remain consistent. No new native capability is claimed by design changes. |
| Queue & playlists | Observed empty; source populated | Make Add media the empty-state primary action; hide empty-only shuffle/repeat/filter/save controls. Preserve queue versus named playlist behaviour, import/export and reorder. |
| PDF reader | Source; read/search/bookmark pages | Keep fit/zoom/search and page navigation. Use read/unread labels and Notes & bookmarks; preserve text anchors and reader preferences. |
| EPUB and comic reader | Source; read chapters or pages | Use Previous/Next chapter or page rather than “reading cell.” Keep contents, spread controls, direction and notes. Friendly error/loading text replaces geometry/debug wording; provide an exit/recovery action. |
| Reading preferences | Source; adjust this reader or inherited defaults | Preserve explicit App/Library/This title scopes and per-field inheritance. Rename “Open Study tools” to “Notes & bookmarks” in reader tap actions. No reskin of the functional preference controls is necessary. |
| Resource / document / photo viewer | Source; preview or open a file | Photo viewing must not create reading progress or offer Study/course completion. Course resources may retain lesson navigation; ordinary documents keep reading tools and external-open fallback. |
| Photo slideshow | Source; view photos | Preserve photo-only controls and five-second pacing. Keep bounded decoding. Replace raw load errors with a concise message; no progress/completion UI. |
| Settings | Observed; change a preference | Remove learning slogan. Keep Appearance immediately visible and group Playback, Reading, Backup, Network, migration and diagnostics into labelled expandable sections. Keep permissions and recovery explanations near their controls. |
| Player controls and engine preferences | Observed upper area; source rest | Retain one Save action and editable controls. Separate shortcuts from native engine preferences through labelled expandable sections, keeping values available. |
| Network / pairing | Observed disconnected; source connected | Remove repeated hero title. Keep one concise explanation then pairing form/status. Use Network as the single title; do not alter pairing or start sharing during design review. |
| Server setup / online host | Source | Shorten duplicate header; preserve setup sequence, address/code, source controls and devices. Correct the outdated claim that all local libraries are automatically shared: library grants control access. |
| Device library permissions | Source | Preserve explicit browse/stream/change gates and dependent disabled switches. Use concise instructions and a useful load-error/retry state. Do not change any actual grants during design review. |
| Backup / restore / MyVLC import previews | Source | Preserve previews, conflict choices and warnings. Use “library data” rather than “learning data.” Do not run imports/restores as part of design inspection. |
| Browser paired player | Source only | Keep native/browser category semantics aligned. A forbidden operation must not erase valid pairing. Browser screenshots and paired-device acceptance remain pending. |

## Category contract

| Category | Browse emphasis | Primary tools and status |
| --- | --- | --- |
| Movies | Posters/titles, year, editions | Play/Resume, watched, versions, subtitles; no course Study |
| Television | Shows → seasons → episodes | Play/Resume, watched, episode sequence, subtitles |
| Music | Artists → albums → tracks | Listen/Resume, queue, audio tracks/EQ; no course completion |
| Music videos | Video titles | Play/Resume, watched, video tools |
| Audiobooks | Authors / books | Listen/Resume, speed, chapters where supported, finished |
| Podcasts | Series / episodes | Listen/Resume, speed, finished; no course Study |
| Books | Authors / titles | Read/Continue reading, contents, preferences, notes/bookmarks, read |
| Comics | Titles / pages | Read/Continue reading, spreads/direction, notes/bookmarks, read |
| Documents | Files / titles | Open/Continue reading, PDF/text tools where supported, notes/bookmarks |
| Courses | Sections / lessons | Resume learning, sequential lessons, Study tools, completion |
| Photos | Months / collections | Open, image viewing, slideshow; no reading progress/completion |
| Home videos | Months / titles | Play/Resume, watched, video tools |
| Mixed / other | Actual media type | Choose tools by actual type; never assume a course |

## Implementation order after saving this report

1. Fix explicit Home navigation and Search/Notes reader routes.
2. Correct remaining category leaks in metadata, library settings and language.
3. Reduce crowded headers, group Settings/advanced controls and improve empty-state hierarchy.
4. Apply small utility-screen fixes (pagination, reader wording/recovery, permission load recovery).
5. Hot reload for user-authorised screenshot comparison when the Mac is available; update Graphify and record the exact visual coverage. Automated tests remain a separate later phase.

## Follow-up visual coverage

Do not call the entire UI visually verified from two movie files. Review the remaining categories with suitable user-approved sample libraries, connected-device states, narrow windows, dark mode and populated queues/collections in the later visual/acceptance phase. These observations may justify further layout changes; no speculative redesign of those states is presented as evidence here.

## Implementation record after the report was saved

The next pass implemented the changes above: explicit Home/tab navigation, proper EPUB/comic jump routes, category-specific metadata fields and library reading settings, shorter headers, expandable Settings/player preferences, compact recent artwork, queue/collection empty-state actions, conditional utility pagination, reader labels/recovery and permission-load recovery. Existing course semantics and stored histories were retained. See the implementation worklog for scope and known remaining master-plan work.

Formatting completed. The user-authorised Flutter visual session compiled and hot restarted after correcting a nullable-playlist branch; hot reload completed. These are startup/compilation observations, not automated test results or category acceptance. Mac locking interrupted the first pass; the resumed screenshot work is recorded below. The saved movie Details screenshot documents the earlier category correction, which this pass retained.

Graphify was refreshed. The project mapper now includes structural Markdown headings without collapsing curated document references. Current counts and integrity details are in `graphify-out/GRAPH_REPORT.md`. Its documented Linux macro-header extraction limitation and unresolved references remain mapping limitations, not application test failures.

## Follow-up screenshot decisions

After another unlock, the current source was rebuilt into the launchable macOS app. The follow-up walkthrough captured Home, Settings, empty queue, mixed/video library, metadata editor, library settings, Search, Notes, disconnected Network and mode selection. Home from Queue and Library settings visibly selected Home; mode Back returned to Network without changing device role.

Before the next edits, three additional visual findings were recorded:

- The compact Recently added card truncates the title early because its trailing play button consumes the title width. Move the explicit play/open action onto the artwork and let the title use the whole card width. Retain separate Details versus playback actions and accessible labels.
- Metadata is correctly category-scoped, but Remove, Reset and Lock repeat as dominant controls beneath every field. Put these secondary actions into a labelled field-options menu; keep the edit state visible and Save in the header. Shorten the introductory text while retaining the override/lock explanation in help.
- Returning users still see the large first-run branding in device-mode selection, pushing role actions below the fold. Keep first-run branding for setup; use a compact in-app mode choice with the existing Back control.

These are visual design refinements. They do not authorise changing the current library category, pairing a server, editing metadata values or starting playback during this walkthrough.

The extended editor walkthrough exposed two further presentation inconsistencies before correction: Title Files used the raw release filename as a large heading although Details used the identified title, and the collection type/search fields touched each other without a clear type label. Use the effective catalog title for the Title Files heading while retaining the exact filename below; label and space the collection fields. No additional backend behaviour is needed for these changes.

The App reading-defaults panel was then inspected without changing preferences. Its fallback option said “Use app default” while editing that very app default. Change this App-scope label to “Built-in default”; retain inheritance wording for Library/Title scopes and preserve all values.

The follow-up refinements were implemented. Screenshots confirmed the full card title, quieter metadata fields, field-options menu, both in-app mode actions above the fold, the identified Title Files heading, labelled collection fields and the clarified reader default. Empty collections, the new-collection editor, the file picker, All media and player/reader preference panels were inspected without saving. The app was rebuilt from current source so reopening it retains the changes; a hot-reload-only session had reopened an older compiled layout.

Screenshot evidence now includes `home-final.png`, `settings-final.png`, `playlists-final.png`, `library-final.png`, `metadata-final.png`, `metadata-field-options.png`, `library-settings-final.png`, `search-final.png`, `notes-final.png`, `network-final.png`, `mode-final.png`, `collections-final.png`, `collection-editor-final.png`, `title-files-final.png`, `file-picker-final.png`, `browse-final.png`, `reading-preferences-final.png` and `player-settings-final.png`, all under `.verification/ui-review-2026-10-20/`. The visual record covers only the states shown. Untouched reader/media categories and connected-server states remain pending.

During the development walkthrough Flutter's native accessibility bridge logged repeated AXTree update errors. Some later accessibility observations also reported incorrect checkbox roles for ordinary text/buttons. The cause is unresolved; pointer navigation and screenshot capture continued. Accessibility acceptance must investigate this separately. No automated tests, analyzer, playback acceptance, metadata save, pairing or permission mutation was performed in this follow-up.

## Core navigation gap reported by the user: categories, scanning and identification

20 October 2026, before this next UI change. The user reports that Movies, TV,
Books, Music and the other categories are absent, scanning/identification are not
visible, and Notes in the main navigation makes the app feel like the old product.
The running app was inspected again. Screenshots are
`.verification/ui-review-2026-10-20/category-gap-notes-before.png` and
`category-gap-libraries-before.png`; the library detail screen was also inspected.

Observed product issues:

1. Main navigation presents Home / Libraries / Search / Notes / Settings. Notes
   receives the same prominence as the entire media collection, even when empty.
2. Libraries shows a single generic Imported media row with no category surface.
   There is no visible entry for an empty Movies, TV, Music or Books collection.
3. The two imported videos live in a Mixed library. The existing media-type filter
   filters library declarations, so it cannot categorize those files as Movies.
4. Add library opens a folder picker before exposing the content-type setup. The
   important product decision is hidden behind an unrelated operating-system step.
5. Library rescan lives in an overflow menu or behind an unlabelled folder icon.
   Neither says “Scan library” on the main library screen.
6. Identification is buried in title editing and an offline JSON catalog tab.
   Local detected category/title/year/episode hints have no review workflow.
7. The active build predates the latest source work; source completion has not
   been reflected in the app the user is evaluating.

Implementation decisions for this pass:

- Remove Notes from main navigation; retain item/course/reader notes and existing
  saved data. Keep a backward-compatible route for old Notes links.
- Show every media category by name on Home/Libraries, including clear empty
  states and category-specific Add library actions. Category views include
  appropriately classified files from Mixed libraries without moving user files.
- Store an indexed category facet derived from explicit library context or local
  file/metadata hints. Per-title category correction remains explicit. Filename
  categorization is not an online metadata match or proof of a movie's identity.
- Ask for library type/name before opening its folder picker.
- Expose labelled Scan library and Identify titles entry points and real scan
  progress/cancellation. Present detected local hints for review and route exact
  title/provider correction into the existing metadata editor.
- Rebuild/start the app for the user-authorized visual review and capture the
  resulting category/navigation screens. Automated tests/analyzers stay deferred.

### Confirmed failure during the renewed user walkthrough

Home → Browse all → Library type → Movies shows an empty-state instruction to
add files even though All media contains two video files. Saved screenshot:
`.verification/ui-review-2026-10-20/category-gap-movies-empty-before.png`.
This is a functional category-discovery defect: the current filter tests library
kind, so files imported into Mixed disappear from Movies. The folder-first add
flow was also observed directly and cancelled without importing anything.
The fix must include actual file categorization and category browsing, not only
renaming headings. No existing files or study data were changed in this review.

### First category implementation: visual review and next corrections

The rebuilt app now visibly shows Movies with 2 titles, all other category entry
points, and four main destinations without Notes. Opening Movies now displays
the two imported videos. Adding a library now shows name/type before the folder
picker; the setup was observed and dismissed without creating a library.
Screenshots: `categories-home-first-pass.png`, `categories-movies-first-pass.png`
and `category-add-setup-reviewed.png` in the review directory.

User-role impressions before the next refinement:

- The full category tile directory pushes Continue entirely off Home's first
  viewport. Keep the full directory on Libraries and use compact category entry
  points on Home so both media discovery and resume are visible.
- Movies repeats its heading and spends too much vertical space on generic
  explanation and a redundant all-libraries dropdown. Remove the repeated header
  and put source names plus labelled Scan/Identify actions above the titles.
- Category pages must connect to the source libraries behind them. A user should
  not need to return through Home to discover which library to scan or identify.
- Music/photos/other categories need their own appropriate card proportions and
  empty-state wording rather than the identical generic poster layout.

### Category-specific empty state

The Books walkthrough exposed another inherited media-only detail: the empty
screen used a video-library icon, generic media search and “No books titles yet”.
Save: `category-books-empty-reviewed.png`. Give fixed categories their own icon,
search wording and add-library action. This is a reviewed empty state; populated
book/music/TV libraries have not been visually exercised with real content.

### Final captured core-navigation state

The macOS debug app was rebuilt and cold-launched from the final source. The
review confirms the following visible states:

- `category-home-final.png`: every category is directly available alongside
  Continue; primary navigation is Home/Libraries/Search/Settings, without Notes.
- `category-movies-final.png`: Movies contains the two existing imported videos
  and shows its source library plus Scan library / Identify titles controls.
- `category-identification-reviewed.png`: exact filenames, detected title/year,
  local-hint status, category correction and the title/match editor entry point.
- `category-books-final.png`: Books-specific icon/search, clear empty state and
  Add books library action.
- `category-books-setup-final.png`: Books name/content are preselected before
  choosing a source folder. This was dismissed without importing files.

The running app is left on Movies. The build succeeds; automated tests and
analyzers remain deferred. This confirms those visible navigation states, not
scan completion, matching/technical/OCR correctness or the full master plan.
Populated books/music/TV category journeys, online metadata/artwork and remaining
category-specific grouping/reader workflows still require implementation or
later fixture-backed review. No manual metadata/category edits or new imports
were saved during this visual pass. Startup rebuilt derived category facets.
