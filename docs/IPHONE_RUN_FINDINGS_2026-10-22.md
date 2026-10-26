# Physical iPhone run findings — 22 October 2026

## Evidence and coverage

User-supplied debug output from a physical iPhone run. The user explicitly
confirmed that they disconnected the device: the final lost connection is not
a crash. Xcode build, installation and launch succeeded in that historical run.
No screenshots were supplied; this is log-based screen evidence and source
inspection, not a new visual walkthrough or acceptance run.

## Screen findings before changes

- Shared top bar: tapping Back twice produced `There is nothing to pop`, at
  `app_top_bar.dart:38`. Source inspection shows an unconditional router pop.
  Keep custom back callbacks; otherwise pop when possible and return Home when
  the page has no router history.
- Shell navigation: `NavigationRail` overflowed vertically by 22 pixels within
  342 pixels of available height. The log does not establish the exact device
  orientation. Source inspection shows scrolling disabled by default. Enable
  rail scrolling so destinations and trailing Network/mode controls remain
  reachable in short viewports.
- Settings → Network & devices → paired server address: `SelectableText` at
  `sync_client_section.dart:115` failed restoring a scroll offset because stored
  state was a boolean. The enclosing collapsible `StudySection` uses an
  `ExpansionTile` with a `PageStorageKey`; the address has no separate key, so
  its internal scrollable can read the panel's expansion state. Give the address
  a distinct storage key. Later inactive-element assertions may be cascading;
  that relationship is not yet verified.

## Scope and reference boundaries

These are shared navigation/layout and transient widget-state corrections.
They retain contextual notes, paired-server state and reader positions. The
Plex targeted and Panels deep decompilation findings remain implementation
references; these fixes make no new claims about private Plex/Panels behavior.

Local-network permission and media-plugin Swift Package Manager warnings are
separate from these three defects and are not addressed by this patch.

## Implementation versus verification

Source fixes address the three mechanisms above. Formatting and Graphify
maintenance are implementation work. No tests, analyzers, builds or runtime
acceptance journeys were executed for this patch. Physical-device rechecking
of Back without history, navigation in a short viewport, and opening/reopening
paired-server settings remains pending in the separate verification phase.
