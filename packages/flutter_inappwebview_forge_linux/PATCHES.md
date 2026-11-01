Pinned forge Linux dependency with application-owned build compatibility fixes:
- WPE 2.0 uses WebKitNetworkSession to own persistent container storage. Replace removed WebsiteDataManager/WebContext construction in both FDO and WPEPlatform paths, retain incognito precedence, and release the caller's session reference after view creation.
- Correct the contentBlockersChanged local variable typo.
The application's CMake bridge maps the fork's exported native target/header names to Flutter's package registration names.
- Support both the preview disable-animations setting and the stable WPE 2.54 reduced-motion setting.
