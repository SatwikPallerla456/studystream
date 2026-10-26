# macOS build verification — 25–26 October 2026

The user explicitly requested fixing the reported launch/build errors, building
and verifying the macOS target. This authorizes build/startup verification despite
the earlier separation of implementation and automated acceptance testing.

## Repairs

- PDF route constructor now accepts its declared initialStudyAnchor.
- The player-settings import preview uses a checked immutable map across UI
  callbacks, including the previously missed speed value.
- Player time displays call the existing shared formatter correctly.
- Vendored flutter_inappwebview_forge_macos 1.1.10 under packages/ with its license
  and PATCHES.md; root dependency_overrides selects the patched copy. Fixed
  NSEdgeInsets left/right access/construction, the macOS-14 ContainerManager
  availability boundary, and public cookie method default-argument visibility.
  The global Pub cache was not edited. Minimum macOS remains 12.0.
- The libVLC runtime bundle phase is explicitly always-run, matching its intended
  ownership and avoiding the missing-output dependency warning.
- Startup log exposed Future-returning setState closures in the identification
  screen. Both refresh paths now assign inside synchronous block closures.

## Executed evidence

`flutter pub get`: exit 0, selected repository-owned macOS WebView override.

`flutter build macos --debug --no-pub`: exit 0 on 25 October; produced
`build/macos/Build/Products/Debug/Tangerine.app`.
Log: `.verification/macos-build-2026-10-25/build-debug-1.log`.

The initial Flutter launch attached a Dart VM service but later logged the
identification-screen refresh exception above; that historical launch is not
claimed to be clean. Log: `launch-debug.log` in the same evidence directory.

After Advanced MyVLC workflow implementation on 26 October, the final build
command again exited **0** and reported the same built bundle. Native compilation
also resolved the new SwiftUI state-declaration and libVLC navigation-argument
integration errors found during this pass. Final build log:
`.verification/macos-build-2026-10-25/build-advanced-verified-2026-10-26.log`.

`codesign --verify --deep --strict build/macos/Build/Products/Debug/Tangerine.app`:
exit **0** after the final build.

## Warnings and limits

Four upstream plugins still lack Swift Package Manager support and currently use
Flutter's CocoaPods fallback: local_notifier, media_kit_libs_macos_video,
media_kit_video and tray_manager. Upstream WebKit/AppKit/AVFoundation deprecation
and concurrency migration warnings remain. These notices did not prevent this
build. No warning suppression or unsupported SDK downgrade was introduced.

A successful macOS debug build/signature check does not establish release
signing/notarization, another platform's compilation, playback parity, permission
acceptance, live service-account acceptance or the deferred full test suite.

Final launch command on 26 October:
`flutter run -d macos --debug --no-pub --no-resident`, exit **0**.
Flutter reported the built application, Metal rendering initialization and completed
file synchronization. Log:
`.verification/macos-build-2026-10-25/launch-advanced-2026-10-26.log`.
No Dart unhandled exception was observed during this bounded startup check. The
native desktop_multi_window plugin still logged an early invalid-engine-handle
platform-message warning. No full feature journey or clean multi-window lifecycle
acceptance is claimed from this launch.
