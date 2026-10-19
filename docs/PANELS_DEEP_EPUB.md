# Panels EPUB rendering: detailed native recovery

Target is the unchanged Panels 3.13.8 (974) arm64 slice, SHA-256 `9a75cdc1b6196a9d5d55c5f16c55c14a024dfbcec4950cfc854725d5a351d7dc`. All execution descriptions below describe compiled control flow, not new runtime observations. Canonical REA evidence is distinguished from offline LLVM/Swift reflection inspection. Raw Ghidra C has incorrect Swift async/return-register prototypes in places; register-level conclusions use the matching LLVM instructions as corroboration. This pass did not execute Panels or modify product code. The report describes the shipped implementation, not reconstructed original Swift source.

## 1. Three independent mode decisions

- `EPUBImageGenerator.Mode` has cases **image**, **ePUB**. In `0x10123407c`, raw mode 0 calls the direct-image extraction branch; nonzero calls the EPUB rendering branch. Its log constructs the literal names `image`/`epub`, independently confirming the metadata case mapping.
- `EPUBPageView.RenderingConfiguration` has cases **alwaysAsComic**, **alwaysAsText**, **automatic**. Dispatch `0x101415e9c` maps 0 and 2 initially to the comic branch (`0x101417f80`), and 1 to text (`0x10141886c`).
- The current page's `RenderingMode` is **comic** (0) or **text** (1). Those two branches write the mode byte directly; this is separate from generator image-vs-EPUB mode.
- **Automatic heuristic recovered:** old REA `0x10141413c`, `ev_2976c7b416de228505ac4b78b8dbcc2d8ab4affefc535b8f78ae3f90fbe6018d`, [targeted-031.c](../.verification/panels-native-20261019/pseudocode/targeted-031.c) lines 320–359: if a current render exists, configuration==automatic, current render mode==comic, and **contentHeight / contentWidth > 2.5**, rerender through the text branch. Equality 2.5 stays comic. This is an aspect-ratio heuristic, not detection of semantic text content.
- Generator constructor `0x101233508` stores `0x0500` at object+0x10: image mode 0, adjacent comic-format byte 5. It also initializes internal caching true. This default is now canonical REA as well as corroborated by `epub-llvm-0x101233508.asm`; the exact event that later changes generator mode through setter `0x10123339c` is still unresolved.

`0x10123407c` — [`ev_550f67d0c45df44921edfc7bd7f6e0535305716d4e77975db4c726d20b30fc80`](../.verification/panels-native-deep-20261019/evidence/deep3-092-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-092.c).
`0x101415e9c` — [`ev_3e333e12efe4586955e85394f536465c27d1ee048a3c65f42183fde82aed19b2`](../.verification/panels-native-deep-20261019/evidence/deep3-096-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-096.c).
`0x101417f80` — [`ev_2c627aa524af3a69093bc03e3f1183a3fd1e8bc5d45f2ada5d4cfcfa0b0dffe6`](../.verification/panels-native-deep-20261019/evidence/deep3-098-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-098.c).
`0x10141886c` — [`ev_e8f98b23758f403be67f4dfa936063bd78937848129ec02c8128636769f07773`](../.verification/panels-native-deep-20261019/evidence/deep3-100-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-100.c).
`0x1014fb494` — [`ev_59072aff78fae13e6b5d82a8eccc4dd3eda1ab85074ee56d4740b33953ab3ef1`](../.verification/panels-native-deep-20261019/evidence/deep3-069-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-069.c).
`0x101233508` — [`ev_8ca65098fc00ad9773b58a54d2882a240c74dd9434cc0cae0f22dc0f2253ff4a`](../.verification/panels-native-deep-20261019/evidence/deep3-240-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-240.c).

`ePUBPageRenderer` itself chooses the live `EPUBPageView` path when the generator's mode getter returns 1; otherwise it delegates to `ImagePageRenderer`. This establishes two materially different pipelines: a live HTML/WebKit surface and a direct-image surface. The constructor creates both and retains a shared EPUBReader. Native render calls add one to the zero-based renderer page index before passing the page number to EPUBPageView; missing spine resources yield `pageNotFound`.

## 2. Reader configuration and HTML loading

The previously recovered `0x10140fc18` has canonical REA evidence `ev_c09e561523a0ceee5d494ae1513efbea43fe76490bc3bd0dffc52d36cbce3992`. Combining its indirect setter calls with the compiled Swift Configuration fields and offline setter disassembly now identifies exact values:

| Property | Set value | Setter / data offset |
|---|---:|---|
| asyncRenderingTimeoutInterval | 2.0 seconds | `0x1013b4600` -> `0x102a54360` |
| asyncRenderingRetries | 2 | `0x1013b46cc` -> `0x102a54368` |
| onLoadFadeInAnimationDuration | 0 | `0x1013b4798` -> `0x102a54370` |
| hideBars | true | `0x1013b3c04` -> `0x102a542f8` |
| canChangeScrollDirection | false | `0x1013b3cd0` -> `0x102a54300` |
| cssFilePaths | bundled PanelsEpubStyle.css path | metadata setter +0x828 -> `0x1013b55cc` |
| jsFilePaths | bundled PanelsEpubScripts.js path | metadata setter +0x810 -> `0x1013b5574` |

These are configuration writes; they do not by themselves establish total end-to-end timeout/retry duration. `javascriptExecutionTimeoutInterval` is a distinct property, not the 2-second property just identified.

The base ePUBKit PageView retains the actual HTML. Its load continuation constructs stylesheet `<link>` and JavaScript `<script src>` tags from those file path arrays, adds media-overlay style setup, and rewrites the `<head>`. It additionally applies reader font/text-size/night classes. It calls the optional page HTML delegate, which is Panels' viewport normalizer, before `WKWebView.loadHTMLString:baseURL:`. The **base URL is a file URL made from the directory of resource.fullHref**, through NSString.stringByDeletingLastPathComponent. It sets webview alpha 0 while loading, then waits for completion through an async task. Reset stops WKWebView loading and evaluates `document.documentElement.remove()` rather than leaving old page DOM mounted.

`0x1013d2e1c` — [`ev_863573d2f5b02eee6901d5d17034a50abd673adc3215dbf446da5a4e46c0b831`](../.verification/panels-native-deep-20261019/evidence/deep3-051-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-051.c).
`0x1013d1f68` — [`ev_3f32de7ac70d4357a24a0c958ea9bc24eaec426748a755d905cdf6f085d1ff86`](../.verification/panels-native-deep-20261019/evidence/deep3-052-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-052.c).
`0x10140ffb8` — [`ev_d5b50ef48a1447f01f8a50d5d94b7bed7ae2a8e8f9f5c741c3251d2afaff4f40`](../.verification/panels-native-deep-20261019/evidence/deep3-027-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-027.c).
`0x101410204` — [`ev_55fd5a68eab4ba45543b4e6a05631bf2f4b66ed375c975df9a91d88ed27b44a3`](../.verification/panels-native-deep-20261019/evidence/deep3-028-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-028.c).
`0x1013b5660` — [`ev_e616abe209ca7d5359ecaab185c6a84f0ce20120cfc3965e27ad617e5e9cf418`](../.verification/panels-native-deep-20261019/evidence/deep3-026-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-026.c).

The HTML/CSS/JS path establishes that mixed text, images, and SVG can reach WebKit intact. It does **not** prove exhaustive feature parity, font availability, or correct behavior for every malformed/unsupported EPUB. The existing viewport normalization still preserves numeric width/height and replaces scale directives with initial/minimum/maximum 1 and user-scalable=no.

## 3. Local-folder and archive resource adapters

`0x10140fc18` selects `ePUBFolderWrapper` when URL.isLocalDirectory, otherwise `ePUBFileDecompressor`. Swift reflection resolves wrapper fields accurately where ObjC chained pointers gave misleading alias names:

- Folder: CoreFileSystem.Path root, SecureFileManager, dictionary of relative path -> CoreFileSystem.Path.
- Archive: CoreFileSystem.Path, existential ZipUnpacker<FilePacking.ZipFileInfo>, array of ZIP entries.
- Both declare archivedFileNotFound(path), invalidFormat, unableToCalculateContent errors.

The folder lookup checks its subPaths dictionary for the requested path. Success reads Data through CoreFileSystem; failure throws archivedFileNotFound(path). A folder URL helper builds a file URL and resolves it against the root. The archive equivalent dispatches into ZipUnpacker witnesses for URL/path and byte-data access. Its sync member inventory maps the ZIP entries to their path strings. This supports archive-aware reads; the examined code does not show a custom WKURLSchemeHandler.

`0x10141cfdc` — [`ev_b96a3076d0578c055fb239231fffa9db54c0f592eab3474fae2eb20f5cce9715`](../.verification/panels-native-deep-20261019/evidence/deep3-025-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-025.c).
`0x10141d870` — [`ev_5098c5f22fbe7f7f6cdfd91077f3d6a04968c8e0c02f5bb7a0fe433eadb53e0b`](../.verification/panels-native-deep-20261019/evidence/deep3-054-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-054.c).
`0x10141c70c` — [`ev_134b8a77a77be3d43a457077eecd6c6f4f1ed554a16374d13d0220c97d744d4b`](../.verification/panels-native-deep-20261019/evidence/deep3-056-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-056.c).
`0x10141c510` — [`ev_b6ef2047795e27e40a8ce52975e255ec10f76338fbe4e55cc176ceb9f24d534b`](../.verification/panels-native-deep-20261019/evidence/deep3-163-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-163.c).
`0x10141c880` — [`ev_d52aaa2a4cb4b0598d3db55fc693d2ff9a02ec3b4c8d46c97a07143a4de49080`](../.verification/panels-native-deep-20261019/evidence/deep3-164-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-164.c).
`0x10141d7c8` — [`ev_39db6f1a084cf23ff8d3dc6da5a1159c4645b6aff44274e302d6a30491642a9a`](../.verification/panels-native-deep-20261019/evidence/deep3-165-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-165.c).
`0x10141d9a8` — [`ev_116296e773145134371d7cd20822405b23985abadabca47dae129c07bd7b3f9c`](../.verification/panels-native-deep-20261019/evidence/deep3-166-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-166.c).

Remaining boundary: the precise ZipUnpacker witness target and extraction-to-file/cache policy need another trace; do not infer full archive extraction or an HTTP/scheme resource server merely from the adapter name. HTML baseURL behavior above is established independently.

## 4. Direct image extraction is deliberately narrower than HTML rendering

The image generator first gets the requested spine resource. It invokes the resource-image parser, which performs two regex searches:

1. `<(img|image).+(src|xlink:href)=".*".+>` with case-insensitive + dot-matches-line-separators options.
2. `(src|xlink:href)=".*?"` with case-insensitive matching on the first match from step 1.

It takes the first matched attribute, removes `src=` / `xlink:href=` and surrounding quote characters, then resolves the path against **resource.relativeHref**. Repeated leading `../` segments remove parent directory components before appending the remaining image path. It looks the resolved path up in **book.images**, then reads that resource's data and constructs UIImage(initWithData:). No matching image yields nil from the parser; a matched path missing from book.images or undecodable bytes takes an error branch. This recognizes HTML `img src` and SVG `image xlink:href` resource references. It does not rasterize an entire mixed-content HTML page.

The regex helper `0x10139e6cc` ORs option bit 1, and the first caller supplies bit 8; installed Foundation NSRegularExpression.h confirms those names. Exact regex literals and callsites are retained in `epub-direct-string-candidates.json` and `epub-llvm-0x10139c200.asm`.

When extraction returns nil, generator continuation `0x1012348c0` logs 'no image element found', creates an empty UIImage and wraps it in an ImageResult. That branch itself does not automatically switch to WebKit. Successful images pass cancellation checks and the existing thumbnail/result path.

`0x101234514` — [`ev_0b0ff1275c12b0addb39f9c0ef77eaf5e23e55ba3a8579565f7a1a53ddb760f2`](../.verification/panels-native-deep-20261019/evidence/deep3-093-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-093.c).
`0x10139c200` — [`ev_e2da248d156cc69727ad340f7a301384887f04279c361d107f374d9b88f59ca6`](../.verification/panels-native-deep-20261019/evidence/deep3-222-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-222.c).
`0x10139d100` — [`ev_f50ae8521a7e3dfa664d5876e8965c6406a32b46b08dbf3765351e89dad64f0b`](../.verification/panels-native-deep-20261019/evidence/deep3-223-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-223.c).
`0x10139bc28` — [`ev_a8cd82e39214774f95d95d365b816056d7dd8d228e6cd2f93bcbc20b64b723fa`](../.verification/panels-native-deep-20261019/evidence/deep3-224-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-224.c).
`0x1012348c0` — [`ev_8cdb5da9e5cb58a4f7397306270f3e34d8dddabef2173b2359484ee8999f8b4a`](../.verification/panels-native-deep-20261019/evidence/deep3-140-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-140.c).

This explains a meaningful mixed-content distinction: live EPUB mode retains and renders full HTML; direct image mode selects an embedded image resource and can omit surrounding text/decorative layout. Do not describe those modes as interchangeable.

## 5. Native geometry handshake and page reuse

The existing five-field JS handshake remains canonical old REA `ev_6856b99a3d8700a63f671ca6bac147b91faa57941cfcd7451ba5b8379c80e5dd` and parser `ev_2976c7b416de228505ac4b78b8dbcc2d8ab4affefc535b8f78ae3f90fbe6018d`.

Newly interpreted details from that parser:

- Comic mode uses integer-truncated measured content width/height as pageSize.
- Text mode uses superview bounds if present; without a superview it falls back to width and **width * 1.6**.
- Scaled measured dimensions are also truncated toward zero before storage as pageScaledSize; pageScale retains the parsed floating value.
- Stored size/scale and layout invalidation are updated when the computed pageSize changed (or was nil) and is not the zero size. It asks the superview to relayout.
- User interaction is enabled exactly when renderingMode==text (mode 1), established in matching assembly at `0x1014156f0..0x101415700`.
- Native comic and text render branches reuse an existing render only if resource object identity, page number, reader object identity, and rendering mode match. Otherwise they clear currentRender and reset/load the base content view. Text entry additionally clears the cached size/scaled size/scale optionals before proceeding.
- The content view is mounted once and uses constraints extending half a point past all four edges: top/leading -0.5, bottom/trailing +0.5. The wrapper clips its bounds. This is an observed geometry detail; its visual motivation is not established.

`0x101417f80` — [`ev_2c627aa524af3a69093bc03e3f1183a3fd1e8bc5d45f2ada5d4cfcfa0b0dffe6`](../.verification/panels-native-deep-20261019/evidence/deep3-098-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-098.c).
`0x10141886c` — [`ev_e8f98b23758f403be67f4dfa936063bd78937848129ec02c8128636769f07773`](../.verification/panels-native-deep-20261019/evidence/deep3-100-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-100.c).
`0x101412840` — [`ev_db26944751e3e784631a2a04b764086b58eb982b893069c6d810b8d5da238259`](../.verification/panels-native-deep-20261019/evidence/deep3-029-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-029.c).

## 6. Snapshot and retry pipeline

Base ePUBKit PageView's snapshot operation constructs WKSnapshotConfiguration, sets its rect to the supplied CGRect, optionally sets snapshotWidth when the optional width is non-nil, **sets afterScreenUpdates=true**, and calls takeSnapshotWithConfiguration:completionHandler:. The completion bridge resumes with the NSError when present, otherwise returns the UIImage; an impossible both-nil branch traps. Accessing a missing weak webview returns an explicit error.

The image-generation path waits **200 ms** after the rendering/size task, checks UIImage.checkImageFitsInMemory(size, scale:1), and requests a snapshot with rect origin (0,0), the returned dimensions, and snapshotWidth=nil. This delay is local to that recovered generation path; it is not a universal page transition duration.

`0x1013d4718` — [`ev_8fd17dad88b3d7b00041f7d7179305b95fe91e46bdbac82634eeeeb99406c927`](../.verification/panels-native-deep-20261019/evidence/deep3-111-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-111.c).
`0x1013d49d0` — [`ev_b97d33b8865f6797954745416eccc095743107ac1227ffc4175eabce2b909cc4`](../.verification/panels-native-deep-20261019/evidence/deep3-138-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-138.c).
`0x101236434` — [`ev_ea443298d7b0df40618a33a3bc52a0a7f7c18e8abb606a61cfda0169f9638088`](../.verification/panels-native-deep-20261019/evidence/deep3-237-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-237.c).
`0x1012364dc` — [`ev_fbcc4e55965eeb372b9352bdbc98739b4b8519e6ec49af6d5607fbf75905a0b6`](../.verification/panels-native-deep-20261019/evidence/deep3-238-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-238.c).
`0x10141923c` — [`ev_f1906f81248bf6e809e3791f1eb4839c6d8d888948883f47e14de94e6634a31a`](../.verification/panels-native-deep-20261019/evidence/deep3-239-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-239.c).

The renderer has a separate failure retry loop: if base EPUB PageView status==failed (enum raw 3) and retry counter<3, it clears the supplied page surface state, increments the counter, and retries native creation/rendering. At retry exhaustion it reports failedToRenderPage. This is distinct from the base reader configuration's asyncRenderingRetries=2. The same code distinguishes cancellation errors from real errors and checks that the target page still matches before publishing success/error state. Task results are awaited through CoreExtensions.cancellableValue; generator code checks Task.checkCancellation before acquiring its reusable rendering page and before proceeding.

`0x1014fc118` — [`ev_689c071514ec064fc90ad1e402c351dcbd88a19bdbbf6a8831c1cb4d52a61c24`](../.verification/panels-native-deep-20261019/evidence/deep3-074-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-074.c).
`0x1014fc00c` — [`ev_871ec0a25f67a22d6fc99310793078613bedb234cb0ce878646f7b7a1a46f293`](../.verification/panels-native-deep-20261019/evidence/deep3-073-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-073.c).
`0x101235c98` — [`ev_50a099706d0a09993a9f9551ec924401a7bbac30cb05f9e5c4cb1340a7cb01f7`](../.verification/panels-native-deep-20261019/evidence/deep3-094-procedure_pseudo_code.json), [raw C](../.verification/panels-native-deep-20261019/pseudocode/deep3-094.c).

## Offline evidence and limitations

Supporting files under [the retained EPUB analysis directory](../.verification/panels-native-deep-20261019/epub-notes.md) have prefix `epub-` and are ordinary immutable artifact inspection, not canonical REA records:

- `epub-class-inventory.json` / `epub-objc-methods.json`: 42 selected ePUBKit/EPUB-support/generator/renderer classes, 235 decoded Objective-C implementations. The parser explicitly rejects false trailing categories. ObjC ivar names whose chained fixups point at imported symbols are unresolved aliases; use Swift reflection for their real names.
- [epub-reflection-selected.json](../.verification/panels-native-deep-20261019/epub-reflection-selected.json): selected records from the shared complete Swift field-descriptor parser, including exact enums, configuration fields, Book.images and resource relative/full href.
- [epub-async-vtable-candidates.json](../.verification/panels-native-deep-20261019/epub-async-vtable-candidates.json): typed class->async-descriptor candidate mapping. Each pointer's rel32 targets an actual LC_FUNCTION_STARTS entry; a context-size word is retained. This recovered methods omitted by scanning only direct code pointers.
- `epub-llvm-*.asm`, `epub-calls-*.json`: address-bounded LLVM instructions with bindings/selectors from the same Mach-O. Direct call lists do not claim indirect-call completeness.
- `epub-direct-string-candidates.json`: syntactic ADRP+ADD candidates restricted to string sections. A candidate is not a proven runtime call by itself.
- `epub-snapshot-direct-callers.json`: all direct callsites of the three specifically relevant snapshot/draw selectors in this main executable, bounded to these instructions.
- [epub-new-evidence-map.json](../.verification/panels-native-deep-20261019/epub-new-evidence-map.json): canonical new REA evidence references for this subsystem.

A bounded mode-switch search found no direct B/BL callers of setter `0x10123339c` in the main executable. A syntactic scan for metadata slot +0xb0 combined with a nearby literal mode 1 call was empty. This does not exclude indirect calls, a Swift `_modify` accessor, key-path mutation, or writes outside the scanned forms. `epub-mode-setter-syntactic-candidates.json` retains that bounded result.

Residual questions: exact generator mode-switch trigger; archive extraction/cache-file policy behind ZipUnpacker witness calls; exhaustive EPUB remote resource/font/security behavior; scripts or formats handled by WebKit internally; actual timing under huge or malformed mixed-content fixtures. No absence of a custom scheme handler was proven by an exhaustive dynamic search. No new EPUB fixture runtime was run in this subtask.
