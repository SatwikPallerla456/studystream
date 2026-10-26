# Opening screen design — 22 October 2026

## Findings before changes

The current main entry point waits for macOS folder restoration, media-engine
setup, PDF initialization and the database before calling runApp. A custom
opening animation cannot cover that delay. There is no branded opening state;
database failure replaces the app with a separate learning-only error screen.
The existing brand is a charcoal tile with an orange fruit, green leaf and cream
play mark. Use it rather than introducing another logo or an unrelated style.

## Design

Show the branded screen in the first Flutter frame, then perform existing
startup work. Use the app's light/dark palette, a subtle orange glow, a short
scale/rotation settle of the existing mark, a staggered wordmark/tagline reveal,
and a restrained orbit accent. “Watch. Read. Learn.” represents the Plex,
Panels and StudyStream product contract. Show real initialization status without
inventing a percentage. Crossfade into the normal app once both initialization
and the roughly one-second opening animation finish. Longer initialization keeps
a quiet activity indicator; it must not replay the introduction on route changes.

Reduced motion uses a static mark and skips the animation hold/crossfade.
Failure stays on the branded screen with clear recovery text and Retry. Retain
existing data, folder-access restoration, watcher startup and paired-client
restoration. Dispose an unsuccessful provider container and avoid overlapping
retry attempts. This is an opening screen, not a new onboarding requirement.

## Evidence boundary

These findings and decisions precede implementation. Startup builds/screenshots
are allowed for design review. Automated tests/analyzers and full startup/failure/
platform acceptance remain deferred with the separate testing phase.

## Implementation and visual coverage

`main.dart` now paints TangerineStartup immediately and initializes native
access/player/reader/database work through one asynchronous initializer. The
startup host owns its provider container, prevents overlapping retries, and
waits for both readiness and the 1.15-second intro before crossfading to the
normal routed app. Reduced motion skips the intro hold and transition. There
is no splash route to reappear on back navigation. Existing watchers, client
restoration and image-cache limits remain connected.

The splash animates the existing mark with a scale/rotation settle, orbit accent,
wordmark/tagline fade and orange glow. A quiet dot indicator covers longer
initialization. Status labels describe actual stages without a fabricated
percentage. Failure retains the branded layout and offers a guarded retry.

The isolated `tool/splash_design_preview.dart` entry point was used for visual
review of light, dark, replayed animation and error layouts. It never opens a
database or source folder. Captures are saved under
`.verification/splash-2026-10-22/`. Error appearance is a preview, not evidence
that a real startup failure/retry was exercised. The normal entry point was
then rebuilt successfully and launched into the user's existing Home/library.
The ordinary build is restored and left running.

No tests or analyzers were run. Reduced-motion system changes, failure recovery,
closing during initialization, deep links and other platforms remain for later
acceptance. The review verifies composition and normal macOS launch only.

## Opening chooser correction — findings before changes

The user correctly notes that the first implementation is only a splash and
then Home. It has no separate opening screen for each run. The existing mode
chooser is only shown when no saved device role exists, so returning users do
not see it. DeviceRuntime also starts a configured server while reading saved
settings, before the user could make a fresh run choice.

Extend the completed splash by one second (2.15 seconds total, retaining the
original 1.15-second reveal). When initialization is ready, animate the same
logo from the centre to a compact upper-left brand header. Fade in a centred
Player / Server opening chooser, mark the last-used mode and wait for an explicit
selection. Player includes local or connected-server media, reading and study;
Server opens the existing sharing/setup workflow. Keep mode settings and pairing
configuration; defer server auto-start until Server is selected. Reduced motion
skips the splash hold and logo flight. Never start a server merely by displaying
the chooser. This is the new normal launch flow, not only a preview or first-run
onboarding page. Preserve later /mode switching and the existing app routes.

The first full-flow preview reached the opening chooser's semantics but rendered
an opaque red error layer. This is a visual failure, not a completed review.
Investigate the rendering diagnostic and save a corrected screenshot before
restoring the normal build. The isolated harness logs Flutter errors to its
own temporary directory for this review; it has no library access.

Diagnostics locate the red layer in the isolated preview toolbar: tooltips were
placed above the Navigator overlay. Replace those preview-only controls with
labelled buttons. The production chooser is not the source of that error. Also
keep the chooser compact: remove feature-list repetition, reserve equal space
for mode descriptions and prioritize both actions in the initial viewport.

## Revised opening implementation and preview coverage

The launch controller now holds the completed reveal for another second
(2.15 seconds total) before replacing the splash route with an 850 ms hero-logo
flight and page fade. The shared mark travels from the centre to the upper-left
brand header. The separate opening page asks which mode to use, identifies the
last-used mode, and waits for Player or Server. It appears on every launch, even
when the device already has a saved role. Only a successful mode selection
mounts the normal routed app. The existing /mode destination remains available.

Player retains local/connected library, reading and study behavior. Server
opens the existing setup/management screen. Loading, preference failure/retry
and a guarded mode-selection operation are connected. DeviceRuntime loading
now reads configuration only; configured auto-start is performed after Server
is chosen, with an already-running guard. Server preference wording describes
this choice. Saved role and sharing configuration remain available across runs.

The corrected isolated preview visibly shows light/dark opening layouts, both
actions in the first viewport, the centre splash and the completed header
handoff. Screenshots: opening-light-final.png, opening-dark-final.png,
opening-replay-splash.png and opening-replay-handoff.png. The earlier red capture
is retained as failed-review evidence. The preview toolbar error was corrected
by using labelled controls above the Navigator instead of overlay tooltips.
Preview mode actions do not change configuration or start networking.

Automated tests/analyzers and full mode persistence, networking, failure, mobile
and reduced-motion acceptance remain deferred. Source wiring, isolated layout
review and the normal startup review are distinct evidence.

## Normal revised launch review

The final normal macOS build succeeds. The real launch visibly starts with the
splash, then reaches the new opening chooser with its existing Player role
marked Last used. Both mode actions are visible and the app waits there instead
of opening Home automatically. Captured in opening-production.png and left
running for the user to select a mode. No role was changed or server started by
the review. The screenshot preview's data-free layout review and this ordinary
startup view do not replace the deferred mode/networking acceptance phase.
