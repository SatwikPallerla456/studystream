# Panels deep decompilation: geometry, direction, gestures and zoom

Target is the immutable Panels 3.13.8 (974) arm64 slice, SHA-256 `9a75cdc1b6196a9d5d55c5f16c55c14a024dfbcec4950cfc854725d5a351d7dc`. This is static analysis, not an execution trace or original Swift source. Canonical REA results are in `evidence/deep3-NNN-procedure_pseudo_code.json`, verbatim C in `pseudocode/deep3-NNN.c`. The `geometry-*.asm`, reflection JSON, parsers and translated Python model are **ordinary immutable Mach-O/LLVM inspection**, not additional REA Evidence. The [evidence index](../.verification/panels-native-deep-20261019/evidence-index.json) links every record. The [reflection and instruction ledger](../.verification/panels-native-deep-20261019/geometry-notes.md) preserves supporting files. The deep3 seeded Ghidra profile disables global reference discovery; no exhaustive-call-graph claim applies.

## Major corrections to the previous report

1. The continuous sizing “geometry tag 2” is **absence of an optional PageGeometry**. `0x101536500` returns stored width/height/index/placeholder if `0 <= index < count`; otherwise all payload registers zero and final tag 2. PageGeometry reflection fields are size, index, placeholder. Bool tags 0/1 belong to present values; 2 is nil. Therefore the viewport fallback is missing geometry, not a special page category. Assembly is `geometry-0x101536500.asm`; prior canonical continuous C is E033 (`targeted-033.c`).
2. Generic single-tap continuation E066 (`0x1016c7fd4`) sends **top and center classifications to the same centerTapAction closure**. It reads global offset 0x102bdc618 for both top(0) and center(3)/other; left(1) uses 608 and right(2) uses 610. Compiled ivar metadata explicitly names these offsets. topTapAction is 600 and is not read by this continuation. Prior claim of separate top/center actions was too broad.
3. Cover/wide exceptions and the pairing anchor are recoverable; they are no longer merely unnamed tags. See below.

## Spread classification and canonical identity

Canonical new C: **deep3-045** constructor `0x1016bb948`, **046** update `0x1016bb858`, **080** forward classifier `0x1016e937c`, **081** backward classifier `0x1016e9064`. Existing E017 (`0x1016b8210`) builds spread view models from classifications; E019 (`0x1016b8c04`) maps a canonical one-based page to its containing spread.

`PagePosition` reflection descriptor `0x1021866c0` declares center, left, right, each carrying ComicGeometry.PageGeometry. Its VWT getEnumTag `0x1006f0708` returns byte 24 >> 6, confirming machine tags 0/1/2. Preserve payload bit 0 (placeholder) separately. `PageGeometry` is width,height,index,placeholder; array element stride is 32.

The update clamps `ReadingSession.doublePageFixedIndex` to zero when negative or outside geometry count. The zero-based anchor controls the pairing boundary; it does not renumber pages. Classification is computed backward from the anchor and forward after it:

- **Page index 0 is always center** (single cover).
- **Strictly landscape (`width > height`) is center**. Square pages participate like portrait pages.
- Portrait/square pages alternate pair-start(left) and pair-end(right). Pairing restarts at wide-page breaks.
- A wide page turns an adjacent unpaired half into center: forward pass repairs preceding left; reverse pass repairs following right.
- The final unpaired left is center.
- A nonzero fixed index anchors a left half; surrounding pairs are calculated on both sides, with cover and landscape repairs.

The constructor first creates placeholder geometries `(100,200,index,true)`, applies fallback alternating positions with first/last singles, and then updates from the analyzer's current geometries. These placeholder values are not real page dimensions.

`geometry-pairing-model.py` translates this instruction path for **finite positive input dimensions**; `geometry-model-examples.json` records illustrative outputs, not observations of Panels. Seven portrait pages give `[1], [2,3], [4,5], [6,7]`. Setting fixed index 2 gives `[1], [2], [3,4], [5,6], [7]`. A wide page interrupts a pair and leaves its orphan neighbor single. The independent model is review aid, not app code or exact recovered source.

E017 emits a center as a singleton; a left entry followed by right as one paired spread; a right entry is consumed by its preceding left and does not emit another spread. The loop does not skip its numeric index; its tag drives this behavior. If pairing is unavailable, left falls back to single. On the true direction predicate, paired source order is swapped. E019 checks either source page index+1 and returns the presentation spread index or nil. Stored identities remain canonical.

## Effective reverse-reading predicate

Existing canonical E127 `0x1016adb6c`, new enum witnesses **deep3-075/076**, `0x10166b0fc`/`0x10166b144`.

The exact predicate is:

```text
reversePresentation = !readingSession.leftToRightReading
  && (pageTransition is pageCurl or panelsView
      || pageTransition.scrollDirection == horizontal)
```

ReadingSession field 13 is leftToRightReading, read through runtime metadata field-offset vector at metadata+0x44. ReaderConfiguration offsets: customTitle 0; pageTransition 16; backgroundColor 19; screenBrightness 24; scrobblerPosition 33. PageTransition is a three-byte enum with high two bits of byte 2 as tag: 0 paginated, 1 continuous, 2 pageCurl, 3 empty panelsView. PaginatedConfiguration has scrollDirection at 0, pageFitting at 1, numberOfPages at 2; continuous has scrollDirection at 0. ScrollDirection enum order is horizontal(0), vertical(1).

Thus **vertical paginated/continuous presentation does not reverse merely because the session is RTL**. Page-curl and panels-view retain the RTL condition independently of an axis payload. This predicate is shared by spread placement, neighbor selection, and horizontal scrubber presentation. It is a presentation predicate, not full default/title precedence.

`geometry-requested-types.json` preserves full field ordering and initial metadata vectors. ReadingSession's later initial offsets are zero until runtime metadata completes: **zero initial slots are not actual zero field offsets**.

## Fitting policies

New C **deep3-113/114/115** (`0x1016c3528`, `0x1016c3744`, `0x1016c3668`), selectors **141/142** (`0x1016fadc0`, `0x1016daef0`). Protocol-conformance records at `0x10204464c`, `0x1020446d4`, `0x102044734` bind methods to their actual classes. ARM64 floating aggregate returns are the authority where C drops geometry values.

PageFitting 0 `fit` selects StandardComicPageFrameCalculator; 1 `fill` selects FillScreenComicPageFrameCalculator; 2 `automatic` selects AdjustOrientationComicPageFrameCalculator. Same selector is present for single-page and page-curl readers. Standard's frame method `0x1016c3968` directly returns the reference UIView.frame. Image content fitting inside that rectangle is a separate surface operation.

For finite positive nonsquare source and viewport dimensions:

- Automatic returns the reference frame when orientations match. A portrait source in landscape viewport expands the frame to `(viewportWidth, viewportWidth*sourceHeight/sourceWidth)`. A landscape source in portrait viewport expands to `(viewportHeight*sourceWidth/sourceHeight, viewportHeight)`. This creates scrollable overflow along the mismatched axis.
- Fill computes aspect-preserving cover dimensions with scale `max(viewportWidth/sourceWidth, viewportHeight/sourceHeight)`. **Square source or square viewport takes the unchanged-frame branch**, so generic “max-cover always” is incorrect for those cases.
- In computed branches overflowing origins become zero; a dimension smaller than the available dimension uses floor-centering. Unchanged-frame branches retain the input CGRect. Safe-area/zoom transforms downstream remain separate.

Continuous sizing preserves aspect ratio at the viewport's cross-axis: vertical mode height=W*h/w; horizontal mode width=H*w/h; computed values are clamped nonnegative. Missing optional geometry retains viewport size. Paginated outer cells are viewport-sized independently of inner fitting.

## Tap bindings and settings

New C **047–050** sets up double, single, continuous and pagecurl tap actions. **146/147** are double-cell right/left bodies `0x1016be850`/`0x1016be98c`; **149/150** are single-cell right/left thunks/bodies `0x1016c3474`/`0x1016c347c`; **151–153** cover single center, side-disable and double tap.

Side tap behavior is configurable. Concrete `PanelsReadersEnvironment` conformance `0x101f58f80` uses witness table `0x102640c58`:

| Witness slot | Function | Backing setting / behavior |
| --- | --- | --- |
| +0xd8 | 0x1000cb100 | GlobalFlags._readersTapToChangePage (offset variable 0x102958690) |
| +0xf0 | 0x1000cb1cc | GlobalFlags._readersTapLeftNavigationDirectionKey (0x102958698) |
| +0x108 | 0x1000cb2e4 | GlobalFlags._readersTapRightNavigationDirectionKey (0x1029586a0) |

The static switch array `0x102931818` contains index 0 `right`, index 1 `left`. Left getter returns caseIndex!=0; right getter returns caseIndex==1. Both therefore encode “left” as true but have different unknown-value fallbacks. Left/right tap closures forward trigger bytes 8/9 respectively and select physical navigation entry points from those settings. The canonical next/previous page additionally depends on effective direction, so a universal “left tap always next in RTL” is too broad for customized settings.

The generic gate also consults zoomControl witness +0xd8 and shouldDisableSideTaps closure. Double-cell side-disable returns false at zoomScale==1; otherwise it checks the zoom-lock state's optional tag. It does not indiscriminately block every tap whenever zoomed. Single-cell center ignores action while a transition flag is active and delegates using the reader's protocol witness. Double tap toggles toward zoomScale 1 or the environment-configured target; fallback target 2.5; reset restores minimum/maximum zoom bounds to 1 and 5 and clears active zoom-lock state. Floating values/Swift optionals require assembly corroboration before full implementation.

## Remaining boundaries

- Canonical page identity and reader-specific zoom restoration are established. Exact visual position preservation through every geometry/rotation/mode change is not established.
- Configured tap branches are recovered. Every touch/swipe/device combination still needs runtime fixtures; UIKit's private gesture arbitration is outside these bodies.
- Malformed geometry, NaN dimensions, accessibility variations and live gesture timing were not exercised in this static pass.

## Canonical REA identities for geometry records

- deep3-044-procedure_pseudo_code.json: `0x10166b18c` → `ev_3f6677b5bcf3c2c193ca741e8833e37dfe033cffb4a21f2a3ed1736c32e60358`
- deep3-045-procedure_pseudo_code.json: `0x1016bb948` → `ev_06ce65fd82dd30c5c577527637eb64d2a6751ba5ebbff0b229aeaa3e81adc76a`
- deep3-046-procedure_pseudo_code.json: `0x1016bb858` → `ev_69d1dee341a8f91e9d69c7810719915da2b85e89970ec6ad4cf6ab1eb5d3f248`
- deep3-047-procedure_pseudo_code.json: `0x1016be4d0` → `ev_df8234aace103d49d5046acb2ef31bd8ab4d1ae0d37b2c62bcb8f14ddeb24ee8`
- deep3-048-procedure_pseudo_code.json: `0x1016c0690` → `ev_1a3564f77cfd6208035e2871a4f63283e12570a7b764f38cf188d680dc4b5c98`
- deep3-049-procedure_pseudo_code.json: `0x1016ccbcc` → `ev_0ba896f93b94f9a0ca9df4ff5613a2fad736b05dc0e11db4863e1a25469a8d2f`
- deep3-050-procedure_pseudo_code.json: `0x1016deb90` → `ev_e3d0d655548e151b1edee33b8947dd2e33dbfe0c9d49b0ff2229ea7084b53334`
- deep3-075-procedure_pseudo_code.json: `0x10166b0fc` → `ev_552bf2b240a328051fa1a8bdccc7f2fd54820ec61540928c8491669e3862f471`
- deep3-076-procedure_pseudo_code.json: `0x10166b144` → `ev_289d14fff3f9ddca61a00c4a5f4e990e701f642426520735a94d7e0a2c0fc58c`
- deep3-077-procedure_pseudo_code.json: `0x1006f0708` → `ev_d70f458c752aa013cf0d6c51baa6cfff97279fa1087e587b39dcd597f2d9d757`
- deep3-079-procedure_pseudo_code.json: `0x10166aea0` → `ev_cd9b2dd67d8e10c0e54271e05c9214bec61e92ddc5160c7ecc0f7b1b96826cd3`
- deep3-080-procedure_pseudo_code.json: `0x1016e937c` → `ev_2e727ea832681f0f7a151b87edb91a8947bfae8336cd365a25227d6b64a67545`
- deep3-081-procedure_pseudo_code.json: `0x1016e9064` → `ev_ec0c31660594f1c55cafd74535f4d37570f4e74b4f7bffa9c7cc8e73cde4a798`
- deep3-113-procedure_pseudo_code.json: `0x1016c3528` → `ev_0a20377fa86d7198e1d25eb8f7808142b70f196bdc26d1ad473798a1676b79d5`
- deep3-114-procedure_pseudo_code.json: `0x1016c3744` → `ev_a6fd3aa0ece037a9bc96cddfa3dd40cce58b8664ad8a59d4087b8e2d5c193fb4`
- deep3-115-procedure_pseudo_code.json: `0x1016c3668` → `ev_18df78edfb4ed4879323f6894b5aeab33b3184ff95ec0d5c30e38e819ae8feb4`
- deep3-116-procedure_pseudo_code.json: `0x101660868` → `ev_f0730a58e18e073e2450b7a918ce958cb431665832550eb1aa54a65d6452bb46`
- deep3-117-procedure_pseudo_code.json: `0x1016610d4` → `ev_5c519967f11b5a00cfee9b77e1aea225008ccbb6a46d65d7e6a62023f5392aac`
- deep3-141-procedure_pseudo_code.json: `0x1016fadc0` → `ev_451d89f279fce22593438b147f65443d3896eb902e8eaf2e59459468aced35c2`
- deep3-142-procedure_pseudo_code.json: `0x1016daef0` → `ev_a6894a7f2857ce5441e14eaa35fbb3dbc648c146202db17e3a869465efc253cd`
- deep3-146-procedure_pseudo_code.json: `0x1016be850` → `ev_ff48d9001ffa7f6fe2a5a81fb4a5c0a37b964da0dc5922c37127fc355d309be7`
- deep3-147-procedure_pseudo_code.json: `0x1016be98c` → `ev_0a1b35bb086115bb4374cc087784668296f50b99cd888aced7994077224bd685`
- deep3-148-procedure_pseudo_code.json: `0x1016beb8c` → `ev_6af1f740a67b626aff4063045c1c0b2b9318a8ef74bc21f355ac08ecd8d919a8`
- deep3-149-procedure_pseudo_code.json: `0x1016c3474` → `ev_cb72dec8d83cec1fd28bd3411df7841495768dd4dbd7005ef042b56fc228a42b`
- deep3-150-procedure_pseudo_code.json: `0x1016c347c` → `ev_2775e3f32466feeafdc50f0ede1254daab56fb415c1a75b56f0e65889f92c98f`
- deep3-151-procedure_pseudo_code.json: `0x1016c3484` → `ev_577768343d3fbb3e36e25236422d74b3e112e6aa40b6a30937d8e5003589dc6d`
- deep3-152-procedure_pseudo_code.json: `0x1016c348c` → `ev_f5981496eebee0d2f9acee7cb970852dda3d06d5dfec5800518082c19ae33bc8`
- deep3-153-procedure_pseudo_code.json: `0x1016c3494` → `ev_7a63561172ad1f0dbb2b8c7b8ad7a09ef2d0feceda2e17566da86d477d35914a`

## Zoom-lock coordinates and restoration

Canonical pseudocode plus the separately retained instructions establish this apply/capture chain:

- ZoomLocker metadata `0x102a64df8` has scrollView at +16; scrollLock +24; zoomLock at +72 (`scale,x,y`, absent tag +96); delegate at +112/+120.
- `0x1016605f4(scale,x,y,animated)` sets UIScrollView.zoomScale; when scale>1 it applies **the supplied x/y directly to setContentOffset:animated:**, stores the same doubles and notifies delegate witness +8. No coordinate normalization occurs in this method.
- `0x1016606d8` handles pinch state: at ended it reads actual UIScrollView.zoomScale/contentOffset and calls the apply/store method. Scale<=1 can clear the lock, enable scrolling, reset zoom to 1 and x offset to zero, preserving the observed vertical offset argument. This is not a generic normalized page anchor.
- Single-cell ZoomLockerDelegate conformance `0x102044588`, witness `0x102711818`, slot +8 thunk `0x1016c2ef0` → `0x1016c3278`: stores the same triple in SinglePageReaderViewController.currentZoomLock, then `0x1016fae88` copies it into ReadingSession.lastZoomLock, with identifier **`standard_single_page_reader`**.
- Single persistence clears lastZoomLock when current lock is absent **or pageFitting!=fit**. The capture delegate traps if called in a non-fit mode, an invariant to respect rather than a user-facing behavior.
- Single VC constructor `0x1016fb5ec` restores only for pageFitting==fit and saved identifier equal to `standard_single_page_reader`; it copies all three saved doubles unchanged.
- Double-cell conformance `0x102044390`, witness `0x102711620`, slot +8 `0x1016bf440` stores identical triple in DoublePageReaderViewController.currentZoomLock, then `0x1016e9f10` copies it into the session with the VC's identifier. Double VC constructor `0x1016ea418` uses identifier **`standard_double_page_reader`**, checks equality before restoration and copies identical values.
- Clearing a lock clears the 40-byte optional ReadingSessionZoomLock (String identifier, scale, CGPoint offset). Both save paths notify `0x1016b3aa0` after mutation; database commit is a separate downstream process.

These direct reads/copies/setContentOffset calls establish **UIScrollView content-offset coordinates, not normalized document/page coordinates, on this zoom-lock path**. This does not prove every other session scrollOffset shares the same space. Cross-mode single↔double zoom-lock replay is prevented by identifier equality; canonical page and continuous-position transfer require their own trace. Full geometry changes may still clamp through UIKit, so unchanged raw values do not prove invariant visual content across rotations.

The instruction files are `geometry-0x1016605f4.asm`, `geometry-0x1016606d8.asm`, `geometry-0x1016c3278.asm`, `geometry-0x1016bf440.asm`, `geometry-0x1016fae88.asm`, `geometry-0x1016e9f10.asm`, `geometry-0x1016fb5ec.asm`, and `geometry-0x1016ea418.asm`. These instruction files remain ordinary inspection. The corresponding canonical REA records are linked below.

## Continuous zoom identifiers and cell restoration

The continuous-reader constructor `0x1016cad9c` reads the optional `lastZoomLock`, compares its identifier with `0x1016ca79c`, and on equality sends the same saved scale/x/y to ZoomLocker with animation disabled. The identifier is assembled from `continuous_scroll_reader_` plus the axis label. Ordinary assembly resolves the axis label initializers `0x10164ec3c` and `0x10164e8cc` through localization with Vertical/Horizontal fallbacks. Treat the possible locale dependence as an implementation observation needing a language-switch runtime check; do not replace it with an asserted stable enum wire value.

Cell restoration `0x1016c2428` passes a present saved triple directly to ZoomLocker; the absent branch sets min/max zoom 1/5. This is separate from the normal `scrollOffset` field. The detailed state section of [the main report](PANELS_DEEP_DECOMPILATION.md) explains that distinction.

## Thumbnail layout and navigation

`HorizontalFlippableLayout` exposes horizontal flipping. The recovered isRTL-update body at `0x1017207fc` invalidates/reloads layout when the effective predicate changes; this is presentation mirroring rather than a reordering of canonical source records. The full layout preparation body `0x10171e940` builds index-path attributes in canonical item order, expands selected page/spread members and caches attributes. `0x10171f878` returns attributes by equal index path. Selection body `0x1017228a8` obtains the cell's represented canonical page, forwards it to `0x1016b35fc`, emits navigation trigger 5, then scrolls the corresponding item into view. It does not compute `count-index` in this selection body. The complete visual RTL thumb/scrubber behavior across all modes still requires runtime verification.

Two neighbor bodies make the canonical mapping explicit. `0x1016b3390` returns page+1 for normal presentation and page-1 for effective reverse presentation; `0x1016b349c` does the opposite. Each bounds-checks against 1..pageCount and returns an absent optional at the boundary. This avoids mistaking a physical directional action for a change in stored page numbering.

## Additional canonical records

Each link contains the full Evidence ID, source identity, analysis-profile digest and limitations. Assembly-only corroboration is identified by its operation.

| Procedure | Operation | Canonical response | Evidence ID |
| --- | --- | --- | --- |
| `0x101536500` | procedure_assembly | [deep3-172-procedure_assembly](../.verification/panels-native-deep-20261019/evidence/deep3-172-procedure_assembly.json) | `ev_d8aef300a7a86877ed44f702d1f33248d10777786017bc8cc8b47a616681e5be` |
| `0x1016e9f10` | procedure_pseudo_code | [deep3-192-procedure_pseudo_code](../.verification/panels-native-deep-20261019/evidence/deep3-192-procedure_pseudo_code.json) | `ev_a1bd908e9f33abb3fc7a9f9b8d9b3096316ee23486be45ced56d4857bc5f669f` |
| `0x1016fae88` | procedure_pseudo_code | [deep3-193-procedure_pseudo_code](../.verification/panels-native-deep-20261019/evidence/deep3-193-procedure_pseudo_code.json) | `ev_4c91e03169980a17b5dfb30a22529e48033331d0b9651e12b95ac3e69c52d346` |
| `0x1017207fc` | procedure_pseudo_code | [deep3-215-procedure_pseudo_code](../.verification/panels-native-deep-20261019/evidence/deep3-215-procedure_pseudo_code.json) | `ev_b1acd33a09cfa03ffd3a1707529e07c8701ae48854d5b6f05a1ccc2d0dd85c4d` |
| `0x1016605f4` | procedure_pseudo_code | [deep3-241-procedure_pseudo_code](../.verification/panels-native-deep-20261019/evidence/deep3-241-procedure_pseudo_code.json) | `ev_e389366b383a0f933be17f11ef07b81206709746ddc37c6447f9da8728007706` |
| `0x1016606d8` | procedure_pseudo_code | [deep3-242-procedure_pseudo_code](../.verification/panels-native-deep-20261019/evidence/deep3-242-procedure_pseudo_code.json) | `ev_2782dc84aff93ea2f3142b5d8dad8666540a1b4e36e77388a5e81eee7e712949` |
| `0x101660944` | procedure_pseudo_code | [deep3-243-procedure_pseudo_code](../.verification/panels-native-deep-20261019/evidence/deep3-243-procedure_pseudo_code.json) | `ev_7c3bebc92dcda86a5b196b7ef7a0262455b890afbf09ad1562450fdda9cf464c` |
| `0x101660ba8` | procedure_pseudo_code | [deep3-244-procedure_pseudo_code](../.verification/panels-native-deep-20261019/evidence/deep3-244-procedure_pseudo_code.json) | `ev_3a333bfcd9007efd87a62b0cc655c9f6c5b304cfadb720482a8bd38d9f50d5f7` |
| `0x1016c3278` | procedure_pseudo_code | [deep3-245-procedure_pseudo_code](../.verification/panels-native-deep-20261019/evidence/deep3-245-procedure_pseudo_code.json) | `ev_6f858dc61af3e54841db4a3adc447f682927513eedcc73146a97ba6947f9508e` |
| `0x1016bf440` | procedure_pseudo_code | [deep3-246-procedure_pseudo_code](../.verification/panels-native-deep-20261019/evidence/deep3-246-procedure_pseudo_code.json) | `ev_3bc04cb9c37e674794e0f086379f7911f3808aacced1cb527423aeec7400e5e0` |
| `0x1016fb5ec` | procedure_pseudo_code | [deep3-247-procedure_pseudo_code](../.verification/panels-native-deep-20261019/evidence/deep3-247-procedure_pseudo_code.json) | `ev_e60118617ce1effa62e9a66587a5e4d5211381ccff09a90677afc608369ff923` |
| `0x1016ea418` | procedure_pseudo_code | [deep3-248-procedure_pseudo_code](../.verification/panels-native-deep-20261019/evidence/deep3-248-procedure_pseudo_code.json) | `ev_223bef06959cccbdb9d4b41519236525a6bb3daebc3eb76ce8da9f1950fa3882` |
| `0x10171e940` | procedure_pseudo_code | [deep3-253-procedure_pseudo_code](../.verification/panels-native-deep-20261019/evidence/deep3-253-procedure_pseudo_code.json) | `ev_aa7e818cbb3c3f8b71cc26c84d347edfc41d9c47e0044ef25cd4dba3baef159e` |
| `0x10171f878` | procedure_pseudo_code | [deep3-254-procedure_pseudo_code](../.verification/panels-native-deep-20261019/evidence/deep3-254-procedure_pseudo_code.json) | `ev_52d8129830fb0108a2338562b683a744ccdb5dbbccfa8c40adadd4340be3153b` |
| `0x1017228a8` | procedure_pseudo_code | [deep3-255-procedure_pseudo_code](../.verification/panels-native-deep-20261019/evidence/deep3-255-procedure_pseudo_code.json) | `ev_ca8270d58981a3380fe7f34b2a8c1c44276ea235d6512d418b8e05f63c2186d7` |
| `0x1016cad9c` | procedure_pseudo_code | [deep3-281-procedure_pseudo_code](../.verification/panels-native-deep-20261019/evidence/deep3-281-procedure_pseudo_code.json) | `ev_be75eff007d45d669b1465731621d652f102e3eb1a68bfc59aedd85dd3c19992` |
| `0x1016ca79c` | procedure_pseudo_code | [deep3-282-procedure_pseudo_code](../.verification/panels-native-deep-20261019/evidence/deep3-282-procedure_pseudo_code.json) | `ev_1f82ad097abafd1e0c9be0330adf2a1f059cb4d6017d12423f9a153e6fcbac54` |
| `0x1016c2428` | procedure_pseudo_code | [deep3-283-procedure_pseudo_code](../.verification/panels-native-deep-20261019/evidence/deep3-283-procedure_pseudo_code.json) | `ev_290166a8ca62e19c77d2c755114b2abc72a1d6ae7642d035c3de5d20cfde8dc4` |
| `0x1016b349c` | procedure_pseudo_code | [deep3-313-procedure_pseudo_code](../.verification/panels-native-deep-20261019/evidence/deep3-313-procedure_pseudo_code.json) | `ev_7c96aa9b78897157b56990e88ad3ba5a9002c2b6c29019adaa4b7694ecbe5196` |
| `0x1016b3390` | procedure_pseudo_code | [deep3-314-procedure_pseudo_code](../.verification/panels-native-deep-20261019/evidence/deep3-314-procedure_pseudo_code.json) | `ev_4cfa2c0947e7c690714c1ddbf2cfdc28cf3df1b63d3cb7b96abd6a8e92e591b0` |
