# Manga page-turn direction — 21 October 2026

## Findings saved before changes

The user reports that reverse page turning fails for page edges, swipes/trackpad
and bottom controls. The running Choujin X v01 reader opens at page 8 / 240.
Its title preference visibly says Right to left, with default Previous/Next
leading/trailing tap actions. The bottom slider still starts from the left and
the previous/next buttons retain their left-to-right placement. The screenshot
is saved in .verification/manga-direction-2026-10-21/.

Source inspection through Graphify shows horizontal touch deltas and keyboard
arrows already consult rtl, but bottom controls/slider do not. There are no
trackpad pan/zoom or horizontal pointer-scroll page-turn handlers. Single-page
taps are handled by a parent detector outside the image's double-tap and zoom
gesture detector, leaving competing gesture ownership. Route single taps through
the same image detector as double taps; keep a background tap fallback.

Use effective horizontal direction consistently for physical input and mirrored
navigation controls. Keep canonical page numbers and saved positions unchanged.
Keep selection, zoom, pinch and vertical scrolling ahead of page-turn gestures.
Panels findings (docs/PANELS_DEEP_DECOMPILATION.md section 3) distinguish reversed
horizontal presentation from canonical page identity and vertical reading.

## Evidence boundary

Opening the current page and inspecting its existing preferences is design
review, not a completed page-turn acceptance run. Tests/analyzers and the separate
runtime acceptance phase remain deferred under the user's execution order.

## Implementation

BookReaderScreen now mirrors bottom button placement/icons and slider direction
for RTL horizontal reading, without reversing canonical page identity. Physical
keyboard/touch/trackpad direction uses the same effective horizontal predicate.
The image detector owns single taps together with double-tap zoom; the outer
canvas retains a tap fallback for margins. Trackpad pan/zoom events and horizontal
scroll signals have bounded turn thresholds, pinch/zoom/selection guards and a
wheel cooldown. Vertical scrolling remains outside those horizontal handlers.
Previous/next controls stop at presentation-cell boundaries, including spreads.

No preference, note or canonical position migration is introduced. The current
title's RTL preference was inspected without changing it. Automated tests,
physical touch/trackpad correctness and page-turn acceptance remain deferred.

## Rebuilt control-layout review

The normal macOS debug build succeeds. Reopening the same title retains page
8 / 240 and its existing RTL preference. The page slider now has the beginning
on the right; the physical left button represents next and the right button
represents previous. Captured in `navigation-after.png`. This is visual layout
evidence only; page-turn gestures were not executed as acceptance tests.
