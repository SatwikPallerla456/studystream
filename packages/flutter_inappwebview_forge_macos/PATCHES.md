# Tangerine macOS compatibility patch

Vendored from flutter_inappwebview_forge_macos 1.1.10, distributed at
https://pub.dev/packages/flutter_inappwebview_forge_macos/versions/1.1.10
Upstream: https://github.com/emirkanacar/flutter_inappwebview
The upstream Apache-2.0 LICENSE, NOTICE, attribution and runtime sources are retained.
Example and test-only folders are omitted. Package version and channel ABI are unchanged.

Targeted compatibility changes for Tangerine's macOS 12 minimum and installed Xcode SDK:

- Use NSEdgeInsets with left/right when reading and setting WKWebView.obscuredContentInsets.
- Store the macOS 14-only ContainerManager as Any, matching ProxyManager's existing
  availability-safe ownership pattern; cast inside the existing macOS 14 disposal guard.
- Make the default WKHTTPCookieStore a public immutable static value so public Swift
  methods can legally use it in default arguments. No code reassigned this store.

The root pubspec.yaml dependency override makes these changes reproducible instead
of modifying the user's global Pub cache. Record actual build evidence in
  docs/TANGERINE_MACOS_BUILD_VERIFICATION_2026-10-25.md.
