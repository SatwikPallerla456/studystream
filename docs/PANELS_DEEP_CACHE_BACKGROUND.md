# Panels native cache and background implementation details

Target: Panels 3.13.8 (974), immutable arm64 slice SHA-256 `9a75cdc1b6196a9d5d55c5f16c55c14a024dfbcec4950cfc854725d5a351d7dc`.

19 October 2026 · Panels 3.13.8 (974).

This supplements the first native report. It **closes several gaps previously described as unresolved**: the per-provider memory count policy, memory-warning response, priority-aware request sharing/retry, background composition and transition duration, and a separate app-wide disk limit subsystem. Static code establishes compiled behavior; this pass did not measure execution, peak memory, or achieved throughput. Ghidra C retains Swift register/async/signature errors; preserved ARM64 assembly is the numeric/calling-convention cross-check.

`Dnnn` identifies a complete REA response in the [deep evidence folder](../.verification/panels-native-deep-20261019/evidence/), with verbatim output in [pseudocode/](../.verification/panels-native-deep-20261019/pseudocode/). Full IDs are appended below. Own `cache-*.asm`, `background-*.asm` and reflection JSON are **ordinary immutable Mach-O/LLVM inspection**, not new REA Evidence. New REA records use the main investigation's deep3 analysis profile; use each record's profile and limitations.

## 1. Concrete reader memory caches and eviction

Compiled reflection identifies `ComicPageGeneration.ComicPageImageProvider` as the owner of:

- `pagesCache: [Int: ImageResult]` and `thumbnailsCache: [Int: ImageResult]`.
- `pageLoadTasks` and `thumbnailsLoadTasks`: maps from integer index to `(Task<ImageResult, Error>, priority: TaskPriority)`.
- Optional base/page/thumbnail disk paths, a `cacheEnabled` flag, a `ComicPageImageFilterManager`, and a secure file manager.

This is separate from `ImagePageRenderer`'s prefetch maps and from the bundled Kingfisher cache. The presence of Kingfisher does not make its defaults the reader's cache policy.

**Pages:** `0x10121d288` collects `(ImageResult, index)` entries from `pagesCache`. When count is **at least 11**, it sorts newest date first and removes the suffix starting at zero-based element **9**, retaining nine entries. The page insertion path `0x10121bbf4` invokes this cleaner **before insertion**. **D082, D084, D085**, with `cache-provider.asm` and `cache-0x101225084.asm`.

**Thumbnails:** `0x10122327c` has the analogous rule: trigger at **51**, retain **49**, then callers insert a result. Direct callers include `0x10121ec60`, `0x10121f690`, `0x10121fd30`, and `0x101220dfc`. **D083** and `cache-0x10122327c.asm`, `cache-background-direct-callers.json`.

These are hysteresis rules, **not exact hard limits of ten/fifty**. A normal sequence of distinct insertions can reach eleven pages or fifty-one thumbnails before a subsequent cleanup. Replacement, other mutation paths, and concurrent task lifetimes matter. The rule counts `ImageResult` entries, **not decoded bytes**, and does not bound total application/image-framework memory.

**Recency refresh:** shared memory lookup `0x101222720` returns nil when caching is disabled or the index is absent. A valid hit creates a new `ImageResult` holding the same image/predecode/pipeline data but `mode = memoryCache` and `date = now`, replaces the dictionary entry, and returns it. Date-based eviction therefore incorporates successful accesses rather than only original generation time. **D086**. `ImageResult.LoadMode` reflection lists `extraction`, `download`, `memoryCache`, and `diskCache`; the integer tag 2 matches the memory-cache path.

**Pipeline validity:** lookup consults the optional filter manager's `0x10120d7d8`; mismatch removes the cached index and yields nil. Offline body comparison checks effective filter bytes and transformation counts. `ComicPageImageTransformation` reflection has the single case `removeBorders`, explaining why count is sufficient for that enum array. A false `shouldProcessFiltersAndTransformations` callback treats effective pipelines as empty. This is a lazy per-key invalidation path; it is not proof that every pipeline event clears every cache. **D145** confirms these comparisons; the compiled single-case transformation enum supplies the ordinary type interpretation.

**Memory warning:** provider initialization observes `UIApplicationDidReceiveMemoryWarningNotification` on the main queue with a weak capture. The block routes through an actor task to `0x1012163c0`, which replaces **both result dictionaries with the empty dictionary** and releases old values. That body does **not** clear either load-task map. **D133–D137**, with imported notification pointer `0x1027796b0` and wrapper chain in `cache-0x101215bc0.asm`, `cache-0x101216178.asm`, `cache-0x101225b74.asm`, `cache-0x101216354.asm`, `cache-0x1012163c0.asm`.

## 2. Prefetch ownership, cancellation and scheduling

`ImagePageRenderer` owns distinct `[Int: Utilities.TaskStorage<ImageResult, Error>]` prefetch maps for pages and thumbnails. Its prefetch entry point bounds-checks the requested index against provider page count, returns without creating another task for an existing map key, otherwise creates a MainActor task with a weak renderer capture, wraps/records it, and awaits cancellable value. Success notifies the multicast delegate, clears the map key, and releases task storage; error also clears/releases it. **D037–D043, D068**.

Renderer cancellation looks up `TaskStorage` by page index, invokes vtable offset `0xf0`, and removes the map key. Offline Swift descriptor decoding resolves that slot to `Utilities.TaskStorage` procedure `0x101313ce0` (descriptor `0x102178fa0`, vtable offset 17 pointer words, 16 method records). It reserves an increasing ticket under `NSLock` and queues actor cleanup. `0x101313a24` applies the action only when its ticket is greater than `latestAppliedTicket`, calls `0x1013141b8` to cancel the stored Swift task unless already cancelled, then clears the stored task and its identifier. **D173–D175**. This avoids an older queued action superseding newer storage actions; no global semaphore/concurrency count follows from this mechanism.

At the **provider** level, `0x1012168ac` captures caller `Task.currentPriority`. It checks `pageLoadTasks[index]`: an existing task is shareable when it is not cancelled and its stored priority is **greater than or equal to** the current request's priority. It then awaits that task's cancellable value. Otherwise it constructs/stores a new request task and awaits it. The recovered replacement branch does not visibly cancel the old task merely because a higher-priority request arrives; do not describe this as proven in-place priority escalation or automatic old-task cancellation. **D087**; thumbnail analogue **D089**.

When awaiting fails, `0x101217830` specifically recognizes a cancellation error, checks that the shared load task was cancelled while the calling task is still active, logs `Page load … cancelled by another caller. Retrying`, and starts the provider request path again. Other errors/caller cancellation propagate through the failure path. **D088**; thumbnail analogue **D090**. Swift asynchronous frame registers must be interpreted with assembly, not apparent C local-variable names.

UIKit still supplies prefetch index lists. No fixed application-wide ahead-page count or global decoded-memory byte budget has been recovered. Count thresholds above are useful implementation facts, but cannot substitute for those distinct quantities.

## 3. Disk cache directories and index keys

Provider initialization appends literal **`page_cache`** and **`thumbnail_cache`** directories to the optional supplied base disk path. The shared path helper `0x101222c1c` takes the appropriate directory field and appends the integer page index's decimal description with `isDirectory = false`; it adds no hash/extension in that helper. Absence of a directory returns an absent path. **D133, D144**, plus initializer/path assembly.

This is a different layer from prior fixture observations of library `.Panels/geometry` and `.Panels/thumbnails`. Do not rename one layer to the other or infer a common retention policy without following the owning cache root.

## 4. Separate app-wide disk size limiter

A distinct actor `Panels.CacheSizeLimiter` uses `roots`, a dynamic optional limit, `isInUse(URL)`, `CacheActivity`, a grace period, a target ratio, current run, periodic task, and an injectable clock. `CacheRoot` contains URL, file/folder unit, recency resource key, and hidden-file policy. This discovery corrects the earlier report's broad statement that disk eviction was unknown; it does not turn this policy into a decoded-page memory budget.

Concrete wiring at `0x1004f86bc` sets **gracePeriod = 600 seconds**, **targetRatio = 0.9**, default clock `Date.init`, open-document in-use check, and a closure reading the selected cache size. The compiled table maps `CacheSizeLimit` choices to **decimal bytes**: 1,000,000,000; 5,000,000,000; 16,000,000,000; 32,000,000,000; and nil for unlimited. These are not binary GiB. **D251** reads `cacheMaximumSizeKey`, accepts integer values 1/5/16/32, and maps an absent, invalid, or unsupported value to unlimited. This is the getter fallback; the current user selection and any separately registered defaults were not read. **D211–D212**, `cache-0x1004f86bc.asm`, `cache-0x1004f88ec.asm`, literal table at `0x101f71518`.

`0x1004fb3ac` starts periodic checking with **600 seconds**. The periodic loop sleeps the supplied interval converted to nanoseconds, checks cancellation, and dispatches later checks. **D161–D162, D214**. The starter returns without adding a second periodic task if one is already stored. **D250**, checked against assembly at `0x1005f7154`, further shows the periodic check skips an unlimited limit, reads and resets `CacheActivity.hasUnaccountedWrites` under lock, and runs cleanup only when that flag was true. Thus a timer tick does not imply a full filesystem scan. This loop does not prove the task remains scheduled while every OS lifecycle state is suspended.

Main cleanup `0x1005f72e0` collects candidates and sums byte sizes. If total exceeds the dynamic limit, the target is `Int64(limit * 0.9)` and the grace cutoff is `now - 600 seconds`. It sorts candidates **oldest date first** (sort wrapper **D235**, Date `<` comparison/swap **D234**), then removes eligible items until the remaining accounted total reaches the target or candidates are exhausted. Each deletion requires **lastUsed < cutoff** and **not in use**. Deletion failures are logged and do not count as successful space reclaimed. **D158–D160**. The target is best effort: protected/recent/inaccessible candidates can leave usage above it.

The aggregate-folder collector obtains its own configured recency date and available descendant dates, selects the newest of those dates (**D249**, `0x1005f8aa4`, generic `Comparable.<` accumulator), and uses `Date.distantPast` if none are available. It sums descendant sizes for the deletion unit. **D159**. This protects a folder containing a recently touched child, rather than dating every folder only by its own inode. Enumeration **D252** includes regular files and obtains `URLResourceValues.totalFileAllocatedSize`, falling back to `fileAllocatedSize`, then zero when neither is available. The budget therefore uses allocated disk bytes, not logical file length or decoded/RSS memory. Failed enumeration/resource reads can leave the accounted total incomplete.

The production root builder creates eight roots (**D213**). Field names are ordinary Swift-reflection corroboration of FileIndex metadata offsets (`NumFields = 53`, `FieldOffsetVectorOffset = 2` pointer words), not guessed filesystem names:

| FileIndex field | Unit | Recency | Hidden entries |
|---|---|---|---|
| internalThumbnailsStoragePath | individual files | modification date | included |
| remoteImagesPath | individual files | modification date | included |
| metadataStoragePath | individual files | modification date | included |
| storeImagesCachePath | individual files | modification date | included |
| kingfisherImagesCachePath | individual files | creation date | included |
| streamedComicsCachePath | folders at depth 2 | creation date | skipped |
| _streamedComicsCachePath | folders at depth 2 | creation date | skipped |
| comicsExtractionTempsPath | folders at depth 1 | creation date | included |

The `isInUse` closure at `0x1005f66dc` reads shared `ComicModels.OpenComicDocuments` and calls `0x101513750`. That routine locks entries, drops dead references, standardizes paths, and protects an exact path match or an ancestor/descendant match using `/` boundaries in either direction. This prevents deleting an open comic or a containing cache folder. **D230–D231** plus `cache-0x101513750.asm`, reflection class/field identity, and the shared-getter chain. This is app-owned open-document accounting, not an OS file-lock query.

## 5. Background composition and transitions

The compiled `ReadersBackground` enum contains **single(color), verticalGradient(top,bottom), horizontalGradient(left,right)**. A layer stores the enum and owns a `CAGradientLayer`. At `0x101620c8c`, enum tag 0 hides the gradient and sets the view background color. Tag 1 configures an **axial** gradient from **(.5,0) to (.5,1)**; tag 2 configures **(0,.5) to (1,.5)**. Both set **four colors `[first, first, second, second]`**. The body does not set explicit `locations`; it updates inside a `CATransaction` with implicit actions disabled and fits the gradient to view bounds. **D033**, chained import `_kCAGradientLayerAxial`, `background-view.asm`. This concretely establishes two-tone composition rather than an unresolved hypothetical shader.

`ReadersBackgroundView` lazily owns a current layer and transition layer. Layout/set-frame callbacks refit both layers to bounds, and each layer refits its gradient. **D015–D019**. This establishes resize handling, but not every caller's orientation-to-gradient selection policy.

**Discrete update `0x101620104`:** while its `updating` flag is set, it rejects another update. It refits both layers, removes their gradient animations, compares the requested enum/colors with current background, and hides/zeros the transition layer if already equal. A changed value is placed on the transition layer with alpha 0 and visible. Animated updates use `UIView.animate` with **duration 0.3 seconds, delay 0, options 4 (`BeginFromCurrentState`)**. Animation raises the overlay alpha to 1; completion installs the new value on the current layer, hides/zeros the overlay, and clears `updating`. The immediate branch performs the promotion/cleanup synchronously. Equality checks require matching enum cases and `NSObject` color equality for the one or two colors. **D030–D036**; enum arguments and lost Objective-C bools are checked against assembly.

**Interactive update `0x101620548`:** also returns while a discrete update is active. For progress exactly 0, it installs the first background on the current layer; for progress exactly 1, the second. Both endpoint branches hide the transition layer and zero its alpha. Otherwise it installs the first on current, the second on transition, sets transition alpha directly to progress, and shows it. That body does not clamp progress; callers must be traced before claiming a global 0…1 invariant. **D032**, `background-view.asm`.

This is a crossfade of complete solid/gradient layers; it does not interpolate two raw UIColor values in the recovered view routine.

## 6. Background cache lifetime and remaining bounds

The first-pass color sampling and task/result arrays remain valid. New full reflection resolves exact types: three result arrays (single UIColor?, horizontal pair?, vertical pair?) and three arrays of optional `Utilities.TaskStorage` values, indexed per page. White/black/automatic configuration enum and `DynamicBackgroundMode.singleColor/duoTone` are explicit compiled cases.

A bounded ordinary instruction-reference scan of direct ADRP/LDR accesses to the six array-offset globals found constructor initialization, requests/completions, reads in reader models, and a destructor releasing all six arrays. It did **not** reveal a standalone direct-array clearing routine. This is a bounded syntactic search, not proof of absence of indirect/optimized invalidation. See `background-field-reference-candidates.json`.

Direct callers instantiate a fresh calculator in several reader construction paths (`0x100057b24`, `0x100058ee0`, `0x1016b6368`). The last also initializes substantial surrounding reader state, so it must not be mislabeled a proven configuration-change-only invalidator without tracing its entry. Cache replacement after every pipeline/background/mode change remains a narrower unresolved question. Likewise the edge sampler itself has no automatic white-border exclusion; the separately compiled `removeBorders` transformation must be tied to the actual color input path before asserting preprocessing in all modes.

## Reproducibility and ordinary inspection artifacts

Supporting artifacts are retained in [the deep analysis folder](../.verification/panels-native-deep-20261019/). The original [native report](PANELS_NATIVE_DECOMPILATION.md) describes the target identity and earlier limitations; this supplement replaces its broader unresolved statements for the paths established here.

- `cache-swift-field-descriptors.json`: exactly 7,963 parsed descriptors, covers the full shipped `__swift5_fieldmd` byte range; symbolic refs/external chained imports decoded. Some private-parent names remain unresolved hex contexts; no source name is invented for them.
- `cache-type-accessor-index.json`: connects decoded native type contexts to metadata accessor entry points.
- `cache-class-pointer-candidates.json`: provider/background class metadata pointer candidates, not independently proven virtual method names.
- `cache-provider.asm`, `cache-provider-calls.json`, `cache-provider-string-references.json`: module instructions/calls/direct literal candidates, with original stub binding names substituted in comments.
- `background-view.asm`, `background-view-calls.json`: complete inspected background-view range and direct calls.
- `cache-task-storage.asm`, `cache-size-limiter.asm`, `cache-disk-sort.asm`: supporting routines.
- `cache_background_inspect.py`, `cache_swift_fields.py`: reproducible ordinary byte/LLVM/reflection readers; operate on the immutable target.

## Outstanding limits

No live cache hit/eviction trace or peak-memory measurement was collected. Per-provider count eviction, app-wide disk-byte eviction, task cancellation, UIKit prefetch indices, and low-level image-allocation guards are separate policies. Global simultaneous decode/conversion limits, exact thumbnail dimensions, disk encoding parameters/retention at each individual provider, framework-owned memory residency, and every calculator reset trigger remain distinct questions. Closed PDFKit/graphics internal caches are not implemented in this executable.

## Canonical REA evidence IDs

| Reference | Requested procedure | Evidence ID |
|---|---|---|
| [D015](../.verification/panels-native-deep-20261019/evidence/deep3-015-procedure_pseudo_code.json) | `0x10161fdd4` | `ev_a7aab6a245aaa2ca8925c4ea32247d2bfc24427aeaf3884b5f3fd3cfdf110b3e` |
| [D016](../.verification/panels-native-deep-20261019/evidence/deep3-016-procedure_pseudo_code.json) | `0x101620008` | `ev_d3833f1c112525202449fc832f4aa1bf109631419c016c80b793d137f312560a` |
| [D017](../.verification/panels-native-deep-20261019/evidence/deep3-017-procedure_pseudo_code.json) | `0x101620064` | `ev_705ed97c11bf3dda254436cb2c486f4bb2a73d3bb91a3450269eb72174328a64` |
| [D018](../.verification/panels-native-deep-20261019/evidence/deep3-018-procedure_pseudo_code.json) | `0x101620a90` | `ev_0c58b62d7c88c107800722faeaef01ccf09c64ceadfd882212748b7958ab2740` |
| [D019](../.verification/panels-native-deep-20261019/evidence/deep3-019-procedure_pseudo_code.json) | `0x101620c30` | `ev_42abdbfbbd5ace383243190ddb7fcb7be4fec2bd3ac2b5fed818611896b9ff91` |
| [D030](../.verification/panels-native-deep-20261019/evidence/deep3-030-procedure_pseudo_code.json) | `0x101620104` | `ev_ed12d725e34188b83832dd04aa90fbc122c76f86c57fd5aadd12dbc9326f2549` |
| [D031](../.verification/panels-native-deep-20261019/evidence/deep3-031-procedure_pseudo_code.json) | `0x1016204b0` | `ev_6d7721175dc3b027b9476a7a7a582bb1dce58bba6bf4864bb78f1face166aa38` |
| [D032](../.verification/panels-native-deep-20261019/evidence/deep3-032-procedure_pseudo_code.json) | `0x101620548` | `ev_e8e73be1653792ecfbed3ab9bf08040d4ba895b8cb32daa345e3bcd47df72bd0` |
| [D033](../.verification/panels-native-deep-20261019/evidence/deep3-033-procedure_pseudo_code.json) | `0x101620c8c` | `ev_19631d6e17e23f37b03c50f52ccdca982119dced96ef796f527d29f0defcd1c8` |
| [D034](../.verification/panels-native-deep-20261019/evidence/deep3-034-procedure_pseudo_code.json) | `0x101621114` | `ev_323a1996bb6d0c2e23a859bb95e189d3322d7addb409538f8d2a5aa061136e4d` |
| [D035](../.verification/panels-native-deep-20261019/evidence/deep3-035-procedure_pseudo_code.json) | `0x10162148c` | `ev_85787ac549fd9bdf789a280df205a3fde75a0fcce8445c092e4218be1bd86f34` |
| [D036](../.verification/panels-native-deep-20261019/evidence/deep3-036-procedure_pseudo_code.json) | `0x1016214ec` | `ev_9193486397f48b20c9c4b92756a81b3178d18735a2496fccb4e610656b7c1ebd` |
| [D037](../.verification/panels-native-deep-20261019/evidence/deep3-037-procedure_pseudo_code.json) | `0x1014ef44c` | `ev_90df4005173a8ece1014e3f04e2d7318df67451d868f40a069c05213286007df` |
| [D038](../.verification/panels-native-deep-20261019/evidence/deep3-038-procedure_pseudo_code.json) | `0x1014ef7e4` | `ev_7943f244145c3a1d3374fd0e30236aafcff0a708cd274ec04865158382cc613c` |
| [D039](../.verification/panels-native-deep-20261019/evidence/deep3-039-procedure_pseudo_code.json) | `0x1014ef8c8` | `ev_b6e16a0d23f07d7ec2ba029a45a4b8c8fc6381107f1af238e9d5f1951cf569be` |
| [D040](../.verification/panels-native-deep-20261019/evidence/deep3-040-procedure_pseudo_code.json) | `0x1014efd6c` | `ev_a1c72f5666962638ca3a0a5842c8b40915d852f406b1e49950f92f4ae066c05d` |
| [D041](../.verification/panels-native-deep-20261019/evidence/deep3-041-procedure_pseudo_code.json) | `0x1014efef4` | `ev_ac083ed9f1cf8b656274e1f87fe8d1076906d7a7b31585f172a6906d47a14c78` |
| [D042](../.verification/panels-native-deep-20261019/evidence/deep3-042-procedure_pseudo_code.json) | `0x1014f027c` | `ev_5511aa9c809caff273fd454a3639c460960d681bea63103dd6bfb1daa7e002a9` |
| [D043](../.verification/panels-native-deep-20261019/evidence/deep3-043-procedure_pseudo_code.json) | `0x1014f0360` | `ev_8657e212c362fa5b339a4b39a281ea2248446f0d1145f741ae4045886b624f49` |
| [D068](../.verification/panels-native-deep-20261019/evidence/deep3-068-procedure_pseudo_code.json) | `0x1014eece4` | `ev_5138c518fd4f523ad1ad184bcb0600aa9021823ba2ed0a8c8e25958fbefbb85e` |
| [D082](../.verification/panels-native-deep-20261019/evidence/deep3-082-procedure_pseudo_code.json) | `0x10121d288` | `ev_4e854be89796fe0a08b48409ddd3f77491603e0a4d057117098a4de93292298b` |
| [D083](../.verification/panels-native-deep-20261019/evidence/deep3-083-procedure_pseudo_code.json) | `0x10122327c` | `ev_44d3ef0b1e4e36cf5e39e6b1c9d6272cfd50d81b663d224bf84496ae120e777a` |
| [D084](../.verification/panels-native-deep-20261019/evidence/deep3-084-procedure_pseudo_code.json) | `0x101225084` | `ev_1832ae0724339f731dad8026e43c20341b4bc69eb6f6b1257a81ff8077a010b8` |
| [D085](../.verification/panels-native-deep-20261019/evidence/deep3-085-procedure_pseudo_code.json) | `0x10121bbf4` | `ev_f935c99302d43b2f1755fe9781d494120dfd1d282e538be9fc0f99c095effecc` |
| [D086](../.verification/panels-native-deep-20261019/evidence/deep3-086-procedure_pseudo_code.json) | `0x101222720` | `ev_9beed70f28ccfa38745e1d9037ce58fcdeac03cc4e6fa961ea0774195fb5dcc0` |
| [D087](../.verification/panels-native-deep-20261019/evidence/deep3-087-procedure_pseudo_code.json) | `0x1012168ac` | `ev_c478b9881b3a66c0fb2e05d0639c4cb6d57320d3e6e38c384b9ad80093836503` |
| [D088](../.verification/panels-native-deep-20261019/evidence/deep3-088-procedure_pseudo_code.json) | `0x101217830` | `ev_8c85beadc40c12491ba586028be7e3faf13f732ba88a7eedcb0de2e0fa8fbcef` |
| [D089](../.verification/panels-native-deep-20261019/evidence/deep3-089-procedure_pseudo_code.json) | `0x10121d718` | `ev_b2ef336b1fcf98ea7988b94e515c01a4714f3e61eeed7d3149b881aea1b72920` |
| [D090](../.verification/panels-native-deep-20261019/evidence/deep3-090-procedure_pseudo_code.json) | `0x10121e3bc` | `ev_88e4d124e0568fcd9cbe0968c4b780c0ee949de233e40961fa782c2bde006e11` |
| [D133](../.verification/panels-native-deep-20261019/evidence/deep3-133-procedure_pseudo_code.json) | `0x101215bc0` | `ev_68901a7f5c4c2017b2f976f93d9185418728b241098f9a3967cba8ff9654d475` |
| [D134](../.verification/panels-native-deep-20261019/evidence/deep3-134-procedure_pseudo_code.json) | `0x1012163c0` | `ev_3855d8351a4c4e0a9bc205ca78c7807563e26190aa66ae370462c86564304aa2` |
| [D135](../.verification/panels-native-deep-20261019/evidence/deep3-135-procedure_pseudo_code.json) | `0x1012236d0` | `ev_fd2d8346ef462e72e3b3a96d7ff071ec73948111f7aaf9f6b9dfd455004cc6ae` |
| [D136](../.verification/panels-native-deep-20261019/evidence/deep3-136-procedure_pseudo_code.json) | `0x101216178` | `ev_8f3d2306caacd3d8486a614cc7aca02e7dff879a091d7825c9ea8c030ff8ba31` |
| [D137](../.verification/panels-native-deep-20261019/evidence/deep3-137-procedure_pseudo_code.json) | `0x101225b74` | `ev_aed2768e92ec56b00a762db5ab8996f63df0af223ac47cd10347c4a28471b592` |
| [D144](../.verification/panels-native-deep-20261019/evidence/deep3-144-procedure_pseudo_code.json) | `0x101222c1c` | `ev_f5584f5d389c4f6d0c8eda5134c492ddcaffbe54d08d005ef739543dbc4b6e33` |
| [D145](../.verification/panels-native-deep-20261019/evidence/deep3-145-procedure_pseudo_code.json) | `0x10120d7d8` | `ev_aeeeba1d281297abf9dd4cc238c378b6426650abdf8ecffd0751257faa60a60b` |
| [D158](../.verification/panels-native-deep-20261019/evidence/deep3-158-procedure_pseudo_code.json) | `0x1005f72e0` | `ev_344ac2fae4b96e7d5b5b4b0949c9676827f744dae446657db39e1f0a8808820b` |
| [D159](../.verification/panels-native-deep-20261019/evidence/deep3-159-procedure_pseudo_code.json) | `0x1005f8158` | `ev_2cd0003db621bed96803be83c04f5a1da01a98881932d623f62852df908d3048` |
| [D160](../.verification/panels-native-deep-20261019/evidence/deep3-160-procedure_pseudo_code.json) | `0x1005f8960` | `ev_9ab70c744513c9311f09e47e0a7d4c58fe5eb8a95ceaa9a44365a1968a1588f8` |
| [D161](../.verification/panels-native-deep-20261019/evidence/deep3-161-procedure_pseudo_code.json) | `0x1005f6df0` | `ev_a4861a87978b6b2170a86c8a8a80c795c3bce0a53f1664e60c50ae231c3103bb` |
| [D162](../.verification/panels-native-deep-20261019/evidence/deep3-162-procedure_pseudo_code.json) | `0x1005f6fb0` | `ev_1142b6c3e9dc29648ce340d6968679af9efd79ee0ddc5e2389c1d17fb8bbfe28` |
| [D173](../.verification/panels-native-deep-20261019/evidence/deep3-173-procedure_pseudo_code.json) | `0x101313ce0` | `ev_88a298570c74585f68c1be47821129229f57ebca1aa740e00f725f009f1b4718` |
| [D174](../.verification/panels-native-deep-20261019/evidence/deep3-174-procedure_pseudo_code.json) | `0x101313a24` | `ev_b9bef66508486d96f9881bdb09cd4072f027fa436f0e26095c7def6bbc945edc` |
| [D175](../.verification/panels-native-deep-20261019/evidence/deep3-175-procedure_pseudo_code.json) | `0x1013141b8` | `ev_eced71d3b6ef71646f22e0475d28606e721a9f2a7700dc26d3a6a17443435996` |
| [D211](../.verification/panels-native-deep-20261019/evidence/deep3-211-procedure_pseudo_code.json) | `0x1004f86bc` | `ev_cebb095f54c41ac64ff34afe3b1a3d0dc8c39299f9bad82f0bac95609a333ab5` |
| [D212](../.verification/panels-native-deep-20261019/evidence/deep3-212-procedure_pseudo_code.json) | `0x1004f88ec` | `ev_e6ea2cca1524cbe4a277feb8248f5ab1ce4047d89315b3f3a2a5cd5c2730bf9e` |
| [D213](../.verification/panels-native-deep-20261019/evidence/deep3-213-procedure_pseudo_code.json) | `0x1005fa82c` | `ev_574dc1e36d57090c98c9194464315f87396aac034804307ad7edf95f5a3afc05` |
| [D214](../.verification/panels-native-deep-20261019/evidence/deep3-214-procedure_pseudo_code.json) | `0x1004fb3ac` | `ev_40e0e4773972e778bd760a799739b50b19f612ded60e705b3c597ac2cadfb015` |
| [D230](../.verification/panels-native-deep-20261019/evidence/deep3-230-procedure_pseudo_code.json) | `0x101513750` | `ev_f02c3d453c2a90446378bbc53fa5ecd17a10211d404355df6ed1e902f29b8c2e` |
| [D231](../.verification/panels-native-deep-20261019/evidence/deep3-231-procedure_pseudo_code.json) | `0x101513554` | `ev_75acb5c6fa0cac71c6af14a42dcfd845f3fe3b36c3f3fd36f8567ac53abd9746` |
| [D234](../.verification/panels-native-deep-20261019/evidence/deep3-234-procedure_pseudo_code.json) | `0x1005f9f7c` | `ev_9d39ef561dd093254912b2cb7f61a92478890745327cbee2ec7675ad16d33d08` |
| [D235](../.verification/panels-native-deep-20261019/evidence/deep3-235-procedure_pseudo_code.json) | `0x1005f97d0` | `ev_563bbbca84f613cd0e6b368e8b401b494e53d172f536167116d01cf1de681ff3` |
| [D249](../.verification/panels-native-deep-20261019/evidence/deep3-249-procedure_pseudo_code.json) | `0x1005f8aa4` | `ev_82ac25b71ff09516da815ce0f7814e4d2ed839bc397f56fe22889eba290acd6d` |
| [D250](../.verification/panels-native-deep-20261019/evidence/deep3-250-procedure_pseudo_code.json) | `0x1005f7154` | `ev_4fbd0f0b45082053299dc9134f110c3bd1eb88141aae5fbfe0311cbbb5ea85b6` |
| [D251](../.verification/panels-native-deep-20261019/evidence/deep3-251-procedure_pseudo_code.json) | `0x1005f5f20` | `ev_2393e3f36cb47a5cdee557789d91c4f5899ae9940e0ca34375caa855b49cd0f4` |
| [D252](../.verification/panels-native-deep-20261019/evidence/deep3-252-procedure_pseudo_code.json) | `0x1005fab90` | `ev_6931f0589632913b2e7cf8768beb1924f8e515d1e72a3601269654eb1c52418e` |
