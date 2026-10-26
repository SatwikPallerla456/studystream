# Browser experience — 26 October 2026

## Findings before changes

Source-only review with Graphify; screenshot review remains disabled by the user.
No visual or runtime journey acceptance is claimed.

- Library uses a flat video/audio/document filter and immediately opens a file.
  TV show/season/episode, music artist/album/track, reading author/series and named
  collection journeys are absent, despite the native catalog storing them.
- Cards have no rich detail step, edition/version selection, ordered files,
  extras or source-independent technical facts.
- PDF uses the browser's opaque PDF iframe, so its current page/selection is not
  observable. EPUB/CBZ fall through to an unsupported message even though the
  server already has CBZ/PDF image-page delivery.
- Bookmarks require an audio/video element. Reader notes cannot preserve a page,
  normalized position or passage; existing browser Study entries can display a
  page but cannot navigate back to it.
- Host remote exposes only previous/play/pause/±10s/next; rate, volume, mute,
  seeking, tracks, chapters and native presentation are not discoverable.
- Pairing cookies, bounded paged Study, per-library browse/stream/mutate grants,
  source containment and serialized progress writes must remain authoritative.

## Design and implementation approach

Category tabs lead to scoped hierarchy breadcrumbs and natural-order lists.
Libraries remain visible; category-specific labels and shapes replace generic
movie-style cards for every medium. Collections open ordered member pages.
Details show descriptive metadata and editions/files/extras before play/read.
The reader owns page/section navigation, contents, zoom/typography/direction,
passage selection and durable locators; bounded raster/text/EPUB resources are
served through the existing authenticated origin. PDF keeps a separate original
file link as a browser fallback. Study remains contextual in the viewer.
Host controls reflect advertised active-player capabilities and remain behind
host opt-in and per-library mutation permission.

References: PLEX_TARGETED_DECOMPILATION.md and PLEX_CATALOG_SCHEMA.md for catalog
hierarchy, editions/parts and user-state separation; PANELS_DEEP_DECOMPILATION.md,
PANELS_DEEP_GEOMETRY.md and PANELS_DEEP_EPUB.md for canonical page/text anchors,
resource ownership and publication destinations. Recovered behavior is a design
reference, not proof of private browser behavior or runtime parity.

## Safe checkpoint

The user requested stopping before frontend implementation was complete. Active
browser/server/remote wiring was restored to its pre-task state. Backend/bridge
and UI/wiring drafts are saved under browser-checkpoint-2026-10-26/ with isolated
patches and a resume ledger. The requested browser features are **not activated or
verified** at this checkpoint. Earlier implementation changes remain intact.
